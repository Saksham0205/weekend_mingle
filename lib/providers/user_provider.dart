import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/user_data_service.dart';

class UserProvider with ChangeNotifier {
  static const String _userDataKey = 'user_data';
  final UserDataService _userDataService = UserDataService();
  UserModel? _user;
  bool _isLoading = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;

  // Initialize user data from local storage and Firebase
  Future<void> initializeUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Try to get data from local storage first
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString(_userDataKey);

      if (userDataString != null) {
        final userData = json.decode(userDataString);
        _user = UserModel.fromMap(userData, userData['uid']);
      }

      // Then fetch fresh data from Firebase
      final freshUserData = await _userDataService.getCurrentUser();
      if (freshUserData != null) {
        _user = freshUserData;
        // Update local storage
        await prefs.setString(_userDataKey, json.encode(_user!.toMap()));
      }
    } catch (e) {
      print('Error initializing user: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update user data
  Future<void> updateUserData(Map<String, dynamic> data) async {
    try {
      print('UserProvider: Starting data update: ${data.keys}');

      // Clear cached data to force a fresh fetch
      _userDataService.clearCache();

      // Update data in Firestore
      await _userDataService.updateUserData(data);

      // Force a fresh data fetch after update
      final freshUser = await _userDataService.getCurrentUser();
      if (freshUser != null) {
        _user = freshUser;

        // Update in SharedPreferences with the fresh data
        final prefs = await SharedPreferences.getInstance();
        final jsonData = json.encode(_user!.toMap());
        await prefs.setString(_userDataKey, jsonData);
        print('UserProvider: Local storage updated');
      }

      // Notify listeners to update UI
      notifyListeners();
      print('UserProvider: UI refresh triggered');
    } catch (e) {
      print('UserProvider update error: $e');
      rethrow;
    }
  }

  // Clear user data (on logout)
  Future<void> clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userDataKey);
      _user = null;
      _userDataService.clearCache();
      notifyListeners();
    } catch (e) {
      print('Error clearing user data: $e');
    }
  }

  // Update specific fields
  Future<void> updateProfilePhoto(String photoUrl) async {
    if (_user != null) {
      await updateUserData({'photoUrl': photoUrl});
    }
  }

  Future<void> updateProfileInfo({
    String? name,
    String? bio,
    String? profession,
    String? company,
    String? industry,
    String? locationName,
  }) async {
    if (_user != null) {
      final data = {
        if (name != null) 'name': name,
        if (bio != null) 'bio': bio,
        if (profession != null) 'profession': profession,
        if (company != null) 'company': company,
        if (industry != null) 'industry': industry,
        if (locationName != null) 'locationName': locationName,
      };
      await updateUserData(data);
    }
  }

  Future<void> updateSkillsAndInterests({
    List<String>? skills,
    List<String>? weekendInterests,
  }) async {
    if (_user != null) {
      final data = {
        if (skills != null) 'skills': skills,
        if (weekendInterests != null) 'weekendInterests': weekendInterests,
      };
      await updateUserData(data);
    }
  }

  Future<void> updateAvailability(Map<String, bool> availability) async {
    if (_user != null) {
      await updateUserData({'availability': availability});
    }
  }

  Future<void> updatePersonalityAnswers(Map<String, String> answers) async {
    if (_user != null) {
      await updateUserData({'personalityAnswers': answers});
    }
  }

  Future<void> updateSocialMedia({
    String? linkedin,
    String? github,
    String? twitter,
  }) async {
    if (_user != null) {
      final data = {
        if (linkedin != null) 'linkedin': linkedin,
        if (github != null) 'github': github,
        if (twitter != null) 'twitter': twitter,
      };
      await updateUserData(data);
    }
  }
}