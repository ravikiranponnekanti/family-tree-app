import 'package:flutter/material.dart';
import 'models/person.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'screens/person_form.dart';
import 'screens/person_detail.dart';
import 'screens/login_screen.dart';
import 'screens/tree_graph_screen.dart';

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
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
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

  void _logout() {
    _auth.logout();
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Tree'),
        actions: [
          IconButton(
            tooltip: 'Tree view',
            icon: const Icon(Icons.account_tree),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TreeGraphScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: FutureBuilder<List<Person>>(
        future: _personsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: ${snapshot.error}\n\n'
                    'Is the backend running and is baseUrl correct?'),
              ),
            );
          }
          final persons = snapshot.data ?? [];
          if (persons.isEmpty) {
            return const Center(child: Text('No family members yet. Tap + to add.'));
          }
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              itemCount: persons.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = persons[i];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(p.firstName.isNotEmpty ? p.firstName[0] : '?'),
                  ),
                  title: Text(p.fullName),
                  subtitle: Text(p.birthDate ?? ''),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PersonDetail(personId: p.id!),
                    ),
                  ).then((_) => _refresh()),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
