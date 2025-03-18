import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Notification channels
  static const String _messageChannelId = 'mingle_messages';
  static const String _friendRequestChannelId = 'mingle_friend_requests';
  static const String _weekendPlanChannelId = 'mingle_weekend_plans';
  static const String _generalChannelId = 'mingle_general';

  // Initialize notification services
  static Future<void> initialize() async {
    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: true,
      carPlay: false,
      criticalAlert: false,
    );

    // Log permission status
    debugPrint('FCM: Permission status: ${settings.authorizationStatus}');

    // Initialize local notifications
    const initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onNotificationTapped,
    );

    // Create notification channels (Android only)
    await _createNotificationChannels();
  }

  // Public method for initializing notifications from main
  static Future<void> initializeNotifications() async {
    await initialize();

    // Set up handlers for when the app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleForegroundMessage(message);
    });

    // Handle notification tap when app is in background but open
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message);
    });

    // Update FCM token whenever Firebase generates a new one
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _saveToken(token);
    });
  }

  // Save FCM token to Firestore
  static Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await updateToken(user.uid);
    }
  }

  // Create notification channels for Android
  static Future<void> _createNotificationChannels() async {
    // For Android 8.0 or higher
    const messagingChannel = AndroidNotificationChannel(
      _messageChannelId,
      'Messages',
      description: 'Notifications for new messages',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    const friendRequestChannel = AndroidNotificationChannel(
      _friendRequestChannelId,
      'Friend Requests',
      description: 'Notifications for friend requests',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    const weekendPlanChannel = AndroidNotificationChannel(
      _weekendPlanChannelId,
      'Weekend Plans',
      description: 'Notifications for weekend plans',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    const generalChannel = AndroidNotificationChannel(
      _generalChannelId,
      'General',
      description: 'General notifications',

      enableVibration: true,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(messagingChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(friendRequestChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(weekendPlanChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(generalChannel);
  }

  // Background message handler
  static Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    debugPrint('FCM: Handling background message: ${message.messageId}');
    // We don't need to show a notification here because FCM will automatically
    // create the notification when the app is in the background
  }

  // Show local notification
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;
    final data = message.data;

    if (notification == null) return;

    // Determine channel based on notification type
    String channelId = _generalChannelId;
    if (data['type'] == 'message') {
      channelId = _messageChannelId;
    } else if (data['type'] == 'friend_request') {
      channelId = _friendRequestChannelId;
    } else if (data['type'] == 'weekend_plan') {
      channelId = _weekendPlanChannelId;
    }

    // Create the notification details
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == _messageChannelId
          ? 'Messages'
          : channelId == _friendRequestChannelId
          ? 'Friend Requests'
          : channelId == _weekendPlanChannelId
          ? 'Weekend Plans'
          : 'General',
      channelDescription: 'Notifications for Mingle',
      importance: Importance.high,
      priority: Priority.high,
      icon: android?.smallIcon ?? '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details =
    NotificationDetails(android: androidDetails, iOS: iosDetails);

    // Show the notification
    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: json.encode(data),
    );
  }

  // Handle tapped notifications from local notification plugin
  static void onNotificationTapped(NotificationResponse details) {
    _handleNotificationTap(details.payload);
  }

  // Handle foreground message
  static void _handleForegroundMessage(RemoteMessage message) {
    _showLocalNotification(message);
  }

  // Handle notification tap
  static void _handleNotificationTap(dynamic payload) {
    if (payload == null) return;

    // If it's a RemoteMessage, extract the payload
    String? payloadString;
    if (payload is RemoteMessage) {
      payloadString = payload.data['payload'];
    } else {
      payloadString = payload;
    }

    if (payloadString == null) return;

    try {
      final data = json.decode(payloadString);
      // Handle navigation based on notification type
      // This will be implemented by the navigation service or handled in the UI
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
    }
  }

  // Update FCM token in Firestore
  static Future<void> updateToken(String userId) async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
      debugPrint('FCM: Token updated for user $userId');
    }
  }

  // Delete FCM token on logout
  static Future<void> deleteToken() async {
    await _messaging.deleteToken();
    debugPrint('FCM: Token deleted');
  }

  // Subscribe to topics for different notification types
  static Future<void> subscribeToTopics(List<String> topics) async {
    for (final topic in topics) {
      await _messaging.subscribeToTopic(topic);
      debugPrint('FCM: Subscribed to topic: $topic');
    }
  }

  // Unsubscribe from topics
  static Future<void> unsubscribeFromTopics(List<String> topics) async {
    for (final topic in topics) {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('FCM: Unsubscribed from topic: $topic');
    }
  }

  // Store notification in Firestore
  static Future<void> storeNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    required String sourceId,
    Map<String, dynamic>? additionalData,
  }) async {
    await _firestore.collection('users').doc(userId).collection('notifications').add({
      'title': title,
      'body': body,
      'type': type,
      'sourceId': sourceId,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
      'data': additionalData,
    });
  }

  // Get notifications for a user
  static Stream<QuerySnapshot> getUserNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  // Mark notification as read
  static Future<void> markNotificationAsRead(String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({
      'isRead': true,
    });
  }

  // Mark all notifications as read
  static Future<void> markAllNotificationsAsRead(String userId) async {
    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  // Delete a notification
  static Future<void> deleteNotification(String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  // Send notification to a specific user (using Cloud Functions)
  static Future<void> sendPushNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    required String sourceId,
    Map<String, dynamic>? additionalData,
  }) async {
    // This would typically call a Cloud Function to send the notification
    // For now, we'll just store it in Firestore
    await storeNotification(
      userId: userId,
      title: title,
      body: body,
      type: type,
      sourceId: sourceId,
      additionalData: additionalData,
    );
  }

  // For backwards compatibility with existing code
  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    await sendPushNotification(
      userId: userId,
      title: title,
      body: body,
      type: data['type'] ?? 'general',
      sourceId: data['sourceId'] ?? '',
      additionalData: data,
    );
  }

  // Get unread notification count
  static Stream<int> getUnreadNotificationCount(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}