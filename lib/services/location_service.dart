import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    try {
      return await Geolocator.getCurrentPosition();
    } catch (e) {
      throw Exception('Error getting location: $e');
    }
  }

  Future<String?> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        final components = [
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((element) => element != null && element.isNotEmpty).toList();

        return components.join(', ');
      }
      return null;
    } catch (e) {
      throw Exception('Error getting address: $e');
    }
  }

  // static Future<List<Map<String, dynamic>>> getNearbyUsers(
  //     GeoPoint userLocation,
  //     double radiusInKm,
  //     ) async {
  //   try {
  //     final QuerySnapshot<Map<String, dynamic>> snapshot =
  //     await FirebaseFirestore.instance.collection('users').get();
  //
  //     final List<Map<String, dynamic>> nearbyUsers = [];
  //
  //     for (final doc in snapshot.docs) {
  //       final userData = doc.data();
  //       final location = userData['location'] as GeoPoint?;
  //
  //       if (location != null) {
  //         final distance = Geolocator.distanceBetween(
  //           userLocation.latitude,
  //           userLocation.longitude,
  //           location.latitude,
  //           location.longitude,
  //         );
  //
  //         // Convert distance from meters to kilometers
  //         if (distance / 1000 <= radiusInKm) {
  //           nearbyUsers.add({
  //             ...userData,
  //             'distance': distance / 1000, // distance in kilometers
  //           });
  //         }
  //       }
  //     }
  //
  //     // Sort by distance
  //     nearbyUsers.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
  //
  //     return nearbyUsers;
  //   } catch (e) {
  //     print('Error getting nearby users: $e');
  //     return [];
  //   }
  // }

  static String getLocationDescription(GeoPoint location) {
    // Format location to 2 decimal places
    return '${location.latitude.toStringAsFixed(2)}, ${location.longitude.toStringAsFixed(2)}';
  }

}