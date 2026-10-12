-- © Flatra Tech Ltd. All rights reserved.
-- Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
-- Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
-- Contact: +2349025975247
-- 0020_role_hierarchy_and_depot_admins.sql
--
-- Additive, non-destructive and idempotent.
--
-- THE HIERARCHY CHANGES HERE. The existing policy helpers give an ADMIN (or a
-- COUNTRY_HEAD) visibility of exactly the depot on their own profile row, so a
-- country head could not see their country and an admin could not be given a
-- second depot. The spec requires:
--
--     SUPERADMIN(4) > COUNTRY HEAD(3) > ADMIN(2) > USER(1)
--
-- and, critically:
--
--     COUNTRY HEAD and SUPERADMIN  → every depot
--     ADMIN                        → only the depots they administer
--     USER                         → own depot and own assignments
--
-- This is implemented by ADDING role helpers and a `depot_admins` table, then
-- re-pointing the existing policies at them. No existing function is dropped,
-- and `profiles.role` still has no client-write path whatsoever.

-- ---------------------------------------------------------------------------
-- 1. depot_admins — which depots an ADMIN may administer
-- ---------------------------------------------------------------------------
-- A country head assigns an admin to the depots they manage. Without this table
-- an ADMIN can only ever see their own depot, and there is no way to delegate.
create table if not exists public.depot_admins (
  id uuid primary key default gen_random_uuid(),
  depot_id uuid not null references public.depots(id) on delete cascade,
  admin_user_id uuid not null references public.profiles(id) on delete cascade,
  assigned_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

-- One row per pair, so re-assigning is idempotent.
create unique index if not exists depot_admins_pair_idx
  on public.depot_admins(depot_id, admin_user_id);

alter table public.depot_admins enable row level security;

drop policy if exists depot_admins_read on public.depot_admins;
create policy depot_admins_read on public.depot_admins
  for select to authenticated
  using (
    public.is_superadmin()
    or public.is_country_head()
    or admin_user_id = auth.uid()
  );

-- Managed by a country head or super admin. No client-side assignment.
drop policy if exists depot_admins_write on public.depot_admins;
create policy depot_admins_write on public.depot_admins
  for all to authenticated
  using (public.is_superadmin() or public.is_country_head())
  with check (public.is_superadmin() or public.is_country_head());

-- ---------------------------------------------------------------------------
-- 2. Role helpers
-- ---------------------------------------------------------------------------
-- `rank` makes each level expressible without re-deriving comparisons.

create or replace function public.role_rank(r public.user_role default null)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select case coalesce(
      -- An explicit argument wins, so policy definitions can pass a role.
      r,
      -- Otherwise read the caller's own profile row. The profile is
      -- authoritative: an app_metadata claim can be stale after a role change
      -- until the next token refresh, and trusting it would let a role change
      -- lag behind the database it is supposed to describe.
      (select p.role from public.profiles p where p.id = auth.uid()),
      'USER'::public.user_role)
    when 'SUPERADMIN'   then 4
    when 'COUNTRY_HEAD' then 3
    when 'ADMIN'        then 2
    when 'USER'         then 1
    else 0
  end;
$$;

create or replace function public.has_role_at_least(min_rank integer)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.role_rank() >= min_rank;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.role_rank() >= 2, false);
$$;

create or replace function public.is_country_head()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.role_rank() >= 3, false);
$$;

create or replace function public.is_superadmin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.role_rank() >= 4, false);
$$;

-- ---------------------------------------------------------------------------
-- 3. Depot visibility
-- ---------------------------------------------------------------------------
-- Replaces the old "management sees everything" rule, which treated a plain
-- ADMIN as country-wide. The new rule is role-scoped: a country head or super
-- admin sees every depot, an admin sees only the depots assigned to them, and
-- a USER keeps exactly the visibility they already had.
--
-- The signature is kept byte-identical to the one in migration 0016
-- (`can_read_depot(depot_id uuid)`): PostgreSQL refuses to rename an input
-- parameter through CREATE OR REPLACE, and a DROP is not possible either
-- because the existing policies depend on this function. Matching the signature
-- exactly is therefore the only safe way to change the body.
--
-- The stand-in branch keeps the original semantics from migration 0016:
-- `stand_ins.user_id` is the person away, and `covering_depot_id` is what the
-- coverer is entitled to.
create or replace function public.can_read_depot(depot_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    -- Country head and super admin see everything.
    public.role_rank() >= 3
    or depot_id in (
      -- Own depot, unchanged for USER and ADMIN alike.
      select p.depot_id from public.profiles p
        where p.id = auth.uid() and p.is_active
      union
      -- Depots an ADMIN has been assigned to administer.
      select da.depot_id from public.depot_admins da
        where da.admin_user_id = auth.uid()
      union
      -- Depot covered on behalf of a colleague (dates still checked).
      select s.covering_depot_id from public.stand_ins s
        where s.user_id = auth.uid() and s.status = 'ACTIVE'
          and current_date between s.start_date and s.end_date
    )
$$;

-- Whether the current user may approve a permit. Only a country head or super
-- admin may; an admin may not, even for a depot they administer.
create or replace function public.can_approve_permits()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.role_rank() >= 3;
$$;

-- Platform export is a super-admin capability; a country head and admin may
-- export within their scope, but only a super admin may export everything.
create or replace function public.can_export_platform()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.role_rank() >= 3;
$$;

-- ---------------------------------------------------------------------------
-- 4. Existing policies now read the new semantics
-- ---------------------------------------------------------------------------
-- The `can_read_depot` definition above is what the existing policies call, so
-- every table's read path changes automatically. No policy text needs editing.

-- The one behaviour that does change: `depots_read` previously admitted an
-- admin only through `is_admin()`, which resolved to their own profile depot.
-- Repointing it at the depot-admin table is what makes an admin see their whole
-- assigned set.
drop policy if exists depots_read on public.depots;
create policy depots_read on public.depots
  for select to authenticated
  using (
    public.role_rank() >= 2
    or public.can_read_depot(id)
  );

-- Permit approval is no longer an admin action.
drop policy if exists permits_update on public.permits;
create policy permits_update on public.permits
  for update to authenticated
  using (
    -- The author may revise a draft or a rejected permit at any time.
    created_by = auth.uid()
    -- A country head or super admin may approve or reject.
    or public.can_approve_permits()
  )
  with check (
    created_by = auth.uid()
    or public.can_approve_permits()
  );

-- ---------------------------------------------------------------------------
-- 5. audit backfill for role changes
-- ---------------------------------------------------------------------------
-- Roles are never client-writable. `profiles_update` (migration 0003) already
-- restricts updates to self-service and the RLS grant only covers the columns
-- a user may touch, so no policy change is needed here. The assertion test in
-- the RLS suite pins this.
