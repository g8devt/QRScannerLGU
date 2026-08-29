import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/claimant_options.dart';
import '../../domain/entities/claimant_info.dart';
import '../bloc/claim_bloc.dart';
import '../bloc/claim_event.dart';
import 'confirm_identity_page.dart';

class ClaimantInfoPage extends StatefulWidget {
  const ClaimantInfoPage({super.key});

  @override
  State<ClaimantInfoPage> createState() => _ClaimantInfoPageState();
}

class _ClaimantInfoPageState extends State<ClaimantInfoPage> {
  ClaimantType _type = ClaimantType.self;
  String? _idType;
  String? _relation;
  final _nameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _otherIdTypeController = TextEditingController();
  final _otherRelationController = TextEditingController();
  final _claimedAmountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  static final RegExp _amountPattern = RegExp(r'^\d+(\.\d{1,2})?$');

  @override
  void initState() {
    super.initState();
    // Pre-fill from any previously saved claimant info, so reopening this
    // page (e.g. via the edit button on Preview) shows the existing values
    // instead of resetting the form.
    final claimant = context.read<ClaimBloc>().state.claimant;
    _type = claimant.type;
    _nameController.text = claimant.name;
    _idNumberController.text = claimant.idNumber;
    if (claimant.relation.isNotEmpty) {
      if (claimantRelations.contains(claimant.relation)) {
        _relation = claimant.relation;
      } else {
        _relation = 'Other';
        _otherRelationController.text = claimant.relation;
      }
    }
    if (claimant.idType.isNotEmpty) {
      if (philippineIdTypes.contains(claimant.idType)) {
        _idType = claimant.idType;
      } else {
        _idType = 'Other';
        _otherIdTypeController.text = claimant.idType;
      }
    }
    if (claimant.claimedAmount != null) {
      _claimedAmountController.text = claimant.claimedAmount!.toStringAsFixed(
        2,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idNumberController.dispose();
    _otherIdTypeController.dispose();
    _otherRelationController.dispose();
    _claimedAmountController.dispose();
    super.dispose();
  }

  void _onTypeChanged(ClaimantType? value) {
    if (value == null || value == _type) return;
    setState(() {
      _type = value;
      // Clear representative-only fields whenever the claimant type changes,
      // so stale data from a previous selection isn't carried over/submitted.
      _nameController.clear();
      _relation = null;
      _otherRelationController.clear();
    });
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    final relation = _relation == 'Other'
        ? _otherRelationController.text.trim()
        : (_relation ?? '');
    final amountText = _claimedAmountController.text.trim();
    final info = ClaimantInfo(
      type: _type,
      name: _type == ClaimantType.representative
          ? _nameController.text.trim()
          : '',
      relation: _type == ClaimantType.representative ? relation : '',
      idType: _idType == 'Other'
          ? _otherIdTypeController.text.trim()
          : (_idType ?? ''),
      idNumber: _idNumberController.text.trim(),
      claimedAmount: amountText.isEmpty ? null : double.parse(amountText),
    );
    context.read<ClaimBloc>().add(ClaimantInfoSaved(info));
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ConfirmIdentityPage()));
  }

  @override
  Widget build(BuildContext context) {
    final application = context.select(
      (ClaimBloc bloc) => bloc.state.application,
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Claimant Information')),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    children: [
                      if (application != null) ...[
                        _ApplicantBanner(
                          fullName: application.applicantFullName,
                        ),
                        const SizedBox(height: 16),
                      ],
                      _SectionCard(
                        title: 'Who is claiming?',
                        icon: Icons.person_search_outlined,
                        children: [
                          _ClaimantTypeTile(
                            title: 'Self',
                            selected: _type == ClaimantType.self,
                            onTap: () => _onTypeChanged(ClaimantType.self),
                          ),
                          const SizedBox(height: 8),
                          _ClaimantTypeTile(
                            title: 'Representative',
                            selected: _type == ClaimantType.representative,
                            onTap: () =>
                                _onTypeChanged(ClaimantType.representative),
                          ),
                        ],
                      ),
                      if (_type == ClaimantType.representative) ...[
                        const SizedBox(height: 12),
                        _SectionCard(
                          title: 'Representative Details',
                          icon: Icons.badge_outlined,
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Representative name',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _relation,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Relation to applicant',
                              ),
                              items: [
                                for (final relation in claimantRelations)
                                  DropdownMenuItem(
                                    value: relation,
                                    child: Text(
                                      relation,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (v) => setState(() => _relation = v),
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                            if (_relation == 'Other') ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _otherRelationController,
                                decoration: const InputDecoration(
                                  labelText: 'Specify relation',
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Identification',
                        icon: Icons.credit_card_outlined,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _idType,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'ID type',
                            ),
                            items: [
                              for (final type in philippineIdTypes)
                                DropdownMenuItem(
                                  value: type,
                                  child: Text(
                                    type,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) => setState(() => _idType = v),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                          if (_idType == 'Other') ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _otherIdTypeController,
                              decoration: const InputDecoration(
                                labelText: 'Specify ID type',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _idNumberController,
                            decoration: const InputDecoration(
                              labelText: 'ID number',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Claim Amount',
                        icon: Icons.payments_outlined,
                        children: [
                          TextFormField(
                            controller: _claimedAmountController,
                            decoration: const InputDecoration(
                              labelText: 'Claim amount',
                              prefixText: '₱ ',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (v) {
                              final value = v?.trim() ?? '';
                              if (value.isEmpty) return null;
                              if (!_amountPattern.hasMatch(value) ||
                                  double.parse(value) <= 0) {
                                return 'Enter a valid amount';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: FilledButton(
                    onPressed: _continue,
                    child: const Text('Continue'),
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

/// Small identity banner naming the applicant this claimant form is being
/// filled out for — mirrors the avatar/name header pattern used across the
/// app's sheets and detail pages instead of a bare line of text.
class _ApplicantBanner extends StatelessWidget {
  const _ApplicantBanner({required this.fullName});

  final String fullName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.assignment_ind_outlined, color: scheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Applicant',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fullName,
                  style: textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grouped, card-framed section for related form fields — gives the flat
/// list of previously ungrouped fields clear visual hierarchy, matching
/// [InfoCard]'s section-card language elsewhere in the app.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text(title, style: textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Selectable claimant-type tile — a card-style stand-in for the plain
/// [RadioListTile] pair, so "Self" vs "Representative" reads as two
/// distinct choices rather than a default checklist control.
class _ClaimantTypeTile extends StatelessWidget {
  const _ClaimantTypeTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: selected
          ? scheme.primaryContainer
          : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
