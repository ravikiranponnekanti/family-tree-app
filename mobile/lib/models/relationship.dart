class Relationship {
  final int? id;
  final int personAId;
  final int personBId;
  final String? type; // MARRIED, PARTNER, DIVORCED, ENGAGED
  final String? startDate;
  final String? endDate;

  Relationship({
    this.id,
    required this.personAId,
    required this.personBId,
    this.type,
    this.startDate,
    this.endDate,
  });

  factory Relationship.fromJson(Map<String, dynamic> json) {
    return Relationship(
      id: json['id'],
      personAId: json['personAId'],
      personBId: json['personBId'],
      type: json['type'],
      startDate: json['startDate'],
      endDate: json['endDate'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'personAId': personAId,
      'personBId': personBId,
      'type': type,
      'startDate': startDate,
      'endDate': endDate,
    };
  }
}
