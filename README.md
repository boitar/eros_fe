# Eros-FE
English | [简体中文](https://github.com/erosTeam/eros_fe/blob/master/README_cn.md)

## Introduction

An Unofficial e-hentai app make on flutter

## Standalone downloads module

This local `codex/custom-downloads` branch is rebuilt directly from fixed
`master` `2fe86b737`, retaining version `1.9.2+566`. It includes gallery download
recovery, resumable transfers, queue/terminal-state propagation, cover fallback
and traditional download cards. Other custom business branches are not required.

### Resume and restore downloads

Pause and continue gallery tasks from Downloads. Interrupted HTTP transfers keep
`.part` metadata, validate Range/If-Range responses and publish final files only
after a complete transfer. Changing concurrency waits for the old queue to stop.
A completed file and its asynchronous completion write finish before success is
reported; cancelled or superseded workers cannot publish late completion.

When a download folder is moved away, records remain intact and the list shows
“Files temporarily unavailable”. Move the folder back and use Continue/Recheck.
Existing final files are reclaimed before scheduling, and partial restoration
queues only missing images. Explicit redownload remains a separate action.

### Build and verify independently

Verified toolchain: Flutter 3.47.1 and Xcode 27.0; minimum Flutter is 3.41.
All iOS configurations use `cn.honjow.fehv`. The scene lifecycle, ARM64 Simulator
configuration, test SDK and deployment lockfiles are included in this branch.
Prepare the public empty config; personal encrypted configuration is not added:

```sh
cp lib/config/config.dart.sample lib/config/config.dart
analysis_before="$(mktemp)"
cp analysis_options.yaml "$analysis_before"
flutter pub get --enforce-lockfile
cp "$analysis_before" analysis_options.yaml
dart analyze --format=machine
flutter test --no-pub
```

Current validation: 42 unit/widget tests pass, including local HTTP Range
scenarios, final-file protection, cancellation/replacement callbacks, awaited
completion writes, restored queues, cover fallback and traditional cards in
both themes, portrait/landscape and 1.6x text. The recovery suite includes 15
filesystem scenarios. Static analysis reports zero errors and no new diagnostics
relative to the same adapted master baseline; inherited warnings/infos remain.

Four production `lib/main.dart` XCTest runs pass on isolated iPhone 18 Pro and
iPad Pro 11-inch (M5), iOS 27.0 (24A434), with light/default text and dark/OS
accessibility-medium text. Each checks download restoration, missing-file state,
rotation, restart and opening an existing local file in the production reader.
Both device types also pass the 15 recovery scenarios using real Isar and the
filesystem in isolated temporary directories.

Install CocoaPods and XcodeGen, boot an isolated iOS 27 Simulator, and keep the
output directory outside the checkout. Each run name must be unique:

```sh
bash benchmark/downloads_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" download-light
xcrun simctl ui "$DEVICE_UUID" appearance dark
xcrun simctl ui "$DEVICE_UUID" content_size accessibility-medium
bash benchmark/downloads_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" download-dark-large
bash benchmark/downloads_ui_tests/run-recovery.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" recovery
```

`run-native.sh` builds the production entry with debug-only offline fixtures;
all unknown requests and mutations are blocked. The recovery executable uses a
new temporary database and directories, never user download records. Its JSON
result reports the 15 actual Isar/filesystem scenarios separately from UI tests.
Repeat on both device types. An ordinary production-entry build without offline
defines is also checked for independent compilation.

`Debug-SimulatorUI` omits MLKit and the legacy archive-downloader registration.
These results cover the Dio gallery download implementation; they do not certify
OCR, legacy archive downloads, Android SAF devices, physical-device behavior,
LiveContainer, Release or other untested platforms. The upstream category bar's
large-text overflow and fixed-height waterfall tag clipping remain inherited UI
limitations. No IPA is produced by this reconstruction.

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
