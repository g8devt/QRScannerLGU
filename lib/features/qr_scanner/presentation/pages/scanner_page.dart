import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../main.dart';
import '../../../cvl_lookup/presentation/pages/cvl_lookup_page.dart';
import '../../../cvl_lookup/presentation/pages/cvl_search_page.dart';
import '../../../social_service_claim/presentation/pages/service_details_page.dart';
import '../../../social_service_claim/presentation/pages/verify_page.dart';
import '../../data/datasources/mobile_scanner_datasource.dart';
import '../bloc/scanner_bloc.dart';
import '../bloc/scanner_event.dart';
import '../bloc/scanner_state.dart';
import '../widgets/scanner_overlay.dart';
import '../widgets/scanner_top_bar.dart';

/// What a scan should do once a QR code is detected.
enum ScanPurpose {
  /// Route into the claim-verification flow (VerifyPage).
  claim,

  /// Route into the read-only application-details view.
  viewDetails,

  /// Route into the read-only CVL record lookup view.
  cvlLookup,
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key, this.purpose = ScanPurpose.claim});

  final ScanPurpose purpose;

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage>
    with WidgetsBindingObserver, RouteAware {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Deferred to after the first frame: when ScannerPage replaces LoginPage
    // in place (no route push — see AuthGate), this is the widget's very
    // first build, so the MobileScanner platform view hasn't completed its
    // first layout/attach yet. Starting the camera before that leaves the
    // preview blank on real devices until something forces a relayout
    // (e.g. pulling down the status bar).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ScannerBloc>().add(const StartScan());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute<void>);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    context.read<ScannerBloc>().add(const StartScan());
  }

  @override
  void didPushNext() {
    // Mirrors _goBack()'s reasoning: mobile_scanner's controller.start()
    // no-ops while value.isRunning is already true (see MobileScanner
    // Controller.start()). Without pausing here, a route pushed on top —
    // e.g. tapping the search icon into CvlSearchPage — leaves the
    // camera "running" underneath, so the next start() call elsewhere
    // (the Set QR scanner sheet) silently does nothing and that sheet's
    // preview stays blank until this page's camera is genuinely stopped
    // and restarted at least once.
    context.read<ScannerBloc>().add(const PauseScan());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent == true;
    switch (state) {
      case AppLifecycleState.resumed:
        if (isCurrentRoute) {
          context.read<ScannerBloc>().add(const StartScan());
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        if (isCurrentRoute) {
          context.read<ScannerBloc>().add(const PauseScan());
        }
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _goBack(BuildContext context) {
    // mobile_scanner never stops the camera on its own when this widget
    // unmounts (our controller uses autoStart: false, so its dispose()
    // skips stop()). Without this, the controller stays "running" in the
    // background after leaving this page, so the next visit's start() call
    // becomes a no-op (see MobileScannerController.start()'s
    // `if (value.isRunning) return;`) and the camera preview never paints.
    context.read<ScannerBloc>().add(const PauseScan());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<MobileScannerDatasource>().controller;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goBack(context);
      },
      child: Scaffold(
        body: BlocConsumer<ScannerBloc, ScannerState>(
          listener: (context, state) {
            // ScannerPage stays mounted underneath whatever gets pushed on
            // top of it (e.g. CvlLookupPage, then its Set QR sheet), but it
            // keeps listening to this same shared ScannerBloc. Without this
            // guard, a scan performed by something on top (like the Set QR
            // sheet's own camera) also gets treated as a detection here,
            // pushing a duplicate page for the same raw value and racing
            // whatever that top screen is doing with it.
            final isCurrentRoute = ModalRoute.of(context)?.isCurrent == true;
            if (state is ScannerDetected && isCurrentRoute) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => switch (widget.purpose) {
                    ScanPurpose.viewDetails => ServiceDetailsPage(
                      rawValue: state.rawValue,
                    ),
                    ScanPurpose.cvlLookup => CvlLookupPage(
                      rawValue: state.rawValue,
                    ),
                    ScanPurpose.claim => VerifyPage(rawValue: state.rawValue),
                  },
                ),
              );
            }
          },
          builder: (context, state) {
            final scheme = Theme.of(context).colorScheme;
            final title = switch (widget.purpose) {
              ScanPurpose.viewDetails => 'Scan to View Details',
              ScanPurpose.cvlLookup => 'Scan to View CVL Record',
              ScanPurpose.claim => 'Scan to Fetch ID',
            };
            final subtitle = switch (widget.purpose) {
              ScanPurpose.viewDetails =>
                'Align the QR within the frame to view application details.',
              ScanPurpose.cvlLookup =>
                'Align the QR within the frame to view the CVL record.',
              ScanPurpose.claim =>
                'Align the QR within the frame. After scan, you can capture a verification photo.',
            };
            return Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(controller: controller),
                ScannerOverlay(isDetected: state is ScannerDetected),
                // Minimal top chrome: just the controls, no title bar —
                // the frame is the focal point, not a page header pasted
                // over the camera feed.
                Align(
                  alignment: Alignment.topCenter,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          ScannerIconButton(
                            icon: Icons.close_rounded,
                            tooltip: 'Close',
                            onPressed: () => _goBack(context),
                          ),
                          const Spacer(),
                          if (widget.purpose == ScanPurpose.cvlLookup)
                            ScannerIconButton(
                              icon: Icons.search_rounded,
                              tooltip: 'Search by name',
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CvlSearchPage(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Caption + controls anchored to the bottom, below the
                // centered frame — matches a modern scanner app's
                // "Scan Code" caption over a floating control pill,
                // rather than a hint banner competing with the frame.
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  height: 1.3,
                                ),
                          ),
                          const SizedBox(height: 20),
                          if (state is ScannerScanning)
                            ScannerIconButton(
                              icon: state.torchOn
                                  ? Icons.flash_on_rounded
                                  : Icons.flash_off_rounded,
                              tooltip: 'Toggle flashlight',
                              active: state.torchOn,
                              onPressed: () => context.read<ScannerBloc>().add(
                                const ToggleTorch(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (state is ScannerError)
                  Center(
                    child: Card(
                      color: scheme.errorContainer,
                      margin: const EdgeInsets.all(24),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: scheme.onErrorContainer,
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              state.message,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: scheme.onErrorContainer),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => context.read<ScannerBloc>().add(
                                const RetryScan(),
                              ),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
