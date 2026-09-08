import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../core/paging/paged_notifier.dart';
import '../../../core/theme/app_metrics.dart';
import '../data/catalogue_repository.dart';
import '../data/experience_filters.dart';
import '../data/filter_options_repository.dart';
import '../data/listing_filters.dart';
import '../data/stay_filters.dart';
import 'catalogue.dart';
import 'catalogue_cards.dart';
import 'catalogue_results.dart';
import 'catalogue_results_view.dart';
import 'experience_filter_sheet.dart';
import 'filter_options_notifier.dart';
import 'stay_filter_sheet.dart';

// Where the client opens: one field, the two catalogues behind a toggle, and
// the results of whichever is in front. Both are kept alive rather than rebuilt
// on each switch, so a reader who has read down one catalogue and glanced at
// the other comes back to where they were.
//
// The bar over it is the shell's, because the bell in it belongs to every tab;
// the filters stand in it beside that bell rather than over the results.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({this.resultsHeader, this.trailing, super.key});

  // What another module draws over the results. It scrolls with them rather
  // than standing between the search and the first card, and it is handed in
  // because what is published on this platform is not this feature's.
  final Widget? resultsHeader;

  // What the shell puts in the bar after this screen's own act. Handed in for
  // the same reason the header above is: it belongs to every tab, not to this.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<StayResults>(
          create: (BuildContext context) =>
              StayResults(context.read<CatalogueRepository>()),
        ),
        ChangeNotifierProvider<ExperienceResults>(
          create: (BuildContext context) =>
              ExperienceResults(context.read<CatalogueRepository>()),
        ),
        ChangeNotifierProvider<FilterOptionsNotifier>(
          // The choices are read as the screen opens rather than as the sheet
          // does: a reader who reaches for the filters straight away should
          // find them there rather than watch them arrive.
          lazy: false,
          create: (BuildContext context) =>
              FilterOptionsNotifier(context.read<FilterOptionsRepository>()),
        ),
      ],
      child: _Explore(resultsHeader: resultsHeader, trailing: trailing),
    );
  }
}

class _Explore extends StatefulWidget {
  const _Explore({this.resultsHeader, this.trailing});

  final Widget? resultsHeader;
  final Widget? trailing;

  @override
  State<_Explore> createState() => _ExploreState();
}

class _ExploreState extends State<_Explore> {
  final TextEditingController _field = TextEditingController();

  Catalogue _catalogue = Catalogue.stays;

  @override
  void initState() {
    super.initState();

    // The catalogue in front reads itself; the one behind waits until it is
    // shown, because a reader who never touches the toggle should not have
    // paid for a search they did not make.
    //
    // It is asked after the frame that mounts this rather than during it: a
    // notifier that published from inside initState would be dirtying the tree
    // it is being built into.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        _catchUpWith(_catalogue);
      }
    });
  }

  @override
  void dispose() {
    _field.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        automaticallyImplyLeading: false,
        actions: <Widget>[
          _FiltersAction(
            applied: switch (_catalogue) {
              Catalogue.stays =>
                context.watch<StayResults>().query.applied.length,
              Catalogue.experiences =>
                context.watch<ExperienceResults>().query.applied.length,
            },
            onOpen: switch (_catalogue) {
              Catalogue.stays => _openStayFilters,
              Catalogue.experiences => _openExperienceFilters,
            },
          ),
          ?widget.trailing,
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _Header(
              field: _field,
              catalogue: _catalogue,
              onSearch: _search,
              onCatalogue: _reveal,
            ),
            Expanded(
              child: IndexedStack(
                index: _catalogue.index,
                children: <Widget>[
                  CatalogueResultsView<Accommodation, StayFilters>(
                    catalogue: Catalogue.stays,
                    results: context.read<StayResults>(),
                    resultsHeader: widget.resultsHeader,
                    itemBuilder: (BuildContext context, Accommodation stay) =>
                        StayCard(stay),
                  ),
                  CatalogueResultsView<Experience, ExperienceFilters>(
                    catalogue: Catalogue.experiences,
                    results: context.read<ExperienceResults>(),
                    resultsHeader: widget.resultsHeader,
                    itemBuilder: (BuildContext context, Experience term) =>
                        TermCard(term),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? get _words => written(_field.text);

  void _search(String _) => _catchUpWith(_catalogue);

  void _reveal(Catalogue catalogue) {
    setState(() => _catalogue = catalogue);
    _catchUpWith(catalogue);
  }

  void _catchUpWith(Catalogue catalogue) {
    switch (catalogue) {
      case Catalogue.stays:
        _catchUp(context.read<StayResults>());
      case Catalogue.experiences:
        _catchUp(context.read<ExperienceResults>());
    }
  }

  // The field is one field over both catalogues, so a catalogue brought to the
  // front is asked the words that are in it — unless those words are already
  // the ones it is answering, which is the whole reason the other one is kept
  // alive.
  //
  // A read in flight is not a reason to drop a search. The words a reader
  // submitted while the first page was still coming are the words they want,
  // and only the newest read may write, so the older one lands nowhere.
  void _catchUp<TItem, TQuery extends ListingFilters<TQuery>>(
    PagedNotifier<TItem, TQuery> results,
  ) {
    final TQuery wanted = results.query.searchingFor(_words);

    if (wanted == results.query && (results.isLoading || results.hasLanded)) {
      return;
    }

    unawaited(results.apply(wanted));
  }

  Future<void> _openStayFilters() async {
    final StayResults results = context.read<StayResults>();
    final FilterOptionsNotifier options = context.read<FilterOptionsNotifier>();

    final StayFilters? chosen = await StayFilterSheet.show(
      context,
      current: results.query,
      options: options,
    );

    if (chosen != null && chosen != results.query) {
      unawaited(results.apply(chosen));
    }
  }

  Future<void> _openExperienceFilters() async {
    final ExperienceResults results = context.read<ExperienceResults>();
    final FilterOptionsNotifier options = context.read<FilterOptionsNotifier>();

    final ExperienceFilters? chosen = await ExperienceFilterSheet.show(
      context,
      current: results.query,
      options: options,
    );

    if (chosen != null && chosen != results.query) {
      unawaited(results.apply(chosen));
    }
  }
}

// The field and the toggle, pinned over the results. Searching is a gesture
// rather than a side effect of typing: every first page of a search is a row
// the server keeps to recommend from, and a reader who types six letters meant
// to make one search rather than six.
class _Header extends StatelessWidget {
  const _Header({
    required this.field,
    required this.catalogue,
    required this.onSearch,
    required this.onCatalogue,
  });

  final TextEditingController field;
  final Catalogue catalogue;
  final ValueChanged<String> onSearch;
  final ValueChanged<Catalogue> onCatalogue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        children: <Widget>[
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: field,
            builder: (BuildContext context, TextEditingValue typed, Widget? _) {
              return TextField(
                controller: field,
                textInputAction: TextInputAction.search,
                onSubmitted: onSearch,
                decoration: InputDecoration(
                  hintText: catalogue.hint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: typed.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            field.clear();
                            onSearch('');
                          },
                          icon: const Icon(Icons.close),
                          tooltip: 'Clear search',
                        ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<Catalogue>(
              segments: <ButtonSegment<Catalogue>>[
                for (final Catalogue option in Catalogue.values)
                  ButtonSegment<Catalogue>(
                    value: option,
                    label: Text(option.label),
                  ),
              ],
              selected: <Catalogue>{catalogue},
              showSelectedIcon: false,
              onSelectionChanged: (Set<Catalogue> chosen) =>
                  onCatalogue(chosen.single),
            ),
          ),
        ],
      ),
    );
  }
}

// The tune icon in the bar, carrying how many filters are in force so a reader
// who has narrowed the list is told without opening the sheet.
class _FiltersAction extends StatelessWidget {
  const _FiltersAction({required this.applied, required this.onOpen});

  final int applied;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onOpen,
      tooltip: switch (applied) {
        0 => 'Filters',
        1 => '1 filter',
        _ => '$applied filters',
      },
      icon: Badge(
        isLabelVisible: applied > 0,
        label: Text('$applied'),
        child: const Icon(Icons.tune_rounded),
      ),
    );
  }
}
