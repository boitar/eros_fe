#!/usr/bin/env python3
"""Resolve CI build version and release metadata from Git refs and pubspec.yaml.

For `v*` tag releases (both stable and nightly/pre-release), derives Flutter
`--build-name`, `--build-number`, and artifact version directly from the Git tag
plus a monotonic build-number offset, eliminating the need to edit pubspec.yaml
in Git for nightly or tag releases.
"""

from __future__ import annotations

import datetime as dt
import os
import pathlib
import re
import sys
from dataclasses import dataclass

try:
    from zoneinfo import ZoneInfo
except ImportError:  # pragma: no cover
    ZoneInfo = None  # type: ignore[assignment]

DEFAULT_BUILD_NUMBER_OFFSET = 550
MAX_WIN32_VERSION_PART = 65535

PUBSPEC_VERSION_RE = re.compile(r"^\s*version:\s*([^\s#]+)", re.MULTILINE)
SEMVER_CORE_RE = re.compile(r"^([0-9]+\.[0-9]+\.[0-9]+)(?:-[0-9A-Za-z.-]+)?(?:\+([0-9]+))?$")
TAG_SEMVER_RE = re.compile(r"^v([0-9]+\.[0-9]+\.[0-9]+)(-[0-9A-Za-z.-]+)?(?:\+([0-9]+))?$")
PRERELEASE_KEYWORDS = ("nightly", "pre", "beta", "alpha", "rc")


@dataclass(frozen=True)
class ReleaseMetadata:
    build_name: str
    build_number: int
    artifact_version: str
    pubspec_version: str
    is_tag_release: bool
    is_prerelease: bool
    android_only_arm64: bool
    build_date: str
    short_sha: str

    def to_output_dict(self) -> dict[str, str]:
        return {
            "build_name": self.build_name,
            "build_number": str(self.build_number),
            "artifact_version": self.artifact_version,
            "pubspec_version": self.pubspec_version,
            "is_tag_release": "true" if self.is_tag_release else "false",
            "is_prerelease": "true" if self.is_prerelease else "false",
            "android_only_arm64": "true" if self.android_only_arm64 else "false",
            "build_date": self.build_date,
            "short_sha": self.short_sha,
        }


def parse_pubspec_version(pubspec_text: str) -> tuple[str, int, str]:
    match = PUBSPEC_VERSION_RE.search(pubspec_text)
    if not match:
        raise ValueError("Failed to find `version:` in pubspec.yaml")
    raw_version = match.group(1).strip()
    parsed = SEMVER_CORE_RE.match(raw_version)
    if not parsed:
        raise ValueError(f"Unsupported pubspec.yaml version format: {raw_version!r}")
    build_name = parsed.group(1)
    build_number = int(parsed.group(2)) if parsed.group(2) is not None else 1
    _validate_version_parts(build_name, build_number)
    return build_name, build_number, raw_version


def _validate_version_parts(build_name: str, build_number: int) -> None:
    parts = build_name.split(".")
    if len(parts) != 3 or not all(p.isdigit() for p in parts):
        raise ValueError(f"build_name must be MAJOR.MINOR.PATCH, got {build_name!r}")
    for part in parts:
        val = int(part)
        if val < 0 or val > MAX_WIN32_VERSION_PART:
            raise ValueError(
                f"build_name component {val} out of range 0..{MAX_WIN32_VERSION_PART}"
            )
    if build_number < 1 or build_number > MAX_WIN32_VERSION_PART:
        raise ValueError(
            f"build_number {build_number} out of range 1..{MAX_WIN32_VERSION_PART}"
        )


def _shanghai_date(now: dt.datetime | None = None) -> str:
    if ZoneInfo is not None:
        try:
            tz = ZoneInfo("Asia/Shanghai")
        except Exception:
            tz = dt.timezone(dt.timedelta(hours=8))
    else:  # pragma: no cover
        tz = dt.timezone(dt.timedelta(hours=8))
    current = now.astimezone(tz) if now is not None else dt.datetime.now(tz)
    return current.strftime("%Y%m%d")


def resolve_metadata(
    *,
    pubspec_text: str,
    github_ref: str,
    github_ref_name: str,
    github_run_number: int,
    github_sha: str,
    android_all_abis: bool = False,
    build_number_offset: int = DEFAULT_BUILD_NUMBER_OFFSET,
    now: dt.datetime | None = None,
) -> ReleaseMetadata:
    if github_run_number < 0:
        raise ValueError(f"github_run_number must be non-negative, got {github_run_number}")
    if build_number_offset < 0:
        raise ValueError(f"build_number_offset must be non-negative, got {build_number_offset}")

    pubspec_name, pubspec_build, pubspec_raw = parse_pubspec_version(pubspec_text)
    is_tag_release = github_ref.startswith("refs/tags/v")

    if is_tag_release:
        tag_name = github_ref_name or github_ref.removeprefix("refs/tags/")
        tag_lower = tag_name.lower()
        tag_match = TAG_SEMVER_RE.match(tag_name)

        if tag_match:
            build_name = tag_match.group(1)
            prerelease_suffix = tag_match.group(2) or ""
            explicit_build = tag_match.group(3)
            if explicit_build is not None:
                build_number = int(explicit_build)
            else:
                build_number = max(pubspec_build, build_number_offset + github_run_number)
            artifact_version = f"{build_name}{prerelease_suffix}+{build_number}"
            is_prerelease = bool(prerelease_suffix) or any(
                token in tag_lower for token in PRERELEASE_KEYWORDS
            )
        else:
            build_name = pubspec_name
            build_number = max(pubspec_build, build_number_offset + github_run_number)
            artifact_version = f"{build_name}+{build_number}"
            is_prerelease = any(token in tag_lower for token in PRERELEASE_KEYWORDS)
    else:
        build_name = pubspec_name
        build_number = pubspec_build
        artifact_version = f"{pubspec_name}+{pubspec_build}"
        is_prerelease = False

    _validate_version_parts(build_name, build_number)
    android_only_arm64 = not (is_tag_release or android_all_abis)

    return ReleaseMetadata(
        build_name=build_name,
        build_number=build_number,
        artifact_version=artifact_version,
        pubspec_version=pubspec_raw,
        is_tag_release=is_tag_release,
        is_prerelease=is_prerelease,
        android_only_arm64=android_only_arm64,
        build_date=_shanghai_date(now),
        short_sha=github_sha[:9],
    )


def write_github_outputs(outputs: dict[str, str], output_path: pathlib.Path) -> None:
    lines: list[str] = []
    for key, value in outputs.items():
        if "\n" in value or "\r" in value:
            raise ValueError(f"Output value for {key!r} contains newline characters")
        lines.append(f"{key}={value}\n")
    with output_path.open("a", encoding="utf-8") as fh:
        fh.writelines(lines)


def main() -> int:
    pubspec_path = pathlib.Path(os.environ.get("PUBSPEC_PATH", "pubspec.yaml"))
    pubspec_text = pubspec_path.read_text(encoding="utf-8")

    github_ref = os.environ.get("GITHUB_REF", "")
    github_ref_name = os.environ.get("GITHUB_REF_NAME", "")
    run_number_raw = os.environ.get("GITHUB_RUN_NUMBER", "0").strip() or "0"
    offset_raw = os.environ.get(
        "BUILD_NUMBER_OFFSET", str(DEFAULT_BUILD_NUMBER_OFFSET)
    ).strip() or str(DEFAULT_BUILD_NUMBER_OFFSET)
    github_sha = os.environ.get("GITHUB_SHA", "")
    android_all_abis = os.environ.get("INPUT_ANDROID_ALL_ABIS", "false").lower() == "true"

    meta = resolve_metadata(
        pubspec_text=pubspec_text,
        github_ref=github_ref,
        github_ref_name=github_ref_name,
        github_run_number=int(run_number_raw),
        github_sha=github_sha,
        android_all_abis=android_all_abis,
        build_number_offset=int(offset_raw),
    )

    outputs = meta.to_output_dict()
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        write_github_outputs(outputs, pathlib.Path(github_output))

    print(
        f"Resolved metadata | artifact_version={meta.artifact_version} "
        f"| build_name={meta.build_name} | build_number={meta.build_number} "
        f"| pubspec={meta.pubspec_version} | tag_release={outputs['is_tag_release']} "
        f"| prerelease={outputs['is_prerelease']} "
        f"| android_only_arm64={outputs['android_only_arm64']} "
        f"| build_date={meta.build_date} | sha={meta.short_sha}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
