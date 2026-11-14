import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react';
import { ArrowUpRight, ExternalLink, Plus, Search, Trash2 } from 'lucide-react';
import { supabase } from '../supabase';
import type { ResolvedDivisionModule } from './mapping';
import type { SchoolDepartment } from './types';

interface FinanceBudgetPageProps {
  schoolId: number | null;
  canEdit: boolean;
  mod: ResolvedDivisionModule;
}

type ItemType = 'budget' | 'asset';
type ItemStatus = 'active' | 'completed' | 'maintenance';

interface FinanceItemRow {
  id: number;
  id_school: number;
  item_type: ItemType;
  code: string;
  title: string;
  department_id: number | null;
  amount: number;
  status: ItemStatus;
  external_url: string | null;
}

const STATUS_LABEL: Record<ItemStatus, string> = {
  active: 'กำลังดำเนินการ / ใช้งานปกติ',
  completed: 'เบิกจ่ายครบ / เสร็จสิ้น',
  maintenance: 'รอซ่อมบำรุง / จำหน่าย',
};

export default function FinanceBudgetPage({
  schoolId,
  canEdit,
  mod,
}: FinanceBudgetPageProps) {
  const [tab, setTab] = useState<ItemType>('budget');
  const [items, setItems] = useState<FinanceItemRow[]>([]);
  const [departments, setDepartments] = useState<SchoolDepartment[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [query, setQuery] = useState('');

  // Form
  const [code, setCode] = useState('');
  const [title, setTitle] = useState('');
  const [departmentId, setDepartmentId] = useState('');
  const [amount, setAmount] = useState('');
  const [externalUrl, setExternalUrl] = useState('');

  const loadAll = useCallback(async () => {
    if (!schoolId) return;
    setLoading(true);
    const [finRes, deptRes] = await Promise.all([
      supabase
        .from('SchoolWebFinanceItems')
        .select(
          'id, id_school, item_type, code, title, department_id, amount, status, external_url',
        )
        .eq('id_school', schoolId)
        .order('id', { ascending: false }),
      supabase
        .from('SchoolDepartments')
        .select('id, id_school, code, name, category, sort_order, is_active')
        .eq('id_school', schoolId)
        .eq('is_active', true),
    ]);

    if (finRes.error) setError(finRes.error.message);
    else setItems((finRes.data as FinanceItemRow[] | null) ?? []);

    if (!deptRes.error) {
      setDepartments((deptRes.data as SchoolDepartment[] | null) ?? []);
    }
    setLoading(false);
  }, [schoolId]);

  useEffect(() => {
    loadAll();
  }, [loadAll]);

  const deptMap = useMemo(() => {
    const map = new Map<number, string>();
    for (const d of departments) map.set(d.id, d.name);
    return map;
  }, [departments]);

  const tabItems = useMemo(() => {
    const q = query.trim().toLowerCase();
    return items.filter((item) => {
      if (item.item_type !== tab) return false;
      if (!q) return true;
      return (
        item.code.toLowerCase().includes(q) ||
        item.title.toLowerCase().includes(q)
      );
    });
  }, [items, tab, query]);

  const totalAmount = useMemo(
    () => tabItems.reduce((sum, r) => sum + (Number(r.amount) || 0), 0),
    [tabItems],
  );

  async function handleAdd(e: FormEvent) {
    e.preventDefault();
    if (!schoolId || !canEdit) return;
    setBusy(true);
    setError(null);

    const { error: insErr } = await supabase.from('SchoolWebFinanceItems').insert({
      id_school: schoolId,
      item_type: tab,
      code: code.trim(),
      title: title.trim(),
      department_id: departmentId ? Number(departmentId) : null,
      amount: Number(amount) || 0,
      external_url: externalUrl.trim() || null,
      status: 'active',
    });

    if (insErr) {
      setError(insErr.message);
    } else {
      setCode('');
      setTitle('');
      setAmount('');
      setExternalUrl('');
      await loadAll();
    }
    setBusy(false);
  }

  async function updateStatus(id: number, status: ItemStatus) {
    if (!canEdit) return;
    setBusy(true);
    const { error: updErr } = await supabase
      .from('SchoolWebFinanceItems')
      .update({ status })
      .eq('id', id);
    if (updErr) setError(updErr.message);
    else await loadAll();
    setBusy(false);
  }

  async function removeItem(id: number) {
    if (!canEdit) return;
    setBusy(true);
    const { error: delErr } = await supabase
      .from('SchoolWebFinanceItems')
      .delete()
      .eq('id', id);
    if (delErr) setError(delErr.message);
    else await loadAll();
    setBusy(false);
  }

  return (
    <div className="space-y-6">
      {/* Optional Sub-web Launcher if URL is configured for this module */}
      {mod.resolved_url && (
        <section className="surface-card flex flex-col gap-4 p-5 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p className="text-sm font-semibold text-ink">
              ระบบ Web ย่อยของ{mod.title}
            </p>
            <p className="mt-0.5 text-xs text-slate-500">
              เชื่อมต่อกับ Web ย่อยภายนอกของฝ่ายการเงินและพัสดุ
            </p>
          </div>
          <a
            href={mod.resolved_url}
            target={mod.open_mode === 'new_tab' ? '_blank' : '_self'}
            rel={mod.open_mode === 'new_tab' ? 'noreferrer' : undefined}
            className="btn-primary shrink-0"
          >
            <span>เปิด Web ย่อยการเงิน/พัสดุ</span>
            <ArrowUpRight className="h-4 w-4" strokeWidth={1.5} />
          </a>
        </section>
      )}

      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h2 className="text-xl font-semibold tracking-tight text-ink">
            {tab === 'budget'
              ? 'ทะเบียนโครงการและงบประมาณ'
              : 'ทะเบียนพัสดุและครุภัณฑ์'}
          </h2>
          <p className="mt-1 text-sm text-slate-600">
            ยอดรวมในหมวดนี้:{' '}
            <span className="font-semibold tabular-nums text-ink">
              {totalAmount.toLocaleString('th-TH', {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2,
              })}
            </span>{' '}
            บาท
          </p>
        </div>

        <div className="inline-flex rounded-lg border border-line bg-white p-1">
          <button
            type="button"
            onClick={() => setTab('budget')}
            className={`rounded-md px-3 py-1.5 text-sm font-medium transition-colors ${
              tab === 'budget'
                ? 'bg-brand-50 text-brand-700'
                : 'text-slate-600 hover:text-ink'
            }`}
          >
            โครงการและงบประมาณ
          </button>
          <button
            type="button"
            onClick={() => setTab('asset')}
            className={`rounded-md px-3 py-1.5 text-sm font-medium transition-colors ${
              tab === 'asset'
                ? 'bg-brand-50 text-brand-700'
                : 'text-slate-600 hover:text-ink'
            }`}
          >
            พัสดุและครุภัณฑ์
          </button>
        </div>
      </div>

      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {canEdit && (
        <section className="surface-card p-6">
          <h3 className="text-base font-semibold text-ink">
            {tab === 'budget' ? 'เพิ่มโครงการ/งบประมาณ' : 'เพิ่มรายการครุภัณฑ์/พัสดุ'}
          </h3>
          <form onSubmit={handleAdd} className="mt-4 grid gap-4 sm:grid-cols-12">
            <div className="sm:col-span-2">
              <label className="mb-1.5 block text-xs font-medium text-ink">
                {tab === 'budget' ? 'รหัสโครงการ' : 'รหัสครุภัณฑ์'}
              </label>
              <input
                type="text"
                required
                value={code}
                onChange={(e) => setCode(e.target.value)}
                placeholder={tab === 'budget' ? 'BG-6901' : 'AS-001'}
                className="input tabular-nums"
              />
            </div>

            <div className="sm:col-span-4">
              <label className="mb-1.5 block text-xs font-medium text-ink">
                {tab === 'budget' ? 'ชื่อโครงการ / รายการงบ' : 'ชื่อครุภัณฑ์ / พัสดุ'}
              </label>
              <input
                type="text"
                required
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="ระบุชื่อรายการ"
                className="input"
              />
            </div>

            <div className="sm:col-span-2">
              <label className="mb-1.5 block text-xs font-medium text-ink">
                ฝ่ายที่รับผิดชอบ
              </label>
              <select
                value={departmentId}
                onChange={(e) => setDepartmentId(e.target.value)}
                className="input"
              >
                <option value="">ไม่ระบุ</option>
                {departments.map((d) => (
                  <option key={d.id} value={d.id}>
                    {d.name}
                  </option>
                ))}
              </select>
            </div>

            <div className="sm:col-span-2">
              <label className="mb-1.5 block text-xs font-medium text-ink">
                จำนวนเงิน / มูลค่า (บาท)
              </label>
              <input
                type="number"
                step="0.01"
                min="0"
                required
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="0.00"
                className="input tabular-nums"
              />
            </div>

            <div className="flex items-end sm:col-span-2">
              <button type="submit" disabled={busy} className="btn-primary w-full">
                <Plus className="h-4 w-4" strokeWidth={1.5} />
                <span>บันทึก</span>
              </button>
            </div>
          </form>
        </section>
      )}

      <section className="surface-card p-6">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div className="relative w-full sm:w-64">
            <Search
              className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
              strokeWidth={1.5}
            />
            <input
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="ค้นหารหัส หรือชื่อรายการ"
              className="input pl-9"
            />
          </div>
          <span className="tabular-nums text-xs text-slate-500">
            {tabItems.length.toLocaleString('th-TH')} รายการ
          </span>
        </div>

        <div className="mt-5 overflow-x-auto rounded-lg border border-line">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-line bg-canvas text-xs font-medium text-slate-500">
              <tr>
                <th className="px-4 py-3">รหัส</th>
                <th className="px-4 py-3">รายการ</th>
                <th className="px-4 py-3">ฝ่ายที่รับผิดชอบ</th>
                <th className="px-4 py-3 text-right">จำนวนเงิน (บาท)</th>
                <th className="px-4 py-3">สถานะ</th>
                {canEdit && <th className="px-4 py-3 text-right">จัดการ</th>}
              </tr>
            </thead>
            <tbody className="divide-y divide-line">
              {loading ? (
                <tr>
                  <td colSpan={canEdit ? 6 : 5} className="px-4 py-8 text-center text-slate-500">
                    กำลังโหลดข้อมูล...
                  </td>
                </tr>
              ) : tabItems.length === 0 ? (
                <tr>
                  <td colSpan={canEdit ? 6 : 5} className="px-4 py-8 text-center text-slate-500">
                    ยังไม่มีรายการในหมวดนี้
                  </td>
                </tr>
              ) : (
                tabItems.map((row) => (
                  <tr key={row.id} className="hover:bg-slate-50/60">
                    <td className="whitespace-nowrap px-4 py-3 font-medium tabular-nums text-ink">
                      {row.code}
                    </td>
                    <td className="px-4 py-3 text-ink">{row.title}</td>
                    <td className="px-4 py-3 text-slate-600">
                      {row.department_id ? deptMap.get(row.department_id) || '-' : '-'}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-right font-medium tabular-nums text-ink">
                      {Number(row.amount).toLocaleString('th-TH', {
                        minimumFractionDigits: 2,
                        maximumFractionDigits: 2,
                      })}
                    </td>
                    <td className="px-4 py-3">
                      {canEdit ? (
                        <select
                          value={row.status}
                          disabled={busy}
                          onChange={(e) =>
                            updateStatus(row.id, e.target.value as ItemStatus)
                          }
                          className="rounded border border-line bg-white px-2 py-1 text-xs text-ink outline-none focus:border-brand-500"
                        >
                          {Object.entries(STATUS_LABEL).map(([val, lbl]) => (
                            <option key={val} value={val}>
                              {lbl}
                            </option>
                          ))}
                        </select>
                      ) : (
                        <span className="text-xs text-slate-600">
                          {STATUS_LABEL[row.status]}
                        </span>
                      )}
                    </td>
                    {canEdit && (
                      <td className="px-4 py-3 text-right">
                        <div className="inline-flex items-center gap-1">
                          {row.external_url && (
                            <a
                              href={row.external_url}
                              target="_blank"
                              rel="noreferrer"
                              className="rounded p-1 text-brand-600 hover:bg-brand-50"
                            >
                              <ExternalLink className="h-4 w-4" strokeWidth={1.5} />
                            </a>
                          )}
                          <button
                            type="button"
                            disabled={busy}
                            onClick={() => removeItem(row.id)}
                            className="rounded p-1 text-slate-400 hover:bg-red-50 hover:text-red-600"
                            title="ลบรายการ"
                          >
                            <Trash2 className="h-4 w-4" strokeWidth={1.5} />
                          </button>
                        </div>
                      </td>
                    )}
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
