class Person {
  final int? id;
  final String firstName;
  final String? lastName;
  final String? gender;
  final String? birthDate;
  final String? deathDate;
  final String? bio;
  final String? photoUrl;
  final int? fatherId;
  final int? motherId;

  Person({
    this.id,
    required this.firstName,
    this.lastName,
    this.gender,
    this.birthDate,
    this.deathDate,
    this.bio,
    this.photoUrl,
    this.fatherId,
    this.motherId,
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'],
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'],
      gender: json['gender'],
      birthDate: json['birthDate'],
      deathDate: json['deathDate'],
      bio: json['bio'],
      photoUrl: json['photoUrl'],
      fatherId: json['fatherId'],
      motherId: json['motherId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'gender': gender,
      'birthDate': birthDate,
      'deathDate': deathDate,
      'bio': bio,
      'photoUrl': photoUrl,
      'fatherId': fatherId,
      'motherId': motherId,
    };
  }

  String get fullName =>
      lastName != null && lastName!.isNotEmpty ? '$firstName $lastName' : firstName;
}
