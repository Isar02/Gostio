import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';

void main() {
  group('detect', () {
    test('reads the type the bytes prove', () {
      expect(ImageRules.detect(_jpeg), ImageRules.jpeg);
      expect(ImageRules.detect(_png), ImageRules.png);
      expect(ImageRules.detect(_webp), ImageRules.webp);
    });

    test('a file with an image name and other bytes is not an image', () {
      expect(ImageRules.detect(_bytes(<int>[0x25, 0x50, 0x44, 0x46])), isNull);
    });

    test('a truncated signature is not read as the type it starts as', () {
      expect(ImageRules.detect(_bytes(<int>[0xFF, 0xD8])), isNull);
    });
  });

  group('refuse', () {
    test('says what the server says about a file that is not an image', () {
      expect(
        ImageRules.refuse(_bytes(<int>[0x25, 0x50, 0x44, 0x46])),
        'An image has to be one of image/jpeg, image/png, image/webp.',
      );
    });

    test('names the same bound the server counts in', () {
      final Uint8List large = Uint8List(ImageRules.maximumBytes + 1)
        ..setRange(0, 3, <int>[0xFF, 0xD8, 0xFF]);

      expect(ImageRules.refuse(large), 'An image is at most 4 MB.');
    });

    test('an empty file is refused before its type is read', () {
      expect(ImageRules.refuse(Uint8List(0)), 'Choose an image to upload.');
    });

    test('an image the server would take is not refused', () {
      expect(ImageRules.refuse(_jpeg), isNull);
    });
  });
}

Uint8List _bytes(List<int> content) => Uint8List.fromList(content);

final Uint8List _jpeg = _bytes(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);

final Uint8List _png = _bytes(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
]);

final Uint8List _webp = _bytes(<int>[
  0x52,
  0x49,
  0x46,
  0x46,
  0x24,
  0x00,
  0x00,
  0x00,
  0x57,
  0x45,
  0x42,
  0x50,
]);
