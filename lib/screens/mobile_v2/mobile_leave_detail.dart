/// รายละเอียดใบลา (มือถือ mobile_v2) — จัดหมวดหมู่ให้ชัดเจนและสบายตา
///
/// หมวดหมู่ในหน้านี้:
///   1) การ์ดสรุปสถานะและผู้ยื่นใบลา
///   2) หมวดรายละเอียดวันลาและเหตุผล
///   3) หมวดเอกสารและการจัดการ (ดู/พิมพ์ใบลา · แก้ไขใบลา)
///   4) หมวดการพิจารณาสำหรับผู้ดูแลระบบ (อนุมัติ / ส่งกลับ / ลบ)
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/firebase_service.dart';
import '../../widgets/leave_form_page.dart';
import 'leave_actions.dart';
import 'menu_access.dart';
import 'mobile_pages.dart';
import '../../utils/leave_permissions.dart';

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
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style: GoogleFonts.sarabun(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(message,
                  style: GoogleFonts.sarabun(fontSize: 15, color: mobileMuted)),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: color,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
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
    final canEdit = _isAdmin ||
        LeavePermissions.canModify(_leave,
            role: widget.access.userRole, myName: widget.access.currentUser);
    final start = FirebaseService.formatThaiDate(_leave['startDate']);
    final end = FirebaseService.formatThaiDate(_leave['endDate']);
    final medical = (_leave['medicalCertificate'] ?? '').toString();
    final halfDay = _leave['isHalfDay'] == true
        ? (_leave['halfDayPeriod'] == 'afternoon' ? 'ครึ่งวันบ่าย' : 'ครึ่งวันเช้า')
        : 'เต็มวัน';
    final receiveNumber = (_leave['receiveNumber'] ?? '').toString().trim();

    final rows = <(IconData, String, String)>[
      (Icons.person_outline_rounded, 'ผู้ยื่นใบลา', (_leave['fullName'] ?? '-').toString()),
      (Icons.category_outlined, 'ประเภทการลา', (_leave['leaveType'] ?? '-').toString()),
      (Icons.calendar_month_rounded, 'ช่วงวันที่ลา', start == end ? start : '$start ถึง $end'),
      (
        Icons.schedule_rounded,
        'จำนวนวันลา',
        '${FirebaseService.formatLeaveDayCount(_leave['totalDays'])} วัน ($halfDay)'
      ),
      (Icons.notes_rounded, 'เหตุผลการลา', (_leave['reason'] ?? '').toString()),
      (Icons.phone_outlined, 'เบอร์ติดต่อ', (_leave['phone'] ?? '').toString()),
      if (receiveNumber.isNotEmpty)
        (Icons.verified_outlined, 'เลขรับใบลา', receiveNumber),
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            // ── หมวดที่ 1: ข้อมูลใบลา ──
            const MobileSectionHeader(
              icon: Icons.assignment_outlined,
              title: 'ข้อมูลการลา',
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: mobileLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(999)),
                        child: Text(status,
                            style: GoogleFonts.sarabun(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: fg)),
                      ),
                      const Spacer(),
                      if (receiveNumber.isNotEmpty)
                        Text(
                          'เลขรับที่ $receiveNumber',
                          style: GoogleFonts.sarabun(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: mobileMuted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 8),
                  for (final (icon, label, value) in rows)
                    if (value.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, size: 17, color: mobileMuted),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 96,
                              child: Text(label,
                                  style: GoogleFonts.sarabun(
                                      fontSize: 13.5, color: mobileMuted)),
                            ),
                            Expanded(
                              child: Text(value,
                                  style: GoogleFonts.sarabun(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: mobileInk)),
                            ),
                          ],
                        ),
                      ),
                  if (medical.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: mobileAccent,
                          side: const BorderSide(color: Color(0xFFBFDBFE)),
                          backgroundColor: const Color(0xFFF8FAFC),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => launchUrl(Uri.parse(medical),
                            mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.attach_file_rounded, size: 18),
                        label: Text('เปิดดูไฟล์ใบรับรองแพทย์ที่แนบ',
                            style: GoogleFonts.sarabun(
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── หมวดที่ 2: เอกสารและการจัดการ ──
            const SizedBox(height: 20),
            const MobileSectionHeader(
              icon: Icons.description_outlined,
              title: 'เอกสารและการจัดการ',
              iconColor: Color(0xFF0284C7),
            ),
            _action(
              Icons.print_rounded,
              'ดูใบลา / พิมพ์เอกสาร (PDF)',
              'แสดงหน้าใบลาตามแม่แบบของโรงเรียน',
              _busy ? null : _openDocument,
            ),
            if (canEdit)
              _action(
                Icons.edit_note_rounded,
                'แก้ไขข้อมูลใบลา',
                'ปรับปรุงวันที่ เหตุผล หรือเอกสารแนบ',
                _busy ? null : _edit,
              ),

            // ── หมวดที่ 3: การอนุมัติสำหรับผู้ดูแลระบบ ──
            if (_isAdmin) ...[
              const SizedBox(height: 16),
              const MobileSectionHeader(
                icon: Icons.gavel_rounded,
                title: 'การพิจารณาสำหรับผู้ดูแลระบบ',
                iconColor: Color(0xFFD97706),
              ),
              if (group != LeaveStatusGroup.approved)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _busy || group == LeaveStatusGroup.returned
                            ? null
                            : _return,
                        icon: const Icon(Icons.reply_rounded, size: 18),
                        label: Text('ไม่อนุมัติ',
                            style: GoogleFonts.sarabun(
                                fontSize: 15.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _busy ? null : _approve,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white))
                            : const Icon(Icons.check_circle_outline_rounded,
                                size: 19),
                        label: Text('อนุมัติใบลา',
                            style: GoogleFonts.sarabun(
                                fontSize: 15.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626)),
                  onPressed: _busy ? null : _delete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 19),
                  label: Text('ลบใบลานี้ถาวร',
                      style: GoogleFonts.sarabun(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _action(
      IconData icon, String label, String subtitle, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: mobileLine),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: mobileAccent, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: GoogleFonts.sarabun(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: mobileInk)),
                      Text(subtitle,
                          style: GoogleFonts.sarabun(
                              fontSize: 12, color: mobileMuted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: mobileMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
