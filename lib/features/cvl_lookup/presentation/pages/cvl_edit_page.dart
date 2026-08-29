import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/info_card.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../qr_scanner/domain/usecases/capture_photo.dart';
import '../../domain/entities/cvl_record.dart';
import '../bloc/cvl_lookup_cubit.dart';
import '../bloc/cvl_lookup_state.dart';
import '../widgets/photo_preview_page.dart';

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

  // No reset() in dispose(): this page can now be pushed on top of
  // CvlLookupPage (its "Edit" button), which shares this same
  // CvlLookupCubit instance — resetting it here would wipe the record
  // CvlLookupPage is still displaying underneath. Every fresh open
  // (fetchById) emits a loading state synchronously before its result
  // arrives anyway, so there's no stale data left behind for a
  // subsequent, unrelated use of this cubit to accidentally show.

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
              return _LoadErrorView(
                message: state.errorMessage ?? 'Could not load this record.',
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

/// Failed-to-load state — a soft circular icon badge over the error
/// message, matching the empty/error state pattern used elsewhere (e.g.
/// `_HintMessage` in cvl_search_page.dart) instead of bare centered text.
class _LoadErrorView extends StatelessWidget {
  const _LoadErrorView({required this.message});

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
          ],
        ),
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save changes?'),
        content: const Text(
          'This will update the contact details and photo for this CVL record.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

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
    final scheme = Theme.of(context).colorScheme;
    final isBusy = widget.isSaving || widget.isUpdatingPhoto;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Only contact details and photo below can be edited.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              InfoCard(
                title: 'Record Details',
                rows: {
                  'Full Name': record.fullName,
                  if (record.gender.isNotEmpty) 'Gender': record.gender,
                  if (record.birthdate.isNotEmpty)
                    'Birthdate': record.birthdate,
                  if (record.address.isNotEmpty) 'Address': record.address,
                  if (record.barangay.isNotEmpty) 'Barangay': record.barangay,
                  if (record.municipality.isNotEmpty)
                    'Municipality': record.municipality,
                  if (record.precinctNo.isNotEmpty)
                    'Precinct No.': record.precinctNo,
                  if (record.sector.isNotEmpty) 'Sector': record.sector,
                },
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.contact_phone_outlined,
                            size: 20,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Contact Details',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: _validateContactNo,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _gender,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          prefixIcon: Icon(Icons.wc_outlined),
                        ),
                        items: [
                          for (final option in _genderOptions)
                            DropdownMenuItem(
                              value: option,
                              child: Text(option),
                            ),
                          // Unrecognized legacy value (see _normalizeGender) —
                          // shown as-is so the field isn't silently blanked,
                          // and picking one of the options above overwrites it.
                          if (_gender != null &&
                              !_genderOptions.contains(_gender))
                            DropdownMenuItem(
                              value: _gender,
                              child: Text(_gender!),
                            ),
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
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: isBusy ? null : () => _save(context),
                  icon: isBusy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    isBusy ? 'Saving…' : 'Save Changes',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
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

  /// Whether there's an actual photo to show full-screen — not the
  /// placeholder person icon.
  bool get _hasPreviewableImage =>
      newPhotoPath != null || record.hasDisplayableImage;

  ImageProvider get _imageProvider {
    final stagedPath = newPhotoPath;
    return stagedPath != null
        ? FileImage(File(stagedPath))
        : NetworkImage(record.imgPath);
  }

  void _openFullScreenPreview(BuildContext context) {
    // Guards again here, not just via the thumbnail's onTap being null
    // below — belt and suspenders against ever opening a preview with
    // nothing to show.
    if (!_hasPreviewableImage) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PhotoPreviewPage(image: _imageProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stagedPath = newPhotoPath;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.photo_camera_back_outlined,
                  size: 20,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Text('Photo', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                GestureDetector(
                  onTap: _hasPreviewableImage
                      ? () => _openFullScreenPreview(context)
                      : null,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 80,
                      height: 80,
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
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
                                    errorBuilder:
                                        (context, error, stackTrace) => Icon(
                                          Icons.broken_image_outlined,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outline,
                                        ),
                                  )
                                : Icon(
                                    Icons.person_outline,
                                    size: 40,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  )),
                    ),
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
          ],
        ),
      ),
    );
  }
}
