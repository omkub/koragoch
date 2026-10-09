/// หน้าจอมือถือแบบใหม่ (ทดลอง) — เปิดได้ที่หน้าบัญชี (MobileUiPreference)
///
/// พาร์ท 0: ยังเป็นหน้าจอเดิมทุกอย่าง (เตรียมสวิตช์ไว้ก่อน)
library;

import 'package:flutter/material.dart';

import '../mobile/mobile_main_layout.dart';

class MobileShell extends StatelessWidget {
  const MobileShell({super.key});

  @override
  Widget build(BuildContext context) => const MobileMainLayout();
}
