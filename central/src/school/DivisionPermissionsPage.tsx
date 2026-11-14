import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Check, ShieldCheck } from 'lucide-react';
import { rolesForSchool, supabase, type Role } from '../supabase';
import type { DivisionWithModules } from './mapping';
import type { SchoolBasic } from './types';

interface RoleDivisionAccessRow {
  id?: number;
  id_school: number;
  division_id: number;
  id_role: number;
  can_view: boolean;
  can_edit: boolean;
}

interface DivisionPermissionsPageProps {
  school: SchoolBasic | null;
  schoolId: number | null;
  canEdit: boolean;
  divisions: DivisionWithModules[];
  hasDbMapping: boolean;
  onReload: () => Promise<void>;
}

export default function DivisionPermissionsPage({
  school,
  schoolId,
  canEdit,
  divisions,
  hasDbMapping,
  onReload,
}: DivisionPermissionsPageProps) {
  const [roles, setRoles] = useState<Role[]>([]);
  const [accessMap, setAccessMap] = useState<
    Record<string, { can_view: boolean; can_edit: boolean }>
  >({});
  const [selectedDivId, setSelectedDivId] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [busyKey, setBusyKey] = useState<string | null>(null);
  const [message, setMessage] = useState<{
    type: 'ok' | 'err';
    text: string;
  } | null>(null);

  const selectedDivision =
    divisions.find((d) => d.id === selectedDivId) ?? divisions[0] ?? null;

  const loadData = useCallback(async () => {
    if (!schoolId) return;
    setLoading(true);
    const [rolesRes, accessRes] = await Promise.all([
      supabase
        .from('roles')
        .select('ID_Roles, Accessrights, id_school')
        .order('ID_Roles', { ascending: true }),
      supabase
        .from('SchoolWebRoleDivisionAccess')
        .select('id, id_school, division_id, id_role, can_view, can_edit')
        .eq('id_school', schoolId),
    ]);

    const allRoles = (rolesRes.data as Role[] | null) ?? [];
    setRoles(rolesForSchool(allRoles, schoolId));

    const map: Record<string, { can_view: boolean; can_edit: boolean }> = {};
    for (const row of (accessRes.data as RoleDivisionAccessRow[] | null) ?? []) {
      map[`${row.division_id}:${row.id_role}`] = {
        can_view: row.can_view,
        can_edit: row.can_edit,
      };
    }
    setAccessMap(map);
    setLoading(false);
  }, [schoolId]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  useEffect(() => {
    if (divisions.length > 0 && selectedDivId === null) {
      setSelectedDivId(divisions[0].id);
    }
  }, [divisions, selectedDivId]);

  async function seedDivisionsFirst() {
    if (!schoolId || !canEdit) return;
    setBusyKey('seed');
    setMessage(null);
    const { error } = await supabase.rpc('seed_school_web_divisions', {
      target_school_id: schoolId,
    });
    setBusyKey(null);
    if (error) {
      setMessage({
        type: 'err',
        text: `สร้างโครงสร้างฝ่ายไม่สำเร็จ: ${error.message}`,
      });
      return;
    }
    await onReload();
    await loadData();
    setMessage({
      type: 'ok',
      text: 'สร้างโครงสร้างฝ่ายเริ่มต้นของโรงเรียนเรียบร้อยแล้ว',
    });
  }

  async function updatePermission(
    divisionId: number,
    roleId: number,
    nextView: boolean,
    nextEdit: boolean,
  ) {
    if (!schoolId || !canEdit || divisionId < 0) return;
    const key = `${divisionId}:${roleId}`;
    setBusyKey(key);
    setMessage(null);

    const finalView = nextEdit ? true : nextView;
    const finalEdit = finalView ? nextEdit : false;

    const { error } = await supabase.from('SchoolWebRoleDivisionAccess').upsert(
      {
        id_school: schoolId,
        division_id: divisionId,
        id_role: roleId,
        can_view: finalView,
        can_edit: finalEdit,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'division_id,id_role' },
    );

    setBusyKey(null);
    if (error) {
      setMessage({
        type: 'err',
        text: `บันทึกสิทธิ์ไม่สำเร็จ: ${error.message} (ตรวจสอบว่ารันไฟล์ supabase/school_web_part4_permissions_finance.sql แล้ว)`,
      });
      return;
    }

    setAccessMap((prev) => ({
      ...prev,
      [key]: { can_view: finalView, can_edit: finalEdit },
    }));
    await onReload();
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="text-xs font-medium text-brand-600">
            โหมดผู้ดูแลระบบกลาง · สิทธิ์ตามโครงสร้างฝ่าย
          </p>
          <h1 className="mt-1 text-2xl font-semibold tracking-tight text-ink">
            สิทธิ์เข้าถึงและแก้ไขข้อมูลแต่ละฝ่าย
          </h1>
          <p className="mt-1 text-sm text-slate-600">
            กำหนดว่าบทบาท (Role) ใดใน {school?.fullName || 'โรงเรียน'} สามารถเปิดดูหรือจัดการข้อมูลในแต่ละฝ่ายได้
          </p>
        </div>

        <Link to="/admin/mapping" className="btn-secondary btn-sm shrink-0">
          จัดการฝ่ายและ Module
        </Link>
      </div>

      {message && (
        <div
          className={`rounded-xl border px-4 py-3 text-xs font-medium ${
            message.type === 'ok'
              ? 'border-emerald-200 bg-emerald-50 text-emerald-800'
              : 'border-rose-200 bg-rose-50 text-rose-700'
          }`}
        >
          {message.text}
        </div>
      )}

      {!hasDbMapping ? (
        <div className="surface-card p-6">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h2 className="text-base font-semibold text-ink">
                ต้องเปิดใช้งานโครงสร้างฝ่ายของโรงเรียนในฐานข้อมูลก่อน
              </h2>
              <p className="mt-1 text-xs text-slate-600">
                กดปุ่มด้านขวาเพื่อสร้างรายการฝ่ายเริ่มต้นของโรงเรียน แล้วจึงกำหนดสิทธิ์รายบทบาทได้
              </p>
            </div>
            {canEdit && (
              <button
                type="button"
                disabled={busyKey === 'seed'}
                onClick={seedDivisionsFirst}
                className="btn-primary shrink-0"
              >
                {busyKey === 'seed'
                  ? 'กำลังสร้างโครงสร้าง...'
                  : 'สร้างโครงสร้างฝ่ายเริ่มต้น'}
              </button>
            )}
          </div>
        </div>
      ) : (
        <div className="grid gap-6 lg:grid-cols-12">
          {/* เลือกฝ่ายทางซ้าย */}
          <div className="space-y-3 lg:col-span-4">
            <h2 className="text-sm font-semibold text-ink">
              1. เลือกฝ่ายงาน ({divisions.length})
            </h2>
            <div className="space-y-2">
              {divisions.map((div) => {
                const isSelected = selectedDivision?.id === div.id;
                return (
                  <button
                    key={div.id}
                    type="button"
                    onClick={() => setSelectedDivId(div.id)}
                    className={`w-full rounded-xl border p-4 text-left transition-colors ${
                      isSelected
                        ? 'border-brand-500 bg-white ring-1 ring-brand-500'
                        : 'border-line bg-white hover:border-slate-300'
                    }`}
                  >
                    <div className="flex items-center justify-between gap-2">
                      <p className="text-sm font-semibold text-ink">{div.name}</p>
                      <span
                        className={`rounded-md px-2 py-0.5 text-[11px] font-medium ${
                          div.is_enabled
                            ? 'bg-emerald-50 text-emerald-700'
                            : 'bg-slate-100 text-slate-500'
                        }`}
                      >
                        {div.is_enabled ? 'เปิดใช้' : 'ปิดอยู่'}
                      </span>
                    </div>
                    {div.description && (
                      <p className="mt-1 line-clamp-1 text-xs text-slate-500">
                        {div.description}
                      </p>
                    )}
                  </button>
                );
              })}
            </div>
          </div>

          {/* ตารางกำหนดสิทธิ์ตาม Role ทางขวา */}
          <div className="lg:col-span-8">
            {selectedDivision && (
              <div className="surface-card overflow-hidden">
                <div className="border-b border-line px-6 py-4">
                  <div className="flex items-center gap-2">
                    <ShieldCheck
                      className="h-[18px] w-[18px] text-brand-600"
                      strokeWidth={1.5}
                    />
                    <h2 className="text-base font-semibold text-ink">
                      2. สิทธิ์ของแต่ละบทบาทใน "{selectedDivision.name}"
                    </h2>
                  </div>
                  <p className="mt-0.5 text-xs text-slate-500">
                    ค่าเริ่มต้นอนุญาตให้บุคลากรทุกคนเปิดดูได้ ส่วนสิทธิ์แก้ไขข้อมูลในฝ่ายจะเปิดเฉพาะผู้ดูแลระบบหรือบทบาทที่ติ๊ก "แก้ไขข้อมูลในฝ่าย"
                  </p>
                </div>

                {loading ? (
                  <div className="p-8 text-center text-sm text-slate-500">
                    กำลังโหลดรายการบทบาท...
                  </div>
                ) : roles.length === 0 ? (
                  <div className="p-8 text-center text-sm text-slate-500">
                    ไม่พบข้อมูลตารางบทบาท (roles)
                  </div>
                ) : (
                  <div className="overflow-x-auto">
                    <table className="w-full border-collapse text-left text-sm">
                      <thead>
                        <tr className="border-b border-line bg-canvas text-xs font-medium text-slate-500">
                          <th className="px-6 py-3">รหัส</th>
                          <th className="px-6 py-3">ชื่อบทบาท (Role)</th>
                          <th className="px-6 py-3 text-center">เปิดดูฝ่ายนี้ได้</th>
                          <th className="px-6 py-3 text-center">
                            จัดการ/แก้ไขข้อมูลในฝ่าย
                          </th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-line">
                        {roles.map((role) => {
                          const key = `${selectedDivision.id}:${role.ID_Roles}`;
                          const current = accessMap[key] ?? {
                            can_view: true,
                            can_edit: false,
                          };
                          const isBusy = busyKey === key;

                          return (
                            <tr key={role.ID_Roles} className="hover:bg-slate-50/70">
                              <td className="px-6 py-3.5 tabular-nums text-xs text-slate-500">
                                #{role.ID_Roles}
                              </td>
                              <td className="px-6 py-3.5 font-medium text-ink">
                                {role.Accessrights}
                              </td>
                              <td className="px-6 py-3.5 text-center">
                                <button
                                  type="button"
                                  disabled={!canEdit || isBusy}
                                  onClick={() =>
                                    updatePermission(
                                      selectedDivision.id,
                                      role.ID_Roles,
                                      !current.can_view,
                                      current.can_edit,
                                    )
                                  }
                                  className={`inline-flex h-6 w-6 items-center justify-center rounded-md border transition-colors ${
                                    current.can_view
                                      ? 'border-brand-600 bg-brand-600 text-white'
                                      : 'border-slate-300 bg-white text-transparent hover:border-slate-400'
                                  }`}
                                  aria-label="เปิดดูฝ่ายนี้ได้"
                                >
                                  <Check className="h-3.5 w-3.5" strokeWidth={2} />
                                </button>
                              </td>
                              <td className="px-6 py-3.5 text-center">
                                <button
                                  type="button"
                                  disabled={!canEdit || isBusy}
                                  onClick={() =>
                                    updatePermission(
                                      selectedDivision.id,
                                      role.ID_Roles,
                                      current.can_view,
                                      !current.can_edit,
                                    )
                                  }
                                  className={`inline-flex h-6 w-6 items-center justify-center rounded-md border transition-colors ${
                                    current.can_edit
                                      ? 'border-emerald-600 bg-emerald-600 text-white'
                                      : 'border-slate-300 bg-white text-transparent hover:border-slate-400'
                                  }`}
                                  aria-label="จัดการแก้ไขข้อมูลในฝ่าย"
                                >
                                  <Check className="h-3.5 w-3.5" strokeWidth={2} />
                                </button>
                              </td>
                            </tr>
                          );
                        })}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
