import { useState, type FormEvent } from 'react';
import { Eye, EyeOff, Lock, School } from 'lucide-react';
import { supabase, toAuthEmail } from '../lib/supabase';

export default function LoginPage() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);

    const { error: authError } = await supabase.auth.signInWithPassword({
      email: toAuthEmail(username),
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
    <div className="grid min-h-screen bg-canvas lg:grid-cols-12">
      {/* Left: Quiet institutional context */}
      <div className="hidden flex-col justify-between border-r border-line bg-white p-12 lg:col-span-5 lg:flex">
        <div className="flex items-center gap-3">
          <div className="grid h-10 w-10 place-items-center rounded-lg bg-brand-600 text-white">
            <School className="h-5 w-5" strokeWidth={1.5} />
          </div>
          <div>
            <p className="text-sm font-semibold text-ink">ระบบบริหารจัดการโรงเรียน</p>
            <p className="text-xs text-slate-500">School Portal</p>
          </div>
        </div>

        <div className="max-w-md space-y-3">
          <h1 className="text-2xl font-semibold tracking-tight text-ink">
            ศูนย์รวมงานบริหารและระบบสารสนเทศของโรงเรียน
          </h1>
          <p className="text-sm leading-relaxed text-slate-600">
            เข้าสู่ระบบด้วยบัญชีผู้ใช้งานเดิมของโรงเรียน เพื่อเข้าถึงข้อมูลกลางและเปิดใช้งานระบบวันลาได้จากที่เดียว
          </p>
        </div>

        <p className="text-xs text-slate-400">
          ใช้บัญชีเดียวกับระบบวันลาและไปราชการ
        </p>
      </div>

      {/* Right: Login form */}
      <div className="flex items-center justify-center p-6 sm:p-12 lg:col-span-7">
        <div className="w-full max-w-sm">
          <div className="mb-8 lg:hidden">
            <div className="flex items-center gap-3">
              <div className="grid h-10 w-10 place-items-center rounded-lg bg-brand-600 text-white">
                <School className="h-5 w-5" strokeWidth={1.5} />
              </div>
              <div>
                <p className="text-sm font-semibold text-ink">ระบบบริหารจัดการโรงเรียน</p>
                <p className="text-xs text-slate-500">ใช้บัญชีเดียวกับระบบวันลา</p>
              </div>
            </div>
          </div>

          <div className="surface-card p-6 sm:p-8">
            <h2 className="text-lg font-semibold text-ink">เข้าสู่ระบบ</h2>
            <p className="mt-1 text-sm text-slate-600">
              กรอกชื่อผู้ใช้และรหัสผ่านของคุณ
            </p>

            <form onSubmit={handleSubmit} className="mt-6 space-y-4">
              <div>
                <label
                  htmlFor="username"
                  className="mb-1.5 block text-sm font-medium text-ink"
                >
                  ชื่อผู้ใช้
                </label>
                <input
                  id="username"
                  type="text"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  placeholder="ชื่อผู้ใช้ระบบวันลา"
                  autoComplete="username"
                  autoFocus
                  required
                  className="w-full rounded-lg border border-line bg-white px-3 py-2 text-sm text-ink outline-none transition-colors focus:border-brand-500"
                />
              </div>

              <div>
                <label
                  htmlFor="password"
                  className="mb-1.5 block text-sm font-medium text-ink"
                >
                  รหัสผ่าน
                </label>
                <div className="relative">
                  <input
                    id="password"
                    type={showPassword ? 'text' : 'password'}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="รหัสผ่าน"
                    autoComplete="current-password"
                    required
                    className="w-full rounded-lg border border-line bg-white py-2 pl-3 pr-10 text-sm text-ink outline-none transition-colors focus:border-brand-500"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword((prev) => !prev)}
                    className="absolute right-2.5 top-1/2 -translate-y-1/2 rounded p-1 text-slate-400 hover:text-slate-600"
                    aria-label={showPassword ? 'ซ่อนรหัสผ่าน' : 'แสดงรหัสผ่าน'}
                  >
                    {showPassword ? (
                      <EyeOff className="h-4 w-4" strokeWidth={1.5} />
                    ) : (
                      <Eye className="h-4 w-4" strokeWidth={1.5} />
                    )}
                  </button>
                </div>
              </div>

              {error && (
                <div className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
                  {error}
                </div>
              )}

              <button
                type="submit"
                disabled={busy}
                className="btn-primary w-full py-2.5"
              >
                <Lock className="h-4 w-4" strokeWidth={1.5} />
                <span>{busy ? 'กำลังตรวจสอบ...' : 'เข้าสู่ระบบ'}</span>
              </button>
            </form>
          </div>
        </div>
      </div>
    </div>
  );
}
