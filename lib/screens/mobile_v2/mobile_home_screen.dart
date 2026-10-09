/// หน้าหลักบนมือถือ — แสดงตามสิทธิ์
///
/// - ทุกคน: ทักทาย + วันลาของฉัน + ใบลาล่าสุด + ทางลัดเมนูที่มีสิทธิ์
/// - ผู้บริหาร / ผู้ดูแลระบบ: วันนี้ในโรงเรียน (ลา / ไปราชการ)
/// - ผู้ดูแลระบบ: งานรอพิจารณา + คำขอรีเซ็ตรหัส (ผู้บริหารไม่อนุมัติ จึงไม่เห็น)
/// ดึงลงเพื่อโหลดใหม่
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/firebase_service.dart';
import 'menu_access.dart';
import 'mobile_home_data.dart';
import 'mobile_pages.dart';

const _line = Color(0xFFE2E8F0);

class MobileHomeScreen extends StatefulWidget {
  final MenuAccess access;

  /// สลับไปแท็บล่าง (0 หน้าหลัก · 1 ส่งใบลา · 2 ประวัติ · 3 บัญชี)
  final ValueChanged<int> onGoTab;

  const MobileHomeScreen(
      {super.key, required this.access, required this.onGoTab});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  late Future<MobileHomeData> _data = MobileHomeData.load(widget.access);

  Future<void> _refresh() async {
    final next = MobileHomeData.load(widget.access);
    setState(() => _data = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final access = widget.access;
    final shortcuts = [
      for (final s in mobileShortcuts)
        if (access.can(s.menu)) s
    ];
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<MobileHomeData>(
        future: _data,
        builder: (context, snap) {
          final d = snap.data;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _greeting(d, access),
              const SizedBox(height: 16),
              if (d == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (d.pending != null) ...[
                  _pendingCards(d),
                  const SizedBox(height: 12),
                ],
                if (d.today != null) ...[
                  _todayCard(d.today!),
                  const SizedBox(height: 12),
                ],
                if (d.hasOwnLeaves) ...[
                  _myLeaveCard(d),
                  const SizedBox(height: 12),
                  _latestLeaveCard(d),
                  const SizedBox(height: 12),
                ],
              ],
              if (shortcuts.isNotEmpty) ...[
                const SizedBox(height: 4),
                _sectionTitle('เมนู'),
                const SizedBox(height: 8),
                MobileShortcutGrid(shortcuts: shortcuts),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _greeting(MobileHomeData? d, MenuAccess access) {
    final name = d?.fullName ?? access.currentUser;
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFFDBEAFE),
          child: Text(name.isEmpty ? '?' : name.characters.first,
              style: GoogleFonts.sarabun(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: mobileAccent)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('สวัสดี',
                  style: GoogleFonts.sarabun(fontSize: 13, color: mobileMuted)),
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sarabun(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: mobileInk)),
              if ((d?.subtitle ?? '').isNotEmpty)
                Text(d!.subtitle,
                    style:
                        GoogleFonts.sarabun(fontSize: 13, color: mobileMuted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pendingCards(MobileHomeData d) {
    final p = d.pending!;
    final total = p.leaves + p.trips;
    return Row(
      children: [
        Expanded(
          child: _tile(
            color: const Color(0xFFFEF3C7),
            fg: const Color(0xFF92400E),
            icon: Icons.pending_actions_rounded,
            value: '$total',
            label: 'รอพิจารณา',
            detail: 'ใบลา ${p.leaves} · ราชการ ${p.trips}',
            onTap: () => widget.onGoTab(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _tile(
            color: const Color(0xFFFEE2E2),
            fg: const Color(0xFF991B1B),
            icon: Icons.lock_reset_rounded,
            value: '${d.resetRequests ?? 0}',
            label: 'ขอรีเซ็ตรหัส',
            detail: 'ดูที่บัญชี',
            onTap: () => widget.onGoTab(3),
          ),
        ),
      ],
    );
  }

  Widget _tile({
    required Color color,
    required Color fg,
    required IconData icon,
    required String value,
    required String label,
    required String detail,
    VoidCallback? onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: fg, size: 20),
                const Spacer(),
                Text(value,
                    style: GoogleFonts.sarabun(
                        fontSize: 24, fontWeight: FontWeight.w800, color: fg)),
              ]),
              const SizedBox(height: 4),
              Text(label,
                  style: GoogleFonts.sarabun(
                      fontSize: 14, fontWeight: FontWeight.w700, color: fg)),
              Text(detail,
                  style: GoogleFonts.sarabun(
                      fontSize: 12, color: fg.withValues(alpha: 0.8))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _todayCard(({int onLeave, int onTrip}) t) {
    return _card(
      title: 'วันนี้ในโรงเรียน',
      child: Row(
        children: [
          _stat('${t.onLeave}', 'คนลา'),
          _stat('${t.onTrip}', 'คนไปราชการ'),
        ],
      ),
    );
  }

  Widget _myLeaveCard(MobileHomeData d) {
    String n(num v) => FirebaseService.formatLeaveDayCount(v);
    return _card(
      title: d.fiscalYear == null
          ? 'วันลาของฉัน'
          : 'วันลาของฉัน · ปีงบ ${d.fiscalYear}',
      child: Row(
        children: [
          _stat(n(d.myDays.sick), 'ป่วย (วัน)'),
          _stat(n(d.myDays.personal), 'กิจ (วัน)'),
          _stat(n(d.myDays.maternity), 'คลอด (วัน)'),
        ],
      ),
    );
  }

  Widget _latestLeaveCard(MobileHomeData d) {
    final l = d.latestLeave;
    final status = (l?['status'] ?? '').toString();
    final (bg, fg) = status.contains('ไม่')
        ? (const Color(0xFFFEE2E2), const Color(0xFF991B1B))
        : status.contains('รอ') || status.contains('พิจารณา')
            ? (const Color(0xFFFEF3C7), const Color(0xFF92400E))
            : (const Color(0xFFDCFCE7), const Color(0xFF166534));
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: l == null ? () => widget.onGoTab(1) : () => widget.onGoTab(2),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ใบลาล่าสุด',
                        style: GoogleFonts.sarabun(
                            fontSize: 12, color: mobileMuted)),
                    Text(
                        l == null
                            ? 'ยังไม่มีใบลา — แตะเพื่อส่งใบลา'
                            : '${l['leaveType']} · ${FirebaseService.formatThaiDate(l['startDate'])}',
                        style: GoogleFonts.sarabun(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: mobileInk)),
                  ],
                ),
              ),
              if (l != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: bg, borderRadius: BorderRadius.circular(999)),
                  child: Text(status.isEmpty ? '-' : status,
                      style: GoogleFonts.sarabun(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: fg)),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: mobileMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.sarabun(fontSize: 12, color: mobileMuted)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.sarabun(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: mobileInk)),
            Text(label,
                style: GoogleFonts.sarabun(fontSize: 12, color: mobileMuted)),
          ],
        ),
      );
}

Widget _sectionTitle(String text) => Text(text,
    style: GoogleFonts.sarabun(
        fontSize: 14, fontWeight: FontWeight.w700, color: mobileMuted));

/// ตารางปุ่มทางลัด 3 คอลัมน์
class MobileShortcutGrid extends StatelessWidget {
  final List<MobileShortcut> shortcuts;

  const MobileShortcutGrid({super.key, required this.shortcuts});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: [
        for (final s in shortcuts)
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => openMobileMenu(context, s),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _line),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(s.icon, color: mobileAccent, size: 24),
                    ),
                    const SizedBox(height: 8),
                    Text(s.label,
                        style: GoogleFonts.sarabun(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: mobileInk)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
