-- 0009_incidents_and_hazards.sql — incident log + hazard observation with risk scoring.

create table public.incidents (
  id uuid primary key default gen_random_uuid(),
  depot_id uuid not null references public.depots(id) on delete cascade,
  incident_number text not null unique,
  occurred_at timestamptz not null default now(),
  incident_type text,
  severity public.severity not null default 'MEDIUM',
  description text not null,
  root_cause text,
  actions_taken text,
  involved_personnel jsonb not null default '[]',
  photo_paths text[] not null default '{}',
  status public.incident_status not null default 'OPEN',
  reported_by uuid references public.profiles(id) on delete set null,
  reported_by_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.hazards (
  id uuid primary key default gen_random_uuid(),
  depot_id uuid not null references public.depots(id) on delete cascade,
  location text,
  description text not null,
  hazard_type text,
  likelihood int not null default 3 check (likelihood between 1 and 5),
  severity public.severity not null default 'MEDIUM',
  risk_score int check (risk_score between 1 and 25),
  risk_rating text,
  reported_by uuid references public.profiles(id) on delete set null,
  reported_by_name text,
  photo_paths text[] not null default '{}',
  corrective_action text,
  controlled_confirmed boolean not null default false,
  status public.hazard_status not null default 'OPEN',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);