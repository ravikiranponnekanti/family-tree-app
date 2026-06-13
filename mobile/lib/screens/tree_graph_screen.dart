import 'package:flutter/material.dart';
import '../models/person.dart';
import '../models/relationship.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/person_avatar.dart';
import 'person_detail.dart';

class TreeGraphScreen extends StatefulWidget {
  final int? highlightId;
  const TreeGraphScreen({super.key, this.highlightId});
  @override
  State<TreeGraphScreen> createState() => _TreeGraphScreenState();
}

class _TreeGraphScreenState extends State<TreeGraphScreen> {
  final _api = ApiService();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = Future.wait([_api.getPersons(), _api.getRelationships()]);
  }

  Widget _legendDot(Color c) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Tree'),
        flexibleSpace:
            Container(decoration: const BoxDecoration(gradient: AppTheme.heroGradient)),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final persons = snapshot.data![0] as List<Person>;
          final rels = snapshot.data![1] as List<Relationship>;
          if (persons.isEmpty) {
            return const Center(child: Text('No people to display yet.'));
          }
          return Stack(
            children: [
              _TreeView(
                  persons: persons,
                  relationships: rels,
                  highlightId: widget.highlightId),
              if (widget.highlightId != null)
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _legendDot(AppTheme.gold),
                        const Text('  Selected   ',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textDark)),
                        _legendDot(AppTheme.primary),
                        const Text('  Family',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textDark)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Node {
  final Person person;
  double x = 0; // center x
  int depth = 0;
  _Node(this.person);
}

class _TreeView extends StatelessWidget {
  final List<Person> persons;
  final List<Relationship> relationships;
  final int? highlightId;
  const _TreeView(
      {required this.persons,
      required this.relationships,
      this.highlightId});

  static const double nodeW = 120;
  static const double nodeH = 96;
  static const double hGap = 28;
  static const double vGap = 70;
  static const double coupleGap = 16;

  @override
  Widget build(BuildContext context) {
    // Compute the nuclear family of the highlighted person:
    // parents + spouse(s) + children.
    final Set<int> familyIds = {};
    if (highlightId != null) {
      final self = persons.firstWhere((p) => p.id == highlightId,
          orElse: () => Person(firstName: ''));
      // parents
      if (self.fatherId != null) familyIds.add(self.fatherId!);
      if (self.motherId != null) familyIds.add(self.motherId!);
      // children
      for (final p in persons) {
        if (p.fatherId == highlightId || p.motherId == highlightId) {
          familyIds.add(p.id!);
        }
      }
      // spouse(s)
      for (final r in relationships) {
        if (r.personAId == highlightId) familyIds.add(r.personBId);
        if (r.personBId == highlightId) familyIds.add(r.personAId);
      }
      familyIds.remove(highlightId); // self is gold, not green
    }

    final nodes = <int, _Node>{};
    for (final p in persons) {
      nodes[p.id!] = _Node(p);
    }

    // ---- spouse map (who is married to whom) ----
    final spouseOf = <int, int>{};
    for (final r in relationships) {
      // first spouse link wins for layout pairing
      spouseOf.putIfAbsent(r.personAId, () => r.personBId);
      spouseOf.putIfAbsent(r.personBId, () => r.personAId);
    }

    // 1) assign depth = longest ancestor chain
    int depthOf(int id, Set<int> seen) {
      final n = nodes[id];
      if (n == null) return 0;
      if (seen.contains(id)) return n.depth;
      seen.add(id);
      int d = 0;
      for (final pid in [n.person.fatherId, n.person.motherId]) {
        if (pid != null && nodes.containsKey(pid)) {
          final pd = depthOf(pid, seen) + 1;
          if (pd > d) d = pd;
        }
      }
      n.depth = d;
      return d;
    }

    for (final id in nodes.keys) {
      depthOf(id, {});
    }

    // Align spouses to the same (deeper) depth so couples sit on one row
    for (final entry in spouseOf.entries) {
      final a = nodes[entry.key];
      final b = nodes[entry.value];
      if (a != null && b != null) {
        final d = a.depth > b.depth ? a.depth : b.depth;
        a.depth = d;
        b.depth = d;
      }
    }

    int maxDepth = 0;
    for (final n in nodes.values) {
      if (n.depth > maxDepth) maxDepth = n.depth;
    }

    // children of a person
    final childrenOf = <int, List<_Node>>{};
    for (final n in nodes.values) {
      for (final pid in [n.person.fatherId, n.person.motherId]) {
        if (pid != null && nodes.containsKey(pid)) {
          childrenOf.putIfAbsent(pid, () => []).add(n);
        }
      }
    }

    // 2) couple-aware tidy layout.
    // A "unit" is either a single person or a married couple. We place units
    // left-to-right; a couple occupies two node slots side by side and its
    // children hang from the midpoint between the two spouses.
    double nextLeaf = 0;
    final positioned = <int>{};

    // returns the center x of the placed unit
    double placeUnit(_Node n) {
      if (positioned.contains(n.person.id)) return n.x;

      final spouseId = spouseOf[n.person.id];
      final spouse = spouseId != null ? nodes[spouseId] : null;
      final hasSpouse = spouse != null && !positioned.contains(spouseId);

      // gather children of this couple/person
      final kidSet = <int, _Node>{};
      for (final k in (childrenOf[n.person.id] ?? [])) {
        kidSet[k.person.id!] = k;
      }
      if (spouse != null) {
        for (final k in (childrenOf[spouseId] ?? [])) {
          kidSet[k.person.id!] = k;
        }
      }
      final kids = kidSet.values.toList()
        ..sort((a, b) => a.person.id!.compareTo(b.person.id!));

      positioned.add(n.person.id!);
      if (hasSpouse) positioned.add(spouseId!);

      if (kids.isEmpty) {
        // place couple/person at the current leaf position
        if (hasSpouse) {
          n.x = nextLeaf;
          spouse.x = nextLeaf + nodeW + coupleGap;
          nextLeaf += 2 * nodeW + coupleGap + hGap;
          return (n.x + spouse.x) / 2;
        } else {
          n.x = nextLeaf;
          nextLeaf += nodeW + hGap;
          return n.x;
        }
      } else {
        // place children first
        final kidCenters = <double>[];
        for (final k in kids) {
          kidCenters.add(placeUnit(k));
        }
        final childMid = (kidCenters.reduce((a, b) => a < b ? a : b) +
                kidCenters.reduce((a, b) => a > b ? a : b)) /
            2;
        // center the couple over their children's midpoint
        if (hasSpouse) {
          // symmetric around childMid: spouse A on left, spouse B on right
          n.x = childMid - nodeW - coupleGap / 2;
          spouse.x = childMid + coupleGap / 2;
          return childMid;
        } else {
          n.x = childMid - nodeW / 2;
          return childMid;
        }
      }
    }

    // Place starting from top-most generation (roots), couples first.
    final roots = nodes.values.where((n) => n.depth == 0).toList()
      ..sort((a, b) => a.person.id!.compareTo(b.person.id!));
    for (final r in roots) {
      placeUnit(r);
    }
    // place anything left (people whose parents weren't roots, orphans)
    final remaining = nodes.values.toList()
      ..sort((a, b) => a.depth.compareTo(b.depth));
    for (final n in remaining) {
      if (!positioned.contains(n.person.id)) {
        placeUnit(n);
      }
    }

    // compute canvas size
    double minX = double.infinity, maxX = -double.infinity;
    for (final n in nodes.values) {
      if (n.x < minX) minX = n.x;
      if (n.x > maxX) maxX = n.x;
    }
    final shift = -minX + 20;
    for (final n in nodes.values) {
      n.x += shift;
    }
    final canvasW = (maxX - minX) + nodeW + 40;
    final canvasH = (maxDepth + 1) * (nodeH + vGap) + 40;

    final positions = <int, Offset>{
      for (final n in nodes.values)
        n.person.id!: Offset(n.x, 20 + n.depth * (nodeH + vGap))
    };

    final w = canvasW < 360 ? 360.0 : canvasW;

    return _CenteringViewer(
      canvasWidth: w,
      canvasHeight: canvasH,
      highlightPos: highlightId != null ? positions[highlightId] : null,
      child: Container(
        width: w,
        height: canvasH,
        color: AppTheme.bg,
        child: Stack(
          children: [
            CustomPaint(
              size: Size(canvasW, canvasH),
              painter: _CleanEdgePainter(
                persons: persons,
                relationships: relationships,
                positions: positions,
                nodeW: nodeW,
                nodeH: nodeH,
              ),
            ),
            ...nodes.values.map((n) {
              final pos = positions[n.person.id!]!;
              final isSelf = n.person.id == highlightId;
              final isFamily = familyIds.contains(n.person.id);
              final dim = highlightId != null && !isSelf && !isFamily;
              return Positioned(
                left: pos.dx,
                top: pos.dy,
                child: _NodeCard(
                    person: n.person,
                    highlighted: isSelf,
                    family: isFamily,
                    dimmed: dim),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// InteractiveViewer that auto-centers on a highlighted node on first build.
class _CenteringViewer extends StatefulWidget {
  final double canvasWidth;
  final double canvasHeight;
  final Offset? highlightPos;
  final Widget child;
  const _CenteringViewer({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.highlightPos,
    required this.child,
  });

  @override
  State<_CenteringViewer> createState() => _CenteringViewerState();
}

class _CenteringViewerState extends State<_CenteringViewer> {
  final _controller = TransformationController();

  @override
  void initState() {
    super.initState();
    if (widget.highlightPos != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerOnHighlight());
    }
  }

  void _centerOnHighlight() {
    final pos = widget.highlightPos!;
    final screen = MediaQuery.of(context).size;
    // center the node roughly in the visible area
    const scale = 1.0;
    final dx = -(pos.dx + _TreeView.nodeW / 2) * scale + screen.width / 2;
    final dy = -(pos.dy + _TreeView.nodeH / 2) * scale + screen.height / 3;
    _controller.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale);
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _controller,
      constrained: false,
      minScale: 0.25,
      maxScale: 2.5,
      boundaryMargin: const EdgeInsets.all(400),
      child: widget.child,
    );
  }
}

class _CleanEdgePainter extends CustomPainter {
  final List<Person> persons;
  final List<Relationship> relationships;
  final Map<int, Offset> positions;
  final double nodeW;
  final double nodeH;

  _CleanEdgePainter({
    required this.persons,
    required this.relationships,
    required this.positions,
    required this.nodeW,
    required this.nodeH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.55)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    final spousePaint = Paint()
      ..color = AppTheme.gold
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    // Group children by a "family key" = the couple (or single parent).
    // This way each set of siblings gets ONE bus line from their parents.
    final familyChildren = <String, List<Offset>>{};
    final familyAnchor = <String, Offset>{}; // point just below the parent(s)

    String keyFor(int? fatherId, int? motherId) {
      final ids = [fatherId, motherId].whereType<int>().toList()..sort();
      return ids.join('-');
    }

    for (final p in persons) {
      final childPos = positions[p.id!];
      if (childPos == null) continue;
      final fId = p.fatherId, mId = p.motherId;
      if (fId == null && mId == null) continue;
      if ((fId != null && positions[fId] == null) &&
          (mId != null && positions[mId] == null)) {
        continue;
      }
      final key = keyFor(fId, mId);
      final childTop = Offset(childPos.dx + nodeW / 2, childPos.dy);
      familyChildren.putIfAbsent(key, () => []).add(childTop);

      // anchor = midpoint just below the parents
      if (!familyAnchor.containsKey(key)) {
        final pts = <Offset>[];
        for (final pid in [fId, mId].whereType<int>()) {
          final pp = positions[pid];
          if (pp != null) {
            pts.add(Offset(pp.dx + nodeW / 2, pp.dy + nodeH));
          }
        }
        if (pts.isNotEmpty) {
          final ax =
              pts.map((e) => e.dx).reduce((a, b) => a + b) / pts.length;
          final ay = pts.map((e) => e.dy).reduce((a, b) => a > b ? a : b);
          familyAnchor[key] = Offset(ax, ay);
        }
      }
    }

    // Draw one tidy bus per family
    familyChildren.forEach((key, childTops) {
      final anchor = familyAnchor[key];
      if (anchor == null) return;
      final minChildTop =
          childTops.map((c) => c.dy).reduce((a, b) => a < b ? a : b);
      final busY = (anchor.dy + minChildTop) / 2;
      // vertical from parents' midpoint down to bus
      canvas.drawLine(anchor, Offset(anchor.dx, busY), linePaint);
      // horizontal bus
      final minX =
          childTops.map((c) => c.dx).reduce((a, b) => a < b ? a : b);
      final maxX =
          childTops.map((c) => c.dx).reduce((a, b) => a > b ? a : b);
      canvas.drawLine(Offset(minX, busY), Offset(maxX, busY), linePaint);
      // verticals down to each child
      for (final c in childTops) {
        canvas.drawLine(Offset(c.dx, busY), Offset(c.dx, c.dy), linePaint);
      }
    });

    // spouse links — horizontal gold line between the two cards
    final drawnPairs = <String>{};
    for (final r in relationships) {
      final a = positions[r.personAId];
      final b = positions[r.personBId];
      if (a == null || b == null) continue;
      final pairKey = ([r.personAId, r.personBId]..sort()).join('-');
      if (drawnPairs.contains(pairKey)) continue;
      drawnPairs.add(pairKey);
      final ay = Offset(a.dx + nodeW / 2, a.dy + nodeH / 2);
      final by = Offset(b.dx + nodeW / 2, b.dy + nodeH / 2);
      canvas.drawLine(ay, by, spousePaint);
      final mid = Offset((ay.dx + by.dx) / 2, (ay.dy + by.dy) / 2);
      canvas.drawCircle(mid, 4, Paint()..color = AppTheme.gold);
    }
  }

  @override
  bool shouldRepaint(covariant _CleanEdgePainter oldDelegate) => true;
}

class _NodeCard extends StatelessWidget {
  final Person person;
  final bool highlighted;
  final bool family;
  final bool dimmed;
  const _NodeCard(
      {required this.person,
      this.highlighted = false,
      this.family = false,
      this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.genderColor(person.gender);

    // Determine border + glow per state
    Color borderColor;
    double borderWidth;
    List<BoxShadow> shadow;
    Color bgColor;

    if (highlighted) {
      borderColor = AppTheme.gold;
      borderWidth = 3;
      bgColor = AppTheme.gold.withValues(alpha: 0.12);
      shadow = [
        BoxShadow(
            color: AppTheme.gold.withValues(alpha: 0.55),
            blurRadius: 18,
            spreadRadius: 2),
      ];
    } else if (family) {
      borderColor = AppTheme.primary;
      borderWidth = 3;
      bgColor = AppTheme.primary.withValues(alpha: 0.10);
      shadow = [
        BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 1),
      ];
    } else {
      borderColor = accent.withValues(alpha: 0.6);
      borderWidth = 2;
      bgColor = AppTheme.surface;
      shadow = AppTheme.cardShadow;
    }

    final card = AnimatedScale(
      scale: highlighted ? 1.12 : (family ? 1.05 : 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      child: Container(
        width: _TreeView.nodeW,
        height: _TreeView.nodeH,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: shadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PersonAvatar(person: person, radius: 22),
            const SizedBox(height: 6),
            Text(person.fullName,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: highlighted
                        ? AppTheme.primaryDim
                        : (family ? AppTheme.primary : AppTheme.textDark))),
          ],
        ),
      ),
    );

    final wrapped = GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PersonDetail(personId: person.id!))),
      child: card,
    );

    // Fade out non-family members when a highlight is active
    return AnimatedOpacity(
      opacity: dimmed ? 0.35 : 1.0,
      duration: const Duration(milliseconds: 400),
      child: wrapped,
    );
  }
}
