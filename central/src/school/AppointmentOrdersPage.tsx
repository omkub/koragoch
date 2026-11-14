import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ArrowDown,
  ArrowUp,
  Check,
  Plus,
  Save,
  Search,
  Trash2,
  UserPlus,
} from 'lucide-react';
import { supabase } from '../supabase';
import {
  composeOfficialPosition,
  createDefaultOrderDraft,
  DEFAULT_ACADEMIC_STANDINGS,
  DEFAULT_ADMIN_POSITIONS,
  splitOfficialPosition,
  type AppointmentOrderFull,
  type AppointmentOrderRecord,
  type OrderGroupDraft,
  type OrderMemberDraft,
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

interface StaffOption {
  id_user: number;
  fullName: string;
  adminPosition: string;
  academicStanding: string;
  officialPosition: string;
}

const WORKING_ROLE_OPTIONS = [
  'ประธานคณะทำงาน',
  'รองประธานคณะทำงาน',
  'หัวหน้าคณะทำงาน',
  'คณะทำงาน',
  'คณะทำงานและเลขานุการ',
  'คณะทำงานและผู้ช่วยเลขานุการ',
];

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
  const [adminPositions, setAdminPositions] = useState<string[]>(
    DEFAULT_ADMIN_POSITIONS,
  );
  const [academicStandings, setAcademicStandings] = useState<string[]>(
    DEFAULT_ACADEMIC_STANDINGS,
  );
  const [mobilePane, setMobilePane] = useState<'editor' | 'preview'>('editor');
  const [useThaiDigits, setUseThaiDigits] = useState(false);

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [exportingDocx, setExportingDocx] = useState(false);
  const [message, setMessage] = useState<{
    type: 'ok' | 'err';
    text: string;
  } | null>(null);

  // Draft state (Left Pane)
  const [draft, setDraft] = useState<Omit<AppointmentOrderFull, 'id'>>(() =>
    createDefaultOrderDraft(
      schoolId ?? 0,
      division.id,
      division.division_key,
      division.name,
      '1',
    ),
  );

  // Load staff list + adminroles + positions + academics + existing orders
  const loadInitialData = useCallback(async () => {
    if (!schoolId) return;
    setLoading(true);

    const [
      ordersRes,
      teachersRes,
      rolesRes,
      adminRolesRes,
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
      supabase.from('positions').select('ID_Positions, positionName'),
      supabase.from('academics').select('ID_Academics, AcademicsName'),
    ]);

    const roleMap = new Map<number, string>();
    for (const r of (rolesRes.data as { ID_Roles: number; Accessrights: string }[] | null) ?? []) {
      if (r.Accessrights?.trim()) roleMap.set(r.ID_Roles, r.Accessrights.trim());
    }

    const adminRoleMap = new Map<number, string>();
    const adminPosSet = new Set<string>();
    for (const ar of (adminRolesRes.data as { ID_AdminRoles: number; AdminRolesName: string | null }[] | null) ?? []) {
      const name = (ar.AdminRolesName || '').trim();
      if (name && name !== 'ไม่มีตำแหน่งบริหาร' && name !== '-') {
        adminRoleMap.set(ar.ID_AdminRoles, name);
        adminPosSet.add(name);
      }
    }

    const posMap = new Map<number, string>();
    for (const p of (positionsRes.data as { ID_Positions: number; positionName: string | null }[] | null) ?? []) {
      const name = (p.positionName || '').trim();
      if (name && name !== '-') {
        posMap.set(p.ID_Positions, name);
        adminPosSet.add(name);
      }
    }
    for (const defPos of DEFAULT_ADMIN_POSITIONS) {
      adminPosSet.add(defPos);
    }
    setAdminPositions([...adminPosSet]);

    const acadMap = new Map<number, string>();
    const acadSet = new Set<string>(['ไม่มีวิทยฐานะ']);
    for (const ac of (academicsRes.data as { ID_Academics: number; AcademicsName: string | null }[] | null) ?? []) {
      const name = (ac.AcademicsName || '').trim();
      if (name && name !== '-') {
        acadMap.set(ac.ID_Academics, name);
        acadSet.add(name);
      }
    }
    for (const defAcad of DEFAULT_ACADEMIC_STANDINGS) {
      acadSet.add(defAcad);
    }
    setAcademicStandings([...acadSet]);

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

        // 1) ตำแหน่งบริหาร / ตำแหน่งสายงาน
        const idAdminRole = Number(t.id_adminrole);
        const idPosition = Number(t.id_position);
        const idRole = Number(t.id_role);

        const resolvedAdminPos =
          (idAdminRole ? adminRoleMap.get(idAdminRole) : '') ||
          String(t['ตำแหน่งงานบริหาร'] || '').trim() ||
          (idPosition ? posMap.get(idPosition) : '') ||
          String(t.position || '').trim() ||
          (idRole ? roleMap.get(idRole) : '') ||
          'ครู';

        // 2) วิทยฐานะ
        const idAcademic = Number(
          t.ID_Academics ?? t.id_academic ?? t.id_academics ?? 0,
        );
        const resolvedAcadRaw =
          (idAcademic ? acadMap.get(idAcademic) : '') ||
          String(t.academicStanding ?? t['วิทยฐานะ'] ?? '').trim();
        const resolvedAcademic =
          resolvedAcadRaw &&
          resolvedAcadRaw !== 'ไม่มีวิทยฐานะ' &&
          resolvedAcadRaw !== '-'
            ? resolvedAcadRaw
            : '';

        return {
          id_user: idUser,
          fullName,
          adminPosition: resolvedAdminPos,
          academicStanding: resolvedAcademic,
          officialPosition: composeOfficialPosition(
            resolvedAdminPos,
            resolvedAcademic,
          ),
        };
      });

    setStaffList(activeTeachers);

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

  // Calculate next order number automatically
  const nextOrderNo = useMemo(() => {
    const nums = orders
      .map((o) => Number.parseInt(o.order_no, 10))
      .filter((n) => !Number.isNaN(n) && n > 0);
    return nums.length > 0 ? String(Math.max(...nums) + 1) : '1';
  }, [orders]);

  // Load details of a specific order when selected
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
          .map((m, mIdx) => {
            const split = splitOfficialPosition(
              m.official_position,
              academicStandings,
            );
            return {
              id: m.id,
              member_no: mIdx + 1,
              id_user: m.id_user,
              full_name: m.full_name,
              admin_position: split.admin_position,
              academic_standing: split.academic_standing,
              official_position: m.official_position,
              working_role: m.working_role,
            };
          });
        const gDuties = Array.isArray(g.duties)
          ? g.duties.map((d) => String(d))
          : [''];
        return {
          id: g.id,
          group_no: idx + 1,
          group_title: g.group_title,
          duties: gDuties.length > 0 ? gDuties : [''],
          members:
            gMembers.length > 0
              ? gMembers
              : [
                  {
                    member_no: 1,
                    id_user: null,
                    full_name: '',
                    admin_position: 'ครู',
                    academic_standing: '',
                    official_position: 'ครู',
                    working_role: 'คณะทำงาน',
                  },
                ],
        };
      });

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
        groups:
          builtGroups.length > 0
            ? builtGroups
            : createDefaultOrderDraft(
                header.id_school,
                division.id,
                division.division_key,
                division.name,
              ).groups,
      });
    },
    [orders, academicStandings, division.id, division.division_key, division.name],
  );

  function handleStartNewOrder() {
    if (!schoolId) return;
    setSelectedOrderId('new');
    setMessage(null);
    setDraft(
      createDefaultOrderDraft(
        schoolId,
        division.id,
        division.division_key,
        division.name,
        nextOrderNo,
      ),
    );
  }

  useEffect(() => {
    if (!schoolId) return;
    setSelectedOrderId('new');
    setDraft(
      createDefaultOrderDraft(
        schoolId,
        division.id,
        division.division_key,
        division.name,
        nextOrderNo,
      ),
    );
  }, [schoolId, division.id, division.division_key, division.name, nextOrderNo]);

  // --- Group (ข้อ 1, 2, 3...) Handlers ---
  function addGroup() {
    setDraft((prev) => {
      const nextNo = prev.groups.length + 1;
      return {
        ...prev,
        groups: [
          ...prev.groups,
          {
            group_no: nextNo,
            group_title: `คณะทำงานชุดที่ ${nextNo}`,
            members: [
              {
                member_no: 1,
                id_user: null,
                full_name: '',
                admin_position: 'ครู',
                academic_standing: '',
                official_position: 'ครู',
                working_role: 'คณะทำงาน',
              },
            ],
            duties: ['ดำเนินการตามภารกิจที่ได้รับมอบหมายให้เป็นไปด้วยความเรียบร้อย'],
          },
        ],
      };
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

  // --- Member (ข้อ 1.1, 1.2...) Handlers ---
  function addMemberFromTeacher(groupIdx: number, teacher: StaffOption) {
    setDraft((prev) => {
      const copy = [...prev.groups];
      const g = copy[groupIdx];
      const hasOnlyBlankFirst =
        g.members.length === 1 && !g.members[0].full_name.trim();
      const nextMembers: OrderMemberDraft[] = hasOnlyBlankFirst
        ? [
            {
              member_no: 1,
              id_user: teacher.id_user,
              full_name: teacher.fullName,
              admin_position: teacher.adminPosition,
              academic_standing: teacher.academicStanding,
              official_position: teacher.officialPosition,
              working_role: g.members[0].working_role || 'ประธานคณะทำงาน',
            },
          ]
        : [
            ...g.members,
            {
              member_no: g.members.length + 1,
              id_user: teacher.id_user,
              full_name: teacher.fullName,
              admin_position: teacher.adminPosition,
              academic_standing: teacher.academicStanding,
              official_position: teacher.officialPosition,
              working_role: 'คณะทำงาน',
            },
          ];

      copy[groupIdx] = { ...g, members: nextMembers };
      return { ...prev, groups: copy };
    });
  }

  function selectTeacherForExistingRow(
    groupIdx: number,
    memberIdx: number,
    teacher: StaffOption,
  ) {
    setDraft((prev) => {
      const copy = [...prev.groups];
      const g = copy[groupIdx];
      const members = [...g.members];
      members[memberIdx] = {
        ...members[memberIdx],
        id_user: teacher.id_user,
        full_name: teacher.fullName,
        admin_position: teacher.adminPosition,
        academic_standing: teacher.academicStanding,
        official_position: teacher.officialPosition,
      };
      copy[groupIdx] = { ...g, members };
      return { ...prev, groups: copy };
    });
  }

  function addBlankMember(groupIdx: number) {
    setDraft((prev) => {
      const copy = [...prev.groups];
      const g = copy[groupIdx];
      copy[groupIdx] = {
        ...g,
        members: [
          ...g.members,
          {
            member_no: g.members.length + 1,
            id_user: null,
            full_name: '',
            admin_position: 'ครู',
            academic_standing: '',
            official_position: 'ครู',
            working_role: 'คณะทำงาน',
          },
        ],
      };
      return { ...prev, groups: copy };
    });
  }

  function updateMemberName(groupIdx: number, memberIdx: number, name: string) {
    setDraft((prev) => {
      const copy = [...prev.groups];
      const g = copy[groupIdx];
      const members = [...g.members];
      members[memberIdx] = {
        ...members[memberIdx],
        full_name: name,
      };
      copy[groupIdx] = { ...g, members };
      return { ...prev, groups: copy };
    });
  }

  function updateMemberPositionParts(
    groupIdx: number,
    memberIdx: number,
    nextAdminPos: string,
    nextAcademic: string,
  ) {
    setDraft((prev) => {
      const copy = [...prev.groups];
      const g = copy[groupIdx];
      const members = [...g.members];
      const combined = composeOfficialPosition(nextAdminPos, nextAcademic);
      members[memberIdx] = {
        ...members[memberIdx],
        admin_position: nextAdminPos,
        academic_standing: nextAcademic,
        official_position: combined,
      };
      copy[groupIdx] = { ...g, members };
      return { ...prev, groups: copy };
    });
  }

  function updateMemberWorkingRole(
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

  function removeMember(groupIdx: number, memberIdx: number) {
    setDraft((prev) => {
      const copy = [...prev.groups];
      const g = copy[groupIdx];
      if (g.members.length <= 1) {
        copy[groupIdx] = {
          ...g,
          members: [
            {
              member_no: 1,
              id_user: null,
              full_name: '',
              admin_position: 'ครู',
              academic_standing: '',
              official_position: 'ครู',
              working_role: 'คณะทำงาน',
            },
          ],
        };
        return { ...prev, groups: copy };
      }
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
          draft.effective_text.trim() || 'ทั้งนี้ ตั้งแต่บัดนี้เป็นต้นไป',
        order_date: draft.order_date,
        signer_name: draft.signer_name.trim(),
        signer_title: draft.signer_title.trim(),
        updated_at: new Date().toISOString(),
      };

      if (selectedOrderId === 'new') {
        const { data: insOrder, error: insErr } = await supabase
          .from('SchoolWebOrders')
          .insert(orderPayload)
          .select('id')
          .single();
        if (insErr || !insOrder) {
          throw new Error(insErr?.message || 'ไม่สามารถสร้างคำสั่งได้');
        }
        targetOrderId = insOrder.id;
      } else {
        targetOrderId = selectedOrderId;
        const { error: updErr } = await supabase
          .from('SchoolWebOrders')
          .update(orderPayload)
          .eq('id', targetOrderId);
        if (updErr) throw new Error(updErr.message);

        await supabase
          .from('SchoolWebOrderGroups')
          .delete()
          .eq('order_id', targetOrderId);
      }

      for (let gIdx = 0; gIdx < draft.groups.length; gIdx++) {
        const g = draft.groups[gIdx];
        const cleanDuties = g.duties.map((d) => d.trim()).filter(Boolean);

        const { data: insGroup, error: gErr } = await supabase
          .from('SchoolWebOrderGroups')
          .insert({
            id_school: schoolId,
            order_id: targetOrderId,
            group_no: gIdx + 1,
            group_title: g.group_title.trim() || `คณะทำงานชุดที่ ${gIdx + 1}`,
            duties: cleanDuties,
          })
          .select('id')
          .single();

        if (gErr || !insGroup) {
          throw new Error(gErr?.message || 'บันทึกชุดคณะทำงานไม่สำเร็จ');
        }

        const validMembers = g.members.filter((m) => m.full_name.trim());
        if (validMembers.length > 0) {
          const memberRows = validMembers.map((m, mIdx) => ({
            id_school: schoolId,
            order_id: targetOrderId,
            group_id: insGroup.id,
            member_no: mIdx + 1,
            id_user: m.id_user,
            full_name: m.full_name.trim(),
            official_position: m.official_position.trim(),
            working_role: m.working_role.trim() || 'คณะทำงาน',
          }));

          const { error: mErr } = await supabase
            .from('SchoolWebOrderMembers')
            .insert(memberRows);
          if (mErr) throw new Error(mErr.message);
        }
      }

      await loadInitialData();
      setSelectedOrderId(targetOrderId);
      setMessage({
        type: 'ok',
        text: `บันทึกคำสั่งที่ ${orderPayload.order_no}/${orderPayload.order_year} เรียบร้อยแล้ว`,
      });
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

  const signerSplit = useMemo(
    () => splitOfficialPosition(draft.signer_title, academicStandings),
    [draft.signer_title, academicStandings],
  );

  return (
    <div className="space-y-4">
      {/* Top Action Bar */}
      <div className="surface-card p-4">
        <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
          <div className="flex flex-wrap items-center gap-2">
            <div className="inline-flex rounded-lg border border-line bg-canvas p-0.5">
              <button
                type="button"
                onClick={() => setScopeFilter('division')}
                className={`rounded-md px-2.5 py-1 text-xs font-medium transition-colors ${
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
                className={`rounded-md px-2.5 py-1 text-xs font-medium transition-colors ${
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
              className="input max-w-xs py-1.5 text-xs"
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
              className="btn-secondary btn-sm"
            >
              <Plus className="h-3.5 w-3.5" strokeWidth={1.5} />
              <span>สร้างคำสั่งใหม่</span>
            </button>
          </div>

          <div className="flex flex-wrap items-center gap-2">
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
                ส่วนที่ 1 · หัวคำสั่งและข้อความเกริ่นนำ
              </h2>
              <p className="mt-0.5 text-xs text-slate-500">
                ระบุเลขที่คำสั่ง ชื่อเรื่อง และย่อหน้าข้อความต้นเรื่อง
              </p>
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
                  ส่วนที่ 2 · ชุดคณะทำงานและหน้าที่ ({draft.groups.length} คณะ)
                </h2>
                <p className="text-xs text-slate-500">
                  พิมพ์ค้นหาชื่อครู เลือกตำแหน่งบริหาร วิทยฐานะ และตำแหน่งทำงานได้รายคน
                </p>
              </div>
              {canEdit && (
                <button
                  type="button"
                  onClick={addGroup}
                  className="btn-primary btn-sm"
                >
                  <Plus className="h-3.5 w-3.5" strokeWidth={1.5} />
                  <span>เพิ่มชุดคณะทำงาน (ข้อ {draft.groups.length + 1})</span>
                </button>
              )}
            </div>

            {draft.groups.map((group, gIdx) => (
              <div key={gIdx} className="surface-card space-y-4 p-5">
                {/* หัวข้อชุดคณะทำงาน เช่น 1. คณะทำงานด้านอำนวยการ */}
                <div className="flex flex-col gap-2 border-b border-line pb-3 sm:flex-row sm:items-center sm:justify-between">
                  <div className="flex flex-1 items-center gap-2">
                    <span className="inline-flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-brand-50 font-semibold tabular-nums text-xs text-brand-700">
                      {gIdx + 1}.
                    </span>
                    <input
                      type="text"
                      disabled={!canEdit}
                      value={group.group_title}
                      onChange={(e) => updateGroupTitle(gIdx, e.target.value)}
                      placeholder="เช่น คณะทำงานด้านอำนวยการ"
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

                {/* แถบค้นหาชื่อบุคลากรเพื่อเพิ่มเข้าชุดคณะทำงาน */}
                <div className="space-y-3">
                  <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                    <p className="text-xs font-medium text-slate-600">
                      รายชื่อในข้อที่ {gIdx + 1} (ชื่อ-นามสกุล · ตำแหน่งบริหาร · วิทยฐานะ · ตำแหน่งทำงาน)
                    </p>

                    {canEdit && (
                      <div className="flex flex-wrap items-center gap-2">
                        <QuickTeacherSearchPicker
                          staffList={staffList}
                          placeholder="พิมพ์ชื่อค้นหาบุคลากรเพื่อเพิ่ม..."
                          onSelect={(teacher) =>
                            addMemberFromTeacher(gIdx, teacher)
                          }
                        />
                        <button
                          type="button"
                          onClick={() => addBlankMember(gIdx)}
                          className="inline-flex h-8 items-center gap-1 rounded-lg border border-line bg-white px-2.5 text-xs font-medium text-slate-700 hover:bg-slate-50"
                        >
                          <UserPlus className="h-3.5 w-3.5" strokeWidth={1.5} />
                          <span>เพิ่มแถวเปล่า</span>
                        </button>
                      </div>
                    )}
                  </div>

                  {/* รายการผู้ได้รับแต่งตั้ง (1.1, 1.2...) */}
                  <div className="space-y-2.5">
                    {group.members.map((member, mIdx) => {
                      const currentAdminPos =
                        member.admin_position ??
                        splitOfficialPosition(
                          member.official_position,
                          academicStandings,
                        ).admin_position;
                      const currentAcademic =
                        member.academic_standing ??
                        splitOfficialPosition(
                          member.official_position,
                          academicStandings,
                        ).academic_standing;

                      const posOptions =
                        currentAdminPos &&
                        !adminPositions.includes(currentAdminPos)
                          ? [currentAdminPos, ...adminPositions]
                          : adminPositions;

                      const acadOptions =
                        currentAcademic &&
                        !academicStandings.includes(currentAcademic)
                          ? [currentAcademic, ...academicStandings]
                          : academicStandings;

                      return (
                        <div
                          key={mIdx}
                          className="rounded-xl border border-line bg-canvas/60 p-3 space-y-2"
                        >
                          <div className="grid gap-2 sm:grid-cols-12 sm:items-center">
                            {/* 1) ชื่อ-นามสกุล (พิมพ์ค้นหาชื่อครูได้ทันที) */}
                            <div className="flex items-center gap-2 sm:col-span-6">
                              <span className="w-7 shrink-0 text-right font-semibold tabular-nums text-xs text-brand-700">
                                {gIdx + 1}.{mIdx + 1}
                              </span>
                              <div className="flex-1">
                                <SearchableMemberNameInput
                                  value={member.full_name}
                                  disabled={!canEdit}
                                  staffList={staffList}
                                  onChangeText={(txt) =>
                                    updateMemberName(gIdx, mIdx, txt)
                                  }
                                  onSelectTeacher={(teacher) =>
                                    selectTeacherForExistingRow(
                                      gIdx,
                                      memberIdxValue(mIdx),
                                      teacher,
                                    )
                                  }
                                />
                              </div>
                            </div>

                            {/* 2) ตำแหน่งทำงานในคณะกรรมการ */}
                            <div className="flex items-center gap-1.5 sm:col-span-6">
                              <select
                                disabled={!canEdit}
                                value={
                                  WORKING_ROLE_OPTIONS.includes(member.working_role)
                                    ? member.working_role
                                    : '__custom__'
                                }
                                onChange={(e) => {
                                  if (e.target.value !== '__custom__') {
                                    updateMemberWorkingRole(
                                      gIdx,
                                      mIdx,
                                      e.target.value,
                                    );
                                  }
                                }}
                                aria-label="เลือกตำแหน่งทำงาน"
                                className="input py-1.5 text-xs"
                              >
                                {WORKING_ROLE_OPTIONS.map((role) => (
                                  <option key={role} value={role}>
                                    {role}
                                  </option>
                                ))}
                                {!WORKING_ROLE_OPTIONS.includes(
                                  member.working_role,
                                ) && (
                                  <option value="__custom__">
                                    {member.working_role || 'กำหนดเอง'}
                                  </option>
                                )}
                              </select>

                              {canEdit && (
                                <button
                                  type="button"
                                  onClick={() => removeMember(gIdx, mIdx)}
                                  className="rounded p-1.5 text-slate-400 hover:bg-rose-50 hover:text-rose-600"
                                  title="ลบรายชื่อนี้"
                                >
                                  <Trash2
                                    className="h-3.5 w-3.5"
                                    strokeWidth={1.5}
                                  />
                                </button>
                              )}
                            </div>
                          </div>

                          {/* แถวที่ 2 ของคนนี้: Dropdown ตำแหน่งบริหาร + Dropdown วิทยฐานะ */}
                          <div className="grid gap-2 pl-9 sm:grid-cols-12">
                            <div className="sm:col-span-6">
                              <label className="mb-0.5 block text-[11px] font-medium text-slate-500">
                                ตำแหน่ง / ตำแหน่งบริหาร
                              </label>
                              <select
                                disabled={!canEdit}
                                value={currentAdminPos}
                                onChange={(e) =>
                                  updateMemberPositionParts(
                                    gIdx,
                                    mIdx,
                                    e.target.value,
                                    currentAcademic,
                                  )
                                }
                                className="input py-1 text-xs"
                              >
                                <option value="">-- เลือกตำแหน่งบริหาร/สายงาน --</option>
                                {posOptions.map((pos) => (
                                  <option key={pos} value={pos}>
                                    {pos}
                                  </option>
                                ))}
                              </select>
                            </div>

                            <div className="sm:col-span-6">
                              <label className="mb-0.5 block text-[11px] font-medium text-slate-500">
                                วิทยฐานะ
                              </label>
                              <select
                                disabled={!canEdit}
                                value={currentAcademic || 'ไม่มีวิทยฐานะ'}
                                onChange={(e) => {
                                  const val =
                                    e.target.value === 'ไม่มีวิทยฐานะ'
                                      ? ''
                                      : e.target.value;
                                  updateMemberPositionParts(
                                    gIdx,
                                    mIdx,
                                    currentAdminPos,
                                    val,
                                  );
                                }}
                                className="input py-1 text-xs"
                              >
                                {acadOptions.map((acad) => (
                                  <option key={acad} value={acad}>
                                    {acad}
                                  </option>
                                ))}
                              </select>
                            </div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>

                {/* หน้าที่ของคณะทำงานชุดนี้ */}
                <div className="space-y-2 border-t border-line pt-3">
                  <div className="flex items-center justify-between">
                    <p className="text-xs font-medium text-slate-600">
                      หน้าที่ (ของข้อ {gIdx + 1}. {group.group_title})
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
              </div>
            ))}
          </section>

          {/* 3) ส่วนท้ายคำสั่ง วันที่สั่ง และผู้ลงนาม */}
          <section className="surface-card space-y-4 p-5">
            <div className="border-b border-line pb-3">
              <h2 className="text-sm font-semibold text-ink">
                ส่วนที่ 3 · วันที่มีผลบังคับใช้ และผู้ลงนามคำสั่ง
              </h2>
              <p className="mt-0.5 text-xs text-slate-500">
                พิมพ์ชื่อค้นหาผู้ลงนาม พร้อมเลือกตำแหน่งบริหารและวิทยฐานะได้ทันที
              </p>
            </div>

            <div className="grid gap-3 sm:grid-cols-12">
              <div className="sm:col-span-7">
                <label className="mb-1 block text-xs font-medium text-ink">
                  ข้อความผลบังคับใช้
                </label>
                <input
                  type="text"
                  disabled={!canEdit}
                  value={draft.effective_text}
                  onChange={(e) =>
                    setDraft((prev) => ({
                      ...prev,
                      effective_text: e.target.value,
                    }))
                  }
                  placeholder="ทั้งนี้ ตั้งแต่บัดนี้เป็นต้นไป"
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

              <div className="sm:col-span-12">
                <label className="mb-1 block text-xs font-medium text-ink">
                  ชื่อผู้ลงนาม (พิมพ์ชื่อค้นหาจากทะเบียนบุคลากร หรือพิมพ์เอง)
                </label>
                <SearchableMemberNameInput
                  value={draft.signer_name}
                  disabled={!canEdit}
                  staffList={staffList}
                  placeholder="พิมพ์ชื่อเพื่อค้นหาผู้บริหาร/บุคลากร..."
                  onChangeText={(txt) =>
                    setDraft((prev) => ({ ...prev, signer_name: txt }))
                  }
                  onSelectTeacher={(teacher) =>
                    setDraft((prev) => ({
                      ...prev,
                      signer_name: teacher.fullName,
                      signer_title: teacher.officialPosition,
                    }))
                  }
                />
              </div>

              <div className="sm:col-span-6">
                <label className="mb-1 block text-xs font-medium text-ink">
                  ตำแหน่งบริหารผู้ลงนาม
                </label>
                <select
                  disabled={!canEdit}
                  value={signerSplit.admin_position}
                  onChange={(e) => {
                    const nextTitle = composeOfficialPosition(
                      e.target.value,
                      signerSplit.academic_standing,
                    );
                    setDraft((prev) => ({ ...prev, signer_title: nextTitle }));
                  }}
                  className="input py-1.5 text-xs"
                >
                  <option value="">-- เลือกตำแหน่งบริหาร --</option>
                  {(signerSplit.admin_position &&
                  !adminPositions.includes(signerSplit.admin_position)
                    ? [signerSplit.admin_position, ...adminPositions]
                    : adminPositions
                  ).map((pos) => (
                    <option key={pos} value={pos}>
                      {pos}
                    </option>
                  ))}
                </select>
              </div>

              <div className="sm:col-span-6">
                <label className="mb-1 block text-xs font-medium text-ink">
                  วิทยฐานะผู้ลงนาม
                </label>
                <select
                  disabled={!canEdit}
                  value={signerSplit.academic_standing || 'ไม่มีวิทยฐานะ'}
                  onChange={(e) => {
                    const acadVal =
                      e.target.value === 'ไม่มีวิทยฐานะ' ? '' : e.target.value;
                    const nextTitle = composeOfficialPosition(
                      signerSplit.admin_position,
                      acadVal,
                    );
                    setDraft((prev) => ({ ...prev, signer_title: nextTitle }));
                  }}
                  className="input py-1.5 text-xs"
                >
                  {academicStandings.map((acad) => (
                    <option key={acad} value={acad}>
                      {acad}
                    </option>
                  ))}
                </select>
              </div>

              <div className="sm:col-span-12">
                <label className="mb-1 block text-xs font-medium text-slate-500">
                  ตำแหน่งที่แสดงใต้ลายเซ็น (ปรับแต่งข้อความเพิ่มเติมได้)
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
                  className="input py-1.5 text-xs"
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
            useThaiDigits={useThaiDigits}
            onChangeThaiDigits={setUseThaiDigits}
            exportingDocx={exportingDocx}
            onExportDocx={async () => {
              setExportingDocx(true);
              try {
                await exportAppointmentOrderToDocx(
                  schoolName,
                  draft,
                  useThaiDigits,
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

function memberIdxValue(idx: number): number {
  return idx;
}

/**
 * ช่องพิมพ์ค้นหาบุคลากรแบบรวดเร็วเพื่อกดเพิ่มเข้าชุดคณะทำงาน
 */
function QuickTeacherSearchPicker({
  staffList,
  placeholder,
  onSelect,
}: {
  staffList: StaffOption[];
  placeholder: string;
  onSelect: (teacher: StaffOption) => void;
}) {
  const [query, setQuery] = useState('');
  const [open, setOpen] = useState(false);
  const wrapRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handleOutside(e: MouseEvent) {
      if (wrapRef.current && !wrapRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener('mousedown', handleOutside);
    return () => document.removeEventListener('mousedown', handleOutside);
  }, []);

  const matches = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return staffList.slice(0, 30);
    return staffList.filter(
      (s) =>
        s.fullName.toLowerCase().includes(q) ||
        s.adminPosition.toLowerCase().includes(q) ||
        s.academicStanding.toLowerCase().includes(q),
    );
  }, [staffList, query]);

  return (
    <div ref={wrapRef} className="relative w-64">
      <div className="relative">
        <Search
          className="pointer-events-none absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-brand-600"
          strokeWidth={1.5}
        />
        <input
          type="text"
          value={query}
          onFocus={() => setOpen(true)}
          onChange={(e) => {
            setQuery(e.target.value);
            setOpen(true);
          }}
          placeholder={placeholder}
          className="h-8 w-full rounded-lg border border-brand-200 bg-brand-50/50 pl-8 pr-3 text-xs text-ink placeholder:text-brand-700/70 outline-none focus:border-brand-500 focus:bg-white"
        />
      </div>

      {open && (
        <div className="absolute right-0 z-30 mt-1 max-h-60 w-80 overflow-y-auto rounded-xl border border-line bg-white p-1 shadow-lg">
          {matches.length === 0 ? (
            <p className="px-3 py-2 text-xs text-slate-500">
              ไม่พบบุคลากรที่ตรงกับ "{query}"
            </p>
          ) : (
            matches.map((t) => (
              <button
                key={t.id_user}
                type="button"
                onClick={() => {
                  onSelect(t);
                  setQuery('');
                  setOpen(false);
                }}
                className="flex w-full items-center justify-between gap-2 rounded-lg px-3 py-2 text-left text-xs hover:bg-brand-50"
              >
                <span className="font-medium text-ink">{t.fullName}</span>
                <span className="shrink-0 rounded bg-slate-100 px-1.5 py-0.5 text-[11px] text-slate-600">
                  {t.officialPosition}
                </span>
              </button>
            ))
          )}
        </div>
      )}
    </div>
  );
}

/**
 * ช่อง ชื่อ-นามสกุล ที่สามารถพิมพ์ค้นหาชื่อครูในโรงเรียนได้แบบ Autocomplete
 */
function SearchableMemberNameInput({
  value,
  disabled,
  staffList,
  placeholder = 'พิมพ์ชื่อค้นหา หรือระบุชื่อ-นามสกุล...',
  onChangeText,
  onSelectTeacher,
}: {
  value: string;
  disabled?: boolean;
  staffList: StaffOption[];
  placeholder?: string;
  onChangeText: (text: string) => void;
  onSelectTeacher: (teacher: StaffOption) => void;
}) {
  const [open, setOpen] = useState(false);
  const wrapRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handleOutside(e: MouseEvent) {
      if (wrapRef.current && !wrapRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener('mousedown', handleOutside);
    return () => document.removeEventListener('mousedown', handleOutside);
  }, []);

  const matches = useMemo(() => {
    const q = value.trim().toLowerCase();
    if (!q) return staffList.slice(0, 25);
    return staffList
      .filter(
        (s) =>
          s.fullName.toLowerCase().includes(q) ||
          s.adminPosition.toLowerCase().includes(q) ||
          s.academicStanding.toLowerCase().includes(q),
      )
      .slice(0, 25);
  }, [staffList, value]);

  return (
    <div ref={wrapRef} className="relative">
      <input
        type="text"
        disabled={disabled}
        value={value}
        onFocus={() => setOpen(true)}
        onChange={(e) => {
          onChangeText(e.target.value);
          setOpen(true);
        }}
        placeholder={placeholder}
        className="input py-1.5 text-xs"
      />

      {open && !disabled && matches.length > 0 && (
        <div className="absolute left-0 z-30 mt-1 max-h-56 w-full min-w-[260px] overflow-y-auto rounded-xl border border-line bg-white p-1 shadow-lg">
          {matches.map((t) => (
            <button
              key={t.id_user}
              type="button"
              onClick={() => {
                onSelectTeacher(t);
                setOpen(false);
              }}
              className="flex w-full items-center justify-between gap-2 rounded-lg px-2.5 py-1.5 text-left text-xs hover:bg-brand-50"
            >
              <span className="font-medium text-ink">{t.fullName}</span>
              <span className="shrink-0 text-[11px] text-slate-500">
                {t.officialPosition}
              </span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
