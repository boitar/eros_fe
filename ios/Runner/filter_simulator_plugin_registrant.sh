#!/bin/sh

# Flutter regenerates GeneratedPluginRegistrant.m during every build. The
# Google MLKit pods currently contain device-only objects, so the dedicated
# simulator UI configuration must omit only their registration while keeping
# every other Flutter plugin and the real app navigation intact.

set -eu

registrant_path="${1:?missing GeneratedPluginRegistrant.m path}"

if [ ! -f "$registrant_path" ]; then
  exit 0
fi

# The build phase is intentionally always out of date. This guard makes the
# script safe if Xcode invokes it more than once for the same generated file.
if grep -q 'EROS_SIMULATOR_UI_TEST' "$registrant_path"; then
  exit 0
fi

temporary_path="${registrant_path}.simulator-ui.tmp"

awk '
  BEGIN {
    import_guard_open = 0
    close_import_guard = 0
    registration_guard_open = 0
  }

  # Keep the generated MLKit imports available to normal device and release
  # builds, but hide them from the simulator-only compile unit.
  /^#if __has_include\(<google_mlkit_barcode_scanning\// {
    print "#if !defined(EROS_SIMULATOR_UI_TEST)"
    import_guard_open = 1
  }

  # The closing #endif immediately following the language-id import closes
  # the generated block; add our outer guard after it.
  import_guard_open && ($0 ~ /^@import google_mlkit_language_id;$/) {
    close_import_guard = 1
  }

  # Put one guard around all three MLKit registrations.
  /^  \[GoogleMlKitBarcodeScanningPlugin registerWithRegistrar:/ {
    print "#if !defined(EROS_SIMULATOR_UI_TEST)"
    registration_guard_open = 1
  }

  {
    print $0

    if (close_import_guard && ($0 ~ /^#endif$/)) {
      print "#endif // EROS_SIMULATOR_UI_TEST"
      import_guard_open = 0
      close_import_guard = 0
    }

    if (registration_guard_open && ($0 ~ /GoogleMlKitLanguageIdPlugin registerWithRegistrar:/)) {
      print "#endif // EROS_SIMULATOR_UI_TEST"
      registration_guard_open = 0
    }
  }
' "$registrant_path" > "$temporary_path"

mv "$temporary_path" "$registrant_path"
