import 'package:flutter/painting.dart';

import 'app_colors.dart';

enum Tone {
  neutral(AppColors.neutral, AppColors.neutralGround),
  informative(AppColors.info, AppColors.infoGround),
  positive(AppColors.success, AppColors.successGround),
  attention(AppColors.warning, AppColors.warningGround),
  negative(AppColors.danger, AppColors.dangerGround);

  const Tone(this.foreground, this.ground);

  final Color foreground;
  final Color ground;
}
