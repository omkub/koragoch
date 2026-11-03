import { useState, type FormEvent } from 'react';
import { authEmailForUsername, supabase } from '../supabase';
import { Field } from '../ui/components';

export default function LoginPage() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);

    const { error: authError } = await supabase.auth.signInWithPassword({
      email: authEmailForUsername(username),
      password,
    });
    if (authError) {
      setError('ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง');
      setBusy(false);
      return;
    }

    // ล็อกอินผ่าน แต่ไม่ใช่ผู้ดูแลระบบ (ส่วนกลางหรือโรงเรียน) → ออกทันที
    const { data: isAdmin } = await supabase.rpc('is_admin');
    if (isAdmin !== true) {
      await supabase.auth.signOut();
      setError('บัญชีนี้ไม่ใช่ผู้ดูแลระบบ');
    }
    setBusy(false);
  }

  return (
    <div className="grid min-h-screen place-items-center bg-canvas px-4 py-10">
      <div className="w-full max-w-[400px]">
        <div className="mb-6 flex flex-col items-center text-center">
          <div className="grid h-14 w-14 place-items-center rounded-2xl bg-brand-600 text-xl font-bold text-white shadow-md">
            ลา
          </div>
          <span className="mt-3 rounded-full bg-brand-50 px-3 py-0.5 text-xs font-semibold text-brand-700">
            ระบบบริหารจัดการส่วนกลาง
          </span>
          <h1 className="mt-2 text-2xl font-bold tracking-tight text-ink">เข้าสู่ระบบผู้ดูแล</h1>
          <p className="mt-1 text-[13px] text-slate-500">สำหรับผู้ดูแลระบบส่วนกลาง และผู้ดูแลระบบประจำโรงเรียน</p>
        </div>

        <form className="card flex flex-col gap-4 p-6 sm:p-7" onSubmit={submit}>
          <Field label="ชื่อผู้ใช้ (Username)">
            <input
              className="input"
              value={username}
              placeholder="กรอกชื่อผู้ใช้"
              onChange={(e) => setUsername(e.target.value)}
              autoComplete="username"
              autoFocus
              required
            />
          </Field>
          <Field label="รหัสผ่าน (Password)">
            <input
              className="input"
              type="password"
              value={password}
              placeholder="••••••••"
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
              required
            />
          </Field>
          {error && <div className="alert-error">{error}</div>}
          <button type="submit" className="btn-primary mt-1 w-full py-2.5 text-sm" disabled={busy}>
            {busy ? 'กำลังตรวจสอบสิทธิ์...' : 'เข้าสู่ระบบ'}
          </button>
        </form>

        <a
          href="../"
          className="mt-5 block text-center text-[13px] font-medium text-slate-500 transition-colors hover:text-brand-700"
        >
          ← กลับไปหน้าแอปสำหรับครูและบุคลากร
        </a>
      </div>
    </div>
  );
}
