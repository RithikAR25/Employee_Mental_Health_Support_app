import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  String? _userName;
  String? _userAvatar;
  Map<String, dynamic> _userDetails = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final snapshot = await _database.child('users/${user.uid}').get();
        if (snapshot.value != null && snapshot.value is Map) {
          setState(() {
            _userDetails = Map<String, dynamic>.from(snapshot.value as Map);
            _userName = _userDetails['name'];
            _userAvatar = _userDetails['avatar'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not load profile data.')),
            );
          }
        }
      } catch (error) {
        print("Error fetching user profile: $error");
        setState(() {
          _isLoading = false;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error loading profile.')),
          );
        }
      }
    } else {
      setState(() {
        _isLoading = false;
      });
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    final auth = FirebaseAuth.instance;
    final storage = const FlutterSecureStorage();
    try {
      await auth.signOut();
      await storage.delete(key: 'auth_token');
      await storage.delete(key: 'auth_expiration');
      await storage.delete(key: 'user_id');
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/welcome');
      }
    } catch (e) {
      print("Error during logout: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error signing out. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Your Profile',
          style: TextStyle(color: Color(0xFF00171F)),
        ),
        backgroundColor: Color(0xFF007EA7),
        iconTheme: const IconThemeData(color: Color(0xFF00171F)),
        elevation: 0.8,
      ),
      backgroundColor: const Color(0xFFF0F0F5),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        if (_userName != null)
                          Column(
                            // <-- Modification: Added Column here
                            children: [
                              CircleAvatar(
                                radius: MediaQuery.of(context).size.width * 0.2,
                                backgroundImage:
                                    _userAvatar != null
                                        ? AssetImage(
                                          'assets/avatars/$_userAvatar',
                                        )
                                        : const AssetImage(
                                          'assets/avatars/avatar1.png',
                                        ),
                              ),
                              const SizedBox(height: 16),
                              // <-- Modified: width changed to height
                              Text(
                                _userName!,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00171F),
                                ),
                              ),
                            ],
                          ), // <-- End of Column
                      ],
                    ),

                    const SizedBox(height: 24),

                    _buildDetailRow('Email', _userDetails['email']),
                    _buildDetailRow('Name', _userDetails['name']),
                    _buildDetailRow('Location', _userDetails['location']),
                    _buildDetailRow('Age Range', _userDetails['ageRange']),
                    _buildDetailRow('Profession', _userDetails['profession']),
                    _buildDetailRow(
                      'Mental Health Issue(s)',
                      (_userDetails['mentalHealthIssue'] as List?)?.join(
                            ', ',
                          ) ??
                          'Not specified',
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _logout(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFED1A3B),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Logout',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF007EA7),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: Align(
              // <-- Modification: Added Align widget
              alignment: Alignment.centerRight,
              // <-- Modification: Align text to end (right)
              child: Text(
                value ?? 'Not specified',
                style: const TextStyle(color: Color(0xFF00171F)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
