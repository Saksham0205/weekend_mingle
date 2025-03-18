import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group_model.dart';
import '../models/user_model.dart';
import 'dart:io';
import 'cloudinary_services.dart';
import 'location_service.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final LocationService _locationService = LocationService();

  // Create a new group
  Future<Group> createGroup({
    required String name,
    required String description,
    required String category,
    File? imageFile,
    bool isPublic = true,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    // Get user data
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = UserModel.fromFirestore(userDoc);

    // Upload image to Cloudinary if provided
    String? imageUrl;
    if (imageFile != null) {
      try {
        imageUrl = await CloudinaryService.uploadImage(imageFile.path as File);
      } catch (e) {
        throw Exception("Failed to upload image: $e");
      }
    }

    // Get user location if available
    GeoPoint? location = userData.location;
    String? locationName = userData.locationName;

    // Create group
    final groupRef = _firestore.collection('groups').doc();
    final group = Group(
      id: groupRef.id,
      name: name,
      description: description,
      creatorId: user.uid,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
      members: [user.uid],
      admins: [user.uid],
      pendingMembers: [],
      isPublic: isPublic,
      category: category,
      location: location,
      locationName: locationName,
      memberCount: 1,
      metadata: {
        'creatorName': userData.name,
        'creatorPhotoUrl': userData.photoUrl,
      },
    );

    await groupRef.set(group.toMap());
    return group;
  }

  // Get groups the user is a member of
  Stream<List<Group>> getUserGroups(String userId) {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Group.fromFirestore(doc)).toList();
    });
  }

  // Get groups based on location and category
  Future<List<Group>> getNearbyGroups({
    required double radius, // in km
    String? category,
    bool includePrivate = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    // Get user location
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = UserModel.fromFirestore(userDoc);

    if (userData.location == null) {
      throw Exception("User location not available");
    }

    // Create a GeoPoint to represent user location
    final center = userData.location!;

    // Calculate the bounds for the query
    final bounds = await _locationService.calculateGeoBounds(
        center.latitude,
        center.longitude,
        radius
    );

    // Query based on location bounds
    Query query = _firestore
        .collection('groups')
        .orderBy('location.latitude')
        .orderBy('location.longitude')
        .startAt([bounds['minLat'], bounds['minLng']])
        .endAt([bounds['maxLat'], bounds['maxLng']]);

    // Apply category filter if provided
    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }

    // Apply privacy filter
    if (!includePrivate) {
      query = query.where('isPublic', isEqualTo: true);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Group.fromFirestore(doc)).toList();
  }

  // Request to join a group
  Future<void> requestToJoinGroup(String groupId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    final groupRef = _firestore.collection('groups').doc(groupId);
    final groupDoc = await groupRef.get();

    if (!groupDoc.exists) {
      throw Exception("Group not found");
    }

    final group = Group.fromFirestore(groupDoc);

    // Check if already a member or has pending request
    if (group.members.contains(user.uid)) {
      throw Exception("Already a member of this group");
    }

    if (group.pendingMembers.contains(user.uid)) {
      throw Exception("Already requested to join this group");
    }

    // If public group, add directly as member
    if (group.isPublic) {
      await groupRef.update({
        'members': FieldValue.arrayUnion([user.uid]),
        'memberCount': FieldValue.increment(1),
      });
    } else {
      // For private groups, add to pending members
      await groupRef.update({
        'pendingMembers': FieldValue.arrayUnion([user.uid]),
      });
    }
  }

  // Approve/reject join request
  Future<void> respondToJoinRequest(String groupId, String userId, bool approve) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    final groupRef = _firestore.collection('groups').doc(groupId);
    final groupDoc = await groupRef.get();

    if (!groupDoc.exists) {
      throw Exception("Group not found");
    }

    final group = Group.fromFirestore(groupDoc);

    // Check if requester exists in pending
    if (!group.pendingMembers.contains(userId)) {
      throw Exception("No pending request from this user");
    }

    // Check if current user is an admin
    if (!group.isAdmin(user.uid)) {
      throw Exception("Not authorized to approve/reject requests");
    }

    // Update the group
    final batch = _firestore.batch();

    // Remove from pending in either case
    batch.update(groupRef, {
      'pendingMembers': FieldValue.arrayRemove([userId]),
    });

    if (approve) {
      // Add to members if approved
      batch.update(groupRef, {
        'members': FieldValue.arrayUnion([userId]),
        'memberCount': FieldValue.increment(1),
      });
    }

    await batch.commit();
  }

  // Leave a group
  Future<void> leaveGroup(String groupId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    final groupRef = _firestore.collection('groups').doc(groupId);
    final groupDoc = await groupRef.get();

    if (!groupDoc.exists) {
      throw Exception("Group not found");
    }

    final group = Group.fromFirestore(groupDoc);

    // Check if a member
    if (!group.members.contains(user.uid)) {
      return; // Not a member, nothing to do
    }

    // Check if this is the last member
    if (group.members.length <= 1) {
      // Delete the group if last member
      await groupRef.delete();
      return;
    }

    // Check if this is the last admin
    final isAdmin = group.admins.contains(user.uid);
    final batch = _firestore.batch();

    // Remove from members
    batch.update(groupRef, {
      'members': FieldValue.arrayRemove([user.uid]),
      'memberCount': FieldValue.increment(-1),
    });

    if (isAdmin) {
      // Remove from admins
      batch.update(groupRef, {
        'admins': FieldValue.arrayRemove([user.uid]),
      });

      // If this was the last admin, make someone else an admin
      if (group.admins.length <= 1) {
        final newAdminId = group.members.firstWhere(
              (memberId) => memberId != user.uid,
          orElse: () => '',
        );

        if (newAdminId.isNotEmpty) {
          batch.update(groupRef, {
            'admins': FieldValue.arrayUnion([newAdminId]),
          });
        }
      }
    }

    await batch.commit();
  }

  // Update group details
  Future<void> updateGroup({
    required String groupId,
    String? name,
    String? description,
    String? category,
    File? imageFile,
    bool? isPublic,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    final groupRef = _firestore.collection('groups').doc(groupId);
    final groupDoc = await groupRef.get();

    if (!groupDoc.exists) {
      throw Exception("Group not found");
    }

    final group = Group.fromFirestore(groupDoc);

    // Check if user is an admin
    if (!group.isAdmin(user.uid)) {
      throw Exception("Not authorized to update group");
    }

    // Upload new image if provided
    String? imageUrl;
    if (imageFile != null) {
      try {
        imageUrl = await CloudinaryService.uploadImage(imageFile.path as File);
      } catch (e) {
        throw Exception("Failed to upload image: $e");
      }
    }

    // Create update map with only provided fields
    final Map<String, dynamic> updates = {};

    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (category != null) updates['category'] = category;
    if (imageUrl != null) updates['imageUrl'] = imageUrl;
    if (isPublic != null) updates['isPublic'] = isPublic;

    if (updates.isNotEmpty) {
      await groupRef.update(updates);
    }
  }

  // Get groups by category
  Stream<List<Group>> getGroupsByCategory(String category) {
    return _firestore
        .collection('groups')
        .where('category', isEqualTo: category)
        .where('isPublic', isEqualTo: true)
        .orderBy('memberCount', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Group.fromFirestore(doc)).toList();
    });
  }

  // Search groups by name
  Future<List<Group>> searchGroups(String query) async {
    // Convert query to lowercase for case-insensitive search
    final lowercaseQuery = query.toLowerCase();

    // Get all public groups
    final snapshot = await _firestore
        .collection('groups')
        .where('isPublic', isEqualTo: true)
        .get();

    // Filter locally by name
    final filteredGroups = snapshot.docs
        .map((doc) => Group.fromFirestore(doc))
        .where((group) =>
    group.name.toLowerCase().contains(lowercaseQuery) ||
        group.description.toLowerCase().contains(lowercaseQuery))
        .toList();

    return filteredGroups;
  }

  // Promote a member to admin
  Future<void> promoteToAdmin(String groupId, String userId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    final groupRef = _firestore.collection('groups').doc(groupId);
    final groupDoc = await groupRef.get();

    if (!groupDoc.exists) {
      throw Exception("Group not found");
    }

    final group = Group.fromFirestore(groupDoc);

    // Check if current user is an admin
    if (!group.isAdmin(user.uid)) {
      throw Exception("Not authorized to promote members");
    }

    // Check if target user is a member
    if (!group.members.contains(userId)) {
      throw Exception("User is not a member of this group");
    }

    // Check if already an admin
    if (group.admins.contains(userId)) {
      return; // Already an admin, nothing to do
    }

    // Promote to admin
    await groupRef.update({
      'admins': FieldValue.arrayUnion([userId]),
    });
  }
}