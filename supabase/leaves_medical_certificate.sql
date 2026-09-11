-- Run once in the Supabase SQL Editor before importing Leaves.
-- Firebase Leaves may contain a medicalCertificate URL for medical leave evidence.
BEGIN;

ALTER TABLE public."Leaves"
    ADD COLUMN IF NOT EXISTS "medicalCertificate" text;

NOTIFY pgrst, 'reload schema';
COMMIT;