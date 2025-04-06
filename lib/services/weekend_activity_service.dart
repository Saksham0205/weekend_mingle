import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/weekend_activity_model.dart';
import '../models/user_model.dart';
import '../models/user_model.dart';

class WeekendActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _activitiesCollection;

  WeekendActivityService()
      : _activitiesCollection =
            FirebaseFirestore.instance.collection('weekend_activities');

  // Get all weekend activities
  Stream<List<WeekendActivity>> getWeekendActivities() {
    return _activitiesCollection
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WeekendActivity.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>, null))
          .toList();
    });
  }

  // Get weekend activities created by a specific user
  Stream<List<WeekendActivity>> getUserWeekendActivities(String userId) {
    return _activitiesCollection
        .where('creatorId', isEqualTo: userId)
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WeekendActivity.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>, null))
          .toList();
    });
  }

  // Get a specific weekend activity
  Future<WeekendActivity?> getWeekendActivity(String activityId) async {
    final docSnapshot = await _activitiesCollection.doc(activityId).get();
    if (docSnapshot.exists) {
      return WeekendActivity.fromFirestore(
          docSnapshot as DocumentSnapshot<Map<String, dynamic>>, null);
    }
    return null;
  }

  // Get a specific weekend activity as a stream
  Stream<WeekendActivity?> getWeekendActivityStream(String activityId) {
    return _activitiesCollection.doc(activityId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return WeekendActivity.fromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>, null);
    });
  }

  // Create a new weekend activity
  Future<String> createWeekendActivity({
    required String creatorId,
    required String creatorName,
    String? creatorPhotoUrl,
    required String title,
    required String description,
    required String eventType,
    required bool isPaid,
    double? price,
    required int capacity,
    required String location,
    GeoPoint? locationCoordinates,
    required DateTime date,
    required DateTime startTime,
    required DateTime endTime,
    String? imageUrl,
    Map<String, dynamic>? additionalInfo,
  }) async {
    final docRef = _activitiesCollection.doc();

    final activity = WeekendActivity(
      id: docRef.id,
      creatorId: creatorId,
      creatorName: creatorName,
      creatorPhotoUrl: creatorPhotoUrl,
      title: title,
      description: description,
      eventType: eventType,
      isPaid: isPaid,
      price: price,
      capacity: capacity,
      currentAttendees: 1, // Creator is automatically attending
      location: location,
      locationCoordinates: locationCoordinates,
      date: date,
      startTime: startTime,
      endTime: endTime,
      attendees: [creatorId], // Creator is automatically attending
      interestedUsers: [],
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
      additionalInfo: additionalInfo,
    );

    await docRef.set(activity.toMap());
    return docRef.id;
  }

  // Update an existing weekend activity
  Future<void> updateWeekendActivity(WeekendActivity activity) async {
    await _activitiesCollection.doc(activity.id).update(activity.toMap());
  }

  // Delete a weekend activity
  Future<void> deleteWeekendActivity(String activityId) async {
    await _activitiesCollection.doc(activityId).delete();
  }

  // Join a weekend activity
  Future<void> joinWeekendActivity(String activityId, String userId) async {
    final activityRef = _activitiesCollection.doc(activityId);

    return _firestore.runTransaction((transaction) async {
      final activitySnapshot = await transaction.get(activityRef);

      if (!activitySnapshot.exists) {
        throw Exception('Activity does not exist');
      }

      final activity = WeekendActivity.fromFirestore(
          activitySnapshot as DocumentSnapshot<Map<String, dynamic>>, null);

      if (activity.attendees.contains(userId)) {
        throw Exception('User is already attending this activity');
      }

      if (activity.currentAttendees >= activity.capacity) {
        throw Exception('Activity is at full capacity');
      }

      final updatedAttendees = List<String>.from(activity.attendees)
        ..add(userId);

      transaction.update(activityRef, {
        'attendees': updatedAttendees,
        'currentAttendees': activity.currentAttendees + 1,
      });
    });
  }

  // Leave a weekend activity
  Future<void> leaveWeekendActivity(String activityId, String userId) async {
    final activityRef = _activitiesCollection.doc(activityId);

    return _firestore.runTransaction((transaction) async {
      final activitySnapshot = await transaction.get(activityRef);

      if (!activitySnapshot.exists) {
        throw Exception('Activity does not exist');
      }

      final activity = WeekendActivity.fromFirestore(
          activitySnapshot as DocumentSnapshot<Map<String, dynamic>>, null);

      if (!activity.attendees.contains(userId)) {
        throw Exception('User is not attending this activity');
      }

      // Don't allow the creator to leave
      if (activity.creatorId == userId) {
        throw Exception('Creator cannot leave the activity');
      }

      final updatedAttendees = List<String>.from(activity.attendees)
        ..remove(userId);

      transaction.update(activityRef, {
        'attendees': updatedAttendees,
        'currentAttendees': activity.currentAttendees - 1,
      });
    });
  }

  // Express interest in a weekend activity
  Future<void> expressInterest(String activityId, String userId) async {
    final activityRef = _activitiesCollection.doc(activityId);

    return _firestore.runTransaction((transaction) async {
      final activitySnapshot = await transaction.get(activityRef);

      if (!activitySnapshot.exists) {
        throw Exception('Activity does not exist');
      }

      final activity = WeekendActivity.fromFirestore(
          activitySnapshot as DocumentSnapshot<Map<String, dynamic>>, null);

      if (activity.interestedUsers.contains(userId)) {
        throw Exception('User has already expressed interest in this activity');
      }

      final updatedInterestedUsers = List<String>.from(activity.interestedUsers)
        ..add(userId);

      transaction.update(activityRef, {
        'interestedUsers': updatedInterestedUsers,
      });
    });
  }

  // Remove interest from a weekend activity
  Future<void> removeInterest(String activityId, String userId) async {
    final activityRef = _activitiesCollection.doc(activityId);

    return _firestore.runTransaction((transaction) async {
      final activitySnapshot = await transaction.get(activityRef);

      if (!activitySnapshot.exists) {
        throw Exception('Activity does not exist');
      }

      final activity = WeekendActivity.fromFirestore(
          activitySnapshot as DocumentSnapshot<Map<String, dynamic>>, null);

      if (!activity.interestedUsers.contains(userId)) {
        throw Exception('User has not expressed interest in this activity');
      }

      final updatedInterestedUsers = List<String>.from(activity.interestedUsers)
        ..remove(userId);

      transaction.update(activityRef, {
        'interestedUsers': updatedInterestedUsers,
      });
    });
  }

  // Get recommended weekend activities based on user interests and location
  Future<List<WeekendActivity>> getRecommendedActivities(UserModel user,
      {int limit = 10}) async {
    // Get activities that match user's weekend interests
    final interestQuery = await _activitiesCollection
        .where('eventType',
            whereIn: user.weekendInterests.isNotEmpty
                ? user.weekendInterests
                : ['Other'])
        .where('date', isGreaterThanOrEqualTo: DateTime.now())
        .orderBy('date', descending: false)
        .limit(limit)
        .get();

    final List<WeekendActivity> recommendedActivities = interestQuery.docs
        .map((doc) => WeekendActivity.fromFirestore(
            doc as DocumentSnapshot<Map<String, dynamic>>, null))
        .toList();

    // If we have location data, add some nearby activities
    if (user.location != null && recommendedActivities.length < limit) {
      // Get the user's location
      final userLocation = user.location!;

      // Calculate bounds for a reasonable radius (approximately 50km)
      const double radiusInDegrees = 0.5; // Rough approximation

      final lowerLat = userLocation.latitude - radiusInDegrees;
      final upperLat = userLocation.latitude + radiusInDegrees;
      final lowerLng = userLocation.longitude - radiusInDegrees;
      final upperLng = userLocation.longitude + radiusInDegrees;

      final locationQuery = await _activitiesCollection
          .where('locationCoordinates.latitude',
              isGreaterThanOrEqualTo: lowerLat)
          .where('locationCoordinates.latitude', isLessThanOrEqualTo: upperLat)
          .where('date', isGreaterThanOrEqualTo: DateTime.now())
          .orderBy('date', descending: false)
          .limit(limit - recommendedActivities.length)
          .get();

      // Filter for longitude manually since Firestore can't query on multiple fields
      final nearbyActivities = locationQuery.docs
          .map((doc) => WeekendActivity.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>, null))
          .where((activity) =>
              activity.locationCoordinates != null &&
              activity.locationCoordinates!.longitude >= lowerLng &&
              activity.locationCoordinates!.longitude <= upperLng)
          .toList();

      // Add unique nearby activities to recommendations
      for (final activity in nearbyActivities) {
        if (!recommendedActivities.any((a) => a.id == activity.id)) {
          recommendedActivities.add(activity);
          if (recommendedActivities.length >= limit) break;
        }
      }
    }

    return recommendedActivities;
  }

  // Get activities by category/event type
  Stream<List<WeekendActivity>> getActivitiesByCategory(String category) {
    return _activitiesCollection
        .where('eventType', isEqualTo: category)
        .where('date', isGreaterThanOrEqualTo: DateTime.now())
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WeekendActivity.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>, null))
          .toList();
    });
  }

  // Get popular activities (most attendees or interested users)
  Stream<List<WeekendActivity>> getPopularActivities({int limit = 10}) {
    return _activitiesCollection
        .where('date', isGreaterThanOrEqualTo: DateTime.now())
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
      final activities = snapshot.docs
          .map((doc) => WeekendActivity.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>, null))
          .toList();

      // Sort by popularity (attendees + interested users)
      activities.sort((a, b) {
        final aPopularity = a.attendees.length + a.interestedUsers.length;
        final bPopularity = b.attendees.length + b.interestedUsers.length;
        return bPopularity.compareTo(aPopularity); // Descending order
      });

      return activities.take(limit).toList();
    });
  }

  // Share activity with friends (creates a notification)
  Future<void> shareActivityWithFriends(
      String activityId, String senderId, List<String> friendIds) async {
    final batch = _firestore.batch();
    final activity = await getWeekendActivity(activityId);

    if (activity == null) {
      throw Exception('Activity does not exist');
    }

    // Create a notification for each friend
    for (final friendId in friendIds) {
      final notificationRef = _firestore.collection('notifications').doc();
      batch.set(notificationRef, {
        'userId': friendId,
        'senderId': senderId,
        'type': 'activity_share',
        'activityId': activityId,
        'activityTitle': activity.title,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // Get activities that friends are attending
  Future<List<WeekendActivity>> getFriendsActivities(List<String> friendIds,
      {int limit = 10}) async {
    if (friendIds.isEmpty) return [];

    final List<WeekendActivity> friendsActivities = [];

    // Get activities where friends are attendees
    for (final friendId in friendIds) {
      final query = await _activitiesCollection
          .where('attendees', arrayContains: friendId)
          .where('date', isGreaterThanOrEqualTo: DateTime.now())
          .orderBy('date', descending: false)
          .limit(limit)
          .get();

      final activities = query.docs
          .map((doc) => WeekendActivity.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>, null))
          .toList();

      for (final activity in activities) {
        if (!friendsActivities.any((a) => a.id == activity.id)) {
          friendsActivities.add(activity);
          if (friendsActivities.length >= limit) break;
        }
      }

      if (friendsActivities.length >= limit) break;
    }

    return friendsActivities;
  }
}
