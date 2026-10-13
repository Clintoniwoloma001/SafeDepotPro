-- © Flatra Tech Ltd. All rights reserved.
-- 0025_inspection_signatures.sql — add signature_path to inspections and truck_inspections.

alter table public.inspections
    add column if not exists signature_path text;

alter table public.truck_inspections
    add column if not exists signature_path text;
