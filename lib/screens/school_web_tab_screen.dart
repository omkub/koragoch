import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/firebase_service.dart';
import '../theme/app_tokens.dart';
import '../utils/school_info.dart';
import '../utils/web_platform.dart' as platform;
import '../widgets/school_web_frame.dart';

/// หน้าจอแท็บ "เว็บโรงเรียน" บนระบบวันลา (PC)
///
/// รวมเว็บโรงเรียน (/central/) เข้ามาเป็นโปรแกรมเดียวกันโดยแชร์ Supabase Session อัตโนมัติ
/// พร้อมหน้าตั้งค่าสิทธิ์การมองเห็นแท็บและสิทธิ์การเข้าถึงแต่ละฝ่ายของโรงเรียนภายในแท็บนี้
class SchoolWebTabScreen extends StatefulWidget {
  final VoidCallback? onPermissionsChanged;

  const SchoolWebTabScreen({
    super.key,
    this.onPermissionsChanged,
  });

  @override
  State<SchoolWebTabScreen> createState() => _SchoolWebTabScreenState();
}

class _SchoolWebTabScreenState extends State<SchoolWebTabScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  /// 0 = หน้าเว็บโรงเรียนของตัวเอง (Embedded), 1 = ตั้งค่าสิทธิ์การมองเห็น
  int _activeView = 0;

  String _subPath = '';
  int _reloadCounter = 0;
  bool _isAdmin = false;

  // ข้อมูลสำหรับหน้าตั้งค่าสิทธิ์การมองเห็นในแท็บนี้
  bool _loadingPerms = false;
  bool _savingPerms = false;
  List<Map<String, dynamic>> _schoolRoles = [];
  Map<int, bool> _tabVisibilityByRole = {}; // id_role -> เห็นแท็บเว็บโรงเรียนหรือไม่ (menu_id = 6)
  List<Map<String, dynamic>> _schoolDivisions = [];
  // key: '${divisionId}_${roleId}' -> {'can_view': bool, 'can_edit': bool}
  Map<String, Map<String, bool>> _divisionAccessMap = {};

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('userRole') ?? '';
    final user = prefs.getString('currentUser') ?? '';
    final isAdmin = role.contains('ผู้ดูแลระบบ') ||
        role.contains('ผู้บริหาร') ||
        user == 'ผู้ดูแลระบบ' ||
        SchoolInfo.isSuperAdmin;
    if (mounted) {
      setState(() => _isAdmin = isAdmin);
    }
  }

  String _buildCurrentWebUrl({required bool embedded, String? overrideSubPath}) {
    final session = Supabase.instance.client.auth.currentSession;
    final schoolId = SchoolInfo.currentSchoolId;
    final targetSub = overrideSubPath ?? _subPath;
    final url = platform.resolveSchoolWebUrl(
      accessToken: session?.accessToken,
      refreshToken: session?.refreshToken,
      schoolId: schoolId,
      embedded: embedded,
      subPath: targetSub,
    );
    if (_reloadCounter == 0) return url;
    final sep = url.contains('?') ? '&' : '?';
    final hashIdx = url.indexOf('#');
    if (hashIdx >= 0) {
      return '${url.substring(0, hashIdx)}${sep}_r=$_reloadCounter${url.substring(hashIdx)}';
    }
    return '$url${sep}_r=$_reloadCounter';
  }

  Future<void> _loadVisibilitySettings() async {
    final client = _firebaseService.supabaseClient;
    if (client == null) return;

    setState(() => _loadingPerms = true);
    try {
      final schoolId = SchoolInfo.currentSchoolId;

      // 1) โหลดบทบาทของโรงเรียน (roles)
      final rolesRows = await _firebaseService.rolesInSchool(
        client.from('roles').select('ID_Roles, Accessrights, id_school'),
      );
      final rolesList = <Map<String, dynamic>>[];
      for (final r in (rolesRows as List)) {
        final id = int.tryParse(r['ID_Roles']?.toString() ?? '');
        final name = (r['Accessrights'] ?? '').toString().trim();
        if (id != null && name.isNotEmpty) {
          rolesList.add({'id_role': id, 'name': name});
        }
      }

      // 2) โหลดสิทธิ์การมองเห็นแท็บเว็บโรงเรียน (Permissions.menu_id = 6)
      final permRows = await _firebaseService.inSchool(
        client.from('Permissions').select('id_role, menu_id, status').eq('menu_id', 6),
      );
      final tabVis = <int, bool>{};
      for (final r in rolesList) {
        final roleId = r['id_role'] as int;
        // ค่าเริ่มต้น: เปิดให้เห็นแท็บเว็บโรงเรียน
        tabVis[roleId] = true;
      }
      for (final row in (permRows as List)) {
        final roleId = int.tryParse(row['id_role']?.toString() ?? '');
        if (roleId == null) continue;
        final st = row['status'];
        final allowed = st == true ||
            st == 1 ||
            st.toString() == '1' ||
            st.toString().toUpperCase() == 'TRUE';
        tabVis[roleId] = allowed;
      }

      // 3) โหลดรายการฝ่ายของเว็บโรงเรียนและสิทธิ์รายฝ่าย (เชื่อมกับ Permissions -201..-204 / -301..-304 และ SchoolWebRoleDivisionAccess)
      var divList = <Map<String, dynamic>>[
        {
          'id': 1,
          'division_key': 'hr',
          'name': 'ฝ่ายบริหารงานบุคคล',
          'view_menu_id': -201,
          'edit_menu_id': -301,
        },
        {
          'id': 2,
          'division_key': 'academic',
          'name': 'ฝ่ายบริหารงานวิชาการ',
          'view_menu_id': -202,
          'edit_menu_id': -302,
        },
        {
          'id': 3,
          'division_key': 'admin',
          'name': 'ฝ่ายบริหารงานทั่วไป',
          'view_menu_id': -203,
          'edit_menu_id': -303,
        },
        {
          'id': 4,
          'division_key': 'finance',
          'name': 'ฝ่ายบริหารงานงบประมาณ',
          'view_menu_id': -204,
          'edit_menu_id': -304,
        },
      ];
      final divAccMap = <String, Map<String, bool>>{};

      for (final d in divList) {
        final dId = d['id'];
        for (final r in rolesList) {
          final rId = r['id_role'] as int;
          final isAdminRole =
              (r['name'] as String).contains('ผู้ดูแลระบบ') ||
                  (r['name'] as String).contains('ผู้บริหาร');
          divAccMap['${dId}_$rId'] = {
            'can_view': true,
            'can_edit': isAdminRole,
          };
        }
      }

      if (schoolId != null) {
        try {
          final roleDivPermRows = await _firebaseService.inSchool(
            client
                .from('Permissions')
                .select('id_role, menu_id, status')
                .lte('menu_id', -201)
                .gte('menu_id', -304),
          );
          for (final row in (roleDivPermRows as List)) {
            final rId = int.tryParse(row['id_role']?.toString() ?? '');
            final mId = int.tryParse(row['menu_id']?.toString() ?? '');
            if (rId == null || mId == null) continue;
            final st = row['status'];
            final allowed = st == true ||
                st == 1 ||
                st.toString() == '1' ||
                st.toString().toUpperCase() == 'TRUE';

            for (final d in divList) {
              final dId = d['id'];
              if (d['view_menu_id'] == mId) {
                final cur = divAccMap['${dId}_$rId'] ??
                    {'can_view': true, 'can_edit': false};
                divAccMap['${dId}_$rId'] = {
                  'can_view': allowed,
                  'can_edit': allowed ? (cur['can_edit'] ?? false) : false,
                };
              } else if (d['edit_menu_id'] == mId) {
                final cur = divAccMap['${dId}_$rId'] ??
                    {'can_view': true, 'can_edit': false};
                divAccMap['${dId}_$rId'] = {
                  'can_view': allowed ? true : (cur['can_view'] ?? true),
                  'can_edit': allowed,
                };
              }
            }
          }
        } catch (e) {
          debugPrint('ℹ️ โหลดสิทธิ์ฝ่ายจาก Permissions ไม่สำเร็จ: $e');
        }
      }

      if (mounted) {
        setState(() {
          _schoolRoles = rolesList;
          _tabVisibilityByRole = tabVis;
          _schoolDivisions = divList;
          _divisionAccessMap = divAccMap;
          _loadingPerms = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ โหลดการตั้งค่าสิทธิ์เว็บโรงเรียนไม่สำเร็จ: $e');
      if (mounted) setState(() => _loadingPerms = false);
    }
  }

  Future<void> _saveVisibilitySettings() async {
    final client = _firebaseService.supabaseClient;
    if (client == null) return;

    setState(() => _savingPerms = true);
    final now = DateTime.now().toIso8601String();
    final schoolId = SchoolInfo.currentSchoolId;
    String? errorMsg;

    try {
      // 1) บันทึกสิทธิ์การมองเห็นแท็บ "เว็บโรงเรียน" (menu_id = 6) ลงตาราง Permissions
      final permRecords = <Map<String, dynamic>>[];
      for (final r in _schoolRoles) {
        final roleId = r['id_role'] as int;
        final roleName = r['name'] as String;
        final isAdminRole = roleName.contains('ผู้ดูแลระบบ');
        final allowed = isAdminRole ? true : (_tabVisibilityByRole[roleId] ?? true);

        permRecords.add(FirebaseService.withSchool('Permissions', {
          'id_role': roleId,
          'menu_id': 6,
          'status': allowed ? '1' : '0',
          'updatedAt': now,
        }));
      }

      if (permRecords.isNotEmpty) {
        await client
            .from('Permissions')
            .upsert(permRecords, onConflict: 'id_school,id_role,menu_id');
      }

      // 2) บันทึกสิทธิ์การมองเห็นและแก้ไขแต่ละฝ่ายในเว็บโรงเรียนลง Permissions (-201..-204 / -301..-304)
      if (schoolId != null && _schoolDivisions.isNotEmpty) {
        final divPermRecords = <Map<String, dynamic>>[];
        for (final d in _schoolDivisions) {
          final dId = d['id'] as int;
          final viewMenuId = d['view_menu_id'] as int?;
          final editMenuId = d['edit_menu_id'] as int?;
          if (viewMenuId == null || editMenuId == null) continue;

          for (final r in _schoolRoles) {
            final rId = r['id_role'] as int;
            final entry = _divisionAccessMap['${dId}_$rId'];
            final canView = entry?['can_view'] ?? true;
            final canEdit = canView ? (entry?['can_edit'] ?? false) : false;

            divPermRecords.add(FirebaseService.withSchool('Permissions', {
              'id_role': rId,
              'menu_id': viewMenuId,
              'status': canView ? '1' : '0',
              'updatedAt': now,
            }));
            divPermRecords.add(FirebaseService.withSchool('Permissions', {
              'id_role': rId,
              'menu_id': editMenuId,
              'status': canEdit ? '1' : '0',
              'updatedAt': now,
            }));
          }
        }

        if (divPermRecords.isNotEmpty) {
          await client
              .from('Permissions')
              .upsert(divPermRecords, onConflict: 'id_school,id_role,menu_id');
        }
      }

      widget.onPermissionsChanged?.call();
    } catch (e) {
      errorMsg = e.toString();
    } finally {
      if (mounted) {
        setState(() => _savingPerms = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: errorMsg == null ? AppColors.positive : AppColors.negative,
            content: Text(
              errorMsg == null
                  ? 'บันทึกสิทธิ์การมองเห็นเว็บโรงเรียนเรียบร้อยแล้ว'
                  : 'บันทึกไม่สำเร็จ: $errorMsg',
              style: GoogleFonts.sarabun(),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final embeddedUrl = _buildCurrentWebUrl(embedded: true);

    return Column(
      children: [
        // แถบควบคุมด้านบนของแท็บเว็บโรงเรียน
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  size: 18,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      SchoolInfo.fullName,
                      style: GoogleFonts.sarabun(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'ระบบบริหารงานโรงเรียน 4 ฝ่าย · คำสั่งแต่งตั้ง · งบประมาณ · บุคลากร',
                      style: GoogleFonts.sarabun(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // ปุ่มสลับหน้าย่อย: [ เว็บโรงเรียน | ตั้งค่าสิทธิ์การมองเห็น ]
              if (_isAdmin) ...[
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.raised,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildModeChip(
                        index: 0,
                        icon: Icons.web_rounded,
                        label: 'ใช้งานเว็บโรงเรียน',
                        onTap: () => setState(() => _activeView = 0),
                      ),
                      _buildModeChip(
                        index: 1,
                        icon: Icons.visibility_outlined,
                        label: 'ตั้งค่าสิทธิ์การมองเห็น',
                        onTap: () {
                          setState(() => _activeView = 1);
                          _loadVisibilitySettings();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
              ],

              // ปุ่มลัดเมื่ออยู่ในโหมดเว็บโรงเรียน
              if (_activeView == 0) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _subPath = 'division/hr/appointment-orders';
                      _reloadCounter++;
                    });
                  },
                  icon: const Icon(Icons.description_outlined, size: 16),
                  label: Text(
                    'คำสั่งแต่งตั้ง',
                    style: GoogleFonts.sarabun(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text,
                    side: const BorderSide(color: AppColors.line),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'รีเฟรชหน้าเว็บโรงเรียน',
                  onPressed: () => setState(() => _reloadCounter++),
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  onPressed: () {
                    final fullUrl = _buildCurrentWebUrl(embedded: false);
                    platform.openUrlInBrowser(fullUrl, sameTab: false);
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  label: Text(
                    'เปิดเต็มจอ',
                    style: GoogleFonts.sarabun(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // พื้นที่แสดงผลหลัก
        Expanded(
          child: _activeView == 0
              ? SchoolWebFrame(url: embeddedUrl)
              : _buildVisibilitySettingsPanel(),
        ),
      ],
    );
  }

  Widget _buildModeChip({
    required int index,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final active = _activeView == index;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: active ? AppColors.accent : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.sarabun(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.text : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilitySettingsPanel() {
    if (_loadingPerms) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.accent,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ส่วนหัว + ปุ่มบันทึก
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ตั้งค่าสิทธิ์การมองเห็นเว็บโรงเรียน (${SchoolInfo.fullName})',
                            style: GoogleFonts.sarabun(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'กำหนดว่าบทบาทใดในโรงเรียนจะมองเห็นแท็บ "เว็บโรงเรียน" บนแถบเมนู PC และสามารถเข้าดูหรือแก้ไขข้อมูลในแต่ละฝ่ายได้บ้าง',
                            style: GoogleFonts.sarabun(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _savingPerms ? null : _saveVisibilitySettings,
                      icon: _savingPerms
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(
                        _savingPerms ? 'กำลังบันทึก...' : 'บันทึกสิทธิ์การมองเห็น',
                        style: GoogleFonts.sarabun(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ส่วนที่ 1: สิทธิ์การมองเห็นแท็บ "เว็บโรงเรียน" บนเมนูซ้ายของแอปวันลา (PC)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. สิทธิ์การมองเห็นแท็บ "เว็บโรงเรียน" บนเมนูซ้าย (PC)',
                      style: GoogleFonts.sarabun(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'เปิด/ปิดการแสดงปุ่มเมนู "เว็บโรงเรียน" บนแถบเมนูด้านซ้ายของหน้าจอ PC ตามกลุ่มบทบาท',
                      style: GoogleFonts.sarabun(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _schoolRoles.map((role) {
                        final roleId = role['id_role'] as int;
                        final roleName = role['name'] as String;
                        final isAdminRole = roleName.contains('ผู้ดูแลระบบ');
                        final isVisible =
                            isAdminRole ? true : (_tabVisibilityByRole[roleId] ?? true);

                        return Container(
                          width: 220,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isVisible
                                ? AppColors.accentSoft.withValues(alpha: 0.35)
                                : AppColors.raised,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isVisible ? AppColors.accent : AppColors.line,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      roleName,
                                      style: GoogleFonts.sarabun(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.text,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      isVisible ? 'มองเห็นแท็บนี้' : 'ซ่อนแท็บนี้',
                                      style: GoogleFonts.sarabun(
                                        fontSize: 11,
                                        color: isVisible
                                            ? AppColors.accent
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: isVisible,
                                activeThumbColor: AppColors.accent,
                                onChanged: isAdminRole
                                    ? null
                                    : (val) {
                                        setState(() {
                                          _tabVisibilityByRole[roleId] = val;
                                        });
                                      },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ส่วนที่ 2: สิทธิ์การมองเห็นและแก้ไขแต่ละฝ่ายภายในเว็บโรงเรียน
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '2. สิทธิ์การมองเห็นและจัดการแต่ละฝ่ายภายในเว็บโรงเรียน',
                              style: GoogleFonts.sarabun(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'กำหนดสิทธิ์ให้แต่ละบทบาทมองเห็นฝ่ายงาน (ดูได้) หรือมีสิทธิ์สร้าง/แก้ไขข้อมูล เช่น คำสั่งแต่งตั้ง และงบประมาณ (แก้ไขได้)',
                              style: GoogleFonts.sarabun(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _subPath = 'admin/division-permissions';
                                  _activeView = 0;
                                  _reloadCounter++;
                                });
                              },
                              icon: const Icon(Icons.lock_outline_rounded, size: 16),
                              label: Text(
                                'สิทธิ์ราย Module ย่อย',
                                style: GoogleFonts.sarabun(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _subPath = 'user-permissions';
                                  _activeView = 0;
                                  _reloadCounter++;
                                });
                              },
                              icon: const Icon(Icons.person_outline_rounded, size: 16),
                              label: Text(
                                'กำหนดสิทธิ์รายบุคคล',
                                style: GoogleFonts.sarabun(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _subPath = 'admin/mapping';
                                  _activeView = 0;
                                  _reloadCounter++;
                                });
                              },
                              icon: const Icon(Icons.tune_rounded, size: 16),
                              label: Text(
                                'จับคู่ Module รายฝ่าย',
                                style: GoogleFonts.sarabun(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_schoolDivisions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'กำลังใช้โครงสร้าง 4 ฝ่ายมาตรฐานของโรงเรียน (กดปุ่ม "ตั้งค่า Module รายฝ่าย" เพื่อปรับแต่งเพิ่มเติม)',
                          style: GoogleFonts.sarabun(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor:
                              WidgetStateProperty.all(AppColors.raised),
                          columns: [
                            DataColumn(
                              label: Text(
                                'ฝ่ายของโรงเรียน',
                                style: GoogleFonts.sarabun(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            ..._schoolRoles.map(
                              (r) => DataColumn(
                                label: Text(
                                  r['name'] as String,
                                  style: GoogleFonts.sarabun(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          rows: _schoolDivisions.map((div) {
                            final dId = div['id'] as int;
                            final dName = (div['name'] ?? '').toString();

                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    dName,
                                    style: GoogleFonts.sarabun(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                ..._schoolRoles.map((r) {
                                  final rId = r['id_role'] as int;
                                  final key = '${dId}_$rId';
                                  final entry = _divisionAccessMap[key] ??
                                      {'can_view': true, 'can_edit': false};
                                  final canView = entry['can_view'] ?? true;
                                  final canEdit = entry['can_edit'] ?? false;

                                  return DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FilterChip(
                                          label: Text(
                                            'ดูได้',
                                            style: GoogleFonts.sarabun(
                                              fontSize: 11,
                                            ),
                                          ),
                                          selected: canView,
                                          onSelected: (v) {
                                            setState(() {
                                              _divisionAccessMap[key] = {
                                                'can_view': v,
                                                'can_edit': v ? canEdit : false,
                                              };
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 6),
                                        FilterChip(
                                          label: Text(
                                            'แก้ไขได้',
                                            style: GoogleFonts.sarabun(
                                              fontSize: 11,
                                            ),
                                          ),
                                          selected: canEdit,
                                          onSelected: (v) {
                                            setState(() {
                                              _divisionAccessMap[key] = {
                                                'can_view': v ? true : canView,
                                                'can_edit': v,
                                              };
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            );
                          }).toList(),
                        ),
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
}
