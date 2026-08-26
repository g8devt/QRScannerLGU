import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 64,
            ),
            const SizedBox(height: 16),
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
        padding: const EdgeInsets.all(16),
        children: [
          InfoCard(
            title: 'Identity',
            rows: {
              'Full Name': record.fullName,
              if (record.gender.isNotEmpty) 'Gender': record.gender,
              if (record.birthdate.isNotEmpty) 'Birthdate': record.birthdate,
            },
          ),
          const SizedBox(height: 12),
          if (record.address.isNotEmpty || record.barangay.isNotEmpty || record.municipality.isNotEmpty || record.precinctNo.isNotEmpty) ...[
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
            const SizedBox(height: 12),
          ],
          if (record.contactNo.isNotEmpty || record.email.isNotEmpty) ...[
            InfoCard(
              title: 'Contact',
              rows: {
                if (record.contactNo.isNotEmpty) 'Contact No.': record.contactNo,
                if (record.email.isNotEmpty) 'Email': record.email,
              },
            ),
            const SizedBox(height: 12),
          ],
          if (record.sector.isNotEmpty) ...[
            InfoCard(title: 'Sector', rows: {'Sector': record.sector}),
            const SizedBox(height: 12),
          ],
          _QrCodeSection(qrCode: record.qrCode),
          CvlPhotoSection(record: record),
          const SizedBox(height: 16),
          _ActionButtons(record: record),
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
/// instance, updating the displayed record in place on success.
class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.record});

  final CvlRecord record;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CvlLookupCubit>();
    return Column(
      children: [
        FilledButton.icon(
          onPressed: () => _openEditPage(context, record),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit'),
        ),
        const SizedBox(height: 8),
        if (record.hasQr)
          OutlinedButton.icon(
            onPressed: () => confirmAndRemoveQr(
              context,
              fullName: record.fullName,
              onRemoveQr: cubit.removeQr,
            ),
            icon: const Icon(Icons.qr_code_scanner_outlined),
            label: const Text('Remove QR Code'),
          )
        else
          OutlinedButton.icon(
            onPressed: () => openSetQrSheet(
              context,
              fullName: record.fullName,
              onSetQr: cubit.setQr,
            ),
            icon: const Icon(Icons.qr_code_2_outlined),
            label: const Text('Set QR Code'),
          ),
      ],
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('QR Code', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 120,
                  child: Text(
                    'Code',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(qrCode.isNotEmpty ? qrCode : 'Not assigned'),
                ),
              ],
            ),
            if (qrCode.isNotEmpty) ...[
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
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

