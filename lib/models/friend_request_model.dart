import 'package:cloud_firestore/cloud_firestore.dart';

class FriendRequestModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime createdAt;

  FriendRequestModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
  });

  factory FriendRequestModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options,
      ) {
    final data = snapshot.data()!;
    return FriendRequestModel(
      id: snapshot.id,
      senderId: data['senderId'],
      receiverId: data['receiverId'],
      status: data['status'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}