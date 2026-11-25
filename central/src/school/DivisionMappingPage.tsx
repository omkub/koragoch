import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react';
import {
  Check,
  ExternalLink,
  Layers,
  Pencil,
  Plus,
  Power,
  RefreshCw,
  Search,
  Trash2,
  UserCheck,
  Users,
} from 'lucide-react';
import { supabase } from '../supabase';
import type {
  DivisionIconName,
  DivisionWithModules,
  ModuleCatalogItem,
  ResolvedDivisionModule,
} from './mapping';
import {
  fetchRoleDivisionModulePermissions,
  type RoleDivisionModulePermissions,
} from './roleModulePermissions';
import {
  fetchSchoolStaffMembers,
  getStaffAssignedDivisionKeys,
  getStaffDivisionMemberRole,
  inferRoleTierFromRoleName,
  ROLE_TIER_META,
  saveStaffDivisionMembership,
  type DivisionMemberRole,
  type SchoolStaffMember,
} from './staffDivisionMapping';
import type { SchoolBasic } from './types';

interface DivisionMappingPageProps {
  school: SchoolBasic | null;
  schoolId: number | null;
  canEdit: boolean;
  isSuper?: boolean;
  catalog: ModuleCatalogItem[];
  divisions: DivisionWithModules[];
  hasDbMapping: boolean;
  onReload: () => Promise<void>;
}

const ICON_OPTIONS: { value: DivisionIconName; label: string }[] = [
  { value: 'users', label: 'บุคลากร (Users)' },
  { value: 'graduation-cap', label: 'วิชาการ/นักเรียน (Academic)' },
  { value: 'file-text', label: 'สารบรรณ/เอกสาร (Document)' },
  { value: 'wallet', label: 'การเงิน/พัสดุ (Wallet)' },
  { value: 'folder', label: 'ทั่วไป (Folder)' },
];

export default function DivisionMappingPage({
  school,
  schoolId,
  canEdit,
  catalog,
  divisions,
  hasDbMapping,
  onReload,
}: DivisionMappingPageProps) {
  const [activeTab, setActiveTab] = useState<'modules' | 'staff'>('modules');
  const [selectedDivId, setSelectedDivId] = useState<number | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  // Add Division form
  const [showAddDiv, setShowAddDiv] = useState(false);
  const [divKey, setDivKey] = useState('');
  const [divName, setDivName] = useState('');
  const [divDesc, setDivDesc] = useState('');
  const [divIcon, setDivIcon] = useState<DivisionIconName>('folder');

  // Add Catalog Module form
  const [selectedCatalogKey, setSelectedCatalogKey] = useState('');

  // Add External Sub-web form
  const [showAddExt, setShowAddExt] = useState(false);
  const [extTitle, setExtTitle] = useState('');
  const [extKey, setExtKey] = useState('');
  const [extDesc, setExtDesc] = useState('');
  const [extUrl, setExtUrl] = useState('');
  const [extOpenMode, setExtOpenMode] = useState<'new_tab' | 'same_tab'>('new_tab');

  // Staff Division Mapping state (Tab 2)
  const [staffList, setStaffList] = useState<SchoolStaffMember[]>([]);
  const [permState, setPermState] = useState<RoleDivisionModulePermissions>({
    divisionByRole: {},
    moduleByRole: {},
    userTabOverride: {},
    divisionByUser: {},
    moduleByUser: {},
  });
  const [loadingStaff, setLoadingStaff] = useState(false);
  const [savingUserKey, setSavingUserKey] = useState<string | null>(null);
  const [staffSearch, setStaffSearch] = useState('');
  const [staffFilter, setStaffFilter] = useState<'all' | 'assigned' | 'unassigned'>('all');

  useEffect(() => {
    if (divisions.length === 0) {
      setSelectedDivId(null);
      return;
    }
    if (!selectedDivId || !divisions.some((d) => d.id === selectedDivId)) {
      setSelectedDivId(divisions[0].id);
    }
  }, [divisions, selectedDivId]);

  const activeDivision =
    divisions.find((d) => d.id === selectedDivId) ?? divisions[0] ?? null;

  const allDivisionKeys = useMemo(
    () => divisions.map((d) => d.division_key),
    [divisions],
  );
  const allModuleKeys = useMemo(() => {
    const s = new Set<string>();
    for (const d of divisions) {
      for (const m of d.modules) s.add(m.module_key);
    }
    return [...s];
  }, [divisions]);

  const loadStaffMappingData = useCallback(async () => {
    if (!schoolId) return;
    setLoadingStaff(true);
    try {
      const [staff, perms] = await Promise.all([
        fetchSchoolStaffMembers(schoolId),
        fetchRoleDivisionModulePermissions(
          schoolId,
          allDivisionKeys.length > 0
            ? allDivisionKeys
            : ['hr', 'academic', 'admin', 'finance'],
          allModuleKeys.length > 0 ? allModuleKeys : undefined,
        ),
      ]);
      setStaffList(staff);
      setPermState(perms);
    } finally {
      setLoadingStaff(false);
    }
  }, [schoolId, allDivisionKeys, allModuleKeys]);

  useEffect(() => {
    loadStaffMappingData();
  }, [loadStaffMappingData]);

  async function handleChangeStaffDivisionRole(
    staff: SchoolStaffMember,
    divisionKey: string,
    nextRole: DivisionMemberRole,
  ) {
    if (!schoolId || !canEdit) return;
    const key = `${staff.id_user}:${divisionKey}`;
    setSavingUserKey(key);
    setError(null);
    setMessage(null);

    const { error: saveErr } = await saveStaffDivisionMembership({
      schoolId,
      idUser: staff.id_user,
      divisionKey,
      memberRole: nextRole,
    });

    setSavingUserKey(null);
    if (saveErr) {
      setError(`บันทึกสังกัดฝ่ายไม่สำเร็จ: ${saveErr}`);
      return;
    }

    setPermState((prev) => {
      const nextDivByUser = { ...prev.divisionByUser };
      if (nextRole === 'none') {
        delete nextDivByUser[key];
      } else {
        nextDivByUser[key] = {
          can_view: true,
          can_edit: nextRole === 'editor',
        };
      }
      return {
        ...prev,
        divisionByUser: nextDivByUser,
      };
    });

    const roleLabel =
      nextRole === 'editor'
        ? 'เจ้าหน้าที่ประจำฝ่าย (แก้ไขข้อมูลได้)'
        : nextRole === 'member'
          ? 'สมาชิกในฝ่าย (ดูและใช้งานระบบงานในฝ่าย)'
          : 'นำออกจากฝ่าย';
    setMessage(`อัปเดตสังกัดของ "${staff.fullName}" เป็น "${roleLabel}" เรียบร้อยแล้ว`);
    await onReload();
  }

  async function handleSeedDefaultMapping() {
    if (!schoolId || !canEdit) return;
    setBusy(true);
    setError(null);
    setMessage(null);

    const { error: rpcErr } = await supabase.rpc('seed_school_web_divisions', {
      target_school_id: schoolId,
    });

    if (rpcErr) {
      setError(rpcErr.message);
    } else {
      setMessage('สร้างโครงสร้างฝ่ายและระบบงานมาตรฐานให้โรงเรียนเรียบร้อยแล้ว');
      await onReload();
    }
    setBusy(false);
  }

  async function toggleDivision(div: DivisionWithModules) {
    if (!canEdit || div.id < 0) return;
    setBusy(true);
    setError(null);
    const { error: updErr } = await supabase
      .from('SchoolWebDivisions')
      .update({ is_enabled: !div.is_enabled })
      .eq('id', div.id);

    if (updErr) setError(updErr.message);
    else await onReload();
    setBusy(false);
  }

  async function removeDivision(div: DivisionWithModules) {
    if (!canEdit || div.id < 0) return;
    setBusy(true);
    setError(null);
    const { error: delErr } = await supabase
      .from('SchoolWebDivisions')
      .delete()
      .eq('id', div.id);

    if (delErr) setError(delErr.message);
    else await onReload();
    setBusy(false);
  }

  async function handleAddDivision(e: FormEvent) {
    e.preventDefault();
    if (!schoolId || !canEdit) return;
    setBusy(true);
    setError(null);

    const cleanKey =
      divKey.trim().toLowerCase().replace(/\s+/g, '-') ||
      `div-${Date.now().toString(36)}`;

    const { data: newDiv, error: insErr } = await supabase
      .from('SchoolWebDivisions')
      .insert({
        id_school: schoolId,
        division_key: cleanKey,
        name: divName.trim(),
        description: divDesc.trim() || null,
        icon_name: divIcon,
        sort_order: divisions.length + 1,
        is_enabled: true,
      })
      .select('id')
      .single();

    if (insErr) {
      setError(insErr.message);
    } else {
      if (newDiv?.id) {
        await supabase.from('SchoolWebDivisionModules').insert({
          id_school: schoolId,
          division_id: newDiv.id,
          module_key: 'appointment-orders',
          sort_order: 10,
          is_enabled: true,
        });
      }
      setDivKey('');
      setDivName('');
      setDivDesc('');
      setShowAddDiv(false);
      await onReload();
    }
    setBusy(false);
  }

  async function handleAssignCatalogModule(e: FormEvent) {
    e.preventDefault();
    if (
      !schoolId ||
      !canEdit ||
      !activeDivision ||
      activeDivision.id < 0 ||
      !selectedCatalogKey
    ) {
      return;
    }
    setBusy(true);
    setError(null);

    const catItem = catalog.find((c) => c.module_key === selectedCatalogKey);
    const { error: insErr } = await supabase
      .from('SchoolWebDivisionModules')
      .upsert(
        {
          id_school: schoolId,
          division_id: activeDivision.id,
          module_key: selectedCatalogKey,
          external_url: catItem?.default_url || null,
          sort_order: activeDivision.modules.length + 1,
          is_enabled: true,
        },
        { onConflict: 'division_id,module_key' },
      );

    if (insErr) {
      setError(insErr.message);
    } else {
      setSelectedCatalogKey('');
      await onReload();
    }
    setBusy(false);
  }

  async function handleAddExternalModule(e: FormEvent) {
    e.preventDefault();
    if (!schoolId || !canEdit || !activeDivision || activeDivision.id < 0) return;
    setBusy(true);
    setError(null);

    const cleanKey =
      extKey.trim().toLowerCase().replace(/\s+/g, '-') ||
      `ext-${Date.now().toString(36)}`;

    const { error: insErr } = await supabase
      .from('SchoolWebDivisionModules')
      .insert({
        id_school: schoolId,
        division_id: activeDivision.id,
        module_key: cleanKey,
        custom_title: extTitle.trim(),
        custom_description: extDesc.trim() || null,
        external_url: extUrl.trim(),
        open_mode: extOpenMode,
        sort_order: activeDivision.modules.length + 1,
        is_enabled: true,
      });

    if (insErr) {
      setError(insErr.message);
    } else {
      setExtTitle('');
      setExtKey('');
      setExtDesc('');
      setExtUrl('');
      setShowAddExt(false);
      await onReload();
    }
    setBusy(false);
  }

  async function toggleModule(mod: ResolvedDivisionModule) {
    if (!canEdit || mod.id < 0) return;
    setBusy(true);
    setError(null);
    const { error: updErr } = await supabase
      .from('SchoolWebDivisionModules')
      .update({ is_enabled: !mod.is_enabled })
      .eq('id', mod.id);

    if (updErr) setError(updErr.message);
    else await onReload();
    setBusy(false);
  }

  async function updateModuleUrl(mod: ResolvedDivisionModule, nextUrl: string) {
    if (!canEdit || mod.id < 0) return;
    setBusy(true);
    setError(null);
    const { error: updErr } = await supabase
      .from('SchoolWebDivisionModules')
      .update({ external_url: nextUrl.trim() || null })
      .eq('id', mod.id);

    if (updErr) setError(updErr.message);
    else {
      setMessage(`อัปเดตลิงก์ของ "${mod.title}" เรียบร้อยแล้ว`);
      await onReload();
    }
    setBusy(false);
  }

  async function removeModule(mod: ResolvedDivisionModule) {
    if (!canEdit || mod.id < 0) return;
    setBusy(true);
    setError(null);
    const { error: delErr } = await supabase
      .from('SchoolWebDivisionModules')
      .delete()
      .eq('id', mod.id);

    if (delErr) setError(delErr.message);
    else await onReload();
    setBusy(false);
  }

  const assignedKeys = new Set(
    activeDivision?.modules.map((m) => m.module_key) ?? [],
  );
  const unassignedCatalog = catalog.filter(
    (c) => !assignedKeys.has(c.module_key),
  );

  const divisionNameByKey = useMemo(() => {
    const map = new Map<string, string>();
    for (const d of divisions) map.set(d.division_key, d.name);
    return map;
  }, [divisions]);

  const filteredStaff = useMemo(() => {
    if (!activeDivision) return [];
    const q = staffSearch.trim().toLowerCase();
    return staffList.filter((s) => {
      if (q) {
        const hit =
          s.fullName.toLowerCase().includes(q) ||
          s.username.toLowerCase().includes(q) ||
          s.roleName.toLowerCase().includes(q);
        if (!hit) return false;
      }
      const memberRole = getStaffDivisionMemberRole(
        permState,
        s.id_user,
        activeDivision.division_key,
      );
      if (staffFilter === 'assigned' && memberRole === 'none') return false;
      if (staffFilter === 'unassigned' && memberRole !== 'none') return false;
      return true;
    });
  }, [staffList, staffSearch, staffFilter, permState, activeDivision]);

  // ครูผู้สอน = ระดับผู้ใช้งานที่ยังไม่สังกัดฝ่ายใด (เห็นเฉพาะ "งานของฉัน")
  const teachingOnlyStaff = useMemo(
    () =>
      staffList.filter(
        (s) =>
          inferRoleTierFromRoleName(s.roleName, s.is_super_admin, s.id_role, permState) ===
            'user' &&
          getStaffAssignedDivisionKeys(permState, s.id_user, allDivisionKeys).length === 0,
      ),
    [staffList, permState, allDivisionKeys],
  );

  return (
    <div className="space-y-6">
      {teachingOnlyStaff.length > 0 && (
        <div className="rounded-xl border border-line bg-canvas px-4 py-3 text-xs leading-relaxed text-slate-600">
          <span className="font-semibold text-ink">
            ครูผู้สอน {teachingOnlyStaff.length} คน
          </span>{' '}
          ยังไม่สังกัดฝ่ายใด จึงเห็นเฉพาะ &ldquo;งานของฉัน&rdquo; ไม่เห็นงานของฝ่าย ·
          ถ้าคนไหนทำงานบริหารด้วย ให้ผูกสังกัดฝ่ายด้านล่าง
        </div>
      )}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="text-xs font-medium text-brand-600">
            ตั้งค่าโรงเรียน · โครงสร้างฝ่ายและการจัดสังกัดบุคลากร
          </p>
          <h1 className="mt-1 text-2xl font-semibold tracking-tight text-ink">
            ฝ่าย, ระบบงานในฝ่าย และสังกัดบุคลากร
          </h1>
          <p className="mt-1 text-sm text-slate-600">
            กำหนดโครงสร้างฝ่ายและระบบงานของ{' '}
            <span className="font-medium text-ink">
              {school?.fullName || `โรงเรียน #${schoolId ?? '-'}`}
            </span>{' '}
            พร้อมระบุว่าบุคลากรแต่ละคนสังกัดอยู่ฝ่ายใด (อยู่ฝ่ายไหนจะมองเห็นระบบงานของฝ่ายนั้นอัตโนมัติ)
          </p>
        </div>

        {canEdit && !hasDbMapping && activeTab === 'modules' && (
          <button
            type="button"
            disabled={busy}
            onClick={handleSeedDefaultMapping}
            className="btn-primary shrink-0"
          >
            <RefreshCw className="h-4 w-4" strokeWidth={1.5} />
            <span>บันทึกโครงสร้างมาตรฐานลงฐานข้อมูล</span>
          </button>
        )}
      </div>

      {/* แถบสลับหมวด: [ 1. โครงสร้างฝ่าย & ระบบงาน | 2. จัดสังกัดบุคลากรเข้าฝ่าย ] */}
      <div className="flex flex-wrap gap-2 border-b border-line pb-3">
        <button
          type="button"
          onClick={() => setActiveTab('modules')}
          className={`inline-flex items-center gap-2 rounded-xl px-4 py-2.5 text-xs font-semibold transition-colors ${
            activeTab === 'modules'
              ? 'bg-brand-600 text-white shadow-sm'
              : 'border border-line bg-white text-slate-600 hover:bg-slate-50'
          }`}
        >
          <Layers className="h-4 w-4" strokeWidth={1.75} />
          <span>1. จัดการฝ่ายและระบบงานในฝ่าย</span>
        </button>
        <button
          type="button"
          onClick={() => setActiveTab('staff')}
          className={`inline-flex items-center gap-2 rounded-xl px-4 py-2.5 text-xs font-semibold transition-colors ${
            activeTab === 'staff'
              ? 'bg-brand-600 text-white shadow-sm'
              : 'border border-line bg-white text-slate-600 hover:bg-slate-50'
          }`}
        >
          <Users className="h-4 w-4" strokeWidth={1.75} />
          <span>
            2. จัดสังกัดบุคลากรเข้าฝ่าย ({staffList.length} คน)
          </span>
        </button>
      </div>

      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}
      {message && (
        <div className="rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">
          {message}
        </div>
      )}

      {activeTab === 'modules' ? (
        /* TAB 1: Asymmetric 5 + 7 Mapping Grid (ฝ่าย <-> Module) */
        <div className="grid gap-6 lg:grid-cols-12">
          {/* Left 5 cols: School Divisions */}
          <section className="surface-card p-6 lg:col-span-5">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-base font-semibold text-ink">
                  1. ฝ่ายของโรงเรียน ({divisions.length})
                </h2>
                <p className="mt-0.5 text-xs text-slate-500">
                  ฝ่ายที่เปิดใช้งานจะแสดงเป็นเมนูหลักใน Sidebar ของโรงเรียน
                </p>
              </div>
              {canEdit && hasDbMapping && (
                <button
                  type="button"
                  onClick={() => setShowAddDiv((p) => !p)}
                  className="text-xs font-medium text-brand-600 hover:text-brand-700"
                >
                  {showAddDiv ? 'ยกเลิก' : '+ เพิ่มฝ่าย'}
                </button>
              )}
            </div>

            {canEdit && showAddDiv && (
              <form
                onSubmit={handleAddDivision}
                className="mt-4 space-y-3 rounded-xl border border-line bg-canvas/70 p-4"
              >
                <div>
                  <label className="mb-1 block text-xs font-medium text-ink">
                    ชื่อฝ่าย
                  </label>
                  <input
                    type="text"
                    required
                    value={divName}
                    onChange={(e) => setDivName(e.target.value)}
                    placeholder="เช่น ฝ่ายกิจการนักเรียน"
                    className="input"
                  />
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="mb-1 block text-xs font-medium text-ink">
                      รหัสฝ่าย (ภาษาอังกฤษ)
                    </label>
                    <input
                      type="text"
                      value={divKey}
                      onChange={(e) => setDivKey(e.target.value)}
                      placeholder="เช่น student-affairs"
                      className="input"
                    />
                  </div>
                  <div>
                    <label className="mb-1 block text-xs font-medium text-ink">
                      ไอคอน
                    </label>
                    <select
                      value={divIcon}
                      onChange={(e) => setDivIcon(e.target.value as DivisionIconName)}
                      className="input"
                    >
                      {ICON_OPTIONS.map((opt) => (
                        <option key={opt.value} value={opt.value}>
                          {opt.label}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>
                <div>
                  <label className="mb-1 block text-xs font-medium text-ink">
                    คำอธิบายสั้น
                  </label>
                  <input
                    type="text"
                    value={divDesc}
                    onChange={(e) => setDivDesc(e.target.value)}
                    placeholder="หน้าที่ของฝ่าย"
                    className="input"
                  />
                </div>
                <div className="flex justify-end">
                  <button type="submit" disabled={busy} className="btn-primary btn-sm">
                    <Plus className="h-3.5 w-3.5" strokeWidth={1.5} />
                    <span>สร้างฝ่าย</span>
                  </button>
                </div>
              </form>
            )}

            <div className="mt-4 space-y-2">
              {divisions.map((div) => {
                const isSelected = activeDivision?.id === div.id;
                const enabledModCount = div.modules.filter((m) => m.is_enabled).length;
                return (
                  <div
                    key={div.id}
                    onClick={() => setSelectedDivId(div.id)}
                    className={`cursor-pointer rounded-xl border p-3.5 transition-colors ${
                      isSelected
                        ? 'border-brand-500 bg-brand-50/40'
                        : 'border-line bg-white hover:bg-slate-50/80'
                    }`}
                  >
                    <div className="flex items-start justify-between gap-2">
                      <div className="min-w-0">
                        <div className="flex items-center gap-2">
                          <p className="text-sm font-medium text-ink">{div.name}</p>
                          {!div.is_enabled && (
                            <span className="rounded bg-slate-100 px-1.5 py-0.5 text-[11px] text-slate-500">
                              ปิดอยู่
                            </span>
                          )}
                        </div>
                        {div.description && (
                          <p className="mt-0.5 text-xs text-slate-500">
                            {div.description}
                          </p>
                        )}
                        <p className="mt-1.5 tabular-nums text-[11px] text-slate-400">
                          เปิดใช้งาน {enabledModCount} จาก {div.modules.length} ระบบงาน
                        </p>
                      </div>

                      {canEdit && div.id > 0 && (
                        <div
                          className="flex shrink-0 items-center gap-1"
                          onClick={(e) => e.stopPropagation()}
                        >
                          <button
                            type="button"
                            disabled={busy}
                            onClick={() => toggleDivision(div)}
                            title={
                              div.is_enabled
                                ? 'ปิดฝ่ายนี้ (ซ่อนจากโรงเรียนนี้)'
                                : 'เปิดใช้งานฝ่ายนี้'
                            }
                            className={`rounded-lg border p-1.5 transition-colors ${
                              div.is_enabled
                                ? 'border-emerald-200 bg-emerald-50 text-emerald-700'
                                : 'border-line bg-white text-slate-400 hover:text-slate-700'
                            }`}
                          >
                            <Power className="h-3.5 w-3.5" strokeWidth={1.5} />
                          </button>
                          <button
                            type="button"
                            disabled={busy}
                            onClick={() => removeDivision(div)}
                            title="ลบฝ่ายนี้"
                            className="rounded-lg border border-line bg-white p-1.5 text-slate-400 hover:border-red-200 hover:bg-red-50 hover:text-red-600"
                          >
                            <Trash2 className="h-3.5 w-3.5" strokeWidth={1.5} />
                          </button>
                        </div>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </section>

          {/* Right 7 cols: Modules mapped to selected Division */}
          <section className="surface-card p-6 lg:col-span-7">
            {!activeDivision ? (
              <p className="text-sm text-slate-500">เลือกฝ่ายทางซ้ายเพื่อดูระบบงานในฝ่าย</p>
            ) : (
              <div className="space-y-5">
                <div className="flex flex-col gap-3 border-b border-line pb-4 sm:flex-row sm:items-center sm:justify-between">
                  <div>
                    <div className="flex items-center gap-2">
                      <Layers className="h-[18px] w-[18px] text-brand-600" strokeWidth={1.5} />
                      <h2 className="text-base font-semibold text-ink">
                        2. ระบบงานใน &ldquo;{activeDivision.name}&rdquo;
                      </h2>
                    </div>
                    <p className="mt-0.5 text-xs text-slate-500">
                      กำหนดว่าฝ่ายนี้มีระบบงานอะไรบ้าง บุคลากรที่สังกัดฝ่ายนี้จะมองเห็นและใช้งานได้โดยอัตโนมัติ
                    </p>
                  </div>

                  {canEdit && activeDivision.id > 0 && (
                    <button
                      type="button"
                      onClick={() => setShowAddExt((p) => !p)}
                      className="btn-secondary btn-sm shrink-0"
                    >
                      <Plus className="h-3.5 w-3.5" strokeWidth={1.5} />
                      <span>{showAddExt ? 'ปิดฟอร์ม' : 'เพิ่มลิงก์ระบบงานในฝ่ายนี้'}</span>
                    </button>
                  )}
                </div>

                {/* Add from Standard Catalog */}
                {canEdit && activeDivision.id > 0 && unassignedCatalog.length > 0 && (
                  <form
                    onSubmit={handleAssignCatalogModule}
                    className="flex flex-wrap items-center gap-2 rounded-xl border border-line bg-canvas/60 p-3"
                  >
                    <select
                      value={selectedCatalogKey}
                      onChange={(e) => setSelectedCatalogKey(e.target.value)}
                      className="input flex-1 py-1.5 text-xs"
                    >
                      <option value="">
                        + เลือกระบบงานมาตรฐานมาใส่ในฝ่ายนี้...
                      </option>
                      {unassignedCatalog.map((c) => (
                        <option key={c.module_key} value={c.module_key}>
                          {c.title}
                        </option>
                      ))}
                    </select>
                    <button
                      type="submit"
                      disabled={!selectedCatalogKey || busy}
                      className="btn-primary btn-sm"
                    >
                      <Check className="h-3.5 w-3.5" strokeWidth={1.5} />
                      <span>เพิ่มเข้าฝ่ายนี้</span>
                    </button>
                  </form>
                )}

                {/* Add Custom External Sub-web */}
                {canEdit && showAddExt && activeDivision.id > 0 && (
                  <form
                    onSubmit={handleAddExternalModule}
                    className="grid gap-3 rounded-xl border border-line bg-canvas/70 p-4 sm:grid-cols-2"
                  >
                    <div>
                      <label className="mb-1 block text-xs font-medium text-ink">
                        ชื่อระบบงาน
                      </label>
                      <input
                        type="text"
                        required
                        value={extTitle}
                        onChange={(e) => setExtTitle(e.target.value)}
                        placeholder="เช่น ระบบการเงินโรงเรียน"
                        className="input"
                      />
                    </div>
                    <div>
                      <label className="mb-1 block text-xs font-medium text-ink">
                        รหัสอ้างอิง (ไม่บังคับ)
                      </label>
                      <input
                        type="text"
                        value={extKey}
                        onChange={(e) => setExtKey(e.target.value)}
                        placeholder="เช่น finance-system"
                        className="input"
                      />
                    </div>
                    <div className="sm:col-span-2">
                      <label className="mb-1 block text-xs font-medium text-ink">
                        ลิงก์ระบบงาน (URL)
                      </label>
                      <input
                        type="url"
                        required
                        value={extUrl}
                        onChange={(e) => setExtUrl(e.target.value)}
                        placeholder="https://..."
                        className="input"
                      />
                    </div>
                    <div>
                      <label className="mb-1 block text-xs font-medium text-ink">
                        คำอธิบายสั้น
                      </label>
                      <input
                        type="text"
                        value={extDesc}
                        onChange={(e) => setExtDesc(e.target.value)}
                        placeholder="รายละเอียดสั้น ๆ"
                        className="input"
                      />
                    </div>
                    <div>
                      <label className="mb-1 block text-xs font-medium text-ink">
                        การเปิดลิงก์
                      </label>
                      <select
                        value={extOpenMode}
                        onChange={(e) =>
                          setExtOpenMode(e.target.value as 'new_tab' | 'same_tab')
                        }
                        className="input"
                      >
                        <option value="new_tab">เปิดหน้าต่างใหม่</option>
                        <option value="same_tab">เปิดหน้าต่างเดิม</option>
                      </select>
                    </div>
                    <div className="flex justify-end sm:col-span-2">
                      <button type="submit" disabled={busy} className="btn-primary btn-sm">
                        <Plus className="h-3.5 w-3.5" strokeWidth={1.5} />
                        <span>บันทึกระบบงานในฝ่ายนี้</span>
                      </button>
                    </div>
                  </form>
                )}

                {/* Mapped Modules List */}
                {activeDivision.modules.length === 0 ? (
                  <p className="py-8 text-center text-sm text-slate-500">
                    ยังไม่มีระบบงานในฝ่ายนี้
                  </p>
                ) : (
                  <div className="divide-y divide-line rounded-xl border border-line">
                    {activeDivision.modules.map((mod) => (
                      <ModuleRowItem
                        key={mod.id}
                        mod={mod}
                        canEdit={canEdit && mod.id > 0}
                        busy={busy}
                        onToggle={() => toggleModule(mod)}
                        onSaveUrl={(url) => updateModuleUrl(mod, url)}
                        onRemove={() => removeModule(mod)}
                      />
                    ))}
                  </div>
                )}
              </div>
            )}
          </section>
        </div>
      ) : (
        /* หมวดที่ 2: จัดสังกัดบุคลากรเข้าฝ่าย (บุคลากร <-> ฝ่าย) */
        <div className="space-y-5">
          {/* คำอธิบายหลักการทำงานของสังกัดฝ่าย */}
          <div className="rounded-2xl border border-brand-200 bg-brand-50/40 p-4">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <h2 className="text-sm font-semibold text-ink">
                  หลักการทำงาน: บุคลากรสังกัดฝ่ายไหน → มองเห็นระบบงานตามฝ่ายนั้นอัตโนมัติ
                </h2>
                <p className="mt-1 text-xs text-slate-600">
                  1) <strong>ผู้ใช้งาน (ครู/บุคลากร)</strong>: เมื่อถูกผูกเข้ากับฝ่ายใด จะมองเห็นเฉพาะฝ่ายของตัวเองและใช้งานระบบงานทั้งหมดที่อยู่ในฝ่ายนั้นโดยอัตโนมัติ (สามารถสังกัดได้มากกว่า 1 ฝ่าย)
                  <br />
                  2) <strong>ผู้บริหาร / แอดมินโรงเรียน / ผู้ดูแลส่วนกลาง</strong>: มองเห็นครบทุกฝ่ายของโรงเรียนโดยอัตโนมัติ
                </p>
              </div>
            </div>
          </div>

          <div className="grid gap-6 lg:grid-cols-12">
            {/* ซ้าย 5 คอลัมน์: รายชื่อฝ่าย + จำนวนบุคลากรในฝ่าย */}
            <section className="surface-card p-6 lg:col-span-5">
              <h2 className="text-base font-semibold text-ink">
                เลือกฝ่ายที่ต้องการจัดบุคลากร ({divisions.length})
              </h2>
              <p className="mt-0.5 text-xs text-slate-500">
                คลิกเลือกฝ่ายเพื่อกำหนดว่าบุคลากรคนใดสังกัดอยู่ในฝ่ายนี้บ้าง
              </p>

              <div className="mt-4 space-y-2.5">
                {divisions.map((div) => {
                  const isSelected = activeDivision?.id === div.id;
                  const membersCount = staffList.filter(
                    (s) =>
                      getStaffDivisionMemberRole(
                        permState,
                        s.id_user,
                        div.division_key,
                      ) !== 'none',
                  ).length;
                  const editorsCount = staffList.filter(
                    (s) =>
                      getStaffDivisionMemberRole(
                        permState,
                        s.id_user,
                        div.division_key,
                      ) === 'editor',
                  ).length;

                  return (
                    <button
                      key={div.id}
                      type="button"
                      onClick={() => setSelectedDivId(div.id)}
                      className={`w-full rounded-xl border p-4 text-left transition-colors ${
                        isSelected
                          ? 'border-brand-600 bg-brand-50/50'
                          : 'border-line bg-white hover:bg-slate-50'
                      }`}
                    >
                      <div className="flex items-start justify-between gap-2">
                        <div>
                          <p className="text-sm font-semibold text-ink">
                            {div.name}
                          </p>
                          <p className="mt-0.5 text-xs text-slate-500">
                            ระบบงานในฝ่าย:{' '}
                            {div.modules
                              .filter((m) => m.is_enabled)
                              .map((m) => m.title)
                              .join(', ') || 'ยังไม่มีระบบงาน'}
                          </p>
                        </div>
                        <span className="shrink-0 rounded-full bg-brand-100 px-2.5 py-0.5 text-xs font-semibold text-brand-700">
                          {membersCount} คน
                        </span>
                      </div>

                      {editorsCount > 0 && (
                        <p className="mt-2 text-[11px] font-medium text-emerald-700">
                          เจ้าหน้าที่แก้ไขข้อมูลประจำฝ่าย {editorsCount} คน
                        </p>
                      )}
                    </button>
                  );
                })}
              </div>
            </section>

            {/* ขวา 7 คอลัมน์: รายชื่อบุคลากรและการกำหนดสังกัดเข้าฝ่ายที่เลือก */}
            <section className="surface-card p-6 lg:col-span-7">
              {!activeDivision ? (
                <p className="text-sm text-slate-500">เลือกฝ่ายทางซ้ายก่อน</p>
              ) : (
                <div className="space-y-4">
                  <div className="border-b border-line pb-4">
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <div>
                        <h2 className="text-base font-semibold text-ink">
                          จัดบุคลากรเข้า &ldquo;{activeDivision.name}&rdquo;
                        </h2>
                        <p className="mt-0.5 text-xs text-slate-500">
                          บุคลากรที่อยู่ในฝ่ายนี้จะใช้งานระบบงาน:{' '}
                          <span className="font-medium text-ink">
                            {activeDivision.modules
                              .filter((m) => m.is_enabled)
                              .map((m) => m.title)
                              .join(' · ') || '-'}
                          </span>
                        </p>
                      </div>
                    </div>

                    {/* ค้นหาและตัวกรองบุคลากร */}
                    <div className="mt-4 flex flex-wrap items-center gap-2">
                      <div className="relative flex-1 min-w-[200px]">
                        <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
                        <input
                          type="text"
                          value={staffSearch}
                          onChange={(e) => setStaffSearch(e.target.value)}
                          placeholder="ค้นหาชื่อบุคลากร, ชื่อผู้ใช้ หรือตำแหน่ง..."
                          className="input pl-9 py-1.5 text-xs"
                        />
                      </div>

                      <div className="inline-flex rounded-lg border border-line bg-canvas p-0.5">
                        {(
                          [
                            { id: 'all', label: 'ทั้งหมด' },
                            { id: 'assigned', label: 'อยู่ฝ่ายนี้แล้ว' },
                            { id: 'unassigned', label: 'ยังไม่อยู่ฝ่ายนี้' },
                          ] as const
                        ).map((f) => (
                          <button
                            key={f.id}
                            type="button"
                            onClick={() => setStaffFilter(f.id)}
                            className={`rounded-md px-2.5 py-1 text-xs font-medium transition-colors ${
                              staffFilter === f.id
                                ? 'bg-white text-ink shadow-sm'
                                : 'text-slate-500 hover:text-ink'
                            }`}
                          >
                            {f.label}
                          </button>
                        ))}
                      </div>
                    </div>
                  </div>

                  {loadingStaff ? (
                    <p className="py-8 text-center text-sm text-slate-500">
                      กำลังโหลดรายชื่อบุคลากร...
                    </p>
                  ) : filteredStaff.length === 0 ? (
                    <p className="py-8 text-center text-sm text-slate-500">
                      ไม่พบบุคลากรตามเงื่อนไขที่ค้นหา
                    </p>
                  ) : (
                    <div className="divide-y divide-line rounded-xl border border-line">
                      {filteredStaff.map((staff) => {
                        const tier = inferRoleTierFromRoleName(
                          staff.roleName,
                          staff.is_super_admin,
                          staff.id_role,
                          permState,
                        );
                        const tierMeta = ROLE_TIER_META[tier];
                        const memberRole = getStaffDivisionMemberRole(
                          permState,
                          staff.id_user,
                          activeDivision.division_key,
                        );
                        const assignedDivKeys = getStaffAssignedDivisionKeys(
                          permState,
                          staff.id_user,
                          allDivisionKeys,
                        );
                        const isSaving =
                          savingUserKey ===
                          `${staff.id_user}:${activeDivision.division_key}`;
                        const isAutoFullAdmin =
                          tier === 'super_admin' || tier === 'school_admin';

                        return (
                          <div
                            key={staff.id_user}
                            className={`flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between ${
                              memberRole !== 'none' ? 'bg-brand-50/20' : 'bg-white'
                            }`}
                          >
                            <div className="min-w-0 space-y-1">
                              <div className="flex flex-wrap items-center gap-2">
                                <span className="text-sm font-semibold text-ink">
                                  {staff.fullName}
                                </span>
                                <span
                                  className={`rounded-full px-2 py-0.5 text-[10px] font-semibold ${tierMeta.badgeClass}`}
                                >
                                  {tierMeta.shortLabel}
                                </span>
                                <span className="text-xs text-slate-400">
                                  ({staff.roleName})
                                </span>
                              </div>

                              {/* แสดงฝ่ายที่บุคลากรคนนี้สังกัดอยู่ทั้งหมด */}
                              {isAutoFullAdmin ? (
                                <p className="text-xs text-emerald-700">
                                  ระดับ {tierMeta.shortLabel}: มองเห็นและแก้ไขได้ทุกฝ่ายโดยอัตโนมัติ
                                </p>
                              ) : tier === 'executive' ? (
                                <p className="text-xs text-amber-700">
                                  ระดับผู้บริหาร: มองเห็นทุกฝ่ายโดยอัตโนมัติ (สามารถตั้งเป็นเจ้าหน้าที่ฝ่ายเพื่อแก้ไขข้อมูลได้)
                                </p>
                              ) : assignedDivKeys.length > 0 ? (
                                <div className="flex flex-wrap items-center gap-1 pt-0.5">
                                  <span className="text-[11px] text-slate-500">
                                    สังกัดปัจจุบัน:
                                  </span>
                                  {assignedDivKeys.map((dk) => (
                                    <span
                                      key={dk}
                                      className="rounded-md bg-brand-50 px-2 py-0.5 text-[11px] font-medium text-brand-700 ring-1 ring-inset ring-brand-200"
                                    >
                                      {divisionNameByKey.get(dk) || dk}
                                    </span>
                                  ))}
                                </div>
                              ) : (
                                <p className="flex flex-wrap items-center gap-1.5 text-xs text-slate-500">
                                  <span className="rounded-full bg-slate-100 px-2 py-0.5 text-[10px] font-semibold text-slate-700">
                                    ครูผู้สอน
                                  </span>
                                  ยังไม่สังกัดฝ่าย — ใช้งานได้เฉพาะ &ldquo;งานของฉัน&rdquo;
                                </p>
                              )}
                            </div>

                            {/* ปุ่มเลือกสังกัดในฝ่ายนี้ */}
                            {!isAutoFullAdmin && (
                              <div className="inline-flex flex-wrap shrink-0 items-center gap-1.5">
                                <button
                                  type="button"
                                  disabled={!canEdit || isSaving}
                                  onClick={() =>
                                    handleChangeStaffDivisionRole(
                                      staff,
                                      activeDivision.division_key,
                                      'none',
                                    )
                                  }
                                  className={`rounded-lg border px-2.5 py-1.5 text-xs font-medium transition-colors ${
                                    memberRole === 'none'
                                      ? 'border-slate-700 bg-slate-700 text-white'
                                      : 'border-line bg-white text-slate-600 hover:bg-slate-50'
                                  } disabled:opacity-50`}
                                >
                                  ไม่อยู่ฝ่ายนี้
                                </button>
                                <button
                                  type="button"
                                  disabled={!canEdit || isSaving}
                                  onClick={() =>
                                    handleChangeStaffDivisionRole(
                                      staff,
                                      activeDivision.division_key,
                                      'member',
                                    )
                                  }
                                  className={`inline-flex items-center gap-1 rounded-lg border px-2.5 py-1.5 text-xs font-medium transition-colors ${
                                    memberRole === 'member'
                                      ? 'border-sky-600 bg-sky-600 text-white'
                                      : 'border-line bg-white text-slate-600 hover:bg-slate-50'
                                  } disabled:opacity-50`}
                                >
                                  <UserCheck className="h-3.5 w-3.5" />
                                  <span>สังกัดฝ่ายนี้</span>
                                </button>
                                <button
                                  type="button"
                                  disabled={!canEdit || isSaving}
                                  onClick={() =>
                                    handleChangeStaffDivisionRole(
                                      staff,
                                      activeDivision.division_key,
                                      'editor',
                                    )
                                  }
                                  className={`inline-flex items-center gap-1 rounded-lg border px-2.5 py-1.5 text-xs font-medium transition-colors ${
                                    memberRole === 'editor'
                                      ? 'border-emerald-600 bg-emerald-600 text-white'
                                      : 'border-line bg-white text-slate-600 hover:bg-slate-50'
                                  } disabled:opacity-50`}
                                >
                                  <Pencil className="h-3.5 w-3.5" />
                                  <span>เจ้าหน้าที่ฝ่าย (แก้ไขได้)</span>
                                </button>
                              </div>
                            )}
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>
              )}
            </section>
          </div>
        </div>
      )}
    </div>
  );
}

function ModuleRowItem({
  mod,
  canEdit,
  busy,
  onToggle,
  onSaveUrl,
  onRemove,
}: {
  mod: ResolvedDivisionModule;
  canEdit: boolean;
  busy: boolean;
  onToggle: () => void;
  onSaveUrl: (url: string) => void;
  onRemove: () => void;
}) {
  const [editingUrl, setEditingUrl] = useState(false);
  const [urlVal, setUrlVal] = useState(mod.resolved_url || '');

  return (
    <div className="p-4">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div className="min-w-0 space-y-1">
          <div className="flex flex-wrap items-center gap-2">
            <p className="text-sm font-medium text-ink">{mod.title}</p>
            <span className="rounded bg-slate-100 px-2 py-0.5 text-[11px] text-slate-600">
              {mod.module_key}
            </span>
            {!mod.is_enabled && (
              <span className="rounded bg-slate-100 px-2 py-0.5 text-[11px] text-slate-500">
                ปิดใช้งาน
              </span>
            )}
          </div>
          {mod.description && (
            <p className="text-xs text-slate-500">{mod.description}</p>
          )}
          {mod.resolved_url && !editingUrl && (
            <div className="flex items-center gap-2 pt-0.5">
              <a
                href={mod.resolved_url}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-1 truncate text-xs text-brand-600 hover:underline"
              >
                <span>ลิงก์: {mod.resolved_url}</span>
                <ExternalLink className="h-3 w-3 shrink-0" strokeWidth={1.5} />
              </a>
            </div>
          )}
        </div>

        {canEdit && (
          <div className="flex shrink-0 items-center gap-1.5">
            <button
              type="button"
              onClick={() => {
                setUrlVal(mod.resolved_url || '');
                setEditingUrl((p) => !p);
              }}
              className="rounded-lg border border-line px-2.5 py-1 text-xs text-slate-600 hover:bg-slate-50"
            >
              {editingUrl ? 'ยกเลิก' : 'ตั้งค่าลิงก์'}
            </button>
            <button
              type="button"
              disabled={busy}
              onClick={onToggle}
              title={mod.is_enabled ? 'ปิดระบบงานนี้' : 'เปิดระบบงานนี้'}
              className={`rounded-lg border p-1.5 transition-colors ${
                mod.is_enabled
                  ? 'border-emerald-200 bg-emerald-50 text-emerald-700'
                  : 'border-line bg-white text-slate-400'
              }`}
            >
              <Power className="h-3.5 w-3.5" strokeWidth={1.5} />
            </button>
            <button
              type="button"
              disabled={busy}
              onClick={onRemove}
              title="เอาออกจากฝ่ายนี้"
              className="rounded-lg border border-line p-1.5 text-slate-400 hover:border-red-200 hover:bg-red-50 hover:text-red-600"
            >
              <Trash2 className="h-3.5 w-3.5" strokeWidth={1.5} />
            </button>
          </div>
        )}
      </div>

      {editingUrl && canEdit && (
        <div className="mt-3 flex items-center gap-2">
          <input
            type="url"
            value={urlVal}
            onChange={(e) => setUrlVal(e.target.value)}
            placeholder="https://... (เว้นว่างหากไม่มีลิงก์ภายนอก)"
            className="input py-1.5 text-xs"
          />
          <button
            type="button"
            disabled={busy}
            onClick={() => {
              onSaveUrl(urlVal);
              setEditingUrl(false);
            }}
            className="btn-primary btn-sm shrink-0"
          >
            บันทึก
          </button>
        </div>
      )}
    </div>
  );
}
