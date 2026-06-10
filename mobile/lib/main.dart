import 'package:flutter/material.dart';
import 'models/person.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'screens/person_form.dart';
import 'screens/person_detail.dart';
import 'screens/login_screen.dart';
import 'screens/tree_graph_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/person_avatar.dart';

void main() => runApp(const FamilyTreeApp());

class FamilyTreeApp extends StatefulWidget {
  const FamilyTreeApp({super.key});

  @override
  State<FamilyTreeApp> createState() => _FamilyTreeAppState();
}

class _FamilyTreeAppState extends State<FamilyTreeApp> {
  bool _loggedIn = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Tree',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme(),
      home: _loggedIn
          ? HomeScreen(onLogout: () => setState(() => _loggedIn = false))
          : LoginScreen(onLoggedIn: () => setState(() => _loggedIn = true)),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  late Future<List<Person>> _personsFuture;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _personsFuture = _api.getPersons();
    });
  }

  Future<void> _openForm({Person? existing}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PersonForm(existing: existing)),
    );
    if (result == true) _refresh();
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Log out?'),
        content: const Text('You will need to log in again next time.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _auth.logout();
              widget.onLogout();
            },
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add'),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('My Family Tree',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ),
              IconButton(
                tooltip: 'Tree view',
                icon: const Icon(Icons.hub_outlined, color: Colors.white),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TreeGraphScreen()),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (v) {
                  if (v == 'logout') _confirmLogout();
                  if (v == 'refresh') _refresh();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'refresh',
                      child: ListTile(
                          leading: Icon(Icons.refresh),
                          title: Text('Refresh'))),
                  const PopupMenuItem(
                      value: 'logout',
                      child: ListTile(
                          leading: Icon(Icons.logout),
                          title: Text('Log out'))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search family members...',
              prefixIcon: const Icon(Icons.search),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return FutureBuilder<List<Person>>(
      future: _personsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _errorState(snapshot.error.toString());
        }
        var persons = snapshot.data ?? [];
        if (_search.isNotEmpty) {
          persons = persons
              .where((p) => p.fullName.toLowerCase().contains(_search))
              .toList();
        }
        if (persons.isEmpty) {
          return _emptyState();
        }
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
            itemCount: persons.length,
            itemBuilder: (context, i) => _personCard(persons[i]),
          ),
        );
      },
    );
  }

  Widget _personCard(Person p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PersonDetail(personId: p.id!)),
        ).then((_) => _refresh()),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              PersonAvatar(person: p, radius: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.fullName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark)),
                    if (p.birthDate != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.cake_outlined,
                              size: 14, color: AppTheme.textMuted),
                          const SizedBox(width: 5),
                          Text(p.birthDate!,
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.textMuted)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.family_restroom,
                size: 72, color: AppTheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              _search.isNotEmpty
                  ? 'No matches for "$_search"'
                  : 'No family members yet',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark),
            ),
            const SizedBox(height: 8),
            const Text('Tap the Add button to start building your tree.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _errorState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            const Text('Could not load data',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'The server may be waking up (takes ~50s on the free plan). '
              'Pull down to retry.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
