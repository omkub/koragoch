/// สวิตช์ "หน้าตาใหม่บนมือถือ" — เลือกได้ต่อเครื่อง
///
/// เปิด (ค่าเริ่มต้น ตั้งแต่พาร์ท 8) = หน้าจอมือถือแบบใหม่ (MobileShell)
/// ปิด = กลับไปใช้หน้าจอมือถือแบบเดิม (MobileMainLayout)
///
/// เก็บใน SharedPreferences ของเครื่อง — เครื่องที่เคยกดปิดไว้จะยังเป็นแบบเดิม
/// เมื่อใช้หน้าตาใหม่จริงจนมั่นใจแล้ว ค่อยลบหน้าจอเดิม สวิตช์ และไฟล์นี้ทิ้ง
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MobileUiPreference {
  MobileUiPreference._();

  static const _key = 'mobile_ui_v2';

  /// true = ใช้หน้าตาใหม่ — หน้าจอที่ฟังค่านี้จะสลับให้ทันทีเมื่อเปลี่ยน
  static final ValueNotifier<bool> useNewUi = ValueNotifier(true);

  static bool _loaded = false;

  /// อ่านค่าที่เคยเลือกไว้ (เรียกครั้งเดียวตอนเปิดแอป เรียกซ้ำได้ไม่เป็นไร)
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      useNewUi.value = prefs.getBool(_key) ?? true;
    } catch (e) {
      debugPrint('⚠️  อ่านค่าหน้าตามือถือไม่สำเร็จ ใช้หน้าตาใหม่: $e');
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
