abstract class NotificationEvent {}

class LoadNotificationsEvent extends NotificationEvent {}

class UpdateFCMTokenEvent extends NotificationEvent {
  final String userId;
  final String? token;

  UpdateFCMTokenEvent(this.userId, this.token);
}

class MarkNotificationAsReadEvent extends NotificationEvent {
  final String notificationId;

  MarkNotificationAsReadEvent(this.notificationId);
}

class ClearNotificationsEvent extends NotificationEvent {}

class AddNotificationEvent extends NotificationEvent {
  final Map<String, dynamic> notificationData;

  AddNotificationEvent(this.notificationData);
}
