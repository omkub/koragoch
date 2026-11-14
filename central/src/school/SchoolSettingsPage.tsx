import { useState, type FormEvent } from 'react';
import { ExternalLink, Plus, Power, Trash2 } from 'lucide-react';
import { supabase } from '../supabase';
import AcademicSettingsSection from './AcademicSettingsSection';
import { DEFAULT_MODULE_LINKS } from './modules';
import type { SchoolBasic, SchoolModuleLink } from './types';

interface SchoolSettingsPageProps {
  school: SchoolBasic | null;
  schoolId: number | null;
  canEdit: boolean;
  modules: SchoolModuleLink[];
  hasDbRows: boolean;
  onReload: () => Promise<void>;
}

const CATEGORY_LABEL: Record<SchoolModuleLink['category'], string> = {
  hr: 'งานบุคคลและวันลา',
  academic: 'งานวิชาการ',
  admin: 'งานบริหารและตั้งค่า',
  other: 'อื่น ๆ',
};

export default function SchoolSettingsPage({
  school,
  schoolId,
  canEdit,
  modules,
  hasDbRows,
  onReload,
}: SchoolSettingsPageProps) {
  const [title, setTitle] = useState('');
  const [moduleKey, setModuleKey] = useState('');
  const [description, setDescription] = useState('');
  const [url, setUrl] = useState('');
  const [openMode, setOpenMode] = useState<'new_tab' | 'same_tab'>('new_tab');
  const [category, setCategory] = useState<SchoolModuleLink['category']>('hr');
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function seedDefaults() {
    if (!schoolId || !canEdit) return;
    setBusy(true);
    setError(null);
    setMessage(null);

    const rows = DEFAULT_MODULE_LINKS.map((item, idx) => ({
      id_school: schoolId,
      module_key: item.module_key,
      title: item.title,
      description: item.description,
      url: item.url,
      open_mode: item.open_mode,
      category: item.category,
      sort_order: idx + 1,
      is_enabled: item.is_enabled,
    }));

    const { error: upsertErr } = await supabase
      .from('SchoolModules')
      .upsert(rows, { onConflict: 'id_school,module_key' });

    if (upsertErr) {
      setError(`บันทึกค่าเริ่มต้นไม่สำเร็จ: ${upsertErr.message}`);
    } else {
      setMessage('บันทึกลิงก์ระบบวันลามาตรฐานลงฐานข้อมูลแล้ว');
      await onReload();
    }
    setBusy(false);
  }

  async function handleAdd(e: FormEvent) {
    e.preventDefault();
    if (!schoolId || !canEdit) return;
    setBusy(true);
    setError(null);
    setMessage(null);

    const cleanKey = moduleKey.trim() || `mod-${Date.now().toString(36)}`;

    const { error: insertErr } = await supabase.from('SchoolModules').insert({
      id_school: schoolId,
      module_key: cleanKey,
      title: title.trim(),
      description: description.trim() || null,
      url: url.trim(),
      open_mode: openMode,
      category,
      sort_order: modules.length + 1,
      is_enabled: true,
    });

    if (insertErr) {
      setError(`เพิ่มลิงก์ไม่สำเร็จ: ${insertErr.message}`);
    } else {
      setTitle('');
      setModuleKey('');
      setDescription('');
      setUrl('');
      setMessage('เพิ่มลิงก์ระบบย่อยเรียบร้อยแล้ว');
      await onReload();
    }
    setBusy(false);
  }

  async function toggleEnabled(mod: SchoolModuleLink) {
    if (!mod.id || !canEdit) return;
    setBusy(true);
    setError(null);
    const { error: updErr } = await supabase
      .from('SchoolModules')
      .update({ is_enabled: !mod.is_enabled })
      .eq('id', mod.id);

    if (updErr) setError(updErr.message);
    else await onReload();
    setBusy(false);
  }

  async function removeModule(mod: SchoolModuleLink) {
    if (!mod.id || !canEdit) return;
    setBusy(true);
    setError(null);
    const { error: delErr } = await supabase
      .from('SchoolModules')
      .delete()
      .eq('id', mod.id);

    if (delErr) setError(delErr.message);
    else await onReload();
    setBusy(false);
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight text-ink">
          ตั้งค่าโรงเรียน
        </h1>
        <p className="mt-1 text-sm text-slate-600">
          จัดการปีการศึกษา ภาคเรียน และลิงก์ระบบย่อยภายในหมวดหมู่ต่าง ๆ
        </p>
      </div>

      {/* School Info */}
      <section className="surface-card p-6">
        <h2 className="text-base font-semibold text-ink">ข้อมูลโรงเรียน</h2>
        <div className="mt-4 grid gap-4 sm:grid-cols-3">
          <div>
            <p className="text-xs text-slate-500">รหัสโรงเรียน</p>
            <p className="mt-0.5 text-sm font-medium tabular-nums text-ink">
              {schoolId ?? '-'}
            </p>
          </div>
          <div>
            <p className="text-xs text-slate-500">ชื่อโรงเรียน</p>
            <p className="mt-0.5 text-sm font-medium text-ink">
              {school?.fullName || '-'}
            </p>
          </div>
          <div>
            <p className="text-xs text-slate-500">สังกัด</p>
            <p className="mt-0.5 text-sm font-medium text-ink">
              {school?.affiliation || '-'}
            </p>
          </div>
        </div>
      </section>

      <AcademicSettingsSection
        schoolId={schoolId}
        canEdit={canEdit}
        onUpdated={onReload}
      />

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

      {/* Module Links */}
      <section className="surface-card p-6">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h2 className="text-base font-semibold text-ink">
              ลิงก์ระบบย่อย ({modules.length})
            </h2>
            <p className="mt-0.5 text-xs text-slate-500">
              {hasDbRows
                ? 'ดึงข้อมูลจากตาราง SchoolModules (แสดงในหมวดหมู่ของระบบนั้น ๆ)'
                : 'กำลังแสดงลิงก์เริ่มต้น'}
            </p>
          </div>

          {canEdit && !hasDbRows && (
            <button
              type="button"
              disabled={busy}
              onClick={seedDefaults}
              className="btn-secondary shrink-0"
            >
              บันทึกลิงก์ระบบวันลามาตรฐานลงฐานข้อมูล
            </button>
          )}
        </div>

        <div className="mt-5 divide-y divide-line rounded-lg border border-line">
          {modules.map((mod) => (
            <div
              key={mod.id ?? mod.module_key}
              className="flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between"
            >
              <div className="min-w-0 space-y-1">
                <div className="flex flex-wrap items-center gap-2">
                  <p className="text-sm font-medium text-ink">{mod.title}</p>
                  <span className="rounded bg-slate-100 px-2 py-0.5 text-[11px] text-slate-600">
                    {CATEGORY_LABEL[mod.category]}
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
                <p className="truncate text-xs text-slate-400">{mod.url}</p>
              </div>

              <div className="flex shrink-0 items-center gap-2">
                <a
                  href={mod.url}
                  target={mod.open_mode === 'new_tab' ? '_blank' : '_self'}
                  rel={mod.open_mode === 'new_tab' ? 'noreferrer' : undefined}
                  className="btn-secondary btn-sm"
                >
                  <span>เปิดลิงก์</span>
                  <ExternalLink className="h-3.5 w-3.5" strokeWidth={1.5} />
                </a>

                {canEdit && mod.id && (
                  <>
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => toggleEnabled(mod)}
                      title={mod.is_enabled ? 'ปิดใช้งานชั่วคราว' : 'เปิดใช้งาน'}
                      className="rounded-lg border border-line p-1.5 text-slate-600 hover:bg-slate-50"
                    >
                      <Power className="h-4 w-4" strokeWidth={1.5} />
                    </button>
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => removeModule(mod)}
                      title="ลบลิงก์"
                      className="rounded-lg border border-line p-1.5 text-red-600 hover:bg-red-50"
                    >
                      <Trash2 className="h-4 w-4" strokeWidth={1.5} />
                    </button>
                  </>
                )}
              </div>
            </div>
          ))}
        </div>
      </section>

      {canEdit && (
        <section className="surface-card p-6">
          <h2 className="text-base font-semibold text-ink">เพิ่มลิงก์ระบบย่อยใหม่</h2>
          <form onSubmit={handleAdd} className="mt-4 grid gap-4 sm:grid-cols-2">
            <div>
              <label className="mb-1.5 block text-xs font-medium text-ink">
                ชื่อระบบ
              </label>
              <input
                type="text"
                required
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="เช่น ระบบวันลาและไปราชการ"
                className="input"
              />
            </div>

            <div>
              <label className="mb-1.5 block text-xs font-medium text-ink">
                รหัสอ้างอิง (ไม่บังคับ)
              </label>
              <input
                type="text"
                value={moduleKey}
                onChange={(e) => setModuleKey(e.target.value)}
                placeholder="เช่น leave-app"
                className="input"
              />
            </div>

            <div className="sm:col-span-2">
              <label className="mb-1.5 block text-xs font-medium text-ink">
                ลิงก์ปลายทาง (URL)
              </label>
              <input
                type="url"
                required
                value={url}
                onChange={(e) => setUrl(e.target.value)}
                placeholder="https://..."
                className="input"
              />
            </div>

            <div className="sm:col-span-2">
              <label className="mb-1.5 block text-xs font-medium text-ink">
                คำอธิบายสั้น
              </label>
              <input
                type="text"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="อธิบายการใช้งานสั้น ๆ"
                className="input"
              />
            </div>

            <div>
              <label className="mb-1.5 block text-xs font-medium text-ink">
                หมวดหมู่
              </label>
              <select
                value={category}
                onChange={(e) =>
                  setCategory(e.target.value as SchoolModuleLink['category'])
                }
                className="input"
              >
                <option value="hr">งานบุคคลและวันลา</option>
                <option value="academic">งานวิชาการ</option>
                <option value="admin">งานบริหารและตั้งค่า</option>
                <option value="other">อื่น ๆ</option>
              </select>
            </div>

            <div>
              <label className="mb-1.5 block text-xs font-medium text-ink">
                รูปแบบการเปิดลิงก์
              </label>
              <select
                value={openMode}
                onChange={(e) =>
                  setOpenMode(e.target.value as 'new_tab' | 'same_tab')
                }
                className="input"
              >
                <option value="new_tab">เปิดแท็บใหม่</option>
                <option value="same_tab">เปิดในหน้าต่างเดิม</option>
              </select>
            </div>

            <div className="flex justify-end sm:col-span-2">
              <button type="submit" disabled={busy} className="btn-primary">
                <Plus className="h-4 w-4" strokeWidth={1.5} />
                <span>เพิ่มลิงก์ระบบย่อย</span>
              </button>
            </div>
          </form>
        </section>
      )}
    </div>
  );
}
