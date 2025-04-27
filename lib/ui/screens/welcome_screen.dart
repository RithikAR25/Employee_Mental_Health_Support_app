import 'dart:developer' as developer;
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart'; // Import for cached network images
import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<String> _carouselImageUrls = [];

  @override
  void initState() {
    super.initState();
    _loadRandomPosters(5); // Fetch exactly 5 random posters
  }

  Future<void> _loadRandomPosters(int count) async {
    try {
      final snapshot = await _database.child('posters').get();
      if (snapshot.value != null && snapshot.value is List) {
        final List<dynamic> postersData = snapshot.value as List<dynamic>;
        final Random random = Random();
        final List<String> randomUrls = [];
        final int numberOfPosters = postersData.length;
        final int numberOfUrlsToFetch = min(count, numberOfPosters);

        if (numberOfPosters > 0) {
          postersData.shuffle(random);
          randomUrls.addAll(
            postersData.take(numberOfUrlsToFetch).cast<String>(),
          );
        }

        setState(() {
          _carouselImageUrls = randomUrls;
        });
        developer.log("Welcome Screen Poster URLs: $_carouselImageUrls");
      } else {
        developer.log(
          "Error: Unexpected data type for posters data: ${snapshot.value.runtimeType}",
        );
      }
    } catch (error) {
      print("Error fetching welcome screen posters: $error");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: Colors.white),
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: MediaQuery.of(context).padding.top + 50.0,
          bottom: 20.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Column(
              children: [
                Text(
                  'Welcome to OneLife',
                  style: GoogleFonts.roboto(
                    fontSize:
                        MediaQuery.of(context).size.width > 360 ? 30.0 : 24.0,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF00171F),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10.0),
                Text(
                  'Your space for calm, clarity, and care.',
                  style: GoogleFonts.roboto(
                    fontSize:
                        MediaQuery.of(context).size.width > 360 ? 14.0 : 11.0,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF000000),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 0.0),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20.0,
                  horizontal: 30.0,
                ),
                child: CarouselSlider(
                  options: CarouselOptions(
                    autoPlay: true,
                    enlargeCenterPage: true,
                    aspectRatio: 9 / 16,
                    viewportFraction: 1,
                  ),
                  items:
                      _carouselImageUrls.map((url) {
                        return _buildCarouselItem(context, url);
                      }).toList(),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 10.0,
                horizontal: 20.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/signup');
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      backgroundColor: const Color(0xFF00A8E8),
                    ),
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        fontSize: 18.0,
                        color: Color(0xFFffffff),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5.0),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/login');
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF007EA7)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 18.0,
                        color: Color(0xFF00A8E8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12.0),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselItem(BuildContext context, String imageUrl) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.0),
          boxShadow: const [
            BoxShadow(
              color: Colors.grey,
              blurRadius: 2.0,
              offset: Offset(3, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10.0),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            width: MediaQuery.of(context).size.width,
            placeholder:
                (context, url) =>
                    const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
        ),
      ),
    );
  }
}
