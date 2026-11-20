import { useEffect, useMemo, useRef, useState } from 'react';
import { Layers } from 'lucide-react';
import {
  groupItems,
  schoolName,
  supabase,
  type Access,
  type PermissionItem,
  type Role,
  type School,
} from '../supabase';
import {
  fetchRoleDivisionModulePermissions,
  resolveModuleAccessLevel,
  resolveUserModuleOverrideLevel,
  saveUserModuleOverride,
  saveUserSchoolWebTabOverride,
  type AccessLevel,
  type RoleDivisionModulePermissions,
  type UserOverrideLevel,
  type UserTabOverride,
} from '../school/roleModulePermissions';
import {
  fetchSchoolPackageConfig,
  isModuleAllowedForSchool,
  SCHOOL_MODULE_META,
  type SchoolPackageConfig,
} from '../school/schoolPackage';
import { EmptyState, Notice, PageHeader, SectionHeader } from '../ui/components';
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

const LEVEL_LABEL: Record<AccessLevel, string> = {
  hidden: 'ซ่อน',
  view: 'ดูอย่างเดียว',
  edit: 'แก้ไขได้',
};

const USER_LEVEL_OPTIONS: {
  value: UserOverrideLevel;
  label: string;
  activeClass: string;
}[] = [
  {
    value: 'inherit',
    label: 'ตามบทบาท',
    activeClass: 'border-brand-600 bg-brand-600 text-white',
  },
  {
    value: 'hidden',
    label: 'ซ่อน',
    activeClass: 'border-slate-700 bg-slate-700 text-white',
  },
  {
    value: 'view',
    label: 'ดูอย่างเดียว',
    activeClass: 'border-sky-600 bg-sky-600 text-white',
  },
  {
    value: 'edit',
    label: 'แก้ไขได้',
    activeClass: 'border-emerald-600 bg-emerald-600 text-white',
  },
];

/**
 * สิทธิ์รายคน (UserPermissions) — กำหนดสิทธิ์เจาะจงรายบุคคลทั้งในเว็บโรงเรียน (Module ย่อย) และระบบวันลา
 */
export default function UserPermissionsPage({
  access,
  lockedSchoolId = null,
}: {
  access: Access;
  /** โรงเรียนที่กำลังจัดการ (มาจากแถบหัว) — ส่งมาแล้วจะไม่มีตัวเลือกโรงเรียนในหน้า */
  lockedSchoolId?: number | null;
}) {
  const isSuper = access.level === 'super';
  const [schools, setSchools] = useState<School[]>([]);
  const [schoolId, setSchoolId] = useState<number | null>(
    lockedSchoolId ?? access.schoolId,
  );
  useEffect(() => {
    if (lockedSchoolId != null) setSchoolId(lockedSchoolId);
  }, [lockedSchoolId]);
  const [roles, setRoles] = useState<Role[]>([]);
  const [items, setItems] = useState<PermissionItem[]>([]);
  const [teachers, setTeachers] = useState<TeacherRow[]>([]);
  const [ceiling, setCeiling] = useState<Record<string, boolean>>({});
  const [schoolPackage, setSchoolPackage] =
    useState<SchoolPackageConfig | null>(null);
  const [roleModPerms, setRoleModPerms] =
    useState<RoleDivisionModulePermissions>({
      divisionByRole: {},
      moduleByRole: {},
      userTabOverride: {},
      divisionByUser: {},
      moduleByUser: {},
    });
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState<TeacherRow | null>(null);
  const [saved, setSaved] = useState<Flags>({});
  const [flags, setFlags] = useState<Flags>({});
  const [message, setMessage] = useState<{ text: string; error?: boolean } | null>(null);
  const [busy, setBusy] = useState(false);
  const [busyModKey, setBusyModKey] = useState<string | null>(null);
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
        setMessage({
          text: `โหลดไม่สำเร็จ: ${failed.message} (รัน fine_permissions.sql แล้วหรือยัง?)`,
          error: true,
        });
        return;
      }
      setSchools(s.data as School[]);
      setRoles(r.data as Role[]);
      setItems(i.data as PermissionItem[]);
      if (schoolId === null && s.data?.length) {
        setSchoolId((s.data[0] as School).id_school);
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (schoolId === null) return;
    setSelected(null);
    (async () => {
      const [t, c, pkg, modPerms] = await Promise.all([
        supabase
          .from('Teachers')
          .select('id_user, fullName, username, id_role, is_super_admin')
          .eq('id_school', schoolId)
          .order('fullName'),
        supabase
          .from('RolePermissions')
          .select('id_role, item_key, allowed')
          .eq('id_school', schoolId),
        fetchSchoolPackageConfig(schoolId),
        fetchRoleDivisionModulePermissions(schoolId),
      ]);
      if (t.error || c.error) {
        setMessage({ text: (t.error ?? c.error)!.message, error: true });
        return;
      }
      setTeachers(t.data as TeacherRow[]);
      const next: Record<string, boolean> = {};
      for (const row of c.data ?? []) {
        next[`${row.id_role}:${row.item_key}`] = row.allowed;
      }
      setCeiling(next);
      setSchoolPackage(pkg);
      setRoleModPerms(modPerms);
    })();
  }, [schoolId]);

  const inCeiling = (t: TeacherRow, key: string) =>
    ceiling[`${t.id_role}:${key}`] === true;

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
    const effective: Flags = {};
    for (const item of items) {
      effective[item.key] =
        inCeiling(t, item.key) && (overrides[item.key] ?? true);
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
    const toDisable = changed.filter((k) => !flags[k]);
    const toEnable = changed.filter((k) => flags[k]);
    const results = await Promise.all([
      toDisable.length
        ? supabase.from('UserPermissions').upsert(
            toDisable.map((k) => ({
              id_user: selected.id_user,
              item_key: k,
              allowed: false,
            })),
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
    setMessage({
      text: `บันทึกสิทธิ์ของ ${selected.fullName ?? selected.username} แล้ว`,
    });
    openTeacher(selected);
  }

  async function handleSaveUserTabOverride(override: UserTabOverride) {
    if (!selected || !schoolId) return;
    setBusyModKey('tab-override');
    setMessage(null);

    const { error } = await saveUserSchoolWebTabOverride({
      schoolId,
      idUser: selected.id_user,
      override,
    });

    if (error) {
      setBusyModKey(null);
      setMessage({ text: `บันทึกไม่สำเร็จ: ${error}`, error: true });
      return;
    }

    const updated = await fetchRoleDivisionModulePermissions(schoolId);
    setRoleModPerms(updated);
    setBusyModKey(null);
    setMessage({
      text: `บันทึกการมองเห็นแท็บเว็บโรงเรียนของ ${selected.fullName ?? selected.username} เรียบร้อยแล้ว`,
    });
  }

  async function handleSaveUserModuleLevel(
    moduleKey: string,
    moduleTitle: string,
    level: UserOverrideLevel,
  ) {
    if (!selected || !schoolId) return;
    setBusyModKey(`mod:${moduleKey}`);
    setMessage(null);

    const { error } = await saveUserModuleOverride({
      schoolId,
      idUser: selected.id_user,
      moduleKey,
      level,
    });

    if (error) {
      setBusyModKey(null);
      setMessage({ text: `บันทึกไม่สำเร็จ: ${error}`, error: true });
      return;
    }

    const updated = await fetchRoleDivisionModulePermissions(schoolId);
    setRoleModPerms(updated);
    setBusyModKey(null);
    setMessage({
      text: `อัปเดตสิทธิ์ Module "${moduleTitle}" ของ ${selected.fullName ?? selected.username} เรียบร้อยแล้ว`,
    });
  }

  const roleName = (id: number | null) =>
    roles.find((r) => r.ID_Roles === id)?.Accessrights ?? '-';

  const visible = teachers.filter((t) => {
    const q = search.trim().toLowerCase();
    return (
      !q ||
      `${t.fullName ?? ''} ${t.username ?? ''}`.toLowerCase().includes(q)
    );
  });

  const ceilingCount = (t: TeacherRow) =>
    items.filter((i) => inCeiling(t, i.key)).length;
  const currentSchool = schools.find((s) => s.id_school === schoolId);

  const allowedSchoolModules = useMemo(
    () =>
      SCHOOL_MODULE_META.filter((m) =>
        isModuleAllowedForSchool(schoolPackage, m.key),
      ),
    [schoolPackage],
  );

  function pick(t: TeacherRow) {
    openTeacher(t);
    if (window.matchMedia('(max-width: 1023px)').matches) {
      setTimeout(
        () =>
          detailRef.current?.scrollIntoView({
            behavior: 'smooth',
            block: 'start',
          }),
        50,
      );
    }
  }

  const selectedTabOverride: UserTabOverride = useMemo(() => {
    if (!selected) return 'inherit';
    if (selected.id_user in roleModPerms.userTabOverride) {
      return roleModPerms.userTabOverride[selected.id_user]
        ? 'visible'
        : 'hidden';
    }
    return 'inherit';
  }, [selected, roleModPerms]);

  return (
    <>
      <PageHeader
        category="3. สิทธิ์และการเข้าถึง"
        title="กำหนดสิทธิ์รายบุคคล"
        description="กำหนดสิทธิ์เจาะจงรายคนทั้งการเข้าถึง Module ย่อยในเว็บโรงเรียน (ซ่อน / ดูอย่างเดียว / แก้ไขได้) และสิทธิ์ในระบบวันลา"
        actions={
          isSuper && lockedSchoolId == null ? (
            <div className="flex items-center gap-2">
              <span className="text-xs font-semibold text-slate-500">
                โรงเรียน:
              </span>
              <select
                className="input w-auto max-w-full font-semibold"
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
            </div>
          ) : currentSchool ? (
            <span className="badge-brand">{schoolName(currentSchool)}</span>
          ) : null
        }
      />
      <Notice message={message} />

      <div className="grid items-start gap-5 lg:grid-cols-[320px_minmax(0,1fr)]">
        {/* คอลัมน์ซ้าย: เลือกบุคลากร */}
        <div>
          <SectionHeader
            step="1"
            title="เลือกบุคลากร"
            subtitle={`ทั้งหมด ${visible.length} คน`}
          />
          <section className="card overflow-hidden">
            <div className="relative border-b border-line p-3">
              <IconSearch className="pointer-events-none absolute left-6 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
              <input
                className="input py-1.5 pl-9 text-[13px]"
                placeholder="ค้นหาชื่อ หรือ username..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>
            <div className="max-h-[280px] overflow-y-auto p-2 lg:max-h-[68vh]">
              {visible.map((t) => {
                const active = selected?.id_user === t.id_user;
                const hasCustomMod = Object.keys(roleModPerms.moduleByUser).some(
                  (k) => k.startsWith(`${t.id_user}:`),
                );
                return (
                  <button
                    key={t.id_user}
                    className={`mb-0.5 flex w-full flex-col items-start rounded-xl px-3 py-2.5 text-left transition-colors ${
                      active
                        ? 'bg-brand-50 text-brand-700 ring-1 ring-inset ring-brand-500/20'
                        : 'hover:bg-slate-50'
                    }`}
                    onClick={() => pick(t)}
                  >
                    <span className="text-[13px] font-semibold">
                      {t.fullName || t.username}
                    </span>
                    <div className="mt-1 flex flex-wrap items-center gap-1.5 text-xs text-slate-500">
                      <span className={active ? 'badge-brand' : 'badge-slate'}>
                        {t.is_super_admin ? 'ส่วนกลาง' : roleName(t.id_role)}
                      </span>
                      {hasCustomMod && (
                        <span className="rounded bg-emerald-100 px-1.5 py-0.5 text-[10px] font-semibold text-emerald-700">
                          ตั้งค่า Module เฉพาะคน
                        </span>
                      )}
                    </div>
                  </button>
                );
              })}
              {visible.length === 0 && (
                <EmptyState>ไม่พบรายชื่อบุคลากร</EmptyState>
              )}
            </div>
          </section>
        </div>

        {/* คอลัมน์ขวา: ตารางสิทธิ์รายคน */}
        <div className="space-y-6">
          <SectionHeader
            step="2"
            title={
              selected
                ? `รายการสิทธิ์ของ: ${selected.fullName || selected.username}`
                : 'ตั้งค่าสิทธิ์รายบุคคล'
            }
            subtitle={
              selected
                ? `สิทธิ์หลัก: ${selected.is_super_admin ? 'ผู้ดูแลส่วนกลาง' : roleName(selected.id_role)}`
                : 'คลิกเลือกรายชื่อบุคลากรทางด้านซ้ายเพื่อดูและแก้ไขสิทธิ์'
            }
          />

          <section ref={detailRef} className="scroll-mt-20 space-y-6">
            {!selected ? (
              <div className="card overflow-hidden">
                <EmptyState>เลือกรายชื่อบุคลากรทางซ้ายเพื่อตั้งค่าสิทธิ์</EmptyState>
              </div>
            ) : selected.is_super_admin ? (
              <div className="card overflow-hidden">
                <EmptyState>
                  ผู้ดูแลระบบส่วนกลางได้รับสิทธิ์ทุกรายการโดยอัตโนมัติ (ไม่สามารถปิดรายรายการได้)
                </EmptyState>
              </div>
            ) : (
              <>
                {/* ส่วนที่ 2.1: สิทธิ์การใช้งานเว็บโรงเรียนและ Module ย่อยรายบุคคล */}
                <div className="card overflow-hidden">
                  <div className="card-title flex-wrap bg-brand-50/40">
                    <div className="flex items-center gap-2">
                      <Layers className="h-4 w-4 text-brand-600" />
                      <span className="font-semibold text-ink">
                        สิทธิ์เว็บโรงเรียนและ Module ย่อยเฉพาะของ:{' '}
                        {selected.fullName || selected.username}
                      </span>
                    </div>
                    <span className="badge-brand">
                      บทบาทหลัก: {roleName(selected.id_role)}
                    </span>
                  </div>

                  <div className="divide-y divide-line p-5">
                    {/* การมองเห็นแท็บเว็บโรงเรียนบน PC เฉพาะคน */}
                    <div className="pb-4">
                      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                        <div>
                          <p className="text-sm font-semibold text-ink">
                            การมองเห็นแท็บ &ldquo;เว็บโรงเรียน&rdquo; บนหน้าจอ PC (ระบบวันลา)
                          </p>
                          <p className="mt-0.5 text-xs text-slate-500">
                            เปิดหรือซ่อนแท็บเว็บโรงเรียนเฉพาะบุคคลนี้ (แม้บทบาทหลักจะถูกซ่อนไว้)
                          </p>
                        </div>

                        <div className="inline-flex flex-wrap items-center gap-1.5">
                          {(
                            [
                              { val: 'inherit', label: 'ตามบทบาท' },
                              { val: 'visible', label: 'เปิดให้เห็น' },
                              { val: 'hidden', label: 'ซ่อนแท็บนี้' },
                            ] as { val: UserTabOverride; label: string }[]
                          ).map((opt) => {
                            const active = selectedTabOverride === opt.val;
                            return (
                              <button
                                key={opt.val}
                                type="button"
                                disabled={busyModKey === 'tab-override'}
                                onClick={() => handleSaveUserTabOverride(opt.val)}
                                className={`rounded-lg border px-3 py-1.5 text-xs font-medium transition-colors ${
                                  active
                                    ? 'border-brand-600 bg-brand-600 text-white'
                                    : 'border-line bg-white text-slate-600 hover:bg-slate-50'
                                } disabled:opacity-50`}
                              >
                                {opt.label}
                              </button>
                            );
                          })}
                        </div>
                      </div>
                    </div>

                    {/* รายการ Module ย่อยที่โรงเรียนได้รับอนุญาต */}
                    <div className="pt-4">
                      <p className="mb-3 text-xs font-semibold text-slate-500">
                        กำหนดสิทธิ์ราย Module ย่อยสำหรับบุคลากรคนนี้ ({allowedSchoolModules.length} Module ที่เปิดในโรงเรียนนี้)
                      </p>

                      <div className="grid gap-3 sm:grid-cols-2">
                        {allowedSchoolModules.map((mod) => {
                          const userOverride = resolveUserModuleOverrideLevel(
                            roleModPerms,
                            selected.id_user,
                            mod.key,
                          );
                          const roleDefaultLevel = resolveModuleAccessLevel(
                            roleModPerms,
                            selected.id_role,
                            mod.divisionKey === 'all' ? 'hr' : mod.divisionKey,
                            mod.key,
                            roleName(selected.id_role).includes('ผู้ดูแลระบบ'),
                            null,
                          );
                          const effectiveLevel =
                            userOverride === 'inherit'
                              ? roleDefaultLevel
                              : userOverride;
                          const isBusy = busyModKey === `mod:${mod.key}`;

                          return (
                            <div
                              key={mod.key}
                              className="flex flex-col justify-between gap-2.5 rounded-xl border border-line bg-slate-50/40 p-3.5"
                            >
                              <div>
                                <div className="flex items-center justify-between gap-2">
                                  <span className="text-xs font-semibold text-ink">
                                    {mod.title}
                                  </span>
                                  <span className="rounded-full bg-white px-2 py-0.5 text-[10px] font-semibold text-slate-600 ring-1 ring-line">
                                    ผลลัพธ์: {LEVEL_LABEL[effectiveLevel]}
                                  </span>
                                </div>
                                <p className="mt-0.5 text-[11px] text-slate-500">
                                  ค่าตามบทบาท ({roleName(selected.id_role)}):{' '}
                                  <strong>{LEVEL_LABEL[roleDefaultLevel]}</strong>
                                </p>
                              </div>

                              <div className="grid grid-cols-4 gap-1">
                                {USER_LEVEL_OPTIONS.map((opt) => {
                                  const active = userOverride === opt.value;
                                  return (
                                    <button
                                      key={opt.value}
                                      type="button"
                                      disabled={isBusy}
                                      onClick={() =>
                                        handleSaveUserModuleLevel(
                                          mod.key,
                                          mod.title,
                                          opt.value,
                                        )
                                      }
                                      className={`rounded-md border px-1.5 py-1 text-[11px] font-medium transition-colors ${
                                        active
                                          ? opt.activeClass
                                          : 'border-line bg-white text-slate-600 hover:bg-slate-50'
                                      } disabled:opacity-50`}
                                    >
                                      {opt.label}
                                    </button>
                                  );
                                })}
                              </div>
                            </div>
                          );
                        })}
                      </div>
                    </div>
                  </div>
                </div>

                {/* ส่วนที่ 2.2: สิทธิ์ระบบวันลารายบุคคล (ภายใต้เพดานของบทบาท) */}
                <div className="card overflow-hidden">
                  <div className="card-title flex-wrap bg-slate-50/50">
                    <div className="flex items-center gap-2">
                      <span className="font-semibold text-ink">
                        สิทธิ์การปฏิบัติงานในระบบวันลา ({selected.fullName || selected.username})
                      </span>
                    </div>
                    <span className="badge-green">
                      เปิดใช้งาน {items.filter((i) => flags[i.key]).length} / เพดาน{' '}
                      {ceilingCount(selected)} รายการ
                    </span>
                  </div>

                  <PermMatrix
                    firstHeader="หมวดหมู่และรายการสิทธิ์ระบบวันลา"
                    groups={groupItems(items).map(([group, list]) => ({
                      group,
                      rows: list.map((item) => {
                        const allowedByRole = inCeiling(selected, item.key);
                        return {
                          key: item.key,
                          label: item.label,
                          note: allowedByRole ? undefined : 'อยู่นอกเพดานสิทธิ์',
                          muted: !allowedByRole,
                          cells: [
                            {
                              key: item.key,
                              checked: flags[item.key] ?? false,
                              dirty: flags[item.key] !== saved[item.key],
                              disabled: !allowedByRole,
                              onChange: () =>
                                setFlags({
                                  ...flags,
                                  [item.key]: !flags[item.key],
                                }),
                            },
                          ],
                        };
                      }),
                    }))}
                  />
                  <SaveBar
                    changed={changed.length}
                    busy={busy}
                    onReset={() => setFlags(saved)}
                    onSave={save}
                  />
                </div>
              </>
            )}
          </section>
        </div>
      </div>
    </>
  );
}
