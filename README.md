# Eros-FE
English | [简体中文](https://github.com/erosTeam/eros_fe/blob/master/README_cn.md)

## Introduction

An Unofficial e-hentai app make on flutter

## Standalone waterfall module

This local `codex/custom-waterfall` branch was rebuilt on 2026-10-14 directly
from `master` `2fe86b737`, with application version `1.9.2+566`. It contains only
waterfall stability work from the boitar fork; other custom modules are not
required. The upstream introduction, features, screenshots and credits remain
below.

### Use the stable waterfall lists

Open Settings > Layout > List mode and select Waterfall or Waterfall - Large.
Invalid/missing cover dimensions use a finite fallback ratio. Large waterfall
cards render at their actual height without frame-separated placeholders.
Pagination appends/prepends to the existing list, and unchanged gallery objects
retain their item controllers across rebuilds.

### Build and verify independently

Use Flutter 3.41 or newer; this reconstruction is verified with Flutter 3.47.1
and Xcode 27.0. Prepare the public empty config template as described in the
upstream compiling section; no personal encrypted configuration is included.
The iOS bundle identifier is `cn.honjow.fehv` in every build configuration.
Required iOS 27 scene lifecycle and ARM64 Simulator compatibility are part of
this branch, not supplied by another business branch.

```sh
cp lib/config/config.dart.sample lib/config/config.dart
analysis_before="$(mktemp)"
cp analysis_options.yaml "$analysis_before"
flutter pub get --enforce-lockfile
# Preserve the baseline exclusions if Flutter auto-migrates this file.
cp "$analysis_before" analysis_options.yaml
dart analyze --format=machine
flutter test --no-pub
```

Current validation: 29 unit/widget tests pass, including actual waterfall card
rendering, invalid cover sizes, append/controller identity, return scrolling,
portrait/landscape, light/dark themes and 1.6x text scaling. Standalone ARM64
`Debug-SimulatorUI` builds pass with the production `lib/main.dart`, both with
and without offline fixture defines. Eight native XCTest executions pass on
iPhone 18 Pro and iPad Pro 11-inch (M5), iOS 27.0 (24A434): two cases on each
device with light/default text and dark/OS accessibility-medium text. They
check settings persistence after restart, both waterfall modes, actual
viewport changes after gestures and restored card rectangles in both
orientations. The analyzer reports zero errors and no new diagnostics compared
with the adapted fixed-master baseline; existing warnings/infos remain.

For native reproduction, install CocoaPods and XcodeGen, prepare the public
config, and boot a new isolated iOS 27 Simulator. Keep logs/results outside the
checkout and choose a unique run name:

```sh
bash benchmark/waterfall_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" waterfall-light
# Repeat after setting the isolated device's appearance and content size:
xcrun simctl ui "$DEVICE_UUID" appearance dark
xcrun simctl ui "$DEVICE_UUID" content_size accessibility-medium
bash benchmark/waterfall_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" waterfall-dark-large
```

The offline adapter serves neutral gallery HTML and tiny covers, rejects
unknown API requests and mutations, and is enabled only by
`EROS_OFFLINE_ACCEPTANCE=true` in debug builds. Test identifiers are also
debug-only; compact waterfall cards intentionally have no visible title.

Known inherited UI limitations: the unchanged master category bar can overflow
under OS large text because its text-width measurement ignores scaling; its
fixed-height waterfall tag rows can also clip enlarged text. Native functional
checks do not claim these existing accessibility/layout issues are fixed, or
that the entire UI meets release acceptance.

`Debug-SimulatorUI` deliberately omits MLKit and the legacy downloader plugin
registrations. It is for isolated UI acceptance only, not full download/OCR or
release-function acceptance. Real accounts, physical-device behavior,
LiveContainer and untested platforms are outside this validation.

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
