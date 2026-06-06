import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class AuthService {
  static const String baseUrl = ApiService.baseUrl;

  /// Returns the username on success; throws with a readable message on failure.
  Future<String> login(String username, String password) async {
    return _authRequest('/auth/login', username, password);
  }

  Future<String> register(String username, String password) async {
    return _authRequest('/auth/register', username, password);
  }

  Future<String> _authRequest(String path, String username, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode == 200 || res.statusCode == 201) {
      ApiService.authToken = body['token'];
      return body['username'];
    }
    throw Exception(body['message'] ?? 'Authentication failed');
  }

  void logout() {
    ApiService.authToken = null;
  }
}
