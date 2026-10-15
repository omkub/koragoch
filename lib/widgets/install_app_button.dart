import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/web_platform.dart' as platform;

/// ปุ่ม "ติดตั้งแอปลงเครื่อง" สำหรับคนที่สร้างทางลัดเองไม่เป็น (มือถือ + PC)
///
/// - Chrome / Edge (Android, Windows, Mac): เปิดหน้าต่างติดตั้งของเบราว์เซอร์เลย
/// - iPhone / iPad (Safari ไม่มีหน้าต่างนี้), เปิดผ่าน LINE, หรือเบราว์เซอร์ที่
///   ยังไม่พร้อม: แสดงวิธีทำทีละขั้นตามเครื่อง
/// - เปิดจากแอปที่ติดตั้งแล้ว: ไม่แสดงปุ่ม
///
/// ฝั่ง JS อยู่ใน web/index.html (koragochInstallInfo / koragochPromptInstall)
class InstallAppButton extends StatelessWidget {
  /// true = แถวแบบหน้าตั้งค่า (หน้าบัญชี), false = ปุ่มขอบ (หน้าล็อกอิน)
  final bool tile;

  const InstallAppButton({super.key, this.tile = false});

  static bool get _alreadyInstalled {
    final info = platform.installInfo();
    return info['standalone'] == true || info['installed'] == true;
  }

  Future<void> _install(BuildContext context) async {
    final info = platform.installInfo();
    if (info['canPrompt'] == true) {
      final outcome = await platform.promptInstall();
      if (!context.mounted) return;
      if (outcome == 'accepted') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'ติดตั้งแล้ว — เปิดจากไอคอน "ระบบวันลา" บนหน้าจอได้เลย')));
        return;
      }
      if (outcome == 'dismissed') return;
    }
    if (!context.mounted) return;
    _showSteps(context, info);
  }

  void _showSteps(BuildContext context, Map<String, dynamic> info) {
    final ios = info['ios'] == true;
    final android = info['android'] == true;
    final inApp = info['inAppBrowser'] == true;
    final safari = info['safari'] == true;

    final String title;
    final List<String> steps;
    if (inApp) {
      title = 'เปิดในเบราว์เซอร์ก่อน';
      steps = [
        'ตอนนี้เปิดผ่านแอป LINE / Facebook ซึ่งติดตั้งไม่ได้',
        'กดปุ่ม "คัดลอกลิงก์" ด้านล่าง',
        ios
            ? 'เปิด Safari แล้ววางลิงก์ในช่องที่อยู่'
            : 'เปิด Chrome แล้ววางลิงก์ในช่องที่อยู่',
        'กดปุ่ม "ติดตั้งแอปลงเครื่อง" อีกครั้ง',
      ];
    } else if (ios && !safari) {
      title = 'iPhone / iPad ต้องใช้ Safari';
      steps = [
        'กดปุ่ม "คัดลอกลิงก์" ด้านล่าง',
        'เปิดแอป Safari แล้ววางลิงก์ในช่องที่อยู่',
        'กดปุ่มแชร์ (สี่เหลี่ยมมีลูกศรชี้ขึ้น)',
        'เลือก "เพิ่มไปยังหน้าจอโฮม" แล้วกด "เพิ่ม"',
      ];
    } else if (ios) {
      title = 'ติดตั้งบน iPhone / iPad';
      steps = [
        'กดปุ่มแชร์ (สี่เหลี่ยมมีลูกศรชี้ขึ้น) แถบล่างของ Safari',
        'เลื่อนลงแล้วเลือก "เพิ่มไปยังหน้าจอโฮม"',
        'กด "เพิ่ม" มุมขวาบน',
        'ไอคอน "ระบบวันลา" จะอยู่บนหน้าจอโฮม เปิดจากไอคอนได้เลย',
      ];
    } else if (android) {
      title = 'ติดตั้งบนมือถือ Android';
      steps = [
        'เปิดหน้านี้ใน Chrome',
        'กดเมนู ⋮ มุมขวาบน',
        'เลือก "ติดตั้งแอป" หรือ "เพิ่มลงในหน้าจอหลัก"',
        'กด "ติดตั้ง" — ไอคอน "ระบบวันลา" จะอยู่บนหน้าจอ',
      ];
    } else {
      title = 'ติดตั้งบนคอมพิวเตอร์';
      steps = [
        'เปิดหน้านี้ใน Google Chrome หรือ Microsoft Edge',
        'Chrome: กดไอคอนติดตั้ง (จอคอมมีลูกศร) ท้ายช่องที่อยู่ หรือเมนู ⋮ > '
            '"แคสต์ บันทึก และแชร์" > "ติดตั้งหน้าเว็บเป็นแอป"',
        'Edge: เมนู … > "แอป" > "ติดตั้งไซต์นี้เป็นแอป"',
        'กด "ติดตั้ง" — จะมีไอคอน "ระบบวันลา" บนเดสก์ท็อป / เมนู Start',
      ];
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title,
            style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: const Color(0xFF2563EB),
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(steps[i],
                              style: GoogleFonts.sarabun(fontSize: 15))),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.link, size: 18),
            label: const Text('คัดลอกลิงก์'),
            onPressed: () {
              final link = Uri.base.replace(fragment: '').toString();
              Clipboard.setData(ClipboardData(
                  text: link.endsWith('#')
                      ? link.substring(0, link.length - 1)
                      : link));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('คัดลอกลิงก์แล้ว')));
            },
          ),
          FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('เข้าใจแล้ว')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_alreadyInstalled) return const SizedBox.shrink();

    if (tile) {
      return Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0))),
        child: ListTile(
          leading: const Icon(Icons.install_mobile_rounded,
              color: Color(0xFF2563EB)),
          title: Text('ติดตั้งแอปลงเครื่อง',
              style: GoogleFonts.sarabun(fontWeight: FontWeight.w600)),
          subtitle: Text('มีไอคอนบนหน้าจอ เปิดได้เลยไม่ต้องพิมพ์ลิงก์',
              style: GoogleFonts.sarabun(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _install(context),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => _install(context),
      icon: const Icon(Icons.install_mobile_rounded, size: 18),
      label: Text('ติดตั้งแอปลงเครื่อง',
          style: GoogleFonts.sarabun(fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
