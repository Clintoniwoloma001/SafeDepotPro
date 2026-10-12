-- © Flatra Tech Ltd. All rights reserved.
-- Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
-- Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
-- Contact: +2349025975247
-- 0023_import_business_keys.sql
--
-- Additive, non-destructive and idempotent.
--
-- The Base44 import upserts on a business key per table. Migration 0022 added
-- a unique index on trucks.reg_no; this one adds the matching index on
-- routine_tasks.title, which the import's ON CONFLICT also needs.
--
-- There was no unique constraint on routine_tasks.title, so the import failed
-- with "no unique or exclusion constraint matching the ON CONFLICT
-- specification".

create unique index if not exists routine_tasks_title_key
  on public.routine_tasks(title);
