-- © Flatra Tech Ltd. All rights reserved.
-- Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
-- Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
-- Contact: +2349025975247
-- 0021_protect_privileged_profile_columns.sql
--
-- Additive, non-destructive and idempotent.
--
-- A SECURITY DEFECT FOUND DURING VERIFICATION, FIXED HERE.
--
-- `profiles_update_self` (migration 0003) reads:
--
--     for update to authenticated using (auth.uid() = id)
--
-- with no `with check`. PostgreSQL defaults the check to the using expression,
-- which is `auth.uid() = id` — true for the caller. So the policy permits a
-- user to write ANY column of their own profile, and the column grants include
-- `role`. A logged-in USER could therefore promote themselves to SUPERADMIN
-- with one request.
--
-- The spec requires that `profiles.role` is never client-writable. A policy
-- cannot enforce a per-column restriction, so it is enforced here with a
-- trigger that raises on any change to the privileged columns by a caller who
-- is not an administrator.

-- Privileged columns: those set by an administrator, not by the account holder.
create or replace function public.protect_profiles_privileged_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- An administrator may change any of these; everyone else may not.
  if public.role_rank() >= 2 then
    return new;
  end if;

  if new.role is distinct from old.role then
    raise exception 'permission denied: profiles.role is not client-writable'
      using errcode = '42501';
  end if;

  if new.depot_id is distinct from old.depot_id then
    raise exception 'permission denied: profiles.depot_id is not client-writable'
      using errcode = '42501';
  end if;

  if new.is_active is distinct from old.is_active then
    raise exception 'permission denied: profiles.is_active is not client-writable'
      using errcode = '42501';
  end if;

  return new;
end $$;

drop trigger if exists trg_protect_profiles_privileged
  on public.profiles;
create trigger trg_protect_profiles_privileged
  before update on public.profiles
  for each row execute function public.protect_profiles_privileged_columns();

-- Revoke the blanket UPDATE grant on the privileged columns as a second
-- barrier. A trigger is the authoritative control (a policy or grant change
-- can be reverted); revoking the grant means the write never reaches the
-- trigger at all for those columns.
revoke update on public.profiles from authenticated;
grant update (full_name, phone, preferred_language, avatar_url) on public.profiles to authenticated;

-- The self-service update policy also needs a check clause, so a caller cannot
-- reassign the row to another user id in the same statement.
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
  for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);
