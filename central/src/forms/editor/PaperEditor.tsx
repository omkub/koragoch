import { FONT_CHOICES, PAPER_PRESETS, paperDimensions, type PaperSettings, type PaperSize } from '../template';
import { Field, NumberInput, Toggle } from './inputs';

/** ตั้งค่ากระดาษ: ขนาด / แนว / ระยะขอบ / ฟอนต์ / ระยะบรรทัด */
export default function PaperEditor({ paper, onChange }: { paper: PaperSettings; onChange: (p: PaperSettings) => void }) {
  const set = <K extends keyof PaperSettings>(key: K, value: PaperSettings[K]) => onChange({ ...paper, [key]: value });
  const setMargin = (side: keyof PaperSettings['margin'], v: number | null) =>
    onChange({ ...paper, margin: { ...paper.margin, [side]: Math.max(0, v ?? 0) } });
  const { widthMm, heightMm } = paperDimensions(paper);
  const fontKnown = FONT_CHOICES.some((f) => f.value === paper.fontFamily);

  return (
    <div className="paper-editor">
      <div className="fd-grid">
        <Field label="ขนาดกระดาษ">
          <select value={paper.size} onChange={(e) => set('size', e.target.value as PaperSize)}>
            {Object.entries(PAPER_PRESETS).map(([k, v]) => (
              <option key={k} value={k}>{v.label}</option>
            ))}
            <option value="custom">กำหนดเอง</option>
          </select>
        </Field>
        <Field label="แนวกระดาษ">
          <select value={paper.orientation} onChange={(e) => set('orientation', e.target.value as PaperSettings['orientation'])}>
            <option value="portrait">แนวตั้ง</option>
            <option value="landscape">แนวนอน</option>
          </select>
        </Field>
        {paper.size === 'custom' && (
          <>
            <Field label="กว้าง">
              <NumberInput value={paper.widthMm} min={50} step={1} onChange={(v) => set('widthMm', Math.max(50, v ?? 210))} />
            </Field>
            <Field label="สูง">
              <NumberInput value={paper.heightMm} min={50} step={1} onChange={(v) => set('heightMm', Math.max(50, v ?? 297))} />
            </Field>
          </>
        )}
      </div>
      <p className="muted small" style={{ margin: '4px 0 8px' }}>
        ขนาดจริง {Math.round(widthMm * 10) / 10} × {Math.round(heightMm * 10) / 10} มม.
      </p>

      <div className="small" style={{ fontWeight: 600, marginBottom: 4 }}>ระยะขอบ</div>
      <div className="fd-grid margins">
        <Field label="บน"><NumberInput value={paper.margin.top} min={0} onChange={(v) => setMargin('top', v)} /></Field>
        <Field label="ล่าง"><NumberInput value={paper.margin.bottom} min={0} onChange={(v) => setMargin('bottom', v)} /></Field>
        <Field label="ซ้าย"><NumberInput value={paper.margin.left} min={0} onChange={(v) => setMargin('left', v)} /></Field>
        <Field label="ขวา"><NumberInput value={paper.margin.right} min={0} onChange={(v) => setMargin('right', v)} /></Field>
      </div>

      <div className="fd-grid">
        <Field label="ฟอนต์">
          <select value={paper.fontFamily} onChange={(e) => set('fontFamily', e.target.value)}>
            {!fontKnown && <option value={paper.fontFamily}>{paper.fontFamily}</option>}
            {FONT_CHOICES.map((f) => (
              <option key={f.value} value={f.value}>{f.label}</option>
            ))}
          </select>
        </Field>
        <Field label="ขนาดตัวอักษรพื้นฐาน" hint="ค่าเดิมใบลา 10.5 pt">
          <NumberInput value={paper.fontSizePt} min={6} step={0.5} suffix="pt" onChange={(v) => set('fontSizePt', Math.max(6, v ?? 10.5))} />
        </Field>
        <Field label="ระยะห่างบรรทัด" hint="เท่าของขนาดตัวอักษร">
          <NumberInput value={paper.lineHeight} min={0.8} step={0.05} suffix="เท่า" onChange={(v) => set('lineHeight', Math.max(0.8, v ?? 1.45))} />
        </Field>
      </div>
      <Toggle
        checked={paper.fitToPage}
        onChange={(v) => set('fitToPage', v)}
        label="เนื้อหาเกินหน้า → ย่อให้พอดีกระดาษหน้าเดียวอัตโนมัติ"
      />
    </div>
  );
}
