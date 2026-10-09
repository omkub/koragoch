import 'package:flutter/material.dart';
import '../utils/mobile_ui_preference.dart';
import 'main_layout.dart';
import 'mobile/mobile_main_layout.dart';
import 'mobile_v2/mobile_shell.dart';

class ResponsiveLayout extends StatefulWidget {
  const ResponsiveLayout({super.key});

  @override
  State<ResponsiveLayout> createState() => _ResponsiveLayoutState();
}

class _ResponsiveLayoutState extends State<ResponsiveLayout> {
  @override
  void initState() {
    super.initState();
    MobileUiPreference.load();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 🕵️‍♂️ ถ้าหน้าจอแคบกว่า 1100px ให้สลับไปใช้ดีไซน์สำหรับมือถือโดยเฉพาะครับ 🥇🏆
        // หน้าตาใหม่ (ทดลอง) เปิดได้ต่อเครื่องที่หน้าบัญชี — ดู MobileUiPreference
        if (constraints.maxWidth < 1100) {
          return ValueListenableBuilder<bool>(
            valueListenable: MobileUiPreference.useNewUi,
            builder: (context, useNew, _) =>
                useNew ? const MobileShell() : const MobileMainLayout(),
          );
        }
        // 🖥️ ถ้าหน้าจอกว้าง ให้ใช้ดีไซน์แบบ PC Desktop มาตรฐานครับ
        return const MainLayout();
      },
    );
  }
}
