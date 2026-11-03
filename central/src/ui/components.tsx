import type { ReactNode } from 'react';

/** หัวหน้า: ป้ายหมวดหมู่ + ชื่อหน้า + คำอธิบาย + ปุ่มด้านขวา (มือถือ: ปุ่มลงมาบรรทัดใหม่) */
export function PageHeader({
  category,
  title,
  description,
  actions,
}: {
  category?: ReactNode;
  title: ReactNode;
  description?: ReactNode;
  actions?: ReactNode;
}) {
  return (
    <div className="mb-6 flex flex-col gap-3 border-b border-slate-200/70 pb-4 sm:flex-row sm:items-end sm:justify-between">
      <div className="min-w-0">
        {category && (
          <div className="mb-1.5 inline-flex items-center gap-1.5 rounded-full bg-brand-50 px-2.5 py-0.5 text-[11px] font-semibold tracking-wide text-brand-700">
            {category}
          </div>
        )}
        <h1 className="text-xl font-bold tracking-tight text-ink sm:text-2xl">{title}</h1>
        {description && <p className="mt-1 max-w-3xl text-[13px] leading-relaxed text-slate-500">{description}</p>}
      </div>
      {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
    </div>
  );
}

/** หัวหมวดหมู่ย่อยในหน้า — ช่วยแบ่งกลุ่มข้อมูลให้สบายตา */
export function SectionHeader({
  step,
  title,
  subtitle,
  badge,
  actions,
}: {
  step?: string | number;
  title: ReactNode;
  subtitle?: ReactNode;
  badge?: ReactNode;
  actions?: ReactNode;
}) {
  return (
    <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
      <div className="flex min-w-0 items-center gap-2.5">
        {step !== undefined && (
          <span className="grid h-6 w-6 shrink-0 place-items-center rounded-lg bg-brand-600 text-xs font-bold text-white shadow-sm">
            {step}
          </span>
        )}
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <h2 className="text-[14.5px] font-bold text-ink">{title}</h2>
            {badge}
          </div>
          {subtitle && <p className="text-xs text-slate-500">{subtitle}</p>}
        </div>
      </div>
      {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
    </div>
  );
}

/** การ์ดตัวเลขสรุป แยกสีตามความหมาย */
export function StatCard({
  icon,
  label,
  value,
  hint,
  tone = 'brand',
}: {
  icon: ReactNode;
  label: string;
  value: ReactNode;
  hint?: ReactNode;
  tone?: 'slate' | 'brand' | 'green' | 'amber' | 'red';
}) {
  const palette = {
    brand: {
      iconBg: 'bg-brand-50 text-brand-600 ring-1 ring-brand-500/15',
      hint: 'text-slate-500',
      value: 'text-ink',
    },
    slate: {
      iconBg: 'bg-slate-100 text-slate-600 ring-1 ring-slate-500/10',
      hint: 'text-slate-500',
      value: 'text-ink',
    },
    green: {
      iconBg: 'bg-emerald-50 text-emerald-600 ring-1 ring-emerald-500/15',
      hint: 'text-emerald-700',
      value: 'text-emerald-700',
    },
    amber: {
      iconBg: 'bg-amber-50 text-amber-600 ring-1 ring-amber-500/15',
      hint: 'text-amber-700',
      value: 'text-amber-700',
    },
    red: {
      iconBg: 'bg-red-50 text-red-600 ring-1 ring-red-500/15',
      hint: 'text-red-600',
      value: 'text-red-700',
    },
  }[tone];

  return (
    <div className="card flex flex-col justify-between p-4 sm:p-5">
      <div className="flex items-center justify-between gap-2 text-[12.5px] font-medium text-slate-500">
        <span className="truncate">{label}</span>
        <span className={`grid h-8 w-8 shrink-0 place-items-center rounded-xl ${palette.iconBg}`}>{icon}</span>
      </div>
      <div className="mt-2.5">
        <div className={`text-2xl font-bold leading-none tabular-nums sm:text-[28px] ${palette.value}`}>{value}</div>
        {hint && <div className={`mt-1.5 text-xs font-medium ${palette.hint}`}>{hint}</div>}
      </div>
    </div>
  );
}

/** ข้อความแจ้ง (สำเร็จ / ผิดพลาด) — ใช้คู่กับ state { text, error } ที่ทุกหน้ามีอยู่แล้ว */
export function Notice({ message }: { message: { text: string; error?: boolean } | null }) {
  if (!message) return null;
  return (
    <div role="status" className={`mb-4 flex items-center gap-2 ${message.error ? 'alert-error' : 'alert-ok'}`}>
      <span className="text-base leading-none">{message.error ? '⚠️' : '✅'}</span>
      <span className="flex-1">{message.text}</span>
    </div>
  );
}

/** สถานะกำลังโหลด / ว่าง ในกล่อง */
export function EmptyState({ children }: { children: ReactNode }) {
  return <div className="px-4 py-12 text-center text-sm text-slate-500">{children}</div>;
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
