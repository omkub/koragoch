/// สวิตช์ "หน้าตาใหม่บนมือถือ" — เลือกได้ต่อเครื่อง ระหว่างที่ทยอยปรับหน้าจอมือถือ
///
/// ปิด (ค่าเริ่มต้น) = หน้าจอมือถือแบบเดิม (MobileMainLayout)
/// เปิด = หน้าจอมือถือแบบใหม่ (MobileShell) — ยังอยู่ระหว่างพัฒนา
///
/// เก็บใน SharedPreferences ของเครื่อง จึงเปิดลองเฉพาะเครื่องตัวเองได้
/// คนอื่นยังเห็นแบบเดิม เมื่อเปิดใช้จริงทุกคน (พาร์ท 8) ไฟล์นี้จะถูกลบ
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MobileUiPreference {
  MobileUiPreference._();

  static const _key = 'mobile_ui_v2';

  /// true = ใช้หน้าตาใหม่ — หน้าจอที่ฟังค่านี้จะสลับให้ทันทีเมื่อเปลี่ยน
  static final ValueNotifier<bool> useNewUi = ValueNotifier(false);

  static bool _loaded = false;

  /// อ่านค่าที่เคยเลือกไว้ (เรียกครั้งเดียวตอนเปิดแอป เรียกซ้ำได้ไม่เป็นไร)
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      useNewUi.value = prefs.getBool(_key) ?? false;
    } catch (e) {
      debugPrint('⚠️  อ่านค่าหน้าตามือถือไม่สำเร็จ ใช้แบบเดิม: $e');
    }
  }

  static Future<void> set(bool value) async {
    useNewUi.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (e) {
      debugPrint('⚠️  บันทึกค่าหน้าตามือถือไม่สำเร็จ: $e');
    }
  }
}
