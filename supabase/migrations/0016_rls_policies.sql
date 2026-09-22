-- 0016_rls_policies.sql — Row Level Security per role for every table + storage buckets.

-- Role predicates.
create or replace function public.is_superadmin()
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.profiles where id = auth.uid() and role = 'SUPERADMIN' and is_active) $$;

create or replace function public.is_country_head()
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.profiles where id = auth.uid() and role in ('COUNTRY_HEAD', 'SUPERADMIN') and is_active) $$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.profiles where id = auth.uid() and role in ('ADMIN', 'COUNTRY_HEAD', 'SUPERADMIN') and is_active) $$;

-- Read helper: management sees all depots, regular users see only their own (or covered) depot.
create or replace function public.can_read_depot(depot_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select public.is_country_head()
      or depot_id in (
        select p.depot_id from public.profiles p where p.id = auth.uid() and p.is_active
        union
        select s.covering_depot_id from public.stand_ins s
          where s.user_id = auth.uid() and s.status = 'ACTIVE'
            and current_date between s.start_date and s.end_date
      )
$$;

alter table public.depots enable row level security;
alter table public.depot_zones enable row level security;
alter table public.app_settings enable row level security;
alter table public.profiles enable row level security;
alter table public.personnel enable row level security;
alter table public.routine_tasks enable row level security;
alter table public.task_history enable row level security;
alter table public.toolbox_talks enable row level security;
alter table public.toolbox_attendees enable row level security;
alter table public.permits enable row level security;
alter table public.checklist_templates enable row level security;
alter table public.inspections enable row level security;
alter table public.inspection_answers enable row level security;
alter table public.trucks enable row level security;
alter table public.truck_inspections enable row level security;
alter table public.incidents enable row level security;
alter table public.hazards enable row level security;
alter table public.capa enable row level security;
alter table public.assets enable row level security;
alter table public.man_hours enable row level security;
alter table public.shift_handovers enable row level security;
alter table public.stand_ins enable row level security;
alter table public.assistant_documents enable row level security;
alter table public.audit_log enable row level security;

-- depots
create policy depots_read on public.depots for select to authenticated using (public.can_read_depot(id));
create policy depots_write on public.depots for insert to authenticated with check (public.is_admin());
create policy depots_update on public.depots for update to authenticated using (public.is_admin());
create policy depots_delete on public.depots for delete to authenticated using (public.is_country_head());

-- depot_zones
create policy zones_read on public.depot_zones for select to authenticated using (public.can_read_depot(depot_id));
create policy zones_write on public.depot_zones for insert to authenticated with check (public.is_admin());
create policy zones_update on public.depot_zones for update to authenticated using (public.is_admin());
create policy zones_delete on public.depot_zones for delete to authenticated using (public.is_admin());

-- app_settings
create policy settings_read on public.app_settings for select to authenticated using (true);
create policy settings_write on public.app_settings for insert to authenticated with check (public.is_superadmin());
create policy settings_update on public.app_settings for update to authenticated using (public.is_superadmin());

-- profiles: self + managed-user lists
create policy profiles_read on public.profiles for select to authenticated using (true);
create policy profiles_update_self on public.profiles for update to authenticated using (auth.uid() = id);
create policy profiles_update_manage on public.profiles for update to authenticated using (public.is_admin());
create policy profiles_insert on public.profiles for insert to authenticated with check (public.is_admin());

-- personnel
create policy personnel_read on public.personnel for select to authenticated using (public.can_read_depot(depot_id));
create policy personnel_write on public.personnel for insert to authenticated with check (public.is_admin());
create policy personnel_update on public.personnel for update to authenticated using (public.is_admin());
create policy personnel_delete on public.personnel for delete to authenticated using (public.is_admin());

-- routine_tasks
create policy tasks_read on public.routine_tasks for select to authenticated using (public.is_country_head() or assigned_depot_ids && array(select p.depot_id from public.profiles p where p.id = auth.uid() and p.is_active) or all_depots);
create policy tasks_write on public.routine_tasks for insert to authenticated with check (public.is_admin());
create policy tasks_update on public.routine_tasks for update to authenticated using (public.is_admin());
create policy tasks_delete on public.routine_tasks for delete to authenticated using (public.is_admin());

-- task_history
create policy history_read on public.task_history for select to authenticated using (public.can_read_depot(depot_id));
create policy history_insert on public.task_history for insert to authenticated with check (user_id = auth.uid() or public.is_admin());
create policy history_update on public.task_history for update to authenticated using (public.is_admin());
create policy history_delete on public.task_history for delete to authenticated using (public.is_admin());

-- toolbox_talks
create policy toolbox_read on public.toolbox_talks for select to authenticated using (public.can_read_depot(depot_id));
create policy toolbox_insert on public.toolbox_talks for insert to authenticated with check (public.can_read_depot(depot_id));
create policy toolbox_update on public.toolbox_talks for update to authenticated using (public.is_admin() or created_by = auth.uid());
create policy toolbox_delete on public.toolbox_talks for delete to authenticated using (public.is_admin());

-- toolbox_attendees
create policy attendees_read on public.toolbox_attendees for select to authenticated using (true);
create policy attendees_insert on public.toolbox_attendees for insert to authenticated with check (true);
create policy attendees_update on public.toolbox_attendees for update to authenticated using (public.is_admin());
create policy attendees_delete on public.toolbox_attendees for delete to authenticated using (public.is_admin());

-- permits
create policy permits_read on public.permits for select to authenticated using (public.can_read_depot(depot_id));
create policy permits_insert on public.permits for insert to authenticated with check (public.can_read_depot(depot_id));
create policy permits_update on public.permits for update to authenticated using (public.is_admin() or created_by = auth.uid());
create policy permits_delete on public.permits for delete to authenticated using (public.is_admin());

-- checklist_templates
create policy templates_read on public.checklist_templates for select to authenticated using (true);
create policy templates_write on public.checklist_templates for insert to authenticated with check (public.is_admin());
create policy templates_update on public.checklist_templates for update to authenticated using (public.is_admin() or (not is_factory and created_by = auth.uid()));
create policy templates_delete on public.checklist_templates for delete to authenticated using (public.is_admin() or (not is_factory and created_by = auth.uid()));

-- inspections
create policy inspections_read on public.inspections for select to authenticated using (public.can_read_depot(depot_id));
create policy inspections_insert on public.inspections for insert to authenticated with check (public.can_read_depot(depot_id));
create policy inspections_update on public.inspections for update to authenticated using (public.is_admin() or completed_by = auth.uid());
create policy inspections_delete on public.inspections for delete to authenticated using (public.is_admin());

-- inspection_answers
create policy answers_read on public.inspection_answers for select to authenticated using (true);
create policy answers_insert on public.inspection_answers for insert to authenticated with check (true);
create policy answers_update on public.inspection_answers for update to authenticated using (public.is_admin());
create policy answers_delete on public.inspection_answers for delete to authenticated using (public.is_admin());

-- trucks
create policy trucks_read on public.trucks for select to authenticated using (public.can_read_depot(depot_id));
create policy trucks_write on public.trucks for insert to authenticated with check (public.is_admin());
create policy trucks_update on public.trucks for update to authenticated using (public.is_admin());
create policy trucks_delete on public.trucks for delete to authenticated using (public.is_admin());

-- truck_inspections
create policy truck_insp_read on public.truck_inspections for select to authenticated using (public.can_read_depot(depot_id));
create policy truck_insp_insert on public.truck_inspections for insert to authenticated with check (public.can_read_depot(depot_id));
create policy truck_insp_update on public.truck_inspections for update to authenticated using (public.is_admin() or completed_by = auth.uid());
create policy truck_insp_delete on public.truck_inspections for delete to authenticated using (public.is_admin());

-- incidents
create policy incidents_read on public.incidents for select to authenticated using (public.can_read_depot(depot_id));
create policy incidents_insert on public.incidents for insert to authenticated with check (public.can_read_depot(depot_id));
create policy incidents_update on public.incidents for update to authenticated using (public.is_admin() or reported_by = auth.uid());
create policy incidents_delete on public.incidents for delete to authenticated using (public.is_admin());

-- hazards
create policy hazards_read on public.hazards for select to authenticated using (public.can_read_depot(depot_id));
create policy hazards_insert on public.hazards for insert to authenticated with check (public.can_read_depot(depot_id));
create policy hazards_update on public.hazards for update to authenticated using (public.is_admin() or reported_by = auth.uid());
create policy hazards_delete on public.hazards for delete to authenticated using (public.is_admin());

-- capa
create policy capa_read on public.capa for select to authenticated using (public.can_read_depot(depot_id));
create policy capa_insert on public.capa for insert to authenticated with check (public.can_read_depot(depot_id));
create policy capa_update on public.capa for update to authenticated using (public.is_admin() or responsible_user_id = auth.uid());
create policy capa_delete on public.capa for delete to authenticated using (public.is_admin());

-- assets
create policy assets_read on public.assets for select to authenticated using (public.can_read_depot(depot_id));
create policy assets_write on public.assets for insert to authenticated with check (public.is_admin());
create policy assets_update on public.assets for update to authenticated using (public.is_admin());
create policy assets_delete on public.assets for delete to authenticated using (public.is_admin());

-- man_hours
create policy man_hours_read on public.man_hours for select to authenticated using (public.can_read_depot(depot_id));
create policy man_hours_write on public.man_hours for insert to authenticated with check (public.is_admin());
create policy man_hours_update on public.man_hours for update to authenticated using (public.is_admin());
create policy man_hours_delete on public.man_hours for delete to authenticated using (public.is_admin());

-- shift_handovers
create policy handover_read on public.shift_handovers for select to authenticated using (public.can_read_depot(depot_id));
create policy handover_insert on public.shift_handovers for insert to authenticated with check (public.can_read_depot(depot_id));
create policy handover_update on public.shift_handovers for update to authenticated using (public.is_admin() or outgoing_user_id = auth.uid() or incoming_user_id = auth.uid());
create policy handover_delete on public.shift_handovers for delete to authenticated using (public.is_admin());

-- stand_ins
create policy stand_in_read on public.stand_ins for select to authenticated using (public.is_country_head() or user_id = auth.uid() or covering_user_id = auth.uid());
create policy stand_in_insert on public.stand_ins for insert to authenticated with check (user_id = auth.uid() or public.is_admin());
create policy stand_in_update on public.stand_ins for update to authenticated using (public.is_admin() or user_id = auth.uid() or covering_user_id = auth.uid());
create policy stand_in_delete on public.stand_ins for delete to authenticated using (public.is_admin());

-- assistant_documents
create policy rag_docs_read on public.assistant_documents for select to authenticated using (true);
create policy rag_docs_write on public.assistant_documents for insert to authenticated with check (public.is_superadmin());
create policy rag_docs_update on public.assistant_documents for update to authenticated using (public.is_superadmin());
create policy rag_docs_delete on public.assistant_documents for delete to authenticated using (public.is_superadmin());

-- audit_log: only administrators inspect, server key writes.
create policy audit_read on public.audit_log for select to authenticated using (public.is_superadmin());
create policy audit_write on public.audit_log for insert to authenticated with check (public.is_superadmin());

-- Storage buckets + policies.
insert into storage.buckets (id, name, public) values
  ('photos', 'photos', true),
  ('signatures', 'signatures', true),
  ('capa-proof', 'capa-proof', true)
on conflict (id) do nothing;

create policy photos_read on storage.objects for select to authenticated using (bucket_id in ('photos', 'signatures', 'capa-proof'));
create policy photos_insert on storage.objects for insert to authenticated with check (bucket_id in ('photos', 'signatures', 'capa-proof'));
create policy photos_update on storage.objects for update to authenticated using (public.is_admin());
create policy photos_delete on storage.objects for delete to authenticated using (public.is_admin());