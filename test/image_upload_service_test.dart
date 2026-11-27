import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartfind/services/image_upload_service.dart';

ImageUploadService _service(
  http.Response Function(http.Request request) handler, {
  String cloud = 'demo-cloud',
  String preset = 'smartfind_unsigned',
}) {
  return ImageUploadService(
    client: MockClient((request) async => handler(request)),
    cloudName: cloud,
    preset: preset,
  );
}

final Uint8List _photo = Uint8List.fromList(List<int>.generate(64, (i) => i));

void main() {
  group('uploadBytes', () {
    test(
      'posts to the right Cloudinary endpoint and returns secure_url',
      () async {
        http.Request? seen;
        final service = _service((request) {
          seen = request;
          return http.Response(
            jsonEncode({
              'secure_url':
                  'https://res.cloudinary.com/demo-cloud/image/upload/v1/a.jpg',
              'public_id': 'a',
            }),
            200,
          );
        });

        final url = await service.uploadBytes(_photo, filename: 'cat.jpg');

        expect(
          url,
          'https://res.cloudinary.com/demo-cloud/image/upload/v1/a.jpg',
        );
        expect(seen, isNotNull);
        expect(seen!.method, 'POST');
        expect(
          seen!.url.toString(),
          'https://api.cloudinary.com/v1_1/demo-cloud/image/upload',
        );
        final body = latin1.decode(seen!.bodyBytes);
        expect(body, contains('name="upload_preset"'));
        expect(body, contains('smartfind_unsigned'));
        expect(body, contains('filename="cat.jpg"'));
      },
    );

    test('refuses to run when Cloudinary is not configured', () async {
      final service = _service(
        (_) => http.Response('{}', 200),
        cloud: '',
        preset: '',
      );
      expect(service.isConfigured, isFalse);
      await expectLater(
        service.uploadBytes(_photo),
        throwsA(isA<ImageUploadException>()),
      );
    });

    test('rejects empty and oversized files before any network call', () async {
      var calls = 0;
      final service = _service((_) {
        calls++;
        return http.Response('{}', 200);
      });
      await expectLater(
        service.uploadBytes(Uint8List(0)),
        throwsA(isA<ImageUploadException>()),
      );
      await expectLater(
        service.uploadBytes(Uint8List(ImageUploadService.maxBytes + 1)),
        throwsA(isA<ImageUploadException>()),
      );
      expect(calls, 0);
    });

    test('explains a missing upload preset', () async {
      final service = _service(
        (_) => http.Response(
          jsonEncode({
            'error': {'message': 'Upload preset not found'},
          }),
          400,
        ),
      );
      await expectLater(
        service.uploadBytes(_photo),
        throwsA(
          isA<ImageUploadException>().having(
            (e) => e.message,
            'message',
            contains('CLOUDINARY_UPLOAD_PRESET'),
          ),
        ),
      );
    });

    test('explains a preset that is not unsigned', () async {
      final service = _service(
        (_) => http.Response(
          jsonEncode({
            'error': {
              'message':
                  'Upload preset must be whitelisted for unsigned uploads',
            },
          }),
          400,
        ),
      );
      await expectLater(
        service.uploadBytes(_photo),
        throwsA(
          isA<ImageUploadException>().having(
            (e) => e.message,
            'message',
            contains('Unsigned'),
          ),
        ),
      );
    });

    test('explains a wrong cloud name', () async {
      final service = _service(
        (_) => http.Response(
          jsonEncode({
            'error': {'message': 'Invalid cloud_name nope'},
          }),
          401,
        ),
      );
      await expectLater(
        service.uploadBytes(_photo),
        throwsA(
          isA<ImageUploadException>().having(
            (e) => e.message,
            'message',
            contains('CLOUDINARY_CLOUD_NAME'),
          ),
        ),
      );
    });

    test('reports a network failure in plain words', () async {
      final service = ImageUploadService(
        client: MockClient((_) async => throw http.ClientException('offline')),
        cloudName: 'demo-cloud',
        preset: 'p',
      );
      await expectLater(
        service.uploadBytes(_photo),
        throwsA(
          isA<ImageUploadException>().having(
            (e) => e.message,
            'message',
            contains('internet'),
          ),
        ),
      );
    });

    test('treats a 200 without secure_url as an error', () async {
      final service = _service((_) => http.Response('{}', 200));
      await expectLater(
        service.uploadBytes(_photo),
        throwsA(isA<ImageUploadException>()),
      );
    });
  });

  group('optimizedUrl', () {
    const original =
        'https://res.cloudinary.com/demo-cloud/image/upload/v1700000000/smartfind/a.jpg';

    test('adds a size + quality transformation', () {
      expect(
        ImageUploadService.optimizedUrl(original, width: 400),
        'https://res.cloudinary.com/demo-cloud/image/upload/'
        'c_limit,w_400,q_auto/v1700000000/smartfind/a.jpg',
      );
    });

    test('leaves other URLs untouched', () {
      const other = 'https://example.com/photo.jpg';
      expect(ImageUploadService.optimizedUrl(other), other);
      expect(ImageUploadService.optimizedUrl(''), '');
    });

    test('does not stack a second transformation', () {
      const transformed =
          'https://res.cloudinary.com/demo-cloud/image/upload/w_100/v1/a.jpg';
      expect(ImageUploadService.optimizedUrl(transformed), transformed);
    });
  });
}
