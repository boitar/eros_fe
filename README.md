# Eros-FE
English | [简体中文](https://github.com/erosTeam/eros_fe/blob/master/README_cn.md)

## Introduction

An Unofficial e-hentai app make on flutter

## Independent haptics module

`codex/custom-haptics` is one complete commit directly on fixed master
`2fe86b737`, retaining `1.9.2+566`. Settings > Advanced > Vibration controls
application feedback. Refresh prepares each pull cycle and emits bounded progress
ticks; buttons, reading actions, download transitions and favorite/rating results
use feedback. This standalone version keeps the traditional interface.

All six iOS feedback styles plus prepare/tick use the single-purpose
`eros/haptics` bridge, with a reply for every request. Selection uses Flutter.
The disabled switch skips enhanced calls and capability queries; unsupported
desktop platforms and missing/error plugins safely fall back. Android timing and
capability fallback are preserved, without Android hardware acceptance.

Use Flutter 3.47.1, Xcode 27.0 and Bundle ID `cn.honjow.fehv`:

```sh
cp lib/config/config.dart.sample lib/config/config.dart
analysis_before="$(mktemp)"
cp analysis_options.yaml "$analysis_before"
flutter pub get --enforce-lockfile
cp "$analysis_before" analysis_options.yaml
dart analyze --format=machine
flutter test --no-pub --concurrency=1
bash benchmark/haptics_ui_tests/run-native.sh "$DEVICE_UUID" "$OUTPUT_DIRECTORY" haptics
```

All 25 tests passed, with zero analyzer errors or new diagnostics against the
adapted master baseline. Production `lib/main.dart` ARM64 Debug-SimulatorUI builds
passed with and without offline definitions. On the highest installed available
iOS 27.0 (24A434), isolated iPhone 18 Pro and iPad Pro 11-inch (M5) passed 12 native
checks across light/default and dark/accessibility-medium profiles: actual bridge
counters, two real pulls, switch disable, disabled restart, re-enable and rotation.
Counters describe accepted calls, not physical vibration. Flutter's inherited
refresh armed mediumImpact is separate from the enhanced application switch;
this module does not claim to control that SDK feedback.

Debug-only neutral offline fixtures require an isolated empty account. Keep logs,
screenshots and results outside the checkout. Debug-SimulatorUI omits MLKit and
the legacy archive-downloader registration. Physical haptic strength, Release,
LiveContainer, OCR, legacy archive downloads and untested platforms are outside
acceptance. No IPA or remote publication is produced. Master's large-text rail,
fixed ordinary cards and waterfall tag clipping remain inherited limitations.

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
