/// ประวัติการลาบนมือถือ (หน้าตาใหม่)
///
/// - การ์ดสั้น: ประเภท · จำนวนวัน · วันที่ · ป้ายสถานะ — แตะเพื่อดูรายละเอียด
/// - ตัวกรองสถานะ / รอบงบประมาณ / ค้นหาชื่อ (ดูทั้งโรงเรียน)
/// - ผู้ที่ฐานข้อมูลให้ดูทั้งโรงเรียนได้: สลับ "ของฉัน / ทั้งโรงเรียน"
/// - ดึงลงเพื่อโหลดใหม่
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/firebase_service.dart';
import 'leave_actions.dart';
import 'menu_access.dart';
import 'mobile_leave_detail.dart';
import 'mobile_pages.dart';

const _line = Color(0xFFE2E8F0);

class MobileLeaveHistory extends StatefulWidget {
  final MenuAccess access;

  /// แก้ใบลา → สลับไปแท็บส่งใบลาพร้อมข้อมูลเดิม
  final ValueChanged<Map<String, dynamic>> onEdit;

  const MobileLeaveHistory(
      {super.key, required this.access, required this.onEdit});

  @override
  State<MobileLeaveHistory> createState() => _MobileLeaveHistoryState();
}

class _MobileLeaveHistoryState extends State<MobileLeaveHistory> {
  final _service = FirebaseService();

  bool _canViewAll = false;
  bool _showAll = false;
  LeaveStatusGroup? _filter;
  String _search = '';

  List<Map<String, dynamic>> _rounds = [];
  Map<String, dynamic>? _round;

  List<Map<String, dynamic>> _leaves = [];
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;

  String get _myName => widget.access.currentUser.trim();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final results = await Future.wait<Object?>([
      _service.canViewAllLeaves().catchError((_) => false),
      _service.getFiscalRounds().catchError((_) => <Map<String, dynamic>>[]),
      _service.getActiveFiscalRound().catchError((_) => null),
      _service.getUsersFromSupabase().catchError((_) => <Map<String, dynamic>>[]),
    ]);
    if (!mounted) return;
    final rounds = (results[1] as List).cast<Map<String, dynamic>>();
    final active = results[2] as Map<String, dynamic>?;
    setState(() {
      _canViewAll = results[0] as bool;
      // ผู้ดูแลระบบเปิดมาเห็นทั้งโรงเรียน (งานอนุมัติ) / คนอื่นเห็นของตัวเองก่อน
      _showAll = _canViewAll && widget.access.isAdmin;
      _rounds = rounds;
      _round = active == null
          ? (rounds.isNotEmpty ? rounds.first : null)
          : rounds.firstWhere((r) => r['id'] == active['id'],
              orElse: () => rounds.isNotEmpty ? rounds.first : {});
      if (_round?.isEmpty ?? false) _round = null;
      _users = (results[3] as List).cast<Map<String, dynamic>>();
    });
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final leaves = _showAll
          ? await _service.getLeaveRequestsFromSupabase(throwOnError: true)
          : await _service.getMyLeaveRequestsFromSupabase(_myName);
      if (!mounted) return;
      setState(() {
        _leaves = leaves;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _visible {
    final q = _search.trim().toLowerCase();
    return _leaves.where((l) {
      final round = _round;
      if (round != null &&
          !FirebaseService.isDateInRange(
              (l['startDate'] ?? '').toString(),
              (round['startDate'] ?? '').toString(),
              (round['endDate'] ?? '').toString())) {
        return false;
      }
      if (_filter != null && LeaveStatus.group(LeaveStatus.of(l)) != _filter) {
        return false;
      }
      if (q.isEmpty) return true;
      return '${l['fullName']} ${l['leaveType']} ${l['reason']}'
          .toLowerCase()
          .contains(q);
    }).toList();
  }

  Future<void> _openDetail(Map<String, dynamic> leave) async {
    final changed = await Navigator.of(context).push<bool>(CupertinoPageRoute(
      builder: (_) => MobileLeaveDetail(
        leave: leave,
        access: widget.access,
        allUsers: _users,
        allLeaves: _leaves,
        onEdit: widget.onEdit,
      ),
    ));
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    int count(LeaveStatusGroup? g) {
      final scoped = _leaves.where((l) {
        final round = _round;
        return round == null ||
            FirebaseService.isDateInRange(
                (l['startDate'] ?? '').toString(),
                (round['startDate'] ?? '').toString(),
                (round['endDate'] ?? '').toString());
      });
      return g == null
          ? scoped.length
          : scoped.where((l) => LeaveStatus.group(LeaveStatus.of(l)) == g).length;
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_canViewAll) ...[
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('ของฉัน')),
                        ButtonSegment(value: true, label: Text('ทั้งโรงเรียน')),
                      ],
                      selected: {_showAll},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) {
                        setState(() => _showAll = s.first);
                        _load();
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_rounds.isNotEmpty) _roundPicker(),
                  if (_showAll) ...[
                    const SizedBox(height: 10),
                    TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'ค้นหาชื่อ / ประเภท / เหตุผล',
                        hintStyle: GoogleFonts.sarabun(fontSize: 14),
                        prefixIcon: const Icon(Icons.search_rounded),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _line)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _line)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final (g, label) in [
                          (null, 'ทั้งหมด'),
                          (LeaveStatusGroup.pending, 'รอพิจารณา'),
                          (LeaveStatusGroup.approved, 'อนุมัติ'),
                          (LeaveStatusGroup.returned, 'ส่งกลับ / ไม่อนุมัติ'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('$label (${count(g)})',
                                  style: GoogleFonts.sarabun(fontSize: 13)),
                              selected: _filter == g,
                              showCheckmark: false,
                              onSelected: (_) => setState(() => _filter = g),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('โหลดข้อมูลไม่สำเร็จ',
                      style: GoogleFonts.sarabun(color: Colors.red)),
                  TextButton(onPressed: _load, child: const Text('ลองใหม่')),
                ]),
              ),
            )
          else if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                    _leaves.isEmpty ? 'ยังไม่มีใบลา' : 'ไม่พบใบลาที่ตรงกับตัวกรอง',
                    style:
                        GoogleFonts.sarabun(fontSize: 15, color: mobileMuted)),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _card(visible[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _roundPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          value: _round,
          isExpanded: true,
          style: GoogleFonts.sarabun(
              fontSize: 14, color: mobileInk, fontWeight: FontWeight.w600),
          items: [
            for (final r in _rounds)
              DropdownMenuItem(
                  value: r,
                  child: Text('ปีงบ ${r['year']} · รอบที่ ${r['round']}')),
          ],
          onChanged: (r) => setState(() => _round = r),
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> l) {
    final status = LeaveStatus.of(l);
    final (bg, fg) = LeaveStatus.colors(status);
    final type = (l['leaveType'] ?? '').toString();
    final icon = type.contains('ป่วย')
        ? Icons.healing_rounded
        : type.contains('คลอด')
            ? Icons.child_friendly_rounded
            : Icons.work_outline_rounded;
    final start = FirebaseService.formatThaiDate(l['startDate']);
    final end = FirebaseService.formatThaiDate(l['endDate']);
    final dates = start == end ? start : '$start – $end';
    final days = FirebaseService.formatLeaveDayCount(l['totalDays']);
    final isMine = (l['fullName'] ?? '').toString().trim() == _myName;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetail(l),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: mobileAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_showAll && !isMine)
                      Text((l['fullName'] ?? '-').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sarabun(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: mobileInk)),
                    Text('$type · $days วัน',
                        style: GoogleFonts.sarabun(
                            fontSize: _showAll && !isMine ? 13 : 15,
                            fontWeight: _showAll && !isMine
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: mobileInk)),
                    Text(dates,
                        style: GoogleFonts.sarabun(
                            fontSize: 12, color: mobileMuted)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(999)),
                child: Text(status,
                    style: GoogleFonts.sarabun(
                        fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
              ),
              const Icon(Icons.chevron_right_rounded, color: mobileMuted),
            ],
          ),
        ),
      ),
    );
  }
}
