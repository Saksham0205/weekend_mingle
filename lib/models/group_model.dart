import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  final String id;
  final String name;
  final String description;
  final String creatorId;
  final String? imageUrl;
  final DateTime createdAt;
  final List<String> members;
  final List<String> admins;
  final List<String> pendingMembers;
  final bool isPublic;
  final String category; // e.g., 'Professional', 'Social', 'Hobby', etc.
  final GeoPoint? location;
  final String? locationName;
  final int memberCount;
  final Map<String, dynamic>? metadata;

  Group({
    required this.id,
    required this.name,
    required this.description,
    required this.creatorId,
    this.imageUrl,
    required this.createdAt,
    required this.members,
    required this.admins,
    required this.pendingMembers,
    required this.isPublic,
    required this.category,
    this.location,
    this.locationName,
    required this.memberCount,
    this.metadata,
  });

  factory Group.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Group(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      creatorId: data['creatorId'] ?? '',
      imageUrl: data['imageUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      members: List<String>.from(data['members'] ?? []),
      admins: List<String>.from(data['admins'] ?? []),
      pendingMembers: List<String>.from(data['pendingMembers'] ?? []),
      isPublic: data['isPublic'] ?? true,
      category: data['category'] ?? 'Social',
      location: data['location'],
      locationName: data['locationName'],
      memberCount: data['memberCount'] ?? 0,
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'creatorId': creatorId,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'members': members,
      'admins': admins,
      'pendingMembers': pendingMembers,
      'isPublic': isPublic,
      'category': category,
      'location': location,
      'locationName': locationName,
      'memberCount': memberCount,
      'metadata': metadata,
    };
  }

  // Check if user is an admin
  bool isAdmin(String userId) => admins.contains(userId);

  // Check if user is a member
  bool isMember(String userId) => members.contains(userId);

  // Check if user has a pending request
  bool hasPendingRequest(String userId) => pendingMembers.contains(userId);

  Group copyWith({
    String? name,
    String? description,
    String? imageUrl,
    List<String>? members,
    List<String>? admins,
    List<String>? pendingMembers,
    bool? isPublic,
    String? category,
    GeoPoint? location,
    String? locationName,
    int? memberCount,
    Map<String, dynamic>? metadata,
  }) {
    return Group(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      creatorId: creatorId,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt,
      members: members ?? this.members,
      admins: admins ?? this.admins,
      pendingMembers: pendingMembers ?? this.pendingMembers,
      isPublic: isPublic ?? this.isPublic,
      category: category ?? this.category,
      location: location ?? this.location,
      locationName: locationName ?? this.locationName,
      memberCount: memberCount ?? this.memberCount,
      metadata: metadata ?? this.metadata,
    );
  }
}