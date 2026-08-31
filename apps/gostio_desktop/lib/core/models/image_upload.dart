import 'package:flutter/foundation.dart';

import '../validation/image_rules.dart';

@immutable
class ImageUpload {
  const ImageUpload({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  String get contentType => ImageRules.detect(bytes) ?? ImageRules.unknown;

  String? get refusal => ImageRules.refuse(bytes);
}
