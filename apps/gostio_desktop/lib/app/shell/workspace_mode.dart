import 'package:gostio_core/gostio_core.dart';

// Declared widest first: an account holding both opens on the first of the two.
enum WorkspaceMode {
  administrator('Administrator', 'Admin panel'),
  host('Host', 'Host panel');

  const WorkspaceMode(this.label, this.panelName);

  final String label;
  final String panelName;

  static List<WorkspaceMode> forAccount(User account) => <WorkspaceMode>[
    if (account.hasRole(RoleNames.administrator)) administrator,
    if (account.hasRole(RoleNames.host)) host,
  ];
}
