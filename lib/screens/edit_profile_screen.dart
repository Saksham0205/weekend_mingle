import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/cloudinary_services.dart';
import '../services/location_service.dart';
import '../models/user_model.dart';
import '../services/user_data_service.dart';
import '../providers/user_provider.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _professionController = TextEditingController();
  final _companyController = TextEditingController();
  final _industryController = TextEditingController();
  final _locationNameController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _githubController = TextEditingController();
  final _twitterController = TextEditingController();
  final _cloudinaryService = CloudinaryService();
  final _userDataService = UserDataService();
  String? _photoUrl;
  List<String> _selectedSkills = [];
  List<String> _selectedWeekendInterests = [];
  Map<String, bool> _availability = {
    'weekday_morning_early': false,    // 6-9 AM
    'weekday_morning_late': false,     // 9-12 PM
    'weekday_afternoon_early': false,  // 12-3 PM
    'weekday_afternoon_late': false,   // 3-6 PM
    'weekday_evening_early': false,    // 6-9 PM
    'weekday_evening_late': false,     // 9-12 AM
    'weekend_morning_early': false,    // 6-9 AM
    'weekend_morning_late': false,     // 9-12 PM
    'weekend_afternoon_early': false,  // 12-3 PM
    'weekend_afternoon_late': false,   // 3-6 PM
    'weekend_evening_early': false,    // 6-9 PM
    'weekend_evening_late': false,     // 9-12 AM
  };

  late TabController _tabController;
  bool _isLoading = false;
  final _locationService = LocationService();
  double _profileCompletion = 0.0;

  // Personality quiz answers
  Map<String, String> _personalityAnswers = {
    'personality_type': '',
    'communication_style': '',
    'work_style': '',
    'learning_style': '',
  };

  final List<String> _personalityTypes = [
    'Introvert', 'Extrovert', 'Ambivert'
  ];

  final List<String> _communicationStyles = [
    'Direct', 'Diplomatic', 'Collaborative', 'Analytical'
  ];

  final List<String> _workStyles = [
    'Structured', 'Flexible', 'Creative', 'Methodical'
  ];

  final List<String> _learningStyles = [
    'Visual', 'Auditory', 'Reading/Writing', 'Kinesthetic'
  ];

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _calculateProfileCompletion() {
    int totalFields = 0;
    int filledFields = 0;

    // Basic info
    if (_nameController.text.isNotEmpty) filledFields++;
    if (_bioController.text.isNotEmpty) filledFields++;
    if (_professionController.text.isNotEmpty) filledFields++;
    if (_companyController.text.isNotEmpty) filledFields++;
    if (_industryController.text.isNotEmpty) filledFields++;
    if (_locationNameController.text.isNotEmpty) filledFields++;
    if (_photoUrl != null) filledFields++;
    totalFields += 7;

    // Skills and interests
    if (_selectedSkills.isNotEmpty) filledFields++;
    if (_selectedWeekendInterests.isNotEmpty) filledFields++;
    totalFields += 2;

    // Availability
    if (_availability.values.any((v) => v)) filledFields++;
    totalFields++;

    // Personality quiz
    if (_personalityAnswers.values.every((v) => v.isNotEmpty)) filledFields++;
    totalFields++;

    // Social media
    if (_linkedinController.text.isNotEmpty) filledFields++;
    if (_githubController.text.isNotEmpty) filledFields++;
    if (_twitterController.text.isNotEmpty) filledFields++;
    totalFields += 3;

    setState(() {
      _profileCompletion = filledFields / totalFields;
    });
  }

  Widget _buildProfileHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 600;
        final profileImageSize = isWideScreen ? 150.0 : 120.0;
        final nameFontSize = isWideScreen ? 28.0 : 24.0;
        final professionFontSize = isWideScreen ? 18.0 : 16.0;

        return Container(
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top gradient bar
              Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              // Profile section
              Transform.translate(
                offset: const Offset(0, -60),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        children: [
                          // Profile image with border
                          Container(
                            width: profileImageSize,
                            height: profileImageSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _photoUrl != null
                                  ? CachedNetworkImage(
                                imageUrl: _photoUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const CircularProgressIndicator(),
                                errorWidget: (context, url, error) => const Icon(Icons.error),
                              )
                                  : Icon(Icons.person, size: profileImageSize * 0.5),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Name and profession
                          Text(
                            _nameController.text.isEmpty ? 'Your Name' : _nameController.text,
                            style: TextStyle(
                              fontSize: nameFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _professionController.text.isEmpty ? 'Your Profession' : _professionController.text,
                            style: TextStyle(
                              fontSize: professionFontSize,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          // Profile completion indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    value: _profileCompletion,
                                    strokeWidth: 2,
                                    backgroundColor: Colors.grey[300],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${(_profileCompletion * 100).toInt()}% Complete',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                      // Camera button
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).primaryColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(Icons.camera_alt, color: Colors.white, size: isWideScreen ? 24 : 20),
                            onPressed: _pickImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPersonalityQuiz() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Personality Quiz'),
        const SizedBox(height: 16),
        _buildQuizQuestion(
          'What\'s your personality type?',
          _personalityTypes,
              (value) => setState(() => _personalityAnswers['personality_type'] = value),
        ),
        const SizedBox(height: 16),
        _buildQuizQuestion(
          'What\'s your communication style?',
          _communicationStyles,
              (value) => setState(() => _personalityAnswers['communication_style'] = value),
        ),
        const SizedBox(height: 16),
        _buildQuizQuestion(
          'What\'s your work style?',
          _workStyles,
              (value) => setState(() => _personalityAnswers['work_style'] = value),
        ),
        const SizedBox(height: 16),
        _buildQuizQuestion(
          'What\'s your learning style?',
          _learningStyles,
              (value) => setState(() => _personalityAnswers['learning_style'] = value),
        ),
      ],
    );
  }

  Widget _buildQuizQuestion(String question, List<String> options, Function(String) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = _personalityAnswers.values.contains(option);
            return ChoiceChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) onSelect(option);
              },
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
              checkmarkColor: Theme.of(context).primaryColor,
            );
          }).toList(),
        ),
      ],
    );
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

  Widget _buildSocialMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Social Media'),
        const SizedBox(height: 16),
        _buildSocialMediaField(
          'LinkedIn',
          _linkedinController,
          Icons.link_rounded,
          Colors.blue[700]!,
        ),
        const SizedBox(height: 12),
        _buildSocialMediaField(
          'GitHub',
          _githubController,
          Icons.code,
          Colors.black87,
        ),
        const SizedBox(height: 12),
        _buildSocialMediaField(
          'Twitter',
          _twitterController,
          Icons.alternate_email,
          Colors.blue[400]!,
        ),
      ],
    );
  }

  Widget _buildSocialMediaField(
      String label,
      TextEditingController controller,
      IconData icon,
      Color color,
      ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 600;
        return TextField(
          controller: controller,
          style: TextStyle(fontSize: isWideScreen ? 16 : 14),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(fontSize: isWideScreen ? 16 : 14),
            prefixIcon: Icon(icon, color: color, size: isWideScreen ? 24 : 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[100],
            contentPadding: EdgeInsets.symmetric(
              horizontal: isWideScreen ? 16 : 12,
              vertical: isWideScreen ? 16 : 12,
            ),
          ),
          onChanged: (_) => _calculateProfileCompletion(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Basic Info'),
            Tab(text: 'Skills & Interests'),
            Tab(text: 'Personality'),
          ],
        ),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          // Basic Info Tab
          SingleChildScrollView(
            child: Column(
              children: [
                _buildProfileHeader(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          label: 'Full Name',
                          icon: Icons.person,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _bioController,
                          label: 'Bio',
                          icon: Icons.description,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _professionController,
                          label: 'Profession',
                          icon: Icons.work,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _companyController,
                          label: 'Company',
                          icon: Icons.business,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _industryController,
                          label: 'Industry',
                          icon: Icons.category,
                        ),
                        const SizedBox(height: 16),
                        _buildLocationField(),
                        const SizedBox(height: 24),
                        _buildSocialMediaSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Skills & Interests Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Skills'),
                const SizedBox(height: 16),
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
                          _calculateProfileCompletion();
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('Weekend Interests'),
                const SizedBox(height: 16),
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
                          _calculateProfileCompletion();
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('Availability'),
                const SizedBox(height: 16),
                _buildAvailabilityGrid(),
              ],
            ),
          ),
          // Personality Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildPersonalityQuiz(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 600;
        return TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(fontSize: isWideScreen ? 16 : 14),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(fontSize: isWideScreen ? 16 : 14),
            prefixIcon: Icon(icon, size: isWideScreen ? 24 : 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[100],
            contentPadding: EdgeInsets.symmetric(
              horizontal: isWideScreen ? 16 : 12,
              vertical: isWideScreen ? 16 : 12,
            ),
          ),
          onChanged: (_) => _calculateProfileCompletion(),
        );
      },
    );
  }

  Widget _buildLocationField() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _locationNameController,
            decoration: InputDecoration(
              labelText: 'Location',
              prefixIcon: const Icon(Icons.location_on),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            onChanged: (_) => _calculateProfileCompletion(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.my_location),
          onPressed: _updateLocation,
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildAvailabilityGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 600;
        final crossAxisCount = isWideScreen ? 3 : 2;
        final aspectRatio = isWideScreen ? 3.0 : 2.5;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvailabilitySection('Weekdays', [
              ['Early Morning', '6-9 AM', 'weekday_morning_early'],
              ['Late Morning', '9-12 PM', 'weekday_morning_late'],
              ['Early Afternoon', '12-3 PM', 'weekday_afternoon_early'],
              ['Late Afternoon', '3-6 PM', 'weekday_afternoon_late'],
              ['Early Evening', '6-9 PM', 'weekday_evening_early'],
              ['Late Evening', '9-12 AM', 'weekday_evening_late'],
            ]),
            const SizedBox(height: 24),
            _buildAvailabilitySection('Weekends', [
              ['Early Morning', '6-9 AM', 'weekend_morning_early'],
              ['Late Morning', '9-12 PM', 'weekend_morning_late'],
              ['Early Afternoon', '12-3 PM', 'weekend_afternoon_early'],
              ['Late Afternoon', '3-6 PM', 'weekend_afternoon_late'],
              ['Early Evening', '6-9 PM', 'weekend_evening_early'],
              ['Late Evening', '9-12 AM', 'weekend_evening_late'],
            ]),
          ],
        );
      },
    );
  }

  Widget _buildAvailabilitySection(String title, List<List<String>> timeSlots) {
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
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 3.0,
          children: timeSlots.map((slot) {
            final isSelected = _availability[slot[2]] ?? false;
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _availability[slot[2]] = !isSelected;
                    _calculateProfileCompletion();
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              slot[0],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              slot[1],
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isSelected ? Icons.check_circle : Icons.cancel,
                        color: isSelected ? Colors.green : Colors.red,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userData = userProvider.user;

      if (userData != null) {
        setState(() {
          _nameController.text = userData.name ?? '';
          _bioController.text = userData.bio ?? '';
          _professionController.text = userData.profession ?? '';
          _companyController.text = userData.company ?? '';
          _industryController.text = userData.industry ?? '';
          _locationNameController.text = userData.locationName ?? '';
          _photoUrl = userData.photoUrl;
          _selectedSkills = List<String>.from(userData.skills ?? []);
          _selectedWeekendInterests = List<String>.from(userData.weekendInterests ?? []);
          _availability = Map<String, bool>.from(userData.availability ?? {});
          _linkedinController.text = userData.linkedin ?? '';
          _githubController.text = userData.github ?? '';
          _twitterController.text = userData.twitter ?? '';
          _personalityAnswers = Map<String, String>.from(userData.personalityAnswers ?? {});
        });
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
      // Collect all data in one map
      final updatedData = {
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'profession': _professionController.text.trim(),
        'company': _companyController.text.trim(),
        'industry': _industryController.text.trim(),
        'locationName': _locationNameController.text.trim(),
        'skills': _selectedSkills,
        'weekendInterests': _selectedWeekendInterests,
        'availability': _availability,
        'personalityAnswers': _personalityAnswers,
        'linkedin': _linkedinController.text.trim(),
        'github': _githubController.text.trim(),
        'twitter': _twitterController.text.trim(),
      };

      // Add photoUrl only if it exists
      if (_photoUrl != null) {
        updatedData['photoUrl'] = _photoUrl!;
      }

      print('Saving profile with data: ${updatedData.keys}');
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Single update call instead of multiple separate calls
      await userProvider.updateUserData(updatedData);

      if (mounted) {
        // Force UI refresh by reinitializing
        await userProvider.initializeUser();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
}