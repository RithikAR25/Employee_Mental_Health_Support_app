import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DoctorDetailsPage extends StatelessWidget {
  const DoctorDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Extract the doctor data passed as an argument.
    final Map<String, dynamic>? doctor =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    // If doctor data is null, show an error.
    if (doctor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Doctor data is missing.')),
      );
    }

    // Build the UI using the doctor data.
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F5), // Consistent background color
      appBar: AppBar(
        title: Text(
          'Doctor details',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: const Color(0xFF007EA7),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildDoctorHeader(context, doctor),
              const SizedBox(height: 40),
              _buildDoctorBio(doctor),
              const SizedBox(height: 20),
              _buildContactInfo(context, doctor),
              const SizedBox(height: 20),
              _buildRatingAndReviews(doctor),
            ],
          ),
        ),
      ),
    );
  }

  // Header section with avatar and name
  Widget _buildDoctorHeader(BuildContext context, Map<String, dynamic> doctor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Column(
          children: [
            CircleAvatar(
              radius: MediaQuery.of(context).size.width * 0.2,
              backgroundImage: CachedNetworkImageProvider(
                doctor['profileImage'] ?? 'https://example.com/default.jpg',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              doctor['name'],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF003459),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Bio section
  Widget _buildDoctorBio(Map<String, dynamic> doctor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Biography',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00171F),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          doctor['bio'] ?? 'No bio available.',
          style: const TextStyle(fontSize: 16, color: Color(0xFF00171F)),
          textAlign: TextAlign.start,
        ),
      ],
    );
  }

  // Contact info section
  Widget _buildContactInfo(BuildContext context, Map<String, dynamic> doctor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Contact Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00171F),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Contact: ${doctor['contact'] ?? 'N/A'}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(
                      0xFF000000,
                    ), // Make contact info tappable color
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: GestureDetector(
                onTap: () async {
                  final phoneNumber = doctor['contact'];
                  if (phoneNumber != null) {
                    final cleanedPhone = phoneNumber.replaceAll(
                      RegExp(r'\D'),
                      '',
                    );
                    final whatsappUrl = Uri.parse(
                      "https://wa.me/$cleanedPhone",
                    );
                    if (await canLaunchUrl(whatsappUrl)) {
                      await launchUrl(
                        whatsappUrl,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("WhatsApp is not installed."),
                          ),
                        );
                      }
                    }
                  }
                },
                child: Image.asset(
                  // Use the AssetImage here
                  'assets/logo/whatsapp.png',
                  // Replace with your actual asset path
                  height: 36, // Adjust size as needed
                  width: 36,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Rating and Reviews section
  Widget _buildRatingAndReviews(Map<String, dynamic> doctor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rating and Reviews',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00171F),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 20),
            const SizedBox(width: 5),
            Text(
              '${doctor['rating'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 10),
            Text(
              '(${doctor['reviewCount'] ?? 0} reviews)',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
        // Add more review display here if you have review data
      ],
    );
  }
}
