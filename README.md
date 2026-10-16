# Eros-FE
English | [简体中文](https://github.com/erosTeam/eros_fe/blob/master/README_cn.md)

## Introduction

An Unofficial e-hentai app make on flutter

## Independent Liquid Glass module

`codex/custom-liquid-glass-verified` is directly based on fixed master `2fe86b737`, retaining
`1.9.2+566`. Enable iOS Liquid Glass in Settings > Style. Choose the default
expanded two-row rail or compact inline layout; changes apply immediately and
persist. UIKit renders native navigation, category rails and popup surfaces,
with application/system theme synchronization, safe areas, coordinated scroll
collapse and accessibility appearance. Native availability checks select glass
or traditional blur. Disabling the setting or using an unsupported platform keeps
the traditional interface. Horizontal rail browsing does not select categories;
selection and return scrolling target the actual current child page.

This module fixes the traditional-navigation regression introduced by glass
integration. Changing main tabs does not refresh. Reselecting the current tab
returns to the top immediately; another tap within 800ms refreshes and clears the
sequence. Expired taps start a new sequence. Glass retains one-reselection
return-and-refresh for the current gallery, favorites and rankings page. Titles
only scroll to the top; downloads/settings gain no refresh. Main/child category
changes, navigation mode changes and disposal clear pending taps; unmounted
scroll targets safely do nothing, and cached siblings cannot claim navigation.
Restoring favorites synchronizes the saved visible index with its category ID,
including out-of-range values and logged-out local favorites, while retaining
the user's previous valid category.

The source download page layout, adaptive popups, long-press menus and fully
listed favorite folders/note forms are included. Existing download/favorite data
interfaces remain; the standalone module does not require enhanced downloads,
favorite state, group indexing or haptics. Basic feedback uses existing interfaces
with safe fallback. Ordinary cards use intrinsic content height for accessibility
text while preserving the normal-text fixed-height preference.

Flutter 3.47+ is required for the native tab bar's hit-test-based gesture policy,
which avoids stale UIKit selection after page changes. Validation uses Flutter
3.47.1, Xcode 27.0 and Bundle ID `cn.honjow.fehv`:

```sh
cp lib/config/config.dart.sample lib/config/config.dart
analysis_before="$(mktemp)"
cp analysis_options.yaml "$analysis_before"
flutter pub get --enforce-lockfile
cp "$analysis_before" analysis_options.yaml
dart analyze --format=machine
flutter test --no-pub --concurrency=1
bash benchmark/glass_ui_tests/run-native.sh "$DEVICE_UUID" "$OUTPUT_DIRECTORY" glass
```

All 194 tests passed, with zero analyzer errors or new diagnostics against the
same-toolchain master baseline. Production `lib/main.dart` builds with and
without offline definitions passed. On the highest installed iOS 27.0 (24A434),
iPhone 18 Pro (light/default) and iPad Pro 11-inch (M5, dark/accessibility-medium)
passed 10 native cases on the final source: native category selection immediately
after a traditional/glass mode switch, traditional and cached-page navigation,
glass navigation/forms, rotation, theme changes and real process restart.
Tests press native controls at their physical centers and check the actual page,
client request counts, real inner/outer offsets and rendered card geometry.

This verified branch releases a removed traditional rail's controller callback,
so selecting a native category cannot call setState on the disposed rail and
abort the actual page change. Controller replacement preserves the current
binding. Three lifecycle regressions accompany the fix. The earlier branch
`codex/custom-liquid-glass` and its tag remain intact for historical evidence;
this branch is a complete single commit directly on fixed master.

The iPad native bottom bar retains stacked, readable labels in narrow panes.
Landscape controls preserve the window's actual top safe area; cutout docking
is restricted to portrait. Keep logs, screenshots and result bundles outside
the checkout, and use an isolated simulator with neutral offline data.

Debug-only fixtures require an isolated account and block real mutations.
Debug-SimulatorUI omits MLKit and legacy archive-downloader registration.
Physical devices, Release, LiveContainer, OCR, legacy archive downloads and
untested platforms are outside acceptance. No IPA or remote publication is
produced.

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
