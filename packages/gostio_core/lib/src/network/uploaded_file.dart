import 'package:flutter/foundation.dart';

// A file as a multipart body carries it: the field it is bound from, and the
// bytes under a name and a type.
@immutable
class UploadedFile {
  const UploadedFile({
    required this.field,
    required this.name,
    required this.bytes,
    required this.contentType,
  });

  final String field;
  final String name;
  final Uint8List bytes;
  final String contentType;
}
