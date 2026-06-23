import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_service.dart';

class MobilePasswordResetScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const MobilePasswordResetScreen({super.key, this.onBack});

  @override
  State<MobilePasswordResetScreen> createState() => _MobilePasswordResetScreenState();
}

class _MobilePasswordResetScreenState extends State<MobilePasswordResetScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;

  // 🔑 รีเซ็ตรหัสผ่านเป็น 123456 และเปิดสิทธิ์ 24 ชม. ครับ 🥇🏆
  Future<void> _approveReset(Map<String, dynamic> user) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.key_rounded, color: Colors.red, size: 22),
          const SizedBox(width: 10),
          Text('อนุมัติการรีเซ็ต?', style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          'รีเซ็ตรหัสผ่านของ\n"${user['fullName'] ?? user['username']}"\nเป็น 123456 และให้สิทธิ์ตั้งรหัสใหม่ภายใน 24 ชั่วโมงหรือไม่?',
          style: GoogleFonts.sarabun(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('ยกเลิก', style: GoogleFonts.sarabun(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('อนุมัติ', style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final DateTime expiry = DateTime.now().add(const Duration(hours: 24));
      await _firebaseService.db
          .collection('Teachers')
          .doc(user['id'])
          .update({
        'forgotPasswordStatus': 'reset_by_admin',
        'tempPassword': '123456',
        'resetAllowedUntil': expiry.toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ รีเซ็ตรหัสผ่านสำเร็จ! ให้ครูล็อกอินด้วยรหัส 123456 ครับ',
              style: GoogleFonts.sarabun(color: Colors.white)),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ เกิดข้อผิดพลาด: $e', style: GoogleFonts.sarabun()),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: widget.onBack ?? () => Navigator.pop(context),
        ),
        title: Text('จัดการรหัสผ่าน',
            style: GoogleFonts.sarabun(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firebaseService.db
            .collection('Teachers')
            .where('forgotPasswordStatus', isEqualTo: 'waiting')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, size: 64, color: Colors.green),
                    ),
                    const SizedBox(height: 24),
                    Text('ไม่มีรายการรอดำเนินการ',
                        style: GoogleFonts.sarabun(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    Text('ขณะนี้ไม่มีครูที่แจ้งลืมรหัสผ่านรอการอนุมัติครับ',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.sarabun(fontSize: 13, color: Colors.blueGrey)),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              // แถบแจ้งเตือนจำนวน
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade600, Colors.red.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'รอดำเนินการ ${docs.length} รายการ — กรุณารีเซ็ตรหัสผ่านให้ครูครับ',
                        style: GoogleFonts.sarabun(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              // รายการครูที่แจ้งลืมรหัส
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final user = {'id': doc.id, ...doc.data() as Map<String, dynamic>};
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.orange.withOpacity(0.15),
                                child: Text(
                                  (user['fullName'] ?? user['username'] ?? '?')[0],
                                  style: GoogleFonts.sarabun(
                                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(user['fullName'] ?? user['username'] ?? '-',
                                        style: GoogleFonts.sarabun(fontSize: 15, fontWeight: FontWeight.bold)),
                                    Text(user['position'] ?? 'ครู',
                                        style: GoogleFonts.sarabun(fontSize: 12, color: Colors.black54)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('รอดำเนินการ',
                                    style: GoogleFonts.sarabun(
                                        fontSize: 10, color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('กลุ่มสาระฯ',
                                        style: GoogleFonts.sarabun(fontSize: 10, color: Colors.black38)),
                                    Text(user['department'] ?? '-',
                                        style: GoogleFonts.sarabun(fontSize: 12, color: Colors.blueGrey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _approveReset(user),
                              icon: const Icon(Icons.key_rounded, size: 18),
                              label: Text('อนุมัติการรีเซ็ตรหัสผ่าน',
                                  style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 14)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
