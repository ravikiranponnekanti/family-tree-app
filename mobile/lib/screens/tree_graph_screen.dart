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

/// Shifts a node and all its descendants horizontally by [dx].
/// Used to keep a child's own children moving with them when re-centering.
void _shiftSubtree(_Node node, double dx, Map<int, _Node> nodes,
    Map<int, List<int>> spousesOf,
    [Set<int>? visited]) {
  visited ??= {};
  if (visited.contains(node.person.id)) return;
  visited.add(node.person.id!);
  node.x += dx;
  // shift children of this node
  for (final other in nodes.values) {
    final f = other.person.fatherId, m = other.person.motherId;
    if (f == node.person.id || m == node.person.id) {
      _shiftSubtree(other, dx, nodes, spousesOf, visited);
    }
  }
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

    // ---- spouse map: a person can have MULTIPLE spouses ----
    final spousesOf = <int, List<int>>{};
    for (final r in relationships) {
      spousesOf.putIfAbsent(r.personAId, () => []);
      spousesOf.putIfAbsent(r.personBId, () => []);
      if (!spousesOf[r.personAId]!.contains(r.personBId)) {
        spousesOf[r.personAId]!.add(r.personBId);
      }
      if (!spousesOf[r.personBId]!.contains(r.personAId)) {
        spousesOf[r.personBId]!.add(r.personAId);
      }
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
    for (final entry in spousesOf.entries) {
      final a = nodes[entry.key];
      if (a == null) continue;
      for (final spId in entry.value) {
        final b = nodes[spId];
        if (b != null) {
          final d = a.depth > b.depth ? a.depth : b.depth;
          a.depth = d;
          b.depth = d;
        }
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

    // 2) family-cluster tidy layout.
    // - Single person: one slot.
    // - Simple couple (each has only the other as spouse): side by side,
    //   children hang from the midpoint between them.
    // - Multi-spouse person (e.g. a husband with 2 wives): the central person
    //   sits in the MIDDLE with spouses arranged on each side; each spouse's
    //   children hang under that spouse.
    double nextLeaf = 0;
    final positioned = <int>{};

    // helper: children whose parents are exactly {parentA, parentB}
    List<_Node> kidsOfPair(int a, int b) {
      final out = <_Node>[];
      for (final n in nodes.values) {
        final f = n.person.fatherId, m = n.person.motherId;
        final pair = {if (f != null) f, if (m != null) m};
        if (pair.contains(a) && pair.contains(b)) out.add(n);
      }
      out.sort((x, y) => x.person.id!.compareTo(y.person.id!));
      return out;
    }

    // place a leaf single person
    double placeSinglePerson(_Node n) {
      n.x = nextLeaf;
      nextLeaf += nodeW + hGap;
      return n.x;
    }

    // forward declaration via local function variable
    late double Function(_Node) placeUnit;

    // place all children of a given parent-pair, return their center x
    double? placeKidsOfPair(int a, int b) {
      final kids = kidsOfPair(a, b);
      if (kids.isEmpty) return null;
      final centers = <double>[];
      for (final k in kids) {
        if (!positioned.contains(k.person.id)) {
          centers.add(placeUnit(k));
        } else {
          centers.add(k.x + nodeW / 2);
        }
      }
      return (centers.reduce((a, b) => a < b ? a : b) +
              centers.reduce((a, b) => a > b ? a : b)) /
          2;
    }

    placeUnit = (n) {
      if (positioned.contains(n.person.id)) return n.x + nodeW / 2;

      final spouses = (spousesOf[n.person.id] ?? [])
          .where((s) => nodes.containsKey(s) && !positioned.contains(s))
          .toList();

      // full spouse list (regardless of placement) — used to detect that
      // this person is a multi-spouse center even if a spouse slipped through
      final allSpouses = (spousesOf[n.person.id] ?? [])
          .where((s) => nodes.containsKey(s))
          .toList();

      // If this person's spouse is themselves a multi-spouse center
      // (e.g. we reached a wife before the husband who has 2 wives),
      // delegate to placing that center's full cluster first, so the
      // husband never collapses onto one wife's position.
      if (spouses.length == 1) {
        final spId = spouses.first;
        final spousePartners = (spousesOf[spId] ?? [])
            .where((s) => nodes.containsKey(s))
            .toList();
        if (spousePartners.length >= 2 && !positioned.contains(spId)) {
          placeUnit(nodes[spId]!); // place the husband's whole cluster
          return n.x + nodeW / 2;  // this person was positioned in that cluster
        }
      }

      // ----- MULTI-SPOUSE CLUSTER (central person with 2+ spouses) -----
      if (allSpouses.length >= 2) {
        positioned.add(n.person.id!);
        // arrange: [spouse0] [center] [spouse1] [spouse2...]
        // We'll place left spouse, then center, then right spouses,
        // each spouse's children under that spouse.
        final leftSpouse = nodes[allSpouses.first]!;
        final rightSpouses =
            allSpouses.skip(1).map((s) => nodes[s]!).toList();

        // place left spouse's children, then left spouse over them
        positioned.add(leftSpouse.person.id!);
        final leftKidMid =
            placeKidsOfPair(n.person.id!, leftSpouse.person.id!);
        if (leftKidMid != null) {
          leftSpouse.x = leftKidMid - nodeW / 2;
        } else {
          leftSpouse.x = nextLeaf;
          nextLeaf += nodeW + hGap;
        }

        // center person goes right after left spouse
        n.x = leftSpouse.x + nodeW + coupleGap;
        if (n.x < nextLeaf) n.x = nextLeaf;
        nextLeaf = n.x + nodeW + coupleGap;

        // right spouses + their kids
        for (final rs in rightSpouses) {
          positioned.add(rs.person.id!);
          final startLeaf = nextLeaf;
          final rsKidMid = placeKidsOfPair(n.person.id!, rs.person.id!);
          if (rsKidMid != null) {
            rs.x = rsKidMid - nodeW / 2;
            if (rs.x < n.x + nodeW + coupleGap) {
              rs.x = n.x + nodeW + coupleGap;
            }
          } else {
            rs.x = startLeaf;
          }
          nextLeaf = rs.x + nodeW + hGap;
        }

        // Re-center each spouse's children under the midpoint between the
        // central person and that spouse, so a single child sits BETWEEN
        // their mother and father (not off to one side).
        void recenterKids(_Node spouseNode) {
          final kids = kidsOfPair(n.person.id!, spouseNode.person.id!);
          if (kids.isEmpty) return;
          final parentMid =
              ((n.x + nodeW / 2) + (spouseNode.x + nodeW / 2)) / 2;
          // current center of the kids
          final curCenters =
              kids.map((k) => k.x + nodeW / 2).toList();
          final curMid = (curCenters.reduce((a, b) => a < b ? a : b) +
                  curCenters.reduce((a, b) => a > b ? a : b)) /
              2;
          final shift = parentMid - curMid;
          for (final k in kids) {
            _shiftSubtree(k, shift, nodes, spousesOf);
          }
        }

        recenterKids(leftSpouse);
        for (final rs in rightSpouses) {
          recenterKids(rs);
        }
        return n.x + nodeW / 2;
      }

      // ----- SIMPLE COUPLE (one spouse) -----
      if (spouses.length == 1) {
        final spouse = nodes[spouses.first]!;
        positioned.add(n.person.id!);
        positioned.add(spouse.person.id!);
        final kidMid = placeKidsOfPair(n.person.id!, spouse.person.id!);
        if (kidMid != null) {
          // husband-left, wife-right around children's midpoint
          n.x = kidMid - nodeW - coupleGap / 2;
          spouse.x = kidMid + coupleGap / 2;
          return kidMid;
        } else {
          n.x = nextLeaf;
          spouse.x = nextLeaf + nodeW + coupleGap;
          nextLeaf += 2 * nodeW + coupleGap + hGap;
          return (n.x + spouse.x) / 2 + nodeW / 2;
        }
      }

      // ----- SINGLE PERSON (no spouse): place over own children if any -----
      positioned.add(n.person.id!);
      final ownKids = childrenOf[n.person.id] ?? [];
      if (ownKids.isEmpty) {
        return placeSinglePerson(n) + nodeW / 2;
      } else {
        final centers = <double>[];
        for (final k in ownKids) {
          if (!positioned.contains(k.person.id)) {
            centers.add(placeUnit(k));
          } else {
            centers.add(k.x + nodeW / 2);
          }
        }
        final mid = (centers.reduce((a, b) => a < b ? a : b) +
                centers.reduce((a, b) => a > b ? a : b)) /
            2;
        n.x = mid - nodeW / 2;
        return mid;
      }
    };

    // Place starting from top-most generation (roots).
    final roots = nodes.values.where((n) => n.depth == 0).toList()
      ..sort((a, b) => a.person.id!.compareTo(b.person.id!));
    for (final r in roots) {
      placeUnit(r);
    }
    // place anything left (orphans / deeper unplaced)
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
