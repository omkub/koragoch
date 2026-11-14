import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/responsive_layout.dart';
import 'theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:thai_buddhist_date/thai_buddhist_date.dart' as tbd;
import 'services/firebase_service.dart';
import 'utils/school_info.dart';
import 'utils/staff_status.dart';
import 'utils/web_platform.dart' as platform;
import 'widgets/update_banner.dart';

Future<void> clearSessionPrefs(SharedPreferences prefs) async {
  await prefs.remove('isLoggedIn');
  await prefs.remove('loginAt');
  await prefs.remove('currentUser');
  await prefs.remove('userRole');
  await prefs.remove('userFullDataJson');
  platform.clearBrowserSsoStorage();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    debugPrint('✅ Firebase initialized');
  } catch (e) {
    debugPrint("❌ Firebase Initialize Error: $e");
  }

  runApp(const MyApp());

  tbd.ThaiDateService()
      .initializeLocale('th_TH')
      .catchError((e) => debugPrint("Thai Date Initialize Error: $e"));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Widget _homeWidget = const LoginScreen();

  /// งาน initialize ของ Supabase — เก็บไว้เพื่อให้ตอนเช็ก session รอได้ถูกจังหวะ
  Future<void>? _supabaseReady;

  @override
  void initState() {
    super.initState();
    _supabaseReady = _initializeSupabaseInBackground();
    _handleBackgroundStartup();
  }

  Future<void> _initializeSupabaseInBackground() {
    return Supabase.initialize(
      url: 'https://uziajblqlbrvqmxvizsi.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV6aWFqYmxxbGJydnFteHZpenNpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2Njc1MzIsImV4cCI6MjA5OTI0MzUzMn0.cpnt8uctNacuJWNelYx5C_oP0xEPtUhzvNDgyWkg0ZA',
    )
        .then((_) => debugPrint('✅ Supabase initialized'))
        .catchError((e) => debugPrint("❌ Supabase Initialize Error: $e"));
  }

  String _resolveEffectiveRole(Iterable<dynamic> values) {
    final roles = values
        .where((value) => value != null)
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList();

    if (roles.contains('ผู้ดูแลระบบ')) return 'ผู้ดูแลระบบ';
    if (roles.contains('ผู้บริหาร')) return 'ผู้บริหาร';
    if (roles.contains('ครู')) return 'ครู';
    return roles.isNotEmpty ? roles.first : 'ครู';
  }

  Future<String> _resolveRoleFromSupabase(
    SupabaseClient supabase,
    Map<String, dynamic> userData,
  ) async {
    final direct = _resolveEffectiveRole([
      userData['role'],
      userData['permission'],
    ]);
    if (direct != 'ครู') return direct;

    final idRole = userData['id_role'];
    if (idRole != null) {
      try {
        final rows = await supabase
            .from('roles')
            .select('Accessrights')
            .eq('ID_Roles', idRole)
            .limit(1);
        if (rows.isNotEmpty) {
          final name = (rows.first['Accessrights'] ?? '').toString().trim();
          if (name.isNotEmpty) return _resolveEffectiveRole([name]);
        }
      } catch (e) {
        debugPrint('resolve role error: $e');
      }
    }
    return direct;
  }

  /// เติมข้อมูลผู้ใช้ลง SharedPreferences อัตโนมัติจาก Supabase Session (สำหรับ SSO จากเว็บโรงเรียน /central/)
  Future<bool> _hydratePrefsFromSupabaseSession(SharedPreferences prefs) async {
    try {
      final supabase = Supabase.instance.client;
      final authUid = supabase.auth.currentUser?.id;
      if (authUid == null || authUid.isEmpty) return false;

      final rows = await supabase
          .from('Teachers')
          .select()
          .eq('auth_uid', authUid)
          .limit(1);
      if (rows.isEmpty) return false;

      final userData = Map<String, dynamic>.from(rows.first as Map);
      final teacherPk = userData['id_user'];
      final teacherDocId =
          (userData['firebase_uid'] ?? teacherPk ?? '').toString();
      final effectiveRole = await _resolveRoleFromSupabase(supabase, userData);

      userData['role'] = effectiveRole;
      userData['permission'] = effectiveRole;
      userData['id'] = teacherDocId;

      final firebaseService = FirebaseService();
      final enrichedUser = await firebaseService.enrichTeacher(userData);

      final safeJson = jsonEncode({
        ...enrichedUser,
        'id': teacherDocId,
        'role': effectiveRole,
        'permission': effectiveRole,
      }, toEncodable: (item) {
        if (item is DateTime) return item.toIso8601String();
        return item.toString();
      });

      await prefs.setBool('isLoggedIn', true);
      await prefs.setInt('loginAt', DateTime.now().millisecondsSinceEpoch);
      await prefs.setString('currentUser',
          (userData['fullName'] ?? userData['name'] ?? 'ผู้ใช้งาน').toString());
      await prefs.setString('userRole', effectiveRole);
      await prefs.setString('userFullDataJson', safeJson);
      return true;
    } catch (e) {
      debugPrint('SSO Hydrate Error: $e');
      return false;
    }
  }

  Future<void> _handleBackgroundStartup() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      try {
        await _supabaseReady?.timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('⚠️  รอ Supabase ไม่สำเร็จ: $e');
      }

      final supabase = Supabase.instance.client;

      // 🔗 ตรวจรับ SSO Session จากเว็บโรงเรียน (/central/) ทั้งจาก URL และ localStorage
      final ssoRefreshToken = platform.consumeIncomingSsoRefreshToken();
      if (ssoRefreshToken != null &&
          ssoRefreshToken.isNotEmpty &&
          supabase.auth.currentSession == null) {
        try {
          await supabase.auth.setSession(ssoRefreshToken);
          debugPrint('✅ รับ SSO Session จากเว็บโรงเรียนสำเร็จ');
        } catch (e) {
          debugPrint('⚠️  ตั้งค่า SSO Session ไม่สำเร็จ: $e');
        }
      }

      final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final int? loginAt = prefs.getInt('loginAt');
      final String? cachedUserJson = prefs.getString('userFullDataJson');
      final bool isPrefsFresh = isLoggedIn &&
          loginAt != null &&
          cachedUserJson != null &&
          cachedUserJson.isNotEmpty &&
          (DateTime.now().millisecondsSinceEpoch - loginAt) <
              (2 * 60 * 60 * 1000);

      var hasSession = supabase.auth.currentSession != null;

      if (hasSession) {
        // ตรวจสถานะปฏิบัติงาน (ต้องยังปฏิบัติงานอยู่)
        final status = await FirebaseService.myEmploymentStatus();
        if (status != null && status != StaffStatus.active) {
          await supabase.auth.signOut();
          await clearSessionPrefs(prefs);
          return;
        }

        // ถ้ามี session ใน Supabase อยู่แล้ว (เช่น กดสลับมาจากเว็บโรงเรียน /central/)
        // แต่ใน SharedPreferences ยังไม่มีข้อมูลหรือหมดอายุ ให้ดึงข้อมูลจาก Teachers มาเติมให้อัตโนมัติ
        var readyToEnter = isPrefsFresh;
        if (!readyToEnter) {
          readyToEnter = await _hydratePrefsFromSupabaseSession(prefs);
        }

        if (readyToEnter) {
          await SchoolInfo.load(force: !isPrefsFresh);
          if (mounted) {
            setState(() => _homeWidget = const ResponsiveLayout());
          }
          return;
        }
      }

      if (isLoggedIn) {
        debugPrint('ℹ️  ไม่พบ session ที่ใช้งานได้ — ล้างค่าและแสดงหน้า Login');
        await clearSessionPrefs(prefs);
      }
    } catch (e) {
      debugPrint("Startup Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ระบบวันลา',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // 🇹🇭 เปิดโหมดภาษาไทยให้แอปครับ 🥇🏆
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('th', 'TH'), // ไทย
        Locale('en', 'US'), // อังกฤษ
      ],
      locale: const Locale('th', 'TH'), // บังคับใช้ภาษาไทยเป็นค่าเริ่มต้นครับ
      // 🔥 บังคับใช้ฟิสิกส์การเลื่อนแบบหยุดกึก (Clamping) เพื่อไม่ให้ติด Bug ใน LINE Browser ครับ 🥇🏆
      scrollBehavior: const MyScrollBehavior(),
      // โชว์หน้า Login ทันที! (ไม่มีหน้าแดง ไม่มีค้างแน่นอนครับ)🏁🏆🥇🚀
      home: _homeWidget,
      // แถบ "มีเวอร์ชันใหม่" ลอยบนทุกหน้า (ไม่บังคับอัปเดต)
      builder: (context, child) =>
          UpdateBanner(child: child ?? const SizedBox.shrink()),
    );
  }
}

// 🚀 คลาสควบคุมพฤติกรรมการเลื่อน (Custom Scroll Behavior) 🕵️‍♂️🥇🏆
class MyScrollBehavior extends MaterialScrollBehavior {
  const MyScrollBehavior();

  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child; // ซ่อน Scrollbar ของ Browser หากต้องการ
  }

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child; // ปิดเอฟเฟกต์การเด้ง (Glow/Bounce) ที่ขอบจอ
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // 🥇 บังคับใช้ Clamping เพื่อป้องกันระบบ "ลากเพื่อปิด" ของ LINE Browser ครับ 🏆
    return const ClampingScrollPhysics();
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
