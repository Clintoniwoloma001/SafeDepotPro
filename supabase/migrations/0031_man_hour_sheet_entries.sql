-- © Flatra Tech Ltd. All rights reserved.
-- Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
-- Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
-- Contact: +2349025975247
-- 0031_man_hour_sheet_entries.sql — per-depot monthly man-hour sheets.
--
-- One header row per depot/period carries the draft/submitted lock state, and
-- one child row per man-hour entry carries the headcount, days and hours that
-- make up the "NAMES / NO. OF WORKER / NO. OF DAYS / NO. OF HOURS / TOTAL"
-- grid exported to the corporate West Depots workbook.

create table if not exists public.man_hour_sheets (
  id uuid primary key default gen_random_uuid(),
  depot_id uuid not null references public.depots(id) on delete cascade,
  period_year int not null check (period_year between 2020 and 2100),
  period_month int not null check (period_month between 1 and 12),
  status text not null default 'DRAFT' check (status in ('DRAFT', 'SUBMITTED')),
  submitted_at timestamptz,
  submitted_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (depot_id, period_year, period_month)
);

create table if not exists public.man_hour_sheet_entries (
  id uuid primary key default gen_random_uuid(),
  sheet_id uuid not null references public.man_hour_sheets(id) on delete cascade,
  row_index int not null default 0,
  category text not null default 'FTE' check (category in ('FTE', 'DSO', 'CONTRACTOR')),
  entry_name text not null default '',
  worker_count int not null default 0 check (worker_count >= 0),
  days_worked int not null default 0 check (days_worked >= 0),
  hours_per_day int not null default 8 check (hours_per_day >= 0),
  total_hours numeric generated always as (worker_count * days_worked * hours_per_day) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (sheet_id, row_index)
);

create index if not exists man_hour_sheets_period_idx
  on public.man_hour_sheets(period_year desc, period_month desc);
create index if not exists man_hour_sheet_entries_sheet_idx
  on public.man_hour_sheet_entries(sheet_id, row_index);

drop trigger if exists trg_man_hour_sheets_updated_at on public.man_hour_sheets;
create trigger trg_man_hour_sheets_updated_at
  before update on public.man_hour_sheets
  for each row execute function public.set_updated_at();

drop trigger if exists trg_man_hour_sheet_entries_updated_at on public.man_hour_sheet_entries;
create trigger trg_man_hour_sheet_entries_updated_at
  before update on public.man_hour_sheet_entries
  for each row execute function public.set_updated_at();

alter table public.man_hour_sheets enable row level security;
alter table public.man_hour_sheet_entries enable row level security;

drop policy if exists man_hour_sheets_read on public.man_hour_sheets;
create policy man_hour_sheets_read on public.man_hour_sheets
  for select to authenticated using ((public.can_read_depot(depot_id) or public.is_admin()));

drop policy if exists man_hour_sheets_insert on public.man_hour_sheets;
create policy man_hour_sheets_insert on public.man_hour_sheets
  for insert to authenticated with check ((public.can_read_depot(depot_id) or public.is_admin()));

drop policy if exists man_hour_sheets_update on public.man_hour_sheets;
create policy man_hour_sheets_update on public.man_hour_sheets
  for update to authenticated
  using ((public.can_read_depot(depot_id) or public.is_admin()))
  with check ((public.can_read_depot(depot_id) or public.is_admin()));

drop policy if exists man_hour_sheets_delete on public.man_hour_sheets;
create policy man_hour_sheets_delete on public.man_hour_sheets
  for delete to authenticated using (public.is_admin());

drop policy if exists man_hour_sheet_entries_read on public.man_hour_sheet_entries;
create policy man_hour_sheet_entries_read on public.man_hour_sheet_entries
  for select to authenticated using (
    exists (
      select 1 from public.man_hour_sheets s
      where s.id = sheet_id and (public.can_read_depot(s.depot_id) or public.is_admin())
    )
  );

drop policy if exists man_hour_sheet_entries_insert on public.man_hour_sheet_entries;
create policy man_hour_sheet_entries_insert on public.man_hour_sheet_entries
  for insert to authenticated with check (
    exists (
      select 1 from public.man_hour_sheets s
      where s.id = sheet_id and (public.can_read_depot(s.depot_id) or public.is_admin())
    )
  );

drop policy if exists man_hour_sheet_entries_update on public.man_hour_sheet_entries;
create policy man_hour_sheet_entries_update on public.man_hour_sheet_entries
  for update to authenticated
  using (
    exists (
      select 1 from public.man_hour_sheets s
      where s.id = sheet_id and (public.can_read_depot(s.depot_id) or public.is_admin())
    )
  )
  with check (
    exists (
      select 1 from public.man_hour_sheets s
      where s.id = sheet_id and (public.can_read_depot(s.depot_id) or public.is_admin())
    )
  );

drop policy if exists man_hour_sheet_entries_delete on public.man_hour_sheet_entries;
create policy man_hour_sheet_entries_delete on public.man_hour_sheet_entries
  for delete to authenticated using (
    exists (
      select 1 from public.man_hour_sheets s
      where s.id = sheet_id and (public.can_read_depot(s.depot_id) or public.is_admin())
    )
  );
