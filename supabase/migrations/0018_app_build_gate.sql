-- © Flatra Tech Ltd. All rights reserved.
-- Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
-- Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
-- Contact: +2349025975247
-- 0018_app_build_gate.sql
--
-- Server-side build authorisation ("is this a real, current build of ours?").
--
-- Motivation: everything client-side is optional. An attacker who unpacks and
-- repackages the APK can patch out Dart-level integrity checks as easily as we
-- add them, so the authoritative decision has to be made where the attacker
-- cannot reach it — in the database, behind RLS.
--
-- Design:
--   * app_builds        — allow-list of known builds. The service-role key
--                         writes it; clients only ever read.
--   * build_assertions   — append-only log of every gate evaluation, so a
--                         revoked build's activity can be reconstructed.
--   * assert_build_allowed(rpc) — the single decision function, called at
--                         sign-in and before sensitive writes.
--
-- No service-role or database credential ever reaches the app. The app holds
-- only the publishable key and the claims in its own JWT.

-- ---------------------------------------------------------------------------
-- app_builds
-- ---------------------------------------------------------------------------
create table if not exists public.app_builds (
  id uuid primary key default gen_random_uuid(),
  -- Display version, e.g. "1.2.3". Compared as a version tuple by the gate.
  version text not null,
  -- Android applicationId. Lets one table serve several app flavours.
  application_id text not null default 'com.clintoniwoloma.safedepot_pro',
  -- SHA-256 of the APK signing certificate (no colons, upper or lower case),
  -- captured from `apksigner` on the real release keystore.
  cert_fingerprint text not null,
  -- Minimum build the server will accept. Raising this kills every older
  -- build at once, which is the coarse revocation lever.
  min_supported_version text,
  status text not null default 'ACTIVE'
    check (status in ('ACTIVE', 'REVOKED', 'EXPIRED')),
  -- Release channel, so a Play build and a sideloaded build can be told apart.
  channel text not null default 'production'
    check (channel in ('production', 'internal', 'staging')),
  notes text,
  registered_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- One active row per version+app+cert triple.
create unique index if not exists app_builds_identity_idx
  on public.app_builds(application_id, version, cert_fingerprint);

alter table public.app_builds enable row level security;

-- Authenticated users may read the allow-list. This is not a secret: the
-- certificate fingerprint of a public app is discoverable from the store
-- listing or the APK itself, and knowing it grants nothing.
drop policy if exists app_builds_read on public.app_builds;
create policy app_builds_read on public.app_builds
  for select to authenticated using (true);

-- No insert, update or delete policy. Client writes are impossible, so a
-- leaked build cannot be un-blocked from the app it leaked from.
-- Administration is done with the service role via the CLI or the dashboard.

-- ---------------------------------------------------------------------------
-- build_assertions — append-only audit of gate decisions
-- ---------------------------------------------------------------------------
create table if not exists public.build_assertions (
  id uuid primary key default gen_random_uuid(),
  -- Nullable: an unauthenticated repackaged build never gets a jwt.sub.
  actor_user_id uuid,
  reported_version text,
  reported_cert_fingerprint text,
  reported_application_id text,
  allowed boolean not null,
  reason text not null,
  user_agent text,
  created_at timestamptz not null default now()
);

create index if not exists build_assertions_created_idx
  on public.build_assertions(created_at desc);

alter table public.build_assertions enable row level security;

-- Superadmins inspect the trail; the service role appends to it.
drop policy if exists build_assertions_read on public.build_assertions;
create policy build_assertions_read on public.build_assertions
  for select to authenticated using (public.is_superadmin());

-- ---------------------------------------------------------------------------
-- Gate decision function
-- ---------------------------------------------------------------------------
-- Kept deliberately strict: it defaults to DENY. An unregistered build, a
-- revoked build, or a version below min_supported_version all return
-- allowed=false, and the caller refuses the operation rather than asking the
-- user to retry.
--
-- Note on comparison: version strings are compared component-wise on integers
-- rather than lexically, so "1.10.0" correctly sorts after "1.9.0".

create or replace function public.parse_version(v text)
returns int[]
language plpgsql immutable
as $$
declare
  parts text[];
  out int[] := array[]::int[];
  p text;
begin
  if v is null then return out; end if;
  parts := string_to_array(split_part(v, '+', 1), '.');
  foreach p in array parts loop
    begin
      out := array_append(out, greatest(0, p::int));
    exception when others then
      out := array_append(out, 0);
    end;
  end loop;
  return out;
end $$;

create or replace function public.version_gte(a text, b text)
returns boolean
language plpgsql immutable
as $$
declare
  va int[] := public.parse_version(a);
  vb int[] := public.parse_version(b);
  n int;
begin
  n := greatest(array_length(va, 1), array_length(vb, 1));
  for i in 0..(coalesce(n, 1) - 1) loop
    if coalesce(va[i + 1], 0) > coalesce(vb[i + 1], 0) then return true; end if;
    if coalesce(va[i + 1], 0) < coalesce(vb[i + 1], 0) then return false; end if;
  end loop;
  return true;
end $$;

create or replace function public.assert_build_allowed(
  p_version text,
  p_cert_fingerprint text,
  p_application_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_record public.app_builds%rowtype;
  v_app_id text := coalesce(p_application_id, 'com.clintoniwoloma.safedepot_pro');
  v_fingerprint text := upper(replace(coalesce(p_cert_fingerprint, ''), ':', ''));
  v_allowed boolean := false;
  v_reason text;
  v_actor uuid := auth.uid();
begin
  select * into v_record
  from public.app_builds
  where application_id = v_app_id
    and upper(replace(cert_fingerprint, ':', '')) = v_fingerprint
    and version = p_version
  order by registered_at desc
  limit 1;

  if not found then
    v_reason := 'unknown build: no allow-listed build matches this version and certificate';
  elsif v_record.status = 'REVOKED' then
    v_reason := 'build revoked';
  elsif v_record.status = 'EXPIRED' then
    v_reason := 'build expired';
  elsif v_record.min_supported_version is not null
        and not public.version_gte(p_version, v_record.min_supported_version) then
    v_reason := format('version %s is below the minimum supported version %s',
                       p_version, v_record.min_supported_version);
  else
    v_allowed := true;
    v_reason := 'ok';
  end if;

  insert into public.build_assertions (
    actor_user_id, reported_version, reported_cert_fingerprint,
    reported_application_id, allowed, reason
  ) values (
    v_actor, p_version, v_fingerprint, v_app_id, v_allowed, v_reason
  );

  return jsonb_build_object(
    'allowed', v_allowed,
    'reason', v_reason,
    'application_id', v_app_id,
    'version', p_version,
    'channel', v_record.channel
  );
end $$;

-- Authenticated callers may evaluate the gate. The function is SECURITY
-- DEFINER so it can read app_builds without granting direct table access, and
-- it writes only to build_assertions, never to app_builds.
revoke all on function public.assert_build_allowed(text, text, text) from public;
grant execute on function public.assert_build_allowed(text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Register the development build.
-- ---------------------------------------------------------------------------
-- The fingerprint below is the debug keystore's certificate. It is registered
-- so that a local debug build can be gated during development; the real
-- release fingerprint must replace it before the first production release
-- (see docs/RELEASING.md, "Registering the release build").
insert into public.app_builds
  (application_id, version, cert_fingerprint, min_supported_version, status, channel, notes)
values
  ('com.clintoniwoloma.safedepot_pro', '1.0.0',
   'debug-unsigned-placeholder', null, 'ACTIVE', 'staging',
   'Development placeholder. Replace with the SHA-256 of the release signing certificate.')
on conflict (application_id, version, cert_fingerprint) do nothing;

-- ---------------------------------------------------------------------------
-- updated_at bookkeeping, matching the convention in 0015.
-- ---------------------------------------------------------------------------
drop trigger if exists trg_app_builds_updated_at on public.app_builds;
create trigger trg_app_builds_updated_at
  before update on public.app_builds
  for each row execute function public.set_updated_at();
