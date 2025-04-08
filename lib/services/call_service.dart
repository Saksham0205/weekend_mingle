import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Agora App ID - you would need to get this from the Agora Console
  // For production, this should be stored securely and not hardcoded
  static const String appId =
      'a1b2c3d4e5f6g7h8i9j0'; // Replace with your actual Agora App ID

  // Agora engine instance
  RtcEngine? _engine;
  int? _localUid;
  final Set<int> _remoteUids = <int>{};

  // Stream controllers for call events
  final StreamController<Set<int>> _remoteUidsController =
      StreamController<Set<int>>.broadcast();
  Stream<Set<int>> get remoteUids => _remoteUidsController.stream;

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
  RtcEngine? get engine => _engine;

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

    // Initialize Agora and join the channel
    await _joinChannel(channelName, isVideoCall);

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
    final String channelName = callData['channelName'] as String;

    // Check permissions
    bool permissionsGranted = await requestPermissions(isVideoCall);
    if (!permissionsGranted) {
      throw Exception('Call permissions not granted');
    }

    // Update call status
    await _firestore.collection('calls').doc(callId).update({
      'status': 'accepted',
    });

    // Initialize Agora and join the channel
    await _joinChannel(channelName, isVideoCall);

    // Update local state
    _isInCall = true;
    _currentCallId = callId;
    _currentChannelName = channelName;
  }

  // End a call
  Future<void> endCall() async {
    if (_currentCallId == null) return;

    // Update call status in Firestore
    await _firestore.collection('calls').doc(_currentCallId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });

    // Leave the Agora channel
    await _leaveChannel();

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

    // If we're in this call, leave the channel
    if (_currentCallId == callId) {
      await _leaveChannel();
      _isInCall = false;
      _currentCallId = null;
      _currentChannelName = null;
    }
  }

  // Initialize Agora engine
  Future<void> _initializeAgoraEngine() async {
    if (_engine != null) return;

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // Register event handlers
    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        debugPrint("Local user joined: ${connection.localUid}");
        _localUid = connection.localUid;
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        debugPrint("Remote user joined: $remoteUid");
        _remoteUids.add(remoteUid);
        _remoteUidsController.add(_remoteUids);
      },
      onUserOffline: (RtcConnection connection, int remoteUid,
          UserOfflineReasonType reason) {
        debugPrint("Remote user left: $remoteUid");
        _remoteUids.remove(remoteUid);
        _remoteUidsController.add(_remoteUids);
      },
      onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
        debugPrint(
            '[onTokenPrivilegeWillExpire] connection: ${connection.toJson()}, token: $token');
      },
    ));
  }

  // Join a channel for video/voice call
  Future<void> _joinChannel(String channelName, bool isVideoCall) async {
    await _initializeAgoraEngine();

    // Enable video if it's a video call
    if (isVideoCall) {
      await _engine!.enableVideo();
      await _engine!.startPreview();
    } else {
      await _engine!.disableVideo();
    }

    // Set audio profile and scenario
    await _engine!.setAudioProfile(
      profile: AudioProfileType.audioProfileDefault,
      scenario: AudioScenarioType.audioScenarioChatroom,
    );

    // Join the channel
    await _engine!.joinChannel(
      token: '', // Use token-based authentication in production
      channelId: channelName,
      uid: 0, // 0 means let the Agora server assign one
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  // Leave the channel
  Future<void> _leaveChannel() async {
    if (_engine != null) {
      await _engine!.leaveChannel();
      await _engine!.stopPreview();
      _remoteUids.clear();
      _remoteUidsController.add(_remoteUids);
    }
  }

  // Toggle mute
  void toggleMute() {
    _isMuted = !_isMuted;
    _engine?.muteLocalAudioStream(_isMuted);
  }

  // Toggle camera
  void toggleCamera() {
    _isCameraOff = !_isCameraOff;
    _engine?.muteLocalVideoStream(_isCameraOff);
  }

  // Toggle speaker
  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    _engine?.setEnableSpeakerphone(_isSpeakerOn);
  }

  // Switch camera (front/back)
  void switchCamera() {
    _engine?.switchCamera();
  }

  // Get active calls for current user
  Stream<List<DocumentSnapshot>> getActiveCalls() {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    return _firestore
        .collection('calls')
        .where('status', isEqualTo: 'ringing')
        .where(Filter.or(
          Filter('callerId', isEqualTo: user.uid),
          Filter('recipientId', isEqualTo: user.uid),
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
          Filter('callerId', isEqualTo: user.uid),
          Filter('recipientId', isEqualTo: user.uid),
        ))
        .orderBy('startedAt', descending: true)
        .limit(50)
        .get();

    return calls.docs;
  }
}
