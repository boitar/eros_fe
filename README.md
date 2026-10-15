# Eros-FE
English | [简体中文](https://github.com/erosTeam/eros_fe/blob/master/README_cn.md)

## Introduction

An Unofficial e-hentai app make on flutter

## Standalone favorites module

This local `codex/custom-favorites` branch is rebuilt directly from fixed
`master` `2fe86b737`, retaining version `1.9.2+566`. It includes favorite badge
parsing, account-scoped state shared by lists and details, server confirmation,
cache invalidation and note-edit protection. It uses the traditional favorite
forms and does not require another custom business branch.

Open Change Favorites from a gallery card or the detail page. The dialog opens
while the existing server note loads; typing takes precedence over a late note
response. Saving updates the colored heart only after a fresh server read
confirms the category. Failed confirmation retains the previous state. Switching
accounts clears previous favorite metadata, and fresh current-account state is
applied to already mounted cards and details. Local favorites remain on device.
The title long-press retains the existing list/picker form preference.

### Build and verify independently

Verified toolchain: Flutter 3.47.1, Xcode 27.0; minimum Flutter is 3.41.
All iOS configurations use `cn.honjow.fehv`. This branch includes the minimal
scene lifecycle and ARM64 Simulator configuration, dependency lockfiles and test
SDK. Use the public empty template before building:

```sh
cp lib/config/config.dart.sample lib/config/config.dart
analysis_before="$(mktemp)"
cp analysis_options.yaml "$analysis_before"
flutter pub get --enforce-lockfile
cp "$analysis_before" analysis_options.yaml
dart analyze --format=machine
flutter test --no-pub
```

Current validation: all 121 unit/widget tests pass. Static analysis reports zero
errors and no new diagnostics relative to the same adapted master baseline.
Unit/widget coverage includes
all ten categories, missing/malformed badges, request races, account isolation,
confirmation failures, note loading versus typing, traditional list/picker
forms, and mounted card/detail updates after account changes.

Install CocoaPods and XcodeGen, boot an isolated Simulator, and use a unique run
name with an output directory outside the checkout:

```sh
bash benchmark/favorites_ui_tests/run-native.sh   "$DEVICE_UUID" "$OUTPUT_DIRECTORY" favorites-light
xcrun simctl ui "$DEVICE_UUID" appearance dark
xcrun simctl ui "$DEVICE_UUID" content_size accessibility-medium
bash benchmark/favorites_ui_tests/run-native.sh   "$DEVICE_UUID" "$OUTPUT_DIRECTORY" favorites-dark-large
```

Repeat on iPhone and iPad. The harness builds production `lib/main.dart` with
debug-only offline fixtures and a synthetic account, blocks all mutations and
unknown requests, edits and cancels a real form, changes form styles, restarts
the app in a fresh process and checks persisted style plus landscape layout.
All eight native tests pass across isolated iPhone 18 Pro and iPad Pro 11-inch
(M5), iOS 27.0 (24A434): light/default text and dark/accessibility-medium text.
The two phases have separate launch PIDs. No real account is used. The ordinary
production-entry build without offline defines also passes.

`Debug-SimulatorUI` omits MLKit and legacy archive-downloader registration.
Physical devices, real server writes, LiveContainer, Release, OCR and other
platforms remain unverified. The unchanged category bar and fixed-height traditional card layout retain
large-text limitations. In the narrow iPad pane, ordinary list cards overflow
by 90 pixels with accessibility-medium text; the favorite form remains usable.
These functional checks do not certify all large-text layouts. This reconstruction produces no IPA.

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
