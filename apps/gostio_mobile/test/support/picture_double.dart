import 'dart:typed_data';

import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/profile/data/picture_source.dart';

// The camera and the gallery, answered without a phone behind them. What the
// door answers is set by the test; which door was opened is recorded.
class PictureSourceDouble implements PictureSource {
  PictureSourceDouble({this.answer = const PictureDeclined()});

  PictureChoice answer;

  final List<PictureOrigin> opened = <PictureOrigin>[];

  @override
  Future<PictureChoice> pick(PictureOrigin origin) async {
    opened.add(origin);

    return answer;
  }
}

// A picture the rules accept: the signature is what `ImageRules` reads a type
// off, and nothing here looks at the bytes after it.
ImageUpload picture({String name = 'face.png'}) => ImageUpload(
  name: name,
  bytes: Uint8List.fromList(<int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x01,
    0x02,
  ]),
);

// Bytes of no kind the server takes. A document renamed to `.png` arrives
// exactly like this.
ImageUpload notAPicture({String name = 'lease.png'}) => ImageUpload(
  name: name,
  bytes: Uint8List.fromList(<int>[0x25, 0x50, 0x44, 0x46, 0x2D]),
);
