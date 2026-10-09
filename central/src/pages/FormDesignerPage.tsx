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
        text:
          formType === 'leave'
            ? `บันทึกเป็นเวอร์ชัน ${v.version} แล้ว — ใบลาใน app ใช้แม่แบบนี้ภายใน 5 นาที (หรือทันทีเมื่อเข้าระบบใหม่)`
            : `บันทึกเป็นเวอร์ชัน ${v.version} แล้ว — app จะใช้แม่แบบนี้เมื่อเชื่อมต่อเสร็จ`,
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
      <div className="row">
        <h1>แบบฟอร์ม</h1>
        <div className="seg-tabs">
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
      </div>

      <div className="card fd-toolbar">
        <label className="fd-field">
          <span>แก้แม่แบบของ</span>
          <select
            value={scope === 'global' ? 'global' : String(scope)}
            onChange={(e) => {
              if (!confirmDiscard()) return;
              setScope(e.target.value === 'global' ? 'global' : Number(e.target.value));
            }}
          >
            <option value="global">แม่แบบกลาง (ทุกโรงเรียน)</option>
            {schools.map((s) => (
              <option key={s.id_school} value={s.id_school}>{schoolName(s)}</option>
            ))}
          </select>
        </label>
        <div className="fd-status">
          <span className={`badge ${source === 'school' ? 'on' : ''}`}>
            {scope === 'global' ? (source === 'builtin' ? SOURCE_LABEL.builtin : 'แม่แบบกลาง') : SOURCE_LABEL[source]}
            {activeVersion !== null && ` · เวอร์ชัน ${activeVersion}`}
          </span>
          {dirty && <span className="warn">● ยังไม่ได้บันทึก</span>}
        </div>
        <span className="spacer" />
        <select value="" onChange={(e) => copyFrom(e.target.value)}>
          <option value="">คัดลอกแม่แบบจาก...</option>
          <option value="builtin">ค่าเริ่มต้นของระบบ</option>
          {scope !== 'global' && <option value="global">แม่แบบกลาง</option>}
          {schools.filter((s) => s.id_school !== scope).map((s) => (
            <option key={s.id_school} value={s.id_school}>{schoolName(s)}</option>
          ))}
        </select>
        <button className="secondary" onClick={() => setShowHistory(!showHistory)}>ประวัติ ({versions.length})</button>
        {scope !== 'global' && source === 'school' && (
          <button className="secondary" disabled={busy} onClick={revertToGlobal}>ใช้แม่แบบกลาง</button>
        )}
        <input className="note-input" placeholder="หมายเหตุการบันทึก (ไม่บังคับ)" value={note} onChange={(e) => setNote(e.target.value)} />
        <button disabled={busy || (!dirty && source !== 'builtin' && !(scope !== 'global' && source === 'global'))} onClick={save}>
          {scope === 'global' ? 'บันทึกแม่แบบกลาง' : 'บันทึกสำหรับโรงเรียนนี้'}
        </button>
      </div>

      {scope !== 'global' && source === 'global' && (
        <div className="ok">โรงเรียนนี้ใช้แม่แบบกลางอยู่ — แก้แล้วกดบันทึก จะกลายเป็นแม่แบบเฉพาะโรงเรียนนี้ (โรงเรียนอื่นไม่เปลี่ยน)</div>
      )}
      {scope === 'global' && source === 'builtin' && (
        <div className="ok">ยังไม่เคยบันทึกแม่แบบกลางลงฐานข้อมูล — กด "บันทึกแม่แบบกลาง" หนึ่งครั้ง เพื่อให้ app ดึงไปใช้ได้</div>
      )}
      {message && <div className={message.error ? 'error' : 'ok'}>{message.text}</div>}

      {showHistory && (
        <div className="card">
          <h3>ประวัติเวอร์ชัน — {scope === 'global' ? 'แม่แบบกลาง' : 'โรงเรียนนี้'}</h3>
          {versions.length === 0 ? (
            <p className="muted">ยังไม่มีการบันทึก</p>
          ) : (
            <table>
              <thead>
                <tr><th>เวอร์ชัน</th><th>เมื่อ</th><th>หมายเหตุ</th><th /></tr>
              </thead>
              <tbody>
                {versions.map((v) => (
                  <tr key={v.id_template}>
                    <td><b>{v.version}</b>{v.version === versions[0].version && <span className="badge on" style={{ marginLeft: 6 }}>ล่าสุด</span>}</td>
                    <td>{thaiDateTime(v.createdAt)}</td>
                    <td>{v.uses_default ? <i>กลับไปใช้แม่แบบกลาง</i> : v.note ?? '-'}</td>
                    <td className="num">
                      {!v.uses_default && (
                        <button className="secondary small" onClick={() => openVersion(v)}>เปิดเวอร์ชันนี้</button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}

      <div className="fd-layout">
        <div className="fd-side">
          <div className="card">
            <button className="fd-section-btn" onClick={() => setShowPaper(!showPaper)}>
              {showPaper ? '▾' : '▸'} กระดาษ — {draft.paper.size === 'custom' ? 'กำหนดเอง' : draft.paper.size}{' '}
              {draft.paper.orientation === 'portrait' ? 'แนวตั้ง' : 'แนวนอน'} · {draft.paper.fontSizePt} pt
            </button>
            {showPaper && <PaperEditor paper={draft.paper} onChange={(paper) => setDraft((d) => ({ ...d, paper }))} />}
          </div>

          <div className="card">
            <div className="row" style={{ marginBottom: 8 }}>
              <h3 style={{ margin: 0 }}>บรรทัด ({draft.blocks.length})</h3>
              <select value="" onChange={(e) => e.target.value && addBlock(e.target.value as BlockType)}>
                <option value="">+ เพิ่มบรรทัด</option>
                {ADDABLE_BLOCKS[formType].map((t) => (
                  <option key={t} value={t}>{BLOCK_TYPE_LABEL[t]}</option>
                ))}
              </select>
            </div>
            <ol className="block-list">
              {draft.blocks.map((b, i) => (
                <li key={b.id} className={`${b.id === selectedId ? 'active' : ''} ${b.visible ? '' : 'hidden-block'}`}>
                  <button className="block-name" onClick={() => setSelectedId(b.id === selectedId ? null : b.id)}>
                    <span className="muted small">{i + 1}.</span> {b.name}
                    <small>{BLOCK_TYPE_LABEL[b.type]}{b.visible ? '' : ' · ซ่อนอยู่'}</small>
                  </button>
                  <button className="icon-btn" title={b.visible ? 'ซ่อน' : 'แสดง'} onClick={() => updateBlock({ ...b, visible: !b.visible })}>
                    {b.visible ? '👁' : '◌'}
                  </button>
                  <button className="icon-btn" title="เลื่อนขึ้น" onClick={() => moveBlock(i, -1)}>↑</button>
                  <button className="icon-btn" title="เลื่อนลง" onClick={() => moveBlock(i, 1)}>↓</button>
                  {b.type !== 'approval' && b.type !== 'leaveTypes' && b.type !== 'header' && (
                    <button className="icon-btn" title="ทำสำเนา" onClick={() => duplicateBlock(b)}>⧉</button>
                  )}
                </li>
              ))}
            </ol>
          </div>

          {selected && (
            <div className="card">
              <BlockEditor
                key={selected.id}
                block={selected}
                onChange={updateBlock}
                onDelete={selected.builtIn ? undefined : () => deleteBlock(selected.id)}
                placeholders={placeholders}
                flags={flags}
              />
              {selected.builtIn && <p className="muted small">บรรทัดของแม่แบบเริ่มต้น ลบไม่ได้ แต่ซ่อนได้ (ปุ่ม 👁)</p>}
            </div>
          )}
        </div>

        <div className="fd-preview">
          <div className="card fd-preview-bar">
            <label className="fd-field">
              <span>ข้อมูลตัวอย่างจาก</span>
              <select value={dataSchoolId ?? ''} disabled={scope !== 'global'} onChange={(e) => setDataSchoolId(Number(e.target.value))}>
                {schools.map((s) => (
                  <option key={s.id_school} value={s.id_school}>{schoolName(s)}</option>
                ))}
              </select>
            </label>
            <label className="fd-field grow">
              <span>{formType === 'leave' ? 'ใบลา' : 'รายการไปราชการ'}</span>
              <select value={recordId} onChange={(e) => setRecordId(e.target.value)}>
                <option value={SAMPLE}>ข้อมูลตัวอย่าง (สมมติ)</option>
                {records.map((r) => (
                  <option key={r.id} value={r.id}>{r.label}</option>
                ))}
              </select>
            </label>
            <button className="secondary" disabled={!context} onClick={printTest}>ทดลองพิมพ์ / PDF</button>
          </div>

          {fit && (fit.overflowPx > 1 || fit.overflowWidthPx > 1) && (
            <div className="error">
              เนื้อหา{fit.overflowPx > 1 ? `สูงเกินหน้ากระดาษ ${Math.ceil(fit.overflowPx / 3.78)} มม.` : ''}
              {fit.overflowWidthPx > 1 ? ` กว้างเกินกระดาษ ${Math.ceil(fit.overflowWidthPx / 3.78)} มม.` : ''} — พิมพ์แล้วจะ
              {fit.overflowPx > 1 ? 'ขึ้นหน้าใหม่' : 'ล้นขอบ'} ลดระยะเว้น / ขนาดตัวอักษร หรือเปิด "ย่อให้พอดีกระดาษ" ในตั้งค่ากระดาษ
            </div>
          )}
          {fit && fit.fitScale < 1 && (
            <div className="ok">ย่ออัตโนมัติเหลือ {Math.round(fit.fitScale * 100)}% ให้พอดีกระดาษหน้าเดียว</div>
          )}

          {html ? (
            <PreviewFrame html={html} onSelectBlock={setSelectedId} onFit={setFit} />
          ) : (
            <div className="card muted">กำลังโหลดข้อมูลตัวอย่าง...</div>
          )}
          <p className="muted small">กดที่บรรทัดบนเอกสารเพื่อเลือกมาแก้</p>
        </div>
      </div>
    </>
  );
}
