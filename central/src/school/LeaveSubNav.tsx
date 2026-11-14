import { NavLink } from 'react-router-dom';
import type { Access } from '../supabase';

interface LeaveSubNavProps {
  access: Access;
}

interface SubTab {
  to: string;
  label: string;
  end?: boolean;
  minAccess?: 'school' | 'super';
}

const LEAVE_TABS: SubTab[] = [
  { to: '/leave', label: 'ภาพรวมและเปิดแอปวันลา', end: true },
  { to: '/leave/staff', label: 'ทะเบียนบุคลากร' },
  { to: '/leave/departments', label: 'ฝ่ายและกลุ่มสาระ' },
  // ส่วนตั้งค่าระบบวันลา (central เดิม)
  { to: '/user-permissions', label: 'สิทธิ์รายบุคคล', minAccess: 'school' },
  { to: '/leave-admin', label: 'ภาพรวมตั้งค่าวันลา', minAccess: 'super' },
  { to: '/schools', label: 'โรงเรียน', minAccess: 'super' },
  { to: '/admins', label: 'ผู้ดูแลโรงเรียน', minAccess: 'super' },
  { to: '/staff', label: 'สถานะบุคลากร', minAccess: 'super' },
  { to: '/admin-positions', label: 'ตำแหน่งบริหาร', minAccess: 'super' },
  { to: '/line', label: 'LINE แจ้งเตือน', minAccess: 'super' },
  { to: '/role-permissions', label: 'เพดานสิทธิ์และเมนู', minAccess: 'super' },
  { to: '/attendance', label: 'ลงเวลาสแกนหน้า', minAccess: 'super' },
  { to: '/forms', label: 'ออกแบบฟอร์ม', minAccess: 'super' },
];

export default function LeaveSubNav({ access }: LeaveSubNavProps) {
  const visibleTabs = LEAVE_TABS.filter((t) => {
    if (!t.minAccess) return true;
    if (t.minAccess === 'school') {
      return access.level === 'school' || access.level === 'super';
    }
    return access.level === 'super';
  });

  return (
    <div className="mb-6 border-b border-line pb-3">
      <div className="flex flex-wrap items-center gap-1.5">
        {visibleTabs.map((tab) => (
          <NavLink
            key={tab.to}
            to={tab.to}
            end={tab.end}
            className={({ isActive }) =>
              `rounded-lg px-3 py-1.5 text-xs font-medium transition-colors ${
                isActive
                  ? 'bg-brand-600 text-white'
                  : 'bg-white text-slate-600 ring-1 ring-line hover:bg-slate-50 hover:text-ink'
              }`
            }
          >
            {tab.label}
          </NavLink>
        ))}
      </div>
    </div>
  );
}
