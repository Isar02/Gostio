import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../theme/app_metrics.dart';

// Every picture is fetched through the client, because it lives behind the
// bearer header.
class ApiImage extends StatelessWidget {
  const ApiImage({
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = AppRadii.medium,
    this.missingIcon = Icons.image_outlined,
    super.key,
  });

  // Neither the cache nor an Image already showing the old bytes can see them
  // change, so a replacement is a different picture from here on.
  static Future<void> forget(BuildContext context, String path) async {
    final ApiImageProvider stale = ApiImageProvider(
      context.read<ApiClient>(),
      path,
    );

    _Replaced.raise(path);

    await stale.evict();
  }

  final String? path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final IconData missingIcon;

  @override
  Widget build(BuildContext context) {
    final String? path = this.path;

    if (path == null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: _Placeholder(width: width, height: height, icon: missingIcon),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: Image(
        image: ApiImageProvider(context.read<ApiClient>(), path),
        width: width,
        height: height,
        fit: fit,
        // A row is drawn before its picture arrives, so the space the picture
        // will take is held rather than collapsed and pushed open later.
        frameBuilder: (
          BuildContext context,
          Widget child,
          int? frame,
          bool wasSynchronouslyLoaded,
        ) => frame == null ? _Placeholder(width: width, height: height) : child,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) =>
                Semantics(
                  label: _refusal(error),
                  child: _Placeholder(
                    width: width,
                    height: height,
                    icon: Icons.image_not_supported_outlined,
                  ),
                ),
      ),
    );
  }
}

// How many times this client has replaced the bytes at an address.
abstract final class _Replaced {
  static final Map<String, int> _counts = <String, int>{};

  static int of(String path) => _counts[path] ?? 0;

  static void raise(String path) => _counts[path] = of(path) + 1;
}

String _refusal(Object error) => switch (error) {
  final ApiException failure =>
    'This picture could not be read. '
        '${failure.message}',
  _ => 'This picture could not be read.',
};

@immutable
class ApiImageProvider extends ImageProvider<ApiImageProvider> {
  ApiImageProvider(this.client, this.path)
    : generation = client.tokenGeneration,
      writes = _Replaced.of(path);

  final ApiClient client;
  final String path;

  final int generation;
  final int writes;

  @override
  Future<ApiImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<ApiImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    ApiImageProvider key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _read(key, decode),
    scale: 1,
    debugLabel: key.path,
  );

  Future<ui.Codec> _read(
    ApiImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    final Uint8List bytes = await key.client.bytes(key.path);

    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is ApiImageProvider &&
      other.client == client &&
      other.path == path &&
      other.generation == generation &&
      other.writes == writes;

  @override
  int get hashCode => Object.hash(client, path, generation, writes);
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.width, this.height, this.icon});

  final double? width;
  final double? height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: AppColors.neutralGround,
      alignment: Alignment.center,
      child: icon == null
          ? null
          : Icon(icon, size: AppSizes.icon, color: AppColors.inkFaint),
    );
  }
}
