/// หน้าหลักบนมือถือ — ทางลัดไปทุกเมนูที่ผู้ใช้มีสิทธิ์
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'menu_access.dart';
import 'mobile_pages.dart';

class MobileHomeScreen extends StatelessWidget {
  final MenuAccess access;

  /// สลับไปแท็บล่าง (0 หน้าหลัก · 1 ส่งใบลา · 2 ประวัติ · 3 บัญชี)
  final ValueChanged<int> onGoTab;

  const MobileHomeScreen(
      {super.key, required this.access, required this.onGoTab});

  @override
  Widget build(BuildContext context) {
    final shortcuts = [
      for (final s in mobileShortcuts)
        if (access.can(s.menu)) s
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (shortcuts.isNotEmpty) ...[
          _sectionTitle('เมนู'),
          const SizedBox(height: 8),
          MobileShortcutGrid(shortcuts: shortcuts),
        ],
      ],
    );
  }
}

Widget _sectionTitle(String text) => Text(text,
    style: GoogleFonts.sarabun(
        fontSize: 14, fontWeight: FontWeight.w700, color: mobileMuted));

/// ตารางปุ่มทางลัด 3 คอลัมน์
class MobileShortcutGrid extends StatelessWidget {
  final List<MobileShortcut> shortcuts;

  const MobileShortcutGrid({super.key, required this.shortcuts});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: [
        for (final s in shortcuts)
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => openMobileMenu(context, s),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(s.icon, color: mobileAccent, size: 24),
                    ),
                    const SizedBox(height: 8),
                    Text(s.label,
                        style: GoogleFonts.sarabun(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: mobileInk)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
