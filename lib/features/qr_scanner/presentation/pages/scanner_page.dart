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
import '../widgets/info_banner.dart';
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
            if (state is ScannerDetected) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => switch (widget.purpose) {
                    ScanPurpose.viewDetails => ServiceDetailsPage(rawValue: state.rawValue),
                    ScanPurpose.cvlLookup => CvlLookupPage(rawValue: state.rawValue),
                    ScanPurpose.claim => VerifyPage(rawValue: state.rawValue),
                  },
                ),
              );
            }
          },
          builder: (context, state) {
            return Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(controller: controller),
                const ScannerOverlay(),
                Align(
                  alignment: Alignment.topCenter,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ScannerTopBar(
                        title: switch (widget.purpose) {
                          ScanPurpose.viewDetails => 'Scan QR to View Details',
                          ScanPurpose.cvlLookup => 'Scan QR to View CVL Record',
                          ScanPurpose.claim => 'Scan QR to Fetch ID',
                        },
                        onBack: () => _goBack(context),
                        onSearch: widget.purpose == ScanPurpose.cvlLookup
                            ? () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const CvlSearchPage()),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: InfoBanner(
                        icon: Icons.info_outline,
                        trailing: state is ScannerScanning
                            ? IconButton(
                                icon: Icon(
                                  state.torchOn
                                      ? Icons.flash_on
                                      : Icons.flash_off,
                                  color: Colors.white,
                                ),
                                onPressed: () => context
                                    .read<ScannerBloc>()
                                    .add(const ToggleTorch()),
                              )
                            : null,
                        child: Text(
                          switch (widget.purpose) {
                            ScanPurpose.viewDetails =>
                              'Align the QR within the frame to view application details.',
                            ScanPurpose.cvlLookup =>
                              'Align the QR within the frame to view the CVL record.',
                            ScanPurpose.claim =>
                              'Align the QR within the frame. After scan, you can capture a verification photo.',
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                if (state is ScannerError)
                  Center(
                    child: Card(
                      margin: const EdgeInsets.all(24),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(state.message, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => context.read<ScannerBloc>().add(
                                const RetryScan(),
                              ),
                              child: const Text('Retry'),
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
