import 'package:flutter/material.dart';
import '../models/person.dart';
import '../models/relationship.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/person_avatar.dart';
import 'person_form.dart';
import 'tree_graph_screen.dart';

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
  late Future<List<Relationship>> _relationshipsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _personFuture = _api.getPerson(widget.personId);
      _childrenFuture = _api.getChildren(widget.personId);
      _relationshipsFuture = _api.getRelationshipsForPerson(widget.personId);
    });
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete this person?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      try {
        await _api.deletePerson(widget.personId);
        if (mounted) navigator.pop(true);
      } catch (e) {
        messenger.showSnackBar(
            SnackBar(content: Text("Couldn't delete: $e")));
      }
    }
  }

  Future<void> _addRelationship() async {
    final all = await _api.getPersons();
    final candidates = all.where((p) => p.id != widget.personId).toList();
    if (!mounted) return;
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add another person first.')));
      return;
    }
    int? selectedPartnerId = candidates.first.id;
    String selectedType = 'MARRIED';

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Add relationship'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int?>(
                initialValue: selectedPartnerId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Partner'),
                items: candidates
                    .map((p) => DropdownMenuItem<int?>(
                        value: p.id, child: Text(p.fullName)))
                    .toList(),
                onChanged: (v) => setLocal(() => selectedPartnerId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'MARRIED', child: Text('Married')),
                  DropdownMenuItem(value: 'PARTNER', child: Text('Partner')),
                  DropdownMenuItem(value: 'ENGAGED', child: Text('Engaged')),
                  DropdownMenuItem(
                      value: 'DIVORCED', child: Text('Divorced')),
                ],
                onChanged: (v) =>
                    setLocal(() => selectedType = v ?? 'MARRIED'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add')),
          ],
        ),
      ),
    );

    if (created == true && selectedPartnerId != null) {
      await _api.createRelationship(Relationship(
        personAId: widget.personId,
        personBId: selectedPartnerId!,
        type: selectedType,
      ));
      _load();
    }
  }

  Future<void> _removeRelationship(int id) async {
    await _api.deleteRelationship(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Person>(
        future: _personFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 56, color: AppTheme.textMuted),
                    const SizedBox(height: 16),
                    const Text("Couldn't load this person.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppTheme.textLight,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 12)),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Go back'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final p = snapshot.data!;
          return CustomScrollView(
            slivers: [
              _heroAppBar(p),
              SliverToBoxAdapter(child: _body(p)),
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

  Widget _heroAppBar(Person p) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      actions: [
        IconButton(
          tooltip: 'Show my family in tree',
          icon: const Icon(Icons.account_tree),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => TreeGraphScreen(highlightId: p.id)),
          ),
        ),
        IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Hero(
                  tag: 'avatar-${p.id}',
                  child: PersonAvatar(person: p, radius: 50),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(p.fullName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(Person p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoChips(p),
          if (p.bio != null && p.bio!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionCard(
              icon: Icons.notes,
              title: 'About',
              child: Text(p.bio!,
                  style: const TextStyle(height: 1.4, color: AppTheme.textDark)),
            ),
          ],
          const SizedBox(height: 16),
          _childrenSection(),
          const SizedBox(height: 16),
          _relationshipsSection(),
        ],
      ),
    );
  }

  Widget _infoChips(Person p) {
    final chips = <Widget>[];
    if (p.gender != null) {
      chips.add(_chip(Icons.wc, p.gender!));
    }
    if (p.birthDate != null) {
      chips.add(_chip(Icons.cake_outlined, 'Born ${p.birthDate}'));
    }
    if (p.deathDate != null) {
      chips.add(_chip(Icons.local_florist_outlined, 'Died ${p.deathDate}'));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textDark)),
        ],
      ),
    );
  }

  Widget _sectionCard(
      {required IconData icon,
      required String title,
      required Widget child,
      Widget? action}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark)),
                const Spacer(),
                if (action != null) action,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _childrenSection() {
    return _sectionCard(
      icon: Icons.child_care,
      title: 'Children',
      child: FutureBuilder<List<Person>>(
        future: _childrenFuture,
        builder: (context, snap) {
          final kids = snap.data ?? [];
          if (kids.isEmpty) {
            return const Text('None recorded',
                style: TextStyle(color: AppTheme.textMuted));
          }
          return Column(
            children: kids
                .map((k) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: PersonAvatar(person: k, radius: 20),
                      title: Text(k.fullName),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppTheme.textMuted),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PersonDetail(personId: k.id!)),
                      ),
                    ))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _relationshipsSection() {
    return _sectionCard(
      icon: Icons.favorite_border,
      title: 'Relationships',
      action: TextButton.icon(
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add'),
        onPressed: _addRelationship,
      ),
      child: FutureBuilder<List<Relationship>>(
        future: _relationshipsFuture,
        builder: (context, relSnap) {
          final rels = relSnap.data ?? [];
          if (rels.isEmpty) {
            return const Text('None recorded',
                style: TextStyle(color: AppTheme.textMuted));
          }
          return FutureBuilder<List<Person>>(
            future: _api.getPersons(),
            builder: (context, peopleSnap) {
              final people = peopleSnap.data ?? [];
              Person personFor(int id) => people.firstWhere((p) => p.id == id,
                  orElse: () => Person(firstName: 'Unknown'));
              return Column(
                children: rels.map((r) {
                  final otherId = r.personAId == widget.personId
                      ? r.personBId
                      : r.personAId;
                  final other = personFor(otherId);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: PersonAvatar(person: other, radius: 20),
                    title: Text(other.fullName),
                    subtitle: Text(_relLabel(r.type)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _removeRelationship(r.id!),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => PersonDetail(personId: otherId)),
                    ),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }

  String _relLabel(String? type) {
    switch (type) {
      case 'MARRIED':
        return 'Married';
      case 'PARTNER':
        return 'Partner';
      case 'ENGAGED':
        return 'Engaged';
      case 'DIVORCED':
        return 'Divorced';
      default:
        return type ?? '';
    }
  }
}
