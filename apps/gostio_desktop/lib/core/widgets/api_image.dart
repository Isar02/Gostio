import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../network/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';

class ApiImage extends StatelessWidget {
  const ApiImage({
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = AppRadii.medium,
    super.key,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image(
        image: ApiImageProvider(context.read<ApiClient>(), path),
        width: width,
        height: height,
        fit: fit,
        frameBuilder: (
          BuildContext context,
          Widget child,
          int? frame,
          bool wasSynchronouslyLoaded,
        ) => frame == null ? _Placeholder(width: width, height: height) : child,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) =>
                _Placeholder(
                  width: width,
                  height: height,
                  icon: Icons.image_not_supported_outlined,
                ),
      ),
    );
  }
}

@immutable
class ApiImageProvider extends ImageProvider<ApiImageProvider> {
  ApiImageProvider(this.client, this.path)
    : generation = client.tokenGeneration;

  final ApiClient client;
  final String path;

  final int generation;

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
      other.generation == generation;

  @override
  int get hashCode => Object.hash(client, path, generation);
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
          : Icon(icon, size: AppSizes.iconSmall, color: AppColors.inkFaint),
    );
  }
}
