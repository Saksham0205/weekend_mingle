import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/story_model.dart';
import '../models/user_model.dart';
import '../services/story_service.dart';
import '../providers/user_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:percent_indicator/percent_indicator.dart';

class StoriesWidget extends StatefulWidget {
  const StoriesWidget({Key? key}) : super(key: key);

  @override
  State<StoriesWidget> createState() => _StoriesWidgetState();
}

class _StoriesWidgetState extends State<StoriesWidget> {
  final StoryService _storyService = StoryService();
  final _imagePicker = ImagePicker();
  bool _isCreatingStory = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<UserProvider>(context).user;
    if (currentUser == null) return const SizedBox.shrink();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Stories',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to all stories view
                  _showAllStoriesScreen();
                },
                child: const Text('See All'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 110,
          child: StreamBuilder<List<Story>>(
            stream: _storyService.getFriendsStories(currentUser.uid),
            builder: (context, friendStoriesSnapshot) {
              return StreamBuilder<List<Story>>(
                stream: _storyService.getUserStories(currentUser.uid),
                builder: (context, userStoriesSnapshot) {
                  if (friendStoriesSnapshot.connectionState == ConnectionState.waiting ||
                      userStoriesSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final List<Story> userStories = userStoriesSnapshot.data ?? [];
                  final List<Story> friendStories = friendStoriesSnapshot.data ?? [];

                  // Group stories by user
                  final Map<String, List<Story>> storiesByUser = {};

                  // Add current user's stories
                  if (userStories.isNotEmpty) {
                    storiesByUser[currentUser.uid] = userStories;
                  }

                  // Add friends' stories
                  for (final story in friendStories) {
                    if (!storiesByUser.containsKey(story.userId)) {
                      storiesByUser[story.userId] = [];
                    }
                    storiesByUser[story.userId]!.add(story);
                  }

                  // Sort by recency - newest stories first
                  final sortedUsers = storiesByUser.keys.toList()
                    ..sort((a, b) {
                      final aStories = storiesByUser[a]!;
                      final bStories = storiesByUser[b]!;
                      return bStories.first.createdAt.compareTo(aStories.first.createdAt);
                    });

                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: sortedUsers.length + 1, // +1 for create story
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // Create story item
                        return _buildCreateStoryItem(currentUser);
                      }

                      final userId = sortedUsers[index - 1];
                      final userStoryList = storiesByUser[userId]!;
                      final isCurrentUser = userId == currentUser.uid;

                      return _buildStoryItem(
                          userStoryList,
                          isCurrentUser ? currentUser : null
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
  }

  Widget _buildCreateStoryItem(UserModel currentUser) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 8),
      child: GestureDetector(
        onTap: _isCreatingStory ? null : _pickImage,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(35),
                  ),
                  child: _isCreatingStory
                      ? const Center(
                    child: CircularProgressIndicator(),
                  )
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(35),
                    child: currentUser.photoUrl != null
                        ? CachedNetworkImage(
                      imageUrl: currentUser.photoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) =>
                      const Icon(Icons.person),
                    )
                        : const Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Your Story',
              style: TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryItem(List<Story> stories, UserModel? user) {
    final story = stories.first; // Show the most recent story
    final hasMultipleStories = stories.length > 1;
    final hasViewed = story.hasViewed(Provider.of<UserProvider>(context).user!.uid);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: () {
          _showStoryView(stories);
        },
        child: Column(
          children: [
            Stack(
              children: [
                // Story ring indicator
                Container(
                  width: 74,
                  height: 74,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasViewed
                        ? null
                        : LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Colors.purple,
                        Colors.orange,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    color: hasViewed ? Colors.grey[300] : null,
                  ),
                  child: CircularPercentIndicator(
                    radius: 35,
                    lineWidth: 2,
                    percent: story.timeRemainingPercent / 100,
                    backgroundColor: Colors.transparent,
                    progressColor: hasViewed ? Colors.grey : Theme.of(context).primaryColor,
                    circularStrokeCap: CircularStrokeCap.round,
                    center: ClipRRect(
                      borderRadius: BorderRadius.circular(35),
                      child: CachedNetworkImage(
                        imageUrl: story.userPhotoUrl ?? (user?.photoUrl ?? ''),
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.person, color: Colors.grey),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.person, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
                if (hasMultipleStories)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        stories.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 70,
              child: Text(
                story.userName,
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final pickedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedImage != null) {
      _createStory(File(pickedImage.path));
    }
  }

  Future<void> _createStory(File imageFile) async {
    setState(() {
      _isCreatingStory = true;
    });

    try {
      await _storyService.createStory(
        mediaFile: imageFile,
        mediaType: 'image',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create story: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingStory = false;
        });
      }
    }
  }

  void _showStoryView(List<Story> stories) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoryViewScreen(stories: stories),
      ),
    );
  }

  void _showAllStoriesScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AllStoriesScreen(),
      ),
    );
  }
}

class StoryViewScreen extends StatefulWidget {
  final List<Story> stories;

  const StoryViewScreen({Key? key, required this.stories}) : super(key: key);

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  int _currentIndex = 0;
  final StoryService _storyService = StoryService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    // Mark as viewed and start animation
    _loadStory();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _loadStory() {
    // Mark current story as viewed
    final currentUserId = Provider.of<UserProvider>(context, listen: false).user!.uid;
    _storyService.viewStory(widget.stories[_currentIndex].id);

    // Start the animation
    _animationController.forward(from: 0.0);
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _loadStory();
    } else {
      // No more stories, close the view
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _loadStory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];
    final mediaType = story.mediaType;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          final tapPosition = details.globalPosition.dx;

          // Tap on left third of screen goes to previous story
          if (tapPosition < screenWidth / 3) {
            _previousStory();
          }
          // Tap on right third of screen goes to next story
          else if (tapPosition > 2 * screenWidth / 3) {
            _nextStory();
          }
          // Tap in middle pauses/resumes the animation
          else {
            if (_animationController.isAnimating) {
              _animationController.stop();
            } else {
              _animationController.forward();
            }
          }
        },
        child: Stack(
          children: [
            // Story progress indicator
            Positioned(
              top: MediaQuery.of(context).padding.top,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: List.generate(
                    widget.stories.length,
                        (index) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: LinearProgressIndicator(
                          value: index < _currentIndex
                              ? 1.0
                              : index == _currentIndex
                              ? _animationController.value
                              : 0.0,
                          backgroundColor: Colors.grey.withOpacity(0.5),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Story content
            Center(
              child: mediaType == 'image' && story.mediaUrl != null
                  ? CachedNetworkImage(
                imageUrl: story.mediaUrl!,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.error, color: Colors.white),
                ),
              )
                  : mediaType == 'text'
                  ? Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      Colors.purple,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    story.text ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
                  : const Center(
                child: Text(
                  'Unsupported media type',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),

            // User info at top
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: story.userPhotoUrl != null
                        ? CachedNetworkImageProvider(story.userPhotoUrl!)
                        : null,
                    child: story.userPhotoUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        story.userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getTimeAgo(story.createdAt),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final Duration difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 0) {
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

class AllStoriesScreen extends StatelessWidget {
  const AllStoriesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<UserProvider>(context).user!.uid;
    final storyService = StoryService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Stories'),
      ),
      body: StreamBuilder<List<Story>>(
        stream: storyService.getFriendsStories(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No stories available'),
            );
          }

          // Group stories by user
          final Map<String, List<Story>> storiesByUser = {};
          for (final story in snapshot.data!) {
            if (!storiesByUser.containsKey(story.userId)) {
              storiesByUser[story.userId] = [];
            }
            storiesByUser[story.userId]!.add(story);
          }

          // Sort users by most recent story
          final sortedUsers = storiesByUser.keys.toList()
            ..sort((a, b) {
              final aStories = storiesByUser[a]!;
              final bStories = storiesByUser[b]!;
              return bStories.first.createdAt.compareTo(aStories.first.createdAt);
            });

          return ListView.builder(
            itemCount: sortedUsers.length,
            itemBuilder: (context, index) {
              final userId = sortedUsers[index];
              final userStories = storiesByUser[userId]!;
              final story = userStories.first; // Use the most recent story for display

              return ListTile(
                leading: Container(
                  width: 56,
                  height: 56,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Colors.purple,
                        Colors.orange,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundImage: story.userPhotoUrl != null
                        ? CachedNetworkImageProvider(story.userPhotoUrl!)
                        : null,
                    child: story.userPhotoUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                ),
                title: Text(story.userName),
                subtitle: Text(
                  '${userStories.length} stories · ${_getTimeAgo(story.createdAt)}',
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StoryViewScreen(stories: userStories),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final Duration difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 0) {
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