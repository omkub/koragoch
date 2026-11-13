import { useCallback, useEffect, useState } from 'react';
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import type { Session } from '@supabase/supabase-js';
import AppShell from './components/AppShell';
import { DEFAULT_MODULE_LINKS } from './config/modules';
import { extractUsername, supabase } from './lib/supabase';
import AcademicsPage from './pages/AcademicsPage';
import DashboardPage from './pages/DashboardPage';
import DepartmentsPage from './pages/DepartmentsPage';
import DocumentsPage from './pages/DocumentsPage';
import LoginPage from './pages/LoginPage';
import SettingsModulesPage from './pages/SettingsModulesPage';
import StaffPage from './pages/StaffPage';
import StudentsPage from './pages/StudentsPage';
import type {
  AcademicTerm,
  AcademicYear,
  SchoolInfo,
  SchoolModuleLink,
} from './types/school';

interface UserContext {
  isSuperAdmin: boolean;
  isAdmin: boolean;
  schoolId: number | null;
  fullName: string;
}

export default function App() {
  const [session, setSession] = useState<Session | null>(null);
  const [authReady, setAuthReady] = useState(false);

  const [userCtx, setUserCtx] = useState<UserContext | null>(null);
  const [schools, setSchools] = useState<SchoolInfo[]>([]);
  const [selectedSchoolId, setSelectedSchoolId] = useState<number | null>(null);

  const [academicLabel, setAcademicLabel] = useState('ยังไม่ได้ตั้งค่าปีการศึกษา');
  const [modules, setModules] = useState<SchoolModuleLink[]>(DEFAULT_MODULE_LINKS);
  const [hasDbModules, setHasDbModules] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setAuthReady(true);
    });
    const { data } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession);
      setAuthReady(true);
    });
    return () => data.subscription.unsubscribe();
  }, []);

  // Load user role, schoolId, and teacher profile (Read-only)
  useEffect(() => {
    if (!session) {
      setUserCtx(null);
      setSchools([]);
      setSelectedSchoolId(null);
      return;
    }

    (async () => {
      const username = extractUsername(session.user.email);
      const [superRes, adminRes, schoolRes, schoolsRes, teacherRes] =
        await Promise.all([
          supabase.rpc('is_super_admin'),
          supabase.rpc('is_admin'),
          supabase.rpc('current_school_id'),
          supabase
            .from('Schools')
            .select('id_school, fullName, affiliation')
            .order('id_school'),
          username
            ? supabase
                .from('Teachers')
                .select('fullName')
                .eq('username', username)
                .limit(1)
                .maybeSingle()
            : Promise.resolve({ data: null }),
        ]);

      const schoolId =
        typeof schoolRes.data === 'number'
          ? schoolRes.data
          : Number(schoolRes.data) || null;
      const schoolList = (schoolsRes.data as SchoolInfo[] | null) ?? [];

      setUserCtx({
        isSuperAdmin: superRes.data === true,
        isAdmin: adminRes.data === true,
        schoolId,
        fullName: teacherRes.data?.fullName || username || 'ผู้ใช้งาน',
      });
      setSchools(schoolList);
      setSelectedSchoolId(schoolId ?? schoolList[0]?.id_school ?? null);
    })();
  }, [session]);

  const loadSchoolContext = useCallback(async () => {
    if (!selectedSchoolId) return;

    const [yearRes, termRes, modRes] = await Promise.all([
      supabase
        .from('AcademicYears')
        .select('id, id_school, year_be, label, is_current')
        .eq('id_school', selectedSchoolId)
        .eq('is_current', true)
        .limit(1)
        .maybeSingle(),
      supabase
        .from('AcademicTerms')
        .select('id, id_school, academic_year_id, term_no, label, is_current')
        .eq('id_school', selectedSchoolId)
        .eq('is_current', true)
        .limit(1)
        .maybeSingle(),
      supabase
        .from('SchoolModules')
        .select('id, module_key, title, description, url, open_mode, category, is_enabled')
        .eq('id_school', selectedSchoolId)
        .order('sort_order', { ascending: true }),
    ]);

    const currentYear = yearRes.data as AcademicYear | null;
    const currentTerm = termRes.data as AcademicTerm | null;
    if (currentTerm?.label) {
      setAcademicLabel(currentTerm.label);
    } else if (currentYear?.label) {
      setAcademicLabel(currentYear.label);
    } else {
      setAcademicLabel('ปีการศึกษา 2569 (ค่าเริ่มต้น)');
    }

    const dbModules = (modRes.data as SchoolModuleLink[] | null) ?? [];
    if (dbModules.length > 0) {
      setModules(dbModules);
      setHasDbModules(true);
    } else {
      setModules(DEFAULT_MODULE_LINKS);
      setHasDbModules(false);
    }
  }, [selectedSchoolId]);

  useEffect(() => {
    loadSchoolContext();
  }, [loadSchoolContext]);

  if (!authReady) {
    return (
      <div className="grid min-h-screen place-items-center bg-canvas text-sm text-slate-500">
        กำลังเตรียมระบบ...
      </div>
    );
  }

  if (!session) {
    return <LoginPage />;
  }

  if (!userCtx) {
    return (
      <div className="grid min-h-screen place-items-center bg-canvas text-sm text-slate-500">
        กำลังโหลดข้อมูลโรงเรียน...
      </div>
    );
  }

  const currentSchool =
    schools.find((s) => s.id_school === selectedSchoolId) ?? null;
  const roleLabel = userCtx.isSuperAdmin
    ? 'ผู้ดูแลระบบส่วนกลาง'
    : userCtx.isAdmin
      ? 'ผู้ดูแลระบบโรงเรียน'
      : 'บุคลากรโรงเรียน';
  const canEditSchool = userCtx.isSuperAdmin || userCtx.isAdmin;

  return (
    <BrowserRouter basename={import.meta.env.BASE_URL}>
      <AppShell
        schoolName={currentSchool?.fullName || 'โรงเรียน (ระบบแม่)'}
        academicTermLabel={academicLabel}
        userName={userCtx.fullName}
        roleLabel={roleLabel}
        schools={schools}
        selectedSchoolId={selectedSchoolId}
        canSwitchSchool={userCtx.isSuperAdmin}
        onSelectSchool={setSelectedSchoolId}
        onSignOut={() => supabase.auth.signOut()}
        modules={modules}
      >
        <Routes>
          <Route
            path="/"
            element={
              <DashboardPage
                school={currentSchool}
                schoolId={selectedSchoolId}
                canEdit={canEditSchool}
                academicLabel={academicLabel}
                modules={modules}
              />
            }
          />
          <Route
            path="/staff"
            element={<StaffPage schoolId={selectedSchoolId} modules={modules} />}
          />
          <Route
            path="/departments"
            element={
              <DepartmentsPage
                schoolId={selectedSchoolId}
                canEdit={canEditSchool}
              />
            }
          />
          <Route
            path="/students"
            element={
              <StudentsPage
                schoolId={selectedSchoolId}
                canEdit={canEditSchool}
              />
            }
          />
          <Route
            path="/academics"
            element={
              <AcademicsPage
                schoolId={selectedSchoolId}
                canEdit={canEditSchool}
              />
            }
          />
          <Route
            path="/documents"
            element={
              <DocumentsPage
                schoolId={selectedSchoolId}
                canEdit={canEditSchool}
              />
            }
          />
          <Route
            path="/settings"
            element={
              <SettingsModulesPage
                school={currentSchool}
                schoolId={selectedSchoolId}
                canEdit={canEditSchool}
                modules={modules}
                hasDbRows={hasDbModules}
                onReload={loadSchoolContext}
              />
            }
          />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </AppShell>
    </BrowserRouter>
  );
}
