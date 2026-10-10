import 'package:flutter/material.dart';
import 'main_layout.dart';
import 'mobile_v2/mobile_shell.dart';

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 🕵️‍♂️ ถ้าหน้าจอแคบกว่า 1100px ใช้หน้าจอแบบแอปมือถือ (mobile_v2) 🥇🏆
        if (constraints.maxWidth < 1100) return const MobileShell();
        // 🖥️ ถ้าหน้าจอกว้าง ให้ใช้ดีไซน์แบบ PC Desktop มาตรฐานครับ
        return const MainLayout();
      },
    );
  }
}
