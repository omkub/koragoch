/// หน้า "ลงเวลา" (เมนู 10)
///
///   ของฉัน   ประวัติลงเวลาของตัวเองรายเดือน + ความยินยอมใช้ข้อมูลใบหน้า
///   รายวัน   ภาพรวมทั้งโรงเรียน ใครมา ใครสาย ใครยังไม่สแกน   (attendance.view_all)
///            แก้ / เพิ่ม / ยกเลิกเวลาแทน ต้องมีเหตุผล       (attendance.edit)
///   รายเดือน สรุปต่อคน + ดาวน์โหลด Excel (CSV)              (attendance.view_all)
///
/// สถานะทั้งหมดคำนวณในฐานข้อมูล (attendance_day_status) — ดู
/// supabase/attendance_daily.sql
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/attendance_service.dart';
import '../utils/web_platform.dart' as platform;

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _line = Color(0xFFE2E8F0);
const _pageBg = Color(0xFFF1F5F9);

/// สี + ไอคอนของแต่ละสถานะ
({Color fg, Color bg, IconData icon}) statusStyle(String status) =>
    switch (status) {
      'มา' => (
          fg: const Color(0xFF15803D),
          bg: const Color(0xFFDCFCE7),
          icon: Icons.check_circle_rounded
        ),
      'สาย' => (
          fg: const Color(0xFFB45309),
          bg: const Color(0xFFFEF3C7),
          icon: Icons.schedule_rounded
        ),
      'ลา' => (
          fg: const Color(0xFF1D4ED8),
          bg: const Color(0xFFDBEAFE),
          icon: Icons.event_busy_rounded
        ),
      'ไปราชการ' => (
          fg: const Color(0xFF7C3AED),
          bg: const Color(0xFFEDE9FE),
          icon: Icons.business_center_rounded
        ),
      'ขาด' => (
          fg: const Color(0xFFB91C1C),
          bg: const Color(0xFFFEE2E2),
          icon: Icons.cancel_rounded
        ),
      'ยังไม่สแกน' => (
          fg: const Color(0xFFC2410C),
          bg: const Color(0xFFFFEDD5),
          icon: Icons.hourglass_empty_rounded
        ),
      _ => (
          fg: _muted,
          bg: const Color(0xFFF1F5F9),
          icon: Icons.remove_circle_outline_rounded
        ),
    };

class AttendanceScreen extends StatefulWidget {
  /// false = ไม่แสดงชื่อหน้า (เปิดในหน้าตาใหม่บนมือถือ ซึ่งมีแถบหัวของแอปแล้ว)
  /// ยังแสดงเวลาเข้างาน / สาย / เลิกงาน
  final bool showHeader;

  const AttendanceScreen({super.key, this.showHeader = true});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _service = AttendanceService();

  bool _loading = true;
  String? _error;
  AttendanceSettingsInfo _settings = const AttendanceSettingsInfo();
  bool _viewAll = false;
  bool _canEdit = false;
  int? _myId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('userFullDataJson');
      if (cached != null && cached.isNotEmpty) {
        final id = (jsonDecode(cached) as Map)['id_user'];
        _myId = id is int ? id : int.tryParse('$id');
      }
      final results = await Future.wait([
        _service.getSettings(),
        _service.getPermissions(),
      ]);
      final perms = results[1] as ({bool viewAll, bool edit});
      if (!mounted) return;
      setState(() {
        _settings = results[0] as AttendanceSettingsInfo;
        _viewAll = perms.viewAll;
        _canEdit = perms.edit;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AttendanceService.errorMessage(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 1100;
    final pad = EdgeInsets.fromLTRB(
        isMobile ? 16 : 32, isMobile ? 12 : 32, isMobile ? 16 : 32, 0);

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = _ErrorView(message: _error!, onRetry: _init);
    } else if (!_settings.enabled) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'โรงเรียนยังไม่เปิดใช้ระบบลงเวลา\n(เปิดได้ที่ web ส่วนกลาง > ลงเวลา)',
            textAlign: TextAlign.center,
            style: GoogleFonts.sarabun(color: _muted, fontSize: 15),
          ),
        ),
      );
    } else if (!_viewAll) {
      body =
          _MyAttendanceTab(service: _service, settings: _settings, myId: _myId);
    } else {
      body = DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: _ink,
              unselectedLabelColor: _muted,
              indicatorColor: _ink,
              labelStyle: GoogleFonts.sarabun(fontWeight: FontWeight.bold),
              unselectedLabelStyle: GoogleFonts.sarabun(),
              tabs: const [
                Tab(text: 'รายวัน'),
                Tab(text: 'รายเดือน'),
                Tab(text: 'ของฉัน'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: [
                  _DailyTab(
                      service: _service,
                      settings: _settings,
                      canEdit: _canEdit),
                  _MonthlyTab(service: _service),
                  _MyAttendanceTab(
                      service: _service, settings: _settings, myId: _myId),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final content = Container(
      color: _pageBg,
      padding: pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.showHeader)
                      Text('ลงเวลา',
                          style: GoogleFonts.sarabun(
                              fontSize: isMobile ? 22 : 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black)),
                    Text(
                        'เข้างาน ${_settings.workStart} · สายหลัง ${_settings.lateAfter} · เลิกงาน ${_settings.workEnd}',
                        style:
                            GoogleFonts.sarabun(fontSize: 13, color: _muted)),
                  ],
                ),
              ),
              // มือถือ: เว้นที่ให้กระดิ่งแจ้งเตือนที่ลอยอยู่มุมขวาบน
              if (isMobile && widget.showHeader) const SizedBox(width: 48),
            ],
          ),
          SizedBox(height: isMobile ? 8 : 16),
          Expanded(child: body),
        ],
      ),
    );
    return isMobile && widget.showHeader
        ? Scaffold(
            backgroundColor: _pageBg,
            body: SafeArea(bottom: false, child: content))
        : content;
  }
}

// ═══════════════════════════════════════════════════════════════
// ของฉัน
// ═══════════════════════════════════════════════════════════════

class _MyAttendanceTab extends StatefulWidget {
  final AttendanceService service;
  final AttendanceSettingsInfo settings;
  final int? myId;
  const _MyAttendanceTab(
      {required this.service, required this.settings, required this.myId});

  @override
  State<_MyAttendanceTab> createState() => _MyAttendanceTabState();
}

class _MyAttendanceTabState extends State<_MyAttendanceTab>
    with AutomaticKeepAliveClientMixin {
  DateTime _month = DateTime(
      AttendanceService.thaiToday().year, AttendanceService.thaiToday().month);
  List<DayStatus> _days = [];
  DateTime? _consentAt;
  bool _consentLoaded = false;
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    final id = widget.myId;
    if (id == null) return;
    try {
      final at = await widget.service.getMyConsent(id);
      if (mounted) {
        setState(() {
          _consentAt = at;
          _consentLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _consentLoaded = true);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = _month;
      final to = DateTime(_month.year, _month.month + 1, 0);
      final rows =
          await widget.service.getDayStatus(from, to, userId: widget.myId);
      if (!mounted) return;
      setState(() {
        // ไม่มีสิทธิ์ดูทั้งโรงเรียน ฐานข้อมูลคืนเฉพาะของตัวเองอยู่แล้ว
        _days = rows
            .where((r) => widget.myId == null || r.idUser == widget.myId)
            .where((r) => r.status != 'ยังไม่ถึง')
            .toList()
          ..sort((a, b) => b.day.compareTo(a.day));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AttendanceService.errorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _toggleConsent(bool consent) async {
    if (!consent) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('ถอนความยินยอม',
              style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
          content: Text(
              'ถอนความยินยอมแล้ว แจ้งผู้ดูแลระบบให้ลบใบหน้าของคุณออกจากเครื่องสแกนด้วย '
              'และคุณจะต้องลงเวลาด้วยวิธีอื่นตามที่โรงเรียนกำหนด',
              style: GoogleFonts.sarabun()),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('ยกเลิก')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('ถอนความยินยอม')),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      final at = await widget.service.setConsent(consent);
      if (mounted) setState(() => _consentAt = at);
    } catch (e) {
      if (mounted) _snack(context, AttendanceService.errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final counts = <String, int>{};
    for (final d in _days) {
      counts[d.status] = (counts[d.status] ?? 0) + 1;
    }
    final lateMinutes = _days.fold<int>(0, (s, d) => s + d.lateMinutes);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (_consentLoaded && widget.myId != null) _consentCard(),
          const SizedBox(height: 12),
          _MonthPicker(
            month: _month,
            onChanged: (m) {
              setState(() => _month = m);
              _load();
            },
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _ErrorView(message: _error!, onRetry: _load)
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in ['มา', 'สาย', 'ลา', 'ไปราชการ', 'ขาด'])
                  _CountChip(status: s, count: counts[s] ?? 0),
                if (lateMinutes > 0)
                  Chip(
                    label: Text(
                        'สายรวม ${AttendanceService.minutesLabel(lateMinutes)}',
                        style: GoogleFonts.sarabun(fontSize: 13)),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: _line),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_days.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                    child: Text('ไม่มีข้อมูลในเดือนนี้',
                        style: GoogleFonts.sarabun(color: _muted))),
              )
            else
              _Card(
                child: Column(
                  children: [
                    for (var i = 0; i < _days.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: _line),
                      _DayRow(
                        status: _days[i],
                        title: AttendanceService.thaiDayLabel(_days[i].day),
                        onTap: _days[i].scanCount == 0 || widget.myId == null
                            ? null
                            : () => showScanDetail(
                                  context,
                                  service: widget.service,
                                  status: _days[i],
                                  canEdit: false,
                                ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _consentCard() {
    final given = _consentAt != null;
    return _Card(
      color: given ? Colors.white : const Color(0xFFFFFBEB),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(given ? Icons.verified_user_rounded : Icons.face_rounded,
                color:
                    given ? const Color(0xFF15803D) : const Color(0xFFB45309)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      given
                          ? 'ยินยอมใช้ข้อมูลใบหน้าแล้ว'
                          : 'ขอความยินยอมใช้ข้อมูลใบหน้าเพื่อลงเวลา',
                      style: GoogleFonts.sarabun(
                          fontWeight: FontWeight.bold, color: _ink)),
                  const SizedBox(height: 4),
                  Text(
                      given
                          ? 'เมื่อ ${AttendanceService.thaiShortDate(_consentAt!)} ${AttendanceService.hm(_consentAt)} น.'
                          : 'ใบหน้าเก็บไว้ในเครื่องสแกนที่โรงเรียนเท่านั้น '
                              'ระบบนี้เก็บแค่เวลาที่สแกน ใช้เพื่อบันทึกเวลาปฏิบัติราชการ '
                              'ถอนความยินยอมได้ทุกเมื่อ',
                      style: GoogleFonts.sarabun(fontSize: 13, color: _muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            given
                ? TextButton(
                    onPressed: () => _toggleConsent(false),
                    child: Text('ถอน', style: GoogleFonts.sarabun()))
                : FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _ink),
                    onPressed: () => _toggleConsent(true),
                    child: Text('ยินยอม', style: GoogleFonts.sarabun())),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// รายวัน (ทั้งโรงเรียน)
// ═══════════════════════════════════════════════════════════════

class _DailyTab extends StatefulWidget {
  final AttendanceService service;
  final AttendanceSettingsInfo settings;
  final bool canEdit;
  const _DailyTab(
      {required this.service, required this.settings, required this.canEdit});

  @override
  State<_DailyTab> createState() => _DailyTabState();
}

class _DailyTabState extends State<_DailyTab>
    with AutomaticKeepAliveClientMixin {
  DateTime _day = AttendanceService.thaiToday();
  List<DayStatus> _rows = [];
  String? _filter;
  String _search = '';
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.service.getDayStatus(_day, _day);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AttendanceService.errorMessage(e);
        _loading = false;
      });
    }
  }

  void _shiftDay(int days) {
    final next = _day.add(Duration(days: days));
    if (next.isAfter(AttendanceService.thaiToday())) return;
    setState(() => _day = next);
    _load();
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2024),
      lastDate: AttendanceService.thaiToday(),
    );
    if (picked == null) return;
    setState(() => _day = picked);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final counts = <String, int>{};
    for (final r in _rows) {
      counts[r.status] = (counts[r.status] ?? 0) + 1;
    }
    final q = _search.trim();
    final visible = _rows
        .where((r) => _filter == null || r.status == _filter)
        .where((r) => q.isEmpty || r.fullName.contains(q))
        .toList()
      ..sort((a, b) {
        final s = AttendanceService.statusOrder
            .indexOf(a.status)
            .compareTo(AttendanceService.statusOrder.indexOf(b.status));
        if (s != 0) return s;
        // คนมาก่อนอยู่บน
        final ta = a.firstScan, tb = b.firstScan;
        if (ta != null && tb != null) return ta.compareTo(tb);
        return a.fullName.compareTo(b.fullName);
      });
    final isToday = _day == AttendanceService.thaiToday();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Row(
            children: [
              IconButton(
                  onPressed: () => _shiftDay(-1),
                  icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(
                child: InkWell(
                  onTap: _pickDay,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '${isToday ? 'วันนี้ · ' : ''}${AttendanceService.thaiDayLabel(_day)} ${_day.year + 543}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.sarabun(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _ink),
                    ),
                  ),
                ),
              ),
              IconButton(
                  onPressed: isToday ? null : () => _shiftDay(1),
                  icon: const Icon(Icons.chevron_right_rounded)),
              IconButton(
                  tooltip: 'โหลดใหม่',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded, color: _muted)),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('ทั้งหมด (${_rows.length})',
                        style: GoogleFonts.sarabun(fontSize: 13)),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                ),
                for (final s in AttendanceService.statusOrder)
                  if ((counts[s] ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(statusStyle(s).icon,
                            size: 16, color: statusStyle(s).fg),
                        label: Text('$s (${counts[s]})',
                            style: GoogleFonts.sarabun(fontSize: 13)),
                        selected: _filter == s,
                        onSelected: (_) =>
                            setState(() => _filter = _filter == s ? null : s),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: _inputDecoration('ค้นหาชื่อ', Icons.search_rounded),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _ErrorView(message: _error!, onRetry: _load)
          else if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                  child: Text('ไม่มีรายชื่อ',
                      style: GoogleFonts.sarabun(color: _muted))),
            )
          else
            _Card(
              child: Column(
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: _line),
                    _DayRow(
                      status: visible[i],
                      title: visible[i].fullName,
                      // รายการสแกนดิบของคนอื่นเปิดได้เฉพาะแอดมิน (RLS)
                      onTap: !widget.canEdit
                          ? null
                          : () async {
                              final changed = await showScanDetail(
                                context,
                                service: widget.service,
                                status: visible[i],
                                canEdit: widget.canEdit,
                              );
                              if (changed == true) _load();
                            },
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// รายเดือน
// ═══════════════════════════════════════════════════════════════

class _MonthlyTab extends StatefulWidget {
  final AttendanceService service;
  const _MonthlyTab({required this.service});

  @override
  State<_MonthlyTab> createState() => _MonthlyTabState();
}

class _MonthlyTabState extends State<_MonthlyTab>
    with AutomaticKeepAliveClientMixin {
  DateTime _month = DateTime(
      AttendanceService.thaiToday().year, AttendanceService.thaiToday().month);
  List<AttendanceSummaryRow> _rows = [];
  bool _loading = true;
  bool _exporting = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  DateTime get _from => _month;
  DateTime get _to => DateTime(_month.year, _month.month + 1, 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.service.getSummary(_from, _to);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AttendanceService.errorMessage(e);
        _loading = false;
      });
    }
  }

  void _download(List<int> bytes, String fileName) {
    final ok =
        platform.downloadBytes(bytes, fileName, 'text/csv;charset=utf-8');
    if (!ok) _snack(context, 'ดาวน์โหลดไฟล์ได้เฉพาะบนเว็บครับ');
  }

  void _exportSummary() {
    final label = AttendanceService.thaiMonthYear(_month);
    _download(
        AttendanceService.summaryCsv(_rows, title: 'สรุปการลงเวลา $label'),
        'สรุปลงเวลา_$label.csv');
  }

  Future<void> _exportDaily() async {
    setState(() => _exporting = true);
    try {
      final rows = await widget.service.getDayStatus(_from, _to);
      final label = AttendanceService.thaiMonthYear(_month);
      _download(
          AttendanceService.dailyCsv(
              rows.where((r) => r.status != 'ยังไม่ถึง').toList(),
              title: 'การลงเวลารายวัน $label'),
          'ลงเวลารายวัน_$label.csv');
    } catch (e) {
      if (mounted) _snack(context, AttendanceService.errorMessage(e));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cols = [
      ('วันทำการ', (AttendanceSummaryRow r) => '${r.workDays}'),
      ('มา', (AttendanceSummaryRow r) => '${r.present}'),
      (
        'สาย',
        (AttendanceSummaryRow r) =>
            r.late == 0 ? '0' : '${r.late} (${r.lateMinutes}น.)'
      ),
      ('ลา', (AttendanceSummaryRow r) => '${r.onLeave}'),
      ('ราชการ', (AttendanceSummaryRow r) => '${r.onTrip}'),
      ('ขาด', (AttendanceSummaryRow r) => '${r.absent}'),
      ('ไม่สแกนออก', (AttendanceSummaryRow r) => '${r.missingOut}'),
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: _MonthPicker(
                month: _month,
                onChanged: (m) {
                  setState(() => _month = m);
                  _load();
                },
              ),
            ),
            OutlinedButton.icon(
              onPressed: _loading || _rows.isEmpty ? null : _exportSummary,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text('สรุป (Excel)', style: GoogleFonts.sarabun()),
            ),
            OutlinedButton.icon(
              onPressed: _loading || _exporting ? null : _exportDaily,
              icon: _exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text('รายวัน (Excel)', style: GoogleFonts.sarabun()),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          _ErrorView(message: _error!, onRetry: _load)
        else if (_rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
                child: Text('ไม่มีข้อมูล',
                    style: GoogleFonts.sarabun(color: _muted))),
          )
        else
          _Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: GoogleFonts.sarabun(
                    fontWeight: FontWeight.bold, color: _ink),
                dataTextStyle: GoogleFonts.sarabun(color: _ink),
                columnSpacing: 20,
                columns: [
                  const DataColumn(label: Text('ชื่อ-สกุล')),
                  for (final c in cols)
                    DataColumn(label: Text(c.$1), numeric: true),
                ],
                rows: [
                  for (final r in _rows)
                    DataRow(cells: [
                      DataCell(Text(r.fullName)),
                      for (final c in cols)
                        DataCell(Text(c.$2(r),
                            style: GoogleFonts.sarabun(
                                color: c.$1 == 'ขาด' && r.absent > 0
                                    ? const Color(0xFFB91C1C)
                                    : c.$1 == 'สาย' && r.late > 0
                                        ? const Color(0xFFB45309)
                                        : _ink))),
                    ]),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// รายละเอียดการสแกน + แก้เวลา
// ═══════════════════════════════════════════════════════════════

/// คืน true ถ้ามีการแก้ไข (ให้หน้าที่เรียกโหลดใหม่)
Future<bool?> showScanDetail(
  BuildContext context, {
  required AttendanceService service,
  required DayStatus status,
  required bool canEdit,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) =>
        _ScanDetailDialog(service: service, status: status, canEdit: canEdit),
  );
}

class _ScanDetailDialog extends StatefulWidget {
  final AttendanceService service;
  final DayStatus status;
  final bool canEdit;
  const _ScanDetailDialog(
      {required this.service, required this.status, required this.canEdit});

  @override
  State<_ScanDetailDialog> createState() => _ScanDetailDialogState();
}

class _ScanDetailDialogState extends State<_ScanDetailDialog> {
  List<ScanLog>? _scans;
  String? _error;
  bool _changed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final scans = await widget.service
          .getScans(widget.status.idUser, widget.status.day);
      if (mounted) setState(() => _scans = scans);
    } catch (e) {
      if (mounted) setState(() => _error = AttendanceService.errorMessage(e));
    }
  }

  /// ถามเวลา (ถ้า [askTime]) + เหตุผล
  Future<({TimeOfDay? time, String reason})?> _ask(String title,
      {bool askTime = false, TimeOfDay? initial}) {
    TimeOfDay? time = initial;
    final reason = TextEditingController();
    return showDialog<({TimeOfDay? time, String reason})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(title,
              style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (askTime)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime:
                            time ?? const TimeOfDay(hour: 8, minute: 0),
                        builder: (c, child) => MediaQuery(
                          data: MediaQuery.of(c)
                              .copyWith(alwaysUse24HourFormat: true),
                          child: child!,
                        ),
                      );
                      if (picked != null) setLocal(() => time = picked);
                    },
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(
                        time == null
                            ? 'เลือกเวลา'
                            : 'เวลา ${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')} น.',
                        style: GoogleFonts.sarabun()),
                  ),
                if (askTime) const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  autofocus: !askTime,
                  maxLines: 2,
                  decoration: _inputDecoration(
                      'เหตุผล (จำเป็น) เช่น เครื่องเสีย / ลืมสแกน', null),
                  onChanged: (_) => setLocal(() {}),
                ),
                const SizedBox(height: 8),
                Text('บันทึกชื่อผู้แก้และเหตุผลไว้ตรวจสอบย้อนหลัง',
                    style: GoogleFonts.sarabun(fontSize: 12, color: _muted)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ยกเลิก')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _ink),
              onPressed: reason.text.trim().isEmpty || (askTime && time == null)
                  ? null
                  : () => Navigator.pop(ctx, (time: time, reason: reason.text)),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  DateTime _at(TimeOfDay t) {
    final d = widget.status.day;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      _changed = true;
      await _load();
    } catch (e) {
      if (mounted) _snack(context, AttendanceService.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final r = await _ask('เพิ่มเวลาแทน', askTime: true);
    if (r == null) return;
    await _run(() => widget.service
        .addManualScan(widget.status.idUser, _at(r.time!), r.reason));
  }

  Future<void> _correct(ScanLog log) async {
    final r = await _ask('แก้เวลา ${AttendanceService.hm(log.scannedAt)} น.',
        askTime: true,
        initial:
            TimeOfDay(hour: log.scannedAt.hour, minute: log.scannedAt.minute));
    if (r == null) return;
    await _run(() => widget.service
        .correctScan(log, widget.status.idUser, _at(r.time!), r.reason));
  }

  Future<void> _void(ScanLog log) async {
    final r =
        await _ask('ยกเลิกเวลา ${AttendanceService.hm(log.scannedAt)} น.');
    if (r == null) return;
    await _run(() => widget.service.voidScan(log.idLog, r.reason));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.status;
    final style = statusStyle(s.status);
    final scans = _scans;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.fullName,
                    style: GoogleFonts.sarabun(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                Text(
                    '${AttendanceService.thaiDayLabel(s.day)} ${s.day.year + 543}',
                    style: GoogleFonts.sarabun(fontSize: 13, color: _muted)),
              ],
            ),
          ),
          _StatusPill(status: s.status, style: style),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: _error != null
            ? Text(_error!, style: GoogleFonts.sarabun(color: Colors.red))
            : scans == null
                ? const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator()))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (s.note.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(s.note,
                              style: GoogleFonts.sarabun(color: _muted)),
                        ),
                      if (scans.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text('ไม่มีการสแกนในวันนี้',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.sarabun(color: _muted)),
                        ),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final log in scans) _scanTile(log),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
      actions: [
        if (widget.canEdit)
          TextButton.icon(
            onPressed: _busy || scans == null ? null : _add,
            icon: const Icon(Icons.add_rounded),
            label: Text('เพิ่มเวลาแทน', style: GoogleFonts.sarabun()),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, _changed),
          child: Text('ปิด', style: GoogleFonts.sarabun()),
        ),
      ],
    );
  }

  Widget _scanTile(ScanLog log) {
    final details = [
      log.sourceLabel,
      if (log.note.isNotEmpty) log.note,
      if (log.voided) 'ยกเลิกแล้ว: ${log.voidReason}',
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        log.source == 'manual'
            ? Icons.edit_note_rounded
            : log.source == 'import'
                ? Icons.upload_file_rounded
                : Icons.face_retouching_natural_rounded,
        color: log.voided ? _line : _muted,
      ),
      title: Text('${AttendanceService.hm(log.scannedAt)} น.',
          style: GoogleFonts.sarabun(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: log.voided ? _muted : _ink,
            decoration: log.voided ? TextDecoration.lineThrough : null,
          )),
      subtitle: Text(details,
          style: GoogleFonts.sarabun(fontSize: 12, color: _muted)),
      trailing: widget.canEdit && !log.voided
          ? PopupMenuButton<String>(
              enabled: !_busy,
              onSelected: (v) => v == 'edit' ? _correct(log) : _void(log),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('แก้เวลา')),
                PopupMenuItem(value: 'void', child: Text('ยกเลิกเวลานี้')),
              ],
            )
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ชิ้นส่วนย่อย
// ═══════════════════════════════════════════════════════════════

class _DayRow extends StatelessWidget {
  final DayStatus status;
  final String title;
  final VoidCallback? onTap;
  const _DayRow({required this.status, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = statusStyle(status.status);
    final times = status.firstScan == null
        ? ''
        : status.scanCount > 1
            ? '${AttendanceService.hm(status.firstScan)} – ${AttendanceService.hm(status.lastScan)}'
            : AttendanceService.hm(status.firstScan);
    final sub = [
      if (status.lateMinutes > 0)
        'สาย ${AttendanceService.minutesLabel(status.lateMinutes)}',
      if (status.note.isNotEmpty) status.note,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(style.icon, color: style.fg, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.sarabun(
                          fontWeight: FontWeight.w600, color: _ink)),
                  if (sub.isNotEmpty)
                    Text(sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            GoogleFonts.sarabun(fontSize: 12, color: _muted)),
                ],
              ),
            ),
            if (times.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 8),
                child: Text(times,
                    style: GoogleFonts.sarabun(
                        fontWeight: FontWeight.w600, color: _ink)),
              ),
            _StatusPill(status: status.status, style: style),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  final ({Color fg, Color bg, IconData icon}) style;
  const _StatusPill({required this.status, required this.style});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: style.bg, borderRadius: BorderRadius.circular(999)),
        child: Text(status,
            style: GoogleFonts.sarabun(
                fontSize: 12, fontWeight: FontWeight.bold, color: style.fg)),
      );
}

class _CountChip extends StatelessWidget {
  final String status;
  final int count;
  const _CountChip({required this.status, required this.count});

  @override
  Widget build(BuildContext context) {
    final style = statusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: style.bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 16, color: style.fg),
          const SizedBox(width: 6),
          Text('$status $count',
              style: GoogleFonts.sarabun(
                  fontWeight: FontWeight.bold, color: style.fg)),
        ],
      ),
    );
  }
}

class _MonthPicker extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  const _MonthPicker({required this.month, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final today = AttendanceService.thaiToday();
    final isCurrent = month.year == today.year && month.month == today.month;
    return _Card(
      child: Row(
        children: [
          IconButton(
              onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left_rounded)),
          Expanded(
            child: Text(AttendanceService.thaiMonthYear(month),
                textAlign: TextAlign.center,
                style: GoogleFonts.sarabun(
                    fontWeight: FontWeight.bold, color: _ink)),
          ),
          IconButton(
              onPressed: isCurrent
                  ? null
                  : () => onChanged(DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right_rounded)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final Color color;
  const _Card({required this.child, this.color = Colors.white});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text('โหลดข้อมูลไม่สำเร็จ: $message',
                textAlign: TextAlign.center,
                style: GoogleFonts.sarabun(color: Colors.red)),
            TextButton(onPressed: onRetry, child: const Text('ลองใหม่')),
          ],
        ),
      );
}

InputDecoration _inputDecoration(String hint, IconData? icon) =>
    InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.sarabun(color: _muted),
      prefixIcon: icon == null ? null : Icon(icon, color: _muted),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _line)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _line)),
    );

void _snack(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
