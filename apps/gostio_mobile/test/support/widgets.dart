import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

// One widget in the theme it is actually read in. The client is here because
// a picture is fetched through it, and a widget that draws none never asks.
Widget drawn(Widget widget, {ApiClient? client}) => Provider<ApiClient>.value(
  value: client ?? ApiClient(baseUrl: Uri.parse('http://10.0.2.2:5000')),
  child: MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: widget),
  ),
);

// A sheet needs something to open from, and its opener has to survive it.
Widget opener(void Function(BuildContext context) onPressed) => drawn(
  Builder(
    builder: (BuildContext context) => Center(
      child: ElevatedButton(
        onPressed: () => onPressed(context),
        child: const Text('Open'),
      ),
    ),
  ),
);
