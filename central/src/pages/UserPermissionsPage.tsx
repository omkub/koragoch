import { useEffect, useMemo, useRef, useState } from 'react';
import {
  groupItems,
  schoolName,
  supabase,
  type Access,
  type PermissionItem,
  type Role,
  type School,
} from '../supabase';
import { EmptyState, Notice, PageHeader } from '../ui/components';
import { IconSearch } from '../ui/icons';
import PermMatrix, { SaveBar } from '../ui/PermMatrix';

interface TeacherRow {
  id_user: number;
  fullName: string | null;
  username: string | null;
  id_role: number | null;
  is_super_admin: boolean | null;
}

type Flags = Record<string, boolean>; // item_key → เปิด/ปิด

/**
 * สิทธิ์รายคน (UserPermissions) — เปิด/ปิดทีละรายการ ไม่เกินเพดานของสิทธิ์
 *
 *   ผู้ดูแลส่วนกลาง: เลือกได้ทุกโรงเรียน
 *   แอดมินโรงเรียน: เฉพาะโรงเรียนตัวเอง (RLS + trigger guard_user_permission)
 *
 * เก็บเฉพาะรายการที่ "ปิด" ไว้ในตาราง — รายการที่เปิดตามเพดานไม่ต้องมีแถว
 */
export default function UserPermissionsPage({ access }: { access: Access }) {
  const isSuper = access.level === 'super';
  const [schools, setSchools] = useState<School[]>([]);
  const [schoolId, setSchoolId] = useState<number | null>(access.schoolId);
  const [roles, setRoles] = useState<Role[]>([]);
  const [items, setItems] = useState<PermissionItem[]>([]);
  const [teachers, setTeachers] = useState<TeacherRow[]>([]);
  const [ceiling, setCeiling] = useState<Record<string, boolean>>({}); // `${role}:${key}`
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState<TeacherRow | null>(null);
  const [saved, setSaved] = useState<Flags>({});
  const [flags, setFlags] = useState<Flags>({});
  const [message, setMessage] = useState<{ text: string; error?: boolean } | null>(null);
  const [busy, setBusy] = useState(false);
  const detailRef = useRef<HTMLElement>(null);

  useEffect(() => {
    (async () => {
      const [s, r, i] = await Promise.all([
        supabase.from('Schools').select('*').order('id_school'),
        supabase.from('roles').select('ID_Roles, Accessrights').order('ID_Roles'),
        supabase.from('PermissionItems').select('key, group, label, sort').order('sort'),
      ]);
      const failed = s.error ?? r.error ?? i.error;
      if (failed) {
        setMessage({ text: `โหลดไม่สำเร็จ: ${failed.message} (รัน fine_permissions.sql แล้วหรือยัง?)`, error: true });
        return;
      }
      setSchools(s.data as School[]);
      setRoles(r.data as Role[]);
      setItems(i.data as PermissionItem[]);
      if (schoolId === null && s.data?.length) setSchoolId((s.data[0] as School).id_school);
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (schoolId === null) return;
    setSelected(null);
    (async () => {
      const [t, c] = await Promise.all([
        supabase
          .from('Teachers')
          .select('id_user, fullName, username, id_role, is_super_admin')
          .eq('id_school', schoolId)
          .order('fullName'),
        supabase.from('RolePermissions').select('id_role, item_key, allowed').eq('id_school', schoolId),
      ]);
      if (t.error || c.error) {
        setMessage({ text: (t.error ?? c.error)!.message, error: true });
        return;
      }
      setTeachers(t.data as TeacherRow[]);
      const next: Record<string, boolean> = {};
      for (const row of c.data ?? []) next[`${row.id_role}:${row.item_key}`] = row.allowed;
      setCeiling(next);
    })();
  }, [schoolId]);

  const inCeiling = (t: TeacherRow, key: string) => ceiling[`${t.id_role}:${key}`] === true;

  async function openTeacher(t: TeacherRow) {
    setMessage(null);
    setSelected(t);
    const { data, error } = await supabase
      .from('UserPermissions')
      .select('item_key, allowed')
      .eq('id_user', t.id_user);
    if (error) {
      setMessage({ text: error.message, error: true });
      return;
    }
    const overrides: Flags = {};
    for (const row of data ?? []) overrides[row.item_key] = row.allowed;
    // ค่าที่แสดง = เพดาน AND รายคน (ไม่มีแถวรายคน = ตามเพดาน)
    const effective: Flags = {};
    for (const item of items) {
      effective[item.key] = inCeiling(t, item.key) && (overrides[item.key] ?? true);
    }
    setSaved(effective);
    setFlags(effective);
  }

  const changed = useMemo(
    () => items.filter((i) => flags[i.key] !== saved[i.key]).map((i) => i.key),
    [flags, saved, items],
  );

  async function save() {
    if (!selected || changed.length === 0) return;
    setBusy(true);
    // ปิด → เก็บแถว allowed=false / เปิด → ลบแถว (กลับไปตามเพดาน)
    const toDisable = changed.filter((k) => !flags[k]);
    const toEnable = changed.filter((k) => flags[k]);
    const results = await Promise.all([
      toDisable.length
        ? supabase.from('UserPermissions').upsert(
            toDisable.map((k) => ({ id_user: selected.id_user, item_key: k, allowed: false })),
          )
        : Promise.resolve({ error: null }),
      toEnable.length
        ? supabase
            .from('UserPermissions')
            .delete()
            .eq('id_user', selected.id_user)
            .in('item_key', toEnable)
        : Promise.resolve({ error: null }),
    ]);
    setBusy(false);
    const failed = results.find((r) => r.error)?.error;
    if (failed) {
      setMessage({ text: `บันทึกไม่สำเร็จ: ${failed.message}`, error: true });
      return;
    }
    setMessage({ text: `บันทึกสิทธิ์ของ ${selected.fullName ?? selected.username} แล้ว` });
    openTeacher(selected);
  }

  const roleName = (id: number | null) =>
    roles.find((r) => r.ID_Roles === id)?.Accessrights ?? '-';

  const visible = teachers.filter((t) => {
    const q = search.trim().toLowerCase();
    return !q || `${t.fullName ?? ''} ${t.username ?? ''}`.toLowerCase().includes(q);
  });

  const ceilingCount = (t: TeacherRow) => items.filter((i) => inCeiling(t, i.key)).length;
  const currentSchool = schools.find((s) => s.id_school === schoolId);

  function pick(t: TeacherRow) {
    openTeacher(t);
    // มือถือ: รายละเอียดอยู่ใต้รายชื่อ — เลื่อนลงไปให้เห็นทันที
    if (window.matchMedia('(max-width: 1023px)').matches) {
      setTimeout(() => detailRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' }), 50);
    }
  }

  return (
    <>
      <PageHeader
        title="สิทธิ์ผู้ใช้"
        description="เปิด/ปิดรายการให้แต่ละคนได้ ไม่เกินเพดานของสิทธิ์ที่ผู้ดูแลส่วนกลางกำหนด · รายการสีเทา = อยู่นอกเพดาน"
        actions={
          isSuper ? (
            <select
              className="input w-auto max-w-full"
              value={schoolId ?? ''}
              onChange={(e) => setSchoolId(Number(e.target.value))}
              aria-label="เลือกโรงเรียน"
            >
              {schools.map((s) => (
                <option key={s.id_school} value={s.id_school}>
                  {schoolName(s)}
                </option>
              ))}
            </select>
          ) : currentSchool ? (
            <span className="badge-slate">{schoolName(currentSchool)}</span>
          ) : null
        }
      />
      <Notice message={message} />

      <div className="grid items-start gap-4 lg:grid-cols-[300px_minmax(0,1fr)]">
        <section className="card overflow-hidden">
          <div className="relative p-3">
            <IconSearch className="pointer-events-none absolute left-6 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
            <input
              className="input pl-9"
              placeholder="ค้นหาชื่อ / username"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          <div className="max-h-[260px] overflow-y-auto border-t border-line p-2 lg:max-h-[70vh]">
            {visible.map((t) => {
              const active = selected?.id_user === t.id_user;
              return (
                <button
                  key={t.id_user}
                  className={`flex w-full flex-col items-start rounded-lg px-3 py-2 text-left transition-colors ${
                    active ? 'bg-brand-50 text-brand-700' : 'hover:bg-slate-50'
                  }`}
                  onClick={() => pick(t)}
                >
                  <span className="text-[13.5px] font-medium">{t.fullName || t.username}</span>
                  <span className="text-xs text-slate-500">
                    {t.is_super_admin ? 'ส่วนกลาง' : roleName(t.id_role)} · {ceilingCount(t)} รายการ
                  </span>
                </button>
              );
            })}
            {visible.length === 0 && <EmptyState>ไม่พบรายชื่อ</EmptyState>}
          </div>
        </section>

        <section ref={detailRef} className="card scroll-mt-20 overflow-hidden">
          {!selected ? (
            <EmptyState>เลือกรายชื่อเพื่อตั้งค่าสิทธิ์</EmptyState>
          ) : (
            <>
              <div className="card-title flex-wrap">
                <span>{selected.fullName || selected.username}</span>
                <span className="text-xs font-medium text-slate-500">
                  {selected.is_super_admin ? 'ผู้ดูแลส่วนกลาง' : roleName(selected.id_role)} · ใช้ได้{' '}
                  {items.filter((i) => flags[i.key]).length}/{ceilingCount(selected)}
                </span>
              </div>
              {selected.is_super_admin ? (
                <EmptyState>ผู้ดูแลระบบส่วนกลางได้ทุกรายการเสมอ ปรับไม่ได้</EmptyState>
              ) : (
                <>
                  <PermMatrix
                    firstHeader="รายการ"
                    groups={groupItems(items).map(([group, list]) => ({
                      group,
                      rows: list.map((item) => {
                        const allowedByRole = inCeiling(selected, item.key);
                        return {
                          key: item.key,
                          label: item.label,
                          note: allowedByRole ? undefined : 'นอกเพดาน',
                          muted: !allowedByRole,
                          cells: [
                            {
                              key: item.key,
                              checked: flags[item.key] ?? false,
                              dirty: flags[item.key] !== saved[item.key],
                              disabled: !allowedByRole,
                              onChange: () => setFlags({ ...flags, [item.key]: !flags[item.key] }),
                            },
                          ],
                        };
                      }),
                    }))}
                  />
                  <SaveBar changed={changed.length} busy={busy} onReset={() => setFlags(saved)} onSave={save} />
                </>
              )}
            </>
          )}
        </section>
      </div>
    </>
  );
}
