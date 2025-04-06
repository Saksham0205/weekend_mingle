import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String content;
  final String? imageUrl;
  final DateTime timestamp;
  final List<String> likes;
  final List<Comment> comments;
  final Map<String, dynamic>? additionalInfo;

  Post({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.content,
    this.imageUrl,
    required this.timestamp,
    required this.likes,
    required this.comments,
    this.additionalInfo,
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    List<Comment> commentsList = [];
    if (data['comments'] != null) {
      commentsList = List<Comment>.from(
        (data['comments'] as List).map(
          (comment) => Comment.fromMap(comment),
        ),
      );
    }

    return Post(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userPhotoUrl: data['userPhotoUrl'],
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      likes: List<String>.from(data['likes'] ?? []),
      comments: commentsList,
      additionalInfo: data['additionalInfo'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'content': content,
      'imageUrl': imageUrl,
      'timestamp': Timestamp.fromDate(timestamp),
      'likes': likes,
      'comments': comments.map((comment) => comment.toMap()).toList(),
      'additionalInfo': additionalInfo,
    };
  }
}

class Comment {
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String content;
  final DateTime timestamp;

  Comment({
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.content,
    required this.timestamp,
  });

  factory Comment.fromMap(Map<String, dynamic> data) {
    return Comment(
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userPhotoUrl: data['userPhotoUrl'],
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
