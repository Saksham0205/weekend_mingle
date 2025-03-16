import 'package:cloud_firestore/cloud_firestore.dart';

class WeekendActivity {
  final String id;
  final String creatorId;
  final String creatorName;
  final String? creatorPhotoUrl;
  final String title;
  final String description;
  final String eventType; // e.g., 'Hiking', 'Dinner', 'Movie', etc.
  final bool isPaid;
  final double? price;
  final int capacity;
  final int currentAttendees;
  final String location;
  final GeoPoint? locationCoordinates;
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final List<String> attendees;
  final List<String> interestedUsers;
  final String? imageUrl;
  final DateTime createdAt;
  final Map<String, dynamic>? additionalInfo; // For any extra details

  WeekendActivity({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    this.creatorPhotoUrl,
    required this.title,
    required this.description,
    required this.eventType,
    required this.isPaid,
    this.price,
    required this.capacity,
    required this.currentAttendees,
    required this.location,
    this.locationCoordinates,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.attendees,
    required this.interestedUsers,
    this.imageUrl,
    required this.createdAt,
    this.additionalInfo,
  });

  factory WeekendActivity.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options,
      ) {
    final data = snapshot.data()!;
    return WeekendActivity(
      id: snapshot.id,
      creatorId: data['creatorId'] ?? '',
      creatorName: data['creatorName'] ?? '',
      creatorPhotoUrl: data['creatorPhotoUrl'],
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      eventType: data['eventType'] ?? '',
      isPaid: data['isPaid'] ?? false,
      price: data['price']?.toDouble(),
      capacity: data['capacity'] ?? 0,
      currentAttendees: data['currentAttendees'] ?? 0,
      location: data['location'] ?? '',
      locationCoordinates: data['locationCoordinates'],
      date: (data['date'] as Timestamp).toDate(),
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      attendees: List<String>.from(data['attendees'] ?? []),
      interestedUsers: List<String>.from(data['interestedUsers'] ?? []),
      imageUrl: data['imageUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      additionalInfo: data['additionalInfo'],
    );
  }

  factory WeekendActivity.fromMap(Map<String, dynamic> data, String id) {
    return WeekendActivity(
      id: id,
      creatorId: data['creatorId'] ?? '',
      creatorName: data['creatorName'] ?? '',
      creatorPhotoUrl: data['creatorPhotoUrl'],
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      eventType: data['eventType'] ?? '',
      isPaid: data['isPaid'] ?? false,
      price: data['price']?.toDouble(),
      capacity: data['capacity'] ?? 0,
      currentAttendees: data['currentAttendees'] ?? 0,
      location: data['location'] ?? '',
      locationCoordinates: data['locationCoordinates'],
      date: (data['date'] as Timestamp).toDate(),
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      attendees: List<String>.from(data['attendees'] ?? []),
      interestedUsers: List<String>.from(data['interestedUsers'] ?? []),
      imageUrl: data['imageUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      additionalInfo: data['additionalInfo'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'creatorId': creatorId,
      'creatorName': creatorName,
      'creatorPhotoUrl': creatorPhotoUrl,
      'title': title,
      'description': description,
      'eventType': eventType,
      'isPaid': isPaid,
      'price': price,
      'capacity': capacity,
      'currentAttendees': currentAttendees,
      'location': location,
      'locationCoordinates': locationCoordinates,
      'date': Timestamp.fromDate(date),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'attendees': attendees,
      'interestedUsers': interestedUsers,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'additionalInfo': additionalInfo,
    };
  }

  WeekendActivity copyWith({
    String? id,
    String? creatorId,
    String? creatorName,
    String? creatorPhotoUrl,
    String? title,
    String? description,
    String? eventType,
    bool? isPaid,
    double? price,
    int? capacity,
    int? currentAttendees,
    String? location,
    GeoPoint? locationCoordinates,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    List<String>? attendees,
    List<String>? interestedUsers,
    String? imageUrl,
    DateTime? createdAt,
    Map<String, dynamic>? additionalInfo,
  }) {
    return WeekendActivity(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      creatorPhotoUrl: creatorPhotoUrl ?? this.creatorPhotoUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      eventType: eventType ?? this.eventType,
      isPaid: isPaid ?? this.isPaid,
      price: price ?? this.price,
      capacity: capacity ?? this.capacity,
      currentAttendees: currentAttendees ?? this.currentAttendees,
      location: location ?? this.location,
      locationCoordinates: locationCoordinates ?? this.locationCoordinates,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      attendees: attendees ?? this.attendees,
      interestedUsers: interestedUsers ?? this.interestedUsers,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      additionalInfo: additionalInfo ?? this.additionalInfo,
    );
  }
}