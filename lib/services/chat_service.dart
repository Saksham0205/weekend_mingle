import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import 'dart:async';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get stream of chats for current user
  Stream<List<Chat>> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Chat.fromFirestore(doc)).toList();
    });
  }

  // Get messages for a specific chat
  Stream<List<Message>> getChatMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
    });
  }

  // Send a message to a chat
  Future<void> sendMessage({
    required String chatId,
    required String content,
    String? imageUrl,
    required String type,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Get user data
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = UserModel.fromFirestore(userDoc);

    // Create message
    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    final message = Message(
      id: messageRef.id,
      senderId: user.uid,
      senderName: userData.name,
      senderPhotoUrl: userData.photoUrl,
      content: content,
      imageUrl: imageUrl,
      timestamp: DateTime.now(),
      isRead: false,
      type: type,
      readBy: [user.uid],
    );

    // Update chat with last message info
    final chatRef = _firestore.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();
    final chatData = chatDoc.data() as Map<String, dynamic>;

    // Get all participants except sender
    final List<String> participants = List<String>.from(chatData['participants']);
    final Map<String, int> unreadCounts = Map<String, int>.from(chatData['unreadCounts'] ?? {});

    // Update unread counts for all participants except sender
    for (final participant in participants) {
      if (participant != user.uid) {
        unreadCounts[participant] = (unreadCounts[participant] ?? 0) + 1;
      }
    }

    // Batch write operations for both message and chat update
    final batch = _firestore.batch();

    // Add message
    batch.set(messageRef, message.toMap());

    // Update chat
    batch.update(chatRef, {
      'lastMessageText': content,
      'lastMessageAt': Timestamp.fromDate(DateTime.now()),
      'lastMessageSenderId': user.uid,
      'unreadCounts': unreadCounts,
    });

    await batch.commit();
  }

  // Create a new 1:1 chat or get existing chat between two users
  Future<String> createOrGetChat(String otherUserId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    // Check if a chat already exists between these two users
    final querySnapshot = await _firestore
        .collection('chats')
        .where('participants', arrayContains: user.uid)
        .where('isGroupChat', isEqualTo: false)
        .get();

    for (final doc in querySnapshot.docs) {
      final chat = Chat.fromFirestore(doc);
      if (chat.participants.contains(otherUserId) && chat.participants.length == 2) {
        return chat.id;
      }
    }

    // No existing chat, create a new one
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final currentUser = UserModel.fromFirestore(userDoc);

    final otherUserDoc = await _firestore.collection('users').doc(otherUserId).get();
    final otherUser = UserModel.fromFirestore(otherUserDoc);

    final chatRef = _firestore.collection('chats').doc();
    final chat = Chat(
      id: chatRef.id,
      participants: [user.uid, otherUserId],
      participantNames: {
        user.uid: currentUser.name,
        otherUserId: otherUser.name,
      },
      participantPhotos: {
        user.uid: currentUser.photoUrl,
        otherUserId: otherUser.photoUrl,
      },
      createdAt: DateTime.now(),
      lastMessageAt: DateTime.now(),
      lastMessageText: '',
      lastMessageSenderId: '',
      unreadCounts: {
        user.uid: 0,
        otherUserId: 0,
      },
      isGroupChat: false,
    );

    await chatRef.set(chat.toMap());
    return chat.id;
  }

  // Create a new group chat
  Future<String> createGroupChat({
    required String name,
    String? photoUrl,
    required List<String> memberIds,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    // Make sure the creator is included in members
    if (!memberIds.contains(user.uid)) {
      memberIds.add(user.uid);
    }

    // Get all member profiles to store names and photos
    final participantNames = <String, String>{};
    final participantPhotos = <String, String?>{};
    final unreadCounts = <String, int>{};

    for (final memberId in memberIds) {
      final memberDoc = await _firestore.collection('users').doc(memberId).get();
      final memberData = UserModel.fromFirestore(memberDoc);

      participantNames[memberId] = memberData.name;
      participantPhotos[memberId] = memberData.photoUrl;
      unreadCounts[memberId] = 0;
    }

    // Create the group chat
    final chatRef = _firestore.collection('chats').doc();
    final chat = Chat(
      id: chatRef.id,
      participants: memberIds,
      participantNames: participantNames,
      participantPhotos: participantPhotos,
      createdAt: DateTime.now(),
      lastMessageAt: DateTime.now(),
      lastMessageText: '',
      lastMessageSenderId: '',
      unreadCounts: unreadCounts,
      isGroupChat: true,
      groupName: name,
      groupPhotoUrl: photoUrl,
      creatorId: user.uid,
      admins: [user.uid],
    );

    await chatRef.set(chat.toMap());

    // Add system message about group creation
    final messageRef = chatRef.collection('messages').doc();
    final message = Message(
      id: messageRef.id,
      senderId: 'system',
      senderName: 'System',
      content: '${participantNames[user.uid]} created this group',
      timestamp: DateTime.now(),
      isRead: false,
      type: 'system',
      readBy: [],
    );

    await messageRef.set(message.toMap());

    return chat.id;
  }

  // Add members to group chat
  Future<void> addMembersToGroupChat({
    required String chatId,
    required List<String> memberIds,
  }) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();

    if (!chatDoc.exists) {
      throw Exception("Chat not found");
    }

    final chat = Chat.fromFirestore(chatDoc);

    if (!chat.isGroupChat) {
      throw Exception("Cannot add members to a non-group chat");
    }

    // Get current user for system message
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("User not authenticated");

    // Get the new members' data
    final participantNames = Map<String, String>.from(chat.participantNames);
    final participantPhotos = Map<String, String?>.from(chat.participantPhotos);
    final unreadCounts = Map<String, int>.from(chat.unreadCounts);
    final participants = List<String>.from(chat.participants);

    final newMembers = <String, String>{};

    for (final memberId in memberIds) {
      if (!participants.contains(memberId)) {
        participants.add(memberId);

        final memberDoc = await _firestore.collection('users').doc(memberId).get();
        final memberData = UserModel.fromFirestore(memberDoc);

        participantNames[memberId] = memberData.name;
        participantPhotos[memberId] = memberData.photoUrl;
        unreadCounts[memberId] = 0;
        newMembers[memberId] = memberData.name;
      }
    }

    if (newMembers.isEmpty) {
      return; // No new members to add
    }

    // Update the chat
    await chatRef.update({
      'participants': participants,
      'participantNames': participantNames,
      'participantPhotos': participantPhotos,
      'unreadCounts': unreadCounts,
    });

    // Add system message about added members
    final newMembersNames = newMembers.values.join(', ');
    final messageRef = chatRef.collection('messages').doc();
    final message = Message(
      id: messageRef.id,
      senderId: 'system',
      senderName: 'System',
      content: '${chat.participantNames[currentUser.uid]} added $newMembersNames to the group',
      timestamp: DateTime.now(),
      isRead: false,
      type: 'system',
      readBy: [],
    );

    await messageRef.set(message.toMap());
  }

  // Mark messages as read
  Future<void> markChatAsRead(String chatId, String userId) async {
    // Get chat to update unread count
    final chatRef = _firestore.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();

    if (!chatDoc.exists) return;

    final chat = Chat.fromFirestore(chatDoc);
    final unreadCounts = Map<String, int>.from(chat.unreadCounts);
    unreadCounts[userId] = 0;

    // Update the chat
    await chatRef.update({
      'unreadCounts': unreadCounts,
    });

    // Mark messages as read
    final batch = _firestore.batch();
    final messagesQuery = await chatRef
        .collection('messages')
        .where('readBy', arrayContains: userId)
        .where('senderId', isNotEqualTo: userId)
        .limit(100) // Limit for batch size
        .get();

    for (final doc in messagesQuery.docs) {
      final messageRef = chatRef.collection('messages').doc(doc.id);
      batch.update(messageRef, {
        'readBy': FieldValue.arrayUnion([userId]),
        'isRead': true,
      });
    }

    if (messagesQuery.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  // Leave a group chat
  Future<void> leaveGroupChat(String chatId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    final chatRef = _firestore.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();

    if (!chatDoc.exists) {
      throw Exception("Chat not found");
    }

    final chat = Chat.fromFirestore(chatDoc);

    if (!chat.isGroupChat) {
      throw Exception("Cannot leave a non-group chat");
    }

    if (!chat.participants.contains(user.uid)) {
      return; // Already not in the chat
    }

    // Remove from participants
    final participants = List<String>.from(chat.participants);
    participants.remove(user.uid);

    // Check if this was the last participant
    if (participants.isEmpty) {
      // Delete the entire chat if no participants left
      await chatRef.delete();
      return;
    }

    // Check if user was an admin and the only admin
    final admins = List<String>.from(chat.admins ?? []);
    if (admins.contains(user.uid)) {
      admins.remove(user.uid);

      // If this was the last admin, make the first participant an admin
      if (admins.isEmpty && participants.isNotEmpty) {
        admins.add(participants[0]);
      }
    }

    // Update participant maps
    final participantNames = Map<String, String>.from(chat.participantNames);
    final participantPhotos = Map<String, String?>.from(chat.participantPhotos);
    final unreadCounts = Map<String, int>.from(chat.unreadCounts);

    participantNames.remove(user.uid);
    participantPhotos.remove(user.uid);
    unreadCounts.remove(user.uid);

    // Update the chat
    await chatRef.update({
      'participants': participants,
      'participantNames': participantNames,
      'participantPhotos': participantPhotos,
      'unreadCounts': unreadCounts,
      'admins': admins,
    });

    // Add system message about user leaving
    final messageRef = chatRef.collection('messages').doc();
    final message = Message(
      id: messageRef.id,
      senderId: 'system',
      senderName: 'System',
      content: '${chat.participantNames[user.uid]} left the group',
      timestamp: DateTime.now(),
      isRead: false,
      type: 'system',
      readBy: [],
    );

    await messageRef.set(message.toMap());
  }
}