import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../models/weekend_activity_model.dart';
import 'dart:io';
import 'cloudinary_services.dart';

class FeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CloudinaryService _cloudinaryService = CloudinaryService();

  // Create a new post
  Future<String> createPost({
    required String content,
    File? imageFile,
    List<String>? hashtags,
    String? activityId,
    Map<String, dynamic>? additionalInfo,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    // Get user data
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = UserModel.fromDocumentSnapshot(userDoc);

    // Upload image if provided
    String? imageUrl;
    if (imageFile != null) {
      imageUrl = await CloudinaryService.uploadImage(imageFile);
    }

    // Create post document
    final postRef = _firestore.collection('posts').doc();

    // Prepare post data
    final postData = {
      'userId': user.uid,
      'userName': userData.name,
      'userPhotoUrl': userData.photoUrl,
      'content': content,
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': [],
      'comments': [],
      'hashtags': hashtags ?? [],
      'activityId': activityId,
      'additionalInfo': additionalInfo,
    };

    // Save post to Firestore
    await postRef.set(postData);

    // If post is related to an activity, update the activity with this post reference
    if (activityId != null) {
      await _firestore.collection('weekend_activities').doc(activityId).update({
        'relatedPosts': FieldValue.arrayUnion([postRef.id]),
      });
    }

    return postRef.id;
  }

  // Get feed posts for a user (from friends and followed users)
  Stream<List<Post>> getUserFeed(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((userDoc) async {
      final userData = UserModel.fromDocumentSnapshot(userDoc);
      final followingIds = userData.following ?? [];
      final friendIds = userData.friends;

      // Combine friends and following for a complete social graph
      final socialIds = {...followingIds, ...friendIds, userId}
          .toList(); // Include user's own posts

      if (socialIds.isEmpty) {
        return <Post>[];
      }

      // Query posts from social connections
      final postDocs = await _firestore
          .collection('posts')
          .where('userId', whereIn: socialIds)
          .orderBy('timestamp', descending: true)
          .limit(50) // Limit to recent posts
          .get();

      return postDocs.docs.map((doc) => Post.fromFirestore(doc)).toList();
    });
  }

  // Get posts for a specific user
  Stream<List<Post>> getUserPosts(String userId) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
    });
  }

  // Get posts related to a specific weekend activity
  Stream<List<Post>> getActivityPosts(String activityId) {
    return _firestore
        .collection('posts')
        .where('activityId', isEqualTo: activityId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
    });
  }

  // Like or unlike a post
  Future<void> toggleLikePost(String postId, String userId) async {
    final postRef = _firestore.collection('posts').doc(postId);

    return _firestore.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);

      if (!postDoc.exists) {
        throw Exception('Post does not exist');
      }

      final post = Post.fromFirestore(postDoc);
      final likes = List<String>.from(post.likes);

      if (likes.contains(userId)) {
        // User already liked this post, remove like
        likes.remove(userId);
      } else {
        // Add like
        likes.add(userId);

        // Create notification if the post is not by the current user
        if (post.userId != userId) {
          final notificationRef = _firestore.collection('notifications').doc();
          transaction.set(notificationRef, {
            'userId': post.userId, // Post creator receives notification
            'senderId': userId,
            'type': 'post_like',
            'postId': postId,
            'read': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }

      transaction.update(postRef, {'likes': likes});
    });
  }

  // Add comment to a post
  Future<void> addComment(String postId, String userId, String userName,
      String? userPhotoUrl, String commentText) async {
    final postRef = _firestore.collection('posts').doc(postId);

    return _firestore.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);

      if (!postDoc.exists) {
        throw Exception('Post does not exist');
      }

      final post = Post.fromFirestore(postDoc);

      // Create new comment
      final newComment = {
        'userId': userId,
        'userName': userName,
        'userPhotoUrl': userPhotoUrl,
        'text': commentText,
        'timestamp': Timestamp.now(),
      };

      // Add comment to post
      transaction.update(postRef, {
        'comments': FieldValue.arrayUnion([newComment]),
      });

      // Create notification if the post is not by the current user
      if (post.userId != userId) {
        final notificationRef = _firestore.collection('notifications').doc();
        transaction.set(notificationRef, {
          'userId': post.userId, // Post creator receives notification
          'senderId': userId,
          'type': 'post_comment',
          'postId': postId,
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // Delete a post
  Future<void> deletePost(String postId) async {
    final postDoc = await _firestore.collection('posts').doc(postId).get();

    if (!postDoc.exists) return;

    final post = Post.fromFirestore(postDoc);
    final batch = _firestore.batch();

    // Delete the post
    batch.delete(_firestore.collection('posts').doc(postId));

    // If post is related to an activity, remove reference from the activity
    if (post.additionalInfo != null &&
        post.additionalInfo!['activityId'] != null) {
      final activityId = post.additionalInfo!['activityId'];
      batch
          .update(_firestore.collection('weekend_activities').doc(activityId), {
        'relatedPosts': FieldValue.arrayRemove([postId]),
      });
    }

    // Delete related notifications
    final notifications = await _firestore
        .collection('notifications')
        .where('postId', isEqualTo: postId)
        .get();

    for (final doc in notifications.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // Share a post with friends
  Future<void> sharePost(
      String postId, String userId, List<String> recipientIds) async {
    final batch = _firestore.batch();
    final postDoc = await _firestore.collection('posts').doc(postId).get();

    if (!postDoc.exists) {
      throw Exception('Post does not exist');
    }

    // Create notifications for recipients
    for (final recipientId in recipientIds) {
      final notificationRef = _firestore.collection('notifications').doc();
      batch.set(notificationRef, {
        'userId': recipientId,
        'senderId': userId,
        'type': 'post_share',
        'postId': postId,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // Get trending posts based on engagement
  Future<List<Post>> getTrendingPosts({int limit = 10}) async {
    // Get recent posts
    final postDocs = await _firestore
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(100) // Get a larger set to filter from
        .get();

    final posts = postDocs.docs.map((doc) => Post.fromFirestore(doc)).toList();

    // Sort by engagement (likes + comments)
    posts.sort((a, b) {
      final aEngagement = a.likes.length + a.comments.length;
      final bEngagement = b.likes.length + b.comments.length;
      return bEngagement.compareTo(aEngagement); // Descending order
    });

    // Return top trending posts
    return posts.take(limit).toList();
  }

  // Get posts with specific hashtags
  Future<List<Post>> getPostsByHashtag(String hashtag, {int limit = 20}) async {
    final postDocs = await _firestore
        .collection('posts')
        .where('hashtags', arrayContains: hashtag)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return postDocs.docs.map((doc) => Post.fromFirestore(doc)).toList();
  }

  // Create a post about a weekend activity
  Future<String> createActivityPost({
    required String activityId,
    required String content,
    File? imageFile,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    // Get activity details
    final activityDoc =
        await _firestore.collection('weekend_activities').doc(activityId).get();
    if (!activityDoc.exists) {
      throw Exception('Activity does not exist');
    }

    final activity = WeekendActivity.fromFirestore(activityDoc, null);

    // Create post with activity reference
    return createPost(
      content: content,
      imageFile: imageFile,
      activityId: activityId,
      additionalInfo: {
        'activityTitle': activity.title,
        'activityType': activity.eventType,
        'activityDate': activity.date,
      },
    );
  }

  // Get feed with mix of posts and weekend activities
  Future<List<dynamic>> getMixedFeed(String userId) async {
    // Get user's social connections
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userData = UserModel.fromDocumentSnapshot(userDoc);
    final followingIds = userData.following ?? [];
    final friendIds = userData.friends;

    // Combine friends and following for a complete social graph
    final socialIds = {...followingIds, ...friendIds, userId}.toList();

    // Get posts from social connections
    final postDocs = await _firestore
        .collection('posts')
        .where('userId', whereIn: socialIds)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .get();

    final posts = postDocs.docs.map((doc) => Post.fromFirestore(doc)).toList();

    // Get weekend activities from friends
    final activityDocs = await _firestore
        .collection('weekend_activities')
        .where('creatorId', whereIn: socialIds)
        .where('date', isGreaterThanOrEqualTo: DateTime.now())
        .orderBy('date')
        .limit(10)
        .get();

    final activities = activityDocs.docs
        .map((doc) => WeekendActivity.fromFirestore(doc, null))
        .toList();

    // Combine and sort by timestamp/date
    final mixedFeed = [...posts, ...activities];
    mixedFeed.sort((a, b) {
      final DateTime aTime =
          a is Post ? a.timestamp : (a as WeekendActivity).date;
      final DateTime bTime =
          b is Post ? b.timestamp : (b as WeekendActivity).date;
      return bTime.compareTo(aTime); // Descending order (newest first)
    });

    return mixedFeed;
  }
}
