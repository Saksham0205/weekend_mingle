import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/post_model.dart';
import '../models/story_model.dart';
import '../models/weekend_activity_model.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../services/feed_service.dart';
import '../services/social_weekend_activity_service.dart';
import '../services/social_connection_service.dart';
import 'stories_widget.dart';

class SocialFeedWidget extends StatefulWidget {
  const SocialFeedWidget({super.key});

  @override
  State<SocialFeedWidget> createState() => _SocialFeedWidgetState();
}

class _SocialFeedWidgetState extends State<SocialFeedWidget> {
  final FeedService _feedService = FeedService();
  final SocialWeekendActivityService _socialActivityService =
      SocialWeekendActivityService();
  final SocialConnectionService _socialConnectionService =
      SocialConnectionService();

  List<dynamic> _feedItems = [];
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
      _isError = false;
    });

    try {
      final currentUser =
          Provider.of<UserProvider>(context, listen: false).user;
      if (currentUser == null) {
        setState(() {
          _isError = true;
          _errorMessage = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Get mixed social feed
      final feedItems =
          await _socialActivityService.getSocialActivityFeed(currentUser.uid);

      setState(() {
        _feedItems = feedItems;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isError = true;
        _errorMessage = 'Failed to load feed: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<UserProvider>(context).user;
    if (currentUser == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _loadFeed,
      child: Column(
        children: [
          // Stories row at the top
          const StoriesWidget(),

          // Feed content
          Expanded(
            child: _buildFeedContent(currentUser),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedContent(UserModel currentUser) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_errorMessage'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFeed,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_feedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Your feed is empty',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Follow more users or join weekend activities',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                // Get suggested users to follow
                final suggestedUsers = await _socialConnectionService
                    .getSuggestedUsersToFollow(currentUser.uid);

                if (suggestedUsers.isNotEmpty && mounted) {
                  _showSuggestedUsersDialog(suggestedUsers, currentUser.uid);
                }
              },
              child: const Text('Find People to Follow'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _feedItems.length,
      itemBuilder: (context, index) {
        final item = _feedItems[index];

        if (item is Post) {
          return _buildPostCard(item, currentUser);
        } else if (item is WeekendActivity) {
          return _buildActivityCard(item, currentUser);
        } else if (item is Story) {
          return _buildStoryPreviewCard(item, currentUser);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildPostCard(Post post, UserModel currentUser) {
    final isLiked = post.likes.contains(currentUser.uid);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post header with user info
          ListTile(
            leading: GestureDetector(
              onTap: () => _navigateToProfile(post.userId),
              child: CircleAvatar(
                backgroundImage: post.userPhotoUrl != null
                    ? CachedNetworkImageProvider(post.userPhotoUrl!)
                    : null,
                child:
                    post.userPhotoUrl == null ? const Icon(Icons.person) : null,
              ),
            ),
            title: GestureDetector(
              onTap: () => _navigateToProfile(post.userId),
              child: Text(
                post.userName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            subtitle: Text(timeago.format(post.timestamp)),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showPostOptions(post, currentUser),
            ),
          ),

          // Post content
          if (post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(post.content),
            ),

          // Post image if available
          if (post.imageUrl != null)
            CachedNetworkImage(
              imageUrl: post.imageUrl!,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => const AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => const AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(child: Icon(Icons.error)),
              ),
            ),

          // Activity reference if this post is about an activity
          if (post.additionalInfo != null &&
              post.additionalInfo!['activityId'] != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () =>
                    _navigateToActivity(post.additionalInfo!['activityId']),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.additionalInfo!['activityTitle'] ??
                                  'Weekend Activity',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (post.additionalInfo!['activityDate'] != null)
                              Text(
                                'Date: ${(post.additionalInfo!['activityDate'] as DateTime).toString().split(' ')[0]}',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                ),
              ),
            ),

          // Action buttons
          Row(
            children: [
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : null,
                ),
                onPressed: () => _handleLikePost(post.id, currentUser.uid),
              ),
              Text('${post.likes.length}'),
              IconButton(
                icon: const Icon(Icons.comment_outlined),
                onPressed: () => _showCommentSheet(post, currentUser),
              ),
              Text('${post.comments.length}'),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () => _handleSharePost(post, currentUser),
              ),
            ],
          ),

          // Comments preview
          if (post.comments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show the latest comment
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${post.comments.last.userName}: ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Text(post.comments.last.content),
                      ),
                    ],
                  ),

                  // Show view all comments if there are more
                  if (post.comments.length > 1)
                    TextButton(
                      onPressed: () => _showCommentSheet(post, currentUser),
                      child: Text(
                        'View all ${post.comments.length} comments',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(WeekendActivity activity, UserModel currentUser) {
    final bool isAttending = activity.attendees.contains(currentUser.uid);
    final bool isInterested =
        activity.interestedUsers.contains(currentUser.uid);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Activity header with creator info
          ListTile(
            leading: GestureDetector(
              onTap: () => _navigateToProfile(activity.creatorId),
              child: CircleAvatar(
                backgroundImage: activity.creatorPhotoUrl != null
                    ? CachedNetworkImageProvider(activity.creatorPhotoUrl!)
                    : null,
                child: activity.creatorPhotoUrl == null
                    ? const Icon(Icons.person)
                    : null,
              ),
            ),
            title: Row(
              children: [
                GestureDetector(
                  onTap: () => _navigateToProfile(activity.creatorId),
                  child: Text(
                    activity.creatorName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('created a new activity'),
              ],
            ),
            subtitle: Text(timeago.format(activity.createdAt)),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {},
            ),
          ),

          // Activity image if available
          if (activity.imageUrl != null)
            CachedNetworkImage(
              imageUrl: activity.imageUrl!,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => const AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => const AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(child: Icon(Icons.error)),
              ),
            ),

          // Activity details
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: () => _navigateToActivity(activity.id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.category, size: 16),
                      const SizedBox(width: 4),
                      Text(activity.eventType),
                      const SizedBox(width: 16),
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 4),
                      Text(activity.date.toString().split(' ')[0]),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          activity.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.people, size: 16),
                      const SizedBox(width: 4),
                      Text(
                          '${activity.currentAttendees}/${activity.capacity} attending'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    activity.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActivityButton(
                  icon: isAttending ? Icons.check : Icons.add,
                  label: isAttending ? 'Attending' : 'Join',
                  color: isAttending ? Colors.green : Colors.blue,
                  onTap: () =>
                      _handleJoinActivity(activity, currentUser, isAttending),
                ),
                _buildActivityButton(
                  icon: isInterested ? Icons.star : Icons.star_border,
                  label: isInterested ? 'Interested' : 'Interest',
                  color: isInterested ? Colors.amber : Colors.grey,
                  onTap: () => _handleInterestActivity(
                      activity, currentUser, isInterested),
                ),
                _buildActivityButton(
                  icon: Icons.share,
                  label: 'Share',
                  color: Colors.purple,
                  onTap: () => _handleShareActivity(activity, currentUser),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryPreviewCard(Story story, UserModel currentUser) {
    // Only show story previews for stories that reference activities
    if (story.metadata == null || !story.metadata!.containsKey('activityId')) {
      return const SizedBox.shrink();
    }

    final activityId = story.metadata!['activityId'] as String;
    final activityTitle =
        story.metadata!['activityTitle'] as String? ?? 'Weekend Activity';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Story header with user info
          ListTile(
            leading: GestureDetector(
              onTap: () => _navigateToProfile(story.userId),
              child: CircleAvatar(
                backgroundImage: story.userPhotoUrl != null
                    ? CachedNetworkImageProvider(story.userPhotoUrl!)
                    : null,
                child: story.userPhotoUrl == null
                    ? const Icon(Icons.person)
                    : null,
              ),
            ),
            title: Row(
              children: [
                GestureDetector(
                  onTap: () => _navigateToProfile(story.userId),
                  child: Text(
                    story.userName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('shared a story about an activity'),
              ],
            ),
            subtitle: Text(timeago.format(story.createdAt)),
          ),

          // Story preview
          GestureDetector(
            onTap: () => _navigateToStory(story),
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                image: story.mediaUrl != null
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(story.mediaUrl!),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.3),
                          BlendMode.darken,
                        ),
                      )
                    : null,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (story.text != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          story.text!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _navigateToActivity(activityId),
                      child: Text('View $activityTitle'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.remove_red_eye),
                label: const Text('View Story'),
                onPressed: () => _navigateToStory(story),
              ),
              TextButton.icon(
                icon: const Icon(Icons.event),
                label: const Text('View Activity'),
                onPressed: () => _navigateToActivity(activityId),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color),
            ),
          ],
        ),
      ),
    );
  }

  void _showPostOptions(Post post, UserModel currentUser) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share'),
                onTap: () {
                  Navigator.pop(context);
                  _handleSharePost(post, currentUser);
                },
              ),
              if (post.userId == currentUser.uid)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title:
                      const Text('Delete', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _feedService.deletePost(post.id);
                    _loadFeed();
                  },
                ),
              if (post.userId != currentUser.uid)
                ListTile(
                  leading: const Icon(Icons.report),
                  title: const Text('Report'),
                  onTap: () {
                    Navigator.pop(context);
                    // Show report dialog
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleLikePost(String postId, String userId) async {
    try {
      await _feedService.toggleLikePost(postId, userId);
      _loadFeed(); // Refresh feed to show updated like status
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error liking post: $e')),
        );
      }
    }
  }

  Future<void> _handleSharePost(Post post, UserModel currentUser) async {
    // Get user's friends to share with
    final friends =
        await _socialConnectionService.getUserFriends(currentUser.uid);

    if (friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have no friends to share with')),
      );
      return;
    }

    // Show dialog to select friends
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        List<String> selectedFriendIds = [];

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Share with friends'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    final isSelected = selectedFriendIds.contains(friend.uid);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            selectedFriendIds.add(friend.uid);
                          } else {
                            selectedFriendIds.remove(friend.uid);
                          }
                        });
                      },
                      title: Text(friend.name),
                      secondary: CircleAvatar(
                        backgroundImage: friend.photoUrl != null
                            ? CachedNetworkImageProvider(friend.photoUrl!)
                            : null,
                        child: friend.photoUrl == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedFriendIds.isEmpty) {
                      Navigator.pop(context);
                      return;
                    }

                    try {
                      await _feedService.sharePost(
                        post.id,
                        currentUser.uid,
                        selectedFriendIds,
                      );

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Post shared successfully!'),
                        ),
                      );
                    } catch (e) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to share: $e')),
                      );
                    }
                  },
                  child: const Text('Share'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCommentSheet(Post post, UserModel currentUser) {
    final TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Comments',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: post.comments.length,
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
                      title: Text(
                        comment.userName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(comment.content),
                      trailing: Text(
                        timeago.format(comment.timestamp),
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentController,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () async {
                      final commentText = commentController.text.trim();
                      if (commentText.isEmpty) return;

                      try {
                        await _feedService.addComment(
                          post.id,
                          currentUser.uid,
                          currentUser.name,
                          currentUser.photoUrl,
                          commentText,
                        );

                        commentController.clear();
                        _loadFeed(); // Refresh feed to show new comment
                        Navigator.pop(context);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error adding comment: $e')),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleInterestActivity(WeekendActivity activity,
      UserModel currentUser, bool isInterested) async {
    try {
      if (isInterested) {
        // Remove interest
        await _socialActivityService.removeInterestInActivity(
            activity.id, currentUser.uid);
      } else {
        // Add interest
        await _socialActivityService.showInterestInActivity(
            activity.id, currentUser.uid);
      }

      // Refresh the feed to show updated state
      _loadFeed();
    } catch (e) {
      // Handle any errors that occur during the interest process
      setState(() {
        _isError = true;
        _errorMessage =
            'Failed to ${isInterested ? "remove" : "show"} interest in activity: $e';
      });

      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $_errorMessage')),
      );
    }
  }

  Future<void> _handleShareActivity(
      WeekendActivity activity, UserModel currentUser) async {
    // Get user's friends to share with
    final friends =
        await _socialConnectionService.getUserFriends(currentUser.uid);

    if (friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have no friends to share with')),
      );
      return;
    }

    // Show dialog to select friends
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        List<String> selectedFriendIds = [];

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Share activity with friends'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    final isSelected = selectedFriendIds.contains(friend.uid);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            selectedFriendIds.add(friend.uid);
                          } else {
                            selectedFriendIds.remove(friend.uid);
                          }
                        });
                      },
                      title: Text(friend.name),
                      secondary: CircleAvatar(
                        backgroundImage: friend.photoUrl != null
                            ? CachedNetworkImageProvider(friend.photoUrl!)
                            : null,
                        child: friend.photoUrl == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedFriendIds.isEmpty) {
                      Navigator.pop(context);
                      return;
                    }

                    try {
                      await _socialActivityService.shareActivity(
                        activity.id,
                        currentUser.uid,
                        selectedFriendIds,
                      );

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Activity shared successfully!'),
                        ),
                      );
                    } catch (e) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to share: $e')),
                      );
                    }
                  },
                  child: const Text('Share'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _navigateToStory(Story story) {
    // Navigate to story viewer
    Navigator.pushNamed(context, '/story_viewer', arguments: story.id);
  }

  Future<void> _handleJoinActivity(
      WeekendActivity activity, UserModel currentUser, bool isAttending) async {
    try {
      if (isAttending) {
        // Leave the activity
        await _socialActivityService.leaveActivity(
            activity.id, currentUser.uid);
      } else {
        // Join the activity
        await _socialActivityService.joinActivity(activity.id, currentUser.uid);
      }

      // Refresh the feed to show updated state
      _loadFeed();
    } catch (e) {
      // Handle any errors that occur during the join/leave process
      setState(() {
        _isError = true;
        _errorMessage =
            'Failed to ${isAttending ? "leave" : "join"} activity: $e';
      });

      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $_errorMessage')),
      );
    }
  }

  void _showSuggestedUsersDialog(
      List<UserModel> suggestedUsers, String currentUserId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suggested Users to Follow'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: suggestedUsers.length,
            itemBuilder: (context, index) {
              final user = suggestedUsers[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: user.photoUrl != null
                      ? CachedNetworkImageProvider(user.photoUrl!)
                      : null,
                  child:
                      user.photoUrl == null ? const Icon(Icons.person) : null,
                ),
                title: Text(user.name),
                subtitle: Text(user.bio ?? ''),
                trailing: ElevatedButton(
                  onPressed: () {
                    _socialConnectionService.followUser(
                        currentUserId, user.uid);
                    Navigator.of(context).pop();
                    _loadFeed(); // Refresh feed after following
                  },
                  child: const Text('Follow'),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _navigateToProfile(String userId) {
    // Navigate to user profile
    Navigator.pushNamed(context, '/profile', arguments: userId);
  }

  void _navigateToActivity(String activityId) {
    // Fetch the activity data first
    _socialActivityService.getWeekendActivityById(activityId).then((activity) {
      if (activity != null && mounted) {
        // Navigate to the activity detail screen
        Navigator.pushNamed(
          context,
          '/weekend_activity_detail',
          arguments: activity,
        );
      }
    }).catchError((error) {
      // Show error if activity not found
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading activity: $error')),
        );
      }
    });
  }
}
