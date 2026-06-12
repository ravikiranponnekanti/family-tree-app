import 'package:flutter/material.dart';
import '../models/person.dart';
import '../theme/app_theme.dart';

class PersonAvatar extends StatelessWidget {
  final Person person;
  final double radius;
  final bool ring;

  const PersonAvatar(
      {super.key, required this.person, this.radius = 24, this.ring = true});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = person.photoUrl != null && person.photoUrl!.isNotEmpty;
    final accent = AppTheme.genderColor(person.gender);

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.surfaceHi,
      backgroundImage: hasPhoto ? NetworkImage(person.photoUrl!) : null,
      child: hasPhoto
          ? null
          : Text(_initials(),
              style: TextStyle(
                  fontSize: radius * 0.7,
                  fontWeight: FontWeight.bold,
                  color: accent)),
    );

    if (!ring) return avatar;

    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [accent, accent.withValues(alpha: 0.4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: avatar,
    );
  }

  String _initials() {
    final f = person.firstName.isNotEmpty ? person.firstName[0] : '';
    final l = (person.lastName != null && person.lastName!.isNotEmpty)
        ? person.lastName![0]
        : '';
    final r = (f + l).toUpperCase();
    return r.isEmpty ? '?' : r;
  }
}
