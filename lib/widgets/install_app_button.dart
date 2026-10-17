import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/web_platform.dart' as platform;

/// ปุ่มติดตั้งแอป — มือถือ: "เพิ่มไปยังหน้าจอโฮม", คอม: "ติดตั้งแอปลงเครื่อง"
///
/// กดแล้วติดตั้งเลย (หน้าต่างยืนยันของเบราว์เซอร์ กด "ติดตั้ง" ครั้งเดียว) บน
/// Chrome / Edge / Samsung Internet ทั้ง Android และ PC — ต้องมี web/sw.js +
/// manifest ที่ถูกต้อง เบราว์เซอร์ถึงจะยอม
///
/// iPhone / iPad: Apple ไม่เปิดให้เว็บสั่งเพิ่มลงหน้าจอโฮมเอง (ไม่มีทางทำได้)
/// จึงชี้ปุ่มแชร์ของ Safari ให้กด 2 ครั้งแทน · เปิดผ่าน LINE: ต้องเปิดในเบราว์เซอร์
/// ก่อน · เปิดจากแอปที่ติดตั้งแล้ว: ไม่แสดงปุ่ม
///
/// ฝั่ง JS อยู่ใน web/index.html (koragochInstallInfo / koragochPromptInstall)
class InstallAppButton extends StatefulWidget {
  /// true = แถวแบบหน้าตั้งค่า (หน้าบัญชี), false = ปุ่มขอบ (หน้าล็อกอิน)
  final bool tile;

  const InstallAppButton({super.key, this.tile = false});

  @override
  State<InstallAppButton> createState() => _InstallAppButtonState();
}

class _InstallAppButtonState extends State<InstallAppButton> {
  bool _busy = false;
  bool _done = false;

  Map<String, dynamic> get _info => platform.installInfo();

  bool get _isMobile => _info['ios'] == true || _info['android'] == true;

  String get _label =>
      _isMobile ? 'เพิ่มไปยังหน้าจอโฮม' : 'ติดตั้งแอปลงเครื่อง';

  Future<void> _install() async {
    final info = _info;
    if (info['inAppBrowser'] == true) {
      _openInBrowserSheet(info['ios'] == true);
      return;
    }
    if (info['ios'] == true) {
      _iosSheet(info['safari'] == true);
      return;
    }

    setState(() => _busy = true);
    final outcome = await platform.promptInstall();
    if (!mounted) return;
    setState(() => _busy = false);

    switch (outcome) {
      case 'accepted':
        setState(() => _done = true);
        _snack('ติดตั้งแล้ว — เปิดจากไอคอน "ระบบวันลา" ได้เลย');
      case 'dismissed':
        break;
      default:
        if (_info['installed'] == true) {
          setState(() => _done = true);
          _snack('ติดตั้งไว้ในเครื่องนี้แล้ว — เปิดจากไอคอน "ระบบวันลา" ได้เลย');
          return;
        }
        // Chrome ไม่ส่งสิทธิ์เปิดหน้าต่างติดตั้งมา: ติดตั้งไว้แล้ว (เช็กไม่ได้ทุกเครื่อง)
        // เคยกดปิดหน้าต่างติดตั้ง หรือเป็นเบราว์เซอร์ที่ไม่รองรับ (Firefox, Safari)
        _manualInstallSheet();
    }
  }

  /// สำรองเมื่อเบราว์เซอร์ไม่ยอมให้ปุ่มเปิดหน้าต่างติดตั้งเอง
  void _manualInstallSheet() {
    final mobile = _isMobile;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ติดตั้งจากปุ่มนี้ไม่ได้ตอนนี้',
                  style: GoogleFonts.sarabun(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                  'มักเกิดเมื่อเครื่องนี้ติดตั้งไว้แล้ว หรือเคยกดปิดหน้าต่างติดตั้งไป',
                  style: GoogleFonts.sarabun(
                      fontSize: 13, color: Colors.blueGrey)),
              const SizedBox(height: 16),
              _iosStep(Icons.apps_rounded, 'ถ้าติดตั้งไว้แล้ว',
                  mobile
                      ? 'หาไอคอน "ระบบวันลา" ที่หน้าจอโฮม'
                      : 'หาไอคอน "ระบบวันลา" ที่เดสก์ท็อปหรือเมนู Start'),
              const SizedBox(height: 12),
              _iosStep(
                  mobile ? Icons.more_vert : Icons.install_desktop_rounded,
                  'ถ้ายังไม่ได้ติดตั้ง',
                  mobile
                      ? 'แตะ ⋮ มุมขวาบนของ Chrome > "เพิ่มลงในหน้าจอหลัก"'
                      : 'คลิกไอคอนติดตั้งท้ายช่องที่อยู่เว็บ หรือ ⋮ > '
                          '"ส่ง บันทึก และแชร์" > "ติดตั้งหน้าเว็บเป็นแอป"'),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));

  void _copyLink() {
    final link = Uri.base.replace(fragment: '').toString();
    Clipboard.setData(ClipboardData(
        text: link.endsWith('#') ? link.substring(0, link.length - 1) : link));
    _snack('คัดลอกลิงก์แล้ว');
  }

  /// iPhone: ชี้ปุ่มแชร์ของ Safari (แถบล่างกลางจอ) — กด 2 ครั้งก็เสร็จ
  void _iosSheet(bool safari) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('เพิ่มไปยังหน้าจอโฮม',
                  style: GoogleFonts.sarabun(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (!safari) ...[
                Text('iPhone ต้องเปิดใน Safari ก่อน',
                    style: GoogleFonts.sarabun(fontSize: 15)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _copyLink,
                  icon: const Icon(Icons.link),
                  label: const Text('คัดลอกลิงก์ไปเปิดใน Safari'),
                ),
              ] else ...[
                _iosStep(Icons.ios_share, 'แตะปุ่มแชร์', 'ที่แถบล่างของ Safari'),
                const SizedBox(height: 12),
                _iosStep(Icons.add_box_outlined, 'แตะ "เพิ่มไปยังหน้าจอโฮม"',
                    'แล้วกด "เพิ่ม"'),
                const SizedBox(height: 16),
                const Icon(Icons.keyboard_double_arrow_down_rounded,
                    size: 40, color: Color(0xFF2563EB)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _iosStep(IconData icon, String title, String detail) => Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: const Color(0xFF2563EB)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.sarabun(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                Text(detail,
                    style: GoogleFonts.sarabun(
                        fontSize: 13, color: Colors.blueGrey)),
              ],
            ),
          ),
        ],
      );

  /// เปิดผ่าน LINE / Facebook: ติดตั้งจากในแอปพวกนี้ไม่ได้
  void _openInBrowserSheet(bool ios) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('เปิดใน${ios ? ' Safari' : ' Chrome'} ก่อน',
                  style: GoogleFonts.sarabun(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                  'เปิดผ่าน LINE อยู่ ซึ่งเพิ่มลงหน้าจอโฮมไม่ได้ — '
                  'แตะ ⋮ หรือ … มุมขวาแล้วเลือก "เปิดในเบราว์เซอร์" '
                  'หรือคัดลอกลิงก์ไปวาง',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sarabun(fontSize: 14)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _copyLink,
                icon: const Icon(Icons.link),
                label: const Text('คัดลอกลิงก์'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (_done || info['standalone'] == true || info['installed'] == true) {
      return const SizedBox.shrink();
    }
    final icon = _isMobile
        ? Icons.add_to_home_screen_rounded
        : Icons.install_desktop_rounded;
    const busyIcon = SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2));

    if (widget.tile) {
      return Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0))),
        child: ListTile(
          leading: _busy ? busyIcon : Icon(icon, color: const Color(0xFF2563EB)),
          title: Text(_label,
              style: GoogleFonts.sarabun(fontWeight: FontWeight.w600)),
          subtitle: Text('มีไอคอน "ระบบวันลา" เปิดได้เลยไม่ต้องพิมพ์ลิงก์',
              style: GoogleFonts.sarabun(fontSize: 12)),
          onTap: _busy ? null : _install,
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: _busy ? null : _install,
      icon: _busy ? busyIcon : Icon(icon, size: 18),
      label: Text(_label,
          style: GoogleFonts.sarabun(fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
