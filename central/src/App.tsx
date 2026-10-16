import { useEffect, useState, type ReactNode } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import type { Session } from '@supabase/supabase-js';
import { supabase, type Access } from './supabase';
import AppShell from './ui/AppShell';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import SchoolsPage from './pages/SchoolsPage';
import SchoolAdminsPage from './pages/SchoolAdminsPage';
import StaffPage from './pages/StaffPage';
import LinePage from './pages/LinePage';
import RolePermissionsPage from './pages/RolePermissionsPage';
import UserPermissionsPage from './pages/UserPermissionsPage';
import AttendancePage from './pages/AttendancePage';
import FormDesignerPage from './pages/FormDesignerPage';

/** หน้าที่ยังใช้สไตล์เดิม (legacy.css) — ย้ายครบแล้วลบทิ้ง */
const Legacy = ({ children }: { children: ReactNode }) => <div className="legacy">{children}</div>;

/** หน้าเต็มจอกลางจอ (ตรวจสิทธิ์ / ไม่มีสิทธิ์) */
function CenterScreen({ children }: { children: ReactNode }) {
  return <div className="grid min-h-screen place-items-center p-4">{children}</div>;
}

/**
 * เว็บผู้ดูแลระบบ
 *
 *   ผู้ดูแลส่วนกลาง (is_super_admin) — ทุกเมนู ทุกโรงเรียน
 *   แอดมินโรงเรียน (is_admin = id_role 22) — เฉพาะ "สิทธิ์ผู้ใช้" ของโรงเรียนตัวเอง
 *
 * สิทธิ์จริงคุมด้วย RLS ในฐานข้อมูล (ดู supabase/fine_permissions.sql)
 * เมนูที่ซ่อนไว้แค่ไม่ให้หลง ไม่ใช่ตัวกัน
 */
export default function App() {
  const [session, setSession] = useState<Session | null>(null);
  const [access, setAccess] = useState<Access | null>(null);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session));
    const { data } = supabase.auth.onAuthStateChange((_event, s) => setSession(s));
    return () => data.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (!session) {
      setAccess(null);
      return;
    }
    (async () => {
      const [superRes, adminRes, schoolRes] = await Promise.all([
        supabase.rpc('is_super_admin'),
        supabase.rpc('is_admin'),
        supabase.rpc('current_school_id'),
      ]);
      setAccess({
        level: superRes.data === true ? 'super' : adminRes.data === true ? 'school' : 'none',
        schoolId: typeof schoolRes.data === 'number' ? schoolRes.data : Number(schoolRes.data) || null,
      });
    })();
  }, [session]);
  if (!session) {
    return (
      <LoginPage />

    );
  }
  if (access === null) {
    return <CenterScreen><p className="text-sm text-slate-500">กำลังตรวจสิทธิ์...</p></CenterScreen>;
  }
  if (access.level === 'none') {
    return (
      <CenterScreen>
        <div className="card w-full max-w-sm p-6">
          <h2 className="text-lg font-bold">ไม่มีสิทธิ์เข้าหน้านี้</h2>
          <p className="mt-1 text-sm text-slate-500">หน้านี้สำหรับผู้ดูแลระบบเท่านั้น</p>
          <button className="btn-primary mt-5 w-full" onClick={() => supabase.auth.signOut()}>
            ออกจากระบบ
          </button>
        </div>
      </CenterScreen>
    );
  }

  const isSuper = access.level === 'super';

  return (
    <AppShell isSuper={isSuper}>
      <Routes>
        {isSuper ? (
          <>
            <Route path="/" element={<DashboardPage />} />
            <Route path="/schools" element={<SchoolsPage />} />
            <Route path="/admins" element={<SchoolAdminsPage />} />
            <Route path="/staff" element={<StaffPage />} />
            <Route path="/line" element={<Legacy><LinePage /></Legacy>} />
            <Route path="/role-permissions" element={<Legacy><RolePermissionsPage /></Legacy>} />
            <Route path="/attendance" element={<Legacy><AttendancePage /></Legacy>} />
            <Route path="/forms" element={<Legacy><FormDesignerPage /></Legacy>} />
            <Route path="/forms/leave" element={<Navigate to="/forms" replace />} />
            <Route path="/user-permissions" element={<Legacy><UserPermissionsPage access={access} /></Legacy>} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </>
        ) : (
          <>
            <Route path="/user-permissions" element={<Legacy><UserPermissionsPage access={access} /></Legacy>} />
            <Route path="*" element={<Navigate to="/user-permissions" replace />} />
          </>
        )}
      </Routes>
    </AppShell>
  );
}
