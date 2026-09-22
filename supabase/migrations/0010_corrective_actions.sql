-- 0010_corrective_actions.sql — CAPA records with source linkage, assignment, proof & closure.

create table public.capa (
  id uuid primary key default gen_random_uuid(),
  depot_id uuid not null references public.depots(id) on delete cascade,
  capa_number text not null unique,
  title text not null,
  source_type text not null default 'STANDALONE' check (source_type in ('STANDALONE', 'INCIDENT', 'HAZARD', 'INSPECTION', 'TRUCK_INSPECTION', 'AUDIT')),
  source_id uuid,
  description text,
  root_cause text,
  corrective_action text,
  responsible_user_id uuid references public.profiles(id) on delete set null,
  responsible_name text,
  assigner_user_id uuid references public.profiles(id) on delete set null,
  assigner_name text,
  priority public.priority not null default 'MEDIUM',
  status public.capa_status not null default 'OPEN',
  due_date date,
  completion_rate int not null default 0 check (completion_rate between 0 and 100),
  proof_paths text[] not null default '{}',
  signature_path text,
  completed_at timestamptz,
  completed_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);