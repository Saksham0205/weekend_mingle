import '../base/base_state.dart';
import '../../models/chat_model.dart';
import '../../models/message_model.dart';

abstract class ChatState extends BaseState {}

class ChatInitialState extends ChatState {}

class ChatLoadingState extends ChatState {}

class ChatsLoadedState extends ChatState {
  final List<Chat> chats;

  ChatsLoadedState(this.chats);
}

class ChatMessagesLoadedState extends ChatState {
  final String chatId;
  final List<Message> messages;

  ChatMessagesLoadedState(this.chatId, this.messages);
}

class MessageSentState extends ChatState {
  final String chatId;
  final Message message;

  MessageSentState(this.chatId, this.message);
}

class ChatCreatedState extends ChatState {
  final Chat chat;

  ChatCreatedState(this.chat);
}

class ChatUpdatedState extends ChatState {
  final String chatId;
  final Map<String, dynamic> updateData;

  ChatUpdatedState(this.chatId, this.updateData);
}

class ChatErrorState extends ChatState {
  final String message;

  ChatErrorState(this.message);
}
