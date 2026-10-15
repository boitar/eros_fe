# Eros-FE
English | [简体中文](https://github.com/erosTeam/eros_fe/blob/master/README_cn.md)

## Introduction

An Unofficial e-hentai app make on flutter

## Standalone action accessibility module

`codex/custom-accessibility` is a complete single commit directly on fixed master
`2fe86b737`, retaining `1.9.2+566`. Traditional gallery, favorite and search views
now expose twenty existing action labels: search, top/jump, group management,
favorite order/chooser, image search/filter, desktop refresh, quick-search actions,
clear text and open gallery link. The labels follow the source's Chinese wording.
Existing callbacks and pointer behavior are retained. The decorative search-field
prefix keeps its appearance and empty callback, but is excluded from semantics
so it does not advertise a search action that performs nothing.

Thirteen full-suite unit/widget tests pass, with zero analyzer errors and no
new diagnostics against master under the same toolchain. A regression first
reproduced the decorative prefix's phantom button, then verified its exclusion.
Component tests verify semantic tap actions and their existing callbacks for
search editing, URL input, desktop refresh and favorite navigation, including
large text and dark theme. Production `lib/main.dart` builds with and without
offline defines. Eight native checks pass across light/default and
dark/accessibility-medium on isolated iPhone 18 Pro and iPad Pro 11-inch (M5),
highest available iOS 27.0 (24A434). They open real group management, jump and
search routes, check labels in portrait/landscape, clear entered text, and
verify URL input exposes the matching action instead of quick-search addition.

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
bash benchmark/accessibility_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" accessibility
```

Use isolated iPhone/iPad installations, and test light/default and
dark/accessibility-medium. The debug-only fixture configures the production
entry with neutral local HTTP responses and no logged-in account; the harness
reads actual Flutter/native semantics and invokes existing controls. Evidence
stays outside Git. No glass, enhanced haptics or other custom business module
is required. The Chinese source labels are not new translations for other
locales. XCTest does not certify VoiceOver spoken output or physical-device
focus gestures. Image-search/OCR, real account operations, Release, LiveContainer
and untested platforms remain outside acceptance. Existing master large-type
rail/card layout limitations are unchanged. `Debug-SimulatorUI` omits MLKit and
legacy archive-downloader registration. This iteration creates no IPA.

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
