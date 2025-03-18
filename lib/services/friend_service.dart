import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friend_request_model.dart';
import '../models/user_model.dart';

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
}