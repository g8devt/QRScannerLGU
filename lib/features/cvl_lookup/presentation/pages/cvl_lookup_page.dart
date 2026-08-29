import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/info_card.dart';
import '../../domain/entities/cvl_record.dart';
import '../bloc/cvl_lookup_cubit.dart';
import '../bloc/cvl_lookup_state.dart';
import '../widgets/cvl_photo_section.dart';
import '../widgets/qr_actions.dart';
import 'cvl_edit_page.dart';

/// Read-only view of a CVL record — reached either by scanning a QR
/// ([rawValue]) or by tapping a search result ([recordId]) — or a "no
/// record found" message when the lookup doesn't match anything.
class CvlLookupPage extends StatefulWidget {
  const CvlLookupPage({super.key, required String this.rawValue})
    : recordId = null;

  const CvlLookupPage.byId({super.key, required int this.recordId})
    : rawValue = null;

  final String? rawValue;
  final int? recordId;

  @override
  State<CvlLookupPage> createState() => _CvlLookupPageState();
}

class _CvlLookupPageState extends State<CvlLookupPage> {
  late final CvlLookupCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<CvlLookupCubit>();
    final rawValue = widget.rawValue;
    final recordId = widget.recordId;
    if (rawValue != null) {
      _cubit.fetch(rawValue);
    } else {
      _cubit.fetchById(recordId!);
    }
  }

  // No reset() in dispose(): CvlEditPage (pushed on top of this page by
  // the Edit button below) shares this same CvlLookupCubit instance —
  // resetting it here would wipe the record CvlEditPage just loaded.
  // Every fresh open (fetch/fetchById) emits a loading state
  // synchronously before its result arrives anyway, so there's no stale
  // data left behind for a subsequent, unrelated use of this cubit to
  // accidentally show.

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(title: const Text('CVL Record')),
        body: BlocBuilder<CvlLookupCubit, CvlLookupState>(
          builder: (context, state) {
            switch (state.status) {
              case CvlLookupStatus.initial:
              case CvlLookupStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case CvlLookupStatus.failed:
                return _ErrorView(
                  message:
                      state.errorMessage ??
                      'No CVL record was found for this QR code.',
                );
              case CvlLookupStatus.loaded:
                return _DetailsView(record: state.record!);
            }
          },
        ),
      ),
    );
  }
}

/// Empty/error state — mirrors `_HintMessage` in cvl_search_page.dart: a
/// soft circular icon badge over a short message, instead of a bare
/// icon+text stack.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

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
                color: scheme.errorContainer,
              ),
              child: Icon(
                Icons.error_outline,
                size: 40,
                color: scheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsView extends StatelessWidget {
  const _DetailsView({required this.record});

  final CvlRecord record;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _IdentityHeader(record: record),
          const SizedBox(height: 16),
          InfoCard(
            title: 'Identity',
            rows: {
              'Full Name': record.fullName,
              if (record.gender.isNotEmpty) 'Gender': record.gender,
              if (record.birthdate.isNotEmpty) 'Birthdate': record.birthdate,
            },
          ),
          if (record.address.isNotEmpty ||
              record.barangay.isNotEmpty ||
              record.municipality.isNotEmpty ||
              record.precinctNo.isNotEmpty) ...[
            const SizedBox(height: 12),
            InfoCard(
              title: 'Location',
              rows: {
                if (record.address.isNotEmpty) 'Address': record.address,
                if (record.barangay.isNotEmpty) 'Barangay': record.barangay,
                if (record.municipality.isNotEmpty)
                  'Municipality': record.municipality,
                if (record.precinctNo.isNotEmpty)
                  'Precinct No.': record.precinctNo,
              },
            ),
          ],
          if (record.contactNo.isNotEmpty || record.email.isNotEmpty) ...[
            const SizedBox(height: 12),
            InfoCard(
              title: 'Contact',
              rows: {
                if (record.contactNo.isNotEmpty)
                  'Contact No.': record.contactNo,
                if (record.email.isNotEmpty) 'Email': record.email,
              },
            ),
          ],
          if (record.sector.isNotEmpty) ...[
            const SizedBox(height: 12),
            InfoCard(title: 'Sector', rows: {'Sector': record.sector}),
          ],
          const SizedBox(height: 12),
          _QrCodeSection(qrCode: record.qrCode),
          const SizedBox(height: 12),
          CvlPhotoSection(record: record),
          const SizedBox(height: 20),
          _ActionButtons(record: record),
        ],
      ),
    );
  }
}

/// Hero identity block leading the detail view — avatar (photo when
/// available, initials otherwise), name, and a QR-tag status chip, on a
/// tonal container so it reads as this page's header rather than another
/// [InfoCard] row.
class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({required this.record});

  final CvlRecord record;

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
    final textTheme = Theme.of(context).textTheme;
    final location = [
      record.barangay,
      record.municipality,
    ].where((s) => s.isNotEmpty).join(', ');

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: scheme.primary,
              foregroundImage: record.hasDisplayableImage
                  ? NetworkImage(record.imgPath)
                  : null,
              child: Text(
                _initials(record.fullName),
                style: textTheme.titleLarge?.copyWith(
                  color: scheme.onPrimary,
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
                    record.fullName,
                    style: textTheme.titleLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: scheme.onPrimaryContainer.withValues(
                            alpha: 0.8,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.onPrimaryContainer.withValues(
                                alpha: 0.8,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  _QrStatusChip(hasQr: record.hasQr),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small status pill showing whether a Kabaka QR code is tagged to this
/// record — reads from the shared [AppStatusColors] extension instead of
/// a raw green/grey pair.
class _QrStatusChip extends StatelessWidget {
  const _QrStatusChip({required this.hasQr});

  final bool hasQr;

  @override
  Widget build(BuildContext context) {
    final status = Theme.of(context).extension<AppStatusColors>()!;
    final scheme = Theme.of(context).colorScheme;
    final background = hasQr
        ? status.successContainer
        : scheme.surface.withValues(alpha: 0.6);
    final foreground = hasQr ? status.onSuccessContainer : scheme.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasQr ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 14,
            color: foreground,
          ),
          const SizedBox(width: 4),
          Text(
            hasQr ? 'Kabaka Card tagged' : 'No Kabaka Card tagged',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens [CvlEditPage] for [record], then shows a confirmation snackbar
/// back on this page once it reports a successful save.
Future<void> _openEditPage(BuildContext context, CvlRecord record) async {
  final success = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => CvlEditPage(recordId: record.id)),
  );
  if (success == true && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Record updated.')));
  }
}

/// Replaces the old "Scan Another" button: Edit always available; Set QR
/// Code / Remove QR Code shown depending on whether [record] already has
/// one assigned. Both QR actions operate on this same [CvlLookupCubit]
/// instance, updating the displayed record in place on success. Styled
/// as icon-chip tiles (matching `_QrActionTile` in cvl_search_page.dart)
/// instead of plain stacked buttons.
class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.record});

  final CvlRecord record;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CvlLookupCubit>();
    final scheme = Theme.of(context).colorScheme;
    final status = Theme.of(context).extension<AppStatusColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ActionTile(
          icon: Icons.edit_outlined,
          iconBackground: scheme.primaryContainer,
          iconColor: scheme.onPrimaryContainer,
          title: 'Edit Record',
          subtitle: 'Update contact details or photo',
          onTap: () => _openEditPage(context, record),
        ),
        const SizedBox(height: 10),
        record.hasQr
            ? _ActionTile(
                icon: Icons.qr_code_scanner_outlined,
                iconBackground: scheme.errorContainer,
                iconColor: scheme.onErrorContainer,
                title: 'Remove QR Code',
                subtitle: 'Unlink the current Kabaka Card',
                onTap: () => confirmAndRemoveQr(
                  context,
                  fullName: record.fullName,
                  onRemoveQr: cubit.removeQr,
                ),
              )
            : _ActionTile(
                icon: Icons.qr_code_2_outlined,
                iconBackground: status.successContainer,
                iconColor: status.onSuccessContainer,
                title: 'Set QR Code',
                subtitle: 'Link a Kabaka Card to this record',
                onTap: () => openSetQrSheet(
                  context,
                  fullName: record.fullName,
                  onSetQr: cubit.setQr,
                ),
              ),
      ],
    );
  }
}

/// One tappable action row: a colored icon chip, a title/subtitle pair,
/// and a trailing chevron — same visual language as `_QrActionTile` in
/// cvl_search_page.dart, reused here for the page-level action list.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the assigned QR code both as its raw value and as a rendered,
/// scannable image (encoding the same value [find_cvl_by_qr_bataan]
/// matches on) — or "Not assigned" with no image when [qrCode] is
/// empty.
class _QrCodeSection extends StatelessWidget {
  const _QrCodeSection({required this.qrCode});

  final String qrCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.qr_code_2_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Kabaka QR Code',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            if (qrCode.isEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Not assigned',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            if (qrCode.isNotEmpty) ...[
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: QrImageView(
                    data: qrCode,
                    version: QrVersions.auto,
                    size: 160,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
