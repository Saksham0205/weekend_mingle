import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String content;
  final String? imageUrl;
  final String? voiceUrl; // URL for voice messages
  final int? voiceDuration; // Duration of voice message in seconds
  final DateTime timestamp;
  final bool isRead;
  final String type; // 'text', 'image', 'emoji', 'voice', etc.
  final List<String> readBy; // List of user IDs who have read the message
  final List<String> deliveredTo; // List of user IDs who received the message

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.content,
    this.imageUrl,
    this.voiceUrl,
    this.voiceDuration,
    required this.timestamp,
    required this.isRead,
    required this.type,
    required this.readBy,
    required this.deliveredTo,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderPhotoUrl: data['senderPhotoUrl'],
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'],
      voiceUrl: data['voiceUrl'],
      voiceDuration: data['voiceDuration'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      type: data['type'] ?? 'text',
      readBy: List<String>.from(data['readBy'] ?? []),
      deliveredTo: List<String>.from(data['deliveredTo'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'senderId': senderId,
    'senderName': senderName,
    'senderPhotoUrl': senderPhotoUrl,
    'content': content,
    'imageUrl': imageUrl,
    'voiceUrl': voiceUrl,
    'voiceDuration': voiceDuration,
    'timestamp': Timestamp.fromDate(timestamp),
    'isRead': isRead,
    'type': type,
    'readBy': readBy,
    'deliveredTo': deliveredTo,
  };

  Message copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderPhotoUrl,
    String? content,
    String? imageUrl,
    DateTime? timestamp,
    bool? isRead,
    String? type,
    List<String>? readBy,
    List<String>? deliveredTo,
    String? voiceUrl,
    int? voiceDuration,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      readBy: readBy ?? this.readBy,
      deliveredTo: deliveredTo ?? this.deliveredTo,
      voiceUrl: voiceUrl ?? this.voiceUrl,
      voiceDuration: voiceDuration ?? this.voiceDuration,
    );
  }
}
