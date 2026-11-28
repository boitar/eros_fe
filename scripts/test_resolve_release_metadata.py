#!/usr/bin/env python3
"""Unit tests for scripts/resolve_release_metadata.py."""

from __future__ import annotations

import datetime as dt
import pathlib
import sys
import tempfile
import unittest

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from scripts.resolve_release_metadata import (
    DEFAULT_BUILD_NUMBER_OFFSET,
    parse_pubspec_version,
    resolve_metadata,
    write_github_outputs,
)

SAMPLE_PUBSPEC = """
name: eros_fe
description: An unofficial e-hentai app

publish_to: 'none'
version: 1.11.2+571
"""


class ResolveReleaseMetadataTest(unittest.TestCase):
    def setUp(self) -> None:
        self.fixed_now = dt.datetime(2026, 11, 28, 7, 30, 0, tzinfo=dt.timezone.utc)

    def test_nightly_tag_derives_version_without_touching_pubspec(self) -> None:
        meta = resolve_metadata(
            pubspec_text=SAMPLE_PUBSPEC,
            github_ref="refs/tags/v1.12.0-nightly",
            github_ref_name="v1.12.0-nightly",
            github_run_number=25,
            github_sha="752a82401abcdef123456",
            now=self.fixed_now,
        )
        self.assertEqual(meta.build_name, "1.12.0")
        self.assertEqual(meta.build_number, DEFAULT_BUILD_NUMBER_OFFSET + 25)
        self.assertEqual(meta.artifact_version, "1.12.0-nightly+575")
        self.assertEqual(meta.pubspec_version, "1.11.2+571")
        self.assertTrue(meta.is_tag_release)
        self.assertTrue(meta.is_prerelease)
        self.assertFalse(meta.android_only_arm64)
        self.assertEqual(meta.build_date, "20261128")
        self.assertEqual(meta.short_sha, "752a82401")

    def test_stable_tag_uses_semver_and_monotonic_build_number(self) -> None:
        meta = resolve_metadata(
            pubspec_text=SAMPLE_PUBSPEC,
            github_ref="refs/tags/v1.12.0",
            github_ref_name="v1.12.0",
            github_run_number=30,
            github_sha="abcdef1234567890",
            now=self.fixed_now,
        )
        self.assertEqual(meta.build_name, "1.12.0")
        self.assertEqual(meta.build_number, 580)
        self.assertEqual(meta.artifact_version, "1.12.0+580")
        self.assertTrue(meta.is_tag_release)
        self.assertFalse(meta.is_prerelease)
        self.assertFalse(meta.android_only_arm64)

    def test_stable_tag_respects_higher_pubspec_build_number(self) -> None:
        higher_pubspec = SAMPLE_PUBSPEC.replace("1.11.2+571", "1.12.0+620")
        meta = resolve_metadata(
            pubspec_text=higher_pubspec,
            github_ref="refs/tags/v1.12.0",
            github_ref_name="v1.12.0",
            github_run_number=30,
            github_sha="abcdef1234567890",
            now=self.fixed_now,
        )
        self.assertEqual(meta.build_name, "1.12.0")
        self.assertEqual(meta.build_number, 620)
        self.assertEqual(meta.artifact_version, "1.12.0+620")

    def test_tag_with_explicit_build_number_overrides_auto(self) -> None:
        meta = resolve_metadata(
            pubspec_text=SAMPLE_PUBSPEC,
            github_ref="refs/tags/v1.12.0+700",
            github_ref_name="v1.12.0+700",
            github_run_number=30,
            github_sha="abcdef1234567890",
            now=self.fixed_now,
        )
        self.assertEqual(meta.build_name, "1.12.0")
        self.assertEqual(meta.build_number, 700)
        self.assertEqual(meta.artifact_version, "1.12.0+700")
        self.assertFalse(meta.is_prerelease)

    def test_rc_and_dated_nightly_tags_are_prereleases(self) -> None:
        for tag, expected_artifact in [
            ("v1.12.0-rc.1", "1.12.0-rc.1+580"),
            ("v1.12.0-nightly.20261128", "1.12.0-nightly.20261128+580"),
            ("v1.12.0-dev.1", "1.12.0-dev.1+580"),
        ]:
            meta = resolve_metadata(
                pubspec_text=SAMPLE_PUBSPEC,
                github_ref=f"refs/tags/{tag}",
                github_ref_name=tag,
                github_run_number=30,
                github_sha="abcdef1234567890",
                now=self.fixed_now,
            )
            self.assertEqual(meta.build_name, "1.12.0")
            self.assertEqual(meta.artifact_version, expected_artifact)
            self.assertTrue(meta.is_prerelease)

    def test_branch_push_keeps_pubspec_version_and_arm64_only(self) -> None:
        meta = resolve_metadata(
            pubspec_text=SAMPLE_PUBSPEC,
            github_ref="refs/heads/custom",
            github_ref_name="custom",
            github_run_number=24,
            github_sha="1234567890abcdef",
            android_all_abis=False,
            now=self.fixed_now,
        )
        self.assertEqual(meta.build_name, "1.11.2")
        self.assertEqual(meta.build_number, 571)
        self.assertEqual(meta.artifact_version, "1.11.2+571")
        self.assertFalse(meta.is_tag_release)
        self.assertFalse(meta.is_prerelease)
        self.assertTrue(meta.android_only_arm64)

    def test_workflow_dispatch_all_abis(self) -> None:
        meta = resolve_metadata(
            pubspec_text=SAMPLE_PUBSPEC,
            github_ref="refs/heads/custom",
            github_ref_name="custom",
            github_run_number=24,
            github_sha="1234567890abcdef",
            android_all_abis=True,
            now=self.fixed_now,
        )
        self.assertFalse(meta.is_tag_release)
        self.assertFalse(meta.android_only_arm64)

    def test_invalid_pubspec_or_overflow_build_number_raises(self) -> None:
        with self.assertRaises(ValueError):
            parse_pubspec_version("name: eros_fe\n")
        with self.assertRaises(ValueError):
            resolve_metadata(
                pubspec_text=SAMPLE_PUBSPEC,
                github_ref="refs/tags/v1.12.0+70000",
                github_ref_name="v1.12.0+70000",
                github_run_number=25,
                github_sha="123456789",
                now=self.fixed_now,
            )

    def test_write_github_outputs_rejects_newlines(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            out = pathlib.Path(td) / "github_output"
            write_github_outputs({"build_name": "1.12.0", "build_number": "575"}, out)
            self.assertEqual(
                out.read_text(encoding="utf-8"),
                "build_name=1.12.0\nbuild_number=575\n",
            )
            with self.assertRaises(ValueError):
                write_github_outputs({"bad": "1.0\ninjected=true"}, out)


if __name__ == "__main__":
    unittest.main()
