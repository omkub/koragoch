/// หน้าหลักบนมือถือ (mobile_v2)
///
/// แสดงตามสิทธิ์:
///   - ครู / บุคลากร: สรุปวันลาของปีงบ + ใบลาล่าสุด + ทางลัดงานประจำวัน
///   - ผู้บริหาร / ผู้ดูแลระบบ: งานรอพิจารณา + ภาพรวมบุคลากรวันนี้ + เมนูบริหาร
///     (สลับไปดูข้อมูลการลาของตัวเองได้)
///
/// ดีไซน์: พื้นและกรอบเป็นเทากลาง สีหลักน้ำเงินกรมท่าอยู่ที่ปุ่ม "ยื่นใบลา"
/// และตัวเลขวันลาที่ใช้ไปเท่านั้น สถานะใบลาเป็นตรายางหมึก (ดู lib/theme/app_tokens.dart)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/firebase_service.dart';
import '../../theme/app_tokens.dart';
import '../../utils/profile_image.dart';
import '../../utils/school_info.dart';
import '../../widgets/school_logo.dart';
import 'leave_actions.dart';
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

  /// มุมมองของผู้บริหาร / ผู้ดูแลระบบ: 0 = ภาพรวมโรงเรียน, 1 = การลาของฉัน
  int _viewModeIndex = 0;

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
      color: AppColors.accent,
      displacement: 20,
      child: FutureBuilder<MobileHomeData>(
        future: _data,
        builder: (context, snap) {
          final d = snap.data;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _header(d, access),
              const SizedBox(height: 24),
              if (isManager && d != null && d.hasOwnLeaves) ...[
                _viewSwitcher(),
                const SizedBox(height: 24),
              ],
              if (d == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accent),
                  ),
                )
              else if (isManager && _viewModeIndex == 0) ...[
                if (d.pending != null) ...[
                  MobileSectionHeader(
                    title: 'รอพิจารณา',
                    trailingText:
                        '${(d.pending?.leaves ?? 0) + (d.pending?.trips ?? 0)} รายการ',
                  ),
                  _pendingTiles(d),
                  const SizedBox(height: 24),
                ],
                if (d.today != null) ...[
                  const MobileSectionHeader(title: 'บุคลากรวันนี้'),
                  _todayCard(d.today!),
                  const SizedBox(height: 24),
                ],
                if (managementShortcuts.isNotEmpty) ...[
                  const MobileSectionHeader(title: 'บริหารและรายงาน'),
                  MobileShortcutGrid(shortcuts: managementShortcuts),
                ],
              ] else ...[
                if (d.hasOwnLeaves) ...[
                  MobileSectionHeader(
                    title: 'วันลาของฉัน',
                    trailingText:
                        d.fiscalYear == null ? null : 'ปีงบ ${d.fiscalYear}',
                  ),
                  _myLeaveCard(d),
                  const SizedBox(height: 24),
                ],
                if (workShortcuts.isNotEmpty) ...[
                  const MobileSectionHeader(title: 'งานประจำวัน'),
                  MobileShortcutGrid(shortcuts: workShortcuts),
                  const SizedBox(height: 24),
                ],
                if (isManager && managementShortcuts.isNotEmpty) ...[
                  const MobileSectionHeader(title: 'บริหารและรายงาน'),
                  MobileShortcutGrid(shortcuts: managementShortcuts),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  // ── ส่วนหัว: โรงเรียน · ชื่อ · ตำแหน่ง · ปุ่มยื่นใบลา ──
  Widget _header(MobileHomeData? d, MenuAccess access) {
    final name = d?.fullName ?? access.currentUser;
    // subtitle = ตำแหน่ง / กลุ่มสาระ (ไม่มีข้อมูลจะเป็นบทบาทผู้ใช้)
    final subtitle = (d?.subtitle ?? access.userRole).trim();
    final photo = d?.profileImage ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SchoolLogo(dataUrl: SchoolInfo.logo, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                SchoolInfo.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.meta,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onGoTab(3);
              },
              child: ProfileAvatar(
                imageUrl: photo,
                size: 48,
                name: name.isEmpty ? '?' : name,
                backgroundColor: AppColors.raised,
                foregroundColor: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.style(22, weight: FontWeight.w600),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.secondary,
                    ),
                ],
              ),
            ),
          ],
        ),
        if (access.can(2)) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.control)),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                widget.onGoTab(1);
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('ยื่นใบลา',
                  style: AppText.style(14,
                      weight: FontWeight.w500, color: Colors.white)),
            ),
          ),
        ],
      ],
    );
  }

  // ── ตัวสลับมุมมอง: ช่องที่เลือกเป็นพื้นขาวยกขึ้นจากราง ──
  Widget _viewSwitcher() {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.raised,
        borderRadius: BorderRadius.circular(AppRadius.control + 2),
      ),
      child: Row(
        children: [
          Expanded(child: _switchSegment(0, 'ภาพรวมโรงเรียน')),
          Expanded(child: _switchSegment(1, 'การลาของฉัน')),
        ],
      ),
    );
  }

  Widget _switchSegment(int index, String label) {
    final active = _viewModeIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (active) return;
        HapticFeedback.selectionClick();
        setState(() => _viewModeIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.control - 2),
          border: Border.all(
              color: active ? AppColors.line : Colors.transparent),
        ),
        child: Text(
          label,
          style: AppText.style(13,
              weight: active ? FontWeight.w500 : FontWeight.w400,
              color: active ? AppColors.text : AppColors.textSecondary),
        ),
      ),
    );
  }

  // ── งานรอพิจารณา ──
  Widget _pendingTiles(MobileHomeData d) {
    final p = d.pending!;
    return Row(
      children: [
        Expanded(
          child: _figureTile(
            value: '${p.leaves}',
            unit: 'ฉบับ',
            label: 'ใบลารอพิจารณา',
            highlight: p.leaves > 0,
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onGoTab(2);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _figureTile(
            value: '${p.trips}',
            unit: 'รายการ',
            label: 'ไปราชการรออนุมัติ',
            onTap: () {
              HapticFeedback.lightImpact();
              final tripShortcut =
                  mobileShortcuts.firstWhere((s) => s.menu == 9);
              openMobileMenu(context, tripShortcut);
            },
          ),
        ),
      ],
    );
  }

  /// การ์ดตัวเลข: ตัวเลข + หน่วย · ป้ายกำกับ (แตะเพื่อเปิด)
  Widget _figureTile({
    required String value,
    required String unit,
    required String label,
    bool highlight = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(
                  text: value,
                  style: AppText.figure(28,
                      color: highlight ? AppColors.accent : AppColors.text),
                ),
                TextSpan(
                  text: ' $unit',
                  style: AppText.style(13, color: AppColors.textMuted),
                ),
              ])),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.secondary),
                  ),
                  if (onTap != null)
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: AppColors.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── บุคลากรวันนี้ ──
  Widget _todayCard(({int onLeave, int onTrip}) t) {
    Widget cell(String value, String label) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: value, style: AppText.figure(22)),
                  TextSpan(
                      text: ' คน',
                      style: AppText.style(13, color: AppColors.textMuted)),
                ])),
                const SizedBox(height: 2),
                Text(label, style: AppText.secondary),
              ],
            ),
          ),
        );

    return Container(
      decoration: appCardDecoration(),
      child: IntrinsicHeight(
        child: Row(
          children: [
            cell('${t.onLeave}', 'ลาวันนี้'),
            const VerticalDivider(width: 1, thickness: 1, color: AppColors.line),
            cell('${t.onTrip}', 'ไปราชการวันนี้'),
          ],
        ),
      ),
    );
  }

  // ── วันลาของฉัน: วันที่ใช้ไปรวม (ตัวเลขเด่นของหน้า) + แยกประเภท + ใบลาล่าสุด ──
  Widget _myLeaveCard(MobileHomeData d) {
    String n(num v) => FirebaseService.formatLeaveDayCount(v);
    final total = d.myDays.sick + d.myDays.personal + d.myDays.maternity;
    final types = [
      ('ลาป่วย', d.myDays.sick),
      ('ลากิจ', d.myDays.personal),
      ('ลาคลอด', d.myDays.maternity),
    ];

    return Container(
      decoration: appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ใช้ไปแล้ว', style: AppText.secondary),
                Text.rich(TextSpan(children: [
                  TextSpan(
                      text: n(total),
                      style: AppText.figure(28, color: AppColors.accent)),
                  TextSpan(
                      text: ' วัน',
                      style: AppText.style(14, color: AppColors.textMuted)),
                ])),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                for (final (label, days) in types)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: AppText.meta),
                        Text('${n(days)} วัน',
                            style: AppText.figure(14,
                                weight: FontWeight.w400)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.line),
          _latestLeaveRow(d),
        ],
      ),
    );
  }

  Widget _latestLeaveRow(MobileHomeData d) {
    final l = d.latestLeave;
    final status = (l?['status'] ?? '').toString();
    return InkWell(
      borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.card)),
      onTap: () {
        HapticFeedback.lightImpact();
        l == null ? widget.onGoTab(1) : widget.onGoTab(2);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ใบลาล่าสุด', style: AppText.meta),
                  Text(
                    l == null
                        ? 'ยังไม่มีใบลาในปีงบนี้'
                        : '${l['leaveType']} · ${FirebaseService.formatThaiDate(l['startDate'])}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label,
                  ),
                ],
              ),
            ),
            if (l != null) ...[
              const SizedBox(width: 12),
              LeaveStatus.stamp(status),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

/// ตารางทางลัด 3 คอลัมน์ — ไอคอนเส้นสีเดียว ป้ายชื่อ และคำอธิบายสั้น
class MobileShortcutGrid extends StatelessWidget {
  final List<MobileShortcut> shortcuts;

  const MobileShortcutGrid({super.key, required this.shortcuts});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.08,
      children: [
        for (final s in shortcuts)
          Material(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.card),
              onTap: () {
                HapticFeedback.lightImpact();
                openMobileMenu(context, s);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(s.icon, color: AppColors.textSecondary, size: 20),
                    const Spacer(),
                    Text(s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.label),
                    if (s.subtitle.isNotEmpty)
                      Text(s.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.style(11, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
