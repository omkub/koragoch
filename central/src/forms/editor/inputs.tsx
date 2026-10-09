import { useState, type ReactNode } from 'react';
import type { Placeholder } from '../template';

// ── แทรกตัวแทนข้อมูลลงช่องข้อความที่กำลังแก้ ───────────────────

let lastTextField: HTMLInputElement | HTMLTextAreaElement | null = null;

/** ตั้งค่าแบบที่ React รับรู้ (controlled input) */
function setNativeValue(el: HTMLInputElement | HTMLTextAreaElement, value: string) {
  const proto = el instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
  Object.getOwnPropertyDescriptor(proto, 'value')!.set!.call(el, value);
  el.dispatchEvent(new Event('input', { bubbles: true }));
}

export function PlaceholderBar({ items }: { items: Placeholder[] }) {
  const [open, setOpen] = useState(false);
  return (
    <div className="ph-bar">
      <button type="button" className="link-btn" onClick={() => setOpen(!open)}>
        {open ? '▾' : '▸'} ตัวแทนข้อมูล — คลิกช่องข้อความก่อน แล้วกดเพื่อแทรก
      </button>
      {open && (
        <div className="ph-list">
          {items.map((p) => (
            <button
              key={p.key}
              type="button"
              className="ph-chip"
              title={p.label}
              // mousedown + preventDefault = ไม่แย่ง focus จากช่องที่กำลังแก้
              onMouseDown={(e) => {
                e.preventDefault();
                const el = lastTextField;
                if (!el || !document.contains(el)) return;
                const token = `{${p.key}}`;
                const start = el.selectionStart ?? el.value.length;
                const end = el.selectionEnd ?? start;
                setNativeValue(el, el.value.slice(0, start) + token + el.value.slice(end));
                el.setSelectionRange(start + token.length, start + token.length);
              }}
            >
              {`{${p.key}}`}
              <small>{p.label}</small>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

// ── ช่องกรอก ───────────────────────────────────────────────────

export function Field({ label, children, hint }: { label: string; children: ReactNode; hint?: string }) {
  return (
    <label className="fd-field">
      <span>{label}</span>
      {children}
      {hint && <small className="muted">{hint}</small>}
    </label>
  );
}

export function TextInput({
  value,
  onChange,
  placeholder,
  multiline,
}: {
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  multiline?: boolean;
}) {
  const common = {
    value,
    placeholder,
    onFocus: (e: React.FocusEvent<HTMLInputElement | HTMLTextAreaElement>) => {
      lastTextField = e.currentTarget;
    },
  };
  return multiline ? (
    <textarea rows={3} {...common} onChange={(e) => onChange(e.target.value)} />
  ) : (
    <input {...common} onChange={(e) => onChange(e.target.value)} />
  );
}

/** ตัวเลข มม. — nullable = ว่างได้ (ใช้ค่าเดิม) */
export function NumberInput({
  value,
  onChange,
  nullable,
  defaultHint,
  step = 0.5,
  min,
  suffix = 'มม.',
}: {
  value: number | null;
  onChange: (v: number | null) => void;
  nullable?: boolean;
  defaultHint?: string;
  step?: number;
  min?: number;
  suffix?: string;
}) {
  return (
    <span className="num-input">
      <input
        type="number"
        step={step}
        min={min}
        value={value === null ? '' : Math.round(value * 100) / 100}
        placeholder={nullable ? defaultHint ?? 'ค่าเดิม' : undefined}
        onChange={(e) => {
          const raw = e.target.value;
          if (raw === '') onChange(nullable ? null : 0);
          else if (!Number.isNaN(Number(raw))) onChange(Number(raw));
        }}
      />
      <span className="muted small">{suffix}</span>
    </span>
  );
}

export function Toggle({ checked, onChange, label }: { checked: boolean; onChange: (v: boolean) => void; label: string }) {
  return (
    <label className="fd-check">
      <input type="checkbox" checked={checked} onChange={(e) => onChange(e.target.checked)} />
      {label}
    </label>
  );
}

/** รายการบรรทัดข้อความ (เพิ่ม / ลบ / เลื่อน) */
export function LinesEditor({ lines, onChange }: { lines: string[]; onChange: (v: string[]) => void }) {
  const set = (i: number, v: string) => onChange(lines.map((l, j) => (j === i ? v : l)));
  const move = (i: number, d: number) => {
    const j = i + d;
    if (j < 0 || j >= lines.length) return;
    const next = [...lines];
    [next[i], next[j]] = [next[j], next[i]];
    onChange(next);
  };
  return (
    <div className="lines-editor">
      {lines.map((l, i) => (
        <div key={i} className="line-row">
          <span className="muted small">{i + 1}</span>
          <TextInput value={l} onChange={(v) => set(i, v)} placeholder="(บรรทัดว่าง)" />
          <button type="button" className="icon-btn" title="เลื่อนขึ้น" onClick={() => move(i, -1)}>↑</button>
          <button type="button" className="icon-btn" title="เลื่อนลง" onClick={() => move(i, 1)}>↓</button>
          <button type="button" className="icon-btn danger" title="ลบบรรทัด" onClick={() => onChange(lines.filter((_, j) => j !== i))}>✕</button>
        </div>
      ))}
      <button type="button" className="secondary small" onClick={() => onChange([...lines, ''])}>+ เพิ่มบรรทัด</button>
      <small className="muted">ใช้ **ข้อความ** เพื่อทำตัวหนา</small>
    </div>
  );
}
