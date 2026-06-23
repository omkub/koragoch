import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ประวัติการลาของคุณ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            Text('ตรวจสอบสถานะและรายละเอียดใบลาที่คุณเคยส่ง', style: TextStyle(color: Colors.blueGrey, fontSize: 13)),
          ]),
        ]),
        const SizedBox(height: 32),
        // Filter Tabs (Optional but looks premium)
        Row(children: [
          _buildFilterTab('ทั้งหมด', isActive: true),
          _buildFilterTab('รออนุมัติ'),
          _buildFilterTab('อนุมัติแล้ว'),
          _buildFilterTab('ไม่อนุมัติ'),
        ]),
        const SizedBox(height: 24),
        // History List
        Expanded(
          child: ListView(
            children: [
              _buildHistoryCard('ลาป่วย', '24 เม.ย. 2569 - 25 เม.ย. 2569 (2 วัน)', 'มีอาการไข้สูง ปวดศีรษะ', 'รออนุมัติ', const Color(0xFFF59E0B)),
              _buildHistoryCard('ลากิจ', '10 มี.ค. 2569 (1 วัน)', 'ไปติดต่อราชการที่สำนักงานเขต', 'อนุมัติแล้ว', const Color(0xFF10B981)),
              _buildHistoryCard('ลาพักผ่อน', '15 ม.ค. 2569 - 17 ม.ค. 2569 (3 วัน)', 'พักผ่อนประจำปี', 'อนุมัติแล้ว', const Color(0xFF10B981)),
              _buildHistoryCard('ลาป่วย', '05 ธ.ค. 2568 (1 วัน)', 'ท้องเสียรุนแรง', 'ไม่อนุมัติ', const Color(0xFFEF4444)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildFilterTab(String title, {bool isActive = false}) {
    return Container(margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(color: isActive ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: isActive ? Colors.transparent : Colors.black12)), child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isActive ? Colors.white : const Color(0xFF64748B))));
  }

  Widget _buildHistoryCard(String type, String date, String reason, String status, Color statusColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black12, width: 0.5)),
      child: Row(children: [
        // Icon Left
        Container(width: 56, height: 56, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)), child: Icon(Icons.description_outlined, color: const Color(0xFF1E293B), size: 28)),
        const SizedBox(width: 24),
        // Info Middle
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Text(type, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(width: 12), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)))]),
            const SizedBox(height: 6),
            Text(date, style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w500, fontSize: 13)),
            const SizedBox(height: 4),
            Text(reason, style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
          ]),
        ),
        // Action Right
        IconButton(onPressed: () {}, icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black26)),
      ]),
    );
  }
}
