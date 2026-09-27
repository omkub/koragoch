import { schoolAddress, schoolName, type School } from '../supabase';

type PreviewSchool = Pick<
  School,
  'namePart1' | 'namePart2' | 'fullName' | 'address' | 'affiliation' | 'subdistrict' | 'district' | 'province'
>;

/**
 * ตัวอย่างหัวใบลา — จัดวางตาม lib/widgets/leave_form_document.dart ในแอป Flutter
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

  return (
    <div className="preview">
      <div className="preview-label">ตัวอย่างหัวใบลา</div>
      <div className="paper">
        <div className="paper-top">
          <div className="paper-title">
            <u><b>แบบใบลา</b></u>
            <div>ลาป่วย/ลากิจ/ลาคลอดบุตร</div>
          </div>
          <div className="paper-receive">
            รับที่ .................<br />
            วันที่ .................<br />
            เวลา .................
          </div>
        </div>

        <div className="paper-school">
          <b>{hasName ? fullName : '(ชื่อโรงเรียน)'}</b>
          <div className={address ? '' : 'missing'}>{address || '(ที่อยู่)'}</div>
          <div className="paper-date">วันที่ ...... เดือน .............. พ.ศ. ........</div>
        </div>

        <div><b>เรื่อง</b> ...........................................</div>
        <div>เรียน ผู้อำนวยการ{hasName ? fullName : '(ชื่อโรงเรียน)'}</div>
        <div className="paper-indent">
          ข้าพเจ้า ....................... ตำแหน่ง ............. {hasName ? part1 : '(ชื่อโรงเรียน)'}
        </div>
        <div>
          {part2 && `${part2} `}
          <span className={affiliation ? '' : 'missing'}>{affiliation || '(สังกัด)'}</span>
        </div>

        <div className="paper-sign">
          ลงชื่อ .................................
          <br />( ................................. )
          <br />
          ผู้อำนวยการ{hasName ? fullName : '(ชื่อโรงเรียน)'}
        </div>
      </div>

      {warnings.length > 0 && (
        <ul className="preview-warn">
          {warnings.map((w) => (
            <li key={w}>{w}</li>
          ))}
        </ul>
      )}
    </div>
  );
}
