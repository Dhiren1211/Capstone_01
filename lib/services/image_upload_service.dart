import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';

/// Thrown when a photo could not be uploaded. [message] is safe to show to
/// the user.
class ImageUploadException implements Exception {
  const ImageUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Uploads photos to **Cloudinary** (free plan) using an *unsigned upload
/// preset*. This replaces Firebase Storage, which now requires a paid (Blaze)
/// plan.
///
/// How it works:
///   1. The app sends the picture to
///      `https://api.cloudinary.com/v1_1/<cloud_name>/image/upload`
///      together with the name of your unsigned preset.
///   2. Cloudinary stores the file and answers with JSON that contains a
///      permanent HTTPS address (`secure_url`).
///   3. The app saves only that address in Firestore.
///
/// No secret is ever shipped in the app: an unsigned preset can only *add*
/// images (it cannot read, list or delete anything), and you decide in the
/// Cloudinary dashboard which formats / size / folder the preset accepts.
class ImageUploadService {
  ImageUploadService({http.Client? client, String? cloudName, String? preset})
    : _client = client ?? http.Client(),
      _cloudName = cloudName ?? AppConfig.cloudinaryCloudName,
      _preset = preset ?? AppConfig.cloudinaryUploadPreset;

  /// Shared instance used by the screens.
  static final ImageUploadService instance = ImageUploadService();

  /// Cloudinary's free plan accepts images up to 10 MB.
  static const int maxBytes = 10 * 1024 * 1024;

  final http.Client _client;
  final String _cloudName;
  final String _preset;

  bool get isConfigured => _cloudName.isNotEmpty && _preset.isNotEmpty;

  /// Uploads a picture chosen with `image_picker` and returns its HTTPS URL.
  Future<String> uploadXFile(XFile file) async {
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      throw const ImageUploadException(
        'The selected photo could not be read. Please pick it again.',
      );
    }
    return uploadBytes(bytes, filename: file.name);
  }

  /// Uploads raw image bytes and returns the HTTPS URL of the stored image.
  Future<String> uploadBytes(Uint8List bytes, {String filename = ''}) async {
    if (!isConfigured) {
      throw const ImageUploadException(
        'Photo upload is not set up yet. Add CLOUDINARY_CLOUD_NAME and '
        'CLOUDINARY_UPLOAD_PRESET to env.json (see README), or submit '
        'without a photo.',
      );
    }
    if (bytes.isEmpty) {
      throw const ImageUploadException('The selected photo is empty.');
    }
    if (bytes.length > maxBytes) {
      throw const ImageUploadException(
        'That photo is larger than 10 MB. Please choose a smaller one.',
      );
    }

    final uri = Uri.https(
      'api.cloudinary.com',
      '/v1_1/$_cloudName/image/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _preset
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename.trim().isEmpty ? 'upload.jpg' : filename.trim(),
        ),
      );

    final http.Response response;
    try {
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 60));
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ImageUploadException(
        'The upload took too long. Check your connection and try again.',
      );
    } catch (_) {
      throw const ImageUploadException(
        'Could not reach the image server. Check your internet connection '
        'and try again.',
      );
    }

    Map<String, dynamic> body = const <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      // Fall through — handled below by the status code / missing url.
    }

    if (response.statusCode != 200) {
      final error = body['error'];
      final detail = error is Map ? error['message'] : null;
      throw ImageUploadException(
        _friendlyError(response.statusCode, detail is String ? detail : null),
      );
    }

    final url = body['secure_url'];
    if (url is! String || url.isEmpty) {
      throw const ImageUploadException(
        'The image server returned an unexpected answer. Please try again.',
      );
    }
    return url;
  }

  static String _friendlyError(int status, String? detail) {
    final d = (detail ?? '').toLowerCase();
    if (d.contains('upload preset not found')) {
      return 'Cloudinary upload preset not found. Check '
          'CLOUDINARY_UPLOAD_PRESET in env.json.';
    }
    if (d.contains('whitelisted') || d.contains('unsigned')) {
      return 'The Cloudinary upload preset must be set to "Unsigned". '
          'See the README, step "Create the upload preset".';
    }
    if (d.contains('cloud_name') || d.contains('cloud name')) {
      return 'Cloudinary cloud name looks wrong. Check CLOUDINARY_CLOUD_NAME '
          'in env.json.';
    }
    if (status == 413 || d.contains('file size too large')) {
      return 'That photo is too large for the free plan (10 MB max).';
    }
    if (status == 420 || status == 429) {
      return 'The free Cloudinary quota is used up for now. Try again later.';
    }
    if (detail != null && detail.isNotEmpty) {
      return 'Photo upload failed: $detail';
    }
    return 'Photo upload failed (error $status). Please try again.';
  }

  /// Returns a smaller, faster-loading version of a Cloudinary image URL.
  ///
  /// Any other URL is returned unchanged. The transformation only makes the
  /// picture *smaller* (`c_limit`) and re-compresses it (`q_auto`).
  static String optimizedUrl(String url, {int width = 800}) {
    final match = _cloudinaryUpload.firstMatch(url);
    if (match == null) return url;
    return '${match.group(1)}c_limit,w_$width,q_auto/${match.group(2)}';
  }

  static final RegExp _cloudinaryUpload = RegExp(
    r'^(https://res\.cloudinary\.com/[^/]+/image/upload/)(v\d+/.+)$',
  );

  void dispose() => _client.close();
}
