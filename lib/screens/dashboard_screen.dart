import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int)? onNavigate;

  const DashboardScreen({super.key, this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  String _currentUser = 'ผู้ใช้งาน';
  String _userRole = 'ครู';
  Map<String, dynamic>? _activeRound; // 📅 รอบงบประมาณปัจจุบัน (ตามปฏิทิน)
  Map<String, dynamic>? _selectedRound; // 📅 รอบที่เลือกดูอยู่ครับ
  List<Map<String, dynamic>> _allRounds = []; // 📅 รายรายการรอบทั้งหมด

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUser = prefs.getString('currentUser') ?? 'ผู้ใช้งาน';
      _userRole = prefs.getString('userRole') ?? 'ครู';
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 1100;

    // 🛡️ ใช้ระบบ Combined Stream เพื่อให้ข้อมูลมาพร้อมกันโดยไม่ต้อง Nest ครับ 🥇🏆
    return StreamBuilder<Map<String, dynamic>>(
      stream: _firebaseService.getDashboardDataStream(),
      builder: (context, snapshot) {
        // 🔄 จังหวะรอโหลดข้อมูลแบบพรีเมียมครับ 🕵️‍♂️
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildFullScreenLoading();
        }

        if (snapshot.hasError) {
          return Center(
              child:
                  Text('เกิดข้อผิดพลาดในการโหลดข้อมูลครับ: ${snapshot.error}'));
        }

        final data = snapshot.data ?? {};
        final allRounds = (data['rounds'] as List<Map<String, dynamic>>?) ?? [];
        final allData =
            (data['allLeaves'] as List<Map<String, dynamic>>?) ?? [];
        final leaveTypesFromDb =
            (data['leaveTypes'] as List<Map<String, dynamic>>?) ?? [];

        // 🏗️ ดึงรายชื่อประเภทการลาจากฐานข้อมูลมาเตรียมไว้ครับ
        final List<String> dynamicLeaveTypes = leaveTypesFromDb
            .map((t) => t['Value']?.toString() ?? '')
            .where((t) => t.isNotEmpty)
            .toList();

        // 📅 คัดกรองหารรอบงบประมาณที่ Active ในปัจจุบัน (ใช้ padLeft เพื่อให้ตรงกับรูปแบบ 01/01/2569)
        final now = DateTime.now();
        final d = now.day.toString().padLeft(2, '0');
        final m = now.month.toString().padLeft(2, '0');
        final y = now.year + 543;
        final todayStr = "$d/$m/$y";

        Map<String, dynamic>? currentActiveRound;
        try {
          currentActiveRound = allRounds.firstWhere(
              (r) => FirebaseService.isDateInRange(
                  todayStr, r['startDate'] ?? '', r['endDate'] ?? ''),
              orElse: () => allRounds.isNotEmpty ? allRounds.first : {});
          if (currentActiveRound != null && currentActiveRound.isEmpty)
            currentActiveRound = null;
        } catch (e) {
          currentActiveRound = allRounds.isNotEmpty ? allRounds.first : null;
        }

        // 🎯 กำหนดรอบที่จะแสดงผล
        final viewRound = _selectedRound ?? currentActiveRound;

        // 🏎️ เตรียมช่วงวันที่ให้พร้อมก่อนเข้า Loop เพื่อความเร็วครับ 🏆
        DateTime? rangeStart, rangeEnd;
        if (viewRound != null) {
          rangeStart = FirebaseService.parseFast(viewRound['startDate'] ?? '');
          rangeEnd = FirebaseService.parseFast(viewRound['endDate'] ?? '');
        }

        // 🔥 กรองข้อมูลตามบทบาทและรอบงบประมาณแบบรวดเร็วครับ
        final List<Map<String, dynamic>> leaves = [];
        Map<String, int> typeCountMap = {};
        for (var t in dynamicLeaveTypes) {
          typeCountMap[t] = 0;
        }
        int pendingCount = 0;
        int approvedCount = 0;

        for (var l in allData) {
          // 🛡️ กรองตามบทบาท: เฉพาะผู้ดูแลระบบและผู้บริหารเท่านั้นที่จะเห็นข้อมูลทั้งหมด นอกนั้นเห็นเฉพาะของตัวเองครับ 🥇🏆
          bool isAdmin = _userRole.contains('ผู้ดูแลระบบ') ||
              _userRole.contains('ผู้บริหาร');
          if (!isAdmin && l['fullName'] != _currentUser) continue;

          // 🛡️ กรองตามงบประมาณ
          if (rangeStart != null && rangeEnd != null) {
            final startDateStr = (l['startDate'] ?? '').toString();
            final leaveDate = FirebaseService.parseFast(startDateStr);

            if (leaveDate == null) continue;
            if (leaveDate.isBefore(rangeStart) || leaveDate.isAfter(rangeEnd))
              continue;
          }

          // ✅ ข้อมูลผ่านการกรองแล้ว เก็บลง List และคำนวณสถิติพร้อมกันเลยครับ
          leaves.add(l);

          String status = (l['status'] ?? '').toString();
          String type = (l['leaveType'] ?? '').toString();

          // 🛡️ ทำการ Normalize ประเภทการลาเพื่อให้ข้อมูลที่ใกล้เคียงกันถูกนับรวมกันครับ 🥇🏆
          String normalizedType = type;
          // ตรวจสอบกับลิสต์จาก DB
          for (var dbType in dynamicLeaveTypes) {
            if (type == dbType ||
                type.contains(dbType) ||
                dbType.contains(type)) {
              normalizedType = dbType;
              break;
            }
          }

          if (status.contains('รอ') || status.contains('พิจารณา'))
            pendingCount++;
          else if (status.contains('อนุญาต') ||
              status.contains('อนุมัติ') ||
              status.contains('ส่งใบลาแล้ว') ||
              status.contains('ส่งใบแล้ว')) approvedCount++;

          typeCountMap[normalizedType] =
              (typeCountMap[normalizedType] ?? 0) + 1;
        }

        leaves.sort(FirebaseService.compareLeaveRecency);
        int totalAll = leaves.length;

        return SizedBox.expand(
          child: Container(
            color: const Color(0xFFF1F5F9),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(
                      isMobile, viewRound, allRounds, currentActiveRound),
                  const SizedBox(height: 32),
                  if (allRounds.isEmpty)
                    _buildNoBudgetWarning()
                  else ...[
                    _buildStatsGrid(isMobile, totalAll, typeCountMap,
                        pendingCount, approvedCount),
                    const SizedBox(height: 32),
                    _buildMiddleSection(
                        isMobile, typeCountMap, totalAll, leaves),
                  ],
                  // 🕵️‍♂️ เพิ่มพ่วงพื้นที่ด้านล่างเล็กน้อยกันโดนบังครับ
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFullScreenLoading() {
    return SizedBox.expand(
      child: Container(
        color: const Color(0xFFF1F5F9),
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
                ),
              ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 40,
                        offset: const Offset(0, 10)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: Color(0xFF0F172A),
                      strokeWidth: 3,
                      backgroundColor: Color(0xFFE2E8F0),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'กำลังประมวลผลสรุปข้อมูล...',
                      style: GoogleFonts.sarabun(
                        fontSize: 16,
                        color: const Color(0xFF1E293B),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'กรุณารอสักครู่ ระบบกำลังจัดสรรสถิติให้คุณครับ',
                      style: GoogleFonts.sarabun(
                          fontSize: 12, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile, Map<String, dynamic>? selectedRound,
      List<Map<String, dynamic>> allRounds, Map<String, dynamic>? activeRound) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 16,
        children: [
          if (allRounds.isNotEmpty)
            Container(
              width: isMobile ? double.infinity : 280,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.withOpacity(0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: () {
                  final String? currentId =
                      (selectedRound?['id'] ?? activeRound?['id'])?.toString();
                  final String? safeValue =
                      allRounds.any((r) => r['id'].toString() == currentId)
                          ? currentId
                          : (allRounds.isNotEmpty
                              ? allRounds.first['id'].toString()
                              : null);

                  return DropdownButton<String>(
                    value: safeValue,
                    icon: const Icon(Icons.calendar_today_outlined,
                        size: 16, color: Colors.indigo),
                    isExpanded: true,
                    dropdownColor: const Color(0xFFF8FAFC),
                    selectedItemBuilder: (BuildContext context) {
                      return allRounds.map<Widget>((round) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "ปี ${round['year']} รอบที่ ${round['round']}",
                            style: GoogleFonts.sarabun(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList();
                    },
                    items: allRounds.map((round) {
                      bool isCurrent = round['id'] == activeRound?['id'];
                      String dateRange = "ไม่ระบุช่วงวันที่";
                      if (round['startDate'] != null &&
                          round['endDate'] != null &&
                          round['startDate'].toString().isNotEmpty &&
                          round['endDate'].toString().isNotEmpty) {
                        dateRange =
                            "${FirebaseService.formatThaiDate(round['startDate'])} - ${FirebaseService.formatThaiDate(round['endDate'])}";
                      }

                      return DropdownMenuItem<String>(
                        value: round['id'].toString(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      "ปี ${round['year']} รอบที่ ${round['round']}",
                                      style: GoogleFonts.sarabun(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo),
                                    ),
                                    if (isCurrent) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius:
                                                BorderRadius.circular(4)),
                                        child: Text("ปัจจุบัน",
                                            style: GoogleFonts.sarabun(
                                                fontSize: 10,
                                                color: Colors.white)),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  dateRange,
                                  style: GoogleFonts.sarabun(
                                      fontSize: 11,
                                      color: Colors.indigo.withOpacity(0.6)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedRound = allRounds
                              .firstWhere((r) => r['id'].toString() == val);
                        });
                      }
                    },
                  );
                }(),
              ),
            ),
          ElevatedButton.icon(
            onPressed: () {
              if (widget.onNavigate != null) widget.onNavigate!(2);
            },
            icon: const Icon(Icons.add, size: 18),
            label: Text('สร้างใบลาใหม่',
                style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(bool isMobile, int totalAll,
      Map<String, int> typeCountMap, int pend, int apprv) {
    return LayoutBuilder(builder: (context, constraints) {
      int crossAxisCount = isMobile ? 2 : 3;
      double aspectRatio = isMobile ? 1.4 : 4.2;
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: aspectRatio,
        children: [
          _buildCounterCard('การลาทั้งหมด', totalAll.toString(), 'รายการรวม',
              Icons.summarize_outlined, const Color(0xFFEFF6FF), Colors.blue,
              isMobile: isMobile),

          // 🏗️ สร้างบัตรตามประเภทการลาในฐานข้อมูลจริงครับ 🥇🏆
          ...typeCountMap.entries.map((e) {
            IconData icon = Icons.description_outlined;
            Color color = Colors.blueGrey;

            if (e.key.contains('ป่วย')) {
              icon = Icons.health_and_safety_outlined;
              color = Colors.red;
            } else if (e.key.contains('กิจ')) {
              icon = Icons.assignment_ind_outlined;
              color = Colors.amber;
            } else if (e.key.contains('คลอด')) {
              icon = Icons.child_care_rounded;
              color = Colors.purple;
            } else if (e.key.contains('พักผ่อน')) {
              icon = Icons.beach_access_rounded;
              color = Colors.teal;
            }

            return _buildCounterCard(e.key, e.value.toString(), 'รายการ', icon,
                color.withOpacity(0.05), color,
                isMobile: isMobile);
          }).toList(),

          _buildCounterCard(
              'รออนุมัติ',
              pend.toString(),
              'รอดำเนินการ',
              Icons.hourglass_empty_rounded,
              const Color(0xFFFFF7ED),
              Colors.orange,
              isWarning: pend > 0,
              isMobile: isMobile),
          _buildCounterCard(
              'อนุมัติแล้ว',
              apprv.toString(),
              'เสร็จสิ้น',
              Icons.check_circle_outline_rounded,
              const Color(0xFFF0FDF4),
              Colors.green,
              isMobile: isMobile),
        ],
      );
    });
  }

  Widget _buildMiddleSection(bool isMobile, Map<String, int> typeMap, int total,
      List<Map<String, dynamic>> leaves) {
    if (isMobile) {
      return Column(children: [
        _buildChartCard(typeMap, total.toDouble()),
        const SizedBox(height: 24),
        _buildHistoryCard(leaves, isMobile: true)
      ]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 4, child: _buildHistoryCard(leaves)),
        const SizedBox(width: 24),
        Expanded(flex: 6, child: _buildChartCard(typeMap, total.toDouble())),
      ],
    );
  }

  Widget _buildNoBudgetWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20)
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.orange.shade50, shape: BoxShape.circle),
            child: Icon(Icons.warning_amber_rounded,
                size: 64, color: Colors.orange.shade700),
          ),
          const SizedBox(height: 24),
          Text('ยังไม่มีการกำหนดรอบงบประมาณ',
              style: GoogleFonts.sarabun(
                  fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            'กรุณาไปที่เมนู "จัดการระบบ" -> แท็บ "ปีงบประมาณ"\nเพื่อกำหนดช่วงเวลาและเปิดใช้งานรอบงบประมาณที่ต้องการสรุปผลครับ',
            textAlign: TextAlign.center,
            style: GoogleFonts.sarabun(
                fontSize: 15, color: Colors.blueGrey, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterCard(String title, String val, String sub, IconData icon,
      Color bgColor, Color mainColor,
      {bool isWarning = false, bool isMobile = false}) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
        border: Border.all(color: mainColor.withOpacity(0.1), width: 1.5),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -5,
            bottom: -5,
            child: Icon(icon,
                size: isMobile ? 40 : 50, color: mainColor.withOpacity(0.05)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: mainColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, size: 16, color: mainColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.sarabun(
                          fontSize: isMobile ? 12 : 14,
                          color: Colors.blueGrey,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 📏 ปรับขนาดตัวเลขลงบนมือถือ เพื่อประหยัดพื้นที่แนวตั้งครับ 🥇
                  Text(val,
                      style: GoogleFonts.sarabun(
                          fontSize: isMobile ? 28 : 38,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B))),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text(sub,
                          style: GoogleFonts.sarabun(
                              fontSize: isMobile ? 10 : 13,
                              color: Colors.blueGrey),
                          overflow: TextOverflow.ellipsis)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(Map<String, dynamic> typeMap, double totalCount) {
    final List<Color> chartColors = [
      const Color(0xFF0F172A),
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
    ];

    return Container(
      height: 480,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_outline,
                  size: 20, color: Colors.black45),
              const SizedBox(width: 12),
              Text('สัดส่วนจำนวนครั้งการลา',
                  style: GoogleFonts.sarabun(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          Expanded(
            child: totalCount == 0
                ? Center(
                    child: Text('ยังไม่มีข้อมูลการลา',
                        style: GoogleFonts.sarabun(color: Colors.grey)))
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 100,
                          sections: typeMap.entries.map((e) {
                            int index = typeMap.keys.toList().indexOf(e.key);
                            double value = 0;
                            if (e.value is int)
                              value = e.value.toDouble();
                            else if (e.value is double) value = e.value;

                            return PieChartSectionData(
                              color: chartColors[index % chartColors.length],
                              value: value,
                              title: '',
                              radius: 35,
                            );
                          }).toList(),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('รวม (ครั้ง)',
                              style: GoogleFonts.sarabun(
                                  fontSize: 12, color: Colors.blueGrey)),
                          Text(totalCount.toInt().toString(),
                              style: GoogleFonts.sarabun(
                                  fontSize: 32, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
          ),
          if (typeMap.isNotEmpty)
            Center(
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: typeMap.entries.map((e) {
                  int index = typeMap.keys.toList().indexOf(e.key);
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: chartColors[index % chartColors.length],
                              shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('${e.key} (${e.value} ครั้ง)',
                          style: GoogleFonts.sarabun(
                              fontSize: 11, color: Colors.black54)),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(List<Map<String, dynamic>> leaves,
      {bool isMobile = false}) {
    return Container(
      height: 480,
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_toggle_off_rounded,
                      size: 20, color: Colors.teal),
                  const SizedBox(width: 12),
                  Text('ประวัติล่าสุด',
                      style: GoogleFonts.sarabun(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              InkWell(
                onTap: () {
                  if (widget.onNavigate != null) {
                    widget.onNavigate!(3);
                  }
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text('ดูทั้งหมด',
                      style: GoogleFonts.sarabun(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: leaves.isEmpty
                ? Center(
                    child: Text('ยังไม่มีประวัติการลา',
                        style: GoogleFonts.sarabun(color: Colors.grey)))
                : ListView.builder(
                    itemCount: leaves.length > 5 ? 5 : leaves.length,
                    itemBuilder: (context, index) {
                      final item = leaves[index];
                      String dateRange =
                          '${FirebaseService.formatThaiDate(item['startDate'])} - ${FirebaseService.formatThaiDate(item['endDate'])}';

                      return _buildHistoryItem(
                        item['fullName']?.toString() ?? 'ไม่ระบุชื่อ',
                        'ครู',
                        FirebaseService.leaveTypeWithHalfDay(item),
                        '${FirebaseService.formatLeaveDayCount(item['days'] ?? item['totalDays'] ?? 0)} วัน',
                        dateRange,
                        item['reason']?.toString() ?? '',
                        item['status']?.toString() ?? 'ส่งใบลาแล้ว',
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(String name, String pos, String type, String days,
      String date, String reason, String status) {
    Color statusBg = const Color(0xFFDCFCE7);
    Color statusText = Colors.teal;
    if (status.contains('รอ')) {
      statusBg = Colors.orange.shade50;
      statusText = Colors.orange.shade700;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.02)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_pin_rounded,
                  size: 24, color: Colors.blueGrey),
              const SizedBox(width: 12),
              // 🔥 ใช้ Expanded ตรงนี้เพื่อแก้ปัญหา Right Overflow ครับ 🥇🏆
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // 🛡️ ใส่ Flexible เพื่อให้ชื่อไม่ล้นไปเบียดสถานะครับ
                        Flexible(
                          child: Text(
                            name,
                            style: GoogleFonts.sarabun(
                                fontSize: 13, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(pos,
                              style: const TextStyle(
                                  fontSize: 7, color: Colors.black54)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(type,
                            style: GoogleFonts.sarabun(
                                fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        Text(days,
                            style: GoogleFonts.sarabun(
                                fontSize: 11,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 🛡️ สถานะการลา
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: statusBg, borderRadius: BorderRadius.circular(20)),
                child: Text(status,
                    style: TextStyle(
                        fontSize: 9,
                        color: statusText,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          // 📅 วันที่ลา (นำกลับมาแสดงผลครับ)
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 4),
            child: Text(date,
                style: const TextStyle(fontSize: 10, color: Colors.black26)),
          ),
        ],
      ),
    );
  }
}
