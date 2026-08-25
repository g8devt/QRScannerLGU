import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/cvl_record.dart';
import '../bloc/cvl_lookup_cubit.dart';
import '../bloc/cvl_lookup_state.dart';

/// Read-only view of a scanned CVL record, or a "no record found" message
/// when the scanned QR doesn't match anything in `app_cvl_list`.
class CvlLookupPage extends StatefulWidget {
  const CvlLookupPage({super.key, required this.rawValue});

  final String rawValue;

  @override
  State<CvlLookupPage> createState() => _CvlLookupPageState();
}

class _CvlLookupPageState extends State<CvlLookupPage> {
  late final CvlLookupCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<CvlLookupCubit>();
    _cubit.fetch(widget.rawValue);
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
        body: BlocBuilder<CvlLookupCubit, CvlLookupState>(
          builder: (context, state) {
            switch (state.status) {
              case CvlLookupStatus.initial:
              case CvlLookupStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case CvlLookupStatus.failed:
                return _ErrorView(message: state.errorMessage ?? 'No CVL record was found for this QR code.');
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
  const _DetailsView({required this.record});

  final CvlRecord record;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
            rows: {'Code': record.qrCode},
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
