import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter_chat_bubble/chat_bubble.dart';
import 'package:flutter_chat_bubble/bubble_type.dart';
import 'package:animate_do/animate_do.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/cloudinary_services.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';

class ChatScreen extends StatefulWidget {
  final UserModel? otherUser;
  final String chatId;
  final String otherUserName;
  final bool isGroupChat;

  const ChatScreen({
    super.key,
    this.otherUser,
    required this.chatId,
    required this.otherUserName,
    this.isGroupChat = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _authService = AuthService();
  final _userService = UserService();
  final _chatService = ChatService();
  bool _isCheckingFriendship = true;
  bool _isSendingMessage = false;
  bool _isTyping = false;
  bool _showEmoji = false;
  Timer? _typingTimer;
  bool _isFriend = false;
  List<Message> _messages = [];
  bool _isLoading = true;
  StreamSubscription? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _checkFriendshipStatus();
    _markMessagesAsRead();
    _messageController.addListener(_onTypingChanged);
    _setupMessagesListener();
  }

  void _setupMessagesListener() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    _messagesSubscription = _chatService.getChatMessages(widget.chatId)
        .listen((messages) {
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });

        // Mark messages as read when new messages arrive
        _markMessagesAsRead();
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTypingChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _messagesSubscription?.cancel();
    super.dispose();
  }

  void _onTypingChanged() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    if (_messageController.text.isNotEmpty && !_isTyping) {
      setState(() => _isTyping = true);
      FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({'${currentUser.uid}_typing': true});
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        setState(() => _isTyping = false);
        FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .update({'${currentUser.uid}_typing': false});
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _markMessagesAsRead() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();

      if (chatDoc.exists) {
        await chatDoc.reference.update({
          'unreadCount${currentUser.uid}': 0,
        });
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  Future<void> _checkFriendshipStatus() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    // For group chats, we don't need to check friendship
    if (widget.isGroupChat || widget.otherUser == null) {
      setState(() {
        _isFriend = true;
        _isCheckingFriendship = false;
      });
      return;
    }

    final isFriend = await _userService.areFriends(
      currentUser.uid,
      widget.otherUser!.uid,
    );

    if (mounted) {
      setState(() {
        _isFriend = isFriend;
        _isCheckingFriendship = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final imageFile = File(image.path);
        await _sendFile(imageFile, 'image');
      }
    } catch (e) {
      _showErrorSnackbar('Error picking image: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null) {
        final file = File(result.files.single.path!);
        await _sendFile(file, 'file');
      }
    } catch (e) {
      _showErrorSnackbar('Error picking file: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendFile(File file, String type) async {
    setState(() => _isSendingMessage = true);

    try {
      final url = await CloudinaryService.uploadFile(file);
      if (url != null) {
        await _sendMessage(
          text: type == 'image' ? null : '📎 File',
          fileUrl: url,
          fileType: type,
        );
      }
    } catch (e) {
      _showErrorSnackbar('Error uploading file: $e');
    } finally {
      setState(() => _isSendingMessage = false);
    }
  }

  Future<void> _sendMessage({
    String? text,
    String? fileUrl,
    String? fileType,
  }) async {
    if ((text == null || text.isEmpty) && fileUrl == null) return;

    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    setState(() => _isSendingMessage = true);

    try {
      await _chatService.sendMessage(
        chatId: widget.chatId,
        content: text ?? '',
        imageUrl: fileUrl,
        type: fileType ?? 'text',
      );

      _messageController.clear();
      _scrollToBottom();

      // Send push notification - only for direct messages
      if (!widget.isGroupChat && widget.otherUser != null) {
        await NotificationService.sendNotification(
          userId: widget.otherUser!.uid,
          title: 'New message from ${currentUser.displayName}',
          body: text ?? (fileType == 'image' ? '📷 Photo' : '📎 File'),
          data: {
            'type': 'chat_message',
            'chatId': widget.chatId,
            'senderId': currentUser.uid,
          },
        );
      }
    } catch (e) {
      _showErrorSnackbar('Error sending message: $e');
    } finally {
      setState(() => _isSendingMessage = false);
    }
  }

  Future<void> _addReaction(String messageId, String emoji) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    try {
      final messageRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(messageId);

      await messageRef.update({
        'reactions.${currentUser.uid}': emoji,
      });
    } catch (e) {
      _showErrorSnackbar('Error adding reaction: $e');
    }
  }

  Future<void> _blockUser() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'blockedUsers': FieldValue.arrayUnion([widget.otherUser!.uid]),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User blocked successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showErrorSnackbar('Error blocking user: $e');
    }
  }

  Future<void> _reportUser() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select a reason for reporting:'),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Inappropriate content'),
              onTap: () => Navigator.pop(context, 'inappropriate_content'),
            ),
            ListTile(
              title: const Text('Harassment'),
              onTap: () => Navigator.pop(context, 'harassment'),
            ),
            ListTile(
              title: const Text('Spam'),
              onTap: () => Navigator.pop(context, 'spam'),
            ),
            ListTile(
              title: const Text('Other'),
              onTap: () => Navigator.pop(context, 'other'),
            ),
          ],
        ),
      ),
    );

    if (reason != null) {
      try {
        await FirebaseFirestore.instance.collection('reports').add({
          'reportedUser': widget.otherUser!.uid,
          'reportedBy': _authService.currentUser?.uid,
          'reason': reason,
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report submitted successfully'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        _showErrorSnackbar('Error submitting report: $e');
      }
    }
  }

  void _showReactionPicker(String messageId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              height: 5,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add Reaction',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  Navigator.pop(context);
                  _addReaction(messageId, emoji.emoji);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 5,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _attachmentOption(
                  icon: Icons.photo,
                  label: 'Gallery',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage();
                  },
                ),
                _attachmentOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    // Implement camera functionality
                  },
                ),
                _attachmentOption(
                  icon: Icons.attach_file,
                  label: 'Document',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _pickFile();
                  },
                ),
                _attachmentOption(
                  icon: Icons.location_on,
                  label: 'Location',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    // Implement location sharing
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _attachmentOption(
                  icon: Icons.person,
                  label: 'Contact',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    // Implement contact sharing
                  },
                ),
                _attachmentOption(
                  icon: Icons.music_note,
                  label: 'Audio',
                  color: Colors.pink,
                  onTap: () {
                    Navigator.pop(context);
                    // Implement audio recording/sharing
                  },
                ),
                _attachmentOption(
                  icon: Icons.sticky_note_2,
                  label: 'Poll',
                  color: Colors.teal,
                  onTap: () {
                    Navigator.pop(context);
                    // Implement poll creation
                  },
                ),
                _attachmentOption(
                  icon: Icons.more_horiz,
                  label: 'More',
                  color: Colors.grey,
                  onTap: () {
                    Navigator.pop(context);
                    // Show more options
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(String messageId) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    try {
      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Message'),
          content: const Text('Are you sure you want to delete this message?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Get the message before deleting it (to update the last message if needed)
      final messageDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(messageId)
          .get();

      // Delete the message
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(messageId)
          .delete();

      // Check if the deleted message was the last message in the chat
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();

      final chatData = chatDoc.data();
      if (chatData != null) {
        final lastMessageSenderId = chatData['lastMessageSenderId'] as String?;
        final lastMessageTime = chatData['lastMessageTime'] as Timestamp?;

        // If the deleted message was the last message
        if (lastMessageSenderId == currentUser.uid &&
            messageDoc.data()?['timestamp'] == lastMessageTime) {

          // Find the new last message
          final lastMessageQuery = await FirebaseFirestore.instance
              .collection('chats')
              .doc(widget.chatId)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

          if (lastMessageQuery.docs.isNotEmpty) {
            final newLastMessage = lastMessageQuery.docs.first;
            final newLastMessageData = newLastMessage.data();

            // Update the chat document with the new last message
            final displayText = newLastMessageData['text'] ??
                (newLastMessageData['fileType'] == 'image' ? '📷 Photo' : '📎 File');

            await FirebaseFirestore.instance
                .collection('chats')
                .doc(widget.chatId)
                .update({
              'lastMessage': displayText,
              'lastMessageTime': newLastMessageData['timestamp'],
              'lastMessageSenderId': newLastMessageData['senderId'],
            });
          } else {
            // If no messages left, update with empty values
            await FirebaseFirestore.instance
                .collection('chats')
                .doc(widget.chatId)
                .update({
              'lastMessage': 'No messages yet',
              'lastMessageTime': FieldValue.serverTimestamp(),
              'lastMessageSenderId': '',
            });
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackbar('Error deleting message: $e');
    }
  }
  Future<void> _deleteEntireChat() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    try {
      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Conversation'),
          content: Text('Are you sure you want to delete your entire chat with ${widget.otherUserName}? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // Get all messages in batches (Firestore limits batch size)
      final messagesQuery = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .get();

      // Use batched writes for better performance
      // Firestore has a limit of 500 operations per batch
      const batchLimit = 450;
      int operationCount = 0;
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (final doc in messagesQuery.docs) {
        batch.delete(doc.reference);
        operationCount++;

        // If we're approaching the batch limit, commit and create a new batch
        if (operationCount >= batchLimit) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          operationCount = 0;
        }
      }

      // Commit any remaining operations
      if (operationCount > 0) {
        await batch.commit();
      }

      // Finally, delete the chat document itself
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .delete();

      // Dismiss loading dialog and navigate back
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat deleted successfully'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Dismiss loading dialog if there was an error
      if (mounted) {
        Navigator.of(context).pop();
        _showErrorSnackbar('Error deleting chat: $e');
      }
    }
  }

  void _showMessageOptions(String messageId, bool isCurrentUserMessage) {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 5,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.emoji_emotions_outlined),
              title: const Text('React to message'),
              onTap: () {
                Navigator.pop(context);
                _showReactionPicker(messageId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                // Implement reply functionality in the future
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Copy text'),
              onTap: () {
                Navigator.pop(context);
                // Find message text and copy to clipboard
                final message = _messages.firstWhere((m) => m.id == messageId).data();
                if (message['text'] != null && message['text'].isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: message['text'] as String));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Text copied to clipboard'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            // Only show delete option for messages sent by the current user
            if (isCurrentUserMessage)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete message', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(messageId);
                },
              ),
          ],
        ),
      ),
    );
  }
  Widget _attachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              size: 30,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
      Map<String, dynamic> message,
      bool isCurrentUser,
      bool isFirstInGroup,
      bool isLastInGroup,
      String messageId,
      DateTime? timestamp,
      ) {
    final radius = isFirstInGroup ? 20.0 : 5.0;
    final bubbleMargin = isFirstInGroup
        ? const EdgeInsets.only(top: 10)
        : const EdgeInsets.only(top: 2);

    return FadeIn(
      duration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(
          messageId,
          isCurrentUser,
        ),
        child: Padding(
          padding: bubbleMargin,
          child: Row(
            mainAxisAlignment: isCurrentUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Show avatar only for other user's messages and if it's the last in group
              if (!isCurrentUser && isLastInGroup)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    backgroundImage: widget.otherUser!.photoUrl != null &&
                        widget.otherUser!.photoUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(widget.otherUser!.photoUrl!)
                    as ImageProvider
                        : null,
                    child: widget.otherUser!.photoUrl == null ||
                        widget.otherUser!.photoUrl!.isEmpty
                        ? Text(
                      widget.otherUserName[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    )
                        : null,
                  ),
                )
              // Add a placeholder space when the avatar isn't shown
              else if (!isCurrentUser)
                const SizedBox(width: 32),

              // The message content column - this should always be shown
              Flexible(  // Make this flexible to ensure proper layout
                child: Column(
                  crossAxisAlignment:
                  isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    ChatBubble(
                      clipper: ChatBubbleClipper5(
                        type: isCurrentUser
                            ? BubbleType.sendBubble
                            : BubbleType.receiverBubble,
                        radius: radius,
                      ),
                      alignment: isCurrentUser ? Alignment.topRight : Alignment.topLeft,
                      margin: const EdgeInsets.only(top: 2),
                      backGroundColor: isCurrentUser
                          ? Theme.of(context).primaryColor
                          : Colors.grey[100],
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.65,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (message['text'] != null && message['text'].isNotEmpty)
                              Text(
                                message['text'] as String,
                                style: TextStyle(
                                  color: isCurrentUser ? Colors.white : Colors.black87,
                                ),
                              ),
                            if (message['fileUrl'] != null) ...[
                              // Rest of your file handling code
                            ],
                            // Reactions display code
                          ],
                        ),
                      ),
                    ),
                    // Timestamp display
                  ],
                ),
              ),
              // Add some spacing at the end for current user messages
              if (isCurrentUser)
                const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leadingWidth: 30,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Hero(
              tag: 'chat-${widget.otherUser!.uid}',
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                backgroundImage: widget.otherUser!.photoUrl != null &&
                    widget.otherUser!.photoUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(widget.otherUser!.photoUrl!)
                as ImageProvider
                    : null,
                child: widget.otherUser!.photoUrl == null ||
                    widget.otherUser!.photoUrl!.isEmpty
                    ? Text(
                  widget.otherUserName[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  // TODO: Navigate to user profile
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherUserName,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('chats')
                          .doc(widget.chatId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();

                        final data = snapshot.data?.data() as Map<String, dynamic>?;
                        final isTyping =
                            data?['${widget.otherUser!.uid}_typing'] as bool? ?? false;

                        return Text(
                          isTyping ? 'typing...' : widget.otherUser!.profession,
                          style: TextStyle(
                            fontSize: 12,
                            color: isTyping ? Theme.of(context).primaryColor : Colors.grey,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.black87),
            onPressed: () {
              // TODO: Implement video call
            },
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Colors.black87),
            onPressed: () {
              // TODO: Implement voice call
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              color: Colors.black87,
            ),
            onSelected: (value) {
              switch (value) {
                case 'block':
                  _blockUser();
                  break;
                case 'report':
                  _reportUser();
                  break;
                case 'search':
                // TODO: Implement search in conversation
                  break;
                case 'mute':
                // TODO: Implement notifications muting
                  break;
                case 'wallpaper':
                // TODO: Implement chat wallpaper change
                  break;
                case 'delete_chat':
                  _deleteEntireChat();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'search',
                child: Text('Search'),
              ),
              const PopupMenuItem(
                value: 'mute',
                child: Text('Mute notifications'),
              ),
              const PopupMenuItem(
                value: 'wallpaper',
                child: Text('Chat wallpaper'),
              ),
              const PopupMenuItem(
                value: 'block',
                child: Text('Block User'),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Text('Report User'),
              ),
              const PopupMenuItem(
                value: 'delete_chat',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Chat', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
      body: Container(
        child: _isCheckingFriendship
            ? const Center(child: CircularProgressIndicator())
            : !_isFriend
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Messaging not available',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You can only message users who have\naccepted your friend request.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        )
            : Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No messages yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start the conversation with ${widget.otherUserName}!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index].data;
                  final messageId = _messages[index].id;
                  final isCurrentUser = message['senderId'] == currentUser.uid;
                  final timestamp = message['timestamp'] != null
                      ? (message['timestamp'] as Timestamp).toDate()
                      : null;

                  // Determine if this message is part of a group
                  bool isFirstInGroup = true;
                  bool isLastInGroup = true;

                  if (index > 0) {
                    final prevMessage = _messages[index - 1].data;
                    isFirstInGroup = prevMessage['senderId'] != message['senderId'];
                  }

                  if (index < _messages.length - 1) {
                    final nextMessage = _messages[index + 1].data;
                    isLastInGroup = nextMessage['senderId'] != message['senderId'];
                  }

                  return _buildMessageBubble(
                    message,
                    isCurrentUser,
                    isFirstInGroup,
                    isLastInGroup,
                    messageId,
                    timestamp,
                  );
                },
              ),
            ),
            Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showEmoji = !_showEmoji;
                      });
                    },
                    icon: Icon(
                      _showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined,
                      color: Colors.grey[600],
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      onSubmitted: (text) {
                        if (text.isNotEmpty) {
                          _sendMessage(text: text);
                        }
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: _showAttachmentOptions,
                    icon: Icon(
                      Icons.attach_file,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 2),
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _messageController.text.isEmpty
                          ? () {
                        // Implement voice message recording
                      }
                          : _isSendingMessage
                          ? null
                          : () => _sendMessage(text: _messageController.text),
                      icon: _isSendingMessage
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Icon(
                        _messageController.text.isEmpty
                            ? Icons.mic
                            : Icons.send,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_showEmoji)
              SizedBox(
                height: 250,
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    _messageController.text =
                        _messageController.text + emoji.emoji;
                    _messageController.selection =
                        TextSelection.fromPosition(TextPosition(
                            offset: _messageController.text.length));
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatMessageTime(Timestamp timestamp) {
    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);

    if (difference.inDays > 0) {
      return '${messageTime.hour}:${messageTime.minute.toString().padLeft(2, '0')} ${messageTime.day}/${messageTime.month}';
    } else {
      return '${messageTime.hour}:${messageTime.minute.toString().padLeft(2, '0')}';
    }
  }
}