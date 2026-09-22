-- 0011_assets.sql — physical asset register (tools, PPE, equipment) with zones & calibration.

create table public.assets (
  id uuid primary key default gen_random_uuid(),
  depot_id uuid not null references public.depots(id) on delete cascade,
  asset_tag text not null,
  name text not null,
  asset_type text,
  make_model text,
  serial_number text,
  zone_id uuid references public.depot_zones(id) on delete set null,
  zone_name text,
  purchase_date date,
  status public.asset_status not null default 'AVAILABLE',
  condition text,
  last_calibration_date date,
  next_calibration_date date,
  assigned_to_user_id uuid references public.profiles(id) on delete set null,
  assigned_to_name text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);