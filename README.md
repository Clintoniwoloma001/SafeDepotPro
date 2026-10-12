# SafeDepot Pro

Depot safety and workflow management: inspections, incidents, permits and
approvals, corrective actions, and an append-only audit trail.

Flutter (Android first) + Supabase, with over-the-air Dart updates delivered by
Shorebird.

---

## Proprietary software

**© Flatra Tech Ltd. All rights reserved.**

Designed and developed by **Clinton Iwoloma — The Imaginr, CEO, Flatra Tech
Ltd.** This software is proprietary and confidential. Unauthorized copying,
modification, distribution or reuse is prohibited.

For more jobs and automation workflows contact **+2349025975247**.

Every source file in this repository carries that copyright header. The header
is added mechanically, so it cannot drift:

```sh
dart run tool/add_headers.dart           # add any missing headers
dart run tool/add_headers.dart --check   # fail if any are missing (CI/hook)
```

See [LICENSE](LICENSE), [NOTICE](NOTICE) and [AUTHORS](AUTHORS).

---

## Repository layout

```
android/                Android host project
lib/
  core/
    config/             Build-time config + the missing-config error screen
    router/             GoRouter, route catalog, single auth guard
    theme/              Material 3 light/dark themes and colour tokens
  data/
    models/             Typed models — field names match DB columns exactly
    repositories/       One repository per bounded area
    supabase/           Client bootstrap, secure session store, outbox
  features/             Feature-first screens (auth, inspections, incidents…)
  providers/            Riverpod wiring
supabase/               Migrations (source of truth for the schema), edge functions
legacy/                 The previous web app, kept for reference — not built
env/                    Build-time config (gitignored except *.example)
test/
```

## Requirements

- Flutter stable (see `pubspec.yaml` for the SDK constraint)
- Android SDK + JDK 17+
- [Supabase CLI](https://supabase.com/docs/guides/cli) for migrations
- [Shorebird CLI](https://shorebird.dev) for OTA releases and patches

## Configuration

Two separate credential paths, deliberately:

| File | Used by | Contains | Committed? |
|---|---|---|---|
| `env/app.json` | The **app** (build time) | `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` | No |
| `.env.local` | **Migration tooling only** (`supabase`, `psql`) | `SUPABASE_PROJECT_REF`, `SUPABASE_DB_PASSWORD` | No |

`env/app.json` is passed to the build with `--dart-define-from-file`. It holds
the publishable key, which is a client key by design — every table is protected
by Row Level Security, so it grants no access the user does not already have.
**Never** put the service-role key or the database password in it: anything
bundled into the APK can be extracted from it.

Create both from the templates:

```sh
cp env/app.json.example env/app.json      # then fill in real values
cp .env.local.example .env.local          # then fill in the DB password
```

## Running

```sh
flutter run --dart-define-from-file=env/app.json
```

Without the config file the app shows a clear error screen explaining what is
missing and the exact command to use — it does not crash.

## Database

The SQL in `supabase/migrations/` is the source of truth for the schema, and
it is applied through the CLI rather than the dashboard:

```sh
supabase init                 # once, already done in this repo
supabase link --project-ref <ref>
supabase db push              # apply migrations
supabase migration new <name> # author the next one
```

Migrations are idempotent and non-destructive: existing objects are never
recreated, policies are guarded, and no `DROP` is issued without an explicit
review.

### Roles

`USER` → `COUNTRY_HEAD` → `ADMIN` → `SUPERADMIN`.

`profiles.role` is **not** client-writable. There is no policy and no UI that
can raise a role from the app; role changes are an administrative action
performed against a trusted session.

### Row Level Security

Every table has RLS enabled. Reads are scoped by `can_read_depot()`, which
returns true for a country head or super admin, and otherwise restricts to the
user's own depot plus any depot they cover through an active `stand_ins` row.
There is no public write path to any table.

## Releasing

See [docs/RELEASING.md](docs/RELEASING.md) for the Shorebird release and patch
workflow, versioning rules, and what cannot be delivered as a patch.

## Tests

```sh
flutter analyze
flutter test
```

## Legacy web app

The earlier Vite/React implementation was moved to `legacy/` for reference and
is no longer built or deployed. Its `src/services` layer documents the domain
rules that this app implements; the SQL schema it targeted is the same one used
here. Note that its `STORAGE_BUCKETS` constant names buckets
(`images`, `attachments`) that the SQL never created — the authoritative
buckets are `photos`, `signatures` and `capa-proof`, and this app uses those.
