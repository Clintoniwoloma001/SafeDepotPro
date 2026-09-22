-- 0007_checklists_and_inspections.sql — checklist templates, inspections, answers.

create table public.checklist_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text not null default 'HSE' check (type in ('HSE', 'TRUCK')),
  description text,
  sections jsonb not null default '[]',
  is_factory boolean not null default false,
  is_active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.inspections (
  id uuid primary key default gen_random_uuid(),
  depot_id uuid references public.depots(id) on delete set null,
  template_id uuid references public.checklist_templates(id) on delete set null,
  checklist_name text not null,
  type text not null default 'HSE' check (type in ('HSE', 'TRUCK')),
  status public.inspection_status not null default 'SUBMITTED',
  completed_by uuid references public.profiles(id) on delete set null,
  answers jsonb not null default '[]',
  compliance numeric default 0,
  notes text,
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.inspection_answers (
  id uuid primary key default gen_random_uuid(),
  inspection_id uuid not null references public.inspections(id) on delete cascade,
  question_id text not null,
  response public.inspection_response,
  severity public.severity,
  comment text,
  photo_paths text[] not null default '{}',
  created_at timestamptz not null default now()
);