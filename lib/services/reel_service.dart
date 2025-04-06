import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/story_model.dart';
import '../models/user_model.dart';
import 'dart:io';
import 'dart:async';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'cloudinary_services.dart';
import 'story_service.dart';

class ReelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final StoryService _storyService = StoryService();

  // Create a new reel (extended story with longer expiration)
  Future<Story> createReel({
    required File videoFile,
    String? caption,
    List<String>? hashtags,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    // Get user data
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = UserModel.fromDocumentSnapshot(userDoc);

    // Upload video to Cloudinary
    String? videoUrl;
    String? thumbnailUrl;

    try {
      // Generate thumbnail
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
      );

      if (thumbnailPath != null) {
        thumbnailUrl = await CloudinaryService.uploadImage(File(thumbnailPath));
      }

      // Upload the video
      videoUrl = await CloudinaryService.uploadVideo(videoFile);

      // Prepare metadata
      final metadata = {
        'caption': caption,
        'hashtags': hashtags ?? [],
        'likes': [],
        'comments': [],
        'shares': 0,
        'thumbnailUrl': thumbnailUrl,
        ...?additionalMetadata,
      };

      // Create the reel with 7-day expiration
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(days: 7));

      return await _storyService.createStory(
        mediaFile: videoFile,
        text: caption,
        mediaType: TYPE_REEL,
        metadata: metadata,
      );
    } catch (e) {
      throw Exception("Failed to create reel: $e");
    }
  }

  // Get reels from users the current user follows
  Stream<List<Story>> getFollowingReels(String userId) {
    // Get current timestamp
    final now = DateTime.now();

    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((userDoc) async {
      final userData = UserModel.fromDocumentSnapshot(userDoc);
      final followingIds = userData.following ?? [];
      final friendIds = userData.friends;

      // Combine friends and following for a complete social graph
      final socialIds = {...followingIds, ...friendIds}.toList();

      if (socialIds.isEmpty) {
        return <Story>[];
      }

      // Query reels from social connections that haven't expired
      final reelDocs = await _firestore
          .collection('stories')
          .where('userId', whereIn: socialIds)
          .where('mediaType', isEqualTo: TYPE_REEL)
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('expiresAt', descending: false)
          .get();

      return reelDocs.docs.map((doc) => Story.fromFirestore(doc)).toList();
    });
  }

  // Get trending reels based on likes and views
  Future<List<Story>> getTrendingReels({int limit = 10}) async {
    final now = DateTime.now();

    // Get active reels
    final reelDocs = await _firestore
        .collection('stories')
        .where('mediaType', isEqualTo: TYPE_REEL)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('expiresAt', descending: false)
        .get();

    final reels = reelDocs.docs.map((doc) => Story.fromFirestore(doc)).toList();

    // Sort by engagement (likes + comments + views)
    reels.sort((a, b) {
      final aLikes = (a.metadata?['likes'] as List?)?.length ?? 0;
      final aComments = (a.metadata?['comments'] as List?)?.length ?? 0;
      final aViews = a.viewers.length;
      final aEngagement = aLikes + aComments + aViews;

      final bLikes = (b.metadata?['likes'] as List?)?.length ?? 0;
      final bComments = (b.metadata?['comments'] as List?)?.length ?? 0;
      final bViews = b.viewers.length;
      final bEngagement = bLikes + bComments + bViews;

      return bEngagement.compareTo(aEngagement); // Descending order
    });

    // Return top trending reels
    return reels.take(limit).toList();
  }

  // Like a reel
  Future<void> likeReel(String reelId, String userId) async {
    final reelRef = _firestore.collection('stories').doc(reelId);

    return _firestore.runTransaction((transaction) async {
      final reelDoc = await transaction.get(reelRef);

      if (!reelDoc.exists) {
        throw Exception('Reel does not exist');
      }

      final reel = Story.fromFirestore(reelDoc);
      final likes = List<String>.from(reel.metadata?['likes'] ?? []);

      if (likes.contains(userId)) {
        // User already liked this reel, remove like
        likes.remove(userId);
      } else {
        // Add like
        likes.add(userId);
      }

      // Update the metadata with new likes
      final updatedMetadata = Map<String, dynamic>.from(reel.metadata ?? {});
      updatedMetadata['likes'] = likes;

      transaction.update(reelRef, {'metadata': updatedMetadata});
    });
  }

  // Comment on a reel
  Future<void> commentOnReel(String reelId, String userId, String userName,
      String userPhotoUrl, String comment) async {
    final reelRef = _firestore.collection('stories').doc(reelId);

    return _firestore.runTransaction((transaction) async {
      final reelDoc = await transaction.get(reelRef);

      if (!reelDoc.exists) {
        throw Exception('Reel does not exist');
      }

      final reel = Story.fromFirestore(reelDoc);
      final comments =
          List<Map<String, dynamic>>.from(reel.metadata?['comments'] ?? []);

      // Add new comment
      comments.add({
        'userId': userId,
        'userName': userName,
        'userPhotoUrl': userPhotoUrl,
        'text': comment,
        'timestamp': Timestamp.now(),
      });

      // Update the metadata with new comments
      final updatedMetadata = Map<String, dynamic>.from(reel.metadata ?? {});
      updatedMetadata['comments'] = comments;

      transaction.update(reelRef, {'metadata': updatedMetadata});
    });
  }

  // Share a reel
  Future<void> shareReel(
      String reelId, String userId, List<String> recipientIds) async {
    final reelRef = _firestore.collection('stories').doc(reelId);
    final batch = _firestore.batch();

    // Get the reel
    final reelDoc = await reelRef.get();
    if (!reelDoc.exists) {
      throw Exception('Reel does not exist');
    }

    final reel = Story.fromFirestore(reelDoc);

    // Increment share count
    final updatedMetadata = Map<String, dynamic>.from(reel.metadata ?? {});
    updatedMetadata['shares'] = (updatedMetadata['shares'] ?? 0) + 1;
    batch.update(reelRef, {'metadata': updatedMetadata});

    // Create notifications for recipients
    for (final recipientId in recipientIds) {
      final notificationRef = _firestore.collection('notifications').doc();
      batch.set(notificationRef, {
        'userId': recipientId,
        'senderId': userId,
        'type': 'reel_share',
        'reelId': reelId,
        'reelCreatorId': reel.userId,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // Get user's reels
  Stream<List<Story>> getUserReels(String userId) {
    final now = DateTime.now();

    return _firestore
        .collection('stories')
        .where('userId', isEqualTo: userId)
        .where('mediaType', isEqualTo: TYPE_REEL)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('expiresAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Story.fromFirestore(doc)).toList();
    });
  }

  // Delete a reel
  Future<void> deleteReel(String reelId) async {
    await _firestore.collection('stories').doc(reelId).delete();
  }

  // Mark reel as viewed
  Future<void> markReelAsViewed(String reelId, String userId) async {
    final reelRef = _firestore.collection('stories').doc(reelId);

    return _firestore.runTransaction((transaction) async {
      final reelDoc = await transaction.get(reelRef);

      if (!reelDoc.exists) {
        throw Exception('Reel does not exist');
      }

      final reel = Story.fromFirestore(reelDoc);
      if (!reel.viewers.contains(userId)) {
        final updatedViewers = List<String>.from(reel.viewers)..add(userId);
        transaction.update(reelRef, {'viewers': updatedViewers});
      }
    });
  }
}
