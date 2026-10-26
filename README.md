# Eros-FE
English | [简体中文](./README_cn.md)

## Introduction

An unofficial E-Hentai app built with Flutter.

## Fork enhancements over master

This fork builds on Eros-FE master and focuses on iOS/iPadOS: native Liquid Glass
navigation, grid tags, and improvements to download recovery, favorites, sharing,
history, avatars, haptics and action accessibility.

`custom` starts at fixed master `2fe86b737`, retains version `1.9.2+566`, and
integrates all eleven independently deliverable modules:

| Module | Use | Independent branch |
| --- | --- | --- |
| Waterfall stability | Settings > Layout > Waterfall / Waterfall - Large; stable cover dimensions, return scrolling and pagination/controller reuse | `codex/custom-waterfall` |
| Downloads | Pause/continue or restore a moved folder, then recheck existing files before missing images are queued | `codex/custom-downloads` |
| Favorites | Traditional/glass forms, confirmed server results, account isolation and protected note edits | `codex/custom-favorites-verified` |
| Sharing | Native iOS/iPadOS links, images, files and exports with modal/anchor handling | `codex/custom-sharing` |
| History | Shared initialization, serialized local persistence/clear and awaited sync | `codex/custom-history` |
| Visible group index | Stable visible UUID/page mapping, reorder/delete and restart restoration | `codex/custom-group-index` |
| Action accessibility | Labels for existing traditional controls; decorative no-op prefix excluded | `codex/custom-accessibility` |
| Haptics | Native bridge, progressive pulls, application switch and operation feedback | `codex/custom-haptics` |
| Avatar | Album/Files/URL, verified upload retry, local preview and container recovery | `codex/custom-avatar` |
| Grid tags | Aligned cards, two-row horizontal tags, independent width and restoration | `codex/custom-grid-tags` |
| Liquid Glass | Settings > Style: native navigation, two-row/inline top bars, popups, safe areas and scroll synchronization; repairs traditional navigation regressions introduced by glass integration | `codex/custom-liquid-glass-verified` |

Each canonical business branch contains one complete commit directly on fixed
master. The original ten ordered non-fast-forward merges are preserved, followed
by an explicit favorites repair merge and the final glass merge. All eleven
canonical independent commit IDs are retained. The canonical module branches,
the integrated `custom` branch and their annotated tags are published in
`boitar/eros_fe`. The former favorites and glass branches and tags are preserved
locally for traceability, not published as current delivery branches; use the
verified branches listed above. For grid tags, the current independent tag is
`2026-10-15-custom-grid-tags-independent-verifier`, not the older
`2026-10-15-custom-grid-tags-independent`.

The integration keeps account/revision guards for favorites and avatars,
download recovery protections, visible group UUID mapping and serialized history
operations while adapting their shared glass surfaces. Account initialization completes
before widgets subscribe to favorite state, including a cold launch with glass restored.

The complete integration passed all 486 tests on 2026-10-16; analysis found zero
errors and zero diagnostics added to the same-toolchain master baseline. Seven
production `lib/main.dart` ARM64 Debug-SimulatorUI variants built successfully, including
builds with and without offline definitions. On the highest installed available
iOS 27.0 (24A434), iPhone 18 Pro and iPad Pro 11-inch (M5) passed 10 navigation/form
checks, 30 glass combinations with favorites, avatars, visible group indexes,
haptics and downloads, and two traditional cold-start settings-before-favorites
checks: 42 native cases in total. Phone uses light/default text and iPad uses
dark/accessibility-medium text. Every combination proves actual native glass
activation; restart phases read persisted application state.

Before publication on 2026-10-17, four additional native smoke checks passed on
iPhone 18 Pro and iPad Pro 11-inch (M5), using the same iOS 27.0 runtime and
source-matched formal builds. They cover a cold launch opening settings before
favorites and native category selection after switching navigation modes on
both devices; they are not a new run of the full 486-test suite.

The complete verified favorites branch passed 121 tests, two formal main builds
and six cold-start/form/restart native cases. Account initialization belongs to
this independently usable module and is carried into custom by the repair merge.
The independent glass module passed 194 tests and 10 native checks on the final
source, including native category selection immediately after a mode switch.
The regression tests cover traditional reselection timing,
cached/current page selection, actual scroll positions, refresh counts, mode
changes, unsupported-platform fallback and disposal. Ordinary gallery cards now
expand for scaled text. Module branches document their own earlier acceptance.

### 2026-10-18: save gallery images to Photos

Version remains `1.9.2+566`. The fix tag is `2026-10-18-gallery-save-cache`;
the `custom` integration tag is `2026-10-18-custom-gallery-save-cache`.

- Long-press and toolbar menus offer "Save current image" and "Save original image".
  Current-image saves reuse local files, temporary files or the viewer's exact cache key,
  requiring no network when cached. Original saves reuse only a confirmed original or
  download through the original-image endpoint; the image preference alone is not proof of quality.
- Menu selection captures the image source before navigation. Duplicate original options
  are omitted when the endpoint is missing or both sources are confirmed identical.
  Downloads isolate image identity and quality, checking status, length and image contents
  before publishing a completed file instead of selecting arbitrary shared temporary files.
- iOS imports encoded files through PhotoKit with add-only authorization, preserving
  supported formats, transparency and animation. Permission, invalid-file, download,
  unsupported-format and write failures remain distinct. Success follows the completed
  import, and concurrent saves are blocked.
- All 511 tests and the final 38 focused tests passed, with no added analysis diagnostics
  against the same-source baseline. On the highest installed available iOS 27.0 (24A434),
  iPhone 18 Pro verified zero-download cached saves, original downloads and reuse,
  denied add-only permission without library writes, and HTML/HTTP error classification.
  Imported PNG, JPEG and GIF files match their source SHA-256 hashes.
- Production `lib/main.dart` Simulator and unsigned Release arm64 builds passed, including
  local IPA package 67 integrity checks. That IPA was delivered locally, not uploaded to
  the repository or GitHub Releases; the version number is unchanged. LiveContainer host
  permissions and in-container saves, plus physical Android devices, still require
  acceptance testing; Simulator results do not substitute for those checks.

### 2026-10-26: favorite form compatibility and confirmed saves

Version remains `1.9.2+566`. The fix tag is `2026-10-26-favorite-form-fix`;
the `custom` integration and release tag is `2026-10-26-custom-favorite-form-fix`.

- Favorite submissions use URL-encoded text forms after anonymous EH/EX controls
  identified administrative HTTP 403 responses to multipart text forms. Archive
  downloads (local and H@H), My Tags, site settings/profile and comments use the
  same verified encoding correction; forum login and file uploads retain their encoding.
- A save updates shared state only after fresh server reads confirm the requested
  category and exact note. Deletion requires an explicit not-favorited result;
  the popup's default category 0 is never accepted as proof of success.
- Each operation sends one POST. Uncertain outcomes use bounded readbacks without
  repeating the write. Login redirects, challenges and HTTP rejections show short
  errors, while account/revision guards prevent stale state updates.
- All 554 Flutter tests passed, with zero analysis errors or warnings. Eight
  traditional/Liquid Glass native cases passed on iPhone 18 Pro and iPad Pro
  11-inch (M5), iOS 27.0 (24A434), covering categories 0/7, note editing/clearing,
  list refresh, process restart, removal and HTTP 403 rejection. Normal-entry
  clean installation, startup and process-survival checks also passed. Before
  publication, four additional cases passed on the highest installed available
  iOS 27.1 (24A94425) / iPhone Duo, covering both styles and restart/rejection.
  The UI driver presses the visible upper card area to avoid the native tab bar.
- The release reuses verified unsigned arm64 IPA package 68, built on 2026-10-23
  from the same application source with the public configuration template and no
  acceptance definitions. Real-account LiveContainer acceptance remains pending;
  anonymous protocol controls and synthetic UI tests do not establish that result.

### Build and verify

Use Flutter 3.47.1 and Xcode 27.0; the minimum Flutter version is 3.47.0 for the
public native gesture policy. The iOS Bundle ID is `cn.honjow.fehv`. In a new
checkout, prepare the upstream public configuration template, then run:

```sh
cp lib/config/config.dart.sample lib/config/config.dart
analysis_before="$(mktemp)"
cp analysis_options.yaml "$analysis_before"
flutter pub get --enforce-lockfile
cp "$analysis_before" analysis_options.yaml
dart analyze --format=machine
flutter test --no-pub
```

Native reproductions use production `lib/main.dart` and debug-only neutral offline
fixtures. Boot an isolated iOS 27 Simulator, keep output outside the checkout and
choose unique run names. Run the verifiers serially:

```sh
mkdir -p "$OUTPUT_DIRECTORY/harness"
bash benchmark/waterfall_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" waterfall
bash benchmark/downloads_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" downloads
bash benchmark/downloads_ui_tests/run-recovery.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" recovery
bash benchmark/favorites_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" favorites
bash benchmark/sharing_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" sharing
bash benchmark/history_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" history
bash benchmark/group_index_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" group-index
bash benchmark/accessibility_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" accessibility
bash benchmark/haptics_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" haptics
bash benchmark/avatar_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" avatar
bash benchmark/grid_tags_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" grid-tags
bash benchmark/glass_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" glass
```

For glass combinations, prefix the favorites, avatar, group-index, haptics or
downloads runner with `EROS_VERIFY_GLASS=1`. This enables glass through real
settings and asserts native navigation without mixing glass seed data into the
business fixture. `EROS_CROSS_GLASS_ACTIVE` in each case log proves activation.
To repeat the additional cold-start regression on a fresh installed favorites
fixture, run `benchmark/favorites_ui_tests/verify-installed.sh` with the device,
external output directory, a unique run name and the fourth argument `bootstrap`;
leave `EROS_VERIFY_GLASS` unset for this traditional entry path.

Real forum uploads and live Cloudflare remain unverified; local HTTP coverage
includes authentication, multipart requests, errors, 403 and verification retry.
Action labels remain Chinese. Simulator semantics do not establish physical
VoiceOver speech/focus. Accepted native haptic calls do not establish physical
vibration or intensity; inherited Flutter refresh feedback remains separate from
the enhanced application switch.

`Debug-SimulatorUI` omits MLKit and legacy archive-downloader registration.
Physical devices, Android SAF hardware, OCR, legacy archive downloads,
LiveContainer, Release and other untested platforms remain outside acceptance.
Master's traditional category header still overflows by about 22px in the narrow
iPad pane at accessibility-medium, and fixed-height waterfall tags retain
clipping limitations. Its unscaled group rail can miss right-side
label taps at accessibility sizes, where mapping was checked by PageView gestures.
The unchanged history card retains a 29px overflow in the narrow iPad pane at
accessibility-medium. The legacy debug download-task metadata writer remains
unimplemented in both master and source.

## 🔍 Translations Wanted 🔍
Please submit a pull request if you want to help with translation.

App Strings: `lib/l10n/{lang}.arb`

## Installation for iOS

This fork publication contains source code, not a fork IPA. The Releases link
below points to upstream builds and does not provide these custom enhancements.

1. Get the ipa file from [Releases](https://github.com/erosTeam/eros_fe/releases/latest).
2. Use some software like [AltStore](https://altstore.io) to install the ipa file on your device. Or [AltStore.json](https://config-feh.vercel.app/AltStore.json)

## Descriptions

The main reference for UI is [E-HentaiViewer](https://github.com/kayanouriko/E-HentaiViewer)

Current Issues:

- List sliding may have a small lag. Not as smooth as native apps
- Does miss some essential features (still under development)

## Thanks

The code and logic of the following projects are used and referenced for development

- [E-HentaiViewer](https://github.com/kayanouriko/E-HentaiViewer)
- [EhViewer](https://github.com/seven332/EhViewer)

EhTagTranslation

- [EhTagTranslation/Database](https://github.com/EhTagTranslation/Database)

Translation
- [KeepSOBP](https://github.com/KeepSOBP) Korean translation
- [pursel](https://github.com/pursel), [Gigas002](https://github.com/Gigas002) -- Russian translation
- [cristal-node](https://github.com/cristal-node) -- Japanese translation

## Screenshot

### Home Page List

<img width="200" src="./screenshot/home.png" > 

### Settings

<img width="200" src="./screenshot/setting.png" >

### Gallery

<img width="200" src="./screenshot/gallery1.png" > <img width="200" src="./screenshot/gallery2.png" > 

### Search

<img width="200" src="./screenshot/search1.png" > <img width="200" src="./screenshot/search2.png" >

### Read

<img width="200" src="./screenshot/read1.png" > <img width="200" src="./screenshot/read2.png" >

## Function

- [x] Popula,Watch,Home,Favorites
- [x] List View,Waterfall View Switch
- [x] Gallery information view
- [x] Gallery Image view
- [x] Automatically turn pages
- [x] eh/ex switch
- [x] Tag search
- [x] Login
- [x] Search
- [x] Search term matching tag
- [x] Advanced search
- [x] Save and share images
- [x] Cache optimization
- [x] Advanced settings
- [x] post comments, vote up ，vote down
- [x] watched and user tag
- [x] Download

## TODO


## Dependency projects/plugins (partial)

- network: [dio](https://pub.dev/packages/dio)
- Status Management: [getx](https://pub.dev/packages/get)
- db: [sqflite](https://pub.dev/packages/sqflite)
- Data Persistence: [shared_preferences](https://pub.dev/packages/shared_preferences)
- intl: [intl](https://pub.dev/packages/intl)
- Image: [cached_network_image](https://pub.dev/packages/cached_network_image)、[extended_image](https://pub.dev/packages/extended_image)

## About compiling

Use the validated Flutter/Xcode versions and configuration steps in
[Build and verify](#build-and-verify), rather than an unspecified latest SDK.
