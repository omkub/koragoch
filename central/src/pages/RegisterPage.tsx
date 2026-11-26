import { useEffect, useState, type FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { FlaskConical } from 'lucide-react';
import { authEmailForUsername, supabase } from '../supabase';
import { Field } from '../ui/components';

/**
 * สมัครทดลองใช้งาน (โรงเรียนทดลอง) — เปิดได้โดยไม่ต้องล็อกอิน
 * สมัครผ่าน Edge Function `trial-register` แล้วล็อกอินให้อัตโนมัติ
 * ผู้ทดลองได้สิทธิ์ "ครู" + เจ้าหน้าที่ทั้ง 4 ฝ่ายของโรงเรียนทดลองเท่านั้น
 */

interface DemoInfo {
  ok: boolean;
  school_name?: string;
  signup_enabled?: boolean;
  account_ttl_days?: number;
}

const PREFIX = 'demo_';

async function readFunctionError(error: unknown): Promise<string> {
  const ctx = (error as { context?: Response })?.context;
  if (ctx && typeof ctx.json === 'function') {
    try {
      const body = (await ctx.json()) as { error?: string };
      if (body?.error) return body.error;
    } catch {
      // ignore
    }
  }
  return 'สมัครไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';
}

export default function RegisterPage() {
  const navigate = useNavigate();
  const [info, setInfo] = useState<DemoInfo | null>(null);
  const [fullName, setFullName] = useState('');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    supabase.rpc('get_demo_school_info').then(({ data }) => {
      setInfo((data as DemoInfo | null) ?? { ok: false });
    });
  }, []);

  const cleanName = username.trim().toLowerCase().replace(/^demo_/, '');
  const fullUsername = PREFIX + cleanName;

  async function submit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    if (!/^[a-z0-9._-]{3,30}$/.test(cleanName)) {
      setError('ชื่อผู้ใช้ใช้ได้เฉพาะ a-z 0-9 . _ - ยาว 3–30 ตัว');
      return;
    }
    if (password.length < 8) {
      setError('รหัสผ่านต้องยาวอย่างน้อย 8 ตัว');
      return;
    }
    if (password !== confirm) {
      setError('ยืนยันรหัสผ่านไม่ตรงกัน');
      return;
    }

    setBusy(true);
    const { data, error: fnError } = await supabase.functions.invoke('trial-register', {
      body: { fullName: fullName.trim(), username: fullUsername, password },
    });
    if (fnError || !(data as { ok?: boolean })?.ok) {
      setError(fnError ? await readFunctionError(fnError) : 'สมัครไม่สำเร็จ');
      setBusy(false);
      return;
    }

    const { error: signInError } = await supabase.auth.signInWithPassword({
      email: authEmailForUsername(fullUsername),
      password,
    });
    setBusy(false);
    if (signInError) {
      setError('สมัครสำเร็จแล้ว แต่เข้าสู่ระบบอัตโนมัติไม่ได้ — กรุณาเข้าสู่ระบบด้วยชื่อผู้ใช้ ' + fullUsername);
      return;
    }
    navigate('/school', { replace: true });
  }

  const closed = info !== null && (!info.ok || !info.signup_enabled);

  return (
    <div className="grid min-h-screen place-items-center bg-canvas px-4 py-12">
      <div className="w-full max-w-[420px]">
        <div className="mb-6 flex flex-col items-center text-center">
          <div className="grid h-12 w-12 place-items-center rounded-xl bg-brand-600 text-white">
            <FlaskConical className="h-5 w-5" strokeWidth={1.5} />
          </div>
          <p className="mt-3 text-xs font-medium text-brand-600">ทดลองใช้งานระบบ</p>
          <h1 className="mt-1 text-2xl font-semibold tracking-tight text-ink">สมัครทดลองใช้</h1>
          <p className="mt-1 text-xs leading-relaxed text-slate-500">
            เข้าใช้งานใน{' '}
            <span className="font-semibold text-ink">{info?.school_name ?? 'โรงเรียนทดลอง'}</span>{' '}
            ได้ทันที ข้อมูลทั้งหมดเป็นข้อมูลสมมุติ
            {info?.account_ttl_days ? ` · บัญชีใช้ได้ ${info.account_ttl_days} วัน` : ''}
          </p>
        </div>

        {closed ? (
          <div className="surface-card p-6 text-center text-sm text-slate-600">
            ขณะนี้ปิดรับสมัครทดลองใช้ชั่วคราว
          </div>
        ) : (
          <form className="surface-card flex flex-col gap-4 p-6" onSubmit={submit}>
            <Field label="ชื่อ - นามสกุล">
              <input
                className="input"
                value={fullName}
                onChange={(e) => setFullName(e.target.value)}
                placeholder="ชื่อที่จะแสดงในระบบ (ผู้ทดลองคนอื่นเห็นได้)"
                maxLength={100}
                required
              />
            </Field>
            <Field label="ชื่อผู้ใช้">
              <div className="flex items-stretch">
                <span className="grid place-items-center rounded-l-lg border border-r-0 border-line bg-canvas px-2.5 text-sm text-slate-500">
                  {PREFIX}
                </span>
                <input
                  className="input rounded-l-none"
                  value={cleanName}
                  onChange={(e) => setUsername(e.target.value)}
                  placeholder="a-z 0-9 . _ -"
                  autoComplete="username"
                  required
                />
              </div>
            </Field>
            <Field label="รหัสผ่าน (อย่างน้อย 8 ตัว)">
              <input
                className="input"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="new-password"
                required
              />
            </Field>
            <Field label="ยืนยันรหัสผ่าน">
              <input
                className="input"
                type="password"
                value={confirm}
                onChange={(e) => setConfirm(e.target.value)}
                autoComplete="new-password"
                required
              />
            </Field>
            <p className="text-[11px] leading-relaxed text-slate-500">
              ไม่ต้องใช้อีเมลหรือข้อมูลส่วนตัว · อย่าใช้รหัสผ่านเดียวกับบัญชีอื่นของคุณ
            </p>
            {error && <div className="alert-error">{error}</div>}
            <button
              type="submit"
              className="btn-primary mt-1 w-full py-2.5 text-sm"
              disabled={busy || info === null}
            >
              {busy ? 'กำลังสมัคร...' : 'สมัครและเข้าใช้งาน'}
            </button>
          </form>
        )}

        <div className="mt-4 text-center text-xs text-slate-500">
          มีบัญชีอยู่แล้ว?{' '}
          <Link to="/" className="font-semibold text-brand-700 hover:underline">
            เข้าสู่ระบบ
          </Link>
        </div>
      </div>
    </div>
  );
}
