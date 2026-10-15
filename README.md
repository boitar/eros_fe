# Eros-FE
English | [简体中文](https://github.com/erosTeam/eros_fe/blob/master/README_cn.md)

## Introduction

An Unofficial e-hentai app make on flutter

## Standalone history module

`codex/custom-history` starts directly at fixed master `2fe86b737`, retaining
`1.9.2+566`. It reuses one initialization future, waits for migration and database
loading before publishing history, and serializes local writes and clearing.
Sync waits for initialized local data and pending writes. Gallery-item history
controllers are resolved lazily; other custom business modules are not required.

The standalone version passes 14 full-suite unit/widget tests, with zero analyzer
errors and no new diagnostics against master under the same toolchain. Delayed-storage
regressions reproduced four failures before repair: early clear, early sync,
a new visit overwritten by initialization, and a late write surviving clear.
The regressions now pass. Production `lib/main.dart` builds with and without
offline defines. Eight native checks passed on isolated iPhone 18 Pro and
iPad Pro 11-inch (M5) devices with the highest available iOS 27.0 (24A434),
covering light/default and dark/accessibility-medium cold history, rotation,
clearing, and reading the empty database in a fresh process.

### Build and verify

Use Flutter 3.47.1 and Xcode 27.0, with minimum Flutter 3.41 and bundle identifier
`cn.honjow.fehv`. Prepare the public empty configuration:

```sh
cp lib/config/config.dart.sample lib/config/config.dart
analysis_before="$(mktemp)"
cp analysis_options.yaml "$analysis_before"
flutter pub get --enforce-lockfile
cp "$analysis_before" analysis_options.yaml
dart analyze --format=machine
flutter test --no-pub
bash benchmark/history_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" history
```

Use isolated iPhone and iPad instances for light/default and
dark/accessibility-medium profiles. Run populated-list checks before clearing. The native harness opens production history
as the first configured tab, checks real Isar rows and ordering, rotates, clears
through the existing confirmation dialog, and restarts to read the empty database.
A debug-only readiness identifier comes from completed initialization, so an
unloaded blank frame cannot satisfy the empty-history assertion. The seed marker
prevents a restart from recreating cleared test records. Outputs stay outside Git.

The unchanged master fixed-height history card still overflows by 29 px in the
narrow iPad pane at accessibility-medium text. This data module does not alter
that layout; initialization, ordering, clearing and restart checks still pass.

`Debug-SimulatorUI` omits MLKit and legacy archive-downloader registration.
Real cloud accounts, physical devices, Release, LiveContainer, OCR and other
platforms are not accepted by these offline checks. No IPA is produced.

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
