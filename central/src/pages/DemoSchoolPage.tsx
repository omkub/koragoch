import { useCallback, useEffect, useMemo, useState } from 'react';
import { RotateCcw, Trash2 } from 'lucide-react';
import { supabase } from '../supabase';
import { EmptyState, Notice, PageHeader } from '../ui/components';

/**
 * ศูนย์ส่วนกลาง → โรงเรียนทดลองใช้ (/admin/demo)
 * เปิด/ปิดรับสมัคร · อายุบัญชี · รีเซ็ตข้อมูลตั้งต้น · รายชื่อ / ลบบัญชีทดลอง
 * ใช้ได้เฉพาะผู้ดูแลส่วนกลาง (RLS + Edge Function trial-register ตรวจซ้ำ)
 */

interface DemoConfig {
  id_school: number;
  demo_signup_enabled: boolean;
  account_ttl_days: number;
}

interface DemoAccount {
  id_user: number;
  username: string;
  created_at: string;
  expires_at: string;
  fullName?: string;
}

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
  return error instanceof Error ? error.message : 'ทำรายการไม่สำเร็จ';
}

const fmt = (iso: string) =>
  new Date(iso).toLocaleString('th-TH', { dateStyle: 'medium', timeStyle: 'short' });

export default function DemoSchoolPage() {
  const [config, setConfig] = useState<DemoConfig | null>(null);
  const [schoolName, setSchoolName] = useState('');
  const [accounts, setAccounts] = useState<DemoAccount[]>([]);
  const [selected, setSelected] = useState<Set<number>>(new Set());
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState<string | null>(null);
  const [message, setMessage] = useState<{ text: string; error?: boolean } | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    const { data: cfg } = await supabase
      .from('SchoolWebDemoConfig')
      .select('id_school, demo_signup_enabled, account_ttl_days')
      .order('id_school')
      .limit(1)
      .maybeSingle();
    const c = (cfg as DemoConfig | null) ?? null;
    setConfig(c);
    if (c) {
      const [schoolRes, accRes] = await Promise.all([
        supabase.from('Schools').select('fullName').eq('id_school', c.id_school).maybeSingle(),
        supabase
          .from('SchoolWebDemoAccounts')
          .select('id_user, username, created_at, expires_at')
          .eq('id_school', c.id_school)
          .order('created_at', { ascending: false }),
      ]);
      setSchoolName((schoolRes.data as { fullName?: string } | null)?.fullName ?? '');
      const list = (accRes.data as DemoAccount[] | null) ?? [];
      const ids = list.map((a) => a.id_user);
      const { data: names } = ids.length
        ? await supabase.from('Teachers').select('id_user, fullName').in('id_user', ids)
        : { data: [] };
      const nameMap = new Map(
        ((names as { id_user: number; fullName: string }[] | null) ?? []).map((n) => [n.id_user, n.fullName]),
      );
      setAccounts(list.map((a) => ({ ...a, fullName: nameMap.get(a.id_user) })));
    }
    setSelected(new Set());
    setLoading(false);
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const expiredCount = useMemo(
    () => accounts.filter((a) => new Date(a.expires_at) < new Date()).length,
    [accounts],
  );

  async function saveConfig(patch: Partial<DemoConfig>) {
    if (!config) return;
    setBusy('config');
    const { error } = await supabase
      .from('SchoolWebDemoConfig')
      .update({ ...patch, updated_at: new Date().toISOString() })
      .eq('id_school', config.id_school);
    setBusy(null);
    if (error) {
      setMessage({ text: `บันทึกไม่สำเร็จ: ${error.message}`, error: true });
      return;
    }
    setConfig({ ...config, ...patch });
    setMessage({ text: 'บันทึกการตั้งค่าแล้ว' });
  }

  async function resetData() {
    if (!config) return;
    if (
      !window.confirm(
        'ล้างข้อมูลงานทั้งหมดของโรงเรียนทดลอง (นักเรียน ห้องเรียน วิชา ตารางสอน คะแนน ประกาศ) แล้วเติมชุดตั้งต้นใหม่?\nบัญชีผู้ทดลองไม่ถูกลบ · ย้อนกลับไม่ได้',
      )
    )
      return;
    setBusy('reset');
    const { data, error } = await supabase.rpc('reset_demo_school_data', { target: config.id_school });
    setBusy(null);
    if (error) {
      setMessage({ text: `รีเซ็ตไม่สำเร็จ: ${error.message}`, error: true });
      return;
    }
    const r = data as { students?: number; subjects?: number; grades?: number } | null;
    setMessage({
      text: `รีเซ็ตแล้ว: นักเรียน ${r?.students ?? '-'} · วิชา ${r?.subjects ?? '-'} · คะแนน ${r?.grades ?? '-'} · คาบสอนของผู้ทดลองถูกล้าง (สมัครใหม่จะได้คาบใหม่)`,
    });
  }

  async function deleteAccounts(body: Record<string, unknown>, confirmText: string) {
    if (!window.confirm(`${confirmText}\nบัญชีเข้าระบบจะถูกลบถาวร ย้อนกลับไม่ได้`)) return;
    setBusy('delete');
    const { data, error } = await supabase.functions.invoke('trial-register', {
      body: { action: 'delete_accounts', ...body },
    });
    setBusy(null);
    if (error) {
      setMessage({ text: `ลบไม่สำเร็จ: ${await readFunctionError(error)}`, error: true });
      return;
    }
    setMessage({ text: `ลบบัญชีทดลองแล้ว ${(data as { deleted?: number })?.deleted ?? 0} บัญชี` });
    await load();
  }

  const toggle = (id: number) =>
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });

  if (!loading && !config) {
    return (
      <div className="surface-card p-8">
        <EmptyState>ยังไม่ได้ตั้งค่าโรงเรียนทดลอง (รัน supabase/school_web_demo_setup.sql)</EmptyState>
      </div>
    );
  }

  return (
    <div>
      <PageHeader
        category="ศูนย์ส่วนกลาง"
        title="โรงเรียนทดลองใช้"
        description={`${schoolName || 'โรงเรียนทดลอง'} · ผู้สมัครได้สิทธิ์ครู + เจ้าหน้าที่ 4 ฝ่ายของโรงเรียนนี้เท่านั้น · หน้าสมัคร /register`}
      />
      <Notice message={message} />

      {config && (
        <div className="grid gap-4 lg:grid-cols-2">
          <section className="surface-card space-y-4 p-5">
            <h2 className="text-sm font-semibold text-ink">การรับสมัคร</h2>
            <label className="flex items-center justify-between gap-3 text-sm">
              <span>
                เปิดรับสมัครทดลองใช้
                <span className="block text-xs text-slate-500">ปิดแล้วหน้า /register จะแจ้งว่าปิดรับสมัคร</span>
              </span>
              <input
                type="checkbox"
                className="h-5 w-5"
                checked={config.demo_signup_enabled}
                disabled={busy !== null}
                onChange={(e) => saveConfig({ demo_signup_enabled: e.target.checked })}
              />
            </label>
            <label className="flex items-center justify-between gap-3 text-sm">
              <span>
                อายุบัญชีทดลอง (วัน)
                <span className="block text-xs text-slate-500">มีผลกับผู้สมัครใหม่</span>
              </span>
              <select
                className="input w-24 py-1.5 text-sm"
                value={config.account_ttl_days}
                disabled={busy !== null}
                onChange={(e) => saveConfig({ account_ttl_days: Number(e.target.value) })}
              >
                {[1, 3, 7, 14, 30].map((d) => (
                  <option key={d} value={d}>
                    {d}
                  </option>
                ))}
              </select>
            </label>
          </section>

          <section className="surface-card space-y-3 p-5">
            <h2 className="text-sm font-semibold text-ink">ข้อมูลของโรงเรียนทดลอง</h2>
            <p className="text-xs leading-relaxed text-slate-500">
              ผู้ทดลองเพิ่ม / แก้ / ลบข้อมูลได้อิสระ กดรีเซ็ตเพื่อกลับเป็นชุดตั้งต้น (นักเรียน 1,200 คน 30 ห้อง 87 วิชา
              ตารางสอน คะแนน SGS ประกาศ) — ข้อมูลสมมุติทั้งหมด
            </p>
            <button
              type="button"
              className="btn-secondary"
              disabled={busy !== null}
              onClick={resetData}
            >
              <RotateCcw className="h-4 w-4" />
              {busy === 'reset' ? 'กำลังรีเซ็ต…' : 'รีเซ็ตข้อมูลตั้งต้น'}
            </button>
          </section>
        </div>
      )}

      <section className="surface-card mt-4 p-5">
        <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
          <h2 className="text-sm font-semibold text-ink">
            บัญชีทดลอง ({accounts.length}){expiredCount > 0 ? ` · หมดอายุ ${expiredCount}` : ''}
          </h2>
          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              className="btn-secondary btn-sm"
              disabled={busy !== null || expiredCount === 0}
              onClick={() => deleteAccounts({ expired_only: true }, `ลบบัญชีที่หมดอายุ ${expiredCount} บัญชี?`)}
            >
              ลบที่หมดอายุ
            </button>
            <button
              type="button"
              className="btn-secondary btn-sm text-red-700"
              disabled={busy !== null || selected.size === 0}
              onClick={() =>
                deleteAccounts({ id_users: [...selected] }, `ลบบัญชีที่เลือก ${selected.size} บัญชี?`)
              }
            >
              <Trash2 className="h-3.5 w-3.5" />
              ลบที่เลือก ({selected.size})
            </button>
          </div>
        </div>

        {loading ? (
          <EmptyState>กำลังโหลด…</EmptyState>
        ) : accounts.length === 0 ? (
          <EmptyState>ยังไม่มีผู้สมัครทดลอง</EmptyState>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[560px] text-sm">
              <thead>
                <tr className="border-b border-line text-left text-xs text-slate-500">
                  <th className="w-8 py-2" />
                  <th className="py-2">ชื่อ</th>
                  <th className="py-2">ชื่อผู้ใช้</th>
                  <th className="py-2">สมัครเมื่อ</th>
                  <th className="py-2">หมดอายุ</th>
                </tr>
              </thead>
              <tbody>
                {accounts.map((a) => {
                  const expired = new Date(a.expires_at) < new Date();
                  return (
                    <tr key={a.id_user} className="border-b border-line/60">
                      <td className="py-2">
                        <input
                          type="checkbox"
                          checked={selected.has(a.id_user)}
                          onChange={() => toggle(a.id_user)}
                          aria-label={`เลือก ${a.username}`}
                        />
                      </td>
                      <td className="py-2 text-ink">{a.fullName ?? '-'}</td>
                      <td className="py-2 text-slate-600">{a.username}</td>
                      <td className="py-2 text-xs text-slate-500">{fmt(a.created_at)}</td>
                      <td className={`py-2 text-xs ${expired ? 'font-semibold text-red-700' : 'text-slate-500'}`}>
                        {fmt(a.expires_at)}
                        {expired ? ' (หมดอายุ)' : ''}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
