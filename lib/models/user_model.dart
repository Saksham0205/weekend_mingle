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
  final String? linkedin;
  final String? github;
  final String? twitter;
  final Map<String, String>? personalityAnswers;

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
    this.linkedin,
    this.github,
    this.twitter,
    this.personalityAnswers,
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
      [SnapshotOptions? options]
      ) {
    final data = snapshot.data()!;
    return UserModel(
      uid: snapshot.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      profession: data['profession'] ?? '',
      photoUrl: data['photoUrl'],
      bio: data['bio'],
      interests: (data['interests'] != null) ? List<String>.from(data['interests'] as List<dynamic>) : [],
      location: data['location'],
      company: data['company'],
      locationName: data['locationName'],
      lastActive: (data['lastActive'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      weekendInterests: (data['weekendInterests'] != null) ? List<String>.from(data['weekendInterests'] as List<dynamic>) : [],
      availability: Map<String, bool>.from(data['availability'] ?? {}),
      industry: data['industry'],
      skills: (data['skills'] != null) ? List<String>.from(data['skills'] as List<dynamic>) : [],
      openToNetworking: data['openToNetworking'] ?? true,
      friends: (data['friends'] != null) ? List<String>.from(data['friends'] as List<dynamic>) : [],
      pendingFriendRequests: (data['pendingFriendRequests'] != null) ? List<String>.from(data['pendingFriendRequests'] as List<dynamic>) : [],
      sentFriendRequests: (data['sentFriendRequests'] != null) ? List<String>.from(data['sentFriendRequests'] as List<dynamic>) : [],
      linkedin: data['linkedin'],
      github: data['github'],
      twitter: data['twitter'],
      personalityAnswers: data['personalityAnswers'] != null
          ? Map<String, String>.from(data['personalityAnswers'])
          : null,
    );
  }

  // Renamed from fromFirestore to fromDocumentSnapshot for non-generic DocumentSnapshot
  factory UserModel.fromDocumentSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return UserModel(
      uid: snapshot.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      profession: data['profession'] ?? '',
      photoUrl: data['photoUrl'],
      bio: data['bio'],
      interests: (data['interests'] != null) ? List<String>.from(data['interests'] as List<dynamic>) : [],
      location: data['location'],
      company: data['company'],
      locationName: data['locationName'],
      lastActive: (data['lastActive'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      weekendInterests: (data['weekendInterests'] != null) ? List<String>.from(data['weekendInterests'] as List<dynamic>) : [],
      availability: Map<String, bool>.from(data['availability'] ?? {}),
      industry: data['industry'],
      skills: (data['skills'] != null) ? List<String>.from(data['skills'] as List<dynamic>) : [],
      openToNetworking: data['openToNetworking'] ?? true,
      friends: (data['friends'] != null) ? List<String>.from(data['friends'] as List<dynamic>) : [],
      pendingFriendRequests: (data['pendingFriendRequests'] != null) ? List<String>.from(data['pendingFriendRequests'] as List<dynamic>) : [],
      sentFriendRequests: (data['sentFriendRequests'] != null) ? List<String>.from(data['sentFriendRequests'] as List<dynamic>) : [],
      linkedin: data['linkedin'],
      github: data['github'],
      twitter: data['twitter'],
      personalityAnswers: data['personalityAnswers'] != null
          ? Map<String, String>.from(data['personalityAnswers'])
          : null,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      profession: data['profession'] ?? '',
      photoUrl: data['photoUrl'],
      bio: data['bio'],
      interests: (data['interests'] != null) ? List<String>.from(data['interests'] as List<dynamic>) : [],
      location: data['location'],
      company: data['company'],
      locationName: data['locationName'],
      // Handle Timestamp or String for lastActive
      lastActive: data['lastActive'] != null
          ? data['lastActive'] is Timestamp
          ? (data['lastActive'] as Timestamp).toDate()
          : data['lastActive'] is String
          ? DateTime.parse(data['lastActive'])
          : null
          : null,
      // Handle Timestamp or String for createdAt
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.parse(data['createdAt'] ?? DateTime.now().toIso8601String()),
      weekendInterests: (data['weekendInterests'] != null) ? List<String>.from(data['weekendInterests'] as List<dynamic>) : [],
      availability: Map<String, bool>.from(data['availability'] ?? {}),
      industry: data['industry'],
      skills: (data['skills'] != null) ? List<String>.from(data['skills'] as List<dynamic>) : [],
      openToNetworking: data['openToNetworking'] ?? true,
      friends: (data['friends'] != null) ? List<String>.from(data['friends'] as List<dynamic>) : [],
      pendingFriendRequests: (data['pendingFriendRequests'] != null) ? List<String>.from(data['pendingFriendRequests'] as List<dynamic>) : [],
      sentFriendRequests: (data['sentFriendRequests'] != null) ? List<String>.from(data['sentFriendRequests'] as List<dynamic>) : [],
      linkedin: data['linkedin'],
      github: data['github'],
      twitter: data['twitter'],
      personalityAnswers: data['personalityAnswers'] != null
          ? Map<String, String>.from(data['personalityAnswers'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'profession': profession,
      'photoUrl': photoUrl,
      'bio': bio,
      'interests': interests,
      'location': location,
      'company': company,
      'locationName': locationName,
      'lastActive': lastActive?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'weekendInterests': weekendInterests,
      'availability': availability,
      'industry': industry,
      'skills': skills,
      'openToNetworking': openToNetworking,
      'friends': friends,
      'pendingFriendRequests': pendingFriendRequests,
      'sentFriendRequests': sentFriendRequests,
      'linkedin': linkedin,
      'github': github,
      'twitter': twitter,
      'personalityAnswers': personalityAnswers,
    };
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
      'linkedin': linkedin,
      'github': github,
      'twitter': twitter,
      'personalityAnswers': personalityAnswers,
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
    String? linkedin,
    String? github,
    String? twitter,
    Map<String, String>? personalityAnswers,
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
      linkedin: linkedin ?? this.linkedin,
      github: github ?? this.github,
      twitter: twitter ?? this.twitter,
      personalityAnswers: personalityAnswers ?? this.personalityAnswers,
    );
  }
}