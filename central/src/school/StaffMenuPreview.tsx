import { useMemo } from 'react';
import type { DivisionWithModules } from './mapping';
import type { RoleDivisionModulePermissions } from './roleModulePermissions';
import {
  ACCESS_SOURCE_LABEL,
  explainDivisionAccess,
  inferRoleTierFromRoleName,
  ROLE_TIER_META,
  type AccessDecision,
  type SchoolStaffMember,
} from './staffDivisionMapping';

/**
 * ดูตัวอย่างเมนูซ้ายที่บุคลากรคนนี้เห็นจริงในเว็บโรงเรียน
 * ใช้ตัวตัดสินสิทธิ์ชุดเดียวกับเมนูจริง (explainDivisionAccess) จึงตรงกันเสมอ
 */
export default function StaffMenuPreview({
  staff,
  divisions,
  perms,
}: {
  staff: SchoolStaffMember;
  divisions: DivisionWithModules[];
  perms: RoleDivisionModulePermissions;
}) {
  const tier = inferRoleTierFromRoleName(
    staff.roleName,
    staff.is_super_admin,
    staff.id_role,
    perms,
  );

  const rows = useMemo(
    () =>
      explainDivisionAccess({
        divisions: divisions.filter((d) => d.is_enabled),
        perms,
        roleTier: tier,
        roleId: staff.id_role,
        idUser: staff.id_user,
      }),
    [divisions, perms, tier, staff.id_role, staff.id_user],
  );

  const visibleCount = rows.filter(
    (r) =>
      r.access.level !== 'hidden' ||
      r.modules.some((m) => m.access.level !== 'hidden'),
  ).length;

  return (
    <div className="surface-card p-6 space-y-4">
      <div className="flex flex-col gap-1 border-b border-line pb-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-base font-semibold text-ink">
            เมนูที่ {staff.fullName} เห็นจริง
          </h2>
          <p className="mt-0.5 text-xs text-slate-500">
            คำนวณจากตัวตัดสินสิทธิ์เดียวกับเมนูซ้ายของเว็บโรงเรียน · ป้ายสีเทาบอกว่าได้สิทธิ์มาจากไหน
          </p>
        </div>
        <span
          className={`self-start rounded-full px-2.5 py-0.5 text-[11px] font-semibold ${ROLE_TIER_META[tier].badgeClass}`}
        >
          {ROLE_TIER_META[tier].shortLabel}
        </span>
      </div>

      {visibleCount === 0 && (
        <p className="rounded-lg bg-canvas px-3 py-2 text-xs text-slate-600">
          ไม่เห็นฝ่ายใดเลย — ใช้งานได้เฉพาะ &ldquo;งานของฉัน&rdquo; (ครูผู้สอน)
          ถ้าต้องการให้ทำงานในฝ่าย ให้ผูกสังกัดฝ่ายที่หน้า &ldquo;ฝ่ายและบุคลากร&rdquo;
        </p>
      )}

      <ul className="space-y-3">
        {rows.map((row) => (
          <li key={row.division.id} className="space-y-1">
            <AccessLine
              label={row.division.name}
              access={row.access}
              strong
            />
            <ul className="space-y-0.5 pl-5">
              {row.modules.map((m) => (
                <li key={m.module.id}>
                  <AccessLine label={m.module.title} access={m.access} />
                </li>
              ))}
            </ul>
          </li>
        ))}
      </ul>
    </div>
  );
}

const LEVEL_TEXT: Record<AccessDecision['level'], string> = {
  hidden: 'ไม่เห็น',
  view: 'ดู',
  edit: 'แก้ไข',
};

const LEVEL_CLASS: Record<AccessDecision['level'], string> = {
  hidden: 'text-slate-400',
  view: 'text-brand-700',
  edit: 'text-emerald-700',
};

function AccessLine({
  label,
  access,
  strong = false,
}: {
  label: string;
  access: AccessDecision;
  strong?: boolean;
}) {
  const hidden = access.level === 'hidden';
  return (
    <div className="flex items-center justify-between gap-3 text-xs">
      <span
        className={`truncate ${strong ? 'font-semibold' : ''} ${
          hidden ? 'text-slate-400 line-through' : 'text-ink'
        }`}
      >
        {label}
      </span>
      <span className="flex shrink-0 items-center gap-1.5">
        <span className="rounded bg-canvas px-1.5 py-0.5 text-[10px] text-slate-500">
          {ACCESS_SOURCE_LABEL[access.source]}
        </span>
        <span className={`w-10 text-right font-semibold ${LEVEL_CLASS[access.level]}`}>
          {LEVEL_TEXT[access.level]}
        </span>
      </span>
    </div>
  );
}
