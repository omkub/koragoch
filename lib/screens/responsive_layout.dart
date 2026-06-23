import 'package:flutter/material.dart';
import 'main_layout.dart';
import 'mobile/mobile_main_layout.dart';

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 🕵️‍♂️ ถ้าหน้าจอแคบกว่า 1100px ให้สลับไปใช้ดีไซน์สำหรับมือถือโดยเฉพาะครับ 🥇🏆
        if (constraints.maxWidth < 1100) {
          return const MobileMainLayout();
        }
        // 🖥️ ถ้าหน้าจอกว้าง ให้ใช้ดีไซน์แบบ PC Desktop มาตรฐานครับ
        return const MainLayout();
      },
    );
  }
}
