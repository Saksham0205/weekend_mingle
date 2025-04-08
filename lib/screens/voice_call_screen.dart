import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../services/call_service.dart';
import '../utils/responsive_helper.dart';

class VoiceCallScreen extends StatefulWidget {
  final String callId;
  final String channelName;
  final String remoteUserId;
  final String remoteUserName;
  final String? remoteUserPhotoUrl;
  final bool isOutgoing;

  const VoiceCallScreen({
    super.key,
    required this.callId,
    required this.channelName,
    required this.remoteUserId,
    required this.remoteUserName,
    this.remoteUserPhotoUrl,
    required this.isOutgoing,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  final CallService _callService = CallService();
  bool _localUserJoined = false;
  bool _remoteUserJoined = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  Duration _callDuration = Duration.zero;
  late Timer _callTimer;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    // Request microphone permission
    await Permission.microphone.request();

    // Initialize call based on whether it's outgoing or incoming
    if (widget.isOutgoing) {
      // For outgoing calls, we've already initialized the call before navigating to this screen
      _localUserJoined = true;
      // Listen for remote user to join
      _listenForCallStatusChanges();
    } else {
      // For incoming calls, join the existing call
      try {
        await _callService.joinCall(widget.callId);
        setState(() {
          _localUserJoined = true;
        });
        // Listen for call status changes
        _listenForCallStatusChanges();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join call: $e')),
        );
        Navigator.pop(context);
      }
    }

    // Start call timer
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _remoteUserJoined) {
        setState(() {
          _callDuration = Duration(seconds: timer.tick);
        });
      }
    });
  }

  void _listenForCallStatusChanges() {
    // Listen to Agora remote user events through our CallService
    _callService.remoteUids.listen((uids) {
      if (mounted) {
        setState(() {
          _remoteUserJoined = uids.isNotEmpty;
        });
      }
    });

    // Also listen to Firestore for call status changes
    // This would be implemented to handle call ended/declined from the other side
  }

  void _toggleMute() {
    _callService.toggleMute();
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  void _toggleSpeaker() {
    _callService.toggleSpeaker();
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
  }

  void _endCall() async {
    await _callService.endCall();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _endCall();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.blue.shade900,
                Colors.blue.shade700,
                Colors.blue.shade500,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Call status bar
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: ResponsiveHelper.getResponsiveHeight(20),
                    horizontal: ResponsiveHelper.getResponsiveWidth(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveHelper.getResponsiveWidth(16),
                          vertical: ResponsiveHelper.getResponsiveHeight(8),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.phone_in_talk,
                              color: Colors.white,
                              size: ResponsiveHelper.getResponsiveWidth(16),
                            ),
                            SizedBox(
                                width: ResponsiveHelper.getResponsiveWidth(8)),
                            Text(
                              _remoteUserJoined
                                  ? _formatDuration(_callDuration)
                                  : widget.isOutgoing
                                      ? 'Calling...'
                                      : 'Connecting...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize:
                                    ResponsiveHelper.getResponsiveWidth(14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // User profile
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: ResponsiveHelper.getResponsiveWidth(70),
                          backgroundImage: widget.remoteUserPhotoUrl != null
                              ? NetworkImage(widget.remoteUserPhotoUrl!)
                              : null,
                          backgroundColor: Colors.grey[300],
                          child: widget.remoteUserPhotoUrl == null
                              ? Icon(
                                  Icons.person,
                                  size: ResponsiveHelper.getResponsiveWidth(70),
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        SizedBox(
                            height: ResponsiveHelper.getResponsiveHeight(24)),
                        Text(
                          widget.remoteUserName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: ResponsiveHelper.getResponsiveWidth(28),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(
                            height: ResponsiveHelper.getResponsiveHeight(8)),
                        Text(
                          _remoteUserJoined
                              ? 'On call'
                              : widget.isOutgoing
                                  ? 'Calling...'
                                  : 'Incoming call',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: ResponsiveHelper.getResponsiveWidth(16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Call controls
                Container(
                  padding: EdgeInsets.symmetric(
                    vertical: ResponsiveHelper.getResponsiveHeight(30),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        icon: _isMuted ? Icons.mic_off : Icons.mic,
                        label: _isMuted ? 'Unmute' : 'Mute',
                        onPressed: _toggleMute,
                      ),
                      _buildControlButton(
                        icon: Icons.call_end,
                        label: 'End',
                        backgroundColor: Colors.red,
                        onPressed: _endCall,
                      ),
                      _buildControlButton(
                        icon:
                            _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                        label: _isSpeakerOn ? 'Speaker Off' : 'Speaker On',
                        onPressed: _toggleSpeaker,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    Color? backgroundColor,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: ResponsiveHelper.getResponsiveWidth(60),
          height: ResponsiveHelper.getResponsiveWidth(60),
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon),
            color: Colors.white,
            iconSize: ResponsiveHelper.getResponsiveWidth(30),
            onPressed: onPressed,
          ),
        ),
        SizedBox(height: ResponsiveHelper.getResponsiveHeight(8)),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: ResponsiveHelper.getResponsiveWidth(14),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Clean up resources
    _callTimer.cancel();
    if (_localUserJoined) {
      _callService.endCall();
    }
    super.dispose();
  }
}
