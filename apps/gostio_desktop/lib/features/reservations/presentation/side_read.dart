import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';

// What is read beside the booking answers one of three things: the thing, that
// there is none, or that it could not be read. The last two are not the same
// sentence on the screen, so they are not the same value here either.
@immutable
class SideRead<T> {
  const SideRead.answered(this.value) : failure = null;
  const SideRead.failed(ApiException this.failure) : value = null;

  static const SideRead<Never> none = SideRead<Never>.answered(null);

  final T? value;
  final ApiException? failure;
}
