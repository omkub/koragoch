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

    // ล็อกอินผ่าน แต่ไม่ใช่ผู้ดูแลระบบ (ส่วนกลางหรือโรงเรียน) → ออกทันที
    const { data: isAdmin } = await supabase.rpc('is_admin');
    if (isAdmin !== true) {
      await supabase.auth.signOut();
      setError('บัญชีนี้ไม่ใช่ผู้ดูแลระบบ');
    }
    setBusy(false);
  }

  return (
    <div className="center">
      <form className="card narrow" onSubmit={submit}>
        <h2>ผู้ดูแลระบบ</h2>
        <p className="muted">ระบบลาออนไลน์ — ผู้ดูแลส่วนกลาง / ผู้ดูแลโรงเรียน</p>
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
