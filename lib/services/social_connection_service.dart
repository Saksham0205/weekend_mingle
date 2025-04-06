import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'friend_service.dart';

class SocialConnectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FriendService _friendService = FriendService();

  // Follow a user (Instagram-style following)
  Future<void> followUser(String followerId, String followedId) async {
    final batch = _firestore.batch();

    // Update follower's following list
    final followerRef = _firestore.collection('users').doc(followerId);
    batch.update(followerRef, {
      'following': FieldValue.arrayUnion([followedId]),
    });

    // Update followed user's followers list
    final followedRef = _firestore.collection('users').doc(followedId);
    batch.update(followedRef, {
      'followers': FieldValue.arrayUnion([followerId]),
    });

    // Create notification for the followed user
    final notificationRef = _firestore.collection('notifications').doc();
    batch.set(notificationRef, {
      'userId': followedId,
      'senderId': followerId,
      'type': 'new_follower',
      'read': false,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // Unfollow a user
  Future<void> unfollowUser(String followerId, String followedId) async {
    final batch = _firestore.batch();

    // Update follower's following list
    final followerRef = _firestore.collection('users').doc(followerId);
    batch.update(followerRef, {
      'following': FieldValue.arrayRemove([followedId]),
    });

    // Update followed user's followers list
    final followedRef = _firestore.collection('users').doc(followedId);
    batch.update(followedRef, {
      'followers': FieldValue.arrayRemove([followerId]),
    });

    await batch.commit();
  }

  // Get followers of a user
  Stream<List<UserModel>> getUserFollowers(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((userDoc) async {
      if (!userDoc.exists) return [];

      final userData = UserModel.fromDocumentSnapshot(userDoc);
      final followerIds = userData.followers ?? [];

      if (followerIds.isEmpty) return [];

      // Get user documents for all followers
      final followerDocs = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: followerIds)
          .get();

      return followerDocs.docs
          .map((doc) => UserModel.fromDocumentSnapshot(doc))
          .toList();
    });
  }

  // Get users that a user is following
  Stream<List<UserModel>> getUserFollowing(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((userDoc) async {
      if (!userDoc.exists) return [];

      final userData = UserModel.fromDocumentSnapshot(userDoc);
      final followingIds = userData.following ?? [];

      if (followingIds.isEmpty) return [];

      // Get user documents for all following
      final followingDocs = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: followingIds)
          .get();

      return followingDocs.docs
          .map((doc) => UserModel.fromDocumentSnapshot(doc))
          .toList();
    });
  }

  // Check if a user is following another user
  Future<bool> isFollowing(String followerId, String followedId) async {
    final userDoc = await _firestore.collection('users').doc(followerId).get();
    if (!userDoc.exists) return false;

    final userData = UserModel.fromDocumentSnapshot(userDoc);
    final followingIds = userData.following ?? [];

    return followingIds.contains(followedId);
  }

  // Get suggested users to follow based on interests and connections
  Future<List<UserModel>> getSuggestedUsersToFollow(String userId,
      {int limit = 10}) async {
    // Get current user data
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return [];

    final userData = UserModel.fromDocumentSnapshot(userDoc);
    final followingIds = userData.following ?? [];
    final friendIds = userData.friends;

    // Combine following and friends to exclude from suggestions
    final excludeIds = {...followingIds, ...friendIds, userId}.toList();

    // Get users with similar interests
    final List<UserModel> suggestedUsers = [];

    // First, try to find users with similar weekend interests
    if (userData.weekendInterests.isNotEmpty) {
      for (final interest in userData.weekendInterests) {
        // Find users with this interest who aren't already connected
        final interestQuery = await _firestore
            .collection('users')
            .where('weekendInterests', arrayContains: interest)
            .limit(limit * 2) // Get more than needed to filter
            .get();

        for (final doc in interestQuery.docs) {
          final suggestedUser = UserModel.fromDocumentSnapshot(doc);
          if (!excludeIds.contains(suggestedUser.uid) &&
              !suggestedUsers.any((u) => u.uid == suggestedUser.uid)) {
            suggestedUsers.add(suggestedUser);
            if (suggestedUsers.length >= limit) break;
          }
        }

        if (suggestedUsers.length >= limit) break;
      }
    }

    // If we still need more suggestions, try professional interests
    if (suggestedUsers.length < limit && userData.interests.isNotEmpty) {
      for (final interest in userData.interests) {
        final interestQuery = await _firestore
            .collection('users')
            .where('interests', arrayContains: interest)
            .limit(limit * 2)
            .get();

        for (final doc in interestQuery.docs) {
          final suggestedUser = UserModel.fromDocumentSnapshot(doc);
          if (!excludeIds.contains(suggestedUser.uid) &&
              !suggestedUsers.any((u) => u.uid == suggestedUser.uid)) {
            suggestedUsers.add(suggestedUser);
            if (suggestedUsers.length >= limit) break;
          }
        }

        if (suggestedUsers.length >= limit) break;
      }
    }

    // If we still need more, try industry or company
    if (suggestedUsers.length < limit && userData.industry != null) {
      final industryQuery = await _firestore
          .collection('users')
          .where('industry', isEqualTo: userData.industry)
          .limit(limit * 2)
          .get();

      for (final doc in industryQuery.docs) {
        final suggestedUser = UserModel.fromDocumentSnapshot(doc);
        if (!excludeIds.contains(suggestedUser.uid) &&
            !suggestedUsers.any((u) => u.uid == suggestedUser.uid)) {
          suggestedUsers.add(suggestedUser);
          if (suggestedUsers.length >= limit) break;
        }
      }
    }

    // If we still need more and user has a company, try company
    if (suggestedUsers.length < limit && userData.company != null) {
      final companyQuery = await _firestore
          .collection('users')
          .where('company', isEqualTo: userData.company)
          .limit(limit * 2)
          .get();

      for (final doc in companyQuery.docs) {
        final suggestedUser = UserModel.fromDocumentSnapshot(doc);
        if (!excludeIds.contains(suggestedUser.uid) &&
            !suggestedUsers.any((u) => u.uid == suggestedUser.uid)) {
          suggestedUsers.add(suggestedUser);
          if (suggestedUsers.length >= limit) break;
        }
      }
    }

    // If we still need more, get friends of friends
    if (suggestedUsers.length < limit && friendIds.isNotEmpty) {
      for (final friendId in friendIds) {
        final friendDoc =
            await _firestore.collection('users').doc(friendId).get();
        if (!friendDoc.exists) continue;

        final friendData = UserModel.fromDocumentSnapshot(friendDoc);
        final friendsFriends = friendData.friends;

        for (final friendsFriendId in friendsFriends) {
          if (!excludeIds.contains(friendsFriendId) &&
              !suggestedUsers.any((u) => u.uid == friendsFriendId)) {
            final friendsFriendDoc =
                await _firestore.collection('users').doc(friendsFriendId).get();
            if (friendsFriendDoc.exists) {
              suggestedUsers
                  .add(UserModel.fromDocumentSnapshot(friendsFriendDoc));
              if (suggestedUsers.length >= limit) break;
            }
          }
        }

        if (suggestedUsers.length >= limit) break;
      }
    }

    // If we still need more, get active users
    if (suggestedUsers.length < limit) {
      final activeUsersQuery = await _firestore
          .collection('users')
          .orderBy('lastActive', descending: true)
          .limit(limit * 3)
          .get();

      for (final doc in activeUsersQuery.docs) {
        final suggestedUser = UserModel.fromDocumentSnapshot(doc);
        if (!excludeIds.contains(suggestedUser.uid) &&
            !suggestedUsers.any((u) => u.uid == suggestedUser.uid)) {
          suggestedUsers.add(suggestedUser);
          if (suggestedUsers.length >= limit) break;
        }
      }
    }

    return suggestedUsers;
  }

  // Get mutual connections (both friends and followers)
  Future<List<UserModel>> getMutualConnections(String userId1, String userId2,
      {int limit = 10}) async {
    // Get data for both users
    final user1Doc = await _firestore.collection('users').doc(userId1).get();
    final user2Doc = await _firestore.collection('users').doc(userId2).get();

    if (!user1Doc.exists || !user2Doc.exists) return [];

    final user1Data = UserModel.fromDocumentSnapshot(user1Doc);
    final user2Data = UserModel.fromDocumentSnapshot(user2Doc);

    // Get mutual friends
    final user1Friends = user1Data.friends;
    final user2Friends = user2Data.friends;
    final mutualFriendIds =
        user1Friends.where((id) => user2Friends.contains(id)).toList();

    // Get mutual followers/following
    final user1Following = user1Data.following ?? [];
    final user2Following = user2Data.following ?? [];
    final mutualFollowingIds =
        user1Following.where((id) => user2Following.contains(id)).toList();

    // Combine and remove duplicates
    final mutualConnectionIds =
        {...mutualFriendIds, ...mutualFollowingIds}.toList();

    if (mutualConnectionIds.isEmpty) return [];

    // Get user data for mutual connections
    final mutualConnectionDocs = await _firestore
        .collection('users')
        .where(FieldPath.documentId,
            whereIn: mutualConnectionIds.take(limit).toList())
        .get();

    return mutualConnectionDocs.docs
        .map((doc) => UserModel.fromDocumentSnapshot(doc))
        .toList();
  }

  // Convert a follower to a friend (send friend request)
  Future<void> convertFollowerToFriend(String userId, String followerId) async {
    // Check if already friends
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) throw Exception('User not found');

    final userData = UserModel.fromDocumentSnapshot(userDoc);
    if (userData.friends.contains(followerId)) {
      throw Exception('Already friends with this user');
    }

    // Send friend request
    await _friendService.sendFriendRequest(userId, followerId);
  }

  // Get social graph statistics
  Future<Map<String, dynamic>> getSocialStats(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) throw Exception('User not found');

    final userData = UserModel.fromDocumentSnapshot(userDoc);

    // Count posts
    final postsQuery = await _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .get();

    // Count stories
    final storiesQuery = await _firestore
        .collection('stories')
        .where('userId', isEqualTo: userId)
        .get();

    // Count weekend activities
    final activitiesQuery = await _firestore
        .collection('weekend_activities')
        .where('creatorId', isEqualTo: userId)
        .get();

    return {
      'followers': userData.followers?.length ?? 0,
      'following': userData.following?.length ?? 0,
      'friends': userData.friends.length,
      'posts': postsQuery.docs.length,
      'stories': storiesQuery.docs.length,
      'activities': activitiesQuery.docs.length,
    };
  }

  // Get a user's friends as a Future (for use with await)
  Future<List<UserModel>> getUserFriends(String userId) async {
    // Get the user document to access their friends list
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return [];

    final userData = UserModel.fromDocumentSnapshot(userDoc);
    final friendIds = userData.friends;

    if (friendIds.isEmpty) return [];

    // Get user documents for all friends
    try {
      final friendDocs = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: friendIds)
          .get();

      return friendDocs.docs
          .map((doc) => UserModel.fromDocumentSnapshot(doc))
          .toList();
    } catch (e) {
      // Handle the case where there might be too many friend IDs for a single query
      if (e.toString().contains('maximum')) {
        // If we have too many friends for a single query, split into batches
        final List<UserModel> allFriends = [];

        // Process in batches of 10
        for (var i = 0; i < friendIds.length; i += 10) {
          final end = (i + 10 < friendIds.length) ? i + 10 : friendIds.length;
          final batch = friendIds.sublist(i, end);

          final batchDocs = await _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: batch)
              .get();

          allFriends.addAll(batchDocs.docs
              .map((doc) => UserModel.fromDocumentSnapshot(doc))
              .toList());
        }

        return allFriends;
      }

      // For other errors, return empty list
      return [];
    }
  }
}
