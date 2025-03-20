abstract class ChatEvent {}

class LoadChatsEvent extends ChatEvent {}

class SendMessageEvent extends ChatEvent {
  final String chatId;
  final String content;
  final String senderId;

  SendMessageEvent({
    required this.chatId,
    required this.content,
    required this.senderId,
  });
}

class LoadChatMessagesEvent extends ChatEvent {
  final String chatId;

  LoadChatMessagesEvent(this.chatId);
}

class CreateChatEvent extends ChatEvent {
  final List<String> participants;
  final Map<String, String> participantNames;
  final Map<String, String?> participantPhotos;

  CreateChatEvent({
    required this.participants,
    required this.participantNames,
    required this.participantPhotos,
  });
}

class UpdateChatEvent extends ChatEvent {
  final String chatId;
  final Map<String, dynamic> updateData;

  UpdateChatEvent(this.chatId, this.updateData);
}
