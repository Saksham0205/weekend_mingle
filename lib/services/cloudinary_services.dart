import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  final cloudinary = CloudinaryPublic(
    'dpgrnxjay',  // Your Cloudinary cloud name
    'Weekend Minlge',  // Your upload preset
    cache: false,
  );

  // Replace these with your Cloudinary credentials
  static const String cloudName = 'dpgrnxjay';
  static const String uploadPreset = 'Weekend Minlge';
  static const String apiKey = '426339432116811';

  static Future<String?> uploadImage(File imageFile) async {
    return uploadFile(imageFile, resourceType: 'image');
  }

  static Future<String?> uploadFile(File file, {String resourceType = 'auto'}) async {
    try {
      final url = Uri.parse(
          'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload');

      // Get file extension
      final extension = path.extension(file.path).toLowerCase();

      // Create form data
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..fields['resource_type'] = resourceType
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: '${DateTime.now().millisecondsSinceEpoch}$extension',
        ));

      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);
      final jsonData = jsonDecode(responseString);

      if (response.statusCode == 200) {
        return jsonData['secure_url'];
      }
      return null;
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  Future<String> uploadProfileImage(String userId, File imageFile) async {
    try {
      // Create a unique file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final publicId = 'mingle/profiles/$userId/$timestamp';

      // Upload to Cloudinary
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          publicId: publicId,
          folder: 'mingle/profiles',
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      // Apply transformations using the getOptimizedImageUrl method
      final optimizedUrl = getOptimizedImageUrl(
        response.secureUrl,
        width: 400,
        height: 400,
        transformation: 'c_fill,g_face,e_auto_contrast,e_auto_color,e_improve,q_90',
      );

      return optimizedUrl;
    } catch (e) {
      throw Exception('Error uploading image to Cloudinary: $e');
    }
  }

  Future<void> deleteProfileImage(String imageUrl) async {
    try {
      // Extract public ID from the URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      final publicId = pathSegments
          .skipWhile((segment) => segment != 'mingle')
          .join('/')
          .replaceAll(RegExp(r'\.[^.]+$'), '');

      // Note: Deletion requires backend implementation
      // Cloudinary Public package doesn't support deletion
      // You'll need to implement this on your backend
      print('To delete image with public ID: $publicId');
      print('This operation requires backend implementation');
    } catch (e) {
      throw Exception('Error preparing image deletion: $e');
    }
  }

  String getOptimizedImageUrl(String originalUrl, {
    int? width,
    int? height,
    String? transformation,
  }) {
    try {
      final uri = Uri.parse(originalUrl);
      final pathSegments = uri.pathSegments;

      // Find the upload segment index
      final uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex == -1) return originalUrl;

      // Build transformation string
      final transforms = <String>[];

      if (width != null) transforms.add('w_$width');
      if (height != null) transforms.add('h_$height');
      if (transformation != null) transforms.add(transformation);

      // If no transformations, return original URL
      if (transforms.isEmpty) return originalUrl;

      // Insert transformations after 'upload' segment
      final newPathSegments = [
        ...pathSegments.sublist(0, uploadIndex + 1),
        transforms.join(','),
        ...pathSegments.sublist(uploadIndex + 1),
      ];

      // Reconstruct the URL
      return uri.replace(pathSegments: newPathSegments).toString();
    } catch (e) {
      print('Error optimizing image URL: $e');
      return originalUrl;
    }
  }
}