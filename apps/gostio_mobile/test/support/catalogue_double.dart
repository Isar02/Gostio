import 'dart:async';

import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/explore/data/catalogue_repository.dart';
import 'package:gostio_mobile/features/explore/data/experience_filters.dart';
import 'package:gostio_mobile/features/explore/data/filter_options.dart';
import 'package:gostio_mobile/features/explore/data/filter_options_repository.dart';
import 'package:gostio_mobile/features/explore/data/stay_filters.dart';

import 'listing_fixture.dart';

// The two catalogues answered without a socket. Each call records the filters
// and the page it was asked for, so a test says what it expects the screen to
// have sent rather than reading the query back off the screen.
class CatalogueDouble implements CatalogueRepository {
  CatalogueDouble({
    List<Accommodation>? stays,
    List<Experience>? experiences,
    this.failure,
    this.holdsTheCall = false,
    this.stayCount,
    this.experienceCount,
  }) : _stays = stays ?? <Accommodation>[stay()],
       _experiences = experiences ?? <Experience>[experience()];

  final ApiException? failure;
  final bool holdsTheCall;

  // A count larger than the rows handed over is how a list with a page still
  // to come is drawn without writing out the page that follows it.
  final int? stayCount;
  final int? experienceCount;

  final List<Accommodation> _stays;
  final List<Experience> _experiences;
  final Completer<void> _answer = Completer<void>();

  final List<StayFilters> stayFilters = <StayFilters>[];
  final List<ExperienceFilters> experienceFilters = <ExperienceFilters>[];
  final List<int> pagesAsked = <int>[];

  StayFilters get lastStayFilters => stayFilters.last;

  ExperienceFilters get lastExperienceFilters => experienceFilters.last;

  void answer() => _answer.complete();

  @override
  Future<PagedResult<Accommodation>> stays({
    required StayFilters filters,
    required int page,
    required int pageSize,
  }) async {
    await _held();
    stayFilters.add(filters);
    pagesAsked.add(page);
    _refuseIfAsked();

    return _page<Accommodation>(_stays, page, pageSize, stayCount);
  }

  @override
  Future<PagedResult<Experience>> experiences({
    required ExperienceFilters filters,
    required int page,
    required int pageSize,
  }) async {
    await _held();
    experienceFilters.add(filters);
    pagesAsked.add(page);
    _refuseIfAsked();

    return _page<Experience>(_experiences, page, pageSize, experienceCount);
  }

  Future<void> _held() => holdsTheCall ? _answer.future : Future<void>.value();

  void _refuseIfAsked() {
    if (failure case final ApiException refused) {
      throw refused;
    }
  }

  // The rows the double was made with are the whole table, so a page of them
  // is cut here the way the server would cut it.
  static PagedResult<T> _page<T>(
    List<T> rows,
    int page,
    int pageSize,
    int? totalCount,
  ) {
    final int from = (page - 1) * pageSize;
    final int to = from + pageSize;

    return PagedResult<T>(
      items: from >= rows.length
          ? List<T>.empty()
          : rows.sublist(from, to > rows.length ? rows.length : to),
      page: page,
      pageSize: pageSize,
      totalCount: totalCount ?? rows.length,
    );
  }
}

// The lookup tables both sheets are built from.
class FilterOptionsDouble implements FilterOptionsRepository {
  FilterOptionsDouble({FilterOptions? options, this.failure})
    : options = options ?? filterOptions();

  final FilterOptions options;
  final ApiException? failure;

  int reads = 0;

  @override
  Future<FilterOptions> read() async {
    reads++;

    if (failure case final ApiException refused) {
      throw refused;
    }

    return options;
  }
}
