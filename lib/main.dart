import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';  // ← เพิ่มบรรทัดนี้
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/responsive_layout.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:thai_buddhist_date/thai_buddhist_date.dart' as tbd;
import 'utils/school_info.dart';

Future<void> clearSessionPrefs(SharedPreferences prefs) async {
  await prefs.remove('isLoggedIn');
  await prefs.remove('loginAt');
  await prefs.remove('currentUser');
  await prefs.remove('userRole');
  await prefs.remove('userFullDataJson');
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
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV6aWFqYmxxbGJydnFteHZpenNpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2Njc1MzIsImV4cCI6MjA5OTI0MzUzMn0.cpnt8uctNacuJWNelYx5C_oP0xEPtUhzvNDgyWkg0ZA',
    )
        .then((_) => debugPrint('✅ Supabase initialized'))
        .catchError((e) => debugPrint("❌ Supabase Initialize Error: $e"));
  }

  Future<void> _handleBackgroundStartup() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final int? loginAt = prefs.getInt('loginAt');

      if (isLoggedIn && loginAt != null) {
        // 🚀 จำ session จาก SharedPreferences ล้วน (เลิกพึ่ง FirebaseAuth)
        // ตรวจสอบอายุการล็อกอิน (ตัวอย่าง 2 ชั่วโมง)
        if ((DateTime.now().millisecondsSinceEpoch - loginAt) <
            (2 * 60 * 60 * 1000)) {
          // ยังไม่หมดอายุ — แต่ต้องมี session ของ Supabase Auth อยู่จริงด้วย
          //
          // หลังเปิด RLS ถ้าเข้าหน้าหลักโดยไม่มี session จะอ่านฐานข้อมูลไม่ได้
          // สักตาราง หน้าจอจะว่างเปล่าโดยไม่บอกสาเหตุ — เช็กตรงนี้แล้วเด้งกลับ
          // ไปหน้า Login ให้ล็อกอินใหม่จะชัดเจนกว่า
          try {
            await _supabaseReady;
          } catch (_) {
            // ต่อ Supabase ไม่ได้ — ปล่อยให้ตกไปทางล้าง session ข้างล่าง
          }
          final hasSession =
              Supabase.instance.client.auth.currentSession != null;
          if (hasSession) {
            // ชื่อโรงเรียนมาจากตาราง Schools ต้องโหลดก่อนวาดใบลา
            // ถ้าโหลดไม่ได้จะใช้ค่าสำรอง ไม่บล็อกการเข้าแอป
            await SchoolInfo.load();
            if (mounted) setState(() => _homeWidget = const ResponsiveLayout());
          } else {
            debugPrint('ℹ️  ไม่พบ session ของ Supabase Auth — กลับไปหน้า Login');
            await clearSessionPrefs(prefs);
          }
        } else {
          // หมดอายุ → ล้าง session แล้วกลับไปหน้า Login
          await clearSessionPrefs(prefs);
        }
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E293B)),
        useMaterial3: true,
        textTheme: GoogleFonts.sarabunTextTheme(),
      ),
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
