-- © Flatra Tech Ltd. All rights reserved.
-- Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
-- Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
-- Contact: +2349025975247
-- 0027_comprehensive_features.sql — truck inspection templates, task reminders, toolbox topics, app settings, storage buckets.

-- Ensure app_settings exists (created in 0002, but add missing columns if any)
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'app_settings' and column_name = 'org_name'
  ) then
    alter table public.app_settings add column org_name text not null default 'SafeDepot Services';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'app_settings' and column_name = 'logo_url'
  ) then
    alter table public.app_settings add column logo_url text;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'app_settings' and column_name = 'default_language'
  ) then
    alter table public.app_settings add column default_language text not null default 'en';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'app_settings' and column_name = 'timezone'
  ) then
    alter table public.app_settings add column timezone text not null default 'UTC';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'app_settings' and column_name = 'currency'
  ) then
    alter table public.app_settings add column currency text not null default 'USD';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'app_settings' and column_name = 'enable_ai_reminders'
  ) then
    alter table public.app_settings add column enable_ai_reminders boolean not null default true;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'app_settings' and column_name = 'ai_reminder_window_days'
  ) then
    alter table public.app_settings add column ai_reminder_window_days int not null default 7;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'app_settings' and column_name = 'reminder_frequency'
  ) then
    alter table public.app_settings add column reminder_frequency text not null default 'overdue';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'app_settings' and column_name = 'reminder_time'
  ) then
    alter table public.app_settings add column reminder_time text not null default '08:00';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'app_settings' and column_name = 'reminder_message'
  ) then
    alter table public.app_settings add column reminder_message text;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'app_settings' and column_name = 'json_version'
  ) then
    alter table public.app_settings add column json_version text not null default '1';
  end if;
end $$;

-- Truck inspection templates (global, admin-managed)
create table if not exists public.truck_inspection_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  version text not null default '1.0',
  is_active boolean not null default true,
  is_factory boolean not null default false,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.truck_inspection_template_items (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.truck_inspection_templates(id) on delete cascade,
  section text not null,
  question_text text not null,
  weight numeric not null default 1 check (weight > 0),
  is_critical boolean not null default false,
  requires_photo boolean not null default false,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists truck_inspection_template_items_template_idx on public.truck_inspection_template_items(template_id);

-- Task reminders configuration (per task)
create table if not exists public.task_reminders (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.routine_tasks(id) on delete cascade,
  enabled boolean not null default true,
  reminder_before_minutes int not null default 60, -- remind X minutes before due
  reminder_after_overdue_minutes int not null default 0, -- 0 = disabled, else remind X minutes after overdue
  channels text[] not null default '{push,email}', -- push, email, sms
  recipient_role text check (recipient_role in ('ASSIGNEE', 'SUPERVISOR', 'ADMIN', 'ALL_DEPOT')),
  custom_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists task_reminders_task_idx on public.task_reminders(task_id);

-- Toolbox talk topics (shared across depots, weekly rotation)
create table if not exists public.toolbox_topics (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  content text not null,
  category text,
  is_high_risk boolean not null default false,
  week_of_year int check (week_of_year between 1 and 53), -- for weekly rotation
  is_active boolean not null default true,
  is_factory boolean not null default false,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists toolbox_topics_week_idx on public.toolbox_topics(week_of_year) where week_of_year is not null;

-- Toolbox talk images (separate table for multiple images per talk)
create table if not exists public.toolbox_talk_images (
  id uuid primary key default gen_random_uuid(),
  toolbox_talk_id uuid not null references public.toolbox_talks(id) on delete cascade,
  storage_path text not null,
  caption text,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists toolbox_talk_images_talk_idx on public.toolbox_talk_images(toolbox_talk_id);

-- Enhanced toolbox attendees (already exists in 0005, add missing columns)
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'toolbox_attendees' and column_name = 'employee_number'
  ) then
    alter table public.toolbox_attendees add column employee_number text;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'toolbox_attendees' and column_name = 'signature_path'
  ) then
    alter table public.toolbox_attendees add column signature_path text;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'toolbox_attendees' and column_name = 'signed_at'
  ) then
    alter table public.toolbox_attendees add column signed_at timestamptz default now();
  end if;
end $$;

-- Add signature_path to truck_inspections if missing (from 0025)
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'truck_inspections' and column_name = 'signature_path'
  ) then
    alter table public.truck_inspections add column signature_path text;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'truck_inspections' and column_name = 'template_id'
  ) then
    alter table public.truck_inspections add column template_id uuid references public.truck_inspection_templates(id) on delete set null;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'truck_inspections' and column_name = 'answers_json'
  ) then
    alter table public.truck_inspections add column answers_json jsonb not null default '[]';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'truck_inspections' and column_name = 'compliance_score'
  ) then
    alter table public.truck_inspections add column compliance_score numeric default 0;
  end if;
end $$;

-- Add missing columns to trucks table (backfill depot_id for existing trucks)
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'trucks' and column_name = 'company'
  ) then
    alter table public.trucks add column company text;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'trucks' and column_name = 'driver_name'
  ) then
    alter table public.trucks add column driver_name text;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'trucks' and column_name = 'driver_phone'
  ) then
    alter table public.trucks add column driver_phone text;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'trucks' and column_name = 'make_model'
  ) then
    alter table public.trucks add column make_model text;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'trucks' and column_name = 'year'
  ) then
    alter table public.trucks add column year int;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'trucks' and column_name = 'color'
  ) then
    alter table public.trucks add column color text;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'trucks' and column_name = 'qr_code_url'
  ) then
    alter table public.trucks add column qr_code_url text;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'trucks' and column_name = 'last_inspection_date'
  ) then
    alter table public.trucks add column last_inspection_date date;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'trucks' and column_name = 'last_inspection_result'
  ) then
    alter table public.trucks add column last_inspection_result text;
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'trucks' and column_name = 'next_inspection_date'
  ) then
    alter table public.trucks add column next_inspection_date date;
  end if;
end $$;

-- Updated_at triggers for new tables
drop trigger if exists trg_truck_inspection_templates_updated_at on public.truck_inspection_templates;
create trigger trg_truck_inspection_templates_updated_at
  before update on public.truck_inspection_templates
  for each row execute function public.set_updated_at();

drop trigger if exists trg_truck_inspection_template_items_updated_at on public.truck_inspection_template_items;
create trigger trg_truck_inspection_template_items_updated_at
  before update on public.truck_inspection_template_items
  for each row execute function public.set_updated_at();

drop trigger if exists trg_task_reminders_updated_at on public.task_reminders;
create trigger trg_task_reminders_updated_at
  before update on public.task_reminders
  for each row execute function public.set_updated_at();

drop trigger if exists trg_toolbox_topics_updated_at on public.toolbox_topics;
create trigger trg_toolbox_topics_updated_at
  before update on public.toolbox_topics
  for each row execute function public.set_updated_at();

drop trigger if exists trg_toolbox_talk_images_updated_at on public.toolbox_talk_images;
create trigger trg_toolbox_talk_images_updated_at
  before update on public.toolbox_talk_images
  for each row execute function public.set_updated_at();

-- RLS Policies for new tables

-- truck_inspection_templates: admins manage, all authenticated read
alter table public.truck_inspection_templates enable row level security;

drop policy if exists truck_inspection_templates_read on public.truck_inspection_templates;
create policy truck_inspection_templates_read on public.truck_inspection_templates
  for select to authenticated using (true);

drop policy if exists truck_inspection_templates_write on public.truck_inspection_templates;
create policy truck_inspection_templates_write on public.truck_inspection_templates
  for insert to authenticated with check (public.is_admin());

drop policy if exists truck_inspection_templates_update on public.truck_inspection_templates;
create policy truck_inspection_templates_update on public.truck_inspection_templates
  for update to authenticated using (public.is_admin() or (not is_factory and created_by = auth.uid()));

drop policy if exists truck_inspection_templates_delete on public.truck_inspection_templates;
create policy truck_inspection_templates_delete on public.truck_inspection_templates
  for delete to authenticated using (public.is_admin() or (not is_factory and created_by = auth.uid()));

-- truck_inspection_template_items: same as templates
alter table public.truck_inspection_template_items enable row level security;

drop policy if exists truck_inspection_template_items_read on public.truck_inspection_template_items;
create policy truck_inspection_template_items_read on public.truck_inspection_template_items
  for select to authenticated using (true);

drop policy if exists truck_inspection_template_items_write on public.truck_inspection_template_items;
create policy truck_inspection_template_items_write on public.truck_inspection_template_items
  for insert to authenticated with check (public.is_admin());

drop policy if exists truck_inspection_template_items_update on public.truck_inspection_template_items;
create policy truck_inspection_template_items_update on public.truck_inspection_template_items
  for update to authenticated using (public.is_admin());

drop policy if exists truck_inspection_template_items_delete on public.truck_inspection_template_items;
create policy truck_inspection_template_items_delete on public.truck_inspection_template_items
  for delete to authenticated using (public.is_admin());

-- task_reminders: admin manages, assignee reads
alter table public.task_reminders enable row level security;

drop policy if exists task_reminders_read on public.task_reminders;
create policy task_reminders_read on public.task_reminders
  for select to authenticated using (
    public.is_admin()
    or task_id in (select id from public.routine_tasks where assigned_user_ids @> array[auth.uid()])
    or task_id in (select id from public.routine_tasks where assigned_depot_ids @> array[(select depot_id from public.profiles where id = auth.uid() and is_active)])
    or task_id in (select id from public.routine_tasks where all_depots)
  );

drop policy if exists task_reminders_write on public.task_reminders;
create policy task_reminders_write on public.task_reminders
  for insert to authenticated with check (public.is_admin());

create policy task_reminders_update on public.task_reminders
  for update to authenticated using (public.is_admin());

create policy task_reminders_delete on public.task_reminders
  for delete to authenticated using (public.is_admin());

-- toolbox_topics: all read, admin manages
alter table public.toolbox_topics enable row level security;

create policy toolbox_topics_read on public.toolbox_topics
  for select to authenticated using (is_active);

create policy toolbox_topics_write on public.toolbox_topics
  for insert to authenticated with check (public.is_admin());

create policy toolbox_topics_update on public.toolbox_topics
  for update to authenticated using (public.is_admin() or (not is_factory and created_by = auth.uid()));

create policy toolbox_topics_delete on public.toolbox_topics
  for delete to authenticated using (public.is_admin() or (not is_factory and created_by = auth.uid()));

-- toolbox_talk_images: read if can read talk, insert if can read talk
alter table public.toolbox_talk_images enable row level security;

create policy toolbox_talk_images_read on public.toolbox_talk_images
  for select to authenticated using (
    toolbox_talk_id in (select id from public.toolbox_talks where public.can_read_depot(depot_id))
  );

create policy toolbox_talk_images_insert on public.toolbox_talk_images
  for insert to authenticated with check (
    toolbox_talk_id in (select id from public.toolbox_talks where public.can_read_depot(depot_id))
  );

create policy toolbox_talk_images_update on public.toolbox_talk_images
  for update to authenticated using (public.is_admin());

create policy toolbox_talk_images_delete on public.toolbox_talk_images
  for delete to authenticated using (public.is_admin());

-- Ensure storage buckets exist for new content types
insert into storage.buckets (id, name, public) values
  ('toolbox-images', 'toolbox-images', true),
  ('truck-inspection-photos', 'truck-inspection-photos', true),
  ('company-assets', 'company-assets', true)
on conflict (id) do nothing;

create policy if not exists toolbox_images_read on storage.objects
  for select to authenticated using (bucket_id = 'toolbox-images');

create policy if not exists toolbox_images_insert on storage.objects
  for insert to authenticated with check (bucket_id = 'toolbox-images');

create policy if not exists truck_inspection_photos_read on storage.objects
  for select to authenticated using (bucket_id = 'truck-inspection-photos');

create policy if not exists truck_inspection_photos_insert on storage.objects
  for insert to authenticated with check (bucket_id = 'truck-inspection-photos');

create policy if not exists company_assets_read on storage.objects
  for select to authenticated using (bucket_id = 'company-assets');

create policy if not exists company_assets_insert on storage.objects
  for insert to authenticated with check (bucket_id = 'company-assets' and public.is_admin());

create policy if not exists company_assets_update on storage.objects
  for update to authenticated using (bucket_id = 'company-assets' and public.is_admin());

create policy if not exists company_assets_delete on storage.objects
  for delete to authenticated using (bucket_id = 'company-assets' and public.is_admin());