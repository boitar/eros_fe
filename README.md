# Eros-FE
English | [简体中文](https://github.com/erosTeam/eros_fe/blob/master/README_cn.md)

## Introduction

An Unofficial e-hentai app make on flutter

## Standalone visible-group index module

`codex/custom-group-index` has one complete commit directly on fixed master
`2fe86b737`, retaining `1.9.2+566`. It maps page indices through visible groups,
keeps the current UUID when profiles are reordered, chooses a visible neighbor
when the current group is hidden or deleted, clamps saved indices, and shows
the existing empty fallback when no visible groups remain. The traditional
group rail uses the same visible list as its pages. Keep using the rail's group
management button to reorder/delete; hidden flags in imported profiles are
respected. The last visible index is restored at startup.

Eighteen full-suite unit/widget tests pass, with zero analyzer errors and no
new diagnostics against master under the same toolchain. The native matrix
also exposed blank content after deleting a selected final page: recreating
its viewport could restore an obsolete numeric page. A stable PageView now
retains its UUID-keyed subpages, and the real neighboring content is checked.
Production `lib/main.dart` builds with and without offline defines. Twelve
native checks pass on isolated iPhone 18 Pro and iPad Pro 11-inch (M5), highest
available iOS 27.0 (24A434): four light/default and dark/accessibility-medium
cold/rotation checks, plus each device's reorder/current deletion, fresh-process
selection restoration, all-hidden fallback and fallback restoration.

### Build and verify

Use Flutter 3.47.1, Xcode 27.0 and bundle identifier `cn.honjow.fehv` (minimum
Flutter 3.41). Prepare the upstream public empty configuration:

```sh
cp lib/config/config.dart.sample lib/config/config.dart
analysis_before="$(mktemp)"
cp analysis_options.yaml "$analysis_before"
flutter pub get --enforce-lockfile
cp "$analysis_before" analysis_options.yaml
dart analyze --format=machine
flutter test --no-pub
bash benchmark/group_index_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" group-index
```

Use fresh isolated installations. The production-entry fixture seeds neutral
A/B/C/D profiles once, hides B, and starts at visible C; later launches restore
actual edits from Hive instead of reseeding. Native checks compare current UUID
with real profile-specific gallery titles, not metadata alone. Outputs remain
outside Git. Reorder tests use a slow drag and hold for the existing animation.

Master's traditional LinkScrollBar still measures unscaled text: accessibility
text can overflow and make rightmost label taps ineffective. Default-size label
clicks pass; large-type mapping is verified through the existing horizontal
PageView gesture. Narrow iPad fixed-height cards retain 90px bottom overflow and
tag clipping; these are recorded visual limitations, not visual acceptance.
`Debug-SimulatorUI` omits MLKit/legacy archive-downloader registration. Real cloud
sync, physical devices, Release, LiveContainer, OCR and other platforms are not
accepted by these offline tests. No glass, enhanced haptics or other custom
business module is required. This iteration creates no IPA.

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
