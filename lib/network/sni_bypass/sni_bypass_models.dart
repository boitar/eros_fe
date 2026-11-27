import 'package:flutter/foundation.dart';

/// Connection strategy for E-Hentai / ExHentai network traffic.
enum SniBypassMode {
  /// Standard system / external proxy transport. Zero local interception.
  standard('standard'),

  /// Local loopback proxy with TLS ClientHello record-layer fragmentation +
  /// DoH/Hosts. Preserves real SNI and full HTTPS certificate verification.
  enhanced('enhanced'),

  /// Local loopback proxy with TCP-segment ClientHello fragmentation +
  /// DoH/Hosts (keeps a single intact TLS record while splitting across TCP
  /// packets). Preserves real SNI and full HTTPS certificate verification.
  compat('compat');

  const SniBypassMode(this.storageKey);

  final String storageKey;

  bool get isBypassEnabled => this != SniBypassMode.standard;

  static SniBypassMode fromStorageKey(String? raw) {
    for (final mode in SniBypassMode.values) {
      if (mode.storageKey == raw) {
        return mode;
      }
    }
    return SniBypassMode.standard;
  }
}

/// Probe state for a DoH server or site diagnostic row.
enum ProbeStatus {
  idle,
  testing,
  ok,
  polluted,
  timeout,
  error,
}

@immutable
class DohServerConfig {
  const DohServerConfig({
    required this.id,
    required this.name,
    required this.url,
    this.bootstrapIps = const <String>[],
    this.isCustom = false,
    this.isBuiltin = false,
  });

  factory DohServerConfig.fromJson(
    Map<String, dynamic> json, {
    bool defaultCustom = false,
    bool defaultBuiltin = false,
  }) {
    final rawIps = json['bootstrapIps'] ?? json['bootstrap_ips'];
    final ips = <String>[
      if (rawIps is List)
        for (final item in rawIps)
          if (item is String && isValidPublicIpv4(item.trim())) item.trim(),
    ];
    final url = (json['url'] as String? ?? '').trim();
    final id = (json['id'] as String? ?? '').trim();
    final name = (json['name'] as String? ?? '').trim();
    return DohServerConfig(
      id: id.isNotEmpty ? id : _fallbackId(url),
      name: name.isNotEmpty ? name : (Uri.tryParse(url)?.host ?? url),
      url: url,
      bootstrapIps: List<String>.unmodifiable(ips),
      isCustom: json['isCustom'] as bool? ?? defaultCustom,
      isBuiltin: json['isBuiltin'] as bool? ?? defaultBuiltin,
    );
  }

  final String id;
  final String name;
  final String url;
  final List<String> bootstrapIps;
  final bool isCustom;
  final bool isBuiltin;

  Uri? get uri => Uri.tryParse(url);

  String get host => uri?.host ?? '';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'url': url,
        'bootstrapIps': bootstrapIps,
        'isCustom': isCustom,
        'isBuiltin': isBuiltin,
      };

  static String _fallbackId(String url) {
    final sanitized = url
        .toLowerCase()
        .replaceAll(RegExp(r'^https?://'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return sanitized.isEmpty ? 'doh-custom' : sanitized;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DohServerConfig &&
          id == other.id &&
          name == other.name &&
          url == other.url &&
          listEquals(bootstrapIps, other.bootstrapIps) &&
          isCustom == other.isCustom &&
          isBuiltin == other.isBuiltin;

  @override
  int get hashCode =>
      Object.hash(id, name, url, Object.hashAll(bootstrapIps), isCustom, isBuiltin);
}

@immutable
class DohProbeResult {
  const DohProbeResult({
    required this.serverId,
    required this.status,
    this.latencyMs,
    this.resolvedIps = const <String>[],
    this.detail,
    this.testedAt,
  });

  final String serverId;
  final ProbeStatus status;
  final int? latencyMs;
  final List<String> resolvedIps;
  final String? detail;
  final DateTime? testedAt;
}

@immutable
class SiteCheckResult {
  const SiteCheckResult({
    required this.host,
    required this.status,
    this.statusCode,
    this.latencyMs,
    this.resolvedIp,
    this.error,
  });

  final String host;
  final ProbeStatus status;
  final int? statusCode;
  final int? latencyMs;
  final String? resolvedIp;
  final String? error;
}

@immutable
class DohCatalogSnapshot {
  const DohCatalogSnapshot({
    this.version = 1,
    this.updatedAt,
    required this.servers,
    required this.fallbackHosts,
  });

  factory DohCatalogSnapshot.fromJson(Map<String, dynamic> json) {
    final rawServers = json['servers'];
    final servers = <DohServerConfig>[];
    if (rawServers is List) {
      for (final item in rawServers) {
        if (item is Map<String, dynamic>) {
          final parsed = DohServerConfig.fromJson(item);
          if (isPermittedDohUrl(parsed.uri)) {
            servers.add(parsed);
          }
        } else if (item is Map) {
          final parsed = DohServerConfig.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (isPermittedDohUrl(parsed.uri)) {
            servers.add(parsed);
          }
        }
      }
    }

    final rawHosts = json['fallbackHosts'] ?? json['fallback_hosts'];
    final fallbackHosts = <String, List<String>>{};
    if (rawHosts is Map) {
      rawHosts.forEach((key, value) {
        if (key is String && value is List) {
          final cleanHost = key.trim().toLowerCase();
          final ips = <String>[
            for (final ip in value)
              if (ip is String && !isLikelyPoisonedEhIp(ip.trim())) ip.trim(),
          ];
          if (cleanHost.isNotEmpty && ips.isNotEmpty) {
            fallbackHosts[cleanHost] = List<String>.unmodifiable(ips);
          }
        }
      });
    }

    DateTime? updatedAt;
    final rawTime = json['updatedAt'] ?? json['updated_at'];
    if (rawTime is String && rawTime.trim().isNotEmpty) {
      updatedAt = DateTime.tryParse(rawTime.trim());
    } else if (rawTime is int) {
      updatedAt = DateTime.fromMillisecondsSinceEpoch(rawTime, isUtc: true);
    }

    return DohCatalogSnapshot(
      version: json['version'] is int ? json['version'] as int : 1,
      updatedAt: updatedAt,
      servers: List<DohServerConfig>.unmodifiable(servers),
      fallbackHosts: Map<String, List<String>>.unmodifiable(fallbackHosts),
    );
  }

  final int version;
  final DateTime? updatedAt;
  final List<DohServerConfig> servers;
  final Map<String, List<String>> fallbackHosts;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': version,
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
        'servers': servers.map((s) => s.toJson()).toList(),
        'fallbackHosts': fallbackHosts,
      };
}

/// Detected external proxy or TUN/Fake-IP environment that may conflict with
/// in-app SNI bypass.
enum ProxyConflictKind {
  manualProxy,
  systemProxy,
  fakeIpTun,
}

@immutable
class ProxyConflictInfo {
  const ProxyConflictInfo({
    required this.kind,
    this.detail,
  });

  final ProxyConflictKind kind;
  final String? detail;
}

/// Built-in defaults and helper predicates for E-Hentai SNI bypass.
abstract final class SniBypassDefaults {
  static const String autoServerId = 'auto';

  static const List<String> catalogUrls = <String>[
    'https://cdn.jsdelivr.net/gh/boitar/eros_fe@doh-data/doh_list.json',
    'https://fastly.jsdelivr.net/gh/boitar/eros_fe@doh-data/doh_list.json',
    'https://raw.githubusercontent.com/boitar/eros_fe/doh-data/doh_list.json',
  ];

  static const List<String> managedDomainSuffixes = <String>[
    'e-hentai.org',
    'exhentai.org',
    'ehgt.org',
    'ehtracker.org',
  ];

  static const List<String> diagnosticHosts = <String>[
    'e-hentai.org',
    'exhentai.org',
    'api.e-hentai.org',
    'ehgt.org',
  ];

  static const List<DohServerConfig> builtinServers = <DohServerConfig>[
    DohServerConfig(
      id: 'dns-sb',
      name: 'DNS.SB',
      url: 'https://doh.dns.sb/dns-query',
      bootstrapIps: <String>['185.222.222.222', '45.11.45.11'],
      isBuiltin: true,
    ),
    DohServerConfig(
      id: 'cf-1001',
      name: 'Cloudflare (1.0.0.1)',
      url: 'https://1.0.0.1/dns-query',
      bootstrapIps: <String>['1.0.0.1'],
      isBuiltin: true,
    ),
    DohServerConfig(
      id: 'nextdns',
      name: 'NextDNS',
      url: 'https://dns.nextdns.io/dns-query',
      bootstrapIps: <String>['45.90.28.0', '45.90.30.0'],
      isBuiltin: true,
    ),
    DohServerConfig(
      id: 'adguard',
      name: 'AdGuard DNS',
      url: 'https://dns.adguard-dns.com/dns-query',
      bootstrapIps: <String>['94.140.14.14', '94.140.15.15'],
      isBuiltin: true,
    ),
    DohServerConfig(
      id: 'cf-1111',
      name: 'Cloudflare (1.1.1.1)',
      url: 'https://1.1.1.1/dns-query',
      bootstrapIps: <String>['1.1.1.1'],
      isBuiltin: true,
    ),
    DohServerConfig(
      id: 'dnspod',
      name: 'DNSPod',
      url: 'https://doh.pub/resolve',
      bootstrapIps: <String>['1.12.12.12', '120.53.53.53'],
      isBuiltin: true,
    ),
  ];

  /// Fallback IPv4 pool verified against public resolvers when DoH is unreachable.
  static const Map<String, List<String>> builtinFallbackHosts =
      <String, List<String>>{
    'e-hentai.org': <String>['172.66.132.196', '172.66.140.62'],
    'forums.e-hentai.org': <String>['172.66.140.62', '172.66.132.196'],
    'exhentai.org': <String>['104.21.56.202', '172.67.187.219'],
    'ehgt.org': <String>['185.132.132.76', '185.132.132.79', '62.112.8.152'],
    'api.e-hentai.org': <String>[
      '37.48.92.161',
      '212.7.200.104',
      '89.149.222.80',
      '212.7.202.51',
      '95.211.79.44',
      '37.48.81.204',
    ],
    's.exhentai.org': <String>[
      '178.175.132.22',
      '178.175.128.254',
      '178.175.129.254',
    ],
    'ehtracker.org': <String>[
      '212.7.200.122',
      '212.7.202.58',
      '37.48.92.183',
      '95.211.79.57',
    ],
  };

  static bool isManagedDomain(String host) {
    final normalized = host.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    for (final suffix in managedDomainSuffixes) {
      if (normalized == suffix || normalized.endsWith('.$suffix')) {
        return true;
      }
    }
    return false;
  }
}

/// Parses an IPv4 string into its 4 octets, or returns null if invalid.
List<int>? parseIpv4Octets(String ip) {
  final parts = ip.trim().split('.');
  if (parts.length != 4) {
    return null;
  }
  final octets = <int>[];
  for (final part in parts) {
    if (part.isEmpty || part.length > 3) {
      return null;
    }
    final value = int.tryParse(part);
    if (value == null || value < 0 || value > 255) {
      return null;
    }
    if (part.length > 1 && part.startsWith('0')) {
      return null;
    }
    octets.add(value);
  }
  return octets;
}

/// True when [ip] is in RFC 2544 benchmark range `198.18.0.0/15` commonly used
/// by Surge Enhanced Mode, Clash/Mihomo TUN, Shadowrocket, and sing-box Fake-IP.
bool isFakeIpAddress(String ip) {
  final o = parseIpv4Octets(ip);
  if (o == null) {
    return false;
  }
  return o[0] == 198 && (o[1] == 18 || o[1] == 19);
}

/// True when [ip] is a valid routable public IPv4 address (excludes private,
/// loopback, link-local, CGNAT, Fake-IP, multicast, and reserved ranges).
bool isValidPublicIpv4(String ip) {
  final o = parseIpv4Octets(ip);
  if (o == null) {
    return false;
  }
  final a = o[0];
  final b = o[1];
  final c = o[2];
  if (a == 0 || a == 10 || a == 127 || a >= 224) {
    return false;
  }
  if (a == 100 && b >= 64 && b <= 127) {
    return false;
  }
  if (a == 169 && b == 254) {
    return false;
  }
  if (a == 172 && b >= 16 && b <= 31) {
    return false;
  }
  if (a == 192 && b == 168) {
    return false;
  }
  if (a == 192 && b == 0 && (c == 0 || c == 2)) {
    return false;
  }
  if (a == 198 && (b == 18 || b == 19)) {
    return false;
  }
  if (a == 198 && b == 51 && c == 100) {
    return false;
  }
  if (a == 203 && b == 0 && c == 113) {
    return false;
  }
  return true;
}

/// Validates whether [uri] is a permitted public HTTPS DoH endpoint (rejects
/// non-HTTPS schemes, non-443 ports, loopback/private/CGNAT/reserved IPv4
/// literals, IPv6 literals, and local hostnames like `localhost` / `*.local`).
bool isPermittedDohUrl(Uri? uri) {
  if (uri == null || uri.scheme.toLowerCase() != 'https') {
    return false;
  }
  if (uri.hasPort && uri.port != 443) {
    return false;
  }
  var host = uri.host.trim().toLowerCase();
  while (host.endsWith('.')) {
    host = host.substring(0, host.length - 1);
  }
  if (host.isEmpty) {
    return false;
  }
  if (host == 'localhost' ||
      host.endsWith('.localhost') ||
      host.endsWith('.local') ||
      host.endsWith('.internal')) {
    return false;
  }
  // Reject IPv6 literals (e.g. ::1, fc00::/7, fe80::/10, ::ffff:127.0.0.1).
  if (host.contains(':')) {
    return false;
  }
  if (parseIpv4Octets(host) != null) {
    return isValidPublicIpv4(host);
  }
  return host.contains('.');
}

/// Well-known GFW DNS poisoning sinkhole / misdirection prefixes frequently
/// returned for E-Hentai / ExHentai by domestic recursive resolvers (e.g.
/// Facebook `66.220.*` / `31.13.*` / `157.240.*`, Twitter `199.59.148-151.*`,
/// Dropbox `162.125.*`, etc.).
bool isLikelyPoisonedEhIp(String ip) {
  if (!isValidPublicIpv4(ip)) {
    return true;
  }
  final o = parseIpv4Octets(ip)!;
  final a = o[0];
  final b = o[1];
  final c = o[2];

  // Facebook / Meta ranges commonly injected as poisoned A records
  if ((a == 31 && b == 13) ||
      (a == 66 && b == 220) ||
      (a == 69 && (b == 63 || b == 171)) ||
      (a == 157 && b == 240) ||
      (a == 173 && b == 252) ||
      (a == 179 && b == 60 && c >= 192 && c <= 195)) {
    return true;
  }

  // Twitter / X ranges commonly injected as poisoned A records
  if ((a == 199 && b == 59 && c >= 148 && c <= 151) ||
      (a == 104 && b == 244 && c >= 40 && c <= 47) ||
      (a == 199 && b == 16 && c >= 156 && c <= 159) ||
      (a == 199 && b == 96 && c == 57)) {
    return true;
  }

  // Classic GFW DNS poisoning sinkhole IPs
  if ((a == 59 && b == 24 && c == 3) ||
      (a == 93 && b == 46 && c == 8) ||
      (a == 243 && b == 185) ||
      (a == 46 && b == 82 && c == 174) ||
      (a == 37 && b == 61 && c == 54) ||
      (a == 8 && b == 7 && c == 198) ||
      (a == 203 && b == 98 && c == 7) ||
      (a == 202 && b == 160 && c == 128) ||
      (a == 159 && b == 106 && c == 121) ||
      (a == 162 && b == 125)) {
    return true;
  }

  return false;
}
