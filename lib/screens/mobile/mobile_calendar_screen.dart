import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';

class MobileCalendarScreen extends StatefulWidget {
  const MobileCalendarScreen({super.key});

  @override
  State<MobileCalendarScreen> createState() => _MobileCalendarScreenState();
}

class _MobileCalendarScreenState extends State<MobileCalendarScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  String _currentUser = '';
  String _userRole = '';
  Map<DateTime, List<dynamic>> _events = {};

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUser = prefs.getString('currentUser') ?? '';
      _userRole = prefs.getString('userRole') ?? '';
    });
  }

  DateTime? _stringToDateTime(String s) {
    try {
      final p = s.split('/');
      if (p.length != 3) return null;
      int year = int.parse(p[2]);
      if (year > 2400) year -= 543;
      return DateTime(year, int.parse(p[1]), int.parse(p[0]));
    } catch (_) {
      return null;
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return _events[date] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _firebaseService.getCalendarActivitiesStream(
            fullName: null, // Admin เห็นทุกคนครับ
          ),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              _events = {};
              for (var leave in snapshot.data!) {
                final start = _stringToDateTime(leave['startDate'] ?? '');
                final end = _stringToDateTime(leave['endDate'] ?? '');

                if (start != null && end != null) {
                  DateTime current =
                      DateTime(start.year, start.month, start.day);
                  final last = DateTime(end.year, end.month, end.day);

                  while (current.isBefore(last) ||
                      current.isAtSameMomentAs(last)) {
                    _events[current] ??= [];
                    _events[current]!.add(leave);
                    current = current.add(const Duration(days: 1));
                  }
                }
              }
            }

            final selectedEvents =
                _getEventsForDay(_selectedDay ?? _focusedDay);

            return Column(
              children: [
                // 📅 Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ปฏิทินการลา',
                            style: GoogleFonts.sarabun(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'รายการการลาของบุคลากรทุกคน',
                            style: GoogleFonts.sarabun(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _focusedDay = DateTime.now()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.today_rounded,
                                  size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                'วันนี้',
                                style: GoogleFonts.sarabun(
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 🗓️ Calendar
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: TableCalendar(
                    locale: 'th_TH',
                    firstDay: DateTime.utc(2025, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
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
                          color: const Color(0xFF2563EB).withOpacity(0.15),
                          shape: BoxShape.circle),
                      todayTextStyle: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.bold),
                      selectedDecoration: const BoxDecoration(
                          color: Color(0xFF2563EB), shape: BoxShape.circle),
                      markerDecoration: const BoxDecoration(
                          color: Colors.orange, shape: BoxShape.circle),
                      markersMaxCount: 1,
                      outsideDaysVisible: false,
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonVisible: true,
                      titleCentered: true,
                      titleTextStyle: GoogleFonts.sarabun(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      titleTextFormatter: (date, locale) {
                        final months = [
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
                          'ธันวาคม'
                        ];
                        return '${months[date.month - 1]} ${date.year + 543}';
                      },
                      formatButtonDecoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      formatButtonTextStyle: GoogleFonts.sarabun(
                          fontSize: 11, fontWeight: FontWeight.bold),
                      leftChevronIcon: const Icon(Icons.chevron_left_rounded,
                          color: Color(0xFF2563EB)),
                      rightChevronIcon: const Icon(Icons.chevron_right_rounded,
                          color: Color(0xFF2563EB)),
                    ),
                  ),
                ),

                // 📝 Event List
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        'กิจกรรม: ',
                        style: GoogleFonts.sarabun(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A)),
                      ),
                      Text(
                        FirebaseService.formatThaiDate(
                            _selectedDay ?? _focusedDay),
                        style: GoogleFonts.sarabun(
                            fontSize: 15, color: const Color(0xFF2563EB)),
                      ),
                      const Spacer(),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                ),

                Expanded(
                  child: _buildEventList(selectedEvents),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEventList(List<dynamic> events) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available_outlined,
                size: 52, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'ไม่มีรายการการลาในวันนี้ครับ',
              style: GoogleFonts.sarabun(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final type = event['leaveType'] ?? 'บันทึกกิจกรรม';

        Color color = Colors.blue;
        if (type.contains('ลาป่วย')) color = Colors.red;
        if (type.contains('ลากิจ')) color = Colors.orange;
        if (type.contains('ลาพักผ่อน')) color = Colors.green;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: color, width: 4)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)
            ],
          ),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(type,
                        style: GoogleFonts.sarabun(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 13, color: Colors.black38),
                  const SizedBox(width: 5),
                  Text(
                    '${FirebaseService.formatThaiDate(event['startDate'])} - ${FirebaseService.formatThaiDate(event['endDate'])}',
                    style: GoogleFonts.sarabun(
                        fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
              if (event['reason'] != null &&
                  event['reason'].toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'เหตุผล: ${event['reason']}',
                  style:
                      GoogleFonts.sarabun(fontSize: 12, color: Colors.black38),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
