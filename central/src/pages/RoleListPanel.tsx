import { useEffect, useState, type FormEvent } from 'react';
import { supabase, type Role } from '../supabase';
import { Notice } from '../ui/components';
import { IconLock, IconPlus } from '../ui/icons';

/**
 * รายชื่อสิทธิ์ของโรงเรียนที่เลือก — เพิ่ม / เปลี่ยนชื่อ / ลบ (ชุดเดียวกับ
 * จัดการระบบ > ข้อมูลพื้นฐาน > สิทธิ์การเข้าถึง ในแอปของโรงเรียนนั้น)
 *
 * สิทธิ์หลัก (id_school ว่าง) ใช้ทุกโรงเรียน แก้ไม่ได้ — ฐานข้อมูลบังคับด้วย
 * trigger guard_roles (roles_per_school.sql) ซึ่งตรวจชื่อซ้ำ / ยังมีคนใช้ ให้ด้วย
 * สิทธิ์ใหม่ได้เพดาน + เมนูที่เห็นเหมือน "ครู" ของโรงเรียนนั้น (trigger seed_new_role)
 */
export default function RoleListPanel({
  roles,
  schoolId,
  onChanged,
}: {
  roles: Role[];
  schoolId: number;
  onChanged: () => Promise<void>;
}) {
  const [counts, setCounts] = useState<Record<number, number>>({});
  const [name, setName] = useState('');
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<{ text: string; error?: boolean } | null>(null);

  async function loadCounts() {
    const { data } = await supabase.from('Teachers').select('id_role').eq('id_school', schoolId);
    const next: Record<number, number> = {};
    for (const t of data ?? []) {
      if (t.id_role != null) next[t.id_role] = (next[t.id_role] ?? 0) + 1;
    }
    setCounts(next);
  }

  useEffect(() => {
    setMessage(null);
    loadCounts();
  }, [schoolId]);

  async function run(action: () => PromiseLike<{ error: { message: string } | null }>, done: string) {
    setBusy(true);
    const { error } = await action();
    setBusy(false);
    if (error) {
      setMessage({ text: error.message, error: true });
      return false;
    }
    setMessage({ text: done });
    await onChanged();
    await loadCounts();
    return true;
  }

  async function add(e: FormEvent) {
    e.preventDefault();
    const value = name.trim();
    if (!value) return;
    const ok = await run(
      () => supabase.from('roles').insert({ Accessrights: value, id_school: schoolId }),
      `เพิ่มสิทธิ์ "${value}" แล้ว — เริ่มต้นเห็นเมนูและเพดานเหมือน "ครู" ปรับได้ที่แท็บอื่น`,
    );
    if (ok) setName('');
  }

  function rename(r: Role) {
    const value = prompt('ชื่อสิทธิ์ใหม่', r.Accessrights)?.trim();
    if (!value || value === r.Accessrights) return;
    run(
      () => supabase.from('roles').update({ Accessrights: value }).eq('ID_Roles', r.ID_Roles),
      `เปลี่ยนชื่อเป็น "${value}" แล้ว`,
    );
  }

  function remove(r: Role) {
    if (!confirm(`ลบสิทธิ์ "${r.Accessrights}" ของโรงเรียนนี้?`)) return;
    run(() => supabase.from('roles').delete().eq('ID_Roles', r.ID_Roles), `ลบสิทธิ์ "${r.Accessrights}" แล้ว`);
  }

  return (
    <>
      <div className="alert-info mb-4 text-[13px] leading-relaxed">
        สิทธิ์หลัก (มีกุญแจ) ใช้ทุกโรงเรียน แก้หรือลบไม่ได้ · สิทธิ์ที่เพิ่มที่นี่ใช้เฉพาะโรงเรียนที่เลือก
        เหมือนแอดมินโรงเรียนเพิ่มเองในแอป · ลบได้เมื่อไม่มีบุคลากรใช้สิทธิ์นั้นแล้ว
      </div>
      <Notice message={message} />

      <section className="card overflow-hidden">
        <table className="table">
          <thead>
            <tr>
              <th>สิทธิ์</th>
              <th>ใช้กับ</th>
              <th className="text-right">บุคลากร</th>
              <th className="w-0" />
            </tr>
          </thead>
          <tbody>
            {roles.map((r) => {
              const core = r.id_school == null;
              return (
                <tr key={r.ID_Roles}>
                  <td className="font-medium text-ink">{r.Accessrights}</td>
                  <td>
                    {core ? (
                      <span className="badge-brand">ทุกโรงเรียน</span>
                    ) : (
                      <span className="badge-green">เฉพาะโรงเรียนนี้</span>
                    )}
                  </td>
                  <td className="text-right tabular-nums">{counts[r.ID_Roles] ?? 0}</td>
                  <td className="whitespace-nowrap text-right">
                    {core ? (
                      <span className="inline-flex text-slate-400" title="สิทธิ์หลักของระบบ แก้หรือลบไม่ได้">
                        <IconLock className="h-4 w-4" />
                      </span>
                    ) : (
                      <div className="flex justify-end gap-2">
                        <button className="btn-secondary btn-sm" disabled={busy} onClick={() => rename(r)}>
                          เปลี่ยนชื่อ
                        </button>
                        <button className="btn-danger btn-sm" disabled={busy} onClick={() => remove(r)}>
                          ลบ
                        </button>
                      </div>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>

        <form onSubmit={add} className="flex gap-2 border-t border-slate-100 p-4 sm:px-5">
          <input
            className="input flex-1"
            value={name}
            placeholder="ชื่อสิทธิ์ใหม่ เช่น แม่บ้าน"
            onChange={(e) => setName(e.target.value)}
          />
          <button className="btn-primary" disabled={busy || !name.trim()}>
            <IconPlus className="h-4 w-4" />
            เพิ่มสิทธิ์
          </button>
        </form>
      </section>
    </>
  );
}
