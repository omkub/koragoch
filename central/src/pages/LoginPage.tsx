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
    <div className="grid min-h-screen place-items-center px-4 py-10">
      <div className="w-full max-w-[380px]">
        <div className="mb-6 flex flex-col items-center text-center">
          <div className="grid h-12 w-12 place-items-center rounded-2xl bg-ink text-lg font-bold text-white">ลา</div>
          <h1 className="mt-4 text-xl font-bold">ผู้ดูแลระบบ</h1>
          <p className="mt-1 text-[13px] text-slate-500">ระบบวันลา — ผู้ดูแลส่วนกลาง / ผู้ดูแลโรงเรียน</p>
        </div>

        <form className="card flex flex-col gap-4 p-6" onSubmit={submit}>
          <Field label="ชื่อผู้ใช้">
            <input
              className="input"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              autoComplete="username"
              autoFocus
              required
            />
          </Field>
          <Field label="รหัสผ่าน">
            <input
              className="input"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
              required
            />
          </Field>
          {error && <div className="alert-error">{error}</div>}
          <button type="submit" className="btn-primary mt-1 w-full py-2.5" disabled={busy}>
            {busy ? 'กำลังเข้าสู่ระบบ...' : 'เข้าสู่ระบบ'}
          </button>
        </form>

        <a href="../" className="mt-5 block text-center text-[13px] text-slate-500 hover:text-ink">
          ← ไปแอปสำหรับครู
        </a>
      </div>
    </div>
  );
}
