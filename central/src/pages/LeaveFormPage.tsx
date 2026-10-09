import { useEffect, useMemo, useState } from 'react';
import { schoolName, supabase, type School } from '../supabase';
import { LeaveFormData, formatThaiDate, type Row } from '../leaveForm/leaveFormData';
import { buildLeaveFormHtml } from '../leaveForm/leaveFormHtml';
import { loadLeaveFormSource, sampleLeaf, type LeaveFormSource } from '../leaveForm/leaveFormSource';

const SAMPLE = 'sample';

/**
 * แบบฟอร์มใบลา — พาร์ท 1: แสดงใบลาเหมือน app ทุกตัวอักษร (ยังตั้งค่าไม่ได้)
 *
 * ใบลาวาดด้วย buildLeaveFormHtml ที่แปลงมาจาก app แล้วแสดงใน iframe
 * (CSS ของใบลาไม่ปนกับหน้าเว็บ และพิมพ์ได้ขนาดกระดาษจริง)
 * เลือกใบลาจริงของโรงเรียน หรือใบตัวอย่างถ้ายังไม่มีใบลา
 */
export default function LeaveFormPage() {
  const [schools, setSchools] = useState<School[]>([]);
  const [schoolId, setSchoolId] = useState<number | null>(null);
  const [source, setSource] = useState<LeaveFormSource | null>(null);
  const [leaveId, setLeaveId] = useState<string>(SAMPLE);
  const [search, setSearch] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    (async () => {
      const { data, error } = await supabase.from('Schools').select('*').order('id_school');
      if (error) {
        setError(`โหลดรายชื่อโรงเรียนไม่สำเร็จ: ${error.message}`);
        return;
      }
      setSchools(data as School[]);
      if (data?.length) setSchoolId((data[0] as School).id_school);
    })();
  }, []);

  useEffect(() => {
    if (schoolId === null) return;
    setLoading(true);
    setError(null);
    setSource(null);
    loadLeaveFormSource(schoolId)
      .then((src) => {
        setSource(src);
        setLeaveId(src.leaves.length ? String(src.leaves[0].requestId) : SAMPLE);
      })
      .catch((e) => setError(`โหลดข้อมูลไม่สำเร็จ: ${e instanceof Error ? e.message : e}`))
      .finally(() => setLoading(false));
  }, [schoolId]);

  const leaf: Row | null = useMemo(() => {
    if (!source) return null;
    if (leaveId === SAMPLE) return sampleLeaf(source);
    return source.leaves.find((l) => String(l.requestId) === leaveId) ?? sampleLeaf(source);
  }, [source, leaveId]);

  const buildHtml = (autoPrint: boolean) =>
    source && leaf
      ? buildLeaveFormHtml(
          new LeaveFormData({
            leaf,
            allUsers: source.users,
            allLeaveRequests: source.leaves,
            leaveTypeNames: source.leaveTypeNames,
            school: source.school,
          }),
          { autoPrint },
        )
      : '';

  const html = useMemo(() => buildHtml(false), [source, leaf]); // eslint-disable-line react-hooks/exhaustive-deps

  function openPrint() {
    const w = window.open('', '_blank');
    if (!w) {
      setError('เบราว์เซอร์บล็อกหน้าต่างพิมพ์ กรุณาอนุญาต pop-up');
      return;
    }
    w.document.open();
    w.document.write(buildHtml(true));
    w.document.close();
  }

  const visibleLeaves = (source?.leaves ?? []).filter((l) => {
    const q = search.trim();
    return !q || `${l.fullName} ${l.leaveType} ${l.startDate}`.includes(q);
  });

  return (
    <>
      <div className="row">
        <h1>แบบฟอร์มใบลา</h1>
        <select value={schoolId ?? ''} onChange={(e) => setSchoolId(Number(e.target.value))}>
          {schools.map((s) => (
            <option key={s.id_school} value={s.id_school}>
              {schoolName(s)}
            </option>
          ))}
        </select>
      </div>
      <p className="muted" style={{ marginBottom: 16 }}>
        ใบลาแบบเดียวกับที่ app พิมพ์อยู่ตอนนี้ (ยังตั้งค่าไม่ได้ — จะเพิ่มในพาร์ทถัดไป)
      </p>

      {error && <div className="error">{error}</div>}

      <div className="form-layout">
        <div className="card form-side">
          <h3>เลือกใบลา</h3>
          <input
            placeholder="ค้นหาชื่อ / ประเภท / วันที่"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          <div className="leave-list">
            <button
              className={`leave-item ${leaveId === SAMPLE ? 'active' : ''}`}
              onClick={() => setLeaveId(SAMPLE)}
            >
              <b>ใบลาตัวอย่าง</b>
              <small>ข้อมูลสมมติ — ใช้ดูหน้าตาเอกสาร</small>
            </button>
            {loading && <p className="muted">กำลังโหลด...</p>}
            {visibleLeaves.slice(0, 200).map((l) => (
              <button
                key={String(l.requestId)}
                className={`leave-item ${leaveId === String(l.requestId) ? 'active' : ''}`}
                onClick={() => setLeaveId(String(l.requestId))}
              >
                <b>{String(l.fullName || '-')}</b>
                <small>
                  {String(l.leaveType || '-')} · {formatThaiDate(l.startDate)} · {String(l.status ?? '')}
                </small>
              </button>
            ))}
            {source && visibleLeaves.length > 200 && (
              <p className="muted small">แสดง 200 รายการล่าสุด — ใช้ช่องค้นหาเพื่อหาใบอื่น</p>
            )}
          </div>
        </div>

        <div className="form-preview-pane">
          <div className="row" style={{ marginBottom: 8 }}>
            <span className="muted">ตัวอย่างเอกสาร (A4)</span>
            <button disabled={!html} onClick={openPrint}>เปิดหน้าพิมพ์ / PDF</button>
          </div>
          {html ? (
            <iframe className="doc-frame" title="ตัวอย่างใบลา" srcDoc={html} />
          ) : (
            <div className="card muted">{loading ? 'กำลังโหลด...' : 'เลือกโรงเรียน'}</div>
          )}
        </div>
      </div>
    </>
  );
}
