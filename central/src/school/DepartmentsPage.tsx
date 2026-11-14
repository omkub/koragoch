import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { Plus, Power, Trash2 } from 'lucide-react';
import { supabase } from '../supabase';
import type { SchoolDepartment } from './types';

interface DepartmentsPageProps {
  schoolId: number | null;
  canEdit: boolean;
}

const CATEGORY_LABEL: Record<SchoolDepartment['category'], string> = {
  management: 'ฝ่ายบริหาร',
  academic: 'กลุ่มสาระการเรียนรู้',
  support: 'งานสนับสนุน',
  department: 'หน่วยงานทั่วไป',
};

export default function DepartmentsPage({ schoolId, canEdit }: DepartmentsPageProps) {
  const [items, setItems] = useState<SchoolDepartment[]>([]);
  const [loading, setLoading] = useState(true);
  const [name, setName] = useState('');
  const [code, setCode] = useState('');
  const [category, setCategory] =
    useState<SchoolDepartment['category']>('academic');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!schoolId) return;
    setLoading(true);
    const { data, error: fetchErr } = await supabase
      .from('SchoolDepartments')
      .select('id, id_school, code, name, category, sort_order, is_active')
      .eq('id_school', schoolId)
      .order('sort_order', { ascending: true })
      .order('id', { ascending: true });

    if (fetchErr) {
      setError(fetchErr.message);
    } else {
      setItems((data as SchoolDepartment[] | null) ?? []);
    }
    setLoading(false);
  }, [schoolId]);

  useEffect(() => {
    load();
  }, [load]);

  async function handleAdd(e: FormEvent) {
    e.preventDefault();
    if (!schoolId || !canEdit) return;
    setBusy(true);
    setError(null);

    const { error: insErr } = await supabase.from('SchoolDepartments').insert({
      id_school: schoolId,
      code: code.trim() || null,
      name: name.trim(),
      category,
      sort_order: items.length + 1,
      is_active: true,
    });

    if (insErr) {
      setError(insErr.message);
    } else {
      setName('');
      setCode('');
      await load();
    }
    setBusy(false);
  }

  async function toggleActive(item: SchoolDepartment) {
    if (!canEdit) return;
    setBusy(true);
    const { error: updErr } = await supabase
      .from('SchoolDepartments')
      .update({ is_active: !item.is_active })
      .eq('id', item.id);
    if (updErr) setError(updErr.message);
    else await load();
    setBusy(false);
  }

  async function removeItem(item: SchoolDepartment) {
    if (!canEdit) return;
    setBusy(true);
    const { error: delErr } = await supabase
      .from('SchoolDepartments')
      .delete()
      .eq('id', item.id);
    if (delErr) setError(delErr.message);
    else await load();
    setBusy(false);
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight text-ink">
          ฝ่ายและกลุ่มสาระการเรียนรู้
        </h1>
        <p className="mt-1 text-sm text-slate-600">
          จัดการโครงสร้างหน่วยงานภายในโรงเรียน
        </p>
      </div>

      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {canEdit && (
        <section className="surface-card p-6">
          <h2 className="text-base font-semibold text-ink">เพิ่มฝ่ายหรือกลุ่มสาระ</h2>
          <form onSubmit={handleAdd} className="mt-4 grid gap-4 sm:grid-cols-12">
            <div className="sm:col-span-5">
              <label className="mb-1.5 block text-xs font-medium text-ink">
                ชื่อหน่วยงาน / กลุ่มสาระ
              </label>
              <input
                type="text"
                required
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="เช่น กลุ่มสาระการเรียนรู้วิทยาศาสตร์และเทคโนโลยี"
                className="input"
              />
            </div>

            <div className="sm:col-span-2">
              <label className="mb-1.5 block text-xs font-medium text-ink">
                รหัสย่อ
              </label>
              <input
                type="text"
                value={code}
                onChange={(e) => setCode(e.target.value)}
                placeholder="เช่น วท."
                className="input"
              />
            </div>

            <div className="sm:col-span-3">
              <label className="mb-1.5 block text-xs font-medium text-ink">
                หมวดหมู่
              </label>
              <select
                value={category}
                onChange={(e) =>
                  setCategory(e.target.value as SchoolDepartment['category'])
                }
                className="input"
              >
                <option value="management">ฝ่ายบริหาร</option>
                <option value="academic">กลุ่มสาระการเรียนรู้</option>
                <option value="support">งานสนับสนุน</option>
                <option value="department">หน่วยงานทั่วไป</option>
              </select>
            </div>

            <div className="flex items-end sm:col-span-2">
              <button type="submit" disabled={busy} className="btn-primary w-full">
                <Plus className="h-4 w-4" strokeWidth={1.5} />
                <span>เพิ่ม</span>
              </button>
            </div>
          </form>
        </section>
      )}

      <section className="surface-card p-6">
        <h2 className="text-base font-semibold text-ink">
          รายการหน่วยงาน ({items.length})
        </h2>

        <div className="mt-4 divide-y divide-line rounded-lg border border-line">
          {loading ? (
            <p className="p-6 text-center text-sm text-slate-500">
              กำลังโหลดข้อมูล...
            </p>
          ) : items.length === 0 ? (
            <p className="p-6 text-center text-sm text-slate-500">
              ยังไม่มีข้อมูลฝ่ายหรือกลุ่มสาระของโรงเรียนนี้
            </p>
          ) : (
            items.map((item) => (
              <div
                key={item.id}
                className="flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between"
              >
                <div className="min-w-0">
                  <div className="flex flex-wrap items-center gap-2">
                    <p className="text-sm font-medium text-ink">{item.name}</p>
                    {item.code && (
                      <span className="rounded bg-slate-100 px-2 py-0.5 text-xs text-slate-600">
                        {item.code}
                      </span>
                    )}
                    <span className="rounded bg-brand-50 px-2 py-0.5 text-xs text-brand-700">
                      {CATEGORY_LABEL[item.category]}
                    </span>
                    {!item.is_active && (
                      <span className="rounded bg-slate-100 px-2 py-0.5 text-xs text-slate-500">
                        ปิดใช้งาน
                      </span>
                    )}
                  </div>
                </div>

                {canEdit && (
                  <div className="flex shrink-0 items-center gap-2">
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => toggleActive(item)}
                      title={item.is_active ? 'ปิดใช้งาน' : 'เปิดใช้งาน'}
                      className="rounded-lg border border-line p-1.5 text-slate-600 hover:bg-slate-50"
                    >
                      <Power className="h-4 w-4" strokeWidth={1.5} />
                    </button>
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => removeItem(item)}
                      title="ลบ"
                      className="rounded-lg border border-line p-1.5 text-red-600 hover:bg-red-50"
                    >
                      <Trash2 className="h-4 w-4" strokeWidth={1.5} />
                    </button>
                  </div>
                )}
              </div>
            ))
          )}
        </div>
      </section>
    </div>
  );
}
