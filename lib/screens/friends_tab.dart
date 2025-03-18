import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/friend_request_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/friend_service.dart';
import 'chat_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _friendService = FriendService();
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToChat(BuildContext context, UserModel otherUser) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    // Create or get existing chat document
    final chatId = [currentUser.uid, otherUser.uid]..sort();
    final chatDocRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId.join('_'));

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
            otherUserName: otherUser.name,
          ),
        ),
      );
    }
  }

  void _showFriendProfile(BuildContext context, UserModel friend) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Stack(
            children: [
              SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      children: [
                        Container(
                          height: 250,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Theme.of(context).primaryColor,
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
                                tag: 'friend-${friend.uid}',
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 60,
                                    backgroundColor: Colors.white,
                                    child: CircleAvatar(
                                      radius: 58,
                                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                      backgroundImage: friend.photoUrl != null
                                          ? CachedNetworkImageProvider(friend.photoUrl!) as ImageProvider
                                          : null,
                                      child: friend.photoUrl == null
                                          ? Text(
                                        friend.name[0].toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      )
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                friend.name,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (friend.profession.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    friend.profession,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            color: Colors.white,
                            onPressed: () => Navigator.pop(context),
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
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildActionButton(
                                context,
                                icon: Icons.message,
                                label: 'Message',
                                color: Theme.of(context).primaryColor,
                                onTap: () {
                                  Navigator.pop(context);
                                  _navigateToChat(context, friend);
                                },
                              ),
                              _buildActionButton(
                                context,
                                icon: Icons.calendar_today,
                                label: 'Plan Meetup',
                                color: Colors.orange,
                                onTap: () {
                                  // TODO: Implement meetup planning
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Coming soon: Plan meetups with friends!'),
                                    ),
                                  );
                                },
                              ),
                              _buildActionButton(
                                context,
                                icon: Icons.person_remove,
                                label: 'Remove',
                                color: Colors.red,
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Remove Friend'),
                                      content: Text('Are you sure you want to remove ${friend.name} from your friends?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            final currentUser = _authService.currentUser;
                                            if (currentUser != null) {
                                              _friendService.removeFriend(currentUser.uid, friend.uid);
                                            }
                                            Navigator.pop(context); // Close dialog
                                            Navigator.pop(context); // Close profile
                                          },
                                          child: const Text('Remove'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          if (friend.bio != null && friend.bio!.isNotEmpty) ...[
                            _buildSectionTitle('About'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Text(friend.bio!),
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (friend.company != null || friend.industry != null) ...[
                            _buildSectionTitle('Professional Info'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue[100]!),
                              ),
                              child: Column(
                                children: [
                                  if (friend.company != null)
                                    ListTile(
                                      leading: const Icon(Icons.business, color: Colors.blue),
                                      title: Text(friend.company!),
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  if (friend.industry != null)
                                    ListTile(
                                      leading: const Icon(Icons.work, color: Colors.blue),
                                      title: Text(friend.industry!),
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (friend.locationName != null) ...[
                            _buildSectionTitle('Location'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green[100]!),
                              ),
                              child: ListTile(
                                leading: const Icon(Icons.location_on, color: Colors.green),
                                title: Text(friend.locationName!),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                trailing: TextButton.icon(
                                  icon: const Icon(Icons.map),
                                  label: const Text('View Map'),
                                  onPressed: () {
                                    // TODO: Implement map view
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Coming soon: View friend\'s location on map!'),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (friend.skills.isNotEmpty) ...[
                            _buildSectionTitle('Professional Skills'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.purple[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.purple[100]!),
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: friend.skills.map((skill) {
                                  return Chip(
                                    label: Text(
                                      skill,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    backgroundColor: Colors.purple.withOpacity(0.1),
                                    side: const BorderSide(color: Colors.purple, width: 0.5),
                                    labelStyle: const TextStyle(color: Colors.purple),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (friend.weekendInterests.isNotEmpty) ...[
                            _buildSectionTitle('Weekend Activities'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange[100]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: friend.weekendInterests.map((interest) {
                                      return ActionChip(
                                        avatar: const Icon(Icons.star, size: 16),
                                        label: Text(
                                          interest,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        backgroundColor: Colors.orange.withOpacity(0.1),
                                        side: const BorderSide(color: Colors.orange, width: 0.5),
                                        labelStyle: const TextStyle(color: Colors.orange),
                                        onPressed: () {
                                          // TODO: Implement activity suggestion
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Suggest doing $interest together?'),
                                              action: SnackBarAction(
                                                label: 'Plan',
                                                onPressed: () {
                                                  // TODO: Implement activity planning
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 12),
                                  Center(
                                    child: TextButton.icon(
                                      icon: const Icon(Icons.add_circle_outline),
                                      label: const Text('Suggest New Activity'),
                                      onPressed: () {
                                        // TODO: Implement activity suggestion
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Coming soon: Suggest activities to do together!'),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          _buildSectionTitle('Available Times'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.teal[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.teal[100]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: friend.availability.entries
                                      .where((entry) => entry.value)
                                      .map((entry) {
                                    final time = entry.key.split('_').map(
                                          (word) => word[0].toUpperCase() + word.substring(1),
                                    ).join(' ');
                                    return ActionChip(
                                      avatar: const Icon(Icons.access_time, size: 16),
                                      label: Text(
                                        time,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      backgroundColor: Colors.teal.withOpacity(0.1),
                                      side: const BorderSide(color: Colors.teal, width: 0.5),
                                      labelStyle: const TextStyle(color: Colors.teal),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Schedule Meetup'),
                                            content: Text('Would you like to schedule a meetup with ${friend.name} on $time?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  // TODO: Implement meetup scheduling
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Coming soon: Schedule meetups with friends!'),
                                                    ),
                                                  );
                                                },
                                                child: const Text('Schedule'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: TextButton.icon(
                                    icon: const Icon(Icons.calendar_today),
                                    label: const Text('Find Common Time'),
                                    onPressed: () {
                                      // TODO: Implement common time finder
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Coming soon: Find common available times!'),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: TextButton.icon(
                              icon: const Icon(Icons.report_outlined),
                              label: const Text('Report User'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Report User'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('Why are you reporting this user?'),
                                        const SizedBox(height: 16),
                                        ...['Inappropriate behavior', 'Spam', 'Fake profile', 'Other'].map(
                                              (reason) => ListTile(
                                            title: Text(reason),
                                            onTap: () {
                                              Navigator.pop(context);
                                              // TODO: Implement user reporting
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Thank you for reporting. We will review your report.'),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.grey[300],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
      BuildContext context, {
        required IconData icon,
        required String label,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return const Center(child: Text('Not logged in'));

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Friends'),
            Tab(text: 'Requests'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFriendsList(currentUser.uid),
              _buildRequestsList(currentUser.uid),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFriendsList(String userId) {
    return StreamBuilder<List<UserModel>>(
      stream: _friendService.getFriends(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final friends = snapshot.data!;
        if (friends.isEmpty) {
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
                  'No friends yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start connecting with people!',
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
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                onTap: () => _showFriendProfile(context, friend),
                leading: Hero(
                  tag: 'friend-${friend.uid}',
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    backgroundImage: friend.photoUrl != null
                        ? CachedNetworkImageProvider(friend.photoUrl!) as ImageProvider
                        : null,
                    child: friend.photoUrl == null
                        ? Text(
                      friend.name[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    )
                        : null,
                  ),
                ),
                title: Text(friend.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(friend.profession),
                    if (friend.company != null)
                      Text(
                        friend.company!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.message_outlined),
                      onPressed: () => _navigateToChat(context, friend),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showFriendProfile(context, friend),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRequestsList(String userId) {
    return StreamBuilder<List<FriendRequestModel>>(
      stream: _friendService.getPendingRequests(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!;
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_add_disabled_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No pending requests',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(request.senderId)
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(height: 0);
                }

                final sender = UserModel.fromFirestore(
                  snapshot.data! as DocumentSnapshot<Map<String, dynamic>>,
                  null,
                );

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: ListTile(
                    onTap: () => _showRequestSenderProfile(context, sender, request),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      backgroundImage: sender.photoUrl != null
                          ? CachedNetworkImageProvider(sender.photoUrl!) as ImageProvider
                          : null,
                      child: sender.photoUrl == null
                          ? Text(
                        sender.name[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      )
                          : null,
                    ),
                    title: Text(sender.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sender.profession),
                        Text(
                          'Tap to view profile',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline),
                          color: Colors.green,
                          onPressed: () => _friendService.acceptFriendRequest(
                            request.id,
                            userId,
                            sender.uid,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel_outlined),
                          color: Colors.red,
                          onPressed: () => _friendService.rejectFriendRequest(
                            request.id,
                            userId,
                            sender.uid,
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

  void _showRequestSenderProfile(BuildContext context, UserModel sender, FriendRequestModel request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Stack(
            children: [
              SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      children: [
                        Container(
                          height: 250,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Theme.of(context).primaryColor,
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
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundColor: Colors.white,
                                  child: CircleAvatar(
                                    radius: 58,
                                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                    backgroundImage: sender.photoUrl != null
                                        ? CachedNetworkImageProvider(sender.photoUrl!) as ImageProvider
                                        : null,
                                    child: sender.photoUrl == null
                                        ? Text(
                                      sender.name[0].toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 48,
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
                                sender.name,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (sender.profession.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    sender.profession,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            color: Colors.white,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Friend request actions banner
                          Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '${sender.name} wants to connect with you',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.check),
                                      label: const Text('Accept'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () {
                                        final currentUser = _authService.currentUser;
                                        if (currentUser != null) {
                                          _friendService.acceptFriendRequest(
                                            request.id,
                                            currentUser.uid,
                                            sender.uid,
                                          );
                                        }
                                        Navigator.pop(context);
                                      },
                                    ),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.close),
                                      label: const Text('Decline'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () {
                                        final currentUser = _authService.currentUser;
                                        if (currentUser != null) {
                                          _friendService.rejectFriendRequest(
                                            request.id,
                                            currentUser.uid,
                                            sender.uid,
                                          );
                                        }
                                        Navigator.pop(context);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          if (sender.bio != null && sender.bio!.isNotEmpty) ...[
                            _buildSectionTitle('About'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Text(sender.bio!),
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (sender.company != null || sender.industry != null) ...[
                            _buildSectionTitle('Professional Info'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue[100]!),
                              ),
                              child: Column(
                                children: [
                                  if (sender.company != null)
                                    ListTile(
                                      leading: const Icon(Icons.business, color: Colors.blue),
                                      title: Text(sender.company!),
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  if (sender.industry != null)
                                    ListTile(
                                      leading: const Icon(Icons.work, color: Colors.blue),
                                      title: Text(sender.industry!),
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (sender.locationName != null) ...[
                            _buildSectionTitle('Location'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green[100]!),
                              ),
                              child: ListTile(
                                leading: const Icon(Icons.location_on, color: Colors.green),
                                title: Text(sender.locationName!),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (sender.skills.isNotEmpty) ...[
                            _buildSectionTitle('Professional Skills'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.purple[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.purple[100]!),
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: sender.skills.map((skill) {
                                  return Chip(
                                    label: Text(
                                      skill,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    backgroundColor: Colors.purple.withOpacity(0.1),
                                    side: const BorderSide(color: Colors.purple, width: 0.5),
                                    labelStyle: const TextStyle(color: Colors.purple),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (sender.weekendInterests.isNotEmpty) ...[
                            _buildSectionTitle('Weekend Activities'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange[100]!),
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: sender.weekendInterests.map((interest) {
                                  return Chip(
                                    label: Text(
                                      interest,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    backgroundColor: Colors.orange.withOpacity(0.1),
                                    side: const BorderSide(color: Colors.orange, width: 0.5),
                                    labelStyle: const TextStyle(color: Colors.orange),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}