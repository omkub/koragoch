import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  ArrowDown,
  ArrowUp,
  Check,
  Plus,
  Save,
  Trash2,
  UserPlus,
} from 'lucide-react';
import { supabase } from '../supabase';
import {
  createDefaultOrderDraft,
  type AppointmentOrderFull,
  type AppointmentOrderRecord,
  type OrderGroupDraft,
  type OrderMemberDraft,
} from './appointmentOrders';
import type { DivisionWithModules } from './mapping';
import { exportAppointmentOrderToDocx } from './exportOrderDocx';
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
  officialPosition: string;
}

const WORKING_ROLE_SUGGESTIONS = [
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

  // Load staff list + existing orders
  const loadInitialData = useCallback(async () => {
    if (!schoolId) return;
    setLoading(true);

    const [ordersRes, teachersRes, rolesRes] = await Promise.all([
      supabase
        .from('SchoolWebOrders')
        .select('*')
        .eq('id_school', schoolId)
        .order('order_year', { ascending: false })
        .order('id', { ascending: false }),
      supabase
        .from('Teachers')
        .select('id_user, fullName, id_role, employment_status')
        .eq('id_school', schoolId)
        .order('fullName', { ascending: true }),
      supabase.from('roles').select('ID_Roles, Accessrights'),
    ]);

    const roleMap = new Map<number, string>();
    for (const r of (rolesRes.data as { ID_Roles: number; Accessrights: string }[] | null) ?? []) {
      roleMap.set(r.ID_Roles, r.Accessrights);
    }

    const activeTeachers: StaffOption[] = (
      (teachersRes.data as
        | {
            id_user: number;
            fullName: string | null;
            id_role: number | null;
            employment_status?: string | null;
          }[]
        | null) ?? []
    )
      .filter((t) => !t.employment_status || t.employment_status === 'active')
      .map((t) => ({
        id_user: t.id_user,
        fullName: (t.fullName || '').trim() || `บุคลากร #${t.id_user}`,
        officialPosition: (t.id_role ? roleMap.get(t.id_role) : null) || 'ครู',
      }));

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
          members:
            gMembers.length > 0
              ? gMembers
              : [
                  {
                    member_no: 1,
                    id_user: null,
                    full_name: '',
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
    [orders, division.id, division.division_key, division.name],
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

  // Reset default draft when switching division tab
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
  function addMemberFromTeacher(groupIdx: number, teacherIdStr: string) {
    const teacherId = Number(teacherIdStr);
    const teacher = staffList.find((t) => t.id_user === teacherId);
    if (!teacher) return;

    setDraft((prev) => {
      const copy = [...prev.groups];
      const g = copy[groupIdx];
      // If first member is empty placeholder, replace it; otherwise append
      const hasOnlyBlankFirst =
        g.members.length === 1 && !g.members[0].full_name.trim();
      const nextMembers: OrderMemberDraft[] = hasOnlyBlankFirst
        ? [
            {
              member_no: 1,
              id_user: teacher.id_user,
              full_name: teacher.fullName,
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
              official_position: teacher.officialPosition,
              working_role: 'คณะทำงาน',
            },
          ];

      copy[groupIdx] = { ...g, members: nextMembers };
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
            official_position: 'ครู',
            working_role: 'คณะทำงาน',
          },
        ],
      };
      return { ...prev, groups: copy };
    });
  }

  function updateMemberField(
    groupIdx: number,
    memberIdx: number,
    field: keyof OrderMemberDraft,
    value: string,
  ) {
    setDraft((prev) => {
      const copy = [...prev.groups];
      const g = copy[groupIdx];
      const members = [...g.members];
      members[memberIdx] = { ...members[memberIdx], [field]: value };
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
              official_position: '',
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

        // ล้างคณะทำงานเดิมเพื่อบันทึกชุดปัจจุบันเข้าไปใหม่
        await supabase
          .from('SchoolWebOrderGroups')
          .delete()
          .eq('order_id', targetOrderId);
      }

      // บันทึกแต่ละชุดคณะทำงาน (ข้อ 1, 2, 3...) และรายชื่อย่อย (1.1, 1.2...)
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

  return (
    <div className="space-y-4">
      <datalist id="working-role-suggestions">
        {WORKING_ROLE_SUGGESTIONS.map((role) => (
          <option key={role} value={role} />
        ))}
      </datalist>

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
            {/* Mobile/Tablet Portrait Mode Switcher (iOS / Small Screens) */}
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
                  เพิ่มชุดคณะทำงาน ข้อ 1, 2, 3... พร้อมรายชื่อครูและหน้าที่ของแต่ละชุด
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

                {/* รายชื่อผู้ได้รับแต่งตั้ง (1.1, 1.2...) */}
                <div className="space-y-2.5">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <p className="text-xs font-medium text-slate-600">
                      รายชื่อในข้อที่ {gIdx + 1} (ชื่อ-นามสกุล · ตำแหน่ง · ตำแหน่งทำงาน)
                    </p>

                    {canEdit && (
                      <div className="flex flex-wrap items-center gap-1.5">
                        <select
                          value=""
                          onChange={(e) => {
                            if (e.target.value) {
                              addMemberFromTeacher(gIdx, e.target.value);
                            }
                          }}
                          aria-label="เลือกครูเข้าคณะทำงาน"
                          className="rounded-lg border border-brand-200 bg-brand-50/60 px-2.5 py-1 text-xs font-medium text-brand-700 outline-none focus:border-brand-500"
                        >
                          <option value="">
                            + เลือกจากรายชื่อบุคลากรในโรงเรียน...
                          </option>
                          {staffList.map((t) => (
                            <option key={t.id_user} value={t.id_user}>
                              {t.fullName} ({t.officialPosition})
                            </option>
                          ))}
                        </select>

                        <button
                          type="button"
                          onClick={() => addBlankMember(gIdx)}
                          className="inline-flex items-center gap-1 rounded-lg border border-line bg-white px-2.5 py-1 text-xs font-medium text-slate-700 hover:bg-slate-50"
                        >
                          <UserPlus className="h-3 w-3" strokeWidth={1.5} />
                          <span>เพิ่มแถวเปล่า</span>
                        </button>
                      </div>
                    )}
                  </div>

                  <div className="space-y-2">
                    {group.members.map((member, mIdx) => (
                      <div
                        key={mIdx}
                        className="grid gap-2 rounded-xl border border-line bg-canvas/60 p-2.5 sm:grid-cols-12 sm:items-center"
                      >
                        <div className="flex items-center gap-2 sm:col-span-5">
                          <span className="w-8 shrink-0 text-right font-medium tabular-nums text-xs text-slate-500">
                            {gIdx + 1}.{mIdx + 1}
                          </span>
                          <input
                            type="text"
                            disabled={!canEdit}
                            value={member.full_name}
                            onChange={(e) =>
                              updateMemberField(
                                gIdx,
                                mIdx,
                                'full_name',
                                e.target.value,
                              )
                            }
                            placeholder="ชื่อ-นามสกุล"
                            className="input py-1.5 text-xs"
                          />
                        </div>

                        <div className="sm:col-span-3">
                          <input
                            type="text"
                            disabled={!canEdit}
                            value={member.official_position}
                            onChange={(e) =>
                              updateMemberField(
                                gIdx,
                                mIdx,
                                'official_position',
                                e.target.value,
                              )
                            }
                            placeholder="ตำแหน่ง (เช่น ครู)"
                            className="input py-1.5 text-xs"
                          />
                        </div>

                        <div className="flex items-center gap-1.5 sm:col-span-4">
                          <input
                            type="text"
                            list="working-role-suggestions"
                            disabled={!canEdit}
                            value={member.working_role}
                            onChange={(e) =>
                              updateMemberField(
                                gIdx,
                                mIdx,
                                'working_role',
                                e.target.value,
                              )
                            }
                            placeholder="ตำแหน่งทำงาน"
                            className="input py-1.5 text-xs"
                          />
                          {canEdit && (
                            <button
                              type="button"
                              onClick={() => removeMember(gIdx, mIdx)}
                              className="rounded p-1 text-slate-400 hover:bg-rose-50 hover:text-rose-600"
                              title="ลบรายชื่อนี้"
                            >
                              <Trash2 className="h-3.5 w-3.5" strokeWidth={1.5} />
                            </button>
                          )}
                        </div>
                      </div>
                    ))}
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
                ระบุข้อความท้ายคำสั่ง วันที่สั่ง และชื่อ-ตำแหน่งผู้ลงนาม
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

              {canEdit && staffList.length > 0 && (
                <div className="sm:col-span-12">
                  <label className="mb-1 block text-xs font-medium text-slate-500">
                    ดึงชื่อผู้บริหาร/ผู้ลงนามจากทะเบียนบุคลากร (ตัวเลือกช่วยกรอก)
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
                          signer_title: `ผู้อำนวยการ${schoolName}`,
                        }));
                      }
                    }}
                    className="input py-1.5 text-xs"
                  >
                    <option value="">
                      เลือกชื่อผู้ลงนามจากรายชื่อบุคลากร...
                    </option>
                    {staffList.map((t) => (
                      <option key={t.id_user} value={t.id_user}>
                        {t.fullName} ({t.officialPosition})
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
