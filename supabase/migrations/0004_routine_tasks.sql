-- 0004_routine_tasks.sql — recurring task templates + completion history.

create table public.routine_tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  task_type public.completion_method not null default 'MANUAL',
  category text,
  all_depots boolean not null default false,
  assigned_depot_ids uuid[] not null default '{}',
  assigned_user_ids uuid[] not null default '{}',
  frequency public.frequency not null default 'DAILY',
  monthly_dates int[] not null default '{1}',
  start_date date not null default current_date,
  end_date date,
  expected_occurrences int,
  linked_module text check (linked_module in ('TOOLBOX', 'HOUSEKEEPING')),
  ai_prompt text,
  requires_photo_on_completion boolean not null default false,
  is_active boolean not null default true,
  sequence_order int not null default 0,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.task_history (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.routine_tasks(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  actor_name text,
  depot_id uuid references public.depots(id) on delete set null,
  completed_at timestamptz not null default now(),
  occurrences int not null default 1,
  expected_occurrences int,
  comment text,
  photo_paths text[] not null default '{}',
  signature_path text,
  latitude double precision,
  longitude double precision,
  ai_verified boolean not null default false,
  form_answers jsonb,
  attendance_count int,
  created_at timestamptz not null default now()
);