import { useCallback, useEffect, useState } from 'react';
import { Check, Layers, Power, ShieldAlert, Sparkles } from 'lucide-react';
import {
  fetchSchoolPackageConfig,
  saveSchoolPackageEntries,
  SCHOOL_DIVISION_MENU_IDS,
  SCHOOL_DIVISION_META,
  SCHOOL_MODULE_MENU_IDS,
  SCHOOL_MODULE_META,
  SCHOOL_WEB_ENABLED_MENU_ID,
  type SchoolPackageConfig,
} from './schoolPackage';

interface SchoolPackagePanelProps {
  schoolId: number | null;
  schoolName?: string;
  canManage: boolean;
  onUpdated?: () => Promise<void> | void;
}

export default function SchoolPackagePanel({
  schoolId,
  schoolName = 'โรงเรียน',
  canManage,
  onUpdated,
}: SchoolPackagePanelProps) {
  const [config, setConfig] = useState<SchoolPackageConfig | null>(null);
  const [loading, setLoading] = useState(false);
  const [busyKey, setBusyKey] = useState<string | null>(null);
  const [feedback, setFeedback] = useState<{
    type: 'ok' | 'err';
    text: string;
  } | null>(null);

  const load = useCallback(async () => {
    if (!schoolId) return;
    setLoading(true);
    const pkg = await fetchSchoolPackageConfig(schoolId);
    setConfig(pkg);
    setLoading(false);
  }, [schoolId]);

  useEffect(() => {
    load();
  }, [load]);

  if (!schoolId) return null;

  async function handleToggleSchoolWeb(nextEnabled: boolean) {
    if (!schoolId || !canManage || !config) return;
    setBusyKey('web-master');
    setFeedback(null);

    const { error } = await saveSchoolPackageEntries(schoolId, [
      { menuId: SCHOOL_WEB_ENABLED_MENU_ID, enabled: nextEnabled },
    ]);

    setBusyKey(null);
    if (error) {
      setFeedback({ type: 'err', text: `บันทึกไม่สำเร็จ: ${error}` });
      return;
    }

    setConfig({ ...config, schoolWebEnabled: nextEnabled });
    setFeedback({
      type: 'ok',
      text: nextEnabled
        ? `เปิดใช้งาน "เว็บโรงเรียน" สำหรับ ${schoolName} เรียบร้อยแล้ว`
        : `ตั้งค่าให้ ${schoolName} ใช้งานเฉพาะระบบวันลา (ซ่อนเว็บโรงเรียน) เรียบร้อยแล้ว`,
    });
    await onUpdated?.();
  }

  async function handleToggleDivision(divKey: string, nextAllowed: boolean) {
    if (!schoolId || !canManage || !config) return;
    const menuId = SCHOOL_DIVISION_MENU_IDS[divKey];
    if (!menuId) return;

    setBusyKey(`div:${divKey}`);
    setFeedback(null);

    const { error } = await saveSchoolPackageEntries(schoolId, [
      { menuId, enabled: nextAllowed },
    ]);

    setBusyKey(null);
    if (error) {
      setFeedback({ type: 'err', text: `บันทึกไม่สำเร็จ: ${error}` });
      return;
    }

    setConfig({
      ...config,
      allowedDivisions: {
        ...config.allowedDivisions,
        [divKey]: nextAllowed,
      },
    });
    setFeedback({
      type: 'ok',
      text: `อัปเดตฝ่ายงานของ ${schoolName} เรียบร้อยแล้ว`,
    });
    await onUpdated?.();
  }

  async function handleToggleModule(modKey: string, nextAllowed: boolean) {
    if (!schoolId || !canManage || !config) return;
    const menuId = SCHOOL_MODULE_MENU_IDS[modKey];
    if (!menuId) return;

    setBusyKey(`mod:${modKey}`);
    setFeedback(null);

    const { error } = await saveSchoolPackageEntries(schoolId, [
      { menuId, enabled: nextAllowed },
    ]);

    setBusyKey(null);
    if (error) {
      setFeedback({ type: 'err', text: `บันทึกไม่สำเร็จ: ${error}` });
      return;
    }

    setConfig({
      ...config,
      allowedModules: {
        ...config.allowedModules,
        [modKey]: nextAllowed,
      },
    });
    setFeedback({
      type: 'ok',
      text: `อัปเดตระบบงานของ ${schoolName} เรียบร้อยแล้ว`,
    });
    await onUpdated?.();
  }

  async function applyPreset(preset: 'all' | 'hr_only' | 'leave_subweb_only') {
    if (!schoolId || !canManage) return;
    setBusyKey(`preset:${preset}`);
    setFeedback(null);

    const entries: { menuId: number; enabled: boolean }[] = [];

    if (preset === 'leave_subweb_only') {
      entries.push({ menuId: SCHOOL_WEB_ENABLED_MENU_ID, enabled: false });
      for (const d of SCHOOL_DIVISION_META) {
        entries.push({ menuId: d.menuId, enabled: d.key === 'hr' });
      }
      for (const m of SCHOOL_MODULE_META) {
        entries.push({ menuId: m.menuId, enabled: m.key === 'leave-system' });
      }
    } else if (preset === 'hr_only') {
      entries.push({ menuId: SCHOOL_WEB_ENABLED_MENU_ID, enabled: true });
      for (const d of SCHOOL_DIVISION_META) {
        entries.push({ menuId: d.menuId, enabled: d.key === 'hr' });
      }
      const hrAllowedKeys = new Set([
        'leave-system',
        'staff-registry',
        'departments',
        'appointment-orders',
      ]);
      for (const m of SCHOOL_MODULE_META) {
        entries.push({
          menuId: m.menuId,
          enabled: hrAllowedKeys.has(m.key),
        });
      }
    } else {
      entries.push({ menuId: SCHOOL_WEB_ENABLED_MENU_ID, enabled: true });
      for (const d of SCHOOL_DIVISION_META) {
        entries.push({ menuId: d.menuId, enabled: true });
      }
      for (const m of SCHOOL_MODULE_META) {
        entries.push({ menuId: m.menuId, enabled: true });
      }
    }

    const { error } = await saveSchoolPackageEntries(schoolId, entries);
    setBusyKey(null);

    if (error) {
      setFeedback({ type: 'err', text: `ตั้งค่าชุดสำเร็จรูปไม่สำเร็จ: ${error}` });
      return;
    }

    await load();
    setFeedback({
      type: 'ok',
      text:
        preset === 'leave_subweb_only'
          ? `ตั้งค่าให้ ${schoolName} ใช้งานเฉพาะระบบวันลาอย่างเดียว (ปิดเว็บโรงเรียน) แล้ว`
          : preset === 'hr_only'
            ? `ตั้งค่าให้ ${schoolName} ใช้เว็บโรงเรียนเฉพาะฝ่ายบริหารงานบุคคลและคำสั่งแต่งตั้งแล้ว`
            : `เปิดใช้งานเว็บโรงเรียนและทุกระบบงานให้ ${schoolName} ครบทั้งหมดแล้ว`,
    });
    await onUpdated?.();
  }

  const enabledModCount = config
    ? SCHOOL_MODULE_META.filter((m) => config.allowedModules[m.key] !== false)
        .length
    : SCHOOL_MODULE_META.length;

  const enabledDivCount = config
    ? SCHOOL_DIVISION_META.filter((d) => config.allowedDivisions[d.key] !== false)
        .length
    : SCHOOL_DIVISION_META.length;

  return (
    <div className="surface-card overflow-hidden border-brand-200">
      {/* Header */}
      <div className="border-b border-line bg-brand-50/40 px-6 py-4">
        <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <div className="inline-flex items-center gap-1.5 rounded-full bg-brand-100 px-2.5 py-0.5 text-[11px] font-semibold text-brand-700">
              <Layers className="h-3.5 w-3.5" />
              <span>ขอบเขตระดับโรงเรียน (กำหนดโดยผู้ดูแลส่วนกลาง)</span>
            </div>
            <h2 className="mt-1.5 text-base font-semibold text-ink">
              ระบบงานที่เปิดให้โรงเรียนใช้งาน: {schoolName}
            </h2>
            <p className="mt-0.5 text-xs text-slate-600">
              กำหนดว่าโรงเรียนนี้จะเปิดใช้ &ldquo;เว็บโรงเรียน&rdquo; หรือใช้เฉพาะ &ldquo;ระบบวันลา&rdquo; และเลือกให้เห็นเฉพาะระบบงานที่อนุญาตเท่านั้น
            </p>
          </div>

          {canManage && (
            <div className="flex flex-wrap items-center gap-2">
              <button
                type="button"
                disabled={busyKey !== null || loading}
                onClick={() => applyPreset('all')}
                className="btn-secondary btn-sm text-xs"
              >
                <Sparkles className="h-3.5 w-3.5 text-brand-600" />
                <span>เปิดครบทุกระบบงาน</span>
              </button>
              <button
                type="button"
                disabled={busyKey !== null || loading}
                onClick={() => applyPreset('hr_only')}
                className="btn-secondary btn-sm text-xs"
              >
                <span>เฉพาะงานบุคคล + คำสั่ง</span>
              </button>
              <button
                type="button"
                disabled={busyKey !== null || loading}
                onClick={() => applyPreset('leave_subweb_only')}
                className="btn-secondary btn-sm text-xs text-amber-700 hover:bg-amber-50"
              >
                <span>เฉพาะระบบวันลา (ปิดเว็บ รร.)</span>
              </button>
            </div>
          )}
        </div>
      </div>

      <div className="space-y-6 p-6">
        {feedback && (
          <div
            className={`rounded-xl border px-4 py-3 text-xs font-medium ${
              feedback.type === 'ok'
                ? 'border-emerald-200 bg-emerald-50 text-emerald-800'
                : 'border-rose-200 bg-rose-50 text-rose-700'
            }`}
          >
            {feedback.text}
          </div>
        )}

        {loading || !config ? (
          <p className="text-xs text-slate-500">กำลังโหลดการตั้งค่าระดับโรงเรียน...</p>
        ) : (
          <>
            {/* 1. Master Toggle: เปิด/ปิด เว็บโรงเรียน */}
            <div
              className={`flex flex-col gap-4 rounded-xl border p-4 sm:flex-row sm:items-center sm:justify-between ${
                config.schoolWebEnabled
                  ? 'border-emerald-200 bg-emerald-50/40'
                  : 'border-amber-200 bg-amber-50/50'
              }`}
            >
              <div className="space-y-1">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="text-sm font-semibold text-ink">
                    1. สถานะการใช้งาน &ldquo;เว็บโรงเรียน&rdquo;
                  </span>
                  <span
                    className={`rounded-full px-2.5 py-0.5 text-[11px] font-semibold ${
                      config.schoolWebEnabled
                        ? 'bg-emerald-100 text-emerald-800'
                        : 'bg-amber-100 text-amber-800'
                    }`}
                  >
                    {config.schoolWebEnabled
                      ? 'เปิดใช้งานเว็บโรงเรียน'
                      : 'ปิดเว็บโรงเรียน (ใช้เฉพาะระบบวันลา)'}
                  </span>
                </div>
                <p className="text-xs text-slate-600">
                  {config.schoolWebEnabled
                    ? 'บุคลากรของโรงเรียนนี้สามารถกดเมนู "เว็บโรงเรียน" บนจอคอมและเข้าใช้งานระบบงานที่เปิดไว้ด้านล่างได้'
                    : 'ซ่อนเมนู "เว็บโรงเรียน" บนแอประบบวันลาของโรงเรียนนี้ทั้งหมด (บุคลากรจะใช้งานได้เฉพาะแอประบบวันลาเท่านั้น)'}
                </p>
              </div>

              <button
                type="button"
                disabled={!canManage || busyKey === 'web-master'}
                onClick={() => handleToggleSchoolWeb(!config.schoolWebEnabled)}
                className={`inline-flex shrink-0 items-center gap-2 rounded-xl px-4 py-2.5 text-xs font-semibold transition-colors ${
                  config.schoolWebEnabled
                    ? 'bg-emerald-600 text-white hover:bg-emerald-700'
                    : 'bg-white text-slate-700 ring-1 ring-slate-300 hover:bg-slate-50'
                } disabled:opacity-50`}
              >
                <Power className="h-4 w-4" />
                <span>
                  {config.schoolWebEnabled
                    ? 'เปิดเว็บโรงเรียนอยู่ (คลิกเพื่อปิด)'
                    : 'ปิดเว็บโรงเรียนอยู่ (คลิกเพื่อเปิด)'}
                </span>
              </button>
            </div>

            {!config.schoolWebEnabled && (
              <div className="flex items-start gap-2.5 rounded-xl border border-amber-200 bg-amber-50/70 px-4 py-3 text-xs text-amber-900">
                <ShieldAlert className="mt-0.5 h-4 w-4 shrink-0 text-amber-600" />
                <div>
                  ขณะนี้ <strong>{schoolName}</strong> ถูกตั้งค่าให้ใช้งานเฉพาะ{' '}
                  <strong>ระบบวันลา</strong> เท่านั้น เมนู &ldquo;เว็บโรงเรียน&rdquo; จะถูกซ่อนจากหน้าจอคอมของโรงเรียนนี้โดยอัตโนมัติ
                </div>
              </div>
            )}

            {/* 2. ฝ่ายงานที่อนุญาตให้โรงเรียนนี้เห็น */}
            <div>
              <div className="mb-3 flex items-center justify-between">
                <div>
                  <h3 className="text-sm font-semibold text-ink">
                    2. ฝ่ายงานที่เปิดให้โรงเรียนนี้ใช้งาน ({enabledDivCount}/
                    {SCHOOL_DIVISION_META.length} ฝ่าย)
                  </h3>
                  <p className="text-xs text-slate-500">
                    ฝ่ายที่ถูกปิดไว้จะไม่แสดงในเมนูซ้ายและหน้าแรกของโรงเรียนนี้เลย
                  </p>
                </div>
              </div>

              <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                {SCHOOL_DIVISION_META.map((div) => {
                  const allowed = config.allowedDivisions[div.key] !== false;
                  const isBusy = busyKey === `div:${div.key}`;
                  return (
                    <div
                      key={div.key}
                      className={`flex items-start justify-between gap-3 rounded-xl border p-3.5 transition-colors ${
                        allowed
                          ? 'border-brand-200 bg-brand-50/30'
                          : 'border-line bg-slate-50/70 opacity-75'
                      }`}
                    >
                      <div className="min-w-0">
                        <p className="text-xs font-semibold text-ink">
                          {div.title}
                        </p>
                        <p className="mt-0.5 line-clamp-2 text-[11px] text-slate-500">
                          {div.description}
                        </p>
                        <span
                          className={`mt-1.5 inline-block rounded px-1.5 py-0.5 text-[10px] font-semibold ${
                            allowed
                              ? 'bg-emerald-100 text-emerald-700'
                              : 'bg-slate-200 text-slate-600'
                          }`}
                        >
                          {allowed ? 'เปิดให้โรงเรียนเห็น' : 'ซ่อนจากโรงเรียนนี้'}
                        </span>
                      </div>

                      <button
                        type="button"
                        disabled={!canManage || isBusy}
                        onClick={() => handleToggleDivision(div.key, !allowed)}
                        className={`inline-flex h-6 w-6 shrink-0 items-center justify-center rounded-md border transition-colors ${
                          allowed
                            ? 'border-brand-600 bg-brand-600 text-white'
                            : 'border-slate-300 bg-white text-transparent hover:border-slate-400'
                        } disabled:opacity-50`}
                        aria-label={`เปิดหรือปิด ${div.title}`}
                      >
                        <Check className="h-3.5 w-3.5" strokeWidth={2.2} />
                      </button>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* 3. ระบบงานที่อนุญาตให้โรงเรียนนี้เห็น */}
            <div>
              <div className="mb-3 flex items-center justify-between">
                <div>
                  <h3 className="text-sm font-semibold text-ink">
                    3. ระบบงานที่เปิดให้โรงเรียนนี้ใช้งาน ({enabledModCount}/
                    {SCHOOL_MODULE_META.length} ระบบงาน)
                  </h3>
                  <p className="text-xs text-slate-500">
                    ติ๊กเลือกเฉพาะระบบงานที่ต้องการเปิดให้โรงเรียนนี้ใช้งาน (รายการที่ไม่ติ๊กจะถูกซ่อนทั้งจากหน้าเว็บโรงเรียนและหน้าตั้งค่าของแอดมินโรงเรียน)
                  </p>
                </div>
              </div>

              <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                {SCHOOL_MODULE_META.map((mod) => {
                  const allowed = config.allowedModules[mod.key] !== false;
                  const isBusy = busyKey === `mod:${mod.key}`;
                  return (
                    <div
                      key={mod.key}
                      className={`flex items-start justify-between gap-3 rounded-xl border p-3.5 transition-colors ${
                        allowed
                          ? 'border-brand-200 bg-white'
                          : 'border-line bg-slate-50/70 opacity-75'
                      }`}
                    >
                      <div className="min-w-0">
                        <div className="flex flex-wrap items-center gap-1.5">
                          <p className="text-xs font-semibold text-ink">
                            {mod.title}
                          </p>
                        </div>
                        <p className="mt-0.5 line-clamp-2 text-[11px] text-slate-500">
                          {mod.description}
                        </p>
                        <span
                          className={`mt-1.5 inline-block rounded px-1.5 py-0.5 text-[10px] font-semibold ${
                            allowed
                              ? 'bg-brand-50 text-brand-700'
                              : 'bg-slate-200 text-slate-600'
                          }`}
                        >
                          {allowed ? 'อนุญาตให้ใช้งาน' : 'ซ่อนไม่ให้เห็น'}
                        </span>
                      </div>

                      <button
                        type="button"
                        disabled={!canManage || isBusy}
                        onClick={() => handleToggleModule(mod.key, !allowed)}
                        className={`inline-flex h-6 w-6 shrink-0 items-center justify-center rounded-md border transition-colors ${
                          allowed
                            ? 'border-brand-600 bg-brand-600 text-white'
                            : 'border-slate-300 bg-white text-transparent hover:border-slate-400'
                        } disabled:opacity-50`}
                        aria-label={`เปิดหรือปิดระบบงาน ${mod.title}`}
                      >
                        <Check className="h-3.5 w-3.5" strokeWidth={2.2} />
                      </button>
                    </div>
                  );
                })}
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
