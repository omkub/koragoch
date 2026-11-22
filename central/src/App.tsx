import { useCallback, useEffect, useState, type ReactNode } from 'react';
import { Navigate, Route, Routes, useLocation, useNavigate } from 'react-router-dom';
import type { Session } from '@supabase/supabase-js';
import {
  clearAllSsoSessions,
  getTargetSchoolIdFromLeaveApp,
  hydrateSsoSession,
  isEmbeddedInLeaveApp,
  navigateToLeaveApp,
  supabase,
  syncSessionToLeaveApp,
  type Access,
} from './supabase';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import SchoolsPage from './pages/SchoolsPage';
import SchoolAdminsPage from './pages/SchoolAdminsPage';
import StaffPage from './pages/StaffPage';
import AdminPositionsPage from './pages/AdminPositionsPage';
import LinePage from './pages/LinePage';
import AttendancePage from './pages/AttendancePage';
import FormDesignerPage from './pages/FormDesignerPage';
import UnifiedShell from './school/UnifiedShell';
import SchoolDashboardPage from './school/SchoolDashboardPage';
import DivisionHubPage from './school/DivisionHubPage';
import SchoolSettingsPage from './school/SchoolSettingsPage';
import DivisionMappingPage from './school/DivisionMappingPage';
import DivisionPermissionsPage from './school/DivisionPermissionsPage';
import PublicSchoolWebPage from './school/PublicSchoolWebPage';
import PublicWebSettingsPage from './school/PublicWebSettingsPage';
import {
  FALLBACK_CATALOG,
  fetchSchoolDivisionTree,
  type DivisionWithModules,
  type ModuleCatalogItem,
} from './school/mapping';
import {
  canUserManagePublicSchoolWeb,
  fetchRoleDivisionModulePermissions,
  type RoleDivisionModulePermissions,
} from './school/roleModulePermissions';
import {
  filterDivisionsByStaffMapping,
  inferRoleTierFromRoleName,
  ROLE_TIER_META,
} from './school/staffDivisionMapping';
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
  const navigate = useNavigate();
  const { pathname } = useLocation();
  const [landedSuper, setLandedSuper] = useState(false);
  const [hydratingSso, setHydratingSso] = useState(true);
  const [session, setSession] = useState<Session | null>(null);
  const [access, setAccess] = useState<Access | null>(null);
  const [userName, setUserName] = useState('ผู้ใช้งาน');
  const [userRoleId, setUserRoleId] = useState<number | null>(null);
  const [userRoleName, setUserRoleName] = useState<string>('ผู้ใช้งาน');
  const [currentUserId, setCurrentUserId] = useState<number | null>(null);
  const [roleWebAccessByRole, setRoleWebAccessByRole] = useState<
    Record<number, boolean>
  >({});

  const [schools, setSchools] = useState<SchoolBasic[]>([]);
  const [selectedSchoolId, setSelectedSchoolId] = useState<number | null>(null);
  const [academicLabel, setAcademicLabel] = useState('ปีการศึกษา 2569');
  const [modules, setModules] = useState<SchoolModuleLink[]>(DEFAULT_MODULE_LINKS);
  const [hasDbModules, setHasDbModules] = useState(false);

  const [catalog, setCatalog] = useState<ModuleCatalogItem[]>(FALLBACK_CATALOG);
  const [divisions, setDivisions] = useState<DivisionWithModules[]>([]);
  const [hasDbMapping, setHasDbMapping] = useState(false);
  const [schoolWebEnabled, setSchoolWebEnabled] = useState(true);
  const [roleDivModPerms, setRoleDivModPerms] =
    useState<RoleDivisionModulePermissions>({
      divisionByRole: {},
      moduleByRole: {},
      userTabOverride: {},
      divisionByUser: {},
      moduleByUser: {},
    });

  useEffect(() => {
    let mounted = true;
    (async () => {
      await hydrateSsoSession();
      const { data } = await supabase.auth.getSession();
      if (mounted) {
        setSession(data.session);
        setHydratingSso(false);
      }
    })();
    const { data } = supabase.auth.onAuthStateChange((_event, s) => {
      if (mounted) setSession(s);
    });
    return () => {
      mounted = false;
      data.subscription.unsubscribe();
    };
  }, []);

  useEffect(() => {
    if (!session) {
      setAccess(null);
      setUserRoleId(null);
      setCurrentUserId(null);
      (async () => {
        const rpcRes = await supabase.rpc('list_public_schools');
        if (!rpcRes.error && Array.isArray(rpcRes.data) && rpcRes.data.length > 0) {
          const pubList = rpcRes.data as SchoolBasic[];
          setSchools(pubList);
          setSelectedSchoolId((prev) => prev ?? pubList[0]?.id_school ?? null);
          return;
        }
        const tblRes = await supabase
          .from('Schools')
          .select('*')
          .order('id_school');
        const tblList = (tblRes.data as SchoolBasic[] | null) ?? [];
        setSchools(tblList);
        setSelectedSchoolId((prev) => prev ?? tblList[0]?.id_school ?? null);
      })();
      return;
    }
    (async () => {
      const username = extractUsername(session.user.email);
      const [superRes, adminRes, schoolRes, schoolsRes, teacherRes, rolesRes] =
        await Promise.all([
          supabase.rpc('is_super_admin'),
          supabase.rpc('is_admin'),
          supabase.rpc('current_school_id'),
          supabase
            .from('Schools')
            .select('*')
            .order('id_school'),
          username
            ? supabase
                .from('Teachers')
                .select('id_user, fullName, id_role')
                .eq('username', username)
                .limit(1)
                .maybeSingle()
            : Promise.resolve({ data: null }),
          supabase.from('roles').select('ID_Roles, Accessrights'),
        ]);

      const schoolId =
        typeof schoolRes.data === 'number'
          ? schoolRes.data
          : Number(schoolRes.data) || null;
      const schoolList = (schoolsRes.data as SchoolBasic[] | null) ?? [];
      const isSuperUser = superRes.data === true;
      const requestedSchoolId = getTargetSchoolIdFromLeaveApp();

      setAccess({
        level: isSuperUser ? 'super' : adminRes.data === true ? 'school' : 'none',
        schoolId,
      });
      const teacherRow = teacherRes.data as {
        id_user?: number | null;
        fullName?: string | null;
        id_role?: number | null;
      } | null;
      const resolvedFullName = teacherRow?.fullName || username || 'ผู้ใช้งาน';
      const resolvedRoleId =
        typeof teacherRow?.id_role === 'number' ? teacherRow.id_role : null;
      const roleRow = (
        (rolesRes.data as { ID_Roles: number; Accessrights: string }[] | null) ?? []
      ).find((r) => r.ID_Roles === resolvedRoleId);
      const resolvedRoleName =
        roleRow?.Accessrights ||
        (isSuperUser || adminRes.data === true ? 'ผู้ดูแลระบบ' : 'ผู้ใช้งาน');

      setUserName(resolvedFullName);
      setUserRoleId(resolvedRoleId);
      setUserRoleName(resolvedRoleName);
      setCurrentUserId(
        typeof teacherRow?.id_user === 'number' ? teacherRow.id_user : null,
      );
      setSchools(schoolList);

      // ซิงก์ Session ขากลับไปยังแอประบบวันลาทันที
      syncSessionToLeaveApp(session, {
        fullName: resolvedFullName,
        roleName: resolvedRoleName,
      });

      // ผูกเข้ากับโรงเรียนของผู้ใช้เองอัตโนมัติ (หรือโรงเรียนที่ส่งมาจากแท็บแอปวันลา)
      const matchedRequested =
        requestedSchoolId &&
        schoolList.some((s) => s.id_school === requestedSchoolId)
          ? requestedSchoolId
          : null;

      if (!isSuperUser && schoolId) {
        setSelectedSchoolId(schoolId);
      } else {
        setSelectedSchoolId(
          matchedRequested ?? schoolId ?? schoolList[0]?.id_school ?? null,
        );
      }
    })();
  }, [session]);

  useEffect(() => {
    if (landedSuper || !access) return;
    setLandedSuper(true);
    if (access.level === 'super' && pathname === '/' && !isEmbeddedInLeaveApp()) {
      navigate('/hq', { replace: true });
    }
  }, [access, landedSuper, pathname, navigate]);

  const loadSchoolContext = useCallback(async () => {
    if (!selectedSchoolId) return;

    const [yearRes, termRes, modRes, treeRes, roleModPerms, webTabPermRes] =
      await Promise.all([
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
        fetchRoleDivisionModulePermissions(selectedSchoolId),
        supabase
          .from('Permissions')
          .select('id_role, status')
          .eq('id_school', selectedSchoolId)
          .eq('menu_id', 6),
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

    const webMap: Record<number, boolean> = {};
    for (const r of (webTabPermRes.data as { id_role: number; status: unknown }[] | null) ?? []) {
      const st = r.status;
      webMap[r.id_role] =
        st === true ||
        st === 1 ||
        String(st) === '1' ||
        String(st).toUpperCase() === 'TRUE';
    }

    setCatalog(treeRes.catalog);
    setDivisions(treeRes.divisions);
    setHasDbMapping(treeRes.hasDbMapping);
    setSchoolWebEnabled(treeRes.schoolPackage.schoolWebEnabled);
    setRoleDivModPerms(roleModPerms);
    setRoleWebAccessByRole(webMap);
  }, [selectedSchoolId]);

  useEffect(() => {
    loadSchoolContext();
  }, [loadSchoolContext]);

  const currentSchoolPreview =
    schools.find((s) => s.id_school === selectedSchoolId) ?? null;

  const canManagePublicWebPreview = Boolean(
    session &&
      canUserManagePublicSchoolWeb({
        perms: roleDivModPerms,
        roleId: userRoleId,
        idUser: currentUserId,
        isSuper: access?.level === 'super',
        isAdminRole:
          access?.level === 'super' || access?.level === 'school',
      }),
  );

  // หน้าเว็บโรงเรียนสำหรับคนนอกดู (Public Web) — เข้าดูได้ทันทีโดยไม่ต้องล็อกอิน
  if (pathname === '/public' || pathname.startsWith('/public/')) {
    return (
      <Routes>
        <Route
          path="/public"
          element={
            <PublicSchoolWebPage
              school={currentSchoolPreview}
              schools={schools}
              isLoggedIn={Boolean(session)}
              canManagePublicWeb={canManagePublicWebPreview}
            />
          }
        />
        <Route
          path="/public/:schoolId"
          element={
            <PublicSchoolWebPage
              school={currentSchoolPreview}
              schools={schools}
              isLoggedIn={Boolean(session)}
              canManagePublicWeb={canManagePublicWebPreview}
            />
          }
        />
      </Routes>
    );
  }

  if (hydratingSso) {
    return (
      <CenterScreen>
        <p className="text-sm text-slate-500">กำลังเชื่อมต่อข้อมูลโรงเรียน...</p>
      </CenterScreen>
    );
  }
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

  const userRoleTier = isSuper
    ? 'super_admin'
    : access.level === 'school'
      ? 'school_admin'
      : inferRoleTierFromRoleName(
          userRoleName,
          false,
          userRoleId,
          roleDivModPerms,
        );

  const roleLabel = `${ROLE_TIER_META[userRoleTier].shortLabel} (${userRoleName})`;

  const canManagePublicWeb = canUserManagePublicSchoolWeb({
    perms: roleDivModPerms,
    roleId: userRoleId,
    idUser: currentUserId,
    isSuper,
    isAdminRole: canEditSchool || userRoleTier === 'school_admin',
  });

  // ตรวจสอบว่าบุคลากรคนนี้มีสิทธิ์เข้าถึง Web โรงเรียนหรือไม่
  const userWebOverride =
    currentUserId !== null
      ? roleDivModPerms.userTabOverride[currentUserId]
      : undefined;
  const roleDefaultWebAccess =
    userRoleId !== null ? (roleWebAccessByRole[userRoleId] ?? true) : true;
  const canUserAccessSchoolWeb =
    canEditSchool ||
    canManagePublicWeb ||
    (userWebOverride !== undefined ? userWebOverride : roleDefaultWebAccess);

  // กรณีที่โรงเรียนปิดการใช้งานเว็บโรงเรียน หรือบุคลากรคนนี้ไม่มีสิทธิ์เข้าถึง Web โรงเรียน
  if ((!schoolWebEnabled || !canUserAccessSchoolWeb) && !isSuper) {
    return (
      <CenterScreen>
        <div className="surface-card max-w-md space-y-4 p-8 text-center">
          <div className="mx-auto inline-flex h-12 w-12 items-center justify-center rounded-2xl bg-brand-50 text-brand-600">
            <span className="text-lg font-semibold">รร.</span>
          </div>
          <h1 className="text-lg font-semibold text-ink">
            {currentSchool?.fullName || 'โรงเรียนของคุณ'}
          </h1>
          <p className="text-sm leading-relaxed text-slate-600">
            {!schoolWebEnabled
              ? 'โรงเรียนนี้ยังไม่ได้เปิดใช้เว็บโรงเรียน ใช้งานได้เฉพาะระบบวันลา'
              : 'บัญชีของคุณยังไม่ได้รับสิทธิ์ใช้เว็บโรงเรียน ติดต่อแอดมินโรงเรียนเพื่อขอสิทธิ์ · ระหว่างนี้ใช้ระบบวันลาได้ตามปกติ'}
          </p>
          <div className="flex flex-col gap-2 pt-2">
            <button
              type="button"
              onClick={() => navigateToLeaveApp()}
              className="btn-primary w-full justify-center"
            >
              เปิดระบบวันลา
            </button>
            <button
              type="button"
              onClick={() => {
                clearAllSsoSessions();
                supabase.auth.signOut();
              }}
              className="btn-secondary w-full justify-center text-xs"
            >
              ออกจากระบบ
            </button>
          </div>
        </div>
      </CenterScreen>
    );
  }

  // กรองฝ่ายและ Module ย่อยตามสังกัดฝ่ายของบุคลากรจริง (Auto-Visibility ตามฝ่าย) และระดับสิทธิ์ 4 ระดับ
  const staffFiltered = filterDivisionsByStaffMapping({
    divisions,
    perms: roleDivModPerms,
    roleTier: userRoleTier,
    roleId: userRoleId,
    idUser: currentUserId,
  });

  const visibleDivisions: DivisionWithModules[] = staffFiltered.visibleDivisions;

  const editableDivisionIds = divisions
    .filter(
      (div) =>
        staffFiltered.editableDivisionKeys.has(div.division_key),
    )
    .map((div) => div.id);

  const editableModuleKeys: string[] = [...staffFiltered.editableModuleKeys];

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
      onSignOut={() => {
        clearAllSsoSessions();
        supabase.auth.signOut();
      }}
      divisions={visibleDivisions}
      canManagePublicWeb={canManagePublicWeb}
      isEmbedded={isEmbeddedInLeaveApp()}
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
              canManagePublicWeb={canManagePublicWeb}
              academicLabel={academicLabel}
              divisions={visibleDivisions}
            />
          }
        />

        {/* หน้าตั้งค่าเว็บโรงเรียนสาธารณะ (สำหรับผู้ดูแลส่วนกลาง / แอดมินโรงเรียน / ครูผู้ดูแลเว็บโรงเรียน) */}
        <Route
          path="/public-web-settings"
          element={
            <PublicWebSettingsPage
              school={currentSchool}
              schoolId={selectedSchoolId}
              canManage={canManagePublicWeb}
            />
          }
        />
        <Route
          path="/admin/public-web"
          element={
            <PublicWebSettingsPage
              school={currentSchool}
              schoolId={selectedSchoolId}
              canManage={canManagePublicWeb}
            />
          }
        />

        {/* หน้ากลางของแต่ละฝ่าย (Dynamic Division Hub: แสดงเฉพาะ Module ที่ map อยู่กับฝ่ายนั้น) */}
        <Route
          path="/division/:divisionKey"
          element={
            <DivisionHubPage
              schoolId={selectedSchoolId}
              schoolName={currentSchool?.fullName || 'โรงเรียน'}
              canEdit={canEditSchool}
              editableDivisionIds={editableDivisionIds}
              editableModuleKeys={editableModuleKeys}
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
              schoolName={currentSchool?.fullName || 'โรงเรียน'}
              canEdit={canEditSchool}
              editableDivisionIds={editableDivisionIds}
              editableModuleKeys={editableModuleKeys}
              access={access}
              divisions={visibleDivisions}
            />
          }
        />

        {/* ② ตั้งค่าโรงเรียน — แอดมินโรงเรียน (โรงเรียนตัวเอง) / ส่วนกลาง (โรงเรียนที่เลือกในศูนย์ส่วนกลาง) */}
        {canEditSchool && (
          <>
            <Route
              path="/admin/mapping"
              element={
                <DivisionMappingPage
                  school={currentSchool}
                  schoolId={selectedSchoolId}
                  canEdit={canEditSchool}
                  isSuper={isSuper}
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
                  isSuper={isSuper}
                  divisions={divisions}
                  hasDbMapping={hasDbMapping}
                  onReload={loadSchoolContext}
                />
              }
            />
            <Route
              path="/user-permissions"
              element={
                <DivisionPermissionsPage
                  school={currentSchool}
                  schoolId={selectedSchoolId}
                  canEdit={canEditSchool}
                  isSuper={isSuper}
                  divisions={divisions}
                  hasDbMapping={hasDbMapping}
                  onReload={loadSchoolContext}
                  initialSection="individual"
                />
              }
            />
          </>
        )}
        {/* ② หน้าตั้งค่าระบบวันลาของโรงเรียน — ใช้โรงเรียนจากที่เดียว (selectedSchoolId)
            แอดมินโรงเรียน = โรงเรียนตัวเองเสมอ (ต้องรัน supabase/school_admin_leave_settings.sql) */}
        {canEditSchool && (
          <>
            <Route path="/staff" element={<StaffPage lockedSchoolId={selectedSchoolId} />} />
            <Route
              path="/admin-positions"
              element={<AdminPositionsPage lockedSchoolId={selectedSchoolId} />}
            />
            <Route path="/line" element={<LinePage lockedSchoolId={selectedSchoolId} />} />
            <Route
              path="/attendance"
              element={<AttendancePage lockedSchoolId={selectedSchoolId} />}
            />
            <Route
              path="/forms"
              element={
                selectedSchoolId ? (
                  <FormDesignerPage fixedScope={selectedSchoolId} />
                ) : (
                  <Navigate to="/hq" replace />
                )
              }
            />
            <Route path="/forms/leave" element={<Navigate to="/forms" replace />} />
          </>
        )}
        {/* ③ ศูนย์ผู้ดูแลส่วนกลาง */}
        {isSuper && (
          <>
            <Route path="/hq" element={<DashboardPage />} />
            <Route path="/hq/forms" element={<FormDesignerPage fixedScope="global" />} />
            <Route path="/hq/line" element={<LinePage />} />
            <Route path="/leave-admin" element={<Navigate to="/hq" replace />} />
            <Route path="/schools" element={<SchoolsPage />} />
            <Route path="/admins" element={<SchoolAdminsPage />} />
            <Route
              path="/role-permissions"
              element={
                <DivisionPermissionsPage
                  school={currentSchool}
                  schoolId={selectedSchoolId}
                  canEdit={canEditSchool}
                  isSuper={isSuper}
                  divisions={divisions}
                  hasDbMapping={hasDbMapping}
                  onReload={loadSchoolContext}
                  initialSection="package_ceiling"
                />
              }
            />
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
