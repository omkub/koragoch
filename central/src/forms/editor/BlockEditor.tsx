import { BLOCK_DEFAULT_SPACE_PX } from '../render';
import {
  BLOCK_TYPE_LABEL,
  pxToMm,
  type Align,
  type Block,
  type FlagOption,
  type Placeholder,
  type Segment,
} from '../template';
import { Field, LinesEditor, NumberInput, PlaceholderBar, TextInput, Toggle } from './inputs';

interface Props {
  block: Block;
  onChange: (b: Block) => void;
  onDelete?: () => void;
  placeholders: Placeholder[];
  flags: FlagOption[];
}

const ALIGN_OPTIONS: { value: Align | ''; label: string }[] = [
  { value: '', label: 'ค่าเดิม' },
  { value: 'left', label: 'ชิดซ้าย' },
  { value: 'center', label: 'กึ่งกลาง' },
  { value: 'right', label: 'ชิดขวา' },
  { value: 'justify', label: 'เต็มบรรทัด' },
];

/** ตั้งค่าบรรทัดที่เลือก — เนื้อหาตามชนิด + ตำแหน่ง / ระยะ / ตัวอักษร */
export default function BlockEditor({ block, onChange, onDelete, placeholders, flags }: Props) {
  const set = <K extends keyof Block>(key: K, value: Block[K]) => onChange({ ...block, [key]: value } as Block);
  const [defBefore, defAfter] = BLOCK_DEFAULT_SPACE_PX[block.type];
  const hint = (px: number) => `ค่าเดิม ${Math.round(pxToMm(px) * 100) / 100}`;

  return (
    <div className="block-editor">
      <div className="row" style={{ marginBottom: 8 }}>
        <h3 style={{ margin: 0 }}>{BLOCK_TYPE_LABEL[block.type]}</h3>
        {onDelete && (
          <button type="button" className="secondary small danger" onClick={onDelete}>ลบบรรทัดนี้</button>
        )}
      </div>
      <Field label="ชื่อบรรทัด (แสดงในรายการเท่านั้น)">
        <input value={block.name} onChange={(e) => set('name', e.target.value)} />
      </Field>

      <fieldset>
        <legend>เนื้อหา</legend>
        <PlaceholderBar items={placeholders} />
        <ContentEditor block={block} onChange={onChange} flags={flags} />
      </fieldset>

      <fieldset>
        <legend>ตำแหน่งและระยะ</legend>
        <div className="fd-grid">
          <Field label="เว้นก่อนบรรทัด">
            <NumberInput nullable value={block.spaceBeforeMm} onChange={(v) => set('spaceBeforeMm', v)} defaultHint={hint(defBefore)} />
          </Field>
          <Field label="เว้นหลังบรรทัด">
            <NumberInput nullable value={block.spaceAfterMm} onChange={(v) => set('spaceAfterMm', v)} defaultHint={hint(defAfter)} />
          </Field>
          <Field label="ความสูงอย่างน้อย">
            <NumberInput nullable value={block.minHeightMm} onChange={(v) => set('minHeightMm', v)} defaultHint="อัตโนมัติ" />
          </Field>
          <Field label="ย่อหน้าซ้าย">
            <NumberInput nullable value={block.indentMm} onChange={(v) => set('indentMm', v)} defaultHint="0" />
          </Field>
          <Field label="ขยับซ้าย-ขวา" hint="ลบ = ไปทางซ้าย">
            <NumberInput value={block.offsetXMm} onChange={(v) => set('offsetXMm', v ?? 0)} />
          </Field>
          <Field label="ขยับขึ้น-ลง" hint="ลบ = ขึ้นบน">
            <NumberInput value={block.offsetYMm} onChange={(v) => set('offsetYMm', v ?? 0)} />
          </Field>
          {block.type !== 'spacer' && (
            <Field label="จัดแนว">
              <select value={block.align ?? ''} onChange={(e) => set('align', (e.target.value || null) as Align | null)}>
                {ALIGN_OPTIONS.map((o) => (
                  <option key={o.value} value={o.value}>{o.label}</option>
                ))}
              </select>
            </Field>
          )}
        </div>
      </fieldset>

      {block.type !== 'spacer' && (
        <fieldset>
          <legend>ตัวอักษร</legend>
          <div className="fd-grid">
            <Field label="ขนาด">
              <NumberInput nullable value={block.fontSizePt} onChange={(v) => set('fontSizePt', v)} defaultHint="ตามกระดาษ" suffix="pt" />
            </Field>
            <Toggle checked={block.bold} onChange={(v) => set('bold', v)} label="ตัวหนาทั้งบรรทัด" />
            <Toggle checked={block.underline} onChange={(v) => set('underline', v)} label="ขีดเส้นใต้" />
          </div>
        </fieldset>
      )}
    </div>
  );
}

function ContentEditor({ block, onChange, flags }: { block: Block; onChange: (b: Block) => void; flags: FlagOption[] }) {
  switch (block.type) {
    case 'row':
      return <SegmentsEditor segments={block.segments} flags={flags} onChange={(segments) => onChange({ ...block, segments })} />;

    case 'textBox':
      return (
        <>
          <LinesEditor lines={block.lines} onChange={(lines) => onChange({ ...block, lines })} />
          <div className="fd-grid">
            <Field label="ความกว้างกล่อง">
              <NumberInput nullable value={block.boxWidthMm} onChange={(v) => onChange({ ...block, boxWidthMm: v })} defaultHint="เต็มบรรทัด" />
            </Field>
            <BoxPosition value={block.boxPosition} onChange={(boxPosition) => onChange({ ...block, boxPosition })} />
            <Field label="ย่อหน้าบรรทัดแรก">
              <NumberInput value={block.firstLineIndentMm} onChange={(v) => onChange({ ...block, firstLineIndentMm: v ?? 0 })} />
            </Field>
          </div>
        </>
      );

    case 'signature':
      return (
        <>
          <LinesEditor lines={block.lines} onChange={(lines) => onChange({ ...block, lines })} />
          <div className="fd-grid">
            <Field label="ความกว้างกล่อง">
              <NumberInput nullable value={block.boxWidthMm} onChange={(v) => onChange({ ...block, boxWidthMm: v })} defaultHint="เต็มบรรทัด" />
            </Field>
            <BoxPosition value={block.boxPosition} onChange={(boxPosition) => onChange({ ...block, boxPosition })} />
          </div>
        </>
      );

    case 'header':
      return (
        <>
          <Field label="ชื่อแบบฟอร์ม">
            <TextInput value={block.title} onChange={(title) => onChange({ ...block, title })} />
          </Field>
          <Field label="บรรทัดรอง">
            <TextInput value={block.subtitle} onChange={(subtitle) => onChange({ ...block, subtitle })} placeholder="(ไม่มี)" />
          </Field>
          <Toggle checked={block.showReceiveBox} onChange={(showReceiveBox) => onChange({ ...block, showReceiveBox })} label='แสดงกล่อง "รับที่" มุมขวา' />
          {block.showReceiveBox && (
            <LinesEditor lines={block.receiveLines} onChange={(receiveLines) => onChange({ ...block, receiveLines })} />
          )}
        </>
      );

    case 'leaveTypes':
      return (
        <>
          <p className="muted small">ช่องติ๊กดึงจากตารางประเภทการลา (LeaveTypes) อัตโนมัติ</p>
          <div className="fd-grid">
            <Field label="คำนำหน้า">
              <TextInput value={block.label} onChange={(label) => onChange({ ...block, label })} />
            </Field>
            <Field label="คำนำเหตุผล">
              <TextInput value={block.reasonLabel} onChange={(reasonLabel) => onChange({ ...block, reasonLabel })} />
            </Field>
          </div>
          <Toggle checked={block.showBrace} onChange={(showBrace) => onChange({ ...block, showBrace })} label="แสดงปีกกา" />
        </>
      );

    case 'approval':
      return (
        <>
          <Toggle checked={block.showStats} onChange={(showStats) => onChange({ ...block, showStats })} label="แสดงตารางสถิติวันลา" />
          {block.showStats && (
            <Field label="หัวตารางสถิติ">
              <TextInput value={block.statsTitle} onChange={(statsTitle) => onChange({ ...block, statsTitle })} />
            </Field>
          )}
          <SubLines title="ช่องเซ็นหัวหน้ากลุ่มบริหารงานบุคคล (ซ้าย)" lines={block.hrLines} onChange={(hrLines) => onChange({ ...block, hrLines })} />
          <SubLines title="ช่องเซ็นผู้ลา (ขวาบน)" lines={block.applicantLines} onChange={(applicantLines) => onChange({ ...block, applicantLines })} />
          <Toggle checked={block.showComment} onChange={(showComment) => onChange({ ...block, showComment })} label="แสดงช่องความคิดเห็น" />
          {block.showComment && (
            <Field label="หัวข้อความคิดเห็น">
              <TextInput value={block.commentLabel} onChange={(commentLabel) => onChange({ ...block, commentLabel })} />
            </Field>
          )}
          <SubLines title="ช่องเซ็นรองผู้อำนวยการ" lines={block.deputyLines} onChange={(deputyLines) => onChange({ ...block, deputyLines })} />
          <Toggle checked={block.showOrder} onChange={(showOrder) => onChange({ ...block, showOrder })} label="แสดงช่องคำสั่ง" />
          {block.showOrder && (
            <>
              <Field label="หัวข้อคำสั่ง">
                <TextInput value={block.orderLabel} onChange={(orderLabel) => onChange({ ...block, orderLabel })} />
              </Field>
              <SubLines title="ตัวเลือกคำสั่ง (ช่องติ๊ก)" lines={block.orderOptions} onChange={(orderOptions) => onChange({ ...block, orderOptions })} />
            </>
          )}
          <SubLines title="ช่องเซ็นผู้อำนวยการ" lines={block.directorLines} onChange={(directorLines) => onChange({ ...block, directorLines })} />
        </>
      );

    case 'memberTable':
      return (
        <>
          <p className="muted small">รายชื่อดึงจากผู้ร่วมเดินทางของรายการไปราชการ (ผู้ขอเป็นคนแรก)</p>
          <div className="fd-grid">
            <Field label="หัวคอลัมน์ลำดับ">
              <TextInput value={block.headers.no} onChange={(no) => onChange({ ...block, headers: { ...block.headers, no } })} />
            </Field>
            <Field label="หัวคอลัมน์ชื่อ">
              <TextInput value={block.headers.name} onChange={(name) => onChange({ ...block, headers: { ...block.headers, name } })} />
            </Field>
            <Field label="หัวคอลัมน์ตำแหน่ง">
              <TextInput value={block.headers.position} onChange={(position) => onChange({ ...block, headers: { ...block.headers, position } })} />
            </Field>
            <Field label="หัวคอลัมน์ลายมือชื่อ">
              <TextInput value={block.headers.signature} onChange={(signature) => onChange({ ...block, headers: { ...block.headers, signature } })} />
            </Field>
          </div>
          <Toggle checked={block.showPosition} onChange={(showPosition) => onChange({ ...block, showPosition })} label="แสดงคอลัมน์ตำแหน่ง" />
          <Toggle checked={block.showSignature} onChange={(showSignature) => onChange({ ...block, showSignature })} label="แสดงคอลัมน์ลายมือชื่อ" />
        </>
      );

    case 'spacer':
      return (
        <Field label="ความสูงที่ว่าง">
          <NumberInput value={block.heightMm} min={0} onChange={(v) => onChange({ ...block, heightMm: v ?? 0 })} />
        </Field>
      );
  }
}

function SubLines({ title, lines, onChange }: { title: string; lines: string[]; onChange: (v: string[]) => void }) {
  return (
    <div className="sub-lines">
      <div className="small" style={{ fontWeight: 600, margin: '10px 0 4px' }}>{title}</div>
      <LinesEditor lines={lines} onChange={onChange} />
    </div>
  );
}

function BoxPosition({ value, onChange }: { value: 'left' | 'center' | 'right'; onChange: (v: 'left' | 'center' | 'right') => void }) {
  return (
    <Field label="ตำแหน่งกล่อง">
      <select value={value} onChange={(e) => onChange(e.target.value as 'left' | 'center' | 'right')}>
        <option value="left">ชิดซ้าย</option>
        <option value="center">กึ่งกลาง</option>
        <option value="right">ชิดขวา</option>
      </select>
    </Field>
  );
}

// ── ส่วนย่อยของบรรทัดข้อความ ───────────────────────────────────

const SEGMENT_LABEL: Record<Segment['kind'], string> = {
  text: 'ข้อความ',
  field: 'ช่องกรอก',
  checkbox: 'ช่องติ๊ก',
};

function SegmentsEditor({ segments, onChange, flags }: { segments: Segment[]; onChange: (s: Segment[]) => void; flags: FlagOption[] }) {
  const set = (i: number, s: Segment) => onChange(segments.map((x, j) => (j === i ? s : x)));
  const move = (i: number, d: number) => {
    const j = i + d;
    if (j < 0 || j >= segments.length) return;
    const next = [...segments];
    [next[i], next[j]] = [next[j], next[i]];
    onChange(next);
  };
  const convert = (s: Segment, kind: Segment['kind']): Segment => {
    const label = s.kind === 'checkbox' ? s.label : s.text;
    if (kind === 'text') return { kind, text: label };
    if (kind === 'field') return { kind, text: label, widthMm: null };
    return { kind, label, flag: flags[flags.length - 1]?.key ?? '' };
  };

  return (
    <div className="segments">
      <p className="muted small">บรรทัดนี้ประกอบจากส่วนย่อยเรียงจากซ้ายไปขวา</p>
      {segments.map((s, i) => (
        <div key={i} className="segment">
          <div className="segment-head">
            <select value={s.kind} onChange={(e) => set(i, convert(s, e.target.value as Segment['kind']))}>
              {(Object.keys(SEGMENT_LABEL) as Segment['kind'][]).map((k) => (
                <option key={k} value={k}>{SEGMENT_LABEL[k]}</option>
              ))}
            </select>
            <span className="spacer" />
            <button type="button" className="icon-btn" title="ไปทางซ้าย" onClick={() => move(i, -1)}>←</button>
            <button type="button" className="icon-btn" title="ไปทางขวา" onClick={() => move(i, 1)}>→</button>
            <button type="button" className="icon-btn danger" title="ลบ" onClick={() => onChange(segments.filter((_, j) => j !== i))}>✕</button>
          </div>
          {s.kind === 'text' && (
            <>
              <TextInput value={s.text} onChange={(text) => set(i, { ...s, text })} />
              <div className="seg-opts">
                <Toggle checked={!!s.bold} onChange={(bold) => set(i, { ...s, bold })} label="ตัวหนา" />
                <Toggle checked={!!s.nowrap} onChange={(nowrap) => set(i, { ...s, nowrap })} label="ห้ามตัดบรรทัด" />
              </div>
            </>
          )}
          {s.kind === 'field' && (
            <>
              <TextInput value={s.text} onChange={(text) => set(i, { ...s, text })} placeholder="(ช่องว่างให้เขียนเอง)" />
              <div className="seg-opts">
                <Toggle checked={!s.noLine} onChange={(line) => set(i, { ...s, noLine: !line })} label="เส้นประ" />
                <Toggle checked={s.widthMm === null} onChange={(grow) => set(i, { ...s, widthMm: grow ? null : 40 })} label="ยืดเต็มที่ว่าง" />
                {s.widthMm !== null && (
                  <NumberInput value={s.widthMm} min={5} onChange={(v) => set(i, { ...s, widthMm: v ?? 40 })} />
                )}
              </div>
            </>
          )}
          {s.kind === 'checkbox' && (
            <div className="fd-grid">
              <Field label="ข้อความ">
                <TextInput value={s.label} onChange={(label) => set(i, { ...s, label })} />
              </Field>
              <Field label="ติ๊กเมื่อ">
                <select value={s.flag} onChange={(e) => set(i, { ...s, flag: e.target.value })}>
                  {flags.map((f) => (
                    <option key={f.key} value={f.key}>{f.label}</option>
                  ))}
                </select>
              </Field>
            </div>
          )}
        </div>
      ))}
      <div className="row" style={{ justifyContent: 'flex-start', margin: 0 }}>
        <button type="button" className="secondary small" onClick={() => onChange([...segments, { kind: 'text', text: '' }])}>+ ข้อความ</button>
        <button type="button" className="secondary small" onClick={() => onChange([...segments, { kind: 'field', text: '', widthMm: null }])}>+ ช่องกรอก</button>
        <button type="button" className="secondary small" onClick={() => onChange([...segments, convert({ kind: 'text', text: '' }, 'checkbox')])}>+ ช่องติ๊ก</button>
      </div>
    </div>
  );
}
