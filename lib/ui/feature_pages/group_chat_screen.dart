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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DatabaseReference _messagesRef = FirebaseDatabase.instance.ref();
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _messages = [];
  Map<String, String> _userNamesCache = {};
  Set<String> _loadedMessageIds = {};
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
    _loadMessages().then((_) {
      _listenForNewMessages(); // 🔵 MODIFICATION: Start listening after loading messages
    });
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

  Future<void> _loadMessages() async {
    setState(() {
      _messages.clear();
      _loadedMessageIds.clear();
    });

    try {
      final snapshot =
          await _messagesRef
              .child('group_messages/${widget.groupId}')
              .orderByChild('timestamp')
              .get();

      if (snapshot.value != null) {
        Map<dynamic, dynamic> messagesData =
            snapshot.value as Map<dynamic, dynamic>;
        for (final entry in messagesData.entries) {
          final messageId = entry.key;
          final message = entry.value as Map<dynamic, dynamic>;
          final senderId = message['senderId'] as String?;

          if (senderId == null || message['timestamp'] == null) {
            continue; // Skip invalid messages
          }

          String senderName = await _getUserName(senderId);
          _messages.add({
            'messageId': messageId,
            'senderId': senderId,
            'senderName': senderName,
            'text': message['text'],
            'timestamp': message['timestamp'],
          });
          _loadedMessageIds.add(messageId);
        }
        _sortMessages();
        _scrollToBottom();
      }
    } catch (error) {
      print("Error loading messages: $error");
    } finally {
      setState(() {});
    }
  }

  void _listenForNewMessages() {
    _messagesRef
        .child('group_messages/${widget.groupId}')
        .orderByChild('timestamp')
        .startAt(DateTime.now().millisecondsSinceEpoch)
        .onChildAdded
        .listen((event) async {
          if (event.snapshot.value != null &&
              !_loadedMessageIds.contains(event.snapshot.key)) {
            Map<dynamic, dynamic> messageData =
                event.snapshot.value as Map<dynamic, dynamic>;

            final senderId = messageData['senderId'] as String?;
            if (senderId == null || messageData['timestamp'] == null) {
              return; // Skip invalid messages
            }

            String senderName = await _getUserName(senderId);

            setState(() {
              _messages.add({
                'messageId': event.snapshot.key,
                'senderId': senderId,
                'senderName': senderName,
                'text': messageData['text'],
                'timestamp': messageData['timestamp'],
              });
              _sortMessages();
            });

            _loadedMessageIds.add(event.snapshot.key!);
            _scrollToBottom();
          }
        });
  }

  void _sortMessages() {
    _messages.sort(
      (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
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

        // 🟢 Remove locally
        setState(() {
          _messages.removeWhere((msg) => msg['messageId'] == messageId);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can only delete your own messages.'),
          ),
        );
      }
    } catch (error) {
      print('Error deleting message: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        backgroundColor: Color(0xFF007EA7),
        elevation: 0.8,
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final bool isMe = message['senderId'] == _auth.currentUser?.uid;
                return _buildChatMessage(message, isMe);
              },
            ),
          ),
          _buildChatInput(),
        ],
      ),
    );
  }

  Widget _buildChatMessage(Map<String, dynamic> message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.topRight : Alignment.topLeft,
      child: GestureDetector(
        onLongPress: () {
          if (isMe) {
            _showDeleteConfirmationDialog(message['messageId']);
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(8),
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
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              Text(
                message['text'] ?? '',
                style: const TextStyle(color: Colors.black),
              ),
              Text(
                DateFormat('HH:mm').format(
                  DateTime.fromMillisecondsSinceEpoch(message['timestamp']),
                ),
                style: const TextStyle(color: Colors.grey, fontSize: 10),
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
      decoration: BoxDecoration(color: Colors.white),
      child: Row(
        children: <Widget>[
          // // Attachment button
          // IconButton(
          //   icon: Icon(Icons.attach_file, color: Colors.grey[600]),
          //   onPressed: () {
          //     // Handle attachment
          //   },
          // ),

          // // Emoji button
          // IconButton(
          //   icon: Icon(Icons.emoji_emotions_outlined, color: Colors.grey[600]),
          //   onPressed: () {
          //     // Handle emoji picker
          //   },
          // ),

          // Text field
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
                onSubmitted: (text) => _sendMessage(),
              ),
            ),
          ),

          // Send button (always visible)
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: IconButton(
              icon: Icon(Icons.send, color: Color(0xFF007EA7)),
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
