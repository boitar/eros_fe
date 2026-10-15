# Eros-FE
English | [简体中文](https://github.com/erosTeam/eros_fe/blob/master/README_cn.md)

## Introduction

An Unofficial e-hentai app make on flutter

## Independent avatar module

`codex/custom-avatar` is directly based on fixed master `2fe86b737`, retaining
`1.9.2+566`. In Settings > E·H > Upload avatar, select Album, Files or Image URL,
then choose forum upload or local use. This standalone module keeps traditional
dialogs. Files opens the system document picker; Album opens the photo picker.
JPEG, PNG, GIF and WebP must decode successfully and be between 1 byte and 9 MB.
Local avatars use unique persistent account-owned copies, with preview and restart
restoration, including recovery after iOS data-container relocation on update. HTTP(S) image URLs cannot embed credentials, and image downloads do
not receive forum cookies. Account changes and late results cannot overwrite the
current avatar. Avatar metadata updates preserve favorite caches and newer folder
metadata.

Forum upload uses the authenticated session and actual form, and reports success
only for a confirmed response. A Cloudflare challenge opens the in-app forum;
complete verification and await cookie synchronization before one retry. Cancelled
or incomplete verification does not retry. Real forum uploads and live Cloudflare
are not accepted here. Local HTTP tests cover authentication, multipart uploads,
empty/error/403 responses, verification retries and account races.

Use Flutter 3.47.1, Xcode 27.0 and Bundle ID `cn.honjow.fehv`:

```sh
cp lib/config/config.dart.sample lib/config/config.dart
analysis_before="$(mktemp)"
cp analysis_options.yaml "$analysis_before"
flutter pub get --enforce-lockfile
cp "$analysis_before" analysis_options.yaml
dart analyze --format=machine
flutter test --no-pub --concurrency=1
bash benchmark/avatar_ui_tests/run-native.sh "$DEVICE_UUID" "$OUTPUT_DIRECTORY" avatar
```

All 41 tests passed with zero analyzer errors or new diagnostics against the
adapted master baseline. Production `lib/main.dart` ARM64 Debug-SimulatorUI builds
passed with and without offline definitions. Native acceptance uses the highest
installed available iOS 27.0 (24A434), isolated iPhone 18 Pro and iPad Pro 11-inch
(M5), light/default and dark/accessibility-medium profiles, rotation and restart.
All 16 native checks passed: URL/album/actual document selection, invalid input,
cancellation, local preview, rotation, process restart and avatar path recovery
after repeated installation.

Debug-only neutral fixtures require an isolated account. Before running the native
script, boot a fresh isolated device on the highest available runtime; the script
imports a neutral image and installs the app. Keep logs, screenshots and results
outside the checkout. Debug-SimulatorUI omits MLKit and legacy archive-downloader
registration. Physical devices, Release, LiveContainer, OCR, legacy archive
downloads and untested platforms are outside acceptance. No IPA or remote
publication is produced.

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
