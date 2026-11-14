import { useCallback, useEffect, useState, type ReactNode } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import type { Session } from '@supabase/supabase-js';
import { supabase, type Access } from './supabase';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import SchoolsPage from './pages/SchoolsPage';
import SchoolAdminsPage from './pages/SchoolAdminsPage';
import StaffPage from './pages/StaffPage';
import AdminPositionsPage from './pages/AdminPositionsPage';
import LinePage from './pages/LinePage';
import RolePermissionsPage from './pages/RolePermissionsPage';
import UserPermissionsPage from './pages/UserPermissionsPage';
import AttendancePage from './pages/AttendancePage';
import FormDesignerPage from './pages/FormDesignerPage';
import UnifiedShell from './school/UnifiedShell';
import SchoolDashboardPage from './school/SchoolDashboardPage';
import DivisionHubPage from './school/DivisionHubPage';
import SchoolSettingsPage from './school/SchoolSettingsPage';
import DivisionMappingPage from './school/DivisionMappingPage';
import DivisionPermissionsPage from './school/DivisionPermissionsPage';
import {
  FALLBACK_CATALOG,
  fetchSchoolDivisionTree,
  type DivisionWithModules,
  type ModuleCatalogItem,
} from './school/mapping';
import { DEFAULT_MODULE_LINKS } from './school/modules';
import type {
  AcademicTerm,
  AcademicYear,
  SchoolBasic,
  SchoolModuleLink,
} from './school/types';

function CenterScreen({ children }: { children: ReactNode }) {
  return <div className="grid min-h-screen place-items-center p-4">{children}</div>;
}

function extractUsername(email: string | undefined | null): string {
  if (!email) return '';
  return email.endsWith('@leave.local') ? email.replace('@leave.local', '') : email;
}

export default function App() {
  const [session, setSession] = useState<Session | null>(null);
  const [access, setAccess] = useState<Access | null>(null);
  const [userName, setUserName] = useState('ผู้ใช้งาน');
  const [userRoleId, setUserRoleId] = useState<number | null>(null);

  const [schools, setSchools] = useState<SchoolBasic[]>([]);
  const [selectedSchoolId, setSelectedSchoolId] = useState<number | null>(null);
  const [academicLabel, setAcademicLabel] = useState('ปีการศึกษา 2569');
  const [modules, setModules] = useState<SchoolModuleLink[]>(DEFAULT_MODULE_LINKS);
  const [hasDbModules, setHasDbModules] = useState(false);

  const [catalog, setCatalog] = useState<ModuleCatalogItem[]>(FALLBACK_CATALOG);
  const [divisions, setDivisions] = useState<DivisionWithModules[]>([]);
  const [hasDbMapping, setHasDbMapping] = useState(false);
  const [roleAccessRows, setRoleAccessRows] = useState<
    { division_id: number; id_role: number; can_view: boolean; can_edit: boolean }[]
  >([]);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session));
    const { data } = supabase.auth.onAuthStateChange((_event, s) => setSession(s));
    return () => data.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (!session) {
      setAccess(null);
      setSchools([]);
      setSelectedSchoolId(null);
      setUserRoleId(null);
      return;
    }
    (async () => {
      const username = extractUsername(session.user.email);
      const [superRes, adminRes, schoolRes, schoolsRes, teacherRes] = await Promise.all([
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
              .select('fullName, id_role')
              .eq('username', username)
              .limit(1)
              .maybeSingle()
          : Promise.resolve({ data: null }),
      ]);

      const schoolId =
        typeof schoolRes.data === 'number'
          ? schoolRes.data
          : Number(schoolRes.data) || null;
      const schoolList = (schoolsRes.data as SchoolBasic[] | null) ?? [];

      setAccess({
        level: superRes.data === true ? 'super' : adminRes.data === true ? 'school' : 'none',
        schoolId,
      });
      const teacherRow = teacherRes.data as {
        fullName?: string | null;
        id_role?: number | null;
      } | null;
      setUserName(teacherRow?.fullName || username || 'ผู้ใช้งาน');
      setUserRoleId(
        typeof teacherRow?.id_role === 'number' ? teacherRow.id_role : null,
      );
      setSchools(schoolList);
      setSelectedSchoolId(schoolId ?? schoolList[0]?.id_school ?? null);
    })();
  }, [session]);

  const loadSchoolContext = useCallback(async () => {
    if (!selectedSchoolId) return;

    const [yearRes, termRes, modRes, treeRes, roleAccRes] = await Promise.all([
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
      fetchSchoolDivisionTree(selectedSchoolId),
      supabase
        .from('SchoolWebRoleDivisionAccess')
        .select('division_id, id_role, can_view, can_edit')
        .eq('id_school', selectedSchoolId),
    ]);

    const currentYear = yearRes.data as AcademicYear | null;
    const currentTerm = termRes.data as AcademicTerm | null;
    if (currentTerm?.label) {
      setAcademicLabel(currentTerm.label);
    } else if (currentYear?.label) {
      setAcademicLabel(currentYear.label);
    } else {
      setAcademicLabel('ปีการศึกษา 2569');
    }

    const dbModules = (modRes.data as SchoolModuleLink[] | null) ?? [];
    if (dbModules.length > 0) {
      setModules(dbModules);
      setHasDbModules(true);
    } else {
      setModules(DEFAULT_MODULE_LINKS);
      setHasDbModules(false);
    }

    setCatalog(treeRes.catalog);
    setDivisions(treeRes.divisions);
    setHasDbMapping(treeRes.hasDbMapping);
    setRoleAccessRows(
      (roleAccRes.data as
        | { division_id: number; id_role: number; can_view: boolean; can_edit: boolean }[]
        | null) ?? [],
    );
  }, [selectedSchoolId]);

  useEffect(() => {
    loadSchoolContext();
  }, [loadSchoolContext]);

  if (!session) {
    return <LoginPage />;
  }
  if (access === null) {
    return (
      <CenterScreen>
        <p className="text-sm text-slate-500">กำลังโหลดข้อมูลโรงเรียน...</p>
      </CenterScreen>
    );
  }

  const isSuper = access.level === 'super';
  const canEditSchool = access.level === 'super' || access.level === 'school';
  const currentSchool =
    schools.find((s) => s.id_school === selectedSchoolId) ?? null;
  const roleLabel = isSuper
    ? 'ผู้ดูแลระบบส่วนกลาง'
    : access.level === 'school'
      ? 'ผู้ดูแลระบบโรงเรียน'
      : 'บุคลากรโรงเรียน';

  // กรองฝ่ายที่ผู้ใช้งานคนนี้สามารถเปิดดูได้ตาม Role (แอดมินเห็นทุกฝ่าย)
  const visibleDivisions = canEditSchool
    ? divisions
    : divisions.filter((div) => {
        if (userRoleId === null) return true;
        const rule = roleAccessRows.find(
          (r) => r.division_id === div.id && r.id_role === userRoleId,
        );
        return rule ? rule.can_view : true;
      });

  const editableDivisionIds =
    userRoleId === null
      ? []
      : roleAccessRows
          .filter((r) => r.id_role === userRoleId && r.can_edit)
          .map((r) => r.division_id);

  return (
    <UnifiedShell
      schoolName={currentSchool?.fullName || 'โรงเรียน'}
      academicTermLabel={academicLabel}
      userName={userName}
      roleLabel={roleLabel}
      access={access}
      schools={schools}
      selectedSchoolId={selectedSchoolId}
      canSwitchSchool={isSuper}
      onSelectSchool={setSelectedSchoolId}
      onSignOut={() => supabase.auth.signOut()}
      divisions={visibleDivisions}
    >
      <Routes>
        {/* หน้าหลักโรงเรียน */}
        <Route
          path="/"
          element={
            <SchoolDashboardPage
              school={currentSchool}
              schoolId={selectedSchoolId}
              canEdit={canEditSchool}
              academicLabel={academicLabel}
              divisions={visibleDivisions}
            />
          }
        />

        {/* หน้ากลางของแต่ละฝ่าย (Dynamic Division Hub: แสดงเฉพาะ Module ที่ map อยู่กับฝ่ายนั้น) */}
        <Route
          path="/division/:divisionKey"
          element={
            <DivisionHubPage
              schoolId={selectedSchoolId}
              canEdit={canEditSchool}
              editableDivisionIds={editableDivisionIds}
              access={access}
              divisions={visibleDivisions}
            />
          }
        />
        <Route
          path="/division/:divisionKey/:moduleKey"
          element={
            <DivisionHubPage
              schoolId={selectedSchoolId}
              canEdit={canEditSchool}
              editableDivisionIds={editableDivisionIds}
              access={access}
              divisions={visibleDivisions}
            />
          }
        />

        {/* โหมด Web หลัก: ส่วนผู้ดูแลระบบกลาง */}
        {canEditSchool && (
          <>
            <Route
              path="/admin/mapping"
              element={
                <DivisionMappingPage
                  school={currentSchool}
                  schoolId={selectedSchoolId}
                  canEdit={canEditSchool}
                  catalog={catalog}
                  divisions={divisions}
                  hasDbMapping={hasDbMapping}
                  onReload={loadSchoolContext}
                />
              }
            />
            <Route
              path="/admin/division-permissions"
              element={
                <DivisionPermissionsPage
                  school={currentSchool}
                  schoolId={selectedSchoolId}
                  canEdit={canEditSchool}
                  divisions={divisions}
                  hasDbMapping={hasDbMapping}
                  onReload={loadSchoolContext}
                />
              }
            />
            <Route
              path="/user-permissions"
              element={<UserPermissionsPage access={access} />}
            />
          </>
        )}
        {isSuper && (
          <>
            <Route path="/leave-admin" element={<DashboardPage />} />
            <Route path="/schools" element={<SchoolsPage />} />
            <Route path="/admins" element={<SchoolAdminsPage />} />
            <Route path="/staff" element={<StaffPage />} />
            <Route path="/admin-positions" element={<AdminPositionsPage />} />
            <Route path="/line" element={<LinePage />} />
            <Route path="/role-permissions" element={<RolePermissionsPage />} />
            <Route path="/attendance" element={<AttendancePage />} />
            <Route path="/forms" element={<FormDesignerPage />} />
            <Route path="/forms/leave" element={<Navigate to="/forms" replace />} />
          </>
        )}

        {/* ตั้งค่าปีการศึกษาและลิงก์ */}
        <Route
          path="/settings"
          element={
            <SchoolSettingsPage
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
    </UnifiedShell>
  );
}
