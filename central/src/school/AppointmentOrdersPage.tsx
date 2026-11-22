import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  ArrowDown,
  ArrowUp,
  Check,
  Filter,
  ImagePlus,
  Plus,
  Save,
  Search,
  Trash2,
  Upload,
  UserCheck,
} from 'lucide-react';
import { supabase } from '../supabase';
import {
  ALL_ARABIC_DIGITS,
  composeOfficialPosition,
  createDefaultOrderDraft,
  fileToPngDataUrl,
  getSavedSchoolEmblem,
  saveSchoolEmblem,
  type AppointmentOrderFull,
  type AppointmentOrderRecord,
  type DigitFormatSettings,
  type OrderGroupDraft,
  type OrderMemberDraft,
  DEFAULT_EFFECTIVE_TEXT,
  WORKING_ROLE_OPTIONS,
  GROUP_KIND_LABELS,
  PERSON_DUTY_INTRO,
  computeHeadingLabels,
  groupKind,
  groupLevel,
  groupNumbered,
  type OrderGroupKind,
} from './appointmentOrders';
import { exportAppointmentOrderToDocx } from './exportOrderDocx';
import type { DivisionWithModules } from './mapping';
import OrderWordPreviewPane from './OrderWordPreviewPane';

interface AppointmentOrdersPageProps {
  schoolId: number | null;
  schoolName: string;
  division: DivisionWithModules;
  canEdit: boolean;
}

export interface StaffOption {
  id_user: number;
  fullName: string;
  adminRoleName: string;      // ตำแหน่งบริหาร (จาก adminroles)
  departmentName: string;     // กลุ่มสาระการเรียนรู้ (จาก departments)
  positionName: string;       // ตำแหน่งสายงาน (จาก positions / roles)
  academicStanding: string;   // วิทยฐานะ (จาก academics)
  displayPosition: string;    // ตำแหน่งที่แสดงในคำสั่งแต่งตั้ง
}


export default function AppointmentOrdersPage({
  schoolId,
  schoolName,
  division,
  canEdit,
}: AppointmentOrdersPageProps) {
  const [orders, setOrders] = useState<AppointmentOrderRecord[]>([]);
  const [scopeFilter, setScopeFilter] = useState<'division' | 'school'>('division');
  const [selectedOrderId, setSelectedOrderId] = useState<number | 'new'>('new');
  const [staffList, setStaffList] = useState<StaffOption[]>([]);

  // Filter Dropdown Options from DB
  const [adminRoleOptions, setAdminRoleOptions] = useState<string[]>([]);
  const [departmentOptions, setDepartmentOptions] = useState<string[]>([]);
  const [academicOptions, setAcademicOptions] = useState<string[]>([]);

  const [mobilePane, setMobilePane] = useState<'editor' | 'preview'>('editor');
  const [digitSettings, setDigitSettings] =
    useState<DigitFormatSettings>(ALL_ARABIC_DIGITS);

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [exportingDocx, setExportingDocx] = useState(false);
  const [message, setMessage] = useState<{
    type: 'ok' | 'err';
    text: string;
  } | null>(null);

  // Draft state (Left Pane)
  const [draft, setDraft] = useState<Omit<AppointmentOrderFull, 'id'>>(() => {
    const base = createDefaultOrderDraft(
      schoolId ?? 0,
      division.id,
      division.division_key,
      division.name,
      '1',
    );
    return {
      ...base,
      groups: base.groups.map((g) => ({ ...g, members: [] })),
    };
  });
  // เลขข้อของทุกหัวข้อ (ป้ายในฟอร์ม ใช้เลขอารบิก)
  const headingLabels = useMemo(
    () => computeHeadingLabels(draft.groups, false),
    [draft.groups],
  );

  // Load staff list + master filter options + existing orders
  const loadInitialData = useCallback(async () => {
    if (!schoolId) return;
    setLoading(true);

    const [
      ordersRes,
      teachersRes,
      rolesRes,
      adminRolesRes,
      departmentsRes,
      schoolDeptsRes,
      positionsRes,
      academicsRes,
    ] = await Promise.all([
      supabase
        .from('SchoolWebOrders')
        .select('*')
        .eq('id_school', schoolId)
        .order('order_year', { ascending: false })
        .order('id', { ascending: false }),
      supabase
        .from('Teachers')
        .select('*')
        .eq('id_school', schoolId)
        .order('fullName', { ascending: true }),
      supabase.from('roles').select('ID_Roles, Accessrights'),
      supabase
        .from('adminroles')
        .select('ID_AdminRoles, AdminRolesName')
        .eq('id_school', schoolId),
      supabase
        .from('departments')
        .select('ID_Departments, DepartmentsName')
        .eq('id_school', schoolId),
      supabase
        .from('SchoolDepartments')
        .select('id, name')
        .eq('id_school', schoolId),
      supabase.from('positions').select('ID_Positions, positionName'),
      supabase.from('academics').select('ID_Academics, AcademicsName'),
    ]);

    const roleMap = new Map<number, string>();
    for (const r of (rolesRes.data as { ID_Roles: number; Accessrights: string }[] | null) ?? []) {
      if (r.Accessrights?.trim()) roleMap.set(r.ID_Roles, r.Accessrights.trim());
    }

    const adminRoleMap = new Map<number, string>();
    const adminSet = new Set<string>();
    for (const ar of (adminRolesRes.data as { ID_AdminRoles: number; AdminRolesName: string | null }[] | null) ?? []) {
      const name = (ar.AdminRolesName || '').trim();
      if (name && name !== '-' && name !== 'ไม่มีตำแหน่งบริหาร') {
        adminRoleMap.set(ar.ID_AdminRoles, name);
        adminSet.add(name);
      }
    }

    const deptMap = new Map<number, string>();
    const deptSet = new Set<string>();
    for (const d of (departmentsRes.data as { ID_Departments: number; DepartmentsName: string | null }[] | null) ?? []) {
      const name = (d.DepartmentsName || '').trim();
      if (name && name !== '-') {
        deptMap.set(d.ID_Departments, name);
        deptSet.add(name);
      }
    }
    for (const sd of (schoolDeptsRes.data as { id: number; name: string | null }[] | null) ?? []) {
      const name = (sd.name || '').trim();
      if (name && name !== '-') {
        deptSet.add(name);
      }
    }

    const posMap = new Map<number, string>();
    for (const p of (positionsRes.data as { ID_Positions: number; positionName: string | null }[] | null) ?? []) {
      const name = (p.positionName || '').trim();
      if (name && name !== '-') {
        posMap.set(p.ID_Positions, name);
      }
    }

    const acadMap = new Map<number, string>();
    const acadSet = new Set<string>(['ไม่มีวิทยฐานะ']);
    for (const ac of (academicsRes.data as { ID_Academics: number; AcademicsName: string | null }[] | null) ?? []) {
      const name = (ac.AcademicsName || '').trim();
      if (name && name !== '-') {
        acadMap.set(ac.ID_Academics, name);
        acadSet.add(name);
      }
    }

    const rawTeachers = (teachersRes.data as Record<string, unknown>[] | null) ?? [];
    const activeTeachers: StaffOption[] = rawTeachers
      .filter((t) => {
        const status = String(t.employment_status || 'active');
        return status === 'active' && !t.is_super_admin;
      })
      .map((t) => {
        const idUser = Number(t.id_user);
        const fullName =
          String(t.fullName || '').trim() || `บุคลากร #${idUser}`;

        // 1) ตำแหน่งบริหาร
        const idAdminRole = Number(t.id_adminrole);
        const rawAdminName =
          (idAdminRole ? adminRoleMap.get(idAdminRole) : '') ||
          String(t['ตำแหน่งงานบริหาร'] || '').trim();
        const adminRoleName =
          rawAdminName && rawAdminName !== 'ไม่มีตำแหน่งบริหาร' && rawAdminName !== '-'
            ? rawAdminName
            : '';
        if (adminRoleName) adminSet.add(adminRoleName);

        // 2) กลุ่มสาระการเรียนรู้
        const idDept = Number(t.id_department);
        const rawDeptName =
          (idDept ? deptMap.get(idDept) : '') ||
          String(t.department || '').trim();
        const departmentName =
          rawDeptName && rawDeptName !== '-' ? rawDeptName : '';
        if (departmentName) deptSet.add(departmentName);

        // 3) ตำแหน่งสายงาน
        const idPosition = Number(t.id_position);
        const idRole = Number(t.id_role);
        const positionName =
          (idPosition ? posMap.get(idPosition) : '') ||
          String(t.position || '').trim() ||
          (idRole ? roleMap.get(idRole) : '') ||
          'ครู';

        // 4) วิทยฐานะ
        const idAcademic = Number(
          t.ID_Academics ?? t.id_academic ?? t.id_academics ?? 0,
        );
        const rawAcad =
          (idAcademic ? acadMap.get(idAcademic) : '') ||
          String(t.academicStanding ?? t['วิทยฐานะ'] ?? '').trim();
        const academicStanding =
          rawAcad && rawAcad !== 'ไม่มีวิทยฐานะ' && rawAcad !== '-'
            ? rawAcad
            : 'ไม่มีวิทยฐานะ';
        if (academicStanding) acadSet.add(academicStanding);

        // ตำแหน่งที่จะแสดงในตารางและในเอกสาร Word
        const basePos = adminRoleName || positionName;
        const displayPosition = composeOfficialPosition(
          basePos,
          academicStanding === 'ไม่มีวิทยฐานะ' ? '' : academicStanding,
        );

        return {
          id_user: idUser,
          fullName,
          adminRoleName,
          departmentName,
          positionName,
          academicStanding,
          displayPosition,
        };
      });

    setStaffList(activeTeachers);
    setAdminRoleOptions([...adminSet]);
    setDepartmentOptions([...deptSet]);
    setAcademicOptions([...acadSet]);

    const dbOrders = (ordersRes.data as AppointmentOrderRecord[] | null) ?? [];
    setOrders(dbOrders);
    setLoading(false);
  }, [schoolId]);

  useEffect(() => {
    loadInitialData();
  }, [loadInitialData]);

  const filteredOrders = useMemo(() => {
    if (scopeFilter === 'school') return orders;
    return orders.filter((o) => o.division_key === division.division_key);
  }, [orders, scopeFilter, division.division_key]);

  const nextOrderNo = useMemo(() => {
    const nums = orders
      .map((o) => Number.parseInt(o.order_no, 10))
      .filter((n) => !Number.isNaN(n) && n > 0);
    return nums.length > 0 ? String(Math.max(...nums) + 1) : '1';
  }, [orders]);

  const selectExistingOrder = useCallback(
    async (orderId: number) => {
      const header = orders.find((o) => o.id === orderId);
      if (!header) return;
      setSelectedOrderId(orderId);
      setMessage(null);

      const [groupsRes, membersRes] = await Promise.all([
        supabase
          .from('SchoolWebOrderGroups')
          .select('*')
          .eq('order_id', orderId)
          .order('group_no', { ascending: true }),
        supabase
          .from('SchoolWebOrderMembers')
          .select('*')
          .eq('order_id', orderId)
          .order('member_no', { ascending: true }),
      ]);

      const rawGroups =
        (groupsRes.data as {
          id: number;
          group_no: number;
          group_title: string;
          duties: unknown;
          kind?: OrderGroupKind | null;
          level?: number | null;
          numbered?: boolean | null;
        }[] | null) ?? [];
      const rawMembers =
        (membersRes.data as {
          id: number;
          group_id: number;
          member_no: number;
          id_user: number | null;
          full_name: string;
          official_position: string;
          working_role: string;
        }[] | null) ?? [];

      const builtGroups: OrderGroupDraft[] = rawGroups.map((g, idx) => {
        const gMembers: OrderMemberDraft[] = rawMembers
          .filter((m) => m.group_id === g.id)
          .map((m, mIdx) => ({
            id: m.id,
            member_no: mIdx + 1,
            id_user: m.id_user,
            full_name: m.full_name,
            official_position: m.official_position,
            working_role: m.working_role,
          }));
        const gDuties = Array.isArray(g.duties)
          ? g.duties.map((d) => String(d))
          : [''];
        return {
          id: g.id,
          group_no: idx + 1,
          group_title: g.group_title,
          duties: gDuties.length > 0 ? gDuties : [''],
          members: gMembers,
          kind: g.kind ?? 'committee',
          level: g.level === 2 ? 2 : 1,
          numbered: g.numbered ?? true,
        };
      });

      const savedEmblem = getSavedSchoolEmblem(header.id_school);
      setDraft({
        id_school: header.id_school,
        division_id: header.division_id,
        division_key: header.division_key,
        order_no: header.order_no,
        order_year: header.order_year,
        subject: header.subject,
        preamble: header.preamble,
        effective_text: header.effective_text,
        order_date: header.order_date,
        signer_name: header.signer_name,
        signer_title: header.signer_title,
        sign_first: header.sign_first ?? false,
        emblem_data_url: savedEmblem.dataUrl,
        emblem_height_cm: savedEmblem.heightCm,
        groups:
          builtGroups.length > 0
            ? builtGroups
            : createDefaultOrderDraft(
                header.id_school,
                division.id,
                division.division_key,
                division.name,
              ).groups.map((g) => ({ ...g, members: [] })),
      });
    },
    [orders, division.id, division.division_key, division.name],
  );

  function handleStartNewOrder() {
    if (!schoolId) return;
    setSelectedOrderId('new');
    setMessage(null);
    const savedEmblem = getSavedSchoolEmblem(schoolId);
    const base = createDefaultOrderDraft(
      schoolId,
      division.id,
      division.division_key,
      division.name,
      nextOrderNo,
    );
    setDraft({
      ...base,
      emblem_data_url: savedEmblem.dataUrl,
      emblem_height_cm: savedEmblem.heightCm,
      groups: base.groups.map((g) => ({ ...g, members: [] })),
    });
  }

  useEffect(() => {
    if (!schoolId) return;
    setSelectedOrderId('new');
    const savedEmblem = getSavedSchoolEmblem(schoolId);
    const base = createDefaultOrderDraft(
      schoolId,
      division.id,
      division.division_key,
      division.name,
      nextOrderNo,
    );
    setDraft({
      ...base,
      emblem_data_url: savedEmblem.dataUrl,
      emblem_height_cm: savedEmblem.heightCm,
      groups: base.groups.map((g) => ({ ...g, members: [] })),
    });
  }, [schoolId, division.id, division.division_key, division.name, nextOrderNo]);

  // --- Garuda Emblem (ตราครุฑ) Upload Handlers ---
  async function handleUploadEmblem(file?: File | null) {
    if (!file) return;
    try {
      const { dataUrl: pngDataUrl } = await fileToPngDataUrl(file);
      const heightCm = draft.emblem_height_cm || 3.0;
      setDraft((prev) => ({
        ...prev,
        emblem_data_url: pngDataUrl,
        emblem_height_cm: heightCm,
      }));
      saveSchoolEmblem(schoolId, pngDataUrl, heightCm);
    } catch (err) {
      setMessage({
        type: 'err',
        text:
          err instanceof Error
            ? err.message
            : 'ไม่สามารถอัปโหลดรูปตราครุฑได้',
      });
    }
  }

  function handleChangeEmblemHeight(heightCm: number) {
    setDraft((prev) => {
      saveSchoolEmblem(schoolId, prev.emblem_data_url || '', heightCm);
      return {
        ...prev,
        emblem_height_cm: heightCm,
      };
    });
  }

  function handleRemoveEmblem() {
    setDraft((prev) => ({
      ...prev,
      emblem_data_url: '',
    }));
    saveSchoolEmblem(schoolId, '', draft.emblem_height_cm || 3.0);
  }

  // --- Group (ข้อ 1, 2, 3...) Handlers ---
  function addGroup(kind: OrderGroupKind = 'committee') {
    setDraft((prev) => {
      const nextNo = prev.groups.length + 1;
      const preset: Record<OrderGroupKind, { title: string; duties: string[]; numbered: boolean }> = {
        section: { title: 'กลุ่มบริหาร........', duties: [], numbered: false },
        committee: {
          title: 'งาน........ ประกอบด้วย',
          duties: ['ดำเนินการตามภารกิจที่ได้รับมอบหมายให้เป็นไปด้วยความเรียบร้อย'],
          numbered: true,
        },
        person: {
          title: 'รองผู้อำนวยการกลุ่มบริหาร........',
          duties: ['ปฏิบัติหน้าที่อื่น ๆ ตามที่ได้รับมอบหมาย'],
          numbered: false,
        },
      };
      const p = preset[kind];
      return {
        ...prev,
        groups: [
          ...prev.groups,
          {
            group_no: nextNo,
            group_title: p.title,
            members: [],
            duties: p.duties,
            kind,
            level: 1,
            numbered: p.numbered,
          },
        ],
      };
    });
  }

  function updateGroupLayout(
    groupIdx: number,
    patch: Partial<Pick<OrderGroupDraft, 'kind' | 'level' | 'numbered'>>,
  ) {
    setDraft((prev) => {
      const copy = [...prev.groups];
      copy[groupIdx] = { ...copy[groupIdx], ...patch };
      return { ...prev, groups: copy };
    });
  }

  function removeGroup(groupIdx: number) {
    setDraft((prev) => {
      if (prev.groups.length <= 1) return prev;
      const nextGroups = prev.groups
        .filter((_, idx) => idx !== groupIdx)
        .map((g, idx) => ({ ...g, group_no: idx + 1 }));
      return { ...prev, groups: nextGroups };
    });
  }

  function moveGroup(groupIdx: number, direction: -1 | 1) {
    setDraft((prev) => {
      const targetIdx = groupIdx + direction;
      if (targetIdx < 0 || targetIdx >= prev.groups.length) return prev;
      const copy = [...prev.groups];
      const temp = copy[groupIdx];
      copy[groupIdx] = copy[targetIdx];
      copy[targetIdx] = temp;
      return {
        ...prev,
        groups: copy.map((g, idx) => ({ ...g, group_no: idx + 1 })),
      };
    });
  }

  function updateGroupTitle(groupIdx: number, title: string) {
    setDraft((prev) => {
      const copy = [...prev.groups];
      copy[groupIdx] = { ...copy[groupIdx], group_title: title };
      return { ...prev, groups: copy };
    });
  }

  // --- Save Picked Members from Filter Table into Group ---
  function appendPickedMembersToGroup(
    groupIdx: number,
    picked: { teacher: StaffOption; workingRole: string }[],
  ) {
    if (picked.length === 0) return;
    setDraft((prev) => {
      const copy = [...prev.groups];
      const g = copy[groupIdx];
      const existing = [...g.members];

      for (const item of picked) {
        const existingIdx = existing.findIndex(
          (m) => m.id_user === item.teacher.id_user,
        );
        if (existingIdx >= 0) {
          existing[existingIdx] = {
            ...existing[existingIdx],
            full_name: item.teacher.fullName,
            official_position: item.teacher.displayPosition,
            working_role: item.workingRole,
          };
        } else {
          existing.push({
            member_no: existing.length + 1,
            id_user: item.teacher.id_user,
            full_name: item.teacher.fullName,
            official_position: item.teacher.displayPosition,
            working_role: item.workingRole,
          });
        }
      }

      copy[groupIdx] = {
        ...g,
        members: existing.map((m, idx) => ({ ...m, member_no: idx + 1 })),
      };
      return { ...prev, groups: copy };
    });
  }

  function updateSavedMemberRole(
    groupIdx: number,
    memberIdx: number,
    workingRole: string,
  ) {
    setDraft((prev) => {
      const copy = [...prev.groups];
      const g = copy[groupIdx];
      const members = [...g.members];
      members[memberIdx] = { ...members[memberIdx], working_role: workingRole };
      copy[groupIdx] = { ...g, members };
      return { ...prev, groups: copy };
    });
  }

  function removeSavedMember(groupIdx: number, memberIdx: number) {
    setDraft((prev) => {
      const copy = [...prev.groups];
      const g = copy[groupIdx];
      const nextMembers = g.members
        .filter((_, idx) => idx !== memberIdx)
        .map((m, idx) => ({ ...m, member_no: idx + 1 }));
      copy[groupIdx] = { ...g, members: nextMembers };
      return { ...prev, groups: copy };
    });
  }

  // --- Duties (หน้าที่ 1, 2...) Handlers ---
  function addDuty(groupIdx: number) {
    setDraft((prev) => {
      const copy = [...prev.groups];
      const g = copy[groupIdx];
      copy[groupIdx] = { ...g, duties: [...g.duties, ''] };
      return { ...prev, groups: copy };
    });
  }

  function updateDuty(groupIdx: number, dutyIdx: number, text: string) {
    setDraft((prev) => {
      const copy = [...prev.groups];
      const g = copy[groupIdx];
      const duties = [...g.duties];
      duties[dutyIdx] = text;
      copy[groupIdx] = { ...g, duties };
      return { ...prev, groups: copy };
    });
  }

  function removeDuty(groupIdx: number, dutyIdx: number) {
    setDraft((prev) => {
      const copy = [...prev.groups];
      const g = copy[groupIdx];
      if (g.duties.length <= 1) {
        copy[groupIdx] = { ...g, duties: [''] };
        return { ...prev, groups: copy };
      }
      copy[groupIdx] = {
        ...g,
        duties: g.duties.filter((_, idx) => idx !== dutyIdx),
      };
      return { ...prev, groups: copy };
    });
  }

  // --- Save & Delete Order ---
  async function handleSaveOrder() {
    if (!schoolId || !canEdit) return;
    if (!draft.subject.trim()) {
      setMessage({ type: 'err', text: 'กรุณาระบุชื่อเรื่องของคำสั่ง' });
      return;
    }

    setSaving(true);
    setMessage(null);

    try {
      let targetOrderId: number;

      const orderPayload = {
        id_school: schoolId,
        division_id: division.id > 0 ? division.id : null,
        division_key: draft.division_key || division.division_key,
        order_no: draft.order_no.trim() || '1',
        order_year: Number(draft.order_year) || new Date().getFullYear() + 543,
        subject: draft.subject.trim(),
        preamble: draft.preamble.trim(),
        effective_text:
          draft.effective_text.trim() || DEFAULT_EFFECTIVE_TEXT,
        order_date: draft.order_date,
        signer_name: draft.signer_name.trim(),
        signer_title: draft.signer_title.trim(),
        sign_first: draft.sign_first ?? false,
        updated_at: new Date().toISOString(),
      };
      // ยังไม่ได้รัน supabase/school_web_appointment_orders_part2.sql → คอลัมน์ใหม่ไม่มี
      const isMissingColumn = (msg?: string) =>
        !!msg && /column|schema cache/i.test(msg) && /(sign_first|kind|level|numbered)/.test(msg);
      let legacySchema = false;
      const withoutNewOrderCols = () => {
        const { sign_first: _omit, ...rest } = orderPayload;
        return rest;
      };

      if (selectedOrderId === 'new') {
        let { data: insOrder, error: insErr } = await supabase
          .from('SchoolWebOrders')
          .insert(orderPayload)
          .select('id')
          .single();
        if (insErr && isMissingColumn(insErr.message)) {
          legacySchema = true;
          ({ data: insOrder, error: insErr } = await supabase
            .from('SchoolWebOrders')
            .insert(withoutNewOrderCols())
            .select('id')
            .single());
        }
        if (insErr || !insOrder) {
          throw new Error(insErr?.message || 'ไม่สามารถสร้างคำสั่งได้');
        }
        targetOrderId = insOrder.id;
      } else {
        targetOrderId = selectedOrderId;
        let { error: updErr } = await supabase
          .from('SchoolWebOrders')
          .update(orderPayload)
          .eq('id', targetOrderId);
        if (updErr && isMissingColumn(updErr.message)) {
          legacySchema = true;
          ({ error: updErr } = await supabase
            .from('SchoolWebOrders')
            .update(withoutNewOrderCols())
            .eq('id', targetOrderId));
        }
        if (updErr) throw new Error(updErr.message);

        await supabase
          .from('SchoolWebOrderGroups')
          .delete()
          .eq('order_id', targetOrderId);
      }

      for (let gIdx = 0; gIdx < draft.groups.length; gIdx++) {
        const g = draft.groups[gIdx];
        const cleanDuties = g.duties.map((d) => d.trim()).filter(Boolean);

        const baseGroupRow = {
          id_school: schoolId,
          order_id: targetOrderId,
          group_no: gIdx + 1,
          group_title: g.group_title.trim() || `คณะทำงานชุดที่ ${gIdx + 1}`,
          duties: groupKind(g) === 'section' ? [] : cleanDuties,
        };
        const layoutCols = {
          kind: groupKind(g),
          level: groupLevel(g),
          numbered: groupNumbered(g),
        };
        let { data: insGroup, error: gErr } = await supabase
          .from('SchoolWebOrderGroups')
          .insert(legacySchema ? baseGroupRow : { ...baseGroupRow, ...layoutCols })
          .select('id')
          .single();
        if (gErr && isMissingColumn(gErr.message)) {
          legacySchema = true;
          ({ data: insGroup, error: gErr } = await supabase
            .from('SchoolWebOrderGroups')
            .insert(baseGroupRow)
            .select('id')
            .single());
        }

        if (gErr || !insGroup) {
          throw new Error(gErr?.message || 'บันทึกชุดคณะทำงานไม่สำเร็จ');
        }

        const validMembers =
          groupKind(g) === 'section' ? [] : g.members.filter((m) => m.full_name.trim());
        if (validMembers.length > 0) {
          const memberRows = validMembers.map((m, mIdx) => ({
            id_school: schoolId,
            order_id: targetOrderId,
            group_id: insGroup.id,
            member_no: mIdx + 1,
            id_user: m.id_user,
            full_name: m.full_name.trim(),
            official_position: m.official_position.trim(),
            working_role: m.working_role.trim() || 'กรรมการ',
          }));

          const { error: mErr } = await supabase
            .from('SchoolWebOrderMembers')
            .insert(memberRows);
          if (mErr) throw new Error(mErr.message);
        }
      }

      await loadInitialData();
      setSelectedOrderId(targetOrderId);
      setMessage(
        legacySchema
          ? {
              type: 'err',
              text: `บันทึกคำสั่งที่ ${orderPayload.order_no}/${orderPayload.order_year} แล้ว แต่ชนิดหัวข้อ / ข้อย่อย / ลงนามหน้าแรก ยังไม่ถูกบันทึก — ให้ผู้ดูแลรัน supabase/school_web_appointment_orders_part2.sql`,
            }
          : {
              type: 'ok',
              text: `บันทึกคำสั่งที่ ${orderPayload.order_no}/${orderPayload.order_year} เรียบร้อยแล้ว`,
            },
      );
    } catch (err) {
      setMessage({
        type: 'err',
        text: err instanceof Error ? err.message : 'เกิดข้อผิดพลาดในการบันทึก',
      });
    } finally {
      setSaving(false);
    }
  }

  async function handleDeleteOrder() {
    if (selectedOrderId === 'new' || !canEdit) return;
    setSaving(true);
    setMessage(null);
    const { error } = await supabase
      .from('SchoolWebOrders')
      .delete()
      .eq('id', selectedOrderId);
    setSaving(false);
    if (error) {
      setMessage({ type: 'err', text: `ลบไม่สำเร็จ: ${error.message}` });
      return;
    }
    await loadInitialData();
    handleStartNewOrder();
    setMessage({ type: 'ok', text: 'ลบคำสั่งแต่งตั้งเรียบร้อยแล้ว' });
  }

  return (
    <div className="space-y-4">
      {/* Top Action Bar */}
      <div className="surface-card p-4">
        <div className="flex flex-col gap-3 xl:flex-row xl:items-center xl:justify-between">
          <div className="flex flex-wrap items-center gap-2 sm:flex-nowrap">
            <div className="inline-flex shrink-0 rounded-lg border border-line bg-canvas p-0.5">
              <button
                type="button"
                onClick={() => setScopeFilter('division')}
                className={` whitespace-nowrap rounded-md px-2.5 py-1 text-xs font-medium transition-colors ${
                  scopeFilter === 'division'
                    ? 'bg-white text-ink shadow-sm'
                    : 'text-slate-500 hover:text-ink'
                }`}
              >
                เฉพาะ{division.name}
              </button>
              <button
                type="button"
                onClick={() => setScopeFilter('school')}
                className={`whitespace-nowrap rounded-md px-2.5 py-1 text-xs font-medium transition-colors ${
                  scopeFilter === 'school'
                    ? 'bg-white text-ink shadow-sm'
                    : 'text-slate-500 hover:text-ink'
                }`}
              >
                ทุกฝ่ายในโรงเรียน ({orders.length})
              </button>
            </div>

            <select
              value={selectedOrderId}
              onChange={(e) => {
                const val = e.target.value;
                if (val === 'new') handleStartNewOrder();
                else selectExistingOrder(Number(val));
              }}
              aria-label="เลือกคำสั่งแต่งตั้ง"
              className="input !w-auto min-w-[210px] max-w-xs flex-1 py-1.5 text-xs sm:flex-initial"
            >
              <option value="new">
                + ร่างคำสั่งแต่งตั้งใหม่ (ที่ {nextOrderNo}/{draft.order_year})
              </option>
              {filteredOrders.map((o) => (
                <option key={o.id} value={o.id}>
                  คำสั่งที่ {o.order_no}/{o.order_year} — {o.subject}
                </option>
              ))}
            </select>

            <button
              type="button"
              onClick={handleStartNewOrder}
              className="btn-secondary btn-sm shrink-0 whitespace-nowrap"
            >
              <Plus className="h-3.5 w-3.5" strokeWidth={1.5} />
              <span>สร้างคำสั่งใหม่</span>
            </button>
          </div>

          <div className="flex flex-wrap items-center gap-2 sm:flex-nowrap">
            <div className="inline-flex rounded-lg border border-line bg-canvas p-0.5 lg:hidden">
              <button
                type="button"
                onClick={() => setMobilePane('editor')}
                className={`rounded-md px-3 py-1 text-xs font-medium ${
                  mobilePane === 'editor'
                    ? 'bg-white text-brand-700 shadow-sm'
                    : 'text-slate-600'
                }`}
              >
                ฝั่งซ้าย: จัดการข้อมูล
              </button>
              <button
                type="button"
                onClick={() => setMobilePane('preview')}
                className={`rounded-md px-3 py-1 text-xs font-medium ${
                  mobilePane === 'preview'
                    ? 'bg-white text-brand-700 shadow-sm'
                    : 'text-slate-600'
                }`}
              >
                ฝั่งขวา: ตัวอย่าง Word
              </button>
            </div>

            {canEdit && selectedOrderId !== 'new' && (
              <button
                type="button"
                disabled={saving}
                onClick={handleDeleteOrder}
                className="btn-secondary btn-sm text-rose-600 hover:bg-rose-50"
              >
                <Trash2 className="h-3.5 w-3.5" strokeWidth={1.5} />
                <span>ลบคำสั่ง</span>
              </button>
            )}

            {canEdit && (
              <button
                type="button"
                disabled={saving || loading}
                onClick={handleSaveOrder}
                className="btn-primary btn-sm"
              >
                <Save className="h-3.5 w-3.5" strokeWidth={1.5} />
                <span>
                  {saving
                    ? 'กำลังบันทึก...'
                    : selectedOrderId === 'new'
                      ? 'บันทึกคำสั่งแต่งตั้ง'
                      : 'บันทึกการแก้ไข'}
                </span>
              </button>
            )}
          </div>
        </div>

        {message && (
          <div
            className={`mt-3 flex items-center gap-2 rounded-lg border px-3 py-2 text-xs font-medium ${
              message.type === 'ok'
                ? 'border-emerald-200 bg-emerald-50 text-emerald-800'
                : 'border-rose-200 bg-rose-50 text-rose-700'
            }`}
          >
            <Check className="h-3.5 w-3.5 shrink-0" strokeWidth={2} />
            <span>{message.text}</span>
          </div>
        )}
      </div>

      {/* Main 2-Pane Split View: Left = Form Manager, Right = Live Word Preview */}
      <div className="grid gap-6 lg:grid-cols-12 lg:items-start">
        {/* ==================== ฝั่งซ้าย: จัดการข้อมูลคำสั่งแต่งตั้ง ==================== */}
        <div
          className={`space-y-5 lg:col-span-6 ${
            mobilePane === 'preview' ? 'hidden lg:block' : 'block'
          }`}
        >
          {/* 1) ส่วนหัวคำสั่ง และข้อความเกริ่นนำ */}
          <section className="surface-card space-y-4 p-5">
            <div className="border-b border-line pb-3">
              <h2 className="text-sm font-semibold text-ink">
                ส่วนที่ 1 · หัวคำสั่ง ตราครุฑ และข้อความเกริ่นนำ
              </h2>
              <p className="mt-0.5 text-xs text-slate-500">
                อัปโหลดรูปตราครุฑสำหรับแสดงหัวคำสั่ง ระบุเลขที่คำสั่ง ชื่อเรื่อง และย่อหน้าข้อความต้นเรื่อง
              </p>
            </div>

            {/* อัปโหลดรูปตราครุฑ (Garuda Emblem Image Upload) */}
            <div className="rounded-xl border border-line bg-canvas/60 p-3.5">
              <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                <div className="flex items-center gap-3">
                  <div className="flex h-16 w-16 shrink-0 items-center justify-center overflow-hidden rounded-lg border border-line bg-white p-1.5">
                    {draft.emblem_data_url ? (
                      <img
                        src={draft.emblem_data_url}
                        alt="ตราครุฑ"
                        className="max-h-full max-w-full object-contain"
                      />
                    ) : (
                      <ImagePlus
                        className="h-6 w-6 text-slate-400"
                        strokeWidth={1.5}
                      />
                    )}
                  </div>

                  <div>
                    <p className="text-xs font-semibold text-ink">
                      ตราครุฑหัวคำสั่ง (อัปโหลดรูปภาพ PNG / JPG)
                    </p>
                    <p className="mt-0.5 text-[11px] text-slate-500">
                      จะแสดงกึ่งกลางด้านบนสุดของคำสั่งทั้งในตัวอย่างกระดาษ A4, การสั่งพิมพ์/PDF และฝังลงในไฟล์ Word (.docx)
                    </p>
                  </div>
                </div>

                <div className="flex flex-wrap items-center gap-2">
                  {/* เลือกขนาดความสูงตราครุฑตามระเบียบงานสารบรรณ */}
                  <div
                    className="inline-flex rounded-lg border border-line bg-white p-0.5"
                    title="ขนาดความสูงตราครุฑ"
                  >
                    {[1.5, 2.5, 3.0].map((cm) => {
                      const active = (draft.emblem_height_cm || 3.0) === cm;
                      return (
                        <button
                          key={cm}
                          type="button"
                          onClick={() => handleChangeEmblemHeight(cm)}
                          className={`rounded px-2 py-1 text-[11px] font-medium tabular-nums transition-colors ${
                            active
                              ? 'bg-brand-600 text-white'
                              : 'text-slate-600 hover:text-ink'
                          }`}
                        >
                          {cm} ซม.
                        </button>
                      );
                    })}
                  </div>

                  <label className="btn-secondary btn-sm cursor-pointer">
                    <Upload className="h-3.5 w-3.5" strokeWidth={1.5} />
                    <span>
                      {draft.emblem_data_url
                        ? 'เปลี่ยนรูปตราครุฑ'
                        : 'อัปโหลดรูปตราครุฑ'}
                    </span>
                    <input
                      type="file"
                      accept="image/png,image/jpeg,image/webp"
                      className="hidden"
                      onChange={(e) => {
                        handleUploadEmblem(e.target.files?.[0]);
                        e.currentTarget.value = '';
                      }}
                    />
                  </label>

                  {draft.emblem_data_url && (
                    <button
                      type="button"
                      onClick={handleRemoveEmblem}
                      className="btn-secondary btn-sm text-rose-600 hover:bg-rose-50"
                      title="ลบรูปตราครุฑออก"
                    >
                      <Trash2 className="h-3.5 w-3.5" strokeWidth={1.5} />
                    </button>
                  )}
                </div>
              </div>
            </div>

            <div className="grid gap-3 sm:grid-cols-12">
              <div className="sm:col-span-3">
                <label className="mb-1 block text-xs font-medium text-ink">
                  คำสั่งที่
                </label>
                <input
                  type="text"
                  disabled={!canEdit}
                  value={draft.order_no}
                  onChange={(e) =>
                    setDraft((prev) => ({ ...prev, order_no: e.target.value }))
                  }
                  placeholder="1"
                  className="input tabular-nums"
                />
              </div>

              <div className="sm:col-span-3">
                <label className="mb-1 block text-xs font-medium text-ink">
                  ปี พ.ศ.
                </label>
                <input
                  type="number"
                  disabled={!canEdit}
                  value={draft.order_year}
                  onChange={(e) =>
                    setDraft((prev) => ({
                      ...prev,
                      order_year: Number(e.target.value) || 2569,
                    }))
                  }
                  className="input tabular-nums"
                />
              </div>

              <div className="sm:col-span-6">
                <label className="mb-1 block text-xs font-medium text-ink">
                  สังกัดฝ่ายงาน
                </label>
                <input
                  type="text"
                  disabled
                  value={division.name}
                  className="input bg-canvas text-slate-600"
                />
              </div>

              <div className="sm:col-span-12">
                <label className="mb-1 block text-xs font-medium text-ink">
                  เรื่อง
                </label>
                <input
                  type="text"
                  disabled={!canEdit}
                  value={draft.subject}
                  onChange={(e) =>
                    setDraft((prev) => ({ ...prev, subject: e.target.value }))
                  }
                  placeholder="เช่น แต่งตั้งคณะทำงานดำเนินโครงการ..."
                  className="input"
                />
              </div>

              <div className="sm:col-span-12">
                <label className="mb-1 block text-xs font-medium text-ink">
                  ข้อความ (ย่อหน้าเกริ่นนำก่อนข้อ 1)
                </label>
                <textarea
                  rows={3}
                  disabled={!canEdit}
                  value={draft.preamble}
                  onChange={(e) =>
                    setDraft((prev) => ({ ...prev, preamble: e.target.value }))
                  }
                  placeholder="เพื่อให้การดำเนินงาน..."
                  className="input py-2 leading-relaxed"
                />
              </div>
            </div>
          </section>

          {/* 2) ส่วนชุดคณะทำงาน ข้อ 1, 2, 3... */}
          <section className="space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-sm font-semibold text-ink">
                  ส่วนที่ 2 · หัวข้อ คณะ และหน้าที่ ({draft.groups.length} หัวข้อ)
                </h2>
                <p className="text-xs text-slate-500">
                  จัดเป็นชั้นได้: หัวข้อกลุ่ม → คณะ/งาน (ข้อหลัก ๖.) → งานย่อย (๖.๑) · เลขข้อนับใหม่ทุกหัวข้อกลุ่ม
                </p>
              </div>
              {canEdit && (
                <div className="flex flex-wrap justify-end gap-1.5">
                  <button type="button" onClick={() => addGroup('section')} className="btn-secondary btn-sm">
                    <Plus className="h-3.5 w-3.5" strokeWidth={1.5} />
                    <span>หัวข้อกลุ่ม</span>
                  </button>
                  <button type="button" onClick={() => addGroup('person')} className="btn-secondary btn-sm">
                    <Plus className="h-3.5 w-3.5" strokeWidth={1.5} />
                    <span>รายบุคคล</span>
                  </button>
                  <button type="button" onClick={() => addGroup('committee')} className="btn-primary btn-sm">
                    <Plus className="h-3.5 w-3.5" strokeWidth={1.5} />
                    <span>คณะ / งาน</span>
                  </button>
                </div>
              )}
            </div>

            {draft.groups.map((group, gIdx) => {
              const kind = groupKind(group);
              const label = headingLabels[gIdx];
              return (
              <div
                key={gIdx}
                className={`surface-card space-y-4 p-5 ${groupLevel(group) === 2 && kind !== 'section' ? 'ml-6 border-l-2 border-l-brand-200' : ''} ${kind === 'section' ? 'bg-slate-50' : ''}`}
              >
                {/* หัวข้อชุดคณะทำงาน เช่น 1. คณะทำงานด้านอำนวยการ (ยังเหมือนเดิม) */}
                <div className="flex flex-col gap-2 border-b border-line pb-3 sm:flex-row sm:items-center sm:justify-between">
                  <div className="flex flex-1 items-center gap-2">
                    <span className="inline-flex h-7 min-w-7 shrink-0 items-center justify-center rounded-lg bg-brand-50 px-1 font-semibold tabular-nums text-xs text-brand-700">
                      {label || '–'}
                    </span>
                    <input
                      type="text"
                      disabled={!canEdit}
                      value={group.group_title}
                      onChange={(e) => updateGroupTitle(gIdx, e.target.value)}
                      placeholder={
                        kind === 'section'
                          ? 'เช่น กลุ่มบริหารวิชาการ'
                          : kind === 'person'
                            ? 'ตำแหน่งที่แสดงหลังชื่อ เช่น รองผู้อำนวยการกลุ่มบริหารวิชาการ'
                            : 'เช่น งานพัฒนาหลักสูตรสถานศึกษา ประกอบด้วย'
                      }
                      className="input font-medium"
                    />
                  </div>

                  {canEdit && (
                    <div className="flex shrink-0 items-center gap-1">
                      <button
                        type="button"
                        disabled={gIdx === 0}
                        onClick={() => moveGroup(gIdx, -1)}
                        className="rounded-lg border border-line p-1.5 text-slate-500 hover:bg-slate-50 disabled:opacity-40"
                        title="เลื่อนขึ้น"
                      >
                        <ArrowUp className="h-3.5 w-3.5" strokeWidth={1.5} />
                      </button>
                      <button
                        type="button"
                        disabled={gIdx === draft.groups.length - 1}
                        onClick={() => moveGroup(gIdx, 1)}
                        className="rounded-lg border border-line p-1.5 text-slate-500 hover:bg-slate-50 disabled:opacity-40"
                        title="เลื่อนลง"
                      >
                        <ArrowDown className="h-3.5 w-3.5" strokeWidth={1.5} />
                      </button>
                      {draft.groups.length > 1 && (
                        <button
                          type="button"
                          onClick={() => removeGroup(gIdx)}
                          className="rounded-lg border border-line p-1.5 text-slate-400 hover:border-rose-200 hover:bg-rose-50 hover:text-rose-600"
                          title="ลบคณะทำงานชุดนี้"
                        >
                          <Trash2 className="h-3.5 w-3.5" strokeWidth={1.5} />
                        </button>
                      )}
                    </div>
                  )}
                </div>

                {/* ชนิดหัวข้อ / ชั้น / เลขข้อ */}
                <div className="flex flex-wrap items-center gap-3 text-xs">
                  <select
                    disabled={!canEdit}
                    value={kind}
                    onChange={(e) => {
                      const k = e.target.value as OrderGroupKind;
                      updateGroupLayout(gIdx, {
                        kind: k,
                        numbered: k === 'committee',
                      });
                    }}
                    className="input w-auto py-1 text-xs"
                  >
                    {(Object.keys(GROUP_KIND_LABELS) as OrderGroupKind[]).map((k) => (
                      <option key={k} value={k}>
                        {GROUP_KIND_LABELS[k]}
                      </option>
                    ))}
                  </select>
                  {kind !== 'section' && (
                    <>
                      <select
                        disabled={!canEdit}
                        value={groupLevel(group)}
                        onChange={(e) =>
                          updateGroupLayout(gIdx, {
                            level: Number(e.target.value) === 2 ? 2 : 1,
                          })
                        }
                        className="input w-auto py-1 text-xs"
                      >
                        <option value={1}>ข้อหลัก (๖.)</option>
                        <option value={2}>ข้อย่อย (๖.๑)</option>
                      </select>
                      <label className="inline-flex items-center gap-1.5 text-slate-600">
                        <input
                          type="checkbox"
                          className="checkbox"
                          disabled={!canEdit}
                          checked={groupNumbered(group)}
                          onChange={(e) =>
                            updateGroupLayout(gIdx, { numbered: e.target.checked })
                          }
                        />
                        แสดงเลขข้อ
                      </label>
                    </>
                  )}
                  {kind === 'person' && (
                    <span className="text-slate-500">
                      ใช้รายชื่อคนแรก แสดงเป็น "ชื่อ ⇥ ตำแหน่ง" ตามด้วย "{PERSON_DUTY_INTRO}"
                    </span>
                  )}
                </div>

                {kind !== 'section' && (
                <>
                {/* ส่วนของ รายชื่อในข้อที่ ... (Filter ด้านบน + ตารางติ๊กเลือก + บันทึกเข้าข้อนี้) */}
                <GroupMemberSelectorSection
                  groupNo={gIdx + 1}
                  groupTitle={group.group_title}
                  savedMembers={group.members}
                  staffList={staffList}
                  adminRoleOptions={adminRoleOptions}
                  departmentOptions={departmentOptions}
                  academicOptions={academicOptions}
                  canEdit={canEdit}
                  onSavePicked={(picked) =>
                    appendPickedMembersToGroup(gIdx, picked)
                  }
                  onUpdateSavedRole={(mIdx, role) =>
                    updateSavedMemberRole(gIdx, mIdx, role)
                  }
                  onRemoveSavedMember={(mIdx) => removeSavedMember(gIdx, mIdx)}
                />

                {/* หน้าที่ของคณะทำงานชุดนี้ */}
                <div className="space-y-2 border-t border-line pt-3">
                  <div className="flex items-center justify-between">
                    <p className="text-xs font-medium text-slate-600">
                      หน้าที่ (ของ {label ? `ข้อ ${label} ` : ''}{group.group_title})
                    </p>
                    {canEdit && (
                      <button
                        type="button"
                        onClick={() => addDuty(gIdx)}
                        className="text-xs font-medium text-brand-600 hover:text-brand-700"
                      >
                        + เพิ่มข้อหน้าที่
                      </button>
                    )}
                  </div>

                  <div className="space-y-2">
                    {group.duties.map((duty, dIdx) => (
                      <div key={dIdx} className="flex items-center gap-2">
                        <span className="w-6 shrink-0 text-right tabular-nums text-xs text-slate-500">
                          {dIdx + 1}.
                        </span>
                        <input
                          type="text"
                          disabled={!canEdit}
                          value={duty}
                          onChange={(e) => updateDuty(gIdx, dIdx, e.target.value)}
                          placeholder="ระบุหน้าที่รับผิดชอบ..."
                          className="input py-1.5 text-xs"
                        />
                        {canEdit && (
                          <button
                            type="button"
                            onClick={() => removeDuty(gIdx, dIdx)}
                            className="rounded p-1 text-slate-400 hover:bg-rose-50 hover:text-rose-600"
                            title="ลบข้อหน้าที่"
                          >
                            <Trash2 className="h-3.5 w-3.5" strokeWidth={1.5} />
                          </button>
                        )}
                      </div>
                    ))}
                  </div>
                </div>
                </>
                )}
              </div>
              );
            })}
          </section>

          {/* 3) ส่วนท้ายคำสั่ง วันที่สั่ง และผู้ลงนาม */}
          <section className="surface-card space-y-4 p-5">
            <div className="border-b border-line pb-3">
              <h2 className="text-sm font-semibold text-ink">
                ส่วนที่ 3 · วันที่มีผลบังคับใช้ และผู้ลงนามคำสั่ง
              </h2>
              <p className="mt-0.5 text-xs text-slate-500">
                ระบุข้อความท้ายคำสั่ง วันที่สั่ง และผู้ลงนามคำสั่ง
              </p>
            </div>

            <label className="flex items-start gap-2 rounded-lg border border-line p-3 text-xs text-slate-700">
              <input
                type="checkbox"
                className="checkbox mt-0.5"
                disabled={!canEdit}
                checked={draft.sign_first ?? false}
                onChange={(e) =>
                  setDraft((prev) => ({ ...prev, sign_first: e.target.checked }))
                }
              />
              <span>
                <span className="font-medium text-ink">ลงนามหน้าแรก แล้วต่อด้วยรายละเอียดแนบท้าย</span>
                <br />
                ข้อความท้าย วันที่สั่ง และผู้ลงนาม อยู่ต่อจากคำเกริ่น (เหมือนคำสั่งแต่งตั้งประจำภาคเรียน) รายชื่อคณะทั้งหมดตามมาหลังลายเซ็น
              </span>
            </label>

            <div className="grid gap-3 sm:grid-cols-12">
              <div className="sm:col-span-7">
                <label className="mb-1 block text-xs font-medium text-ink">
                  ข้อความท้ายคำสั่ง (1 บรรทัด = 1 ย่อหน้า)
                </label>
                <textarea
                  rows={4}
                  disabled={!canEdit}
                  value={draft.effective_text}
                  onChange={(e) =>
                    setDraft((prev) => ({
                      ...prev,
                      effective_text: e.target.value,
                    }))
                  }
                  placeholder={DEFAULT_EFFECTIVE_TEXT}
                  className="input"
                />
              </div>

              <div className="sm:col-span-5">
                <label className="mb-1 block text-xs font-medium text-ink">
                  สั่ง ณ วันที่
                </label>
                <input
                  type="date"
                  disabled={!canEdit}
                  value={draft.order_date}
                  onChange={(e) =>
                    setDraft((prev) => ({ ...prev, order_date: e.target.value }))
                  }
                  className="input tabular-nums"
                />
              </div>

              {canEdit && staffList.length > 0 && (
                <div className="sm:col-span-12">
                  <label className="mb-1 block text-xs font-medium text-slate-500">
                    เลือกผู้บริหาร/ผู้ลงนามจากรายชื่อบุคลากร
                  </label>
                  <select
                    value=""
                    onChange={(e) => {
                      const t = staffList.find(
                        (s) => s.id_user === Number(e.target.value),
                      );
                      if (t) {
                        setDraft((prev) => ({
                          ...prev,
                          signer_name: t.fullName,
                          signer_title: t.displayPosition,
                        }));
                      }
                    }}
                    className="input py-1.5 text-xs"
                  >
                    <option value="">-- เลือกชื่อผู้ลงนาม --</option>
                    {staffList.map((t) => (
                      <option key={t.id_user} value={t.id_user}>
                        {t.fullName} ({t.displayPosition})
                      </option>
                    ))}
                  </select>
                </div>
              )}

              <div className="sm:col-span-6">
                <label className="mb-1 block text-xs font-medium text-ink">
                  ชื่อผู้ลงนาม (ในวงเล็บ)
                </label>
                <input
                  type="text"
                  disabled={!canEdit}
                  value={draft.signer_name}
                  onChange={(e) =>
                    setDraft((prev) => ({ ...prev, signer_name: e.target.value }))
                  }
                  placeholder="เช่น นายสมชาย ใจดี"
                  className="input"
                />
              </div>

              <div className="sm:col-span-6">
                <label className="mb-1 block text-xs font-medium text-ink">
                  ตำแหน่งผู้ลงนาม
                </label>
                <input
                  type="text"
                  disabled={!canEdit}
                  value={draft.signer_title}
                  onChange={(e) =>
                    setDraft((prev) => ({
                      ...prev,
                      signer_title: e.target.value,
                    }))
                  }
                  placeholder={`เช่น ผู้อำนวยการ${schoolName}`}
                  className="input"
                />
              </div>
            </div>
          </section>
        </div>

        {/* ==================== ฝั่งขวา: ตัวอย่างกระดาษ Word (Live Preview) ==================== */}
        <div
          className={`lg:sticky lg:top-20 lg:col-span-6 ${
            mobilePane === 'editor' ? 'hidden lg:block' : 'block'
          }`}
        >
          <OrderWordPreviewPane
            schoolName={schoolName}
            draft={draft}
            digitSettings={digitSettings}
            onChangeDigitSettings={setDigitSettings}
            exportingDocx={exportingDocx}
            onExportDocx={async () => {
              setExportingDocx(true);
              try {
                await exportAppointmentOrderToDocx(
                  schoolName,
                  draft,
                  digitSettings,
                );
              } finally {
                setExportingDocx(false);
              }
            }}
          />
        </div>
      </div>
    </div>
  );
}

/**
 * ส่วนจัดการ "รายชื่อในข้อที่ ..."
 * - ด้านบน: ตัวกรอง Real-time (ชื่อ-นามสกุล, ตำแหน่งบริหาร, กลุ่มสาระการเรียนรู้, วิทยฐานะ)
 * - ตารางแสดงบุคลากรที่กรองได้: [ ติ๊กเลือก | ชื่อ-นามสกุล | ตำแหน่ง | Dropdown เลือกตำแหน่งในคณะ ]
 * - ปุ่มกดบันทึกคนที่ติ๊กเลือกเข้าสู่รายชื่อของข้อนี้
 * - ด้านล่าง: รายชื่อที่บันทึกอยู่ในข้อนี้แล้ว (แสดงลำดับ 1.1, 1.2...)
 */
function GroupMemberSelectorSection({
  groupNo,
  groupTitle,
  savedMembers,
  staffList,
  adminRoleOptions,
  departmentOptions,
  academicOptions,
  canEdit,
  onSavePicked,
  onUpdateSavedRole,
  onRemoveSavedMember,
}: {
  groupNo: number;
  groupTitle: string;
  savedMembers: OrderMemberDraft[];
  staffList: StaffOption[];
  adminRoleOptions: string[];
  departmentOptions: string[];
  academicOptions: string[];
  canEdit: boolean;
  onSavePicked: (
    picked: { teacher: StaffOption; workingRole: string }[],
  ) => void;
  onUpdateSavedRole: (memberIdx: number, workingRole: string) => void;
  onRemoveSavedMember: (memberIdx: number) => void;
}) {
  // Real-time Filter States
  const [nameFilter, setNameFilter] = useState('');
  const [adminRoleFilter, setAdminRoleFilter] = useState('');
  const [deptFilter, setDeptFilter] = useState('');
  const [academicFilter, setAcademicFilter] = useState('');

  // Checkbox selection + Working role per teacher id_user
  const [checkedIds, setCheckedIds] = useState<Record<number, boolean>>({});
  const [selectedRoles, setSelectedRoles] = useState<Record<number, string>>({});
  const [pickerWarning, setPickerWarning] = useState<string | null>(null);
  const [showFilterBox, setShowFilterBox] = useState(true);

  const filteredStaff = useMemo(() => {
    const q = nameFilter.trim().toLowerCase();
    return staffList.filter((s) => {
      if (q && !s.fullName.toLowerCase().includes(q)) return false;
      if (adminRoleFilter && s.adminRoleName !== adminRoleFilter) return false;
      if (deptFilter && s.departmentName !== deptFilter) return false;
      if (academicFilter && s.academicStanding !== academicFilter) return false;
      return true;
    });
  }, [staffList, nameFilter, adminRoleFilter, deptFilter, academicFilter]);

  const checkedCount = useMemo(
    () => Object.values(checkedIds).filter(Boolean).length,
    [checkedIds],
  );

  const allFilteredChecked = useMemo(
    () =>
      filteredStaff.length > 0 &&
      filteredStaff.every((s) => !!checkedIds[s.id_user]),
    [filteredStaff, checkedIds],
  );

  function toggleCheckAllFiltered() {
    setPickerWarning(null);
    if (filteredStaff.length === 0) return;
    setCheckedIds((prev) => {
      const next = { ...prev };
      const shouldCheck = !allFilteredChecked;
      for (const s of filteredStaff) {
        next[s.id_user] = shouldCheck;
      }
      return next;
    });
  }

  function applyRoleToAllChecked(role: string) {
    if (!role) return;
    setPickerWarning(null);
    setSelectedRoles((prev) => {
      const next = { ...prev };
      for (const [idStr, isChecked] of Object.entries(checkedIds)) {
        if (isChecked) {
          next[Number(idStr)] = role;
        }
      }
      return next;
    });
  }

  function toggleCheck(idUser: number) {
    setPickerWarning(null);
    setCheckedIds((prev) => ({
      ...prev,
      [idUser]: !prev[idUser],
    }));
  }

  function handleRoleChange(idUser: number, role: string) {
    setPickerWarning(null);
    setSelectedRoles((prev) => ({
      ...prev,
      [idUser]: role,
    }));
    // เมื่อผู้ใช้เลือกตำแหน่งในคณะ ให้ติ๊กเลือกแถวนั้นให้อัตโนมัติด้วยเพื่อความสะดวก
    if (role) {
      setCheckedIds((prev) => ({ ...prev, [idUser]: true }));
    }
  }

  function handleConfirmSaveSelection() {
    setPickerWarning(null);
    const chosenIds = Object.entries(checkedIds)
      .filter(([, isChecked]) => isChecked)
      .map(([id]) => Number(id));

    if (chosenIds.length === 0) {
      setPickerWarning('กรุณาติ๊กเลือกบุคลากรอย่างน้อย 1 คนก่อนกดบันทึก');
      return;
    }

    // ตรวจสอบว่าทุกคนที่ติ๊กเลือก ได้เลือก "ตำแหน่งในคณะ" ครบแล้ว
    const missingRoleNames: string[] = [];
    const payload: { teacher: StaffOption; workingRole: string }[] = [];

    for (const idUser of chosenIds) {
      const teacher = staffList.find((s) => s.id_user === idUser);
      if (!teacher) continue;
      const role = (selectedRoles[idUser] || '').trim();
      if (!role) {
        missingRoleNames.push(teacher.fullName);
      } else {
        payload.push({ teacher, workingRole: role });
      }
    }

    if (missingRoleNames.length > 0) {
      setPickerWarning(
        `กรุณาเลือก "ตำแหน่งในคณะ" ให้ครบสำหรับ: ${missingRoleNames.join(', ')}`,
      );
      return;
    }

    onSavePicked(payload);
    setCheckedIds({});
    setSelectedRoles({});
  }

  function clearFilters() {
    setNameFilter('');
    setAdminRoleFilter('');
    setDeptFilter('');
    setAcademicFilter('');
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <p className="text-xs font-semibold text-ink">
          รายชื่อในข้อที่ {groupNo} ({savedMembers.length} คน)
        </p>
        {canEdit && (
          <button
            type="button"
            onClick={() => setShowFilterBox((p) => !p)}
            className="inline-flex items-center gap-1 text-xs font-medium text-brand-600 hover:text-brand-700"
          >
            <Filter className="h-3.5 w-3.5" strokeWidth={1.5} />
            <span>
              {showFilterBox
                ? 'ซ่อนตัวกรองเลือกบุคลากร'
                : '+ เปิดตัวกรองเลือกบุคลากรเข้าข้อนี้'}
            </span>
          </button>
        )}
      </div>

      {/* ==================== กล่องตัวกรองบุคลากรทั้งโรงเรียน (Real-time Filter + ตารางติ๊กเลือก) ==================== */}
      {canEdit && showFilterBox && (
        <div className="rounded-xl border border-line bg-canvas/70 p-3.5 space-y-3">
          <div className="flex items-center justify-between">
            <p className="text-xs font-medium text-slate-700">
              ตัวกรองบุคลากรทั้งโรงเรียน (กรองข้อมูลแบบ Real-time)
            </p>
            {(nameFilter ||
              adminRoleFilter ||
              deptFilter ||
              academicFilter) && (
              <button
                type="button"
                onClick={clearFilters}
                className="text-[11px] font-medium text-brand-600 hover:underline"
              >
                ล้างตัวกรองทั้งหมด
              </button>
            )}
          </div>

          {/* 4 ช่องตัวกรอง Real-time */}
          <div className="grid gap-2 sm:grid-cols-2">
            {/* 1. ช่องกรอกชื่อ หรือ นามสกุล */}
            <div>
              <label className="mb-1 block text-[11px] font-medium text-slate-600">
                ค้นหาชื่อ หรือ นามสกุล
              </label>
              <div className="relative">
                <Search
                  className="pointer-events-none absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-slate-400"
                  strokeWidth={1.5}
                />
                <input
                  type="text"
                  value={nameFilter}
                  onChange={(e) => setNameFilter(e.target.value)}
                  placeholder="พิมพ์ชื่อ หรือ นามสกุล..."
                  className="input pl-8 py-1.5 text-xs bg-white"
                />
              </div>
            </div>

            {/* 2. Dropdown ตำแหน่งบริหาร */}
            <div>
              <label className="mb-1 block text-[11px] font-medium text-slate-600">
                ตำแหน่งบริหาร
              </label>
              <select
                value={adminRoleFilter}
                onChange={(e) => setAdminRoleFilter(e.target.value)}
                className="input py-1.5 text-xs bg-white"
              >
                <option value="">ทั้งหมด (ทุกตำแหน่งบริหาร)</option>
                {adminRoleOptions.map((opt) => (
                  <option key={opt} value={opt}>
                    {opt}
                  </option>
                ))}
              </select>
            </div>

            {/* 3. Dropdown กลุ่มสาระการเรียนรู้ */}
            <div>
              <label className="mb-1 block text-[11px] font-medium text-slate-600">
                กลุ่มสาระการเรียนรู้ / ฝ่าย
              </label>
              <select
                value={deptFilter}
                onChange={(e) => setDeptFilter(e.target.value)}
                className="input py-1.5 text-xs bg-white"
              >
                <option value="">ทั้งหมด (ทุกกลุ่มสาระการเรียนรู้)</option>
                {departmentOptions.map((opt) => (
                  <option key={opt} value={opt}>
                    {opt}
                  </option>
                ))}
              </select>
            </div>

            {/* 4. Dropdown วิทยฐานะ */}
            <div>
              <label className="mb-1 block text-[11px] font-medium text-slate-600">
                วิทยฐานะ
              </label>
              <select
                value={academicFilter}
                onChange={(e) => setAcademicFilter(e.target.value)}
                className="input py-1.5 text-xs bg-white"
              >
                <option value="">ทั้งหมด (ทุกวิทยฐานะ)</option>
                {academicOptions.map((opt) => (
                  <option key={opt} value={opt}>
                    {opt}
                  </option>
                ))}
              </select>
            </div>
          </div>

          {/* ตารางแสดงผลบุคลากรที่กรองได้ */}
          <div className="overflow-hidden rounded-lg border border-line bg-white">
            <div className="max-h-60 overflow-y-auto">
              <table className="w-full border-collapse text-left text-xs">
                <thead className="sticky top-0 z-10 border-b border-line bg-slate-50 text-[11px] font-medium text-slate-600">
                  <tr>
                    <th className="w-20 px-2.5 py-2 text-center">
                      <label
                        className="inline-flex cursor-pointer items-center justify-center gap-1.5 select-none"
                        title="ติ๊กเลือกทั้งหมดที่แสดงจากการกรอง"
                      >
                        <input
                          type="checkbox"
                          disabled={filteredStaff.length === 0}
                          checked={allFilteredChecked}
                          onChange={toggleCheckAllFiltered}
                          aria-label="เลือกทั้งหมดที่แสดงจากการกรอง"
                          className="checkbox"
                        />
                        <span>ทั้งหมด</span>
                      </label>
                    </th>
                    <th className="px-2.5 py-2">ชื่อ-นามสกุล</th>
                    <th className="hidden px-2.5 py-2 sm:table-cell">ตำแหน่ง</th>
                    <th className="w-36 px-2.5 py-1.5 sm:w-52">
                      <div className="flex flex-col gap-1">
                        <span>ตำแหน่งในคณะ (เลือกเอง)</span>
                        {checkedCount > 1 && (
                          <select
                            value=""
                            onChange={(e) => {
                              applyRoleToAllChecked(e.target.value);
                              e.currentTarget.value = '';
                            }}
                            aria-label="กำหนดตำแหน่งในคณะให้คนที่ติ๊กทั้งหมด"
                            className="rounded border border-brand-200 bg-brand-50/70 px-1.5 py-0.5 text-[10px] font-normal text-brand-700 outline-none"
                          >
                            <option value="">
                              ตั้งค่าคนที่ติ๊กทั้งหมด ({checkedCount} คน)...
                            </option>
                            {WORKING_ROLE_OPTIONS.map((roleOpt) => (
                              <option key={roleOpt} value={roleOpt}>
                                ตั้งเป็น &quot;{roleOpt}&quot; ทั้งหมด
                              </option>
                            ))}
                          </select>
                        )}
                      </div>
                    </th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-line">
                  {filteredStaff.length === 0 ? (
                    <tr>
                      <td
                        colSpan={4}
                        className="px-3 py-6 text-center text-xs text-slate-500"
                      >
                        ไม่พบบุคลากรตามเงื่อนไขที่กรอง
                      </td>
                    </tr>
                  ) : (
                    filteredStaff.map((staff) => {
                      const isChecked = !!checkedIds[staff.id_user];
                      const chosenRole = selectedRoles[staff.id_user] || '';
                      const alreadyInGroup = savedMembers.some(
                        (m) => m.id_user === staff.id_user,
                      );

                      return (
                        <tr
                          key={staff.id_user}
                          className={`transition-colors ${
                            isChecked
                              ? 'bg-brand-50/60'
                              : 'hover:bg-slate-50/80'
                          }`}
                        >
                          <td className="px-2.5 py-2 text-center">
                            <input
                              type="checkbox"
                              checked={isChecked}
                              onChange={() => toggleCheck(staff.id_user)}
                              aria-label={`เลือก ${staff.fullName}`}
                              className="checkbox"
                            />
                          </td>
                          <td
                            onClick={() => toggleCheck(staff.id_user)}
                            className="cursor-pointer px-2.5 py-2 font-medium text-ink"
                          >
                            <div>{staff.fullName}</div>
                            <div className="mt-0.5 text-[11px] font-normal text-slate-500 sm:hidden">
                              {staff.displayPosition}
                            </div>
                            {(staff.departmentName || alreadyInGroup) && (
                              <div className="mt-0.5 flex flex-wrap items-center gap-1 text-[10px] text-slate-500">
                                {staff.departmentName && (
                                  <span>{staff.departmentName}</span>
                                )}
                                {alreadyInGroup && (
                                  <span className="rounded bg-emerald-50 px-1.5 py-0.2 text-emerald-700">
                                    อยู่ในข้อนี้แล้ว
                                  </span>
                                )}
                              </div>
                            )}
                          </td>
                          <td className="hidden px-2.5 py-2 text-slate-600 sm:table-cell">
                            {staff.displayPosition}
                          </td>
                          <td className="px-2.5 py-2">
                            <select
                              value={chosenRole}
                              onChange={(e) =>
                                handleRoleChange(staff.id_user, e.target.value)
                              }
                              aria-label={`ตำแหน่งในคณะของ ${staff.fullName}`}
                              className={`w-full rounded-md border px-2 py-1 text-xs outline-none ${
                                isChecked && !chosenRole
                                  ? 'border-amber-400 bg-amber-50/50 text-ink'
                                  : 'border-line bg-white text-ink focus:border-brand-500'
                              }`}
                            >
                              <option value="">-- เลือกตำแหน่งในคณะ --</option>
                              {WORKING_ROLE_OPTIONS.map((roleOpt) => (
                                <option key={roleOpt} value={roleOpt}>
                                  {roleOpt}
                                </option>
                              ))}
                            </select>
                          </td>
                        </tr>
                      );
                    })
                  )}
                </tbody>
              </table>
            </div>
          </div>

          {pickerWarning && (
            <div className="rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-xs font-medium text-amber-800">
              {pickerWarning}
            </div>
          )}

          {/* ปุ่มกดบันทึกรายชื่อที่ติ๊กเลือกเข้าข้อนี้ */}
          <div className="flex flex-col gap-2 pt-1 sm:flex-row sm:items-center sm:justify-between">
            <span className="tabular-nums text-xs text-slate-500">
              กรองพบ {filteredStaff.length} คน · ติ๊กเลือกไว้ {checkedCount} คน
            </span>
            <button
              type="button"
              onClick={handleConfirmSaveSelection}
              className="btn-primary btn-sm justify-center"
            >
              <UserCheck className="h-3.5 w-3.5" strokeWidth={1.5} />
              <span>
                บันทึกรายชื่อที่เลือกเข้าข้อที่ {groupNo} ({checkedCount})
              </span>
            </button>
          </div>
        </div>
      )}

      {/* ==================== ตารางรายชื่อที่บันทึกอยู่ในข้อนี้แล้ว (1.1, 1.2...) ==================== */}
      <div className="overflow-hidden rounded-xl border border-line bg-white">
        <div className="border-b border-line bg-canvas px-3.5 py-2 text-xs font-medium text-slate-600">
          รายชื่อที่บันทึกในข้อ {groupNo}. {groupTitle}
        </div>
        {savedMembers.length === 0 ? (
          <div className="px-4 py-5 text-center text-xs text-slate-500">
            ยังไม่มีรายชื่อในข้อที่ {groupNo} กรุณาติ๊กเลือกบุคลากรจากตารางด้านบนแล้วกดบันทึก
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full border-collapse text-left text-xs">
              <thead className="border-b border-line bg-slate-50/70 text-[11px] font-medium text-slate-500">
                <tr>
                  <th className="w-12 px-2.5 py-2 sm:px-3">ข้อ</th>
                  <th className="px-2.5 py-2 sm:px-3">ชื่อ-นามสกุล</th>
                  <th className="hidden px-3 py-2 sm:table-cell">ตำแหน่ง</th>
                  <th className="w-36 px-2.5 py-2 sm:w-44 sm:px-3">ตำแหน่งในคณะ</th>
                  {canEdit && <th className="w-10 px-2 py-2 text-center">ลบ</th>}
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {savedMembers.map((member, mIdx) => (
                  <tr key={mIdx} className="hover:bg-slate-50/60">
                    <td className="px-2.5 py-2 font-semibold tabular-nums text-brand-700 sm:px-3">
                      {groupNo}.{mIdx + 1}
                    </td>
                    <td className="px-2.5 py-2 font-medium text-ink sm:px-3">
                      <div>{member.full_name}</div>
                      {member.official_position && (
                        <div className="mt-0.5 text-[11px] font-normal text-slate-500 sm:hidden">
                          {member.official_position}
                        </div>
                      )}
                    </td>
                    <td className="hidden px-3 py-2 text-slate-600 sm:table-cell">
                      {member.official_position}
                    </td>
                    <td className="px-2.5 py-2 sm:px-3">
                      <select
                        disabled={!canEdit}
                        value={member.working_role}
                        onChange={(e) => onUpdateSavedRole(mIdx, e.target.value)}
                        className="w-full rounded-md border border-line bg-white px-2 py-1 text-xs text-ink outline-none focus:border-brand-500"
                      >
                        {WORKING_ROLE_OPTIONS.map((roleOpt) => (
                          <option key={roleOpt} value={roleOpt}>
                            {roleOpt}
                          </option>
                        ))}
                      </select>
                    </td>
                    {canEdit && (
                      <td className="px-2 py-2 text-center">
                        <button
                          type="button"
                          onClick={() => onRemoveSavedMember(mIdx)}
                          className="rounded p-1 text-slate-400 hover:bg-rose-50 hover:text-rose-600"
                          title="ลบออกจากข้อนี้"
                        >
                          <Trash2 className="h-3.5 w-3.5" strokeWidth={1.5} />
                        </button>
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
