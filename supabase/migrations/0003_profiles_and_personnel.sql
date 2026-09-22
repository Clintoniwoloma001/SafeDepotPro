-- 0003_profiles_and_personnel.sql — auth-linked profiles + personnel directory.

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role public.user_role not null default 'USER',
  depot_id uuid references public.depots(id) on delete set null,
  phone text,
  preferred_language text not null default 'en',
  avatar_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.personnel (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  depot_id uuid references public.depots(id) on delete set null,
  type text not null default 'EMPLOYEE',
  employee_number text unique,
  job_title text,
  email text,
  phone text,
  national_id text,
  date_of_birth date,
  address text,
  emergency_contact_name text,
  emergency_contact_phone text,
  start_date date,
  contract_end_date date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);