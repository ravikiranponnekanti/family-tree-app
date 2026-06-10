import 'package:flutter/material.dart';
import '../models/person.dart';
import '../theme/app_theme.dart';

class PersonAvatar extends StatelessWidget {
  final Person person;
  final double radius;

  const PersonAvatar({super.key, required this.person, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = person.photoUrl != null && person.photoUrl!.isNotEmpty;
    final initials = _initials();

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.genderColor(person.gender),
      backgroundImage: hasPhoto ? NetworkImage(person.photoUrl!) : null,
      child: hasPhoto
          ? null
          : Text(
              initials,
              style: TextStyle(
                fontSize: radius * 0.7,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryDark,
              ),
            ),
    );
  }

  String _initials() {
    final f = person.firstName.isNotEmpty ? person.firstName[0] : '';
    final l = (person.lastName != null && person.lastName!.isNotEmpty)
        ? person.lastName![0]
        : '';
    final result = (f + l).toUpperCase();
    return result.isEmpty ? '?' : result;
  }
}
