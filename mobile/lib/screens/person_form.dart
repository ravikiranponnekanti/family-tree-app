import 'package:flutter/material.dart';
import '../models/person.dart';
import '../services/api_service.dart';

class PersonForm extends StatefulWidget {
  final Person? existing;
  const PersonForm({super.key, this.existing});

  @override
  State<PersonForm> createState() => _PersonFormState();
}

class _PersonFormState extends State<PersonForm> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  late TextEditingController _firstName;
  late TextEditingController _lastName;
  late TextEditingController _birthDate;
  late TextEditingController _bio;
  String? _gender;
  bool _saving = false;
  int? _fatherId;
  int? _motherId;
  List<Person> _allPersons = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _firstName = TextEditingController(text: e?.firstName ?? '');
    _lastName = TextEditingController(text: e?.lastName ?? '');
    _birthDate = TextEditingController(text: e?.birthDate ?? '');
    _bio = TextEditingController(text: e?.bio ?? '');
    _gender = e?.gender;
    _fatherId = e?.fatherId;
    _motherId = e?.motherId;
    _loadPersons();
  }

  Future<void> _loadPersons() async {
    try {
      final list = await _api.getPersons();
      if (mounted) {
        setState(() {
          // Exclude self to prevent a person being their own parent.
          _allPersons =
              list.where((p) => p.id != widget.existing?.id).toList();
        });
      }
    } catch (_) {
      // Non-fatal: parent pickers just stay empty.
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _birthDate.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final person = Person(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim().isEmpty ? null : _lastName.text.trim(),
      gender: _gender,
      birthDate: _birthDate.text.trim().isEmpty ? null : _birthDate.text.trim(),
      bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
      fatherId: _fatherId,
      motherId: _motherId,
    );

    try {
      if (widget.existing == null) {
        await _api.createPerson(person);
      } else {
        await _api.updatePerson(widget.existing!.id!, person);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit Person' : 'Add Person')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _firstName,
                decoration: const InputDecoration(labelText: 'First name *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _lastName,
                decoration: const InputDecoration(labelText: 'Last name'),
              ),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'MALE', child: Text('Male')),
                  DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  DropdownMenuItem(value: 'UNKNOWN', child: Text('Unknown')),
                ],
                onChanged: (v) => setState(() => _gender = v),
              ),
              TextFormField(
                controller: _birthDate,
                decoration: const InputDecoration(
                    labelText: 'Birth date (YYYY-MM-DD)'),
              ),
              TextFormField(
                controller: _bio,
                decoration: const InputDecoration(labelText: 'Bio'),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                value: _fatherId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Father'),
                items: [
                  const DropdownMenuItem<int?>(
                      value: null, child: Text('— none —')),
                  ..._allPersons.map((p) => DropdownMenuItem<int?>(
                      value: p.id, child: Text(p.fullName))),
                ],
                onChanged: (v) => setState(() => _fatherId = v),
              ),
              DropdownButtonFormField<int?>(
                value: _motherId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Mother'),
                items: [
                  const DropdownMenuItem<int?>(
                      value: null, child: Text('— none —')),
                  ..._allPersons.map((p) => DropdownMenuItem<int?>(
                      value: p.id, child: Text(p.fullName))),
                ],
                onChanged: (v) => setState(() => _motherId = v),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
