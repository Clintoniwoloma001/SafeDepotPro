# Releasing SafeDepot Pro

How to cut a Shorebird release, how to patch it, and what cannot be patched.

Verified against the toolchain in this repo: **Shorebird 1.6.124**, **Flutter
3.47.6** (stable), Dart 3.13.5, Android SDK 36.

---

## Contents

1. [Prerequisites](#1-prerequisites)
2. [The release command](#2-the-release-command)
3. [Registering the release build](#3-registering-the-release-build)
4. [The patch workflow](#4-the-patch-workflow)
5. [Versioning](#5-versioning)
6. [What cannot be patched](#6-what-cannot-be-patched)
7. [Symbols: keep them or lose the crash](#7-symbols-keep-them-or-lose-the-crash)
8. [Revoking a build](#8-revoking-a-build)

---

## 1. Prerequisites

Install the CLIs once per machine:

```sh
flutter --version                       # 3.47.6 expected
shorebird --version                     # 1.6.124 expected
```

Authenticate. `shorebird login` opens a browser and you complete the flow there;
this document cannot do it for you.

```sh
shorebird login
```

Create the upload keystore **once**, and store it somewhere you will not lose
it. Losing this keystore makes every future update to the app impossible: the
Play Store refuses an APK signed by a different certificate than the first one
you published, so you would have to ship a brand-new application ID.

```sh
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload -storetype JKS
```

Point the build at it, in `android/key.properties` (gitignored):

```properties
storeFile=../../upload-keystore.jks
storePassword=<keystore password>
keyAlias=upload
keyPassword=<key password>
```

`android/app/build.gradle.kts` reads that file; if it is missing the build
silently falls back to the debug signing config. Never ship a build made that
way.

Capture the certificate fingerprint that will go into the server-side allow-list:

```sh
keytool -list -v -keystore upload-keystore.jks -alias upload | grep 'SHA256:'
```

Take the hex string, remove the `:` separators, upper-case it. That value is
what `app_builds.cert_fingerprint` must contain.

---

## 2. The release command

```sh
shorebird release android \
  --artifact apk \
  --obfuscate \
  --split-debug-info=build/symbols \
  --dart-define-from-file=env/app.json
```

Flag placement matters. `--obfuscate` and `--split-debug-info` are **Shorebird
flags and must appear before the `--` separator**, because Shorebird has to know
about them to record them against the release. Placing them after `--` passes
them to `flutter build` instead, which is what older CLIs required and what the
current CLI mishandled until 1.6.84.

`--dart-define-from-file=env/app.json` is also a Shorebird flag, before `--`.
It carries `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` and `AUTHOR_HASH`:

- the publishable key is a client key and is safe to ship (RLS protects every
  table);
- `AUTHOR_HASH` is the SHA-256 of the authorship constants baked in at build
  time and compared by `lib/core/branding/build_integrity.dart` at startup,
  login and in settings.

Recompute it whenever you edit `lib/core/branding/author_info.dart`:

```sh
python3 - <<'PY'
import hashlib
parts = [
  "Clinton Iwoloma",
  "The Imaginr, CEO, Flatra Tech Ltd",
  "Flatra Tech Ltd",
  "+2349025975247",
  "Made by ImaginirCo-Flatra",
  "Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd. For more jobs and automation workflows contact +2349025975247.",
]
print(hashlib.sha256("|".join(parts).encode()).hexdigest())
PY
```

The command prints the release version. Record it, because patch commands
reference it with `--release-version`. The APK lands at
`build/app/outputs/flutter-apk/app-release.apk`.

Report for the reference release in this repo:

| Field | Value |
|---|---|
| applicationId | `com.clintoniwoloma.safedepot_pro` |
| version | see `pubspec.yaml` (`version: x.y.z+build`) |
| artifact | `app-release.apk` (obfuscated) |

---

## 3. Registering the release build

Until a release exists in `app_builds`, `assert_build_allowed` rejects it and
sensitive writes are refused. Migration `0018_app_build_gate.sql` seeds one
**placeholder** row with a debug fingerprint; it must be replaced.

Register the real one with the service-role key or the SQL editor — never from
the app, because the table has no client write policy:

```sql
insert into public.app_builds
  (application_id, version, cert_fingerprint, min_supported_version, status, channel, notes)
values
  ('com.clintoniwoloma.safedepot_pro', '1.0.0',
   'ABCD1234...',                -- SHA-256 of the upload cert, no colons
   null, 'ACTIVE', 'production',
   'First production release')
on conflict (application_id, version, cert_fingerprint) do nothing;
```

`min_supported_version` is the coarse kill switch: set it to a version and
every older build is refused, app-wide, immediately.

---

## 4. The patch workflow

For a change confined to Dart code:

```sh
shorebird patch android \
  --release-version <version> \
  --split-debug-info=build/symbols-patch \
  --dart-define-from-file=env/app.json
```

**Do not pass `--obfuscate` to a patch.** Shorebird records at release time that
the release was obfuscated and applies the same obfuscation to the patch
itself. Passing the flag again is rejected, with "a patch cannot change the
obfuscation mode of a release", and mixing obfuscated and unobfuscated builds
suffocates the diff: it produces a patch containing every renamed symbol.

The `--release-version` value must match the release exactly, including the
`+build` suffix if you used one.

---

## 5. Versioning

`pubspec.yaml` holds a single version, `x.y.z+b`, used for both the Android
`versionName` (`x.y.z`) and `versionCode` (`b`).

- `b` — the build number, **must increase for every release and every patch**.
  Google Play and the Play Store's internal logic both treat it as the
  monotonically increasing artifact counter, and Shorebird patches reference it.
- `x.y.z` — semver for users. Announce only meaningful changes.

Changing `version` does not by itself produce a new Shorebird release; it
changes what the app reports to the server-side gate. That matters: if you bump
`version` to `1.0.1` but `app_builds` only knows `1.0.0`, `assert_build_allowed`
returns `allowed=false` with reason "unknown build", and the app is locked out.
Bump the version in `app_builds` in the same change.

---

## 6. What cannot be patched

Shorebird patches replace the Dart AOT snapshot only. Anything that is not Dart
code is compiled into the APK the store serves, so a patch cannot deliver it:

- changes to `android/` — the manifest, `build.gradle.kts`, `proguard-rules.pro`,
  native or Java/Kotlin sources, resources
- a change of Flutter version or plugin version (native code differs)
- `pubspec.yaml` when it adds, removes or upgrades a plugin, or changes the
  Android platform configuration
- anything in `ios/`
- anything referenced from `AndroidManifest.xml`, including the permission set
  and the integrity method channel registration
- changes to the Dart–native method-channel surface, if a plugin's Dart side is
  bypassed

The reliable test: if a change requires `flutter clean` before it takes effect
on a previously built tree, assume a patch will not carry it.

Patch sizes also grow with the diff. A patch that touches a large fraction of
the codebase may end up as large as the release itself, at which point shipping
a new release is no more expensive and is easier to reason about.

---

## 7. Symbols: keep them or lose the crash

`--split-debug-info` writes the obfuscation map to a directory on the build
machine. **Without it, a crash from a release build is unreadable** — you get
class names like `a.a.a` and line numbers referring to nothing.

`build/symbols/` is gitignored and lives outside version control, so it is not
protected by the repository. Back it up with the rest of your release
artifacts, keep one directory per release (dated, or named by release version),
and record the mapping in your release notes so a future you can find it.

Symbolise a stack trace with:

```sh
flutter symbolize -i stacktrace.txt -d build/symbols/<release-version>/app.android-arm64.symbols
```

---

## 8. Revoking a build

A leaked, tampered, or accidently published build is revoked from the database,
not from the app:

```sql
update public.app_builds
set status = 'REVOKED'
where application_id = 'com.clintoniwoloma.safedepot_pro'
  and version = '<version>';
```

Revocation takes effect on the next `assert_build_allowed` call, so it lands
within one app start. There is no client path to undo it: `status` is only ever
written with the service role.

<!-- © Flatra Tech Ltd. All rights reserved.
     Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
     Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
     Contact: +2349025975247 -->

---

## 9. Launcher icon and splash

Source of truth: `assets/branding/logo_source.webp` (the owner's shield mark).
Generated from it, all committed:

| File | Purpose |
|---|---|
| `icon_master.png` | 1024×1024 LANCZOS upscale; every other icon downscales from this rather than upscaling from the 160px source |
| `ic_launcher_foreground.png` | adaptive foreground, inset to 62% so the launcher mask cannot crop it |
| `ic_launcher_background.png` | adaptive background, flat shield red |
| `ic_launcher_legacy.png` | pre-Android-8 square fallback |
| `launch_image.png` | splash logo |

Installed into `android/app/src/main/res/`:

- `mipmap-anydpi-v26/ic_launcher.xml` — the `<adaptive-icon>`, in `anydpi-v26`
  and **not** in the density folders. Putting it next to `ic_launcher.png` in
  the same folder is a duplicate-resource build error.
- `mipmap-{mdpi..xxxhdpi}/ic_launcher_background.png` + `ic_launcher_foreground.png`
- `mipmap-{mdpi..xxxhdpi}/ic_launcher.png` — the legacy bitmap fallback
- `mipmap-{mdpi..xxxhdpi}/launch_image.png`
- `values/colors.xml` + `values-night/colors.xml` — `safedepot_brand_red`

Two rules that are easy to get wrong:

1. The adaptive XML must reference `@mipmap/…`, not `@drawable/…`, because the
   layers live in `mipmap-*`.
2. Adaptive layers cannot share a resource name with the legacy bitmap in the
   same directory.

### Replacing the icon

Copy the new source over `assets/branding/logo_source.webp`, then re-run the
generation in `assets/branding/` and reinstall into `res/`. Then **build a new
release** — see §6, an icon is an Android resource and no patch can carry it.

In-app the logo is `AppLogo` in `lib/core/branding/app_logo.dart`, a
`CustomPainter` rather than a bitmap, so it stays sharp at any size and adapts
to the theme without an image dependency.

---

<!-- © Flatra Tech Ltd. All rights reserved.
     Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
     Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
     Contact: +2349025975247 -->
