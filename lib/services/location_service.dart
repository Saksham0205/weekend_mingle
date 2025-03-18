import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:math';
import 'package:flutter/material.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Request location permission and get current position
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    // Check location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // Get current position
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // For backwards compatibility with existing code
  Future<Position?> getCurrentLocation() async {
    try {
      return await getCurrentPosition();
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  // Get address from coordinates
  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.locality}, ${place.administrativeArea}, ${place.country}';
      }
      return 'Unknown location';
    } catch (e) {
      debugPrint('Error getting address: $e');
      return 'Unknown location';
    }
  }

  // Get coordinates from address
  Future<GeoPoint?> getCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        Location location = locations[0];
        return GeoPoint(location.latitude, location.longitude);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting coordinates: $e');
      return null;
    }
  }

  // Format location coordinates to a readable string
  static String getLocationDescription(GeoPoint location) {
    // Format location to 2 decimal places
    return '${location.latitude.toStringAsFixed(2)}, ${location.longitude.toStringAsFixed(2)}';
  }

  // Update user location in Firestore
  Future<void> updateUserLocation(String userId, GeoPoint location, String locationName) async {
    await _firestore.collection('users').doc(userId).update({
      'location': location,
      'locationName': locationName,
      'lastLocationUpdate': FieldValue.serverTimestamp(),
    });
  }

  // Calculate distance between two GeoPoints (Haversine formula)
  double calculateDistance(GeoPoint point1, GeoPoint point2) {
    const earthRadius = 6371.0; // Earth radius in kilometers
    final lat1 = point1.latitude * pi / 180;
    final lon1 = point1.longitude * pi / 180;
    final lat2 = point2.latitude * pi / 180;
    final lon2 = point2.longitude * pi / 180;

    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  // Get nearby users
  Future<List<Map<String, dynamic>>> getNearbyUsers(
      String currentUserId, double radiusInKm) async {
    // Get current user's location
    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    if (!userDoc.exists) throw Exception('User not found');

    final userData = userDoc.data()!;
    final userLocation = userData['location'] as GeoPoint?;

    if (userLocation == null) {
      throw Exception('User location not available');
    }

    // Calculate the bounds for the query
    final bounds = await calculateGeoBounds(
        userLocation.latitude,
        userLocation.longitude,
        radiusInKm
    );

    // Query users within the bounding box
    final snapshot = await _firestore
        .collection('users')
        .where('location', isGreaterThan:
    GeoPoint(bounds['minLat']!, bounds['minLng']!))
        .where('location', isLessThan:
    GeoPoint(bounds['maxLat']!, bounds['maxLng']!))
        .get();

    // Filter users by exact distance and exclude current user
    final nearbyUsers = snapshot.docs
        .map((doc) => {
      'uid': doc.id,
      'data': doc.data(),
      'distance': calculateDistance(
          userLocation,
          doc.data()['location'] as GeoPoint
      ),
    })
        .where((user) =>
    user['uid'] != currentUserId &&
        (user['distance'] as double) <= radiusInKm)
        .toList();

    // Sort by distance
    nearbyUsers.sort((a, b) =>
        (a['distance'] as double).compareTo(b['distance'] as double));

    return nearbyUsers;
  }

  // Calculate geographical bounds for a radius
  Future<Map<String, double>> calculateGeoBounds(
      double lat, double lng, double radiusInKm) async {
    // Earth's radius in kilometers
    const earthRadius = 6371.0;

    // Latitude: 1 degree = 111.2 km
    // Longitude: 1 degree = 111.2 * cos(latitude) km
    double latDelta = radiusInKm / 111.2;
    double lngDelta = radiusInKm / (111.2 * cos(lat * pi / 180));

    return {
      'minLat': lat - latDelta,
      'maxLat': lat + latDelta,
      'minLng': lng - lngDelta,
      'maxLng': lng + lngDelta,
    };
  }

  // Get nearby weekend activities
  Future<List<Map<String, dynamic>>> getNearbyWeekendActivities(
      String currentUserId, double radiusInKm) async {
    // Get current user's location
    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    if (!userDoc.exists) throw Exception('User not found');

    final userData = userDoc.data()!;
    final userLocation = userData['location'] as GeoPoint?;

    if (userLocation == null) {
      throw Exception('User location not available');
    }

    // Calculate the bounds for the query
    final bounds = await calculateGeoBounds(
        userLocation.latitude,
        userLocation.longitude,
        radiusInKm
    );

    // Get the current timestamp
    final now = DateTime.now();

    // Query weekend activities within the bounding box and in the future
    final snapshot = await _firestore
        .collection('weekend_activities')
        .where('locationCoordinates', isGreaterThan:
    GeoPoint(bounds['minLat']!, bounds['minLng']!))
        .where('locationCoordinates', isLessThan:
    GeoPoint(bounds['maxLat']!, bounds['maxLng']!))
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .get();

    // Filter activities by exact distance
    final nearbyActivities = snapshot.docs
        .map((doc) => {
      'id': doc.id,
      'data': doc.data(),
      'distance': calculateDistance(
          userLocation,
          doc.data()['locationCoordinates'] as GeoPoint
      ),
    })
        .where((activity) =>
    (activity['distance'] as double) <= radiusInKm)
        .toList();

    // Sort by distance
    nearbyActivities.sort((a, b) =>
        (a['distance'] as double).compareTo(b['distance'] as double));

    return nearbyActivities;
  }

  // Get nearby groups
  Future<List<Map<String, dynamic>>> getNearbyGroups(
      String currentUserId, double radiusInKm) async {
    // Get current user's location
    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    if (!userDoc.exists) throw Exception('User not found');

    final userData = userDoc.data()!;
    final userLocation = userData['location'] as GeoPoint?;

    if (userLocation == null) {
      throw Exception('User location not available');
    }

    // Calculate the bounds for the query
    final bounds = await calculateGeoBounds(
        userLocation.latitude,
        userLocation.longitude,
        radiusInKm
    );

    // Query groups within the bounding box
    final snapshot = await _firestore
        .collection('groups')
        .where('location', isGreaterThan:
    GeoPoint(bounds['minLat']!, bounds['minLng']!))
        .where('location', isLessThan:
    GeoPoint(bounds['maxLat']!, bounds['maxLng']!))
        .where('isPublic', isEqualTo: true)
        .get();

    // Filter groups by exact distance
    final nearbyGroups = snapshot.docs
        .map((doc) => {
      'id': doc.id,
      'data': doc.data(),
      'distance': calculateDistance(
          userLocation,
          doc.data()['location'] as GeoPoint
      ),
    })
        .where((group) =>
    (group['distance'] as double) <= radiusInKm)
        .toList();

    // Sort by distance
    nearbyGroups.sort((a, b) =>
        (a['distance'] as double).compareTo(b['distance'] as double));

    return nearbyGroups;
  }

  // Convert distance to human-readable format
  String getReadableDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      // Convert to meters if less than 1 km
      final meters = (distanceInKm * 1000).round();
      return '$meters m';
    } else if (distanceInKm < 10) {
      // Show one decimal for distances less than 10 km
      return '${distanceInKm.toStringAsFixed(1)} km';
    } else {
      // Round to nearest km for larger distances
      return '${distanceInKm.round()} km';
    }
  }
}