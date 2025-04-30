import 'dart:developer' as developer;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AllDoctorsPage extends StatefulWidget {
  const AllDoctorsPage({super.key});

  @override
  _AllDoctorsPageState createState() => _AllDoctorsPageState();
}

class _AllDoctorsPageState extends State<AllDoctorsPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  int _limit = 10;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _filteredDoctors = [];

  DataSnapshot? _lastVisibleSnapshot;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadInitialDoctors();
    _scrollController.addListener(_scrollListener);
    _searchController.addListener(_applySearchAndSort);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _searchController.removeListener(_applySearchAndSort);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialDoctors() async {
    setState(() {
      _isLoadingMore = true;
      _doctors.clear();
      _filteredDoctors.clear();
      _lastVisibleSnapshot = null;
      _hasMore = true;
    });

    try {
      final snapshot =
          await _database
              .child('doctors')
              .orderByKey()
              .limitToFirst(_limit)
              .get();
      developer.log("Initial doctors snapshot: ${snapshot.value}");

      if (snapshot.value != null) {
        final doctorsMap = Map<String, dynamic>.from(snapshot.value as Map);
        final List<Map<String, dynamic>> tempDoctors = [];

        doctorsMap.forEach((key, value) {
          if (value is Map) {
            tempDoctors.add(Map<String, dynamic>.from(value));
          }
        });

        _doctors = tempDoctors;
        _lastVisibleSnapshot = snapshot;
        _hasMore = tempDoctors.length >= _limit;

        _applySearchAndSort();
      } else {
        _hasMore = false;
      }
    } catch (e) {
      developer.log("Error loading initial doctors: $e");
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    try {
      final lastKey = _doctors.isNotEmpty ? _doctors.last['id'] : null;
      final snapshot =
          await _database
              .child('doctors')
              .orderByKey()
              .startAfter(lastKey)
              .limitToFirst(_limit)
              .get();

      if (snapshot.value != null) {
        final doctorsMap = Map<String, dynamic>.from(snapshot.value as Map);
        final List<Map<String, dynamic>> newDoctors = [];

        doctorsMap.forEach((key, value) {
          if (value is Map) {
            newDoctors.add(Map<String, dynamic>.from(value));
          }
        });

        _doctors.addAll(newDoctors);
        _hasMore = newDoctors.length >= _limit;

        _applySearchAndSort();
      } else {
        _hasMore = false;
      }
    } catch (e) {
      developer.log("Error loading more doctors: $e");
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  void _applySearchAndSort() {
    final query = _searchController.text.toLowerCase();
    List<Map<String, dynamic>> results =
        _doctors.where((doctor) {
          final name = (doctor['name'] ?? '').toLowerCase();
          final specialization = (doctor['specialization'] ?? '').toLowerCase();
          return name.contains(query) || specialization.contains(query);
        }).toList();

    results.sort((a, b) {
      final aRating = (a['rating'] ?? 0).toDouble();
      final bRating = (b['rating'] ?? 0).toDouble();
      return bRating.compareTo(aRating);
    });

    setState(() => _filteredDoctors = results);
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await _loadInitialDoctors();
    setState(() => _isRefreshing = false);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
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
            color: Colors.grey.shade200,
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: 'Search for articles, doctors...',
          prefixIcon: Icon(Icons.search),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'All Doctors',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: const Color(0xFF007EA7),
      ),
      backgroundColor: const Color(0xFFF0F0F5),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 0.0, 8.0, 8.0),
              child: _buildSearchBar(),
            ),
            //
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                child:
                    _filteredDoctors.isEmpty && !_isLoadingMore
                        ? const Center(child: Text('No doctors available.'))
                        : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          controller: _scrollController,
                          itemCount:
                              _filteredDoctors.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index < _filteredDoctors.length) {
                              return _buildDoctorCard(
                                context,
                                _filteredDoctors[index],
                              );
                            } else {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                          },
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorCard(BuildContext context, Map<String, dynamic> doctor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundImage: CachedNetworkImageProvider(doctor['profileImage']),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17.5,
                    color: Color(0xFF003459),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      doctor['specialization'],
                      style: const TextStyle(
                        fontSize: 13.2,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 15),
                        Text(
                          '${doctor['rating'] ?? 'N/A'}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final phone = doctor['contact'];
                    final cleaned = phone?.replaceAll(RegExp(r'\D'), '');
                    final url = Uri.parse("https://wa.me/$cleaned");
                    if (await canLaunchUrl(url)) {
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("WhatsApp not available"),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    'Contact: ${doctor['contact'] ?? 'N/A'}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF00171F),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ADDED ARROW ICON AND NAVIGATION
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Color(0xFF007EA7)),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/doctorDetails', // Define this route
                arguments: doctor, // Pass the doctor data
              );
            },
          ),
        ],
      ),
    );
  }
}
