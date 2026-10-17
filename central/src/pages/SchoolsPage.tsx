import { useEffect, useState, type FormEvent } from 'react';
import {
  functionError,
  rolesForSchool,
  schoolName,
  supabase,
  type MobileUi,
  type Role,
  type School,
} from '../supabase';
import LeaveHeaderPreview from './LeaveHeaderPreview';
import { EmptyState, Field, Notice, PageHeader } from '../ui/components';
import { IconPlus } from '../ui/icons';
import SchoolLogo, { driveFileId, logoSrc } from '../ui/SchoolLogo';

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
  const [loaded, setLoaded] = useState(false);

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
      supabase.from('roles').select('ID_Roles, Accessrights, id_school').order('ID_Roles'),
    ]);
    if (s.error) setMessage({ text: s.error.message, error: true });
    else setSchools(s.data as School[]);
    if (!r.error) setRoles(r.data as Role[]);
    setLoaded(true);
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

  const uiOptions = (Object.keys(MOBILE_UI_LABEL) as MobileUi[]).map((k) => (
    <option key={k} value={k}>
      {MOBILE_UI_LABEL[k]}
    </option>
  ));

  return (
    <>
      <PageHeader
        title="โรงเรียน"
        description="ข้อมูลโรงเรียนบนหัวใบลา โลโก้ และหน้าจอแอปบนมือถือ"
        actions={
          <button className="btn-primary" onClick={() => startEdit(null)}>
            <IconPlus className="h-4 w-4" /> เพิ่มโรงเรียน
          </button>
        }
      />
      <Notice message={message} />

      {editing !== null && (
        <form className="card mb-5" onSubmit={save}>
          <div className="card-title">{editing === 'new' ? 'เพิ่มโรงเรียนใหม่' : 'แก้ไขข้อมูลโรงเรียน'}</div>
          <div className="grid gap-6 px-4 pb-5 sm:px-5 xl:grid-cols-[minmax(0,1fr)_minmax(0,500px)]">
            <div className="flex min-w-0 flex-col gap-6">
              {/* โลโก้ */}
              <section>
                <h4 className="mb-3 text-[13px] font-semibold text-slate-500">โลโก้โรงเรียน</h4>
                <div className="flex flex-wrap items-center gap-4">
                  {logo ? (
                    <img
                      src={logoSrc(logo) ?? undefined}
                      alt="โลโก้"
                      className="h-16 w-16 rounded-xl border border-slate-200 bg-white object-contain"
                    />
                  ) : (
                    <span className="grid h-16 w-16 place-items-center rounded-xl border border-dashed border-slate-300 text-[11px] text-slate-400">
                      ไม่มีโลโก้
                    </span>
                  )}
                  <div className="flex flex-wrap gap-2">
                    <label className={`btn-secondary ${hasLogo ? 'cursor-pointer' : 'pointer-events-none opacity-50'}`}>
                      เลือกรูป
                      <input
                        type="file"
                        className="sr-only"
                        accept="image/png,image/jpeg,image/webp"
                        disabled={!hasLogo}
                        onChange={(e) => {
                          pickLogo(e.target.files?.[0]);
                          e.target.value = '';
                        }}
                      />
                    </label>
                    {logo && (
                      <button type="button" className="btn-ghost" onClick={() => setLogo(null)}>
                        ลบโลโก้
                      </button>
                    )}
                  </div>
                </div>
                <p className="field-hint mt-2">
                  {hasLogo
                    ? 'แสดงในแอปหลังล็อกอิน และหน้าล็อกอินของเครื่องที่จำการเข้าระบบไว้ · เก็บที่ Google Drive (LogoRPB) · ย่อเหลือ 256px อัตโนมัติ'
                    : 'ต้องรัน supabase/school_logo.sql ก่อน'}
                </p>
              </section>

              {/* ข้อมูลหัวใบลา */}
              <section>
                <h4 className="mb-3 text-[13px] font-semibold text-slate-500">ข้อมูลโรงเรียน (หัวใบลา)</h4>
                <div className="grid gap-4 sm:grid-cols-2">
                  {FIELDS.map((f) => (
                    <Field key={f.key} label={f.label}>
                      <input
                        className="input"
                        value={form[f.key] ?? ''}
                        placeholder={f.hint}
                        onChange={(e) => setForm({ ...form, [f.key]: e.target.value })}
                      />
                    </Field>
                  ))}
                </div>
              </section>

              {/* หน้าจอมือถือ */}
              <section>
                <h4 className="mb-3 text-[13px] font-semibold text-slate-500">หน้าจอแอปบนมือถือ</h4>
                <div className="grid gap-4 sm:grid-cols-2">
                  <Field
                    label="ค่าของโรงเรียน"
                    hint={
                      hasMobileUi
                        ? 'ครูเห็นหน้าจอที่เปลี่ยนเมื่อเปิดแอปครั้งถัดไป · จอคอมไม่เปลี่ยน'
                        : 'ต้องรัน supabase/school_mobile_ui.sql ก่อน (ตอนนี้ทุกโรงเรียนใช้แบบใหม่)'
                    }
                  >
                    <select
                      className="input"
                      value={mobileUi}
                      disabled={!hasMobileUi}
                      onChange={(e) => setMobileUi(e.target.value as MobileUi)}
                    >
                      {uiOptions}
                    </select>
                  </Field>
                  {rolesForSchool(roles, typeof editing === 'number' ? editing : null).map((r) => (
                    <Field
                      key={r.ID_Roles}
                      label={`เฉพาะ ${r.Accessrights}`}
                      hint={hasByRole ? undefined : 'ต้องรัน supabase/school_mobile_ui_by_role.sql ก่อน'}
                    >
                      <select
                        className="input"
                        value={byRole[String(r.ID_Roles)] ?? ''}
                        disabled={!hasByRole}
                        onChange={(e) => setRoleUi(r.ID_Roles, e.target.value as MobileUi | '')}
                      >
                        <option value="">ตามโรงเรียน ({mobileUi === 'old' ? 'แบบเดิม' : 'แบบใหม่'})</option>
                        {uiOptions}
                      </select>
                    </Field>
                  ))}
                </div>
              </section>
            </div>

            {/* อัปเดตทันทีที่พิมพ์ — เห็นก่อนบันทึกว่าหัวใบลาจะออกมาหน้าตาแบบไหน */}
            <LeaveHeaderPreview school={{ ...form, fullName: null }} />
          </div>
          <div className="flex justify-end gap-2 border-t border-line px-4 py-3 sm:px-5">
            <button type="button" className="btn-secondary" onClick={() => setEditing(null)}>
              ยกเลิก
            </button>
            <button type="submit" className="btn-primary" disabled={busy}>
              {busy ? 'กำลังบันทึก...' : 'บันทึก'}
            </button>
          </div>
        </form>
      )}

      <section className="card overflow-hidden">
        <div className="card-title">
          โรงเรียนทั้งหมด
          <span className="text-xs font-medium text-slate-500">{loaded ? `${schools.length} แห่ง` : ''}</span>
        </div>
        {!loaded ? (
          <EmptyState>กำลังโหลด...</EmptyState>
        ) : schools.length === 0 ? (
          <EmptyState>ยังไม่มีโรงเรียน</EmptyState>
        ) : (
          <>
            <div className="hidden overflow-x-auto md:block">
              <table className="table">
                <thead>
                  <tr>
                    <th>โรงเรียน</th>
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
                        <div className="flex items-center gap-3">
                          <SchoolLogo logo={s.logo} name={schoolName(s)} size={30} />
                          <div>
                            <div className="font-medium">{schoolName(s)}</div>
                            <div className="text-xs text-slate-500">
                              #{s.id_school}
                              {s.localCode ? ` · รหัส ${s.localCode}` : ''}
                            </div>
                          </div>
                        </div>
                      </td>
                      <td className="max-w-[260px] truncate" title={s.affiliation ?? ''}>
                        {s.affiliation || '-'}
                      </td>
                      <td>{[s.province, s.district, s.subdistrict].filter(Boolean).join(' / ') || '-'}</td>
                      <td className="text-[13px]">{mobileUiSummary(s)}</td>
                      <td className="text-right">
                        <button className="btn-secondary btn-sm" onClick={() => startEdit(s)}>
                          แก้ไข
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <ul className="divide-y divide-slate-100 md:hidden">
              {schools.map((s) => (
                <li key={s.id_school} className="flex items-center gap-3 px-4 py-3.5">
                  <SchoolLogo logo={s.logo} name={schoolName(s)} size={36} />
                  <div className="min-w-0 flex-1">
                    <div className="truncate font-medium">{schoolName(s)}</div>
                    <div className="truncate text-xs text-slate-500">
                      {[s.province, s.district].filter(Boolean).join(' / ') || '-'} · มือถือ{' '}
                      {s.mobile_ui === 'old' ? 'แบบเดิม' : 'แบบใหม่'}
                    </div>
                  </div>
                  <button className="btn-secondary btn-sm" onClick={() => startEdit(s)}>
                    แก้ไข
                  </button>
                </li>
              ))}
            </ul>
          </>
        )}
      </section>
    </>
  );
}
