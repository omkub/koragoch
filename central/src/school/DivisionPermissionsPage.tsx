import { useCallback, useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { Check, Eye, EyeOff, Layers, Pencil, ShieldCheck } from 'lucide-react';
import { rolesForSchool, supabase, type Role } from '../supabase';
import type { DivisionWithModules } from './mapping';
import {
  fetchRoleDivisionModulePermissions,
  resolveDivisionAccessLevel,
  resolveModuleAccessLevel,
  saveRoleDivisionAccessLevel,
  saveRoleModuleAccessLevel,
  type AccessLevel,
  type RoleDivisionModulePermissions,
} from './roleModulePermissions';
import SchoolPackagePanel from './SchoolPackagePanel';
import type { SchoolBasic } from './types';

interface DivisionPermissionsPageProps {
  school: SchoolBasic | null;
  schoolId: number | null;
  canEdit: boolean;
  isSuper?: boolean;
  divisions: DivisionWithModules[];
  hasDbMapping: boolean;
  onReload: () => Promise<void>;
}

const LEVEL_META: Record<
  AccessLevel,
  { label: string; badgeClass: string; activeBtnClass: string }
> = {
  hidden: {
    label: 'ซ่อน',
    badgeClass: 'bg-slate-100 text-slate-600',
    activeBtnClass: 'bg-slate-700 text-white border-slate-700',
  },
  view: {
    label: 'ดูอย่างเดียว',
    badgeClass: 'bg-sky-50 text-sky-700 ring-1 ring-inset ring-sky-200',
    activeBtnClass: 'bg-sky-600 text-white border-sky-600',
  },
  edit: {
    label: 'แก้ไขได้',
    badgeClass: 'bg-emerald-50 text-emerald-700 ring-1 ring-inset ring-emerald-200',
    activeBtnClass: 'bg-emerald-600 text-white border-emerald-600',
  },
};

export default function DivisionPermissionsPage({
  school,
  schoolId,
  canEdit,
  isSuper = false,
  divisions,
  onReload,
}: DivisionPermissionsPageProps) {
  const [roles, setRoles] = useState<Role[]>([]);
  const [tabVisibleByRole, setTabVisibleByRole] = useState<
    Record<number, boolean>
  >({});
  const [permState, setPermState] = useState<RoleDivisionModulePermissions>({
    divisionByRole: {},
    moduleByRole: {},
    userTabOverride: {},
    divisionByUser: {},
    moduleByUser: {},
  });
  const [selectedDivKey, setSelectedDivKey] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [busyKey, setBusyKey] = useState<string | null>(null);
  const [message, setMessage] = useState<{
    type: 'ok' | 'err';
    text: string;
  } | null>(null);

  const selectedDivision = useMemo(
    () =>
      divisions.find((d) => d.division_key === selectedDivKey) ??
      divisions[0] ??
      null,
    [divisions, selectedDivKey],
  );

  const allDivisionKeys = useMemo(
    () => divisions.map((d) => d.division_key),
    [divisions],
  );
  const allModuleKeys = useMemo(() => {
    const set = new Set<string>();
    for (const d of divisions) {
      for (const m of d.modules) set.add(m.module_key);
    }
    return [...set];
  }, [divisions]);

  const loadData = useCallback(async () => {
    if (!schoolId) return;
    setLoading(true);
    const [rolesRes, permRes, roleDivModPerms] = await Promise.all([
      supabase
        .from('roles')
        .select('ID_Roles, Accessrights, id_school')
        .order('ID_Roles', { ascending: true }),
      supabase
        .from('Permissions')
        .select('id_role, menu_id, status')
        .eq('id_school', schoolId)
        .eq('menu_id', 6),
      fetchRoleDivisionModulePermissions(
        schoolId,
        allDivisionKeys.length > 0
          ? allDivisionKeys
          : ['hr', 'academic', 'admin', 'finance'],
        allModuleKeys.length > 0 ? allModuleKeys : undefined,
      ),
    ]);

    const allRoles = (rolesRes.data as Role[] | null) ?? [];
    const schoolRoles = rolesForSchool(allRoles, schoolId);
    setRoles(schoolRoles);

    const tabMap: Record<number, boolean> = {};
    for (const r of schoolRoles) {
      tabMap[r.ID_Roles] = true;
    }
    for (const row of (permRes.data as
      | { id_role: number; menu_id: number; status: unknown }[]
      | null) ?? []) {
      const st = row.status;
      tabMap[row.id_role] =
        st === true ||
        st === 1 ||
        String(st) === '1' ||
        String(st).toUpperCase() === 'TRUE';
    }
    setTabVisibleByRole(tabMap);
    setPermState(roleDivModPerms);
    setLoading(false);
  }, [schoolId, allDivisionKeys, allModuleKeys]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  useEffect(() => {
    if (
      divisions.length > 0 &&
      (!selectedDivKey || !divisions.some((d) => d.division_key === selectedDivKey))
    ) {
      setSelectedDivKey(divisions[0].division_key);
    }
  }, [divisions, selectedDivKey]);

  async function togglePcTabVisibility(roleId: number, nextVisible: boolean) {
    if (!schoolId || !canEdit) return;
    const key = `tab:${roleId}`;
    setBusyKey(key);
    setMessage(null);

    const { error } = await supabase.from('Permissions').upsert(
      {
        id_school: schoolId,
        id_role: roleId,
        menu_id: 6,
        status: nextVisible ? '1' : '0',
        updatedAt: new Date().toISOString(),
      },
      { onConflict: 'id_school,id_role,menu_id' },
    );

    setBusyKey(null);
    if (error) {
      setMessage({
        type: 'err',
        text: `บันทึกสิทธิ์แท็บ PC ไม่สำเร็จ: ${error.message}`,
      });
      return;
    }

    setTabVisibleByRole((prev) => ({
      ...prev,
      [roleId]: nextVisible,
    }));
    setMessage({
      type: 'ok',
      text: 'อัปเดตสิทธิ์การมองเห็นแท็บ "เว็บโรงเรียน" บนหน้าจอ PC เรียบร้อยแล้ว',
    });
  }

  async function handleChangeDivisionLevel(
    divisionKey: string,
    divisionId: number,
    roleId: number,
    level: AccessLevel,
  ) {
    if (!schoolId || !canEdit) return;
    const key = `div:${divisionKey}:${roleId}`;
    setBusyKey(key);
    setMessage(null);

    const { error } = await saveRoleDivisionAccessLevel({
      schoolId,
      roleId,
      divisionKey,
      divisionId,
      level,
    });

    setBusyKey(null);
    if (error) {
      setMessage({ type: 'err', text: `บันทึกสิทธิ์ฝ่ายไม่สำเร็จ: ${error}` });
      return;
    }

    setPermState((prev) => ({
      ...prev,
      divisionByRole: {
        ...prev.divisionByRole,
        [`${roleId}:${divisionKey}`]: {
          can_view: level !== 'hidden',
          can_edit: level === 'edit',
        },
      },
    }));
    setMessage({
      type: 'ok',
      text: `บันทึกสิทธิ์ระดับฝ่ายงานเรียบร้อยแล้ว (${LEVEL_META[level].label})`,
    });
    await onReload();
  }

  async function handleChangeModuleLevel(
    moduleKey: string,
    moduleTitle: string,
    roleId: number,
    level: AccessLevel,
  ) {
    if (!schoolId || !canEdit) return;
    const key = `mod:${moduleKey}:${roleId}`;
    setBusyKey(key);
    setMessage(null);

    const { error } = await saveRoleModuleAccessLevel({
      schoolId,
      roleId,
      moduleKey,
      level,
    });

    setBusyKey(null);
    if (error) {
      setMessage({ type: 'err', text: `บันทึกสิทธิ์ Module ไม่สำเร็จ: ${error}` });
      return;
    }

    setPermState((prev) => ({
      ...prev,
      moduleByRole: {
        ...prev.moduleByRole,
        [`${roleId}:${moduleKey}`]: {
          can_view: level !== 'hidden',
          can_edit: level === 'edit',
        },
      },
    }));
    setMessage({
      type: 'ok',
      text: `บันทึกสิทธิ์ของ Module "${moduleTitle}" เรียบร้อยแล้ว (${LEVEL_META[level].label})`,
    });
    await onReload();
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="text-xs font-medium text-brand-600">
            โหมดผู้ดูแลระบบ · สิทธิ์การมองเห็นและการใช้งานตามบทบาท
          </p>
          <h1 className="mt-1 text-2xl font-semibold tracking-tight text-ink">
            สิทธิ์เข้าถึงฝ่ายงานและ Module ย่อยตามบทบาท (Role)
          </h1>
          <p className="mt-1 text-sm text-slate-600">
            กำหนดว่าแต่ละบทบาทใน{' '}
            <span className="font-medium text-ink">
              {school?.fullName || 'โรงเรียน'}
            </span>{' '}
            สามารถมองเห็น ซ่อน ดูอย่างเดียว หรือแก้ไขข้อมูลในแต่ละฝ่ายและแต่ละ Module ย่อยได้
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <Link to="/user-permissions" className="btn-secondary btn-sm shrink-0">
            กำหนดสิทธิ์รายบุคคล
          </Link>
          <Link to="/admin/mapping" className="btn-secondary btn-sm shrink-0">
            จัดการฝ่ายและ Module
          </Link>
        </div>
      </div>

      {message && (
        <div
          className={`rounded-xl border px-4 py-3 text-xs font-medium ${
            message.type === 'ok'
              ? 'border-emerald-200 bg-emerald-50 text-emerald-800'
              : 'border-rose-200 bg-rose-50 text-rose-700'
          }`}
        >
          {message.text}
        </div>
      )}

      {/* สิทธิ์ระดับโรงเรียน: เปิด/ปิดเว็บโรงเรียน และเลือก Module ย่อยที่อนุญาตให้โรงเรียนนี้เห็น */}
      {isSuper && (
        <SchoolPackagePanel
          schoolId={schoolId}
          schoolName={school?.fullName || `โรงเรียน #${schoolId ?? '-'}`}
          canManage={isSuper}
          onUpdated={onReload}
        />
      )}

      {/* ส่วนที่ 1: สิทธิ์การมองเห็นแท็บ "เว็บโรงเรียน" บนแถบเมนูซ้ายของแอปวันลา (PC) */}
      <div className="surface-card p-6">
        <div className="mb-4">
          <h2 className="text-base font-semibold text-ink">
            1. สิทธิ์การมองเห็นแท็บ &ldquo;เว็บโรงเรียน&rdquo; บนหน้าจอ PC (ระบบวันลา)
          </h2>
          <p className="mt-0.5 text-xs text-slate-500">
            กำหนดว่ากลุ่มบทบาทใดในโรงเรียนจะเห็นแท็บเมนู &ldquo;เว็บโรงเรียน&rdquo; บนแถบเมนูด้านซ้ายของแอประบบวันลาบน PC
          </p>
        </div>

        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {roles.map((role) => {
            const isAdminRole = role.Accessrights.includes('ผู้ดูแลระบบ');
            const isVisible = isAdminRole
              ? true
              : (tabVisibleByRole[role.ID_Roles] ?? true);
            const isBusy = busyKey === `tab:${role.ID_Roles}`;

            return (
              <div
                key={role.ID_Roles}
                className={`flex items-center justify-between gap-3 rounded-xl border p-3.5 transition-colors ${
                  isVisible
                    ? 'border-brand-200 bg-brand-50/40'
                    : 'border-line bg-canvas/50'
                }`}
              >
                <div className="min-w-0">
                  <p className="truncate text-sm font-semibold text-ink">
                    {role.Accessrights}
                  </p>
                  <p className="text-[11px] text-slate-500">
                    {isVisible ? 'มองเห็นแท็บเว็บโรงเรียน' : 'ซ่อนแท็บเว็บโรงเรียน'}
                  </p>
                </div>

                <button
                  type="button"
                  disabled={!canEdit || isAdminRole || isBusy}
                  onClick={() =>
                    togglePcTabVisibility(role.ID_Roles, !isVisible)
                  }
                  className={`inline-flex h-6 w-6 shrink-0 items-center justify-center rounded-md border transition-colors ${
                    isVisible
                      ? 'border-brand-600 bg-brand-600 text-white'
                      : 'border-slate-300 bg-white text-transparent hover:border-slate-400'
                  } disabled:opacity-50`}
                  aria-label={`เปิดหรือปิดการมองเห็นแท็บเว็บโรงเรียนสำหรับ ${role.Accessrights}`}
                >
                  <Check className="h-3.5 w-3.5" strokeWidth={2} />
                </button>
              </div>
            );
          })}
        </div>
      </div>

      {/* ส่วนที่ 2: สิทธิ์ระดับฝ่ายงาน และ Module ย่อยภายในฝ่าย */}
      {loading ? (
        <div className="surface-card p-8 text-center text-sm text-slate-500">
          กำลังโหลดข้อมูลบทบาทและสิทธิ์แต่ละฝ่าย...
        </div>
      ) : divisions.length === 0 ? (
        <div className="surface-card p-8 text-center text-sm text-slate-500">
          ไม่มีฝ่ายงานที่เปิดให้โรงเรียนนี้ใช้งาน
        </div>
      ) : (
        <div className="grid gap-6 lg:grid-cols-12">
          {/* รายชื่อฝ่ายด้านซ้าย */}
          <div className="space-y-2 lg:col-span-4">
            <p className="px-1 text-xs font-semibold uppercase tracking-wider text-slate-400">
              เลือกฝ่ายงานของโรงเรียน ({divisions.length})
            </p>
            {divisions.map((div) => {
              const active = selectedDivision?.division_key === div.division_key;
              return (
                <button
                  key={div.division_key}
                  type="button"
                  onClick={() => setSelectedDivKey(div.division_key)}
                  className={`flex w-full items-start justify-between gap-3 rounded-xl border p-4 text-left transition-colors ${
                    active
                      ? 'border-brand-600 bg-brand-50/50 text-brand-700'
                      : 'border-line bg-white text-ink hover:bg-slate-50'
                  }`}
                >
                  <div>
                    <div className="flex items-center gap-2">
                      <ShieldCheck
                        className={`h-4 w-4 ${
                          active ? 'text-brand-600' : 'text-slate-400'
                        }`}
                        strokeWidth={1.75}
                      />
                      <span className="text-sm font-semibold">{div.name}</span>
                    </div>
                    {div.description && (
                      <p className="mt-1 text-xs text-slate-500">
                        {div.description}
                      </p>
                    )}
                  </div>
                  <span className="rounded-md bg-slate-100 px-2 py-0.5 text-[11px] font-medium text-slate-600">
                    {div.modules.length} Module
                  </span>
                </button>
              );
            })}
          </div>

          {/* ตารางกำหนดสิทธิ์ตาม Role และแยกตาม Module ย่อยด้านขวา */}
          <div className="space-y-6 lg:col-span-8">
            {selectedDivision && (
              <>
                {/* 2.1 สิทธิ์ระดับฝ่ายงาน (ทั้งฝ่าย) */}
                <div className="surface-card overflow-hidden">
                  <div className="border-b border-line bg-slate-50/60 px-6 py-4">
                    <h2 className="text-base font-semibold text-ink">
                      2.1 สิทธิ์การเข้าถึงระดับฝ่าย: {selectedDivision.name}
                    </h2>
                    <p className="mt-0.5 text-xs text-slate-500">
                      กำหนดว่าแต่ละบทบาทจะเห็นฝ่ายนี้บนแถบเมนูซ้ายหรือไม่ และมีสิทธิ์พื้นฐานเป็น &ldquo;ดูอย่างเดียว&rdquo; หรือ &ldquo;แก้ไขได้ทั้งฝ่าย&rdquo;
                    </p>
                  </div>

                  <div className="divide-y divide-line">
                    {roles.map((role) => {
                      const isAdminRole =
                        role.Accessrights.includes('ผู้ดูแลระบบ');
                      const currentLevel = resolveDivisionAccessLevel(
                        permState,
                        role.ID_Roles,
                        selectedDivision.division_key,
                        isAdminRole,
                      );
                      const isBusy =
                        busyKey ===
                        `div:${selectedDivision.division_key}:${role.ID_Roles}`;

                      return (
                        <div
                          key={role.ID_Roles}
                          className="flex flex-col gap-3 px-6 py-3.5 sm:flex-row sm:items-center sm:justify-between"
                        >
                          <div className="min-w-0">
                            <div className="flex items-center gap-2">
                              <span className="text-sm font-medium text-ink">
                                {role.Accessrights}
                              </span>
                              <span
                                className={`rounded-full px-2 py-0.5 text-[10px] font-semibold ${LEVEL_META[currentLevel].badgeClass}`}
                              >
                                {LEVEL_META[currentLevel].label}
                              </span>
                            </div>
                            {isAdminRole && (
                              <p className="mt-0.5 text-[11px] text-emerald-600">
                                ผู้ดูแลระบบเข้าดูและแก้ไขได้ทุกฝ่ายโดยอัตโนมัติ
                              </p>
                            )}
                          </div>

                          <div className="inline-flex items-center gap-1.5">
                            {(['hidden', 'view', 'edit'] as AccessLevel[]).map(
                              (lvl) => {
                                const active = currentLevel === lvl;
                                return (
                                  <button
                                    key={lvl}
                                    type="button"
                                    disabled={!canEdit || isAdminRole || isBusy}
                                    onClick={() =>
                                      handleChangeDivisionLevel(
                                        selectedDivision.division_key,
                                        selectedDivision.id,
                                        role.ID_Roles,
                                        lvl,
                                      )
                                    }
                                    className={`inline-flex items-center gap-1 rounded-lg border px-2.5 py-1.5 text-xs font-medium transition-colors ${
                                      active
                                        ? LEVEL_META[lvl].activeBtnClass
                                        : 'border-line bg-white text-slate-600 hover:bg-slate-50'
                                    } disabled:opacity-50`}
                                  >
                                    {lvl === 'hidden' && (
                                      <EyeOff className="h-3.5 w-3.5" />
                                    )}
                                    {lvl === 'view' && (
                                      <Eye className="h-3.5 w-3.5" />
                                    )}
                                    {lvl === 'edit' && (
                                      <Pencil className="h-3.5 w-3.5" />
                                    )}
                                    <span>{LEVEL_META[lvl].label}</span>
                                  </button>
                                );
                              },
                            )}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>

                {/* 2.2 สิทธิ์ระดับ Module ย่อยภายในฝ่าย */}
                <div className="surface-card overflow-hidden">
                  <div className="border-b border-line bg-slate-50/60 px-6 py-4">
                    <div className="flex items-center gap-2">
                      <Layers className="h-4 w-4 text-brand-600" />
                      <h2 className="text-base font-semibold text-ink">
                        2.2 สิทธิ์แยกราย Module ย่อยใน{selectedDivision.name}
                      </h2>
                    </div>
                    <p className="mt-0.5 text-xs text-slate-500">
                      กำหนดเจาะจงแต่ละ Module ย่อยว่าบทบาทใด{' '}
                      <strong>ซ่อน</strong> (ไม่เห็นแท็บ Module),{' '}
                      <strong>ดูอย่างเดียว</strong> (เปิดดู/ดาวน์โหลดได้ แต่เพิ่มหรือแก้ไขไม่ได้), หรือ{' '}
                      <strong>แก้ไขได้</strong>
                    </p>
                  </div>

                  {selectedDivision.modules.length === 0 ? (
                    <div className="p-6 text-center text-xs text-slate-500">
                      ไม่มี Module ย่อยในฝ่ายนี้
                    </div>
                  ) : (
                    <div className="divide-y divide-line">
                      {selectedDivision.modules.map((mod) => (
                        <div key={mod.module_key} className="p-5">
                          <div className="mb-3">
                            <div className="flex flex-wrap items-center gap-2">
                              <h3 className="text-sm font-semibold text-ink">
                                {mod.title}
                              </h3>
                              <span className="rounded bg-slate-100 px-2 py-0.5 font-mono text-[10px] text-slate-500">
                                {mod.module_key}
                              </span>
                            </div>
                            {mod.description && (
                              <p className="mt-0.5 text-xs text-slate-500">
                                {mod.description}
                              </p>
                            )}
                          </div>

                          <div className="grid gap-2.5 sm:grid-cols-2">
                            {roles.map((role) => {
                              const isAdminRole =
                                role.Accessrights.includes('ผู้ดูแลระบบ');
                              const divLevel = resolveDivisionAccessLevel(
                                permState,
                                role.ID_Roles,
                                selectedDivision.division_key,
                                isAdminRole,
                              );
                              const modLevel = resolveModuleAccessLevel(
                                permState,
                                role.ID_Roles,
                                selectedDivision.division_key,
                                mod.module_key,
                                isAdminRole,
                              );
                              const isBusy =
                                busyKey ===
                                `mod:${mod.module_key}:${role.ID_Roles}`;

                              return (
                                <div
                                  key={role.ID_Roles}
                                  className="flex flex-col justify-between gap-2 rounded-xl border border-line bg-canvas/40 p-3"
                                >
                                  <div className="flex items-center justify-between gap-2">
                                    <span className="truncate text-xs font-semibold text-ink">
                                      {role.Accessrights}
                                    </span>
                                    <span
                                      className={`rounded-full px-2 py-0.5 text-[10px] font-semibold ${LEVEL_META[modLevel].badgeClass}`}
                                    >
                                      {divLevel === 'hidden'
                                        ? 'ซ่อน (ตามฝ่าย)'
                                        : LEVEL_META[modLevel].label}
                                    </span>
                                  </div>

                                  <div className="grid grid-cols-3 gap-1">
                                    {(
                                      ['hidden', 'view', 'edit'] as AccessLevel[]
                                    ).map((lvl) => {
                                      const active = modLevel === lvl;
                                      return (
                                        <button
                                          key={lvl}
                                          type="button"
                                          disabled={
                                            !canEdit ||
                                            isAdminRole ||
                                            divLevel === 'hidden' ||
                                            isBusy
                                          }
                                          onClick={() =>
                                            handleChangeModuleLevel(
                                              mod.module_key,
                                              mod.title,
                                              role.ID_Roles,
                                              lvl,
                                            )
                                          }
                                          className={`rounded-md border px-2 py-1 text-[11px] font-medium transition-colors ${
                                            active
                                              ? LEVEL_META[lvl].activeBtnClass
                                              : 'border-line bg-white text-slate-600 hover:bg-slate-50'
                                          } disabled:opacity-45`}
                                        >
                                          {LEVEL_META[lvl].label}
                                        </button>
                                      );
                                    })}
                                  </div>
                                </div>
                              );
                            })}
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
