import { useCallback, useEffect, useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import {
  ChevronDown,
  ChevronRight,
  Globe,
  Lock,
  RefreshCw,
  Search,
  ShieldCheck,
  UserCheck,
  Users,
} from 'lucide-react';
import AdminPositionsPage from '../pages/AdminPositionsPage';
import StaffPage from '../pages/StaffPage';
import { supabase } from '../supabase';
import PublicWebSettingsPage from './PublicWebSettingsPage';
import type { SchoolDepartment } from './types';

type HrSubTab =
  | 'internal'
  | 'staff_status'
  | 'admin_positions'
  | 'public_staff';

interface DepartmentsPageProps {
  schoolId: number | null;
  canEdit: boolean;
}

interface StaffMemberRow {
  id_user: number;
  fullName: string;
  username: string;
  id_role: number | null;
  roleName: string;
  positionName: string;
  academicName: string;
  adminRoleName: string;
  employmentStatus: string;
  deptId: number | null;
  deptName: string;
}

interface DepartmentGroup {
  id: number; // -1 = ยังไม่ระบุกลุ่มสาระ
  name: string;
  id_school: number | null;
  category: SchoolDepartment['category'];
  totalActiveCount: number; // ใช้เช็กล็อกปุ่มลบ (ป้องกันลบกลุ่มที่มีครูสังกัดในระบบวันลา)
  members: StaffMemberRow[];
}

const CATEGORY_LABEL: Record<SchoolDepartment['category'], string> = {
  management: 'ฝ่ายบริหาร',
  academic: 'กลุ่มสาระการเรียนรู้',
  support: 'งานสนับสนุน',
  department: 'หน่วยงานทั่วไป',
};

const STATUS_LABEL: Record<string, string> = {
  active: 'ปฏิบัติงาน',
  resigned: 'ลาออก',
  retired: 'เกษียณ',
  transferred: 'ย้าย',
};

function inferCategoryFromName(name: string): SchoolDepartment['category'] {
  const n = name.trim();
  if (
    n.includes('บริหาร') ||
    n.includes('อำนวยการ') ||
    n.includes('ผู้อำนวยการ')
  ) {
    return 'management';
  }
  if (
    n.includes('กลุ่มสาระ') ||
    n.includes('ภาษาไทย') ||
    n.includes('คณิต') ||
    n.includes('วิทย') ||
    n.includes('สังคม') ||
    n.includes('สุขศึกษา') ||
    n.includes('ศิลปะ') ||
    n.includes('การงาน') ||
    n.includes('ต่างประเทศ') ||
    n.includes('กิจกรรมพัฒนาผู้เรียน') ||
    n.includes('แนะแนว')
  ) {
    return 'academic';
  }
  if (
    n.includes('สนับสนุน') ||
    n.includes('ธุรการ') ||
    n.includes('พัสดุ') ||
    n.includes('การเงิน') ||
    n.includes('นักการ') ||
    n.includes('ลูกจ้าง') ||
    n.includes('โสต')
  ) {
    return 'support';
  }
  return 'department';
}

function extractDeptName(row: Record<string, unknown>): string {
  const raw =
    row.DepartmentsName ??
    row.departmentname ??
    row.name ??
    row.value ??
    row.department ??
    row['แผนก_กลุ่มสาระ'] ??
    '';
  return String(raw).trim();
}

function extractDeptId(row: Record<string, unknown>): number {
  return Number(
    row.ID_Departments ??
      row.id_departments ??
      row.id_department ??
      row.id ??
      0,
  );
}

/** ซิงก์ชื่อกลุ่มสาระเข้า SchoolDepartments เบื้องหลังเพื่อให้หน้าหลักสูตร/รายวิชาเห็นตรงกัน */
async function syncSilentToSchoolDepartments(
  schoolId: number,
  deptNames: string[],
) {
  try {
    const { data: existing } = await supabase
      .from('SchoolDepartments')
      .select('id, name')
      .eq('id_school', schoolId);

    const existingNames = new Set(
      ((existing as { id: number; name: string }[] | null) ?? []).map((r) =>
        r.name.trim().toLowerCase(),
      ),
    );
    const missing = deptNames.filter(
      (n) => n.trim() && !existingNames.has(n.trim().toLowerCase()),
    );
    if (missing.length === 0) return;

    await supabase.from('SchoolDepartments').insert(
      missing.map((n, idx) => ({
        id_school: schoolId,
        code: null,
        name: n.trim(),
        category: inferCategoryFromName(n),
        sort_order: existingNames.size + idx + 1,
        is_active: true,
      })),
    );
  } catch {
    // non-fatal background sync
  }
}

export default function DepartmentsPage({
  schoolId,
  canEdit,
}: DepartmentsPageProps) {
  const [rawDepts, setRawDepts] = useState<
    { id: number; name: string; id_school: number | null }[]
  >([]);
  const [allStaff, setAllStaff] = useState<StaffMemberRow[]>([]);
  const [loading, setLoading] = useState(true);

  // Filters & UI state
  const [searchParams, setSearchParams] = useSearchParams();
  const paramTab = searchParams.get('tab') as HrSubTab | null;
  const [hrTab, setHrTab] = useState<HrSubTab>(
    paramTab &&
      [
        'internal',
        'staff_status',
        'admin_positions',
        'public_staff',
      ].includes(paramTab)
      ? paramTab
      : 'internal',
  );

  useEffect(() => {
    if (
      paramTab &&
      [
        'internal',
        'staff_status',
        'admin_positions',
        'public_staff',
      ].includes(paramTab)
    ) {
      setHrTab(paramTab);
    }
  }, [paramTab]);

  const switchHrTab = (next: HrSubTab) => {
    setHrTab(next);
    if (next === 'internal') {
      searchParams.delete('tab');
    } else {
      searchParams.set('tab', next);
    }
    setSearchParams(searchParams, { replace: true });
  };

  const [query, setQuery] = useState('');
  const [onlyActive, setOnlyActive] = useState(true);
  const [collapsedIds, setCollapsedIds] = useState<Set<number>>(new Set());
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!schoolId) return;
    setLoading(true);
    setError(null);

    const [deptRes, teacherRes, roleRes, posRes, acadRes, adminRoleRes] =
      await Promise.all([
        supabase.from('departments').select('*'),
        supabase
          .from('Teachers')
          .select('*')
          .eq('id_school', schoolId)
          .order('fullName', { ascending: true }),
        supabase.from('roles').select('ID_Roles, Accessrights'),
        supabase.from('positions').select('*'),
        supabase.from('academics').select('*'),
        supabase.from('adminroles').select('*'),
      ]);

    if (deptRes.error) {
      setError(
        `โหลดข้อมูลกลุ่มสาระจากระบบวันลาไม่สำเร็จ: ${deptRes.error.message}`,
      );
      setLoading(false);
      return;
    }

    const roleMap = new Map<number, string>();
    for (const r of (roleRes.data as { ID_Roles: number; Accessrights: string }[] | null) ?? []) {
      roleMap.set(r.ID_Roles, r.Accessrights);
    }

    const posMap = new Map<number, string>();
    for (const p of (posRes.data as Record<string, unknown>[] | null) ?? []) {
      const id = Number(p.ID_Positions ?? p.id_position ?? p.id ?? 0);
      const name = String(p.positionName ?? p.name ?? '').trim();
      if (id && name) posMap.set(id, name);
    }

    const acadMap = new Map<number, string>();
    for (const a of (acadRes.data as Record<string, unknown>[] | null) ?? []) {
      const id = Number(a.ID_Academics ?? a.id_academic ?? a.id ?? 0);
      const name = String(a.AcademicsName ?? a.name ?? '').trim();
      if (id && name) acadMap.set(id, name);
    }

    const adminRoleMap = new Map<number, string>();
    for (const ar of (adminRoleRes.data as Record<string, unknown>[] | null) ?? []) {
      const id = Number(ar.ID_AdminRoles ?? ar.id_adminRole ?? ar.id ?? 0);
      const name = String(ar.AdminRolesName ?? ar.name ?? '').trim();
      if (id && name) adminRoleMap.set(id, name);
    }

    const deptRows = (deptRes.data as Record<string, unknown>[] | null) ?? [];
    const idToName = new Map<number, string>();
    const schoolDepts: { id: number; name: string; id_school: number | null }[] =
      [];

    for (const row of deptRows) {
      const rowSchool =
        row.id_school !== undefined && row.id_school !== null
          ? Number(row.id_school)
          : null;
      if (rowSchool !== null && rowSchool !== schoolId) continue;
      const dId = extractDeptId(row);
      const dName = extractDeptName(row);
      if (!dId || !dName) continue;
      idToName.set(dId, dName);
      schoolDepts.push({ id: dId, name: dName, id_school: rowSchool });
    }

    schoolDepts.sort((a, b) => a.id - b.id);

    const teacherRows =
      (teacherRes.data as Record<string, unknown>[] | null) ?? [];
    const parsedStaff: StaffMemberRow[] = teacherRows.map((t) => {
      const depIdRaw = Number(
        t.ID_Departments ?? t.id_department ?? t.department_id ?? 0,
      );
      const depId = depIdRaw > 0 ? depIdRaw : null;
      const depName =
        (depId && idToName.get(depId)) ||
        String(
          t.department ?? t.departmentName ?? t.DepartmentsName ?? '',
        ).trim();
      const roleId =
        t.id_role !== undefined && t.id_role !== null ? Number(t.id_role) : null;
      const posId = Number(t.ID_Positions ?? t.id_position ?? 0);
      const acadId = Number(t.ID_Academics ?? t.id_academic ?? 0);
      const adminRoleId = Number(t.ID_AdminRoles ?? t.id_adminRole ?? 0);

      const positionName =
        (posId && posMap.get(posId)) ||
        String(t.position ?? t.positionName ?? '').trim() ||
        '-';
      const academicName =
        (acadId && acadMap.get(acadId)) ||
        String(t.academic ?? t.AcademicsName ?? '').trim() ||
        '-';
      const adminRoleName =
        (adminRoleId && adminRoleMap.get(adminRoleId)) ||
        String(t.adminRole ?? t.AdminRolesName ?? '').trim() ||
        '-';

      return {
        id_user: Number(t.id_user ?? 0),
        fullName: String(t.fullName ?? '').trim() || '-',
        username: String(t.username ?? '').trim() || '-',
        id_role: roleId,
        roleName: roleId ? (roleMap.get(roleId) ?? '-') : '-',
        positionName,
        academicName,
        adminRoleName,
        employmentStatus: String(t.employment_status ?? 'active') || 'active',
        deptId: depId,
        deptName: depName,
      };
    });

    setRawDepts(schoolDepts);
    setAllStaff(parsedStaff);
    setLoading(false);

    if (canEdit && schoolDepts.length > 0) {
      void syncSilentToSchoolDepartments(
        schoolId,
        schoolDepts.map((d) => d.name),
      );
    }
  }, [schoolId, canEdit]);

  useEffect(() => {
    load();
  }, [load]);

  // จัดกลุ่มบุคลากรตามกลุ่มสาระ/แผนก + รองรับค้นหาและกรองเฉพาะผู้ปฏิบัติงาน
  const { groups, totalVisibleStaff } = useMemo(() => {
    const q = query.trim().toLowerCase();

    // นับจำนวน active staff ทั้งหมดของแต่ละกลุ่ม (ใช้ป้องกันการลบ)
    const activeCountByDeptId = new Map<number, number>();
    const activeCountByDeptName = new Map<string, number>();
    for (const s of allStaff) {
      if (s.employmentStatus !== 'active') continue;
      if (s.deptId) {
        activeCountByDeptId.set(
          s.deptId,
          (activeCountByDeptId.get(s.deptId) ?? 0) + 1,
        );
      }
      if (s.deptName) {
        const key = s.deptName.toLowerCase();
        activeCountByDeptName.set(
          key,
          (activeCountByDeptName.get(key) ?? 0) + 1,
        );
      }
    }

    const visibleStaff = allStaff.filter((s) => {
      if (onlyActive && s.employmentStatus !== 'active') return false;
      return true;
    });

    const deptIdSet = new Set(rawDepts.map((d) => d.id));
    const deptNameToId = new Map(
      rawDepts.map((d) => [d.name.toLowerCase(), d.id]),
    );

    const membersByDeptId = new Map<number, StaffMemberRow[]>();
    const unassigned: StaffMemberRow[] = [];

    for (const s of visibleStaff) {
      let targetId: number | null = null;
      if (s.deptId && deptIdSet.has(s.deptId)) {
        targetId = s.deptId;
      } else if (s.deptName && deptNameToId.has(s.deptName.toLowerCase())) {
        targetId = deptNameToId.get(s.deptName.toLowerCase()) ?? null;
      }

      if (targetId !== null) {
        const list = membersByDeptId.get(targetId) ?? [];
        list.push(s);
        membersByDeptId.set(targetId, list);
      } else {
        unassigned.push(s);
      }
    }

    const builtGroups: DepartmentGroup[] = [];

    for (const d of rawDepts) {
      const allMembers = membersByDeptId.get(d.id) ?? [];
      const deptNameMatch = !q || d.name.toLowerCase().includes(q);
      const filteredMembers = deptNameMatch
        ? allMembers
        : allMembers.filter(
            (m) =>
              m.fullName.toLowerCase().includes(q) ||
              m.username.toLowerCase().includes(q) ||
              m.roleName.toLowerCase().includes(q),
          );

      if (q && !deptNameMatch && filteredMembers.length === 0) continue;

      builtGroups.push({
        id: d.id,
        name: d.name,
        id_school: d.id_school,
        category: inferCategoryFromName(d.name),
        totalActiveCount:
          activeCountByDeptId.get(d.id) ??
          activeCountByDeptName.get(d.name.toLowerCase()) ??
          0,
        members: filteredMembers,
      });
    }

    const filteredUnassigned = !q
      ? unassigned
      : unassigned.filter(
          (m) =>
            m.fullName.toLowerCase().includes(q) ||
            m.username.toLowerCase().includes(q) ||
            m.roleName.toLowerCase().includes(q) ||
            'ยังไม่ระบุกลุ่มสาระ'.includes(q),
        );

    if (filteredUnassigned.length > 0) {
      builtGroups.push({
        id: -1,
        name: 'ยังไม่ระบุกลุ่มสาระ / แผนก',
        id_school: null,
        category: 'department',
        totalActiveCount: filteredUnassigned.length,
        members: filteredUnassigned,
      });
    }

    const totalStaff = builtGroups.reduce((sum, g) => sum + g.members.length, 0);
    return { groups: builtGroups, totalVisibleStaff: totalStaff };
  }, [rawDepts, allStaff, query, onlyActive]);

  const toggleCollapse = (id: number) => {
    setCollapsedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const expandAll = () => setCollapsedIds(new Set());
  const collapseAll = () => setCollapsedIds(new Set(groups.map((g) => g.id)));

  return (
    <div className="space-y-5">
      {/* แท็บย่อยของฝ่ายบริหารงานบุคคล (รวม 4 งานในหน้าเดียว) */}
      <div className="flex flex-wrap gap-1.5 rounded-2xl border border-slate-200/80 bg-white p-1.5 shadow-card">
        <button
          type="button"
          onClick={() => switchHrTab('internal')}
          className={`inline-flex items-center gap-2 rounded-xl px-3.5 py-2 text-xs font-medium transition-all ${
            hrTab === 'internal'
              ? 'bg-brand-600 text-white shadow-sm'
              : 'text-slate-600 hover:bg-slate-100 hover:text-ink'
          }`}
        >
          <Users className="h-4 w-4" />
          <span>1. ทะเบียนบุคลากรตามกลุ่มสาระ</span>
        </button>
        {canEdit && (
          <>
            <button
              type="button"
              onClick={() => switchHrTab('staff_status')}
              className={`inline-flex items-center gap-2 rounded-xl px-3.5 py-2 text-xs font-medium transition-all ${
                hrTab === 'staff_status'
                  ? 'bg-brand-600 text-white shadow-sm'
                  : 'text-slate-600 hover:bg-slate-100 hover:text-ink'
              }`}
            >
              <UserCheck className="h-4 w-4" />
              <span>2. จัดการสถานะบุคลากร</span>
            </button>
            <button
              type="button"
              onClick={() => switchHrTab('admin_positions')}
              className={`inline-flex items-center gap-2 rounded-xl px-3.5 py-2 text-xs font-medium transition-all ${
                hrTab === 'admin_positions'
                  ? 'bg-brand-600 text-white shadow-sm'
                  : 'text-slate-600 hover:bg-slate-100 hover:text-ink'
              }`}
            >
              <ShieldCheck className="h-4 w-4" />
              <span>3. ตำแหน่งบริหาร</span>
            </button>
          </>
        )}
        <button
          type="button"
          onClick={() => switchHrTab('public_staff')}
          className={`inline-flex items-center gap-2 rounded-xl px-3.5 py-2 text-xs font-medium transition-all ${
            hrTab === 'public_staff'
              ? 'bg-brand-600 text-white shadow-sm'
              : 'text-slate-600 hover:bg-slate-100 hover:text-ink'
          }`}
        >
          <Globe className="h-4 w-4" />
          <span>
            {canEdit ? '4.' : '2.'} ทำเนียบบุคลากร (เว็บสาธารณะ)
          </span>
        </button>
      </div>

      {hrTab === 'staff_status' ? (
        <StaffPage lockedSchoolId={schoolId} />
      ) : hrTab === 'admin_positions' ? (
        <AdminPositionsPage lockedSchoolId={schoolId} />
      ) : hrTab === 'public_staff' ? (
        <PublicWebSettingsPage
          school={
            schoolId
              ? { id_school: schoolId, fullName: null, affiliation: null }
              : null
          }
          schoolId={schoolId}
          canManage={canEdit}
          initialSection="staff"
          allowedSections={['staff']}
          customTitle="จัดการทำเนียบบุคลากรบนเว็บสาธารณะ (ฝ่ายบริหารงานบุคคล)"
          customSubtitle="ดึงรายชื่อจากฐานข้อมูลบุคลากร หรือปรับแต่งข้อมูลคณะผู้บริหารและคณาจารย์ที่แสดงบนหน้าเว็บโรงเรียนสาธารณะ"
        />
      ) : (
        <>
          {error && <div className="alert-error text-sm">{error}</div>}

      {/* แถบค้นหา + ตัวกรอง (Read-Only จากระบบวันลา) */}
      <section className="surface-card p-5 space-y-3">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="relative flex-1 min-w-[240px] max-w-md">
            <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
            <input
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="ค้นหาชื่อ-สกุล, ตำแหน่ง, วิทยฐานะ หรือชื่อกลุ่มสาระ..."
              className="input pl-9"
            />
          </div>

          <div className="flex flex-wrap items-center gap-3 text-xs">
            <label className="inline-flex items-center gap-2 text-slate-700 cursor-pointer">
              <input
                type="checkbox"
                checked={onlyActive}
                onChange={(e) => setOnlyActive(e.target.checked)}
                className="checkbox"
              />
              <span>เฉพาะผู้ปฏิบัติงาน</span>
            </label>
            <span className="rounded-lg bg-brand-50 px-2.5 py-1 font-semibold text-brand-700 tabular-nums">
              {totalVisibleStaff} คน • {groups.length} กลุ่มสาระ/แผนก
            </span>
            <div className="flex items-center gap-1.5">
              <button
                type="button"
                onClick={expandAll}
                className="btn-secondary btn-sm"
              >
                ขยายทั้งหมด
              </button>
              <button
                type="button"
                onClick={collapseAll}
                className="btn-secondary btn-sm"
              >
                ยุบทั้งหมด
              </button>
              <button
                type="button"
                onClick={load}
                disabled={loading}
                className="btn-secondary btn-sm"
              >
                <RefreshCw
                  className={`h-3.5 w-3.5 ${loading ? 'animate-spin' : ''}`}
                />
                <span>รีเฟรช</span>
              </button>
            </div>
          </div>
        </div>
        <div className="flex items-center gap-2 border-t border-line pt-2.5 text-xs text-slate-500">
          <Lock className="h-3.5 w-3.5 text-brand-600" />
          <span>
            เชื่อมข้อมูลกลุ่มสาระ ตำแหน่ง วิทยฐานะ และตำแหน่งบริหารจากระบบวันลาโดยตรงแบบ Read-Only (ไม่กระทบหรือแก้ไขข้อมูลในระบบวันลา)
          </span>
        </div>
      </section>

      {/* รายชื่อบุคลากรแยกตามกลุ่มสาระ/แผนก */}
      {loading ? (
        <div className="surface-card p-10 text-center text-sm text-slate-500">
          กำลังโหลดข้อมูลบุคลากรและกลุ่มสาระจากฐานข้อมูล...
        </div>
      ) : groups.length === 0 ? (
        <div className="surface-card p-10 text-center text-sm text-slate-500">
          ไม่พบข้อมูลกลุ่มสาระหรือบุคลากรที่ตรงกับเงื่อนไขการค้นหา
        </div>
      ) : (
        <div className="space-y-4">
          {groups.map((group) => {
            const isCollapsed = collapsedIds.has(group.id) && !query.trim();
            const isVirtual = group.id < 0;
            const isSharedGlobal = !isVirtual && group.id_school === null;

            return (
              <section
                key={group.id}
                className="surface-card overflow-hidden"
              >
                {/* หัวการ์ดกลุ่มสาระ */}
                <div className="flex flex-col gap-3 border-b border-line bg-slate-50/70 px-5 py-3.5 sm:flex-row sm:items-center sm:justify-between">
                  <div className="flex min-w-0 flex-1 items-center gap-2.5">
                    <button
                      type="button"
                      onClick={() => toggleCollapse(group.id)}
                      className="rounded-lg p-1 text-slate-500 hover:bg-slate-200/70 hover:text-ink"
                      aria-label={isCollapsed ? 'ขยายรายชื่อ' : 'ยุบรายชื่อ'}
                    >
                      {isCollapsed ? (
                        <ChevronRight className="h-4 w-4" />
                      ) : (
                        <ChevronDown className="h-4 w-4" />
                      )}
                    </button>

                    <button
                      type="button"
                      onClick={() => toggleCollapse(group.id)}
                      className="flex flex-wrap items-center gap-2 text-left min-w-0"
                    >
                      <h3 className="text-sm font-semibold text-ink">
                        {group.name}
                      </h3>
                      <span className="rounded bg-brand-50 px-2 py-0.5 text-[11px] font-medium text-brand-700">
                        {CATEGORY_LABEL[group.category]}
                      </span>
                      <span
                        className={`inline-flex items-center gap-1 rounded px-2 py-0.5 text-[11px] font-semibold ${
                          group.members.length > 0
                            ? 'bg-emerald-50 text-emerald-700'
                            : 'bg-slate-100 text-slate-500'
                        }`}
                      >
                        <Users className="h-3 w-3" />
                        <span>{group.members.length} คน</span>
                      </span>
                      {isSharedGlobal && (
                        <span className="inline-flex items-center gap-1 rounded bg-slate-100 px-2 py-0.5 text-[11px] text-slate-500">
                          <Lock className="h-3 w-3" />
                          <span>ข้อมูลจากระบบวันลา</span>
                        </span>
                      )}
                    </button>
                  </div>
                </div>

                {/* ตารางรายชื่อบุคลากรในกลุ่มสาระนี้ */}
                {!isCollapsed && (
                  <div className="overflow-x-auto">
                    {group.members.length === 0 ? (
                      <p className="px-5 py-4 text-xs text-slate-400">
                        ยังไม่มีบุคลากรในกลุ่มสาระ/แผนกนี้
                      </p>
                    ) : (
                      <table className="table">
                        <thead>
                          <tr>
                            <th className="w-12 text-center">#</th>
                            <th>ชื่อ-นามสกุล</th>
                            <th>ตำแหน่ง / วิทยฐานะ</th>
                            <th>ตำแหน่งบริหาร</th>
                            <th>บทบาท</th>
                            <th className="w-28 text-center">สถานะ</th>
                          </tr>
                        </thead>
                        <tbody>
                          {group.members.map((m, idx) => (
                            <tr key={m.id_user}>
                              <td className="text-center text-xs text-slate-400 tabular-nums">
                                {idx + 1}
                              </td>
                              <td>
                                <div className="font-medium text-ink">
                                  {m.fullName}
                                </div>
                                <div className="text-xs text-slate-400">
                                  {m.username}
                                </div>
                              </td>
                              <td className="text-slate-700">
                                <div>{m.positionName}</div>
                                {m.academicName &&
                                  m.academicName !== '-' &&
                                  m.academicName !== 'ไม่มี' && (
                                    <div className="text-xs text-brand-600">
                                      {m.academicName}
                                    </div>
                                  )}
                              </td>
                              <td className="text-slate-600">
                                {m.adminRoleName &&
                                m.adminRoleName !== '-' &&
                                m.adminRoleName !== 'ไม่มี' ? (
                                  <span className="inline-flex rounded bg-amber-50 px-2 py-0.5 text-xs font-medium text-amber-800">
                                    {m.adminRoleName}
                                  </span>
                                ) : (
                                  <span className="text-xs text-slate-400">
                                    -
                                  </span>
                                )}
                              </td>
                              <td className="text-slate-600">{m.roleName}</td>
                              <td className="text-center">
                                <span
                                  className={
                                    m.employmentStatus === 'active'
                                      ? 'badge-green'
                                      : 'badge-slate'
                                  }
                                >
                                  {STATUS_LABEL[m.employmentStatus] ??
                                    m.employmentStatus}
                                </span>
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    )}
                  </div>
                )}
              </section>
            );
          })}
        </div>
      )}
        </>
      )}
    </div>
  );
}
