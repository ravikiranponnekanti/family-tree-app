import 'dart:io';
import 'package:http/http.dart' as http;

/// Uploads images directly to Supabase Storage and returns a public URL.
///
/// SETUP (free, one-time):
/// 1. In your Supabase project, go to Storage and create a bucket named
///    `family-photos`. Toggle it **Public** so the returned URLs render.
/// 2. Project Settings > API: copy the Project URL and the `anon` public key.
/// 3. Paste them below. The anon key is safe to ship in a client app *as long as*
///    your bucket policies are set appropriately. For a family app, a public-read
///    bucket with authenticated insert is reasonable; tighten with RLS policies
///    if you want stricter control.
class StorageService {
  // TODO: fill these in from your Supabase dashboard.
  static const String supabaseUrl = 'https://kjwqputuphuinbubyuyq.supabase.co';
static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtqd3FwdXR1cGh1aW5idWJ5dXlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA3NDgyNDQsImV4cCI6MjA5NjMyNDI0NH0.i-awYpW7Ig_hs2FHU0W_WyAOxFpeHNolmQluPmbeMIc';
static const String bucket = 'family-photos';

  bool get isConfigured =>
      !supabaseUrl.contains('YOUR_PROJECT') &&
      !supabaseAnonKey.contains('YOUR_SUPABASE');

  /// Uploads [file] and returns its public URL.
  Future<String> uploadPhoto(File file) async {
    if (!isConfigured) {
      throw Exception(
          'Supabase not configured. Set supabaseUrl and supabaseAnonKey in storage_service.dart');
    }

    final ext = file.path.split('.').last.toLowerCase();
    final objectName =
        'person_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final uploadUri =
        Uri.parse('$supabaseUrl/storage/v1/object/$bucket/$objectName');

    final bytes = await file.readAsBytes();
    final res = await http.post(
      uploadUri,
      headers: {
        'Authorization': 'Bearer $supabaseAnonKey',
        'apikey': supabaseAnonKey,
        'Content-Type': _contentType(ext),
        'x-upsert': 'true',
      },
      body: bytes,
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      // Public URL for a public bucket.
      return '$supabaseUrl/storage/v1/object/public/$bucket/$objectName';
    }
    throw Exception('Upload failed (${res.statusCode}): ${res.body}');
  }

  String _contentType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }
}
