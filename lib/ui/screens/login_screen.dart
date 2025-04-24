import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Import for secure storage
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _storage =
      const FlutterSecureStorage(); // Create a SecureStorage instance
  bool _obscurePassword = true; // For password visibility toggle

  // Function to handle login
  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Show a loading indicator
        showDialog(
          context: context,
          builder:
              (context) => const Center(child: CircularProgressIndicator()),
        );

        // Use Firebase Auth to sign in
        final UserCredential userCredential = await _auth
            .signInWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );

        // Get the user
        final User? user = userCredential.user;

        if (user != null) {
          // Get the authentication token
          final String? token = await user.getIdToken();
          if (token != null) {
            print('Login successful! User ID: ${user.uid}');
            print('Authentication Token: $token');
            // Store the token securely with expiration
            await _storeToken(token, user.uid); // Pass user ID
            // Dismiss the loading indicator
            Navigator.of(context).pop();
            // Navigate to the next screen
            Navigator.pushReplacementNamed(context, '/home');
          } else {
            Navigator.of(context).pop();
            _showErrorDialog("Failed to retrieve authentication token.");
          }
        }
      } on FirebaseAuthException catch (e) {
        // Handle Firebase Auth errors
        Navigator.of(context).pop();
        if (e.code == 'user-not-found') {
          _showErrorDialog('No user found for that email.');
        } else if (e.code == 'wrong-password') {
          _showErrorDialog('Wrong password provided for that user.');
        } else {
          _showErrorDialog('Login error: ${e.message}');
        }
      } catch (e) {
        // Handle other errors
        Navigator.of(context).pop();
        _showErrorDialog('Error during login: $e');
      }
    }
  }

  // Function to store the token securely with expiration
  Future<void> _storeToken(String token, String userId) async {
    // Calculate the expiration time (1 day from now)
    final expiration =
        DateTime.now().add(const Duration(days: 1)).toIso8601String();

    // Store the token and expiration time as a JSON string
    await _storage.write(key: 'auth_token', value: token);
    await _storage.write(key: 'auth_expiration', value: expiration);
    await _storage.write(key: 'user_id', value: userId);
  }

  // Function to show an error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Login Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: Colors.white),
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            // Make the form scrollable
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Welcome Back', // Welcoming text as title
                    style: GoogleFonts.chivo(
                      fontSize: 32.0,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF000000),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8.0),
                  const Text(
                    'Sign in to continue', // Greeting text below title
                    style: TextStyle(fontSize: 16.0, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30.0),
                  SizedBox(
                    height: 50.0,
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        // Use outlined input border
                        prefixIcon: Icon(Icons.email),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF003459)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.black,
                            width: 2.0,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty ||
                            !value.contains('@')) {
                          return 'Please enter a valid email.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  SizedBox(
                    height: 50.0,
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        // Use outlined input border
                        prefixIcon: const Icon(Icons.lock),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF003459)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.black,
                            width: 2.0,
                          ),
                        ),
                        suffixIcon: IconButton(
                          // Password visibility toggle
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty ||
                            value.length < 6) {
                          return 'Password must be at least 6 characters.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 24.0),
                  ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      backgroundColor: const Color(0xFF00a8e8),
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/signup');
                    },
                    child: const Text(
                      "Don't have an account? Sign up",
                      style: TextStyle(fontSize: 16, color: Color(0xFF007ea7)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
