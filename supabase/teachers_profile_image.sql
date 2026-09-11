-- Run once in the Supabase SQL Editor before importing Teachers.
-- Firebase Teachers may contain a profileImage URL for the user's profile photo.
BEGIN;

ALTER TABLE public."Teachers"
    ADD COLUMN IF NOT EXISTS "profileImage" text;

NOTIFY pgrst, 'reload schema';
COMMIT;