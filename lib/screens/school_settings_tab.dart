/// แท็บ "ข้อมูลโรงเรียน" ในหน้าจัดการระบบ
///
/// ข้อมูลนี้ไปปรากฏบนหัวใบลาราชการทุกใบ ทั้งบนจอและตอนพิมพ์
/// เดิมต้องแก้ผ่าน SQL เท่านั้น
///
/// หมายเหตุ: คอลัมน์ `fullName` ในฐานข้อมูลเป็นคอลัมน์ที่คำนวณเอง
/// (namePart1 + namePart2) เขียนทับตรง ๆ ไม่ได้ จึงมีแต่ช่องกรอกสองท่อน
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/school_info.dart';

class SchoolSettingsTab extends StatefulWidget {
  const SchoolSettingsTab({super.key});

  @override
  State<SchoolSettingsTab> createState() => _SchoolSettingsTabState();
}

class _SchoolSettingsTabState extends State<SchoolSettingsTab> {
  final _namePart1 = TextEditingController();
  final _namePart2 = TextEditingController();
  final _address = TextEditingController();
  final _affiliation = TextEditingController();
  final _province = TextEditingController();
  final _district = TextEditingController();

  int? _idSchool;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _namePart1.dispose();
    _namePart2.dispose();
    _address.dispose();
    _affiliation.dispose();
    _province.dispose();
    _district.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final rows = await Supabase.instance.client
          .from('Schools')
          .select()
          .order('id_school')
          .limit(1)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      if (rows.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'ยังไม่มีข้อมูลโรงเรียนในระบบ';
        });
        return;
      }

      final row = Map<String, dynamic>.from(rows.first);
      setState(() {
        _idSchool = int.tryParse(row['id_school']?.toString() ?? '');
        _namePart1.text = (row['namePart1'] ?? '').toString();
        _namePart2.text = (row['namePart2'] ?? '').toString();
        _address.text = (row['address'] ?? '').toString();
        _affiliation.text = (row['affiliation'] ?? '').toString();
        _province.text = (row['province'] ?? '').toString();
        _district.text = (row['district'] ?? '').toString();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'โหลดข้อมูลไม่สำเร็จ: $e';
      });
    }
  }

  Future<void> _save() async {
    if (_idSchool == null) return;

    if (_namePart1.text.trim().isEmpty) {
      _toast('กรุณากรอกชื่อโรงเรียน', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      // ไม่ส่ง fullName ไปด้วย เพราะฐานข้อมูลคำนวณให้เองจากสองท่อน
      await Supabase.instance.client.from('Schools').update({
        'namePart1': _namePart1.text.trim(),
        'namePart2': _namePart2.text.trim(),
        'address': _address.text.trim(),
        'affiliation': _affiliation.text.trim(),
        'province': _province.text.trim(),
        'district': _district.text.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      }).eq('id_school', _idSchool as Object);

      // โหลดใหม่ทันที ใบลาที่เปิดหลังจากนี้จะได้ชื่อใหม่เลย
      await SchoolInfo.load(force: true);

      if (!mounted) return;
      setState(() => _isSaving = false);
      _toast('บันทึกข้อมูลโรงเรียนเรียบร้อยแล้วครับ ✨');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      // RLS อนุญาตให้เฉพาะผู้ดูแลระบบแก้ ถ้าสิทธิ์ไม่พอจะเข้าทางนี้
      _toast('บันทึกไม่สำเร็จ: $e', isError: true);
    }
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.sarabun()),
      backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF10B981),
    ));
  }

  /// ชื่อเต็มที่จะถูกนำไปใช้จริง คำนวณแบบเดียวกับฐานข้อมูล
  String get _previewFullName =>
      SchoolRecord.joinName(_namePart1.text.trim(), _namePart2.text.trim());

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_error!,
                style: GoogleFonts.sarabun(color: Colors.red.shade700)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text('ลองใหม่', style: GoogleFonts.sarabun()),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ข้อมูลโรงเรียน',
              style: GoogleFonts.sarabun(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text('ข้อมูลนี้แสดงบนหัวใบลาราชการทุกใบ ทั้งบนจอและตอนพิมพ์',
              style:
                  GoogleFonts.sarabun(fontSize: 13, color: Colors.blueGrey)),
          const SizedBox(height: 20),

          // แสดงชื่อเต็มที่จะได้จริง เพื่อให้เห็นผลก่อนกดบันทึก
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ชื่อเต็มที่จะใช้ในเอกสาร',
                    style: GoogleFonts.sarabun(
                        fontSize: 12, color: Colors.blueGrey)),
                const SizedBox(height: 6),
                Text(
                    _previewFullName.isEmpty
                        ? '(ยังไม่ได้กรอกชื่อ)'
                        : _previewFullName,
                    style: GoogleFonts.sarabun(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _field('ชื่อโรงเรียน (ส่วนแรก)', _namePart1,
              hint: 'เช่น โรงเรียนรมย์บุรีพิทยาคม', required: true),
          _field('สร้อยชื่อ (ส่วนหลัง)', _namePart2,
              hint: 'เช่น รัชมังคลาภิเษก — ไม่มีก็เว้นว่างได้'),
          _field('ที่อยู่', _address,
              hint: 'เช่น อำเภอบ้านด่าน จังหวัดบุรีรัมย์ 31000'),
          _field('ต้นสังกัด', _affiliation,
              hint: 'เช่น สังกัดสำนักงานเขตพื้นที่การศึกษามัธยมศึกษาบุรีรัมย์'),
          Row(
            children: [
              Expanded(child: _field('จังหวัด', _province)),
              const SizedBox(width: 16),
              Expanded(child: _field('อำเภอ', _district)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_isSaving ? 'กำลังบันทึก...' : 'บันทึกข้อมูล',
                    style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text('ยกเลิกการแก้ไข', style: GoogleFonts.sarabun()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
              '💡 แก้ไขได้เฉพาะผู้ดูแลระบบ และหน้าจออื่นจะเห็นชื่อใหม่'
              'หลังเข้าสู่ระบบครั้งถัดไป',
              style:
                  GoogleFonts.sarabun(fontSize: 12, color: Colors.blueGrey)),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      {String? hint, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(required ? '$label *' : label,
              style: GoogleFonts.sarabun(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B))),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            // อัปเดตตัวอย่างชื่อเต็มด้านบนทันทีที่พิมพ์
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.sarabun(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.sarabun(
                  fontSize: 13, color: const Color(0xFF94A3B8)),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
