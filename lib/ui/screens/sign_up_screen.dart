import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
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
  String? _selectedAgeRange;
  String? _selectedProfession;
  final Set<String> _selectedMentalHealthIssues = {};
  String? _avatar;

  final List<String> _ageRanges = ['18-24', '25-34', '35-44', '45-54', '55+'];

  final List<String> _professions = [
    'IT',
    'Business',
    'Education',
    'Healthcare',
    'Other',
  ];

  final List<String> _mentalHealthIssues = [
    'Stress',
    'Anxiety',
    'Depression',
    'Burnout',
    'Other',
  ];

  final List<String> _avatars = [
    'avatar1.png',
    'avatar2.png',
    'avatar3.png',
    'avatar4.png',
    'avatar5.png',
  ];

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  bool _obscurePassword = true;

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate() &&
        _selectedAgeRange != null &&
        _selectedProfession != null &&
        _selectedMentalHealthIssues.isNotEmpty &&
        _avatar != null) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false, // prevent closing manually
          builder:
              (context) => const Center(child: CircularProgressIndicator()),
        );

        final UserCredential userCredential = await _auth
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );

        final User? user = userCredential.user;
        if (user != null) {
          await _database.child('users/${user.uid}').set({
            'email': _emailController.text.trim(),
            'name': _nameController.text.trim(),
            'location': _locationController.text.trim(),
            'ageRange': _selectedAgeRange,
            'profession': _selectedProfession,
            'mentalHealthIssue': _selectedMentalHealthIssues.toList(),
            'avatar': _avatar,
            'createdAt': DateTime.now().toIso8601String(),
          });

          await user.sendEmailVerification();

          // CLOSE the loading dialog before showing snackbar or navigating
          Navigator.of(context).pop(); // <<=== ADDED this line

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification email sent!')),
          );

          // Add user to relevant chat groups
          for (final issue in _selectedMentalHealthIssues) {
            await _joinChatGroup(user.uid, issue);
          }

          // Navigate to login screen
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } on FirebaseAuthException catch (e) {
        Navigator.of(context).pop(); // Close loading dialog
        String errorMessage = 'An error occurred during sign-up.';
        if (e.code == 'weak-password') {
          errorMessage = 'The password provided is too weak.';
        } else if (e.code == 'email-already-in-use') {
          errorMessage = 'The account already exists for that email.';
        }
        _showErrorDialog(errorMessage);
      } catch (e) {
        print('Error during sign-up: $e');
        Navigator.of(context).pop(); // Close loading dialog
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

      builder:
          (context) => AlertDialog(
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
        decoration: const BoxDecoration(color: Colors.white),

        padding: const EdgeInsets.all(16.0),

        child: Center(
          child: SingleChildScrollView(
            child: SafeArea(
              // Added SafeArea
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
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00171F),
                      ),
                    ),

                    const SizedBox(height: 8.0),

                    SizedBox(
                      height: 50,
                      child: TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF007ea7)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0xFF003459),
                              width: 2.0,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your name.';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 16.0),

                    SizedBox(
                      height: 50,
                      child: TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF007ea7)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0xFF003459),
                              width: 2.0,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your location.';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 16.0),

                    Text(
                      'Age Range',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00171F),
                      ),
                    ),
                    Wrap(
                      spacing: 6.0,
                      children:
                          _ageRanges
                              .map(
                                (range) => ChoiceChip(
                                  backgroundColor: Color(0xFFF0F0F5),
                                  label: Text(range),
                                  selected: _selectedAgeRange == range,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedAgeRange =
                                          selected ? range : null;
                                    });
                                  },

                                  labelStyle: TextStyle(
                                    color:
                                        _selectedAgeRange == range
                                            ? Colors
                                                .white // Color when selected
                                            : Color(0xFF003459),
                                  ),
                                  selectedColor: const Color(0xFF758bfd),
                                  // Color of the chip when selected
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                              )
                              .toList(),
                    ),

                    if (_selectedAgeRange == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 6.0),
                        child: Text(
                          'Please select your age range.',
                          style: TextStyle(color: Colors.red, fontSize: 12.0),
                        ),
                      ),
                    const SizedBox(height: 16.0),
                    Text(
                      'Working Profession',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00171F),
                      ),
                    ),
                    Wrap(
                      spacing: 6.0,
                      children:
                          _professions
                              .map(
                                (profession) => ChoiceChip(
                                  backgroundColor: Color(0xFFF0F0F5),
                                  label: Text(profession),
                                  selected: _selectedProfession == profession,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedProfession =
                                          selected ? profession : null;
                                    });
                                  },
                                  labelStyle: TextStyle(
                                    color:
                                        _selectedProfession == profession
                                            ? Colors
                                                .white // Color when selected
                                            : Color(0xFF003459),
                                  ),
                                  selectedColor: const Color(0xFF758bfd),
                                  // Color of the chip when selected
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                              )
                              .toList(),
                    ),

                    if (_selectedProfession == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 6.0),
                        child: Text(
                          'Please select your working profession.',
                          style: TextStyle(color: Colors.red, fontSize: 12.0),
                        ),
                      ),

                    const SizedBox(height: 30.0),

                    Text(
                      '🧠 Mental Health Info', // Section heading
                      style: GoogleFonts.chivo(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00171F),
                      ),
                    ),

                    const SizedBox(height: 8.0),

                    Text(
                      'Mental Health Issue(s)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00171F),
                      ),
                    ),

                    Wrap(
                      spacing: 6.0,
                      children:
                          _mentalHealthIssues
                              .map(
                                (issue) => FilterChip(
                                  backgroundColor: Color(0xFFF0F0F5),
                                  label: Text(
                                    issue,
                                    style: TextStyle(
                                      color:
                                          _selectedMentalHealthIssues.contains(
                                                issue,
                                              )
                                              ? Colors
                                                  .white // Color when selected
                                              : Color(
                                                0xFF003459,
                                              ), // Default color
                                    ),
                                  ),

                                  selected: _selectedMentalHealthIssues
                                      .contains(issue),

                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedMentalHealthIssues.add(issue);
                                      } else {
                                        _selectedMentalHealthIssues.remove(
                                          issue,
                                        );
                                      }
                                    });
                                  },

                                  selectedColor: const Color(0xFF758bfd),
                                  // Color of the chip when selected
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                              )
                              .toList(),
                    ),

                    if (_selectedMentalHealthIssues.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 6.0),
                        child: Text(
                          'Please select at least one mental health issue.',
                          style: TextStyle(color: Colors.red, fontSize: 12.0),
                        ),
                      ),

                    const SizedBox(height: 30.0),

                    Text(
                      '🔒 Security Info', // Section heading
                      style: GoogleFonts.chivo(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00171F),
                      ),
                    ),

                    const SizedBox(height: 8.0),

                    SizedBox(
                      height: 50,

                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF007ea7)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0xFF003459),
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
                      height: 50,

                      child: TextFormField(
                        controller: _passwordController,

                        obscureText: _obscurePassword,

                        decoration: InputDecoration(
                          labelText: 'Password',

                          border: const OutlineInputBorder(),

                          prefixIcon: const Icon(Icons.lock),

                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF007ea7)),
                          ),

                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0xFF003459),
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

                    const SizedBox(height: 16.0),

                    Text(
                      '🎨 Choose Avatar', // Section heading

                      style: GoogleFonts.chivo(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00171F),
                      ),
                    ),

                    const SizedBox(height: 8),

                    SizedBox(
                      height: 100,

                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
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
                                  color:
                                      _avatar == avatar
                                          ? const Color(0xFF00a8e8)
                                          : Colors.transparent,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Image.asset('assets/avatars/$avatar'),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24.0),

                    ElevatedButton(
                      onPressed: _signUp,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        backgroundColor: const Color(0xFF00a8e8),
                      ),
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),

                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/login');
                      },
                      child: const Text(
                        "Already have an account? Login",
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF007EA7),
                        ),
                      ),
                    ),
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
