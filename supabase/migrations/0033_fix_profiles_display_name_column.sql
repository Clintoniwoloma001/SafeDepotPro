-- © Flatra Tech Ltd. All rights reserved.
-- 0033_fix_profiles_display_name_column.sql
--
-- The Flutter user-management flow was writing to a `display_name` column that
-- does not exist on `public.profiles` (the schema uses `full_name`). The
-- mobile client has been corrected to write `full_name`. This migration makes
-- the admin update path actually succeed:
--
--   * `profiles_update_manage` (RLS) already permits admins to update any row,
--     but migration 0021 revoked the column-level UPDATE grant on the
--     privileged columns, so an authenticated admin still could not write
--     `role`, `depot_id` or `is_active`. Re-grant those columns; the
--     `protect_profiles_privileged_columns` trigger still blocks non-admins.
--   * `updated_at` is maintained by `trg_profiles_updated_at`, so the client
--     must not (and no longer does) set it itself.

grant update (full_name, phone, preferred_language, avatar_url, role, depot_id, is_active)
  on public.profiles to authenticated;

-- Backfill any null names from auth metadata so the UI never shows an empty name.
update public.profiles p
set full_name = coalesce(
  nullif(p.full_name, ''),
  nullif((select u.raw_user_meta_data ->> 'full_name' from auth.users u where u.id = p.id), ''),
  split_part((select u.email from auth.users u where u.id = p.id), '@', 1)
)
where p.full_name is null or p.full_name = '';

-- Reload PostgREST schema cache so the column list is current.
notify pgrst, 'reload schema';
