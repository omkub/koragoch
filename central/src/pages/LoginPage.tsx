import { useState, type FormEvent } from 'react';
import { authEmailForUsername, supabase } from '../supabase';

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

    // ล็อกอินผ่าน แต่ไม่ใช่ผู้ดูแลส่วนกลาง → ออกทันที ไม่ค้าง session ไว้
    const { data: isSuper } = await supabase.rpc('is_super_admin');
    if (isSuper !== true) {
      await supabase.auth.signOut();
      setError('บัญชีนี้ไม่ใช่ผู้ดูแลระบบส่วนกลาง');
    }
    setBusy(false);
  }

  return (
    <div className="center">
      <form className="card narrow" onSubmit={submit}>
        <h2>ผู้ดูแลระบบส่วนกลาง</h2>
        <p className="muted">ระบบลาออนไลน์ — ดูแลทุกโรงเรียน</p>
        <label>
          ชื่อผู้ใช้
          <input value={username} onChange={(e) => setUsername(e.target.value)} autoFocus required />
        </label>
        <label>
          รหัสผ่าน
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required />
        </label>
        {error && <div className="error">{error}</div>}
        <button type="submit" disabled={busy}>
          {busy ? 'กำลังเข้าสู่ระบบ...' : 'เข้าสู่ระบบ'}
        </button>
      </form>
    </div>
  );
}
