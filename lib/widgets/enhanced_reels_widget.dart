import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:visibility_detector/visibility_detector.dart';
import 'package:share_plus/share_plus.dart';
import '../models/story_model.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../services/reel_service.dart';
import '../services/social_connection_service.dart';
import 'dart:async';

class EnhancedReelsWidget extends StatefulWidget {
  final bool showTrending;

  const EnhancedReelsWidget({
    Key? key,
    this.showTrending = false,
  }) : super(key: key);

  @override
  State<EnhancedReelsWidget> createState() => _EnhancedReelsWidgetState();
}

class _EnhancedReelsWidgetState extends State<EnhancedReelsWidget> {
  final ReelService _reelService = ReelService();
  final SocialConnectionService _socialService = SocialConnectionService();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<Story> _reels = [];
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadReels();
  }

  Future<void> _loadReels() async {
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

      List<Story> reels;
      if (widget.showTrending) {
        // Get trending reels
        reels = await _reelService.getTrendingReels();
      } else {
        // Get reels from followed users
        reels = await _reelService.getFollowingReels(currentUser.uid).first;
      }

      setState(() {
        _reels = reels;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isError = true;
        _errorMessage = 'Failed to load reels: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<UserProvider>(context).user;
    if (currentUser == null) return const SizedBox.shrink();

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
              onPressed: _loadReels,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_reels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No reels available',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Follow more users or check back later',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadReels,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
          // Mark as viewed when scrolled to
          if (index < _reels.length) {
            _reelService.markReelAsViewed(_reels[index].id, currentUser.uid);
          }
        },
        itemCount: _reels.length,
        itemBuilder: (context, index) {
          return ReelItem(
            reel: _reels[index],
            currentUserId: currentUser.uid,
            isActive: _currentPage == index,
            onLike: () => _handleLike(_reels[index].id, currentUser.uid),
            onComment: () => _showCommentSheet(_reels[index]),
            onShare: () => _handleShare(_reels[index]),
            onProfileTap: () => _navigateToProfile(_reels[index].userId),
          );
        },
      ),
    );
  }

  Future<void> _handleLike(String reelId, String userId) async {
    try {
      await _reelService.likeReel(reelId, userId);
      // Refresh the current reel to update UI
      _loadReels();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to like: $e')),
      );
    }
  }

  void _showCommentSheet(Story reel) {
    final currentUser = Provider.of<UserProvider>(context, listen: false).user;
    if (currentUser == null) return;

    final comments = (reel.metadata?['comments'] as List?) ?? [];
    final TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(comment['userName'] ?? 'Anonymous'),
                          subtitle: Text(comment['text'] ?? ''),
                          trailing: Text(
                            timeago.format(
                              (comment['timestamp'] as Timestamp).toDate(),
                            ),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: commentController,
                          decoration: const InputDecoration(
                            hintText: 'Add a comment...',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () async {
                          if (commentController.text.trim().isEmpty) return;

                          try {
                            await _reelService.commentOnReel(
                              reel.id,
                              currentUser.uid,
                              currentUser.name,
                              currentUser.photoUrl ?? '',
                              commentController.text.trim(),
                            );

                            // Clear input and refresh comments
                            commentController.clear();
                            Navigator.pop(context);
                            _loadReels();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to comment: $e')),
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
      },
    );
  }

  Future<void> _handleShare(Story reel) async {
    final currentUser = Provider.of<UserProvider>(context, listen: false).user;
    if (currentUser == null) return;

    // Get user's friends for sharing
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final userData = UserModel.fromDocumentSnapshot(userDoc);
    final friendIds = userData.friends;

    if (friendIds.isEmpty) {
      // No friends to share with, use system share
      Share.share(
        'Check out this amazing reel on Weekend Mingle!',
        subject: 'Weekend Mingle Reel',
      );
      return;
    }

    // Get friend user data
    final friendDocs = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: friendIds)
        .get();

    final friends = friendDocs.docs
        .map((doc) => UserModel.fromDocumentSnapshot(doc))
        .toList();

    // Show friend selection dialog
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
                      await _reelService.shareReel(
                        reel.id,
                        currentUser.uid,
                        selectedFriendIds,
                      );

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Reel shared successfully!'),
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

  void _navigateToProfile(String userId) {
    // Navigate to user profile
    Navigator.pushNamed(context, '/profile', arguments: userId);
  }
}

class ReelItem extends StatefulWidget {
  final Story reel;
  final String currentUserId;
  final bool isActive;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onProfileTap;

  const ReelItem({
    Key? key,
    required this.reel,
    required this.currentUserId,
    required this.isActive,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onProfileTap,
  }) : super(key: key);

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isLiked = false;
  int _likeCount = 0;
  int _commentCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _updateLikeStatus();
  }

  @override
  void didUpdateWidget(ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _playVideo();
      } else {
        _pauseVideo();
      }
    }
    if (oldWidget.reel.id != widget.reel.id) {
      _disposeVideo();
      _initializeVideo();
      _updateLikeStatus();
    }
  }

  void _updateLikeStatus() {
    final likes = List<String>.from(widget.reel.metadata?['likes'] ?? []);
    final comments =
        List<dynamic>.from(widget.reel.metadata?['comments'] ?? []);

    setState(() {
      _isLiked = likes.contains(widget.currentUserId);
      _likeCount = likes.length;
      _commentCount = comments.length;
    });
  }

  Future<void> _initializeVideo() async {
    if (widget.reel.mediaUrl == null) return;

    _videoController = VideoPlayerController.network(widget.reel.mediaUrl!);

    try {
      await _videoController!.initialize();
      _videoController!.setLooping(true);

      if (widget.isActive) {
        _playVideo();
      }

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Error initializing video: $e');
    }
  }

  void _playVideo() {
    if (_videoController != null && _isInitialized) {
      _videoController!.play();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  void _pauseVideo() {
    if (_videoController != null && _isInitialized) {
      _videoController!.pause();
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _pauseVideo();
    } else {
      _playVideo();
    }
  }

  void _disposeVideo() {
    if (_videoController != null) {
      _videoController!.dispose();
      _videoController = null;
      _isInitialized = false;
      _isPlaying = false;
    }
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('reel-${widget.reel.id}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction < 0.5 && _isPlaying) {
          _pauseVideo();
        } else if (info.visibleFraction > 0.5 &&
            !_isPlaying &&
            widget.isActive) {
          _playVideo();
        }
      },
      child: GestureDetector(
        onTap: _togglePlayPause,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video or thumbnail
            _buildMediaContent(),

            // Overlay gradient for better text visibility
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.2),
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.4),
                  ],
                ),
              ),
            ),

            // Play/pause indicator
            if (!_isPlaying && _isInitialized)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),

            // User info and caption
            Positioned(
              left: 16,
              right: 70,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User info
                  GestureDetector(
                    onTap: widget.onProfileTap,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: widget.reel.userPhotoUrl != null
                              ? CachedNetworkImageProvider(
                                  widget.reel.userPhotoUrl!)
                              : null,
                          child: widget.reel.userPhotoUrl == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.reel.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Follow',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Caption
                  if (widget.reel.text != null)
                    Text(
                      widget.reel.text!,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  // Hashtags
                  if (widget.reel.metadata != null &&
                      widget.reel.metadata!['hashtags'] != null)
                    Wrap(
                      spacing: 4,
                      children: (widget.reel.metadata!['hashtags'] as List)
                          .map((tag) => Text(
                                '#$tag',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ))
                          .toList(),
                    ),
                ],
              ),
            ),

            // Action buttons
            Positioned(
              right: 16,
              bottom: 16,
              child: Column(
                children: [
                  // Like button
                  _buildActionButton(
                    icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? Colors.red : Colors.white,
                    count: _likeCount,
                    onTap: widget.onLike,
                  ),
                  const SizedBox(height: 16),

                  // Comment button
                  _buildActionButton(
                    icon: Icons.comment,
                    count: _commentCount,
                    onTap: widget.onComment,
                  ),
                  const SizedBox(height: 16),

                  // Share button
                  _buildActionButton(
                    icon: Icons.share,
                    onTap: widget.onShare,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent() {
    if (widget.reel.mediaType == TYPE_REEL ||
        widget.reel.mediaType == TYPE_VIDEO) {
      if (_isInitialized && _videoController != null) {
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        );
      } else {
        // Show thumbnail while video is loading
        if (widget.reel.metadata != null &&
            widget.reel.metadata!['thumbnailUrl'] != null) {
          return CachedNetworkImage(
            imageUrl: widget.reel.metadata!['thumbnailUrl'],
            fit: BoxFit.cover,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(),
            ),
            errorWidget: (context, url, error) => const Center(
              child: Icon(Icons.error),
            ),
          );
        }
      }
    } else if (widget.reel.mediaType == TYPE_IMAGE &&
        widget.reel.mediaUrl != null) {
      return CachedNetworkImage(
        imageUrl: widget.reel.mediaUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) => const Center(
          child: Icon(Icons.error),
        ),
      );
    }

    // Fallback for text-only stories or loading state
    return Container(
      color: Colors.black,
      child: Center(
        child: widget.reel.text != null
            ? Text(
                widget.reel.text!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              )
            : const CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    Color color = Colors.white,
    int? count,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon),
          color: color,
          onPressed: onTap,
        ),
        if (count != null)
          Text(
            count.toString(),
            style: const TextStyle(color: Colors.white),
          ),
      ],
    );
  }
}
