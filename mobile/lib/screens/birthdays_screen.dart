import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'person_detail.dart';

class BirthdaysScreen extends StatefulWidget {
  const BirthdaysScreen({super.key});

  @override
  State<BirthdaysScreen> createState() => _BirthdaysScreenState();
}

class _BirthdaysScreenState extends State<BirthdaysScreen> {
  final _api = ApiService();
  late Future<List<Map<String, dynamic>>> _future;

  static const _months = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _future = _api.getBirthdays();
  }

  @override
  Widget build(BuildContext context) {
    final monthName = _months[DateTime.now().month];
    return Scaffold(
      appBar: AppBar(title: Text('Birthdays in $monthName')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary));
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: AppTheme.textMuted)));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cake_outlined,
                      size: 72,
                      color: AppTheme.primary.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text('No birthdays in $monthName',
                      style: const TextStyle(
                          color: AppTheme.textLight, fontSize: 18)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) => _card(items[i]),
          );
        },
      ),
    );
  }

  Widget _card(Map<String, dynamic> b) {
    final day = b['day'] as int;
    final name = b['name'] as String;
    final age = b['turningAge'];
    final photoUrl = b['photoUrl'] as String?;
    final id = b['id'] as int;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => PersonDetail(personId: id))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: AppTheme.tealGold,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$day',
                        style: const TextStyle(
                            color: Color(0xFF06201D),
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const Text('day',
                        style: TextStyle(
                            color: Color(0xFF06201D), fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🎂 ', style: TextStyle(fontSize: 16)),
                        Expanded(
                          child: Text(name,
                              style: const TextStyle(
                                  color: AppTheme.textLight,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    if (age != null)
                      Text('Turning $age',
                          style: const TextStyle(
                              color: AppTheme.gold, fontSize: 13)),
                  ],
                ),
              ),
              if (photoUrl != null)
                CircleAvatar(
                    radius: 22, backgroundImage: NetworkImage(photoUrl)),
            ],
          ),
        ),
      ),
    );
  }
}
