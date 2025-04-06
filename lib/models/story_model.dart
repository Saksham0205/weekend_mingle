import 'package:cloud_firestore/cloud_firestore.dart';

class Story {
  final String id;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String? mediaUrl;
  final String? text;
  final String mediaType; // 'image', 'video', 'text', 'reel'
  final DateTime createdAt;
  final DateTime
      expiresAt; // 24 hours after creation for stories, 7 days for reels
  final List<String> viewers; // IDs of users who viewed the story
  final Map<String, dynamic>?
      metadata; // Additional metadata including likes, comments, hashtags

  Story({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    this.mediaUrl,
    this.text,
    required this.mediaType,
    required this.createdAt,
    required this.expiresAt,
    required this.viewers,
    this.metadata,
  });

  factory Story.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Story(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userPhotoUrl: data['userPhotoUrl'],
      mediaUrl: data['mediaUrl'],
      text: data['text'],
      mediaType: data['mediaType'] ?? 'image',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      viewers: List<String>.from(data['viewers'] ?? []),
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'mediaUrl': mediaUrl,
      'text': text,
      'mediaType': mediaType,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'viewers': viewers,
      'metadata': metadata,
    };
  }

  // Check if the story is active/not expired
  bool get isActive => DateTime.now().isBefore(expiresAt);

  // Check if a user has viewed this story
  bool hasViewed(String userId) => viewers.contains(userId);

  // Calculate the percentage of time remaining before expiration
  double get timeRemainingPercent {
    final total = expiresAt.difference(createdAt).inMilliseconds;
    final elapsed = DateTime.now().difference(createdAt).inMilliseconds;

    if (elapsed >= total) return 0.0;

    return (total - elapsed) / total * 100;
  }

  Story copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userPhotoUrl,
    String? mediaUrl,
    String? text,
    String? mediaType,
    DateTime? createdAt,
    DateTime? expiresAt,
    List<String>? viewers,
    Map<String, dynamic>? metadata,
  }) {
    return Story(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      text: text ?? this.text,
      mediaType: mediaType ?? this.mediaType,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      viewers: viewers ?? this.viewers,
      metadata: metadata ?? this.metadata,
    );
  }
}
