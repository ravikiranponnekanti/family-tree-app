import 'package:flutter/material.dart';
import '../models/person.dart';
import '../models/relationship.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/person_avatar.dart';
import 'person_detail.dart';

class TreeGraphScreen extends StatefulWidget {
  const TreeGraphScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family Tree')),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final persons = snapshot.data![0] as List<Person>;
          final rels = snapshot.data![1] as List<Relationship>;
          if (persons.isEmpty) {
            return const Center(child: Text('No people to display yet.'));
          }
          return _TreeCanvas(persons: persons, relationships: rels);
        },
      ),
    );
  }
}

class _TreeCanvas extends StatelessWidget {
  final List<Person> persons;
  final List<Relationship> relationships;
  const _TreeCanvas({required this.persons, required this.relationships});

  Map<int, int> _computeGenerations() {
    final byId = {for (final p in persons) p.id!: p};
    final gen = <int, int>{};
    int depthOf(int id, Set<int> visiting) {
      if (gen.containsKey(id)) return gen[id]!;
      if (visiting.contains(id)) return 0;
      visiting.add(id);
      final p = byId[id];
      int d = 0;
      if (p != null) {
        for (final parentId in [p.fatherId, p.motherId].whereType<int>()) {
          if (byId.containsKey(parentId)) {
            final pd = depthOf(parentId, visiting) + 1;
            if (pd > d) d = pd;
          }
        }
      }
      visiting.remove(id);
      gen[id] = d;
      return d;
    }

    for (final p in persons) {
      depthOf(p.id!, {});
    }
    return gen;
  }

  @override
  Widget build(BuildContext context) {
    final gen = _computeGenerations();
    final rows = <int, List<Person>>{};
    for (final p in persons) {
      rows.putIfAbsent(gen[p.id!]!, () => []).add(p);
    }
    final maxGen =
        rows.keys.isEmpty ? 0 : rows.keys.reduce((a, b) => a > b ? a : b);

    const nodeW = 150.0;
    const nodeH = 70.0;
    const hGap = 28.0;
    const vGap = 90.0;

    final positions = <int, Offset>{};
    double canvasWidth = 0;
    for (int g = 0; g <= maxGen; g++) {
      final row = rows[g] ?? [];
      final rowWidth = row.length * nodeW + (row.length - 1) * hGap;
      if (rowWidth > canvasWidth) canvasWidth = rowWidth;
    }
    canvasWidth = canvasWidth < 340 ? 340 : canvasWidth + 40;

    for (int g = 0; g <= maxGen; g++) {
      final row = rows[g] ?? [];
      final rowWidth = row.length * nodeW + (row.length - 1) * hGap;
      double startX = (canvasWidth - rowWidth) / 2;
      for (int i = 0; i < row.length; i++) {
        final x = startX + i * (nodeW + hGap);
        final y = 20 + g * (nodeH + vGap);
        positions[row[i].id!] = Offset(x, y);
      }
    }

    final canvasHeight = 40 + (maxGen + 1) * (nodeH + vGap);

    return InteractiveViewer(
      constrained: false,
      minScale: 0.3,
      maxScale: 2.5,
      boundaryMargin: const EdgeInsets.all(300),
      child: Container(
        width: canvasWidth,
        height: canvasHeight,
        color: AppTheme.bg,
        child: Stack(
          children: [
            CustomPaint(
              size: Size(canvasWidth, canvasHeight),
              painter: _EdgePainter(
                persons: persons,
                relationships: relationships,
                positions: positions,
                nodeW: nodeW,
                nodeH: nodeH,
              ),
            ),
            ...persons.map((p) {
              final pos = positions[p.id!]!;
              return Positioned(
                left: pos.dx,
                top: pos.dy,
                child: _NodeCard(person: p, width: nodeW, height: nodeH),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  final List<Person> persons;
  final List<Relationship> relationships;
  final Map<int, Offset> positions;
  final double nodeW;
  final double nodeH;

  _EdgePainter({
    required this.persons,
    required this.relationships,
    required this.positions,
    required this.nodeW,
    required this.nodeH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final parentPaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final spousePaint = Paint()
      ..color = AppTheme.accent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // Parent -> child elbow lines
    for (final p in persons) {
      final childPos = positions[p.id!];
      if (childPos == null) continue;
      final childTop = Offset(childPos.dx + nodeW / 2, childPos.dy);
      for (final parentId in [p.fatherId, p.motherId].whereType<int>()) {
        final parentPos = positions[parentId];
        if (parentPos == null) continue;
        final parentBottom =
            Offset(parentPos.dx + nodeW / 2, parentPos.dy + nodeH);
        final midY = (parentBottom.dy + childTop.dy) / 2;
        final path = Path()
          ..moveTo(parentBottom.dx, parentBottom.dy)
          ..lineTo(parentBottom.dx, midY)
          ..lineTo(childTop.dx, midY)
          ..lineTo(childTop.dx, childTop.dy);
        canvas.drawPath(path, parentPaint);
      }
    }

    // Spouse links (horizontal dashed-style line between partners)
    for (final r in relationships) {
      final a = positions[r.personAId];
      final b = positions[r.personBId];
      if (a == null || b == null) continue;
      final ay = Offset(a.dx + nodeW / 2, a.dy + nodeH / 2);
      final by = Offset(b.dx + nodeW / 2, b.dy + nodeH / 2);
      canvas.drawLine(ay, by, spousePaint);
      // small heart marker at midpoint
      final mid = Offset((ay.dx + by.dx) / 2, (ay.dy + by.dy) / 2);
      canvas.drawCircle(mid, 4, Paint()..color = AppTheme.accent);
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) => true;
}

class _NodeCard extends StatelessWidget {
  final Person person;
  final double width;
  final double height;
  const _NodeCard(
      {required this.person, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PersonDetail(personId: person.id!)),
      ),
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppTheme.genderColor(person.gender), width: 3),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            PersonAvatar(person: person, radius: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(person.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.textDark)),
                  if (person.birthDate != null)
                    Text(person.birthDate!,
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
