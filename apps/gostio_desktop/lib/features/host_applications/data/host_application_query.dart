import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import 'host_application_status.dart';

// A filter nobody set is left out of the request rather than sent empty, which
// the API would read as a value to match. The applicant is the API's other
// filter and is not one here: it narrows to a single account by id, which is
// how a guest reads their own request rather than how this list is read.
@immutable
class HostApplicationQuery {
  const HostApplicationQuery({this.status});

  final HostApplicationStatus? status;

  bool get isEmpty => toParameters().isEmpty;

  JsonMap toParameters() => <String, dynamic>{'status': ?status?.label};

  @override
  bool operator ==(Object other) =>
      other is HostApplicationQuery && other.status == status;

  @override
  int get hashCode => status.hashCode;
}
