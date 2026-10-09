import { useEffect, useState } from 'react';
import { NavLink, Navigate, Route, Routes } from 'react-router-dom';
import type { Session } from '@supabase/supabase-js';
import { supabase, type Access } from './supabase';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import SchoolsPage from './pages/SchoolsPage';
import SchoolAdminsPage from './pages/SchoolAdminsPage';
import LinePage from './pages/LinePage';
import RolePermissionsPage from './pages/RolePermissionsPage';
import UserPermissionsPage from './pages/UserPermissionsPage';
import AttendancePage from './pages/AttendancePage';
import LeaveFormPage from './pages/LeaveFormPage';

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

  if (!session) return <LoginPage />;
  if (access === null) return <div className="center">กำลังตรวจสิทธิ์...</div>;
  if (access.level === 'none') {
    return (
      <div className="center">
        <div className="card narrow">
          <h2>ไม่มีสิทธิ์เข้าหน้านี้</h2>
          <p>หน้านี้สำหรับผู้ดูแลระบบเท่านั้น</p>
          <button onClick={() => supabase.auth.signOut()}>ออกจากระบบ</button>
        </div>
      </div>
    );
  }

  const isSuper = access.level === 'super';

  return (
    <div className="layout">
      <nav className="sidebar">
        <div className="brand">
          {isSuper ? 'ผู้ดูแลระบบส่วนกลาง' : 'ผู้ดูแลระบบโรงเรียน'}
          <small>ระบบลาออนไลน์</small>
        </div>
        {isSuper && (
          <>
            <NavLink to="/" end>ภาพรวม</NavLink>
            <NavLink to="/schools">โรงเรียน</NavLink>
            <NavLink to="/admins">ผู้ดูแลโรงเรียน</NavLink>
            <NavLink to="/line">LINE แจ้งเตือน</NavLink>
            <NavLink to="/role-permissions">เพดานสิทธิ์</NavLink>
            <NavLink to="/attendance">ลงเวลา (สแกนหน้า)</NavLink>
            <NavLink to="/forms/leave">แบบฟอร์มใบลา</NavLink>
          </>
        )}
        <NavLink to="/user-permissions">สิทธิ์ผู้ใช้</NavLink>
        <div className="spacer" />
        <a href="../">เปิดแอปครู ↗</a>
        <button className="link" onClick={() => supabase.auth.signOut()}>
          ออกจากระบบ
        </button>
      </nav>
      <main className="content">
        <Routes>
          {isSuper ? (
            <>
              <Route path="/" element={<DashboardPage />} />
              <Route path="/schools" element={<SchoolsPage />} />
              <Route path="/admins" element={<SchoolAdminsPage />} />
              <Route path="/line" element={<LinePage />} />
              <Route path="/role-permissions" element={<RolePermissionsPage />} />
              <Route path="/attendance" element={<AttendancePage />} />
              <Route path="/forms/leave" element={<LeaveFormPage />} />
              <Route path="/user-permissions" element={<UserPermissionsPage access={access} />} />
              <Route path="*" element={<Navigate to="/" replace />} />
            </>
          ) : (
            <>
              <Route path="/user-permissions" element={<UserPermissionsPage access={access} />} />
              <Route path="*" element={<Navigate to="/user-permissions" replace />} />
            </>
          )}
        </Routes>
      </main>
    </div>
  );
}
