/// ชุดสี ตัวอักษร และตรายางสถานะของ app — ใช้ร่วมกันทุกหน้าจอ
///
/// ทิศทาง: กระดาษราชการ หมึกน้ำเงินกรมท่า ตรายาง
/// - พื้นและตัวอักษรเป็นเทาเกือบกลาง (graphite) — สีอยู่ที่เนื้อหา ไม่ใช่ที่กรอบ
/// - สีหลัก (accent) มีสีเดียว คือน้ำเงินกรมท่า ใช้กับปุ่มหลัก / รายการที่เลือก /
///   ตัวเลขที่สำคัญที่สุดของหน้า เท่านั้น
/// - สีความหมาย (เขียว / อำพัน / แดง) ใช้บอกสถานะเท่านั้น
/// - ตัวอักษร Sarabun น้ำหนัก 400 / 500 และ 600 สำหรับเน้นเล็กน้อย
/// - ระยะห่างเป็นเลขคูณ 4
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // ── พื้นผิว (graphite light) ──
  static const page = Color(0xFFF7F7F8);
  static const card = Color(0xFFFFFFFF);
  static const raised = Color(0xFFF1F1F3);

  /// เส้นบาง = ตัวอักษรหลักที่ 8%
  static const line = Color(0x14171717);

  // ── ตัวอักษร 3 ระดับ ──
  static const text = Color(0xFF171717);
  static const textSecondary = Color(0xFF525252);
  static const textMuted = Color(0xFF737373);

  // ── สีหลัก: น้ำเงินกรมท่า (ตัวอักษรขาวบนพื้นนี้ ~10:1) ──
  static const accent = Color(0xFF1E3A8A);
  static const accentSoft = Color(0xFFE8ECF6);

  // ── สีความหมาย ──
  static const positive = Color(0xFF15803D);
  static const pending = Color(0xFFB45309);
  static const negative = Color(0xFFDC2626);

  /// พื้นอ่อนของกล่องแจ้งเตือนตามความหมาย (ใช้กับข้อความแจ้งเท่านั้น)
  static const positiveSoft = Color(0xFFEEF6F0);
  static const pendingSoft = Color(0xFFFBF4E8);
  static const negativeSoft = Color(0xFFFCEFEF);
}

/// ขนาดตัวอักษร: 11 / 12 / 13 / 14 / 16 / 18 / 22 / 28
class AppText {
  AppText._();

  static TextStyle style(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.text,
    double? height,
  }) =>
      GoogleFonts.sarabun(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  /// ตัวเลข — ใช้ความกว้างหลักเท่ากัน ให้ตัวเลขเรียงตรงกัน
  static TextStyle figure(double size,
          {Color color = AppColors.text,
          FontWeight weight = FontWeight.w500}) =>
      style(size, weight: weight, color: color)
          .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  static TextStyle get title =>
      style(18, weight: FontWeight.w600, color: AppColors.text);
  static TextStyle get section =>
      style(14, weight: FontWeight.w600, color: AppColors.text);
  static TextStyle get body => style(14, color: AppColors.text);
  static TextStyle get label =>
      style(13, weight: FontWeight.w500, color: AppColors.text);
  static TextStyle get secondary =>
      style(13, color: AppColors.textSecondary);
  static TextStyle get meta => style(12, color: AppColors.textMuted);
}

class AppRadius {
  AppRadius._();

  static const control = 8.0;
  static const card = 12.0;
  static const panel = 16.0;
}

/// กรอบการ์ดมาตรฐาน: พื้นขาว + เส้นบาง ไม่มีเงา
BoxDecoration appCardDecoration({double radius = AppRadius.card}) =>
    BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.line),
    );

/// สถานะ 3 กลุ่มของใบลา / ไปราชการ
enum StampTone { approved, pending, returned }

extension StampToneColor on StampTone {
  Color get ink => switch (this) {
        StampTone.approved => AppColors.positive,
        StampTone.pending => AppColors.pending,
        StampTone.returned => AppColors.negative,
      };
}

/// ลายเซ็นของระบบ: สถานะแสดงเป็น "ตรายางหมึก" — กรอบบางสีหมึก ไม่มีพื้น
/// ใช้กับสถานะใบลา / ไปราชการเท่านั้น ห้ามใช้เป็นป้ายตกแต่งทั่วไป
class StatusStamp extends StatelessWidget {
  final String text;
  final StampTone tone;

  /// ขนาดใหญ่ ใช้ในหน้ารายละเอียด (เอียงเล็กน้อยเหมือนประทับจริง)
  final bool large;

  const StatusStamp(this.text, {super.key, required this.tone, this.large = false});

  @override
  Widget build(BuildContext context) {
    final ink = tone.ink;
    final stamp = Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 12 : 8, vertical: large ? 4 : 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(large ? 6 : 4),
        border: Border.all(color: ink.withValues(alpha: 0.85), width: large ? 1.5 : 1.25),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: AppText.style(large ? 14 : 12,
            weight: FontWeight.w600, color: ink),
      ),
    );
    return large ? Transform.rotate(angle: -0.035, child: stamp) : stamp;
  }
}
