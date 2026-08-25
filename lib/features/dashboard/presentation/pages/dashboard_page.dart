import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../qr_scanner/presentation/pages/scanner_page.dart';

/// Landing page shown right after login. Lets the scanner-staff user jump
/// into QR scanning or log out.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final authBloc = context.read<AuthBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      authBloc.add(const LogoutRequested());
    }
  }

  Future<void> _confirmExit(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit app?'),
        content: const Text('Are you sure you want to close the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    if (confirmed == true) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExit(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Log out',
              onPressed: () => _confirmLogout(context),
            ),
          ],
        ),
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final user = state.user;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      user == null ? 'Welcome' : 'Welcome, ${user.fullName}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    if (user != null)
                      Text(
                        '@${user.username}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    const SizedBox(height: 32),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.qr_code_scanner, size: 32),
                        title: const Text('Scan QR for Claim'),
                        subtitle: const Text('Fetch and verify an ID'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ScannerPage(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.description_outlined, size: 32),
                        title: const Text('View Social Service Details'),
                        subtitle: const Text('Scan a QR to view application details'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ScannerPage(purpose: ScanPurpose.viewDetails),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.badge_outlined, size: 32),
                        title: const Text('Check CVL Record'),
                        subtitle: const Text('Scan a QR to view voter record'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ScannerPage(purpose: ScanPurpose.cvlLookup),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
