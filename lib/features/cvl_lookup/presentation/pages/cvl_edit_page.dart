import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../qr_scanner/domain/usecases/capture_photo.dart';
import '../../domain/entities/cvl_record.dart';
import '../bloc/cvl_lookup_cubit.dart';
import '../bloc/cvl_lookup_state.dart';

/// Editable fields for a CVL record — everything else (name, address,
/// birthdate, precinct, etc.) is shown read-only for context, matching
/// [CvlLookupPage]'s layout, but only Contact No., Email, and Gender
/// can actually be changed and saved here.
const List<String> _genderOptions = ['Male', 'Female'];

/// A PH mobile number in local format — 11 digits, starting with "09"
/// (e.g. `09171234567`) — matching how numbers are already stored
/// elsewhere in this app/DB.
final RegExp _mobileNumberPattern = RegExp(r'^09\d{9}$');

final RegExp _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

/// Both fields are optional (an empty value clears it) but must be
/// well-formed when non-empty.
String? _validateContactNo(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  return _mobileNumberPattern.hasMatch(trimmed)
      ? null
      : 'Enter an 11-digit mobile number starting with 09';
}

String? _validateEmail(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  return _emailPattern.hasMatch(trimmed) ? null : 'Enter a valid email';
}

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
          final error = state.infoUpdateError ?? state.photoUpdateError;
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
                isUpdatingPhoto: state.isUpdatingPhoto,
              );
          }
        },
      ),
    );
  }
}

class _EditForm extends StatefulWidget {
  const _EditForm({
    required this.record,
    required this.isSaving,
    required this.isUpdatingPhoto,
  });

  final CvlRecord record;
  final bool isSaving;
  final bool isUpdatingPhoto;

  @override
  State<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends State<_EditForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _contactController;
  late final TextEditingController _emailController;
  late String? _gender;

  /// A freshly captured photo staged locally — not uploaded yet. It's
  /// only sent to the backend when Save Changes is pressed, alongside
  /// the contact fields, instead of uploading the moment it's captured.
  String? _newPhotoPath;

  /// `cvl_gender` is a free-text column (no DB enum constraint) — legacy
  /// data holds casings like "MALE" that don't exactly match
  /// [_genderOptions]' "Male"/"Female", and DropdownButtonFormField
  /// requires an exact value match or it throws. Normalizes to the
  /// canonical option when it matches case-insensitively; otherwise
  /// keeps the raw value as-is so it can still be shown (see the
  /// dropdown's `items` in build(), which adds it as an extra entry)
  /// instead of crashing or silently discarding it.
  static String? _normalizeGender(String raw) {
    if (raw.isEmpty) return null;
    for (final option in _genderOptions) {
      if (option.toLowerCase() == raw.toLowerCase()) return option;
    }
    return raw;
  }

  @override
  void initState() {
    super.initState();
    _contactController = TextEditingController(text: widget.record.contactNo);
    _emailController = TextEditingController(text: widget.record.email);
    _gender = _normalizeGender(widget.record.gender);
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
      _gender = _normalizeGender(widget.record.gender);
    }
  }

  @override
  void dispose() {
    _contactController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto(BuildContext context) async {
    final path = await context.read<CapturePhoto>()();
    if (path == null) return; // user cancelled
    if (mounted) setState(() => _newPhotoPath = path);
  }

  Future<void> _save(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final cubit = context.read<CvlLookupCubit>();

    final stagedPhotoPath = _newPhotoPath;
    if (stagedPhotoPath != null) {
      final username = context.read<AuthBloc>().state.user?.username;
      await cubit.updatePhoto(stagedPhotoPath, updatedBy: username);
      // updatePhoto() never throws — it reports failure via
      // photoUpdateError in state instead. Stop here so a failed photo
      // upload doesn't silently skip straight to saving the other
      // fields; the error listener in CvlEditPage shows the message and
      // the staged photo stays in place for the user to retry.
      if (!context.mounted || cubit.state.photoUpdateError != null) return;
    }

    await cubit.updateInfo(
      contactNo: _contactController.text.trim(),
      email: _emailController.text.trim(),
      gender: _gender,
    );
    if (!context.mounted) return;
    if (cubit.state.infoUpdateError != null) return;

    // Success — back to the search results list, which shows the
    // confirmation snackbar once it regains focus (see _openEditPage in
    // cvl_search_page.dart), matching the Set QR flow's pattern.
    Navigator.of(context).pop(true);
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
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Contact No.',
                        hintText: '09XXXXXXXXX',
                      ),
                      validator: _validateContactNo,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: [
                        for (final option in _genderOptions)
                          DropdownMenuItem(value: option, child: Text(option)),
                        // Unrecognized legacy value (see _normalizeGender) —
                        // shown as-is so the field isn't silently blanked,
                        // and picking one of the options above overwrites it.
                        if (_gender != null && !_genderOptions.contains(_gender))
                          DropdownMenuItem(value: _gender, child: Text(_gender!)),
                      ],
                      onChanged: (value) => setState(() => _gender = value),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _EditablePhotoSection(
              record: record,
              newPhotoPath: _newPhotoPath,
              onCapture: () => _capturePhoto(context),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: (widget.isSaving || widget.isUpdatingPhoto)
                  ? null
                  : () => _save(context),
              icon: (widget.isSaving || widget.isUpdatingPhoto)
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                (widget.isSaving || widget.isUpdatingPhoto)
                    ? 'Saving...'
                    : 'Save Changes',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Photo capture for the edit form — unlike [CvlPhotoSection] (used by
/// the read-only detail view), capturing here only stages [newPhotoPath]
/// locally; it's uploaded together with the rest of the form when Save
/// Changes is pressed, not immediately on capture.
class _EditablePhotoSection extends StatelessWidget {
  const _EditablePhotoSection({
    required this.record,
    required this.newPhotoPath,
    required this.onCapture,
  });

  final CvlRecord record;

  /// A freshly captured photo not yet saved, if any — takes priority
  /// over [record]'s existing photo for the preview.
  final String? newPhotoPath;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final stagedPath = newPhotoPath;
    return Card(
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
                child: stagedPath != null
                    ? Image.file(File(stagedPath), fit: BoxFit.cover)
                    : (record.hasDisplayableImage
                          ? Image.network(
                              record.imgPath,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    Icons.broken_image_outlined,
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                            )
                          : Icon(
                              Icons.person_outline,
                              size: 40,
                              color: Theme.of(context).colorScheme.outline,
                            )),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCapture,
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(
                  stagedPath != null ? 'Retake Photo' : 'Change Photo',
                ),
              ),
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
