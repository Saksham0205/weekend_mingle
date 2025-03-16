import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/friend_service.dart';
import '../services/location_service.dart';
import '../services/permission_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'chat_screen.dart';
import 'edit_profile_screen.dart';
import 'friends_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await PermissionService.checkAndRequestAllPermissions(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'Mingle',
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.logout,
              color: Theme.of(context).primaryColor,
            ),
            onPressed: () async {
              await _authService.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: _buildCurrentScreen(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Discover',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Friends',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return const DiscoverTab();
      case 1:
        return const FriendsTab();
      case 2:
        return const MessagesTab();
      case 3:
        return const ProfileTab();
      default:
        return const DiscoverTab();
    }
  }
}

class DiscoverTab extends StatelessWidget {
  const DiscoverTab({super.key});

  void _navigateToChat(BuildContext context, UserModel otherUser) async {
    final authService = AuthService();
    final currentUser = authService.currentUser;
    if (currentUser == null) return;

    // Create or get existing chat document
    final chatId = [currentUser.uid, otherUser.uid]..sort();
    final chatDocRef =
        FirebaseFirestore.instance.collection('chats').doc(chatId.join('_'));

    final chatDoc = await chatDocRef.get();
    if (!chatDoc.exists) {
      await chatDocRef.set({
        'participants': chatId,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'unreadCount${currentUser.uid}': 0,
        'unreadCount${otherUser.uid}': 0,
        '${currentUser.uid}_typing': false,
        '${otherUser.uid}_typing': false,
      });
    }

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            otherUser: otherUser,
            chatId: chatDocRef.id,
          ),
        ),
      );
    }
  }

  Future<void> _sendFriendRequest(
      BuildContext context, String currentUserId, UserModel otherUser) async {
    final friendService = FriendService();
    try {
      await friendService.sendFriendRequest(currentUserId, otherUser.uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend request sent to ${otherUser.name}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending friend request: $e')),
        );
      }
    }
  }

  Widget _buildAvailabilityChips(Map<String, bool> availability) {
    final availableTimes = availability.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key
            .split('_')
            .map(
              (word) => word[0].toUpperCase() + word.substring(1),
            )
            .join(' '))
        .toList();

    if (availableTimes.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: availableTimes.map((time) {
        return Chip(
          label: Text(
            time,
            style: const TextStyle(fontSize: 12),
          ),
          backgroundColor: Colors.green.withOpacity(0.1),
          side: const BorderSide(color: Colors.green, width: 0.5),
          labelStyle: const TextStyle(color: Colors.green),
        );
      }).toList(),
    );
  }

  Widget _buildSkillsSection(List<String> skills) {
    if (skills.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Professional Skills',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: skills.map((skill) {
            return Chip(
              label: Text(
                skill,
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: Colors.blue.withOpacity(0.1),
              side: const BorderSide(color: Colors.blue, width: 0.5),
              labelStyle: const TextStyle(color: Colors.blue),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWeekendInterests(List<String> interests) {
    if (interests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Weekend Activities',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: interests.map((interest) {
            return Chip(
              label: Text(
                interest,
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: Colors.purple.withOpacity(0.1),
              side: const BorderSide(color: Colors.purple, width: 0.5),
              labelStyle: const TextStyle(color: Colors.purple),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final currentUser = authService.currentUser;
    if (currentUser == null) return const Center(child: Text('Not logged in'));

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final currentUserData = UserModel.fromFirestore(userSnapshot.data!, null);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, isNotEqualTo: currentUser.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final allUsers = snapshot.data!.docs
                .map((doc) => UserModel.fromFirestore(doc, null))
                .where((user) =>
            !currentUserData.friends.contains(user.uid) &&
                !currentUserData.pendingFriendRequests.contains(user.uid) &&
                !currentUserData.sentFriendRequests.contains(user.uid))
                .toList();

            if (allUsers.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No new people to discover',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: allUsers.length,
              itemBuilder: (context, index) {
                final user = allUsers[index];
                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => DraggableScrollableSheet(
                          initialChildSize: 0.8,
                          maxChildSize: 0.9,
                          minChildSize: 0.5,
                          builder: (context, scrollController) => Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            child: SingleChildScrollView(
                              controller: scrollController,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Stack(
                                    children: [
                                      Container(
                                        height: 200,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Theme.of(context).primaryColor.withOpacity(0.8),
                                              Colors.white,
                                            ],
                                          ),
                                          borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(20),
                                          ),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Hero(
                                              tag: 'profile-${user.uid}',
                                              child: CircleAvatar(
                                                radius: 50,
                                                backgroundColor: Colors.white,
                                                child: CircleAvatar(
                                                  radius: 48,
                                                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                                  backgroundImage: user.photoUrl != null
                                                      ? CachedNetworkImageProvider(user.photoUrl!) as ImageProvider
                                                      : null,
                                                  child: user.photoUrl == null
                                                      ? Text(
                                                    user.name[0].toUpperCase(),
                                                    style: TextStyle(
                                                      fontSize: 36,
                                                      fontWeight: FontWeight.bold,
                                                      color: Theme.of(context).primaryColor,
                                                    ),
                                                  )
                                                      : null,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              user.name,
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            ElevatedButton.icon(
                                              icon: const Icon(Icons.person_add),
                                              label: const Text('Add Friend'),
                                              onPressed: () {
                                                _sendFriendRequest(context, currentUser.uid, user);
                                                Navigator.pop(context);
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 24),
                                        if (user.bio != null && user.bio!.isNotEmpty) ...[
                                          const Text(
                                            'About',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(user.bio!),
                                          const SizedBox(height: 24),
                                        ],
                                        if (user.skills.isNotEmpty)
                                          _buildSkillsSection(user.skills),
                                        if (user.weekendInterests.isNotEmpty) ...[
                                          const SizedBox(height: 24),
                                          _buildWeekendInterests(user.weekendInterests),
                                        ],
                                        const SizedBox(height: 24),
                                        const Text(
                                          'Available Times',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        _buildAvailabilityChips(user.availability),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).primaryColor.withOpacity(0.05),
                            Colors.white,
                          ],
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Profile image
                                Hero(
                                  tag: 'profile-${user.uid}',
                                  child: CircleAvatar(
                                    radius: 40,
                                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                    backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty
                                        ? CachedNetworkImageProvider(user.photoUrl!) as ImageProvider
                                        : null,
                                    child: user.photoUrl == null
                                        ? Text(
                                      user.name[0].toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    )
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // User name
                                Text(
                                  user.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),

                                // Profession
                                Text(
                                  user.profession,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),

                                // Industry (if available)
                                if (user.industry != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    user.industry!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ],

                                // Spacer is removed as it can cause layout issues in constrained spaces
                                const SizedBox(height: 12),

                                // Weekend interests
                                if (user.weekendInterests.isNotEmpty)
                                  Text(
                                    user.weekendInterests.first,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.purple[700],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),

                                // Open to networking indicator
                                if (user.openToNetworking)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.handshake_outlined,
                                          size: 16,
                                          color: Colors.green[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Open to connect',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
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

class MessagesTab extends StatelessWidget {
  const MessagesTab({super.key});

  void _navigateToChat(
      BuildContext context, UserModel otherUser, String chatId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUser: otherUser,
          chatId: chatId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      return const Center(child: Text('Not logged in'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final chats = snapshot.data!.docs;

        if (chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No messages yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start chatting with someone!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index].data();
            final participants = chat['participants'] as List?;

            if (participants == null || participants.isEmpty) {
              return const SizedBox.shrink();
            }

            final otherUserId = participants.firstWhere(
              (id) => id != currentUser.uid,
              orElse: () => '',
            );

            if (otherUserId.isEmpty) {
              return const SizedBox.shrink();
            }

            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(otherUserId)
                  .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData ||
                    userSnapshot.data?.data() == null) {
                  return const SizedBox.shrink();
                }

                final otherUser =
                    UserModel.fromFirestore(userSnapshot.data!, null);
                final lastMessage = chat['lastMessage'] as String?;
                final lastMessageTime = chat['lastMessageTime'] as Timestamp?;
                final unreadCount =
                    chat['unreadCount${currentUser.uid}'] as int? ?? 0;

                return Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  elevation: 0,
                  child: ListTile(
                    onTap: () {
                      _navigateToChat(context, otherUser, chats[index].id);
                    },
                    leading: Hero(
                      tag: 'chat-${otherUser.uid}',
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor:
                            Theme.of(context).primaryColor.withOpacity(0.1),
                        backgroundImage: otherUser.photoUrl != null &&
                                otherUser.photoUrl!.isNotEmpty
                            ? CachedNetworkImageProvider(otherUser.photoUrl!)
                                as ImageProvider
                            : null,
                        child: otherUser.photoUrl == null ||
                                otherUser.photoUrl!.isEmpty
                            ? Text(
                                otherUser.name[0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              )
                            : null,
                      ),
                    ),
                    title: Text(
                      otherUser.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: lastMessage != null
                        ? Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: unreadCount > 0
                                  ? Colors.black87
                                  : Colors.grey[600],
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          )
                        : null,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (lastMessageTime != null)
                          Text(
                            _formatMessageTime(lastMessageTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        if (unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
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

  String _formatMessageTime(Timestamp timestamp) {
    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);

    if (difference.inDays > 7) {
      return '${messageTime.day}/${messageTime.month}/${messageTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;

    if (user == null) {
      return const Center(child: Text('Not logged in'));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = UserModel.fromFirestore(snapshot.data!, null);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 64,
                    backgroundImage: userData.photoUrl != null &&
                            userData.photoUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(userData.photoUrl!)
                            as ImageProvider
                        : null,
                    child:
                        userData.photoUrl == null || userData.photoUrl!.isEmpty
                            ? Text(
                                userData.name[0].toUpperCase(),
                                style: const TextStyle(fontSize: 48),
                              )
                            : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      child: IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditProfileScreen(
                                user: userData,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                userData.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                userData.profession,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
              if (userData.bio != null && userData.bio!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  userData.bio!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
              if (userData.location != null) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      LocationService.getLocationDescription(
                          userData.location!),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfileScreen(user: userData),
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit Profile'),
              ),
            ],
          ),
        );
      },
    );
  }
}
