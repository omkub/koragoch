import { useEffect, useMemo, useState } from 'react';
import {
  groupItems,
  rolesForSchool,
  schoolName,
  supabase,
  type PermissionItem,
  type Role,
  type School,
} from '../supabase';
import MenuVisibilityPanel from './MenuVisibilityPanel';
import RoleListPanel from './RoleListPanel';
import { Notice, PageHeader, SectionHeader } from '../ui/components';
import PermMatrix, { SaveBar } from '../ui/PermMatrix';

type Grid = Record<string, boolean>; // `${id_role}:${item_key}` → allowed
type TabKey = 'ceiling' | 'menus' | 'roles';

const cellKey = (role: number, item: string) => `${role}:${item}`;

const TAB_META: Record<TabKey, { step: string; title: string; subtitle: string }> = {
  ceiling: {
    step: '1',
    title: 'เพดานสิทธิ์สูงสุด (Role Ceiling)',
    subtitle:
      'กำหนดว่าแต่ละสิทธิ์ทำอะไรได้ "มากที่สุด" ในโรงเรียนนี้ — แอดมินโรงเรียนปรับรายคนได้ไม่เกินเพดานนี้ · หากปิดที่นี่ ทุกคนในสิทธิ์นั้นจะเสียสิทธิ์ทันที',
  },
  menus: {
    step: '2',
    title: 'การมองเห็นเมนูในแอป (จอคอม / มือถือ)',
    subtitle:
      'เลือกเมนูที่แต่ละสิทธิ์มองเห็นในแอปของโรงเรียนนี้ (ข้อมูลชุดเดียวกับหน้า จัดการระบบ > กำหนดสิทธิ์เข้าถึง ในแอป)',
  },
  roles: {
    step: '3',
    title: 'รายชื่อสิทธิ์ของโรงเรียน',
    subtitle:
      'จัดการรายชื่อสิทธิ์เพิ่มเติมที่ใช้เฉพาะโรงเรียนนี้ (สิทธิ์หลักของระบบใช้ร่วมทุกโรงเรียน แก้หรือลบไม่ได้)',
  },
};

/**
 * เพดานของสิทธิ์ (RolePermissions) — จัดหมวดหมู่เป็น 3 แท็บภายใต้โรงเรียนที่เลือก
 */
export default function RolePermissionsPage() {
  const [tab, setTab] = useState<TabKey>('ceiling');
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
        supabase.from('roles').select('ID_Roles, Accessrights, id_school').order('ID_Roles'),
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

  async function loadRoles() {
    const { data, error } = await supabase
      .from('roles')
      .select('ID_Roles, Accessrights, id_school')
      .order('ID_Roles');
    if (!error) setRoles(data as Role[]);
  }

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

  const schoolRoles = useMemo(() => rolesForSchool(roles, schoolId), [roles, schoolId]);

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
    setMessage({ text: `บันทึกเพดานสิทธิ์แล้ว ${rows.length} รายการ` });
    loadGrid(schoolId);
  }

  const toggle = (role: number, item: string) =>
    setGrid({ ...grid, [cellKey(role, item)]: !(grid[cellKey(role, item)] ?? false) });

  const countFor = (role: number) => items.filter((i) => grid[cellKey(role, i.key)]).length;

  function switchTab(next: TabKey) {
    if (next === tab) return;
    if (tab === 'ceiling' && changed.length && !confirm('ยังไม่ได้บันทึกเพดานที่แก้ไว้ — ทิ้งการแก้?')) return;
    if (tab === 'ceiling') setGrid(saved);
    setTab(next);
  }

  const meta = TAB_META[tab];

  return (
    <>
      <PageHeader
        category="3. สิทธิ์และการเข้าถึง"
        title="เพดานสิทธิ์และการมองเห็นเมนู"
        description="ตั้งค่ากรอบสิทธิ์สูงสุด การแสดงเมนูในแอป และรายชื่อสิทธิ์ของแต่ละโรงเรียน"
      />

      {/* แถบควบคุมหลัก: เลือกโรงเรียน + สลับหมวดหมู่ย่อย */}
      <section className="card mb-6 flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between sm:px-5">
        <div className="flex flex-wrap items-center gap-2.5">
          <span className="text-[13px] font-semibold text-slate-600">โรงเรียนที่กำลังตั้งค่า:</span>
          <select
            className="input w-auto max-w-full font-semibold"
            value={schoolId ?? ''}
            onChange={(e) => {
              if (
                tab === 'ceiling' &&
                changed.length &&
                !confirm('ยังไม่ได้บันทึกเพดานที่แก้ไว้ — ทิ้งการแก้แล้วเปลี่ยนโรงเรียน?')
              )
                return;
              setSchoolId(Number(e.target.value));
            }}
            aria-label="เลือกโรงเรียน"
          >
            {schools.map((s) => (
              <option key={s.id_school} value={s.id_school}>
                {schoolName(s)}
              </option>
            ))}
          </select>
        </div>

        <div className="seg">
          <button className={tab === 'ceiling' ? 'active' : ''} onClick={() => switchTab('ceiling')}>
            1. เพดานสิทธิ์
          </button>
          <button className={tab === 'menus' ? 'active' : ''} onClick={() => switchTab('menus')}>
            2. การมองเห็นเมนู
          </button>
          <button className={tab === 'roles' ? 'active' : ''} onClick={() => switchTab('roles')}>
            3. รายชื่อสิทธิ์ ({schoolRoles.length})
          </button>
        </div>
      </section>

      <SectionHeader step={meta.step} title={meta.title} subtitle={meta.subtitle} />

      {tab === 'roles' && schoolId !== null && (
        <RoleListPanel
          roles={schoolRoles}
          schoolId={schoolId}
          onChanged={async () => {
            await loadRoles();
            await loadGrid(schoolId);
          }}
        />
      )}

      {tab === 'menus' && schoolId !== null && <MenuVisibilityPanel roles={schoolRoles} schoolId={schoolId} />}

      {tab === 'ceiling' && (
        <>
          <Notice message={message} />
          <section className="card overflow-hidden">
            <PermMatrix
              firstHeader="รายการสิทธิ์การทำงาน"
              roles={schoolRoles}
              countLabel={(r) => `${countFor(r.ID_Roles)}/${items.length}`}
              groups={groupItems(items).map(([group, list]) => ({
                group,
                rows: list.map((item) => ({
                  key: item.key,
                  label: item.label,
                  cells: schoolRoles.map((r) => {
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
            <SaveBar changed={changed.length} busy={busy} onReset={() => setGrid(saved)} onSave={save} />
          </section>
        </>
      )}
    </>
  );
}
