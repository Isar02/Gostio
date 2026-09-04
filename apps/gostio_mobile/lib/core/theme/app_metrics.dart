import 'package:flutter/painting.dart';

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class AppRadii {
  static const BorderRadius medium = BorderRadius.all(Radius.circular(12));
  static const BorderRadius large = BorderRadius.all(Radius.circular(18));
}

abstract final class AppSizes {
  static const double hairline = 1;
  static const double focusRing = 1.5;
  static const double stroke = 2;

  static const double icon = 22;

  // Measured for a thumb rather than a cursor.
  static const double touchTarget = 48;
  static const double appBar = 56;
  static const double brandMark = 48;

  // A form is read down a single column, and a tablet is wide enough to
  // stretch one past the length an eye tracks.
  static const double formColumn = 480;
}
