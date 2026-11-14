import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { Check, Plus } from 'lucide-react';
import { supabase } from '../supabase';
import type { AcademicTerm, AcademicYear } from './types';

interface AcademicSettingsSectionProps {
  schoolId: number | null;
  canEdit: boolean;
  onUpdated: () => Promise<void>;
}

export default function AcademicSettingsSection({
  schoolId,
  canEdit,
  onUpdated,
}: AcademicSettingsSectionProps) {
  const [years, setYears] = useState<AcademicYear[]>([]);
  const [terms, setTerms] = useState<AcademicTerm[]>([]);
  const [yearBe, setYearBe] = useState('2569');
  const [termNo, setTermNo] = useState('1');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!schoolId) return;
    const [yRes, tRes] = await Promise.all([
      supabase
        .from('AcademicYears')
        .select('id, id_school, year_be, label, is_current')
        .eq('id_school', schoolId)
        .order('year_be', { ascending: false }),
      supabase
        .from('AcademicTerms')
        .select('id, id_school, academic_year_id, term_no, label, is_current')
        .eq('id_school', schoolId)
        .order('id', { ascending: false }),
    ]);
    setYears((yRes.data as AcademicYear[] | null) ?? []);
    setTerms((tRes.data as AcademicTerm[] | null) ?? []);
  }, [schoolId]);

  useEffect(() => {
    load();
  }, [load]);

  async function addYearAndTerm(e: FormEvent) {
    e.preventDefault();
    if (!schoolId || !canEdit) return;
    const parsedYear = Number(yearBe);
    const parsedTerm = Number(termNo);
    if (!parsedYear || !parsedTerm) return;

    setBusy(true);
    setError(null);

    await supabase
      .from('AcademicYears')
      .update({ is_current: false })
      .eq('id_school', schoolId);
    await supabase
      .from('AcademicTerms')
      .update({ is_current: false })
      .eq('id_school', schoolId);

    const { data: yearRow, error: yErr } = await supabase
      .from('AcademicYears')
      .upsert(
        {
          id_school: schoolId,
          year_be: parsedYear,
          label: `ปีการศึกษา ${parsedYear}`,
          is_current: true,
        },
        { onConflict: 'id_school,year_be' },
      )
      .select('id')
      .single();

    if (yErr || !yearRow) {
      setError(yErr?.message || 'บันทึกปีการศึกษาไม่สำเร็จ');
      setBusy(false);
      return;
    }

    const { error: tErr } = await supabase.from('AcademicTerms').upsert(
      {
        id_school: schoolId,
        academic_year_id: yearRow.id,
        term_no: parsedTerm,
        label: `ภาคเรียนที่ ${parsedTerm}/${parsedYear}`,
        is_current: true,
      },
      { onConflict: 'academic_year_id,term_no' },
    );

    if (tErr) {
      setError(tErr.message);
    } else {
      await load();
      await onUpdated();
    }
    setBusy(false);
  }

  async function setCurrentTerm(term: AcademicTerm) {
    if (!schoolId || !canEdit) return;
    setBusy(true);
    setError(null);

    await supabase
      .from('AcademicYears')
      .update({ is_current: false })
      .eq('id_school', schoolId);
    await supabase
      .from('AcademicTerms')
      .update({ is_current: false })
      .eq('id_school', schoolId);

    await supabase
      .from('AcademicYears')
      .update({ is_current: true })
      .eq('id', term.academic_year_id);
    await supabase
      .from('AcademicTerms')
      .update({ is_current: true })
      .eq('id', term.id);

    await load();
    await onUpdated();
    setBusy(false);
  }

  return (
    <section className="surface-card p-6">
      <h2 className="text-base font-semibold text-ink">ปีการศึกษาและภาคเรียน</h2>
      <p className="mt-1 text-sm text-slate-600">
        กำหนดปีการศึกษาและภาคเรียนปัจจุบันของโรงเรียน (แสดงบนแถบด้านบนของเว็บ)
      </p>

      {error && (
        <div className="mt-4 rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
          {error}
        </div>
      )}

      {canEdit && (
        <form onSubmit={addYearAndTerm} className="mt-4 flex flex-wrap items-end gap-3">
          <div>
            <label className="mb-1.5 block text-xs font-medium text-ink">
              ปีการศึกษา (พ.ศ.)
            </label>
            <input
              type="number"
              required
              min={2560}
              max={2600}
              value={yearBe}
              onChange={(e) => setYearBe(e.target.value)}
              className="input w-32 tabular-nums"
            />
          </div>

          <div>
            <label className="mb-1.5 block text-xs font-medium text-ink">
              ภาคเรียน
            </label>
            <select
              value={termNo}
              onChange={(e) => setTermNo(e.target.value)}
              className="input w-36"
            >
              <option value="1">ภาคเรียนที่ 1</option>
              <option value="2">ภาคเรียนที่ 2</option>
              <option value="3">ภาคฤดูร้อน</option>
            </select>
          </div>

          <button type="submit" disabled={busy} className="btn-secondary">
            <Plus className="h-4 w-4" strokeWidth={1.5} />
            <span>บันทึกและตั้งเป็นปัจจุบัน</span>
          </button>
        </form>
      )}

      {terms.length > 0 && (
        <div className="mt-5 flex flex-wrap gap-2">
          {terms.map((t) => {
            const yearObj = years.find((y) => y.id === t.academic_year_id);
            const display = t.label || `ภาคเรียนที่ ${t.term_no}/${yearObj?.year_be ?? ''}`;
            return (
              <button
                key={t.id}
                type="button"
                disabled={!canEdit || busy || t.is_current}
                onClick={() => setCurrentTerm(t)}
                className={`inline-flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-medium transition-colors ${
                  t.is_current
                    ? 'border-brand-200 bg-brand-50 text-brand-700'
                    : 'border-line bg-white text-slate-700 hover:bg-slate-50'
                }`}
              >
                {t.is_current && <Check className="h-3.5 w-3.5" strokeWidth={2} />}
                <span>{display}</span>
              </button>
            );
          })}
        </div>
      )}
    </section>
  );
}
