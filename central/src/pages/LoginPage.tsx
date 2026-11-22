import { useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { Building2, Globe } from 'lucide-react';
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

    setBusy(false);
  }

  return (
    <div className="grid min-h-screen place-items-center bg-canvas px-4 py-12">
      <div className="w-full max-w-[400px]">
        <div className="mb-6 flex flex-col items-center text-center">
          <div className="grid h-12 w-12 place-items-center rounded-xl bg-brand-600 text-white">
            <Building2 className="h-5 w-5" strokeWidth={1.5} />
          </div>
          <p className="mt-3 text-xs font-medium text-brand-600">ระบบงานโรงเรียน</p>
          <h1 className="mt-1 text-2xl font-semibold tracking-tight text-ink">
            เข้าสู่ระบบโรงเรียน
          </h1>
          <p className="mt-1 text-xs text-slate-500">
            ใช้ชื่อผู้ใช้และรหัสผ่านเดียวกับระบบวันลาของโรงเรียน
          </p>
        </div>

        <form className="surface-card flex flex-col gap-4 p-6" onSubmit={submit}>
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
              placeholder="กรอกรหัสผ่าน"
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
              required
            />
          </Field>
          {error && <div className="alert-error">{error}</div>}
          <button
            type="submit"
            className="btn-primary mt-1 w-full py-2.5 text-sm"
            disabled={busy}
          >
            {busy ? 'กำลังตรวจสอบสิทธิ์...' : 'เข้าสู่ระบบ'}
          </button>
        </form>

        <div className="mt-4 text-center">
          <Link
            to="/public"
            className="inline-flex w-full items-center justify-center gap-2 rounded-xl border border-brand-200 bg-white px-4 py-2.5 text-xs font-semibold text-brand-700 shadow-sm transition-colors hover:bg-brand-50"
          >
            <Globe className="h-4 w-4 text-brand-600" strokeWidth={1.75} />
            <span>เข้าชมหน้าเว็บโรงเรียน (สำหรับบุคคลภายนอก · ไม่ต้องล็อกอิน)</span>
          </Link>
        </div>
      </div>
    </div>
  );
}
