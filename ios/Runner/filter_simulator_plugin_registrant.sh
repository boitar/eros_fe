#!/bin/sh

# Flutter regenerates GeneratedPluginRegistrant.m during every build. The
# Google MLKit and flutter_downloader pods are unavailable for this simulator
# architecture, so the dedicated UI configuration omits only their registration
# while keeping the navigation and Liquid Glass platform views intact.

set -eu

registrant_path="${1:?missing GeneratedPluginRegistrant.m path}"

if [ ! -f "$registrant_path" ]; then
  exit 0
fi

# The build phase is intentionally always out of date. This marker makes the
# script safe if Xcode invokes it more than once for the same generated file.
if grep -q 'EROS_SIMULATOR_UI_PLUGIN_FILTER_V2' "$registrant_path"; then
  exit 0
fi

temporary_path="${registrant_path}.simulator-ui.tmp"

awk '
  BEGIN {
    import_guard_open = 0
    close_import_guard = 0
    registration_guard_open = 0
    downloader_import_open = 0
    close_downloader_import = 0
    downloader_registration_open = 0
    previous_line = ""
    print "/* EROS_SIMULATOR_UI_PLUGIN_FILTER_V2 */"
  }

  # The downloader uses background URL sessions and is not needed in the
  # isolated simulator UI configuration. Its plugin binary is device-only.
  /^#if __has_include\(<flutter_downloader\// {
    if (previous_line !~ /^#if !defined\(EROS_SIMULATOR_UI_TEST\)$/) {
      print "#if !defined(EROS_SIMULATOR_UI_TEST)"
      downloader_import_open = 1
    }
  }

  downloader_import_open && ($0 ~ /^@import flutter_downloader;$/) {
    close_downloader_import = 1
  }

  # Keep the generated MLKit imports available to normal device and release
  # builds, but hide them from the simulator-only compile unit.
  /^#if __has_include\(<google_mlkit_barcode_scanning\// {
    if (previous_line !~ /^#if !defined\(EROS_SIMULATOR_UI_TEST\)$/) {
      print "#if !defined(EROS_SIMULATOR_UI_TEST)"
      import_guard_open = 1
    }
  }

  # The closing #endif immediately following the language-id import closes
  # the generated block; add our outer guard after it.
  import_guard_open && ($0 ~ /^@import google_mlkit_language_id;$/) {
    close_import_guard = 1
  }

  # Put one guard around all three MLKit registrations.
  /^  \[GoogleMlKitBarcodeScanningPlugin registerWithRegistrar:/ {
    if (previous_line !~ /^#if !defined\(EROS_SIMULATOR_UI_TEST\)$/) {
      print "#if !defined(EROS_SIMULATOR_UI_TEST)"
      registration_guard_open = 1
    }
  }

  /^  \[FlutterDownloaderPlugin registerWithRegistrar:/ {
    if (previous_line !~ /^#if !defined\(EROS_SIMULATOR_UI_TEST\)$/) {
      print "#if !defined(EROS_SIMULATOR_UI_TEST)"
      downloader_registration_open = 1
    }
  }

  {
    print $0

    if (close_import_guard && ($0 ~ /^#endif$/)) {
      print "#endif // EROS_SIMULATOR_UI_TEST"
      import_guard_open = 0
      close_import_guard = 0
    }

    if (close_downloader_import && ($0 ~ /^#endif$/)) {
      print "#endif // EROS_SIMULATOR_UI_TEST"
      downloader_import_open = 0
      close_downloader_import = 0
    }

    if (registration_guard_open && ($0 ~ /GoogleMlKitLanguageIdPlugin registerWithRegistrar:/)) {
      print "#endif // EROS_SIMULATOR_UI_TEST"
      registration_guard_open = 0
    }

    if (downloader_registration_open && ($0 ~ /FlutterDownloaderPlugin registerWithRegistrar:/)) {
      print "#endif // EROS_SIMULATOR_UI_TEST"
      downloader_registration_open = 0
    }

    previous_line = $0
  }
' "$registrant_path" > "$temporary_path"

mv "$temporary_path" "$registrant_path"
