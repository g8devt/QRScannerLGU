import 'package:flutter/material.dart';

/// Blocking, single-button dialog shown when the installed app is behind
/// the latest ACTIVE `app_version` row. No cancel/later action, no back
/// dismissal, no tap-outside dismissal — [PopScope.canPop] is false and
/// the caller shows this with `barrierDismissible: false`.
Future<void> showUpdateRequiredDialog(
  BuildContext context, {
  required String? latestVersion,
  required VoidCallback onUpdate,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Update Required'),
        content: Text(
          latestVersion != null
              ? 'A new version ($latestVersion) of the Scanner app is available. '
                  'You must update before you can continue.'
              : 'A new version of the Scanner app is available. '
                  'You must update before you can continue.',
        ),
        actions: [
          FilledButton(onPressed: onUpdate, child: const Text('Update')),
        ],
      ),
    ),
  );
}

/// Blocking dialog shown when the version check itself could not be
/// verified (network/server error). A failed check must never be treated
/// as "no update needed", so this offers only a retry — no way through.
Future<void> showVersionCheckFailedDialog(
  BuildContext context, {
  required VoidCallback onRetry,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Unable to Verify App Version'),
        content: const Text(
          'We could not confirm this app is up to date. Please check your '
          'internet connection and try again.',
        ),
        actions: [
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
