/** รหัสไฟล์จากลิงก์ Google Drive (…/d/<id>/… หรือ ?id=<id>) */
export function driveFileId(url: string | null | undefined): string | null {
  if (!url || !/drive\.google\.com|docs\.google\.com/.test(url)) return null;
  return url.match(/\/d\/([a-zA-Z0-9_-]{10,})/)?.[1] ?? url.match(/[?&]id=([a-zA-Z0-9_-]{10,})/)?.[1] ?? null;
}

/**
 * ลิงก์ที่ใส่ <img> ได้ — ไฟล์ Drive แสดงผ่าน wsrv.nl แบบเดียวกับแอป
 * (lib/utils/profile_image.dart) รูปที่เพิ่งเลือก (data URL) ใช้ตรง ๆ
 */
export function logoSrc(logo: string | null | undefined): string | null {
  if (!logo) return null;
  const id = driveFileId(logo);
  return id ? `https://wsrv.nl/?url=drive.google.com/uc%3Fid%3D${id}` : logo;
}

/** โลโก้โรงเรียนเล็ก ๆ — ไม่มีโลโก้ = ตัวอักษรแรกของชื่อ */
export default function SchoolLogo({
  logo,
  name,
  size = 32,
}: {
  logo?: string | null;
  name: string;
  size?: number;
}) {
  const src = logoSrc(logo);
  const style = { width: size, height: size };
  if (src) {
    return <img src={src} alt="" style={style} className="shrink-0 rounded-lg bg-white object-contain" />;
  }
  const initial = name.replace(/^โรงเรียน/, '').trim().charAt(0) || '?';
  return (
    <span
      style={style}
      className="grid shrink-0 place-items-center rounded-lg bg-brand-50 text-xs font-bold text-brand-600"
    >
      {initial}
    </span>
  );
}
