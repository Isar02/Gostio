import 'package:flutter/foundation.dart';

import 'app_navigation.dart';
import 'app_section.dart';
import 'workspace_mode.dart';

// Which of the account's roles the client is drawing for, and where inside it.
// The two travel together because switching mode invalidates the section: the
// navigations do not hold the same entries.
class Workspace extends ChangeNotifier {
  Workspace(this.modes) : _mode = modes.first;

  final List<WorkspaceMode> modes;

  WorkspaceMode _mode;
  AppSection _section = AppSection.overview;

  WorkspaceMode get mode => _mode;

  AppSection get section => _section;

  bool get canSwitchMode => modes.length > 1;

  List<NavigationEntry> get navigation => AppNavigation.forMode(_mode);

  String get sectionLabel => AppNavigation.labelFor(_mode, _section);

  void switchTo(WorkspaceMode mode) {
    if (mode == _mode || !modes.contains(mode)) {
      return;
    }

    _mode = mode;
    _section = AppSection.overview;

    notifyListeners();
  }

  void open(AppSection section) {
    if (section == _section) {
      return;
    }

    _section = section;

    notifyListeners();
  }
}
