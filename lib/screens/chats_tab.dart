import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'home_screen.dart';
import 'chat_screen.dart';

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
                    final scaffoldContext =
                        ScaffoldMessenger.of(context).context;
                    if (scaffoldContext != null) {
                      // Set the index to 1 (Connections tab)
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const HomeScreen(initialTabIndex: 1)),
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
            final participants =
                List<String>.from(chatData['participants'] ?? []);

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

                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>?;
                if (userData == null) return const SizedBox();

                final lastMessage =
                    chatData['lastMessage'] as String? ?? 'No messages yet';
                final lastMessageTime =
                    chatData['lastMessageTime'] as Timestamp?;
                final unreadCount =
                    chatData['unreadCount${userProvider.user!.uid}'] as int? ??
                        0;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: userData['photoUrl'] != null
                        ? CachedNetworkImageProvider(userData['photoUrl'])
                        : null,
                    child: userData['photoUrl'] == null
                        ? Text(
                            (userData['name'] as String? ?? 'A')[0]
                                .toUpperCase(),
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
                  onTap: () async {
                    // Get user data from Firestore
                    final userDoc = await _firestore
                        .collection('users')
                        .doc(otherUserId)
                        .get();

                    if (userDoc.exists && userDoc.data() != null) {
                      // Create UserModel using the proper constructor
                      final otherUser =
                          UserModel.fromMap(userDoc.data()!, otherUserId);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            chatId: chat.id,
                            otherUser: otherUser,
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

                // Create a UserModel from the userData
                final otherUser = UserModel.fromMap(userData, userData['uid']);

                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        chatId: chatDoc.id,
                        otherUser: otherUser,
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
