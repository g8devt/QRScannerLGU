import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../main.dart';
import '../../../social_service_claim/presentation/pages/verify_page.dart';
import '../../data/datasources/mobile_scanner_datasource.dart';
import '../bloc/scanner_bloc.dart';
import '../bloc/scanner_event.dart';
import '../bloc/scanner_state.dart';
import '../widgets/info_banner.dart';
import '../widgets/scanner_overlay.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with WidgetsBindingObserver, RouteAware {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<ScannerBloc>().add(const StartScan());
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

  @override
  Widget build(BuildContext context) {
    final controller = context.read<MobileScannerDatasource>().controller;

    return Scaffold(
      body: BlocConsumer<ScannerBloc, ScannerState>(
        listener: (context, state) {
          if (state is ScannerDetected) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => VerifyPage(rawValue: state.rawValue)),
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
                    child: InfoBanner(
                      icon: Icons.qr_code_scanner,
                      child: const Text('Scan QR to Fetch ID', style: TextStyle(fontWeight: FontWeight.bold)),
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
                              icon: Icon(state.torchOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
                              onPressed: () => context.read<ScannerBloc>().add(const ToggleTorch()),
                            )
                          : null,
                      child: const Text(
                        'Align the QR within the frame. After scan, you can capture a verification photo.',
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
                            onPressed: () => context.read<ScannerBloc>().add(const RetryScan()),
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
    );
  }
}
