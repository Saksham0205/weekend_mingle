import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_services.dart';
import '../services/notification_service.dart';

class ChatScreen extends StatefulWidget {
  final UserModel otherUser;
  final String chatId;

  const ChatScreen({
    super.key,
    required this.otherUser,
    required this.chatId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isTyping = false;
  bool _showEmoji = false;
  Timer? _typingTimer;
  final Map<String, AnimationController> _messageAnimations = {};

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
    _messageController.addListener(_onTypingChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTypingChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    for (final controller in _messageAnimations.values) {
      controller.dispose();
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  Future<void> _sendFile(File file, String type) async {
    setState(() => _isLoading = true);

    try {
      final url = await CloudinaryService.uploadFile(file);
      if (url != null) {
        await _sendMessage(
          text: type == 'image' ? '📷 Photo' : '📎 File',
          fileUrl: url,
          fileType: type,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading file: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
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

    setState(() => _isLoading = true);

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      final messageRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc();

      final messageData = {
        'text': text,
        'fileUrl': fileUrl,
        'fileType': fileType,
        'senderId': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'reactions': {},
      };

      batch.set(messageRef, messageData);

      final chatData = {
        'lastMessage': text ?? (fileType == 'image' ? '📷 Photo' : '📎 File'),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'participants': [currentUser.uid, widget.otherUser.uid],
        'unreadCount${widget.otherUser.uid}':
        ((chatDoc.data()?['unreadCount${widget.otherUser.uid}'] ?? 0) as int) + 1,
      };

      batch.set(
        FirebaseFirestore.instance.collection('chats').doc(widget.chatId),
        chatData,
        SetOptions(merge: true),
      );

      await batch.commit();
      _messageController.clear();
      _scrollToBottom();

      // Send push notification
      await NotificationService.sendNotification(
        userId: widget.otherUser.uid,
        title: 'New message from ${currentUser.displayName}',
        body: text ?? (fileType == 'image' ? '📷 Photo' : '📎 File'),
        data: {
          'chatId': widget.chatId,
          'senderId': currentUser.uid,
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding reaction: $e')),
      );
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
        'blockedUsers': FieldValue.arrayUnion([widget.otherUser.uid]),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User blocked successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error blocking user: $e')),
      );
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
          'reportedUser': widget.otherUser.uid,
          'reportedBy': _authService.currentUser?.uid,
          'reason': reason,
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report submitted successfully')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting report: $e')),
        );
      }
    }
  }

  void _showReactionPicker(String messageId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('File'),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).primaryColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Hero(
              tag: 'chat-${widget.otherUser.uid}',
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                backgroundImage: widget.otherUser.photoUrl != null &&
                    widget.otherUser.photoUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(widget.otherUser.photoUrl!)
                as ImageProvider
                    : null,
                child: widget.otherUser.photoUrl == null ||
                    widget.otherUser.photoUrl!.isEmpty
                    ? Text(
                  widget.otherUser.name[0].toUpperCase(),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUser.name,
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
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
                      final isTyping = data?['${widget.otherUser.uid}_typing'] as bool? ?? false;

                      return Text(
                        isTyping ? 'Typing...' : widget.otherUser.profession,
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
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: Theme.of(context).primaryColor,
            ),
            onSelected: (value) {
              switch (value) {
                case 'block':
                  _blockUser();
                  break;
                case 'report':
                  _reportUser();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'block',
                child: Text('Block User'),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Text('Report User'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final messages = snapshot.data!.docs;
                final currentUser = _authService.currentUser;

                if (messages.isEmpty) {
                  return Center(
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
                          'Start the conversation!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data();
                    final messageId = messages[index].id;
                    final isMe = message['senderId'] == currentUser?.uid;
                    final timestamp = message['timestamp'] as Timestamp?;
                    final reactions = (message['reactions'] as Map?)?.cast<String, String>() ?? {};

                    if (!_messageAnimations.containsKey(messageId)) {
                      _messageAnimations[messageId] = AnimationController(
                        vsync: this,
                        duration: const Duration(milliseconds: 500),
                      )..forward();
                    }

                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(isMe ? 1 : -1, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _messageAnimations[messageId]!,
                        curve: Curves.easeOutQuad,
                      )),
                      child: GestureDetector(
                        onLongPress: () => _showReactionPicker(messageId),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment:
                            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: isMe
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                                children: [
                                  if (!isMe) ...[
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Theme.of(context)
                                          .primaryColor
                                          .withOpacity(0.1),
                                      backgroundImage: widget.otherUser.photoUrl != null &&
                                          widget.otherUser.photoUrl!.isNotEmpty
                                          ? CachedNetworkImageProvider(
                                          widget.otherUser.photoUrl!) as ImageProvider
                                          : null,
                                      child: widget.otherUser.photoUrl == null ||
                                          widget.otherUser.photoUrl!.isEmpty
                                          ? Text(
                                        widget.otherUser.name[0].toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color:
                                          Theme.of(context).primaryColor,
                                        ),
                                      )
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? Theme.of(context).primaryColor
                                            : Colors.grey[200],
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(16),
                                          topRight: const Radius.circular(16),
                                          bottomLeft:
                                          Radius.circular(isMe ? 16 : 4),
                                          bottomRight:
                                          Radius.circular(isMe ? 4 : 16),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          if (message['fileUrl'] != null) ...[
                                            if (message['fileType'] == 'image')
                                              ClipRRect(
                                                borderRadius:
                                                BorderRadius.circular(8),
                                                child: CachedNetworkImage(
                                                  imageUrl: message['fileUrl'],
                                                  placeholder: (context, url) =>
                                                  const Center(
                                                    child:
                                                    CircularProgressIndicator(),
                                                  ),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                  const Icon(Icons.error),
                                                ),
                                              )
                                            else
                                              OutlinedButton.icon(
                                                onPressed: () {
                                                  // TODO: Download file
                                                },
                                                icon: const Icon(
                                                    Icons.attach_file),
                                                label: const Text('Download File'),
                                              ),
                                            const SizedBox(height: 8),
                                          ],
                                          if (message['text'] != null)
                                            Text(
                                              message['text'],
                                              style: TextStyle(
                                                color: isMe
                                                    ? Colors.white
                                                    : Colors.black87,
                                                fontSize: 16,
                                              ),
                                            ),
                                          if (timestamp != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatMessageTime(timestamp),
                                              style: TextStyle(
                                                color: isMe
                                                    ? Colors.white.withOpacity(0.7)
                                                    : Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isMe) const SizedBox(width: 24),
                                ],
                              ),
                              if (reactions.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: isMe ? 0 : 40,
                                    right: isMe ? 24 : 0,
                                    top: 4,
                                  ),
                                  child: Wrap(
                                    spacing: 4,
                                    children: reactions.entries
                                        .map(
                                          (e) => Tooltip(
                                        message: e.key == currentUser?.uid
                                            ? 'You'
                                            : e.key == widget.otherUser.uid
                                            ? widget.otherUser.name
                                            : 'User',
                                        child: Text(
                                          e.value,
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    )
                                        .toList(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      color: Theme.of(context).primaryColor,
                      onPressed: _showAttachmentOptions,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showEmoji
                                  ? Icons.keyboard
                                  : Icons.emoji_emotions_outlined,
                            ),
                            onPressed: () {
                              setState(() => _showEmoji = !_showEmoji);
                            },
                          ),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: _isLoading
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.send),
                      color: Theme.of(context).primaryColor,
                      onPressed:
                      _isLoading ? null : () => _sendMessage(text: _messageController.text),
                    ),
                  ],
                ),
                if (_showEmoji)
                  SizedBox(
                    height: 250,
                    child: EmojiPicker(
                      onEmojiSelected: (category, emoji) {
                        _messageController
                          ..text += emoji.emoji
                          ..selection = TextSelection.fromPosition(
                            TextPosition(offset: _messageController.text.length),
                          );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
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