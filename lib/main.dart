import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mental_health_support_app/ui/feature_pages/all_doctors_page.dart';
import 'package:mental_health_support_app/ui/feature_pages/doctor_details_page.dart';

import 'firebase_options.dart';
import 'ui/feature_pages/profile_page.dart';
import 'ui/screens/feature_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/sign_up_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/welcome_screen.dart';

// Create a global function to check token expiration
Future<void> checkTokenExpiration(BuildContext? context) async {
  if (context == null) {
    print("checkTokenExpiration called with null context, cannot navigate");
    return; // Important: Exit if context is null
  }
  final storage = const FlutterSecureStorage();
  final auth = FirebaseAuth.instance;
  final expirationString = await storage.read(key: 'auth_expiration');
  if (expirationString != null) {
    try {
      final expiration = DateTime.parse(expirationString);
      print("Global Token expiration time: $expiration");
      if (DateTime.now().isAfter(expiration)) {
        // Token has expired, log out the user
        await auth.signOut();
        await storage.delete(key: 'auth_token');
        await storage.delete(key: 'auth_expiration');
        await storage.delete(key: 'user_id');
        // Redirect to welcome.  Use a pushAndRemoveUntil to prevent the user
        // from being able to go back to the expired session.
        if (context.mounted) {
          // Check if context is still valid
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
            (route) => false, // Remove all previous routes
          );
        } else {
          print("Context is no longer valid, cannot navigate");
        }
      }
    } catch (e) {
      print("Error parsing expiration time: $e");
      await auth.signOut();
      await storage.delete(key: 'auth_token');
      await storage.delete(key: 'auth_expiration');
      await storage.delete(key: 'user_id');
      if (context.mounted) {
        // Check if context is still valid
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false, // Remove all previous routes
        );
      } else {
        print("Context is no longer valid, cannot navigate");
      }
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set preferred orientations here
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Timer? _timer;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(hours: 1), (timer) {
      // Use the Navigator's context, which is guaranteed to be valid.
      checkTokenExpiration(_navigatorKey.currentContext);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      // ADD THIS LINE
      title: 'Employee Mental Health Support',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily:
            GoogleFonts.cambo().fontFamily, // Apply cambo as the default font
        textTheme: TextTheme(
          // Use roboto for headings and cambo for the rest
          displayLarge: GoogleFonts.roboto(),
          displayMedium: GoogleFonts.roboto(),
          displaySmall: GoogleFonts.roboto(),
          headlineLarge: GoogleFonts.roboto(),
          headlineMedium: GoogleFonts.roboto(),
          headlineSmall: GoogleFonts.roboto(),
          titleLarge: GoogleFonts.roboto(),
          titleMedium: GoogleFonts.roboto(),
          titleSmall: GoogleFonts.roboto(),
          bodyLarge: GoogleFonts.cambo(),
          // Default font
          bodyMedium: GoogleFonts.cambo(),
          // Default font
          labelLarge: GoogleFonts.cambo(),
          // Default font
          labelMedium: GoogleFonts.cambo(),
          // Default font
          labelSmall: GoogleFonts.cambo(), // Default font
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: const Color(0xFFed1a3b),
          // Default color for all CircularProgressIndicators
          circularTrackColor: const Color(0xFF3a769d),
          // Default background color
          strokeCap: StrokeCap.round,
        ),
      ),
      home: const SplashScreen(),
      // Set SplashScreen as the initial screen
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        // Define WelcomeScreen route
        '/signup': (context) => const SignUpScreen(),
        // Define SignUpScreen route
        '/login': (context) => const LoginScreen(),
        // Define LoginScreen route
        '/home': (context) => FeaturePage(),
        '/profile': (context) => const ProfilePage(),
        '/allDoctors': (context) => const AllDoctorsPage(),
        '/doctorDetails': (context) => const DoctorDetailsPage(),
      },
    );
  }
}
