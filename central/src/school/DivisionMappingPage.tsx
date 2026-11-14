import { useEffect, useState, type FormEvent } from 'react';
import {
  Check,
  ExternalLink,
  Layers,
  Plus,
  Power,
  RefreshCw,
  Trash2,
} from 'lucide-react';
import { supabase } from '../supabase';
import type {
  DivisionIconName,
  DivisionWithModules,
  ModuleCatalogItem,
  ResolvedDivisionModule,
} from './mapping';
import type { SchoolBasic } from './types';

interface DivisionMappingPageProps {
  school: SchoolBasic | null;
  schoolId: number | null;
  canEdit: boolean;
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
      setMessage('สร้างโครงสร้างฝ่ายและ Module มาตรฐานให้โรงเรียนเรียบร้อยแล้ว');
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

    const { error: insErr } = await supabase.from('SchoolWebDivisions').insert({
      id_school: schoolId,
      division_key: cleanKey,
      name: divName.trim(),
      description: divDesc.trim() || null,
      icon_name: divIcon,
      sort_order: divisions.length + 1,
      is_enabled: true,
    });

    if (insErr) {
      setError(insErr.message);
    } else {
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

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="text-xs font-medium text-brand-600">
            ส่วนผู้ดูแลระบบกลาง · โครงสร้างระบบโรงเรียน
          </p>
          <h1 className="mt-1 text-2xl font-semibold tracking-tight text-ink">
            จัดการฝ่ายและ Module รายโรงเรียน
          </h1>
          <p className="mt-1 text-sm text-slate-600">
            กำหนดว่า{' '}
            <span className="font-medium text-ink">
              {school?.fullName || `โรงเรียน #${schoolId ?? '-'}`}
            </span>{' '}
            มีฝ่ายใดบ้าง และแต่ละฝ่ายประกอบด้วย Module หรือ Web ย่อยใด
          </p>
        </div>

        {canEdit && !hasDbMapping && (
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

      {/* Asymmetric 5 + 7 Mapping Grid */}
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
                        เปิดใช้งาน {enabledModCount} จาก {div.modules.length} Module
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
            <p className="text-sm text-slate-500">เลือกฝ่ายทางซ้ายเพื่อดู Module</p>
          ) : (
            <div className="space-y-5">
              <div className="flex flex-col gap-3 border-b border-line pb-4 sm:flex-row sm:items-center sm:justify-between">
                <div>
                  <div className="flex items-center gap-2">
                    <Layers className="h-[18px] w-[18px] text-brand-600" strokeWidth={1.5} />
                    <h2 className="text-base font-semibold text-ink">
                      2. Module ภายใต้ "{activeDivision.name}"
                    </h2>
                  </div>
                  <p className="mt-0.5 text-xs text-slate-500">
                    กำหนดว่าฝ่ายนี้มีระบบย่อยอะไรบ้าง และตั้งค่าลิงก์ Web ย่อยของแต่ละ Module
                  </p>
                </div>

                {canEdit && activeDivision.id > 0 && (
                  <button
                    type="button"
                    onClick={() => setShowAddExt((p) => !p)}
                    className="btn-secondary btn-sm shrink-0"
                  >
                    <Plus className="h-3.5 w-3.5" strokeWidth={1.5} />
                    <span>{showAddExt ? 'ปิดฟอร์ม' : 'เพิ่ม Web ย่อยใหม่ในฝ่ายนี้'}</span>
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
                      + เลือก Module มาตรฐานมาใส่ในฝ่ายนี้...
                    </option>
                    {unassignedCatalog.map((c) => (
                      <option key={c.module_key} value={c.module_key}>
                        {c.title} ({c.module_key})
                      </option>
                    ))}
                  </select>
                  <button
                    type="submit"
                    disabled={!selectedCatalogKey || busy}
                    className="btn-primary btn-sm"
                  >
                    <Check className="h-3.5 w-3.5" strokeWidth={1.5} />
                    <span>ผูกเข้ากับฝ่ายนี้</span>
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
                      ชื่อ Module / Web ย่อย
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
                      รหัส Module (ไม่บังคับ)
                    </label>
                    <input
                      type="text"
                      value={extKey}
                      onChange={(e) => setExtKey(e.target.value)}
                      placeholder="เช่น finance-subweb"
                      className="input"
                    />
                  </div>
                  <div className="sm:col-span-2">
                    <label className="mb-1 block text-xs font-medium text-ink">
                      ลิงก์ Web ย่อย (URL)
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
                      <option value="new_tab">เปิดแท็บใหม่</option>
                      <option value="same_tab">เปิดหน้าต่างเดิม</option>
                    </select>
                  </div>
                  <div className="flex justify-end sm:col-span-2">
                    <button type="submit" disabled={busy} className="btn-primary btn-sm">
                      <Plus className="h-3.5 w-3.5" strokeWidth={1.5} />
                      <span>บันทึก Web ย่อยในฝ่ายนี้</span>
                    </button>
                  </div>
                </form>
              )}

              {/* Mapped Modules List */}
              {activeDivision.modules.length === 0 ? (
                <p className="py-8 text-center text-sm text-slate-500">
                  ยังไม่มี Module ที่ผูกไว้กับฝ่ายนี้
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
                <span>Web ย่อย: {mod.resolved_url}</span>
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
              {editingUrl ? 'ยกเลิก' : 'ตั้งค่าลิงก์ Web ย่อย'}
            </button>
            <button
              type="button"
              disabled={busy}
              onClick={onToggle}
              title={mod.is_enabled ? 'ปิด Module นี้' : 'เปิด Module นี้'}
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
            placeholder="https://... (เว้นว่างหากไม่มี Web ย่อยภายนอก)"
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
