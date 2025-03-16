import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String profession;
  final String? photoUrl;
  final String? bio;
  final List<String> interests;
  final GeoPoint? location;
  final String? company;
  final String? locationName;
  final DateTime? lastActive;
  final DateTime createdAt;
  final List<String> weekendInterests;
  final Map<String, bool> availability;
  final String? industry;
  final List<String> skills;
  final bool openToNetworking;
  final List<String> friends;
  final List<String> pendingFriendRequests;
  final List<String> sentFriendRequests;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.profession,
    this.photoUrl,
    this.bio,
    List<String>? interests,
    this.location,
    this.company,
    this.locationName,
    this.lastActive,
    required this.createdAt,
    List<String>? weekendInterests,
    Map<String, bool>? availability,
    this.industry,
    List<String>? skills,
    bool? openToNetworking,
    List<String>? friends,
    List<String>? pendingFriendRequests,
    List<String>? sentFriendRequests,
  }) : interests = interests ?? [],
        weekendInterests = weekendInterests ?? [],
        skills = skills ?? [],
        availability = availability ?? {
          'friday_evening': false,
          'saturday_morning': false,
          'saturday_afternoon': false,
          'saturday_evening': false,
          'sunday_morning': false,
          'sunday_afternoon': false,
          'sunday_evening': false,
        },
        openToNetworking = openToNetworking ?? true,
        friends = friends ?? [],
        pendingFriendRequests = pendingFriendRequests ?? [],
        sentFriendRequests = sentFriendRequests ?? [];

  factory UserModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options,
      ) {
    final data = snapshot.data()!;
    return UserModel(
      uid: snapshot.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      profession: data['profession'] ?? '',
      photoUrl: data['photoUrl'],
      bio: data['bio'],
      interests: List<String>.from(data['interests'] ?? []),
      location: data['location'],
      company: data['company'],
      locationName: data['locationName'],
      lastActive: (data['lastActive'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      weekendInterests: List<String>.from(data['weekendInterests'] ?? []),
      availability: Map<String, bool>.from(data['availability'] ?? {}),
      industry: data['industry'],
      skills: List<String>.from(data['skills'] ?? []),
      openToNetworking: data['openToNetworking'] ?? true,
      friends: List<String>.from(data['friends'] ?? []),
      pendingFriendRequests: List<String>.from(data['pendingFriendRequests'] ?? []),
      sentFriendRequests: List<String>.from(data['sentFriendRequests'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'profession': profession,
      'photoUrl': photoUrl,
      'bio': bio,
      'interests': interests,
      'location': location,
      'company': company,
      'locationName': locationName,
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'weekendInterests': weekendInterests,
      'availability': availability,
      'industry': industry,
      'skills': skills,
      'openToNetworking': openToNetworking,
      'friends': friends,
      'pendingFriendRequests': pendingFriendRequests,
      'sentFriendRequests': sentFriendRequests,
    };
  }

  UserModel copyWith({
    String? name,
    String? profession,
    String? photoUrl,
    String? bio,
    List<String>? interests,
    GeoPoint? location,
    String? company,
    String? locationName,
    List<String>? weekendInterests,
    Map<String, bool>? availability,
    String? industry,
    List<String>? skills,
    bool? openToNetworking,
    List<String>? friends,
    List<String>? pendingFriendRequests,
    List<String>? sentFriendRequests,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email,
      profession: profession ?? this.profession,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      location: location ?? this.location,
      company: company ?? this.company,
      locationName: locationName ?? this.locationName,
      lastActive: lastActive,
      createdAt: createdAt,
      weekendInterests: weekendInterests ?? this.weekendInterests,
      availability: availability ?? this.availability,
      industry: industry ?? this.industry,
      skills: skills ?? this.skills,
      openToNetworking: openToNetworking ?? this.openToNetworking,
      friends: friends ?? this.friends,
      pendingFriendRequests: pendingFriendRequests ?? this.pendingFriendRequests,
      sentFriendRequests: sentFriendRequests ?? this.sentFriendRequests,
    );
  }
}