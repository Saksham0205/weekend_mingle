import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  Future<bool> areFriends(String userId1, String userId2) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId1)
          .get();

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