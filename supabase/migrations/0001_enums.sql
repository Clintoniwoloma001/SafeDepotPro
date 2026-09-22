-- 0001_enums.sql — domain types shared across SafeDepot Pro tables.

create type public.user_role as enum ('USER', 'COUNTRY_HEAD', 'ADMIN', 'SUPERADMIN');
create type public.task_status as enum ('PENDING', 'COMPLETED', 'OVERDUE', 'SKIPPED');
create type public.severity as enum ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');
create type public.priority as enum ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');
create type public.frequency as enum ('DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY', 'BIANNUAL', 'ANNUAL');
create type public.completion_method as enum ('MANUAL', 'FORM', 'COUNT', 'PERMIT', 'VEHICLE', 'EQUIPMENT', 'PERSONNEL', 'AI_VERIFIED');
create type public.permit_status as enum ('DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED', 'CANCELLED', 'COMPLETED');
create type public.inspection_status as enum ('DRAFT', 'SUBMITTED', 'APPROVED', 'CLOSED');
create type public.inspection_response as enum ('PASS', 'FAIL', 'NON_COMPLIANT', 'NA');
create type public.incident_status as enum ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED');
create type public.hazard_status as enum ('OPEN', 'IN_PROGRESS', 'MITIGATED', 'CLOSED');
create type public.capa_status as enum ('OPEN', 'IN_PROGRESS', 'VERIFICATION', 'CLOSED');
create type public.stand_in_status as enum ('PENDING', 'ACTIVE', 'COMPLETED', 'CANCELLED', 'REJECTED');
create type public.shift_status as enum ('PENDING', 'COMPLETED', 'CONFIRMED');
create type public.asset_status as enum ('AVAILABLE', 'IN_USE', 'MAINTENANCE', 'RETIRED');
create type public.truck_result as enum ('PASS', 'FAIL');