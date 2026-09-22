import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firebase_service.dart';
import '../utils/school_info.dart';
import '../widgets/leave_form_page.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  String _currentUser = '';
  String _userRole = '';
  Map<DateTime, List<dynamic>> _events = {};

  // ข้อมูลประกอบสำหรับเปิด "ฟอร์มใบลา" แบบ popup เมื่อกดการ์ดรายชื่อ
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _allLeaveRequests = [];
  List<String> _leaveTypeNames = [];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadFormReferenceData();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUser = prefs.getString('currentUser') ?? '';
      _userRole = prefs.getString('userRole') ?? '';
    });
  }

  /// ฟอร์มใบลาต้องใช้ข้อมูลครู (ตำแหน่ง/วิทยฐานะ), ใบลาทั้งหมด (หาการลาครั้งก่อน)
  /// และรายชื่อประเภทการลา (ช่องติ๊กในแบบฟอร์ม) จึงโหลดเตรียมไว้เบื้องหลัง
  Future<void> _loadFormReferenceData() async {
    try {
      final results = await Future.wait([
        _firebaseService.getUsers(),
        _firebaseService.getLeaveRequestsFromSupabase(),
        _firebaseService.getLeaveTypes(),
      ]);
      if (!mounted) return;
      setState(() {
        _allUsers = results[0] as List<Map<String, dynamic>>;
        _allLeaveRequests = results[1] as List<Map<String, dynamic>>;
        _leaveTypeNames = results[2] as List<String>;
      });
    } catch (e) {
      debugPrint('⚠️  โหลดข้อมูลประกอบฟอร์มใบลาไม่สำเร็จ: $e');
    }
  }

  /// 📄 เปิดฟอร์มใบลาเป็น popup เมื่อกดการ์ดรายชื่อคนลา
  void _showLeaveFormPopup(Map<String, dynamic> leave) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: size.width < 900 ? 12 : 40,
            vertical: 24,
          ),
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: 900,
            height: size.height,
            // 📄 ใบลาฉบับกลาง (lib/widgets/leave_form_document.dart)
            // หน้าประวัติการลายังใช้ LeaveFormPreview ตัวเดิมอยู่ เพื่อให้เปิด
            // ใบเดียวกันจากสองหน้าแล้วเทียบกันได้ว่าแสดงผลตรงกันไหม
            child: LeaveFormPage(
              leaf: leave,
              allUsers: _allUsers,
              allLeaveRequests: _allLeaveRequests,
              leaveTypeNames: _leaveTypeNames,
            ),
          ),
        );
      },
    );
  }

  // 🛠️ แปลงวันที่จาก String "วว/ดด/ปปปป" เป็น DateTime ค.ศ.
  DateTime? _stringToDateTime(String s) {
    try {
      final p = s.split('/');
      if (p.length != 3) return null;
      int year = int.parse(p[2]);
      if (year > 2400) year -= 543; // แปลง พ.ศ. เป๊ก ค.ศ.
      return DateTime(year, int.parse(p[1]), int.parse(p[0]));
    } catch (_) {
      return null;
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    // กำหนดให้เทียบเฉพาะ วัน/เดือน/ปี ครับ
    final date = DateTime(day.year, day.month, day.day);
    return _events[date] ?? [];
  }

  String _formatThaiMonthYear(DateTime date) {
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
    return '${months[date.month - 1]} ${date.year + 543}';
  }

  String _formatThaiFullDate(DateTime date) {
    return '${date.day} ${_formatThaiMonthYear(date)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firebaseService.getCalendarActivitiesStream(
          fullName: (_userRole.contains('ผู้ดูแลระบบ') ||
                  _userRole.contains('ผู้บริหาร'))
              ? null
              : _currentUser,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _events = {};
            for (var leave in snapshot.data!) {
              final start = _stringToDateTime(leave['startDate'] ?? '');
              final end = _stringToDateTime(leave['endDate'] ?? '');

              if (start != null && end != null) {
                // วนลูปเพื่อปักหมุดกิจกรรมทุกวันในช่วงการลาครับ
                DateTime current = DateTime(start.year, start.month, start.day);
                final last = DateTime(end.year, end.month, end.day);

                while (
                    current.isBefore(last) || current.isAtSameMomentAs(last)) {
                  _events[current] ??= [];
                  _events[current]!.add(leave);
                  current = current.add(const Duration(days: 1));
                }
              }
            }
          }

          return Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 📅 Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          SchoolInfo.calendarTitle,
                          style: GoogleFonts.sarabun(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          _userRole.contains('ผู้ดูแลระบบ') ||
                                  _userRole.contains('ผู้บริหาร')
                              ? 'แสดงรายการการลาของบุคลากรทุกคนในโรงเรียน'
                              : 'แสดงรายการการลาของคุณครูตามรอบปฏิทินครับ',
                          style: GoogleFonts.sarabun(
                            fontSize: 14,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () =>
                          setState(() => _focusedDay = DateTime.now()),
                      icon: const Icon(Icons.today, size: 18),
                      label: Text('กลับสู่วันนี้',
                          style:
                              GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🗓️ Calendar Card
                      Expanded(
                        flex: 6,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10)),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: TableCalendar(
                            locale: 'th_TH',
                            firstDay: DateTime.utc(2025, 1, 1),
                            lastDay: DateTime.utc(2030, 12, 31),
                            focusedDay: _focusedDay,
                            calendarFormat: _calendarFormat,
                            selectedDayPredicate: (day) =>
                                isSameDay(_selectedDay, day),
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            },
                            onFormatChanged: (format) {
                              setState(() => _calendarFormat = format);
                            },
                            eventLoader: _getEventsForDay,
                            calendarStyle: CalendarStyle(
                              todayDecoration: BoxDecoration(
                                  color: const Color(0xFF0F172A)
                                      .withValues(alpha: 0.1),
                                  shape: BoxShape.circle),
                              todayTextStyle: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold),
                              selectedDecoration: const BoxDecoration(
                                  color: Color(0xFF0F172A),
                                  shape: BoxShape.circle),
                              markerDecoration: const BoxDecoration(
                                  color: Colors.orange, shape: BoxShape.circle),
                              markersMaxCount: 1,
                            ),
                            headerStyle: HeaderStyle(
                              formatButtonVisible: true,
                              titleCentered: true,
                              titleTextFormatter: (date, locale) =>
                                  _formatThaiMonthYear(date),
                              titleTextStyle: GoogleFonts.sarabun(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                              formatButtonDecoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              formatButtonTextStyle: GoogleFonts.sarabun(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),

                      // 📝 Selected Day Details
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'กิจกรรมประจำวันที่ ${_formatThaiFullDate(_selectedDay ?? _focusedDay)}',
                              style: GoogleFonts.sarabun(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: _buildDetailsList(_getEventsForDay(
                                  _selectedDay ?? _focusedDay)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailsList(List<dynamic> events) {
    if (events.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black.withValues(alpha: 0.02)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available_outlined,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('ไม่มีรายการการลาในวันนี้ครับ',
                style: GoogleFonts.sarabun(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final type = event['leaveType'] ?? 'บันทึกกิจกรรม';

        Color color = Colors.blue;
        if (type.contains('ลาป่วย')) color = Colors.red;
        if (type.contains('ลากิจ')) color = Colors.orange;
        if (type.contains('ลาพักผ่อน')) color = Colors.green;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border(left: BorderSide(color: color, width: 4)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)
            ],
          ),
          clipBehavior: Clip.antiAlias,
          // 👆 กดการ์ดเพื่อเปิดฟอร์มใบลาของคนนั้นขึ้นมาดูครับ
          child: InkWell(
            onTap: () => _showLeaveFormPopup(Map<String, dynamic>.from(event)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          event['fullName'] ?? 'ไม่ระบุชื่อ',
                          style: GoogleFonts.sarabun(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(type,
                            style: GoogleFonts.sarabun(
                                fontSize: 11,
                                color: color,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 14, color: Colors.black38),
                      const SizedBox(width: 6),
                      Text(
                        '${event['startDate']} - ${event['endDate']}',
                        style: GoogleFonts.sarabun(
                            fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                  if (event['reason'] != null &&
                      event['reason'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'เหตุผล: ${event['reason']}',
                      style: GoogleFonts.sarabun(
                          fontSize: 12, color: Colors.black38),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
