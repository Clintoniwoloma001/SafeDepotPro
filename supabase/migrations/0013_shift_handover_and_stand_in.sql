-- 0013_shift_handover_and_stand_in.sql — shift handovers + stand-in coverage.

create table public.shift_handovers (
  id uuid primary key default gen_random_uuid(),
  depot_id uuid not null references public.depots(id) on delete cascade,
  shift text not null default 'DAY' check (shift in ('DAY', 'NIGHT')),
  date text not null,
  outgoing_user_id uuid references public.profiles(id) on delete set null,
  incoming_user_id uuid references public.profiles(id) on delete set null,
  summary text,
  pending_issues text[] not null default '{}',
  equipment_notes text,
  photo_paths text[] not null default '{}',
  status public.shift_status not null default 'PENDING',
  signature_outgoing text,
  signature_incoming text,
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.stand_ins (
  id uuid primary key default gen_random_uuid(),
  depot_id uuid not null references public.depots(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  covering_user_id uuid not null references auth.users(id) on delete cascade,
  covering_depot_id uuid references public.depots(id) on delete set null,
  start_date date not null,
  end_date date not null,
  reason text,
  status public.stand_in_status not null default 'PENDING',
  created_by uuid references public.profiles(id) on delete set null,
  reviewed_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);