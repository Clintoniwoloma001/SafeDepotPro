-- © Flatra Tech Ltd. All rights reserved.
-- Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
-- Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
-- Contact: +2349025975247
-- 0017_notifications_and_idempotency.sql
--
-- Additive, non-destructive. Nothing here is dropped or recreated: tables are
-- created with IF NOT EXISTS, columns are added only when absent, and policies
-- are created only if a policy of that name does not already exist.
--
-- Two things this migration provides:
--
--   1. public.notifications — per-user in-app notification feed. The prior
--      schema drove notifications from a cron edge function with nowhere to
--      store the resulting message, so the app had nothing to read.
--
--   2. client_request_id on the four write-heavy tables. This is the
--      duplicate-submission guard for offline replays: the app mints a key
--      before the write, and a unique index means a retry cannot create a
--      second incident, corrective action, permit or inspection. Relying on
--      the client to disable its own Submit button is not a guarantee on a
--      flaky depot connection.

-- ---------------------------------------------------------------------------
-- 1. notifications
-- ---------------------------------------------------------------------------
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  -- Targeted at exactly one user; a supervisor never sees another person's.
  user_id uuid not null references auth.users(id) on delete cascade,
  depot_id uuid references public.depots(id) on delete cascade,
  title text not null,
  body text,
  -- Free-text category so new sources do not require an enum change.
  category text,
  -- Deep link, matched against the app's route catalog.
  link text,
  severity public.severity not null default 'MEDIUM',
  is_read boolean not null default false,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from pg_indexes where schemaname='public'
                 and indexname='notifications_user_created_idx') then
    create index notifications_user_created_idx
      on public.notifications(user_id, created_at desc);
  end if;

  if not exists (select 1 from pg_indexes where schemaname='public'
                 and indexname='notifications_unread_idx') then
    -- Partial index: only unread rows, which is what the badge counts.
    create index notifications_unread_idx
      on public.notifications(user_id) where is_read = false;
  end if;
end $$;

alter table public.notifications enable row level security;

-- Read: your own notifications only, plus site managers on the same depot.
drop policy if exists notifications_read on public.notifications;
create policy notifications_read on public.notifications
  for select to authenticated
  using (
    user_id = auth.uid()
    or (
      depot_id is not null
      and public.is_admin()
      and public.can_read_depot(depot_id)
    )
  );

-- Marking read is the only client-side write. Creating notifications is a
-- server concern (see notify-overdue edge function); there is no client insert
-- policy by design, so nothing in the app can forge an alert.
drop policy if exists notifications_update_self on public.notifications;
create policy notifications_update_self on public.notifications
  for update to authenticated
  using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid() or public.is_admin());

drop policy if exists notifications_delete_self on public.notifications;
create policy notifications_delete_self on public.notifications
  for delete to authenticated
  using (user_id = auth.uid() or public.is_admin());

-- ---------------------------------------------------------------------------
-- 2. client_request_id — duplicate-submission guard
-- ---------------------------------------------------------------------------
-- Partial unique index rather than NOT NULL: existing rows (written before
-- this migration) have no key, and backfilling them is not possible after the
-- fact. The index only constrains rows that carry a key, so it applies to
-- everything the new app writes without invalidating history.

do $$
declare
  t text;
begin
  foreach t in array array[
    'incidents','inspections','permits','capa'
  ]
  loop
    if not exists (
      select 1 from information_schema.columns
      where table_schema='public' and table_name=t and column_name='client_request_id'
    ) then
      execute format(
        'alter table public.%I add column client_request_id text', t);
    end if;

    if not exists (
      select 1 from pg_indexes
      where schemaname='public' and indexname=format('%s_client_request_id_key', t)
    ) then
      execute format(
        'create unique index %I on public.%I (client_request_id) where client_request_id is not null',
        format('%s_client_request_id_key', t), t);
    end if;
  end loop;
end $$;

-- Keep updated_at bookkeeping in step with the newer tables.
drop trigger if exists trg_notifications_updated_at on public.notifications;
