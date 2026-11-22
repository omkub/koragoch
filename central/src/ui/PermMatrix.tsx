import { Fragment, useState } from 'react';
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
 * - จอคอม (≥ 640px): แสดงทุกบทบาทเป็นตารางหลายคอลัมน์
 * - มือถือ (< 640px): มีแถบเลือกบทบาทด้านบนเพื่อดูและติ๊กทีละบทบาทได้สะดวกโดยไม่ต้องเลื่อนซ้าย-ขวา
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
  const [mobileRoleIdx, setMobileRoleIdx] = useState<number | 'all'>(0);
  const hasMultipleRoles = Boolean(roles && roles.length > 1);
  const safeMobileIdx =
    typeof mobileRoleIdx === 'number' && roles && mobileRoleIdx >= roles.length
      ? 0
      : mobileRoleIdx;

  const cols = (roles?.length ?? 1) + 1;

  const isColHiddenOnMobile = (colIdx: number) =>
    hasMultipleRoles && safeMobileIdx !== 'all' && safeMobileIdx !== colIdx;

  return (
    <div>
      {hasMultipleRoles && roles && (
        <div className="border-b border-line bg-slate-50/80 px-3 py-2.5 sm:hidden">
          <p className="mb-1.5 text-[11px] font-medium text-slate-500">
            เลือกบทบาทที่ต้องการตั้งค่าบนมือถือ:
          </p>
          <div className="flex flex-wrap gap-1.5">
            {roles.map((r, idx) => {
              const active = safeMobileIdx === idx;
              return (
                <button
                  key={r.ID_Roles}
                  type="button"
                  onClick={() => setMobileRoleIdx(idx)}
                  className={`rounded-lg border px-2.5 py-1 text-xs font-medium transition-colors ${
                    active
                      ? 'border-brand-600 bg-brand-600 text-white'
                      : 'border-line bg-white text-slate-600'
                  }`}
                >
                  <span>{r.Accessrights}</span>
                  {countLabel && (
                    <span
                      className={`ml-1 tabular-nums text-[10px] ${
                        active ? 'text-white/90' : 'text-slate-400'
                      }`}
                    >
                      ({countLabel(r)})
                    </span>
                  )}
                </button>
              );
            })}
            <button
              type="button"
              onClick={() => setMobileRoleIdx('all')}
              className={`rounded-lg border px-2.5 py-1 text-xs font-medium transition-colors ${
                safeMobileIdx === 'all'
                  ? 'border-slate-700 bg-slate-700 text-white'
                  : 'border-line bg-white text-slate-600'
              }`}
            >
              ดูทุกบทบาท
            </button>
          </div>
        </div>
      )}

      <div className="overflow-x-auto">
        <table className="table">
          {roles && (
            <thead>
              <tr>
                <th className="sticky left-0 z-10 bg-slate-50">{firstHeader}</th>
                {roles.map((r, idx) => (
                  <th
                    key={r.ID_Roles}
                    className={`w-24 text-center ${
                      isColHiddenOnMobile(idx) ? 'hidden sm:table-cell' : ''
                    }`}
                  >
                    <div className="text-ink">{r.Accessrights}</div>
                    {countLabel && (
                      <div className="mt-0.5 font-normal tabular-nums">
                        {countLabel(r)}
                      </div>
                    )}
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
                    <td className="sticky left-0 z-[1] min-w-[150px] bg-white">
                      <div>{row.label}</div>
                      {row.note && (
                        <div className="mt-0.5 text-[11px] text-slate-400 sm:inline sm:ml-1">
                          — {row.note}
                        </div>
                      )}
                    </td>
                    {row.cells.map((c, idx) => (
                      <td
                        key={c.key}
                        className={`text-center ${c.dirty ? '!bg-amber-50' : ''} ${
                          isColHiddenOnMobile(idx) ? 'hidden sm:table-cell' : ''
                        }`}
                      >
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
      className={`flex flex-wrap items-center justify-end gap-2 border-t border-line bg-white px-4 py-3 sm:px-5 ${
        changed ? 'sticky bottom-0 z-20 shadow-[0_-4px_12px_rgba(15,23,42,0.06)]' : ''
      }`}
    >
      {changed > 0 && (
        <span className="mr-auto text-xs text-amber-700">
          แก้ไว้ {changed} รายการ ยังไม่บันทึก
        </span>
      )}
      <button className="btn-secondary" disabled={changed === 0} onClick={onReset}>
        ยกเลิกการแก้
      </button>
      <button className="btn-primary" disabled={busy || changed === 0} onClick={onSave}>
        {busy ? 'กำลังบันทึก...' : `บันทึก${changed ? ` (${changed})` : ''}`}
      </button>
    </div>
  );
}
