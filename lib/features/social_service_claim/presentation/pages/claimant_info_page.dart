import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  final _nameController = TextEditingController();
  final _relationController = TextEditingController();
  final _idTypeController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _relationController.dispose();
    _idTypeController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    final info = ClaimantInfo(
      type: _type,
      name: _type == ClaimantType.representative ? _nameController.text.trim() : '',
      relation: _type == ClaimantType.representative ? _relationController.text.trim() : '',
      idType: _idTypeController.text.trim(),
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
                groupValue: _type,
                onChanged: (v) => setState(() => _type = v!),
              ),
              RadioListTile<ClaimantType>(
                title: const Text('Representative'),
                value: ClaimantType.representative,
                groupValue: _type,
                onChanged: (v) => setState(() => _type = v!),
              ),
              if (_type == ClaimantType.representative) ...[
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Representative name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: _relationController,
                  decoration: const InputDecoration(labelText: 'Relation to applicant'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ],
              TextFormField(
                controller: _idTypeController,
                decoration: const InputDecoration(labelText: "ID type (e.g. Driver's License)"),
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
