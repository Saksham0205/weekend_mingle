import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friend_request_model.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';

class FriendService {
  final _firestore = FirebaseFirestore.instance;

  Future<void> sendFriendRequest(String senderId, String receiverId) async {
    // Create the friend request
    final requestRef = _firestore.collection('friend_requests').doc();
    final request = FriendRequestModel(
      id: requestRef.id,
      senderId: senderId,
      receiverId: receiverId,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    // Add to friend_requests collection
    await requestRef.set(request.toFirestore());

    // Update sender's sentFriendRequests
    await _firestore.collection('users').doc(senderId).update({
      'sentFriendRequests': FieldValue.arrayUnion([receiverId]),
    });

    // Update receiver's pendingFriendRequests
    await _firestore.collection('users').doc(receiverId).update({
      'pendingFriendRequests': FieldValue.arrayUnion([senderId]),
    });
  }

  Future<void> acceptFriendRequest(String requestId, String userId, String friendId) async {
    final batch = _firestore.batch();

    // Update the friend request status
    final requestRef = _firestore.collection('friend_requests').doc(requestId);
    batch.update(requestRef, {'status': 'accepted'});

    // Add each user to the other's friends list
    final userRef = _firestore.collection('users').doc(userId);
    final friendRef = _firestore.collection('users').doc(friendId);

    batch.update(userRef, {
      'friends': FieldValue.arrayUnion([friendId]),
      'pendingFriendRequests': FieldValue.arrayRemove([friendId]),
    });

    batch.update(friendRef, {
      'friends': FieldValue.arrayUnion([userId]),
      'sentFriendRequests': FieldValue.arrayRemove([userId]),
    });

    await batch.commit();
  }

  Future<void> rejectFriendRequest(String requestId, String userId, String friendId) async {
    final batch = _firestore.batch();

    // Update the friend request status
    final requestRef = _firestore.collection('friend_requests').doc(requestId);
    batch.update(requestRef, {'status': 'rejected'});

    // Remove the request from both users' lists
    final userRef = _firestore.collection('users').doc(userId);
    final friendRef = _firestore.collection('users').doc(friendId);

    batch.update(userRef, {
      'pendingFriendRequests': FieldValue.arrayRemove([friendId]),
    });

    batch.update(friendRef, {
      'sentFriendRequests': FieldValue.arrayRemove([userId]),
    });

    await batch.commit();
  }

  Future<void> removeFriend(String userId, String friendId) async {
    final batch = _firestore.batch();

    final userRef = _firestore.collection('users').doc(userId);
    final friendRef = _firestore.collection('users').doc(friendId);

    batch.update(userRef, {
      'friends': FieldValue.arrayRemove([friendId]),
    });

    batch.update(friendRef, {
      'friends': FieldValue.arrayRemove([userId]),
    });

    await batch.commit();
  }

  Stream<List<UserModel>> getFriends(String userId) {
    return _firestore
        .collection('users')
        .where('friends', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => UserModel.fromDocumentSnapshot(doc))
        .toList());
  }

  Stream<List<FriendRequestModel>> getPendingRequests(String userId) {
    return _firestore
        .collection('friend_requests')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => FriendRequestModel.fromFirestore(doc))
        .toList());
  }

  Future<bool> areFriends(String userId1, String userId2) async {
    final user = await _firestore.collection('users').doc(userId1).get();
    if (!user.exists) return false;

    final userData = UserModel.fromDocumentSnapshot(user);
    return userData.friends.contains(userId2);
  }

  Future<String?> getFriendRequestId(String senderId, String receiverId) async {
    final requests = await _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: senderId)
        .where('receiverId', isEqualTo: receiverId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (requests.docs.isEmpty) return null;
    return requests.docs.first.id;
  }
  
  // Instagram-like follow functionality
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
  
  // Get user's followers
  Stream<List<UserModel>> getFollowers(String userId) {
    return _firestore
        .collection('users')
        .where('following', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromDocumentSnapshot(doc))
          .toList();
    });
  }
  
  // Get users that a user is following
  Stream<List<UserModel>> getFollowing(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((userDoc) async {
      final userData = UserModel.fromDocumentSnapshot(userDoc);
      final followingIds = userData.following ?? [];
      
      if (followingIds.isEmpty) {
        return <UserModel>[];
      }
      
      // Get user documents for all following IDs
      // Note: Firestore has a limit of 10 IDs in a whereIn query
      // For larger lists, we'd need to split into batches
      final List<UserModel> following = [];
      
      for (int i = 0; i < followingIds.length; i += 10) {
        final end = (i + 10 < followingIds.length) ? i + 10 : followingIds.length;
        final batch = followingIds.sublist(i, end);
        
        final querySnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
            
        following.addAll(querySnapshot.docs
            .map((doc) => UserModel.fromDocumentSnapshot(doc))
            .toList());
      }
      
      return following;
    });
  }
  
  // Get social feed (posts from friends and followed users)
  Stream<List<Post>> getSocialFeed(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((userDoc) async {
      final userData = UserModel.fromDocumentSnapshot(userDoc);
      final following = userData.following ?? [];
      final friends = userData.friends;
      
      // Combine friends and following for feed sources
      final feedSources = {...following, ...friends, userId}.toList();
      
      if (feedSources.isEmpty) {
        return <Post>[];
      }
      
      // Get posts from all feed sources
      // Note: Firestore has a limit of 10 IDs in a whereIn query
      final List<Post> feed = [];
      
      for (int i = 0; i < feedSources.length; i += 10) {
        final end = (i + 10 < feedSources.length) ? i + 10 : feedSources.length;
        final batch = feedSources.sublist(i, end);
        
        final querySnapshot = await _firestore
            .collection('posts')
            .where('userId', whereIn: batch)
            .orderBy('timestamp', descending: true)
            .limit(50) // Limit total posts
            .get();
            
        feed.addAll(querySnapshot.docs
            .map((doc) => Post.fromFirestore(doc))
            .toList());
      }
      
      // Sort by timestamp (newest first)
      feed.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      return feed;
    });
  }
  
  // Get suggested friends/connections based on mutual friends, interests, and industry
  Future<List<UserModel>> getSuggestedConnections(String userId, {int limit = 10}) async {
    // Get the user's data
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final user = UserModel.fromDocumentSnapshot(userDoc);
    
    // Get user's existing connections (friends + following + pending requests)
    final existingConnections = {
      ...user.friends,
      ...(user.following ?? []),
      ...user.sentFriendRequests,
      ...user.pendingFriendRequests,
      userId, // Exclude self
    };
    
    // Get users with similar interests
    final interestsQuery = await _firestore
        .collection('users')
        .where('interests', arrayContainsAny: user.interests.isNotEmpty ? user.interests : ['networking'])
        .limit(20)
        .get();
        
    // Get users in the same industry
    final industryQuery = user.industry != null ? await _firestore
        .collection('users')
        .where('industry', isEqualTo: user.industry)
        .limit(20)
        .get() : null;
        
    // Get users with similar weekend interests
    final weekendInterestsQuery = await _firestore
        .collection('users')
        .where('weekendInterests', arrayContainsAny: user.weekendInterests.isNotEmpty ? user.weekendInterests : ['Other'])
        .limit(20)
        .get();
    
    // Combine and score potential connections
    final Map<String, Map<String, dynamic>> potentialConnections = {};
    
    // Process interests matches
    for (final doc in interestsQuery.docs) {
      final connection = UserModel.fromDocumentSnapshot(doc);
      if (existingConnections.contains(connection.uid)) continue;
      
      // Calculate common interests
      final commonInterests = connection.interests.where((i) => user.interests.contains(i)).length;
      
      potentialConnections[connection.uid] = {
        'user': connection,
        'score': commonInterests * 2, // Weight interests highly
      };
    }
    
    // Process industry matches
    if (industryQuery != null) {
      for (final doc in industryQuery.docs) {
        final connection = UserModel.fromDocumentSnapshot(doc);
        if (existingConnections.contains(connection.uid)) continue;
        
        if (potentialConnections.containsKey(connection.uid)) {
          potentialConnections[connection.uid]!['score'] += 3; // Bonus for industry match
        } else {
          potentialConnections[connection.uid] = {
            'user': connection,
            'score': 3, // Base score for industry match
          };
        }
      }
    }
    
    // Process weekend interests matches
    for (final doc in weekendInterestsQuery.docs) {
      final connection = UserModel.fromDocumentSnapshot(doc);
      if (existingConnections.contains(connection.uid)) continue;
      
      // Calculate common weekend interests
      final commonWeekendInterests = connection.weekendInterests.where((i) => user.weekendInterests.contains(i)).length;
      
      if (potentialConnections.containsKey(connection.uid)) {
        potentialConnections[connection.uid]!['score'] += commonWeekendInterests * 2;
      } else {
        potentialConnections[connection.uid] = {
          'user': connection,
          'score': commonWeekendInterests * 2,
        };
      }
    }
    
    // Sort by score and return top suggestions
    final sortedConnections = potentialConnections.values.toList()
      ..sort((a, b) => (b['score'] as num).compareTo(a['score'] as num));
    
    return sortedConnections
        .take(limit)
        .map((item) => item['user'] as UserModel)
        .toList();
  }
}