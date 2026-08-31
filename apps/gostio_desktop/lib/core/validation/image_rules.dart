import 'dart:typed_data';

// What the server accepts as an uploaded image, mirrored so a file it would
// refuse is refused here first and named the same way.
abstract final class ImageRules {
  static const int maximumBytes = 4 * 1024 * 1024;

  static const String jpeg = 'image/jpeg';
  static const String png = 'image/png';
  static const String webp = 'image/webp';

  static const String unknown = 'application/octet-stream';

  static const List<String> allowed = <String>[jpeg, png, webp];

  static const List<String> extensions = <String>['jpg', 'jpeg', 'png', 'webp'];

  static String? detect(Uint8List content) {
    if (_matches(content, 0, _jpegSignature)) {
      return jpeg;
    }

    if (_matches(content, 0, _pngSignature)) {
      return png;
    }

    return _matches(content, 0, _riffTag) && _matches(content, 8, _webpTag)
        ? webp
        : null;
  }

  static String? refuse(Uint8List content) {
    if (content.isEmpty) {
      return 'Choose an image to upload.';
    }

    if (content.length > maximumBytes) {
      return 'An image is at most ${maximumBytes ~/ (1024 * 1024)} MB.';
    }

    return detect(content) == null
        ? 'An image has to be one of ${allowed.join(', ')}.'
        : null;
  }

  static bool _matches(Uint8List content, int at, List<int> signature) {
    if (content.length < at + signature.length) {
      return false;
    }

    for (int index = 0; index < signature.length; index++) {
      if (content[at + index] != signature[index]) {
        return false;
      }
    }

    return true;
  }

  static const List<int> _jpegSignature = <int>[0xFF, 0xD8, 0xFF];
  static const List<int> _pngSignature = <int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ];
  static const List<int> _riffTag = <int>[0x52, 0x49, 0x46, 0x46];
  static const List<int> _webpTag = <int>[0x57, 0x45, 0x42, 0x50];
}
