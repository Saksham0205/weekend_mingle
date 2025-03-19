import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/story_model.dart';
import '../models/user_model.dart';
import 'dart:io';
import 'cloudinary_services.dart';

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
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    // Get user data
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = UserModel.fromDocumentSnapshot(userDoc);

    // Upload media to Cloudinary if provided
    String? mediaUrl;
    if (mediaFile != null) {
      try {
        mediaUrl = await CloudinaryService.uploadImage(mediaFile);
        if (mediaUrl == null) {
          throw Exception("Failed to upload media: No URL returned");
        }
      } catch (e) {
        throw Exception("Failed to upload media: $e");
      }
    }

    // Calculate expiration (24 hours from now)
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));

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
        'location': userData.locationName,
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

  // Delete a story
  Future<void> deleteStory(String storyId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Check if user owns the story
    final storyDoc = await _firestore.collection('stories').doc(storyId).get();
    if (!storyDoc.exists) return;

    final storyData = storyDoc.data() as Map<String, dynamic>;
    if (storyData['userId'] != user.uid) {
      throw Exception("Cannot delete story: Not the owner");
    }

    await _firestore.collection('stories').doc(storyId).delete();
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