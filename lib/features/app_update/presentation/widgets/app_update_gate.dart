import 'package:flutter/material.dart';

import '../../domain/entities/app_version_check_result.dart';
import 'app_update_dialogs.dart';

/// Renders [background] and, whenever [result] blocks login, opens the
/// matching non-dismissible dialog on top of it. Closes the dialog only
/// when [result] flips to [AppVersionCheckOutcome.upToDate] — the caller
/// drives that transition by re-running the version check (e.g. on retry
/// or app resume) and passing a new [result] in.
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({
    super.key,
    required this.result,
    required this.background,
    required this.onUpdate,
    required this.onRetry,
  });

  final AppVersionCheckResult result;
  final Widget background;
  final VoidCallback onUpdate;
  final VoidCallback onRetry;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> {
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(covariant AppUpdateGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result.outcome != widget.result.outcome) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    }
  }

  void _sync() {
    if (!mounted) return;

    if (!widget.result.blocksLogin) {
      if (_dialogOpen) Navigator.of(context, rootNavigator: true).pop();
      return;
    }

    if (_dialogOpen) return;
    _dialogOpen = true;

    final future = widget.result.outcome == AppVersionCheckOutcome.updateRequired
        ? showUpdateRequiredDialog(
            context,
            latestVersion: widget.result.latestVersion,
            onUpdate: widget.onUpdate,
          )
        : showVersionCheckFailedDialog(context, onRetry: widget.onRetry);

    future.then((_) => _dialogOpen = false);
  }

  @override
  Widget build(BuildContext context) => widget.background;
}
