import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react';
import { ExternalLink, Plus, Search, Trash2 } from 'lucide-react';
import { supabase } from '../supabase';
import type { SchoolDepartment } from './types';

interface DocumentsPageProps {
  schoolId: number | null;
  canEdit: boolean;
}

type DocType = 'incoming' | 'outgoing' | 'memo';
type DocStatus = 'pending' | 'acknowledged' | 'archived';

interface DocumentRow {
  id: number;
  id_school: number;
  doc_no: string;
  doc_type: DocType;
  title: string;
  sender_or_receiver: string | null;
  doc_date: string;
  department_id: number | null;
  status: DocStatus;
  external_url: string | null;
}

const TYPE_LABEL: Record<DocType, string> = {
  incoming: 'หนังสือรับ',
  outgoing: 'หนังสือส่ง',
  memo: 'บันทึกข้อความ',
};

const STATUS_LABEL: Record<DocStatus, string> = {
  pending: 'รอดำเนินการ',
  acknowledged: 'รับทราบแล้ว',
  archived: 'จัดเก็บ',
};

export default function DocumentsPage({ schoolId, canEdit }: DocumentsPageProps) {
  const [docs, setDocs] = useState<DocumentRow[]>([]);
  const [departments, setDepartments] = useState<SchoolDepartment[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [query, setQuery] = useState('');
  const [filterType, setFilterType] = useState<'all' | DocType>('all');

  const [docNo, setDocNo] = useState('');
  const [docType, setDocType] = useState<DocType>('incoming');
  const [title, setTitle] = useState('');
  const [counterparty, setCounterparty] = useState('');
  const [docDate, setDocDate] = useState(() => new Date().toISOString().slice(0, 10));
  const [departmentId, setDepartmentId] = useState('');
  const [externalUrl, setExternalUrl] = useState('');

  const loadAll = useCallback(async () => {
    if (!schoolId) return;
    setLoading(true);
    const [docRes, deptRes] = await Promise.all([
      supabase
        .from('SchoolWebDocuments')
        .select(
          'id, id_school, doc_no, doc_type, title, sender_or_receiver, doc_date, department_id, status, external_url',
        )
        .eq('id_school', schoolId)
        .order('doc_date', { ascending: false })
        .order('id', { ascending: false }),
      supabase
        .from('SchoolDepartments')
        .select('id, id_school, code, name, category, sort_order, is_active')
        .eq('id_school', schoolId)
        .eq('is_active', true),
    ]);

    if (docRes.error) setError(docRes.error.message);
    else setDocs((docRes.data as DocumentRow[] | null) ?? []);

    if (!deptRes.error) setDepartments((deptRes.data as SchoolDepartment[] | null) ?? []);
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

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return docs.filter((d) => {
      if (filterType !== 'all' && d.doc_type !== filterType) return false;
      if (!q) return true;
      return (
        d.doc_no.toLowerCase().includes(q) ||
        d.title.toLowerCase().includes(q) ||
        (d.sender_or_receiver || '').toLowerCase().includes(q)
      );
    });
  }, [docs, query, filterType]);

  async function handleAdd(e: FormEvent) {
    e.preventDefault();
    if (!schoolId || !canEdit) return;
    setBusy(true);
    setError(null);

    const { error: insErr } = await supabase.from('SchoolWebDocuments').insert({
      id_school: schoolId,
      doc_no: docNo.trim(),
      doc_type: docType,
      title: title.trim(),
      sender_or_receiver: counterparty.trim() || null,
      doc_date: docDate,
      department_id: departmentId ? Number(departmentId) : null,
      external_url: externalUrl.trim() || null,
      status: 'pending',
    });

    if (insErr) {
      setError(insErr.message);
    } else {
      setDocNo('');
      setTitle('');
      setCounterparty('');
      setExternalUrl('');
      await loadAll();
    }
    setBusy(false);
  }

  async function updateStatus(id: number, status: DocStatus) {
    if (!canEdit) return;
    setBusy(true);
    const { error: updErr } = await supabase
      .from('SchoolWebDocuments')
      .update({ status })
      .eq('id', id);
    if (updErr) setError(updErr.message);
    else await loadAll();
    setBusy(false);
  }

  async function removeDoc(id: number) {
    if (!canEdit) return;
    setBusy(true);
    const { error: delErr } = await supabase
      .from('SchoolWebDocuments')
      .delete()
      .eq('id', id);
    if (delErr) setError(delErr.message);
    else await loadAll();
    setBusy(false);
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight text-ink">
          สารบรรณอิเล็กทรอนิกส์
        </h1>
        <p className="mt-1 text-sm text-slate-600">
          ทะเบียนหนังสือรับ หนังสือส่ง และบันทึกข้อความภายในโรงเรียน
        </p>
      </div>

      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {canEdit && (
        <section className="surface-card p-6">
          <h2 className="text-base font-semibold text-ink">ลงทะเบียนหนังสือใหม่</h2>
          <form onSubmit={handleAdd} className="mt-4 grid gap-4 sm:grid-cols-12">
            <div className="sm:col-span-3">
              <label className="mb-1.5 block text-xs font-medium text-ink">
                เลขที่หนังสือ
              </label>
              <input
                type="text"
                required
                value={docNo}
                onChange={(e) => setDocNo(e.target.value)}
                placeholder="ศธ 04255/123"
                className="input"
              />
            </div>

            <div className="sm:col-span-2">
              <label className="mb-1.5 block text-xs font-medium text-ink">
                ประเภท
              </label>
              <select
                value={docType}
                onChange={(e) => setDocType(e.target.value as DocType)}
                className="input"
              >
                <option value="incoming">หนังสือรับ</option>
                <option value="outgoing">หนังสือส่ง</option>
                <option value="memo">บันทึกข้อความ</option>
              </select>
            </div>

            <div className="sm:col-span-5">
              <label className="mb-1.5 block text-xs font-medium text-ink">
                เรื่อง
              </label>
              <input
                type="text"
                required
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="เรื่องของหนังสือราชการ"
                className="input"
              />
            </div>

            <div className="sm:col-span-2">
              <label className="mb-1.5 block text-xs font-medium text-ink">
                ลงวันที่
              </label>
              <input
                type="date"
                required
                value={docDate}
                onChange={(e) => setDocDate(e.target.value)}
                className="input tabular-nums"
              />
            </div>

            <div className="sm:col-span-4">
              <label className="mb-1.5 block text-xs font-medium text-ink">
                จาก / ถึงหน่วยงาน
              </label>
              <input
                type="text"
                value={counterparty}
                onChange={(e) => setCounterparty(e.target.value)}
                placeholder="เช่น สพม. / ฝ่ายวิชาการ"
                className="input"
              />
            </div>

            <div className="sm:col-span-3">
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

            <div className="sm:col-span-3">
              <label className="mb-1.5 block text-xs font-medium text-ink">
                ลิงก์ไฟล์แนบ (ถ้ามี)
              </label>
              <input
                type="url"
                value={externalUrl}
                onChange={(e) => setExternalUrl(e.target.value)}
                placeholder="https://drive.google.com/..."
                className="input"
              />
            </div>

            <div className="flex items-end sm:col-span-2">
              <button type="submit" disabled={busy} className="btn-primary w-full">
                <Plus className="h-4 w-4" strokeWidth={1.5} />
                <span>ลงทะเบียน</span>
              </button>
            </div>
          </form>
        </section>
      )}

      <section className="surface-card p-6">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex flex-wrap items-center gap-3">
            <div className="relative w-full sm:w-64">
              <Search
                className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
                strokeWidth={1.5}
              />
              <input
                type="text"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="ค้นหาเลขที่ หรือเรื่อง"
                className="input pl-9"
              />
            </div>

            <select
              value={filterType}
              onChange={(e) => setFilterType(e.target.value as 'all' | DocType)}
              className="input w-auto"
            >
              <option value="all">ทุกประเภท</option>
              <option value="incoming">หนังสือรับ</option>
              <option value="outgoing">หนังสือส่ง</option>
              <option value="memo">บันทึกข้อความ</option>
            </select>
          </div>

          <span className="tabular-nums text-xs text-slate-500">
            {filtered.length.toLocaleString('th-TH')} รายการ
          </span>
        </div>

        <div className="mt-5 overflow-x-auto rounded-lg border border-line">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-line bg-canvas text-xs font-medium text-slate-500">
              <tr>
                <th className="px-4 py-3">ลงวันที่</th>
                <th className="px-4 py-3">เลขที่หนังสือ</th>
                <th className="px-4 py-3">ประเภท</th>
                <th className="px-4 py-3">เรื่อง</th>
                <th className="px-4 py-3">ฝ่าย</th>
                <th className="px-4 py-3">สถานะ</th>
                <th className="px-4 py-3 text-right">ไฟล์</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-line">
              {loading ? (
                <tr>
                  <td colSpan={7} className="px-4 py-8 text-center text-slate-500">
                    กำลังโหลดทะเบียนหนังสือ...
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-4 py-8 text-center text-slate-500">
                    ยังไม่มีรายการหนังสือ
                  </td>
                </tr>
              ) : (
                filtered.map((d) => (
                  <tr key={d.id} className="hover:bg-slate-50/60">
                    <td className="whitespace-nowrap px-4 py-3 tabular-nums text-slate-600">
                      {d.doc_date}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 font-medium text-ink">
                      {d.doc_no}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-slate-600">
                      {TYPE_LABEL[d.doc_type]}
                    </td>
                    <td className="px-4 py-3">
                      <p className="font-medium text-ink">{d.title}</p>
                      {d.sender_or_receiver && (
                        <p className="text-xs text-slate-500">{d.sender_or_receiver}</p>
                      )}
                    </td>
                    <td className="px-4 py-3 text-slate-600">
                      {d.department_id ? deptMap.get(d.department_id) || '-' : '-'}
                    </td>
                    <td className="px-4 py-3">
                      {canEdit ? (
                        <select
                          value={d.status}
                          disabled={busy}
                          onChange={(e) =>
                            updateStatus(d.id, e.target.value as DocStatus)
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
                          {STATUS_LABEL[d.status]}
                        </span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-right">
                      <div className="inline-flex items-center gap-1.5">
                        {d.external_url && (
                          <a
                            href={d.external_url}
                            target="_blank"
                            rel="noreferrer"
                            className="rounded p-1 text-brand-600 hover:bg-brand-50"
                            title="เปิดไฟล์แนบ"
                          >
                            <ExternalLink className="h-4 w-4" strokeWidth={1.5} />
                          </a>
                        )}
                        {canEdit && (
                          <button
                            type="button"
                            disabled={busy}
                            onClick={() => removeDoc(d.id)}
                            className="rounded p-1 text-slate-400 hover:bg-red-50 hover:text-red-600"
                            title="ลบรายการ"
                          >
                            <Trash2 className="h-4 w-4" strokeWidth={1.5} />
                          </button>
                        )}
                      </div>
                    </td>
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
