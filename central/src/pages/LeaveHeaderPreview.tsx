import { schoolAddress, schoolName, type School } from '../supabase';

type PreviewSchool = Pick<
  School,
  'namePart1' | 'namePart2' | 'fullName' | 'address' | 'affiliation' | 'subdistrict' | 'district' | 'province'
>;

/**
 * ตัวอย่างหัวใบลา — จัดวางตามแม่แบบเริ่มต้นของใบลา (forms/leaveTemplate.ts)
 * (ส่วนหัว, เรียน, ย่อหน้าแรก, ช่องเซ็นผู้อำนวยการ) ใช้กฎประกอบชื่อ/ที่อยู่ชุดเดียวกัน
 */
export default function LeaveHeaderPreview({ school }: { school: PreviewSchool }) {
  const fullName = schoolName({ ...school, fullName: null });
  const hasName = fullName !== '-';
  const address = schoolAddress(school);
  const affiliation = school.affiliation?.trim() ?? '';
  const part1 = school.namePart1?.trim() || fullName;
  const part2 = school.namePart2?.trim() ?? '';

  const warnings = [
    !hasName && 'ยังไม่มีชื่อโรงเรียน',
    !address && 'ยังไม่มีที่อยู่ — กรอกช่องที่อยู่ หรือ อำเภอ/จังหวัด',
    !school.address?.trim() && address && 'ที่อยู่ประกอบจากอำเภอ/จังหวัด (ไม่มีรหัสไปรษณีย์)',
    !affiliation && 'ยังไม่มีสังกัด — ย่อหน้าแรกของใบลาจะไม่มีสังกัด',
  ].filter(Boolean) as string[];

  const missing = 'italic text-red-600';
  return (
    <div className="min-w-0">
      <div className="mb-2 text-[13px] font-medium text-slate-500">ตัวอย่างหัวใบลา</div>
      <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white px-5 py-6 font-doc text-[13px] leading-[1.9] text-neutral-900 shadow-sm sm:px-7">
        <div className="flex justify-between gap-3">
          <div className="flex-1 text-center">
            <u><b>แบบใบลา</b></u>
            <div>ลาป่วย/ลากิจ/ลาคลอดบุตร</div>
          </div>
          <div className="border border-neutral-700 px-2.5 py-1 text-[11px] leading-[1.8] text-neutral-600">
            รับที่ .................<br />
            วันที่ .................<br />
            เวลา .................
          </div>
        </div>

        <div className="my-3 ml-auto w-fit max-w-[70%] text-center">
          <b>{hasName ? fullName : '(ชื่อโรงเรียน)'}</b>
          <div className={address ? '' : missing}>{address || '(ที่อยู่)'}</div>
          <div className="mt-2">วันที่ ...... เดือน .............. พ.ศ. ........</div>
        </div>

        <div><b>เรื่อง</b> ...........................................</div>
        <div>เรียน ผู้อำนวยการ{hasName ? fullName : '(ชื่อโรงเรียน)'}</div>
        <div className="mt-2 pl-12">
          ข้าพเจ้า ....................... ตำแหน่ง ............. {hasName ? part1 : '(ชื่อโรงเรียน)'}
        </div>
        <div>
          {part2 && `${part2} `}
          <span className={affiliation ? '' : missing}>{affiliation || '(สังกัด)'}</span>
        </div>

        <div className="mt-4 text-center">
          ลงชื่อ .................................
          <br />( ................................. )
          <br />
          ผู้อำนวยการ{hasName ? fullName : '(ชื่อโรงเรียน)'}
        </div>
      </div>

      {warnings.length > 0 && (
        <ul className="mt-2.5 list-disc space-y-0.5 pl-5 text-[13px] text-amber-700">
          {warnings.map((w) => (
            <li key={w}>{w}</li>
          ))}
        </ul>
      )}
    </div>
  );
}
