import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/responsive_helper.dart';

class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Position? _currentPosition;
  List<String> _interests = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadUserInterests();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      // Handle location error
    }
  }

  Future<void> _loadUserInterests() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.user != null) {
      final userDoc = await _firestore
          .collection('users')
          .doc(userProvider.user!.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          _interests = List<String>.from(userDoc.data()?['interests'] ?? []);
        });
      }
    }
  }

  Widget _buildCategoryCard(String category, IconData icon) {
    return Card(
      child: InkWell(
        onTap: () {
          // Navigate to category-specific screen
        },
        child: Padding(
          padding: EdgeInsets.all(ResponsiveHelper.getResponsiveWidth(16)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: ResponsiveHelper.getResponsiveWidth(32)),
              SizedBox(height: ResponsiveHelper.getResponsiveHeight(8)),
              Text(
                category,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveHelper.getResponsiveFontSize(14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNearbyProfessionals() {
    if (_currentPosition == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .where('isProfileComplete', isEqualTo: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(14),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final userData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return Card(
              margin: EdgeInsets.symmetric(
                horizontal: ResponsiveHelper.getResponsiveWidth(16),
                vertical: ResponsiveHelper.getResponsiveHeight(8),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  radius: ResponsiveHelper.getResponsiveWidth(20),
                  backgroundImage: userData['photoUrl'] != null
                      ? CachedNetworkImageProvider(userData['photoUrl'])
                      : null,
                  child: userData['photoUrl'] == null
                      ? Icon(
                          Icons.person,
                          size: ResponsiveHelper.getResponsiveWidth(20),
                        )
                      : null,
                ),
                title: Text(
                  userData['name'] ?? 'Anonymous',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(14),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  userData['profession'] ?? 'No profession listed',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(12),
                  ),
                ),
                trailing: ElevatedButton(
                  onPressed: () {
                    // Navigate to profile or connect
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveHelper.getResponsiveWidth(12),
                      vertical: ResponsiveHelper.getResponsiveHeight(8),
                    ),
                  ),
                  child: Text(
                    'Connect',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(12),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTrendingEvents() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('events')
          .orderBy('attendees', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(14),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return SizedBox(
          height: ResponsiveHelper.getResponsiveHeight(200),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final eventData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              return Card(
                margin: EdgeInsets.all(ResponsiveHelper.getResponsiveWidth(8)),
                child: Container(
                  width: ResponsiveHelper.getResponsiveWidth(200),
                  padding: EdgeInsets.all(ResponsiveHelper.getResponsiveWidth(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (eventData['imageUrl'] != null)
                        Expanded(
                          child: Image.network(
                            eventData['imageUrl'],
                            fit: BoxFit.cover,
                          ),
                        ),
                      SizedBox(height: ResponsiveHelper.getResponsiveHeight(8)),
                      Text(
                        eventData['name'] ?? 'Unnamed Event',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveHelper.getResponsiveFontSize(14),
                        ),
                      ),
                      Text(
                        eventData['description'] ?? 'No description',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(12),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Initialize responsive helper
    ResponsiveHelper.init(context);
    
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _isLoading = true;
          });
          await _getCurrentLocation();
          await _loadUserInterests();
          setState(() {
            _isLoading = false;
          });
        },
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(ResponsiveHelper.getResponsiveWidth(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explore',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(24),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.getResponsiveHeight(16)),
                    Text(
                      'Categories',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(18),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.getResponsiveHeight(8)),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: ResponsiveHelper.isTablet(context) ? 4 : 2,
                      crossAxisSpacing: ResponsiveHelper.getResponsiveWidth(8),
                      mainAxisSpacing: ResponsiveHelper.getResponsiveHeight(8),
                      children: [
                        _buildCategoryCard('Networking Events', Icons.people),
                        _buildCategoryCard('Workshops', Icons.school),
                        _buildCategoryCard('Conferences', Icons.mic),
                        _buildCategoryCard('Meetups', Icons.groups),
                      ],
                    ),
                    SizedBox(height: ResponsiveHelper.getResponsiveHeight(24)),
                    Text(
                      'Professionals Near You',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(18),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.getResponsiveHeight(8)),
                    _buildNearbyProfessionals(),
                    SizedBox(height: ResponsiveHelper.getResponsiveHeight(24)),
                    Text(
                      'Trending Events',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(18),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.getResponsiveHeight(8)),
                    _buildTrendingEvents(),
                    SizedBox(height: ResponsiveHelper.getResponsiveHeight(24)),
                  ],
                ),
              ),
      ),
    );
  }
}