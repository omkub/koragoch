import { useEffect, useMemo, useState } from 'react';
import { supabase, type Role } from '../supabase';
import { Notice } from '../ui/components';
import PermMatrix, { SaveBar } from '../ui/PermMatrix';

type Device = 'pc' | 'mobile';

/**
 * เมนูที่แอปอ่านจากตาราง Permissions (จอคอม) / MobilePermissions (มือถือ)
 * รหัสต้องตรงกับแอป — lib/screens/user_management_screen.dart (_menuIdMapping,
 * _mobileMenuIdMapping) และ lib/screens/mobile_v2/menu_access.dart
 */
const MENUS: Record<Device, { id: number; label: string }[]> = {
  pc: [
    { id: 0, label: 'แดชบอร์ด' },
    { id: 1, label: 'รายงานสรุปการลา' },
    { id: 2, label: 'ส่งใบลา' },
    { id: 3, label: 'ประวัติการลา' },
    { id: 4, label: 'จัดการระบบ' },
    { id: 5, label: 'บุคลากร (กลุ่มสาระ)' },
    { id: 7, label: 'ประวัติการเข้าใช้งาน' },
    { id: 8, label: 'ปฏิทินกิจกรรมส่วนกลาง' },
    { id: 9, label: 'ไปราชการ / ประชุม' },
    { id: 10, label: 'ลงเวลา' },
  ],
  mobile: [
    { id: 0, label: 'สรุปผล' },
    { id: 1, label: 'รายงาน' },
    { id: 2, label: 'ส่งใบลา' },
    { id: 3, label: 'ประวัติการลา' },
    { id: 4, label: 'จัดการระบบ' },
    { id: 5, label: 'บุคลากร' },
    { id: 7, label: 'ประวัติการเข้าใช้งาน' },
    { id: 8, label: 'ปฏิทิน' },
    { id: 9, label: 'ไปราชการ / ประชุม' },
    { id: 10, label: 'ลงเวลา' },
    { id: -1, label: 'บัญชี' },
  ],
};

const TABLE: Record<Device, string> = { pc: 'Permissions', mobile: 'MobilePermissions' };

type Grid = Record<string, boolean>; // `${id_role}:${menu_id}` → เห็นเมนู

const cellKey = (role: number, menu: number) => `${role}:${menu}`;

/** status เป็น bit(1) — PostgREST ส่งมาเป็น "1"/"0" */
const isOn = (v: unknown) => v === true || v === 1 || String(v).trim() === '1' || String(v).toUpperCase() === 'TRUE';

/**
 * การมองเห็นเมนูในแอป (ไม่ใช่เพดาน) — ตาราง Permissions / MobilePermissions
 * ชุดเดียวกับหน้า "จัดการระบบ > กำหนดสิทธิ์เข้าถึง" ในแอป — แยกตามโรงเรียน (roles_per_school.sql)
 */
export default function MenuVisibilityPanel({ roles, schoolId }: { roles: Role[]; schoolId: number }) {
  const [device, setDevice] = useState<Device>('mobile');
  const [saved, setSaved] = useState<Grid>({});
  const [grid, setGrid] = useState<Grid>({});
  const [message, setMessage] = useState<{ text: string; error?: boolean } | null>(null);
  const [busy, setBusy] = useState(false);
  const menus = MENUS[device];

  async function load(d: Device) {
    const { data, error } = await supabase
      .from(TABLE[d])
      .select('id_role, menu_id, status')
      .eq('id_school', schoolId);
    if (error) {
      setMessage({ text: `โหลดไม่สำเร็จ: ${error.message}`, error: true });
      return;
    }
    const next: Grid = {};
    for (const row of data ?? []) {
      if (row.id_role == null || row.menu_id == null) continue;
      next[cellKey(Number(row.id_role), Number(row.menu_id))] = isOn(row.status);
    }
    setSaved(next);
    setGrid(next);
  }

  useEffect(() => {
    setMessage(null);
    load(device);
  }, [device, schoolId]);

  const changed = useMemo(
    () => Object.keys(grid).filter((k) => grid[k] !== (saved[k] ?? false)),
    [grid, saved],
  );

  function switchDevice(d: Device) {
    if (d === device) return;
    if (changed.length && !confirm('ยังไม่ได้บันทึกที่แก้ไว้ — ทิ้งการแก้แล้วเปลี่ยนหน้า?')) return;
    setDevice(d);
  }

  async function save() {
    if (changed.length === 0) return;
    setBusy(true);
    const now = new Date().toISOString();
    const rows = changed.map((k) => {
      const [role, menu] = k.split(':').map(Number);
      return { id_school: schoolId, id_role: role, menu_id: menu, status: grid[k] ? '1' : '0', updatedAt: now };
    });
    const { error } = await supabase
      .from(TABLE[device])
      .upsert(rows, { onConflict: 'id_school,id_role,menu_id' });
    setBusy(false);
    if (error) {
      setMessage({ text: `บันทึกไม่สำเร็จ: ${error.message}`, error: true });
      return;
    }
    setMessage({ text: `บันทึกแล้ว ${rows.length} รายการ — มีผลเมื่อผู้ใช้เปิดแอปใหม่ / ล็อกอินใหม่` });
    load(device);
  }

  const toggle = (role: number, menu: number) =>
    setGrid({ ...grid, [cellKey(role, menu)]: !(grid[cellKey(role, menu)] ?? false) });

  const countFor = (role: number) => menus.filter((m) => grid[cellKey(role, m.id)]).length;

  return (
    <>
      <div className="mb-3 flex flex-wrap items-center gap-3">
        <div className="seg">
          <button className={device === 'pc' ? 'active' : ''} onClick={() => switchDevice('pc')}>
            จอคอม (PC)
          </button>
          <button className={device === 'mobile' ? 'active' : ''} onClick={() => switchDevice('mobile')}>
            มือถือ
          </button>
        </div>
      </div>
      <div className="alert-info mb-4 text-[13px] leading-relaxed">
        เลือกว่าแต่ละสิทธิ์ "เห็นเมนูไหน" ในแอป{device === 'pc' ? 'บนจอคอม' : 'บนมือถือ'} ของโรงเรียนที่เลือก
        (ชุดเดียวกับ จัดการระบบ &gt; สิทธิ์การเข้าถึง ในแอป)
        <br />
        ข้อยกเว้นในแอป: ผู้ดูแลระบบเห็น "จัดการระบบ" เสมอ · "ลงเวลา"
        ขึ้นเฉพาะโรงเรียนที่เปิดใช้ระบบลงเวลา
        {device === 'mobile' && ' · ถ้าไม่ได้ตั้งค่ามือถือของสิทธิ์ไหนไว้เลย แอปใช้ค่าของจอคอมแทน'}
      </div>
      <Notice message={message} />

      <section className="card overflow-hidden">
        <PermMatrix
          firstHeader="เมนู"
          roles={roles}
          countLabel={(r) => `${countFor(r.ID_Roles)}/${menus.length}`}
          groups={[
            {
              group: null,
              rows: menus.map((m) => ({
                key: String(m.id),
                label: m.label,
                cells: roles.map((r) => {
                  const k = cellKey(r.ID_Roles, m.id);
                  return {
                    key: k,
                    checked: grid[k] ?? false,
                    dirty: (grid[k] ?? false) !== (saved[k] ?? false),
                    onChange: () => toggle(r.ID_Roles, m.id),
                  };
                }),
              })),
            },
          ]}
        />
        <SaveBar changed={changed.length} busy={busy} onReset={() => setGrid(saved)} onSave={save} />
      </section>
    </>
  );
}
