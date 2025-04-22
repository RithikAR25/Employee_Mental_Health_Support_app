import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  String? _ageRange;
  String? _profession;
  String? _mentalHealthIssue;
  String? _avatar;

  final List<String> _ageRanges = ['18-24', '25-34', '35-44', '45-54', '55+'];
  final List<String> _professions = [
    'IT',
    'Business',
    'Education',
    'Healthcare',
    'Other'
  ];
  final List<String> _mentalHealthIssues = [
    'Stress',
    'Anxiety',
    'Depression',
    'Burnout',
    'Other'
  ];
  final List<String> _avatars = [
    'avatar1.png',
    'avatar2.png',
    'avatar3.png',
    'avatar4.png',
    'avatar5.png'
  ];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  bool _obscurePassword = true;

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate() &&
        _ageRange != null &&
        _profession != null &&
        _mentalHealthIssue != null &&
        _avatar != null) {
      try {
        // Show a loading indicator
        showDialog(
          context: context,
          builder: (context) =>
          const Center(child: CircularProgressIndicator()),
        );

        final UserCredential userCredential =
        await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        final User? user = userCredential.user;
        if (user != null) {
          // Store additional user information in Realtime Database
          await _database.child('users/${user.uid}').set({
            'email': _emailController.text.trim(),
            'name': _nameController.text.trim(),
            'location': _locationController.text.trim(),
            'ageRange': _ageRange,
            'profession': _profession,
            'mentalHealthIssue': _mentalHealthIssue,
            'avatar': _avatar,
            'createdAt': DateTime.now().toIso8601String(),
          });

          // Send email verification
          await user.sendEmailVerification();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification email sent!')),
          );

          // Add user to the relevant chat group
          await _joinChatGroup(user.uid, _mentalHealthIssue!);

          // Navigate to the next screen (e.g., login screen)
          Navigator.of(context).pushReplacementNamed(
              '/login'); // Replace with your route
        }
        Navigator.of(context).pop();
      } on FirebaseAuthException catch (e) {
        String errorMessage = 'An error occurred during sign-up.';
        if (e.code == 'weak-password') {
          errorMessage = 'The password provided is too weak.';
        } else if (e.code == 'email-already-in-use') {
          errorMessage = 'The account already exists for that email.';
        }
        Navigator.of(context).pop();
        _showErrorDialog(errorMessage);
      } catch (e) {
        print('Error during sign-up: $e');
        Navigator.of(context).pop();
        _showErrorDialog('An unexpected error occurred.');
      }
    } else {
      _showErrorDialog('Please fill in all the required fields.');
    }
  }

  Future<void> _joinChatGroup(String userId, String groupName) async {
    await _database.child('chat_groups/$groupName/members/$userId').set(true);
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Up Error'),
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
                'assets/bgimage/peak_background.jpg'), // Use the same background
            fit: BoxFit.cover,
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: SafeArea( // Added SafeArea
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[

                    const Text(
                      "Let's create your account", // Friendly welcome text
                      style: TextStyle(fontSize: 18, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30.0),
                    Text(
                      '👤 Personal Info', // Section heading
                      style: GoogleFonts.chivo(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8.0),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFff8600)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black, width: 2.0),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFff8600)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black, width: 2.0),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your location.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Age Range',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFff8600)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black, width: 2.0),
                        ),
                      ),
                      value: _ageRange,
                      items: _ageRanges
                          .map((range) => DropdownMenuItem(
                        value: range,
                        child: Text(range),
                      ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _ageRange = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select your age range.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Working Profession',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.work),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFff8600)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black, width: 2.0),
                        ),
                      ),
                      value: _profession,
                      items: _professions
                          .map((profession) => DropdownMenuItem(
                        value: profession,
                        child: Text(profession),
                      ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _profession = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select your working profession.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30.0),
                    Text(
                      '🧠 Mental Health Info', // Section heading
                      style: GoogleFonts.chivo(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8.0),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Mental Health Issue',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.health_and_safety),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFff8600)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black, width: 2.0),
                        ),
                      ),
                      value: _mentalHealthIssue,
                      items: _mentalHealthIssues
                          .map((issue) => DropdownMenuItem(
                        value: issue,
                        child: Text(issue),
                      ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _mentalHealthIssue = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select your mental health issue.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30.0),
                    Text(
                      '🔒 Security Info', // Section heading
                      style: GoogleFonts.chivo(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8.0),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFff8600)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black, width: 2.0),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty || !value.contains('@')) {
                          return 'Please enter a valid email.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFff8600)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black, width: 2.0),
                        ),
                        suffixIcon: IconButton(
                          // Password visibility toggle
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty || value.length < 6) {
                          return 'Password must be at least 6 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      '🎨 Choose Avatar', // Section heading
                      style: GoogleFonts.chivo(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100, // Adjust as needed
                      child: GridView.builder(
                        gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5, // Adjust as needed
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: _avatars.length,
                        itemBuilder: (context, index) {
                          final avatar = _avatars[index];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _avatar = avatar;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _avatar == avatar
                                      ? const Color(0xFF758bfd)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Image.asset(
                                'assets/avatars/$avatar',
                                //  width: 50,  // Removed width and height, let GridView handle it
                                // height: 50,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    ElevatedButton(
                      onPressed: _signUp,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        backgroundColor: const Color(0xFF758bfd),
                      ),
                      child:
                      const Text('Sign Up', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/login');
                      },
                      child: const Text("Already have an account? Login",
                          style: TextStyle(fontSize: 16)),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

