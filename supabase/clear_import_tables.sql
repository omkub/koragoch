-- Run before a full Firebase -> Supabase re-import.
-- This clears imported data and resets identity IDs so the next import inserts fresh rows.
-- The script skips table names that do not exist in public schema.
-- Run schema fixes first when needed, especially permissions_menu_id.sql and mobile_permissions_menu_id.sql.
BEGIN;

DO $$
DECLARE
    table_names text[] := ARRAY[
        'UserRoles',
        'Permissions',
        'MobilePermissions',
        'Leaves',
        'LoginLogs',
        'Teachers',
        'Settings',
        'SpecialHolidays',
        'SpecialWorkingDays',
        'Academics',
        'AdminRoles',
        'AppConfig',
        'Departments',
        'Positions',
        'Roles',
        'LeaveTypes',
        'FiscalRounds',
        'academics',
        'adminroles',
        'appconfig',
        'departments',
        'positions',
        'roles'
    ];
    table_name text;
BEGIN
    FOREACH table_name IN ARRAY table_names LOOP
        IF to_regclass(format('public.%I', table_name)) IS NOT NULL THEN
            EXECUTE format('TRUNCATE TABLE public.%I RESTART IDENTITY CASCADE', table_name);
        END IF;
    END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
COMMIT;