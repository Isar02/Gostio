import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The device the client is developed against: 1080x2400 at 420dpi, which is
// 360 logical pixels across.
const Size _screen = Size(1080, 2400);
const double _density = 3;

void usePhoneScreen() {
  final TestFlutterView view = TestWidgetsFlutterBinding.ensureInitialized()
      .platformDispatcher
      .implicitView!;

  view.physicalSize = _screen;
  view.devicePixelRatio = _density;

  addTearDown(view.reset);
}
