import { Fragment, useEffect, useMemo, useState } from 'react';
import {
  groupItems,
  schoolName,
  supabase,
  type PermissionItem,
  type Role,
  type School,
} from '../supabase';

type Grid = Record<string, boolean>; // `${id_role}:${item_key}` → allowed

const cellKey = (role: number, item: string) => `${role}:${item}`;

/**
 * เพดานของสิทธิ์ (RolePermissions) — แต่ละโรงเรียน × สิทธิ์ × รายการ
 * แก้ได้เฉพาะผู้ดูแลส่วนกลาง (RLS role_permissions_write)
 *
 * ปิดรายการในเพดาน = ทุกคนที่มีสิทธิ์นั้นในโรงเรียนนั้นเสียรายการนั้นทันที
 * แม้เคยเปิดรายคนไว้ก็ตาม
 */
export default function RolePermissionsPage() {
  const [schools, setSchools] = useState<School[]>([]);
  const [roles, setRoles] = useState<Role[]>([]);
  const [items, setItems] = useState<PermissionItem[]>([]);
  const [schoolId, setSchoolId] = useState<number | null>(null);
  const [saved, setSaved] = useState<Grid>({});
  const [grid, setGrid] = useState<Grid>({});
  const [message, setMessage] = useState<{ text: string; error?: boolean } | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    (async () => {
      const [s, r, i] = await Promise.all([
        supabase.from('Schools').select('*').order('id_school'),
        supabase.from('roles').select('ID_Roles, Accessrights').order('ID_Roles'),
        supabase.from('PermissionItems').select('key, group, label, sort').order('sort'),
      ]);
      const failed = s.error ?? r.error ?? i.error;
      if (failed) {
        setMessage({ text: `โหลดไม่สำเร็จ: ${failed.message} (รัน fine_permissions.sql แล้วหรือยัง?)`, error: true });
        return;
      }
      setSchools(s.data as School[]);
      setRoles(r.data as Role[]);
      setItems(i.data as PermissionItem[]);
      if (s.data?.length) setSchoolId((s.data[0] as School).id_school);
    })();
  }, []);

  async function loadGrid(id: number) {
    const { data, error } = await supabase
      .from('RolePermissions')
      .select('id_role, item_key, allowed')
      .eq('id_school', id);
    if (error) {
      setMessage({ text: error.message, error: true });
      return;
    }
    const next: Grid = {};
    for (const row of data ?? []) next[cellKey(row.id_role, row.item_key)] = row.allowed;
    setSaved(next);
    setGrid(next);
  }

  useEffect(() => {
    if (schoolId !== null) {
      setMessage(null);
      loadGrid(schoolId);
    }
  }, [schoolId]);

  const changed = useMemo(
    () => Object.keys(grid).filter((k) => grid[k] !== (saved[k] ?? false)),
    [grid, saved],
  );

  async function save() {
    if (schoolId === null || changed.length === 0) return;
    setBusy(true);
    const rows = changed.map((k) => {
      const [role, ...rest] = k.split(':');
      return {
        id_school: schoolId,
        id_role: Number(role),
        item_key: rest.join(':'),
        allowed: grid[k],
        updatedAt: new Date().toISOString(),
      };
    });
    const { error } = await supabase.from('RolePermissions').upsert(rows);
    setBusy(false);
    if (error) {
      setMessage({ text: `บันทึกไม่สำเร็จ: ${error.message}`, error: true });
      return;
    }
    setMessage({ text: `บันทึกแล้ว ${rows.length} รายการ` });
    loadGrid(schoolId);
  }

  const toggle = (role: number, item: string) =>
    setGrid({ ...grid, [cellKey(role, item)]: !(grid[cellKey(role, item)] ?? false) });

  const countFor = (role: number) =>
    items.filter((i) => grid[cellKey(role, i.key)]).length;

  return (
    <>
      <div className="row">
        <h1>เพดานสิทธิ์</h1>
        <select value={schoolId ?? ''} onChange={(e) => setSchoolId(Number(e.target.value))}>
          {schools.map((s) => (
            <option key={s.id_school} value={s.id_school}>{schoolName(s)}</option>
          ))}
        </select>
      </div>
      <p className="muted" style={{ marginBottom: 16 }}>
        กำหนดว่าแต่ละสิทธิ์ทำอะไรได้ "มากที่สุด" ในโรงเรียนนี้ — แอดมินโรงเรียนปรับรายคนได้ไม่เกินนี้
        ปิดรายการที่นี่ = ทุกคนในสิทธิ์นั้นเสียรายการนั้นทันที
      </p>
      {message && <div className={message.error ? 'error' : 'ok'}>{message.text}</div>}

      <div className="card">
        <table className="perm-table">
          <thead>
            <tr>
              <th>รายการ</th>
              {roles.map((r) => (
                <th key={r.ID_Roles} className="center-cell">
                  {r.Accessrights}
                  <div className="muted small">{countFor(r.ID_Roles)}/{items.length}</div>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {groupItems(items).map(([group, list]) => (
              <Fragment key={group}>
                <tr className="group-row">
                  <td colSpan={roles.length + 1}>{group}</td>
                </tr>
                {list.map((item) => (
                  <tr key={item.key}>
                    <td>{item.label}</td>
                    {roles.map((r) => {
                      const k = cellKey(r.ID_Roles, item.key);
                      const dirty = (grid[k] ?? false) !== (saved[k] ?? false);
                      return (
                        <td key={k} className={`center-cell${dirty ? ' dirty' : ''}`}>
                          <input
                            type="checkbox"
                            checked={grid[k] ?? false}
                            onChange={() => toggle(r.ID_Roles, item.key)}
                          />
                        </td>
                      );
                    })}
                  </tr>
                ))}
              </Fragment>
            ))}
          </tbody>
        </table>
        <div className="row end">
          <button className="secondary" disabled={changed.length === 0} onClick={() => setGrid(saved)}>
            ยกเลิกการแก้
          </button>
          <button disabled={busy || changed.length === 0} onClick={save}>
            {busy ? 'กำลังบันทึก...' : `บันทึก${changed.length ? ` (${changed.length})` : ''}`}
          </button>
        </div>
      </div>
    </>
  );
}
