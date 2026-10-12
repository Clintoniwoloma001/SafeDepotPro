-- © Flatra Tech Ltd. All rights reserved.
-- Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
-- Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
-- Contact: +2349025975247
-- 0022_base44_import_columns.sql
--
-- Additive, non-destructive and idempotent. Every column is added with
-- IF NOT EXISTS and no existing column is altered, renamed or dropped.
--
-- The Base44 export files carry fields the Supabase schema never had. They are
-- preserved rather than dropped:
--
--   * `source_meta jsonb` on the three imported tables, holding the Base44
--     record verbatim. This is the lossless part — any field with no home in
--     this schema survives here instead of being silently discarded, so a
--     future mapping can be written without re-importing.
--   * The columns the app actually needs to render these records: a truck's
--     company and driver (the truck picker and the inspection form both show
--     them), its colour and QR URL, and its last/next inspection dates.

-- ---------------------------------------------------------------------------
-- routine_tasks
-- ---------------------------------------------------------------------------
alter table public.routine_tasks
  add column if not exists source_meta jsonb not null default '{}'::jsonb;

-- ---------------------------------------------------------------------------
-- trucks
-- ---------------------------------------------------------------------------
alter table public.trucks
  add column if not exists company text,
  add column if not exists driver_name text,
  add column if not exists driver_phone text,
  add column if not exists color text,
  add column if not exists qr_code_url text,
  add column if not exists last_inspection_date date,
  add column if not exists last_inspection_result text,
  add column if not exists next_inspection_date date,
  add column if not exists source_meta jsonb not null default '{}'::jsonb;

-- Truck number is the business key for import matching and for the duplicate
-- check the bulk-upload rules require.
create unique index if not exists trucks_reg_no_key
  on public.trucks(reg_no);

-- ---------------------------------------------------------------------------
-- depots
-- ---------------------------------------------------------------------------
alter table public.depots
  add column if not exists source_meta jsonb not null default '{}'::jsonb;

-- ---------------------------------------------------------------------------
-- Lookup helpers for the importer
-- ---------------------------------------------------------------------------
-- The import matches a depot by name when the Base44 code is not already
-- present. Name matching is case-insensitive and trims surrounding whitespace,
-- because the export writes "AJAH" and the UI may have stored "Ajah".
create or replace function public.find_depot_by_name(p_name text)
returns uuid
language sql
stable
set search_path = public
as $$
  select id from public.depots
  where btrim(upper(name)) = btrim(upper(p_name))
  order by created_at
  limit 1;
$$;

-- Title is the import's business key for routine tasks, and it is also what
-- the bulk-upload duplicate check needs. No unique index on it existed, so the
-- import's ON CONFLICT had no valid target.
create unique index if not exists routine_tasks_title_key
  on public.routine_tasks(title);
