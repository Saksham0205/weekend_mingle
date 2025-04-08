import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:weekend_mingle/screens/chat_screen.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/friend_service.dart';
import '../services/location_service.dart';
import '../services/permission_service.dart';
import '../providers/user_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'edit_profile_screen.dart';
import 'explore_tab.dart';
import 'friends_tab.dart';
import '../providers/feed_provider.dart' as feed;
import '../providers/notification_provider.dart' as app_notifications;
import 'notifications_screen.dart';
import 'groups_events_screen.dart';
import 'chats_tab.dart' as ChatsTab;
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';
import 'package:badges/badges.dart' as badges;
import '../models/post_model.dart';
import '../models/weekend_activity_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/stories_widget.dart';
import 'weekend_activities_screen.dart';
import '../utils/responsive_helper.dart';
import '../utils/responsive_extensions.dart';
import 'weekend_activity_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialTabIndex;

  const HomeScreen({super.key, this.initialTabIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  bool _showNotifications = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await PermissionService.checkAndRequestAllPermissions(context);
  }

  Future<void> _sendFriendRequest(
      BuildContext context, String currentUserId, UserModel otherUser) async {
    final friendService = FriendService();
    try {
      await friendService.sendFriendRequest(currentUserId, otherUser.uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Friend request sent to ${otherUser.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending friend request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userProvider = Provider.of<UserProvider>(context);
    if (userProvider.user?.uid != null) {
      // Use addPostFrameCallback to ensure this happens after the build is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<feed.FeedProvider>(context, listen: false)
            .initializeFeed(userProvider.user!.uid);
        Provider.of<app_notifications.NotificationProvider>(context,
            listen: false)
            .initializeNotifications(userProvider.user!.uid);
      });
    }
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, UserModel? currentUser) {
    return AppBar(
      elevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      title: Text(
        'Weekend Mingle',
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            Navigator.pushNamed(context, '/search');
          },
        ),
        Consumer<app_notifications.NotificationProvider>(
          builder: (context, notificationProvider, child) {
            final hasUnread = notificationProvider.hasUnreadNotifications;

            return IconButton(
              icon: badges.Badge(
                showBadge: hasUnread,
                badgeContent: Text(
                  '',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
                badgeStyle: badges.BadgeStyle(
                  badgeColor: Colors.red,
                ),
                child: Icon(Icons.notifications),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/notifications');
              },
            );
          },
        ),
        IconButton(
          icon: CircleAvatar(
            backgroundImage: currentUser?.photoUrl != null
                ? NetworkImage(currentUser!.photoUrl!)
                : const AssetImage('assets/images/default_profile.jpg')
            as ImageProvider,
            radius: 15,
          ),
          onPressed: () {
            final userProvider =
            Provider.of<UserProvider>(context, listen: false);
            if (userProvider.user != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      EditProfileScreen(user: userProvider.user!),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildMainFeed() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(
        child: Text("You must be logged in to view the feed"),
      );
    }

    final feedProvider = Provider.of<feed.FeedProvider>(context, listen: false);

    if (feedProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (feedProvider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error: ${feedProvider.error}',
              style: const TextStyle(color: Colors.red),
            ),
            ElevatedButton(
              onPressed: () {
                final userProvider =
                Provider.of<UserProvider>(context, listen: false);
                feedProvider.initializeFeed(userProvider.user?.uid);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        feedProvider.initializeFeed(userProvider.user?.uid);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          StoriesWidget(),
          _buildRecommendedPeopleSection(),
          _buildTrendingWeekendPlansSection(),
          _buildExploreEventsSection(),
          _buildActiveUsersSection(),
          ...feedProvider.posts
              .map((feedPost) => _buildPostCard(Post(
            id: feedPost.id,
            userId: feedPost.userId,
            userName: feedPost.userName,
            userPhotoUrl: feedPost.userPhotoUrl,
            content: feedPost.content,
            imageUrl: feedPost.imageUrl,
            timestamp: feedPost.timestamp,
            likes: feedPost.likes,
            comments: feedPost.comments
                .map((comment) => Comment(
              userId: comment.userId,
              userName: comment.userName,
              userPhotoUrl: comment.userPhotoUrl,
              content: comment.content,
              timestamp: comment.timestamp,
            ))
                .toList(),
          )))
              .toList(),
        ],
      ),
    );
  }

  // 1. Stories & Quick Updates Section
  Widget _buildStoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Stories & Updates',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () {
                  // TODO: Implement add story functionality
                },
              ),
            ],
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              // Your Story (Add Story Button)
              _buildAddStoryButton(),

              // Example Weekend Mood Stories
              _buildWeekendMoodStory(
                  'Party', Icons.local_fire_department, Colors.red),
              _buildWeekendMoodStory('Chill', Icons.coffee, Colors.brown),
              _buildWeekendMoodStory(
                  'Gaming', Icons.sports_esports, Colors.purple),
              _buildWeekendMoodStory('Outdoor', Icons.landscape, Colors.green),

              // Fetch actual stories from Firebase here
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddStoryButton() {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;
    if (user == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                  image: user.photoUrl != null && user.photoUrl!.isNotEmpty
                      ? DecorationImage(
                    image: CachedNetworkImageProvider(user.photoUrl!),
                    fit: BoxFit.cover,
                  )
                      : null,
                ),
                child: user.photoUrl == null || user.photoUrl!.isEmpty
                    ? Icon(
                  Icons.person,
                  size: 40,
                  color: Colors.grey[400],
                )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Your Story',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekendMoodStory(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.7),
                  color,
                ],
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // 2. Recommended People to Connect Section
  Widget _buildRecommendedPeopleSection() {
    final currentUser = Provider.of<UserProvider>(context).user;
    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const SizedBox.shrink();
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final sentRequests =
        List<String>.from(userData['sentFriendRequests'] ?? []);
        final friends = List<String>.from(userData['friends'] ?? []);
        final pendingRequests =
        List<String>.from(userData['pendingFriendRequests'] ?? []);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'People to Connect',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(
                              () => _currentIndex = 1); // Switch to connections tab
                    },
                    child: const Text('See All'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 250,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where(FieldPath.documentId, isNotEqualTo: currentUser.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Something went wrong'),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allUsers = snapshot.data!.docs;
                  final usersToShow = allUsers.where((doc) {
                    final userId = doc.id;
                    // Filter out friends, pending requests and sent requests
                    return !friends.contains(userId) &&
                        !sentRequests.contains(userId) &&
                        !pendingRequests.contains(userId);
                  }).toList();

                  if (usersToShow.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No new connections available',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: usersToShow.length,
                    itemBuilder: (context, index) {
                      final doc = usersToShow[index];
                      try {
                        final user = UserModel.fromDocumentSnapshot(doc);
                        return _buildUserConnectionCard(user);
                      } catch (e) {
                        print('Error parsing user data at index $index: $e');
                        return const SizedBox.shrink();
                      }
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUserConnectionCard(UserModel user) {
    final currentUser = Provider.of<UserProvider>(context).user;
    if (currentUser == null) return const SizedBox.shrink();

    return Container(
      width: 180,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          CircleAvatar(
            radius: 45,
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
            backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty
                ? CachedNetworkImageProvider(user.photoUrl!) as ImageProvider
                : null,
            child: user.photoUrl == null || user.photoUrl!.isEmpty
                ? Text(
              user.name[0].toUpperCase(),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            )
                : null,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              user.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${user.profession ?? 'Professional'} | ${user.company ?? 'Weekend Mingler'}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _sendFriendRequest(context, currentUser.uid, user),
            icon: const Icon(Icons.person_add, size: 16),
            label: const Text('Connect'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: const TextStyle(fontSize: 14),
            ),
          ),
          SizedBox(height: 12),
        ],
      ),
    );
  }

  // 3. Featured & Trending Weekend Plans Section
  Widget _buildTrendingWeekendPlansSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Trending Weekend Plans',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GroupsEventsScreen(),
                    ),
                  );
                },
                child: const Text('See All'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('weekend_activities')
                .orderBy('currentAttendees', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final activities = snapshot.data?.docs ?? [];

              if (activities.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No weekend plans yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showCreateWeekendPlanDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Create Plan'),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: activities.length,
                      itemBuilder: (context, index) {
                        final doc = activities[index];
                        try {
                          final data = doc.data() as Map<String, dynamic>;
                          final activity =
                          WeekendActivity.fromMap(data, doc.id);
                          return _buildWeekendPlanCard(activity);
                        } catch (e) {
                          print('Error parsing weekend activity: $e');
                          return const SizedBox.shrink();
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WeekendActivitiesScreen(),
                          ),
                        );
                      },
                      child: const Text('View All Activities'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWeekendPlanCard(WeekendActivity activity) {
    final dateFormat = DateFormat('EEEE, MMM d');
    final timeFormat = DateFormat('h:mm a');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: SizedBox(
        width: 250,
        // Use IntrinsicHeight to calculate the minimum required height
        child: IntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image Container - fixed height
              Container(
                height: 80, // Reduced height
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  color: activity.imageUrl == null
                      ? Theme.of(context).primaryColor
                      : null,
                  image: activity.imageUrl != null
                      ? DecorationImage(
                    image: CachedNetworkImageProvider(activity.imageUrl!),
                    fit: BoxFit.cover,
                  )
                      : null,
                ),
                child: activity.imageUrl == null
                    ? Center(
                  child: Icon(
                    _getEventTypeIcon(activity.eventType),
                    color: Colors.white,
                    size: 24,
                  ),
                )
                    : null,
              ),

              // Content area - make this scrollable if needed
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(8),
                  shrinkWrap: true,
                  physics: ClampingScrollPhysics(),
                  children: [
                    // Event Type Tag
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        activity.eventType,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    SizedBox(height: 4),

                    // Title
                    Text(
                      activity.title,
                      style: TextStyle(
                        fontSize: 12, // Reduced font size
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: 4),

                    // Date & Time
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 10, color: Colors.grey),
                        SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            '${dateFormat.format(activity.date)} • ${timeFormat.format(activity.startTime)}',
                            style:
                            TextStyle(fontSize: 9, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 2),

                    // Location - optional, remove if needed
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 10, color: Colors.grey),
                        SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            activity.location,
                            style:
                            TextStyle(fontSize: 9, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 4),

                    // Attendees & Join Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${activity.currentAttendees}/${activity.capacity}',
                          style: TextStyle(
                              fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    WeekendActivityDetailScreen(
                                        activity: activity),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            minimumSize: Size(30, 16),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Join', style: TextStyle(fontSize: 9)),
                        ),
                      ],
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

  // 4. Explore Events & Groups Section
  Widget _buildExploreEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Explore Categories',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _currentIndex = 3); // Switch to explore tab
                },
                child: const Text('More'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildCategoryCard('Professional', Icons.business, Colors.blue),
              _buildCategoryCard('Social', Icons.people, Colors.orange),
              _buildCategoryCard('Fitness', Icons.fitness_center, Colors.green),
              _buildCategoryCard('Gaming', Icons.sports_esports, Colors.purple),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(String title, IconData icon, Color color) {
    return InkWell(
      onTap: () {
        // Navigate to category page
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: MediaQuery.of(context).size.width / 2 - 24,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.7),
              color,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 5. Active Users Nearby Section
  Widget _buildActiveUsersSection() {
    final currentUser = Provider.of<UserProvider>(context).user;
    if (currentUser == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Active Users Nearby',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(
                          () => _currentIndex = 1); // Switch to connections tab
                },
                child: const Text('See All'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 100,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('isOnline', isEqualTo: true)
                .where(FieldPath.documentId, isNotEqualTo: currentUser.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Something went wrong'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final onlineUsers = snapshot.data?.docs ?? [];

              if (onlineUsers.isEmpty) {
                return Center(
                  child: Text(
                    'No active users nearby',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                );
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: onlineUsers.length,
                itemBuilder: (context, index) {
                  final doc = onlineUsers[index];
                  try {
                    final user = UserModel.fromDocumentSnapshot(doc);
                    return _buildActiveUserItem(user);
                  } catch (e) {
                    print('Error parsing online user: $e');
                    return const SizedBox.shrink();
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActiveUserItem(UserModel user) {
    return GestureDetector(
      onTap: () => _showUserBottomSheet(user),
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor:
                  Theme.of(context).primaryColor.withOpacity(0.1),
                  backgroundImage:
                  user.photoUrl != null && user.photoUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(user.photoUrl!)
                  as ImageProvider
                      : null,
                  child: user.photoUrl == null || user.photoUrl!.isEmpty
                      ? Text(
                    user.name[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              user.name.split(' ')[0], // Just the first name
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getEventTypeIcon(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'party':
        return Icons.local_bar;
      case 'dinner':
        return Icons.restaurant;
      case 'movie':
        return Icons.movie;
      case 'concert':
        return Icons.music_note;
      case 'sports':
        return Icons.sports_basketball;
      case 'hiking':
        return Icons.terrain;
      case 'gaming':
        return Icons.sports_esports;
      case 'networking':
        return Icons.business;
      default:
        return Icons.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveHelper.init(context);
    final userProvider = Provider.of<UserProvider>(context);
    return Scaffold(
      appBar: _buildAppBar(context, userProvider.user),
      body: Stack(
        children: [
          _currentIndex == 0 ? _buildMainFeed() : _getScreen(),
          if (_showNotifications) _buildNotificationsOverlay(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon:
            Icon(Icons.home, size: ResponsiveHelper.getResponsiveWidth(24)),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore,
                size: ResponsiveHelper.getResponsiveWidth(24)),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people,
                size: ResponsiveHelper.getResponsiveWidth(24)),
            label: 'Friends',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline,
                size: ResponsiveHelper.getResponsiveWidth(24)),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person,
                size: ResponsiveHelper.getResponsiveWidth(24)),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
        onPressed: _showCreateWeekendPlanDialog,
        child: Icon(Icons.add,
            size: ResponsiveHelper.getResponsiveWidth(24)),
      )
          : null,
    );
  }

  BottomNavigationBarItem _buildNavItem(
      IconData icon, IconData activeIcon, String label, int index) {
    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _currentIndex == index
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon),
      ),
      activeIcon: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(activeIcon),
      ),
      label: label,
    );
  }

  Widget _getScreen() {
    switch (_currentIndex) {
      case 1:
        return const ExploreTab();
      case 2:
        return const FriendsTab();
      case 3:
        return const ChatsTab.ChatsTab();
      case 4:
        return const ProfileTab();
      default:
        return _buildMainFeed();
    }
  }

  void _showUserBottomSheet(UserModel user) {
    final currentUser = Provider.of<UserProvider>(context, listen: false).user;
    if (currentUser == null) return;

    // Check if they are friends before showing the chat option
    FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get()
        .then((doc) {
      final userData = doc.data() as Map<String, dynamic>;
      final friends = List<String>.from(userData['friends'] ?? []);
      final isFriend = friends.contains(user.uid);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Stack(
              children: [
                SingleChildScrollView(
                  controller: controller,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Theme.of(context).primaryColor,
                                  Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.8),
                                ],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            child: user.photoUrl != null &&
                                user.photoUrl!.isNotEmpty &&
                                Uri.tryParse(user.photoUrl!)
                                    ?.hasAbsolutePath ==
                                    true
                                ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                              child: CachedNetworkImage(
                                imageUrl: user.photoUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    Center(
                                      child: Text(
                                        user.name[0].toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 72,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                              ),
                            )
                                : Center(
                              child: Text(
                                user.name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 72,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 16,
                            right: 16,
                            child: IconButton(
                              icon:
                              const Icon(Icons.close, color: Colors.white),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.name,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user.profession,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      if (user.company != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          user.company!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isFriend)
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ChatScreen(
                                                otherUser: user,
                                                chatId:
                                                '${currentUser.uid}_${user.uid}',
                                                otherUserName: user.name,
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.chat),
                                        label: const Text('Message'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      _sendFriendRequest(
                                          context, currentUser.uid, user);
                                      Navigator.pop(context);
                                    },
                                    icon: const Icon(Icons.person_add),
                                    label: const Text('Connect'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (user.locationName != null) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(Icons.location_on,
                                      size: 20, color: Colors.grey[600]),
                                  const SizedBox(width: 8),
                                  Text(
                                    user.locationName!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (user.bio != null && user.bio!.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              const Text(
                                'About',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                user.bio!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ],
                            if (user.skills.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              const Text(
                                'Professional Skills',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: user.skills.map((skill) {
                                  return Chip(
                                    label: Text(skill),
                                    backgroundColor: Theme.of(context)
                                        .primaryColor
                                        .withOpacity(0.1),
                                    labelStyle: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            if (user.weekendInterests.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              const Text(
                                'Weekend Interests',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: user.weekendInterests.map((interest) {
                                  return Chip(
                                    label: Text(interest),
                                    backgroundColor:
                                    Colors.purple.withOpacity(0.1),
                                    labelStyle: const TextStyle(
                                      color: Colors.purple,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            const SizedBox(height: 24),
                            const Text(
                              'Availability',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: user.availability.entries
                                  .where((entry) => entry.value)
                                  .map((entry) {
                                final time = entry.key
                                    .split('_')
                                    .map(
                                      (word) =>
                                  word[0].toUpperCase() +
                                      word.substring(1),
                                )
                                    .join(' ');
                                return Chip(
                                  label: Text(time),
                                  backgroundColor:
                                  Colors.green.withOpacity(0.1),
                                  labelStyle: const TextStyle(
                                    color: Colors.green,
                                  ),
                                );
                              }).toList(),
                            ),
                            if (user.linkedin != null ||
                                user.github != null ||
                                user.twitter != null) ...[
                              const SizedBox(height: 24),
                              const Text(
                                'Social Links',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  if (user.linkedin != null)
                                    IconButton(
                                      icon: const Icon(Icons.link),
                                      onPressed: () {
                                        // Handle LinkedIn link
                                      },
                                      tooltip: 'LinkedIn',
                                    ),
                                  if (user.github != null)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16),
                                      child: IconButton(
                                        icon: const Icon(Icons.code),
                                        onPressed: () {
                                          // Handle GitHub link
                                        },
                                        tooltip: 'GitHub',
                                      ),
                                    ),
                                  if (user.twitter != null)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16),
                                      child: IconButton(
                                        icon: const Icon(Icons.chat),
                                        onPressed: () {
                                          // Handle Twitter link
                                        },
                                        tooltip: 'Twitter',
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 150,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  void _showCreateWeekendPlanDialog() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final dateController = TextEditingController();
    final locationController = TextEditingController();
    final tagController = TextEditingController();
    DateTime? selectedDate;
    String _eventType = 'Other';
    bool _isPrivate = false;
    int _capacity = 10;
    List<String> _tags = [];
    final List<String> _eventTypes = [
      'Hiking',
      'Dinner',
      'Movie',
      'Sports',
      'Gaming',
      'Music',
      'Other'
    ];

    IconData _getEventTypeIcon(String eventType) {
      switch (eventType.toLowerCase()) {
        case 'hiking':
          return Icons.landscape;
        case 'dinner':
          return Icons.restaurant;
        case 'movie':
          return Icons.movie;
        case 'sports':
          return Icons.sports;
        case 'gaming':
          return Icons.games;
        case 'music':
          return Icons.music_note;
        default:
          return Icons.event;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Create Weekend Plan',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.title),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.description),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a description';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _eventType,
                    decoration: InputDecoration(
                      labelText: 'Activity Type',
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(_getEventTypeIcon(_eventType)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: _eventTypes.map((String type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Row(
                          children: [
                            Icon(_getEventTypeIcon(type)),
                            const SizedBox(width: 8),
                            Text(type),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _eventType = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: dateController,
                    decoration: InputDecoration(
                      labelText: 'Date',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.calendar_today),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    readOnly: true,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDate = picked;
                          dateController.text =
                              DateFormat('EEEE, MMM d').format(picked);
                        });
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a date';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: locationController,
                    decoration: InputDecoration(
                      labelText: 'Location',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.location_on),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a location';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: tagController,
                          decoration: InputDecoration(
                            labelText: 'Add Tags',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.tag),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          if (tagController.text.isNotEmpty) {
                            setState(() {
                              _tags.add(tagController.text);
                              tagController.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  if (_tags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: _tags
                          .map((tag) => Chip(
                        label: Text(tag),
                        onDeleted: () {
                          setState(() {
                            _tags.remove(tag);
                          });
                        },
                      ))
                          .toList(),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Maximum Attendees: $_capacity',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () {
                          setState(() {
                            if (_capacity > 2) _capacity--;
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          setState(() {
                            if (_capacity < 50) _capacity++;
                          });
                        },
                      ),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text('Private Event'),
                    subtitle: const Text('Only invited people can join'),
                    value: _isPrivate,
                    onChanged: (bool value) {
                      setState(() {
                        _isPrivate = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      if (formKey.currentState!.validate() &&
                          selectedDate != null) {
                        final currentUser =
                            Provider.of<UserProvider>(context, listen: false)
                                .user;
                        if (currentUser == null) return;

                        try {
                          await FirebaseFirestore.instance
                              .collection('weekend_activities')
                              .add({
                            'title': titleController.text,
                            'description': descriptionController.text,
                            'eventType': _eventType,
                            'date': Timestamp.fromDate(selectedDate!),
                            'startTime': Timestamp.fromDate(selectedDate!),
                            'endTime': Timestamp.fromDate(
                                selectedDate!.add(Duration(hours: 2))),
                            'location': locationController.text,
                            'creatorId': currentUser.uid,
                            'creatorName': currentUser.name ?? 'Anonymous',
                            'creatorPhotoUrl': currentUser.photoUrl,
                            'createdAt': Timestamp.now(),
                            'attendees': [currentUser.uid],
                            'interestedUsers': [],
                            'capacity': _capacity,
                            'currentAttendees': 1,
                            'isPaid': false,
                            'additionalInfo': {
                              'isPrivate': _isPrivate,
                              'tags': _tags
                            },
                          });

                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                Text('Weekend plan created successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                Text('Error creating weekend plan: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                    child: const Text('Create Plan'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsOverlay() {
    final notificationProvider =
    Provider.of<app_notifications.NotificationProvider>(context);
    final notifications = notificationProvider.notifications;

    return Positioned(
      top: 0,
      right: 0,
      width: MediaQuery.of(context).size.width * 0.85,
      child: GestureDetector(
        onTap: () {}, // Prevent clicks from passing through
        child: Card(
          margin: const EdgeInsets.only(top: 8, right: 8),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _showNotifications = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Notification List
                Expanded(
                  child: notifications.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                          null, // We don't have sender photo in our model
                          child: const Icon(Icons.person),
                        ),
                        title: Text(notification.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notification.message),
                            const SizedBox(height: 4),
                            Text(
                              _formatMessageTime(
                                  notification.timestamp as Timestamp?),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        trailing: !notification.isRead
                            ? Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                        )
                            : null,
                        onTap: () {
                          // Mark as read
                          notificationProvider
                              .markAsRead(notification.id);
                          // Handle notification tap based on type
                          _handleNotificationTap(notification);
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                // Footer
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextButton(
                    child: const Text('See All Notifications'),
                    onPressed: () {
                      setState(() {
                        _showNotifications = false;
                      });
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleNotificationTap(app_notifications.Notification notification) {
    setState(() {
      _showNotifications = false;
    });

    switch (notification.type) {
      case 'friend_request':
        setState(() => _currentIndex = 1); // Switch to connections tab
        if (notification.relatedId != null) {
          // If there's a related user ID, we could show their profile
        }
        break;
      case 'message':
        if (notification.relatedId != null) {
          // For message notifications, relatedId is likely the chatId
          final chatId = notification.relatedId!;
          // Find the other user ID from the chat ID
          List<String> userIds = chatId.split('_');
          if (userIds.length == 2) {
            final currentUser =
                Provider.of<UserProvider>(context, listen: false).user;
            final otherUserId =
            userIds[0] == currentUser?.uid ? userIds[1] : userIds[0];

            // Fetch user data
            FirebaseFirestore.instance
                .collection('users')
                .doc(otherUserId)
                .get()
                .then((userDoc) {
              if (userDoc.exists && context.mounted) {
                final userData = userDoc.data()!;
                final otherUser = UserModel.fromMap(userData, otherUserId);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      otherUser: otherUser,
                      chatId: chatId,
                      otherUserName: otherUser.name,
                    ),
                  ),
                );
              }
            });
          }
        }
        break;
      case 'weekend_plan':
      // Navigate to the specific weekend plan
        if (notification.relatedId != null) {
          final planId = notification.relatedId!;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const GroupsEventsScreen(),
              // TODO: Navigate to specific plan with planId
            ),
          );
        }
        break;
      default:
      // Default action is to go to the notifications screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const NotificationsScreen(),
          ),
        );
    }
  }

  Widget _buildPostCard(Post post) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.user;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundImage: post.userPhotoUrl != null
                  ? CachedNetworkImageProvider(post.userPhotoUrl!)
                  : null,
              child:
              post.userPhotoUrl == null ? const Icon(Icons.person) : null,
            ),
            title: Text(post.userName),
            subtitle: Text(timeago.format(post.timestamp)),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                if (currentUser?.uid == post.userId)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                const PopupMenuItem(
                  value: 'report',
                  child: Text('Report'),
                ),
              ],
              onSelected: (value) {
                if (value == 'delete') {
                  Provider.of<feed.FeedProvider>(context, listen: false)
                      .deletePost(post.id);
                }
              },
            ),
          ),
          if (post.imageUrl != null)
            CachedNetworkImage(
              imageUrl: post.imageUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(),
              ),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(post.content),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: Icon(
                  post.likes.contains(currentUser?.uid)
                      ? Icons.favorite
                      : Icons.favorite_border,
                ),
                color: post.likes.contains(currentUser?.uid)
                    ? Colors.red
                    : null, // Move color here
                onPressed: () {
                  if (currentUser != null) {
                    Provider.of<feed.FeedProvider>(context, listen: false)
                        .likePost(post.id, currentUser.uid);
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.comment_outlined),
                onPressed: () {
                  // Show comment dialog
                },
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () {
                  // Handle share
                },
              ),
            ],
          ),
          if (post.likes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${post.likes.length} ${post.likes.length == 1 ? 'like' : 'likes'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          if (post.comments.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Comments',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: post.comments.length > 2 ? 2 : post.comments.length,
              itemBuilder: (context, index) {
                final comment = post.comments[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: comment.userPhotoUrl != null
                        ? CachedNetworkImageProvider(comment.userPhotoUrl!)
                        : null,
                    child: comment.userPhotoUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(comment.userName),
                  subtitle: Text(comment.content),
                );
              },
            ),
            if (post.comments.length > 2)
              TextButton(
                onPressed: () {
                  // Show all comments
                },
                child: Text('View all ${post.comments.length} comments'),
              ),
          ],
        ],
      ),
    );
  }

  String _formatMessageTime(Timestamp? timestamp) {
    if (timestamp == null) return '';

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

class AnimatedCard extends StatefulWidget {
  final UserModel user;
  final VoidCallback onTap;

  const AnimatedCard({
    Key? key,
    required this.user,
    required this.onTap,
  }) : super(key: key);

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
        setState(() => _isHovered = true);
      },
      onTapUp: (_) {
        _controller.reverse();
        setState(() => _isHovered = false);
        widget.onTap();
      },
      onTapCancel: () {
        _controller.reverse();
        setState(() => _isHovered = false);
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Card(
          elevation: _isHovered ? 8 : 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                          backgroundColor:
                          Theme.of(context).primaryColor.withOpacity(0.1),
                          backgroundImage:
                          user.photoUrl != null && user.photoUrl!.isNotEmpty
                              ? CachedNetworkImageProvider(user.photoUrl!)
                          as ImageProvider
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
      ),
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
          otherUserName: otherUser.name,
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

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final friends = List<String>.from(userData['friends'] ?? []);

        if (friends.isEmpty) {
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
                  'No conversations yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect with people to start chatting!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
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
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
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

            final chats = snapshot.data!.docs.where((chat) {
              final participants =
              List<String>.from(chat.data()['participants'] ?? []);
              final otherUserId = participants
                  .firstWhere((id) => id != currentUser.uid, orElse: () => '');
              // Only show chats with friends
              return friends.contains(otherUserId);
            }).toList();

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
                      'Start a conversation',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Message your connections to plan weekend activities!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                final participants =
                List<String>.from(chat.data()['participants'] ?? []);
                final otherUserId = participants.firstWhere(
                        (id) => id != currentUser.uid,
                    orElse: () => '');

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
                    UserModel.fromDocumentSnapshot(userSnapshot.data!);
                    final lastMessage = chat.data()['lastMessage'] as String?;
                    final lastMessageTime =
                    chat.data()['lastMessageTime'] as Timestamp?;
                    final unreadCount =
                        chat.data()['unreadCount${currentUser.uid}'] as int? ??
                            0;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
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
                                ? CachedNetworkImageProvider(
                                otherUser.photoUrl!) as ImageProvider
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
      },
    );
  }

  String _formatMessageTime(Timestamp? timestamp) {
    if (timestamp == null) return '';

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

        final userData = UserModel.fromDocumentSnapshot(snapshot.data!);

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
                        icon: const Icon(Icons.edit, color: Colors.white),
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

// Helper function for firestore document conversions
UserModel userFromDoc(dynamic doc) {
  if (doc is QueryDocumentSnapshot) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap(data, doc.id);
  } else if (doc is DocumentSnapshot) {
    return UserModel.fromDocumentSnapshot(doc);
  } else {
    throw Exception('Unsupported document type');
  }
}
