import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../qr_scanner/data/datasources/mobile_scanner_datasource.dart';
import '../../../qr_scanner/presentation/bloc/scanner_bloc.dart';
import '../../../qr_scanner/presentation/bloc/scanner_event.dart';
import '../../../qr_scanner/presentation/bloc/scanner_state.dart';
import '../../../qr_scanner/presentation/widgets/scanner_overlay.dart';
import '../../domain/entities/cvl_search_result.dart';
import '../../domain/repositories/cvl_repository.dart';
import '../bloc/cvl_search_cubit.dart';
import '../bloc/cvl_search_state.dart';
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

/// Opens the scan-to-assign sheet for [result], then shows a confirmation
/// snackbar back on the search page once it reports success.
Future<void> _openSetQrSheet(
  BuildContext context,
  CvlSearchResult result,
) async {
  final success = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SetQrSheet(result: result),
  );
  if (success == true && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('QR code set.')));
  }
}

/// Per-row action buttons shown inline, beyond opening the detail view.
/// Set QR scans a code and assigns it via [_SetQrSheet]; Edit is still a
/// placeholder — not wired to the backend yet.
class _ResultActions extends StatelessWidget {
  const _ResultActions({required this.result});

  final CvlSearchResult result;

  void _handleTap(BuildContext context, String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label — coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: 'Set QR',
          icon: const Icon(Icons.qr_code_2_outlined),
          onPressed: result.hasQr
              ? null
              : () => _openSetQrSheet(context, result),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
        IconButton.filledTonal(
          tooltip: 'Edit',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _handleTap(context, 'Edit'),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

enum _SetQrPhase { scanning, validating, success, error }

/// Bottom sheet that scans a QR code with the app's shared camera
/// (via the existing [ScannerBloc]/[MobileScannerDatasource], the same
/// pieces [ScannerPage] uses) and assigns it to [result] through
/// [CvlSearchCubit.setQr]. A code the backend rejects — unregistered or
/// already assigned to another record — surfaces inline with a "Scan
/// Again" retry instead of dismissing the sheet.
class _SetQrSheet extends StatefulWidget {
  const _SetQrSheet({required this.result});

  final CvlSearchResult result;

  @override
  State<_SetQrSheet> createState() => _SetQrSheetState();
}

class _SetQrSheetState extends State<_SetQrSheet> {
  _SetQrPhase _phase = _SetQrPhase.scanning;
  String? _errorMessage;

  // Cached here, not looked up in dispose() — an ancestor lookup via
  // context.read() is unsafe once the widget is deactivated, which is
  // exactly what's happening by the time dispose() runs.
  late final ScannerBloc _scannerBloc;

  @override
  void initState() {
    super.initState();
    _scannerBloc = context.read<ScannerBloc>();
    // Deferred to after the first frame, same reasoning as ScannerPage:
    // the MobileScanner platform view needs a completed first layout
    // before starting the camera, or the preview stays blank.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scannerBloc.add(const StartScan());
    });
  }

  @override
  void dispose() {
    _scannerBloc.add(const PauseScan());
    super.dispose();
  }

  Future<void> _handleDetected(String rawValue) async {
    setState(() {
      _phase = _SetQrPhase.validating;
      _errorMessage = null;
    });
    try {
      await context.read<CvlSearchCubit>().setQr(
        id: widget.result.id,
        qrCode: rawValue,
      );
      if (!mounted) return;
      setState(() => _phase = _SetQrPhase.success);
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.of(context).pop(true);
    } on CvlLookupException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _SetQrPhase.error;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _SetQrPhase.error;
        _errorMessage = 'Could not set the QR code: $e';
      });
    }
  }

  void _retry() {
    setState(() {
      _phase = _SetQrPhase.scanning;
      _errorMessage = null;
    });
    _scannerBloc.add(const RetryScan());
  }

  String get _subtitle => switch (_phase) {
    _SetQrPhase.scanning => 'Align the QR code within the frame.',
    _SetQrPhase.validating => 'Checking the QR code…',
    _SetQrPhase.success => 'QR code set.',
    _SetQrPhase.error => _errorMessage ?? 'Could not set the QR code.',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = context.read<MobileScannerDatasource>().controller;

    return BlocListener<ScannerBloc, ScannerState>(
      listenWhen: (previous, current) =>
          current is ScannerDetected || current is ScannerError,
      listener: (context, state) {
        if (state is ScannerDetected && _phase == _SetQrPhase.scanning) {
          _handleDetected(state.rawValue);
        } else if (state is ScannerError) {
          setState(() {
            _phase = _SetQrPhase.error;
            _errorMessage = state.message;
          });
        }
      },
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Set QR — ${widget.result.fullName}',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _phase == _SetQrPhase.error
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 260,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(controller: controller),
                      const ScannerOverlay(),
                      if (_phase == _SetQrPhase.validating)
                        const ColoredBox(
                          color: Colors.black54,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (_phase == _SetQrPhase.success)
                        const ColoredBox(
                          color: Colors.black54,
                          child: Center(
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.greenAccent,
                              size: 56,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_phase == _SetQrPhase.error)
                FilledButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Again'),
                )
              else
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
            ],
          ),
        ),
      ),
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
                      maxLines: 1,
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
