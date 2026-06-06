import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/person.dart';

class ApiService {
  // IMPORTANT:
  //  - Android emulator: use http://10.0.2.2:8080
  //  - iOS simulator / web: use http://localhost:8080
  //  - Physical device: use your computer's LAN IP, e.g. http://192.168.1.20:8080
  //  - Deployed backend: use your Render/Railway URL, e.g. https://family-tree.onrender.com
  static const String baseUrl = 'http://10.0.2.2:8080/api';

  // Set after login/register; attached to every authenticated request.
  static String? authToken;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

  Future<List<Person>> getPersons() async {
    final res = await http.get(Uri.parse('$baseUrl/persons'), headers: _headers);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Person.fromJson(e)).toList();
    }
    throw Exception('Failed to load persons (${res.statusCode})');
  }

  Future<Person> getPerson(int id) async {
    final res = await http.get(Uri.parse('$baseUrl/persons/$id'), headers: _headers);
    if (res.statusCode == 200) {
      return Person.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load person $id');
  }

  Future<List<Person>> getChildren(int id) async {
    final res =
        await http.get(Uri.parse('$baseUrl/persons/$id/children'), headers: _headers);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Person.fromJson(e)).toList();
    }
    throw Exception('Failed to load children');
  }

  Future<Person> createPerson(Person person) async {
    final res = await http.post(
      Uri.parse('$baseUrl/persons'),
      headers: _headers,
      body: jsonEncode(person.toJson()),
    );
    if (res.statusCode == 201 || res.statusCode == 200) {
      return Person.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to create person: ${res.body}');
  }

  Future<Person> updatePerson(int id, Person person) async {
    final res = await http.put(
      Uri.parse('$baseUrl/persons/$id'),
      headers: _headers,
      body: jsonEncode(person.toJson()),
    );
    if (res.statusCode == 200) {
      return Person.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to update person: ${res.body}');
  }

  Future<void> deletePerson(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/persons/$id'), headers: _headers);
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception('Failed to delete person');
    }
  }
}
