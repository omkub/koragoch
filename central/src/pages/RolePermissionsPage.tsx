import { useEffect, useMemo, useState } from 'react';
import {
  groupItems,
  schoolName,
  supabase,
  type PermissionItem,
  type Role,
  type School,
} from '../supabase';
import MenuVisibilityPanel from './MenuVisibilityPanel';
import { Notice, PageHeader } from '../ui/components';
import PermMatrix, { SaveBar } from '../ui/PermMatrix';

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
  const [tab, setTab] = useState<'ceiling' | 'menus'>('ceiling');
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

  function switchTab(next: 'ceiling' | 'menus') {
    if (next === tab) return;
    if (tab === 'ceiling' && changed.length && !confirm('ยังไม่ได้บันทึกเพดานที่แก้ไว้ — ทิ้งการแก้?')) return;
    if (tab === 'ceiling') setGrid(saved);
    setTab(next);
  }

  const tabs = (
    <div className="seg">
      <button className={tab === 'ceiling' ? 'active' : ''} onClick={() => switchTab('ceiling')}>
        เพดานสิทธิ์
      </button>
      <button className={tab === 'menus' ? 'active' : ''} onClick={() => switchTab('menus')}>
        การมองเห็นเมนู
      </button>
    </div>
  );

  if (tab === 'menus') {
    return (
      <>
        <PageHeader
          title="เพดานสิทธิ์"
          description="เมนูที่แต่ละสิทธิ์เห็นในแอป (จอคอม / มือถือ) — ใช้ร่วมกันทุกโรงเรียน"
          actions={tabs}
        />
        <MenuVisibilityPanel roles={roles} />
      </>
    );
  }

  return (
    <>
      <PageHeader
        title="เพดานสิทธิ์"
        description={'กำหนดว่าแต่ละสิทธิ์ทำอะไรได้ "มากที่สุด" ในโรงเรียนนี้ — แอดมินโรงเรียนปรับรายคนได้ไม่เกินนี้ · ปิดรายการที่นี่ = ทุกคนในสิทธิ์นั้นเสียรายการนั้นทันที'}
        actions={
          <>
            {tabs}
            <select
              className="input w-auto max-w-full"
              value={schoolId ?? ''}
              onChange={(e) => setSchoolId(Number(e.target.value))}
              aria-label="เลือกโรงเรียน"
            >
              {schools.map((s) => (
                <option key={s.id_school} value={s.id_school}>
                  {schoolName(s)}
                </option>
              ))}
            </select>
          </>
        }
      />
      <Notice message={message} />

      <section className="card overflow-hidden">
        <PermMatrix
          firstHeader="รายการ"
          roles={roles}
          countLabel={(r) => `${countFor(r.ID_Roles)}/${items.length}`}
          groups={groupItems(items).map(([group, list]) => ({
            group,
            rows: list.map((item) => ({
              key: item.key,
              label: item.label,
              cells: roles.map((r) => {
                const k = cellKey(r.ID_Roles, item.key);
                return {
                  key: k,
                  checked: grid[k] ?? false,
                  dirty: (grid[k] ?? false) !== (saved[k] ?? false),
                  onChange: () => toggle(r.ID_Roles, item.key),
                };
              }),
            })),
          }))}
        />
        <SaveBar
          changed={changed.length}
          busy={busy}
          onReset={() => setGrid(saved)}
          onSave={save}
        />
      </section>
    </>
  );
}
