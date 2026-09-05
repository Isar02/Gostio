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
  static const BorderRadius small = BorderRadius.all(Radius.circular(8));
  static const BorderRadius medium = BorderRadius.all(Radius.circular(12));
  static const BorderRadius large = BorderRadius.all(Radius.circular(18));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));

  // A sheet is a surface that arrived from below, so only the edge that
  // travelled is drawn round.
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(20),
  );
}

abstract final class AppSizes {
  static const double hairline = 1;
  static const double focusRing = 1.5;
  static const double stroke = 2;

  static const double icon = 22;
  static const double iconSmall = 18;
  static const double star = 16;
  static const double spinner = 24;

  // Measured for a thumb rather than a cursor.
  static const double touchTarget = 48;
  static const double appBar = 56;
  static const double brandMark = 48;

  // The bar the whole client is moved through. It is taller than a thumb
  // target because it carries a label under every icon.
  static const double navigationBar = 64;

  // A form is read down a single column, and a tablet is wide enough to
  // stretch one past the length an eye tracks.
  static const double formColumn = 480;

  // A cover is wider than it is tall so the card leads with the picture and
  // still leaves the title above the fold.
  static const double coverAspect = 16 / 10;
  static const double thumbnail = 72;

  static const double sheetHandle = 36;

  // A day in the month grid is a control like any other, so it is a thumb
  // tall. Seven across a 360-pixel phone is what holds the grid's side
  // padding down to `AppSpacing.sm`.
  static const double calendarCell = touchTarget;
}
