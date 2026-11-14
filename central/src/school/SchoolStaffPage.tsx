import { useEffect, useMemo, useState } from 'react';
import { Search } from 'lucide-react';
import { supabase } from '../supabase';

interface SchoolStaffPageProps {
  schoolId: number | null;
}

interface StaffRow {
  id_user: number;
  fullName: string | null;
  username: string | null;
  id_role: number | null;
  employment_status?: string | null;
}

interface RoleRow {
  ID_Roles: number;
  Accessrights: string;
}

const STATUS_LABEL: Record<string, string> = {
  active: 'ปฏิบัติงาน',
  resigned: 'ลาออก',
  retired: 'เกษียณ',
  transferred: 'ย้าย',
};

export default function SchoolStaffPage({ schoolId }: SchoolStaffPageProps) {
  const [staff, setStaff] = useState<StaffRow[]>([]);
  const [roles, setRoles] = useState<RoleRow[]>([]);
  const [query, setQuery] = useState('');
  const [onlyActive, setOnlyActive] = useState(true);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!schoolId) return;
    let cancelled = false;
    setLoading(true);

    (async () => {
      const [staffRes, roleRes] = await Promise.all([
        supabase
          .from('Teachers')
          .select('id_user, fullName, username, id_role, employment_status')
          .eq('id_school', schoolId)
          .order('fullName', { ascending: true }),
        supabase.from('roles').select('ID_Roles, Accessrights'),
      ]);

      if (cancelled) return;
      setStaff((staffRes.data as StaffRow[] | null) ?? []);
      setRoles((roleRes.data as RoleRow[] | null) ?? []);
      setLoading(false);
    })();

    return () => {
      cancelled = true;
    };
  }, [schoolId]);

  const roleMap = useMemo(() => {
    const map = new Map<number, string>();
    for (const r of roles) {
      map.set(r.ID_Roles, r.Accessrights);
    }
    return map;
  }, [roles]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return staff.filter((row) => {
      const status = row.employment_status || 'active';
      if (onlyActive && status !== 'active') return false;
      if (!q) return true;
      return (
        (row.fullName || '').toLowerCase().includes(q) ||
        (row.username || '').toLowerCase().includes(q)
      );
    });
  }, [staff, query, onlyActive]);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight text-ink">
          ทะเบียนบุคลากร
        </h1>
        <p className="mt-1 text-sm text-slate-600">
          รายชื่อบุคลากรและบทบาทภายในโรงเรียน
        </p>
      </div>

      <div className="surface-card p-6">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div className="relative w-full sm:max-w-xs">
            <Search
              className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
              strokeWidth={1.5}
            />
            <input
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="ค้นหาชื่อ หรือชื่อผู้ใช้"
              className="input pl-9"
            />
          </div>

          <div className="flex items-center gap-3 text-sm">
            <label className="flex cursor-pointer items-center gap-2 text-slate-700">
              <input
                type="checkbox"
                checked={onlyActive}
                onChange={(e) => setOnlyActive(e.target.checked)}
                className="checkbox"
              />
              <span>เฉพาะผู้ปฏิบัติงาน</span>
            </label>
            <span className="tabular-nums text-xs text-slate-500">
              {filtered.length.toLocaleString('th-TH')} รายการ
            </span>
          </div>
        </div>

        <div className="mt-5 overflow-x-auto rounded-lg border border-line">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-line bg-canvas text-xs font-medium text-slate-500">
              <tr>
                <th className="px-4 py-3">ชื่อ-นามสกุล</th>
                <th className="px-4 py-3">ชื่อผู้ใช้</th>
                <th className="px-4 py-3">บทบาท</th>
                <th className="px-4 py-3">สถานะ</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-line">
              {loading ? (
                <tr>
                  <td colSpan={4} className="px-4 py-8 text-center text-slate-500">
                    กำลังโหลดรายชื่อบุคลากร...
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={4} className="px-4 py-8 text-center text-slate-500">
                    ไม่พบข้อมูลบุคลากรที่ตรงกับเงื่อนไข
                  </td>
                </tr>
              ) : (
                filtered.map((row) => {
                  const status = row.employment_status || 'active';
                  return (
                    <tr key={row.id_user} className="hover:bg-slate-50/60">
                      <td className="px-4 py-3 font-medium text-ink">
                        {row.fullName || '-'}
                      </td>
                      <td className="px-4 py-3 text-slate-600">
                        {row.username || '-'}
                      </td>
                      <td className="px-4 py-3 text-slate-600">
                        {row.id_role ? roleMap.get(row.id_role) || '-' : '-'}
                      </td>
                      <td className="px-4 py-3">
                        <span
                          className={`inline-block rounded px-2 py-0.5 text-xs ${
                            status === 'active'
                              ? 'bg-emerald-50 text-emerald-700'
                              : 'bg-slate-100 text-slate-600'
                          }`}
                        >
                          {STATUS_LABEL[status] || status}
                        </span>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
