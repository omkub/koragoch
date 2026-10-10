/// รายละเอียดใบลา (มือถือ) — เปิดจากการ์ดในหน้าประวัติ
///
/// ทุกคน: ดูรายละเอียด / ดูใบลา + พิมพ์ (แม่แบบจาก web) / แก้ไข (ตามสิทธิ์)
/// ผู้ดูแลระบบ: อนุมัติ / ไม่อนุมัติ (ส่งกลับ) / ลบ — ผู้บริหารไม่มีสิทธิ์อนุมัติ
/// ปิดหน้านี้คืน true เมื่อข้อมูลเปลี่ยน ให้หน้าประวัติโหลดใหม่
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/firebase_service.dart';
import '../../widgets/leave_form_page.dart';
import 'leave_actions.dart';
import 'menu_access.dart';
import 'mobile_pages.dart';

class MobileLeaveDetail extends StatefulWidget {
  final Map<String, dynamic> leave;
  final MenuAccess access;
  final List<Map<String, dynamic>> allUsers;
  final List<Map<String, dynamic>> allLeaves;
  final ValueChanged<Map<String, dynamic>> onEdit;

  const MobileLeaveDetail({
    super.key,
    required this.leave,
    required this.access,
    required this.allUsers,
    required this.allLeaves,
    required this.onEdit,
  });

  @override
  State<MobileLeaveDetail> createState() => _MobileLeaveDetailState();
}

class _MobileLeaveDetailState extends State<MobileLeaveDetail> {
  late Map<String, dynamic> _leave = widget.leave;
  bool _busy = false;
  bool _changed = false;

  String get _id => (_leave['requestId'] ?? '').toString();
  bool get _isAdmin => widget.access.isAdmin;

  void _close() => Navigator.of(context).pop(_changed);

  Future<void> _run(Future<String> Function() action) async {
    setState(() => _busy = true);
    try {
      final message = await action();
      if (!mounted) return;
      _changed = true;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('ทำรายการไม่สำเร็จ: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message, String action,
      {Color color = mobileAccent}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style: GoogleFonts.sarabun(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(message,
                  style: GoogleFonts.sarabun(fontSize: 15, color: mobileMuted)),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: color,
                    minimumSize: const Size.fromHeight(48)),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(action,
                    style: GoogleFonts.sarabun(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('ยกเลิก'),
              ),
            ],
          ),
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _approve() async {
    if (!await _confirm('อนุมัติใบลา',
        'อนุมัติใบลาของ ${_leave['fullName']} และออกเลขรับ', 'อนุมัติ',
        color: const Color(0xFF16A34A))) {
      return;
    }
    await _run(() async {
      final number = await LeaveActions.approve(_id);
      setState(() => _leave = {
            ..._leave,
            'status': LeaveStatus.approveTo,
            'receiveNumber': number,
          });
      return 'อนุมัติแล้ว (รับที่ $number)';
    });
  }

  Future<void> _return() async {
    if (!await _confirm(
        'ไม่อนุมัติ',
        'ส่งใบลากลับเป็น "ยังไม่ส่ง" ให้ ${_leave['fullName']} แก้ไขแล้วส่งใหม่',
        'ไม่อนุมัติ',
        color: const Color(0xFFDC2626))) {
      return;
    }
    await _run(() async {
      await LeaveActions.returnToApplicant(_id);
      setState(() => _leave = {..._leave, 'status': LeaveStatus.returnTo});
      return 'ส่งกลับให้แก้ไขแล้ว';
    });
  }

  Future<void> _delete() async {
    if (!await _confirm('ลบใบลา',
        'ลบใบลาของ ${_leave['fullName']} ถาวร กู้คืนไม่ได้', 'ลบ',
        color: const Color(0xFFDC2626))) {
      return;
    }
    setState(() => _busy = true);
    try {
      await LeaveActions.delete(_leave);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('ลบใบลาแล้ว'), backgroundColor: Colors.black));
      _changed = true;
      _close();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('ลบไม่สำเร็จ: $e'), backgroundColor: Colors.red));
    }
  }

  void _openDocument() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LeaveFormPage(
        leaf: _leave,
        allUsers: widget.allUsers,
        allLeaveRequests: widget.allLeaves,
      ),
    ));
  }

  void _edit() {
    Navigator.of(context).pop(_changed);
    widget.onEdit(_leave);
  }

  @override
  Widget build(BuildContext context) {
    final status = LeaveStatus.of(_leave);
    final (bg, fg) = LeaveStatus.colors(status);
    final group = LeaveStatus.group(status);
    final canEdit = LeaveStatus.canEdit(status, isAdmin: _isAdmin);
    final start = FirebaseService.formatThaiDate(_leave['startDate']);
    final end = FirebaseService.formatThaiDate(_leave['endDate']);
    final medical = (_leave['medicalCertificate'] ?? '').toString();
    final halfDay = _leave['isHalfDay'] == true
        ? (_leave['halfDayPeriod'] == 'afternoon' ? 'ครึ่งวันบ่าย' : 'ครึ่งวันเช้า')
        : 'เต็มวัน';

    final rows = <(String, String)>[
      ('ผู้ลา', (_leave['fullName'] ?? '-').toString()),
      ('ประเภท', (_leave['leaveType'] ?? '-').toString()),
      ('วันที่', start == end ? start : '$start ถึง $end'),
      (
        'จำนวน',
        '${FirebaseService.formatLeaveDayCount(_leave['totalDays'])} วัน ($halfDay)'
      ),
      ('เหตุผล', (_leave['reason'] ?? '').toString()),
      ('เบอร์ติดต่อ', (_leave['phone'] ?? '').toString()),
      if ((_leave['receiveNumber'] ?? '').toString().isNotEmpty)
        ('เลขรับ', _leave['receiveNumber'].toString()),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: mobileBg,
        appBar: mobileAppBar('รายละเอียดใบลา'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: bg, borderRadius: BorderRadius.circular(999)),
                    child: Text(status,
                        style: GoogleFonts.sarabun(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: fg)),
                  ),
                  const SizedBox(height: 8),
                  for (final (label, value) in rows)
                    if (value.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 96,
                              child: Text(label,
                                  style: GoogleFonts.sarabun(
                                      fontSize: 14, color: mobileMuted)),
                            ),
                            Expanded(
                              child: Text(value,
                                  style: GoogleFonts.sarabun(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: mobileInk)),
                            ),
                          ],
                        ),
                      ),
                  if (medical.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => launchUrl(Uri.parse(medical),
                          mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.attach_file_rounded),
                      label: const Text('ดูใบรับรองแพทย์'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _action(Icons.description_outlined, 'ดูใบลา / พิมพ์',
                _busy ? null : _openDocument),
            if (canEdit)
              _action(Icons.edit_outlined, 'แก้ไขใบลา', _busy ? null : _edit),

            // อนุมัติได้เฉพาะผู้ดูแลระบบ (ผู้บริหารไม่มีสิทธิ์อนุมัติ)
            if (_isAdmin && group != LeaveStatusGroup.approved) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _busy || group == LeaveStatusGroup.returned
                          ? null
                          : _return,
                      child: Text('ไม่อนุมัติ',
                          style: GoogleFonts.sarabun(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _busy ? null : _approve,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : Text('อนุมัติ',
                              style: GoogleFonts.sarabun(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
            if (_isAdmin) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626)),
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('ลบใบลานี้'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE2E8F0))),
          leading: Icon(icon, color: mobileAccent),
          title: Text(label,
              style: GoogleFonts.sarabun(
                  fontSize: 15, fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}
