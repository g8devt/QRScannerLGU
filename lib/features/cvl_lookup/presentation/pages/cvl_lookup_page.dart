import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../qr_scanner/domain/usecases/capture_photo.dart';
import '../../domain/entities/cvl_record.dart';
import '../bloc/cvl_lookup_cubit.dart';
import '../bloc/cvl_lookup_state.dart';

/// Read-only view of a CVL record — reached either by scanning a QR
/// ([rawValue]) or by tapping a search result ([recordId]) — or a "no
/// record found" message when the lookup doesn't match anything.
class CvlLookupPage extends StatefulWidget {
  const CvlLookupPage({super.key, required String this.rawValue}) : recordId = null;

  const CvlLookupPage.byId({super.key, required int this.recordId}) : rawValue = null;

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

  @override
  void dispose() {
    _cubit.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(title: const Text('CVL Record')),
        body: BlocConsumer<CvlLookupCubit, CvlLookupState>(
          listener: (context, state) {
            final error = state.photoUpdateError;
            if (error != null) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(error)));
            }
          },
          builder: (context, state) {
            switch (state.status) {
              case CvlLookupStatus.initial:
              case CvlLookupStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case CvlLookupStatus.failed:
                return _ErrorView(message: state.errorMessage ?? 'No CVL record was found for this QR code.');
              case CvlLookupStatus.loaded:
                return _DetailsView(record: state.record!, isUpdatingPhoto: state.isUpdatingPhoto);
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
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 64),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
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
  const _DetailsView({required this.record, required this.isUpdatingPhoto});

  final CvlRecord record;
  final bool isUpdatingPhoto;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PhotoSection(record: record, isUpdatingPhoto: isUpdatingPhoto),
          _SectionCard(
            title: 'Identity',
            rows: {
              'Full Name': record.fullName,
              if (record.gender.isNotEmpty) 'Gender': record.gender,
              if (record.birthdate.isNotEmpty) 'Birthdate': record.birthdate,
            },
          ),
          _SectionCard(
            title: 'Location',
            rows: {
              if (record.address.isNotEmpty) 'Address': record.address,
              if (record.barangay.isNotEmpty) 'Barangay': record.barangay,
              if (record.municipality.isNotEmpty) 'Municipality': record.municipality,
              if (record.precinctNo.isNotEmpty) 'Precinct No.': record.precinctNo,
            },
          ),
          _SectionCard(
            title: 'Contact',
            rows: {
              if (record.contactNo.isNotEmpty) 'Contact No.': record.contactNo,
              if (record.email.isNotEmpty) 'Email': record.email,
            },
          ),
          if (record.sector.isNotEmpty)
            _SectionCard(title: 'Sector', rows: {'Sector': record.sector}),
          _SectionCard(
            title: 'QR Code',
            rows: {'Code': record.qrCode.isNotEmpty ? record.qrCode : 'Not assigned'},
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Another'),
          ),
        ],
      ),
    );
  }
}

/// Shows the record's photo (only when [CvlRecord.hasDisplayableImage] —
/// a legacy PHP-admin-uploaded photo is a relative path this app has no
/// session to load) with an "Edit Photo" action that captures a new
/// photo via the camera and uploads it.
class _PhotoSection extends StatelessWidget {
  const _PhotoSection({required this.record, required this.isUpdatingPhoto});

  final CvlRecord record;
  final bool isUpdatingPhoto;

  Future<void> _editPhoto(BuildContext context) async {
    final cubit = context.read<CvlLookupCubit>();
    final capturePhoto = context.read<CapturePhoto>();
    final username = context.read<AuthBloc>().state.user?.username;

    final path = await capturePhoto();
    if (path == null) return; // user cancelled
    await cubit.updatePhoto(path, updatedBy: username);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 80,
                height: 80,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: record.hasDisplayableImage
                    ? Image.network(
                        record.imgPath,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.broken_image_outlined,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      )
                    : Icon(
                        Icons.person_outline,
                        size: 40,
                        color: Theme.of(context).colorScheme.outline,
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isUpdatingPhoto ? null : () => _editPhoto(context),
                icon: isUpdatingPhoto
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_outlined),
                label: Text(isUpdatingPhoto ? 'Uploading...' : 'Edit Photo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.rows});

  final String title;
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final entry in rows.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Expanded(child: Text(entry.value)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
