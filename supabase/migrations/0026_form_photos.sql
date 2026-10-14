-- © Flatra Tech Ltd. All rights reserved.
-- Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
-- Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
-- Contact: +2349025975247
-- 0026_form_photos.sql — add photo_paths to shift_handovers, truck_inspections, inspections.

-- shift_handovers already has photo_paths (from 0013), but ensure it exists
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'shift_handovers' and column_name = 'photo_paths'
  ) then
    alter table public.shift_handovers add column photo_paths text[] not null default '{}';
  end if;
end $$;

-- truck_inspections: add generic photo_paths column (distinct from photographed_issues)
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'truck_inspections' and column_name = 'photo_paths'
  ) then
    alter table public.truck_inspections add column photo_paths text[] not null default '{}';
  end if;
end $$;

-- inspections: add generic photo_paths column for inspection-level photos
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'inspections' and column_name = 'photo_paths'
  ) then
    alter table public.inspections add column photo_paths text[] not null default '{}';
  end if;
end $$;