import { useEffect, useState } from 'react';
import { NavLink, Navigate, Route, Routes } from 'react-router-dom';
import type { Session } from '@supabase/supabase-js';
import { supabase } from './supabase';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import SchoolsPage from './pages/SchoolsPage';
import SchoolAdminsPage from './pages/SchoolAdminsPage';

/**
 * เว็บผู้ดูแลระบบส่วนกลาง — เข้าได้เฉพาะบัญชีที่ is_super_admin() เป็นจริง
 * (Teachers.is_super_admin + id_role 22 ดู supabase/admin_role_by_id.sql)
 */
export default function App() {
  const [session, setSession] = useState<Session | null>(null);
  const [isSuper, setIsSuper] = useState<boolean | null>(null);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session));
    const { data } = supabase.auth.onAuthStateChange((_event, s) => setSession(s));
    return () => data.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (!session) {
      setIsSuper(null);
      return;
    }
    supabase.rpc('is_super_admin').then(({ data, error }) => {
      setIsSuper(!error && data === true);
    });
  }, [session]);

  if (!session) return <LoginPage />;
  if (isSuper === null) return <div className="center">กำลังตรวจสิทธิ์...</div>;
  if (!isSuper) {
    return (
      <div className="center">
        <div className="card narrow">
          <h2>ไม่มีสิทธิ์เข้าหน้านี้</h2>
          <p>หน้านี้สำหรับผู้ดูแลระบบส่วนกลางเท่านั้น</p>
          <button onClick={() => supabase.auth.signOut()}>ออกจากระบบ</button>
        </div>
      </div>
    );
  }

  return (
    <div className="layout">
      <nav className="sidebar">
        <div className="brand">
          ผู้ดูแลระบบส่วนกลาง
          <small>ระบบลาออนไลน์</small>
        </div>
        <NavLink to="/" end>ภาพรวม</NavLink>
        <NavLink to="/schools">โรงเรียน</NavLink>
        <NavLink to="/admins">ผู้ดูแลโรงเรียน</NavLink>
        <div className="spacer" />
        <a href="../">เปิดแอปครู ↗</a>
        <button className="link" onClick={() => supabase.auth.signOut()}>
          ออกจากระบบ
        </button>
      </nav>
      <main className="content">
        <Routes>
          <Route path="/" element={<DashboardPage />} />
          <Route path="/schools" element={<SchoolsPage />} />
          <Route path="/admins" element={<SchoolAdminsPage />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </main>
    </div>
  );
}
