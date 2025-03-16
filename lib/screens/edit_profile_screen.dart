import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/cloudinary_services.dart';
import '../services/location_service.dart';
import '../models/user_model.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _professionController = TextEditingController();
  final _companyController = TextEditingController();
  final _industryController = TextEditingController();
  final _locationNameController = TextEditingController();
  final _cloudinaryService = CloudinaryService();
  String? _photoUrl;
  List<String> _selectedSkills = [];
  List<String> _selectedWeekendInterests = [];
  Map<String, bool> _availability = {
    'weekday_morning': false,
    'weekday_afternoon': false,
    'weekday_evening': false,
    'weekend_morning': false,
    'weekend_afternoon': false,
    'weekend_evening': false,
  };

  final List<String> _skillOptions = [
    'Flutter', 'React', 'Node.js', 'Python', 'Java', 'Product Management',
    'UI/UX Design', 'Data Science', 'DevOps', 'Cloud Computing',
    'Machine Learning', 'Digital Marketing', 'Project Management',
    'Business Development', 'Sales', 'Content Writing'
  ];

  final List<String> _weekendInterestOptions = [
    'Coffee Meetups', 'Tech Talks', 'Sports', 'Hiking', 'Photography',
    'Board Games', 'Movies', 'Music', 'Food Exploration', 'Networking Events',
    'Book Club', 'Fitness', 'Art & Culture', 'Travel', 'Volunteering',
    'Language Exchange'
  ];

  bool _isLoading = false;
  final _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userData.exists) {
          final data = userData.data() as Map<String, dynamic>;
          _nameController.text = data['name'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _professionController.text = data['profession'] ?? '';
          _companyController.text = data['company'] ?? '';
          _industryController.text = data['industry'] ?? '';
          _locationNameController.text = data['locationName'] ?? '';
          _photoUrl = data['photoUrl'];
          _selectedSkills = List<String>.from(data['skills'] ?? []);
          _selectedWeekendInterests = List<String>.from(data['weekendInterests'] ?? []);
          _availability = Map<String, bool>.from(data['availability'] ?? {});
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isLoading = true);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Upload to Cloudinary instead of Firebase Storage
        final photoUrl = await _cloudinaryService.uploadProfileImage(
          user.uid,
          File(image.path),
        );

        setState(() => _photoUrl = photoUrl);
        _showSuccessSnackBar('Profile picture updated successfully!');
      }
    } catch (e) {
      _showErrorSnackBar('Error uploading image: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateLocation() async {
    try {
      setState(() => _isLoading = true);
      final location = await _locationService.getCurrentLocation();
      if (location != null) {
        final address = await _locationService.getAddressFromCoordinates(
          location.latitude,
          location.longitude,
        );
        if (address != null) {
          setState(() {
            _locationNameController.text = address;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating location: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'name': _nameController.text.trim(),
          'bio': _bioController.text.trim(),
          'profession': _professionController.text.trim(),
          'company': _companyController.text.trim(),
          'industry': _industryController.text.trim(),
          'locationName': _locationNameController.text.trim(),
          'photoUrl': _photoUrl,
          'skills': _selectedSkills,
          'weekendInterests': _selectedWeekendInterests,
          'availability': _availability,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.grey[300],
            ),
          ),
        ],
      ),
    );
  }
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveProfile,
            ),
        ],
      ),
      body: _isLoading && _photoUrl == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(0.8),
                    Colors.white,
                  ],
                ),
              ),
              child: Center(
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: _buildProfileImage(),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 5,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt),
                          color: Colors.white,
                          onPressed: _pickImage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Basic Information'),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              icon: Icon(Icons.person_outline),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _bioController,
                            decoration: const InputDecoration(
                              labelText: 'Bio',
                              icon: Icon(Icons.description_outlined),
                              alignLabelWithHint: true,
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Professional Details'),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _professionController,
                            decoration: const InputDecoration(
                              labelText: 'Profession',
                              icon: Icon(Icons.work_outline),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _companyController,
                            decoration: const InputDecoration(
                              labelText: 'Company',
                              icon: Icon(Icons.business_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _industryController,
                            decoration: const InputDecoration(
                              labelText: 'Industry',
                              icon: Icon(Icons.category_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Location'),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _locationNameController,
                            decoration: InputDecoration(
                              labelText: 'Location',
                              icon: const Icon(Icons.location_on_outlined),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.my_location),
                                onPressed: _updateLocation,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Professional Skills'),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _skillOptions.map((skill) {
                              final isSelected = _selectedSkills.contains(skill);
                              return FilterChip(
                                label: Text(skill),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedSkills.add(skill);
                                    } else {
                                      _selectedSkills.remove(skill);
                                    }
                                  });
                                },
                                backgroundColor: Colors.purple.withOpacity(0.1),
                                selectedColor: Colors.purple.withOpacity(0.2),
                                checkmarkColor: Colors.purple,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.purple : Colors.purple[700],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Weekend Interests'),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _weekendInterestOptions.map((interest) {
                              final isSelected = _selectedWeekendInterests.contains(interest);
                              return FilterChip(
                                label: Text(interest),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedWeekendInterests.add(interest);
                                    } else {
                                      _selectedWeekendInterests.remove(interest);
                                    }
                                  });
                                },
                                backgroundColor: Colors.orange.withOpacity(0.1),
                                selectedColor: Colors.orange.withOpacity(0.2),
                                checkmarkColor: Colors.orange,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.orange : Colors.orange[700],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Availability'),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildAvailabilitySection(
                            'Weekdays',
                            ['weekday_morning', 'weekday_afternoon', 'weekday_evening'],
                          ),
                          const Divider(height: 32),
                          _buildAvailabilitySection(
                            'Weekends',
                            ['weekend_morning', 'weekend_afternoon', 'weekend_evening'],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildProfileImage() {
    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      // Use Cloudinary's optimized URL for profile images
      final optimizedUrl = _cloudinaryService.getOptimizedImageUrl(
        _photoUrl!,
        width: 200,
        height: 200,
        transformation: 'c_fill,g_face,f_auto,q_auto',
      );

      try {
        return CircleAvatar(
          radius: 58,
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          backgroundImage: CachedNetworkImageProvider(optimizedUrl),
        );
      } catch (e) {
        print('Error loading profile image: $e');
        return _buildPlaceholderImage();
      }
    }

    return _buildPlaceholderImage();
  }
  Widget _buildPlaceholderImage() {
    return CircleAvatar(
      radius: 58,
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Icon(
        Icons.person,
        size: 48,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildAvailabilitySection(String title, List<String> times) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: times.map((time) {
            final isSelected = _availability[time] ?? false;
            final label = time.split('_')[1];
            return FilterChip(
              label: Text(
                label[0].toUpperCase() + label.substring(1),
                style: TextStyle(
                  color: isSelected ? Colors.teal : Colors.teal[700],
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _availability[time] = selected;
                });
              },
              backgroundColor: Colors.teal.withOpacity(0.1),
              selectedColor: Colors.teal.withOpacity(0.2),
              checkmarkColor: Colors.teal,
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _professionController.dispose();
    _companyController.dispose();
    _industryController.dispose();
    _locationNameController.dispose();
    super.dispose();
  }
}