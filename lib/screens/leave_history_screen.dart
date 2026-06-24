import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'leave_form_screen.dart';

class LeaveHistoryScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onEdit;
  const LeaveHistoryScreen({super.key, this.onEdit});

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends State<LeaveHistoryScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _allLeaveRequests = [];

  // Track selected IDs for bulk deletion 🧹✨🥇
  final Set<String> _selectedIds = {};
  bool _isDeletingBulk = false;
  List<Map<String, dynamic>> _latestLeaves =
      []; // 📋 cache รายการล่าสุดจาก stream ครับ
  String? _userRole;
  String? _currentUser;

  // 📅 ระบบจัดการรอบงบประมาณ 🥇🏆
  List<Map<String, dynamic>> _rounds = [];
  Map<String, dynamic>? _selectedRound;
  bool _isRoundsLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNecessaryData();
  }

  Future<void> _fetchNecessaryData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userRole = prefs.getString('userRole');
      _currentUser = prefs.getString('currentUser');

      final usersSnap = await _firebaseService.getUsers();
      final leavesSnap = (_userRole?.contains('ผู้ดูแลระบบ') == true ||
              _userRole?.contains('ผู้บริหาร') == true)
          ? await _firebaseService.getLeaveRequests()
          : await _firebaseService.getMyLeaveRequests(_currentUser ?? '');

      // 🕵️‍♂️ โหลดรอบงบประมาณเพิ่มเติมครับ 🥇🏆
      final roundsSnap = await _firebaseService.getFiscalRounds();
      final activeRound = await _firebaseService.getActiveFiscalRound();

      if (mounted) {
        setState(() {
          _allUsers = usersSnap;
          _allLeaveRequests = leavesSnap;
          _rounds = roundsSnap;

          // ตั้งค่ารอบเริ่มต้นเป็นรอบที่กำลังทำงานครับ 🕵️‍♂️🥇
          if (activeRound != null) {
            _selectedRound = _rounds.firstWhere(
                (r) => r['id'] == activeRound['id'],
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
      debugPrint("Error fetching necessary data: $e");
      if (mounted) setState(() => _isRoundsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      // 🗑️ FAB ลบหลายรายการ — ลอยอยู่มุมขวาล่าง ไม่มีทางหายแน่นอน 🥇🏆
      floatingActionButton: _selectedIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isDeletingBulk
                  ? null
                  : _showBulkDeleteConfirmationFromBanner,
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              icon: _isDeletingBulk
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.delete_forever_rounded, size: 26),
              label: Text(
                _isDeletingBulk
                    ? 'กำลังลบ...'
                    : 'ลบ ${_selectedIds.length} รายการ',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: SingleChildScrollView(
        padding:
            EdgeInsets.all(MediaQuery.of(context).size.width < 800 ? 16 : 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MediaQuery.of(context).size.width < 800
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.history,
                                color: Colors.black, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Text('ประวัติการลาทั้งหมด',
                              style: GoogleFonts.sarabun(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back,
                                size: 18, color: Colors.black),
                            label: Text('ย้อนกลับ',
                                style: GoogleFonts.sarabun(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black)),
                            style: TextButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => setState(() {}),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text('รีเฟรช',
                                style: GoogleFonts.sarabun(
                                    fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // --- Mobile Round Selector ---
                      if (!_isRoundsLoading && _rounds.isNotEmpty)
                        _buildRoundSelector(),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.history,
                                      color: Colors.black, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Text('ประวัติการลาทั้งหมด',
                                    style: GoogleFonts.sarabun(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                                'ตรวจสอบสถานะและประวัติการลาย้อนหลัง กรองรายรอบงบประมาณได้ครับ',
                                style: GoogleFonts.sarabun(
                                    fontSize: 14, color: Colors.black87)),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          // --- Desktop Round Selector ---
                          if (!_isRoundsLoading && _rounds.isNotEmpty)
                            _buildRoundSelector(),
                          const SizedBox(width: 16),
                          TextButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back,
                                size: 18, color: Colors.black),
                            label: Text('ย้อนกลับ',
                                style: GoogleFonts.sarabun(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black)),
                            style: TextButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => setState(() {}),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text('รีเฟรช',
                                style: GoogleFonts.sarabun(
                                    fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))),
                          ),
                        ],
                      ),
                    ],
                  ),
            const SizedBox(height: 16),

            // 🗑️ Bulk Delete Banner — อยู่นอก horizontal scroll เพื่อให้เต็มความกว้างหน้าจอ 🥇🏆
            if (_selectedIds.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.red.shade300, width: 1.5)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.checklist_rounded,
                              color: Colors.red, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('เลือกไว้ ${_selectedIds.length} รายการ',
                                  style: GoogleFonts.sarabun(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade900)),
                              Text(
                                  'กดปุ่มด้านล่างเพื่อลบรายการที่เลือกทั้งหมดออกจากระบบ',
                                  style: GoogleFonts.sarabun(
                                      fontSize: 12,
                                      color: Colors.red.shade400)),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() => _selectedIds.clear()),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: Text('ยกเลิก',
                              style: GoogleFonts.sarabun(
                                  fontWeight: FontWeight.w600)),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isDeletingBulk
                            ? null
                            : _showBulkDeleteConfirmationFromBanner,
                        icon: _isDeletingBulk
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white))
                            : const Icon(Icons.delete_forever_rounded,
                                size: 22),
                        label: Text(
                            _isDeletingBulk
                                ? 'กำลังลบ...'
                                : 'ลบ ${_selectedIds.length} รายการที่เลือกทั้งหมด',
                            style: GoogleFonts.sarabun(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: MediaQuery.of(context).size.width < 1000
                    ? 1200
                    : MediaQuery.of(context).size.width - 64,
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: (_userRole?.contains('ผู้ดูแลระบบ') == true ||
                          _userRole?.contains('ผู้บริหาร') == true)
                      ? _firebaseService.getLeaveRequestsStream()
                      : _firebaseService
                          .getMyLeaveRequestsStream(_currentUser ?? ''),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child:
                              CircularProgressIndicator(color: Colors.black));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                            const Icon(Icons.history_edu,
                                size: 64, color: Colors.black),
                            const SizedBox(height: 16),
                            Text('ยังไม่มีรายการประวัติครับ',
                                style: GoogleFonts.sarabun(color: Colors.black))
                          ]));
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
                    _latestLeaves = leaves; // 📋 อัพเดต cache ครับ
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                child: _buildSelectBox(
                                  checked: leaves.isNotEmpty &&
                                      _selectedIds.length >= leaves.length,
                                  onTap: () {
                                    setState(() {
                                      if (leaves.isNotEmpty &&
                                          _selectedIds.length >=
                                              leaves.length) {
                                        _selectedIds.clear();
                                      } else {
                                        _selectedIds.addAll(leaves.map((l) =>
                                            l['requestId']?.toString() ?? ''));
                                      }
                                    });
                                  },
                                ),
                              ),
                              _buildHeaderLabel('ชื่อ', width: 170),
                              _buildHeaderLabel('ประเภทลา', width: 140),
                              _buildHeaderLabel('เริ่ม', width: 110),
                              _buildHeaderLabel('สิ้นสุด', width: 110),
                              _buildHeaderLabel('เหตุผล', width: 210),
                              _buildHeaderLabel('สถานะ', width: 110),
                              _buildHeaderLabel('ID', width: 150),
                              _buildHeaderLabel('ปีงบ',
                                  width: 80, align: TextAlign.center),
                              _buildHeaderLabel('จำนวนวัน',
                                  width: 80, align: TextAlign.center),
                              _buildHeaderLabel('ใบรับรองแพทย์/ใบนัด',
                                  width: 120, align: TextAlign.center),
                              _buildHeaderLabel('จัดการ',
                                  width: 50, align: TextAlign.right),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5))
                              ]),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: leaves.length,
                              separatorBuilder: (ctx, i) => const Divider(
                                  height: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (ctx, i) =>
                                  _buildHistoryRow(leaves[i]),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: Text(
                        _selectedRound != null
                            ? 'แสดงรายการระหว่างวันที่ ${FirebaseService.formatThaiDate(_selectedRound!['startDate'])} ถึง ${FirebaseService.formatThaiDate(_selectedRound!['endDate'])}'
                            : 'แสดงรายการทั้งหมดในระบบ',
                        style: GoogleFonts.sarabun(
                            fontSize: 12, color: Colors.black)))),
          ],
        ),
      ),
    );
  }

  // 📅 Dropdown เลือกปีงบประมาณ 🥇🏆
  Widget _buildRoundSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month_rounded,
              size: 18, color: Colors.black54),
          const SizedBox(width: 12),
          DropdownButtonHideUnderline(
            child: DropdownButton<Map<String, dynamic>>(
              value: _selectedRound,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.black45),
              style: GoogleFonts.sarabun(
                  fontSize: 14,
                  color: Colors.black,
                  fontWeight: FontWeight.bold),
              borderRadius: BorderRadius.circular(12),
              items: _rounds
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text("ปีงบ ${r['year']} - รอบที่ ${r['round']}"),
                      ))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedRound = val;
                  _selectedIds
                      .clear(); // ล้างการเลือกแบบ Bulk เมื่อเปลี่ยนรอบครับ 🧹
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderLabel(String text,
      {required double width, TextAlign align = TextAlign.left}) {
    return SizedBox(
        width: width,
        child: Text(text,
            textAlign: align,
            style: GoogleFonts.sarabun(
                fontSize: 12,
                color: Colors.black,
                fontWeight: FontWeight.bold)));
  }

  Widget _buildSelectBox({required bool checked, required VoidCallback onTap}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTap: onTap,
        child: SizedBox(
          width: 16,
          height: 16,
          child: Container(
            decoration: BoxDecoration(
              color: checked ? Colors.black : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.black87, width: 1.4),
            ),
            child: checked
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryRow(Map<String, dynamic> leaf) {
    final type = FirebaseService.leaveTypeWithHalfDay(leaf);
    final status = leaf['status'] ?? 'รอพิจารณา';
    final name = leaf['fullName'] ?? '-';
    final requestId = leaf['requestId']?.toString() ?? '';
    final isSelected = _selectedIds.contains(requestId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: _buildSelectBox(
              checked: isSelected,
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedIds.remove(requestId);
                  } else {
                    _selectedIds.add(requestId);
                  }
                });
              },
            ),
          ),
          SizedBox(
              width: 170,
              child: Text(name,
                  style: GoogleFonts.sarabun(
                      fontSize: 13,
                      color: Colors.black,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal),
                  overflow: TextOverflow.ellipsis)),
          SizedBox(
              width: 140,
              child: Text(type,
                  style: GoogleFonts.sarabun(
                      fontSize: 13,
                      color: isSelected ? Colors.black : Colors.black87))),
          SizedBox(
              width: 110,
              child: Text(FirebaseService.formatThaiDate(leaf['startDate']),
                  style:
                      GoogleFonts.sarabun(fontSize: 13, color: Colors.black))),
          SizedBox(
              width: 110,
              child: Text(FirebaseService.formatThaiDate(leaf['endDate']),
                  style:
                      GoogleFonts.sarabun(fontSize: 13, color: Colors.black))),
          SizedBox(
              width: 210,
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(leaf['reason'] ?? '-',
                      style: GoogleFonts.sarabun(
                          fontSize: 13, color: Colors.black),
                      overflow: TextOverflow.ellipsis))),
          SizedBox(
            width: 110,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: (status == 'ส่งใบแล้ว' ||
                          status == 'ส่งใบลาแล้ว' ||
                          status == 'อนุมัติแล้ว' ||
                          status == 'อนุญาต')
                      ? Colors.green.withOpacity(0.1)
                      : (status == 'ยังไม่ส่ง' || status == 'ไม่อนุญาต')
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                      (status == 'ส่งใบแล้ว' ||
                              status == 'ส่งใบลาแล้ว' ||
                              status == 'อนุมัติแล้ว' ||
                              status == 'อนุญาต')
                          ? Icons.check_circle
                          : (status == 'ยังไม่ส่ง' || status == 'ไม่อนุญาต'
                              ? Icons.pending
                              : Icons.check_circle_outline),
                      size: 13,
                      color: (status == 'ส่งใบแล้ว' ||
                              status == 'ส่งใบลาแล้ว' ||
                              status == 'อนุมัติแล้ว' ||
                              status == 'อนุญาต')
                          ? Colors.green
                          : (status == 'ยังไม่ส่ง' || status == 'ไม่อนุญาต'
                              ? Colors.orange
                              : Colors.black)),
                  const SizedBox(width: 4),
                  Text(status,
                      style: GoogleFonts.sarabun(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: (status == 'ส่งใบแล้ว' ||
                                  status == 'ส่งใบลาแล้ว' ||
                                  status == 'อนุมัติแล้ว' ||
                                  status == 'อนุญาต')
                              ? Colors.green
                              : (status == 'ยังไม่ส่ง' || status == 'ไม่อนุญาต'
                                  ? Colors.orange
                                  : Colors.black))),
                ],
              ),
            ),
          ),
          SizedBox(
              width: 150,
              child: Text(requestId,
                  style: GoogleFonts.sarabun(
                      fontSize: 12, color: Colors.black54))),
          SizedBox(
              width: 80,
              child: Center(
                  child: Text(leaf['year']?.toString() ?? '-',
                      style: GoogleFonts.sarabun(
                          fontSize: 12, color: Colors.black)))),
          SizedBox(
              width: 80,
              child: Center(
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(
                          FirebaseService.formatLeaveDayCount(
                              leaf['totalDays']),
                          style: GoogleFonts.sarabun(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black))))),
          SizedBox(
            width: 110,
            child: Center(
              child: Builder(builder: (context) {
                String? certUrl = leaf['medicalCertificate']?.toString();
                if (certUrl != null && certUrl.startsWith('http')) {
                  String imgUrl = certUrl;
                  if (certUrl.contains('drive.google.com')) {
                    final regExp = RegExp(r'(?:id=|\/d\/)([a-zA-Z0-9-_]+)');
                    final match = regExp.firstMatch(certUrl);
                    if (match != null) {
                      imgUrl =
                          'https://lh3.googleusercontent.com/d/${match.group(1)}';
                    }
                  }
                  return InkWell(
                    onTap: () => launchUrl(Uri.parse(certUrl)),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.black.withOpacity(0.1))),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(imgUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => const Icon(
                              Icons.attach_file,
                              color: Colors.black,
                              size: 16)),
                    ),
                  );
                }
                return Text('-',
                    style: GoogleFonts.sarabun(color: Colors.black26));
              }),
            ),
          ),
          SizedBox(
            width: 50,
            child: Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon:
                    const Icon(Icons.more_vert, size: 18, color: Colors.black),
                onSelected: (value) async {
                  if (value == 'view') {
                    _showPdfPreview(leaf);
                  } else if (value == 'edit') {
                    _editLeaveRequest(leaf);
                  } else if (value == 'delete') {
                    _showDeleteConfirmation(leaf);
                  } else if (value == 'approve') {
                    await _updateStatus(requestId, 'ส่งใบแล้ว');
                  } else if (value == 'reject') {
                    await _updateStatus(requestId, 'ยังไม่ส่ง');
                  }
                },
                itemBuilder: (BuildContext context) {
                  final isAdmin = _userRole?.contains('ผู้ดูแลระบบ') == true;
                  final canEdit =
                      isAdmin || status == 'รอพิจารณา' || status == 'ยังไม่ส่ง';

                  return [
                    PopupMenuItem<String>(
                        value: 'approve',
                        child: Row(children: [
                          const Icon(Icons.send_rounded,
                              size: 18, color: Colors.green),
                          const SizedBox(width: 10),
                          Text('ส่งใบแล้ว',
                              style: GoogleFonts.sarabun(
                                  fontSize: 13, color: Colors.green))
                        ])),
                    PopupMenuItem<String>(
                        value: 'reject',
                        child: Row(children: [
                          const Icon(Icons.pending_actions_rounded,
                              size: 18, color: Colors.orange),
                          const SizedBox(width: 10),
                          Text('ยังไม่ส่ง',
                              style: GoogleFonts.sarabun(
                                  fontSize: 13, color: Colors.orange))
                        ])),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                        value: 'view',
                        child: Row(children: [
                          const Icon(Icons.picture_as_pdf_outlined,
                              size: 18, color: Colors.blue),
                          const SizedBox(width: 10),
                          Text('พิมพ์หรือดาวน์โหลด PDF',
                              style: GoogleFonts.sarabun(fontSize: 13))
                        ])),
                    if (canEdit)
                      PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(children: [
                            const Icon(Icons.edit_outlined,
                                size: 18, color: Colors.amber),
                            const SizedBox(width: 10),
                            Text('แก้ไขใบลา',
                                style: GoogleFonts.sarabun(
                                    fontSize: 13, color: Colors.amber.shade700))
                          ])),
                    PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(children: [
                          const Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          const SizedBox(width: 10),
                          Text('ลบรายการ',
                              style: GoogleFonts.sarabun(
                                  fontSize: 13, color: Colors.red))
                        ])),
                  ];
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String requestId, String status) async {
    try {
      await _firebaseService.db
          .collection('Leaves')
          .doc(requestId)
          .update({'status': status});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ ปรับปรุงสถานะเป็น: $status เรียบร้อยแล้ว'),
          backgroundColor: (status == 'ส่งใบแล้ว' ||
                  status == 'ส่งใบลาแล้ว' ||
                  status == 'อนุมัติแล้ว' ||
                  status == 'อนุญาต')
              ? Colors.green
              : Colors.orange,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('❌ เกิดข้อผิดพลาด: $e')));
    }
  }

  void _showPdfPreview(Map<String, dynamic> leaf) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => _PdfPreviewViewer(
          leaf: leaf,
          allUsers: _allUsers,
          allLeaveRequests: _allLeaveRequests,
        ),
      ),
    );
  }

  void _editLeaveRequest(Map<String, dynamic> leaf) {
    if (widget.onEdit != null) {
      widget.onEdit!(leaf);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => LeaveFormScreen(initialData: leaf),
        ),
      );
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> leaf) {
    final requestId = leaf['requestId']?.toString() ?? '';
    final medicalUrl = leaf['medicalCertificate']?.toString() ?? '';
    if (requestId.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 10),
          Text('ยืนยันการลบ',
              style: GoogleFonts.sarabun(fontWeight: FontWeight.bold))
        ]),
        content: Text(
            'คุณต้องการลบรายการใบลา ID: $requestId หรือไม่?\nข้อมูลทั้งหมดจะถูกลบถาวรครับ',
            style: GoogleFonts.sarabun()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('ยกเลิก',
                  style: GoogleFonts.sarabun(color: Colors.grey.shade600))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                if (medicalUrl.isNotEmpty)
                  await _firebaseService.deleteDriveFileStrict(medicalUrl);
                await _firebaseService.db
                    .collection('Leaves')
                    .doc(requestId)
                    .delete();
                if (mounted) {
                  setState(() => _selectedIds.remove(requestId));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('✅ ลบรายการเรียบร้อยแล้ว'),
                      backgroundColor: Colors.red.shade400,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))));
                }
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ เกิดข้อผิดพลาด: $e')));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: Text('ใช่, ลบทั้งหมด',
                style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showBulkDeleteConfirmationFromBanner() {
    // 🔥 ใช้ _latestLeaves ที่ cache ไว้จาก StreamBuilder ล่าสุดครับ
    _showBulkDeleteConfirmation(_latestLeaves);
  }

  void _showBulkDeleteConfirmation(List<Map<String, dynamic>> leaves) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.delete_forever, color: Colors.red),
          const SizedBox(width: 10),
          Text('ลบรายการที่เลือก',
              style: GoogleFonts.sarabun(fontWeight: FontWeight.bold))
        ]),
        content: Text(
            'คุณต้องการลบใบลาที่เลือกทั้งหมด ${_selectedIds.length} รายการหรือไม่?\nขั้นตอนนี้ไม่สามารถย้อนกลับได้ครับ',
            style: GoogleFonts.sarabun()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('ยกเลิก',
                  style: GoogleFonts.sarabun(color: Colors.grey.shade600))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _handleBulkDelete(leaves);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: Text('ยืนยันลบทั้งหมด',
                style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBulkDelete(List<Map<String, dynamic>> allLeaves) async {
    setState(() => _isDeletingBulk = true);
    int count = 0;
    try {
      final idsToDelete = List<String>.from(_selectedIds);
      for (final id in idsToDelete) {
        final leaf = allLeaves.firstWhere(
            (l) => l['requestId']?.toString() == id,
            orElse: () => {});
        if (leaf.isNotEmpty) {
          final medicalUrl = leaf['medicalCertificate']?.toString() ?? '';
          if (medicalUrl.isNotEmpty)
            await _firebaseService.deleteDriveFileStrict(medicalUrl);
          await _firebaseService.db.collection('Leaves').doc(id).delete();
          count++;
        }
      }
      if (mounted) {
        setState(() {
          _selectedIds.clear();
          _isDeletingBulk = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ ลบรสำเร็จทั้งหมด $count รายการ'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeletingBulk = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ เกิดข้อผิดพลาดในการลบกลุ่มรายการ: $e')));
      }
    }
  }
}

class _PdfPreviewViewer extends StatefulWidget {
  final Map<String, dynamic> leaf;
  final List<Map<String, dynamic>> allUsers;
  final List<Map<String, dynamic>> allLeaveRequests;

  const _PdfPreviewViewer(
      {required this.leaf,
      required this.allUsers,
      required this.allLeaveRequests});

  @override
  State<_PdfPreviewViewer> createState() => _PdfPreviewViewerState();
}

class _PdfPreviewViewerState extends State<_PdfPreviewViewer> {
  TextStyle get docBaseStyle =>
      GoogleFonts.sarabun(fontSize: 14, color: Colors.black, height: 1.5);

  String _htmlEscape(dynamic value) =>
      const HtmlEscape().convert((value ?? '-').toString());

  bool _isBlankChoice(String value) {
    final v = value.trim();
    return v.isEmpty || v == '-' || v.contains('เลือก');
  }

  bool _hasNoAcademicStanding(String value) => value.trim() == 'ไม่มีวิทยฐานะ';

  Map<String, dynamic> _userForLeaf() {
    final fullName = (widget.leaf['fullName'] ?? '').toString().trim();
    if (fullName.isEmpty) return const {};
    return widget.allUsers.firstWhere(
      (u) => (u['fullName'] ?? u['name'] ?? '').toString().trim() == fullName,
      orElse: () => const {},
    );
  }

  String _leafPosition() {
    final direct = (widget.leaf['position'] ?? '').toString();
    if (!_isBlankChoice(direct)) return direct;
    final user = _userForLeaf();
    final fromUser = (user['position'] ?? user['ตำแหน่ง'] ?? '').toString();
    return _isBlankChoice(fromUser) ? '' : fromUser;
  }

  String _leafAcademicStanding() {
    final direct = (widget.leaf['academicStanding'] ?? '').toString().trim();
    if (_hasNoAcademicStanding(direct)) return '';
    if (!_isBlankChoice(direct)) return direct;
    final user = _userForLeaf();
    final fromUser =
        (user['academicStanding'] ?? user['rank'] ?? user['วิทยฐานะ'] ?? '')
            .toString()
            .trim();
    return _isBlankChoice(fromUser) || _hasNoAcademicStanding(fromUser)
        ? ''
        : fromUser;
  }

  String _printableHtml({bool autoPrint = false}) {
    final leaf = widget.leaf;
    final leaveType = _htmlEscape(leaf['leaveType']);
    final fullName = _htmlEscape(leaf['fullName']);
    final rawPosition = _leafPosition();
    final rawRank = _leafAcademicStanding();
    final position = _htmlEscape([
      if (rawPosition.isNotEmpty) rawPosition,
      if (rawRank.isNotEmpty) rawRank,
    ].join(' '));
    final startDate =
        _htmlEscape(FirebaseService.formatThaiDate(leaf['startDate']));
    final endDate =
        _htmlEscape(FirebaseService.formatThaiDate(leaf['endDate']));
    final days = _htmlEscape(leaf['totalDays']);
    final reason = _htmlEscape(leaf['reason']);
    final phone = _htmlEscape(leaf['phone']);
    final requestDate =
        '${_htmlEscape(_getDay(leaf['timestamp']))} ${_htmlEscape(_getMonth(leaf['timestamp']))} ${_htmlEscape(_getYear(leaf['timestamp']))}';

    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Leave-${fullName}</title>
  <style>
    @page { size: A4; margin: 18mm; }
    body { font-family: "Sarabun", "TH Sarabun New", Arial, sans-serif; color: #111; }
    .page { max-width: 760px; margin: 0 auto; font-size: 16px; line-height: 1.75; }
    h1 { text-align: center; font-size: 22px; margin: 0 0 6px; text-decoration: underline; }
    h2 { text-align: center; font-size: 18px; margin: 0 0 28px; font-weight: 400; }
    .right { text-align: right; }
    .row { margin: 10px 0; }
    .indent { text-indent: 48px; }
    .line { border-bottom: 1px dotted #444; padding: 0 10px; min-width: 120px; display: inline-block; }
    .reason-section { display: grid; grid-template-columns: max-content minmax(0, 1fr); column-gap: 6px; align-items: start; margin: 0 0 4px 48px; min-width: 0; text-indent: 0; }
    .reason-label { grid-column: 1; white-space: nowrap; }
    .reason-text { grid-column: 2; min-width: 0; white-space: pre-wrap; overflow-wrap: anywhere; word-break: break-word; }
    .reason-underline { grid-column: 2; border-bottom: 1px dotted #444; margin-top: 4px; }
    table { width: 100%; border-collapse: collapse; margin-top: 18px; }
    th, td { border: 1px solid #333; padding: 8px; text-align: center; }
    .sign { margin-top: 34px; text-align: center; }
    .toolbar { position: fixed; right: 16px; top: 16px; }
    .toolbar button { padding: 8px 12px; border: 0; background: #0f172a; color: white; border-radius: 6px; cursor: pointer; }
    @media print { .toolbar { display: none; } body { margin: 0; } }
  </style>
</head>
<body>
  <div class="toolbar"><button onclick="window.print()">พิมพ์ / บันทึก PDF</button></div>
  <main class="page">
    <h1>แบบใบลา</h1>
    <h2>ลาป่วย / ลากิจส่วนตัว / ลาคลอดบุตร</h2>
    <p class="right">วันที่ ${requestDate}</p>
    <p>เรื่อง <span class="line">ขอ${leaveType}</span></p>
    <p>เรียน ผู้อำนวยการโรงเรียน</p>
    <p class="indent">ข้าพเจ้า <span class="line">${fullName}</span>
      ตำแหน่ง <span class="line">${position}</span></p>
    <div class="reason-section">
      <div class="reason-label">มีความประสงค์ขอ${leaveType} เนื่องจาก</div>
      <div class="reason-text">${reason}</div>
      <div class="reason-underline"></div>
    </div>
    <p class="indent">ตั้งแต่วันที่ <span class="line">${startDate}</span>
      ถึงวันที่ <span class="line">${endDate}</span>
      มีกำหนด <span class="line">${days}</span> วัน</p>
    <p>ระหว่างลาติดต่อได้ที่หมายเลขโทรศัพท์ <span class="line">${phone}</span></p>
    <table>
      <thead><tr><th>ประเภทการลา</th><th>จำนวนวัน</th><th>หมายเหตุ</th></tr></thead>
      <tbody><tr><td>${leaveType}</td><td>${days}</td><td></td></tr></tbody>
    </table>
    <div class="sign">
      <p>ขอแสดงความนับถือ</p>
      <br>
      <p>( ${fullName} )</p>
    </div>
  </main>
${autoPrint ? '''
<script>
  window.addEventListener('load', function() {
    setTimeout(function() {
      window.focus();
      window.print();
    }, 350);
  });
</script>
''' : ''}
</body>
</html>
''';
  }

  String _previewLikePrintableHtml({bool autoPrint = false}) {
    final leaf = widget.leaf;
    final leaveTypeRaw = (leaf['leaveType'] ?? '').toString();
    final statusRaw = (leaf['status'] ?? '').toString();
    final totalDays =
        double.tryParse(leaf['totalDays']?.toString() ?? '1') ?? 1;
    final totalDaysText = FirebaseService.formatLeaveDayCount(totalDays);
    final fullName = _htmlEscape(leaf['fullName']);
    final rawPosition = _leafPosition();
    final rawRank = _leafAcademicStanding();
    final position = _htmlEscape([
      if (rawPosition.isNotEmpty) rawPosition,
      if (rawRank.isNotEmpty) rawRank,
    ].join(' '));
    final applicantPosition =
        _htmlEscape(rawPosition.isEmpty ? '-' : rawPosition);
    final leaveType = _htmlEscape(leaveTypeRaw);
    final reason = _htmlEscape(leaf['reason']);
    final phone = _htmlEscape(leaf['phone']);
    final requestDate =
        '${_htmlEscape(_getDay(leaf['timestamp']))} ${_htmlEscape(_getMonth(leaf['timestamp']))} ${_htmlEscape(_getYear(leaf['timestamp']))}';
    final startDate =
        _htmlEscape(FirebaseService.formatThaiDate(leaf['startDate']));
    final endDate =
        _htmlEscape(FirebaseService.formatThaiDate(leaf['endDate']));
    final hrName = _htmlEscape(_getManagerName('หัวหน้ากลุ่มบริหารงานบุคคล'));
    final deputyName =
        _htmlEscape(_getManagerName('รองผู้อำนวยการกลุ่มบริหารงานบุคคล'));
    final directorName = _htmlEscape(_getManagerName('ผู้อำนวยการโรงเรียน'));

    String checkbox(String label, bool checked) {
      return '<span style="display: inline-flex; align-items: center; white-space: nowrap;"><span class="check">${checked ? '✓' : ''}</span><span>$label</span></span>';
    }

    String statRow(String label, String keyword) {
      final fullNameRaw = (leaf['fullName'] ?? '').toString();
      final currentYear = leaf['year']?.toString() ?? '';
      final relevantHistory = widget.allLeaveRequests.where((req) {
        final reqName = (req['fullName'] ?? '').toString();
        final reqType = (req['leaveType'] ?? '').toString();
        final reqYear = (req['year'] ?? '').toString();
        return reqName == fullNameRaw &&
            reqType.contains(keyword) &&
            reqYear == currentYear &&
            req['requestId'] != leaf['requestId'];
      }).toList();
      final prevTimes = relevantHistory.length;
      final prevDays = relevantHistory.fold<double>(
        0,
        (sum, req) =>
            sum + (double.tryParse(req['totalDays']?.toString() ?? '0') ?? 0),
      );
      final currentMatch = leaveTypeRaw.contains(keyword);
      final totalTimes = prevTimes + (currentMatch ? 1 : 0);
      final totalDaysCalc = prevDays + (currentMatch ? totalDays : 0);
      final currentTimesText = currentMatch ? '1' : '-';
      final currentDaysText = currentMatch ? totalDaysText : '-';
      final totalTimesText = totalTimes > 0 ? totalTimes.toString() : '-';
      final totalDaysCalcText = totalTimes > 0
          ? FirebaseService.formatLeaveDayCount(totalDaysCalc)
          : '-';
      final prevDaysText =
          prevTimes > 0 ? FirebaseService.formatLeaveDayCount(prevDays) : '-';
      return '<tr><td>$label</td><td>${prevTimes > 0 ? prevTimes : '-'}</td><td>$prevDaysText</td><td>$currentTimesText</td><td>$currentDaysText</td><td>$totalTimesText</td><td>$totalDaysCalcText</td></tr>';
    }

    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Leave-${fullName}</title>
  <style>
    @page { size: A4; margin: 0; }
    * { box-sizing: border-box; }
    body { margin: 0; background: #475569; font-family: "Sarabun", "TH Sarabun New", Tahoma, Arial, sans-serif; color: #111; }
    .page { width: 794px; min-height: 1123px; margin: 0 auto; padding: 42px 58px; background: white; font-size: 14px; line-height: 1.45; }
    .top { display: grid; grid-template-columns: 165px 1fr 180px; align-items: start; }
    h1 { text-align: center; font-size: 16px; margin: 0; text-decoration: underline; }
    h2 { text-align: center; font-size: 13px; margin: 0; font-weight: 400; }
    .receive { border: 1px solid #111; padding: 10px 12px; font-size: 12px; line-height: 1.8; }
    .school { text-align: center; margin: 18px 0 26px auto; width: 360px; }
    .school strong { font-weight: 700; }
    .row { display: flex; align-items: baseline; gap: 6px; margin: 4px 0; }
    .indent { padding-left: 58px; }
    .line { border-bottom: 1px dotted #aaa; min-height: 20px; padding: 0 8px 1px; text-align: center; font-weight: 600; display: inline-block; white-space: nowrap; }
    .grow { flex: 1; }
    .w40 { width: 40px; } .w60 { width: 60px; } .w80 { width: 80px; } .w130 { width: 130px; } .w150 { width: 150px; }
    .leave-block { display: grid; grid-template-columns: 78px 115px 62px 1fr; align-items: start; margin: 10px 0; }
    .checks { display: grid; gap: 2px; }
    .checkline { display: flex; align-items: center; gap: 7px; height: 22px; }
    .check { width: 14px; height: 14px; border: 1px solid #111; display: inline-flex; align-items: center; justify-content: center; font-size: 13px; line-height: 1; margin-right: 6px; }
    .brace { font-family: "Sarabun", sans-serif; font-size: 140px; line-height: .65; font-weight: 100; color: rgba(0,0,0,0.4); transform: scaleX(0.25); display: inline-block; margin: 0 -35px; }
    .center { text-align: center; }
    .bottom { display: grid; grid-template-columns: 1fr 1.04fr; gap: 46px; margin-top: 28px; align-items: end; }
    .stats-title { text-align: center; font-weight: 700; font-size: 12px; margin-bottom: 8px; }
    table { width: 100%; border-collapse: collapse; }
    th, td { border: 1px solid #333; padding: 4px 5px; text-align: center; font-size: 11px; line-height: 1.25; }
    .signature { text-align: center; margin-top: 14px; line-height: 1.35; }
    .comment { margin-top: 26px; font-size: 12px; font-weight: 700; }
    .order { display: flex; align-items: center; justify-content: center; gap: 12px; margin-top: 22px; }
    .toolbar { position: fixed; right: 16px; top: 16px; }
    .toolbar button { padding: 8px 12px; border: 0; background: #0f172a; color: white; border-radius: 6px; cursor: pointer; }
    .reason-section { display: grid; grid-template-columns: max-content minmax(0, 1fr); column-gap: 6px; align-items: start; margin: 0 0 4px; min-width: 0; }
    .reason-label { grid-column: 1; white-space: nowrap; }
    .reason-text { grid-column: 2; min-width: 0; white-space: pre-wrap; overflow-wrap: anywhere; word-break: break-word; }
    .reason-underline { grid-column: 2; border-bottom: 1px dotted #aaa; margin-top: 4px; }
    @media print { body { background: white; } .toolbar { display: none; } .page { width: 210mm; min-height: 297mm; margin: 0; box-shadow: none; } }
  </style>
</head>
<body>
  <div class="toolbar"><button onclick="window.print()">พิมพ์ / บันทึก PDF</button></div>
  <main class="page">
    <section class="top">
      <div></div>
      <div><h1>แบบใบลา</h1><h2>ลาป่วย/ลากิจ/ลาคลอดบุตร</h2></div>
      <div class="receive">รับที่ ............................<br>วันที่ ............................<br>เวลา ..............................</div>
    </section>

    <section class="school">
      <strong>โรงเรียนรมย์บุรีพิทยาคม รัชมังคลาภิเษก</strong><br>
      อำเภอบ้านด่าน จังหวัดบุรีรัมย์ 31000<br><br>
      วันที่ ${requestDate}
    </section>

    <div class="row"><strong>เรื่อง</strong><span class="line grow">ขอ${leaveType}</span></div>
    <div class="row">เรียน ผู้อำนวยการโรงเรียนรมย์บุรีพิทยาคม รัชมังคลาภิเษก</div>
    <div class="row indent"><span>ข้าพเจ้า</span><span class="line grow">${fullName}</span><span>ตำแหน่ง</span><span class="line grow">${position}</span><span style="white-space: nowrap;">โรงเรียนรมย์บุรีพิทยาคม</span></div>
    <div class="row">รัชมังคลาภิเษก สังกัดสำนักงานเขตพื้นที่การศึกษามัธยมศึกษาบุรีรัมย์ กระทรวงศึกษาธิการ</div>

    <section class="leave-block">
      <strong>ขอลา</strong>
      <div class="checks">
        <div class="checkline">${checkbox('ป่วย', leaveTypeRaw.contains('ป่วย'))}</div>
        <div class="checkline">${checkbox('ลากิจส่วนตัว', leaveTypeRaw.contains('กิจ'))}</div>
        <div class="checkline">${checkbox('ลาคลอดบุตร', leaveTypeRaw.contains('คลอด'))}</div>
        <div class="checkline">${checkbox('ลาพักผ่อน', leaveTypeRaw.contains('พัก'))}</div>
      </div>
      <div class="brace">}</div>
      <div class="reason-section" style="padding-top: 34px;">
        <span class="reason-label">เนื่องจาก</span>
        <div class="reason-text">${reason}</div>
        <div class="reason-underline"></div>
      </div>
    </section>

    <div class="row"><span>ตั้งแต่วันที่</span><span class="line w150">${startDate}</span><span>ถึงวันที่</span><span class="line w150">${endDate}</span><span>มีกำหนด</span><span class="line w60">${totalDaysText}</span><span>วัน</span></div>
    <div class="row"><span>ข้าพเจ้าได้ลา</span><span>${checkbox('ป่วย', false)}</span><span>${checkbox('ลากิจส่วนตัว', false)}</span><span>${checkbox('ลาคลอดบุตร', false)}</span><span>ครั้งสุดท้ายตั้งแต่วันที่</span><span class="line w130"></span></div>
    <div class="row"><span>ถึงวันที่</span><span class="line w130"></span><span>มีกำหนด</span><span class="line w60"></span><span>วัน ในระหว่างที่ลาติดต่อข้าพเจ้าได้ที่</span><span class="line grow">${phone}</span></div>

    <p class="center" style="margin: 22px 0 0;">จึงเรียนมาเพื่อโปรดพิจารณา</p>

    <section class="bottom">
      <div>
        <div class="stats-title">สถิติวันลาในปีงบประมาณนี้</div>
        <table>
          <thead>
            <tr><th rowspan="2">ประเภทการลา</th><th colspan="2">ลามาแล้ว</th><th colspan="2">ลาครั้งนี้</th><th colspan="2">รวมเป็น</th></tr>
            <tr><th>ครั้ง</th><th>วัน</th><th>ครั้ง</th><th>วัน</th><th>ครั้ง</th><th>วัน</th></tr>
          </thead>
          <tbody>${statRow('ป่วย', 'ป่วย')}${statRow('ลากิจส่วนตัว', 'กิจ')}${statRow('ลาคลอดบุตร', 'คลอด')}</tbody>
        </table>
        <div class="signature">ลงชื่อ ..................................................<br>${hrName}<br>หัวหน้ากลุ่มบริหารงานบุคคล<br>........../........../..........</div>
      </div>
      <div>
        <div class="signature" style="margin-top:0;">ขอแสดงความนับถือ<br><br>ลงชื่อ ..................................................<br>( ${fullName} )<br>ตำแหน่ง ${applicantPosition}</div>
        <div class="comment">ความคิดเห็น</div><div class="line grow" style="width:100%; margin-top:4px;"></div>
        <div class="signature">ลงชื่อ ..................................................<br>${deputyName}<br>รองผู้อำนวยการกลุ่มบริหารงานบุคคล<br>........../........../..........</div>
        <div class="order"><strong>คำสั่ง</strong><span>${checkbox('อนุญาต', false)}</span><span>${checkbox('ไม่อนุญาต', false)}</span></div>
        <div class="signature">ลงชื่อ ..................................................<br>${directorName}<br>ผู้อำนวยการโรงเรียนรมย์บุรีพิทยาคม รัชมังคลาภิเษก<br>........../........../..........</div>
      </div>
    </section>
  </main>
${autoPrint ? '''
<script>
  window.addEventListener('load', function() {
    setTimeout(function() {
      window.focus();
      window.print();
    }, 350);
  });
</script>
''' : ''}
</body>
</html>
''';
  }

  void _openPrintWindow({required bool autoPrint}) {
    final blob = html.Blob(
      [_previewLikePrintableHtml(autoPrint: autoPrint)],
      'text/html;charset=utf-8',
    );
    final url = html.Url.createObjectUrlFromBlob(blob);
    final dynamic popup = html.window.open(url, '_blank');
    if (popup == null) {
      html.Url.revokeObjectUrl(url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('เบราว์เซอร์บล็อกหน้าต่างพิมพ์ กรุณาอนุญาต pop-up')),
      );
      return;
    }

    Future.delayed(
        const Duration(seconds: 20), () => html.Url.revokeObjectUrl(url));
  }

  DateTime? _getDateTime(dynamic dt) {
    if (dt == null) return null;
    if (dt is Timestamp) return dt.toDate();
    if (dt is String && dt.contains('/')) {
      try {
        final parts = dt.split('/');
        return DateTime(int.parse(parts[2]) - 543, int.parse(parts[1]),
            int.parse(parts[0]));
      } catch (e) {}
    }
    return null;
  }

  String _getDay(dynamic dtValue) {
    final dt = _getDateTime(dtValue);
    if (dt == null) return '....................';
    return dt.day.toString();
  }

  String _getMonth(dynamic dtValue) {
    final dt = _getDateTime(dtValue);
    if (dt == null) return '....................';
    const months = [
      "มกราคม",
      "กุมภาพันธ์",
      "มีนาคม",
      "เมษายน",
      "พฤษภาคม",
      "มิถุนายน",
      "กรกฎาคม",
      "สิงหาคม",
      "กันยายน",
      "ตุลาคม",
      "พฤศจิกายน",
      "ธันวาคม"
    ];
    return months[dt.month - 1];
  }

  String _getYear(dynamic dtValue) {
    final dt = _getDateTime(dtValue);
    if (dt == null) return '....................';
    return (dt.year + 543).toString();
  }

  String _getManagerName(String adminTitle) {
    if (widget.allUsers.isEmpty) return "(................................)";
    final manager = widget.allUsers.firstWhere(
        (u) => (u['ตำแหน่งงานบริหาร']?.toString() == adminTitle),
        orElse: () => {});
    return manager.isNotEmpty
        ? "(${manager['fullName'] ?? '................................'})"
        : "(................................)";
  }

  @override
  Widget build(BuildContext context) {
    final leaf = widget.leaf;
    final num totalDays =
        double.tryParse(leaf['totalDays']?.toString() ?? '1') ?? 1;
    final totalDaysText = FirebaseService.formatLeaveDayCount(totalDays);

    return Scaffold(
      backgroundColor: const Color(0xFF475569),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1E293B),
        title: Text('ตัวอย่างใบลา - ${leaf['fullName']}',
            style: GoogleFonts.sarabun(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'พิมพ์เอกสาร',
            onPressed: () => _openPrintWindow(autoPrint: true),
            icon: const Icon(Icons.print, color: Colors.white),
          ),
          IconButton(
            tooltip: 'บันทึกเป็น PDF',
            onPressed: () => _openPrintWindow(autoPrint: true),
            icon: const Icon(Icons.download, color: Colors.white),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Container(
            width: 794,
            constraints: const BoxConstraints(minHeight: 1123),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 40,
                    offset: const Offset(0, 20))
              ],
            ),
            padding: const EdgeInsets.all(60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Registration box
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 180),
                    Expanded(
                      child: Column(
                        children: [
                          Text("แบบใบลา",
                              style: GoogleFonts.sarabun(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline)),
                          Text("ลาป่วย/ลากิจ/ลาคลอดบุตร",
                              style: GoogleFonts.sarabun(fontSize: 14)),
                        ],
                      ),
                    ),
                    Container(
                      width: 180,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(border: Border.all(width: 0.8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPerfectDottedLabel("รับที่"),
                          const SizedBox(height: 6),
                          _buildPerfectDottedLabel("วันที่"),
                          const SizedBox(height: 6),
                          _buildPerfectDottedLabel("เวลา"),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text("โรงเรียนรมย์บุรีพิทยาคม รัชมังคลาภิเษก",
                          style: docBaseStyle.copyWith(
                              fontWeight: FontWeight.bold)),
                      Text("อำเภอบ้านด่าน จังหวัดบุรีรัมย์ 31000",
                          style: docBaseStyle),
                      const SizedBox(height: 20),
                      Text(
                          "วันที่  ${_getDay(leaf['timestamp'])}  เดือน  ${_getMonth(leaf['timestamp'])}  พ.ศ.  ${_getYear(leaf['timestamp'])}",
                          style: docBaseStyle),
                    ],
                  ),
                ),
                const SizedBox(height: 35),
                _buildPerfectFullWidthRow([
                  Text("เรื่อง ",
                      style:
                          docBaseStyle.copyWith(fontWeight: FontWeight.bold)),
                  _buildPerfectDottedLine(
                      value: leaf['leaveType'] == '---เลือก---'
                          ? ''
                          : "ขอ${leaf['leaveType']}")
                ]),
                Text("เรียน ผู้อำนวยการโรงเรียนรมย์บุรีพิทยาคม รัชมังคลาภิเษก",
                    style: docBaseStyle),
                const SizedBox(height: 18),
                _buildPerfectFullWidthRow([
                  const SizedBox(width: 60),
                  Text("ข้าพเจ้า", style: docBaseStyle),
                  _buildPerfectDottedLine(
                      value: (leaf['fullName'] ?? '').toString(), flex: 8),
                  Text("ตำแหน่ง", style: docBaseStyle),
                  Builder(builder: (context) {
                    String pos = _leafPosition();
                    if (_isBlankChoice(pos)) pos = '';

                    String rank = _leafAcademicStanding();
                    if (_isBlankChoice(rank)) rank = '';

                    String combined = pos;
                    if (rank.isNotEmpty) combined += " $rank";

                    return _buildPerfectDottedLine(value: combined, flex: 5);
                  }),
                  Text("โรงเรียนรมย์บุรีพิทยาคม", style: docBaseStyle),
                ]),
                Text(
                    "รัชมังคลาภิเษก สังกัดสำนักงานเขตพื้นที่การศึกษามัธยมศึกษาบุรีรัมย์ กระทรวงศึกษาธิการ",
                    style: docBaseStyle),
                const SizedBox(height: 18),

                // Leave Type Section with Styled Curly Bracket
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 80,
                        child: Text("ขอลา",
                            style: docBaseStyle.copyWith(
                                fontWeight: FontWeight.bold))),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        "ป่วย",
                        "ลากิจส่วนตัว",
                        "ลาคลอดบุตร",
                        "ลาพักผ่อน"
                      ].map((t) {
                        bool isChecked = (leaf['leaveType'] ?? '')
                            .toString()
                            .contains(t.replaceAll('ลา', ''));
                        return _buildPerfectCheckBox(t, isChecked);
                      }).toList(),
                    ),
                    const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 15),
                        child: Text("}",
                            style: TextStyle(
                                fontSize: 100,
                                fontWeight: FontWeight.w100,
                                height: 1.1,
                                fontFamily: 'serif'))),
                    Expanded(
                        child: Column(children: [
                      const SizedBox(height: 35),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("เนื่องจาก", style: docBaseStyle),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              leaf['reason']?.toString() ?? '',
                              style: docBaseStyle,
                              softWrap: true,
                              maxLines: null,
                              overflow: TextOverflow.visible,
                              textWidthBasis: TextWidthBasis.parent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _buildPerfectDottedLine(width: double.infinity, flex: 0)
                    ]))
                  ],
                ),
                const SizedBox(height: 18),

                _buildPerfectFullWidthRow([
                  Text("ตั้งแต่วันที่", style: docBaseStyle),
                  _buildPerfectDottedLine(
                      value: FirebaseService.formatThaiDate(leaf['startDate'])),
                  Text("ถึงวันที่", style: docBaseStyle),
                  _buildPerfectDottedLine(
                      value: FirebaseService.formatThaiDate(leaf['endDate'])),
                  Text("มีกำหนด", style: docBaseStyle),
                  _buildPerfectDottedLine(
                      flex: 0, width: 60, value: totalDaysText),
                  Text("วัน", style: docBaseStyle),
                ]),
                _buildPerfectFullWidthRow([
                  Text("ข้าพเจ้าได้ลา", style: docBaseStyle),
                  _buildPerfectCheckBox("ป่วย", false),
                  _buildPerfectCheckBox("ลากิจส่วนตัว", false),
                  _buildPerfectCheckBox("ลาคลอดบุตร", false),
                  Text("ครั้งสุดท้ายตั้งแต่วันที่", style: docBaseStyle),
                  _buildPerfectDottedLine(value: "", flex: 1),
                  Text("ถึงวันที่", style: docBaseStyle),
                  _buildPerfectDottedLine(value: "", flex: 1),
                ]),
                _buildPerfectFullWidthRow([
                  Text("มีกำหนด", style: docBaseStyle),
                  _buildPerfectDottedLine(flex: 0, width: 40, value: ""),
                  Text("วัน ในระหว่างที่ลาติดต่อข้าพเจ้าได้ที่",
                      style: docBaseStyle),
                  _buildPerfectDottedLine(
                      flex: 4, value: leaf['phone']?.toString() ?? ""),
                ]),
                const SizedBox(height: 25),
                Center(
                    child: Text("จึงเรียนมาเพื่อโปรดพิจารณา",
                        style: docBaseStyle)),

                const SizedBox(height: 40),

                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // LEFT SIDE: Statistics & HR Approval
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Spacer(),
                            Text("สถิติวันลาในปีงบประมาณนี้",
                                style: GoogleFonts.sarabun(
                                    fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Table(
                              border: TableBorder.all(width: 0.6),
                              columnWidths: const {
                                0: FlexColumnWidth(1.2),
                                1: FlexColumnWidth(1.0),
                                2: FlexColumnWidth(1.0),
                                3: FlexColumnWidth(1.0),
                              },
                              children: [
                                TableRow(children: [
                                  _PdfCell("ประเภท\nการลา",
                                      bold: true, size: 10, height: 60),
                                  _PdfCell("ลามาแล้ว\nครั้ง/วัน\n(วันทำการ)",
                                      bold: true, size: 10, height: 60),
                                  _PdfCell("ลาครั้งนี้\nครั้ง/วัน\n(วันทำการ)",
                                      bold: true, size: 10, height: 60),
                                  _PdfCell("รวมเป็น\nครั้ง/วัน\n(วันทำการ)",
                                      bold: true, size: 10, height: 60),
                                ]),
                                _buildPerfectTableRow("ป่วย", totalDays, leaf),
                                _buildPerfectTableRow(
                                    "ลากิจส่วนตัว", totalDays, leaf),
                                _buildPerfectTableRow(
                                    "ลาคลอดบุตร", totalDays, leaf),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                                "ลงชื่อ ..................................................",
                                style: docBaseStyle),
                            Text(_getManagerName("หัวหน้ากลุ่มบริหารงานบุคคล"),
                                style: docBaseStyle.copyWith(
                                    fontWeight: FontWeight.bold)),
                            Text("หัวหน้ากลุ่มบริหารงานบุคคล",
                                style: docBaseStyle),
                            Text("........../........../..........",
                                style: docBaseStyle),
                          ],
                        ),
                      ),

                      const SizedBox(width: 45),

                      // RIGHT SIDE: Applicant Sign & Executive Approval
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text("ขอแสดงความนับถือ", style: docBaseStyle),
                            const SizedBox(height: 15),
                            Text(
                                "ลงชื่อ ..................................................",
                                style: docBaseStyle),
                            Text(
                                "(${leaf['fullName'] ?? '................................'})",
                                style: GoogleFonts.sarabun(
                                    fontSize: 14, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                                "ตำแหน่ง ${_leafPosition().isEmpty ? '................................' : _leafPosition()}",
                                style: docBaseStyle),
                            const SizedBox(height: 35),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("ความคิดเห็น",
                                    style: GoogleFonts.sarabun(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(
                                    "................................................................................",
                                    style: GoogleFonts.sarabun(
                                        color: Colors.black26,
                                        fontSize: 13,
                                        letterSpacing: 1)),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                                "ลงชื่อ ..................................................",
                                style: docBaseStyle),
                            Text(
                                _getManagerName(
                                    "รองผู้อำนวยการกลุ่มบริหารงานบุคคล"),
                                style: docBaseStyle.copyWith(
                                    fontWeight: FontWeight.bold)),
                            Text("รองผู้อำนวยการกลุ่มบริหารงานบุคคล",
                                style: docBaseStyle),
                            Text("........../........../..........",
                                style: docBaseStyle),
                            const SizedBox(height: 30),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("คำสั่ง",
                                    style: GoogleFonts.sarabun(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(width: 15),
                                _buildPerfectCheckBox("อนุญาต", false),
                                _buildPerfectCheckBox("ไม่อนุญาต", false),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Text(
                                "ลงชื่อ ..................................................",
                                style: docBaseStyle),
                            Text(_getManagerName("ผู้อำนวยการโรงเรียน"),
                                style: docBaseStyle.copyWith(
                                    fontWeight: FontWeight.bold)),
                            Text(
                                "ผู้อำนวยการโรงเรียนรมย์บุรีพิทยาคม รัชมังคลาภิเษก",
                                style: docBaseStyle,
                                textAlign: TextAlign.center),
                            Text("........../........../..........",
                                style: docBaseStyle),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPerfectDottedLabel(String label) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text("$label .............................",
            style: GoogleFonts.sarabun(
                fontSize: 12, color: Colors.blueGrey.shade800)));
  }

  Widget _buildPerfectFullWidthRow(List<Widget> children) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: children),
      );

  Widget _buildPerfectDottedLine({int flex = 1, double? width, String? value}) {
    final widget = Container(
      width: width,
      height: 32, // เพิ่มความสูงเพื่อยกระดับตัวอักษร
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 2), // ขยับจุดลงล่างสุด
            child: Text(
                "......................................................................................................................................",
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: GoogleFonts.sarabun(
                    color: Colors.black26, fontSize: 18, letterSpacing: 2)),
          ),
          if (value != null && value.isNotEmpty)
            Positioned(
                bottom: 10, // ยกระดับข้อความให้อยู่เหนือจุดไข่ปลา
                child: Text(value,
                    style: GoogleFonts.sarabun(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A)))),
        ],
      ),
    );
    return flex > 0 ? Expanded(flex: flex, child: widget) : widget;
  }

  Widget _buildPerfectCheckBox(String label, bool isChecked) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4, right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                  border: Border.all(width: 1, color: Colors.black)),
              child: isChecked
                  ? const Icon(Icons.check,
                      size: 14, color: Colors.black, weight: 800)
                  : null),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.sarabun(fontSize: 14)),
        ],
      ),
    );
  }

  TableRow _buildPerfectTableRow(
      String label, num currentDays, Map<String, dynamic> currentLeaf) {
    final String fullName = currentLeaf['fullName'] ?? '';
    final String currentYear = currentLeaf['year']?.toString() ?? '';
    final relevantHistory = widget.allLeaveRequests.where((req) {
      final String reqName = req['fullName'] ?? '';
      final String reqType = (req['leaveType'] ?? "").toString();
      final String reqYear = (req['year'] ?? "").toString();
      bool typeMatch = false;
      if (label == "ป่วย") typeMatch = reqType.contains("ป่วย");
      if (label == "ลากิจส่วนตัว") typeMatch = reqType.contains("กิจ");
      if (label == "ลาคลอดบุตร") typeMatch = reqType.contains("คลอด");
      return reqName == fullName &&
          typeMatch &&
          reqYear == currentYear &&
          req['requestId'] != currentLeaf['requestId'];
    }).toList();

    int prevTimes = relevantHistory.length;
    double prevDays = relevantHistory.fold<double>(
        0,
        (sum, req) =>
            sum + (double.tryParse(req['totalDays']?.toString() ?? '0') ?? 0));

    bool isCurrentMatch = (currentLeaf['leaveType'] ?? '')
        .toString()
        .contains(label.replaceAll('ลา', ''));

    int totalTimes = prevTimes + (isCurrentMatch ? 1 : 0);
    double totalDaysCalc =
        prevDays + (isCurrentMatch ? currentDays.toDouble() : 0);
    String prevTimesText = prevTimes > 0 ? prevTimes.toString() : "-";
    String prevDaysText =
        prevTimes > 0 ? FirebaseService.formatLeaveDayCount(prevDays) : "-";
    String currentTimesText = isCurrentMatch ? "1" : "-";
    String currentDaysText =
        isCurrentMatch ? FirebaseService.formatLeaveDayCount(currentDays) : "-";
    String totalTimesText = totalTimes > 0 ? totalTimes.toString() : "-";
    String totalDaysText = totalTimes > 0
        ? FirebaseService.formatLeaveDayCount(totalDaysCalc)
        : "-";

    return TableRow(children: [
      _PdfCell(label, size: 10),
      _PdfSplitCell(prevTimesText, prevDaysText),
      _PdfSplitCell(currentTimesText, currentDaysText),
      _PdfSplitCell(totalTimesText, totalDaysText)
    ]);
  }

  Widget _PdfSplitCell(String left, String right) {
    return Container(
      height: 25,
      child: Row(
        children: [
          Expanded(
              child: Center(
                  child: Text(left, style: GoogleFonts.sarabun(fontSize: 10)))),
          Container(width: 0.6, color: Colors.black),
          Expanded(
              child: Center(
                  child:
                      Text(right, style: GoogleFonts.sarabun(fontSize: 10)))),
        ],
      ),
    );
  }
}

class _PdfCell extends StatelessWidget {
  final String text;
  final bool bold;
  final double size;
  final double? height;
  const _PdfCell(this.text, {this.bold = false, this.size = 12, this.height});
  @override
  Widget build(BuildContext context) => Container(
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4.0),
      child: Text(text,
          textAlign: TextAlign.center,
          style: GoogleFonts.sarabun(
              fontSize: size,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal)));
}
