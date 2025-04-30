import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:url_launcher/url_launcher.dart';

class ArticlePage extends StatefulWidget {
  const ArticlePage({super.key});

  @override
  _ArticlePageState createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<dynamic> _combinedItems = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _hasMore = true;
  int _itemsLoaded = 0;
  static const int _loadBatchSize = 10;
  List<String> _userMentalHealthIssues = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_loadMoreData);
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });
    await _fetchUserMentalHealthIssues();
    await _fetchAndCombineItems();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchUserMentalHealthIssues() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await _database.child('users/${user.uid}').get();
      if (snapshot.exists && snapshot.value is Map) {
        final userData = snapshot.value as Map;
        if (userData.containsKey('mentalHealthIssue') &&
            userData['mentalHealthIssue'] is List) {
          setState(() {
            _userMentalHealthIssues =
                (userData['mentalHealthIssue'] as List).cast<String>();
          });
        }
      }
    }
  }

  Future<void> _fetchAndCombineItems() async {
    List<dynamic> fetchedItems = [];

    // Fetch videos
    final videosSnapshot = await _database.child('videos').get();
    if (videosSnapshot.exists && videosSnapshot.value is Map) {
      final videosData = videosSnapshot.value as Map;
      videosData.forEach((category, items) {
        if (items is Map) {
          items.forEach((key, value) {
            if (value is Map) {
              final video = Map<String, dynamic>.from(value);
              video['type'] = 'video';
              video['category'] = category;
              fetchedItems.add(video);
            }
          });
        }
      });
    }

    // Fetch articles
    final articlesSnapshot = await _database.child('articles').get();
    if (articlesSnapshot.exists && articlesSnapshot.value is Map) {
      final articlesData = articlesSnapshot.value as Map;
      articlesData.forEach((category, items) {
        if (items is Map) {
          items.forEach((key, value) {
            if (value is Map) {
              final article = Map<String, dynamic>.from(value);
              article['type'] = 'article';
              article['category'] = category;
              fetchedItems.add(article);
            }
          });
        }
      });
    }

    // Prioritize and combine
    List<dynamic> prioritizedItems = [];
    for (final issue in _userMentalHealthIssues) {
      prioritizedItems.addAll(
        fetchedItems.where((item) => item['category'] == issue).toList(),
      );
    }
    prioritizedItems.addAll(
      fetchedItems.where((item) => item['category'] == 'General').toList(),
    );

    // Add the rest of the items
    prioritizedItems.addAll(
      fetchedItems
          .where(
            (item) =>
                !_userMentalHealthIssues.contains(item['category']) &&
                item['category'] != 'General',
          )
          .toList(),
    );

    prioritizedItems.shuffle(Random());

    setState(() {
      _combinedItems = prioritizedItems;
      _hasMore = _combinedItems.length > _itemsLoaded;
    });
  }

  Future<void> _loadMoreData() async {
    if (_isLoading || !_hasMore) return;
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent * 0.7) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 500)); // Simulate loading

    final nextBatch =
        _combinedItems.skip(_itemsLoaded).take(_loadBatchSize).toList();
    setState(() {
      _combinedItems.addAll(nextBatch);
      _itemsLoaded = _combinedItems.length;
      _hasMore =
          _combinedItems.length <
          _combinedItems
              .length; // Adjust as needed if fetching more from Firebase on each load
      _isLoading = false;
    });
  }

  String _getVideoThumbnailUrl(String videoUrl) {
    final Uri uri = Uri.parse(videoUrl);
    final String? videoId = uri.queryParameters['v'];
    if (videoId != null) {
      return 'https://img.youtube.com/vi/$videoId/0.jpg';
    }
    return '';
  }

  Future<String?> _getArticleThumbnailUrl(String articleUrl) async {
    try {
      final Metadata? metadata = await MetadataFetch.extract(articleUrl);
      return metadata?.image;
    } catch (e) {
      print('Error fetching metadata for $articleUrl: $e');
      return null;
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not launch $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F5),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'For You',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF00171F),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.8,
      ),
      body:
          _isLoading && _combinedItems.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                controller: _scrollController,
                itemCount: _combinedItems.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < _combinedItems.length) {
                    final item = _combinedItems[index];
                    return Card(
                      margin: const EdgeInsets.all(16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      color: Colors.white,
                      child: InkWell(
                        onTap: () => _launchUrl(item['url']),
                        borderRadius: BorderRadius.circular(10.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              // Thumbnail
                              SizedBox(
                                width: double.infinity,
                                height: 180,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  child:
                                      item['type'] == 'video'
                                          ? CachedNetworkImage(
                                            imageUrl: _getVideoThumbnailUrl(
                                              item['url'],
                                            ),
                                            fit: BoxFit.cover,
                                            placeholder:
                                                (context, url) => const Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    const Icon(Icons.error),
                                          )
                                          : FutureBuilder<String?>(
                                            future: _getArticleThumbnailUrl(
                                              item['url'],
                                            ),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState ==
                                                  ConnectionState.done) {
                                                if (snapshot.hasData &&
                                                    snapshot.data != null) {
                                                  return CachedNetworkImage(
                                                    imageUrl: snapshot.data!,
                                                    fit: BoxFit.cover,
                                                    placeholder:
                                                        (
                                                          context,
                                                          url,
                                                        ) => const Center(
                                                          child:
                                                              CircularProgressIndicator(),
                                                        ),
                                                    errorWidget:
                                                        (context, url, error) =>
                                                            const Icon(
                                                              Icons.error,
                                                            ),
                                                  );
                                                } else {
                                                  return const Center(
                                                    child: Icon(
                                                      Icons.image_not_supported,
                                                      size: 48,
                                                      color: Colors.grey,
                                                    ),
                                                  );
                                                }
                                              } else {
                                                return const Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                );
                                              }
                                            },
                                          ),
                                ),
                              ),
                              const SizedBox(height: 12.0),
                              // Title
                              Text(
                                item['title'] ?? 'No Title',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF003459),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8.0),
                              // Description
                              Text(
                                item['description'] ?? 'No Description',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  } else if (_isLoading && _hasMore) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return null;
                },
              ),
    );
  }
}
