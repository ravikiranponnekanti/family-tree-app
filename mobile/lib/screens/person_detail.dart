import 'package:flutter/material.dart';
import '../models/person.dart';
import '../services/api_service.dart';
import 'person_form.dart';

class PersonDetail extends StatefulWidget {
  final int personId;
  const PersonDetail({super.key, required this.personId});

  @override
  State<PersonDetail> createState() => _PersonDetailState();
}

class _PersonDetailState extends State<PersonDetail> {
  final _api = ApiService();
  late Future<Person> _personFuture;
  late Future<List<Person>> _childrenFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _personFuture = _api.getPerson(widget.personId);
      _childrenFuture = _api.getChildren(widget.personId);
    });
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await _api.deletePerson(widget.personId);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        actions: [
          IconButton(icon: const Icon(Icons.delete), onPressed: _delete),
        ],
      ),
      body: FutureBuilder<Person>(
        future: _personFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final p = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(p.fullName,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              if (p.gender != null) Text('Gender: ${p.gender}'),
              if (p.birthDate != null) Text('Born: ${p.birthDate}'),
              if (p.deathDate != null) Text('Died: ${p.deathDate}'),
              if (p.bio != null) ...[
                const SizedBox(height: 12),
                Text(p.bio!),
              ],
              const Divider(height: 32),
              Text('Children',
                  style: Theme.of(context).textTheme.titleMedium),
              FutureBuilder<List<Person>>(
                future: _childrenFuture,
                builder: (context, snap) {
                  final kids = snap.data ?? [];
                  if (kids.isEmpty) return const Text('None recorded');
                  return Column(
                    children: kids
                        .map((k) => ListTile(
                              title: Text(k.fullName),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PersonDetail(personId: k.id!),
                                ),
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.edit),
        onPressed: () async {
          final p = await _personFuture;
          if (!mounted) return;
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => PersonForm(existing: p)),
          );
          if (result == true) _load();
        },
      ),
    );
  }
}
