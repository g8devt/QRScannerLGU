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
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _idNumberController.dispose();
    _otherIdTypeController.dispose();
    _otherRelationController.dispose();
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
    final relation = _relation == 'Other' ? _otherRelationController.text.trim() : (_relation ?? '');
    final info = ClaimantInfo(
      type: _type,
      name: _type == ClaimantType.representative ? _nameController.text.trim() : '',
      relation: _type == ClaimantType.representative ? relation : '',
      idType: _idType == 'Other' ? _otherIdTypeController.text.trim() : (_idType ?? ''),
      idNumber: _idNumberController.text.trim(),
    );
    context.read<ClaimBloc>().add(ClaimantInfoSaved(info));
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConfirmIdentityPage()));
  }

  @override
  Widget build(BuildContext context) {
    final application = context.select((ClaimBloc bloc) => bloc.state.application);
    return Scaffold(
      appBar: AppBar(title: const Text('Claimant Information')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (application != null)
                Text('Applicant: ${application.applicantFullName}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              const Text('Who is claiming?', style: TextStyle(fontWeight: FontWeight.bold)),
              RadioListTile<ClaimantType>(
                title: const Text('Self'),
                value: ClaimantType.self,
                // ignore: deprecated_member_use
                groupValue: _type,
                // ignore: deprecated_member_use
                onChanged: _onTypeChanged,
              ),
              RadioListTile<ClaimantType>(
                title: const Text('Representative'),
                value: ClaimantType.representative,
                // ignore: deprecated_member_use
                groupValue: _type,
                // ignore: deprecated_member_use
                onChanged: _onTypeChanged,
              ),
              if (_type == ClaimantType.representative) ...[
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Representative name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _relation,
                  decoration: const InputDecoration(labelText: 'Relation to applicant'),
                  items: [
                    for (final relation in claimantRelations) DropdownMenuItem(value: relation, child: Text(relation)),
                  ],
                  onChanged: (v) => setState(() => _relation = v),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                if (_relation == 'Other')
                  TextFormField(
                    controller: _otherRelationController,
                    decoration: const InputDecoration(labelText: 'Specify relation'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
              ],
              DropdownButtonFormField<String>(
                initialValue: _idType,
                decoration: const InputDecoration(labelText: 'ID type'),
                items: [
                  for (final type in philippineIdTypes) DropdownMenuItem(value: type, child: Text(type)),
                ],
                onChanged: (v) => setState(() => _idType = v),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              if (_idType == 'Other')
                TextFormField(
                  controller: _otherIdTypeController,
                  decoration: const InputDecoration(labelText: 'Specify ID type'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              TextFormField(
                controller: _idNumberController,
                decoration: const InputDecoration(labelText: 'ID number'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _continue, child: const Text('Continue')),
            ],
          ),
        ),
      ),
    );
  }
}
