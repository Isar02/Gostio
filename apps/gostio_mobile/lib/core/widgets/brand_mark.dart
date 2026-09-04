import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../theme/app_metrics.dart';

// The mark the launcher icon carries, drawn rather than loaded: the same
// letter on the same ground, at whatever size a screen wants it.
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = AppSizes.brandMark, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.indigo,
        borderRadius: AppRadii.medium,
      ),
      // The descender of the letter is part of the mark, so the glyph sits a
      // little above the middle of the square rather than on it.
      child: Padding(
        padding: EdgeInsets.only(bottom: size * 0.12),
        child: Text(
          'g',
          style: TextStyle(
            fontFamily: AppFonts.displayFamily,
            fontSize: size * 0.66,
            fontWeight: FontWeight.w700,
            height: 1,
            color: AppColors.porcelain,
          ),
        ),
      ),
    );
  }
}
