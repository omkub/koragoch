import { Fragment } from 'react';
import type { Role } from '../supabase';

export interface MatrixCell {
  key: string;
  checked: boolean;
  dirty: boolean;
  disabled?: boolean;
  onChange: () => void;
}

export interface MatrixRow {
  key: string;
  label: string;
  note?: string;
  muted?: boolean;
  cells: MatrixCell[];
}

/**
 * ตารางติ๊กสิทธิ์ (รายการ × สิทธิ์) — ใช้กับเพดานสิทธิ์ / การมองเห็นเมนู / สิทธิ์รายคน
 * คอลัมน์ชื่อรายการติดซ้ายเวลาเลื่อนแนวนอนบนมือถือ · ช่องที่แก้แล้วยังไม่บันทึกเป็นสีเหลือง
 */
export default function PermMatrix({
  firstHeader,
  roles,
  countLabel,
  groups,
}: {
  firstHeader: string;
  roles?: Role[];
  countLabel?: (r: Role) => string;
  groups: { group: string | null; rows: MatrixRow[] }[];
}) {
  const cols = (roles?.length ?? 1) + 1;
  return (
    <div className="overflow-x-auto">
      <table className="table">
        {roles && (
          <thead>
            <tr>
              <th className="sticky left-0 z-10 bg-slate-50">{firstHeader}</th>
              {roles.map((r) => (
                <th key={r.ID_Roles} className="w-24 text-center">
                  <div className="text-ink">{r.Accessrights}</div>
                  {countLabel && <div className="mt-0.5 font-normal tabular-nums">{countLabel(r)}</div>}
                </th>
              ))}
            </tr>
          </thead>
        )}
        <tbody>
          {groups.map(({ group, rows }) => (
            <Fragment key={group ?? 'all'}>
              {group && (
                <tr>
                  <td
                    colSpan={cols}
                    className="sticky left-0 bg-slate-50 py-2 text-xs font-semibold uppercase tracking-wide text-slate-500"
                  >
                    {group}
                  </td>
                </tr>
              )}
              {rows.map((row) => (
                <tr key={row.key} className={row.muted ? 'text-slate-400' : ''}>
                  <td className="sticky left-0 z-[1] min-w-[160px] bg-white">
                    {row.label}
                    {row.note && <span className="ml-1 text-xs text-slate-400">— {row.note}</span>}
                  </td>
                  {row.cells.map((c) => (
                    <td key={c.key} className={`text-center ${c.dirty ? '!bg-amber-50' : ''}`}>
                      <input
                        type="checkbox"
                        className="checkbox h-[18px] w-[18px]"
                        checked={c.checked}
                        disabled={c.disabled}
                        onChange={c.onChange}
                      />
                    </td>
                  ))}
                </tr>
              ))}
            </Fragment>
          ))}
        </tbody>
      </table>
    </div>
  );
}

/** แถบปุ่มท้ายตาราง: ยกเลิกการแก้ / บันทึก (n) — ติดล่างจอเมื่อมีการแก้ */
export function SaveBar({
  changed,
  busy,
  onReset,
  onSave,
}: {
  changed: number;
  busy: boolean;
  onReset: () => void;
  onSave: () => void;
}) {
  return (
    <div
      className={`flex items-center justify-end gap-2 border-t border-line bg-white px-4 py-3 sm:px-5 ${
        changed ? 'sticky bottom-0 z-20 shadow-[0_-4px_12px_rgba(15,23,42,0.06)]' : ''
      }`}
    >
      {changed > 0 && <span className="mr-auto text-xs text-amber-700">แก้ไว้ {changed} รายการ ยังไม่บันทึก</span>}
      <button className="btn-secondary" disabled={changed === 0} onClick={onReset}>
        ยกเลิกการแก้
      </button>
      <button className="btn-primary" disabled={busy || changed === 0} onClick={onSave}>
        {busy ? 'กำลังบันทึก...' : `บันทึก${changed ? ` (${changed})` : ''}`}
      </button>
    </div>
  );
}
