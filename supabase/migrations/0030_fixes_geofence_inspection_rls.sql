-- © Flatra Tech Ltd. All rights reserved.
-- 0030: fixes for inspection types RLS, depot geofence columns + audit, geofence block RPC.

-- 1. RLS for lowercase template tables (so "Select Inspection Type" lists types).
alter table public.truck_inspection_templates enable row level security;
alter table public.truck_inspection_template_items enable row level security;

drop policy if exists truck_inspection_templates_read on public.truck_inspection_templates;
create policy truck_inspection_templates_read on public.truck_inspection_templates
  for select to authenticated using (true);

drop policy if exists truck_inspection_templates_write on public.truck_inspection_templates;
create policy truck_inspection_templates_write on public.truck_inspection_templates
  for insert to authenticated with check (public.is_admin());

drop policy if exists truck_inspection_templates_update on public.truck_inspection_templates;

drop policy if exists truck_inspection_templates_delete on public.truck_inspection_templates;

drop policy if exists truck_inspection_template_items_read on public.truck_inspection_template_items;
create policy truck_inspection_template_items_read on public.truck_inspection_template_items
  for select to authenticated using (true);

drop policy if exists truck_inspection_template_items_write on public.truck_inspection_template_items;
create policy truck_inspection_template_items_write on public.truck_inspection_template_items
  for insert to authenticated with check (public.is_admin());

drop policy if exists truck_inspection_template_items_update on public.truck_inspection_template_items;

drop policy if exists truck_inspection_template_items_delete on public.truck_inspection_template_items;

-- 2. Depot geofence columns.
alter table public.depots add column if not exists geofence_enabled boolean not null default false;
alter table public.depots add column if not exists geofence_mode text not null default 'off';
alter table public.depots add column if not exists geofence_actions jsonb not null default '["inspections","permits","handovers"]'::jsonb;
alter table public.depots add column if not exists timezone text not null default 'Africa/Lagos';

-- 3. Depot audit log.
create table if not exists public.depots_audit (
  id uuid primary key default gen_random_uuid(),
  depot_id uuid references public.depots(id) on delete cascade,
  changed_by uuid references auth.users(id),
  changed_at timestamptz not null default now(),
  action text not null,
  before jsonb,
  after jsonb
);

alter table public.depots_audit enable row level security;
drop policy if exists depots_audit_read on public.depots_audit;
create policy depots_audit_read on public.depots_audit
  for select to authenticated using (public.is_country_head());
drop policy if exists depots_audit_insert on public.depots_audit;
create policy depots_audit_insert on public.depots_audit
  for insert to authenticated with check (public.is_admin());

-- trigger to log depot updates
create or replace function public.log_depot_change()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.depots_audit (depot_id, changed_by, action, before, after)
  values (OLD.id, auth.uid(), TG_OP, to_jsonb(OLD), to_jsonb(NEW));
  return NEW;
end;
$$;

drop trigger if exists trg_depot_audit on public.depots;
create trigger trg_depot_audit
  after update on public.depots
  for each row execute function public.log_depot_change();

-- 4. Server-side geofence block RPC.
create or replace function public.check_geofence(
  p_depot_id uuid,
  p_lat double precision,
  p_lng double precision
) returns boolean language plpgsql security definer set search_path = public
as $$
declare
  d record;
  dist double precision;
begin
  select latitude, longitude, geofence_enabled, geofence_mode, geofence_radius_meters, allowed_radius_meters
    into d from public.depots where id = p_depot_id;
  if not found or d.geofence_enabled is false or d.geofence_mode <> 'block' then
    return true;
  end if;
  if d.latitude is null or d.longitude is null then
    return true;
  end if;
  -- haversine
  dist := 2 * 6371000 * asin(sqrt(
    power(sin(radians(p_lat - d.latitude)/2),2) +
    cos(radians(d.latitude)) * cos(radians(p_lat)) *
    power(sin(radians(p_lng - d.longitude)/2),2)
  ));
  return dist <= coalesce(d.geofence_radius_meters, d.allowed_radius_meters, 50);
end;
$$;

grant execute on function public.check_geofence(uuid, double precision, double precision) to authenticated;
