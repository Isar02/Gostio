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
  static const double tableRow = 44;
  static const double footerRow = 48;
  static const double numericColumn = 120;

  static const double topBar = 56;
  static const double navigation = 248;

  static const double filterField = 200;
  static const double panel = 380;
  static const double panelHeight = 420;
  static const double readingColumn = 520;
}
