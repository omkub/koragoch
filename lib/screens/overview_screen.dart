import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header Section
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('รายงานสรุปการลา', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            Text('ข้อมูลการลาสะสมของคุณครูทั้งหมด (SQL Professional Style)', style: TextStyle(color: Colors.blueGrey, fontSize: 13)),
          ]),
          Row(children: [
            ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.download_for_offline_rounded, size: 18), label: const Text('ไฟล์ PDF', style: TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
            const SizedBox(width: 12),
            IconButton(onPressed: () {}, icon: const Icon(Icons.refresh, size: 20), style: IconButton.styleFrom(backgroundColor: Colors.white, side: const BorderSide(color: Colors.black26, width: 1))),
          ]),
        ]),
        const SizedBox(height: 32),
        // --- ส่วนหัวตารางแบบ Manual Flex (เพิ่มเส้นหนาขึ้น) ---
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), border: Border.all(color: Colors.black26, width: 1)),
          child: Column(children: [
            // ชั้นที่ 1: ประเภทการลา
            Container(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black26, width: 1))),
              child: Row(children: [
                const Expanded(flex: 4, child: Center(child: Text(' ', style: TextStyle(fontWeight: FontWeight.bold)))),
                _buildGroupHeaderCell('ลาป่วย', flex: 2),
                _buildGroupHeaderCell('ลากิจ', flex: 2),
                _buildGroupHeaderCell('ลาคลอด', flex: 2),
                const Expanded(flex: 2, child: Center(child: Text('รวม (ครั้ง / วัน)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
              ]),
            ),
            // ชั้นที่ 2: หัวข้อย่อย
            Row(children: [
              const Expanded(flex: 4, child: Padding(padding: EdgeInsets.only(left: 24, top: 12, bottom: 12), child: Text('ชื่อ - สกุล / ตำแหน่ง', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
              _buildSubHeaderCell('ครั้ง'), _buildSubHeaderCell('วัน'),
              _buildSubHeaderCell('ครั้ง'), _buildSubHeaderCell('วัน'),
              _buildSubHeaderCell('ครั้ง'), _buildSubHeaderCell('วัน'),
              const Expanded(flex: 2, child: SizedBox()),
            ]),
          ]),
        ),
        // --- รายการข้อมูล (พร้อมเส้นแนวตั้งที่เข้มขึ้น) ---
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)), border: Border.all(color: Colors.black26, width: 1)),
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firebaseService.getUsersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('ไม่พบข้อมูล'));

                // กรองผู้ดูแลระบบออกแบบเดิมครับ
                final users = snapshot.data!.where((u) => u['position']?.toString() != 'ผู้ดูแลระบบ').toList();
                
                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1, color: Colors.black12),
                  itemBuilder: (ctx, i) {
                    final user = users[i];
                    return Row(children: [
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(user['fullName']?.toString() ?? 'ไม่ระบุชื่อ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(user['position']?.toString() ?? 'ไม่ระบุตำแหน่ง', style: const TextStyle(color: Colors.blueGrey, fontSize: 10)),
                          ]),
                        ),
                      ),
                      _buildDataCell('-'), _buildDataCell('-'),
                      _buildDataCell('-'), _buildDataCell('-'),
                      _buildDataCell('-'), _buildDataCell('-'),
                      const Expanded(flex: 2, child: Center(child: Text('0 / 0', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
                    ]);
                  },
                );
              },
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildGroupHeaderCell(String title, {int flex = 1}) {
    return Expanded(flex: flex, child: Container(height: 45, decoration: const BoxDecoration(border: Border(left: BorderSide(color: Colors.black26, width: 1), right: BorderSide(color: Colors.black26, width: 1))), child: Center(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B))))));
  }

  Widget _buildSubHeaderCell(String title) {
    return Expanded(child: Container(height: 35, decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black26, width: 1))), child: Center(child: Text(title, style: const TextStyle(fontSize: 10, color: Colors.blueGrey)))));
  }

  Widget _buildDataCell(String val) {
    return Expanded(child: Container(height: 60, decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.black12, width: 0.8))), child: Center(child: Text(val, style: const TextStyle(color: Colors.grey, fontSize: 12)))));
  }
}
