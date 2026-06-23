import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';

class LoginLogsScreen extends StatefulWidget {
  const LoginLogsScreen({super.key});

  @override
  State<LoginLogsScreen> createState() => _LoginLogsScreenState();
}

class _LoginLogsScreenState extends State<LoginLogsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _timeFilter = 'ทั้งหมด';
  String _departmentFilter = 'ทั้งหมด';
  String _roleFilter = 'ทั้งหมด';
  List<String> _departmentOptions = const ['ทั้งหมด'];
  Map<String, String> _departmentByUsername = {};
  Map<String, String> _departmentByFullName = {};
  List<Map<String, dynamic>> _allRounds = [];
  Map<String, dynamic>? _selectedRound;
  Stream<List<Map<String, dynamic>>>? _loginLogsStream;
  bool _isRoundsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _refreshLoginLogsStream() {
    _loginLogsStream = _firebaseService.getLoginLogsStream(
      startDate: _selectedRoundStart,
      endDate: _selectedRoundEnd,
    );
  }

  Future<void> _loadInitialData() async {
    try {
      final departments = await _firebaseService.getDepartments();
      final users = await _firebaseService.getUsers();
      final rounds = await _firebaseService.getFiscalRounds();
      final activeRound = await _firebaseService.getActiveFiscalRound();
      final byUsername = <String, String>{};
      final byFullName = <String, String>{};

      for (final user in users) {
        final department = _userDepartment(user);
        if (department == null) continue;

        final username = user['username']?.toString().trim();
        if (username != null && username.isNotEmpty) {
          byUsername[username] = department;
        }

        final fullName = user['fullName']?.toString().trim();
        if (fullName != null && fullName.isNotEmpty) {
          byFullName[fullName] = department;
        }
      }

      if (!mounted) return;
      setState(() {
        _departmentOptions = ['ทั้งหมด', ...departments];
        _departmentByUsername = byUsername;
        _departmentByFullName = byFullName;
        _allRounds = rounds;
        if (activeRound != null) {
          _selectedRound = rounds.firstWhere(
            (round) => round['id'] == activeRound['id'],
            orElse: () => activeRound,
          );
        } else if (rounds.isNotEmpty) {
          _selectedRound = rounds.first;
        }
        _refreshLoginLogsStream();
        _isRoundsLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading login log lookups: $e');
      if (mounted) {
        setState(() => _isRoundsLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _loginLogsStream == null
                  ? const Center(child: CircularProgressIndicator())
                  : StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _loginLogsStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final allLogs = (snapshot.data ?? [])
                            .where((log) => log['fullName'] != 'ผู้ดูแลระบบ')
                            .toList();
                        final activityLogs =
                            allLogs.where(_matchesFilters).toList();
                        final timelineLogs = allLogs;

                        return SingleChildScrollView(
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  if (!_isRoundsLoading &&
                                      _allRounds.isNotEmpty)
                                    _buildRoundSelector(),
                                  if (!_isRoundsLoading &&
                                      _allRounds.isNotEmpty)
                                    const SizedBox(width: 12),
                                  Expanded(child: _buildSummaryCards(allLogs)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (allLogs.isEmpty)
                                SizedBox(height: 420, child: _buildEmptyState())
                              else
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        children: [
                                          _buildFilterPanel(allLogs),
                                          const SizedBox(height: 16),
                                          _buildActivityTable(activityLogs),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    SizedBox(
                                      width: 260,
                                      child: Column(
                                        children: [
                                          _buildRecentTimeline(timelineLogs),
                                          const SizedBox(height: 16),
                                          _buildSecurityCard(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_rounded,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('ไม่พบประวัติการเข้าใช้งานครับ',
              style: GoogleFonts.sarabun(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return SizedBox(
      width: 300,
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'ค้นหาชื่อ หรือ Username...',
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildRoundSelector() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E3E6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_rounded,
                size: 18, color: Color(0xFF005DAC)),
            const SizedBox(width: 10),
            DropdownButtonHideUnderline(
              child: DropdownButton<Map<String, dynamic>>(
                value: _selectedRound,
                borderRadius: BorderRadius.circular(12),
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF717783)),
                style: GoogleFonts.sarabun(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF191C1E),
                ),
                items: _allRounds
                    .map(
                      (round) => DropdownMenuItem(
                        value: round,
                        child: Text(
                            'ปีงบ ${round['year']} - รอบที่ ${round['round']}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRound = value;
                    _timeFilter = 'ทั้งหมด';
                    _departmentFilter = 'ทั้งหมด';
                    _roleFilter = 'ทั้งหมด';
                  });
                },
              ),
            ),
            if (_selectedRound != null) ...[
              const SizedBox(width: 12),
              Text(
                '${FirebaseService.formatThaiDate(_selectedRound!['startDate'])} - ${FirebaseService.formatThaiDate(_selectedRound!['endDate'])}',
                style: GoogleFonts.sarabun(
                    fontSize: 12, color: const Color(0xFF717783)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(List<Map<String, dynamic>> logs) {
    final now = DateTime.now();
    final todayCount = logs.where((log) {
      final date = _logDate(log);
      return date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).length;
    final sevenDaysCount = logs.where((log) {
      final date = _logDate(log);
      return date != null &&
          date.isAfter(now.subtract(const Duration(days: 7)));
    }).length;
    final monthCount = logs.where((log) {
      final date = _logDate(log);
      return date != null &&
          date.isAfter(now.subtract(const Duration(days: 30)));
    }).length;
    final onlineUsers = logs
        .where((log) {
          final date = _logDate(log);
          return date != null &&
              date.isAfter(now.subtract(const Duration(minutes: 15)));
        })
        .map((log) => log['username']?.toString() ?? '')
        .where((username) => username.isNotEmpty)
        .toSet()
        .length;

    return Row(
      children: [
        _buildSummaryCard('ทั้งหมด', logs.length.toString(), 'รายการ',
            Icons.trending_up_rounded, const Color(0xFF005DAC)),
        const SizedBox(width: 12),
        _buildSummaryCard('วันนี้', todayCount.toString(), 'รายการ',
            Icons.person_outline_rounded, const Color(0xFF4854BB)),
        const SizedBox(width: 12),
        _buildSummaryCard('7 วัน', sevenDaysCount.toString(), 'รายการ',
            Icons.date_range_rounded, const Color(0xFF005DAC)),
        const SizedBox(width: 12),
        _buildSummaryCard('1 เดือน', monthCount.toString(), 'รายการ',
            Icons.calendar_month_rounded, const Color(0xFF944700)),
        const SizedBox(width: 12),
        _buildSummaryCard('สถานะออนไลน์', onlineUsers.toString(), 'ออนไลน์',
            Icons.circle_rounded, const Color(0xFF10B981)),
      ],
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    String caption,
    IconData icon,
    Color color, {
    bool showBar = false,
  }) {
    return Expanded(
      child: Container(
        height: 92,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E3E6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.sarabun(
                    fontSize: 12, color: const Color(0xFF414752))),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.sarabun(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF191C1E))),
            const Spacer(),
            if (showBar)
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: 0.35,
                  minHeight: 3,
                  backgroundColor: const Color(0xFFECEEF1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            else
              Row(
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(caption,
                      style: GoogleFonts.sarabun(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPanel(List<Map<String, dynamic>> logs) {
    final departments =
        _filterItems(logs, _logDepartment, baseItems: _departmentOptions);
    final roles = _filterItems(logs, (log) => log['role']?.toString() ?? 'ครู');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E3E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list_rounded,
                  size: 18, color: Color(0xFF191C1E)),
              const SizedBox(width: 8),
              Text('ตัวกรองข้อมูล',
                  style: GoogleFonts.sarabun(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF191C1E))),
              const Spacer(),
              OutlinedButton(
                onPressed: () => setState(() {
                  _timeFilter = 'ทั้งหมด';
                  _departmentFilter = 'ทั้งหมด';
                  _roleFilter = 'ทั้งหมด';
                }),
                child: Text('ล้างค่า', style: GoogleFonts.sarabun()),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => setState(() {}),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF005DAC),
                  foregroundColor: Colors.white,
                ),
                child: Text('แสดงผลลัพธ์', style: GoogleFonts.sarabun()),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(width: 280, child: _buildSearchBox()),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown(
                  label: 'ช่วงเวลา',
                  value: _timeFilter,
                  items: const ['ทั้งหมด', 'วันนี้', '7 วันล่าสุด', 'เดือนนี้'],
                  onChanged: (value) => setState(() => _timeFilter = value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterDropdown(
                  label: 'กลุ่มสาระ',
                  value: _departmentFilter,
                  items: departments,
                  onChanged: (value) =>
                      setState(() => _departmentFilter = value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterDropdown(
                  label: 'สิทธิ์',
                  value: _roleFilter,
                  items: roles,
                  onChanged: (value) => setState(() => _roleFilter = value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.sarabun(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF717783))),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF7F9FC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE0E3E6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE0E3E6)),
            ),
          ),
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
          style:
              GoogleFonts.sarabun(fontSize: 12, color: const Color(0xFF191C1E)),
        ),
      ],
    );
  }

  Widget _buildActivityTable(List<Map<String, dynamic>> logs) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E3E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Text('รายการกิจกรรม',
                    style: GoogleFonts.sarabun(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF191C1E))),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'รีเฟรช',
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECEEF1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('พบทั้งหมด ${logs.length} รายการ',
                      style: GoogleFonts.sarabun(
                          fontSize: 12, color: const Color(0xFF414752))),
                ),
              ],
            ),
          ),
          Container(
            color: const Color(0xFFF2F4F7),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                _buildHeaderCell('ผู้ใช้งาน', flex: 3),
                _buildHeaderCell('บทบาท', flex: 2),
                _buildHeaderCell('โมดูล', flex: 2),
                _buildHeaderCell('กิจกรรม', flex: 2),
                _buildHeaderCell('วันเวลา', flex: 2, align: TextAlign.right),
                const SizedBox(width: 32),
              ],
            ),
          ),
          if (logs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Text('ไม่พบข้อมูลตามตัวกรองครับ',
                  style: GoogleFonts.sarabun(color: Colors.grey)),
            )
          else
            SizedBox(
              height: 400,
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView.separated(
                  itemCount: logs.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, color: Color(0xFFECEEF1)),
                  itemBuilder: (context, index) =>
                      _buildLogTableRow(logs[index]),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Text('หน้า 1 จาก 1',
                    style: GoogleFonts.sarabun(
                        fontSize: 12, color: const Color(0xFF717783))),
                const Spacer(),
                _buildPagerButton(Icons.chevron_left_rounded),
                const SizedBox(width: 8),
                _buildPagerNumber('1', selected: true),
                const SizedBox(width: 8),
                _buildPagerButton(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text,
      {required int flex, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(text,
          textAlign: align,
          style: GoogleFonts.sarabun(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF717783))),
    );
  }

  Widget _buildLogTableRow(Map<String, dynamic> log) {
    final dateStr = _formatLogThaiDate(log);
    final timeStr = _formatLogClock(log);
    final role = log['role'] ?? 'ครู';
    final isWeb = log['platform'] == 'Web';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isWeb
                        ? const Color(0xFFDFF0FF)
                        : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isWeb
                        ? Icons.desktop_windows_outlined
                        : Icons.smartphone_rounded,
                    color: isWeb ? const Color(0xFF0084FF) : Colors.green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(log['fullName'] ?? 'ไม่ระบุชื่อ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sarabun(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF191C1E))),
                      Text('Username: ${log['username'] ?? '-'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sarabun(
                              fontSize: 11, color: const Color(0xFF717783))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(flex: 2, child: _buildRoleBadge(role)),
          Expanded(
            flex: 2,
            child: Text('Auth System',
                style: GoogleFonts.sarabun(
                    fontSize: 12, color: const Color(0xFF414752))),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 3,
                  backgroundColor: Color(0xFF005DAC),
                ),
                const SizedBox(width: 8),
                Text('เข้าสู่ระบบ',
                    style: GoogleFonts.sarabun(
                        fontSize: 12, color: const Color(0xFF005DAC))),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(dateStr,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.sarabun(
                        fontSize: 12, color: const Color(0xFF414752))),
                Text(timeStr,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.sarabun(
                        fontSize: 11, color: const Color(0xFF717783))),
              ],
            ),
          ),
          const SizedBox(
              width: 32,
              child:
                  Icon(Icons.chevron_right_rounded, color: Color(0xFFC1C6D4))),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    final isAdmin = role.contains('ผู้ดูแลระบบ');
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isAdmin ? const Color(0xFFD4E3FF) : const Color(0xFFECEEF1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(role,
            textAlign: TextAlign.center,
            style: GoogleFonts.sarabun(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isAdmin
                    ? const Color(0xFF005DAC)
                    : const Color(0xFF414752))),
      ),
    );
  }

  Widget _buildPagerButton(IconData icon) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFC1C6D4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: const Color(0xFF414752)),
    );
  }

  Widget _buildPagerNumber(String text, {bool selected = false}) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF005DAC) : Colors.white,
        border: Border.all(color: const Color(0xFFC1C6D4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: GoogleFonts.sarabun(
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : const Color(0xFF414752))),
    );
  }

  Widget _buildRecentTimeline(List<Map<String, dynamic>> logs) {
    final recent = logs.take(4).toList();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E3E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded,
                  size: 18, color: Color(0xFF005DAC)),
              const SizedBox(width: 8),
              Text('กิจกรรมล่าสุด',
                  style: GoogleFonts.sarabun(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF191C1E))),
            ],
          ),
          const SizedBox(height: 16),
          if (recent.isEmpty)
            Text('ไม่มีกิจกรรมล่าสุด',
                style: GoogleFonts.sarabun(color: const Color(0xFF717783)))
          else
            ...recent.map((log) => _buildTimelineItem(log)),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> log) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5),
            decoration: const BoxDecoration(
              color: Color(0xFF005DAC),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_relativeTime(log),
                    style: GoogleFonts.sarabun(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF005DAC))),
                Text('${log['fullName'] ?? '-'} เข้าสู่ระบบ',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sarabun(
                        fontSize: 12, color: const Color(0xFF191C1E))),
                Text('Username: ${log['username'] ?? '-'}',
                    style: GoogleFonts.sarabun(
                        fontSize: 10, color: const Color(0xFF717783))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF005DAC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ระบบตรวจสอบอัจฉริยะ',
              style: GoogleFonts.sarabun(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('ขณะนี้ระบบกำลังตรวจสอบพฤติกรรมการเข้าใช้งานที่ผิดปกติ',
              style: GoogleFonts.sarabun(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_open_rounded,
                    size: 20, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('สถานะความปลอดภัย',
                          style: GoogleFonts.sarabun(
                              fontSize: 11, color: Colors.white70)),
                      Text('เสถียร (Stable)',
                          style: GoogleFonts.sarabun(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesNonSearchFilters(Map<String, dynamic> log) {
    if (_departmentFilter != 'ทั้งหมด' &&
        _logDepartment(log) != _departmentFilter) {
      return false;
    }

    if (_roleFilter != 'ทั้งหมด' &&
        (log['role']?.toString() ?? 'ครู') != _roleFilter) {
      return false;
    }

    if (_timeFilter == 'ทั้งหมด') return true;
    final date = _logDate(log);
    if (date == null) return false;

    final now = DateTime.now();
    if (_timeFilter == 'วันนี้') {
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }
    if (_timeFilter == '7 วันล่าสุด') {
      return date.isAfter(now.subtract(const Duration(days: 7)));
    }
    if (_timeFilter == 'เดือนนี้') {
      return date.year == now.year && date.month == now.month;
    }
    return true;
  }

  bool _matchesFilters(Map<String, dynamic> log) {
    final search = _searchQuery.trim();
    final matchesSearch = search.isEmpty ||
        log['fullName'].toString().contains(search) ||
        log['username'].toString().contains(search);
    if (!matchesSearch) return false;

    return _matchesNonSearchFilters(log);
  }

  List<String> _filterItems(
    List<Map<String, dynamic>> logs,
    String Function(Map<String, dynamic>) getter, {
    List<String> baseItems = const ['ทั้งหมด'],
  }) {
    final values = {
      ...baseItems,
      ...logs.map(getter).where((value) => value.isNotEmpty),
    }..remove('ทั้งหมด');
    final sortedValues = values.toList()..sort();
    return ['ทั้งหมด', ...sortedValues];
  }

  String? _userDepartment(Map<String, dynamic> user) {
    final value = user['department'] ??
        user['subjectGroup'] ??
        user['group'] ??
        user['กลุ่มสาระ'] ??
        user['กลุ่มสาระการเรียนรู้'];
    final department = value?.toString().trim();
    return department == null || department.isEmpty ? null : department;
  }

  String _logDepartment(Map<String, dynamic> log) {
    final direct = _userDepartment(log);
    if (direct != null) return direct;

    final username = log['username']?.toString().trim();
    if (username != null &&
        username.isNotEmpty &&
        _departmentByUsername.containsKey(username)) {
      return _departmentByUsername[username]!;
    }

    final fullName = log['fullName']?.toString().trim();
    if (fullName != null &&
        fullName.isNotEmpty &&
        _departmentByFullName.containsKey(fullName)) {
      return _departmentByFullName[fullName]!;
    }

    return 'ไม่ระบุ';
  }

  DateTime? _logDate(Map<String, dynamic> log) {
    final timestamp = log['timestamp'];
    if (timestamp is Timestamp) return timestamp.toDate();
    return null;
  }

  String _formatLogThaiDate(Map<String, dynamic> log) {
    final date = _logDate(log);
    if (date == null) return '-';
    const months = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year + 543}';
  }

  String _formatLogClock(Map<String, dynamic> log) {
    final date = _logDate(log);
    return date != null ? DateFormat('HH:mm:ss').format(date) : '-';
  }

  String _relativeTime(Map<String, dynamic> log) {
    final date = _logDate(log);
    if (date == null) return '-';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  DateTime? get _selectedRoundStart {
    final raw = _selectedRound?['startDate']?.toString() ?? '';
    final date = _parseFiscalDate(raw);
    return date == null ? null : DateTime(date.year, date.month, date.day);
  }

  DateTime? get _selectedRoundEnd {
    final raw = _selectedRound?['endDate']?.toString() ?? '';
    final date = _parseFiscalDate(raw);
    return date == null
        ? null
        : DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  DateTime? _parseFiscalDate(String value) {
    try {
      final parts = value.trim().replaceAll(' ', '').split('/');
      if (parts.length != 3) return null;
      var year = int.parse(parts[2]);
      if (year > 2400) year -= 543;
      return DateTime(year, int.parse(parts[1]), int.parse(parts[0]));
    } catch (_) {
      return null;
    }
  }
}
