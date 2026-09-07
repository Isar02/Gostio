import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../theme/app_metrics.dart';
import 'api_image.dart';

// A face where an account is named. An account without a picture is drawn as
// its initials rather than as a silhouette every account shares: two letters
// tell a reader which of two names this is, and an outline of a head tells
// them nothing.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    required this.userId,
    required this.name,
    this.hasImage = false,
    this.size = AppSizes.avatar,
    super.key,
  });

  final int userId;
  final String name;
  final bool hasImage;
  final double size;

  static String pathFor(int userId) => '/users/$userId/image';

  static const double _initialsRatio = 0.36;

  @override
  Widget build(BuildContext context) {
    if (hasImage) {
      return ApiImage(
        path: pathFor(userId),
        width: size,
        height: size,
        borderRadius: AppRadii.pill,
      );
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.selected,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials(name),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.indigoDeep,
          fontSize: size * _initialsRatio,
        ),
      ),
    );
  }

  static String _initials(String name) {
    final List<String> words = name
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .toList(growable: false);

    return words.take(2).map((String word) => word[0].toUpperCase()).join();
  }
}
