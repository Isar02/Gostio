import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../core/config/app_settings.dart';
import '../core/network/api_client.dart';
import '../core/session/session.dart';
import '../core/theme/app_theme.dart';
import '../features/accommodations/data/accommodation_amenities_repository.dart';
import '../features/accommodations/data/accommodation_availability_repository.dart';
import '../features/accommodations/data/accommodations_repository.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/experiences/data/experience_slots_repository.dart';
import '../features/experiences/data/experiences_repository.dart';
import '../features/listings/data/listing_photos_repository.dart';
import '../features/notifications/data/notifications_repository.dart';
import '../features/reference/data/reference_repository.dart';
import '../features/reservations/data/reservations_repository.dart';
import '../features/users/data/users_repository.dart';
import 'shell/shell_scaffold.dart';

class GostioApp extends StatelessWidget {
  const GostioApp({required this.settings, super.key});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<ApiClient>(
          create: (BuildContext context) =>
              ApiClient(baseUrl: settings.apiBaseUrl),
          dispose: (BuildContext context, ApiClient client) => client.close(),
        ),
        ChangeNotifierProvider<Session>(
          create: (BuildContext context) => Session(context.read<ApiClient>()),
        ),
        Provider<AuthRepository>(
          create: (BuildContext context) =>
              AuthRepository(context.read<ApiClient>()),
        ),
        Provider<NotificationsRepository>(
          create: (BuildContext context) =>
              NotificationsRepository(context.read<ApiClient>()),
        ),
        Provider<ReferenceRepository>(
          create: (BuildContext context) =>
              ReferenceRepository(context.read<ApiClient>()),
        ),
        Provider<AccommodationsRepository>(
          create: (BuildContext context) =>
              AccommodationsRepository(context.read<ApiClient>()),
        ),
        Provider<AccommodationAmenitiesRepository>(
          create: (BuildContext context) =>
              AccommodationAmenitiesRepository(context.read<ApiClient>()),
        ),
        Provider<AccommodationAvailabilityRepository>(
          create: (BuildContext context) =>
              AccommodationAvailabilityRepository(context.read<ApiClient>()),
        ),
        Provider<ExperiencesRepository>(
          create: (BuildContext context) =>
              ExperiencesRepository(context.read<ApiClient>()),
        ),
        Provider<ExperienceSlotsRepository>(
          create: (BuildContext context) =>
              ExperienceSlotsRepository(context.read<ApiClient>()),
        ),
        Provider<ListingPhotosRepository>(
          create: (BuildContext context) =>
              ListingPhotosRepository(context.read<ApiClient>()),
        ),
        Provider<UsersRepository>(
          create: (BuildContext context) =>
              UsersRepository(context.read<ApiClient>()),
        ),
        Provider<ReservationsRepository>(
          create: (BuildContext context) =>
              ReservationsRepository(context.read<ApiClient>()),
        ),
      ],
      child: MaterialApp(
        title: 'Gostio',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Consumer<Session>(
          builder: (BuildContext context, Session session, Widget? child) =>
              session.isSignedIn ? const ShellScaffold() : const SignInScreen(),
        ),
      ),
    );
  }
}
