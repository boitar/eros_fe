#!/usr/bin/env python3
"""Daily curated DoH server & E-Hentai fallback IP catalog generator.

Uses Python 3 standard library only so GitHub Actions requires zero pip installs.
Probes public DoH endpoints against e-hentai.org & exhentai.org, filters out
polluted/unreachable endpoints, resolves fresh bootstrap IPs, and emits a
deterministic JSON catalog published to the `doh-data` orphan branch.
"""

from __future__ import annotations

import argparse
import base64
import datetime as dt
import ipaddress
import json
import socket
import ssl
import struct
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

# Curated candidate public DoH servers (non-poisoned resolvers + known global nodes).
CANDIDATE_SERVERS: list[dict[str, Any]] = [
    {
        "id": "dns-sb",
        "name": "DNS.SB",
        "url": "https://doh.dns.sb/dns-query",
        "bootstrapIps": ["45.11.45.11", "185.222.222.222"],
        "region": "global",
    },
    {
        "id": "cloudflare",
        "name": "Cloudflare",
        "url": "https://cloudflare-dns.com/dns-query",
        "bootstrapIps": ["1.1.1.1", "1.0.0.1"],
        "region": "global",
    },
    {
        "id": "cloudflare-security",
        "name": "Cloudflare 1.0.0.1",
        "url": "https://1.0.0.1/dns-query",
        "bootstrapIps": ["1.0.0.1", "1.1.1.1"],
        "region": "global",
    },
    {
        "id": "google",
        "name": "Google DNS",
        "url": "https://dns.google/resolve",
        "bootstrapIps": ["8.8.8.8", "8.8.4.4"],
        "region": "global",
    },
    {
        "id": "quad9",
        "name": "Quad9",
        "url": "https://dns.quad9.net/dns-query",
        "bootstrapIps": ["9.9.9.9", "149.112.112.112"],
        "region": "global",
    },
    {
        "id": "adguard",
        "name": "AdGuard",
        "url": "https://dns.adguard-dns.com/dns-query",
        "bootstrapIps": ["94.140.14.14", "94.140.15.15"],
        "region": "global",
    },
    {
        "id": "dnspod",
        "name": "DNSPod",
        "url": "https://doh.pub/dns-query",
        "bootstrapIps": ["1.12.12.12", "120.53.53.53"],
        "region": "cn",
    },
    {
        "id": "mullvad",
        "name": "Mullvad DNS",
        "url": "https://dns.mullvad.net/dns-query",
        "bootstrapIps": ["194.242.2.2"],
        "region": "global",
    },
    {
        "id": "nextdns",
        "name": "NextDNS",
        "url": "https://dns.nextdns.io/dns-query",
        "bootstrapIps": ["45.90.28.0", "45.90.30.0"],
        "region": "global",
    },
]

FALLBACK_DOMAINS: list[str] = [
    "e-hentai.org",
    "exhentai.org",
    "api.e-hentai.org",
    "ehgt.org",
    "forums.e-hentai.org",
    "s.exhentai.org",
    "ehtracker.org",
]

# Known GFW DNS poisoning prefixes (kept strictly aligned with Dart `isLikelyPoisonedEhIp`).
def is_poisoned_eh_ip(ip: str) -> bool:
    if not is_valid_public_ipv4(ip):
        return True
    a, b, c, _ = (int(part) for part in ip.split("."))

    # Facebook / Meta ranges commonly injected as poisoned A records
    if (
        (a == 31 and b == 13)
        or (a == 66 and b == 220)
        or (a == 69 and b in (63, 171))
        or (a == 157 and b == 240)
        or (a == 173 and b == 252)
        or (a == 179 and b == 60 and 192 <= c <= 195)
    ):
        return True

    # Twitter / X ranges commonly injected as poisoned A records
    if (
        (a == 199 and b == 59 and 148 <= c <= 151)
        or (a == 104 and b == 244 and 40 <= c <= 47)
        or (a == 199 and b == 16 and 156 <= c <= 159)
        or (a == 199 and b == 96 and c == 57)
    ):
        return True

    # Classic GFW DNS poisoning sinkhole IPs
    if (
        (a == 59 and b == 24 and c == 3)
        or (a == 93 and b == 46 and c == 8)
        or (a == 243 and b == 185)
        or (a == 46 and b == 82 and c == 174)
        or (a == 37 and b == 61 and c == 54)
        or (a == 8 and b == 7 and c == 198)
        or (a == 203 and b == 98 and c == 7)
        or (a == 202 and b == 160 and c == 128)
        or (a == 159 and b == 106 and c == 121)
        or (a == 162 and b == 125)
    ):
        return True

    return False


def is_valid_public_ipv4(ip: str) -> bool:
    """Strictly aligned with Dart `isValidPublicIpv4` (excludes private, loopback,
    link-local, RFC 6598 CGNAT 100.64.0.0/10, RFC 2544 Fake-IP 198.18.0.0/15,
    documentation, multicast, and reserved ranges)."""
    try:
        addr = ipaddress.IPv4Address(ip)
    except ValueError:
        return False
    a, b, c, _ = addr.packed
    if a in (0, 10, 127) or a >= 224:
        return False
    if a == 100 and 64 <= b <= 127:
        return False
    if a == 169 and b == 254:
        return False
    if a == 172 and 16 <= b <= 31:
        return False
    if a == 192 and b == 168:
        return False
    if a == 192 and b == 0 and c in (0, 2):
        return False
    if a == 198 and b in (18, 19):
        return False
    if a == 198 and b == 51 and c == 100:
        return False
    if a == 203 and b == 0 and c == 113:
        return False
    return True


def encode_dns_a_query(domain: str) -> bytes:
    header = struct.pack(">HHHHHH", 0, 0x0100, 1, 0, 0, 0)
    qname = bytearray()
    for label in domain.strip().lower().split("."):
        if not label:
            continue
        raw = label.encode("ascii")
        qname.append(len(raw))
        qname.extend(raw)
    qname.append(0)
    question = bytes(qname) + struct.pack(">HH", 1, 1)
    return header + question


def _skip_dns_name(packet: bytes, offset: int) -> int:
    guard = 0
    while offset < len(packet) and guard < 128:
        guard += 1
        length = packet[offset]
        if length == 0:
            return offset + 1
        if (length & 0xC0) == 0xC0:
            return offset + 2
        offset += 1 + length
    raise ValueError("Malformed DNS name")


def decode_dns_a_response(packet: bytes) -> list[str]:
    if len(packet) < 12:
        return []
    qdcount, ancount = struct.unpack(">HH", packet[4:8])
    offset = 12
    for _ in range(qdcount):
        offset = _skip_dns_name(packet, offset) + 4
    ips: list[str] = []
    for _ in range(ancount):
        if offset >= len(packet):
            break
        offset = _skip_dns_name(packet, offset)
        if offset + 10 > len(packet):
            break
        rtype, _rclass, _ttl, rdlength = struct.unpack(">HHIH", packet[offset : offset + 10])
        offset += 10
        if offset + rdlength > len(packet):
            break
        if rtype == 1 and rdlength == 4:
            ip = ".".join(str(b) for b in packet[offset : offset + 4])
            if ip not in ips:
                ips.append(ip)
        offset += rdlength
    return ips


def query_doh_a(url: str, domain: str, timeout: float = 6.0) -> tuple[list[str], int]:
    ctx = ssl.create_default_context()
    start = time.monotonic()

    # 1. Try JSON DoH
    parsed = urllib.parse.urlsplit(url)
    params = urllib.parse.parse_qsl(parsed.query, keep_blank_values=True)
    params.extend([("name", domain), ("type", "A")])
    json_url = urllib.parse.urlunsplit(
        (parsed.scheme, parsed.netloc, parsed.path, urllib.parse.urlencode(params), "")
    )
    req = urllib.request.Request(
        json_url,
        headers={
            "Accept": "application/dns-json",
            "User-Agent": "Eros-FE/DoHCatalogBot",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
            if resp.status == 200:
                payload = json.loads(resp.read().decode("utf-8"))
                answers = payload.get("Answer") or []
                ips: list[str] = []
                for ans in answers:
                    if ans.get("type") == 1 and isinstance(ans.get("data"), str):
                        ip = ans["data"].strip()
                        if is_valid_public_ipv4(ip) and ip not in ips:
                            ips.append(ip)
                if ips:
                    ms = int((time.monotonic() - start) * 1000)
                    return ips, ms
    except (urllib.error.URLError, json.JSONDecodeError, OSError, ValueError):
        pass

    # 2. Fallback to RFC 8484 wire format
    wire = encode_dns_a_query(domain)
    b64 = base64.urlsafe_b64encode(wire).decode("ascii").rstrip("=")
    wire_params = urllib.parse.parse_qsl(parsed.query, keep_blank_values=True)
    wire_params.append(("dns", b64))
    wire_url = urllib.parse.urlunsplit(
        (parsed.scheme, parsed.netloc, parsed.path, urllib.parse.urlencode(wire_params), "")
    )
    wire_req = urllib.request.Request(
        wire_url,
        headers={
            "Accept": "application/dns-message",
            "User-Agent": "Eros-FE/DoHCatalogBot",
        },
    )
    with urllib.request.urlopen(wire_req, timeout=timeout, context=ctx) as resp:
        if resp.status != 200:
            raise RuntimeError(f"HTTP {resp.status}")
        raw = resp.read()
        ips = [ip for ip in decode_dns_a_response(raw) if is_valid_public_ipv4(ip)]
        ms = int((time.monotonic() - start) * 1000)
        return ips, ms


def resolve_bootstrap_ips(host: str, existing: list[str]) -> list[str]:
    ips: list[str] = []
    for ip in existing:
        if is_valid_public_ipv4(ip) and ip not in ips:
            ips.append(ip)
    try:
        for info in socket.getaddrinfo(host, 443, socket.AF_INET, socket.SOCK_STREAM):
            ip = info[4][0]
            if is_valid_public_ipv4(ip) and ip not in ips:
                ips.append(ip)
    except OSError:
        pass
    return ips[:4]


def build_catalog(timeout: float = 6.0) -> dict[str, Any]:
    verified_servers: list[tuple[int, dict[str, Any]]] = []

    for candidate in CANDIDATE_SERVERS:
        url = candidate["url"]
        host = urllib.parse.urlsplit(url).hostname or ""
        try:
            eh_ips, eh_ms = query_doh_a(url, "e-hentai.org", timeout=timeout)
            ex_ips, ex_ms = query_doh_a(url, "exhentai.org", timeout=timeout)
        except Exception as exc:
            print(f"[skip] {candidate['id']} ({url}): {exc}", file=sys.stderr)
            continue

        combined = eh_ips + ex_ips
        if not eh_ips or not ex_ips:
            print(f"[skip] {candidate['id']}: empty answers", file=sys.stderr)
            continue
        if any(is_poisoned_eh_ip(ip) for ip in combined):
            print(
                f"[skip] {candidate['id']}: suspected DNS pollution {combined}",
                file=sys.stderr,
            )
            continue

        avg_ms = (eh_ms + ex_ms) // 2
        bootstrap = resolve_bootstrap_ips(host, candidate.get("bootstrapIps", []))
        entry = {
            "id": candidate["id"],
            "name": candidate["name"],
            "url": url,
            "bootstrapIps": bootstrap,
            "region": candidate.get("region", "global"),
        }
        verified_servers.append((avg_ms, entry))
        print(
            f"[ok]   {candidate['id']:20s} {avg_ms:4d} ms  bootstrap={bootstrap}",
            file=sys.stderr,
        )

    verified_servers.sort(key=lambda item: (item[0], item[1]["id"]))
    servers_out = [entry for _, entry in verified_servers]

    # Resolve fresh fallbackHosts using the fastest healthy DoH servers.
    fallback_hosts: dict[str, list[str]] = {}
    resolver_urls = [s["url"] for s in servers_out[:3]] or [
        "https://cloudflare-dns.com/dns-query",
        "https://dns.google/resolve",
    ]
    for domain in FALLBACK_DOMAINS:
        ips_for_domain: list[str] = []
        for resolver_url in resolver_urls:
            try:
                ips, _ = query_doh_a(resolver_url, domain, timeout=timeout)
                for ip in ips:
                    if not is_poisoned_eh_ip(ip) and ip not in ips_for_domain:
                        ips_for_domain.append(ip)
                if ips_for_domain:
                    break
            except Exception:
                continue
        if ips_for_domain:
            fallback_hosts[domain] = ips_for_domain[:4]

    now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
    return {
        "version": 1,
        "updatedAt": now.isoformat().replace("+00:00", "Z"),
        "servers": servers_out,
        "fallbackHosts": fallback_hosts,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Update Eros-FE DoH catalog JSON")
    parser.add_argument("--output", required=True, help="Output JSON path")
    parser.add_argument("--timeout", type=float, default=6.0, help="Per-query timeout (seconds)")
    args = parser.parse_args()

    catalog = build_catalog(timeout=args.timeout)
    if len(catalog["servers"]) < 2:
        print(
            f"Error: too few healthy DoH servers verified ({len(catalog['servers'])}); refusing to overwrite catalog.",
            file=sys.stderr,
        )
        return 1

    with open(args.output, "w", encoding="utf-8") as fp:
        json.dump(catalog, fp, ensure_ascii=False, indent=2)
        fp.write("\n")

    print(
        f"Wrote {args.output}: {len(catalog['servers'])} servers, {len(catalog['fallbackHosts'])} fallback hosts.",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
