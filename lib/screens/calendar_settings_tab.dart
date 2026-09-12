import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firebase_service.dart';
import '../widgets/thai_buddhist_calendar_widget.dart';

class CalendarSettingsTab extends StatefulWidget {
  final int tabIndex; // 0: Budget, 1: Holiday, 2: Special Working Day
  const CalendarSettingsTab({super.key, required this.tabIndex});

  @override
  State<CalendarSettingsTab> createState() => _CalendarSettingsTabState();
}

class _CalendarSettingsTabState extends State<CalendarSettingsTab> {
  final FirebaseService _firebaseService = FirebaseService();

  final Color primaryColor = const Color(0xFF0F172A);
  final Color accentColor = const Color(0xFF3B82F6);

  final _yearController = TextEditingController();
  String _selectedRound = '1';
  DateTime _roundStartDate = DateTime.now();
  DateTime _roundEndDate = DateTime.now();

  DateTime _holidayDate = DateTime.now();
  final _holidayTitleController = TextEditingController();

  DateTime _specialWorkingDate = DateTime.now();
  final _specialWorkingTitleController = TextEditingController();

  bool _isInstallingHolidays = false;
  bool _isRecalculatingLeaves = false;

  final List<String> _thaiMonths = [
    'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน',
    'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม',
    'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
  ];

  @override
  void dispose() {
    _yearController.dispose();
    _holidayTitleController.dispose();
    _specialWorkingTitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.tabIndex) {
      case 0:
        return _buildBudgetTab();
      case 1:
        return _buildHolidayTab();
      case 2:
        return _buildSpecialWorkingDayTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ===== Shared Helpers =====

  String _formatDateForStorage(DateTime date) {
    return '${date.day}/${date.month}/${date.year + 543}';
  }

  String _formatDateDisplay(DateTime date) {
    return '${date.day} ${_thaiMonths[date.month - 1]} ${date.year + 543}';
  }

  DateTime? _parseStoredDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    final isoDate = DateTime.tryParse(text);
    if (isoDate != null) return isoDate;

    final parts = RegExp(r'\d+')
        .allMatches(text)
        .map((match) => int.tryParse(match.group(0) ?? ''))
        .whereType<int>()
        .toList();
    if (parts.length < 3) return null;

    int day, month, year;
    if (parts[0] > 1900) {
      year = parts[0]; month = parts[1]; day = parts[2];
    } else {
      day = parts[0]; month = parts[1]; year = parts[2];
    }

    if (year > 2400) year -= 543;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  DateTime? _recordDate(Map<String, dynamic> data) {
    return _parseStoredDate(data['dateValue']) ??
        _parseStoredDate(data['date']) ??
        _parseStoredDate(data['day']) ??
        _parseStoredDate(data['workDate']);
  }

  String _recordTitle(Map<String, dynamic> data) {
    final title = data['title'] ?? data['name'] ?? data['note'] ?? data['description'] ?? data['detail'];
    final text = title?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  Future<void> _showPremiumDatePicker(DateTime initial, Function(DateTime) onPick) async {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => Center(
        child: ThaiBuddhistCalendarWidget(
          initialDate: initial,
          firstDate: DateTime(DateTime.now().year - 5),
          lastDate: DateTime(DateTime.now().year + 5),
          onDateSelected: onPick,
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildFieldLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: GoogleFonts.sarabun(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.blueGrey.shade700)),
  );

  Widget _buildTextField(TextEditingController ctrl, String hint, {IconData? icon}) {
    return TextField(
      controller: ctrl,
      style: GoogleFonts.sarabun(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.sarabun(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: icon != null ? Icon(icon, size: 18, color: Colors.blueGrey) : null,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: const Color(0xFF3B82F6), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDatePickerField(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(text, style: const TextStyle(fontSize: 13, color: Colors.black87)),
            const Icon(Icons.calendar_month_outlined, size: 18, color: Colors.blueGrey),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? val,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onC,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: val,
          isExpanded: true,
          icon: Icon(icon, size: 18, color: Colors.blueGrey),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.sarabun(fontSize: 14)))).toList(),
          onChanged: onC,
        ),
      ),
    );
  }

  // ===== Budget Tab =====

  Widget _buildRoundDropdown() {
    return _buildDropdownField(
      val: _selectedRound,
      items: ['1', '2'],
      icon: Icons.group_work_outlined,
      onC: (val) => setState(() => _selectedRound = val!),
    );
  }

  Widget _buildBudgetTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.calendar_month_rounded, color: primaryColor, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ตั้งค่ารอบงบประมาณ",
                    style: GoogleFonts.sarabun(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)),
                Text("กำหนดช่วงเวลาของแต่ละรอบงบประมาณเพื่อใช้ในการสรุปสถิติการลา",
                    style: GoogleFonts.sarabun(color: Colors.blueGrey, fontSize: 13)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: _buildGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("เพิ่มรอบงบประมาณ",
                        style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 24),
                    _buildFieldLabel("ปีงบประมาณ (พ.ศ.)"),
                    _buildTextField(_yearController, "เช่น 2569", icon: Icons.calendar_today_rounded),
                    const SizedBox(height: 16),
                    _buildFieldLabel("รอบที่"),
                    _buildRoundDropdown(),
                    const SizedBox(height: 16),
                    _buildFieldLabel("เริ่มต้นตั้งแต่วันที่"),
                    _buildDatePickerField(FirebaseService.formatThaiDate(_roundStartDate), () {
                      _showPremiumDatePicker(_roundStartDate, (d) => setState(() => _roundStartDate = d));
                    }),
                    const SizedBox(height: 16),
                    _buildFieldLabel("ถึงวันที่"),
                    _buildDatePickerField(FirebaseService.formatThaiDate(_roundEndDate), () {
                      _showPremiumDatePicker(_roundEndDate, (d) => setState(() => _roundEndDate = d));
                    }),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (_yearController.text.isNotEmpty) {
                          final String yearStr = _yearController.text;
                          final int startYearBE = _roundStartDate.year < 2400 ? _roundStartDate.year + 543 : _roundStartDate.year;
                          final int endYearBE = _roundEndDate.year < 2400 ? _roundEndDate.year + 543 : _roundEndDate.year;
                          final String startDate = "${_roundStartDate.day}/${_roundStartDate.month}/$startYearBE";
                          final String endDate = "${_roundEndDate.day}/${_roundEndDate.month}/$endYearBE";

                          await _firebaseService.addFiscalRound({
                            'year': yearStr,
                            'round': _selectedRound,
                            'startDate': startDate,
                            'endDate': endDate,
                          });

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('เพิ่มรอบงบประมาณเรียบร้อยแล้วครับ')));
                          }
                        }
                      },
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: Text("เพิ่มข้อมูล", style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 8,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _firebaseService.getFiscalRoundsStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final rounds = snapshot.data!;

                  return _buildGlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.table_chart_outlined, size: 20, color: Colors.blue),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("รายชื่อรอบงบประมาณทั้งหมด",
                                      style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor)),
                                  Text("ข้อมูลช่วงเวลาที่บันทึกไว้ในระบบ",
                                      style: GoogleFonts.sarabun(fontSize: 12, color: Colors.blueGrey)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        if (rounds.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(40),
                            child: Center(child: Text("ยังไม่มีข้อมูลรอบงบประมาณในระบบ", style: GoogleFonts.sarabun(color: Colors.grey))),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: rounds.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final r = rounds[index];
                              final now = DateTime.now();
                              final todayStr = "${now.day}/${now.month}/${now.year + 543}";
                              bool isCurrentCalendar = FirebaseService.isDateInRange(todayStr, r['startDate'] ?? '', r['endDate'] ?? '');

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                title: Row(
                                  children: [
                                    Text("ปี ${r['year']} รอบที่ ${r['round']}", style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
                                    if (isCurrentCalendar)
                                      Container(
                                        margin: const EdgeInsets.only(left: 12),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.auto_awesome, size: 10, color: Colors.blue),
                                            const SizedBox(width: 4),
                                            Text("ปัจจุบัน (ตามปฏิทิน)",
                                                style: GoogleFonts.sarabun(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text("ช่วงเวลา: ${FirebaseService.formatThaiDate(r['startDate'])} - ${FirebaseService.formatThaiDate(r['endDate'])}",
                                        style: GoogleFonts.sarabun(fontSize: 12)),
                                    if (isCurrentCalendar)
                                      Text("สถานะ: กำลังใช้งานสรุปผล (อัตโนมัติ)",
                                          style: GoogleFonts.sarabun(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold))
                                    else
                                      Text("สถานะ: พร้อมใช้งาน (ตามช่วงเวลา)",
                                          style: GoogleFonts.sarabun(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isCurrentCalendar ? Colors.blue.withValues(alpha: 0.1) : Colors.blueGrey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isCurrentCalendar ? Icons.auto_awesome_rounded : Icons.calendar_today_rounded,
                                    color: isCurrentCalendar ? Colors.blue : Colors.blueGrey,
                                    size: 24,
                                  ),
                                ),
                                trailing: IconButton(
                                  onPressed: () {
                                    _firebaseService.deleteFiscalRound(r['id']);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('ลบข้อมูลรอบงบประมาณเรียบร้อยแล้วครับ')));
                                    }
                                  },
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===== Holiday Tab =====

  Future<void> _saveHoliday() async {
    final title = _holidayTitleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อวันหยุดก่อนบันทึก')));
      return;
    }

    final docId = 'holiday_${_dateKey(_holidayDate).replaceAll('-', '')}';
    final now = DateTime.now().toIso8601String();
    await _firebaseService.addMasterItemToSupabase('SpecialHolidays', {
      'id': docId,
      'date': _formatDateForStorage(_holidayDate),
      'dateValue': _holidayDate.toIso8601String(),
      'title': title,
      'note': title,
      'updatedAt': now,
      'createdAt': now,
    });

    _holidayTitleController.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกวันหยุดเรียบร้อยแล้วครับ')));
  }

  Future<Set<String>> _loadSpecialDateKeys(String collection) async {
    final rows = collection == 'SpecialHolidays'
        ? await _firebaseService.getSpecialHolidaysFromSupabase()
        : await _firebaseService.getSpecialWorkingDaysFromSupabase();
    return rows
        .map((r) => _recordDate(r))
        .whereType<DateTime>()
        .map(_dateKey)
        .toSet();
  }

  double _calculateBusinessLeaveDays(
    Map<String, dynamic> leave,
    Set<String> holidayKeys,
    Set<String> specialWorkingKeys,
  ) {
    if (FirebaseService.isHalfDayLeave(leave)) return 0.5;

    final start = _recordDate({'date': leave['startDate'], 'dateValue': leave['startDateValue']});
    final end = _recordDate({'date': leave['endDate'], 'dateValue': leave['endDateValue']});
    if (start == null || end == null) {
      final current = leave['totalDays'] ?? leave['days'];
      if (current is num) return current.toDouble();
      return double.tryParse(current?.toString() ?? '') ?? 0;
    }

    final first = DateTime(start.year, start.month, start.day).isBefore(DateTime(end.year, end.month, end.day))
        ? DateTime(start.year, start.month, start.day)
        : DateTime(end.year, end.month, end.day);
    final last = DateTime(start.year, start.month, start.day).isBefore(DateTime(end.year, end.month, end.day))
        ? DateTime(end.year, end.month, end.day)
        : DateTime(start.year, start.month, start.day);

    final leaveType = (leave['leaveType'] ?? '').toString();
    if (leaveType.contains('คลอด')) {
      return last.difference(first).inDays + 1;
    }

    double total = 0;
    for (DateTime day = first; !day.isAfter(last); day = day.add(const Duration(days: 1))) {
      final key = _dateKey(day);
      final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
      if (specialWorkingKeys.contains(key)) {
        total += 1;
      } else if (holidayKeys.contains(key)) {
        continue;
      } else if (!isWeekend) {
        total += 1;
      }
    }
    return total;
  }

  Future<void> _recalculateAllLeaveDays() async {
    setState(() => _isRecalculatingLeaves = true);
    try {
      final holidayKeys = await _loadSpecialDateKeys('SpecialHolidays');
      final specialWorkingKeys = await _loadSpecialDateKeys('SpecialWorkingDays');
      final leaves = await _firebaseService.getLeaveRequestsFromSupabase();
      int updated = 0;
      final client = _firebaseService.supabaseClient;
      if (client == null) throw Exception('Supabase not initialized');

      for (final leave in leaves) {
        final totalDays = _calculateBusinessLeaveDays(leave, holidayKeys, specialWorkingKeys);
        final id = leave['requestId']?.toString() ?? leave['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        await client.from('leaves').update({
          'totaldays': totalDays,
          'lastupdatedat': DateTime.now().toIso8601String(),
        }).eq('id', id);
        updated++;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('คำนวณวันลาย้อนหลังใหม่แล้ว $updated รายการ')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('คำนวณวันลาย้อนหลังไม่สำเร็จ: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isRecalculatingLeaves = false);
    }
  }

  Future<void> _installDefaultHolidaysForCurrentYear() async {
    setState(() => _isInstallingHolidays = true);
    try {
      final year = DateTime.now().year;
      final holidays = <Map<String, dynamic>>[
        {'date': DateTime(year, 1, 1), 'title': 'วันขึ้นปีใหม่'},
        {'date': DateTime(year, 3, 3), 'title': 'วันมาฆบูชา'},
        {'date': DateTime(year, 4, 6), 'title': 'วันจักรี'},
        {'date': DateTime(year, 4, 13), 'title': 'วันสงกรานต์'},
        {'date': DateTime(year, 4, 14), 'title': 'วันสงกรานต์'},
        {'date': DateTime(year, 4, 15), 'title': 'วันสงกรานต์'},
        {'date': DateTime(year, 5, 1), 'title': 'วันแรงงานแห่งชาติ'},
        {'date': DateTime(year, 5, 4), 'title': 'วันฉัตรมงคล'},
        {'date': DateTime(year, 5, 13), 'title': 'วันพืชมงคล'},
        {'date': DateTime(year, 5, 31), 'title': 'วันวิสาขบูชา'},
        {'date': DateTime(year, 6, 3), 'title': 'วันเฉลิมพระชนมพรรษาสมเด็จพระราชินี'},
        {'date': DateTime(year, 7, 28), 'title': 'วันเฉลิมพระชนมพรรษาพระบาทสมเด็จพระเจ้าอยู่หัว'},
        {'date': DateTime(year, 7, 29), 'title': 'วันอาสาฬหบูชา'},
        {'date': DateTime(year, 8, 12), 'title': 'วันแม่แห่งชาติ'},
        {'date': DateTime(year, 10, 13), 'title': 'วันนวมินทรมหาราช'},
        {'date': DateTime(year, 10, 23), 'title': 'วันปิยมหาราช'},
        {'date': DateTime(year, 12, 5), 'title': 'วันพ่อแห่งชาติ'},
        {'date': DateTime(year, 12, 10), 'title': 'วันรัฐธรรมนูญ'},
        {'date': DateTime(year, 12, 31), 'title': 'วันสิ้นปี'},
      ];

      final client = _firebaseService.supabaseClient;
      if (client == null) throw Exception('Supabase not initialized');
      final now = DateTime.now().toIso8601String();
      for (final holiday in holidays) {
        final date = holiday['date'] as DateTime;
        final title = holiday['title'] as String;
        final docId = 'holiday_${_dateKey(date).replaceAll('-', '')}';
        await client.from('SpecialHolidays').upsert({
          'id': docId,
          'date': _formatDateForStorage(date),
          'dateValue': date.toIso8601String(),
          'title': title,
          'note': title,
          'source': 'default_${year + 543}',
          'updatedAt': now,
          'createdAt': now,
        }, onConflict: 'id');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ติดตั้งวันหยุดราชการหลักปี ${year + 543} แล้ว ${holidays.length} วัน')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ติดตั้งวันหยุดราชการหลักไม่สำเร็จ: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isInstallingHolidays = false);
    }
  }

  Future<void> _deleteSpecialDateRecord(String collection, String docId, String message) async {
    await _firebaseService.deleteMasterItemFromSupabase(collection, docId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildHolidayTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('เพิ่มวันหยุดใหม่',
                  style: GoogleFonts.sarabun(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 4),
              Text('กำหนดวันหยุดนักขัตฤกษ์ วันหยุดพิเศษ หรือวันหยุดเฉพาะของโรงเรียน เพื่อใช้หักลบจำนวนวันลาโดยอัตโนมัติ',
                  style: GoogleFonts.sarabun(color: Colors.blueGrey, fontSize: 13)),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 900;
                  final dateField = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('เลือกวันที่หยุด'),
                      _buildDatePickerField(_formatDateDisplay(_holidayDate), () => _showPremiumDatePicker(_holidayDate, (date) => setState(() => _holidayDate = date))),
                    ],
                  );
                  final titleField = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('ชื่อวันหยุด / รายละเอียด'),
                      _buildTextField(_holidayTitleController, 'เช่น วันสงกรานต์, วันครู, ปิดเทอมภาคเรียน', icon: Icons.edit_calendar_rounded),
                    ],
                  );

                  if (isNarrow) {
                    return Column(children: [dateField, const SizedBox(height: 16), titleField]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [Expanded(flex: 4, child: dateField), const SizedBox(width: 24), Expanded(flex: 6, child: titleField)],
                  );
                },
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isRecalculatingLeaves ? null : _recalculateAllLeaveDays,
                    icon: _isRecalculatingLeaves
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(_isRecalculatingLeaves ? 'กำลังคำนวณ...' : 'คำนวณวันลาย้อนหลังใหม่ทั้งหมด'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade700,
                      backgroundColor: Colors.orange.shade50,
                      side: BorderSide(color: Colors.orange.shade200),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isInstallingHolidays ? null : _installDefaultHolidaysForCurrentYear,
                    icon: _isInstallingHolidays
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sync_rounded, size: 18),
                    label: Text(_isInstallingHolidays ? 'กำลังติดตั้ง...' : 'ติดตั้งวันหยุดราชการหลักปีนี้'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentColor,
                      side: BorderSide(color: accentColor.withValues(alpha: 0.35)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _saveHoliday,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('บันทึกวันหยุด'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildSpecialDateList(
          collection: 'SpecialHolidays',
          title: 'รายการวันหยุดกำหนดเองในระบบ',
          emptyText: 'ยังไม่มีข้อมูลวันหยุดพิเศษเพิ่มเติม',
          emptySubText: 'วันหยุดเสาร์-อาทิตย์และวันหยุดนักขัตฤกษ์พื้นฐานรองรับอยู่ในระบบโดยอัตโนมัติแล้วครับ',
          chipSuffix: 'วัน',
          accent: Colors.amber,
          icon: Icons.event_available_rounded,
          deleteMessage: 'ลบวันหยุดเรียบร้อยแล้วครับ',
        ),
      ],
    );
  }

  // ===== Special Working Day Tab =====

  Future<void> _saveSpecialWorkingDay() async {
    final title = _specialWorkingTitleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อวันทำงานพิเศษก่อนบันทึก')));
      return;
    }

    final docId = 'working_${_dateKey(_specialWorkingDate).replaceAll('-', '')}';
    final now = DateTime.now().toIso8601String();
    await _firebaseService.addMasterItemToSupabase('SpecialWorkingDays', {
      'id': docId,
      'date': _formatDateForStorage(_specialWorkingDate),
      'dateValue': _specialWorkingDate.toIso8601String(),
      'title': title,
      'note': title,
      'updatedAt': now,
      'createdAt': now,
    });

    _specialWorkingTitleController.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกวันทำงานพิเศษเรียบร้อยแล้วครับ')));
  }

  Widget _buildSpecialWorkingDayTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ตั้งค่าวันทำงานพิเศษ (เสาร์-อาทิตย์)',
            style: GoogleFonts.sarabun(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)),
        const SizedBox(height: 4),
        Text('กำหนดวันเสาร์หรืออาทิตย์ที่มีนโยบายการเรียนการสอนของโรงเรียน เพื่อให้นับเป็นวันลาทำงานจริง (ไม่นับวันเสาร์-อาทิตย์)',
            style: GoogleFonts.sarabun(color: Colors.blueGrey, fontSize: 13)),
        const SizedBox(height: 28),
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('เพิ่มวันทำงานพิเศษใหม่',
                  style: GoogleFonts.sarabun(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 900;
                  final dateField = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('วันที่ทำกิจกรรมพิเศษ'),
                      _buildDatePickerField(_formatDateDisplay(_specialWorkingDate),
                          () => _showPremiumDatePicker(_specialWorkingDate, (date) => setState(() => _specialWorkingDate = date))),
                    ],
                  );
                  final titleField = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('ชื่อวันเรียนชดเชย / กิจกรรมตามนโยบายโรงเรียน'),
                      _buildTextField(_specialWorkingTitleController,
                          'เช่น สอนชดเชยวันลอยกระทง, MEP สอนพิเศษ, โครงการเตรียมความพร้อม',
                          icon: Icons.assignment_turned_in_rounded),
                    ],
                  );
                  final saveButton = ElevatedButton.icon(
                    onPressed: _saveSpecialWorkingDay,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('บันทึกวันทำงานพิเศษ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [dateField, const SizedBox(height: 16), titleField, const SizedBox(height: 16), saveButton],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(flex: 3, child: dateField),
                      const SizedBox(width: 16),
                      Expanded(flex: 5, child: titleField),
                      const SizedBox(width: 16),
                      saveButton,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildSpecialDateList(
          collection: 'SpecialWorkingDays',
          title: 'รายการวันทำงานพิเศษกำหนดเองในระบบ',
          emptyText: 'ยังไม่มีข้อมูลวันทำงานพิเศษเพิ่มเติม',
          emptySubText: 'เพิ่มวันที่โรงเรียนมีนโยบายให้วันเสาร์-อาทิตย์เป็นวันทำงานจริงได้จากฟอร์มด้านบนครับ',
          chipSuffix: 'วัน',
          accent: Colors.yellow.shade700,
          icon: Icons.calendar_today_rounded,
          deleteMessage: 'ลบวันทำงานพิเศษเรียบร้อยแล้วครับ',
        ),
      ],
    );
  }

  // ===== Shared Date List Widget =====

  Widget _buildSpecialDateList({
    required String collection,
    required String title,
    required String emptyText,
    required String emptySubText,
    required String chipSuffix,
    required Color accent,
    required IconData icon,
    required String deleteMessage,
  }) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: collection == 'SpecialHolidays'
          ? _firebaseService.getSpecialHolidaysFromSupabase()
          : _firebaseService.getSpecialWorkingDaysFromSupabase(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildGlassCard(child: const Center(child: CircularProgressIndicator()));
        }

        final records = snapshot.data!;
        records.sort((a, b) {
          final aDate = _recordDate(a);
          final bDate = _recordDate(b);
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });

        return _buildGlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title, style: GoogleFonts.sarabun(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text('ทั้งหมด ${records.length} $chipSuffix',
                          style: GoogleFonts.sarabun(fontSize: 12, fontWeight: FontWeight.bold, color: accent)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (records.isEmpty)
                SizedBox(
                  height: 220,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emptyText, style: GoogleFonts.sarabun(color: Colors.blueGrey, fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(emptySubText, style: GoogleFonts.sarabun(color: Colors.grey.shade400, fontSize: 12)),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: records.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final date = _recordDate(record);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: accent.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
                        child: Icon(icon, size: 20, color: accent),
                      ),
                      title: Text(_recordTitle(record), style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, color: primaryColor)),
                      subtitle: Text(date == null ? '-' : _formatDateDisplay(date), style: GoogleFonts.sarabun(color: Colors.blueGrey)),
                      trailing: IconButton(
                        onPressed: () => _deleteSpecialDateRecord(collection, record['id'].toString(), deleteMessage),
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
