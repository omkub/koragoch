import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  BookOpen,
  CalendarDays,
  ClipboardList,
  FileText,
  Megaphone,
  Users,
} from 'lucide-react';
import { isEmbeddedInLeaveApp, navigateToLeaveApp, supabase } from '../supabase';
import { EmptyState } from '../ui/components';

/**
 * งานของฉัน — พื้นที่ของครูทุกคน (รวมครูผู้สอนที่ไม่ได้สังกัดฝ่าย)
 * แสดงเฉพาะข้อมูลที่ผูกกับตัวครูเอง: ตารางสอน ห้องที่ปรึกษา คำสั่งที่มีชื่อตัวเอง + ประกาศโรงเรียน
 */

interface ScheduleRow {
  id: number;
  day_of_week: number;
  period_no: number;
  room_name: string | null;
  classroom_id: number;
  subject_id: number;
}

interface ClassroomRow {
  id: number;
  name: string;
  grade_level: string;
}

interface SubjectRow {
  id: number;
  code: string;
  name: string;
}

interface OrderRow {
  id: number;
  order_no: string;
  order_year: number;
  subject: string;
  order_date: string;
  division_key: string;
}

interface NoticeRow {
  id: number;
  title: string;
  published_at: string;
  is_pinned: boolean;
}

const DAYS = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์'];

export default function MyWorkPage({
  schoolId,
  idUser,
  userName,
}: {
  schoolId: number | null;
  idUser: number | null;
  userName: string;
}) {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [schedules, setSchedules] = useState<ScheduleRow[]>([]);
  const [classrooms, setClassrooms] = useState<Map<number, ClassroomRow>>(new Map());
  const [subjects, setSubjects] = useState<Map<number, SubjectRow>>(new Map());
  const [advisorRooms, setAdvisorRooms] = useState<(ClassroomRow & { students: number })[]>([]);
  const [orders, setOrders] = useState<OrderRow[]>([]);
  const [notices, setNotices] = useState<NoticeRow[]>([]);

  useEffect(() => {
    if (!schoolId || idUser == null) {
      setLoading(false);
      return;
    }
    let cancelled = false;
    (async () => {
      setLoading(true);
      setError(null);
      const [schedRes, advRes, memberRes, noticeRes] = await Promise.all([
        supabase
          .from('SchoolWebTeachingSchedules')
          .select('id, day_of_week, period_no, room_name, classroom_id, subject_id')
          .eq('id_school', schoolId)
          .eq('teacher_id', idUser),
        supabase
          .from('SchoolWebClassrooms')
          .select('id, name, grade_level')
          .eq('id_school', schoolId)
          .eq('advisor_teacher_id', idUser)
          .eq('is_active', true)
          .order('name'),
        supabase
          .from('SchoolWebOrderMembers')
          .select('order_id')
          .eq('id_school', schoolId)
          .eq('id_user', idUser),
        supabase
          .from('SchoolWebAnnouncements')
          .select('id, title, published_at, is_pinned')
          .eq('id_school', schoolId)
          .order('is_pinned', { ascending: false })
          .order('published_at', { ascending: false })
          .limit(5),
      ]);
      if (cancelled) return;

      const firstError =
        schedRes.error || advRes.error || memberRes.error || noticeRes.error;
      if (firstError) setError(firstError.message);

      const sched = (schedRes.data as ScheduleRow[] | null) ?? [];
      const advisor = (advRes.data as ClassroomRow[] | null) ?? [];
      const orderIds = [
        ...new Set(((memberRes.data as { order_id: number }[] | null) ?? []).map((m) => m.order_id)),
      ];
      const classIds = [...new Set(sched.map((s) => s.classroom_id))];
      const subjectIds = [...new Set(sched.map((s) => s.subject_id))];

      const [classRes, subjRes, orderRes, studentRes] = await Promise.all([
        classIds.length
          ? supabase.from('SchoolWebClassrooms').select('id, name, grade_level').in('id', classIds)
          : Promise.resolve({ data: [] }),
        subjectIds.length
          ? supabase.from('SchoolWebSubjects').select('id, code, name').in('id', subjectIds)
          : Promise.resolve({ data: [] }),
        orderIds.length
          ? supabase
              .from('SchoolWebOrders')
              .select('id, order_no, order_year, subject, order_date, division_key')
              .in('id', orderIds)
              .order('order_date', { ascending: false })
          : Promise.resolve({ data: [] }),
        advisor.length
          ? supabase
              .from('SchoolWebStudents')
              .select('classroom_id')
              .in(
                'classroom_id',
                advisor.map((a) => a.id),
              )
              .eq('status', 'enrolled')
          : Promise.resolve({ data: [] }),
      ]);
      if (cancelled) return;

      const studentCount = new Map<number, number>();
      for (const s of (studentRes.data as { classroom_id: number }[] | null) ?? []) {
        studentCount.set(s.classroom_id, (studentCount.get(s.classroom_id) ?? 0) + 1);
      }

      setSchedules(sched);
      setClassrooms(
        new Map(((classRes.data as ClassroomRow[] | null) ?? []).map((c) => [c.id, c])),
      );
      setSubjects(
        new Map(((subjRes.data as SubjectRow[] | null) ?? []).map((s) => [s.id, s])),
      );
      setAdvisorRooms(advisor.map((a) => ({ ...a, students: studentCount.get(a.id) ?? 0 })));
      setOrders((orderRes.data as OrderRow[] | null) ?? []);
      setNotices((noticeRes.data as NoticeRow[] | null) ?? []);
      setLoading(false);
    })();
    return () => {
      cancelled = true;
    };
  }, [schoolId, idUser]);

  const maxPeriod = useMemo(
    () => Math.max(8, ...schedules.map((s) => s.period_no)),
    [schedules],
  );
  const cell = useMemo(() => {
    const m = new Map<string, ScheduleRow>();
    for (const s of schedules) m.set(`${s.day_of_week}:${s.period_no}`, s);
    return m;
  }, [schedules]);

  if (idUser == null) {
    return (
      <div className="surface-card p-8">
        <EmptyState>ไม่พบข้อมูลบุคลากรของบัญชีนี้ จึงแสดงงานของฉันไม่ได้</EmptyState>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <p className="text-xs font-medium text-brand-600">งานของฉัน</p>
        <h1 className="mt-1 text-2xl font-semibold tracking-tight text-ink">{userName}</h1>
        <p className="mt-1 text-sm text-slate-500">
          ข้อมูลที่ผูกกับคุณโดยตรง: ตารางสอน ห้องที่ปรึกษา และคำสั่งที่มีชื่อคุณ
        </p>
      </div>

      {error && (
        <p className="rounded-lg bg-red-50 px-3 py-2 text-xs text-red-700">โหลดข้อมูลบางส่วนไม่สำเร็จ: {error}</p>
      )}

      {/* ตารางสอนของฉัน */}
      <section className="surface-card p-5">
        <SectionTitle icon={CalendarDays} title="ตารางสอนของฉัน" count={schedules.length} unit="คาบ/สัปดาห์" />
        {loading ? (
          <p className="text-sm text-slate-500">กำลังโหลด…</p>
        ) : schedules.length === 0 ? (
          <EmptyState>ยังไม่มีคาบสอนที่ระบุชื่อคุณเป็นครูผู้สอน</EmptyState>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[640px] border-collapse text-xs">
              <thead>
                <tr>
                  <th className="w-20 border border-line bg-canvas p-2 text-left font-semibold text-slate-600">วัน / คาบ</th>
                  {Array.from({ length: maxPeriod }, (_, i) => (
                    <th key={i} className="border border-line bg-canvas p-2 font-semibold text-slate-600">
                      {i + 1}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {DAYS.map((day, di) => (
                  <tr key={day}>
                    <td className="border border-line bg-canvas p-2 font-medium text-ink">{day}</td>
                    {Array.from({ length: maxPeriod }, (_, pi) => {
                      const s = cell.get(`${di + 1}:${pi + 1}`);
                      const subj = s ? subjects.get(s.subject_id) : undefined;
                      const room = s ? classrooms.get(s.classroom_id) : undefined;
                      return (
                        <td key={pi} className={`border border-line p-1.5 align-top ${s ? 'bg-brand-50/60' : ''}`}>
                          {s && (
                            <div className="space-y-0.5">
                              <p className="font-semibold text-brand-800">{subj?.code ?? '—'}</p>
                              <p className="truncate text-slate-600">{subj?.name}</p>
                              <p className="text-slate-500">
                                {room?.name}
                                {s.room_name ? ` · ${s.room_name}` : ''}
                              </p>
                            </div>
                          )}
                        </td>
                      );
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <div className="grid gap-6 lg:grid-cols-2">
        {/* ห้องที่ปรึกษา */}
        <section className="surface-card p-5">
          <SectionTitle icon={Users} title="ห้องที่ปรึกษา" count={advisorRooms.length} unit="ห้อง" />
          {loading ? (
            <p className="text-sm text-slate-500">กำลังโหลด…</p>
          ) : advisorRooms.length === 0 ? (
            <EmptyState>ไม่ได้เป็นครูที่ปรึกษาห้องใด</EmptyState>
          ) : (
            <ul className="divide-y divide-line">
              {advisorRooms.map((r) => (
                <li key={r.id} className="flex items-center justify-between py-2 text-sm">
                  <span className="font-medium text-ink">{r.name}</span>
                  <span className="text-xs text-slate-500">นักเรียน {r.students} คน</span>
                </li>
              ))}
            </ul>
          )}
        </section>

        {/* คำสั่งที่เกี่ยวกับฉัน */}
        <section className="surface-card p-5">
          <SectionTitle icon={FileText} title="คำสั่งที่มีชื่อฉัน" count={orders.length} unit="ฉบับ" />
          {loading ? (
            <p className="text-sm text-slate-500">กำลังโหลด…</p>
          ) : orders.length === 0 ? (
            <EmptyState>ยังไม่มีคำสั่งแต่งตั้งที่ระบุชื่อคุณ</EmptyState>
          ) : (
            <ul className="divide-y divide-line">
              {orders.map((o) => (
                <li key={o.id} className="py-2 text-sm">
                  <p className="font-medium text-ink">{o.subject}</p>
                  <p className="text-xs text-slate-500">
                    ที่ {o.order_no}/{o.order_year} · {new Date(o.order_date).toLocaleDateString('th-TH')}
                  </p>
                </li>
              ))}
            </ul>
          )}
        </section>

        {/* ประกาศโรงเรียน */}
        <section className="surface-card p-5">
          <SectionTitle icon={Megaphone} title="ประกาศโรงเรียนล่าสุด" />
          {loading ? (
            <p className="text-sm text-slate-500">กำลังโหลด…</p>
          ) : notices.length === 0 ? (
            <EmptyState>ยังไม่มีประกาศ</EmptyState>
          ) : (
            <ul className="divide-y divide-line">
              {notices.map((n) => (
                <li key={n.id} className="flex items-start justify-between gap-3 py-2 text-sm">
                  <span className="text-ink">
                    {n.is_pinned && (
                      <span className="mr-1.5 rounded bg-brand-50 px-1.5 py-0.5 text-[10px] font-semibold text-brand-700">ปักหมุด</span>
                    )}
                    {n.title}
                  </span>
                  <span className="shrink-0 text-xs text-slate-500">
                    {new Date(n.published_at).toLocaleDateString('th-TH')}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </section>

        {/* ทางลัด */}
        <section className="surface-card p-5">
          <SectionTitle icon={ClipboardList} title="ทางลัด" />
          <div className="flex flex-col gap-2">
            <Link to="/school/my-work/grades" className="btn-secondary justify-start">
              <BookOpen className="h-4 w-4" /> กรอกคะแนนวิชาที่ฉันสอน
            </Link>
            {!isEmbeddedInLeaveApp() && (
              <button type="button" onClick={() => navigateToLeaveApp()} className="btn-secondary justify-start">
                <CalendarDays className="h-4 w-4" /> เปิดระบบวันลา
              </button>
            )}
          </div>
        </section>
      </div>
    </div>
  );
}

function SectionTitle({
  icon: Icon,
  title,
  count,
  unit,
}: {
  icon: typeof Users;
  title: string;
  count?: number;
  unit?: string;
}) {
  return (
    <div className="mb-3 flex items-center justify-between gap-2">
      <h2 className="flex items-center gap-2 text-sm font-semibold text-ink">
        <Icon className="h-4 w-4 text-brand-600" strokeWidth={1.7} />
        {title}
      </h2>
      {count !== undefined && (
        <span className="text-xs text-slate-500">
          {count} {unit}
        </span>
      )}
    </div>
  );
}
