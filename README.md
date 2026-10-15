# Eros-FE
English | [简体中文](https://github.com/erosTeam/eros_fe/blob/master/README_cn.md)

## Introduction

An Unofficial e-hentai app make on flutter

## Independent grid tags module

`codex/custom-grid-tags` is directly based on fixed master `2fe86b737`, retaining
`1.9.2+566`. Select Settings > Style > List mode > Grid - Tags, or choose it for a
custom group. Cards at the same column width reserve consistent cover, title,
two-row tag and metadata space. Empty tags, long titles and different cover
ratios do not change their aligned heights. Tags scroll horizontally across two
rows. Existing cover, category, favorite marker, count and action controls remain.
In Custom width, select Grid - Tags and adjust its independent width. The preview
updates immediately and settings persist separately from ordinary grids and
waterfall layouts.

Use Flutter 3.47.1, Xcode 27.0 and Bundle ID `cn.honjow.fehv`:

```sh
cp lib/config/config.dart.sample lib/config/config.dart
analysis_before="$(mktemp)"
cp analysis_options.yaml "$analysis_before"
flutter pub get --enforce-lockfile
cp "$analysis_before" analysis_options.yaml
dart analyze --format=machine
flutter test --no-pub --concurrency=1
bash benchmark/grid_tags_ui_tests/run-native.sh "$DEVICE_UUID" "$OUTPUT_DIRECTORY" grid-tags
```

All 23 tests passed with zero analyzer errors or new diagnostics against adapted
master. Production `lib/main.dart` ARM64 Debug-SimulatorUI builds passed with and
without offline definitions. The highest installed available iOS 27.0
(24A434), isolated iPhone 18 Pro and iPad Pro 11-inch (M5) passed all 12 native
production-entry checks across light/default and dark/accessibility-medium
profiles: aligned cards, landscape, actual mode selection, a real width-slider
change and exact-value restoration after process restart.

Debug-only neutral fixtures require an isolated empty account. Boot a fresh
isolated device on the highest runtime before running the native script. Keep
logs, screenshots and results outside the checkout. This module does not depend
on glass, favorite state, history or enhanced haptics. Debug-SimulatorUI omits
MLKit and legacy archive-downloader registration. Physical devices, Release,
LiveContainer, OCR, legacy archive downloads and untested platforms are outside
acceptance. No IPA or remote publication is produced.
The unchanged master traditional header still overflows by about 22px in the narrow
iPad pane at accessibility-medium. Grid cards, settings and restoration passed.

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
