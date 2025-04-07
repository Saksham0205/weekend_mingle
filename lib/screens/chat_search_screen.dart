import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../utils/responsive_helper.dart';

class ChatSearchScreen extends StatefulWidget {
  final String chatId;
  final String chatName;

  const ChatSearchScreen({
    super.key,
    required this.chatId,
    required this.chatName,
  });

  @override
  State<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<ChatSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ChatService _chatService = ChatService();
  List<Message> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
    if (_searchQuery.length >= 2) {
      _performSearch();
    } else {
      setState(() {
        _searchResults = [];
      });
    }
  }

  Future<void> _performSearch() async {
    if (_searchQuery.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      // Get all messages for the chat
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .get();

      // Filter messages that contain the search query
      final filteredMessages = messagesSnapshot.docs
          .map((doc) => Message.fromFirestore(doc))
          .where((message) {
        final content = message.content.toLowerCase();
        return content.contains(_searchQuery.toLowerCase());
      }).toList();

      setState(() {
        _searchResults = filteredMessages;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching messages: $e')),
      );
    }
  }

  void _navigateToMessageContext(Message message) {
    // Close the search screen and return the message ID to navigate to
    Navigator.pop(context, message.id);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search in conversation...',
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: Colors.grey,
              fontSize: ResponsiveHelper.getResponsiveWidth(16),
            ),
          ),
          style: TextStyle(
            color: Colors.black,
            fontSize: ResponsiveHelper.getResponsiveWidth(16),
          ),
          autofocus: true,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
              },
            ),
        ],
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : _searchResults.isEmpty && _searchQuery.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: ResponsiveHelper.getResponsiveWidth(48),
                        color: Colors.grey,
                      ),
                      SizedBox(
                          height: ResponsiveHelper.getResponsiveHeight(16)),
                      Text(
                        'No messages found for "$_searchQuery"',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: ResponsiveHelper.getResponsiveWidth(16),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final message = _searchResults[index];
                    return _buildMessageItem(message);
                  },
                ),
    );
  }

  Widget _buildMessageItem(Message message) {
    // Highlight the search query in the message content
    final content = message.content;
    final query = _searchQuery.toLowerCase();
    final contentLower = content.toLowerCase();

    if (!contentLower.contains(query)) {
      return ListTile(
        title: Text(content),
        subtitle: Text(
          '${message.senderName} • ${_formatTimestamp(message.timestamp)}',
        ),
        onTap: () => _navigateToMessageContext(message),
      );
    }

    final startIndex = contentLower.indexOf(query);
    final endIndex = startIndex + query.length;

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: message.senderPhotoUrl != null
            ? NetworkImage(message.senderPhotoUrl!)
            : null,
        child: message.senderPhotoUrl == null
            ? Text(message.senderName[0].toUpperCase())
            : null,
      ),
      title: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: content.substring(0, startIndex),
              style: TextStyle(
                color: Colors.black,
                fontSize: ResponsiveHelper.getResponsiveWidth(16),
              ),
            ),
            TextSpan(
              text: content.substring(startIndex, endIndex),
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                backgroundColor: Colors.yellow.withOpacity(0.5),
                fontSize: ResponsiveHelper.getResponsiveWidth(16),
              ),
            ),
            TextSpan(
              text: content.substring(endIndex),
              style: TextStyle(
                color: Colors.black,
                fontSize: ResponsiveHelper.getResponsiveWidth(16),
              ),
            ),
          ],
        ),
      ),
      subtitle: Text(
        '${message.senderName} • ${_formatTimestamp(message.timestamp)}',
        style: TextStyle(
          color: Colors.grey,
          fontSize: ResponsiveHelper.getResponsiveWidth(14),
        ),
      ),
      onTap: () => _navigateToMessageContext(message),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
