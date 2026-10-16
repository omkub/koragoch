import { useCallback, useEffect, useMemo, useState } from 'react';
import { schoolName, supabase, type School } from '../supabase';
import { LeaveFormData, formatThaiDate, type Row } from '../leaveForm/leaveFormData';
import { loadLeaveFormSource, sampleLeaf, type LeaveFormSource } from '../leaveForm/leaveFormSource';
import { renderDocument, type RenderContext } from '../forms/render';
import { LEAVE_FLAGS, LEAVE_PLACEHOLDERS, leaveContext } from '../forms/leaveTemplate';
import { TRIP_FLAGS, TRIP_PLACEHOLDERS, loadTripSource, sampleTrip, tripContext, type TripSource } from '../forms/tripTemplate';
import {
  builtInTemplate,
  listVersions,
  resolveTemplate,
  saveVersion,
  setSchoolUsesGlobal,
  type TemplateSource,
  type TemplateVersion,
} from '../forms/templateStore';
import {
  ADDABLE_BLOCKS,
  BLOCK_TYPE_LABEL,
  FORM_TYPE_LABEL,
  cloneTemplate,
  newBlock,
  newBlockId,
  normalizeTemplate,
  type Block,
  type BlockType,
  type FormTemplate,
  type FormType,
} from '../forms/template';
import PaperEditor from '../forms/editor/PaperEditor';
import BlockEditor from '../forms/editor/BlockEditor';
import PreviewFrame, { type FitInfo } from '../forms/editor/PreviewFrame';
import '../forms/editor/designer.css';
import { EmptyState, Field, Notice, PageHeader } from '../ui/components';

type Scope = 'global' | number;
type Message = { text: string; error?: boolean } | null;

const SAMPLE = 'sample';
const SOURCE_LABEL: Record<TemplateSource, string> = {
  school: 'แม่แบบเฉพาะโรงเรียนนี้',
  global: 'ใช้แม่แบบกลาง',
  builtin: 'ค่าเริ่มต้นของระบบ (ยังไม่เคยบันทึก)',
};

function thaiDateTime(iso: string) {
  return new Date(iso).toLocaleString('th-TH', { dateStyle: 'medium', timeStyle: 'short', timeZone: 'Asia/Bangkok' });
}

/**
 * แบบฟอร์ม — ออกแบบใบลา / ใบขออนุญาตไปราชการ (เฉพาะผู้ดูแลส่วนกลาง)
 *
 *   แม่แบบกลาง: ใช้ทุกโรงเรียนที่ไม่มีแม่แบบของตัวเอง
 *   แม่แบบเฉพาะโรงเรียน: บันทึกเมื่อแก้ในขอบเขตของโรงเรียนนั้น
 *   ทุกการบันทึก = เวอร์ชันใหม่ ดูประวัติ / ย้อนกลับได้
 *
 * ตัวอย่างวาดด้วยข้อมูลจริงของโรงเรียน (ใบลา / รายการไปราชการ) หรือข้อมูลตัวอย่าง
 */
export default function FormDesignerPage() {
  const [formType, setFormType] = useState<FormType>('leave');
  const [schools, setSchools] = useState<School[]>([]);
  const [scope, setScope] = useState<Scope>('global');
  const [dataSchoolId, setDataSchoolId] = useState<number | null>(null);

  const [draft, setDraft] = useState<FormTemplate>(() => builtInTemplate('leave'));
  const [savedJson, setSavedJson] = useState('');
  const [source, setSource] = useState<TemplateSource>('builtin');
  const [activeVersion, setActiveVersion] = useState<number | null>(null);
  const [versions, setVersions] = useState<TemplateVersion[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const [leaveSource, setLeaveSource] = useState<LeaveFormSource | null>(null);
  const [tripSource, setTripSource] = useState<TripSource | null>(null);
  const [recordId, setRecordId] = useState(SAMPLE);

  const [fit, setFit] = useState<FitInfo | null>(null);
  const [note, setNote] = useState('');
  const [showHistory, setShowHistory] = useState(false);
  const [showPaper, setShowPaper] = useState(false);
  const [message, setMessage] = useState<Message>(null);
  const [busy, setBusy] = useState(false);

  const dirty = savedJson !== '' && JSON.stringify(draft) !== savedJson;
  const scopeSchoolId = scope === 'global' ? null : scope;

  // ── โหลดรายชื่อโรงเรียน ──
  useEffect(() => {
    supabase
      .from('Schools')
      .select('*')
      .order('id_school')
      .then(({ data, error }) => {
        if (error) return setMessage({ text: `โหลดรายชื่อโรงเรียนไม่สำเร็จ: ${error.message}`, error: true });
        setSchools(data as School[]);
        if (data?.length) setDataSchoolId((data[0] as School).id_school);
      });
  }, []);

  // ── โหลดแม่แบบของขอบเขตที่เลือก ──
  const loadTemplate = useCallback(async () => {
    setMessage(null);
    try {
      const [resolved, list] = await Promise.all([
        resolveTemplate(formType, scopeSchoolId),
        listVersions(formType, scopeSchoolId),
      ]);
      setDraft(resolved.template);
      setSavedJson(JSON.stringify(resolved.template));
      setSource(resolved.source);
      setActiveVersion(resolved.version);
      setVersions(list);
      setSelectedId(null);
    } catch (e) {
      setMessage({ text: `โหลดแม่แบบไม่สำเร็จ: ${e instanceof Error ? e.message : e} (รัน form_templates.sql แล้วหรือยัง?)`, error: true });
      const fallback = builtInTemplate(formType);
      setDraft(fallback);
      setSavedJson(JSON.stringify(fallback));
      setSource('builtin');
      setVersions([]);
    }
  }, [formType, scopeSchoolId]);

  useEffect(() => {
    loadTemplate();
  }, [loadTemplate]);

  // ขอบเขตโรงเรียน → ใช้ข้อมูลของโรงเรียนนั้นในตัวอย่าง
  useEffect(() => {
    if (scope !== 'global') setDataSchoolId(scope);
  }, [scope]);

  // ── โหลดข้อมูลตัวอย่าง ──
  useEffect(() => {
    if (dataSchoolId === null) return;
    setRecordId(SAMPLE);
    if (formType === 'leave') {
      setLeaveSource(null);
      loadLeaveFormSource(dataSchoolId)
        .then(setLeaveSource)
        .catch((e) => setMessage({ text: `โหลดใบลาไม่สำเร็จ: ${e.message}`, error: true }));
    } else {
      setTripSource(null);
      loadTripSource(dataSchoolId)
        .then(setTripSource)
        .catch((e) => setMessage({ text: `โหลดรายการไปราชการไม่สำเร็จ: ${e.message} (รัน official_trips.sql แล้วหรือยัง?)`, error: true }));
    }
  }, [formType, dataSchoolId]);

  const context: RenderContext | null = useMemo(() => {
    if (formType === 'leave') {
      if (!leaveSource) return null;
      const leaf: Row =
        recordId === SAMPLE ? sampleLeaf(leaveSource) : leaveSource.leaves.find((l) => String(l.requestId) === recordId) ?? sampleLeaf(leaveSource);
      return leaveContext(
        new LeaveFormData({
          leaf,
          allUsers: leaveSource.users,
          allLeaveRequests: leaveSource.leaves,
          leaveTypeNames: leaveSource.leaveTypeNames,
          school: leaveSource.school,
        }),
      );
    }
    if (!tripSource) return null;
    const trip = recordId === SAMPLE ? sampleTrip(tripSource) : tripSource.trips.find((t) => String(t.id_trip) === recordId) ?? sampleTrip(tripSource);
    return tripContext(trip, tripSource);
  }, [formType, leaveSource, tripSource, recordId]);

  // ตัวอย่างวาดใหม่หลังหยุดพิมพ์ 250 มส. (ไม่ให้ iframe โหลดใหม่ทุกตัวอักษร)
  const [html, setHtml] = useState('');
  useEffect(() => {
    if (!context) return;
    const t = setTimeout(() => setHtml(renderDocument(draft, context, { editor: true, selectedBlockId: selectedId })), 250);
    return () => clearTimeout(t);
  }, [draft, context, selectedId]);

  // ── แก้แม่แบบ ──
  const updateBlock = (b: Block) => setDraft((d) => ({ ...d, blocks: d.blocks.map((x) => (x.id === b.id ? b : x)) }));
  const moveBlock = (i: number, delta: number) =>
    setDraft((d) => {
      const j = i + delta;
      if (j < 0 || j >= d.blocks.length) return d;
      const blocks = [...d.blocks];
      [blocks[i], blocks[j]] = [blocks[j], blocks[i]];
      return { ...d, blocks };
    });
  const addBlock = (type: BlockType) => {
    const b = newBlock(type);
    setDraft((d) => {
      const at = selectedId ? d.blocks.findIndex((x) => x.id === selectedId) + 1 : d.blocks.length;
      const blocks = [...d.blocks];
      blocks.splice(at || d.blocks.length, 0, b);
      return { ...d, blocks };
    });
    setSelectedId(b.id);
  };
  const duplicateBlock = (b: Block) => {
    const copy = { ...JSON.parse(JSON.stringify(b)), id: newBlockId(), builtIn: false, name: `${b.name} (สำเนา)` } as Block;
    setDraft((d) => {
      const i = d.blocks.findIndex((x) => x.id === b.id);
      const blocks = [...d.blocks];
      blocks.splice(i + 1, 0, copy);
      return { ...d, blocks };
    });
    setSelectedId(copy.id);
  };
  const deleteBlock = (id: string) => {
    setDraft((d) => ({ ...d, blocks: d.blocks.filter((b) => b.id !== id) }));
    setSelectedId(null);
  };

  const confirmDiscard = () => !dirty || window.confirm('มีการแก้ไขที่ยังไม่ได้บันทึก — ทิ้งการแก้ไขหรือไม่?');

  // ── บันทึก / เวอร์ชัน ──
  async function save() {
    setBusy(true);
    setMessage(null);
    try {
      const v = await saveVersion(formType, scopeSchoolId, draft, note);
      setNote('');
      await loadTemplate();
      setMessage({
        text: `บันทึกเป็นเวอร์ชัน ${v.version} แล้ว — ${FORM_TYPE_LABEL[formType]}ใน app ใช้แม่แบบนี้ภายใน 5 นาที (หรือทันทีเมื่อเข้าระบบใหม่)`,
      });
    } catch (e) {
      setMessage({ text: `บันทึกไม่สำเร็จ: ${e instanceof Error ? e.message : e}`, error: true });
    } finally {
      setBusy(false);
    }
  }

  async function revertToGlobal() {
    if (scopeSchoolId === null) return;
    if (!window.confirm('ให้โรงเรียนนี้กลับไปใช้แม่แบบกลาง? (แม่แบบเดิมของโรงเรียนยังอยู่ในประวัติ ย้อนกลับได้)')) return;
    setBusy(true);
    try {
      await setSchoolUsesGlobal(formType, scopeSchoolId, note || 'กลับไปใช้แม่แบบกลาง');
      setNote('');
      await loadTemplate();
      setMessage({ text: 'โรงเรียนนี้กลับไปใช้แม่แบบกลางแล้ว' });
    } catch (e) {
      setMessage({ text: `ไม่สำเร็จ: ${e instanceof Error ? e.message : e}`, error: true });
    } finally {
      setBusy(false);
    }
  }

  async function copyFrom(value: string) {
    if (!value || !confirmDiscard()) return;
    try {
      let t: FormTemplate;
      let label: string;
      if (value === 'builtin') {
        t = builtInTemplate(formType);
        label = 'ค่าเริ่มต้นของระบบ';
      } else if (value === 'global') {
        t = (await resolveTemplate(formType, null)).template;
        label = 'แม่แบบกลาง';
      } else {
        const id = Number(value);
        t = (await resolveTemplate(formType, id)).template;
        const s = schools.find((x) => x.id_school === id);
        label = s ? schoolName(s) : `โรงเรียน #${id}`;
      }
      setDraft(cloneTemplate(t));
      setSelectedId(null);
      setMessage({ text: `คัดลอกจาก "${label}" มาแล้ว — ตรวจตัวอย่างแล้วกดบันทึก` });
    } catch (e) {
      setMessage({ text: `คัดลอกไม่สำเร็จ: ${e instanceof Error ? e.message : e}`, error: true });
    }
  }

  function openVersion(v: TemplateVersion) {
    if (v.uses_default) return;
    if (!confirmDiscard()) return;
    setDraft(normalizeTemplate(v.template, builtInTemplate(formType)));
    setSelectedId(null);
    setNote(`ย้อนจากเวอร์ชัน ${v.version}`);
    setMessage({ text: `เปิดเวอร์ชัน ${v.version} มาแก้แล้ว — กดบันทึกเพื่อใช้เป็นเวอร์ชันล่าสุด` });
  }

  function printTest() {
    if (!context) return;
    const w = window.open('', '_blank');
    if (!w) return setMessage({ text: 'เบราว์เซอร์บล็อกหน้าต่างพิมพ์ กรุณาอนุญาต pop-up', error: true });
    w.document.open();
    w.document.write(renderDocument(draft, context, { toolbar: true, autoPrint: true }));
    w.document.close();
  }

  const selected = draft.blocks.find((b) => b.id === selectedId) ?? null;
  const placeholders = formType === 'leave' ? LEAVE_PLACEHOLDERS : TRIP_PLACEHOLDERS;
  const flags = formType === 'leave' ? LEAVE_FLAGS : TRIP_FLAGS;
  const records: { id: string; label: string }[] =
    formType === 'leave'
      ? (leaveSource?.leaves ?? []).slice(0, 200).map((l) => ({
          id: String(l.requestId),
          label: `${l.fullName || '-'} · ${l.leaveType || '-'} · ${formatThaiDate(l.startDate)}`,
        }))
      : (tripSource?.trips ?? []).map((t) => ({ id: String(t.id_trip), label: `${t.title} · ${t.startDate}` }));

  return (
    <>
      <PageHeader
        title="แบบฟอร์ม"
        description="ออกแบบใบลา / บันทึกไปราชการ ที่แอปใช้พิมพ์ — แก้แม่แบบกลาง หรือแม่แบบเฉพาะโรงเรียน"
        actions={
          <div className="seg">
            {(Object.keys(FORM_TYPE_LABEL) as FormType[]).map((t) => (
              <button
                key={t}
                className={formType === t ? 'active' : ''}
                onClick={() => {
                  if (t !== formType && confirmDiscard()) setFormType(t);
                }}
              >
                {FORM_TYPE_LABEL[t]}
              </button>
            ))}
          </div>
        }
      />

      {/* มือถือ: ใช้ดูตัวอย่างได้ แต่ออกแบบบนจอคอมจะสะดวกกว่ามาก */}
      <div className="alert-info mb-4 text-[13px] lg:hidden">
        หน้านี้ออกแบบบนจอคอมจะสะดวกที่สุด — บนมือถือใช้ดูตัวอย่าง / ทดลองพิมพ์ได้
      </div>

      {/* แถบเครื่องมือ */}
      <section className="card mb-4 p-4 sm:px-5">
        <div className="flex flex-col gap-3 xl:flex-row xl:items-end">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-end">
            <Field label="แก้แม่แบบของ" className="sm:w-64">
              <select
                className="input"
                value={scope === 'global' ? 'global' : String(scope)}
                onChange={(e) => {
                  if (!confirmDiscard()) return;
                  setScope(e.target.value === 'global' ? 'global' : Number(e.target.value));
                }}
              >
                <option value="global">แม่แบบกลาง (ทุกโรงเรียน)</option>
                {schools.map((s) => (
                  <option key={s.id_school} value={s.id_school}>
                    {schoolName(s)}
                  </option>
                ))}
              </select>
            </Field>
            <div className="flex flex-wrap items-center gap-2 pb-1.5">
              <span className={source === 'school' ? 'badge-green' : 'badge-slate'}>
                {scope === 'global' ? (source === 'builtin' ? SOURCE_LABEL.builtin : 'แม่แบบกลาง') : SOURCE_LABEL[source]}
                {activeVersion !== null && ` · เวอร์ชัน ${activeVersion}`}
              </span>
              {dirty && <span className="badge-amber">● ยังไม่ได้บันทึก</span>}
            </div>
          </div>

          <div className="flex flex-1 flex-wrap items-end justify-end gap-2">
            <select className="input w-auto" value="" onChange={(e) => copyFrom(e.target.value)} aria-label="คัดลอกแม่แบบ">
              <option value="">คัดลอกแม่แบบจาก...</option>
              <option value="builtin">ค่าเริ่มต้นของระบบ</option>
              {scope !== 'global' && <option value="global">แม่แบบกลาง</option>}
              {schools
                .filter((s) => s.id_school !== scope)
                .map((s) => (
                  <option key={s.id_school} value={s.id_school}>
                    {schoolName(s)}
                  </option>
                ))}
            </select>
            <button className="btn-secondary" onClick={() => setShowHistory(!showHistory)}>
              ประวัติ ({versions.length})
            </button>
            {scope !== 'global' && source === 'school' && (
              <button className="btn-secondary" disabled={busy} onClick={revertToGlobal}>
                ใช้แม่แบบกลาง
              </button>
            )}
            <input
              className="input w-full sm:w-56"
              placeholder="หมายเหตุการบันทึก (ไม่บังคับ)"
              value={note}
              onChange={(e) => setNote(e.target.value)}
            />
            <button
              className="btn-primary"
              disabled={busy || (!dirty && source !== 'builtin' && !(scope !== 'global' && source === 'global'))}
              onClick={save}
            >
              {scope === 'global' ? 'บันทึกแม่แบบกลาง' : 'บันทึกสำหรับโรงเรียนนี้'}
            </button>
          </div>
        </div>
      </section>

      {scope !== 'global' && source === 'global' && (
        <div className="alert-info mb-4">
          โรงเรียนนี้ใช้แม่แบบกลางอยู่ — แก้แล้วกดบันทึก จะกลายเป็นแม่แบบเฉพาะโรงเรียนนี้ (โรงเรียนอื่นไม่เปลี่ยน)
        </div>
      )}
      {scope === 'global' && source === 'builtin' && (
        <div className="alert-info mb-4">
          ยังไม่เคยบันทึกแม่แบบกลางลงฐานข้อมูล — กด "บันทึกแม่แบบกลาง" หนึ่งครั้ง เพื่อให้ app ดึงไปใช้ได้
        </div>
      )}
      <Notice message={message} />

      {showHistory && (
        <section className="card mb-4 overflow-hidden">
          <div className="card-title">ประวัติเวอร์ชัน — {scope === 'global' ? 'แม่แบบกลาง' : 'โรงเรียนนี้'}</div>
          {versions.length === 0 ? (
            <EmptyState>ยังไม่มีการบันทึก</EmptyState>
          ) : (
            <div className="overflow-x-auto">
              <table className="table">
                <thead>
                  <tr>
                    <th>เวอร์ชัน</th>
                    <th>เมื่อ</th>
                    <th>หมายเหตุ</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {versions.map((v) => (
                    <tr key={v.id_template}>
                      <td className="whitespace-nowrap">
                        <b>{v.version}</b>
                        {v.version === versions[0].version && <span className="badge-green ml-1.5">ล่าสุด</span>}
                      </td>
                      <td className="whitespace-nowrap">{thaiDateTime(v.createdAt)}</td>
                      <td>{v.uses_default ? <i>กลับไปใช้แม่แบบกลาง</i> : v.note ?? '-'}</td>
                      <td className="text-right">
                        {!v.uses_default && (
                          <button className="btn-secondary btn-sm" onClick={() => openVersion(v)}>
                            เปิดเวอร์ชันนี้
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      )}

      <div className="grid items-start gap-4 lg:grid-cols-[400px_minmax(0,1fr)] xl:grid-cols-[430px_minmax(0,1fr)]">
        {/* ซ้าย: กระดาษ / รายการบรรทัด / ตัวแก้ */}
        <div className="flex min-w-0 flex-col gap-4">
          <section className="card p-4">
            <button
              className="flex w-full items-center gap-2 text-left text-[13.5px] font-semibold hover:text-brand-700"
              onClick={() => setShowPaper(!showPaper)}
            >
              <span className="text-slate-400">{showPaper ? '▾' : '▸'}</span>
              กระดาษ — {draft.paper.size === 'custom' ? 'กำหนดเอง' : draft.paper.size}{' '}
              {draft.paper.orientation === 'portrait' ? 'แนวตั้ง' : 'แนวนอน'} · {draft.paper.fontSizePt} pt
            </button>
            {showPaper && (
              <div className="mt-3">
                <PaperEditor paper={draft.paper} onChange={(paper) => setDraft((d) => ({ ...d, paper }))} />
              </div>
            )}
          </section>

          <section className="card overflow-hidden">
            <div className="card-title">
              บรรทัด ({draft.blocks.length})
              <select
                className="input w-auto py-1.5 text-[13px]"
                value=""
                onChange={(e) => e.target.value && addBlock(e.target.value as BlockType)}
                aria-label="เพิ่มบรรทัด"
              >
                <option value="">+ เพิ่มบรรทัด</option>
                {ADDABLE_BLOCKS[formType].map((t) => (
                  <option key={t} value={t}>
                    {BLOCK_TYPE_LABEL[t]}
                  </option>
                ))}
              </select>
            </div>
            <ol className="flex max-h-[46vh] flex-col gap-0.5 overflow-y-auto px-2 pb-2">
              {draft.blocks.map((b, i) => {
                const active = b.id === selectedId;
                return (
                  <li
                    key={b.id}
                    className={`flex items-center gap-0.5 rounded-lg pr-1 ${active ? 'bg-brand-50' : 'hover:bg-slate-50'}`}
                  >
                    <button
                      className="flex min-w-0 flex-1 flex-col items-start px-2.5 py-1.5 text-left"
                      onClick={() => setSelectedId(active ? null : b.id)}
                    >
                      <span
                        className={`truncate text-[13px] font-semibold ${active ? 'text-brand-700' : ''} ${
                          b.visible ? '' : 'text-slate-400 line-through'
                        }`}
                      >
                        <span className="mr-1 font-normal text-slate-400">{i + 1}.</span>
                        {b.name}
                      </span>
                      <span className="text-xs text-slate-500">
                        {BLOCK_TYPE_LABEL[b.type]}
                        {b.visible ? '' : ' · ซ่อนอยู่'}
                      </span>
                    </button>
                    {[
                      { t: b.visible ? 'ซ่อน' : 'แสดง', s: b.visible ? '👁' : '◌', f: () => updateBlock({ ...b, visible: !b.visible }) },
                      { t: 'เลื่อนขึ้น', s: '↑', f: () => moveBlock(i, -1) },
                      { t: 'เลื่อนลง', s: '↓', f: () => moveBlock(i, 1) },
                      ...(b.type !== 'approval' && b.type !== 'leaveTypes' && b.type !== 'header'
                        ? [{ t: 'ทำสำเนา', s: '⧉', f: () => duplicateBlock(b) }]
                        : []),
                    ].map((a) => (
                      <button
                        key={a.t}
                        title={a.t}
                        aria-label={a.t}
                        className="rounded-md px-1.5 py-1 text-sm text-slate-500 hover:bg-slate-200 hover:text-ink"
                        onClick={a.f}
                      >
                        {a.s}
                      </button>
                    ))}
                  </li>
                );
              })}
            </ol>
          </section>

          {selected && (
            <section className="card p-4">
              <BlockEditor
                key={selected.id}
                block={selected}
                onChange={updateBlock}
                onDelete={selected.builtIn ? undefined : () => deleteBlock(selected.id)}
                placeholders={placeholders}
                flags={flags}
              />
              {selected.builtIn && (
                <p className="field-hint mt-2">บรรทัดของแม่แบบเริ่มต้น ลบไม่ได้ แต่ซ่อนได้ (ปุ่ม 👁)</p>
              )}
            </section>
          )}
        </div>

        {/* ขวา: ตัวอย่างเอกสาร */}
        <div className="min-w-0 lg:sticky lg:top-[72px]">
          <section className="card mb-3 p-4">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-end">
              <Field label="ข้อมูลตัวอย่างจาก" className="sm:w-56">
                <select
                  className="input"
                  value={dataSchoolId ?? ''}
                  disabled={scope !== 'global'}
                  onChange={(e) => setDataSchoolId(Number(e.target.value))}
                >
                  {schools.map((s) => (
                    <option key={s.id_school} value={s.id_school}>
                      {schoolName(s)}
                    </option>
                  ))}
                </select>
              </Field>
              <Field label={formType === 'leave' ? 'ใบลา' : 'รายการไปราชการ'} className="min-w-0 flex-1">
                <select className="input" value={recordId} onChange={(e) => setRecordId(e.target.value)}>
                  <option value={SAMPLE}>ข้อมูลตัวอย่าง (สมมติ)</option>
                  {records.map((r) => (
                    <option key={r.id} value={r.id}>
                      {r.label}
                    </option>
                  ))}
                </select>
              </Field>
              <button className="btn-secondary" disabled={!context} onClick={printTest}>
                ทดลองพิมพ์ / PDF
              </button>
            </div>
          </section>

          {fit && (fit.overflowPx > 1 || fit.overflowWidthPx > 1) && (
            <div className="alert-error mb-3 text-[13px]">
              เนื้อหา{fit.overflowPx > 1 ? `สูงเกินหน้ากระดาษ ${Math.ceil(fit.overflowPx / 3.78)} มม.` : ''}
              {fit.overflowWidthPx > 1 ? ` กว้างเกินกระดาษ ${Math.ceil(fit.overflowWidthPx / 3.78)} มม.` : ''} — พิมพ์แล้วจะ
              {fit.overflowPx > 1 ? 'ขึ้นหน้าใหม่' : 'ล้นขอบ'} ลดระยะเว้น / ขนาดตัวอักษร หรือเปิด "ย่อให้พอดีกระดาษ" ในตั้งค่ากระดาษ
            </div>
          )}
          {fit && fit.fitScale < 1 && (
            <div className="alert-ok mb-3 text-[13px]">
              ย่ออัตโนมัติเหลือ {Math.round(fit.fitScale * 100)}% ให้พอดีกระดาษหน้าเดียว
            </div>
          )}

          {html ? (
            <PreviewFrame html={html} onSelectBlock={setSelectedId} onFit={setFit} />
          ) : (
            <div className="card">
              <EmptyState>กำลังโหลดข้อมูลตัวอย่าง...</EmptyState>
            </div>
          )}
          <p className="field-hint mt-2">กดที่บรรทัดบนเอกสารเพื่อเลือกมาแก้</p>
        </div>
      </div>
    </>
  );
}
