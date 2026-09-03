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
  static const Radius smallRadius = Radius.circular(4);

  static const BorderRadius small = BorderRadius.all(smallRadius);
  static const BorderRadius medium = BorderRadius.all(Radius.circular(6));
  static const BorderRadius large = BorderRadius.all(Radius.circular(10));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(100));
}

abstract final class AppSizes {
  static const double hairline = 1;
  static const double focusRing = 1.5;
  static const double stroke = 2;

  static const double dot = 8;
  static const double badge = 16;
  static const double iconSmall = 16;
  static const double icon = 18;
  static const double spinner = 20;
  static const double avatar = 32;

  static const double control = 36;
  static const double tableHeaderRow = 40;
  static const double tableRow = 24;
  static const double footerRow = 48;
  static const double footerRoomy = 420;
  static const double thumbnail = 20;
  static const double thumbnailColumn = 56;
  static const double compactColumn = 88;
  static const double statusColumn = 112;
  static const double dateColumn = 112;
  static const double numericColumn = 120;

  static const double topBar = 56;
  static const double navigation = 248;

  static const double filterField = 200;
  static const double filterFieldNarrow = 120;
  static const double filterFieldWide = 280;
  static const double photoTile = 168;
  static const double photoTileHeight = 126;
  static const double photoCover = 360;
  static const double photoCoverHeight = 270;
  static const double calendarBar = 18;
  static const double calendarDay = 22;

  // A month laid across every listing: the narrowest a day column may be and
  // still be read, a name column wide enough to tell two titles apart, and the
  // gutter the scrollbar sits in where the month is wider than the window.
  static const double timelineDay = 28;
  static const double timelineRow = 40;
  static const double timelineBar = 22;
  static const double timelineListing = 220;
  static const double timelineGutter = 12;
  static const double overviewList = 260;
  static const double overviewChart = 200;
  static const double inbox = 340;
  static const double inboxRow = 76;
  static const double bubble = 460;
  static const double panel = 380;
  static const double panelHeight = 420;
  static const double readingColumn = 520;
  static const double mapDialog = 640;
  static const double mapDialogHeight = 460;
}
