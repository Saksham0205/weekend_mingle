import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../services/call_service.dart';
import '../utils/responsive_helper.dart';

class VideoCallScreen extends StatefulWidget {
  final String callId;
  final String channelName;
  final String remoteUserId;
  final String remoteUserName;
  final String? remoteUserPhotoUrl;
  final bool isOutgoing;

  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.channelName,
    required this.remoteUserId,
    required this.remoteUserName,
    this.remoteUserPhotoUrl,
    required this.isOutgoing,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final CallService _callService = CallService();
  bool _localUserJoined = false;
  bool _remoteUserJoined = false;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;
  bool _isMinimized = false;

  // Video views
  Widget? _localView;
  final Map<int, Widget> _remoteViews = <int, Widget>{};

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    // Request permissions
    await [Permission.camera, Permission.microphone].request();

    // Initialize call based on whether it's outgoing or incoming
    if (widget.isOutgoing) {
      // For outgoing calls, we've already initialized the call before navigating to this screen
      setState(() {
        _localUserJoined = true;
      });

      // Setup local video view
      if (_callService.engine != null) {
        _setupLocalView();
      }

      // Listen for remote user to join
      _listenForCallStatusChanges();
    } else {
      // For incoming calls, join the existing call
      try {
        await _callService.joinCall(widget.callId);
        setState(() {
          _localUserJoined = true;
        });

        // Setup local video view
        if (_callService.engine != null) {
          _setupLocalView();
        }

        // Listen for call status changes
        _listenForCallStatusChanges();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join call: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _listenForCallStatusChanges() {
    // Listen to Agora remote user events through our CallService
    _callService.remoteUids.listen((uids) {
      if (mounted) {
        setState(() {
          _remoteUserJoined = uids.isNotEmpty;
          _updateRemoteViews(uids);
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

  void _toggleCamera() {
    _callService.toggleCamera();
    setState(() {
      _isCameraOff = !_isCameraOff;
    });
  }

  void _toggleSpeaker() {
    _callService.toggleSpeaker();
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
  }

  void _switchCamera() {
    _callService.switchCamera();
  }

  void _endCall() async {
    await _callService.endCall();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _toggleMinimize() {
    setState(() {
      _isMinimized = !_isMinimized;
    });
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
        body: _isMinimized ? _buildMinimizedView() : _buildFullScreenView(),
      ),
    );
  }

  Widget _buildFullScreenView() {
    return Stack(
      children: [
        // Remote user's video (full screen)
        _remoteUserJoined && _remoteViews.isNotEmpty
            ? Container(
                color: Colors.black87,
                child: Center(
                  child: _remoteViews.values.first,
                ),
              )
            : Container(
                color: Colors.black87,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: ResponsiveHelper.getResponsiveWidth(50),
                        backgroundImage: widget.remoteUserPhotoUrl != null
                            ? NetworkImage(widget.remoteUserPhotoUrl!)
                            : null,
                        child: widget.remoteUserPhotoUrl == null
                            ? Icon(
                                Icons.person,
                                size: ResponsiveHelper.getResponsiveWidth(50),
                                color: Colors.white,
                              )
                            : null,
                      ),
                      SizedBox(
                          height: ResponsiveHelper.getResponsiveHeight(20)),
                      Text(
                        widget.remoteUserName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: ResponsiveHelper.getResponsiveWidth(22),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(
                          height: ResponsiveHelper.getResponsiveHeight(10)),
                      Text(
                        widget.isOutgoing ? 'Calling...' : 'Connecting...',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: ResponsiveHelper.getResponsiveWidth(16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

        // Local user's video (small overlay)
        if (_localUserJoined && _localView != null)
          Positioned(
            top: ResponsiveHelper.getResponsiveHeight(40),
            right: ResponsiveHelper.getResponsiveWidth(20),
            child: GestureDetector(
              onTap: _switchCamera,
              child: Container(
                width: ResponsiveHelper.getResponsiveWidth(120),
                height: ResponsiveHelper.getResponsiveHeight(160),
                decoration: BoxDecoration(
                  color: _isCameraOff ? Colors.grey[900] : null,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                clipBehavior: Clip.hardEdge,
                child: _isCameraOff
                    ? const Center(
                        child: Icon(
                          Icons.videocam_off,
                          color: Colors.white,
                          size: 40,
                        ),
                      )
                    : _localView,
              ),
            ),
          ),

        // Call controls at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveHelper.getResponsiveHeight(20),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.8),
                  Colors.transparent,
                ],
              ),
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
                  icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                  label: _isCameraOff ? 'Camera On' : 'Camera Off',
                  onPressed: _toggleCamera,
                ),
                _buildControlButton(
                  icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                  label: _isSpeakerOn ? 'Speaker Off' : 'Speaker On',
                  onPressed: _toggleSpeaker,
                ),
                _buildControlButton(
                  icon: Icons.call_end,
                  label: 'End',
                  backgroundColor: Colors.red,
                  onPressed: _endCall,
                ),
                _buildControlButton(
                  icon: Icons.minimize,
                  label: 'Minimize',
                  onPressed: _toggleMinimize,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMinimizedView() {
    return Stack(
      children: [
        Positioned(
          top: ResponsiveHelper.getResponsiveHeight(40),
          right: ResponsiveHelper.getResponsiveWidth(20),
          child: GestureDetector(
            onTap: _toggleMinimize,
            child: Container(
              width: ResponsiveHelper.getResponsiveWidth(120),
              height: ResponsiveHelper.getResponsiveHeight(160),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Stack(
                children: [
                  Center(
                    child: _remoteUserJoined
                        ? const Text(
                            'Remote Video',
                            style: TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: ResponsiveHelper.getResponsiveWidth(20),
                                backgroundImage: widget.remoteUserPhotoUrl !=
                                        null
                                    ? NetworkImage(widget.remoteUserPhotoUrl!)
                                    : null,
                                child: widget.remoteUserPhotoUrl == null
                                    ? Icon(
                                        Icons.person,
                                        size:
                                            ResponsiveHelper.getResponsiveWidth(
                                                20),
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              SizedBox(
                                  height:
                                      ResponsiveHelper.getResponsiveHeight(5)),
                              Text(
                                widget.remoteUserName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                  ),
                  Positioned(
                    bottom: 5,
                    right: 5,
                    child: GestureDetector(
                      onTap: _endCall,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
          width: ResponsiveHelper.getResponsiveWidth(50),
          height: ResponsiveHelper.getResponsiveWidth(50),
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.grey[800],
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon),
            color: Colors.white,
            onPressed: onPressed,
          ),
        ),
        SizedBox(height: ResponsiveHelper.getResponsiveHeight(5)),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: ResponsiveHelper.getResponsiveWidth(12),
          ),
        ),
      ],
    );
  }

  // Setup local video view
  void _setupLocalView() {
    setState(() {
      _localView = AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: _callService.engine!,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    });
  }

  // Update remote video views
  void _updateRemoteViews(Set<int> uids) {
    _remoteViews.clear();
    for (final uid in uids) {
      _remoteViews[uid] = AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _callService.engine!,
          canvas: VideoCanvas(uid: uid),
          connection: RtcConnection(channelId: widget.channelName),
        ),
      );
    }
  }

  @override
  void dispose() {
    // Clean up resources
    if (_localUserJoined) {
      _callService.endCall();
    }
    _localView = null;
    _remoteViews.clear();
    super.dispose();
  }
}
