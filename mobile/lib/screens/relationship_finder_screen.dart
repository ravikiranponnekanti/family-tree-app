import 'package:flutter/material.dart';
import '../models/person.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/person_avatar.dart';

class RelationshipFinderScreen extends StatefulWidget {
  const RelationshipFinderScreen({super.key});

  @override
  State<RelationshipFinderScreen> createState() =>
      _RelationshipFinderScreenState();
}

class _RelationshipFinderScreenState extends State<RelationshipFinderScreen> {
  final _api = ApiService();
  List<Person> _people = [];
  Person? _from;
  Person? _to;
  String? _resultLabel;
  String? _resultDetail;
  bool _loading = true;
  bool _finding = false;

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    try {
      final list = await _api.getPersons();
      setState(() {
        _people = list;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _find() async {
    if (_from == null || _to == null) return;
    setState(() {
      _finding = true;
      _resultLabel = null;
    });
    try {
      final res = await _api.findRelationship(_from!.id!, _to!.id!);
      setState(() {
        _resultLabel = res['label'] as String?;
        _resultDetail = res['detail'] as String?;
      });
    } catch (e) {
      setState(() {
        _resultLabel = 'Error';
        _resultDetail = e.toString();
      });
    } finally {
      setState(() => _finding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How Are We Related?')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _picker('First person', _from, (p) => setState(() => _from = p)),
                const SizedBox(height: 16),
                Center(
                  child: Icon(Icons.swap_vert,
                      color: AppTheme.primary.withValues(alpha: 0.6),
                      size: 30),
                ),
                const SizedBox(height: 16),
                _picker('Second person', _to, (p) => setState(() => _to = p)),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: (_from != null && _to != null && !_finding)
                      ? _find
                      : null,
                  icon: _finding
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.link),
                  label: const Text('Find Relationship'),
                ),
                const SizedBox(height: 28),
                if (_resultLabel != null) _resultCard(),
              ],
            ),
    );
  }

  Widget _picker(String label, Person? selected, ValueChanged<Person> onPick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final picked = await showModalBottomSheet<Person>(
              context: context,
              backgroundColor: AppTheme.surface,
              shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24))),
              builder: (_) => _pickerSheet(),
            );
            if (picked != null) onPick(picked);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                if (selected != null) ...[
                  PersonAvatar(person: selected, radius: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(selected.fullName,
                        style: const TextStyle(
                            color: AppTheme.textLight,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                ] else
                  const Expanded(
                    child: Text('Tap to choose...',
                        style: TextStyle(color: AppTheme.textMuted)),
                  ),
                const Icon(Icons.expand_more, color: AppTheme.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _pickerSheet() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _people.length,
      itemBuilder: (context, i) {
        final p = _people[i];
        return ListTile(
          leading: PersonAvatar(person: p, radius: 20),
          title: Text(p.fullName,
              style: const TextStyle(color: AppTheme.textLight)),
          onTap: () => Navigator.pop(context, p),
        );
      },
    );
  }

  Widget _resultCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          if (_from != null && _to != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PersonAvatar(person: _from!, radius: 26),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.favorite,
                      color: AppTheme.gold, size: 20),
                ),
                PersonAvatar(person: _to!, radius: 26),
              ],
            ),
          const SizedBox(height: 18),
          ShaderMask(
            shaderCallback: (b) => AppTheme.tealGold.createShader(b),
            child: Text(
              _resultLabel ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
          ),
          if (_to != null) ...[
            const SizedBox(height: 6),
            Text('${_to!.firstName} is the ${_resultLabel?.toLowerCase()}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted)),
          ],
          if (_resultDetail != null) ...[
            const SizedBox(height: 12),
            Text(_resultDetail!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textLight, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
