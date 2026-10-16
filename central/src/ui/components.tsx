import type { ReactNode } from 'react';

/** หัวหน้า: ชื่อหน้า + คำอธิบาย + ปุ่มด้านขวา (มือถือ: ปุ่มลงมาบรรทัดใหม่) */
export function PageHeader({
  title,
  description,
  actions,
}: {
  title: ReactNode;
  description?: ReactNode;
  actions?: ReactNode;
}) {
  return (
    <div className="mb-5 flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
      <div className="min-w-0">
        <h1 className="text-xl font-bold tracking-tight sm:text-2xl">{title}</h1>
        {description && <p className="mt-1 text-[13px] text-slate-500">{description}</p>}
      </div>
      {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
    </div>
  );
}

/** การ์ดตัวเลขสรุป */
export function StatCard({
  icon,
  label,
  value,
  hint,
  tone = 'slate',
}: {
  icon: ReactNode;
  label: string;
  value: ReactNode;
  hint?: ReactNode;
  tone?: 'slate' | 'green' | 'amber' | 'red';
}) {
  const hintColor = {
    slate: 'text-slate-500',
    green: 'text-green-600',
    amber: 'text-amber-600',
    red: 'text-red-600',
  }[tone];
  return (
    <div className="card p-4 sm:p-5">
      <div className="flex items-center gap-2 text-[12.5px] text-slate-500">
        <span className="grid h-7 w-7 place-items-center rounded-lg bg-brand-50 text-brand-600">{icon}</span>
        {label}
      </div>
      <div className="mt-2 text-2xl font-bold leading-none sm:text-[28px]">{value}</div>
      {hint && <div className={`mt-1.5 text-xs ${hintColor}`}>{hint}</div>}
    </div>
  );
}

/** ข้อความแจ้ง (สำเร็จ / ผิดพลาด) — ใช้คู่กับ state { text, error } ที่ทุกหน้ามีอยู่แล้ว */
export function Notice({ message }: { message: { text: string; error?: boolean } | null }) {
  if (!message) return null;
  return (
    <div role="status" className={`mb-4 ${message.error ? 'alert-error' : 'alert-ok'}`}>
      {message.text}
    </div>
  );
}

/** สถานะกำลังโหลด / ว่าง ในกล่อง */
export function EmptyState({ children }: { children: ReactNode }) {
  return <div className="px-4 py-10 text-center text-sm text-slate-500">{children}</div>;
}

/** ช่องกรอกพร้อมป้ายชื่อ */
export function Field({
  label,
  hint,
  children,
  className = '',
}: {
  label: ReactNode;
  hint?: ReactNode;
  children: ReactNode;
  className?: string;
}) {
  return (
    <label className={`field ${className}`}>
      <span>{label}</span>
      {children}
      {hint && <span className="field-hint">{hint}</span>}
    </label>
  );
}
