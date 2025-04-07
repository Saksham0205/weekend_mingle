import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'package:permission_handler/permission_handler.dart';

// This is a placeholder for Agora SDK implementation
// In a real implementation, you would add:
// import 'package:agora_rtc_engine/agora_rtc_engine.dart';

class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Agora App ID - you would need to get this from the Agora Console
  // For production, this should be stored securely and not hardcoded
  static const String appId = 'YOUR_AGORA_APP_ID';

  // Singleton pattern
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  // Call states
  bool _isInCall = false;
  String? _currentCallId;
  String? _currentChannelName;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;

  // Getters for call state
  bool get isInCall => _isInCall;
  String? get currentCallId => _currentCallId;
  bool get isMuted => _isMuted;
  bool get isCameraOff => _isCameraOff;
  bool get isSpeakerOn => _isSpeakerOn;

  // Request permissions for call
  Future<bool> requestPermissions(bool isVideoCall) async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      if (isVideoCall) Permission.camera,
    ].request();

    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (status != PermissionStatus.granted) {
        allGranted = false;
      }
    });

    return allGranted;
  }

  // Initialize a call
  Future<Map<String, dynamic>> initializeCall({
    required String recipientId,
    required bool isVideoCall,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Check permissions
    bool permissionsGranted = await requestPermissions(isVideoCall);
    if (!permissionsGranted) {
      throw Exception('Call permissions not granted');
    }

    // Generate a unique channel name
    String channelName =
        '${user.uid}_${recipientId}_${DateTime.now().millisecondsSinceEpoch}';

    // Create a call document in Firestore
    final callDoc = _firestore.collection('calls').doc();
    final callId = callDoc.id;

    // Get caller information
    final callerDoc = await _firestore.collection('users').doc(user.uid).get();
    final callerData = UserModel.fromDocumentSnapshot(callerDoc);

    // Create call data
    final callData = {
      'callId': callId,
      'channelName': channelName,
      'callerId': user.uid,
      'callerName': callerData.name,
      'callerPhotoUrl': callerData.photoUrl,
      'recipientId': recipientId,
      'isVideoCall': isVideoCall,
      'status': 'ringing', // ringing, accepted, declined, ended
      'startedAt': FieldValue.serverTimestamp(),
      'endedAt': null,
    };

    // Save call to Firestore
    await callDoc.set(callData);

    // Update local state
    _isInCall = true;
    _currentCallId = callId;
    _currentChannelName = channelName;

    return {
      'callId': callId,
      'channelName': channelName,
    };
  }

  // Join a call
  Future<void> joinCall(String callId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Get call data
    final callDoc = await _firestore.collection('calls').doc(callId).get();
    if (!callDoc.exists) throw Exception('Call not found');

    final callData = callDoc.data() as Map<String, dynamic>;
    final bool isVideoCall = callData['isVideoCall'] as bool;

    // Check permissions
    bool permissionsGranted = await requestPermissions(isVideoCall);
    if (!permissionsGranted) {
      throw Exception('Call permissions not granted');
    }

    // Update call status
    await _firestore.collection('calls').doc(callId).update({
      'status': 'accepted',
    });

    // Update local state
    _isInCall = true;
    _currentCallId = callId;
    _currentChannelName = callData['channelName'] as String;
  }

  // End a call
  Future<void> endCall() async {
    if (_currentCallId == null) return;

    // Update call status in Firestore
    await _firestore.collection('calls').doc(_currentCallId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });

    // Reset local state
    _isInCall = false;
    _currentCallId = null;
    _currentChannelName = null;
    _isMuted = false;
    _isCameraOff = false;
    _isSpeakerOn = true;
  }

  // Decline a call
  Future<void> declineCall(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': 'declined',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  // Toggle mute
  void toggleMute() {
    _isMuted = !_isMuted;
    // In a real implementation, you would call the Agora SDK to mute/unmute
  }

  // Toggle camera
  void toggleCamera() {
    _isCameraOff = !_isCameraOff;
    // In a real implementation, you would call the Agora SDK to enable/disable camera
  }

  // Toggle speaker
  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    // In a real implementation, you would call the Agora SDK to switch speaker
  }

  // Switch camera (front/back)
  void switchCamera() {
    // In a real implementation, you would call the Agora SDK to switch camera
  }

  // Get active calls for current user
  Stream<List<DocumentSnapshot>> getActiveCalls() {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    return _firestore
        .collection('calls')
        .where(Filter.or(
          Filter.and(
            Filter.equalTo('callerId', user.uid),
            Filter.equalTo('status', 'ringing'),
          ),
          Filter.and(
            Filter.equalTo('recipientId', user.uid),
            Filter.equalTo('status', 'ringing'),
          ),
        ))
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  // Get call history for current user
  Future<List<DocumentSnapshot>> getCallHistory() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final calls = await _firestore
        .collection('calls')
        .where(Filter.or(
          Filter.equalTo('callerId', user.uid),
          Filter.equalTo('recipientId', user.uid),
        ))
        .orderBy('startedAt', descending: true)
        .limit(50)
        .get();

    return calls.docs;
  }
}
