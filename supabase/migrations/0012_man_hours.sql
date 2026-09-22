-- 0012_man_hours.sql — monthly man-hour records per depot with TRIR/LTIFR computation.

create table public.man_hours (
  id uuid primary key default gen_random_uuid(),
  depot_id uuid not null references public.depots(id) on delete cascade,
  period_start date not null,
  period_end date,
  hours_worked numeric not null default 0,
  overtime_hours numeric not null default 0,
  headcount int not null default 0,
  recordable_incidents int not null default 0,
  lost_time_incidents int not null default 0,
  near_misses int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (depot_id, period_start)
);

create index man_hours_period_start_idx on public.man_hours(period_start);