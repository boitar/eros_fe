# Eros-FE
English | [简体中文](https://github.com/erosTeam/eros_fe/blob/master/README_cn.md)

## Introduction

An Unofficial e-hentai app make on flutter

## Standalone sharing module

`codex/custom-sharing` is rebuilt directly from fixed master `2fe86b737` and
retains version `1.9.2+566`. Gallery links, reader images, torrents, quick-search
exports, downloaded ZIP/EPUB files, app-profile exports and log exports use one sharing service. iOS and
iPadOS present UIKit activity controllers through this branch's own native
plugin; other platforms keep the existing share_plus fallback.

The service waits for Flutter modal dismissal, uses a live native presenter and
a non-empty window-coordinate popover anchor, and rejects overlapping requests.
Cancellation releases the guard. Native failures report an error; text/link
requests can fall back to copying the supplied text. Personal user information
is excluded from app-profile exports by the existing export implementation.

### Independent validation

The current candidate passes 23 unit/widget tests for text/URI metadata, image
and file paths, invalid anchors, concurrent requests, cancellation, failure
fallback, detached contexts, modal dismissal, complete archive output, and
progress success/failure/cancellation. iOS ZIP/EPUB exports use application
temporary storage when Android external cache is unavailable, await archive
writes, and close progress safely on failure or cancellation. Full analysis reports zero
errors and no new diagnostics against the adapted master baseline. Production
`lib/main.dart` ARM64 Simulator builds pass with and without offline defines.
All 16 production-entry XCTest checks pass on isolated iPhone 18 Pro and iPad
Pro 11-inch (M5), iOS 27.0 (24A434), in light/default and dark/accessibility-medium
profiles. Native checks cover link cancellation/reopen, profile files, reader
images and ZIP/EPUB export. Both device types produce archives whose entries and
CRCs are verified. One iPad system accessibility snapshot timed out; the same
entry passed after restarting the isolated simulator, with the failure retained.

Use Flutter 3.47.1, Xcode 27.0, CocoaPods and XcodeGen. Minimum Flutter is 3.41;
iOS configurations use `cn.honjow.fehv`. Prepare the public empty config and
preserve the analyzer options while Flutter resolves packages:

```sh
cp lib/config/config.dart.sample lib/config/config.dart
analysis_before="$(mktemp)"
cp analysis_options.yaml "$analysis_before"
flutter pub get --enforce-lockfile
cp "$analysis_before" analysis_options.yaml
dart analyze --format=machine
flutter test --no-pub
bash benchmark/sharing_ui_tests/run-native.sh \
  "$DEVICE_UUID" "$OUTPUT_DIRECTORY" sharing-light
```

Use isolated iPhone and iPad instances, repeat in dark appearance with OS
accessibility-medium text, and choose a unique run name outside the checkout.
The native harness starts production routes in fresh processes and exercises
gallery-link sharing, cancellation/reopen, a profile file export, and local
reader image sharing after closing its Flutter sheet, plus ZIP/EPUB exports. It cancels system shares
without sending anything. Debug-only fixtures use neutral local files and an
empty account; unknown HTTP requests and mutations are blocked.

`Debug-SimulatorUI` excludes MLKit and legacy archive-downloader registration.
The legacy debug download-task metadata writer is unimplemented in both master
and the source snapshot; only its sharing call is routed here, and that writer
is not accepted as a working export. Physical devices, recipient apps, successful external sends, LiveContainer,
Release, OCR and other platforms are unverified. No IPA or remote publication
is produced by this reconstruction.

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
