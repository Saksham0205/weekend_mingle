import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/chat_model.dart';
import '../../models/message_model.dart';
import '../../services/chat_service.dart';
import '../base/base_bloc.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends BaseBloc<ChatEvent, ChatState> {
  final ChatService _chatService;

  ChatBloc(this._chatService) : super(ChatInitialState()) {
    on<LoadChatsEvent>(_handleLoadChats);
    on<SendMessageEvent>(_handleSendMessage);
    on<LoadChatMessagesEvent>(_handleLoadChatMessages);
    on<CreateChatEvent>(_handleCreateChat);
    on<UpdateChatEvent>(_handleUpdateChat);
  }

  Future<void> _handleLoadChats(
      LoadChatsEvent event, Emitter<ChatState> emit) async {
    try {
      emit(ChatLoadingState());
      final userId = _chatService._auth.currentUser?.uid;
      if (userId == null) {
        emit(ChatErrorState('User not authenticated'));
        return;
      }

      _chatService.getUserChats(userId).listen(
        (chats) {
          emit(ChatsLoadedState(chats));
        },
        onError: (error) {
          emit(ChatErrorState(error.toString()));
        },
      );
    } catch (e) {
      emit(ChatErrorState(e.toString()));
    }
  }

  Future<void> _handleSendMessage(
      SendMessageEvent event, Emitter<ChatState> emit) async {
    try {
      final message = await _chatService.sendMessage(
        event.chatId,
        event.content,
        event.senderId,
      );
      emit(MessageSentState(event.chatId, message));
    } catch (e) {
      emit(ChatErrorState(e.toString()));
    }
  }

  Future<void> _handleLoadChatMessages(
      LoadChatMessagesEvent event, Emitter<ChatState> emit) async {
    try {
      emit(ChatLoadingState());
      _chatService.getChatMessages(event.chatId).listen(
        (messages) {
          emit(ChatMessagesLoadedState(event.chatId, messages));
        },
        onError: (error) {
          emit(ChatErrorState(error.toString()));
        },
      );
    } catch (e) {
      emit(ChatErrorState(e.toString()));
    }
  }

  Future<void> _handleCreateChat(
      CreateChatEvent event, Emitter<ChatState> emit) async {
    try {
      emit(ChatLoadingState());
      final chat = await _chatService.createChat(
        participants: event.participants,
        participantNames: event.participantNames,
        participantPhotos: event.participantPhotos,
      );
      emit(ChatCreatedState(chat));
    } catch (e) {
      emit(ChatErrorState(e.toString()));
    }
  }

  Future<void> _handleUpdateChat(
      UpdateChatEvent event, Emitter<ChatState> emit) async {
    try {
      emit(ChatLoadingState());
      await _chatService.updateChat(event.chatId, event.updateData);
      emit(ChatUpdatedState(event.chatId, event.updateData));
    } catch (e) {
      emit(ChatErrorState(e.toString()));
    }
  }
}
