import 'package:flutter/material.dart';
import 'models/person.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'screens/person_form.dart';
import 'screens/person_detail.dart';
import 'screens/login_screen.dart';
import 'screens/tree_graph_screen.dart';
import 'screens/relationship_finder_screen.dart';
import 'screens/birthdays_screen.dart';
import 'services/pdf_export_service.dart';
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
      title: 'Jumbo Family',
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
    setState(() => _personsFuture = _api.getPersons());
  }

  Future<void> _openForm({Person? existing}) async {
    final result = await Navigator.push<bool>(
      context,
      _fadeRoute<bool>(PersonForm(existing: existing)),
    );
    if (result == true) _refresh();
  }

  Route<T> _fadeRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, a, __) => page,
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
    );
  }

  Future<void> _exportPdf() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final people = await _api.getPersons();
      if (people.isEmpty) {
        messenger.showSnackBar(
            const SnackBar(content: Text('No members to export yet.')));
        return;
      }
      await PdfExportService.exportDirectory(people);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
      body: FutureBuilder<List<Person>>(
        future: _personsFuture,
        builder: (context, snapshot) {
          final loading =
              snapshot.connectionState == ConnectionState.waiting;
          final all = snapshot.data ?? [];
          var persons = all;
          if (_search.isNotEmpty) {
            persons = all
                .where((p) => p.fullName.toLowerCase().contains(_search))
                .toList();
          }
          return RefreshIndicator(
            color: AppTheme.primary,
            backgroundColor: AppTheme.surfaceHi,
            onRefresh: () async => _refresh(),
            child: CustomScrollView(
              slivers: [
                _statsHeader(all),
                if (snapshot.hasError)
                  SliverFillRemaining(
                      hasScrollBody: false,
                      child: _errorState(snapshot.error.toString()))
                else if (loading)
                  const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primary)))
                else if (all.isEmpty)
                  SliverFillRemaining(
                      hasScrollBody: false, child: _emptyState())
                else ...[
                  if (_search.isEmpty) _recentStrip(all),
                  if (_search.isEmpty) _quickActions(),
                  _sectionLabel(
                      _search.isEmpty ? 'All Members' : 'Results'),
                  _grid(persons),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _statsHeader(List<Person> all) {
    final gens = _generationCount(all);
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.heroGradient,
          borderRadius:
              BorderRadius.vertical(bottom: Radius.circular(34)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 22),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ShaderMask(
                    shaderCallback: (b) =>
                        AppTheme.tealGold.createShader(b),
                    child: const Icon(Icons.account_tree,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Jumbo Family',
                        style: TextStyle(
                            color: AppTheme.textLight,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    tooltip: 'Tree view',
                    onPressed: () => Navigator.push(
                        context, _fadeRoute(const TreeGraphScreen())),
                    icon: const Icon(Icons.hub_outlined,
                        color: AppTheme.textLight),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        color: AppTheme.textLight),
                    onSelected: (v) {
                      if (v == 'logout') _confirmLogout();
                      if (v == 'refresh') _refresh();
                      if (v == 'pdf') _exportPdf();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'refresh',
                          child: ListTile(
                              leading: Icon(Icons.refresh),
                              title: Text('Refresh'))),
                      PopupMenuItem(
                          value: 'pdf',
                          child: ListTile(
                              leading: Icon(Icons.picture_as_pdf),
                              title: Text('Export PDF'))),
                      PopupMenuItem(
                          value: 'logout',
                          child: ListTile(
                              leading: Icon(Icons.logout),
                              title: Text('Log out'))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _statChip('${all.length}', 'Members', Icons.people_alt),
                  const SizedBox(width: 12),
                  _statChip('$gens', 'Generations', Icons.layers),
                  const SizedBox(width: 12),
                  _statChip('${all.where((p) => p.photoUrl != null).length}',
                      'Photos', Icons.photo_camera),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search family...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.white70),
                  fillColor: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: AppTheme.textLight,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _recentStrip(List<Person> all) {
    final recent = all.reversed.take(10).toList();
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text('Recently Added',
                  style: TextStyle(
                      color: AppTheme.textLight,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ),
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: recent.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, i) {
                  final p = recent[i];
                  return GestureDetector(
                    onTap: () async {
                      await Navigator.push(context,
                          _fadeRoute(PersonDetail(personId: p.id!)));
                      _refresh();
                    },
                    child: SizedBox(
                      width: 64,
                      child: Column(
                        children: [
                          Hero(
                              tag: 'avatar-${p.id}',
                              child: PersonAvatar(person: p, radius: 30)),
                          const SizedBox(height: 6),
                          Text(p.firstName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppTheme.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActions() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Row(
          children: [
            _actionTile('Birthdays', Icons.cake, AppTheme.gold,
                () => Navigator.push(context, _fadeRoute(const BirthdaysScreen()))),
            const SizedBox(width: 14),
            _actionTile('How Related?', Icons.link, AppTheme.primary,
                () => Navigator.push(
                    context, _fadeRoute(const RelationshipFinderScreen()))),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.textLight,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
        child: Text(text,
            style: const TextStyle(
                color: AppTheme.textLight,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _grid(List<Person> persons) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.82,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => _AnimatedCard(
            index: i,
            child: _profileCard(persons[i]),
          ),
          childCount: persons.length,
        ),
      ),
    );
  }

  Widget _profileCard(Person p) {
    final accent = AppTheme.genderColor(p.gender);
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
            context, _fadeRoute(PersonDetail(personId: p.id!)));
        _refresh();
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 18),
            Hero(
                tag: 'avatar-${p.id}',
                child: PersonAvatar(person: p, radius: 38)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(p.fullName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textLight,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 4),
            if (p.birthDate != null)
              Text(p.birthDate!,
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 12)),
            const Spacer(),
            Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.symmetric(vertical: 6),
              width: double.infinity,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_genderLabel(p.gender),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  String _genderLabel(String? g) {
    switch (g) {
      case 'MALE':
        return 'MALE';
      case 'FEMALE':
        return 'FEMALE';
      default:
        return 'MEMBER';
    }
  }

  int _generationCount(List<Person> all) {
    if (all.isEmpty) return 0;
    final byId = {for (final p in all) p.id: p};
    int depth(Person p, Set<int?> seen) {
      if (seen.contains(p.id)) return 0;
      seen.add(p.id);
      int d = 0;
      for (final pid in [p.fatherId, p.motherId]) {
        final parent = byId[pid];
        if (parent != null) {
          final pd = depth(parent, seen) + 1;
          if (pd > d) d = pd;
        }
      }
      return d;
    }

    int max = 0;
    for (final p in all) {
      final d = depth(p, {});
      if (d > max) max = d;
    }
    return max + 1;
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.family_restroom,
                size: 80, color: AppTheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text('No family members yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textLight)),
            const SizedBox(height: 8),
            const Text('Tap Add to start building your tree.',
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
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textLight)),
            const SizedBox(height: 8),
            const Text(
                'The server may be waking up (~50s on the free plan). Pull down to retry.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted)),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// Staggered fade+slide-in for grid cards.
class _AnimatedCard extends StatefulWidget {
  final int index;
  final Widget child;
  const _AnimatedCard({required this.index, required this.child});
  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: 40 * (widget.index % 8)), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
