import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    // Simulate a loading process or delay
    await Future.delayed(const Duration(seconds: 3));

    // Check if the user is logged in
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    final storage = const FlutterSecureStorage();
    final expirationString = await storage.read(key: 'auth_expiration');

    if (user != null && expirationString != null) {
      try {
        final expiration = DateTime.parse(expirationString);
        if (DateTime.now().isBefore(expiration)) {
          // User is logged in and token is not expired
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/home');
          }
          return;
        }
      } catch (e) {
        print("Error parsing expiration time during splash: $e");
        // Fallback to welcome screen if there's an error
      }
    }

    // If not logged in or token expired, navigate to WelcomeScreen
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            SvgPicture.asset('assets/logo/app_logo.svg', width: 50, height: 50),
          ],
        ),
      ),
    );
  }
}
