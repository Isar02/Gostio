import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../features/accommodations/presentation/accommodations_screen.dart';
import '../../features/experiences/presentation/experiences_screen.dart';
import '../../features/host_applications/presentation/host_applications_screen.dart';
import '../../features/messages/presentation/messages_screen.dart';
import '../../features/news/presentation/news_screen.dart';
import '../../features/overview/presentation/host_overview_screen.dart';
import '../../features/overview/presentation/platform_overview_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/reference/data/reference_table.dart';
import '../../features/reference/presentation/reference_screen.dart';
import '../../features/reports/data/report_scope.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/reservations/presentation/reservations_screen.dart';
import '../../features/reviews/presentation/reviews_screen.dart';
import '../../features/users/presentation/users_screen.dart';
import 'app_section.dart';
import 'workspace_mode.dart';

class SectionScreen extends StatelessWidget {
  const SectionScreen({
    required this.mode,
    required this.section,
    required this.account,
    super.key,
  });

  final WorkspaceMode mode;
  final AppSection section;
  final User account;

  // Every section is named here and none has a fallback: a section added to
  // the navigation without a screen behind it is a compile error rather than a
  // menu entry that opens an apology.
  @override
  Widget build(BuildContext context) {
    return switch (section) {
      // Both panels land here, and the two read nothing alike: a host is shown
      // the month across its own listings, an administrator the platform.
      AppSection.overview =>
        mode == WorkspaceMode.administrator
            ? const PlatformOverviewScreen()
            : HostOverviewScreen(hostId: account.id),
      AppSection.accommodations => AccommodationsScreen(
        asAdministrator: mode == WorkspaceMode.administrator,
        hostId: _hostId,
      ),
      AppSection.experiences => ExperiencesScreen(
        asAdministrator: mode == WorkspaceMode.administrator,
        hostId: _hostId,
      ),
      // Nothing about this list is the administrator's alone: what a booking
      // can be told is the server's to allow, and it allows the same two moves
      // to the host of the listing and to an administrator over both.
      AppSection.reservations => ReservationsScreen(hostId: _hostId),
      // Both of these are reached from the administrator's navigation alone,
      // and the account is passed because three writes on it are refused
      // against the caller's own.
      AppSection.users => UsersScreen(signedInUserId: account.id),
      AppSection.hostApplications => const HostApplicationsScreen(),
      AppSection.reviews => const ReviewsScreen(),
      AppSection.news => const NewsScreen(),
      // The two route families are told apart by the panel rather than by the
      // roles the token holds, so an account in both asks each one on purpose.
      AppSection.reports => ReportsScreen(
        scope: mode == WorkspaceMode.administrator
            ? ReportScope.platform
            : ReportScope.mine,
      ),
      // Both panels read the threads the server hands the caller. A host is in
      // every thread they reach; an administrator also oversees the support
      // queue, so the host view asks for the ones they are actually in.
      AppSection.messages => MessagesScreen(
        signedInUserId: account.id,
        onlyThreadsJoined: mode == WorkspaceMode.host,
      ),
      AppSection.countries => const ReferenceScreen(
        table: ReferenceTable.countries,
      ),
      AppSection.cities => const ReferenceScreen(table: ReferenceTable.cities),
      AppSection.accommodationTypes => const ReferenceScreen(
        table: ReferenceTable.accommodationTypes,
      ),
      AppSection.accommodationCategories => const ReferenceScreen(
        table: ReferenceTable.accommodationCategories,
      ),
      AppSection.experienceCategories => const ReferenceScreen(
        table: ReferenceTable.experienceCategories,
      ),
      AppSection.amenities => const ReferenceScreen(
        table: ReferenceTable.amenities,
      ),
      AppSection.roles => const ReferenceScreen(table: ReferenceTable.roles),
      AppSection.reservationStatuses => const ReferenceScreen(
        table: ReferenceTable.reservationStatuses,
      ),
      // Whoever is signed in, in either panel, is an account that can read and
      // write its own.
      AppSection.profile => const ProfileScreen(),
    };
  }

  // The host panel reads the same table from the caller's own angle.
  int? get _hostId => mode == WorkspaceMode.host ? account.id : null;
}
