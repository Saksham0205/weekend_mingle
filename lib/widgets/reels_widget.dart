import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/story_model.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../services/story_service.dart';

class ReelsWidget extends StatefulWidget {
  const ReelsWidget({Key? key}) : super(key: key);

  @override
  State<ReelsWidget> createState() => _ReelsWidgetState();
}

class _ReelsWidgetState extends State<ReelsWidget> {
  final StoryService _storyService = StoryService();
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<UserProvider>(context).user;
    if (currentUser == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<List<Story>>(
        stream: _storyService.getFollowingReels(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final reels = snapshot.data ?? [];
          if (reels.isEmpty) {
            return const Center(
              child: Text(
                'No reels available. Follow more users to see their reels!',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            );
          }

          return Stack(
            children: [
              // Reels PageView
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: reels.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                  // Mark as viewed
                  _storyService.markStoryAsViewed(reels[index].id);
                },
                itemBuilder: (context, index) {
                  final reel = reels[index];
                  return _ReelItem(
                    reel: reel,
                    storyService: _storyService,
                    currentUserId: currentUser.uid,
                  );
                },
              ),

              // Top navigation
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Reels',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.camera_alt, color: Colors.white),
                        onPressed: () {
                          // Navigate to create reel screen
                          _showCreateReelOptions();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCreateReelOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.video_library, color: Colors.white),
                title: Text('Upload from Gallery',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  // Implement upload from gallery
                  // This would typically use image_picker to select a video
                },
              ),
              ListTile(
                leading: Icon(Icons.videocam, color: Colors.white),
                title: Text('Record New Reel',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  // Implement record new reel
                  // This would typically navigate to a camera screen
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReelItem extends StatefulWidget {
  final Story reel;
  final StoryService storyService;
  final String currentUserId;

  const _ReelItem({
    Key? key,
    required this.reel,
    required this.storyService,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> {
  late VideoPlayerController _videoController;
  bool _isInitialized = false;
  bool _isPlaying = true;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _checkIfLiked();
  }

  void _initializeVideo() {
    if (widget.reel.mediaUrl != null) {
      _videoController = VideoPlayerController.network(widget.reel.mediaUrl!)
        ..initialize().then((_) {
          setState(() {
            _isInitialized = true;
          });
          _videoController.play();
          _videoController.setLooping(true);
        });
    }
  }

  void _checkIfLiked() {
    final likes = widget.reel.metadata?['likes'] as List? ?? [];
    setState(() {
      _isLiked = likes.contains(widget.currentUserId);
    });
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _videoController.dispose();
    }
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _videoController.play();
      } else {
        _videoController.pause();
      }
    });
  }

  void _toggleLike() async {
    try {
      await widget.storyService.likeReel(widget.reel.id);
      setState(() {
        _isLiked = !_isLiked;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showComments() {
    final comments = widget.reel.metadata?['comments'] as List? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Comments',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: comments.isEmpty
                      ? Center(
                          child: Text('No comments yet',
                              style: TextStyle(color: Colors.white)))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            final comment = comments[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: comment['userPhotoUrl'] != null
                                    ? CachedNetworkImageProvider(
                                        comment['userPhotoUrl'])
                                    : null,
                                child: comment['userPhotoUrl'] == null
                                    ? Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(
                                comment['userName'] ?? 'User',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                comment['comment'] ?? '',
                                style: TextStyle(color: Colors.white70),
                              ),
                              trailing: Text(
                                timeago.format(comment['timestamp'].toDate()),
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 12),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    left: 8,
                    right: 8,
                    top: 8,
                  ),
                  child: _CommentInput(
                      reelId: widget.reel.id,
                      storyService: widget.storyService),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _shareReel() {
    // Implement share functionality
    // This would typically show a list of friends to share with
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video player
          if (_isInitialized)
            VideoPlayer(_videoController)
          else
            Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Play/pause indicator (shows briefly when tapped)
          if (!_isPlaying)
            Center(
              child: Icon(
                Icons.play_arrow,
                color: Colors.white.withOpacity(0.7),
                size: 80,
              ),
            ),

          // User info and caption
          Positioned(
            left: 16,
            bottom: 120,
            right: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: widget.reel.userPhotoUrl != null
                          ? CachedNetworkImageProvider(
                              widget.reel.userPhotoUrl!)
                          : null,
                      child: widget.reel.userPhotoUrl == null
                          ? Icon(Icons.person, size: 16)
                          : null,
                    ),
                    SizedBox(width: 8),
                    Text(
                      widget.reel.userName,
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (widget.reel.text != null && widget.reel.text!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      widget.reel.text!,
                      style: TextStyle(color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                // Hashtags
                if (widget.reel.metadata?['hashtags'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      (widget.reel.metadata!['hashtags'] as List)
                          .map((tag) => '#$tag')
                          .join(' '),
                      style: TextStyle(color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),

          // Action buttons
          Positioned(
            right: 16,
            bottom: 120,
            child: Column(
              children: [
                // Like button
                IconButton(
                  icon: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? Colors.red : Colors.white,
                    size: 30,
                  ),
                  onPressed: _toggleLike,
                ),
                Text(
                  '${(widget.reel.metadata?['likes'] as List?)?.length ?? 0}',
                  style: TextStyle(color: Colors.white),
                ),
                SizedBox(height: 16),
                // Comment button
                IconButton(
                  icon: Icon(Icons.comment, color: Colors.white, size: 30),
                  onPressed: _showComments,
                ),
                Text(
                  '${(widget.reel.metadata?['comments'] as List?)?.length ?? 0}',
                  style: TextStyle(color: Colors.white),
                ),
                SizedBox(height: 16),
                // Share button
                IconButton(
                  icon: Icon(Icons.share, color: Colors.white, size: 30),
                  onPressed: _shareReel,
                ),
                Text(
                  '${widget.reel.metadata?['shares'] ?? 0}',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentInput extends StatefulWidget {
  final String reelId;
  final StoryService storyService;

  const _CommentInput({
    Key? key,
    required this.reelId,
    required this.storyService,
  }) : super(key: key);

  @override
  State<_CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<_CommentInput> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.storyService.commentOnReel(widget.reelId, comment);
      _commentController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _commentController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Add a comment...',
              hintStyle: TextStyle(color: Colors.white54),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white24,
              contentPadding: EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
        SizedBox(width: 8),
        _isSubmitting
            ? CircularProgressIndicator(color: Colors.white)
            : IconButton(
                icon: Icon(Icons.send, color: Colors.white),
                onPressed: _submitComment,
              ),
      ],
    );
  }
}
