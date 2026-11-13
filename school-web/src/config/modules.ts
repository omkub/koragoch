import type { SchoolModuleLink } from '../types/school';

/**
 * รายการลิงก์ระบบย่อยเริ่มต้น (ใช้เป็นค่าตั้งต้นในพาร์ท 1
 * ก่อนเชื่อมต่อตาราง SchoolModules บน Supabase ในพาร์ท 2)
 */
export const DEFAULT_MODULE_LINKS: SchoolModuleLink[] = [
  {
    module_key: 'leave-app',
    title: 'ระบบวันลาและไปราชการ',
    description: 'ยื่นใบลา อนุมัติการลา ไปราชการ และลงเวลาปฏิบัติงาน (เปิดแอปเดิม)',
    url: 'https://rbp-chanikarnn.web.app/',
    open_mode: 'new_tab',
    category: 'hr',
    is_enabled: true,
  },
  {
    module_key: 'leave-central',
    title: 'เว็บตั้งค่าระบบวันลาส่วนกลาง',
    description: 'จัดการตั้งค่าฟอร์มวันลา LINE และสิทธิ์ของระบบวันลา',
    url: 'https://rbp-chanikarnn.web.app/central/',
    open_mode: 'new_tab',
    category: 'admin',
    is_enabled: true,
  },
];
