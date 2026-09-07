import 'package:gostio_core/gostio_core.dart';

// Where a picture comes from on a phone. The gallery and the camera are two
// different acts rather than one file dialogue, so the reader chooses which
// before anything opens.
enum PictureOrigin { camera, gallery }

// The camera and the gallery, named as what this client needs of them rather
// than as the plugin that reaches them. Every type belonging to that plugin
// stops at the implementation.
abstract interface class PictureSource {
  Future<PictureChoice> pick(PictureOrigin origin);
}

// The three ways choosing ends, and the reason this is a result rather than a
// value plus an exception: a reader who backed out of the camera did nothing
// wrong, and a camera that would not open is reported rather than thrown.
sealed class PictureChoice {
  const PictureChoice();
}

final class PictureChosen extends PictureChoice {
  const PictureChosen(this.picture);

  final ImageUpload picture;
}

final class PictureDeclined extends PictureChoice {
  const PictureDeclined();
}

// The camera or the gallery could not be opened, or what came back could not
// be read. A picture the rules refuse is not this: those bytes arrived, and
// what is wrong with them is said where the picture is shown.
final class PictureRefused extends PictureChoice {
  const PictureRefused(this.message);

  final String message;
}
