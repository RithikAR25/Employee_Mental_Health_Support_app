import 'dart:developer' as developer;

import 'package:cached_network_image/cached_network_image.dart'; // Import for cached images
import 'package:firebase_auth/firebase_auth.dart'; // Import for Firebase Auth
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Firebase Realtime Database reference
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Lists to hold data fetched from Firebase
  List<Map<String, dynamic>> _doctors = [];
  List<String> _imageCarouselUrls = [
    "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?q=80&w=3200&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
    //beach
    "https://images.unsplash.com/photo-1542291026-7eec264c27ff?q=80&w=3174&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
    //forest
    "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?q=80&w=3270&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
    //mountains
    "https://images.unsplash.com/photo-1519681393784-d120267933ba?q=80&w=3270&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
    //sunrise
  ];
  String _userName =
      "User"; // Default user name  -  Will be fetched from Firebase
  String _userAvatar =
      "avatar1.png"; // Default avatar - Will be fetched from Firebase

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDoctors();
  }

  // Load user data (name and avatar) from Firebase
  Future<void> _loadUserData() async {
    // Get the current user's UID.  You'll need to be signed in.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Fetch user data from the 'users' node using the UID
        final snapshot = await _database.child('users/${user.uid}').get();
        if (snapshot.value != null) {
          //check the type of snapshot.value
          if (snapshot.value is Map) {
            final Map<String, dynamic> userData = Map<String, dynamic>.from(
              snapshot.value as Map,
            );
            developer.log("User Data: $userData");
            setState(() {
              _userName =
                  userData['name'] ??
                  "User"; // Use 'User' if name is not available
              _userAvatar =
                  userData['avatar'] ??
                  "avatar1.png"; // Use default if avatar is missing
            });
          } else {
            developer.log(
              "Error: Unexpected data type for user data: ${snapshot.value.runtimeType}",
            );
          }
        }
      } catch (error) {
        print("Error fetching user data: $error"); //important
        // Handle error (e.g., show a message to the user)
      }
    }
  }

  // Load doctor data from Firebase
  Future<void> _loadDoctors() async {
    try {
      final snapshot = await _database.child('doctors').get();
      if (snapshot.value != null) {
        if (snapshot.value is Map) {
          final Map<String, dynamic> doctorsData = Map<String, dynamic>.from(
            snapshot.value as Map,
          );
          developer.log("Doctors Data: $doctorsData");
          final List<Map<String, dynamic>> tempDoctors = [];
          doctorsData.forEach((key, value) {
            if (value is Map) {
              final Map<String, dynamic> doctor = Map<String, dynamic>.from(
                value,
              );
              tempDoctors.add(doctor);
            } else {
              developer.log(
                "Warning: Unexpected data type for doctor: ${value.runtimeType}",
              );
            }
          });
          if (tempDoctors.length > 3) {
            _doctors = tempDoctors.sublist(0, 3);
          } else {
            _doctors = tempDoctors;
          }
          setState(() {});
        } else {
          developer.log(
            "Error: Unexpected data type for doctors data: ${snapshot.value.runtimeType}",
          );
        }
      }
    } catch (error) {
      print("Error fetching doctors: $error");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildAppBar(context),
                const SizedBox(height: 20),
                _buildSearchBar(),
                const SizedBox(height: 20),
                _buildCategoryIcons(context),
                const SizedBox(height: 20),
                _buildImageCarousel(),
                const SizedBox(height: 20),
                _buildTopDoctorsSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // App bar with greeting and avatar
  Widget _buildAppBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          'Hello, $_userName!',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00171F),
          ),
        ),
        // User Avatar (using CachedNetworkImage for network images)
        CircleAvatar(
          radius: 25,
          backgroundImage: AssetImage('assets/avatars/$_userAvatar'),
        ),
      ],
    );
  }

  // Search bar
  Widget _buildSearchBar() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: 'Search for articles, doctors...',
          prefixIcon: Icon(Icons.search),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  // Category icons
  Widget _buildCategoryIcons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _buildCategoryIcon(
            context,
            Icons.business_center,
            'Corporate Wellness',
          ),
        ),
        Expanded(
          child: _buildCategoryIcon(
            context,
            Icons.school,
            'Colleges & Universities',
          ),
        ),
        Expanded(
          child: _buildCategoryIcon(context, Icons.local_hospital, 'Hospitals'),
        ),
        Expanded(
          child: _buildCategoryIcon(context, Icons.book, 'EdTech & Coaching'),
        ),
      ],
    );
  }

  // Helper for category icon
  Widget _buildCategoryIcon(BuildContext context, IconData icon, String label) {
    return Column(
      children: <Widget>[
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: const Color(0xFF00a8e8),
          ),
          child: Icon(icon, size: 30, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF00171F)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Image carousel
  Widget _buildImageCarousel() {
    return SizedBox(
      height: 200,
      child: PageView.builder(
        itemCount: _imageCarouselUrls.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              image: DecorationImage(
                image: CachedNetworkImageProvider(_imageCarouselUrls[index]),
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }

  // Top doctors section
  Widget _buildTopDoctorsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const Text(
              'Top Doctors',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00171F),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/allDoctors');
              },
              child: const Text(
                'See All',
                style: TextStyle(color: Color(0xFF007EA7)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        //build list of doctors
        Column(
          children:
              _doctors
                  .map((doctor) => _buildDoctorCard(context, doctor))
                  .toList(),
        ),
      ],
    );
  }

  // Helper for doctor card
  Widget _buildDoctorCard(BuildContext context, Map<String, dynamic> doctor) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        // Align items to the start
        children: <Widget>[
          CircleAvatar(
            radius: 36, // Increased radius for larger image
            backgroundImage: CachedNetworkImageProvider(
              "https://imgs.search.brave.com/UKeCinJ7mFuiThmbPG5KyfouPYFz00NjIBKbeIk7q78/rs:fit:500:0:0:0/g:ce/aHR0cHM6Ly9pbWcu/ZnJlZXBpay5jb20v/ZnJlZS1waG90by9k/b2N0b3Itd2Vhcmlu/Zy13aGl0ZS1jb2F0/LW1lZGl1bS1zaG90/XzIzLTIxNDk4NDQ1/NzkuanBnP3NlbXQ9/YWlzX2h5YnJpZCZ3/PTc0MA",
            ),
          ),
          const SizedBox(width: 16), // Increased horizontal spacing
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  doctor['name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003459),
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      doctor['specialization'],
                      style: const TextStyle(
                        fontSize: 12, // Increased font size
                        color: Colors.grey,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(width: 10),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        Text(
                          '${doctor['rating'] ?? "N/A"}',
                          // Display rating or "N/A"
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF00171F),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${doctor['rating'] ?? 0} reviews)',
                          // Display review count or 0
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Contact: ${doctor['contact'] ?? "N/A"}', // Display contact
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF00171F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
