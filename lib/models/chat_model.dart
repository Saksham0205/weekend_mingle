import 'package:cloud_firestore/cloud_firestore.dart';

class Chat {
  final String id;
  final List<String> participants; // List of user IDs
  final Map<String, String> participantNames; // Map of user ID to name
  final Map<String, String?> participantPhotos; // Map of user ID to photo URL
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final String lastMessageText;
  final String lastMessageSenderId;
  final Map<String, int> unreadCounts; // Map of user ID to unread count
  final bool isGroupChat;
  final String? groupName;
  final String? groupPhotoUrl;
  final String? creatorId; // For group chats
  final List<String>? admins; // Admin user IDs for group chats

  Chat({
    required this.id,
    required this.participants,
    required this.participantNames,
    required this.participantPhotos,
    required this.createdAt,
    required this.lastMessageAt,
    required this.lastMessageText,
    required this.lastMessageSenderId,
    required this.unreadCounts,
    required this.isGroupChat,
    this.groupName,
    this.groupPhotoUrl,
    this.creatorId,
    this.admins,
  });

  factory Chat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Chat(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      participantNames: Map<String, String>.from(data['participantNames'] ?? {}),
      participantPhotos: Map<String, String?>.from(data['participantPhotos'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastMessageAt: (data['lastMessageAt'] as Timestamp).toDate(),
      lastMessageText: data['lastMessageText'] ?? '',
      lastMessageSenderId: data['lastMessageSenderId'] ?? '',
      unreadCounts: Map<String, int>.from(data['unreadCounts'] ?? {}),
      isGroupChat: data['isGroupChat'] ?? false,
      groupName: data['groupName'],
      groupPhotoUrl: data['groupPhotoUrl'],
      creatorId: data['creatorId'],
      admins: data['admins'] != null ? List<String>.from(data['admins']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'participantNames': participantNames,
      'participantPhotos': participantPhotos,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessageAt': Timestamp.fromDate(lastMessageAt),
      'lastMessageText': lastMessageText,
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCounts': unreadCounts,
      'isGroupChat': isGroupChat,
      'groupName': groupName,
      'groupPhotoUrl': groupPhotoUrl,
      'creatorId': creatorId,
      'admins': admins,
    };
  }

  // Helper method to get the name of the other participant in a 1:1 chat
  String getOtherParticipantName(String currentUserId) {
    if (isGroupChat) return groupName ?? 'Group Chat';

    for (String userId in participants) {
      if (userId != currentUserId) {
        return participantNames[userId] ?? 'Unknown';
      }
    }
    return 'Unknown';
  }

  // Helper method to get the photo of the other participant in a 1:1 chat
  String? getOtherParticipantPhoto(String currentUserId) {
    if (isGroupChat) return groupPhotoUrl;

    for (String userId in participants) {
      if (userId != currentUserId) {
        return participantPhotos[userId];
      }
    }
    return null;
  }

  // Helper method to get chat display name based on current user
  String getChatDisplayName(String currentUserId) {
    if (isGroupChat) return groupName ?? 'Group Chat';
    return getOtherParticipantName(currentUserId);
  }

  // Helper method to get chat photo based on current user
  String? getChatDisplayPhoto(String currentUserId) {
    if (isGroupChat) return groupPhotoUrl;
    return getOtherParticipantPhoto(currentUserId);
  }

  // Helper method to check if a user is a chat admin
  bool isAdmin(String userId) {
    if (!isGroupChat) return false;
    return admins?.contains(userId) ?? false;
  }

  // Get unread count for a specific user
  int getUnreadCountForUser(String userId) {
    return unreadCounts[userId] ?? 0;
  }

  Chat copyWith({
    String? id,
    List<String>? participants,
    Map<String, String>? participantNames,
    Map<String, String?>? participantPhotos,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    String? lastMessageText,
    String? lastMessageSenderId,
    Map<String, int>? unreadCounts,
    bool? isGroupChat,
    String? groupName,
    String? groupPhotoUrl,
    String? creatorId,
    List<String>? admins,
  }) {
    return Chat(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      participantNames: participantNames ?? this.participantNames,
      participantPhotos: participantPhotos ?? this.participantPhotos,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      isGroupChat: isGroupChat ?? this.isGroupChat,
      groupName: groupName ?? this.groupName,
      groupPhotoUrl: groupPhotoUrl ?? this.groupPhotoUrl,
      creatorId: creatorId ?? this.creatorId,
      admins: admins ?? this.admins,
    );
  }
}