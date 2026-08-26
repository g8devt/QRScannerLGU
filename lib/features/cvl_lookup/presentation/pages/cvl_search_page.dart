import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/cvl_search_result.dart';
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
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    hintText: 'Type at least 2 characters',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: _onChanged,
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
                        return _ResultsList(
                          scrollController: _scrollController,
                          results: state.results,
                          isLoadingMore: state.isLoadingMore,
                          onTap: _openResult,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: isError
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
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
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: results.length + (isLoadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 1),
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
        return ListTile(
          leading: Icon(
            result.hasQr ? Icons.qr_code : Icons.qr_code_2_outlined,
            color: result.hasQr ? null : Theme.of(context).colorScheme.outline,
          ),
          title: Text(result.fullName),
          subtitle: Text(
            [
              result.barangay,
              result.municipality,
            ].where((s) => s.isNotEmpty).join(', '),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onTap(result),
        );
      },
    );
  }
}
