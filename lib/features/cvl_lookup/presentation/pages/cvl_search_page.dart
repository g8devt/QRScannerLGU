import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/cvl_search_result.dart';
import '../bloc/cvl_search_cubit.dart';
import '../bloc/cvl_search_state.dart';
import '../widgets/qr_actions.dart';
import 'cvl_edit_page.dart';
import 'cvl_lookup_page.dart';

/// Search-by-name entry point for CVL records — a separate way in from
/// scanning a QR. Debounces as the staff member types, then shows a
/// scrollable list of matches to tap into the same [CvlLookupPage] detail
/// view the scan flow uses. The list lazy-loads: scrolling near the
/// bottom fetches the next page from the backend instead of eagerly
/// pulling every match up front.
class CvlSearchPage extends StatefulWidget {
  const CvlSearchPage({super.key});

  @override
  State<CvlSearchPage> createState() => _CvlSearchPageState();
}

class _CvlSearchPageState extends State<CvlSearchPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  late final CvlSearchCubit _cubit;

  @override
  void initState() {
    super.initState();
    // Cached here, not looked up in dispose() — an ancestor lookup via
    // context.read() is unsafe once the widget is deactivated, which is
    // exactly what's happening by the time dispose() runs.
    _cubit = context.read<CvlSearchCubit>();
    _scrollController.addListener(_onScroll);
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _cubit.search(value);
    });
  }

  void _onScroll() {
    // Trigger a page ahead of the physical end so the next page is
    // usually ready before the staff member scrolls into blank space;
    // loadMore() itself no-ops if one is already in flight or there's
    // nothing left to fetch.
    const loadMoreThreshold = 200.0;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - loadMoreThreshold) {
      _cubit.loadMore();
    }
  }

  void _clearSearch() {
    _controller.clear();
    _debounce?.cancel();
    _cubit.search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _controller.dispose();
    _cubit.reset();
    super.dispose();
  }

  void _openResult(CvlSearchResult result) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CvlLookupPage.byId(recordId: result.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search CVL Record')),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _SearchField(
                  controller: _controller,
                  onChanged: _onChanged,
                  onClear: _clearSearch,
                ),
              ),
              Expanded(
                child: BlocBuilder<CvlSearchCubit, CvlSearchState>(
                  builder: (context, state) {
                    switch (state.status) {
                      case CvlSearchStatus.initial:
                        return const _HintMessage(
                          icon: Icons.person_search_outlined,
                          message: 'Search for a CVL record by name.',
                        );
                      case CvlSearchStatus.loading:
                        return const Center(child: CircularProgressIndicator());
                      case CvlSearchStatus.failed:
                        return _HintMessage(
                          icon: Icons.error_outline,
                          message: state.errorMessage ?? 'Search failed.',
                          isError: true,
                        );
                      case CvlSearchStatus.loaded:
                        if (state.results.isEmpty) {
                          return const _HintMessage(
                            icon: Icons.search_off,
                            message: 'No matching records found.',
                          );
                        }
                        return Column(
                          children: [
                            _ResultsHeader(count: state.results.length),
                            Expanded(
                              child: _ResultsList(
                                scrollController: _scrollController,
                                results: state.results,
                                isLoadingMore: state.isLoadingMore,
                                onTap: _openResult,
                              ),
                            ),
                          ],
                        );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded, filled search field matching the Material 3 search-bar look.
/// Shows a clear (✕) button once there's text to clear.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(28),
      child: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search by name (min. 2 characters)',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close),
                onPressed: onClear,
              );
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

/// "N found" line shown above the results list once a search has loaded.
class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          count == 1 ? '1 record found' : '$count records found',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

enum _QrAction { setQr, removeQr }

/// Opens the small action sheet for [result]'s QR icon — "Set QR Code"
/// (only enabled while it has none) or "Remove QR Code" (only enabled
/// once it does) — then routes to the scanner sheet or the remove
/// confirmation depending on which was picked.
Future<void> _openQrActionSheet(
  BuildContext context,
  CvlSearchResult result,
) async {
  final action = await showModalBottomSheet<_QrAction>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _QrActionSheet(result: result),
  );
  if (!context.mounted || action == null) return;

  final cubit = context.read<CvlSearchCubit>();
  switch (action) {
    case _QrAction.setQr:
      await openSetQrSheet(
        context,
        fullName: result.fullName,
        onSetQr: (qrCode) => cubit.setQr(id: result.id, qrCode: qrCode),
      );
    case _QrAction.removeQr:
      await confirmAndRemoveQr(
        context,
        fullName: result.fullName,
        onRemoveQr: () => cubit.removeQr(result.id),
      );
  }
}

/// Opens [CvlEditPage] for [result], then shows a confirmation snackbar
/// back on the search page once it reports a successful save.
Future<void> _openEditPage(BuildContext context, CvlSearchResult result) async {
  final success = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => CvlEditPage(recordId: result.id)),
  );
  if (success == true && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Record updated.')));
  }
}

/// Bottom sheet offering "Tag Kabaka Card" / "Remove QR Code" for one
/// search result — replaces jumping straight into the scanner from the
/// row. Leads with the record's identity and current tag status so the
/// two actions below read as "what happens if I tap this", not a bare
/// button pair.
class _QrActionSheet extends StatelessWidget {
  const _QrActionSheet({required this.result});

  final CvlSearchResult result;

  static String _initials(String fullName) {
    final words = fullName.trim().split(RegExp(r'\s+'));
    final letters = words
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase());
    return letters.isEmpty ? '?' : letters.join();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    _initials(result.fullName),
                    style: textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        result.fullName,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      _QrStatusBadge(hasQr: result.hasQr),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _QrActionTile(
              icon: Icons.qr_code_2_rounded,
              iconBackground: scheme.primaryContainer,
              iconColor: scheme.onPrimaryContainer,
              title: 'Tag Kabaka Card',
              subtitle: result.hasQr
                  ? 'Already tagged with a Kabaka Card'
                  : 'Link a Kabaka Card to this record',
              enabled: !result.hasQr,
              onTap: () => Navigator.of(context).pop(_QrAction.setQr),
            ),
            const SizedBox(height: 10),
            _QrActionTile(
              icon: Icons.qr_code_scanner_rounded,
              iconBackground: scheme.errorContainer,
              iconColor: scheme.onErrorContainer,
              title: 'Remove QR Code',
              subtitle: result.hasQr
                  ? 'Unlink the current Kabaka Card'
                  : 'No Kabaka Card is tagged yet',
              enabled: result.hasQr,
              onTap: () => Navigator.of(context).pop(_QrAction.removeQr),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill next to the record name showing whether a Kabaka Card is
/// currently tagged — the same fact the two tiles below act on, made
/// legible at a glance instead of only implied by which button is
/// disabled.
class _QrStatusBadge extends StatelessWidget {
  const _QrStatusBadge({required this.hasQr});

  final bool hasQr;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = hasQr
        ? scheme.tertiaryContainer
        : scheme.surfaceContainerHighest;
    final foreground = hasQr
        ? scheme.onTertiaryContainer
        : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasQr ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 12,
            color: foreground,
          ),
          const SizedBox(width: 4),
          Text(
            hasQr ? 'Kabaka Card tagged' : 'No Kabaka Card tagged',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of the QR action sheet: a colored icon chip, a title/subtitle
/// pair, and a trailing chevron — reads as "what tapping this does"
/// rather than a bare button. Dims and drops the chevron when [enabled]
/// is false, matching the disabled state the plain buttons used to show.
class _QrActionTile extends StatelessWidget {
  const _QrActionTile({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final contentOpacity = enabled ? 1.0 : 0.4;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Opacity(
                opacity: contentOpacity,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Opacity(
                  opacity: contentOpacity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              if (enabled)
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Per-row action buttons shown inline, beyond opening the detail view.
/// The QR icon opens [_QrActionSheet]; Edit opens [CvlEditPage] for
/// contact-details editing.
class _ResultActions extends StatelessWidget {
  const _ResultActions({required this.result});

  final CvlSearchResult result;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: 'QR Code',
          icon: const Icon(Icons.qr_code_2_outlined),
          onPressed: () => _openQrActionSheet(context, result),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
        IconButton.filledTonal(
          tooltip: 'Edit',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _openEditPage(context, result),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _HintMessage extends StatelessWidget {
  const _HintMessage({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isError
                    ? scheme.errorContainer
                    : scheme.surfaceContainerHighest,
              ),
              child: Icon(
                icon,
                size: 40,
                color: isError ? scheme.onErrorContainer : scheme.outline,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.scrollController,
    required this.results,
    required this.isLoadingMore,
    required this.onTap,
  });

  final ScrollController scrollController;
  final List<CvlSearchResult> results;
  final bool isLoadingMore;
  final void Function(CvlSearchResult) onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: results.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == results.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final result = results[index];
        return _ResultCard(result: result, onTap: () => onTap(result));
      },
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.onTap});

  final CvlSearchResult result;
  final VoidCallback onTap;

  static String _initials(String fullName) {
    final words = fullName.trim().split(RegExp(r'\s+'));
    final letters = words
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase());
    return letters.isEmpty ? '?' : letters.join();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final location = [
      result.barangay,
      result.municipality,
    ].where((s) => s.isNotEmpty).join(', ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  _initials(result.fullName),
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      result.fullName,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              location,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              _ResultActions(result: result),
            ],
          ),
        ),
      ),
    );
  }
}
