import 'package:flutter/foundation.dart';

import '../network/uploaded_file.dart';
import '../validation/image_rules.dart';

@immutable
class ImageUpload {
  const ImageUpload({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  String get contentType => ImageRules.detect(bytes) ?? ImageRules.unknown;

  String? get refusal => ImageRules.refuse(bytes);

  // The field is named where the call is made rather than held on the file.
  UploadedFile underField(String field) => UploadedFile(
    field: field,
    name: name,
    bytes: bytes,
    contentType: contentType,
  );
}
