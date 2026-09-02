import 'package:flutter/foundation.dart';

import '../../reference/data/lookup_item.dart';
import '../../reference/data/reference_repository.dart';

@immutable
class UserFilterOptions {
  const UserFilterOptions({required this.roles});

  static const UserFilterOptions none = UserFilterOptions(
    roles: <LookupItem>[],
  );

  static Future<UserFilterOptions> load(ReferenceRepository reference) async =>
      UserFilterOptions(roles: await reference.roles());

  // The roles come from their own table rather than from the three names this
  // client knows, so a role added on the server reaches the filter and the
  // form without a release here.
  final List<LookupItem> roles;
}
