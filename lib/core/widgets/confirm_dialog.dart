import 'package:flutter/material.dart';

/// Shared confirm/cancel dialog — replaces the app's previously
/// duplicated `AlertDialog`s (exit-confirm in login_page.dart and
/// dashboard_page.dart, logout-confirm, remove-QR confirm, set-QR
/// confirm) with one consistent widget and a single emphasis rule:
/// [isDestructive] actions (e.g. logout, remove) get an error-colored
/// confirm button; everything else gets the normal primary color.
///
/// Returns `true` only if the confirm action was tapped — `false` for
/// cancel or dismissing the dialog (e.g. tapping the scrim or the
/// system back gesture).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final colorScheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

/// Shared single-button ("OK") informational dialog — replaces
/// `qr_actions.dart`'s `showQrMessageDialog` and the rejection dialog
/// inside `SetQrSheet`.
Future<void> showMessageDialog(
  BuildContext context, {
  required String title,
  required String message,
  String buttonLabel = 'OK',
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(buttonLabel),
        ),
      ],
    ),
  );
}
