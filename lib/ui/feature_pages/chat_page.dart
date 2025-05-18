// chat_page.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../utils/time_utils.dart';
import 'group_chat_screen.dart';

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
  String? _lastKey;
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

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    _database.child('chat_groups').onChildChanged.listen((event) {
      if (event.snapshot.value != null) {
        final updatedGroup =
            (event.snapshot.value as Map<dynamic, dynamic>)
                .cast<String, dynamic>();
        final groupId = event.snapshot.key;
        setState(() {
          final index = _chatGroups.indexWhere(
            (group) => group['groupId'] == groupId,
          );
          if (index != -1) {
            _chatGroups[index] = {'groupId': groupId, ...updatedGroup};
            _sortChatGroups();
          }
        });
      }
    });

    _database.child('chat_groups').onChildAdded.listen((event) {
      if (event.snapshot.value != null) {
        final newGroup =
            (event.snapshot.value as Map<dynamic, dynamic>)
                .cast<String, dynamic>();
        final groupId = event.snapshot.key;
        final groupWithId = {'groupId': groupId, ...newGroup};

        /// 🛠 Modification Start — Prevent duplicate groups in onChildAdded
        setState(() {
          if (!_chatGroups.any((group) => group['groupId'] == groupId)) {
            _chatGroups.add(groupWithId);
            _sortChatGroups();
          }
        });

        /// 🛠 Modification End
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_loadMoreChatGroups);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialChatGroups() async {
    setState(() {
      _isLoading = true;
      _chatGroups.clear();
      _lastKey = null;
      _hasMore = true;
    });
    try {
      Query query = _database
          .child('chat_groups')
          .orderByKey()
          .limitToFirst(_batchSize);
      final snapshot = await query.get();
      if (snapshot.value != null) {
        final groupsData =
            (snapshot.value as Map<dynamic, dynamic>).cast<String, dynamic>();
        groupsData.forEach((key, value) {
          if (!_chatGroups.any((group) => group['groupId'] == key)) {
            _chatGroups.add({'groupId': key, ...value});
          }
          _lastKey = key;
        });
        _sortChatGroups();
      } else {
        _hasMore = false;
      }
    } catch (error) {
      print("Error fetching initial chat groups: $error");
      _hasMore = false;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreChatGroups() async {
    if (_isLoading || !_hasMore || _lastKey == null) return;
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent * 0.7) {
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      Query query = _database
          .child('chat_groups')
          .orderByKey()
          .startAfter(_lastKey)
          .limitToFirst(_batchSize);
      final snapshot = await query.get();
      if (snapshot.value != null) {
        final groupsData =
            (snapshot.value as Map<dynamic, dynamic>).cast<String, dynamic>();
        if (groupsData.isNotEmpty) {
          groupsData.forEach((key, value) {
            if (!_chatGroups.any((group) => group['groupId'] == key)) {
              _chatGroups.add({'groupId': key, ...value});
            }
            _lastKey = key;
          });
          _sortChatGroups();
          _hasMore = groupsData.length == _batchSize;
        } else {
          _hasMore = false;
        }
      } else {
        _hasMore = false;
      }
    } catch (error) {
      print("Error fetching more chat groups: $error");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _joinGroup(BuildContext context, String groupId) async {
    try {
      await _database
          .child('chat_groups/$groupId/members/$_currentUserId')
          .set(true);

      // Add the join time
      await _database
          .child('member_join_times/$groupId/$_currentUserId')
          .set(ServerValue.timestamp); // Use server timestamp for accuracy

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully joined the group!')),
      );

      // Refresh the list to move the group to "Your Groups" section
      _loadInitialChatGroups();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join group: ${e.toString()}')),
      );
    }
  }

  void _sortChatGroups() {
    _chatGroups.sort((a, b) {
      final timestampA = a['lastMessage']?['timestamp'] as int? ?? 0;
      final timestampB = b['lastMessage']?['timestamp'] as int? ?? 0;
      return timestampB.compareTo(timestampA);
    });
  }

  List<Map<String, dynamic>> get _filteredChatGroups {
    if (_searchQuery.isEmpty) {
      return _chatGroups;
    }
    return _chatGroups.where((group) {
      final name = (group['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery);
    }).toList();
  }

  Widget _buildGroupChatListItem(
    BuildContext context,
    Map<String, dynamic> group,
    bool isUserGroup,
  ) {
    final bool isMember =
        group['members'] != null &&
        group['members'].containsKey(_currentUserId);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        onTap:
            isMember
                ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => GroupChatScreen(
                            groupId: group['groupId'],
                            groupName: group['name'],
                          ),
                    ),
                  );
                }
                : null, // Disable tap if not a member
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFFF0F0F5),
              backgroundImage: CachedNetworkImageProvider(
                group['icon'] ??
                    "https://cdn-icons-png.flaticon.com/128/10117/10117308.png",
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
                  if (isUserGroup) // Conditionally show last message for user's groups
                    Text(
                      group['lastMessage']?['text'] ?? "No messages yet",
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isMember)
              Text(
                group['lastMessage']?['timestamp'] != null
                    ? formatTimestamp(
                      DateTime.fromMillisecondsSinceEpoch(
                        group['lastMessage']['timestamp'],
                      ),
                    )
                    : " ",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            if (!isMember)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007ea7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
                onPressed: () => _joinGroup(context, group['groupId']),
                child: const Text(
                  'Join',
                  style: TextStyle(color: Colors.white),
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
          hintText: 'Search for groups...',
          prefixIcon: Icon(Icons.search),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> yourGroups =
        _filteredChatGroups
            .where(
              (group) =>
                  group['members'] != null &&
                  group['members'].containsKey(_currentUserId),
            )
            .toList();
    List<Map<String, dynamic>> otherGroups =
        _filteredChatGroups
            .where(
              (group) =>
                  group['members'] == null ||
                  !group['members'].containsKey(_currentUserId),
            )
            .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F5),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Chats',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF00171F),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.8,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildSearchBar(),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
              child: Text(
                'Your Groups',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ),
            yourGroups.isEmpty && !_isLoading
                ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No groups joined yet.'),
                )
                : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: yourGroups.length,
                  itemBuilder: (context, index) {
                    return _buildGroupChatListItem(
                      context,
                      yourGroups[index],
                      true,
                    );
                  },
                ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
              child: Text(
                'Other Groups',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ),
            _isLoading && _chatGroups.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : otherGroups.isEmpty && !_isLoading && _chatGroups.isNotEmpty
                ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No other groups available.'),
                )
                : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: otherGroups.length,
                  itemBuilder: (context, index) {
                    return _buildGroupChatListItem(
                      context,
                      otherGroups[index],
                      false,
                    );
                  },
                ),
            if (_isLoading && _chatGroups.isNotEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!_hasMore && _chatGroups.isNotEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: Text('No more groups to load.')),
              ),
          ],
        ),
      ),
    );
  }
}
