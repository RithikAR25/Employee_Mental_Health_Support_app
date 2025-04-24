import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context) async {
    final auth = FirebaseAuth.instance;
    final storage = const FlutterSecureStorage();
    try {
      await auth.signOut();
      await storage.delete(key: 'auth_token');
      await storage.delete(key: 'auth_expiration');
      await storage.delete(key: 'user_id');
      // Navigate to the Welcome screen after successful logout
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/welcome');
      }
    } catch (e) {
      print("Error during logout: $e");
      // Optionally show an error message to the user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error signing out. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text(
            'Settings Page Content',
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _logout(context),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
