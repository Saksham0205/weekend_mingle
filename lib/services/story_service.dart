import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/story_model.dart';
import '../models/user_model.dart';
import 'dart:io';
import 'dart:async';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'cloudinary_services.dart';

// Media type constants
const String TYPE_IMAGE = 'image';
const String TYPE_VIDEO = 'video';
const String TYPE_TEXT = 'text';
const String TYPE_REEL = 'reel';

class StoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CloudinaryService _cloudinaryService = CloudinaryService();

  // Get active stories from friends
  Stream<List<Story>> getFriendsStories(String userId) {
    // Get current timestamp
    final now = DateTime.now();

    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((userDoc) async {
      final userData = UserModel.fromDocumentSnapshot(userDoc);
      final friendIds = userData.friends;

      if (friendIds.isEmpty) {
        return <Story>[];
      }

      // Query stories from friends that haven't expired
      final storyDocs = await _firestore
          .collection('stories')
          .where('userId', whereIn: friendIds)
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('expiresAt', descending: false)
          .get();

      return storyDocs.docs.map((doc) => Story.fromFirestore(doc)).toList();
    });
  }

  // Get current user's active stories
  Stream<List<Story>> getUserStories(String userId) {
    // Get current timestamp
    final now = DateTime.now();

    return _firestore
        .collection('stories')
        .where('userId', isEqualTo: userId)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('expiresAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Story.fromFirestore(doc)).toList();
    });
  }

  // Create a new story
  Future<Story> createStory({
    required File? mediaFile,
    String? text,
    required String mediaType,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    // Get user data
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = UserModel.fromDocumentSnapshot(userDoc);

    // Upload media to Cloudinary if provided
    String? mediaUrl;
    String? thumbnailUrl;

    if (mediaFile != null) {
      try {
        // For video content, generate a thumbnail
        if (mediaType == TYPE_VIDEO || mediaType == TYPE_REEL) {
          final thumbnailPath = await VideoThumbnail.thumbnailFile(
            video: mediaFile.path,
            imageFormat: ImageFormat.JPEG,
            quality: 75,
          );

          if (thumbnailPath != null) {
            thumbnailUrl =
                await CloudinaryService.uploadImage(File(thumbnailPath));
          }
        }

        // Upload the main media file
        mediaUrl = await CloudinaryService.uploadImage(mediaFile);
        if (mediaUrl == null) {
          throw Exception("Failed to upload media: No URL returned");
        }
      } catch (e) {
        throw Exception("Failed to upload media: $e");
      }
    }

    // Calculate expiration (24 hours for regular stories, 7 days for reels)
    final now = DateTime.now();
    final expiresAt = mediaType == TYPE_REEL
        ? now.add(const Duration(days: 7))
        : now.add(const Duration(hours: 24));

    // Create story
    final storyRef = _firestore.collection('stories').doc();
    final story = Story(
      id: storyRef.id,
      userId: user.uid,
      userName: userData.name,
      userPhotoUrl: userData.photoUrl,
      mediaUrl: mediaUrl,
      text: text,
      mediaType: mediaType,
      createdAt: now,
      expiresAt: expiresAt,
      viewers: [],
      metadata: {
        'thumbnailUrl': thumbnailUrl,
        'location': userData.locationName,
        ...?metadata,
      },
    );

    await storyRef.set(story.toMap());
    return story;
  }

  // Mark a story as viewed by current user
  Future<void> viewStory(String storyId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('stories').doc(storyId).update({
      'viewers': FieldValue.arrayUnion([user.uid]),
    });
  }

  // Mark a story as viewed by the current user
  Future<void> markStoryAsViewed(String storyId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    await _firestore.collection('stories').doc(storyId).update({
      'viewers': FieldValue.arrayUnion([user.uid]),
    });
  }

  // Delete a story
  Future<void> deleteStory(String storyId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    final storyDoc = await _firestore.collection('stories').doc(storyId).get();
    if (!storyDoc.exists) throw Exception("Story not found");

    final storyData = storyDoc.data() as Map<String, dynamic>;
    if (storyData['userId'] != user.uid) {
      throw Exception("You can only delete your own stories");
    }

    await _firestore.collection('stories').doc(storyId).delete();
  }

  // Get trending reels (most viewed or liked reels)
  Future<List<Story>> getTrendingReels({int limit = 20}) async {
    final now = DateTime.now();

    // Get reels that haven't expired and have the most views
    final reelsSnapshot = await _firestore
        .collection('stories')
        .where('mediaType', isEqualTo: TYPE_REEL)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('expiresAt', descending: false)
        .get();

    final reels =
        reelsSnapshot.docs.map((doc) => Story.fromFirestore(doc)).toList();

    // Sort by popularity (number of viewers + likes)
    reels.sort((a, b) {
      final aPopularity =
          a.viewers.length + (a.metadata?['likes']?.length ?? 0);
      final bPopularity =
          b.viewers.length + (b.metadata?['likes']?.length ?? 0);
      return bPopularity.compareTo(aPopularity); // Descending order
    });

    return reels.take(limit).toList();
  }

  // Like a reel
  Future<void> likeReel(String reelId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    final reelRef = _firestore.collection('stories').doc(reelId);
    final reelDoc = await reelRef.get();

    if (!reelDoc.exists) throw Exception("Reel not found");

    final reelData = reelDoc.data() as Map<String, dynamic>;
    if (reelData['mediaType'] != TYPE_REEL) {
      throw Exception("This is not a reel");
    }

    // Update likes in metadata
    final metadata = reelData['metadata'] as Map<String, dynamic>? ?? {};
    final likes = List<String>.from(metadata['likes'] ?? []);

    if (likes.contains(user.uid)) {
      // Unlike if already liked
      likes.remove(user.uid);
    } else {
      // Like if not already liked
      likes.add(user.uid);
    }

    metadata['likes'] = likes;

    await reelRef.update({
      'metadata': metadata,
    });
  }

  // Comment on a reel
  Future<void> commentOnReel(String reelId, String comment) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    // Get user data
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = UserModel.fromDocumentSnapshot(userDoc);

    final reelRef = _firestore.collection('stories').doc(reelId);
    final reelDoc = await reelRef.get();

    if (!reelDoc.exists) throw Exception("Reel not found");

    final reelData = reelDoc.data() as Map<String, dynamic>;
    if (reelData['mediaType'] != TYPE_REEL) {
      throw Exception("This is not a reel");
    }

    // Update comments in metadata
    final metadata = reelData['metadata'] as Map<String, dynamic>? ?? {};
    final comments =
        List<Map<String, dynamic>>.from(metadata['comments'] ?? []);

    comments.add({
      'userId': user.uid,
      'userName': userData.name,
      'userPhotoUrl': userData.photoUrl,
      'comment': comment,
      'timestamp': Timestamp.now(),
    });

    metadata['comments'] = comments;

    await reelRef.update({
      'metadata': metadata,
    });
  }

  // Share a reel with friends
  Future<void> shareReel(String reelId, List<String> friendIds) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    final reelDoc = await _firestore.collection('stories').doc(reelId).get();
    if (!reelDoc.exists) throw Exception("Reel not found");

    final reelData = reelDoc.data() as Map<String, dynamic>;
    if (reelData['mediaType'] != TYPE_REEL) {
      throw Exception("This is not a reel");
    }

    // Get user data
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = UserModel.fromDocumentSnapshot(userDoc);

    // Create a notification for each friend
    final batch = _firestore.batch();

    for (final friendId in friendIds) {
      final notificationRef = _firestore.collection('notifications').doc();
      batch.set(notificationRef, {
        'userId': friendId,
        'senderId': user.uid,
        'senderName': userData.name,
        'senderPhotoUrl': userData.photoUrl,
        'type': 'reel_share',
        'reelId': reelId,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // Get reels from followed users
  Stream<List<Story>> getFollowingReels(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((userDoc) async {
      final userData = UserModel.fromDocumentSnapshot(userDoc);
      final following = userData.following ?? [];

      if (following.isEmpty) {
        return <Story>[];
      }

      // Get current timestamp
      final now = DateTime.now();

      // Query reels from followed users that haven't expired
      // Note: Firestore has a limit of 10 IDs in a whereIn query
      final List<Story> reels = [];

      for (int i = 0; i < following.length; i += 10) {
        final end = (i + 10 < following.length) ? i + 10 : following.length;
        final batch = following.sublist(i, end);

        final reelDocs = await _firestore
            .collection('stories')
            .where('userId', whereIn: batch)
            .where('mediaType', isEqualTo: TYPE_REEL)
            .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
            .orderBy('expiresAt', descending: false)
            .get();

        reels.addAll(
            reelDocs.docs.map((doc) => Story.fromFirestore(doc)).toList());
      }

      // Sort by recency (newest first)
      reels.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return reels;
    });
  }

  // Create a reel (specialized story with longer expiration and additional metadata)
  Future<Story> createReel({
    required File videoFile,
    String? caption,
    List<String>? hashtags,
    String? location,
  }) async {
    // Validate that the file is a video
    // This would typically involve checking the file extension or mime type

    // Create a story with TYPE_REEL media type
    return createStory(
      mediaFile: videoFile,
      text: caption,
      mediaType: TYPE_REEL,
      metadata: {
        'hashtags': hashtags ?? [],
        'likes': [],
        'comments': [],
        'shares': 0,
        'location': location,
      },
    );
  }

  // Create a text-only story
  Future<Story> createTextStory({
    required String text,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    // Get user data
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = UserModel.fromDocumentSnapshot(userDoc);

    // Calculate expiration (24 hours for regular stories)
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));

    // Create story
    final storyRef = _firestore.collection('stories').doc();
    final story = Story(
      id: storyRef.id,
      userId: user.uid,
      userName: userData.name,
      userPhotoUrl: userData.photoUrl,
      mediaUrl: null,
      text: text,
      mediaType: TYPE_TEXT,
      createdAt: now,
      expiresAt: expiresAt,
      viewers: [],
      metadata: {
        'location': userData.locationName,
        ...?metadata,
      },
    );

    await storyRef.set(story.toMap());
    return story;
  }

  // Get all unviewed stories
  Stream<List<Story>> getUnviewedStories(String userId) {
    // Get current timestamp
    final now = DateTime.now();

    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((userDoc) async {
      final userData = UserModel.fromDocumentSnapshot(userDoc);
      final friendIds = userData.friends;

      if (friendIds.isEmpty) {
        return <Story>[];
      }

      // Query stories from friends that haven't expired and haven't been viewed
      final storyDocs = await _firestore
          .collection('stories')
          .where('userId', whereIn: friendIds)
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
          .where('viewers', arrayContains: userId)
          .orderBy('expiresAt', descending: false)
          .get();

      return storyDocs.docs.map((doc) => Story.fromFirestore(doc)).toList();
    });
  }
}
