import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/cvl_search_filters.dart';
import '../bloc/cvl_search_cubit.dart';
import '../bloc/cvl_search_state.dart';

/// Bottom sheet for the "Search CVL Record" filters — photo/card as a
/// tri-state segmented choice; municipality/barangay/precinct/major
/// position/leader title as dropdowns backed by live values from
/// [CvlSearchState.filterOptions] (municipality/barangay/precinct are
/// genuinely free-text, organically-varying `app_cvl_list` columns;
/// major position and leader title come from `leader_structure_tbl`
/// instead — leader title cascades to only the titles valid for
/// whichever major position is selected, since one major position can
/// have several leader titles under it); and secondary position/sector
/// as dropdowns from the fixed, hardcoded option lists in
/// `cvl_search_filters.dart` (matching `bataan_lgu_admin`'s EMS
/// dropdowns — secondary position is additionally a DB-level enum).
/// Edits are held locally and only committed (popped back to the
/// caller) on "Apply" — "Clear all" resets the local draft, not the
/// already-applied filters, until Apply is tapped.
class CvlFilterSheet extends StatefulWidget {
  const CvlFilterSheet({super.key});

  @override
  State<CvlFilterSheet> createState() => _CvlFilterSheetState();
}

class _CvlFilterSheetState extends State<CvlFilterSheet> {
  late CvlSearchFilters _draft;

  @override
  void initState() {
    super.initState();
    _draft = context.read<CvlSearchCubit>().state.filters;
  }

  void _clear() => setState(() => _draft = const CvlSearchFilters());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: 8 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: BlocBuilder<CvlSearchCubit, CvlSearchState>(
          buildWhen: (previous, current) =>
              previous.filterOptions != current.filterOptions ||
              previous.filterOptionsStatus != current.filterOptionsStatus,
          builder: (context, state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Text('Filters', style: textTheme.titleLarge),
                    const Spacer(),
                    TextButton(onPressed: _clear, child: const Text('Clear all')),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: _FilterOptionsBody(
                      status: state.filterOptionsStatus,
                      options: state.filterOptions,
                      draft: _draft,
                      onChanged: (draft) => setState(() => _draft = draft),
                      onRetry: () => context.read<CvlSearchCubit>().loadFilterOptions(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_draft),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterOptionsBody extends StatelessWidget {
  const _FilterOptionsBody({
    required this.status,
    required this.options,
    required this.draft,
    required this.onChanged,
    required this.onRetry,
  });

  final CvlFilterOptionsStatus status;
  final CvlFilterOptions options;
  final CvlSearchFilters draft;
  final ValueChanged<CvlSearchFilters> onChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (status == CvlFilterOptionsStatus.loading ||
        status == CvlFilterOptionsStatus.notLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (status == CvlFilterOptionsStatus.failed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Text('Could not load filter options.'),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Photo'),
        _TriStateChoice(
          value: draft.hasPhoto,
          yesLabel: 'Has photo',
          noLabel: 'No photo',
          onChanged: (v) => onChanged(draft.copyWith(hasPhoto: v)),
        ),
        const SizedBox(height: 16),
        _SectionLabel('Card'),
        _TriStateChoice(
          value: draft.hasCard,
          yesLabel: 'With card',
          noLabel: 'Without card',
          onChanged: (v) => onChanged(draft.copyWith(hasCard: v)),
        ),
        const SizedBox(height: 16),
        _SectionLabel('Location'),
        _OptionDropdown(
          label: 'Municipality',
          value: draft.municipality,
          options: options.municipalities,
          onChanged: (v) => onChanged(draft.copyWith(municipality: v)),
        ),
        const SizedBox(height: 10),
        _OptionDropdown(
          label: 'Barangay',
          value: draft.barangay,
          options: options.barangays,
          onChanged: (v) => onChanged(draft.copyWith(barangay: v)),
        ),
        const SizedBox(height: 10),
        _OptionDropdown(
          label: 'Precinct',
          value: draft.precinct,
          options: options.precincts,
          onChanged: (v) => onChanged(draft.copyWith(precinct: v)),
        ),
        const SizedBox(height: 16),
        _SectionLabel('Position'),
        _OptionDropdown(
          label: 'Major position',
          value: draft.positionCode,
          options: options.majorPositions,
          onChanged: (v) {
            // Changing the major position can invalidate the already-picked
            // leader title (it belongs to a different position's list) —
            // clear it rather than silently keep applying a title the
            // dropdown no longer shows as selected.
            final validTitles = options.leaderTitlesFor(v);
            final leaderTitle = validTitles.contains(draft.leaderTitle)
                ? draft.leaderTitle
                : '';
            onChanged(draft.copyWith(positionCode: v, leaderTitle: leaderTitle));
          },
        ),
        const SizedBox(height: 10),
        _OptionDropdown(
          label: 'Leader title',
          value: draft.leaderTitle,
          options: options.leaderTitlesFor(draft.positionCode),
          onChanged: (v) => onChanged(draft.copyWith(leaderTitle: v)),
        ),
        const SizedBox(height: 10),
        _OptionDropdown(
          label: 'Secondary position',
          value: draft.secondaryPosition,
          options: cvlSecondaryPositionOptions,
          onChanged: (v) => onChanged(draft.copyWith(secondaryPosition: v)),
        ),
        const SizedBox(height: 16),
        _SectionLabel('Sector'),
        _OptionDropdown(
          label: 'Sector',
          value: draft.sector,
          options: cvlSectorOptions,
          onChanged: (v) => onChanged(draft.copyWith(sector: v)),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Segmented Any/Yes/No choice backed by [TriState].
class _TriStateChoice extends StatelessWidget {
  const _TriStateChoice({
    required this.value,
    required this.yesLabel,
    required this.noLabel,
    required this.onChanged,
  });

  final TriState value;
  final String yesLabel;
  final String noLabel;
  final ValueChanged<TriState> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TriState>(
      segments: [
        const ButtonSegment(value: TriState.any, label: Text('Any')),
        ButtonSegment(value: TriState.yes, label: Text(yesLabel)),
        ButtonSegment(value: TriState.no, label: Text(noLabel)),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

/// Dropdown for a filter column backed by live DB values. [value] is ''
/// for "Any"; falls back to '' if it no longer appears in [options] (e.g.
/// stale after options reload, or a cascading reset from another filter
/// changing — see the Major Position handler in [_FilterOptionsBody]).
///
/// Keyed on [value]: `DropdownButtonFormField`'s `initialValue` only
/// takes effect on first build, so a value change coming from outside
/// (not the user picking a new item in *this* dropdown) would otherwise
/// leave the displayed selection stale. The key forces Flutter to
/// recreate the field's state — and so re-read `initialValue` — whenever
/// [value] changes for any reason.
class _OptionDropdown extends StatelessWidget {
  const _OptionDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = options.contains(value) ? value : '';
    return DropdownButtonFormField<String>(
      key: ValueKey('$label:$safeValue'),
      initialValue: safeValue.isEmpty ? '' : safeValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem(value: '', child: Text('-- Select --')),
        ...options.map(
          (o) => DropdownMenuItem(
            value: o,
            child: Text(o, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (v) => onChanged(v ?? ''),
    );
  }
}
