import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _chatGroups = [];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  String _currentUserId = "";
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  final int _batchSize = 10;
  int _startAt = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
    }
    _loadInitialChatGroups();
    _scrollController.addListener(_loadMoreChatGroups);

    // 🔵 [MODIFICATION] Listen to search controller changes
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_loadMoreChatGroups);
    _scrollController.dispose();

    // 🔵 [MODIFICATION] Dispose the search controller
    _searchController.dispose();

    super.dispose();
  }

  Future<void> _loadInitialChatGroups() async {
    try {
      final snapshot = await _database.child('chat_groups').get();
      if (snapshot.value != null) {
        Map<dynamic, dynamic> chatGroupsData =
            snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> userGroups = [];
        List<Map<String, dynamic>> otherGroups = [];

        chatGroupsData.forEach((key, value) {
          if (value is Map) {
            Map<String, dynamic> group = value.cast<String, dynamic>();
            group['groupId'] = key;
            if (group['members'] != null &&
                (group['members'] as Map).containsKey(_currentUserId)) {
              userGroups.add(group);
            } else {
              otherGroups.add(group);
            }
          }
        });
        _chatGroups = userGroups + otherGroups;
        _startAt = _chatGroups.length;
        _hasMore = _chatGroups.length >= _batchSize;
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (error) {
      print("Error fetching initial chat groups: $error");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreChatGroups() async {
    if (_isLoading || !_hasMore) return;
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent * 0.7) {
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      final snapshot =
          await _database
              .child('chat_groups')
              .startAt(null, key: _chatGroups.last['groupId'])
              .limitToFirst(_batchSize)
              .get();

      if (snapshot.value != null) {
        Map<dynamic, dynamic> chatGroupsData =
            snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> newGroups = [];
        chatGroupsData.forEach((key, value) {
          if (value is Map) {
            Map<String, dynamic> group = value.cast<String, dynamic>();
            group['groupId'] = key;
            newGroups.add(group);
          }
        });
        if (newGroups.isNotEmpty) {
          newGroups.removeAt(0);
          _chatGroups.addAll(newGroups);
          _startAt = _chatGroups.length;
          _hasMore = newGroups.length == _batchSize;
        } else {
          _hasMore = false;
        }
      } else {
        _hasMore = false;
      }
      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      print("Error fetching more chat groups: $error");
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? userGroup;
    for (var group in _chatGroups) {
      if (group['members'] != null &&
          (group['members'] as Map).containsKey(_currentUserId)) {
        userGroup = group;
        break;
      }
    }
    if (userGroup != null) {
      _chatGroups.remove(userGroup);
      _chatGroups.insert(0, userGroup);
    }

    // 🔵 [MODIFICATION] Filter chat groups according to search query
    List<Map<String, dynamic>> filteredChatGroups =
        _chatGroups.where((group) {
          final name = (group['name'] ?? '').toString().toLowerCase();
          return name.contains(_searchQuery);
        }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F5),
      appBar: AppBar(
        title: const Text(
          'Chats',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00171F),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.8,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            _buildSearchBar(),
            const SizedBox(height: 20),
            Expanded(
              child:
                  _isLoading && _chatGroups.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                        controller: _scrollController,
                        itemCount:
                            filteredChatGroups.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < filteredChatGroups.length) {
                            final group = filteredChatGroups[index];
                            final isUserGroup =
                                group['members'] != null &&
                                (group['members'] as Map).containsKey(
                                  _currentUserId,
                                );
                            return _buildGroupChatListItem(
                              context,
                              group,
                              isUserGroup,
                            );
                          } else if (_isLoading) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return null;
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

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
      child: TextField(
        controller: _searchController,
        // 🔵 [MODIFICATION] Connect search controller
        decoration: const InputDecoration(
          hintText: 'Search for groups...',
          prefixIcon: Icon(Icons.search),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildGroupChatListItem(
    BuildContext context,
    Map<String, dynamic> group,
    bool isUserGroup,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 30,
            backgroundImage: CachedNetworkImageProvider(
              group['icon'] ??
                  "https://github.com/sharmil-shrivastava/mental_health_support_app/blob/main/assets/avatars/avatar1.png?raw=true",
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  group['name'] ?? "Group Name",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        isUserGroup ? FontWeight.bold : FontWeight.normal,
                    color: const Color(0xFF00171F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  group['lastMessage'] ?? "No messages yet",
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            group['lastMessageTime'] ?? " ",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
