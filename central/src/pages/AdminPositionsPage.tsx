import { useEffect, useMemo, useState } from 'react';
import { schoolName, supabase, type School } from '../supabase';
import { isWorkingToday, todayTh } from '../staffStatus';
import { EmptyState, Field, Notice, PageHeader } from '../ui/components';

/**
 * ตำแหน่งบริหารของแต่ละโรงเรียน — ใครดำรงตำแหน่งอะไร ตั้งแต่เมื่อไร (supabase/admin_position_history.sql)
 *
 * บันทึกผ่าน assign_admin_position / delete_admin_position เท่านั้น
 * (ปิดตำแหน่งคนเดิมกับเปิดคนใหม่ต้องเกิดพร้อมกัน) — แอดมินโรงเรียนทำได้จากแอปเช่นกัน
 *
 * end = วันแรกที่ไม่ได้ดำรงตำแหน่ง: ผอ. คนใหม่มีผล 26 ต.ค. → คนเดิมถึง 25 ต.ค.
 */

const NO_POSITION = 'ไม่มีตำแหน่งบริหาร';

interface AdminRole {
  ID_AdminRoles: number;
  AdminRolesName: string | null;
}

interface Teacher {
  id_user: number;
  fullName: string | null;
  employment_status?: string | null;
  left_date?: string | null;
  id_adminrole?: number | null;
  is_super_admin?: boolean | null;
}

interface Period {
  id_history: number;
  id_user: number;
  id_adminrole: number;
  start_date: string | null;
  end_date: string | null;
}

/** 2026-09-30 → 30 ก.ย. 2569 */
function thaiDate(iso: string | null | undefined) {
  if (!iso) return '';
  const d = new Date(`${iso.slice(0, 10)}T00:00:00`);
  return Number.isNaN(d.getTime())
    ? iso
    : d.toLocaleDateString('th-TH', { day: 'numeric', month: 'short', year: 'numeric' });
}

/** วันก่อนหน้า (YYYY-MM-DD) — end เก็บเป็นวันแรกที่ไม่ได้ดำรงตำแหน่ง แต่คนอ่านอยากเห็น "ถึงวันไหน" */
function dayBefore(iso: string) {
  const d = new Date(`${iso.slice(0, 10)}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() - 1);
  return d.toISOString().slice(0, 10);
}

/** ปีงบประมาณ (พ.ศ.) ของวันที่ — เริ่ม 1 ต.ค. */
function fiscalYearOf(iso: string) {
  const [y, m] = iso.split('-').map(Number);
  return (m >= 10 ? y + 1 : y) + 543;
}

/** ดำรงตำแหน่งในวันที่ [day] — ช่วงครอบวันนั้น และยังไม่พ้นสภาพ (ตรงกับ AdminPosition.positionOn ในแอป) */
function holdsOn(p: Period, t: Teacher | undefined, day: string) {
  if (t?.left_date && day >= t.left_date.slice(0, 10)) return false;
  return (!p.start_date || p.start_date <= day) && (!p.end_date || day < p.end_date);
}

export default function AdminPositionsPage() {
  const [schools, setSchools] = useState<School[]>([]);
  const [schoolId, setSchoolId] = useState<number | null>(null);
  const [roles, setRoles] = useState<AdminRole[]>([]);
  const [teachers, setTeachers] = useState<Teacher[]>([]);
  const [periods, setPeriods] = useState<Period[]>([]);
  const [ready, setReady] = useState(true); // false = ยังไม่ได้รัน SQL
  const [message, setMessage] = useState<{ text: string; error?: boolean } | null>(null);
  const [busy, setBusy] = useState(false);

  const today = todayTh();
  const [year, setYear] = useState(fiscalYearOf(today));
  const [form, setForm] = useState({ user: '', role: '', start: today, replace: true });

  useEffect(() => {
    (async () => {
      const s = await supabase.from('Schools').select('*').order('id_school');
      if (s.error) {
        setMessage({ text: s.error.message, error: true });
        return;
      }
      setSchools(s.data as School[]);
      if (s.data?.length) setSchoolId((s.data[0] as School).id_school);
    })();
  }, []);

  async function load(id: number) {
    const [r, t, h] = await Promise.all([
      supabase.from('adminroles').select('ID_AdminRoles, AdminRolesName').eq('id_school', id),
      supabase
        .from('Teachers')
        .select('id_user, fullName, employment_status, left_date, id_adminrole, is_super_admin')
        .eq('id_school', id)
        .order('fullName'),
      supabase
        .from('AdminPositionHistory')
        .select('id_history, id_user, id_adminrole, start_date, end_date')
        .eq('id_school', id),
    ]);
    const failed = r.error ?? t.error;
    if (failed) {
      setMessage({ text: failed.message, error: true });
      return;
    }
    setRoles(((r.data ?? []) as AdminRole[]).filter((x) => (x.AdminRolesName ?? '').trim() && x.AdminRolesName?.trim() !== NO_POSITION));
    setTeachers(((t.data ?? []) as Teacher[]).filter((x) => !x.is_super_admin));
    setReady(!h.error);
    setPeriods(h.error ? [] : (h.data as Period[]));
  }

  useEffect(() => {
    if (schoolId !== null) {
      setMessage(null);
      setForm({ user: '', role: '', start: todayTh(), replace: true });
      load(schoolId);
    }
  }, [schoolId]);

  const roleName = (id: number | null | undefined) =>
    roles.find((r) => r.ID_AdminRoles === id)?.AdminRolesName?.trim() ?? '';
  const teacherById = useMemo(() => new Map(teachers.map((t) => [t.id_user, t])), [teachers]);
  const nameOf = (id: number) => teacherById.get(id)?.fullName?.trim() || `รหัส ${id}`;

  /** ผู้ดำรงตำแหน่งแต่ละตำแหน่ง ณ วันนี้ */
  const holdersToday = useMemo(() => {
    const map = new Map<number, number[]>();
    for (const p of periods) {
      if (holdsOn(p, teacherById.get(p.id_user), today)) {
        map.set(p.id_adminrole, [...(map.get(p.id_adminrole) ?? []), p.id_user]);
      }
    }
    return map;
  }, [periods, teacherById, today]);

  /** คนที่จะถูกแทน — ดำรงตำแหน่งที่เลือกอยู่ก่อนวันที่มีผล (ไม่นับคนที่กำลังตั้ง) */
  const replaced = useMemo(() => {
    const role = Number(form.role);
    if (!role || !form.start) return [];
    const day = dayBefore(form.start);
    return periods
      .filter((p) => p.id_adminrole === role && p.id_user !== Number(form.user))
      .filter((p) => holdsOn(p, teacherById.get(p.id_user), day))
      .map((p) => p.id_user);
  }, [form, periods, teacherById]);

  /** ทำเนียบของปีงบที่เลือก: ตำแหน่ง → [ชื่อ ช่วงเวลา] */
  const roster = useMemo(() => {
    const from = `${year - 544}-10-01`;
    const until = `${year - 543}-10-01`;
    const rows = periods
      .map((p) => {
        const t = teacherById.get(p.id_user);
        // พ้นสภาพก่อนพ้นตำแหน่ง = ดำรงถึงวันพ้นสภาพ
        const left = t?.left_date?.slice(0, 10) ?? null;
        const end = left && (!p.end_date || left < p.end_date) ? left : p.end_date;
        return { ...p, end };
      })
      .filter((p) => !(p.end && p.start_date && p.end <= p.start_date))
      .filter((p) => (!p.start_date || p.start_date < until) && (!p.end || p.end > from));
    const byRole = new Map<number, typeof rows>();
    for (const r of rows) byRole.set(r.id_adminrole, [...(byRole.get(r.id_adminrole) ?? []), r]);
    for (const list of byRole.values()) list.sort((a, b) => (a.start_date ?? '').localeCompare(b.start_date ?? ''));
    return [...byRole.entries()].sort(([a], [b]) => roleRank(roleName(a)) - roleRank(roleName(b)) || roleName(a).localeCompare(roleName(b)));
  }, [periods, teacherById, year, roles]);

  async function assign() {
    if (!form.user || !form.start) return;
    setBusy(true);
    const role = form.role ? Number(form.role) : null;
    const { error } = await supabase.rpc('assign_admin_position', {
      p_id_user: Number(form.user),
      p_id_adminrole: role,
      p_start: form.start,
      p_replace: form.replace,
    });
    setBusy(false);
    if (error) {
      setMessage({ text: `บันทึกไม่สำเร็จ: ${error.message}`, error: true });
      return;
    }
    const who = nameOf(Number(form.user));
    setMessage({
      text: role
        ? `${who} ดำรงตำแหน่ง ${roleName(role)} ตั้งแต่ ${thaiDate(form.start)}`
        : `${who} พ้นตำแหน่งบริหารตั้งแต่ ${thaiDate(form.start)}`,
    });
    setForm({ user: '', role: '', start: todayTh(), replace: true });
    if (schoolId !== null) load(schoolId);
  }

  async function remove(p: Period) {
    const label = `${roleName(p.id_adminrole)} — ${nameOf(p.id_user)}`;
    if (!window.confirm(`ลบรายการ "${label}"?\nถ้ารายการนี้ไปแทนคนเดิม คนเดิมจะกลับมาดำรงตำแหน่งต่อจากวันนั้น`)) return;
    const { error } = await supabase.rpc('delete_admin_position', { p_id_history: p.id_history });
    if (error) {
      setMessage({ text: `ลบไม่สำเร็จ: ${error.message}`, error: true });
      return;
    }
    setMessage({ text: `ลบรายการ ${label} แล้ว` });
    if (schoolId !== null) load(schoolId);
  }

  const working = teachers.filter((t) => isWorkingToday(t.employment_status, t.left_date));
  const years = Array.from({ length: 6 }, (_, i) => fiscalYearOf(today) - i);

  return (
    <>
      <PageHeader
        title="ตำแหน่งบริหาร"
        description="ใครดำรงตำแหน่งอะไร ตั้งแต่เมื่อไร · ชื่อผู้ลงนามในใบลาใช้ผู้ที่ดำรงตำแหน่งในวันที่ส่งใบลา · ตั้งล่วงหน้าได้ มีผลตามวันที่"
        actions={
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
        }
      />
      {!ready && (
        <div className="alert-error mb-4">ยังไม่มีประวัติตำแหน่งบริหาร — ต้องรัน supabase/admin_position_history.sql ก่อน</div>
      )}
      <Notice message={message} />

      <div className="grid gap-5 lg:grid-cols-2">
        <section className="card overflow-hidden">
          <div className="card-title">ดำรงตำแหน่งวันนี้</div>
          {roles.length === 0 ? (
            <EmptyState>โรงเรียนนี้ยังไม่มีรายชื่อตำแหน่งบริหาร</EmptyState>
          ) : (
            <ul className="divide-y divide-slate-100">
              {[...roles]
                .sort((a, b) => roleRank(a.AdminRolesName ?? '') - roleRank(b.AdminRolesName ?? ''))
                .map((r) => {
                  const ids = holdersToday.get(r.ID_AdminRoles) ?? [];
                  return (
                    <li key={r.ID_AdminRoles} className="flex flex-col gap-0.5 px-4 py-2.5 sm:px-5">
                      <span className="text-[13px] text-slate-500">{r.AdminRolesName}</span>
                      <span className={ids.length ? 'font-medium' : 'text-slate-400'}>
                        {ids.length ? ids.map(nameOf).join(', ') : 'ว่าง'}
                      </span>
                    </li>
                  );
                })}
            </ul>
          )}
        </section>

        <section className="card">
          <div className="card-title">บันทึกการเปลี่ยนตำแหน่ง</div>
          <div className="grid gap-4 px-4 pb-4 sm:px-5">
            <Field label="บุคลากร">
              <select
                className="input"
                value={form.user}
                disabled={!ready}
                onChange={(e) => setForm({ ...form, user: e.target.value })}
              >
                <option value="">— เลือก —</option>
                {working.map((t) => (
                  <option key={t.id_user} value={t.id_user}>
                    {t.fullName}
                    {roleName(t.id_adminrole) ? ` (${roleName(t.id_adminrole)})` : ''}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="ตำแหน่ง">
              <select
                className="input"
                value={form.role}
                disabled={!ready}
                onChange={(e) => setForm({ ...form, role: e.target.value })}
              >
                <option value="">{NO_POSITION} (พ้นตำแหน่ง)</option>
                {roles.map((r) => (
                  <option key={r.ID_AdminRoles} value={r.ID_AdminRoles}>
                    {r.AdminRolesName}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="มีผลตั้งแต่วันที่" hint="ก่อนวันนี้ใบลายังขึ้นผู้ลงนามตามตำแหน่งเดิม · ใบลาที่ส่งไปแล้วไม่เปลี่ยน">
              <input
                className="input"
                type="date"
                value={form.start}
                disabled={!ready}
                onChange={(e) => setForm({ ...form, start: e.target.value })}
              />
            </Field>
            {form.role && replaced.length > 0 && (
              <label className="flex items-start gap-2 text-[13px]">
                <input
                  type="checkbox"
                  className="checkbox mt-0.5"
                  checked={form.replace}
                  onChange={(e) => setForm({ ...form, replace: e.target.checked })}
                />
                <span>
                  แทน {replaced.map(nameOf).join(', ')} (พ้นตำแหน่งนี้ตั้งแต่ {thaiDate(form.start)})
                  <span className="block text-slate-500">ไม่ติ๊ก = ตำแหน่งนี้มีได้หลายคน ดำรงตำแหน่งพร้อมกัน</span>
                </span>
              </label>
            )}
          </div>
          <div className="flex justify-end border-t border-line px-4 py-3 sm:px-5">
            <button className="btn-primary" disabled={!ready || busy || !form.user || !form.start} onClick={assign}>
              {busy ? 'กำลังบันทึก...' : 'บันทึก'}
            </button>
          </div>
        </section>
      </div>

      <section className="card mt-5 overflow-hidden">
        <div className="flex items-center justify-between gap-3 px-4 pt-4 sm:px-5">
          <div className="font-semibold">ทำเนียบผู้บริหาร</div>
          <select
            className="input w-auto"
            value={year}
            onChange={(e) => setYear(Number(e.target.value))}
            aria-label="เลือกปีงบประมาณ"
          >
            {years.map((y) => (
              <option key={y} value={y}>
                ปีงบ {y}
              </option>
            ))}
          </select>
        </div>
        {roster.length === 0 ? (
          <EmptyState>ไม่มีผู้ดำรงตำแหน่งบริหารในปีงบ {year}</EmptyState>
        ) : (
          <div className="px-4 pb-4 sm:px-5">
            {roster.map(([roleId, list]) => (
              <div key={roleId} className="mt-4">
                <div className="text-[13px] font-semibold text-slate-500">{roleName(roleId) || `ตำแหน่งรหัส ${roleId}`}</div>
                <ul className="mt-1 divide-y divide-slate-100 rounded-lg border border-line">
                  {list.map((p) => (
                    <li key={p.id_history} className="flex items-center gap-3 px-3 py-2">
                      <div className="min-w-0 flex-1">
                        <div className="truncate font-medium">{nameOf(p.id_user)}</div>
                        <div className="text-xs text-slate-500">
                          {p.start_date ? thaiDate(p.start_date) : 'ก่อนเริ่มบันทึก'} –{' '}
                          {p.end ? thaiDate(dayBefore(p.end)) : 'ปัจจุบัน'}
                        </div>
                      </div>
                      <button className="btn-secondary btn-sm" onClick={() => remove(p)}>
                        ลบ
                      </button>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
        )}
      </section>
    </>
  );
}

/** ผู้อำนวยการก่อน แล้วรองผู้อำนวยการ แล้วตำแหน่งอื่น */
function roleRank(name: string) {
  if (name.includes('ผู้อำนวยการ') && !name.includes('รอง')) return 0;
  if (name.includes('รอง')) return 1;
  return 2;
}
