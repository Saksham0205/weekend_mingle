import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';
import '../providers/user_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'home_screen.dart';
import 'chat_screen.dart';
import 'package:badges/badges.dart' as badges;

class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();
  bool _isCreatingGroupChat = false;
  final TextEditingController _groupNameController = TextEditingController();
  List<String> _selectedContacts = [];

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Widget _buildChatList() {
    final userProvider = Provider.of<UserProvider>(context);
    if (userProvider.user == null) return const SizedBox();

    return StreamBuilder<List<Chat>>(
      stream: _chatService.getUserChats(userProvider.user!.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
                  'No conversations yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connect with friends to start chatting',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to friends tab
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(initialTabIndex: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.people),
                  label: const Text('Find Friends'),
                ),
              ],
            ),
          );
        }

        final chats = snapshot.data!;
        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            final userId = userProvider.user!.uid;
            final otherParticipantName = chat.getChatDisplayName(userId);
            final otherParticipantPhoto = chat.getChatDisplayPhoto(userId);
            final unreadCount = chat.getUnreadCountForUser(userId);

            return ListTile(
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: otherParticipantPhoto != null
                        ? CachedNetworkImageProvider(otherParticipantPhoto)
                        : null,
                    child: otherParticipantPhoto == null
                        ? Icon(
                      chat.isGroupChat
                          ? Icons.group
                          : Icons.person,
                      color: Colors.white,
                    )
                        : null,
                  ),
                  if (chat.isGroupChat)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.group,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              title: Text(
                otherParticipantName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                chat.lastMessageText.isNotEmpty
                    ? chat.lastMessageText
                    : 'Start a conversation',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTimestamp(chat.lastMessageAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: unreadCount > 0 ? Theme.of(context).primaryColor : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (unreadCount > 0)
                    badges.Badge(
                      badgeContent: Text(
                        unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                      badgeStyle: badges.BadgeStyle(
                        badgeColor: Theme.of(context).primaryColor,
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
                      otherUserName: otherParticipantName,
                      isGroupChat: chat.isGroupChat,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      return DateFormat.jm().format(timestamp); // e.g., "2:30 PM"
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(timestamp).inDays < 7) {
      return DateFormat.E().format(timestamp); // e.g., "Mon", "Tue"
    } else {
      return DateFormat.MMMd().format(timestamp); // e.g., "Jan 5"
    }
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
              showSearch(
                context: context,
                delegate: ChatSearchDelegate(),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'create_group') {
                _showCreateGroupDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'create_group',
                child: Row(
                  children: [
                    Icon(Icons.group_add),
                    SizedBox(width: 8),
                    Text('Create Group Chat'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildChatList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          if (userProvider.user != null) {
            _showContactsBottomSheet();
          }
        },
        child: const Icon(Icons.chat),
      ),
    );
  }

  void _showContactsBottomSheet() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'New Conversation',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('users')
                        .doc(userProvider.user!.uid)
                        .collection('friends')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text('No friends found. Add friends to start chatting.'),
                        );
                      }

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final friendDoc = snapshot.data!.docs[index];
                          final friendId = friendDoc.id;

                          return FutureBuilder<DocumentSnapshot>(
                            future: _firestore.collection('users').doc(friendId).get(),
                            builder: (context, friendSnapshot) {
                              if (!friendSnapshot.hasData) {
                                return const ListTile(
                                  leading: CircleAvatar(
                                    child: CircularProgressIndicator(),
                                  ),
                                  title: Text('Loading...'),
                                );
                              }

                              final friendData = friendSnapshot.data!.data() as Map<String, dynamic>;
                              final friend = UserModel.fromMap(friendData, friendId);

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: friend.photoUrl != null
                                      ? CachedNetworkImageProvider(friend.photoUrl!)
                                      : null,
                                  child: friend.photoUrl == null ? const Icon(Icons.person) : null,
                                ),
                                title: Text(friend.name),
                                subtitle: Text(friend.profession),
                                onTap: () async {
                                  Navigator.pop(context);

                                  // Create or get existing chat
                                  final chatId = await _chatService.createOrGetChat(friend.uid);

                                  if (!mounted) return;

                                  // Navigate to chat screen
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                        chatId: chatId,
                                        otherUserName: friend.name,
                                        isGroupChat: false,
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
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateGroupDialog() {
    _selectedContacts = [];
    _groupNameController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create Group Chat'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _groupNameController,
                    decoration: const InputDecoration(
                      labelText: 'Group Name',
                      hintText: 'Enter a name for your group',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showSelectGroupMembersBottomSheet(setState);
                    },
                    child: Text(
                      _selectedContacts.isEmpty
                          ? 'Select Members'
                          : 'Selected ${_selectedContacts.length} members',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _selectedContacts.isEmpty || _groupNameController.text.trim().isEmpty || _isCreatingGroupChat
                      ? null
                      : () async {
                    if (_groupNameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a group name')),
                      );
                      return;
                    }

                    if (_selectedContacts.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select at least one member')),
                      );
                      return;
                    }

                    setState(() {
                      _isCreatingGroupChat = true;
                    });

                    try {
                      final chatId = await _chatService.createGroupChat(
                        name: _groupNameController.text.trim(),
                        memberIds: _selectedContacts,
                      );

                      if (!mounted) return;

                      Navigator.pop(context);

                      // Navigate to the new group chat
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            chatId: chatId,
                            otherUserName: _groupNameController.text.trim(),
                            isGroupChat: true,
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to create group: $e')),
                      );
                    } finally {
                      if (mounted) {
                        setState(() {
                          _isCreatingGroupChat = false;
                        });
                      }
                    }
                  },
                  child: _isCreatingGroupChat
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSelectGroupMembersBottomSheet(StateSetter dialogSetState) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Select Group Members',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedContacts.isNotEmpty)
                      Container(
                        height: 90,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedContacts.length,
                          itemBuilder: (context, index) {
                            final contactId = _selectedContacts[index];
                            return FutureBuilder<DocumentSnapshot>(
                              future: _firestore.collection('users').doc(contactId).get(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const SizedBox(
                                    width: 60,
                                    child: Column(
                                      children: [
                                        CircleAvatar(child: CircularProgressIndicator(strokeWidth: 2)),
                                        SizedBox(height: 4),
                                        Text('Loading...', overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  );
                                }

                                final userData = snapshot.data!.data() as Map<String, dynamic>;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Column(
                                    children: [
                                      Stack(
                                        children: [
                                          CircleAvatar(
                                            radius: 30,
                                            backgroundImage: userData['photoUrl'] != null
                                                ? CachedNetworkImageProvider(userData['photoUrl'])
                                                : null,
                                            child: userData['photoUrl'] == null
                                                ? const Icon(Icons.person)
                                                : null,
                                          ),
                                          Positioned(
                                            right: 0,
                                            top: 0,
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _selectedContacts.remove(contactId);
                                                  dialogSetState(() {});
                                                });
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  size: 14,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        width: 60,
                                        child: Text(
                                          userData['name'] ?? 'Unknown',
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    const Divider(),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('users')
                            .doc(userProvider.user!.uid)
                            .collection('friends')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return const Center(
                              child: Text('No friends found. Add friends to create a group.'),
                            );
                          }

                          return ListView.builder(
                            controller: scrollController,
                            itemCount: snapshot.data!.docs.length,
                            itemBuilder: (context, index) {
                              final friendDoc = snapshot.data!.docs[index];
                              final friendId = friendDoc.id;

                              return FutureBuilder<DocumentSnapshot>(
                                future: _firestore.collection('users').doc(friendId).get(),
                                builder: (context, friendSnapshot) {
                                  if (!friendSnapshot.hasData) {
                                    return const ListTile(
                                      leading: CircleAvatar(
                                        child: CircularProgressIndicator(),
                                      ),
                                      title: Text('Loading...'),
                                    );
                                  }

                                  final friendData = friendSnapshot.data!.data() as Map<String, dynamic>;
                                  final friend = UserModel.fromMap(friendData, friendId);
                                  final isSelected = _selectedContacts.contains(friend.uid);

                                  return CheckboxListTile(
                                    value: isSelected,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          if (!_selectedContacts.contains(friend.uid)) {
                                            _selectedContacts.add(friend.uid);
                                          }
                                        } else {
                                          _selectedContacts.remove(friend.uid);
                                        }
                                        dialogSetState(() {});
                                      });
                                    },
                                    secondary: CircleAvatar(
                                      backgroundImage: friend.photoUrl != null
                                          ? CachedNetworkImageProvider(friend.photoUrl!)
                                          : null,
                                      child: friend.photoUrl == null ? const Icon(Icons.person) : null,
                                    ),
                                    title: Text(friend.name),
                                    subtitle: Text(friend.profession),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class ChatSearchDelegate extends SearchDelegate<String> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();

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
    if (query.isEmpty) {
      return const Center(
        child: Text('Search for chats or friends'),
      );
    }

    final currentUser = Provider.of<UserProvider>(context).user;
    if (currentUser == null) {
      return const Center(
        child: Text('You must be logged in to search'),
      );
    }

    final searchLower = query.toLowerCase();

    return FutureBuilder<QuerySnapshot>(
      future: _firestore
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: searchLower)
          .where('name', isLessThanOrEqualTo: searchLower + '\uf8ff')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No results found'),
          );
        }

        final userDocs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: userDocs.length,
          itemBuilder: (context, index) {
            final userData = userDocs[index].data() as Map<String, dynamic>;
            final userId = userDocs[index].id;

            // Don't show current user
            if (userId == currentUser.uid) return const SizedBox();

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: userData['photoUrl'] != null
                    ? CachedNetworkImageProvider(userData['photoUrl'])
                    : null,
                child: userData['photoUrl'] == null ? const Icon(Icons.person) : null,
              ),
              title: Text(userData['name'] ?? 'Unknown'),
              subtitle: Text(userData['profession'] ?? ''),
              onTap: () async {
                // Create or get chat with this user
                final chatId = await _chatService.createOrGetChat(userId);

                if (!context.mounted) return;

                close(context, chatId);

                // Navigate to chat screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      chatId: chatId,
                      otherUserName: userData['name'] ?? 'Unknown',
                      isGroupChat: false,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

