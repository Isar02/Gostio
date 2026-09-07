import 'package:gostio_core/gostio_core.dart';
import 'package:image_picker/image_picker.dart';

import 'picture_source.dart';

// The camera and the gallery as the phone opens them.
class ImagePickerPictures implements PictureSource {
  ImagePickerPictures([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  // A photograph off a modern phone is several times what the server takes,
  // and the whole of it is read into memory here on the way to the request.
  // The bounds are generous enough for a face at any size this client draws
  // one and small enough that the bytes are a picture rather than a file.
  static const double _widest = 1440;
  static const double _tallest = 1440;
  static const int _quality = 85;

  @override
  Future<PictureChoice> pick(PictureOrigin origin) async {
    XFile? chosen;

    try {
      chosen = await _picker.pickImage(
        source: origin == PictureOrigin.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: _widest,
        maxHeight: _tallest,
        imageQuality: _quality,
      );
    } on Exception catch (failure) {
      return PictureRefused(_refusalFor(origin, failure));
    }

    if (chosen == null) {
      return const PictureDeclined();
    }

    try {
      return PictureChosen(
        ImageUpload(name: chosen.name, bytes: await chosen.readAsBytes()),
      );
    } on Exception catch (failure) {
      return PictureRefused('That picture could not be read. $failure');
    }
  }

  // The plugin refuses a denied permission and a missing camera the same way,
  // so what is said names the door that did not open rather than guessing why.
  static String _refusalFor(PictureOrigin origin, Object failure) =>
      origin == PictureOrigin.camera
      ? 'The camera could not be opened. $failure'
      : 'The gallery could not be opened. $failure';
}
