import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/notification_service.dart';
import '../base/base_bloc.dart';
import 'notification_event.dart';
import 'notification_state.dart';

class NotificationBloc extends BaseBloc<NotificationEvent, NotificationState> {
  final NotificationService _notificationService;

  NotificationBloc(this._notificationService)
      : super(NotificationInitialState()) {
    on<LoadNotificationsEvent>(_handleLoadNotifications);
    on<UpdateFCMTokenEvent>(_handleUpdateFCMToken);
    on<MarkNotificationAsReadEvent>(_handleMarkNotificationAsRead);
    on<ClearNotificationsEvent>(_handleClearNotifications);
    on<AddNotificationEvent>(_handleAddNotification);
  }

  Future<void> _handleLoadNotifications(
      LoadNotificationsEvent event, Emitter<NotificationState> emit) async {
    try {
      emit(NotificationLoadingState());
      final notifications = await _notificationService.getNotifications();
      emit(NotificationsLoadedState(notifications));
    } catch (e) {
      emit(NotificationErrorState(e.toString()));
    }
  }

  Future<void> _handleUpdateFCMToken(
      UpdateFCMTokenEvent event, Emitter<NotificationState> emit) async {
    try {
      await NotificationService.updateToken(event.userId, event.token);
      emit(FCMTokenUpdatedState(event.userId, event.token));
    } catch (e) {
      emit(NotificationErrorState(e.toString()));
    }
  }

  Future<void> _handleMarkNotificationAsRead(MarkNotificationAsReadEvent event,
      Emitter<NotificationState> emit) async {
    try {
      await _notificationService.markNotificationAsRead(event.notificationId);
      emit(NotificationUpdatedState(event.notificationId));
      // Reload notifications to reflect changes
      final notifications = await _notificationService.getNotifications();
      emit(NotificationsLoadedState(notifications));
    } catch (e) {
      emit(NotificationErrorState(e.toString()));
    }
  }

  Future<void> _handleClearNotifications(
      ClearNotificationsEvent event, Emitter<NotificationState> emit) async {
    try {
      await _notificationService.clearNotifications();
      emit(NotificationsLoadedState([]));
    } catch (e) {
      emit(NotificationErrorState(e.toString()));
    }
  }

  Future<void> _handleAddNotification(
      AddNotificationEvent event, Emitter<NotificationState> emit) async {
    try {
      await _notificationService.addNotification(event.notificationData);
      final notifications = await _notificationService.getNotifications();
      emit(NotificationsLoadedState(notifications));
    } catch (e) {
      emit(NotificationErrorState(e.toString()));
    }
  }
}
