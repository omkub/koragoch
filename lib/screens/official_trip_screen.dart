import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firebase_service.dart';
import '../services/official_trip_service.dart';
import '../utils/teacher_sort.dart';
import '../widgets/thai_buddhist_calendar_widget.dart';

// ═══════════════════════════════════════════════════════════════
// หน้า "ไปราชการ / ประชุม" (เมนู 9)
//
// ครู: บันทึกการไปราชการของตัวเอง + ผู้ร่วมเดินทาง, แก้/ลบได้ระหว่าง
//      รอพิจารณา, หลังอนุมัติเขียนรายงานผลได้
// ผู้ดูแลระบบ: บันทึกแทนครู, อนุมัติ/ไม่อนุมัติ, แก้/ลบได้ทุกรายการ
//
// ปุ่มที่ซ่อน/แสดงตรงกับกติกาในฐานข้อมูล (supabase/official_trips.sql)
// ซึ่งเป็นตัวกันจริง — ถ้าฐานข้อมูลปฏิเสธ จะแสดงข้อความจาก trigger
// ═══════════════════════════════════════════════════════════════

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _line = Color(0xFFE2E8F0);
const _pageBg = Color(0xFFF1F5F9);

Color _statusColor(String status) {
  switch (status) {
    case OfficialTripService.approved:
      return const Color(0xFF16A34A);
    case OfficialTripService.rejected:
      return const Color(0xFFDC2626);
    default:
      return const Color(0xFFD97706);
  }
}

int? _asInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '');

class OfficialTripScreen extends StatefulWidget {
  const OfficialTripScreen({super.key});

  @override
  State<OfficialTripScreen> createState() => _OfficialTripScreenState();
}

class _OfficialTripScreenState extends State<OfficialTripScreen> {
  final _service = OfficialTripService();
  final _firebaseService = FirebaseService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _trips = [];
  List<Map<String, dynamic>> _teachers = [];
  Map<int, Map<String, dynamic>> _teacherById = {};
  Set<String> _holidays = {};
  Set<String> _workingDays = {};

  int? _myId;
  bool _isAdmin = false;

  int _fiscalYear = OfficialTripService.fiscalYearOf(DateTime.now());
  bool _onlyMine = false;
  String? _statusFilter;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('userRole') ?? '';
    final currentUser = prefs.getString('currentUser') ?? '';
    int? myId;
    try {
      final cached = prefs.getString('userFullDataJson');
      if (cached != null && cached.isNotEmpty) {
        myId = _asInt((jsonDecode(cached) as Map)['id_user']);
      }
    } catch (e) {
      debugPrint('⚠️  อ่านข้อมูลผู้ใช้จากเครื่องไม่สำเร็จ: $e');
    }
    _myId = myId;
    _isAdmin =
        role.contains('ผู้ดูแลระบบ') || currentUser == 'ผู้ดูแลระบบ';

    try {
      final results = await Future.wait([
        _firebaseService.getUsersFromSupabase(),
        _service.getSpecialDates(),
      ]);
      final teachers = sortedTeachers(
          (results[0] as List<Map<String, dynamic>>)
              .where((t) => _asInt(t['id_user']) != null));
      final special = results[1]
          as ({Set<String> holidays, Set<String> workingDays});
      if (!mounted) return;
      setState(() {
        _teachers = teachers;
        _teacherById = {for (final t in teachers) _asInt(t['id_user'])!: t};
        _holidays = special.holidays;
        _workingDays = special.workingDays;
      });
    } catch (e) {
      debugPrint('⚠️  โหลดรายชื่อบุคลากรไม่สำเร็จ: $e');
    }
    await _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final trips = await _service.getTrips(
        from: OfficialTripService.fiscalYearStart(_fiscalYear),
        to: OfficialTripService.fiscalYearEnd(_fiscalYear),
      );
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = OfficialTripService.errorMessage(e);
        _loading = false;
      });
    }
  }

  // ─── สิทธิ์บนหน้าจอ (ตรงกับ trigger ในฐานข้อมูล) ───────────────

  bool _isOwner(Map<String, dynamic> t) =>
      _myId != null && _asInt(t['id_user']) == _myId;
  bool _isPending(Map<String, dynamic> t) =>
      (t['status'] ?? OfficialTripService.pending) == OfficialTripService.pending;
  bool _canEdit(Map<String, dynamic> t) =>
      _isAdmin || (_isOwner(t) && _isPending(t));
  bool _canApprove(Map<String, dynamic> t) => _isAdmin && _isPending(t);
  bool _canReport(Map<String, dynamic> t) =>
      (_isAdmin || _isOwner(t)) && t['status'] == OfficialTripService.approved;

  // ─── ตัวกรอง ───────────────────────────────────────────────

  List<Map<String, dynamic>> get _scopedTrips => _onlyMine && _myId != null
      ? _trips
          .where((t) => (t['members'] as List<int>).contains(_myId))
          .toList()
      : _trips;

  List<Map<String, dynamic>> get _visibleTrips {
    final query = _search.trim().toLowerCase();
    return _scopedTrips.where((t) {
      if (_statusFilter != null && t['status'] != _statusFilter) return false;
      if (query.isEmpty) return true;
      final haystack = [
        t['title'],
        t['organizer'],
        t['location'],
        t['docNumber'],
        ..._memberNames(t),
      ].whereType<Object>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  List<String> _memberNames(Map<String, dynamic> t) {
    final ownerId = _asInt(t['id_user']);
    final ids = [...(t['members'] as List<int>)]
      ..sort((a, b) => a == ownerId ? -1 : (b == ownerId ? 1 : 0));
    return ids
        .map((id) => (_teacherById[id]?['fullName'] ?? '').toString())
        .where((n) => n.isNotEmpty)
        .toList();
  }

  String _teacherName(dynamic id) =>
      (_teacherById[_asInt(id)]?['fullName'] ?? '-').toString();

  // ─── การกระทำ ───────────────────────────────────────────────

  Future<void> _run(Future<void> Function() action, String doneMessage) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(doneMessage), backgroundColor: Colors.green));
      await _loadTrips();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(OfficialTripService.errorMessage(e)),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _openForm([Map<String, dynamic>? trip]) async {
    if (_myId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('ไม่พบข้อมูลผู้ใช้ กรุณาออกจากระบบแล้วเข้าใหม่'),
          backgroundColor: Colors.red));
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TripFormDialog(
        service: _service,
        teachers: _teachers,
        myId: _myId!,
        isAdmin: _isAdmin,
        holidays: _holidays,
        workingDays: _workingDays,
        trip: trip,
      ),
    );
    if (saved == true) await _loadTrips();
  }

  Future<void> _confirmDelete(Map<String, dynamic> trip) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ลบรายการไปราชการ', style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
        content: Text('ลบ "${trip['title']}" ใช่ไหม? ลบแล้วกู้คืนไม่ได้',
            style: GoogleFonts.sarabun()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ลบ')),
        ],
      ),
    );
    if (ok == true) {
      await _run(() => _service.deleteTrip(_asInt(trip['id_trip'])!),
          'ลบรายการแล้ว');
    }
  }

  Future<void> _openApproval(Map<String, dynamic> trip) async {
    final noteCtrl = TextEditingController();
    final status = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('พิจารณาการไปราชการ',
            style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trip['title']?.toString() ?? '',
                  style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
              Text(
                  '${_teacherName(trip['id_user'])} · ${_dateText(trip)}',
                  style: GoogleFonts.sarabun(color: _muted)),
              const SizedBox(height: 16),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: _inputDecoration('หมายเหตุ (ไม่บังคับ)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก')),
          OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, OfficialTripService.rejected),
              child: const Text('ไม่อนุมัติ')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A)),
              onPressed: () => Navigator.pop(ctx, OfficialTripService.approved),
              child: const Text('อนุมัติ')),
        ],
      ),
    );
    final note = noteCtrl.text;
    noteCtrl.dispose();
    if (status == null) return;
    await _run(
        () => _service.setStatus(_asInt(trip['id_trip'])!,
            status: status, approverId: _myId, note: note),
        status == OfficialTripService.approved ? 'อนุมัติแล้ว' : 'บันทึกว่าไม่อนุมัติแล้ว');
  }

  Future<void> _openReport(Map<String, dynamic> trip) async {
    final ctrl =
        TextEditingController(text: trip['reportSummary']?.toString() ?? '');
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('รายงานผลการไปราชการ',
            style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: ctrl,
            maxLines: 8,
            decoration: _inputDecoration(
                'สรุปสาระสำคัญ / สิ่งที่ได้รับ / การนำไปใช้'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _ink),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('บันทึก')),
        ],
      ),
    );
    final text = ctrl.text;
    ctrl.dispose();
    if (save == true) {
      await _run(() => _service.saveReport(_asInt(trip['id_trip'])!, text),
          'บันทึกรายงานผลแล้ว');
    }
  }

  void _openDetail(Map<String, dynamic> trip) {
    final rows = <(String, String?)>[
      ('ประเภท', trip['tripType']?.toString()),
      ('วันที่', '${_dateText(trip)} (${_daysText(trip)})'),
      ('หน่วยงานที่จัด', trip['organizer']?.toString()),
      ('สถานที่',
          [trip['location'], trip['province']].whereType<Object>().join(' จ.')),
      ('หนังสืออ้างอิง', [
        trip['docNumber'],
        if (OfficialTripService.parseDate(trip['docDate']) != null)
          'ลงวันที่ ${OfficialTripService.formatThaiDate(OfficialTripService.parseDate(trip['docDate'])!)}',
      ].whereType<Object>().join(' ')),
      ('ผู้บันทึก', _teacherName(trip['id_user'])),
      ('ผู้ร่วมเดินทาง', _memberNames(trip).join(', ')),
      ('การเดินทาง', trip['travelMode']?.toString()),
      ('ค่าใช้จ่าย', [
        trip['budgetSource'],
        if (trip['estimatedCost'] != null)
          '${FirebaseService.formatLeaveDayCount(trip['estimatedCost'])} บาท',
      ].whereType<Object>().join(' · ')),
      ('หมายเหตุ', trip['note']?.toString()),
      ('สถานะ', [
        trip['status'],
        if (trip['approvedBy'] != null) 'โดย ${_teacherName(trip['approvedBy'])}',
        if ((trip['approverNote'] ?? '').toString().isNotEmpty)
          '— ${trip['approverNote']}',
      ].whereType<Object>().join(' ')),
      ('รายงานผล', trip['reportSummary']?.toString()),
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trip['title']?.toString() ?? '',
            style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (label, value) in rows)
                  if ((value ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 130,
                            child: Text(label,
                                style: GoogleFonts.sarabun(
                                    color: _muted,
                                    fontWeight: FontWeight.w600)),
                          ),
                          Expanded(
                              child: SelectableText(value!,
                                  style: GoogleFonts.sarabun())),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ปิด')),
        ],
      ),
    );
  }

  // ─── แสดงผล ─────────────────────────────────────────────────

  String _dateText(Map<String, dynamic> t) {
    final start = OfficialTripService.parseDate(t['startDate']);
    final end = OfficialTripService.parseDate(t['endDate']);
    if (start == null || end == null) return '-';
    var text = OfficialTripService.formatThaiRange(start, end);
    if (t['isHalfDay'] == true) {
      text += t['halfDayPeriod'] == 'afternoon' ? ' (บ่าย)' : ' (เช้า)';
    }
    return text;
  }

  String _daysText(Map<String, dynamic> t) =>
      '${FirebaseService.formatLeaveDayCount(t['totalDays'] ?? 0)} วัน';

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 1100;
    final visible = _visibleTrips;

    return Container(
      color: _pageBg,
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isMobile),
          const SizedBox(height: 20),
          _buildFilters(),
          const SizedBox(height: 16),
          Expanded(child: _buildBody(visible)),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ไปราชการ / ประชุม',
                  style: GoogleFonts.sarabun(
                      fontSize: isMobile ? 22 : 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              Text('ปีงบประมาณ $_fiscalYear · ไม่นับเป็นวันลา',
                  style: GoogleFonts.sarabun(fontSize: 13, color: _muted)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'โหลดข้อมูลใหม่',
          onPressed: _loading ? null : _loadTrips,
          icon: const Icon(Icons.refresh_rounded, color: _muted),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _ink,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text('บันทึกไปราชการ',
              style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    final scoped = _scopedTrips;
    int count(String? status) => status == null
        ? scoped.length
        : scoped.where((t) => t['status'] == status).length;
    final thisYear = OfficialTripService.fiscalYearOf(DateTime.now());

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _box(DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _fiscalYear,
            style: GoogleFonts.sarabun(color: _ink, fontWeight: FontWeight.w600),
            items: [
              for (var y = thisYear + 1; y >= thisYear - 4; y--)
                DropdownMenuItem(value: y, child: Text('ปีงบประมาณ $y')),
            ],
            onChanged: (y) {
              if (y == null || y == _fiscalYear) return;
              setState(() => _fiscalYear = y);
              _loadTrips();
            },
          ),
        )),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('ทั้งโรงเรียน')),
            ButtonSegment(value: true, label: Text('ของฉัน')),
          ],
          selected: {_onlyMine},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _onlyMine = s.first),
        ),
        for (final status in [
          null,
          OfficialTripService.pending,
          OfficialTripService.approved,
          OfficialTripService.rejected,
        ])
          ChoiceChip(
            label: Text('${status ?? 'ทั้งหมด'} (${count(status)})',
                style: GoogleFonts.sarabun(fontSize: 13)),
            selected: _statusFilter == status,
            onSelected: (_) => setState(() => _statusFilter = status),
          ),
        SizedBox(
          width: 260,
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: _inputDecoration('ค้นหาเรื่อง / สถานที่ / ชื่อ',
                icon: Icons.search_rounded),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> visible) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text('โหลดข้อมูลไม่สำเร็จ: $_error',
                textAlign: TextAlign.center,
                style: GoogleFonts.sarabun(color: Colors.red)),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadTrips, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }
    if (visible.isEmpty) {
      return Center(
        child: Text(
            _trips.isEmpty
                ? 'ยังไม่มีการไปราชการในปีงบประมาณ $_fiscalYear'
                : 'ไม่พบรายการที่ตรงกับตัวกรอง',
            style: GoogleFonts.sarabun(color: _muted, fontSize: 15)),
      );
    }
    return ListView.separated(
      itemCount: visible.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildTripCard(visible[i]),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final start = OfficialTripService.parseDate(trip['startDate']);
    final status = (trip['status'] ?? OfficialTripService.pending).toString();
    final names = _memberNames(trip);
    final place = [trip['organizer'], trip['location']]
        .where((v) => (v ?? '').toString().trim().isNotEmpty)
        .join(' · ');
    final hasReport = (trip['reportSummary'] ?? '').toString().isNotEmpty;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetail(trip),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // วันที่เริ่ม
              Container(
                width: 64,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _line),
                ),
                child: Column(
                  children: [
                    Text(start == null ? '-' : '${start.day}',
                        style: GoogleFonts.sarabun(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _ink)),
                    Text(
                        start == null
                            ? ''
                            : OfficialTripService.formatThaiDate(start)
                                .split(' ')[1],
                        style: GoogleFonts.sarabun(fontSize: 12, color: _muted)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(trip['title']?.toString() ?? '',
                            style: GoogleFonts.sarabun(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _ink)),
                        _tag(trip['tripType']?.toString() ?? '',
                            const Color(0xFF2563EB)),
                        _tag(status, _statusColor(status)),
                        if (hasReport)
                          _tag('รายงานผลแล้ว', const Color(0xFF7C3AED)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${_dateText(trip)} · ${_daysText(trip)}',
                        style: GoogleFonts.sarabun(
                            fontSize: 13, color: _ink)),
                    if (place.isNotEmpty)
                      Text(place,
                          style:
                              GoogleFonts.sarabun(fontSize: 13, color: _muted)),
                    if (names.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.groups_rounded,
                                size: 16, color: _muted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                names.length <= 3
                                    ? names.join(', ')
                                    : '${names.take(3).join(', ')} และอีก ${names.length - 3} คน',
                                style: GoogleFonts.sarabun(
                                    fontSize: 13, color: _muted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              _buildActions(trip),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(Map<String, dynamic> trip) {
    final items = <PopupMenuEntry<String>>[
      if (_canApprove(trip))
        _menuItem('approve', Icons.fact_check_rounded, 'พิจารณาอนุมัติ'),
      if (_canReport(trip))
        _menuItem('report', Icons.edit_note_rounded, 'รายงานผล'),
      if (_canEdit(trip)) _menuItem('edit', Icons.edit_rounded, 'แก้ไข'),
      if (_canEdit(trip))
        _menuItem('delete', Icons.delete_outline_rounded, 'ลบ',
            color: Colors.red),
    ];
    if (items.isEmpty) return const SizedBox(width: 40);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: _muted),
      itemBuilder: (_) => items,
      onSelected: (action) {
        switch (action) {
          case 'approve':
            _openApproval(trip);
          case 'report':
            _openReport(trip);
          case 'edit':
            _openForm(trip);
          case 'delete':
            _confirmDelete(trip);
        }
      },
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label,
      {Color color = _ink}) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.sarabun(color: color)),
      ]),
    );
  }

  Widget _tag(String text, Color color) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: GoogleFonts.sarabun(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _box(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line),
        ),
        child: child,
      );
}

InputDecoration _inputDecoration(String label, {IconData? icon}) {
  return InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.sarabun(color: _muted, fontSize: 14),
    prefixIcon: icon == null ? null : Icon(icon, size: 20, color: _muted),
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _line)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _line)),
  );
}

// ═══════════════════════════════════════════════════════════════
// ฟอร์มบันทึก / แก้ไข
// ═══════════════════════════════════════════════════════════════

class _TripFormDialog extends StatefulWidget {
  final OfficialTripService service;
  final List<Map<String, dynamic>> teachers;
  final int myId;
  final bool isAdmin;
  final Set<String> holidays;
  final Set<String> workingDays;
  final Map<String, dynamic>? trip;

  const _TripFormDialog({
    required this.service,
    required this.teachers,
    required this.myId,
    required this.isAdmin,
    required this.holidays,
    required this.workingDays,
    this.trip,
  });

  @override
  State<_TripFormDialog> createState() => _TripFormDialogState();
}

class _TripFormDialogState extends State<_TripFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _organizer = TextEditingController();
  final _location = TextEditingController();
  final _province = TextEditingController();
  final _docNumber = TextEditingController();
  final _cost = TextEditingController();
  final _note = TextEditingController();

  late int _ownerId;
  String _tripType = OfficialTripService.tripTypes.first;
  String? _travelMode;
  String? _budgetSource;
  DateTime? _docDate;
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isHalfDay = false;
  String _halfDayPeriod = 'morning';
  final Set<int> _members = {};
  bool _saving = false;

  bool get _isEdit => widget.trip != null;
  bool get _sameDay =>
      OfficialTripService.dateKey(_startDate) ==
      OfficialTripService.dateKey(_endDate);

  num get _totalDays => OfficialTripService.countWorkingDays(
        _startDate,
        _endDate,
        halfDay: _isHalfDay && _sameDay,
        holidays: widget.holidays,
        workingDays: widget.workingDays,
      );

  @override
  void initState() {
    super.initState();
    final t = widget.trip;
    final today = DateTime.now();
    _ownerId = _asInt(t?['id_user']) ?? widget.myId;
    _startDate = OfficialTripService.parseDate(t?['startDate']) ??
        DateTime(today.year, today.month, today.day);
    _endDate = OfficialTripService.parseDate(t?['endDate']) ?? _startDate;
    if (t == null) return;

    _title.text = t['title']?.toString() ?? '';
    _organizer.text = t['organizer']?.toString() ?? '';
    _location.text = t['location']?.toString() ?? '';
    _province.text = t['province']?.toString() ?? '';
    _docNumber.text = t['docNumber']?.toString() ?? '';
    _cost.text = t['estimatedCost'] == null
        ? ''
        : FirebaseService.formatLeaveDayCount(t['estimatedCost']);
    _note.text = t['note']?.toString() ?? '';
    _tripType = OfficialTripService.tripTypes.contains(t['tripType'])
        ? t['tripType']
        : OfficialTripService.tripTypes.last;
    _travelMode = OfficialTripService.travelModes.contains(t['travelMode'])
        ? t['travelMode']
        : null;
    _budgetSource =
        OfficialTripService.budgetSources.contains(t['budgetSource'])
            ? t['budgetSource']
            : null;
    _docDate = OfficialTripService.parseDate(t['docDate']);
    _isHalfDay = t['isHalfDay'] == true;
    _halfDayPeriod =
        t['halfDayPeriod'] == 'afternoon' ? 'afternoon' : 'morning';
    _members.addAll((t['members'] as List<int>? ?? const []));
  }

  @override
  void dispose() {
    for (final c in [
      _title, _organizer, _location, _province, _docNumber, _cost, _note
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _nameOf(int id) {
    final t = widget.teachers
        .firstWhere((t) => _asInt(t['id_user']) == id, orElse: () => {});
    return (t['fullName'] ?? 'ไม่ทราบชื่อ').toString();
  }

  Future<void> _pickDate(DateTime initial, ValueChanged<DateTime> onPick) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => Center(
        child: ThaiBuddhistCalendarWidget(
          initialDate: initial,
          firstDate: DateTime(DateTime.now().year - 5),
          lastDate: DateTime(DateTime.now().year + 5),
          onDateSelected: onPick,
        ),
      ),
    );
  }

  Future<void> _pickMembers() async {
    final picked = await showDialog<Set<int>>(
      context: context,
      builder: (_) => _MemberPickerDialog(
        teachers: widget.teachers,
        selected: {..._members},
        lockedId: _ownerId,
      ),
    );
    if (picked != null) {
      setState(() => _members
        ..clear()
        ..addAll(picked));
    }
  }

  String? _clean(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final halfDay = _isHalfDay && _sameDay;
    final record = <String, dynamic>{
      'id_user': _ownerId,
      'title': _title.text.trim(),
      'tripType': _tripType,
      'organizer': _clean(_organizer),
      'location': _clean(_location),
      'province': _clean(_province),
      'docNumber': _clean(_docNumber),
      'docDate': _docDate == null ? null : OfficialTripService.dateKey(_docDate!),
      'startDate': OfficialTripService.dateKey(_startDate),
      'endDate': OfficialTripService.dateKey(_endDate),
      'isHalfDay': halfDay,
      'halfDayPeriod': halfDay ? _halfDayPeriod : null,
      'totalDays': _totalDays,
      'travelMode': _travelMode,
      'budgetSource': _budgetSource,
      'estimatedCost': num.tryParse(_cost.text.replaceAll(',', '').trim()),
      'note': _clean(_note),
    };

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await widget.service.updateTrip(
          _asInt(widget.trip!['id_trip'])!,
          record,
          ownerId: _ownerId,
          oldMemberIds: widget.trip!['members'] as List<int>,
          memberIds: _members,
        );
      } else {
        await widget.service.createTrip(record, _members);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEdit ? 'บันทึกการแก้ไขแล้ว' : 'บันทึกการไปราชการแล้ว'),
          backgroundColor: Colors.green));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(OfficialTripService.errorMessage(e)),
          backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = [
      _ownerId,
      ..._members.where((id) => id != _ownerId),
    ];

    return Dialog(
      backgroundColor: _pageBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                          _isEdit ? 'แก้ไขการไปราชการ' : 'บันทึกการไปราชการ',
                          style: GoogleFonts.sarabun(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                        onPressed:
                            _saving ? null : () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.isAdmin) ...[
                        _section('ผู้ขอไปราชการ'),
                        DropdownButtonFormField<int>(
                          initialValue: _ownerId,
                          isExpanded: true,
                          decoration: _inputDecoration('บันทึกในนามของ'),
                          items: [
                            for (final t in widget.teachers)
                              DropdownMenuItem(
                                  value: _asInt(t['id_user']),
                                  child: Text(t['fullName'].toString(),
                                      style: GoogleFonts.sarabun())),
                          ],
                          onChanged: _isEdit
                              ? null
                              : (id) {
                                  if (id == null) return;
                                  setState(() {
                                    _members.remove(_ownerId);
                                    _ownerId = id;
                                  });
                                },
                        ),
                        const SizedBox(height: 16),
                      ],
                      _section('เรื่องที่ไป'),
                      TextFormField(
                        controller: _title,
                        decoration:
                            _inputDecoration('เรื่อง เช่น ประชุมผู้บริหารสถานศึกษา *'),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'กรุณากรอกเรื่องที่ไปราชการ'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _row([
                        DropdownButtonFormField<String>(
                          initialValue: _tripType,
                          decoration: _inputDecoration('ประเภท'),
                          items: [
                            for (final v in OfficialTripService.tripTypes)
                              DropdownMenuItem(value: v, child: Text(v)),
                          ],
                          onChanged: (v) =>
                              setState(() => _tripType = v ?? _tripType),
                        ),
                        TextFormField(
                            controller: _organizer,
                            decoration: _inputDecoration('หน่วยงานที่จัด')),
                      ]),
                      const SizedBox(height: 12),
                      _row([
                        TextFormField(
                            controller: _location,
                            decoration: _inputDecoration('สถานที่')),
                        TextFormField(
                            controller: _province,
                            decoration: _inputDecoration('จังหวัด')),
                      ]),
                      const SizedBox(height: 12),
                      _row([
                        TextFormField(
                            controller: _docNumber,
                            decoration:
                                _inputDecoration('เลขที่หนังสือเชิญ / คำสั่ง')),
                        _dateField(
                          'ลงวันที่ (หนังสือ)',
                          _docDate,
                          () => _pickDate(_docDate ?? DateTime.now(),
                              (d) => setState(() => _docDate = d)),
                          onClear: _docDate == null
                              ? null
                              : () => setState(() => _docDate = null),
                        ),
                      ]),
                      const SizedBox(height: 20),
                      _section('วันที่ไปราชการ'),
                      _row([
                        _dateField(
                          'วันเริ่ม *',
                          _startDate,
                          () => _pickDate(_startDate, (d) {
                            setState(() {
                              _startDate = d;
                              if (_endDate.isBefore(d)) _endDate = d;
                            });
                          }),
                        ),
                        _dateField(
                          'วันสิ้นสุด *',
                          _endDate,
                          () => _pickDate(_endDate, (d) {
                            setState(() {
                              _endDate = d.isBefore(_startDate) ? _startDate : d;
                            });
                          }),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (_sameDay) ...[
                            FilterChip(
                              label: const Text('ครึ่งวัน'),
                              selected: _isHalfDay,
                              onSelected: (v) => setState(() => _isHalfDay = v),
                            ),
                            if (_isHalfDay)
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                      value: 'morning', label: Text('เช้า')),
                                  ButtonSegment(
                                      value: 'afternoon', label: Text('บ่าย')),
                                ],
                                selected: {_halfDayPeriod},
                                showSelectedIcon: false,
                                onSelectionChanged: (s) =>
                                    setState(() => _halfDayPeriod = s.first),
                              ),
                          ],
                          Text(
                            'รวม ${FirebaseService.formatLeaveDayCount(_totalDays)} วันทำการ',
                            style: GoogleFonts.sarabun(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF16A34A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _section('ผู้ร่วมเดินทาง (${members.length} คน)'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final id in members)
                            InputChip(
                              label: Text(_nameOf(id),
                                  style: GoogleFonts.sarabun(fontSize: 13)),
                              onDeleted: id == _ownerId
                                  ? null
                                  : () => setState(() => _members.remove(id)),
                            ),
                          ActionChip(
                            avatar: const Icon(Icons.person_add_alt_1_rounded,
                                size: 18),
                            label: const Text('เพิ่มผู้ร่วมเดินทาง'),
                            onPressed: _pickMembers,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _section('การเดินทาง / ค่าใช้จ่าย'),
                      _row([
                        DropdownButtonFormField<String>(
                          initialValue: _travelMode,
                          decoration: _inputDecoration('เดินทางโดย'),
                          items: [
                            for (final v in OfficialTripService.travelModes)
                              DropdownMenuItem(value: v, child: Text(v)),
                          ],
                          onChanged: (v) => setState(() => _travelMode = v),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _budgetSource,
                          decoration: _inputDecoration('ค่าใช้จ่าย'),
                          items: [
                            for (final v in OfficialTripService.budgetSources)
                              DropdownMenuItem(value: v, child: Text(v)),
                          ],
                          onChanged: (v) => setState(() => _budgetSource = v),
                        ),
                        TextFormField(
                          controller: _cost,
                          decoration: _inputDecoration('ประมาณการ (บาท)'),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                          ],
                        ),
                      ]),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _note,
                        maxLines: 2,
                        decoration: _inputDecoration('หมายเหตุ'),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _saving ? null : () => Navigator.pop(context, false),
                      child: const Text('ยกเลิก'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _ink,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                      ),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded, size: 18),
                      label: Text(_isEdit ? 'บันทึกการแก้ไข' : 'บันทึก',
                          style:
                              GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: GoogleFonts.sarabun(
                fontSize: 14, fontWeight: FontWeight.bold, color: _muted)),
      );

  /// วางช่องเรียงกันในแนวนอน (จอแคบเรียงลงมาแทน)
  Widget _row(List<Widget> children) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 520) {
        return Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: children[i]),
          ],
        ],
      );
    });
  }

  Widget _dateField(String label, DateTime? value, VoidCallback onTap,
      {VoidCallback? onClear}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _inputDecoration(label, icon: Icons.event_rounded).copyWith(
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: onClear),
        ),
        child: Text(
            value == null ? '' : OfficialTripService.formatThaiDate(value),
            style: GoogleFonts.sarabun(fontSize: 14)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// เลือกผู้ร่วมเดินทาง (ค้นหาได้)
// ═══════════════════════════════════════════════════════════════

class _MemberPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> teachers;
  final Set<int> selected;
  final int lockedId;

  const _MemberPickerDialog({
    required this.teachers,
    required this.selected,
    required this.lockedId,
  });

  @override
  State<_MemberPickerDialog> createState() => _MemberPickerDialogState();
}

class _MemberPickerDialogState extends State<_MemberPickerDialog> {
  late final Set<int> _selected = {...widget.selected, widget.lockedId};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final list = widget.teachers.where((t) {
      if (q.isEmpty) return true;
      return '${t['fullName']} ${departmentOf(t)}'.toLowerCase().contains(q);
    }).toList();

    return AlertDialog(
      title: Text('เลือกผู้ร่วมเดินทาง (${_selected.length} คน)',
          style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 460,
        height: 480,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: _inputDecoration('ค้นหาชื่อ / กลุ่มสาระ',
                  icon: Icons.search_rounded),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final t = list[i];
                  final id = _asInt(t['id_user'])!;
                  final locked = id == widget.lockedId;
                  return CheckboxListTile(
                    dense: true,
                    value: _selected.contains(id),
                    onChanged: locked
                        ? null
                        : (v) => setState(() =>
                            v == true ? _selected.add(id) : _selected.remove(id)),
                    title: Text(t['fullName'].toString(),
                        style: GoogleFonts.sarabun(fontSize: 14)),
                    subtitle: Text(
                        locked ? 'ผู้ขอไปราชการ' : departmentOf(t),
                        style: GoogleFonts.sarabun(fontSize: 12)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก')),
        FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _ink),
            onPressed: () => Navigator.pop(context, _selected),
            child: const Text('ตกลง')),
      ],
    );
  }
}
