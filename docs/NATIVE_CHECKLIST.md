# Native-completeness checklist

SafeDepot Pro ships its native surface **whole**, so that everything after the
"native-complete" release is a Dart-only Shorebird patch.

## The rule

> A Shorebird patch replaces the Dart AOT snapshot and nothing else.
>
> A new **native plugin**, a new **permission**, a new **asset**, an `ios/`
> or `android/` source change, or a Flutter/plugin version bump requires a
> **new release**, not a patch.

Practical test: if you have to run `flutter clean` for a change to take effect,
a patch will not carry it.

## Plugins present in 2.0.0+3

| Plugin | Purpose | Native? |
|---|---|---|
| `supabase_flutter` | Auth, database, storage, RPC | yes |
| `shorebird_code_push` | OTA patches | yes |
| `flutter_secure_storage` | Session tokens in the keystore | yes |
| `firebase_core`, `firebase_messaging` | Push notifications | yes |
| `flutter_local_notifications` | Notification channels | yes |
| `camera`, `image_picker` | Inspection evidence | yes |
| `geolocator` | GPS stamping | yes |
| `permission_handler` | Runtime permission flows | yes |
| `local_auth` | Biometric app lock | yes |
| `share_plus` | Share exports | yes |
| `url_launcher` | Deep links, email, phone | yes |
| `open_filex` | Open generated PDFs | yes |
| `file_picker` | Import files | yes |
| `pdf`, `printing` | Permit and register PDFs | yes |
| `flutter_map` | Depot heat map (no API key) | yes |
| `lottie` | Illustrations and empty states | yes |
| `signature` | Permit and handover signatures | yes |
| `workmanager` | Offline outbox retry | yes |
| `sqflite` | Durable local outbox | yes |
| `package_info_plus` | Version and build number | yes |
| `path_provider` | File locations | yes |
| `shared_preferences` | Theme preference, flag cache | yes |
| `crypto` | Build-integrity hashing | no (pure Dart) |
| `intl`, `uuid`, `flutter_riverpod`, `go_router`, `meta` | App framework | no (pure Dart) |

`connectivity_plus` was **removed**: it was unused in Dart, and its Linux
transitive `dbus` dependency conflicted with `flutter_local_notifications`.
Offline detection works from network-failure signals instead.

## Permissions declared

| Permission | Why |
|---|---|
| `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE` | Supabase, Shorebird |
| `CAMERA`, `RECORD_AUDIO` | Inspection and incident evidence |
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | GPS stamping |
| `POST_NOTIFICATIONS`, `VIBRATE` | Push and in-app alerts |
| `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC` | Outbox retry |
| `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE` | Export and open PDFs |
| `USE_BIOMETRIC`, `USE_FINGERPRINT` | Biometric lock |

Optional hardware declared non-required so the Play Store does not filter
devices out: camera, location, GPS, touchscreen.

## Other native surface

- **FileProvider** — `androidx.core.content.FileProvider` under
  `${applicationId}.fileprovider`, with `xml/file_paths.xml` covering exports,
  shared PDFs and media.
- **Deep links** — App Links for `https://safedepot.pro` plus the
  `safedepot://` scheme, on `MainActivity`.
- **FCM** — default channel `safedepot_alerts`, default notification icon from
  the launcher mark.
- **url_launcher queries** — `<queries>` block for VIEW/SEND/SENDTO/DIAL, so
  Android 11+ package visibility does not break them.
- **compileSdk 37** and **core library desugaring**, required by
  `permission_handler` and `flutter_local_notifications` respectively.
- **R8 minify + resource shrink** on release, with keep rules only where a
  plugin actually needs them.

## Assets shipped in this release

| Asset | Notes |
|---|---|
| `assets/branding/logo_source.webp` | Owner's 160×160 mark, preserved |
| `assets/branding/icon_master.png` | 1024px LANCZOS master |
| `assets/branding/ic_launcher_foreground.png` | Adaptive foreground |
| `assets/branding/ic_launcher_background.png` | Adaptive background |
| `assets/branding/ic_launcher_legacy.png` | Pre-8 fallback |
| `assets/branding/launch_image.png` | Splash |
| `assets/fonts/PlusJakartaSans-Variable.ttf` | Upright, variable |
| `assets/fonts/PlusJakartaSans-Italic-Variable.ttf` | Italic, variable |
| `assets/flutter_assets/shorebird.yaml` | Shorebird app id |

Adding an asset later also means a new release.

## Updating this checklist

When you add a plugin, permission or asset:

1. Add the plugin with `flutter pub add`.
2. Declare any permission in `AndroidManifest.xml` **now**, not when you first
   use it.
3. Regenerate the splash if the launcher art changed.
4. Add a row to the tables above.
5. Build a new release; never a patch.

<!-- © Flatra Tech Ltd. All rights reserved.
     Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
     Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
     Contact: +2349025975247 -->
