import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class UserDataService {
  static final UserDataService _instance = UserDataService._internal();
  factory UserDataService() => _instance;
  UserDataService._internal();

  UserModel? _cachedUser;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 30);

  Future<UserModel?> getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    // Return cached data if it's still valid
    if (_cachedUser != null && _lastFetchTime != null) {
      final now = DateTime.now();
      if (now.difference(_lastFetchTime!) < _cacheDuration) {
        return _cachedUser;
      }
    }

    // Fetch fresh data from Firestore
    try {
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userData.exists) {
        final data = userData.data() as Map<String, dynamic>;
        _cachedUser = UserModel.fromMap(data, user.uid);
        _lastFetchTime = DateTime.now();
        return _cachedUser;
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
    return null;
  }

  Future<void> updateUserData(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(data);

      // Update cached data
      if (_cachedUser != null) {
        _cachedUser = UserModel.fromMap(
          {..._cachedUser!.toMap(), ...data},
          user.uid,
        );
      }
    } catch (e) {
      print('Error updating user data: $e');
      rethrow;
    }
  }

  void clearCache() {
    _cachedUser = null;
    _lastFetchTime = null;
  }
}