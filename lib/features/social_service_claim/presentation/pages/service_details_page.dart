import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/social_service_details.dart';
import '../bloc/service_details_cubit.dart';
import '../bloc/service_details_state.dart';

/// Read-only view of a scanned social service application. Unlike
/// [VerifyPage]'s claim flow, this never gates on status — it just shows
/// whatever `get_service_details_bataan` returns.
class ServiceDetailsPage extends StatefulWidget {
  const ServiceDetailsPage({super.key, required this.rawValue});

  final String rawValue;

  @override
  State<ServiceDetailsPage> createState() => _ServiceDetailsPageState();
}

class _ServiceDetailsPageState extends State<ServiceDetailsPage> {
  late final ServiceDetailsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<ServiceDetailsCubit>();
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
        appBar: AppBar(title: const Text('Application Details')),
        body: BlocBuilder<ServiceDetailsCubit, ServiceDetailsState>(
          builder: (context, state) {
            switch (state.status) {
              case ServiceDetailsStatus.initial:
              case ServiceDetailsStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case ServiceDetailsStatus.failed:
                return _ErrorView(message: state.errorMessage ?? 'Could not load details.');
              case ServiceDetailsStatus.loaded:
                return _DetailsView(details: state.details!);
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
  const _DetailsView({required this.details});

  final SocialServiceDetails details;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Application',
            rows: {
              'Application #': details.applicationNumber,
              'Status': details.status,
              'Service Type': details.serviceType,
              if (details.serviceSubCategory.isNotEmpty) 'Sub-category': details.serviceSubCategory,
              if (details.assistanceType.isNotEmpty) 'Assistance Type': details.assistanceType,
              if (details.briefDescription.isNotEmpty) 'Description': details.briefDescription,
            },
          ),
          _SectionCard(
            title: 'Beneficiary',
            rows: {
              if (details.beneficiaryName.isNotEmpty) 'Beneficiary': details.beneficiaryName,
              'Name': details.applicantFullName,
              if (details.requestedForRelation.isNotEmpty) 'Relation': details.requestedForRelation,
              if (details.requestedForBirthdate.isNotEmpty) 'Birthdate': details.requestedForBirthdate,
              if (details.requestedForGender.isNotEmpty) 'Gender': details.requestedForGender,
              if (details.requestedForContact.isNotEmpty) 'Contact': details.requestedForContact,
              if (details.requestedForEmail.isNotEmpty) 'Email': details.requestedForEmail,
            },
          ),
          _SectionCard(
            title: 'Address',
            rows: {
              if (details.requestedForAddress.isNotEmpty) 'Address': details.requestedForAddress,
              if (details.requestedForBarangay.isNotEmpty) 'Barangay': details.requestedForBarangay,
              if (details.requestedForMunicipality.isNotEmpty) 'Municipality': details.requestedForMunicipality,
              if (details.requestedForProvince.isNotEmpty) 'Province': details.requestedForProvince,
            },
          ),
          _SectionCard(
            title: 'Amount',
            rows: {
              if (details.amount.isNotEmpty) 'Requested Amount': _formatAmount(details.amount),
              if (details.claimedAmount.isNotEmpty) 'Claimed Amount': _formatAmount(details.claimedAmount),
            },
          ),
          _SectionCard(
            title: 'Appointment',
            rows: {
              if (details.appointmentDate.isNotEmpty) 'Date': details.appointmentDate,
              if (details.appointmentTime.isNotEmpty) 'Time': details.appointmentTime,
              if (details.appointmentLocation.isNotEmpty) 'Location': details.appointmentLocation,
            },
          ),
          _SectionCard(
            title: 'Timeline',
            rows: {
              if (details.dateRequested.isNotEmpty) 'Requested': details.dateRequested,
              if (details.dateApproved.isNotEmpty) 'Approved': details.dateApproved,
              if (details.dateScheduled.isNotEmpty) 'Scheduled': details.dateScheduled,
              if (details.dateReleased.isNotEmpty) 'Released': details.dateReleased,
              if (details.dateClaimed.isNotEmpty) 'Claimed': details.dateClaimed,
            },
          ),
          _DocumentsSection(details: details),
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

/// Formats a raw numeric string (e.g. `"1500"`, `"2340.5"`) as
/// `1,500.00` — comma thousands separators, always 2 decimal places.
/// Falls back to the original string if it isn't a valid number.
String _formatAmount(String raw) {
  final value = double.tryParse(raw);
  if (value == null) return raw;
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final wholeDigits = parts[0].replaceFirst('-', '');
  final sign = parts[0].startsWith('-') ? '-' : '';
  final buffer = StringBuffer();
  for (var i = 0; i < wholeDigits.length; i++) {
    if (i > 0 && (wholeDigits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(wholeDigits[i]);
  }
  return '$sign$buffer.${parts[1]}';
}

class _DocumentsSection extends StatelessWidget {
  const _DocumentsSection({required this.details});

  final SocialServiceDetails details;

  @override
  Widget build(BuildContext context) {
    final documents = [
      if (details.photo2x2.isNotEmpty) ServiceDocument(label: '2x2 Photo', url: details.photo2x2),
      if (details.photoSignature.isNotEmpty) ServiceDocument(label: 'Signature', url: details.photoSignature),
      if (details.imageVerification.isNotEmpty)
        ServiceDocument(label: 'Verification Photo', url: details.imageVerification),
      ...details.documents,
    ];
    if (documents.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Documents', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [for (final doc in documents) _DocumentThumbnail(document: doc)],
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentThumbnail extends StatelessWidget {
  const _DocumentThumbnail({required this.document});

  final ServiceDocument document;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _ImageViewerPage(document: document)),
      ),
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 100,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 100,
                height: 100,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Image.network(
                  document.url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.broken_image_outlined,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              document.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageViewerPage extends StatelessWidget {
  const _ImageViewerPage({required this.document});

  final ServiceDocument document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(document.label),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.network(
            document.url,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 64,
            ),
          ),
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
                      width: 140,
                      child: Text(
                        entry.key,
                        style: TextStyle(color: Theme.of(context).colorScheme.outline),
                      ),
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
