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
  Map<String, String> _userNamesCache = {};
  Set<String> _loadedMessageIds = {}; // To prevent duplicates

  bool _showScrollToBottomButton = false;
  bool _isAtBottom =
      false; // Tracks if the user is currently at the bottom of the chat

  // ADDED: StreamSubscription to manage the real-time listener
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
    // UPDATED: Await _loadInitialMessages() to ensure it completes
    // before starting _listenForNewMessages().
    _loadUserJoinTime().then((_) async {
      await _loadInitialMessages(); // Await this call
      _listenForNewMessages(); // Then start listening for new messages
    });
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    // UPDATED: Cancel the StreamSubscription when the widget is disposed
    _newMessagesSubscription?.cancel();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double currentScroll = _scrollController.position.pixels;
    final double delta = 100.0; // Threshold for considering "at bottom"

    bool atBottom = (maxScroll - currentScroll).abs() <= delta;

    // Only update if the state actually changes to avoid unnecessary rebuilds
    if (_isAtBottom != atBottom) {
      setState(() {
        _isAtBottom = atBottom;
      });
    }

    // Show button when not at bottom and there is scrollable content
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

    // Trigger load more if scrolled to the top and not already loading
    if (_scrollController.position.pixels ==
            _scrollController.position.minScrollExtent &&
        !_isLoadingMore &&
        _messages.isNotEmpty &&
        _oldestTimestamp != null) {
      // UPDATED: Uncommented this line to enable lazy loading
      _loadOlderMessages();
    }
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
        // If join time is not found, assume they joined at a very early time
        // to load all available messages up to the pageSize.
        _userJoinTime = 0;
      }
    }
  }

  Future<String> _getUserName(String userId) async {
    if (_userNamesCache.containsKey(userId)) {
      return _userNamesCache[userId]!;
    }
    final snapshot = await _usersRef.child(userId).child('name').get();

    if (snapshot.value != null) {
      final name = snapshot.value as String;
      _userNamesCache[userId] = name;
      return name;
    }
    return 'Unknown User';
  }

  Future<void> _loadInitialMessages() async {
    if (_userJoinTime == null) {
      setState(() {
        _isLoadingMore = false; // Ensure loading indicator is off
      });
      return;
    }

    // Clear current state to ensure fresh load when re-entering or on initial load
    setState(() {
      _messages.clear();
      _loadedMessageIds.clear();
      _isLoadingMore = true;
    });

    try {
      Query query = _messagesRef
          .child('group_messages/${widget.groupId}')
          .orderByChild('timestamp')
          .startAt(_userJoinTime!) // Only messages from when the user joined
          .limitToLast(_pageSize); // Get the most recent X messages

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

          // Filter out invalid messages or those already processed (though initial clear helps)
          if (senderId == null || timestamp == null) continue;

          String senderName = await _getUserName(senderId);
          fetchedMessages.add({
            'messageId': messageId,
            'senderId': senderId,
            'senderName': senderName,
            'text': message['text'],
            'timestamp': timestamp,
          });
          _loadedMessageIds.add(messageId); // Add to set of loaded IDs
        }

        // Sort fetched messages by timestamp in ascending order (oldest to newest)
        fetchedMessages.sort(
          (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int),
        );

        setState(() {
          _messages.addAll(fetchedMessages); // Add new messages to the end
          if (_messages.isNotEmpty) {
            _oldestTimestamp = _messages.first['timestamp'] as int?;
          }
        });
        for (var msg in fetchedMessages) {
          print(
            "📨 Initial Loaded Message | ${msg['senderName']} | ${msg['timestamp']} | ${msg['text']}",
          );
        }
        //Scroll to the bottom after initial load, ensuring UI is built
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
    // Ensure that _oldestTimestamp is valid before attempting to load older messages
    if (_userJoinTime == null || _oldestTimestamp == null || _isLoadingMore)
      return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Query messages strictly older than the current _oldestTimestamp,
      // and also only from when the user joined.
      Query query = _messagesRef
          .child('group_messages/${widget.groupId}')
          .orderByChild('timestamp')
          .startAt(_userJoinTime!)
          .endBefore(
            _oldestTimestamp!,
          ) // Get messages strictly BEFORE _oldestTimestamp
          .limitToLast(_pageSize); // Fetch up to _pageSize older messages

      final snapshot = await query.get();

      if (snapshot.value != null) {
        Map<dynamic, dynamic> messagesData =
            snapshot.value as Map<dynamic, dynamic>;

        List<Map<String, dynamic>> fetchedMessages = [];
        int newOldestTimestamp = _oldestTimestamp!; // Start with current oldest

        for (final entry in messagesData.entries) {
          final messageId = entry.key;
          final message = entry.value as Map<dynamic, dynamic>;
          final senderId = message['senderId'] as String?;
          final timestamp = message['timestamp'] as int?;

          // Skip if invalid or already loaded
          if (senderId == null ||
              timestamp == null ||
              _loadedMessageIds.contains(messageId)) {
            continue;
          }

          String senderName = await _getUserName(senderId);
          fetchedMessages.add({
            'messageId': messageId,
            'senderId': senderId,
            'senderName': senderName,
            'text': message['text'],
            'timestamp': timestamp,
          });

          _loadedMessageIds.add(messageId); // Add to loaded IDs
          newOldestTimestamp = min(
            newOldestTimestamp,
            timestamp,
          ); // Find the new oldest
        }

        // Sort fetched messages by timestamp in ascending order (oldest to newest)
        fetchedMessages.sort(
          (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int),
        );

        if (fetchedMessages.isEmpty) {
          // No more older messages to load
          setState(() {
            _isLoadingMore = false;
          });
          return;
        }

        setState(() {
          _messages.insertAll(
            0,
            fetchedMessages,
          ); // Insert at the beginning of the list
          _oldestTimestamp = newOldestTimestamp; // Update the oldest timestamp
        });
        for (var msg in fetchedMessages) {
          print(
            "⏪ Older Loaded Message | ${msg['senderName']} | ${msg['timestamp']} | ${msg['text']}",
          );
        }

        // Maintain scroll position relative to the new content
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
    // UPDATED: Cancel any previous subscription to prevent multiple listeners
    _newMessagesSubscription?.cancel();

    final String? currentUserId = _auth.currentUser?.uid;

    if (currentUserId != null && _userJoinTime != null) {
      // Calculate the starting timestamp for the new listener.
      // It must be strictly greater than the latest message timestamp already loaded.
      // If _messages is empty (e.g., initial load found no messages), listen from user's join time.
      final int startTimestamp =
          _messages.isEmpty
              ? _userJoinTime! // Listen from user's join time if no messages loaded
              : (_messages.last['timestamp'] as int) +
                  1; // Listen for messages strictly newer

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

              print(
                "Received onChildAdded: ${event.snapshot.key} at $timestamp",
              );

              // CRITICAL CHECK: Prevent duplicates by ensuring messageId is not already loaded
              // Also ensure timestamp is within user's viewable history (_userJoinTime).
              if (senderId == null ||
                  timestamp == null ||
                  timestamp <
                      _userJoinTime! || // Message is older than user's join time
                  _loadedMessageIds.contains(event.snapshot.key)) {
                print(
                  "🚫 Skipping duplicate or invalid message: ${event.snapshot.key}",
                );
                return; // Skip if invalid, too old, or already loaded
              }

              String senderName = await _getUserName(senderId);
              setState(() {
                _messages.add({
                  // Add to the end of the list (maintaining chronological order)
                  'messageId': event.snapshot.key,
                  'senderId': senderId,
                  'senderName': senderName,
                  'text': messageData['text'],
                  'timestamp': timestamp,
                });
                _loadedMessageIds.add(event.snapshot.key!); // Mark as loaded
                print(
                  "✅ Added new message from listener: ${event.snapshot.key}",
                );

                // Only scroll to bottom if the user is already near the bottom
                // or if it's the current user's message.
                if (_isAtBottom || senderId == currentUserId) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });
                } else {
                  // Show scroll-to-bottom button if not at bottom and new message arrives
                  if (!_showScrollToBottomButton) {
                    setState(() {
                      // Call setState to update UI for the button
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
        _scrollController.position.maxScrollExtent, // Scroll to bottom
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut, // Smoother scrolling
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

        // Update the last message in chat_groups for display in group list
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
        // The _listenForNewMessages will handle adding this message to the list
        // and scrolling to the bottom if appropriate.
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
          _loadedMessageIds.remove(messageId); // Also remove from loaded IDs
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
        await joinTimeRef.remove(); // Remove the join time
        if (context.mounted) {
          Navigator.pop(context); // Go back to the previous screen

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
                Navigator.of(context).pop(); // Close the dialog
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
      body: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  controller: _scrollController,
                  // itemCount: _messages.length + (_isLoadingMore && _messages.isNotEmpty ? 1 : 0),
                  // Adjust itemCount if the loading indicator is shown at the top
                  itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Show loading indicator at the very top when loading older messages
                    if (_isLoadingMore && index == 0) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    // Adjust index if loading indicator is present
                    final messageIndex = _isLoadingMore ? index - 1 : index;
                    if (messageIndex >= 0 && messageIndex < _messages.length) {
                      final message = _messages[messageIndex];
                      final bool isMe =
                          message['senderId'] == _auth.currentUser?.uid;
                      return _buildChatMessage(message, isMe);
                    }
                    return null;
                  },
                ),
                if (_showScrollToBottomButton)
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: FloatingActionButton(
                      mini: true,
                      onPressed: () {
                        _scrollToBottom();
                        // Reset the button state once scrolled to bottom
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
    );
  }

  Widget _buildChatMessage(Map<String, dynamic> message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          if (isMe) {
            _showDeleteConfirmationDialog(message['messageId']);
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(8),
          constraints: BoxConstraints(
            maxWidth:
                MediaQuery.of(context).size.width * 0.75, // Limit bubble width
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
            children: <Widget>[
              if (!isMe && message['senderName'] != null)
                Text(
                  message['senderName']!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  message['text'] ?? '',
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  DateFormat('HH:mm').format(
                    DateTime.fromMillisecondsSinceEpoch(message['timestamp']),
                  ),
                  style: const TextStyle(color: Colors.black54, fontSize: 10),
                ),
              ),
            ],
          ),
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
                // Allow multiline input
                textCapitalization: TextCapitalization.sentences,
                // Capitalize first letter of sentence
                onSubmitted: (text) {
                  // Only send on submit if text is not empty, otherwise avoid new lines
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
