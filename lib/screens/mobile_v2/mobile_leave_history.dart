/// ประวัติการลาบนมือถือ (mobile_v2) — สไตล์ Native Mobile Application
///
/// ปรับปรุงประสบการณ์แบบแอปพลิเคชันมือถือแท้:
///   - สลับขอบเขต "ใบลาของฉัน" vs "ทั้งโรงเรียน" ด้วย Segmented Pill Slider
///   - BottomSheet กรองรอบปีงบประมาณและตัวกรองสถานะแบบ Native Mobile Sheet
///   - ป้ายสถานะแยกสีพร้อมจำนวนกำกับ
///   - การ์ดใบลาแสดงข้อมูลครบถ้วน แตะเพื่อดูรายละเอียด / อนุมัติทันใจ
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/firebase_service.dart';
import 'leave_actions.dart';
import 'menu_access.dart';
import 'mobile_leave_detail.dart';
import 'mobile_pages.dart';
import '../../theme/app_tokens.dart';

class MobileLeaveHistory extends StatefulWidget {
  final MenuAccess access;
  final ValueChanged<Map<String, dynamic>> onEdit;

  const MobileLeaveHistory({
    super.key,
    required this.access,
    required this.onEdit,
  });

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
  VoidCallback? _stopLive;

  @override
  void initState() {
    super.initState();
    _init();
    _stopLive = _service.onLeavesChanged(() => _load(quiet: true));
  }

  @override
  void dispose() {
    _stopLive?.call();
    super.dispose();
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
      _showAll = _canViewAll && widget.access.isAdmin;
      _rounds = rounds;
      _round = active == null
          ? (rounds.isNotEmpty ? rounds.first : null)
          : rounds.firstWhere(
              (r) => r['id'] == active['id'],
              orElse: () => rounds.isNotEmpty ? rounds.first : {},
            );
      if (_round?.isEmpty ?? false) _round = null;
      _users = (results[3] as List).cast<Map<String, dynamic>>();
    });
    await _load();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!mounted) return;
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
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
    HapticFeedback.lightImpact();
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

  void _showFilterBottomSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'เลือกรอบปีงบประมาณ',
                      style: GoogleFonts.sarabun(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: mobileInk,
                      ),
                    ),
                    if (_round != null)
                      TextButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() => _round = null);
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          'ดูทั้งหมด',
                          style: GoogleFonts.sarabun(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: mobileAccent,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _rounds.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final r = _rounds[i];
                      final isSelected = _round?['id'] == r['id'];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: isSelected ? mobileAccent : mobileMuted,
                          size: 20,
                        ),
                        title: Text(
                          (r['roundName'] ?? '').toString(),
                          style: GoogleFonts.sarabun(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? mobileAccent : mobileInk,
                          ),
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _round = r);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
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
      if (g == null) return scoped.length;
      return scoped.where((l) => LeaveStatus.group(LeaveStatus.of(l)) == g).length;
    }

    return Column(
      children: [
        // ── แถบควบคุมด้านบนแบบ Native Mobile Control Card ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // แถวที่ 1: สลับ "ของฉัน / ทั้งโรงเรียน" และ "ปีงบ"
              Row(
                children: [
                  if (_canViewAll)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.raised,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _scopeSegmentButton(
                                label: 'ใบลาของฉัน',
                                isSelected: !_showAll,
                                onTap: () {
                                  if (_showAll) {
                                    HapticFeedback.selectionClick();
                                    setState(() => _showAll = false);
                                    _load();
                                  }
                                },
                              ),
                            ),
                            Expanded(
                              child: _scopeSegmentButton(
                                label: 'ทั้งโรงเรียน',
                                isSelected: _showAll,
                                onTap: () {
                                  if (!_showAll) {
                                    HapticFeedback.selectionClick();
                                    setState(() => _showAll = true);
                                    _load();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Text(
                        'ประวัติการลาของฉัน',
                        style: GoogleFonts.sarabun(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: mobileInk,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _showFilterBottomSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.page,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: mobileLine),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 15, color: mobileAccent),
                          const SizedBox(width: 5),
                          Text(
                            _round == null
                                ? 'ทุกรอบปีงบ'
                                : (_round!['roundName'] ?? '').toString().replaceFirst('รอบที่ ', ''),
                            style: GoogleFonts.sarabun(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: mobileInk,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down_rounded, size: 16, color: mobileMuted),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // แถวที่ 2: ช่องค้นหาข้อความ
              SizedBox(
                height: 38,
                child: TextField(
                  style: GoogleFonts.sarabun(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: _showAll ? 'ค้นหาชื่อผู้ลา ประเภท หรือเหตุผล...' : 'ค้นหาประเภท หรือเหตุผล...',
                    hintStyle: GoogleFonts.sarabun(fontSize: 12, color: mobileMuted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: mobileMuted),
                    suffixIcon: _search.isNotEmpty
                        ? GestureDetector(
                            onTap: () => setState(() => _search = ''),
                            child: const Icon(Icons.cancel_rounded, size: 16, color: mobileMuted),
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.page,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: mobileLine),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: mobileLine),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: mobileAccent),
                    ),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(height: 10),

              // แถวที่ 3: แถบฟิลเตอร์ชิปสถานะ
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip(
                      label: 'ทั้งหมด',
                      count: count(null),
                      isSelected: _filter == null,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _filter = null);
                      },
                    ),
                    const SizedBox(width: 6),
                    _filterChip(
                      label: 'รอพิจารณา',
                      count: count(LeaveStatusGroup.pending),
                      isSelected: _filter == LeaveStatusGroup.pending,
                      color: AppColors.pending,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _filter = LeaveStatusGroup.pending);
                      },
                    ),
                    const SizedBox(width: 6),
                    _filterChip(
                      label: 'ส่งใบแล้ว',
                      count: count(LeaveStatusGroup.approved),
                      isSelected: _filter == LeaveStatusGroup.approved,
                      color: AppColors.positive,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _filter = LeaveStatusGroup.approved);
                      },
                    ),
                    const SizedBox(width: 6),
                    _filterChip(
                      label: 'ยังไม่ส่ง',
                      count: count(LeaveStatusGroup.returned),
                      isSelected: _filter == LeaveStatusGroup.returned,
                      color: AppColors.negative,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _filter = LeaveStatusGroup.returned);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: mobileLine),

        // ── รายการการ์ดใบลา ──
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: mobileAccent))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 36, color: AppColors.negative),
                          const SizedBox(height: 8),
                          Text('โหลดไม่สำเร็จ: $_error', style: GoogleFonts.sarabun(fontSize: 13)),
                          const SizedBox(height: 8),
                          ElevatedButton(onPressed: _load, child: const Text('ลองใหม่')),
                        ],
                      ),
                    )
                  : visible.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: AppColors.raised,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(Icons.description_outlined, size: 30, color: mobileMuted),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'ไม่พบรายการใบลา',
                                  style: GoogleFonts.sarabun(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: mobileInk,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ไม่มีข้อมูลตามตัวกรองที่เลือกในขณะนี้',
                                  style: GoogleFonts.sarabun(fontSize: 12, color: mobileMuted),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _load(quiet: false),
                          color: mobileAccent,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                            itemCount: visible.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _buildLeaveCard(visible[i]),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _scopeSegmentButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.text.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.sarabun(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? mobileAccent : mobileMuted,
          ),
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    Color color = mobileAccent,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : AppColors.page,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : mobileLine),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.sarabun(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : mobileMuted,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0.5),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.sarabun(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : mobileInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// การ์ดใบลาหนึ่งใบ: ประเภท + จำนวนวัน · ช่วงวันที่ · ตรายางสถานะ
  Widget _buildLeaveCard(Map<String, dynamic> l) {
    final status = LeaveStatus.of(l);
    final type = (l['leaveType'] ?? '').toString();
    final name = (l['fullName'] ?? '').toString();
    final days =
        FirebaseService.formatLeaveDayCount(l['totalDays'] ?? l['days'] ?? 1);
    final reason = (l['reason'] ?? '').toString().trim();
    final range = l['startDate'] == l['endDate']
        ? FirebaseService.formatThaiDate(l['startDate'])
        : '${FirebaseService.formatThaiDate(l['startDate'])} – ${FirebaseService.formatThaiDate(l['endDate'])}';

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => _openDetail(l),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(
                                text: type,
                                style: AppText.label.copyWith(fontSize: 14)),
                            TextSpan(
                                text: '  $days วัน',
                                style: AppText.figure(13,
                                    color: AppColors.textSecondary,
                                    weight: FontWeight.w400)),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(range, style: AppText.secondary),
                        if (_showAll && name.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.meta),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  LeaveStatus.stamp(status),
                ],
              ),
              if (reason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.meta),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
