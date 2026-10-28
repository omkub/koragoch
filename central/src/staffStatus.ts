/**
 * สถานะบุคลากรตามวันที่มีผล — ตรงกับ staff_is_working() ใน
 * supabase/staff_status_effective_date.sql และ StaffStatus.isActive ในแอป
 *
 * left_date = วันแรกที่ไม่ได้ปฏิบัติงาน ตั้ง "ย้าย มีผล 26 ต.ค." ไว้ล่วงหน้า
 * วันที่ 25 ยังปฏิบัติงานอยู่ วันที่ 26 จึงพ้นสภาพ
 */

/** วันนี้ตามเวลาไทย (YYYY-MM-DD) — toISOString() เป็น UTC ก่อน 7 โมงเช้าจะได้วันของเมื่อวาน */
export function todayTh(): string {
  return new Date(Date.now() + 7 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

/** ยังปฏิบัติงานวันนี้: สถานะ active หรือยังไม่ถึงวันที่พ้นสภาพ (ไม่ใส่วันที่ = พ้นสภาพแล้ว) */
export function isWorkingToday(status: string | null | undefined, leftDate: string | null | undefined): boolean {
  if ((status ?? 'active') === 'active') return true;
  if (!leftDate) return false;
  return leftDate.slice(0, 10) > todayTh();
}
