import { createClient } from '@supabase/supabase-js';

// ใช้ Supabase Project เดียวกับระบบวันลาและเว็บส่วนกลาง (อ่านข้อมูลกลางร่วมกัน)
const SUPABASE_URL = 'https://uziajblqlbrvqmxvizsi.supabase.co';
const SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV6aWFqYmxxbGJydnFteHZpenNpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2Njc1MzIsImV4cCI6MjA5OTI0MzUzMn0.cpnt8uctNacuJWNelYx5C_oP0xEPtUhzvNDgyWkg0ZA';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    storageKey: 'koragoch-school-web-auth',
  },
});

export function toAuthEmail(identifier: string): string {
  const trimmed = identifier.trim().toLowerCase();
  return trimmed.includes('@') ? trimmed : `${trimmed}@leave.local`;
}

export function extractUsername(email: string | undefined | null): string {
  if (!email) return '';
  return email.endsWith('@leave.local') ? email.replace('@leave.local', '') : email;
}
