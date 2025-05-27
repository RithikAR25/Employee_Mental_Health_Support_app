import 'dart:async'; // Import for StreamSubscription
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  _GroupChatScreenState createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  static const int _pageSize = 20;
  int? _oldestTimestamp; // Oldest timestamp of messages currently loaded
  bool _isLoadingMore = false;
  int? _userJoinTime; // Timestamp when the current user joined the group

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DatabaseReference _messagesRef = FirebaseDatabase.instance.ref();
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _messages = []; // Always sorted oldest to newest
  // UPDATED: Cache now stores Map for name and avatar (filename)
  Map<String, Map<String, String>> _userProfileCache = {};
  Set<String> _loadedMessageIds = {}; // To prevent duplicates

  bool _showScrollToBottomButton = false;
  bool _isAtBottom =
      false; // Tracks if the user is currently at the bottom of the chat

  String? _currentFloatingDate;
  Timer? _floatingDateVisibilityTimer;
  bool _isScrolling = false;

  StreamSubscription<DatabaseEvent>? _newMessagesSubscription;

  final List<Color> _userColors = [
    Colors.blue.shade100,
    Colors.green.shade100,
    Colors.purple.shade100,
    Colors.orange.shade100,
    Colors.teal.shade100,
    Colors.red.shade100,
    Colors.pink.shade100,
    Colors.brown.shade100,
  ];

  Color _getUserColor(String senderId) {
    int hash = senderId.hashCode;
    return _userColors[hash % _userColors.length];
  }

  @override
  void initState() {
    super.initState();
    _loadUserJoinTime().then((_) async {
      await _loadInitialMessages();
      _listenForNewMessages();
    });
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _newMessagesSubscription?.cancel();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _messageController.dispose();
    _floatingDateVisibilityTimer?.cancel();
    super.dispose();
  }

  void _scrollListener() {
    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double currentScroll = _scrollController.position.pixels;
    final double delta = 100.0; // Threshold for considering "at bottom"

    bool atBottom = (maxScroll - currentScroll).abs() <= delta;

    if (_isAtBottom != atBottom) {
      setState(() {
        _isAtBottom = atBottom;
      });
    }

    if (!atBottom &&
        !_showScrollToBottomButton &&
        _scrollController.hasClients &&
        maxScroll > 0) {
      setState(() {
        _showScrollToBottomButton = true;
      });
    } else if (atBottom && _showScrollToBottomButton) {
      setState(() {
        _showScrollToBottomButton = false;
      });
    }

    if (_scrollController.position.pixels ==
            _scrollController.position.minScrollExtent &&
        !_isLoadingMore &&
        _messages.isNotEmpty &&
        _oldestTimestamp != null) {
      _loadOlderMessages();
    }

    // --- Floating Date Indicator Logic ---
    if (_scrollController.hasClients && _messages.isNotEmpty) {
      int firstVisibleItemIndex = 0;
      if (_scrollController.position.pixels >
          _scrollController.position.minScrollExtent) {
        firstVisibleItemIndex =
            (_scrollController.position.pixels / 60).floor();
        if (_isLoadingMore) {
          firstVisibleItemIndex = max(0, firstVisibleItemIndex - 1);
        }
      }

      if (firstVisibleItemIndex < _messages.length &&
          firstVisibleItemIndex >= 0) {
        final message = _messages[firstVisibleItemIndex];
        final timestamp = message['timestamp'] as int;
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final formattedDate = _formatDateForFloatingIndicator(date);

        if (_currentFloatingDate != formattedDate) {
          setState(() {
            _currentFloatingDate = formattedDate;
          });
        }
      } else {
        if (_currentFloatingDate != null) {
          setState(() {
            _currentFloatingDate = null;
          });
        }
      }

      _floatingDateVisibilityTimer?.cancel();
      _isScrolling = true;
      _floatingDateVisibilityTimer = Timer(
        const Duration(milliseconds: 700),
        () {
          if (mounted) {
            setState(() {
              _isScrolling = false;
            });
          }
        },
      );
    } else {
      if (_currentFloatingDate != null || _isScrolling) {
        setState(() {
          _currentFloatingDate = null;
          _isScrolling = false;
        });
      }
    }
  }

  String _formatDateForFloatingIndicator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return 'Today';
    } else if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    } else if (date.year == now.year) {
      return DateFormat('MMMM d').format(date);
    } else {
      return DateFormat('MMMM d,EEEE').format(date);
    }
  }

  // UPDATED: Now fetches both name and avatar (filename)
  Future<Map<String, String>> _getUserProfile(String userId) async {
    if (_userProfileCache.containsKey(userId)) {
      return _userProfileCache[userId]!;
    }
    final snapshot = await _usersRef.child(userId).get();

    String name = 'Unknown User';
    String avatar = ''; // Default empty

    if (snapshot.value != null) {
      final userData = snapshot.value as Map<dynamic, dynamic>;
      name = (userData['name'] as String?) ?? 'Unknown User';
      avatar = (userData['avatar'] as String?) ?? '';
    }

    _userProfileCache[userId] = {'name': name, 'avatar': avatar};
    return _userProfileCache[userId]!;
  }

  Future<void> _loadUserJoinTime() async {
    final String? currentUserId = _auth.currentUser?.uid;

    if (currentUserId != null) {
      final snapshot =
          await _messagesRef
              .child('member_join_times/${widget.groupId}/$currentUserId')
              .get();

      if (snapshot.value != null) {
        _userJoinTime = (snapshot.value as int);
      } else {
        print(
          "Warning: Join time not found for user $currentUserId in group ${widget.groupId}. Setting to 0.",
        );
        _userJoinTime = 0;
      }
    }
  }

  Future<void> _loadInitialMessages() async {
    if (_userJoinTime == null) {
      setState(() {
        _isLoadingMore = false; // Ensure loading indicator is off
      });
      return;
    }

    setState(() {
      _messages.clear();
      _loadedMessageIds.clear();
      _isLoadingMore = true;
    });

    try {
      Query query = _messagesRef
          .child('group_messages/${widget.groupId}')
          .orderByChild('timestamp')
          .startAt(_userJoinTime!)
          .limitToLast(_pageSize);

      final snapshot = await query.get();
      if (snapshot.value != null) {
        Map<dynamic, dynamic> messagesData =
            snapshot.value as Map<dynamic, dynamic>;

        List<Map<String, dynamic>> fetchedMessages = [];

        for (final entry in messagesData.entries) {
          final messageId = entry.key;
          final message = entry.value as Map<dynamic, dynamic>;
          final senderId = message['senderId'] as String?;
          final timestamp = message['timestamp'] as int?;

          if (senderId == null || timestamp == null) continue;

          final userProfile = await _getUserProfile(senderId);
          fetchedMessages.add({
            'messageId': messageId,
            'senderId': senderId,
            'senderName': userProfile['name'],
            'avatar': userProfile['avatar'], // UPDATED: Use 'avatar'
            'text': message['text'],
            'timestamp': timestamp,
          });
          _loadedMessageIds.add(messageId);
        }

        fetchedMessages.sort(
          (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int),
        );

        setState(() {
          _messages.addAll(fetchedMessages);
          if (_messages.isNotEmpty) {
            _oldestTimestamp = _messages.first['timestamp'] as int?;
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    } catch (error) {
      print("Error loading initial messages: $error");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load initial messages: $error')),
        );
      }
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_userJoinTime == null || _oldestTimestamp == null || _isLoadingMore)
      return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      Query query = _messagesRef
          .child('group_messages/${widget.groupId}')
          .orderByChild('timestamp')
          .startAt(_userJoinTime!)
          .endBefore(_oldestTimestamp!)
          .limitToLast(_pageSize);

      final snapshot = await query.get();

      if (snapshot.value != null) {
        Map<dynamic, dynamic> messagesData =
            snapshot.value as Map<dynamic, dynamic>;

        List<Map<String, dynamic>> fetchedMessages = [];
        int newOldestTimestamp = _oldestTimestamp!;

        for (final entry in messagesData.entries) {
          final messageId = entry.key;
          final message = entry.value as Map<dynamic, dynamic>;
          final senderId = message['senderId'] as String?;
          final timestamp = message['timestamp'] as int?;

          if (senderId == null ||
              timestamp == null ||
              _loadedMessageIds.contains(messageId)) {
            continue;
          }

          final userProfile = await _getUserProfile(senderId);
          fetchedMessages.add({
            'messageId': messageId,
            'senderId': senderId,
            'senderName': userProfile['name'],
            'avatar': userProfile['avatar'], // UPDATED: Use 'avatar'
            'text': message['text'],
            'timestamp': timestamp,
          });

          _loadedMessageIds.add(messageId);
          newOldestTimestamp = min(newOldestTimestamp, timestamp);
        }

        fetchedMessages.sort(
          (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int),
        );

        if (fetchedMessages.isEmpty) {
          setState(() {
            _isLoadingMore = false;
          });
          return;
        }

        setState(() {
          _messages.insertAll(0, fetchedMessages);
          _oldestTimestamp = newOldestTimestamp;
        });
        final double currentPosition = _scrollController.position.pixels;
        final double beforeLoadHeight =
            _scrollController.position.maxScrollExtent;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final double afterLoadHeight =
              _scrollController.position.maxScrollExtent;
          _scrollController.jumpTo(
            currentPosition + (afterLoadHeight - beforeLoadHeight),
          );
        });
      }
    } catch (error) {
      print("Error loading older messages: $error");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load older messages: $error')),
        );
      }
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _listenForNewMessages() {
    _newMessagesSubscription?.cancel();

    final String? currentUserId = _auth.currentUser?.uid;

    if (currentUserId != null && _userJoinTime != null) {
      final int startTimestamp =
          _messages.isEmpty
              ? _userJoinTime!
              : (_messages.last['timestamp'] as int) + 1;

      print("👂 Listening for new messages from timestamp: $startTimestamp");

      _newMessagesSubscription = _messagesRef
          .child('group_messages/${widget.groupId}')
          .orderByChild('timestamp')
          .startAt(startTimestamp)
          .onChildAdded
          .listen((event) async {
            if (event.snapshot.value != null) {
              Map<dynamic, dynamic> messageData =
                  event.snapshot.value as Map<dynamic, dynamic>;
              final senderId = messageData['senderId'] as String?;
              final timestamp = messageData['timestamp'] as int?;

              if (senderId == null ||
                  timestamp == null ||
                  timestamp < _userJoinTime! ||
                  _loadedMessageIds.contains(event.snapshot.key)) {
                print(
                  "🚫 Skipping duplicate or invalid message: ${event.snapshot.key}",
                );
                return;
              }

              final userProfile = await _getUserProfile(senderId);
              setState(() {
                _messages.add({
                  'messageId': event.snapshot.key,
                  'senderId': senderId,
                  'senderName': userProfile['name'],
                  'avatar': userProfile['avatar'], // UPDATED: Use 'avatar'
                  'text': messageData['text'],
                  'timestamp': timestamp,
                });
                _loadedMessageIds.add(event.snapshot.key!);

                if (_isAtBottom || senderId == currentUserId) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });
                } else {
                  if (!_showScrollToBottomButton) {
                    setState(() {
                      _showScrollToBottomButton = true;
                    });
                  }
                }
              });
            }
          });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() async {
    String text = _messageController.text.trim();

    if (text.isNotEmpty) {
      final String? senderId = _auth.currentUser?.uid;

      if (senderId != null) {
        final DatabaseReference newMessageRef =
            _messagesRef.child('group_messages/${widget.groupId}').push();

        final timestamp = ServerValue.timestamp;
        await newMessageRef.set({
          'senderId': senderId,
          'text': text,
          'timestamp': timestamp,
        });

        final DatabaseReference groupRef = _messagesRef.child(
          'chat_groups/${widget.groupId}',
        );

        await groupRef.update({
          'lastMessage': {
            'text': text,
            'senderId': senderId,
            'timestamp': timestamp,
          },
        });

        _messageController.clear();
      }
    }
  }

  void _deleteMessage(String messageId) async {
    final String? currentUserId = _auth.currentUser?.uid;

    final DatabaseReference messageRef = _messagesRef.child(
      'group_messages/${widget.groupId}/$messageId',
    );

    try {
      final snapshot = await messageRef.get();

      if (snapshot.value != null &&
          (snapshot.value as Map)['senderId'] == currentUserId) {
        await messageRef.remove();
        setState(() {
          _messages.removeWhere((msg) => msg['messageId'] == messageId);
          _loadedMessageIds.remove(messageId);
        });
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Message deleted.')));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can only delete your own messages.'),
          ),
        );
      }
    } catch (error) {
      print('Error deleting message: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete message: $error')),
        );
      }
    }
  }

  Future<void> _exitGroup() async {
    final String? currentUserId = _auth.currentUser?.uid;

    if (currentUserId != null) {
      final DatabaseReference groupMembersRef = _messagesRef.child(
        'chat_groups/${widget.groupId}/members/$currentUserId',
      );

      final DatabaseReference joinTimeRef = _messagesRef.child(
        'member_join_times/${widget.groupId}/$currentUserId',
      );

      try {
        await groupMembersRef.remove();
        await joinTimeRef.remove();
        if (context.mounted) {
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You have exited the group.')),
          );
        }
      } catch (error) {
        print('Error exiting group: $error');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to exit the group. Please try again.'),
            ),
          );
        }
      }
    }
  }

  void _showExitConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Exit Group?"),
          content: const Text("Are you sure you want to leave this group?"),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text("Exit"),
              onPressed: () {
                _exitGroup();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.groupName,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFFffffff),
          ),
        ),
        backgroundColor: const Color(0xFF007EA7),
        elevation: 0.8,
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'exit') {
                _showExitConfirmationDialog();
              }
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            color: Colors.white,
            itemBuilder:
                (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'exit',
                    child: Text('Exit Group'),
                  ),
                ],
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Stack(
                children: <Widget>[
                  ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isLoadingMore && index == 0) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final messageIndex = _isLoadingMore ? index - 1 : index;
                      if (messageIndex >= 0 &&
                          messageIndex < _messages.length) {
                        final message = _messages[messageIndex];
                        final bool isMe =
                            message['senderId'] == _auth.currentUser?.uid;
                        // Pass avatar filename to _buildChatMessage
                        return _buildChatMessage(
                          message,
                          isMe,
                          message['avatar'] as String?,
                        );
                      }
                      return null;
                    },
                  ),
                  if (_isScrolling && _currentFloatingDate != null)
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _currentFloatingDate!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),

                  if (_showScrollToBottomButton)
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: FloatingActionButton(
                        mini: true,
                        onPressed: () {
                          _scrollToBottom();
                          setState(() => _showScrollToBottomButton = false);
                        },
                        backgroundColor: const Color(0xFF007EA7),
                        child: const Icon(
                          Icons.arrow_downward,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _buildChatInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatMessage(
    Map<String, dynamic> message,
    bool isMe,
    String? avatarFilename,
  ) {
    final bool showAvatar = !isMe;
    Widget avatarWidget = const SizedBox(width: 36, height: 36);

    if (showAvatar) {
      ImageProvider? avatarImage;
      if (avatarFilename != null && avatarFilename.isNotEmpty) {
        avatarImage = AssetImage('assets/avatars/$avatarFilename');
      }

      avatarWidget = Padding(
        padding: const EdgeInsets.only(right: 8.0, bottom: 4.0),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.grey[300],
          backgroundImage: avatarImage,
          child:
              avatarImage == null
                  ? Icon(Icons.person, color: Colors.grey[600], size: 24)
                  : null,
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: <Widget>[
            if (showAvatar) avatarWidget,
            GestureDetector(
              onLongPress: () {
                if (isMe) {
                  _showDeleteConfirmationDialog(message['messageId']);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color:
                      isMe
                          ? Colors.blue.shade300
                          : _getUserColor(message['senderId']),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isMe && message['senderName'] != null)
                      Text(
                        message['senderName']!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            message['text'] ?? '',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('hh:mm a').format(
                            DateTime.fromMillisecondsSinceEpoch(
                              message['timestamp'],
                            ),
                          ),
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey, width: 0.2)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Type a message',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10.0),
                ),
                maxLines: 5,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (text) {
                  if (text.isNotEmpty) {
                    _sendMessage();
                  }
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF007EA7)),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(String messageId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Message?"),
          content: const Text(
            "Are you sure you want to delete this message for everyone?",
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text("Delete"),
              onPressed: () {
                _deleteMessage(messageId);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
