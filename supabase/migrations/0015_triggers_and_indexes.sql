-- 0015_triggers_and_indexes.sql — updated_at bookkeeping, signup profile stamp, supporting indexes.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$ begin
  new.updated_at := now();
  return new;
end $$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''),
          coalesce((new.raw_user_meta_data ->> 'role')::public.user_role, 'USER'::public.user_role))
  on conflict (id) do nothing;
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create trigger trg_depots_updated_at before update on public.depots for each row execute function public.set_updated_at();
create trigger trg_profiles_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger trg_personnel_updated_at before update on public.personnel for each row execute function public.set_updated_at();
create trigger trg_routine_tasks_updated_at before update on public.routine_tasks for each row execute function public.set_updated_at();
create trigger trg_toolbox_talks_updated_at before update on public.toolbox_talks for each row execute function public.set_updated_at();
create trigger trg_permits_updated_at before update on public.permits for each row execute function public.set_updated_at();
create trigger trg_checklist_templates_updated_at before update on public.checklist_templates for each row execute function public.set_updated_at();
create trigger trg_inspections_updated_at before update on public.inspections for each row execute function public.set_updated_at();
create trigger trg_trucks_updated_at before update on public.trucks for each row execute function public.set_updated_at();
create trigger trg_truck_inspections_updated_at before update on public.truck_inspections for each row execute function public.set_updated_at();
create trigger trg_incidents_updated_at before update on public.incidents for each row execute function public.set_updated_at();
create trigger trg_hazards_updated_at before update on public.hazards for each row execute function public.set_updated_at();
create trigger trg_capa_updated_at before update on public.capa for each row execute function public.set_updated_at();
create trigger trg_assets_updated_at before update on public.assets for each row execute function public.set_updated_at();
create trigger trg_man_hours_updated_at before update on public.man_hours for each row execute function public.set_updated_at();
create trigger trg_shift_handovers_updated_at before update on public.shift_handovers for each row execute function public.set_updated_at();
create trigger trg_stand_ins_updated_at before update on public.stand_ins for each row execute function public.set_updated_at();
create trigger trg_assistant_documents_updated_at before update on public.assistant_documents for each row execute function public.set_updated_at();
create trigger trg_app_settings_updated_at before update on public.app_settings for each row execute function public.set_updated_at();

create index routine_tasks_active_idx on public.routine_tasks(is_active) where is_active;
create index toolbox_talks_depot_date_idx on public.toolbox_talks(depot_id, date desc);
create index permits_depot_status_idx on public.permits(depot_id, status);
create index inspections_depot_status_idx on public.inspections(depot_id, status);
create index trucks_depot_active_idx on public.trucks(depot_id, is_active);
create index incidents_depot_date_idx on public.incidents(depot_id, occurred_at desc);
create index hazards_depot_status_idx on public.hazards(depot_id, status);
create index capa_depot_status_idx on public.capa(depot_id, status, due_date);
create index assets_depot_tag_idx on public.assets(depot_id, asset_tag);

-- Audit log used by the platform source-download endpoint.
create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid,
  actor_name text,
  action text not null,
  target text,
  meta jsonb,
  created_at timestamptz not null default now()
);

create index audit_log_created_at_idx on public.audit_log(created_at desc);