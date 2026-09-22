-- 0002_depots_and_settings.sql — depots, depot zones, org settings.

create table public.depots (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  city text,
  region text,
  latitude double precision,
  longitude double precision,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.depot_zones (
  id uuid primary key default gen_random_uuid(),
  depot_id uuid not null references public.depots(id) on delete cascade,
  name text not null,
  description text,
  created_at timestamptz not null default now()
);

create unique index depot_zones_depot_name_key on public.depot_zones(depot_id, name);

create table public.app_settings (
  id uuid primary key default gen_random_uuid(),
  org_name text not null default 'SafeDepot Services',
  logo_url text,
  default_language text not null default 'en',
  timezone text not null default 'UTC',
  currency text not null default 'USD',
  enable_ai_reminders boolean not null default false,
  ai_reminder_window_days int not null default 7,
  reminder_frequency text not null default 'overdue',
  reminder_time text not null default '08:00',
  reminder_message text,
  json_version text not null default '1',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.app_settings (id) values (gen_random_uuid());