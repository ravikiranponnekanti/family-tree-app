import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/person.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class PersonForm extends StatefulWidget {
  final Person? existing;
  const PersonForm({super.key, this.existing});

  @override
  State<PersonForm> createState() => _PersonFormState();
}

class _PersonFormState extends State<PersonForm> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  final _storage = StorageService();

  late TextEditingController _firstName;
  late TextEditingController _lastName;
  late TextEditingController _birthDate;
  late TextEditingController _bio;
  String? _gender;
  bool _saving = false;
  int? _fatherId;
  int? _motherId;
  List<Person> _allPersons = [];
  String? _photoUrl;
  File? _pickedImage;
  bool _uploading = false;

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
    _photoUrl = e?.photoUrl;
    _loadPersons();
  }

  Future<void> _loadPersons() async {
    try {
      final list = await _api.getPersons();
      if (mounted) {
        setState(() {
          _allPersons =
              list.where((p) => p.id != widget.existing?.id).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (picked == null) return;
    setState(() {
      _pickedImage = File(picked.path);
      _uploading = true;
    });
    try {
      final url = await _storage.uploadPhoto(File(picked.path));
      if (mounted) setState(() => _photoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Photo upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
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
      photoUrl: _photoUrl,
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(child: _photoPicker()),
            const SizedBox(height: 20),
            _card([
              TextFormField(
                controller: _firstName,
                decoration: const InputDecoration(
                    labelText: 'First name *',
                    prefixIcon: Icon(Icons.person_outline)),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _lastName,
                decoration: const InputDecoration(
                    labelText: 'Last name',
                    prefixIcon: Icon(Icons.badge_outlined)),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(
                    labelText: 'Gender', prefixIcon: Icon(Icons.wc)),
                items: const [
                  DropdownMenuItem(value: 'MALE', child: Text('Male')),
                  DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  DropdownMenuItem(value: 'UNKNOWN', child: Text('Unknown')),
                ],
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _birthDate,
                decoration: const InputDecoration(
                    labelText: 'Birth date (YYYY-MM-DD)',
                    prefixIcon: Icon(Icons.cake_outlined)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _bio,
                decoration: const InputDecoration(
                    labelText: 'About',
                    prefixIcon: Icon(Icons.notes),
                    alignLabelWithHint: true),
                maxLines: 3,
              ),
            ]),
            const SizedBox(height: 16),
            _card([
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Parents',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: AppTheme.textDark)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _fatherId,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Father', prefixIcon: Icon(Icons.man)),
                items: [
                  const DropdownMenuItem<int?>(
                      value: null, child: Text('— none —')),
                  ..._allPersons.map((p) => DropdownMenuItem<int?>(
                      value: p.id, child: Text(p.fullName))),
                ],
                onChanged: (v) => setState(() => _fatherId = v),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int?>(
                initialValue: _motherId,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Mother', prefixIcon: Icon(Icons.woman)),
                items: [
                  const DropdownMenuItem<int?>(
                      value: null, child: Text('— none —')),
                  ..._allPersons.map((p) => DropdownMenuItem<int?>(
                      value: p.id, child: Text(p.fullName))),
                ],
                onChanged: (v) => setState(() => _motherId = v),
              ),
            ]),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _photoPicker() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 56,
          backgroundColor: AppTheme.surfaceHi,
          backgroundImage: _pickedImage != null
              ? FileImage(_pickedImage!)
              : (_photoUrl != null ? NetworkImage(_photoUrl!) : null)
                  as ImageProvider?,
          child: (_pickedImage == null && _photoUrl == null)
              ? const Icon(Icons.person, size: 56, color: AppTheme.textMuted)
              : null,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            child: _uploading
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white)),
                  )
                : IconButton(
                    iconSize: 20,
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    onPressed: _uploading ? null : _pickAndUpload,
                  ),
          ),
        ),
      ],
    );
  }
}
