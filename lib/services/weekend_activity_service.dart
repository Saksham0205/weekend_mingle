import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/weekend_activity_model.dart';

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
}
