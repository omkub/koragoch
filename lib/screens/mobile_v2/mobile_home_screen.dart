/// หน้าหลักบนมือถือ (mobile_v2) — สไตล์ Native Mobile Application
///
/// รองรับการแสดงผลแยกตามสิทธิ์อย่างลงตัว:
///   - สิทธิ์ทั่วไป (ครู/บุคลากร): สรุปโควตาวันลา KPI Cards เด่นชัด + ปุ่มลัดส่งใบลาด่วน
///   - สิทธิ์ผู้บริหาร (Executive): สรุปภาพรวมโรงเรียนวันนี้ (ใครลา/ไปราชการ) + กราฟสรุปผล
///   - สิทธิ์ผู้ดูแลระบบ (Admin): แท็บมุมมองสลับระหว่าง "งานส่วนตัว" vs "แดชบอร์ดบริหาร" ทันที
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/firebase_service.dart';
import '../../utils/profile_image.dart';
import '../../utils/school_info.dart';
import '../../widgets/school_logo.dart';
import 'menu_access.dart';
import 'mobile_home_data.dart';
import 'mobile_pages.dart';

class MobileHomeScreen extends StatefulWidget {
  final MenuAccess access;
  final ValueChanged<int> onGoTab;

  const MobileHomeScreen({
    super.key,
    required this.access,
    required this.onGoTab,
  });

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  late Future<MobileHomeData> _data = MobileHomeData.load(widget.access);

  /// โหมดมุมมองสำหรับผู้บริหารและแอดมิน: 'overview' (ภาพรวมโรงเรียน) หรือ 'personal' (เรื่องของฉัน)
  int _viewModeIndex = 0; // 0 = แดชบอร์ดโรงเรียน, 1 = ข้อมูลส่วนตัว

  Future<void> _refresh() async {
    HapticFeedback.mediumImpact();
    final next = MobileHomeData.load(widget.access);
    setState(() => _data = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final access = widget.access;
    final isManager = access.isAdmin || access.seesSchoolOverview;

    final workShortcuts = [
      for (final s in mobileShortcuts)
        if (s.group == MobileShortcutGroup.work && access.can(s.menu)) s
    ];
    final managementShortcuts = [
      for (final s in mobileShortcuts)
        if (s.group == MobileShortcutGroup.management && access.can(s.menu)) s
    ];

    return RefreshIndicator(
      onRefresh: _refresh,
      color: mobileAccent,
      displacement: 20,
      child: FutureBuilder<MobileHomeData>(
        future: _data,
        builder: (context, snap) {
          final d = snap.data;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              _headerGreetingHero(d, access),
              const SizedBox(height: 16),

              // ตัวสลับโหมดมุมมองแบบ Native Segmented Control สำหรับผู้บริหาร / แอดมิน
              if (isManager && d != null && d.hasOwnLeaves) ...[
                _buildRoleViewSwitcher(),
                const SizedBox(height: 16),
              ],

              if (d == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: CircularProgressIndicator(color: mobileAccent),
                  ),
                )
              else ...[
                // แสดงตามโหมดที่เลือก (หรือแสดงตามสิทธิ์หากเป็นครูทั่วไป)
                if (isManager && _viewModeIndex == 0) ...[
                  // ── มุมมองการบริหารและงานด่วน ──
                  if (d.pending != null) ...[
                    MobileSectionHeader(
                      icon: Icons.notifications_active_rounded,
                      title: 'งานรอพิจารณาเร่งด่วน',
                      trailingText: '${(d.pending?.leaves ?? 0) + (d.pending?.trips ?? 0)} รายการ',
                      iconColor: const Color(0xFFD97706),
                    ),
                    _pendingActionCards(d),
                    const SizedBox(height: 18),
                  ],

                  if (d.today != null) ...[
                    const MobileSectionHeader(
                      icon: Icons.analytics_rounded,
                      title: 'ภาพรวมบุคลากรวันนี้',
                      trailingText: 'สถานะสด',
                      iconColor: Color(0xFF0284C7),
                    ),
                    _todayExecutiveCard(d.today!),
                    const SizedBox(height: 18),
                  ],

                  if (managementShortcuts.isNotEmpty) ...[
                    const MobileSectionHeader(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'เมนูการบริหารและรายงาน',
                      iconColor: Color(0xFF4F46E5),
                    ),
                    MobileShortcutGrid(shortcuts: managementShortcuts),
                    const SizedBox(height: 18),
                  ],
                ] else ...[
                  // ── มุมมองการทำงานส่วนตัว (ครู / เจ้าหน้าที่ / หรือแอดมินสลับมา) ──
                  if (d.hasOwnLeaves) ...[
                    MobileSectionHeader(
                      icon: Icons.event_available_rounded,
                      title: 'สรุปวันลาของฉัน',
                      trailingText: d.fiscalYear == null ? null : 'ปีงบ ${d.fiscalYear}',
                      iconColor: mobileAccent,
                    ),
                    _myLeaveKPICards(d),
                    const SizedBox(height: 12),
                    _latestLeaveCard(d),
                    const SizedBox(height: 18),
                  ],

                  if (workShortcuts.isNotEmpty) ...[
                    const MobileSectionHeader(
                      icon: Icons.grid_view_rounded,
                      title: 'บริการและการทำงาน',
                      iconColor: Color(0xFF0D9488),
                    ),
                    MobileShortcutGrid(shortcuts: workShortcuts),
                    const SizedBox(height: 18),
                  ],

                  // หากเป็นแอดมินหรือผู้บริหารแต่สลับมาดูหน้าส่วนตัว ยังคงมีปุ่มลัดบริหารด้านล่าง
                  if (isManager && managementShortcuts.isNotEmpty) ...[
                    const MobileSectionHeader(
                      icon: Icons.tune_rounded,
                      title: 'เครื่องมือบริหารจัดการ',
                      iconColor: Color(0xFF6366F1),
                    ),
                    MobileShortcutGrid(shortcuts: managementShortcuts),
                  ],
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  /// การ์ดส่วนหัวแบบ Hero Card โทนสีแอพพลิเคชันมือถือ
  Widget _headerGreetingHero(MobileHomeData? d, MenuAccess access) {
    final name = d?.fullName ?? access.currentUser;
    final subtitle = (d?.subtitle ?? access.userRole).trim();
    final photo = d?.profileImage ?? '';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ลวดลายวงกลมตกแต่งด้านหลังสไตล์โมบายล์
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // แถบโรงเรียน
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: SchoolLogo(dataUrl: SchoolInfo.logo, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        SchoolInfo.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.sarabun(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        access.userRole,
                        style: GoogleFonts.sarabun(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ข้อมูลโปรไฟล์
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.onGoTab(3);
                      },
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: ProfileAvatar(
                              imageUrl: photo,
                              size: 52,
                              name: name.isEmpty ? '?' : name,
                              backgroundColor: Colors.white,
                              foregroundColor: mobileAccent,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'สวัสดีครับ 👋',
                            style: GoogleFonts.sarabun(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.sarabun(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.sarabun(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (access.can(2))
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: mobileAccent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          widget.onGoTab(1);
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          'ยื่นลา',
                          style: GoogleFonts.sarabun(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// สลับมุมมองระหว่าง "งานบริหารโรงเรียน" vs "ข้อมูลส่วนตัว"
  Widget _buildRoleViewSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: mobileLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: _switchButton(
              index: 0,
              icon: Icons.dashboard_rounded,
              label: 'งานบริหาร & โรงเรียน',
            ),
          ),
          Expanded(
            child: _switchButton(
              index: 1,
              icon: Icons.person_rounded,
              label: 'ข้อมูลการลาของฉัน',
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchButton({required int index, required IconData icon, required String label}) {
    final active = _viewModeIndex == index;
    return GestureDetector(
      onTap: () {
        if (!active) {
          HapticFeedback.selectionClick();
          setState(() => _viewModeIndex = index);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? mobileAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: mobileAccent.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: active ? Colors.white : mobileMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.sarabun(
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? Colors.white : mobileMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// การ์ดงานรอพิจารณาสำหรับผู้บริหาร/แอดมิน
  Widget _pendingActionCards(MobileHomeData d) {
    final p = d.pending!;
    return Row(
      children: [
        Expanded(
          child: _actionMetricTile(
            title: 'ใบลารอพิจารณา',
            value: '${p.leaves}',
            unit: 'ฉบับ',
            subtitle: 'แตะเพื่อเปิดพิจารณา',
            icon: Icons.assignment_late_rounded,
            color: const Color(0xFFD97706),
            bgColor: const Color(0xFFFFFBEB),
            borderColor: const Color(0xFFFDE68A),
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onGoTab(2);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionMetricTile(
            title: 'ไปราชการรออนุมัติ',
            value: '${p.trips}',
            unit: 'รายการ',
            subtitle: 'ตรวจสอบคำขอ',
            icon: Icons.business_center_rounded,
            color: const Color(0xFF2563EB),
            bgColor: const Color(0xFFEFF6FF),
            borderColor: const Color(0xFFBFDBFE),
            onTap: () {
              HapticFeedback.lightImpact();
              final tripShortcut = mobileShortcuts.firstWhere((s) => s.menu == 9);
              openMobileMenu(context, tripShortcut);
            },
          ),
        ),
      ],
    );
  }

  Widget _actionMetricTile({
    required String title,
    required String value,
    required String unit,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 19),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: mobileMuted),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.sarabun(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: GoogleFonts.sarabun(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
              Text(
                title,
                style: GoogleFonts.sarabun(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: mobileInk,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.sarabun(
                  fontSize: 11,
                  color: mobileMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// การ์ดภาพรวมโรงเรียนวันนี้สำหรับผู้บริหาร
  Widget _todayExecutiveCard(({int onLeave, int onTrip}) t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: mobileLine),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _todayStatusBox(
                  icon: Icons.beach_access_rounded,
                  label: 'บุคลากรลาวันนี้',
                  count: '${t.onLeave}',
                  unit: 'คน',
                  color: const Color(0xFFEA580C),
                  bg: const Color(0xFFFFEDD5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _todayStatusBox(
                  icon: Icons.flight_takeoff_rounded,
                  label: 'ไปราชการวันนี้',
                  count: '${t.onTrip}',
                  unit: 'คน',
                  color: const Color(0xFF0284C7),
                  bg: const Color(0xFFE0F2FE),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _todayStatusBox({
    required IconData icon,
    required String label,
    required String count,
    required String unit,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: mobileLine),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      count,
                      style: GoogleFonts.sarabun(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: mobileInk,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      unit,
                      style: GoogleFonts.sarabun(
                        fontSize: 11,
                        color: mobileMuted,
                      ),
                    ),
                  ],
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sarabun(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: mobileMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// การ์ด KPI วันลาของฉัน 3 ประเภทขนาดใหญ่ ดีไซน์ทันสมัย
  Widget _myLeaveKPICards(MobileHomeData d) {
    String n(num v) => FirebaseService.formatLeaveDayCount(v);
    return Row(
      children: [
        Expanded(
          child: _leaveKPICardItem(
            icon: Icons.healing_rounded,
            label: 'ลาป่วย',
            days: n(d.myDays.sick),
            color: const Color(0xFF0284C7),
            bgGradient: const [Color(0xFFF0F9FF), Color(0xFFE0F2FE)],
            borderColor: const Color(0xFFBAE6FD),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _leaveKPICardItem(
            icon: Icons.work_outline_rounded,
            label: 'ลากิจ',
            days: n(d.myDays.personal),
            color: const Color(0xFF4F46E5),
            bgGradient: const [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
            borderColor: const Color(0xFFC7D2FE),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _leaveKPICardItem(
            icon: Icons.child_friendly_rounded,
            label: 'ลาคลอด',
            days: n(d.myDays.maternity),
            color: const Color(0xFFDB2777),
            bgGradient: const [Color(0xFFFDF2F8), Color(0xFFFCE7F3)],
            borderColor: const Color(0xFFFBCFE8),
          ),
        ),
      ],
    );
  }

  Widget _leaveKPICardItem({
    required IconData icon,
    required String label,
    required String days,
    required Color color,
    required List<Color> bgGradient,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: bgGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sarabun(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                days,
                style: GoogleFonts.sarabun(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: mobileInk,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'วัน',
                style: GoogleFonts.sarabun(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: mobileMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// การ์ดใบลาล่าสุด
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
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          HapticFeedback.lightImpact();
          l == null ? widget.onGoTab(1) : widget.onGoTab(2);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: mobileLine),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  l == null ? Icons.post_add_rounded : Icons.receipt_long_rounded,
                  color: mobileAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ประวัติใบลาล่าสุด',
                      style: GoogleFonts.sarabun(fontSize: 11.5, color: mobileMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l == null
                          ? 'ยังไม่มีประวัติการลา — แตะเพื่อส่งใบลา'
                          : '${l['leaveType']} · ${FirebaseService.formatThaiDate(l['startDate'])}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sarabun(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: mobileInk,
                      ),
                    ),
                  ],
                ),
              ),
              if (l != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.isEmpty ? '-' : status,
                    style: GoogleFonts.sarabun(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: mobileMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// ตารางปุ่มทางลัด 3 คอลัมน์ แยกสีไอคอนและคำอธิบายย่อย
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
      childAspectRatio: 1.0,
      children: [
        for (final s in shortcuts)
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.lightImpact();
                openMobileMenu(context, s);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: mobileLine),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: s.iconBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(s.icon, color: s.iconColor, size: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sarabun(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: mobileInk,
                      ),
                    ),
                    if (s.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        s.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.sarabun(
                          fontSize: 10.5,
                          color: mobileMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
