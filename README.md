# Eros-FE
English | [简体中文](https://github.com/erosTeam/eros_fe/blob/master/README_cn.md)

## Introduction

An Unofficial e-hentai app make on flutter

## Local custom integration

`custom` starts at fixed master `2fe86b737`, retains version `1.9.2+566`, and
currently integrates the following independently deliverable modules:

| Module | Use | Independent branch |
| --- | --- | --- |
| Waterfall stability | Settings > Layout > Waterfall / Waterfall - Large; stable cover dimensions, return scrolling and pagination/controller reuse | `codex/custom-waterfall` |
| Downloads | Pause/continue or restore a moved folder, then recheck existing files before missing images are queued | `codex/custom-downloads` |
| Favorites | Traditional forms, confirmed server results, account isolation and protected note edits | `codex/custom-favorites` |
| Sharing | Native iOS/iPadOS links, images, files and exports with modal/anchor handling | `codex/custom-sharing` |
| History | Shared initialization, serialized local persistence/clear and awaited sync | `codex/custom-history` |
| Visible group index | Stable visible UUID/page mapping, reorder/delete and restart restoration | `codex/custom-group-index` |
| Action accessibility | Labels for existing traditional controls; decorative no-op prefix excluded | `codex/custom-accessibility` |
| Haptics | Native bridge, progressive pulls, application switch and operation feedback | `codex/custom-haptics` |

Each business branch has a single complete commit directly on the same fixed
master. This integration preserves those commit IDs through explicit merges.
The remaining three planned business modules are not integrated yet.

All 243 tests passed on the eight-module integration, with no new analyzer
diagnostics. Production `lib/main.dart` ARM64 Debug-SimulatorUI builds passed with
and without offline definitions. On iPhone 18 Pro and iPad Pro 11-inch (M5),
iOS 27.0 (24A434), twelve native haptics checks passed across light/default and
dark/accessibility-medium profiles, including real pulls, six accepted style
calls, prepare/tick, switch disable, disabled restart, re-enable and rotation.
The independent haptics module passed 25 tests and twelve native checks.
Accessibility labels remain Chinese; its eight integration native checks do not
establish physical VoiceOver speech/focus acceptance.

### Build and verify

Use Flutter 3.47.1 and Xcode 27.0 (minimum Flutter 3.41); iOS uses `cn.honjow.fehv`.
Prepare the upstream public config template, then run:

```sh
cp lib/config/config.dart.sample lib/config/config.dart
analysis_before="$(mktemp)"
cp analysis_options.yaml "$analysis_before"
flutter pub get --enforce-lockfile
cp "$analysis_before" analysis_options.yaml
dart analyze --format=machine
flutter test --no-pub
```

Native reproductions use the production `lib/main.dart` with debug-only neutral
offline data. Boot an isolated iOS 27 Simulator, keep output outside the checkout
and choose unique run names:

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
```

The inherited Flutter refresh armed mediumImpact is separate from the enhanced
application feedback switch. Accepted native counters do not establish physical
vibration or strength.

The module branches' bilingual READMEs describe their own checks and boundaries.
Integration tests and native entry checks are rerun on the merged tree; source
`dev` test counts and packages do not establish this branch's acceptance.

`Debug-SimulatorUI` omits MLKit and the legacy archive-downloader registration.
Physical devices, Android SAF hardware, OCR, legacy archive downloads,
LiveContainer, Release and other untested platforms are outside acceptance.
Master's large-text category-bar overflow and fixed-height waterfall tag clipping
remain inherited UI limitations. Ordinary fixed-height list cards also overflow
in a narrow iPad pane with OS accessibility-medium text; the favorites form is
functional in that profile. This reconstruction produces no IPA and does
not publish branches or tags remotely. The legacy debug download-task metadata
writer remains unimplemented in master and source; it is not a working export.
Master's unscaled traditional group rail can also overflow and miss right-side
label taps at accessibility sizes; default-size taps pass and large-type group
mapping is checked using the existing PageView gesture.
The unchanged history card overflows by 29px in the narrow iPad pane with
accessibility-medium text; history ordering, clear and restart checks still pass.

## 🔍 Translations Wanted 🔍
Please submit a pull request if you want to help with translation.

App Strings: `lib/l10n/{lang}.arb`

## Installation for iOS
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

flutter version is the latest release version \
rename `lib/config/config.dart.sample` to `lib/config/config.dart` \
rename `lib/firebase_options_sample.dart` to `lib/firebase_options.dart`
