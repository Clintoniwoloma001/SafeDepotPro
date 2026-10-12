-- © Flatra Tech Ltd. All rights reserved.
-- Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
-- Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
-- Contact: +2349025975247
-- 0019_remote_config_and_feature_flags.sql
--
-- Additive, non-destructive and idempotent. Nothing here drops or recreates an
-- existing object.
--
-- Two things this migration provides:
--
--   1. feature_flags — server-side control of which modules are enabled, cached
--      on device so a patch can switch a module on with no reinstall.
--   2. app_builds extended with the columns needed to decide whether the
--      installed build is still supported and where to fetch a newer APK.

-- ---------------------------------------------------------------------------
-- 1. feature_flags
-- ---------------------------------------------------------------------------
create table if not exists public.feature_flags (
  id uuid primary key default gen_random_uuid(),
  -- Stable machine key, e.g. "permits". Referenced by FeatureGate.
  key text not null unique,
  enabled boolean not null default false,
  -- Build number below which the flag is ignored. Lets a flag be authored in
  -- advance for a future release without changing behaviour now.
  min_build integer,
  -- Empty means every role. Otherwise the role wires, e.g. '{ADMIN}'.
  roles text[] not null default '{}',
  -- Shown in the coming-soon card when a module is off.
  message text,
  -- Optional module title override for the same card.
  title text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists feature_flags_key_idx
  on public.feature_flags(key) where enabled = true;

alter table public.feature_flags enable row level security;

-- Read for any authenticated user: a flag has to be readable to have effect,
-- and knowing which modules exist leaks nothing. There is no client write
-- policy, so a user cannot enable a half-built module for themselves.
drop policy if exists feature_flags_read on public.feature_flags;
create policy feature_flags_read on public.feature_flags
  for select to authenticated using (true);

drop trigger if exists trg_feature_flags_updated_at on public.feature_flags;
create trigger trg_feature_flags_updated_at
  before update on public.feature_flags
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 2. app_builds remote-update columns
-- ---------------------------------------------------------------------------
alter table public.app_builds
  add column if not exists build_number integer,
  add column if not exists min_supported_build integer,
  add column if not exists apk_url text,
  add column if not exists release_notes text,
  add column if not exists sha256 text;

-- The columns added in 0018 carried `min_supported_version` (a version string).
-- Both are kept: version is what the gate compares, build number is what the
-- updater compares, and they are authoritative at different times.

drop index if exists app_builds_build_idx;
create unique index if not exists app_builds_build_idx
  on public.app_builds(application_id, build_number)
  where build_number is not null;

-- Seed the flags for the first native-complete release. Everything starts
-- disabled, which is the safe default: a module that is not ready yet shows a
-- branded coming-soon card rather than a screen that crashes.
insert into public.feature_flags (key, enabled, title, message) values
  ('routine_tasks', false, 'Routine Tasks', 'Arrives in an update — no reinstall needed.'),
  ('toolbox_talks', false, 'Toolbox Talks', 'Arrives in an update — no reinstall needed.'),
  ('incidents', false, 'Incidents', 'Arrives in an update — no reinstall needed.'),
  ('hazards', false, 'Hazards', 'Arrives in an update — no reinstall needed.'),
  ('inspections', false, 'HSE Inspections', 'Arrives in an update — no reinstall needed.'),
  ('truck_inspections', false, 'Truck Inspections', 'Arrives in an update — no reinstall needed.'),
  ('permits', false, 'Permit to Work', 'Arrives in an update — no reinstall needed.'),
  ('capa', false, 'Corrective Actions', 'Arrives in an update — no reinstall needed.'),
  ('shift_handover', false, 'Shift Handover', 'Arrives in an update — no reinstall needed.'),
  ('man_hours', false, 'Man-Hours', 'Arrives in an update — no reinstall needed.'),
  ('notifications', false, 'Notifications', 'Arrives in an update — no reinstall needed.'),
  ('ai_copilot', false, 'AI Copilot', 'Arrives in an update — no reinstall needed.'),
  ('scorecards', false, 'Scorecards', 'Arrives in an update — no reinstall needed.'),
  ('heat_map', false, 'Depot Heat Map', 'Arrives in an update — no reinstall needed.'),
  ('photo_gallery', false, 'Photo Gallery', 'Arrives in an update — no reinstall needed.')
on conflict (key) do nothing;

-- Register the current release so the updater has something to compare to.
insert into public.app_builds
  (application_id, version, build_number, cert_fingerprint,
   min_supported_build, status, channel, release_notes)
values
  ('com.clintoniwoloma.safedepot_pro', '2.0.0', 3,
   '630E6BC79CC9038363BE768AE020889747E958D10B93F892BEC711D3BC2ED076',
   null, 'ACTIVE', 'production',
   'Full UI redesign: brand tokens, light/dark, 5-slot navigation, dashboard, '
   'splash. Native-complete: every plugin, permission and asset the roadmap '
   'needs ships in this release so later features are OTA patches.')
on conflict (application_id, version, cert_fingerprint) do nothing;
