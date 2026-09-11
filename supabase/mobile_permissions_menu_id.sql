-- Run once in the Supabase SQL Editor before importing MobilePermissions.
-- Firebase stores one document per role with menu keys -1 and 0..8.
-- Supabase therefore needs one row per role and menu: id_role + menu_id + status.
BEGIN;

ALTER TABLE public."MobilePermissions"
    ADD COLUMN IF NOT EXISTS menu_id integer
    CHECK (menu_id BETWEEN -1 AND 8);

-- Remove old collapsed rows created before menu_id existed. They cannot be
-- mapped back to a specific menu, so keeping them makes row counts wrong.
DELETE FROM public."MobilePermissions"
WHERE menu_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS "MobilePermissions_role_menu_uidx"
    ON public."MobilePermissions" (id_role, menu_id);

NOTIFY pgrst, 'reload schema';
COMMIT;