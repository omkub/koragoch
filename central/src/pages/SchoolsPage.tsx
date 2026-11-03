import { useEffect, useMemo, useState, type FormEvent } from 'react';
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
import { EmptyState, Field, Notice, PageHeader, SectionHeader } from '../ui/components';
import { IconPlus, IconSearch } from '../ui/icons';
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
  new: 'แบบใหม่ (จัดหมวดหมู่ สบายตา · แถบล่าง 4 ปุ่ม)',
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

const IDENTITY_FIELDS: { key: keyof SchoolForm; label: string; hint?: string }[] = [
  { key: 'namePart1', label: 'ชื่อโรงเรียน (ส่วนแรก) *', hint: 'เช่น โรงเรียนรมย์บุรีพิทยาคม' },
  { key: 'namePart2', label: 'ชื่อโรงเรียน (ส่วนหลัง)', hint: 'เช่น รัชมังคลาภิเษก — ไม่มีเว้นว่าง' },
  { key: 'affiliation', label: 'สังกัด', hint: 'เช่น สำนักงานเขตพื้นที่การศึกษามัธยมศึกษา...' },
  { key: 'localCode', label: 'รหัสโรงเรียน', hint: 'รหัสประจำสถานศึกษา (ถ้ามี)' },
];

const LOCATION_FIELDS: { key: keyof SchoolForm; label: string; hint?: string }[] = [
  { key: 'address', label: 'ที่อยู่เต็ม (แสดงบนหัวใบลา)', hint: 'เว้นว่าง = ระบบประกอบจาก ตำบล/อำเภอ/จังหวัด ให้' },
  { key: 'province', label: 'จังหวัด' },
  { key: 'district', label: 'อำเภอ / เขต' },
  { key: 'subdistrict', label: 'ตำบล / แขวง' },
];

const ALL_FIELDS = [...IDENTITY_FIELDS, ...LOCATION_FIELDS];

/**
 * เพิ่ม/แก้ข้อมูลโรงเรียน — แยกหมวดหมู่เป็น 3 ส่วนชัดเจนคู่กับตัวอย่างหัวใบลาสด
 */
export default function SchoolsPage() {
  const [schools, setSchools] = useState<School[]>([]);
  const [editing, setEditing] = useState<number | 'new' | null>(null);
  const [form, setForm] = useState<SchoolForm>(EMPTY);
  const [mobileUi, setMobileUi] = useState<MobileUi>('new');
  const [byRole, setByRole] = useState<ByRole>({});
  const [logo, setLogo] = useState<string | null>(null);
  const [roles, setRoles] = useState<Role[]>([]);
  const [search, setSearch] = useState('');
  const [message, setMessage] = useState<{ text: string; error?: boolean } | null>(null);
  const [busy, setBusy] = useState(false);
  const [loaded, setLoaded] = useState(false);

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
      window.scrollTo({ top: 0, behavior: 'smooth' });
      return;
    }
    setEditing(school.id_school);
    const next = { ...EMPTY };
    for (const f of ALL_FIELDS) next[f.key] = school[f.key] ?? '';
    setForm(next);
    setMobileUi(school.mobile_ui === 'old' ? 'old' : 'new');
    setByRole({ ...(school.mobile_ui_by_role ?? {}) });
    setLogo(school.logo ?? null);
    window.scrollTo({ top: 0, behavior: 'smooth' });
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
    for (const f of ALL_FIELDS) record[f.key] = form[f.key]?.trim() || null;
    if (hasMobileUi) record.mobile_ui = mobileUi;
    if (hasByRole) record.mobile_ui_by_role = byRole;

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

    const oldFile = driveFileId(previous);
    if (hasLogo && oldFile && previous !== record.logo) {
      supabase.functions.invoke(BRIDGE_FUNCTION, { body: { action: 'drive_delete', fileId: oldFile } }).catch(() => {});
    }
    setMessage({ text: editing === 'new' ? 'เพิ่มโรงเรียนใหม่เรียบร้อยแล้ว' : 'บันทึกข้อมูลโรงเรียนเรียบร้อยแล้ว' });
    setEditing(null);
    load();
  }

  const uiOptions = (Object.keys(MOBILE_UI_LABEL) as MobileUi[]).map((k) => (
    <option key={k} value={k}>
      {MOBILE_UI_LABEL[k]}
    </option>
  ));

  const visibleSchools = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return schools;
    return schools.filter((s) =>
      `${schoolName(s)} ${s.affiliation ?? ''} ${s.province ?? ''} ${s.district ?? ''} ${s.localCode ?? ''}`
        .toLowerCase()
        .includes(q),
    );
  }, [schools, search]);

  return (
    <>
      <PageHeader
        category="2. องค์กรและบุคลากร"
        title="จัดการข้อมูลโรงเรียน"
        description="ตั้งค่าตราประจำโรงเรียน ข้อมูลที่แสดงบนหัวใบลา และรูปแบบหน้าจอแอปมือถือแยกตามสิทธิ์"
        actions={
          <button className="btn-primary" onClick={() => startEdit(null)}>
            <IconPlus className="h-4 w-4" /> เพิ่มโรงเรียนใหม่
          </button>
        }
      />
      <Notice message={message} />

      {editing !== null && (
        <form className="card mb-6 overflow-hidden border-brand-200" onSubmit={save}>
          <div className="card-title bg-brand-50/40">
            <div className="flex items-center gap-2">
              <span className="badge-brand">{editing === 'new' ? 'สร้างใหม่' : `รหัส #${editing}`}</span>
              <span>{editing === 'new' ? 'เพิ่มโรงเรียนใหม่' : `แก้ไขข้อมูล: ${form.namePart1 || 'โรงเรียน'}`}</span>
            </div>
            <button type="button" className="btn-ghost btn-sm" onClick={() => setEditing(null)}>
              ปิดฟอร์ม ✕
            </button>
          </div>

          <div className="grid gap-6 p-4 sm:p-5 xl:grid-cols-[minmax(0,1fr)_minmax(0,480px)]">
            <div className="flex min-w-0 flex-col gap-5">
              {/* หมวดย่อย 1: โลโก้ */}
              <section className="subcard">
                <SectionHeader
                  step="1"
                  title="โลโก้และตราประจำโรงเรียน"
                  subtitle="แสดงในแอปหลังเข้าสู่ระบบ และหน้าล็อกอินของเครื่องที่จำบัญชีไว้"
                />
                <div className="mt-3 flex flex-wrap items-center gap-4">
                  {logo ? (
                    <img
                      src={logoSrc(logo) ?? undefined}
                      alt="โลโก้"
                      className="h-16 w-16 rounded-2xl border border-slate-200 bg-white p-1 object-contain shadow-sm"
                    />
                  ) : (
                    <span className="grid h-16 w-16 place-items-center rounded-2xl border border-dashed border-slate-300 bg-white text-[11px] text-slate-400">
                      ไม่มีโลโก้
                    </span>
                  )}
                  <div className="flex flex-col gap-1.5">
                    <div className="flex flex-wrap gap-2">
                      <label className={`btn-secondary ${hasLogo ? 'cursor-pointer' : 'pointer-events-none opacity-50'}`}>
                        เลือกรูปโลโก้
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
                        <button type="button" className="btn-danger btn-sm" onClick={() => setLogo(null)}>
                          ลบโลโก้
                        </button>
                      )}
                    </div>
                    <p className="field-hint">
                      {hasLogo
                        ? 'รองรับ PNG / JPG / WebP · ระบบย่อขนาดเหลือไม่เกิน 256px และเก็บที่ Google Drive (LogoRPB)'
                        : 'ต้องรัน supabase/school_logo.sql ก่อนจึงจะอัปโหลดโลโก้ได้'}
                    </p>
                  </div>
                </div>
              </section>

              {/* หมวดย่อย 2: ข้อมูลชื่อและที่อยู่หัวใบลา */}
              <section className="subcard">
                <SectionHeader
                  step="2"
                  title="ข้อมูลพื้นฐานและที่อยู่บนหัวใบลา"
                  subtitle="ข้อมูลชุดนี้จะถูกนำไปวางบนหัวเอกสารใบลาและบันทึกไปราชการโดยอัตโนมัติ"
                />
                <div className="mt-3 grid gap-4 sm:grid-cols-2">
                  {IDENTITY_FIELDS.map((f) => (
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
                <div className="my-4 border-t border-slate-200/70" />
                <div className="grid gap-4 sm:grid-cols-2">
                  {LOCATION_FIELDS.map((f) => (
                    <Field key={f.key} label={f.label} className={f.key === 'address' ? 'sm:col-span-2' : ''}>
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

              {/* หมวดย่อย 3: หน้าจอแอปบนมือถือ */}
              <section className="subcard">
                <SectionHeader
                  step="3"
                  title="รูปแบบหน้าจอแอปบนมือถือ"
                  subtitle="กำหนดค่าเริ่มต้นของโรงเรียน หรือแยกตามสิทธิ์การใช้งาน"
                />
                <div className="mt-3 grid gap-4 sm:grid-cols-2">
                  <Field
                    label="ค่าเริ่มต้นของโรงเรียน"
                    className="sm:col-span-2"
                    hint={
                      hasMobileUi
                        ? 'มีผลเมื่อครูเปิดแอปครั้งถัดไป · หน้าจอบนคอมพิวเตอร์ไม่เปลี่ยนแปลง'
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
                      label={`สิทธิ์: ${r.Accessrights}`}
                      hint={hasByRole ? undefined : 'ต้องรัน supabase/school_mobile_ui_by_role.sql ก่อน'}
                    >
                      <select
                        className="input"
                        value={byRole[String(r.ID_Roles)] ?? ''}
                        disabled={!hasByRole}
                        onChange={(e) => setRoleUi(r.ID_Roles, e.target.value as MobileUi | '')}
                      >
                        <option value="">ตามค่าโรงเรียน ({mobileUi === 'old' ? 'แบบเดิม' : 'แบบใหม่'})</option>
                        {uiOptions}
                      </select>
                    </Field>
                  ))}
                </div>
              </section>
            </div>

            {/* ตัวอย่างหัวใบลาสด */}
            <div className="xl:sticky xl:top-[76px] xl:h-fit">
              <div className="subcard">
                <SectionHeader
                  title="ตัวอย่างเอกสารหัวใบลา"
                  subtitle="อัปเดตทันทีตามข้อมูลที่พิมพ์ด้านซ้าย"
                />
                <LeaveHeaderPreview school={{ ...form, fullName: null }} />
              </div>
            </div>
          </div>

          <div className="flex items-center justify-end gap-2 border-t border-line bg-slate-50/70 px-4 py-3.5 sm:px-5">
            <button type="button" className="btn-secondary" onClick={() => setEditing(null)}>
              ยกเลิก
            </button>
            <button type="submit" className="btn-primary" disabled={busy}>
              {busy ? 'กำลังบันทึก...' : editing === 'new' ? 'เพิ่มโรงเรียน' : 'บันทึกการแก้ไข'}
            </button>
          </div>
        </form>
      )}

      <section className="card overflow-hidden">
        <div className="card-title flex-wrap">
          <div className="flex items-center gap-2">
            <span>รายชื่อโรงเรียนทั้งหมด</span>
            <span className="badge-slate">{loaded ? `${visibleSchools.length} แห่ง` : 'กำลังโหลด'}</span>
          </div>
          <div className="relative w-full sm:w-64">
            <IconSearch className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
            <input
              className="input py-1.5 pl-9 text-[13px]"
              placeholder="ค้นหาชื่อโรงเรียน / จังหวัด..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
        </div>
        {!loaded ? (
          <EmptyState>กำลังโหลดรายชื่อโรงเรียน...</EmptyState>
        ) : visibleSchools.length === 0 ? (
          <EmptyState>ไม่พบข้อมูลโรงเรียน</EmptyState>
        ) : (
          <>
            <div className="hidden overflow-x-auto md:block">
              <table className="table">
                <thead>
                  <tr>
                    <th>โรงเรียน</th>
                    <th>สังกัด</th>
                    <th>จังหวัด / อำเภอ / ตำบล</th>
                    <th>หน้าจอแอปมือถือ</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {visibleSchools.map((s) => (
                    <tr key={s.id_school}>
                      <td>
                        <div className="flex items-center gap-3">
                          <SchoolLogo logo={s.logo} name={schoolName(s)} size={34} />
                          <div>
                            <div className="font-semibold text-ink">{schoolName(s)}</div>
                            <div className="text-xs text-slate-500">
                              #{s.id_school}
                              {s.localCode ? ` · รหัส ${s.localCode}` : ''}
                            </div>
                          </div>
                        </div>
                      </td>
                      <td className="max-w-[260px] truncate text-slate-600" title={s.affiliation ?? ''}>
                        {s.affiliation || '-'}
                      </td>
                      <td className="text-slate-600">
                        {[s.province, s.district, s.subdistrict].filter(Boolean).join(' / ') || '-'}
                      </td>
                      <td className="text-[13px]">
                        <span className={s.mobile_ui === 'old' ? 'badge-slate' : 'badge-brand'}>
                          {mobileUiSummary(s)}
                        </span>
                      </td>
                      <td className="text-right">
                        <button className="btn-secondary btn-sm" onClick={() => startEdit(s)}>
                          แก้ไขข้อมูล
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <ul className="divide-y divide-slate-100 md:hidden">
              {visibleSchools.map((s) => (
                <li key={s.id_school} className="flex items-center gap-3 px-4 py-3.5">
                  <SchoolLogo logo={s.logo} name={schoolName(s)} size={38} />
                  <div className="min-w-0 flex-1">
                    <div className="truncate font-semibold text-ink">{schoolName(s)}</div>
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
