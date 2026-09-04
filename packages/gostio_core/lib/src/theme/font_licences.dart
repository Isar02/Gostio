import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_fonts.dart';

const Map<String, String> _licences = <String, String>{
  'Geist': '${AppFonts.folder}/Geist-OFL.txt',
  'Manrope': '${AppFonts.folder}/Manrope-OFL.txt',
  'Plus Jakarta Sans': '${AppFonts.folder}/PlusJakartaSans-OFL.txt',
};

void registerFontLicences() {
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry<String, String> font in _licences.entries) {
      yield LicenseEntryWithLineBreaks(<String>[
        font.key,
      ], await rootBundle.loadString(font.value));
    }
  });
}
