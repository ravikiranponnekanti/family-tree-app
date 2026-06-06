import 'package:flutter/material.dart';
import '../models/person.dart';
import '../services/api_service.dart';
import 'person_detail.dart';

/// Renders the family as a layered graph: each generation on its own row,
/// with lines drawn from parents down to children. Pan + zoom via InteractiveViewer.
class TreeGraphScreen extends StatefulWidget {
  const TreeGraphScreen({super.key});

  @override
  State<TreeGraphScreen> createState() => _TreeGraphScreenState();
}

class _TreeGraphScreenState extends State<TreeGraphScreen> {
  final _api = ApiService();
  late Future<List<Person>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getPersons();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family Tree View')),
      body: FutureBuilder<List<Person>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final persons = snapshot.data ?? [];
          if (persons.isEmpty) {
            return const Center(child: Text('No people to display yet.'));
          }
          return _TreeCanvas(persons: persons);
        },
      ),
    );
  }
}

class _TreeCanvas extends StatelessWidget {
  final List<Person> persons;
  const _TreeCanvas({required this.persons});

  // Assign a generation (depth) to each person: roots (no known parents) = 0.
  Map<int, int> _computeGenerations() {
    final byId = {for (final p in persons) p.id!: p};
    final gen = <int, int>{};

    int depthOf(int id, Set<int> visiting) {
      if (gen.containsKey(id)) return gen[id]!;
      if (visiting.contains(id)) return 0; // cycle guard
      visiting.add(id);
      final p = byId[id];
      int d = 0;
      if (p != null) {
        final parents = [p.fatherId, p.motherId].whereType<int>();
        for (final parentId in parents) {
          if (byId.containsKey(parentId)) {
            d = (depthOf(parentId, visiting) + 1) > d
                ? depthOf(parentId, visiting) + 1
                : d;
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

    // Group people by generation row.
    final rows = <int, List<Person>>{};
    for (final p in persons) {
      rows.putIfAbsent(gen[p.id!]!, () => []).add(p);
    }
    final maxGen = rows.keys.isEmpty ? 0 : rows.keys.reduce((a, b) => a > b ? a : b);

    const nodeW = 130.0;
    const nodeH = 64.0;
    const hGap = 24.0;
    const vGap = 90.0;

    // Compute node positions.
    final positions = <int, Offset>{};
    double canvasWidth = 0;
    for (int g = 0; g <= maxGen; g++) {
      final row = rows[g] ?? [];
      final rowWidth = row.length * nodeW + (row.length - 1) * hGap;
      canvasWidth = rowWidth > canvasWidth ? rowWidth : canvasWidth;
    }
    canvasWidth = canvasWidth < 320 ? 320 : canvasWidth + 40;

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
      boundaryMargin: const EdgeInsets.all(200),
      child: SizedBox(
        width: canvasWidth,
        height: canvasHeight,
        child: Stack(
          children: [
            // Edges
            CustomPaint(
              size: Size(canvasWidth, canvasHeight),
              painter: _EdgePainter(
                persons: persons,
                positions: positions,
                nodeW: nodeW,
                nodeH: nodeH,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            // Nodes
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
  final Map<int, Offset> positions;
  final double nodeW;
  final double nodeH;
  final Color color;

  _EdgePainter({
    required this.persons,
    required this.positions,
    required this.nodeW,
    required this.nodeH,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final p in persons) {
      final childPos = positions[p.id!];
      if (childPos == null) continue;
      final childTop = Offset(childPos.dx + nodeW / 2, childPos.dy);

      for (final parentId in [p.fatherId, p.motherId].whereType<int>()) {
        final parentPos = positions[parentId];
        if (parentPos == null) continue;
        final parentBottom =
            Offset(parentPos.dx + nodeW / 2, parentPos.dy + nodeH);

        // Elbow connector: down from parent, across, down to child.
        final midY = (parentBottom.dy + childTop.dy) / 2;
        final path = Path()
          ..moveTo(parentBottom.dx, parentBottom.dy)
          ..lineTo(parentBottom.dx, midY)
          ..lineTo(childTop.dx, midY)
          ..lineTo(childTop.dx, childTop.dy);
        canvas.drawPath(path, paint);
      }
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

  Color _genderColor(BuildContext context) {
    switch (person.gender) {
      case 'MALE':
        return Colors.blue.shade100;
      case 'FEMALE':
        return Colors.pink.shade100;
      default:
        return Theme.of(context).colorScheme.surfaceContainerHighest;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PersonDetail(personId: person.id!),
        ),
      ),
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: _genderColor(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(person.fullName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            if (person.birthDate != null)
              Text(person.birthDate!,
                  style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
