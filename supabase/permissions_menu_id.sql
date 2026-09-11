-- Run once in the Supabase SQL Editor before importing Permissions.
-- Keep Permissions and MobilePermissions in the same row-per-menu shape.
-- Permissions:      id_Permissions, id_role, status, updatedAt, menu_id
-- MobilePermissions:id_MobilePermissions, id_role, status, updatedAt, menu_id
BEGIN;

ALTER TABLE public."Permissions"
    ADD COLUMN IF NOT EXISTS id_role bigint;

ALTER TABLE public."Permissions"
    ADD COLUMN IF NOT EXISTS status bit(1);

ALTER TABLE public."Permissions"
    ADD COLUMN IF NOT EXISTS "updatedAt" timestamptz;

ALTER TABLE public."Permissions"
    ADD COLUMN IF NOT EXISTS menu_id integer
    CHECK (menu_id BETWEEN 0 AND 8);

-- Old wide rows do not have one row per menu. Re-import from Firebase after this.
DELETE FROM public."Permissions"
WHERE menu_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS "Permissions_role_menu_uidx"
    ON public."Permissions" (id_role, menu_id);

-- Remove old wide-shape columns so Permissions matches MobilePermissions.
ALTER TABLE public."Permissions"
    DROP COLUMN IF EXISTS "permissionName",
    DROP COLUMN IF EXISTS "permission_0",
    DROP COLUMN IF EXISTS "permission_1",
    DROP COLUMN IF EXISTS "permission_2",
    DROP COLUMN IF EXISTS "permission_3",
    DROP COLUMN IF EXISTS "permission_4",
    DROP COLUMN IF EXISTS "permission_5",
    DROP COLUMN IF EXISTS "permission_6",
    DROP COLUMN IF EXISTS "permission_7",
    DROP COLUMN IF EXISTS "permission_8";

NOTIFY pgrst, 'reload schema';
COMMIT;