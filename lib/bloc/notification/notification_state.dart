import '../base/base_state.dart';

abstract class NotificationState extends BaseState {}

class NotificationInitialState extends NotificationState {}

class NotificationLoadingState extends NotificationState {}

class NotificationsLoadedState extends NotificationState {
  final List<Map<String, dynamic>> notifications;

  NotificationsLoadedState(this.notifications);
}

class NotificationUpdatedState extends NotificationState {
  final String notificationId;

  NotificationUpdatedState(this.notificationId);
}

class FCMTokenUpdatedState extends NotificationState {
  final String userId;
  final String? token;

  FCMTokenUpdatedState(this.userId, this.token);
}

class NotificationErrorState extends NotificationState {
  final String message;

  NotificationErrorState(this.message);
}
