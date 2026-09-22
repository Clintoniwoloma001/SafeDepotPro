-- 0008_trucks.sql — fleet register + truck inspection log.

create table public.trucks (
  id uuid primary key default gen_random_uuid(),
  depot_id uuid references public.depots(id) on delete set null,
  reg_no text not null,
  make_model text,
  year int,
  capacity_tonnes numeric,
  status text not null default 'OPERATIONAL' check (status in ('OPERATIONAL', 'MAINTENANCE', 'OUT_OF_SERVICE')),
  odo_reading numeric,
  last_service_due date,
  next_service_due date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.truck_inspections (
  id uuid primary key default gen_random_uuid(),
  truck_id uuid not null references public.trucks(id) on delete cascade,
  depot_id uuid references public.depots(id) on delete set null,
  checklist_name text not null default 'Truck Inspection',
  result public.truck_result,
  compliance numeric default 0,
  answers jsonb not null default '[]',
  driver_name text,
  odo_reading numeric,
  remarks text,
  photographed_issues text[] not null default '{}',
  status public.inspection_status not null default 'SUBMITTED',
  completed_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);