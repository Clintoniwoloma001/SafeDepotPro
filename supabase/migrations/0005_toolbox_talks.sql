-- 0005_toolbox_talks.sql — toolbox talk records + attendee signatures.

create table public.toolbox_talks (
  id uuid primary key default gen_random_uuid(),
  depot_id uuid not null references public.depots(id) on delete cascade,
  title text not null,
  description text,
  company text not null default 'SafeDepot Services',
  location text,
  date text not null,
  time text not null,
  facilitator text,
  category text,
  is_high_risk boolean not null default false,
  tag text,
  photo_paths text[] not null default '{}',
  latitude double precision,
  longitude double precision,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.toolbox_attendees (
  id uuid primary key default gen_random_uuid(),
  toolbox_talk_id uuid not null references public.toolbox_talks(id) on delete cascade,
  name text not null,
  employee_number text,
  signature_path text,
  signed_at timestamptz default now(),
  created_at timestamptz not null default now()
);