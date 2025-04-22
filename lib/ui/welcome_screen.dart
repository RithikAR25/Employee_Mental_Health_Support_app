import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:google_fonts/google_fonts.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bgimage/peak_background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: MediaQuery.of(context).padding.top + 16.0, // ✅ Manual top safe space
          bottom: 20.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Welcome to Employee Mental Health Support',
              style: GoogleFonts.chivo(
                fontSize: MediaQuery.of(context).size.width > 360 ? 36.0 : 24.0,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF000000),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20.0),

            Expanded( // ✅ Carousel fills available space without fixed height
              child: CarouselSlider(
                options: CarouselOptions(
                  autoPlay: true,
                  enlargeCenterPage: true,
                  aspectRatio: 9 / 16,
                  viewportFraction: 1,
                ),
                items: [
                  _buildCarouselItem(context, 'assets/posters/poster1.jpg'),
                  _buildCarouselItem(context, 'assets/posters/poster2.jpg'),
                  _buildCarouselItem(context, 'assets/posters/poster3.jpg'),
                  _buildCarouselItem(context, 'assets/posters/poster4.jpg'),
                  _buildCarouselItem(context, 'assets/posters/poster5.jpg'),
                ],
              ),
            ),

            const SizedBox(height: 20.0),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/signup');
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                backgroundColor: const Color(0xFF758bfd),
              ),
              child: const Text(
                'Sign Up',
                style: TextStyle(fontSize: 18.0, color: Color(0xFF000000)),
              ),
            ),
            const SizedBox(height: 12.0),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/login');
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFff8600)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15.0),
              ),
              child: const Text(
                'Login',
                style: TextStyle(fontSize: 18.0, color: Color(0xFFff8600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselItem(BuildContext context, String imagePath) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.0),
          boxShadow: const [
            BoxShadow(
              color: Colors.grey,
              blurRadius: 8.0,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10.0),
          child: Image.asset(
            imagePath,
            fit: BoxFit.cover,
            width: MediaQuery.of(context).size.width,
          ),
        ),
      ),
    );
  }
}
