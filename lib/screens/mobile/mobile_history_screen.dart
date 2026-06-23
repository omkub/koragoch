import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/firebase_service.dart';
import 'mobile_leave_form_screen.dart';

class MobileHistoryScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onEdit;
  const MobileHistoryScreen({super.key, this.onEdit});

  @override
  State<MobileHistoryScreen> createState() => _MobileHistoryScreenState();
}

class _MobileHistoryScreenState extends State<MobileHistoryScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  String _currentUserName = "";
  String _userRole = "";
  bool _isLoading = true;

  // 📅 ระบบจัดการรอบงบประมาณ 🥇🏆
  List<Map<String, dynamic>> _rounds = [];
  Map<String, dynamic>? _selectedRound;
  bool _isRoundsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadRounds();
  }

  Future<void> _loadRounds() async {
    try {
      final rounds = await _firebaseService.getFiscalRounds();
      final active = await _firebaseService.getActiveFiscalRound();

      if (mounted) {
        setState(() {
          _rounds = rounds;
          // ถ้ามีรอบที่กำลังทำงาน (Active) ให้เลือกเป็นค่าเริ่มต้นครับ 🕵️‍♂️🥇
          if (active != null) {
            _selectedRound = _rounds.firstWhere((r) => r['id'] == active['id'],
                orElse: () =>
                    _rounds.isNotEmpty ? _rounds.first : <String, dynamic>{});
            if (_selectedRound!.isEmpty) _selectedRound = null;
          } else if (_rounds.isNotEmpty) {
            _selectedRound = _rounds.first;
          }
          _isRoundsLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading rounds: $e");
      if (mounted) setState(() => _isRoundsLoading = false);
    }
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserName = prefs.getString('currentUser') ?? '';
      _userRole = prefs.getString('userRole') ?? 'ครู';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB))));

    return Material(
      color: const Color(0xFFF4F7FC), // Premium background
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          _userRole.contains('ผู้ดูแลระบบ')
                              ? "ข้อมูลภาพรวมระบบ"
                              : "ข้อมูลส่วนตัว",
                          style: GoogleFonts.sarabun(
                              fontSize: 16,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w600)),
                      Text(
                          _userRole.contains('ผู้ดูแลระบบ')
                              ? "ประวัติการลาทั้งหมด"
                              : "ประวัติการลา",
                          style: GoogleFonts.sarabun(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.5)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ]),
                    child: const Icon(Icons.manage_history_rounded,
                        color: Color(0xFF2563EB), size: 28),
                  )
                ],
              ),
            ),

            // --- Round Selector ---
            if (!_isRoundsLoading && _rounds.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Map<String, dynamic>>(
                      value: _selectedRound,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down_circle_outlined,
                          color: Color(0xFF3B82F6), size: 20),
                      style: GoogleFonts.sarabun(
                          fontSize: 15,
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.w600),
                      borderRadius: BorderRadius.circular(16),
                      items: _rounds
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(
                                    "ปีงบ ${r['year']} - รอบที่ ${r['round']}"),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedRound = val),
                    ),
                  ),
                ),
              ),

            if (_selectedRound != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
                child: Text(
                  "ช่วงวันที่: ${FirebaseService.formatThaiDate(_selectedRound!['startDate'])} ถึง ${FirebaseService.formatThaiDate(_selectedRound!['endDate'])}",
                  style: GoogleFonts.sarabun(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500),
                ),
              ),

            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: (_userRole.contains('ผู้ดูแลระบบ') ||
                        _userRole.contains('ผู้บริหาร'))
                    ? _firebaseService.getLeaveRequestsStream()
                    : _firebaseService
                        .getMyLeaveRequestsStream(_currentUserName.trim()),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF3B82F6)));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 20)
                                ]),
                            child: const Icon(Icons.history_rounded,
                                size: 60, color: Color(0xFFCBD5E1)),
                          ),
                          const SizedBox(height: 16),
                          Text(
                              _userRole.contains('ผู้ดูแลระบบ')
                                  ? "ยังไม่มีข้อมูลการลาในระบบครับ"
                                  : "ยังไม่มีข้อมูลการลาของคุณครับ",
                              style: GoogleFonts.sarabun(
                                  fontSize: 16,
                                  color: const Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }

                  final allLeaves = snapshot.data!;
                  // 🕵️‍♂️ กรองข้อมูลตามรอบงบประมาณที่เลือกครับ 🥇🏆🏎️
                  final leaves = _selectedRound == null
                      ? allLeaves
                      : allLeaves
                          .where((l) => FirebaseService.isDateInRange(
                              l['startDate']?.toString() ?? '',
                              _selectedRound!['startDate'] ?? '',
                              _selectedRound!['endDate'] ?? ''))
                          .toList();

                  if (leaves.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off_rounded,
                              size: 48, color: Color(0xFFCBD5E1)),
                          const SizedBox(height: 12),
                          Text("ไม่พบข้อมูลการลาในรอบนี้ครับ",
                              style: GoogleFonts.sarabun(
                                  fontSize: 14,
                                  color: const Color(0xFF94A3B8))),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 40),
                    physics: const BouncingScrollPhysics(),
                    itemCount: leaves.length,
                    itemBuilder: (context, index) {
                      return _buildLeaveCard(context, leaves[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveCard(BuildContext context, Map<String, dynamic> leave) {
    final status = leave['status'] ?? 'รอพิจารณา';
    final Color statusColor = _getStatusColor(status);
    final String leaveType = FirebaseService.leaveTypeWithHalfDay(leave);
    final String dateRange =
        "${FirebaseService.formatThaiDate(leave['startDate'])} ถึง ${FirebaseService.formatThaiDate(leave['endDate'])}";
    final String totalDays =
        "${FirebaseService.formatLeaveDayCount(leave['totalDays'])} วัน";
    final String name = leave['fullName'] ?? 'ไม่ระบุชื่อ';

    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(name,
                    style: GoogleFonts.sarabun(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 12),
              // 🔥 ส่วนแสดงสถานะและเมนูจัดการ 🕵️‍♂️🥇
              if (_userRole.contains('ผู้ดูแลระบบ') ||
                  status == 'รอพิจารณา' ||
                  status == 'ยังไม่ส่ง')
                _buildActionMenu(context, leave, status, statusColor)
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(status,
                      style: GoogleFonts.sarabun(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: statusColor)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.category_rounded, leaveType,
              const Color(0xFF8B5CF6)), // Purple
          const SizedBox(height: 10),
          _buildInfoRow(Icons.calendar_month_rounded, dateRange,
              const Color(0xFF3B82F6)), // Blue
          const SizedBox(height: 10),
          _buildInfoRow(Icons.access_time_filled_rounded, "จำนวน $totalDays",
              const Color(0xFFF59E0B)), // Amber

          if (leave['reason'] != null &&
              (leave['reason'] as String).isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1F5F9))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_rounded,
                      size: 18, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text("${leave['reason']}",
                          style: GoogleFonts.sarabun(
                              fontSize: 14,
                              color: const Color(0xFF64748B),
                              height: 1.4))),
                ],
              ),
            ),
          ],

          // 📄 ส่วนแสดงใบรับรองแพทย์ (ถ้ามี) 🥇🏆🏎️
          if (leave['medicalCertificate'] != null &&
              (leave['medicalCertificate'] as String).startsWith('http')) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final Uri url = Uri.parse(leave['medicalCertificate']);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF), // Light Blue
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.description_rounded,
                        size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 10),
                    Text("ดูใบรับรองแพทย์/ใบนัด",
                        style: GoogleFonts.sarabun(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2563EB))),
                    const SizedBox(width: 8),
                    const Icon(Icons.open_in_new_rounded,
                        size: 14, color: Color(0xFF3B82F6)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color iconColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(text,
                style: GoogleFonts.sarabun(
                    fontSize: 15,
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w500))),
      ],
    );
  }

  Color _getStatusColor(String status) {
    if (status.contains('รอ') || status == 'ยังไม่ส่ง')
      return const Color(0xFFF59E0B); // Amber 500
    if (status.contains('อนุมัติ') ||
        status == 'ส่งใบลาแล้ว' ||
        status == 'ส่งใบแล้ว' ||
        status == 'อนุญาต') return const Color(0xFF10B981); // Emerald 500
    if (status.contains('ไม่')) return const Color(0xFFEF4444); // Red 500
    return const Color(0xFF94A3B8); // Slate 400
  }

  // 🛠️ เมนูจัดการ (Mobile Actions) 🕵️‍♂️🥇
  Widget _buildActionMenu(BuildContext context, Map<String, dynamic> leave,
      String status, Color statusColor) {
    final isAdmin = _userRole.contains('ผู้ดูแลระบบ');
    final canEdit = isAdmin || status == 'รอพิจารณา' || status == 'ยังไม่ส่ง';

    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      tooltip: "จัดการข้อมูล",
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: statusColor.withOpacity(0.2))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(status,
                style: GoogleFonts.sarabun(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: statusColor)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 18, color: statusColor),
          ],
        ),
      ),
      onSelected: (val) async {
        if (val == 'approve')
          await _updateStatus(leave['requestId'], 'ส่งใบแล้ว');
        if (val == 'reject')
          await _updateStatus(leave['requestId'], 'ยังไม่ส่ง');
        if (val == 'delete') _showDeleteConfirmation(context, leave);
        if (val == 'edit') {
          _editLeaveRequest(leave);
        }
      },
      itemBuilder: (context) => [
        if (isAdmin)
          PopupMenuItem(
              value: 'approve',
              child: Row(children: [
                const Icon(Icons.check_circle_outline,
                    color: Colors.green, size: 20),
                const SizedBox(width: 10),
                Text("ส่งใบแล้ว (อนุมัติ)",
                    style: GoogleFonts.sarabun(fontSize: 14))
              ])),
        if (isAdmin)
          PopupMenuItem(
              value: 'reject',
              child: Row(children: [
                const Icon(Icons.pending_actions,
                    color: Colors.orange, size: 20),
                const SizedBox(width: 10),
                Text("ยังไม่ส่ง (ปฏิเสธ)",
                    style: GoogleFonts.sarabun(fontSize: 14))
              ])),
        if (isAdmin) const PopupMenuDivider(),
        if (canEdit)
          PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                const Icon(Icons.edit_outlined, color: Colors.amber, size: 20),
                const SizedBox(width: 10),
                Text("แก้ไขใบลา",
                    style: GoogleFonts.sarabun(
                        fontSize: 14, color: Colors.amber.shade700))
              ])),
        if (isAdmin)
          PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                const SizedBox(width: 10),
                Text("ลบรายการนี้",
                    style: GoogleFonts.sarabun(fontSize: 14, color: Colors.red))
              ])),
      ],
    );
  }

  // 📝 อัปเดตสถานะใบลา 🥇🏆
  Future<void> _updateStatus(String? requestId, String newStatus) async {
    if (requestId == null) return;
    try {
      await _firebaseService.db
          .collection('Leaves')
          .doc(requestId)
          .update({'status': newStatus});

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ ปรับปรุงสถานะเป็น: $newStatus เรียบร้อยแล้ว'),
            backgroundColor: Colors.green));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('❌ เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red));
    }
  }

  // 🗑️ ยืนยันการลบไฟล์ 🥇🏆
  void _showDeleteConfirmation(
      BuildContext context, Map<String, dynamic> leave) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("ยืนยันการลบ",
            style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
        content: Text(
            "คุณแน่ใจหรือไม่ว่าต้องการลบข้อมูลการลาของ ${leave['fullName']}? ข้อมูลจะถูกลบถาวรครับ",
            style: GoogleFonts.sarabun(fontSize: 15)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("ยกเลิก",
                  style: GoogleFonts.sarabun(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final medicalUrl =
                    leave['medicalCertificate']?.toString() ?? '';
                if (medicalUrl.isNotEmpty)
                  await _firebaseService.deleteDriveFileStrict(medicalUrl);
                await _firebaseService.db
                    .collection('Leaves')
                    .doc(leave['requestId'])
                    .delete();
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('✅ ลบรายการเรียบร้อยแล้ว'),
                      backgroundColor: Colors.black));
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('❌ ล้มเหลว: $e'),
                      backgroundColor: Colors.red));
              }
            },
            child: Text("ยืนยันการลบ",
                style: GoogleFonts.sarabun(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _editLeaveRequest(Map<String, dynamic> leaf) {
    if (widget.onEdit != null) {
      widget.onEdit!(leaf);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => MobileLeaveFormScreen(initialData: leaf),
        ),
      );
    }
  }
}
