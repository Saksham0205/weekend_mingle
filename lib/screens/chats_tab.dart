import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/user_model.dart';
import 'home_screen.dart';

class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Widget _buildChatList() {
    final userProvider = Provider.of<UserProvider>(context);
    if (userProvider.user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .where('participants', arrayContains: userProvider.user!.uid)
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No chats yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start connecting with others to begin chatting!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to the Connections tab in the HomeScreen
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                    // Access the parent HomeScreen state to switch tabs
                    // This is safer than using DefaultTabController which might not be available
                    final scaffoldContext = ScaffoldMessenger.of(context).context;
                    if (scaffoldContext != null) {
                      // Set the index to 1 (Connections tab)
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const HomeScreen(initialTabIndex: 1)),
                      );
                    }
                  },
                  child: const Text('Find Connections'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final chat = snapshot.data!.docs[index];
            final chatData = chat.data() as Map<String, dynamic>;
            final participants = List<String>.from(chatData['participants'] ?? []);

            if (participants.isEmpty || participants.length < 2) {
              return const SizedBox();
            }

            final otherUserId = participants.firstWhere(
                  (id) => id != userProvider.user!.uid,
              orElse: () => '',
            );

            if (otherUserId.isEmpty) {
              return const SizedBox();
            }

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(otherUserId).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const SizedBox();
                }

                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                if (userData == null) return const SizedBox();

                final lastMessage = chatData['lastMessage'] as String? ?? 'No messages yet';
                final lastMessageTime = chatData['lastMessageTime'] as Timestamp?;
                final unreadCount = chatData['unreadCount${userProvider.user!.uid}'] as int? ?? 0;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: userData['photoUrl'] != null
                        ? CachedNetworkImageProvider(userData['photoUrl'])
                        : null,
                    child: userData['photoUrl'] == null
                        ? Text(
                      (userData['name'] as String? ?? 'A')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 20),
                    )
                        : null,
                  ),
                  title: Text(userData['name'] ?? 'Anonymous'),
                  subtitle: Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (lastMessageTime != null)
                        Text(
                          timeago.format(lastMessageTime.toDate()),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          chatId: chat.id,
                          otherUserId: otherUserId,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Implement search functionality
              showSearch(
                context: context,
                delegate: ChatSearchDelegate(),
              );
            },
          ),
        ],
      ),
      body: _buildChatList(),
    );
  }
}

class ChatSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    if (query.length < 2) {
      return const Center(
        child: Text('Type at least 2 characters to search'),
      );
    }

    final userProvider = Provider.of<UserProvider>(context);
    if (userProvider.user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('searchName', arrayContains: query.toLowerCase())
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data?.docs ?? [];
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userData = users[index].data() as Map<String, dynamic>;
            if (userData['uid'] == userProvider.user!.uid) {
              return const SizedBox();
            }

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: userData['photoUrl'] != null
                    ? CachedNetworkImageProvider(userData['photoUrl'])
                    : null,
                child: userData['photoUrl'] == null
                    ? Text(
                  (userData['name'] as String? ?? 'A')[0].toUpperCase(),
                  style: const TextStyle(fontSize: 20),
                )
                    : null,
              ),
              title: Text(userData['name'] ?? 'Anonymous'),
              subtitle: Text(userData['profession'] ?? 'No profession listed'),
              onTap: () async {
                // Create or get existing chat
                final chatDoc = await _createOrGetChat(
                  context,
                  userProvider.user!.uid,
                  userData['uid'],
                );

                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        chatId: chatDoc.id,
                        otherUserId: userData['uid'],
                      ),
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Future<DocumentReference> _createOrGetChat(
      BuildContext context,
      String currentUserId,
      String otherUserId,
      ) async {
    // Check if chat already exists
    final querySnapshot = await FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .get();

    for (final doc in querySnapshot.docs) {
      final participants = List<String>.from(doc['participants'] ?? []);
      if (participants.contains(otherUserId)) {
        return doc.reference;
      }
    }

    // Create new chat
    final chatDoc = await FirebaseFirestore.instance.collection('chats').add({
      'participants': [currentUserId, otherUserId],
      'lastMessage': null,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount$currentUserId': 0,
      'unreadCount$otherUserId': 0,
    });

    return chatDoc;
  }
}

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  Timer? _typingTimer;
  StreamSubscription? _typingSubscription;
  bool _otherUserTyping = false;

  @override
  void initState() {
    super.initState();
    _markAsRead();
    _setupTypingListener();
  }

  void _setupTypingListener() {
    _typingSubscription = _firestore
        .collection('chats')
        .doc(widget.chatId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          setState(() {
            _otherUserTyping = data['${widget.otherUserId}_typing'] ?? false;
          });
        }
      }
    });
  }

  Future<void> _markAsRead() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.user == null) return;

    await _firestore.collection('chats').doc(widget.chatId).update({
      'unreadCount${userProvider.user!.uid}': 0,
    });
  }

  void _updateTypingStatus(bool isTyping) {
    _typingTimer?.cancel();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.user == null) return;

    _firestore.collection('chats').doc(widget.chatId).update({
      '${userProvider.user!.uid}_typing': isTyping,
    });

    if (isTyping) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _firestore.collection('chats').doc(widget.chatId).update({
          '${userProvider.user!.uid}_typing': false,
        });
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.user == null) return;

    final message = _messageController.text.trim();
    _messageController.clear();
    _updateTypingStatus(false);

    try {
      final batch = _firestore.batch();
      final messageRef = _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc();

      batch.set(messageRef, {
        'senderId': userProvider.user!.uid,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
      });

      batch.update(_firestore.collection('chats').doc(widget.chatId), {
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount${widget.otherUserId}': FieldValue.increment(1),
        '${userProvider.user!.uid}_typing': false,
      });

      await batch.commit();

      // Scroll to bottom
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data?.docs ?? [];

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final messageData = messages[index].data() as Map<String, dynamic>;
            final isMe = messageData['senderId'] == Provider.of<UserProvider>(context).user?.uid;
            final message = messageData['message'] as String? ?? '';
            final timestamp = messageData['timestamp'] as Timestamp?;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  if (!isMe) const SizedBox(width: 40),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe ? Theme.of(context).primaryColor : Colors.grey[300],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message,
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black,
                            ),
                          ),
                          if (timestamp != null)
                            Text(
                              timeago.format(timestamp.toDate()),
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe ? Colors.white70 : Colors.black54,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (isMe) const SizedBox(width: 40),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(widget.otherUserId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) {
          return const Scaffold(
            body: Center(child: Text('User not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                CircleAvatar(
                  backgroundImage: userData['photoUrl'] != null
                      ? CachedNetworkImageProvider(userData['photoUrl'])
                      : null,
                  child: userData['photoUrl'] == null
                      ? Text(
                    (userData['name'] as String? ?? 'A')[0].toUpperCase(),
                    style: const TextStyle(fontSize: 20),
                  )
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userData['name'] ?? 'Anonymous'),
                    if (_otherUserTyping)
                      Text(
                        'typing...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.block),
                          title: const Text('Block User'),
                          onTap: () {
                            // Implement block functionality
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.report),
                          title: const Text('Report User'),
                          onTap: () {
                            // Implement report functionality
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(child: _buildMessageList()),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      onPressed: () {
                        // Implement file attachment
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.image),
                                title: const Text('Image'),
                                onTap: () {
                                  // Implement image sending
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.camera_alt),
                                title: const Text('Camera'),
                                onTap: () {
                                  // Implement camera capture
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.insert_drive_file),
                                title: const Text('Document'),
                                onTap: () {
                                  // Implement document sending
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                        ),
                        onChanged: (value) {
                          _updateTypingStatus(value.isNotEmpty);
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _typingSubscription?.cancel();
    super.dispose();
  }
}