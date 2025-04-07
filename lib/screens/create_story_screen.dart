import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:path/path.dart' as path;
import '../services/story_service.dart';
import '../utils/responsive_helper.dart';
import 'package:permission_handler/permission_handler.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final StoryService _storyService = StoryService();
  final TextEditingController _textController = TextEditingController();
  File? _mediaFile;
  String _mediaType = TYPE_TEXT;
  bool _isUploading = false;
  VideoPlayerController? _videoController;
  final FocusNode _textFocusNode = FocusNode();
  Color _backgroundColor = Colors.blue;
  Color _textColor = Colors.white;
  double _textSize = 24.0;
  String _fontWeight = 'normal';

  final List<Color> _colorOptions = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();
    await Permission.storage.request();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _mediaFile = File(image.path);
        _mediaType = TYPE_IMAGE;
        _textController.clear();
      });
    }
  }

  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
      setState(() {
        _mediaFile = File(photo.path);
        _mediaType = TYPE_IMAGE;
        _textController.clear();
      });
    }
  }

  Future<void> _pickVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      final videoFile = File(video.path);

      // Check if video is less than 30 seconds
      final VideoPlayerController controller =
          VideoPlayerController.file(videoFile);
      await controller.initialize();
      final duration = controller.value.duration;

      if (duration.inSeconds > 30) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video must be less than 30 seconds')),
        );
        controller.dispose();
        return;
      }

      setState(() {
        _mediaFile = videoFile;
        _mediaType = TYPE_VIDEO;
        _videoController = controller;
        _textController.clear();
      });
    }
  }

  Future<void> _recordVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.camera);

    if (video != null) {
      final videoFile = File(video.path);

      // Check if video is less than 30 seconds
      final VideoPlayerController controller =
          VideoPlayerController.file(videoFile);
      await controller.initialize();
      final duration = controller.value.duration;

      if (duration.inSeconds > 30) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video must be less than 30 seconds')),
        );
        controller.dispose();
        return;
      }

      setState(() {
        _mediaFile = videoFile;
        _mediaType = TYPE_VIDEO;
        _videoController = controller;
        _textController.clear();
      });
    }
  }

  void _createTextStory() {
    setState(() {
      _mediaFile = null;
      _mediaType = TYPE_TEXT;
      if (_videoController != null) {
        _videoController!.dispose();
        _videoController = null;
      }
    });

    // Focus on text field
    Future.delayed(const Duration(milliseconds: 300), () {
      _textFocusNode.requestFocus();
    });
  }

  Future<void> _uploadStory() async {
    if (_mediaType == TYPE_TEXT && _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text for your story')),
      );
      return;
    }

    if ((_mediaType == TYPE_IMAGE || _mediaType == TYPE_VIDEO) &&
        _mediaFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a media file')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      if (_mediaType == TYPE_TEXT) {
        // Create text story
        final metadata = {
          'backgroundColor': _backgroundColor.value.toString(),
          'textColor': _textColor.value.toString(),
          'textSize': _textSize,
          'fontWeight': _fontWeight,
        };

        await _storyService.createTextStory(
          text: _textController.text.trim(),
          metadata: metadata,
        );
      } else {
        // Create media story
        await _storyService.createStory(
          mediaFile: _mediaFile,
          text: _textController.text.trim().isNotEmpty
              ? _textController.text.trim()
              : null,
          mediaType: _mediaType,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story created successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create story: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _changeBackgroundColor(Color color) {
    setState(() {
      _backgroundColor = color;
    });
  }

  void _changeTextColor(Color color) {
    setState(() {
      _textColor = color;
    });
  }

  void _changeTextSize(double size) {
    setState(() {
      _textSize = size;
    });
  }

  void _toggleFontWeight() {
    setState(() {
      _fontWeight = _fontWeight == 'normal' ? 'bold' : 'normal';
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    if (_videoController != null) {
      _videoController!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Story'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isUploading ? null : _uploadStory,
          ),
        ],
      ),
      body: _isUploading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Story preview area
                Expanded(
                  child: Container(
                    color: Colors.black,
                    child: _buildPreview(),
                  ),
                ),
                // Story creation controls
                Container(
                  color: Colors.white,
                  padding:
                      EdgeInsets.all(ResponsiveHelper.getResponsiveWidth(16)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Media type selection
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildTypeButton(
                              icon: Icons.text_fields,
                              label: 'Text',
                              isSelected: _mediaType == TYPE_TEXT,
                              onTap: _createTextStory,
                            ),
                            _buildTypeButton(
                              icon: Icons.photo_library,
                              label: 'Gallery',
                              isSelected: _mediaType == TYPE_IMAGE &&
                                  _mediaFile != null,
                              onTap: _pickImage,
                            ),
                            _buildTypeButton(
                              icon: Icons.camera_alt,
                              label: 'Camera',
                              isSelected: false,
                              onTap: _takePhoto,
                            ),
                            _buildTypeButton(
                              icon: Icons.video_library,
                              label: 'Video',
                              isSelected: _mediaType == TYPE_VIDEO &&
                                  _mediaFile != null,
                              onTap: _pickVideo,
                            ),
                            _buildTypeButton(
                              icon: Icons.videocam,
                              label: 'Record',
                              isSelected: false,
                              onTap: _recordVideo,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(
                          height: ResponsiveHelper.getResponsiveHeight(16)),

                      // Text input for caption or text story
                      if (_mediaType == TYPE_TEXT)
                        Column(
                          children: [
                            // Color selection for text stories
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final color in _colorOptions)
                                    GestureDetector(
                                      onTap: () =>
                                          _changeBackgroundColor(color),
                                      child: Container(
                                        margin: EdgeInsets.symmetric(
                                          horizontal: ResponsiveHelper
                                              .getResponsiveWidth(4),
                                        ),
                                        width:
                                            ResponsiveHelper.getResponsiveWidth(
                                                30),
                                        height:
                                            ResponsiveHelper.getResponsiveWidth(
                                                30),
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: _backgroundColor == color
                                                ? Colors.white
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            SizedBox(
                                height:
                                    ResponsiveHelper.getResponsiveHeight(8)),

                            // Text formatting options
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.format_bold,
                                    color: _fontWeight == 'bold'
                                        ? Colors.blue
                                        : Colors.grey,
                                  ),
                                  onPressed: _toggleFontWeight,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.format_color_text),
                                  color: _textColor == Colors.white
                                      ? Colors.grey
                                      : _textColor,
                                  onPressed: () => _changeTextColor(
                                    _textColor == Colors.white
                                        ? Colors.black
                                        : Colors.white,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.text_decrease),
                                  onPressed: () =>
                                      _changeTextSize(_textSize - 2),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.text_increase),
                                  onPressed: () =>
                                      _changeTextSize(_textSize + 2),
                                ),
                              ],
                            ),
                          ],
                        ),

                      SizedBox(height: ResponsiveHelper.getResponsiveHeight(8)),

                      // Text input field
                      TextField(
                        controller: _textController,
                        focusNode: _textFocusNode,
                        decoration: InputDecoration(
                          hintText: _mediaType == TYPE_TEXT
                              ? 'Type your story...'
                              : 'Add a caption...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: ResponsiveHelper.getResponsiveWidth(16),
                            vertical: ResponsiveHelper.getResponsiveHeight(12),
                          ),
                        ),
                        maxLines: _mediaType == TYPE_TEXT ? 5 : 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPreview() {
    if (_mediaType == TYPE_TEXT) {
      return Container(
        color: _backgroundColor,
        padding: EdgeInsets.all(ResponsiveHelper.getResponsiveWidth(20)),
        child: Center(
          child: Text(
            _textController.text.isEmpty
                ? 'Your story text will appear here'
                : _textController.text,
            style: TextStyle(
              color: _textColor,
              fontSize: _textSize,
              fontWeight:
                  _fontWeight == 'bold' ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (_mediaType == TYPE_IMAGE && _mediaFile != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            _mediaFile!,
            fit: BoxFit.contain,
          ),
          if (_textController.text.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    EdgeInsets.all(ResponsiveHelper.getResponsiveWidth(16)),
                color: Colors.black.withOpacity(0.5),
                child: Text(
                  _textController.text,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: ResponsiveHelper.getResponsiveWidth(16),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      );
    } else if (_mediaType == TYPE_VIDEO &&
        _mediaFile != null &&
        _videoController != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          ),
          Center(
            child: IconButton(
              icon: Icon(
                _videoController!.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
                size: ResponsiveHelper.getResponsiveWidth(50),
                color: Colors.white.withOpacity(0.8),
              ),
              onPressed: () {
                setState(() {
                  if (_videoController!.value.isPlaying) {
                    _videoController!.pause();
                  } else {
                    _videoController!.play();
                  }
                });
              },
            ),
          ),
          if (_textController.text.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    EdgeInsets.all(ResponsiveHelper.getResponsiveWidth(16)),
                color: Colors.black.withOpacity(0.5),
                child: Text(
                  _textController.text,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: ResponsiveHelper.getResponsiveWidth(16),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate,
              size: ResponsiveHelper.getResponsiveWidth(80),
              color: Colors.white.withOpacity(0.5),
            ),
            SizedBox(height: ResponsiveHelper.getResponsiveHeight(16)),
            Text(
              'Select a media type to create your story',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: ResponsiveHelper.getResponsiveWidth(16),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildTypeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(right: ResponsiveHelper.getResponsiveWidth(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: ResponsiveHelper.getResponsiveWidth(50),
              height: ResponsiveHelper.getResponsiveWidth(50),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.black87,
                size: ResponsiveHelper.getResponsiveWidth(24),
              ),
            ),
            SizedBox(height: ResponsiveHelper.getResponsiveHeight(4)),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.black87,
                fontSize: ResponsiveHelper.getResponsiveWidth(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
