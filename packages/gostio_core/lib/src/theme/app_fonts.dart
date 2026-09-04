// The three bundled faces: what each family is called, and where this package
// keeps the files an application reads by hand rather than through a theme.
abstract final class AppFonts {
  static const String interfaceFamily = 'Geist';
  static const String displayFamily = 'PlusJakartaSans';
  static const String fallbackFamily = 'Manrope';

  static const String folder = 'packages/gostio_core/assets/fonts';

  static const String interfaceRegular = '$folder/Geist-Regular.ttf';
  static const String interfaceSemiBold = '$folder/Geist-SemiBold.ttf';
}
