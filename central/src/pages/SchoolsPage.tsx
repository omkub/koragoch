import { useEffect, useState, type FormEvent } from 'react';
import { functionError, schoolName, supabase, type MobileUi, type Role, type School } from '../supabase';
import LeaveHeaderPreview from './LeaveHeaderPreview';

type SchoolForm = Omit<School, 'id_school' | 'fullName' | 'mobile_ui' | 'mobile_ui_by_role' | 'logo'>;

const LOGO_MAX = 256;

/** ย่อรูปให้ด้านยาวไม่เกิน 256px แล้วแปลงเป็น PNG data URL (ไว้แสดงก่อนบันทึก + อัปโหลด) */
function resizeLogo(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      const scale = Math.min(1, LOGO_MAX / Math.max(img.width, img.height));
      const canvas = document.createElement('canvas');
      canvas.width = Math.max(1, Math.round(img.width * scale));
      canvas.height = Math.max(1, Math.round(img.height * scale));
      canvas.getContext('2d')!.drawImage(img, 0, 0, canvas.width, canvas.height);
      URL.revokeObjectURL(url);
      resolve(canvas.toDataURL('image/png'));
    };
    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error('อ่านไฟล์รูปไม่ได้'));
    };
    img.src = url;
  });
}

const BRIDGE_FUNCTION = 'school-bridge';

/** รหัสไฟล์จากลิงก์ Google Drive (…/d/<id>/… หรือ ?id=<id>) */
function driveFileId(url: string | null | undefined): string | null {
  if (!url || !/drive\.google\.com|docs\.google\.com/.test(url)) return null;
  return url.match(/\/d\/([a-zA-Z0-9_-]{10,})/)?.[1] ?? url.match(/[?&]id=([a-zA-Z0-9_-]{10,})/)?.[1] ?? null;
}

/**
 * ลิงก์ที่ใส่ <img> ได้ — ไฟล์ Drive แสดงผ่าน wsrv.nl แบบเดียวกับแอป
 * (lib/utils/profile_image.dart) รูปที่เพิ่งเลือก (data URL) ใช้ตรง ๆ
 */
function logoSrc(logo: string | null | undefined): string | null {
  if (!logo) return null;
  const id = driveFileId(logo);
  return id ? `https://wsrv.nl/?url=drive.google.com/uc%3Fid%3D${id}` : logo;
}

/** อัปโหลดโลโก้ (data URL) ไป Drive โฟลเดอร์ LogoRPB ผ่าน school-bridge → ลิงก์ */
async function uploadLogo(dataUrl: string, schoolLabel: string): Promise<string> {
  const { data, error } = await supabase.functions.invoke(BRIDGE_FUNCTION, {
    body: {
      action: 'drive_upload',
      folderType: 'logo',
      fileName: `logo_${schoolLabel}_${Date.now()}.png`,
      mimeType: 'image/png',
      file64: dataUrl,
    },
  });
  if (error) throw new Error(await functionError(error));
  const url = String(data?.url ?? '');
  if (!url) throw new Error(String(data?.error ?? 'อัปโหลดโลโก้ไม่สำเร็จ'));
  return url;
}

/** หน้าจอมือถือรายสิทธิ์ { ID_Roles: new|old } — ไม่มีคีย์ = ตามโรงเรียน */
type ByRole = Record<string, MobileUi>;

const MOBILE_UI_LABEL: Record<MobileUi, string> = {
  new: 'แบบใหม่ (แถบล่าง 4 ปุ่ม)',
  old: 'แบบเดิม (แถบล่าง 9 ปุ่ม)',
};

const EMPTY: SchoolForm = {
  namePart1: '',
  namePart2: '',
  address: '',
  affiliation: '',
  localCode: '',
  province: '',
  district: '',
  subdistrict: '',
};

const FIELDS: { key: keyof SchoolForm; label: string; hint?: string }[] = [
  { key: 'namePart1', label: 'ชื่อโรงเรียน (ส่วนแรก)', hint: 'เช่น โรงเรียนรมย์บุรีพิทยาคม' },
  { key: 'namePart2', label: 'ชื่อโรงเรียน (ส่วนหลัง)', hint: 'เช่น รัชมังคลาภิเษก — ไม่มีเว้นว่าง' },
  { key: 'address', label: 'ที่อยู่ (หัวใบลา)', hint: 'เว้นว่าง = ใช้ ตำบล/อำเภอ/จังหวัด ด้านล่าง' },
  { key: 'affiliation', label: 'สังกัด' },
  { key: 'province', label: 'จังหวัด' },
  { key: 'district', label: 'อำเภอ' },
  { key: 'subdistrict', label: 'ตำบล' },
  { key: 'localCode', label: 'รหัสโรงเรียน' },
];

/**
 * เพิ่ม/แก้ข้อมูลโรงเรียน
 * fullName ฐานข้อมูลคำนวณจาก namePart1 + namePart2 เอง (ส่งไปไม่ได้)
 * เพิ่มโรงเรียนได้เฉพาะผู้ดูแลส่วนกลาง (policy schools_insert)
 */
export default function SchoolsPage() {
  const [schools, setSchools] = useState<School[]>([]);
  const [editing, setEditing] = useState<number | 'new' | null>(null);
  const [form, setForm] = useState<SchoolForm>(EMPTY);
  const [mobileUi, setMobileUi] = useState<MobileUi>('new');
  const [byRole, setByRole] = useState<ByRole>({});
  const [logo, setLogo] = useState<string | null>(null);
  const [roles, setRoles] = useState<Role[]>([]);
  const [message, setMessage] = useState<{ text: string; error?: boolean } | null>(null);
  const [busy, setBusy] = useState(false);

  // ยังไม่รัน school_mobile_ui.sql / school_mobile_ui_by_role.sql = ไม่มีคอลัมน์
  // ส่งค่าไปจะบันทึกไม่ผ่านทั้งแถว
  const hasMobileUi = schools.some((s) => 'mobile_ui' in s);
  const hasByRole = schools.some((s) => 'mobile_ui_by_role' in s);
  const hasLogo = schools.some((s) => 'logo' in s);

  async function pickLogo(file: File | undefined) {
    if (!file) return;
    try {
      setLogo(await resizeLogo(file));
    } catch (e) {
      setMessage({ text: (e as Error).message, error: true });
    }
  }

  async function load() {
    const [s, r] = await Promise.all([
      supabase.from('Schools').select('*').order('id_school'),
      supabase.from('roles').select('ID_Roles, Accessrights').order('ID_Roles'),
    ]);
    if (s.error) setMessage({ text: s.error.message, error: true });
    else setSchools(s.data as School[]);
    if (!r.error) setRoles(r.data as Role[]);
  }

  const roleName = (id: string) => roles.find((r) => String(r.ID_Roles) === id)?.Accessrights ?? `สิทธิ์ ${id}`;

  /** สรุปในตาราง เช่น "แบบเดิม · ผู้ดูแลระบบ: แบบใหม่" */
  function mobileUiSummary(s: School) {
    const base = s.mobile_ui === 'old' ? 'แบบเดิม' : 'แบบใหม่';
    const overrides = Object.entries(s.mobile_ui_by_role ?? {}).map(
      ([id, ui]) => `${roleName(id)}: ${ui === 'old' ? 'แบบเดิม' : 'แบบใหม่'}`,
    );
    return [base, ...overrides].join(' · ');
  }

  useEffect(() => {
    load();
  }, []);

  function startEdit(school: School | null) {
    setMessage(null);
    if (!school) {
      setEditing('new');
      setForm(EMPTY);
      setMobileUi('new');
      setByRole({});
      setLogo(null);
      return;
    }
    setEditing(school.id_school);
    const next = { ...EMPTY };
    for (const f of FIELDS) next[f.key] = school[f.key] ?? '';
    setForm(next);
    setMobileUi(school.mobile_ui === 'old' ? 'old' : 'new');
    setByRole({ ...(school.mobile_ui_by_role ?? {}) });
    setLogo(school.logo ?? null);
  }

  function setRoleUi(id: number, value: MobileUi | '') {
    const next = { ...byRole };
    if (value) next[String(id)] = value;
    else delete next[String(id)];
    setByRole(next);
  }

  async function save(e: FormEvent) {
    e.preventDefault();
    if (!form.namePart1?.trim()) {
      setMessage({ text: 'กรุณากรอกชื่อโรงเรียน', error: true });
      return;
    }
    setBusy(true);
    const record: Record<string, string | ByRole | null> = { updatedAt: new Date().toISOString() };
    for (const f of FIELDS) record[f.key] = form[f.key]?.trim() || null;
    if (hasMobileUi) record.mobile_ui = mobileUi;
    if (hasByRole) record.mobile_ui_by_role = byRole;

    // โลโก้: รูปที่เพิ่งเลือก → อัปโหลดไป Drive (LogoRPB) แล้วเก็บแค่ลิงก์
    const previous = editing === 'new' ? null : schools.find((s) => s.id_school === editing)?.logo ?? null;
    if (hasLogo) {
      let next = logo;
      if (next?.startsWith('data:')) {
        try {
          next = await uploadLogo(next, form.localCode?.trim() || String(editing));
        } catch (err) {
          setBusy(false);
          setMessage({ text: `อัปโหลดโลโก้ไม่สำเร็จ: ${(err as Error).message}`, error: true });
          return;
        }
        setLogo(next);
      }
      record.logo = next;
    }

    const { error } =
      editing === 'new'
        ? await supabase.from('Schools').insert(record)
        : await supabase.from('Schools').update(record).eq('id_school', editing as number);
    setBusy(false);

    if (error) {
      setMessage({ text: `บันทึกไม่สำเร็จ: ${error.message}`, error: true });
      return;
    }

    // เปลี่ยน/ลบโลโก้ → ย้ายไฟล์เดิมใน Drive ลงถังขยะ (ไม่สำเร็จก็ไม่เป็นไร)
    const oldFile = driveFileId(previous);
    if (hasLogo && oldFile && previous !== record.logo) {
      supabase.functions.invoke(BRIDGE_FUNCTION, { body: { action: 'drive_delete', fileId: oldFile } }).catch(() => {});
    }
    setMessage({ text: editing === 'new' ? 'เพิ่มโรงเรียนแล้ว' : 'บันทึกแล้ว' });
    setEditing(null);
    load();
  }

  return (
    <>
      <div className="row">
        <h1>โรงเรียน</h1>
        <button onClick={() => startEdit(null)}>+ เพิ่มโรงเรียน</button>
      </div>
      {message && <div className={message.error ? 'error' : 'ok'}>{message.text}</div>}

      {editing !== null && (
        <form className="card form" onSubmit={save}>
          <h3>{editing === 'new' ? 'เพิ่มโรงเรียนใหม่' : 'แก้ไขข้อมูลโรงเรียน'}</h3>
          <div className="form-preview">
            <div className="grid">
              <label>
                โลโก้โรงเรียน
                <div className="logo-field">
                  {logo ? <img src={logoSrc(logo) ?? undefined} alt="โลโก้" /> : <span className="logo-empty">ไม่มีโลโก้</span>}
                  <input
                    type="file"
                    accept="image/png,image/jpeg,image/webp"
                    disabled={!hasLogo}
                    onChange={(e) => {
                      pickLogo(e.target.files?.[0]);
                      e.target.value = '';
                    }}
                  />
                  {logo && (
                    <button type="button" className="secondary small" onClick={() => setLogo(null)}>
                      ลบโลโก้
                    </button>
                  )}
                </div>
                <span className="small muted">
                  {hasLogo
                    ? 'แสดงในแอปหลังล็อกอิน และหน้าล็อกอินของเครื่องที่จำการเข้าระบบไว้ · เก็บไฟล์ที่ Google Drive (โฟลเดอร์ LogoRPB) · ย่อเหลือ 256px อัตโนมัติ'
                    : 'ต้องรัน supabase/school_logo.sql ก่อน'}
                </span>
              </label>
              {FIELDS.map((f) => (
                <label key={f.key}>
                  {f.label}
                  <input
                    value={form[f.key] ?? ''}
                    placeholder={f.hint}
                    onChange={(e) => setForm({ ...form, [f.key]: e.target.value })}
                  />
                </label>
              ))}
              <label>
                หน้าจอแอปบนมือถือ
                <select
                  value={mobileUi}
                  disabled={!hasMobileUi}
                  onChange={(e) => setMobileUi(e.target.value as MobileUi)}
                >
                  {(Object.keys(MOBILE_UI_LABEL) as MobileUi[]).map((k) => (
                    <option key={k} value={k}>
                      {MOBILE_UI_LABEL[k]}
                    </option>
                  ))}
                </select>
                <span className="small muted">
                  {hasMobileUi
                    ? 'ครูเห็นหน้าจอที่เปลี่ยนเมื่อเปิดแอปครั้งถัดไป · จอคอมไม่เปลี่ยน'
                    : 'ต้องรัน supabase/school_mobile_ui.sql ก่อน (ตอนนี้ทุกโรงเรียนใช้แบบใหม่)'}
                </span>
              </label>
              {roles.map((r) => (
                <label key={r.ID_Roles}>
                  หน้าจอมือถือ — {r.Accessrights}
                  <select
                    value={byRole[String(r.ID_Roles)] ?? ''}
                    disabled={!hasByRole}
                    onChange={(e) => setRoleUi(r.ID_Roles, e.target.value as MobileUi | '')}
                  >
                    <option value="">
                      ตามโรงเรียน ({mobileUi === 'old' ? 'แบบเดิม' : 'แบบใหม่'})
                    </option>
                    {(Object.keys(MOBILE_UI_LABEL) as MobileUi[]).map((k) => (
                      <option key={k} value={k}>
                        {MOBILE_UI_LABEL[k]}
                      </option>
                    ))}
                  </select>
                  {!hasByRole && (
                    <span className="small muted">ต้องรัน supabase/school_mobile_ui_by_role.sql ก่อน</span>
                  )}
                </label>
              ))}
            </div>
            {/* อัปเดตทันทีที่พิมพ์ — เห็นก่อนบันทึกว่าหัวใบลาจะออกมาหน้าตาแบบไหน */}
            <LeaveHeaderPreview school={{ ...form, fullName: null }} />
          </div>
          <div className="row end">
            <button type="button" className="secondary" onClick={() => setEditing(null)}>
              ยกเลิก
            </button>
            <button type="submit" disabled={busy}>{busy ? 'กำลังบันทึก...' : 'บันทึก'}</button>
          </div>
        </form>
      )}

      <div className="card">
        <table>
          <thead>
            <tr>
              <th>#</th>
              <th>ชื่อโรงเรียน</th>
              <th>สังกัด</th>
              <th>จังหวัด / อำเภอ / ตำบล</th>
              <th>หน้าจอมือถือ</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {schools.map((s) => (
              <tr key={s.id_school}>
                <td>
                  <span className="school-id">
                    {s.logo ? <img className="logo-thumb" src={logoSrc(s.logo) ?? undefined} alt="" /> : null}
                    {s.id_school}
                  </span>
                </td>
                <td>{schoolName(s)}</td>
                <td>{s.affiliation || '-'}</td>
                <td>{[s.province, s.district, s.subdistrict].filter(Boolean).join(' / ') || '-'}</td>
                <td>{mobileUiSummary(s)}</td>
                <td className="num">
                  <button className="secondary small" onClick={() => startEdit(s)}>แก้ไข</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
