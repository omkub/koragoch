import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'leave_form_screen.dart';
import '../utils/profile_image.dart';
import '../widgets/leave_form_page.dart';

class LeaveHistoryScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onEdit;
  const LeaveHistoryScreen({super.key, this.onEdit});

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends State<LeaveHistoryScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allUsers = [];
  final Map<String, Map<String, dynamic>> _usersByName = {};
  List<String> _leaveTypeNames = [];
  List<Map<String, dynamic>> _allLeaveRequests = [];
  Stream<List<Map<String, dynamic>>>? _leaveRequestsStream;

  // Track selected IDs for bulk deletion 🧹✨🥇
  final Set<String> _selectedIds = {};
  bool _isDeletingBulk = false;
  List<Map<String, dynamic>> _latestLeaves =
      []; // 📋 cache รายการล่าสุดจาก stream ครับ
  String? _userRole;
  String? _currentUser;
  bool _canViewAll = false;
  String _selectedDepartmentFilter = 'ทั้งหมด';
  String _selectedAcademicFilter = 'ทั้งหมด';
  String _selectedPositionFilter = 'ทั้งหมด';
  String _selectedRoleFilter = 'ทั้งหมด';

  // 📅 ระบบจัดการรอบงบประมาณ 🥇🏆
  List<Map<String, dynamic>> _rounds = [];
  Map<String, dynamic>? _selectedRound;
  bool _isRoundsLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNecessaryData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchNecessaryData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('userRole');
      final user = prefs.getString('currentUser');
      final canViewAll = await _firebaseService.currentUserHasAdminRole();

      // โหลดทุกอย่างพร้อมกัน
      final futureLeaves = canViewAll
          ? _firebaseService.getLeaveRequestsFromSupabase()
          : _firebaseService.getMyLeaveRequestsFromSupabase(user ?? '');
      final futureRounds = _firebaseService.getFiscalRoundsFromSupabase();
      final futureActive = _firebaseService.getActiveFiscalRoundFromSupabase();

      final results =
          await Future.wait([futureLeaves, futureRounds, futureActive]);
      final leaveList = results[0] as List<Map<String, dynamic>>;
      final roundsSnap = results[1] as List<Map<String, dynamic>>;
      final activeRound = results[2] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _userRole = role;
          _currentUser = user;
          _canViewAll = canViewAll;
          _leaveRequestsStream = Stream.value(leaveList);
          _allUsers = [];
        });
      }

      // โหลด users แบบ background (ใช้สำหรับ filter/lookup ไม่บล็อค UI)
      _firebaseService.getUsersFromSupabase().then((users) {
        if (!mounted) return;
        setState(() {
          _allUsers = users;
          _usersByName.clear();
          for (final user in users) {
            final name =
                (user['fullName'] ?? user['name'] ?? '').toString().trim();
            if (name.isNotEmpty) _usersByName.putIfAbsent(name, () => user);
          }
        });
      });

      // ประเภทการลาใช้เป็นช่องติ๊กในแบบฟอร์มพิมพ์
      _firebaseService.getLeaveTypes().then((types) {
        if (mounted) setState(() => _leaveTypeNames = types);
      });

      if (mounted) {
        setState(() {
          _rounds = roundsSnap;

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

  Stream<List<Map<String, dynamic>>> _createLeaveRequestsStream(
      bool canViewAll, String? user) {
    // 🚀 ใช้ Supabase read แล้วห่อเป็น Stream ชั่วคราว (Part 5 ค่อยทำ Realtime)
    return canViewAll
        ? Stream.fromFuture(_firebaseService.getLeaveRequestsFromSupabase())
        : Stream.fromFuture(
            _firebaseService.getMyLeaveRequestsFromSupabase(user ?? ''));
  }

  Map<String, dynamic> _userForLeave(Map<String, dynamic> leave) {
    final name = (leave['fullName'] ?? leave['name'] ?? '').toString().trim();
    if (name.isEmpty) return const <String, dynamic>{};
    return _usersByName[name] ?? const <String, dynamic>{};
  }

  String _firstTextValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value != '-') return value;
    }
    return '';
  }

  String _departmentFor(Map<String, dynamic> data) => _firstTextValue(data, [
        'department',
        'departmentName',
        'academic',
        'academicGroup',
        'group',
        'groupName',
        'กลุ่มสาระ',
        'กลุ่มงาน',
      ]);

  String _positionFor(Map<String, dynamic> data) => _firstTextValue(data, [
        'position',
        'positionName',
        'ตำแหน่ง',
      ]);

  String _academicFor(Map<String, dynamic> data) => _firstTextValue(data, [
        'academicStanding',
        'academicstanding',
        'วิทยฐานะ',
      ]);

  String _roleFor(Map<String, dynamic> data) => _firstTextValue(data, [
        'permission',
        'role',
        'สิทธิ์',
      ]);

  List<String> _uniqueFilterOptions(
      String Function(Map<String, dynamic>) pick) {
    final values = _allUsers
        .map(pick)
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['ทั้งหมด', ...values];
  }

  List<Map<String, dynamic>> _applyHistoryFilters(
      List<Map<String, dynamic>> leaves) {
    final keyword = _searchController.text.trim().toLowerCase();

    return leaves.where((leave) {
      final user = _userForLeave(leave);
      final merged = {...user, ...leave};
      final department = _departmentFor(merged);
      final position = _positionFor(merged);
      final academic = _academicFor(merged);
      final role = _roleFor(merged);

      final departmentMatch = _selectedDepartmentFilter == 'ทั้งหมด' ||
          department == _selectedDepartmentFilter;
      final positionMatch = _selectedPositionFilter == 'ทั้งหมด' ||
          position == _selectedPositionFilter;
      final academicMatch = _selectedAcademicFilter == 'ทั้งหมด' ||
          academic == _selectedAcademicFilter;
      final roleMatch =
          _selectedRoleFilter == 'ทั้งหมด' || role == _selectedRoleFilter;

      final searchText = [
        leave['fullName'],
        leave['name'],
        leave['leaveType'],
        leave['reason'],
        leave['status'],
        leave['year'],
        leave['receiveNumber'],
        leave['receiveDate'],
        leave['receiveTime'],
        department,
        position,
      ].map((v) => v?.toString().toLowerCase() ?? '').join(' ');

      return departmentMatch &&
          positionMatch &&
          academicMatch &&
          roleMatch &&
          (keyword.isEmpty || searchText.contains(keyword));
    }).toList();
  }

  /// มีตัวกรองใดถูกใช้อยู่ไหม (ใช้ตัดสินว่าจะโชว์ปุ่มล้างตัวกรองหรือไม่)
  bool get _hasActiveHistoryFilters =>
      _selectedDepartmentFilter != 'ทั้งหมด' ||
      _selectedPositionFilter != 'ทั้งหมด' ||
      _selectedAcademicFilter != 'ทั้งหมด' ||
      _selectedRoleFilter != 'ทั้งหมด' ||
      _searchController.text.trim().isNotEmpty;

  void _clearHistoryFilters() {
    setState(() {
      _selectedDepartmentFilter = 'ทั้งหมด';
      _selectedPositionFilter = 'ทั้งหมด';
      _selectedAcademicFilter = 'ทั้งหมด';
      _selectedRoleFilter = 'ทั้งหมด';
      _searchController.clear();
      _selectedIds.clear();
    });
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
            // แถบหัวเรื่องถูกตัดออกแล้ว ปุ่มรีเฟรชย้ายไปอยู่ท้ายแถบตัวกรอง

            // 🗑️ แถบแจ้งเตือนการเลือกด้านบนถูกตัดออกแล้ว
            // ใช้ปุ่มลอย "ลบ N รายการ" มุมขวาล่างปุ่มเดียวพอครับ

            // จอกว้าง: ตารางยืดเต็มพื้นที่จริงที่เหลือ (ไม่อิงความกว้างจอ
            // ซึ่งรวมแถบเมนูซ้ายไปด้วย จนเกิดที่ว่างด้านขวา)
            // จอแคบ: คงความกว้างขั้นต่ำ 1200 แล้วเลื่อนแนวนอนเหมือนเดิม
            LayoutBuilder(
              builder: (context, tableConstraints) {
                final tableContent = StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _leaveRequestsStream,
                  initialData:
                      _allLeaveRequests.isNotEmpty ? _allLeaveRequests : null,
                  builder: (context, snapshot) {
                    if (_isRoundsLoading ||
                        snapshot.connectionState == ConnectionState.waiting) {
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
                    _allLeaveRequests = allLeaves;
                    // 🕵️‍♂️ กรองข้อมูลตามรอบงบประมาณที่เลือกครับ 🥇🏆🏎️
                    final roundLeaves = _selectedRound == null
                        ? allLeaves
                        : allLeaves
                            .where((l) => FirebaseService.isDateInRange(
                                l['startDate']?.toString() ?? '',
                                _selectedRound!['startDate'] ?? '',
                                _selectedRound!['endDate'] ?? ''))
                            .toList();
                    final leaves = _applyHistoryFilters(roundLeaves);
                    _latestLeaves = leaves; // 📋 อัพเดต cache ครับ
                    return Column(
                      children: [
                        _buildHistoryFilters(),
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
                              _buildHeaderLabel('ชื่อ'),
                              _buildHeaderLabel('ประเภทลา'),
                              _buildHeaderLabel('เริ่ม'),
                              _buildHeaderLabel('สิ้นสุด'),
                              _buildHeaderLabel('เหตุผล'),
                              _buildHeaderLabel('สถานะ'),
                              _buildHeaderLabel('ปีงบ',
                                  align: TextAlign.center),
                              _buildHeaderLabel('จำนวนวัน',
                                  align: TextAlign.center),
                              _buildHeaderLabel('รับที่',
                                  align: TextAlign.center),
                              _buildHeaderLabel('วันที่รับ',
                                  align: TextAlign.center),
                              _buildHeaderLabel('เวลารับ',
                                  align: TextAlign.center),
                              _buildHeaderLabel('ใบรับรองแพทย์/ใบนัด',
                                  align: TextAlign.center),
                              SizedBox(
                                width: 50,
                                child: Text('จัดการ',
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.sarabun(
                                        fontSize: 12,
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5))
                              ]),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: leaves.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 36),
                                    child: Center(
                                      child: Text(
                                        'ไม่พบรายการที่ตรงกับตัวกรอง',
                                        style: GoogleFonts.sarabun(
                                            fontSize: 14,
                                            color: const Color(0xFF64748B),
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  )
                                : SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.65,
                                    child: ListView.separated(
                                      primary: false,
                                      itemCount: leaves.length,
                                      separatorBuilder: (ctx, i) =>
                                          const Divider(
                                              height: 1,
                                              color: Color(0xFFF1F5F9)),
                                      itemBuilder: (ctx, i) =>
                                          _buildHistoryRow(leaves[i]),
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    );
                  },
                );

                if (tableConstraints.maxWidth >= 1000) return tableContent;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(width: 1200, child: tableContent),
                );
              },
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

  // 📅 Dropdown เลือกปีงบประมาณ — หน้าตาเดียวกับช่องกรองอื่นในแถวเดียวกัน 🥇🏆
  Widget _buildRoundFilterField() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_rounded,
              size: 18, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Map<String, dynamic>>(
                value: _selectedRound,
                isExpanded: true,
                hint: Text('เลือกปีงบประมาณ',
                    style: GoogleFonts.sarabun(
                        fontSize: 13, color: const Color(0xFF94A3B8))),
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF64748B)),
                style: GoogleFonts.sarabun(fontSize: 13, color: Colors.black87),
                borderRadius: BorderRadius.circular(10),
                items: _rounds
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(
                              "ปีงบ ${r['year']} - รอบที่ ${r['round']}",
                              overflow: TextOverflow.ellipsis),
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
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryFilters() {
    final departmentOptions = _uniqueFilterOptions(_departmentFor);
    final positionOptions = _uniqueFilterOptions(_positionFor);
    final academicOptions = _uniqueFilterOptions(_academicFor);
    final roleOptions = _uniqueFilterOptions(_roleFor);
    final departmentValue =
        departmentOptions.contains(_selectedDepartmentFilter)
            ? _selectedDepartmentFilter
            : 'ทั้งหมด';
    final positionValue = positionOptions.contains(_selectedPositionFilter)
        ? _selectedPositionFilter
        : 'ทั้งหมด';
    final academicValue = academicOptions.contains(_selectedAcademicFilter)
        ? _selectedAcademicFilter
        : 'ทั้งหมด';
    final roleValue = roleOptions.contains(_selectedRoleFilter)
        ? _selectedRoleFilter
        : 'ทั้งหมด';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // ทุกช่องสูง 48 เท่ากันหมด จอกว้างจึงเรียงได้ใน 1 แถว
          // จอแคบกว่านี้ค่อยยุบเป็นตาราง 2 คอลัมน์ให้ยังกดง่ายอยู่
          final isNarrow = constraints.maxWidth < 1180;
          final round = _buildRoundFilterField();
          final department = _buildFilterDropdown(
            label: 'ทุกกลุ่มสาระ/กลุ่มงาน',
            value: departmentValue,
            items: departmentOptions,
            icon: Icons.groups_2_outlined,
            onChanged: (value) => setState(() {
              _selectedDepartmentFilter = value ?? 'ทั้งหมด';
              _selectedIds.clear();
            }),
          );
          final academic = _buildFilterDropdown(
            label: 'ทุกวิทยฐานะ',
            value: academicValue,
            items: academicOptions,
            icon: Icons.workspace_premium_outlined,
            onChanged: (value) => setState(() {
              _selectedAcademicFilter = value ?? 'ทั้งหมด';
              _selectedIds.clear();
            }),
          );
          final position = _buildFilterDropdown(
            label: 'ทุกตำแหน่ง',
            value: positionValue,
            items: positionOptions,
            icon: Icons.badge_outlined,
            onChanged: (value) => setState(() {
              _selectedPositionFilter = value ?? 'ทั้งหมด';
              _selectedIds.clear();
            }),
          );
          final role = _buildFilterDropdown(
            label: 'ทุกสิทธิ์',
            value: roleValue,
            items: roleOptions,
            icon: Icons.verified_user_outlined,
            onChanged: (value) => setState(() {
              _selectedRoleFilter = value ?? 'ทั้งหมด';
              _selectedIds.clear();
            }),
          );
          final search = _buildSearchFilterField();
          final searchButton = SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              // ตัวกรองทำงานทันทีที่เลือก/พิมพ์อยู่แล้ว ปุ่มนี้ใช้ยืนยันการค้นหา
              // (ปิดคีย์บอร์ดแล้วรีเฟรชรายการตามตัวกรองล่าสุด)
              onPressed: () {
                FocusScope.of(context).unfocus();
                setState(() => _selectedIds.clear());
              },
              icon: const Icon(Icons.search_rounded, size: 18),
              label: Text(
                'ค้นหา',
                style: GoogleFonts.sarabun(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          );
          final refreshButton = SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => setState(() {
                _leaveRequestsStream =
                    _createLeaveRequestsStream(_canViewAll, _currentUser);
                _selectedIds.clear();
              }),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(
                'รีเฟรช',
                style: GoogleFonts.sarabun(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          );

          if (isNarrow) {
            // จอแคบ: 2 ช่องต่อแถว แล้วช่องค้นหา+ปุ่มอยู่แถวสุดท้าย
            Widget pair(Widget left, Widget right) => Row(
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 12),
                    Expanded(child: right),
                  ],
                );
            return Column(
              children: [
                pair(round, department),
                const SizedBox(height: 12),
                pair(academic, position),
                const SizedBox(height: 12),
                pair(role, search),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    refreshButton,
                    const SizedBox(width: 10),
                    searchButton,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 26, child: round),
              const SizedBox(width: 10),
              Expanded(flex: 26, child: department),
              const SizedBox(width: 10),
              Expanded(flex: 20, child: academic),
              const SizedBox(width: 10),
              Expanded(flex: 20, child: position),
              const SizedBox(width: 10),
              Expanded(flex: 18, child: role),
              const SizedBox(width: 10),
              Expanded(flex: 30, child: search),
              const SizedBox(width: 10),
              searchButton,
              const SizedBox(width: 10),
              refreshButton,
            ],
          );
        },
      ),
    );
  }

  /// ช่องกรองแบบ dropdown — ไม่มีป้ายชื่อด้านบนแล้ว ทั้งแถบกรองจึงสูงแค่
  /// บรรทัดเดียว โดยใช้ [label] แทนคำว่า "ทั้งหมด" เพื่อให้ยังรู้ว่ากรองอะไรอยู่
  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF64748B)),
                borderRadius: BorderRadius.circular(10),
                style: GoogleFonts.sarabun(fontSize: 13, color: Colors.black87),
                items: items
                    .map((item) => DropdownMenuItem(
                          value: item,
                          child: Text(item == 'ทั้งหมด' ? label : item,
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ช่องค้นหา — ตัดป้าย "ค้นหา" ด้านบนออก ใช้ไอคอนแว่นขยาย + hint แทน
  Widget _buildSearchFilterField() {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() => _selectedIds.clear()),
        style: GoogleFonts.sarabun(fontSize: 13, color: Colors.black87),
        decoration: InputDecoration(
          hintText: 'ค้นหา ชื่อ เหตุผล ประเภทลา สถานะ',
          hintStyle:
              GoogleFonts.sarabun(fontSize: 13, color: const Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded,
              size: 20, color: Color(0xFF64748B)),
          // ปุ่มล้างตัวกรองทั้งหมด โผล่เมื่อมีตัวกรองใดถูกใช้อยู่
          suffixIcon: _hasActiveHistoryFilters
              ? IconButton(
                  tooltip: 'ล้างตัวกรองทั้งหมด',
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: Color(0xFF64748B)),
                  onPressed: _clearHistoryFilters,
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF334155), width: 1.2),
          ),
        ),
      ),
    );
  }

  // สัดส่วนความกว้างของแต่ละคอลัมน์ในตารางประวัติการลา
  // ใช้ flex แทนความกว้างตายตัว ตารางจะยืดเต็มกรอบ body เสมอ
  // ไม่ว่าจอกว้างเท่าไรหรือกำลังย่อ/ขยายมุมมองอยู่ระดับใด
  static const Map<String, int> _historyColumnFlex = {
    'ชื่อ': 24,
    'ประเภทลา': 13,
    'เริ่ม': 13,
    'สิ้นสุด': 13,
    'เหตุผล': 28,
    'สถานะ': 13,
    'ปีงบ': 8,
    'จำนวนวัน': 9,
    'รับที่': 7,
    'วันที่รับ': 12,
    'เวลารับ': 9,
    'ใบรับรองแพทย์/ใบนัด': 11,
  };

  /// ช่องข้อมูลหนึ่งคอลัมน์ - ใช้ร่วมกันทั้งหัวตารางและแถวข้อมูล
  /// เพื่อให้ขอบซ้าย/ขวาของทุกช่องตรงกันเสมอ
  Widget _historyCell(String key, Widget child) {
    return Expanded(
      flex: _historyColumnFlex[key] ?? 10,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: child,
      ),
    );
  }

  Widget _buildHeaderLabel(String text, {TextAlign align = TextAlign.left}) {
    return _historyCell(
        text,
        Text(text,
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
          _historyCell(
              'ชื่อ',
              Text(name,
                  style: GoogleFonts.sarabun(
                      fontSize: 13,
                      color: Colors.black,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal),
                  overflow: TextOverflow.ellipsis)),
          _historyCell(
              'ประเภทลา',
              Text(type,
                  style: GoogleFonts.sarabun(
                      fontSize: 13,
                      color: isSelected ? Colors.black : Colors.black87))),
          _historyCell(
              'เริ่ม',
              Text(FirebaseService.formatThaiDate(leaf['startDate']),
                  style:
                      GoogleFonts.sarabun(fontSize: 13, color: Colors.black))),
          _historyCell(
              'สิ้นสุด',
              Text(FirebaseService.formatThaiDate(leaf['endDate']),
                  style:
                      GoogleFonts.sarabun(fontSize: 13, color: Colors.black))),
          _historyCell(
              'เหตุผล',
              Text(leaf['reason'] ?? '-',
                  style: GoogleFonts.sarabun(fontSize: 13, color: Colors.black),
                  overflow: TextOverflow.ellipsis)),
          _historyCell(
            'สถานะ',
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: (status == 'ส่งใบแล้ว' ||
                          status == 'ส่งใบลาแล้ว' ||
                          status == 'อนุมัติแล้ว' ||
                          status == 'อนุญาต')
                      ? Colors.green.withValues(alpha: 0.1)
                      : (status == 'ยังไม่ส่ง' || status == 'ไม่อนุญาต')
                          ? Colors.orange.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05),
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
          _historyCell(
              'ปีงบ',
              Center(
                  child: Text(leaf['year']?.toString() ?? '-',
                      style: GoogleFonts.sarabun(
                          fontSize: 12, color: Colors.black)))),
          _historyCell(
              'จำนวนวัน',
              Center(
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
          _historyCell(
              'รับที่',
              Center(
                  child: Text(leaf['receiveNumber']?.toString() ?? '-',
                      style: GoogleFonts.sarabun(
                          fontSize: 12, color: Colors.black)))),
          _historyCell(
              'วันที่รับ',
              Center(
                  child: Text(leaf['receiveDate']?.toString() ?? '-',
                      style: GoogleFonts.sarabun(
                          fontSize: 12, color: Colors.black)))),
          _historyCell(
              'เวลารับ',
              Center(
                  child: Text(leaf['receiveTime']?.toString() ?? '-',
                      style: GoogleFonts.sarabun(
                          fontSize: 12, color: Colors.black)))),
          _historyCell(
            'ใบรับรองแพทย์/ใบนัด',
            Center(
              child: Builder(builder: (context) {
                String? certUrl = leaf['medicalCertificate']?.toString();
                final imgUrl = resolveDisplayImageUrl(certUrl);
                if (certUrl != null && imgUrl != null) {
                  return InkWell(
                    onTap: () => launchUrl(Uri.parse(certUrl)),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.black.withValues(alpha: 0.1))),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(imgUrl,
                          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
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
                  } else if (value == 'set_receive') {
                    _showSetReceiveDialog(leaf);
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
                    PopupMenuItem<String>(
                        value: 'set_receive',
                        child: Row(children: [
                          const Icon(Icons.assignment_turned_in_outlined,
                              size: 18, color: Colors.indigo),
                          const SizedBox(width: 10),
                          Text('กำหนดรับใบลา',
                              style: GoogleFonts.sarabun(
                                  fontSize: 13, color: Colors.indigo))
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

  bool _isApproveStatus(String status) {
    return status == 'ส่งใบแล้ว' ||
        status == 'ส่งใบลาแล้ว' ||
        status == 'อนุมัติแล้ว' ||
        status == 'อนุญาต';
  }

  Future<void> _updateStatus(String requestId, String status) async {
    try {
      final updateData = <String, dynamic>{'status': status};

      if (_isApproveStatus(status)) {
        final receiveNumber = await _firebaseService.generateReceiveNumber();
        final now = DateTime.now();
        updateData['receiveNumber'] = receiveNumber;
        // คอลัมน์ receiveDate/receiveTime เป็น date/time ต้องส่ง ISO (ค.ศ.)
        updateData['receiveDate'] = FirebaseService.toIsoDate(now);
        updateData['receiveTime'] =
            FirebaseService.toIsoTime(now.hour, now.minute);
      }

      await _firebaseService.updateLeaveRequest(requestId, updateData);

      if (mounted) {
        _reloadLeaves(); // ดึงรายการใหม่ ไม่งั้นสถานะในตารางยังเป็นค่าเดิม
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isApproveStatus(status)
              ? '✅ อนุมัติเรียบร้อย (รับที่ ${updateData['receiveNumber']})'
              : '✅ ปรับปรุงสถานะเป็น: $status เรียบร้อยแล้ว'),
          backgroundColor:
              _isApproveStatus(status) ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('❌ เกิดข้อผิดพลาด: $e')));
      }
    }
  }

  void _showSetReceiveDialog(Map<String, dynamic> leaf) {
    final requestId = leaf['requestId']?.toString() ?? '';
    final receiveCtrl =
        TextEditingController(text: leaf['receiveNumber']?.toString() ?? '');
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final thaiYear = selectedDate.year + 543;
          final dateStr = '${selectedDate.day}/${selectedDate.month}/$thaiYear';
          final timeStr =
              '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')} น.';

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              const Icon(Icons.assignment_turned_in_outlined,
                  color: Colors.indigo),
              const SizedBox(width: 12),
              Text('กำหนดรับใบลา',
                  style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ชื่อ: ${leaf['fullName'] ?? '-'}',
                    style: GoogleFonts.sarabun(
                        fontSize: 13, color: Colors.blueGrey)),
                const SizedBox(height: 16),
                Text('รับที่',
                    style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: receiveCtrl,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    hintText: 'เลขรับ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 16),
                Text('วันที่',
                    style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        Text(dateStr, style: GoogleFonts.sarabun(fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('เวลา',
                    style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: selectedTime,
                    );
                    if (picked != null) {
                      setDialogState(() => selectedTime = picked);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        Text(timeStr, style: GoogleFonts.sarabun(fontSize: 14)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('ยกเลิก', style: GoogleFonts.sarabun()),
              ),
              ElevatedButton(
                onPressed: () async {
                  final receiveVal = receiveCtrl.text.trim();
                  if (receiveVal.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('กรุณากรอกเลขรับ')));
                    return;
                  }
                  try {
                    // 🚀 เขียน Supabase เท่านั้น — ห้ามเขียน Firebase
                    await _firebaseService.updateLeaveReceiveNumberInSupabase(
                      requestId,
                      receiveVal,
                      FirebaseService.toIsoDate(selectedDate),
                      FirebaseService.toIsoTime(
                          selectedTime.hour, selectedTime.minute),
                    );
                    // ctx เป็น context ของกล่องโต้ตอบ ไม่ใช่ของหน้านี้
                    // จึงต้องเช็ก ctx.mounted แยกก่อนสั่งปิด
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      _reloadLeaves(); // ดึงรายการใหม่ให้เลขรับขึ้นทันที
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('✅ บันทึกรับที่ $receiveVal เรียบร้อย'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('❌ เกิดข้อผิดพลาด: $e'),
                        backgroundColor: Colors.red,
                      ));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('บันทึก', style: GoogleFonts.sarabun()),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPdfPreview(Map<String, dynamic> leaf) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => LeaveFormPage(
          leaf: leaf,
          allUsers: _allUsers,
          allLeaveRequests: _allLeaveRequests,
          leaveTypeNames: _leaveTypeNames,
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
                if (medicalUrl.isNotEmpty) {
                  await _firebaseService.deleteDriveFileStrict(medicalUrl);
                }
                // 🚀 ลบจาก Supabase — ห้ามลบ Firebase
                await _firebaseService.deleteLeaveFromSupabase(requestId);
                if (mounted) {
                  setState(() => _selectedIds.remove(requestId));
                  _reloadLeaves(); // ดึงรายการใหม่ ไม่งั้นแถวที่ลบไปยังค้างอยู่
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('✅ ลบรายการเรียบร้อยแล้ว'),
                      backgroundColor: Colors.red.shade400,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ เกิดข้อผิดพลาด: $e')));
                }
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

  /// โหลดรายการใบลาใหม่จาก Supabase
  ///
  /// สตรีมของหน้านี้เป็นแบบยิงครั้งเดียวจบ (Stream.value / Stream.fromFuture)
  /// เมื่อมีการลบหรือแก้สถานะ ต้องสร้างสตรีมใหม่เอง ไม่งั้นตารางจะค้างข้อมูลเก่า
  void _reloadLeaves() {
    if (!mounted) return;
    setState(() {
      _leaveRequestsStream =
          _createLeaveRequestsStream(_canViewAll, _currentUser);
    });
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
          if (medicalUrl.isNotEmpty) {
            await _firebaseService.deleteDriveFileStrict(medicalUrl);
          }
          await _firebaseService.deleteLeaveFromSupabase(id);
          count++;
        }
      }
      if (mounted) {
        setState(() {
          _selectedIds.clear();
          _isDeletingBulk = false;
        });
        _reloadLeaves(); // ดึงรายการใหม่หลังลบหลายรายการ
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ ลบสำเร็จทั้งหมด $count รายการ'),
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
