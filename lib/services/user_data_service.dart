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

  Future<UserModel?> getCurrentUser({bool forceFetch = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No authenticated user found');
      return null;
    }

    print('Getting user data for ${user.uid}');

    // Return cached data if it's still valid and forceFetch is false
    if (!forceFetch && _cachedUser != null && _lastFetchTime != null) {
      final now = DateTime.now();
      if (now.difference(_lastFetchTime!) < _cacheDuration) {
        print('Returning cached user data');
        return _cachedUser;
      }
    }

    // Fetch fresh data from Firestore
    try {
      print('Fetching fresh data from Firestore');
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        print('Firestore data received: ${data.keys}');

        _cachedUser = UserModel.fromDocumentSnapshot(userDoc);
        _lastFetchTime = DateTime.now();
        return _cachedUser;
      } else {
        print('User document does not exist in Firestore');
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }

    return null;
  }

  Future<void> updateUserData(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('Error: No authenticated user found!');
      return;
    }

    // Print for debugging
    print('Starting Firestore update with data: $data');

    try {
      // Sanitize data - convert any incompatible types
      final sanitizedData = _sanitizeDataForFirestore(data);

      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(sanitizedData);

      print('Firestore update successful for ${user.uid}');

      // Update cached data with the original (unsanitized) data
      if (_cachedUser != null) {
        final updatedMap = {..._cachedUser!.toMap(), ...data};
        _cachedUser = UserModel.fromMap(updatedMap, user.uid);
        _lastFetchTime = DateTime.now(); // Reset the fetch time
        print('Cache updated successfully');
      } else {
        print('Cache not updated - no cached user');
      }
    } catch (e) {
      print('Error updating user data in Firestore: $e');
      rethrow;
    }
  }

// Helper method to sanitize data before sending to Firestore
  Map<String, dynamic> _sanitizeDataForFirestore(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);

    // Convert DateTime objects to Timestamps
    for (final key in result.keys.toList()) {
      if (result[key] is DateTime) {
        result[key] = Timestamp.fromDate(result[key] as DateTime);
      }

      // Handle DateTime strings (from local storage)
      if (result[key] is String && key.contains('date')) {
        try {
          result[key] = Timestamp.fromDate(DateTime.parse(result[key]));
        } catch (e) {
          // Not a valid date string, leave as is
        }
      }

      // Remove null values
      if (result[key] == null) {
        result.remove(key);
      }
    }

    return result;
  }

  void clearCache() {
    _cachedUser = null;
    _lastFetchTime = null;
  }
}
