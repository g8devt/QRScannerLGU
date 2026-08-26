import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/cvl_record.dart';
import '../bloc/cvl_lookup_cubit.dart';
import '../bloc/cvl_lookup_state.dart';

/// Editable fields for a CVL record — everything else (name, address,
/// birthdate, precinct, etc.) is shown read-only for context, matching
/// [CvlLookupPage]'s layout, but only Contact No., Email, and Gender
/// can actually be changed and saved here.
const List<String> _genderOptions = ['Male', 'Female'];

class CvlEditPage extends StatefulWidget {
  const CvlEditPage({super.key, required this.recordId});

  final int recordId;

  @override
  State<CvlEditPage> createState() => _CvlEditPageState();
}

class _CvlEditPageState extends State<CvlEditPage> {
  late final CvlLookupCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<CvlLookupCubit>();
    _cubit.fetchById(widget.recordId);
  }

  @override
  void dispose() {
    _cubit.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit CVL Record')),
      body: BlocConsumer<CvlLookupCubit, CvlLookupState>(
        listener: (context, state) {
          final error = state.infoUpdateError;
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
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    state.errorMessage ?? 'Could not load this record.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            case CvlLookupStatus.loaded:
              return _EditForm(
                record: state.record!,
                isSaving: state.isUpdatingInfo,
              );
          }
        },
      ),
    );
  }
}

class _EditForm extends StatefulWidget {
  const _EditForm({required this.record, required this.isSaving});

  final CvlRecord record;
  final bool isSaving;

  @override
  State<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends State<_EditForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _contactController;
  late final TextEditingController _emailController;
  late String? _gender;

  @override
  void initState() {
    super.initState();
    _contactController = TextEditingController(text: widget.record.contactNo);
    _emailController = TextEditingController(text: widget.record.email);
    _gender = widget.record.gender.isNotEmpty ? widget.record.gender : null;
  }

  @override
  void didUpdateWidget(covariant _EditForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the fields in sync with a successful save's echoed-back
    // values (e.g. server-side trimming), without clobbering whatever
    // the user is mid-typing on an unrelated rebuild (isSaving flip).
    if (oldWidget.record != widget.record) {
      _contactController.text = widget.record.contactNo;
      _emailController.text = widget.record.email;
      _gender = widget.record.gender.isNotEmpty ? widget.record.gender : null;
    }
  }

  @override
  void dispose() {
    _contactController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await context.read<CvlLookupCubit>().updateInfo(
      contactNo: _contactController.text.trim(),
      email: _emailController.text.trim(),
      gender: _gender,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Changes saved.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ReadOnlySection(record: record),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact Details',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contactController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Contact No.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) return null;
                        return trimmed.contains('@')
                            ? null
                            : 'Enter a valid email';
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: [
                        for (final option in _genderOptions)
                          DropdownMenuItem(value: option, child: Text(option)),
                      ],
                      onChanged: (value) => setState(() => _gender = value),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.isSaving ? null : () => _save(context),
              icon: widget.isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(widget.isSaving ? 'Saving...' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Everything about the record that isn't editable here — shown for
/// context so the person editing can confirm they have the right
/// record.
class _ReadOnlySection extends StatelessWidget {
  const _ReadOnlySection({required this.record});

  final CvlRecord record;

  @override
  Widget build(BuildContext context) {
    final rows = {
      'Full Name': record.fullName,
      if (record.gender.isNotEmpty) 'Gender': record.gender,
      if (record.birthdate.isNotEmpty) 'Birthdate': record.birthdate,
      if (record.address.isNotEmpty) 'Address': record.address,
      if (record.barangay.isNotEmpty) 'Barangay': record.barangay,
      if (record.municipality.isNotEmpty) 'Municipality': record.municipality,
      if (record.precinctNo.isNotEmpty) 'Precinct No.': record.precinctNo,
      if (record.sector.isNotEmpty) 'Sector': record.sector,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Record Details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Read-only — only contact details below can be edited.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final entry in rows.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w600),
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
