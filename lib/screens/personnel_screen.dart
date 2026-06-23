import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firebase_service.dart';

class PersonnelScreen extends StatefulWidget {
  final VoidCallback? onBack; // 🔥 เพิ่ม callback สำหรับกดย้อนกลับครับ 🥇🏆
  const PersonnelScreen({super.key, this.onBack});

  @override
  State<PersonnelScreen> createState() => _PersonnelScreenState();
}

class _PersonnelScreenState extends State<PersonnelScreen> with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  TabController? _tabController;
  List<String> _currentTabs = [];

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 1100;
    
    return Material(
      color: const Color(0xFFF1F5F9),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firebaseService.getUsersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}', style: GoogleFonts.sarabun(color: Colors.black)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }

          final allUsers = snapshot.data ?? [];
          final users = allUsers.where((u) => u['fullName'] != 'ผู้ดูแลระบบ' && (u['role'] ?? u['permission']) != 'ผู้ดูแลระบบ').toList();
          
          if (users.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.people_alt_outlined, size: 64, color: Colors.black),
              const SizedBox(height: 16),
              Text('ไม่พบข้อมูลบุคลากรในระบบ', style: GoogleFonts.sarabun(color: Colors.black))
            ]));
          }

          Map<String, List<Map<String, dynamic>>> groups = {};
          for (var u in users) {
            String dept = u['department']?.toString() ?? u['กลุ่มสาระการเรียนรู้']?.toString() ?? 'อื่นๆ';
            if (!groups.containsKey(dept)) groups[dept] = [];
            groups[dept]!.add(u);
          }

          final List<String> priorityDepts = ['คณิตศาสตร์', 'วิทยาศาสตร์และเทคโนโลยี', 'ภาษาไทย', 'ภาษาต่างประเทศ', 'สังคมศึกษา ศาสนา และวัฒนธรรม', 'ศิลปะ', 'การงานอาชีพ', 'สุขศึกษาและพลศึกษา', 'ฝ่ายบริหาร', 'งานสำนักงาน'];
          final sortedDepts = groups.keys.toList()..sort((a, b) {
            int idxA = priorityDepts.indexWhere((e) => a.contains(e));
            int idxB = priorityDepts.indexWhere((e) => b.contains(e));
            if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
            if (idxA != -1) return -1;
            if (idxB != -1) return 1;
            return a.compareTo(b);
          });
          
          final finalTabs = ['รวมทั้งหมด', ...sortedDepts];
          
          // 🔥 จัดการ TabController เมื่อข้อมูลเปลี่ยนครับ 🥇🏆
          if (_tabController == null || _currentTabs.length != finalTabs.length) {
            _tabController?.dispose();
            _tabController = TabController(length: finalTabs.length, vsync: this);
            _currentTabs = finalTabs;
          }

          return Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isMobile),
                SizedBox(height: isMobile ? 16 : 32),
                
                // 📱 สำหรับมือถือ: ใช้ Dropdown / 💻 สำหรับ PC: ใช้ TabBar 🏆
                if (isMobile) 
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _tabController!.index,
                        isExpanded: true,
                        icon: const Icon(Icons.unfold_more_rounded, color: Color(0xFF64748B)),
                        style: GoogleFonts.sarabun(fontSize: 16, color: const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                        items: finalTabs.asMap().entries.map((entry) {
                          return DropdownMenuItem<int>(
                            value: entry.key,
                            child: Row(
                              children: [
                                Icon(entry.value == 'รวมทั้งหมด' ? Icons.groups_rounded : Icons.folder_rounded, size: 20, color: const Color(0xFF3B82F6)),
                                const SizedBox(width: 12),
                                Text(entry.value),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _tabController!.animateTo(val));
                        },
                      ),
                    ),
                  )
                else
                  Container(
                    height: 50,
                    margin: const EdgeInsets.only(bottom: 32),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicatorColor: Colors.transparent,
                      dividerColor: Colors.transparent,
                      labelPadding: const EdgeInsets.only(right: 12),
                      tabs: finalTabs.map((dept) {
                        final color = dept == 'รวมทั้งหมด' ? const Color(0xFF0F172A) : _getDeptColor(dept);
                        return Tab(
                          child: AnimatedBuilder(
                            animation: _tabController!,
                            builder: (context, child) {
                              final isSelected = _tabController!.index == finalTabs.indexOf(dept);
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? color.withOpacity(0.1) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isSelected ? color : Colors.grey.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(dept == 'รวมทั้งหมด' ? Icons.groups_rounded : Icons.folder_copy_rounded, size: 18, color: isSelected ? color : Colors.blueGrey),
                                    const SizedBox(width: 10),
                                    Text(dept, style: GoogleFonts.sarabun(fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? color : Colors.blueGrey)),
                                  ],
                                ),
                              );
                            }
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                if (!isMobile) const SizedBox(height: 16),

                // 🔥 รายชื่อบุคลากร (Table View) 🕵️‍♂️🏎️🏆
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const BouncingScrollPhysics(),
                    children: finalTabs.map((dept) {
                      final rawMembers = dept == 'รวมทั้งหมด' ? users : (groups[dept] ?? []);
                      final List<String> rankPriority = ['เชี่ยวชาญพิเศษ', 'เชี่ยวชาญ', 'ชำนาญการพิเศษ', 'ชำนาญการ', 'ไม่มีวิทยฐานะ'];
                      final members = List<Map<String, dynamic>>.from(rawMembers);
                      members.sort((a, b) {
                        String rankA = a['academicStanding']?.toString() ?? a['วิทยฐานะ']?.toString() ?? '';
                        String rankB = b['academicStanding']?.toString() ?? b['วิทยฐานะ']?.toString() ?? '';
                        int idxA = rankPriority.indexWhere((e) => rankA.contains(e));
                        int idxB = rankPriority.indexWhere((e) => rankB.contains(e));
                        if (idxA == -1) idxA = 99;
                        if (idxB == -1) idxB = 99;
                        if (idxA != idxB) return idxA.compareTo(idxB);
                        String nameA = a['fullName']?.toString() ?? '';
                        String nameB = b['fullName']?.toString() ?? '';
                        return nameA.compareTo(nameB);
                      });
                      final color = dept == 'รวมทั้งหมด' ? const Color(0xFF3B82F6) : _getDeptColor(dept);
                      if (members.isEmpty) return Center(child: Text('ไม่มีข้อมูลบุคลากรในกลุ่มนี้', style: GoogleFonts.sarabun(color: Colors.blueGrey)));
                      return _buildDataTable(members, color);
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Row(
      children: [
        if (widget.onBack != null) 
          IconButton(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 22),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('บุคลากรตามกลุ่มสาระ',
                style: GoogleFonts.sarabun(
                    fontSize: isMobile ? 22 : 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
          ],
        ),
        const Spacer(),
        IconButton(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh, color: Colors.black)),
      ],
    );
  }

  // 🔥 ฟังก์ชันสุ่มหรือกำหนดสีตามชื่อกลุ่มสาระครับ 🎨🏆
  Color _getDeptColor(String dept) {
    if (dept.contains('คณิตศาสตร์')) return const Color(0xFF3B82F6); // Blue
    if (dept.contains('วิทยาศาสตร์')) return const Color(0xFF10B981); // Emerald
    if (dept.contains('ภาษาไทย')) return const Color(0xFFF59E0B); // Amber
    if (dept.contains('ภาษาต่างประเทศ'))
      return const Color(0xFF8B5CF6); // Violet
    if (dept.contains('ศิลปะ')) return const Color(0xFFEC4899); // Pink
    if (dept.contains('การงานอาชีพ')) return const Color(0xFFF97316); // Orange
    if (dept.contains('สุขศึกษา')) return const Color(0xFFEF4444); // Red
    if (dept.contains('ฝ่ายบริหาร')) return const Color(0xFF0F172A); // Slate
    return const Color(0xFF64748B); // Default
  }

  // 🔥 เปลี่ยนจาก Card เป็นตารางข้อมูล (Data Table) แบบแน่นๆ ตามรูปภาพอ้างอิงครับ 🥇🏆
  Widget _buildDataTable(List<Map<String, dynamic>> members, Color baseColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.resolveWith((states) => baseColor.withOpacity(0.15)),
                    headingTextStyle: GoogleFonts.sarabun(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                    dataRowMinHeight: 60,
                    dataRowMaxHeight: 60,
                    horizontalMargin: 24,
                    columnSpacing: 32,
                    dividerThickness: 0.5,
                    border: TableBorder(
                      horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
                      verticalInside: BorderSide(color: Colors.grey.shade100, width: 1),
                    ),
                    columns: const [
                      DataColumn(label: Text('ลำดับ')),
                      DataColumn(label: Text('รูปโปรไฟล์')),
                      DataColumn(label: Text('ชื่อ-นามสกุล')),
                      DataColumn(label: Text('ตำแหน่งงานบริหาร')),
                      DataColumn(label: Text('ตำแหน่ง')),
                      DataColumn(label: Text('วิทยฐานะ')),
                      DataColumn(label: Text('กลุ่มสาระการเรียนรู้')),
                    ],
                    rows: List<DataRow>.generate(members.length, (index) {
                      final u = members[index];
                      // สร้างสีพื้นหลังสลับแถว (Zebra Striping)
                      final Color rowColor = index % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC);
                      
                      return DataRow(
                        color: MaterialStateProperty.resolveWith((states) => rowColor),
                        cells: [
                          DataCell(Text('${index + 1}', style: GoogleFonts.sarabun(fontSize: 14, color: Colors.blueGrey))),
                          DataCell(_buildTableAvatar(u, baseColor)),
                          DataCell(Text(u['fullName'] ?? '-', style: GoogleFonts.sarabun(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)))),
                          DataCell(Text(u['ตำแหน่งงานบริหาร'] == 'ไม่มีตำแหน่งบริหาร' || u['ตำแหน่งงานบริหาร'] == null ? '-' : u['ตำแหน่งงานบริหาร'], style: GoogleFonts.sarabun(fontSize: 13, color: baseColor))),
                          DataCell(_buildBadge(u['position'] ?? 'ครู', baseColor)),
                          DataCell(_buildBadge(u['academicStanding'] ?? u['วิทยฐานะ'] ?? '-', Colors.blueGrey)),
                          DataCell(Text(u['department'] ?? u['กลุ่มสาระการเรียนรู้'] ?? '-', style: GoogleFonts.sarabun(fontSize: 13, color: Colors.blueGrey.shade700))),
                        ],
                      );
                    }),
                  ),
                ),
               );
              },
             ),
            ),
           ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableAvatar(Map<String, dynamic> u, Color color) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipOval(
        child: Builder(
          builder: (context) {
            String? url = u['profileImage'];
            if (url != null && url.isNotEmpty) {
              String imgUrl = url;
              if (url.contains('drive.google.com')) {
                final regExp = RegExp(r'(?:id=|\/d\/)([a-zA-Z0-9-_]+)');
                final match = regExp.firstMatch(url);
                if (match != null) {
                  // ใช้ wsrv.nl พร็อกซีเสถียรกว่า lh3 สำหรับภาพโปรไฟล์ 🏆
                  imgUrl = 'https://wsrv.nl/?url=drive.google.com/uc%3Fid%3D${match.group(1)}';
                }
              }
              return Image.network(imgUrl, fit: BoxFit.cover, 
                errorBuilder: (c, e, s) => Center(child: Text(u['fullName']?[0] ?? '?', style: GoogleFonts.sarabun(fontSize: 16, fontWeight: FontWeight.bold, color: color)))
              );
            }
            return Center(
              child: Text(u['fullName']?[0] ?? '?', 
                style: GoogleFonts.sarabun(fontSize: 16, fontWeight: FontWeight.bold, color: color)
              ),
            );
          }
        ),
      ),
    );
  }

  Widget _buildBadge(String t, Color c) {
    if (t == '-' || t == '---เลือก---') return Text('-', style: GoogleFonts.sarabun(color: Colors.blueGrey));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(t,
          style: GoogleFonts.sarabun(
              fontSize: 12, color: c, fontWeight: FontWeight.bold)),
    );
  }
}
