import { useEffect, useState } from 'react';
import { ADMIN_ROLE_ID, supabase, type School } from '../supabase';

interface SchoolStats {
  school: School;
  teachers: number;
  admins: number;
  leaves: number;
  pending: number;
}

const PENDING = ['รอพิจารณา', 'ยังไม่ส่ง'];

/** ภาพรวมทุกโรงเรียน — RLS ให้ผู้ดูแลส่วนกลางอ่านได้ทุกแถว */
export default function DashboardPage() {
  const [rows, setRows] = useState<SchoolStats[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      const [schools, teachers, leaves] = await Promise.all([
        supabase.from('Schools').select('*').order('id_school'),
        supabase.from('Teachers').select('id_school, id_role, is_super_admin'),
        supabase.from('Leaves').select('id_school, status'),
      ]);
      const failed = schools.error ?? teachers.error ?? leaves.error;
      if (failed) {
        setError(failed.message);
        return;
      }
      setRows(
        (schools.data as School[]).map((school) => {
          const t = (teachers.data ?? []).filter(
            (x) => x.id_school === school.id_school && !x.is_super_admin,
          );
          const l = (leaves.data ?? []).filter((x) => x.id_school === school.id_school);
          return {
            school,
            teachers: t.length,
            admins: t.filter((x) => x.id_role === ADMIN_ROLE_ID).length,
            leaves: l.length,
            pending: l.filter((x) => PENDING.includes(String(x.status ?? ''))).length,
          };
        }),
      );
    })();
  }, []);

  if (error) return <div className="error">โหลดข้อมูลไม่สำเร็จ: {error}</div>;
  if (!rows) return <p>กำลังโหลด...</p>;

  const total = (key: 'teachers' | 'leaves' | 'pending') =>
    rows.reduce((sum, r) => sum + r[key], 0);

  return (
    <>
      <h1>ภาพรวม</h1>
      <div className="stats">
        <div className="stat"><b>{rows.length}</b><span>โรงเรียน</span></div>
        <div className="stat"><b>{total('teachers')}</b><span>บุคลากร</span></div>
        <div className="stat"><b>{total('leaves')}</b><span>ใบลาทั้งหมด</span></div>
        <div className="stat"><b>{total('pending')}</b><span>รอพิจารณา</span></div>
      </div>

      <div className="card">
        <table>
          <thead>
            <tr>
              <th>โรงเรียน</th>
              <th>จังหวัด / อำเภอ</th>
              <th className="num">บุคลากร</th>
              <th className="num">ผู้ดูแลระบบ</th>
              <th className="num">ใบลา</th>
              <th className="num">รอพิจารณา</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.school.id_school}>
                <td>{r.school.fullName || r.school.namePart1}</td>
                <td>{[r.school.province, r.school.district].filter(Boolean).join(' / ') || '-'}</td>
                <td className="num">{r.teachers}</td>
                <td className="num">
                  {r.admins === 0 ? <span className="warn">ยังไม่มี</span> : r.admins}
                </td>
                <td className="num">{r.leaves}</td>
                <td className="num">{r.pending}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
