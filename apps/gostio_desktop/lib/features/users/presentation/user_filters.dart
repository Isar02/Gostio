import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/filter_bar.dart';
import '../data/user_query.dart';
import 'account_state.dart';
import 'user_filter_options.dart';

class UserFilters extends StatefulWidget {
  const UserFilters({
    required this.options,
    required this.applied,
    required this.isLoading,
    required this.onChanged,
    this.trailing,
    super.key,
  });

  final UserFilterOptions options;

  // The query the rows on screen were fetched under, which is what these
  // controls have to describe once a request has settled.
  final UserQuery applied;

  final bool isLoading;
  final ValueChanged<UserQuery> onChanged;
  final Widget? trailing;

  @override
  State<UserFilters> createState() => _UserFiltersState();
}

class _UserFiltersState extends State<UserFilters> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _email = TextEditingController();

  LookupItem? _role;
  AccountState _state = AccountState.any;

  UserQuery _announced = const UserQuery();
  int _editRevision = 0;
  int _announcedRevision = 0;

  // A request that did not take leaves the rows on the query before it, so the
  // controls go back to that one rather than labelling old rows with a filter
  // that never loaded. A field being typed into is left alone.
  @override
  void didUpdateWidget(UserFilters oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.isLoading &&
        widget.applied != _announced &&
        _editRevision == _announcedRevision) {
      setState(() => _adopt(widget.applied));
    }
  }

  void _adopt(UserQuery query) {
    _name.text = query.name ?? '';
    _username.text = query.username ?? '';
    _email.text = query.email ?? '';
    _role = _roleFor(query.role);
    _state = AccountState.values.firstWhere(
      (AccountState state) => state.isActive == query.isActive,
    );
    _announced = query;
    _announcedRevision = _editRevision;
  }

  void _announce() {
    _announced = UserQuery(
      name: _name.text,
      username: _username.text,
      email: _email.text,
      role: _role?.name,
      isActive: _state.isActive,
    );
    _announcedRevision = _editRevision;

    widget.onChanged(_announced);
  }

  void _change(VoidCallback edit) {
    setState(edit);
    _edited();
    _announce();
  }

  void _edited() => _editRevision++;

  void _clear() => _change(() {
    _name.clear();
    _username.clear();
    _email.clear();
    _role = null;
    _state = AccountState.any;
  });

  LookupItem? _roleFor(String? name) {
    for (final LookupItem candidate in widget.options.roles) {
      if (candidate.name == name) {
        return candidate;
      }
    }

    return null;
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FilterBar(
      onClear: _clear,
      trailing: widget.trailing,
      filters: <Widget>[
        FilterField(
          label: 'Name',
          child: _text(_name, hint: 'Search names'),
        ),
        FilterField(label: 'Username', child: _text(_username)),
        FilterField(label: 'Email', child: _text(_email)),
        FilterField(
          label: 'Role',
          child: AppOptionalDropdown<LookupItem>(
            anyLabel: 'Any role',
            value: _role,
            values: widget.options.roles,
            labels: (LookupItem role) => role.name,
            onChanged: (LookupItem? role) => _change(() => _role = role),
          ),
        ),
        FilterField(
          label: 'Status',
          child: AppDropdown<AccountState>(
            value: _state,
            values: AccountState.values,
            labels: (AccountState state) => state.label,
            onChanged: (AccountState state) => _change(() => _state = state),
          ),
        ),
      ],
    );
  }

  Widget _text(TextEditingController controller, {String? hint}) =>
      FilterTextField(
        controller: controller,
        hint: hint,
        onEdited: _edited,
        onChanged: (String _) => _announce(),
      );
}
