import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../widgets/social_feed_widget.dart';
import '../widgets/enhanced_reels_widget.dart';
import '../widgets/stories_widget.dart';
import '../services/social_connection_service.dart';
import '../services/feed_service.dart';
import '../services/reel_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

class SocialTab extends StatefulWidget {
  const SocialTab({Key? key}) : super(key: key);

  @override
  State<SocialTab> createState() => _SocialTabState();
}

class _SocialTabState extends State<SocialTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SocialConnectionService _socialService = SocialConnectionService();
  final FeedService _feedService = FeedService();
  final ReelService _reelService = ReelService();
  final ImagePicker _imagePicker = ImagePicker();

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

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<UserProvider>(context).user;
    if (currentUser == null) {
      return const Center(child: Text('Please log in to view social content'));
    }

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Social', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.message_outlined),
            onPressed: () => Navigator.pushNamed(context, '/chats'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Feed'),
            Tab(text: 'Reels'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // Feed Tab
          SocialFeedWidget(),

          // Reels Tab
          EnhancedReelsWidget(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateOptions,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.post_add),
                title: const Text('Create Post'),
                onTap: () {
                  Navigator.pop(context);
                  _createPost();
                },
              ),
              ListTile(
                leading: const Icon(Icons.movie),
                title: const Text('Create Reel'),
                onTap: () {
                  Navigator.pop(context);
                  _createReel();
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_photo_alternate),
                title: const Text('Create Story'),
                onTap: () {
                  Navigator.pop(context);
                  _createStory();
                },
              ),
              ListTile(
                leading: const Icon(Icons.event),
                title: const Text('Create Weekend Activity'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/create_weekend_activity');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createPost() async {
    final currentUser = Provider.of<UserProvider>(context, listen: false).user;
    if (currentUser == null) return;

    // Options for post creation
    final ImageSource? source = await _showImageSourceDialog();
    if (source == null) return;

    try {
      final XFile? imageFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (imageFile == null) return;

      // Show post creation dialog
      final TextEditingController contentController = TextEditingController();
      final bool? result = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Create Post'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.file(
                  File(imageFile.path),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(
                    hintText: 'Write a caption...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Post'),
              ),
            ],
          );
        },
      );

      if (result == true) {
        // Create the post
        final postId = await _feedService.createPost(
          content: contentController.text,
          imageFile: File(imageFile.path),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating post: $e')),
      );
    }
  }

  Future<void> _createReel() async {
    final currentUser = Provider.of<UserProvider>(context, listen: false).user;
    if (currentUser == null) return;

    try {
      final XFile? videoFile = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );

      if (videoFile == null) return;

      // Show video preview and caption input
      final TextEditingController captionController = TextEditingController();
      final TextEditingController hashtagsController = TextEditingController();

      // Create video controller for preview
      final videoController = VideoPlayerController.file(File(videoFile.path));
      await videoController.initialize();
      videoController.setLooping(true);
      videoController.play();

      final bool? result = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Create Reel'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: videoController.value.aspectRatio,
                    child: VideoPlayer(videoController),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: captionController,
                    decoration: const InputDecoration(
                      hintText: 'Write a caption...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: hashtagsController,
                    decoration: const InputDecoration(
                      hintText: 'Add hashtags (comma separated)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  videoController.dispose();
                  Navigator.pop(context, false);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  videoController.dispose();
                  Navigator.pop(context, true);
                },
                child: const Text('Post'),
              ),
            ],
          );
        },
      );

      if (result == true) {
        // Process hashtags
        final List<String> hashtags = hashtagsController.text
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList();

        // Create the reel
        final reel = await _reelService.createReel(
          videoFile: File(videoFile.path),
          caption: captionController.text,
          hashtags: hashtags,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reel created successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating reel: $e')),
      );
    }
  }

  Future<void> _createStory() async {
    // Navigate to the story creation screen
    Navigator.pushNamed(context, '/create_story');
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
  }
}
