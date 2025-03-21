import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserModel> getUserById(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw Exception('User not found');
    }
    return UserModel.fromMap(userDoc.data() as Map<String, dynamic>, userId);
  }

  Future<bool> areFriends(String userId1, String userId2) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId1).get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>;
      final friends = List<String>.from(userData['friends'] ?? []);

      return friends.contains(userId2);
    } catch (e) {
      print('Error checking friendship status: $e');
      return false;
    }
  }
}
