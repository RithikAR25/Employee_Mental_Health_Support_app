import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
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

  final List<String> _mentalHealthIssuesList = [
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
    'avatar6.png',
    'avatar7.png',
    'avatar8.png',
    'avatar9.png',
    'avatar10.png',
  ];

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize form fields with existing user data
    _nameController.text = widget.userData['name'] ?? '';
    _locationController.text = widget.userData['location'] ?? '';
    _selectedAgeRange = widget.userData['ageRange'];
    _selectedProfession = widget.userData['profession'];
    final List<dynamic>? issues = widget.userData['mentalHealthIssue'];
    if (issues != null) {
      _selectedMentalHealthIssues.addAll(issues.cast<String>());
    }
    _avatar = widget.userData['avatar'];
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate() &&
        _selectedAgeRange != null &&
        _selectedProfession != null &&
        _selectedMentalHealthIssues.isNotEmpty &&
        _avatar != null) {
      setState(() {
        _isLoading = true;
      });
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await _database.child('users/${user.uid}').update({
            'name': _nameController.text.trim(),
            'location': _locationController.text.trim(),
            'ageRange': _selectedAgeRange,
            'profession': _selectedProfession,
            'mentalHealthIssue': _selectedMentalHealthIssues.toList(),
            'avatar': _avatar,
          });
          setState(() {
            _isLoading = false;
          });
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile updated successfully!')),
            );
            Navigator.pop(context, {
              // Pass updated data back to ProfilePage
              'name': _nameController.text.trim(),
              'location': _locationController.text.trim(),
              'ageRange': _selectedAgeRange,
              'profession': _selectedProfession,
              'mentalHealthIssue': _selectedMentalHealthIssues.toList(),
              'avatar': _avatar,
            });
          }
        } catch (e) {
          print('Error updating profile: $e');
          setState(() {
            _isLoading = false;
          });
          if (context.mounted) {
            _showErrorDialog('Failed to update profile. Please try again.');
          }
        }
      }
    } else {
      _showErrorDialog('Please fill in all the required fields.');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Profile Error'),
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
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        backgroundColor: const Color(0xFF007EA7),
        iconTheme: const IconThemeData(color: Color(0xFF00171F)),
        elevation: 0.8,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Container(
                decoration: const BoxDecoration(color: Colors.white),
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const Text(
                            "Edit your profile details",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30.0),
                          Text(
                            '👤 Personal Info',
                            style: GoogleFonts.chivo(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF00171F),
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
                                  borderSide: BorderSide(
                                    color: Color(0xFF007ea7),
                                  ),
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
                                  borderSide: BorderSide(
                                    color: Color(0xFF007ea7),
                                  ),
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
                                                  ? Colors.white
                                                  : const Color(0xFF003459),
                                        ),
                                        selectedColor: const Color(0xFF758bfd),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8.0,
                                          ),
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
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12.0,
                                ),
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
                                        selected:
                                            _selectedProfession == profession,
                                        onSelected: (selected) {
                                          setState(() {
                                            _selectedProfession =
                                                selected ? profession : null;
                                          });
                                        },
                                        labelStyle: TextStyle(
                                          color:
                                              _selectedProfession == profession
                                                  ? Colors.white
                                                  : const Color(0xFF003459),
                                        ),
                                        selectedColor: const Color(0xFF758bfd),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8.0,
                                          ),
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
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12.0,
                                ),
                              ),
                            ),
                          const SizedBox(height: 30.0),
                          Text(
                            '🧠 Mental Health Info',
                            style: GoogleFonts.chivo(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF00171F),
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
                                _mentalHealthIssuesList
                                    .map(
                                      (issue) => FilterChip(
                                        backgroundColor: Color(0xFFF0F0F5),
                                        label: Text(
                                          issue,
                                          style: TextStyle(
                                            color:
                                                _selectedMentalHealthIssues
                                                        .contains(issue)
                                                    ? Colors.white
                                                    : const Color(0xFF003459),
                                          ),
                                        ),
                                        selected: _selectedMentalHealthIssues
                                            .contains(issue),
                                        onSelected: (selected) {
                                          setState(() {
                                            if (selected) {
                                              _selectedMentalHealthIssues.add(
                                                issue,
                                              );
                                            } else {
                                              _selectedMentalHealthIssues
                                                  .remove(issue);
                                            }
                                          });
                                        },
                                        selectedColor: const Color(0xFF758bfd),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8.0,
                                          ),
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
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12.0,
                                ),
                              ),
                            ),
                          const SizedBox(height: 30.0),
                          Text(
                            '🎨 Choose Avatar',
                            style: GoogleFonts.chivo(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF00171F),
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
                                    child: Image.asset(
                                      'assets/avatars/$avatar',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24.0),
                          ElevatedButton(
                            onPressed: _updateProfile,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 10.0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              backgroundColor: const Color(0xFF00a8e8),
                            ),
                            child:
                                _isLoading
                                    ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : const Text(
                                      'Save Changes',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                      ),
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
