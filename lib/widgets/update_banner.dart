import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/update_checker.dart';
import '../utils/web_platform.dart' as platform;

/// แถบ "มีเวอร์ชันใหม่ — แตะเพื่ออัปเดต" ลอยบนสุดของทุกหน้า (ไม่บังคับ)
///
/// ไม่รีโหลดเอง — ผู้ใช้อาจกรอกใบลาค้างอยู่ ปิดแถบได้ (เปิดแอปครั้งถัดไปก็ได้
/// เวอร์ชันใหม่อยู่แล้ว) ครอบไว้ที่ MaterialApp.builder ใน main.dart
class UpdateBanner extends StatefulWidget {
  final Widget child;
  const UpdateBanner({super.key, required this.child});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  bool _dismissed = false;
  bool _reloading = false;

  @override
  void initState() {
    super.initState();
    UpdateChecker.instance.start();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ValueListenableBuilder<bool>(
          valueListenable: UpdateChecker.instance.available,
          builder: (context, available, _) {
            if (!available || _dismissed) return const SizedBox.shrink();
            return Positioned(
              left: 12,
              right: 12,
              top: 0,
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Material(
                      color: const Color(0xFF1E293B),
                      elevation: 6,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _reloading
                            ? null
                            : () {
                                setState(() => _reloading = true);
                                platform.reloadApp();
                              },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
                          child: Row(
                            children: [
                              const Icon(Icons.system_update_rounded,
                                  color: Color(0xFFFB923C)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _reloading
                                      ? 'กำลังอัปเดต...'
                                      : 'มีเวอร์ชันใหม่ — แตะเพื่ออัปเดต',
                                  style: GoogleFonts.sarabun(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              IconButton(
                                tooltip: 'ไว้ทีหลัง',
                                icon: const Icon(Icons.close,
                                    color: Colors.white70, size: 20),
                                onPressed: () =>
                                    setState(() => _dismissed = true),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
