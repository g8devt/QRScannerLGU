import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../qr_scanner/presentation/pages/scanner_page.dart';

/// Landing page shown right after login. Lets the scanner-staff user jump
/// into QR scanning or log out.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static String _initials(String fullName) {
    final words = fullName.trim().split(RegExp(r'\s+'));
    final letters = words
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase());
    return letters.isEmpty ? '?' : letters.join();
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final authBloc = context.read<AuthBloc>();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log out?',
      message: 'You will need to sign in again to continue.',
      confirmLabel: 'Log out',
      isDestructive: true,
    );

    if (confirmed) {
      authBloc.add(const LogoutRequested());
    }
  }

  Future<void> _confirmExit(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Exit app?',
      message: 'Are you sure you want to close the app?',
      confirmLabel: 'Exit',
    );

    if (confirmed) SystemNavigator.pop();
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
            IconButton.filledTonal(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Log out',
              onPressed: () => _confirmLogout(context),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final user = state.user;
            final scheme = Theme.of(context).colorScheme;
            final textTheme = Theme.of(context).textTheme;
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: scheme.primaryContainer,
                          child: Text(
                            user == null ? '?' : _initials(user.fullName),
                            style: textTheme.titleLarge?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user == null
                                    ? 'Welcome'
                                    : 'Welcome, ${user.fullName}',
                                style: textTheme.headlineSmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (user != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  '@${user.username}',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _DashboardActionTile(
                      icon: Icons.qr_code_scanner_rounded,
                      iconBackground: scheme.primaryContainer,
                      iconColor: scheme.onPrimaryContainer,
                      // The one glow on this screen: marks this as the
                      // primary/most-used action among the three.
                      glowColor: scheme.primary,
                      title: 'Claim Assistance',
                      subtitle: 'Scan a QR to claim assistance',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ScannerPage(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DashboardActionTile(
                      icon: Icons.description_outlined,
                      iconBackground: scheme.tertiaryContainer,
                      iconColor: scheme.onTertiaryContainer,
                      title: 'View Social Service Details',
                      subtitle: 'Scan a QR to view application details',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ScannerPage(
                            purpose: ScanPurpose.viewDetails,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DashboardActionTile(
                      icon: Icons.badge_outlined,
                      iconBackground: scheme.secondaryContainer,
                      iconColor: scheme.onSecondaryContainer,
                      title: 'Check CVL Record',
                      subtitle: 'Scan a QR to view voter record',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ScannerPage(
                            purpose: ScanPurpose.cvlLookup,
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

/// One dashboard navigation entry: a colored icon chip, a title/subtitle
/// pair, and a trailing chevron on the theme's card surface — mirrors
/// `_QrActionTile` in cvl_search_page.dart so the three actions read as
/// distinct, tappable destinations rather than a plain list.
class _DashboardActionTile extends StatelessWidget {
  const _DashboardActionTile({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.glowColor,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// When set, the icon chip carries a soft colored glow — reserved for
  /// the single primary action so it doesn't dilute into decoration.
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: glowColor == null
                      ? null
                      : AppTheme.glow(glowColor!, opacity: 0.4, blur: 16),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
