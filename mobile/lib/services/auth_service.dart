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
    late http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 70));
    } catch (e) {
      throw Exception(
          'Could not reach the server. Check your connection and try again.');
    }

    // Empty body = server reachable but returned nothing (often a cold start
    // that timed out, or a server error). Give a clear, non-cryptic message.
    if (res.body.isEmpty) {
      if (res.statusCode == 200 || res.statusCode == 201) {
        throw Exception('Server returned an empty response. Please try again.');
      }
      throw Exception(
          'Login failed (status ${res.statusCode}). Please try again in a moment.');
    }

    dynamic body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      // Not JSON — surface a readable message instead of a format error.
      throw Exception('Unexpected server response. Please try again.');
    }

    if (res.statusCode == 200 || res.statusCode == 201) {
      ApiService.authToken = body['token'];
      return body['username'];
    }
    throw Exception(body is Map && body['message'] != null
        ? body['message']
        : 'Authentication failed');
  }

  void logout() {
    ApiService.authToken = null;
  }
}
