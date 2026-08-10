import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Thin wrapper around the single-Lambda backend's `{endpoint, token,
/// db_name, ...}` envelope convention. The only place in the app that
/// talks HTTP directly.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Calls [endpoint] with a JSON body. [fields] are merged into the
  /// envelope alongside `endpoint`/`token`/`db_name`.
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> fields) async {
    final body = {
      'endpoint': endpoint,
      'token': AppConfig.staffToken,
      'db_name': AppConfig.dbName,
      ...fields,
    };
    final response = await _client.post(
      Uri.parse(AppConfig.apiBaseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  /// Calls [endpoint] as multipart/form-data. [fields] become form fields;
  /// [files] map a field name to a local file path.
  Future<Map<String, dynamic>> postMultipart(
    String endpoint,
    Map<String, String> fields,
    Map<String, String> files,
  ) async {
    final request = http.MultipartRequest('POST', Uri.parse(AppConfig.apiBaseUrl))
      ..fields['endpoint'] = endpoint
      ..fields['token'] = AppConfig.staffToken
      ..fields['db_name'] = AppConfig.dbName
      ..fields.addAll(fields);

    for (final entry in files.entries) {
      request.files.add(await http.MultipartFile.fromPath(entry.key, entry.value));
    }

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    late final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw ApiException('Unexpected server response (${response.statusCode})');
    }
    if (response.statusCode >= 200 && response.statusCode < 300 && decoded['status'] != false) {
      return decoded;
    }
    final message = decoded['message']?.toString() ?? 'Request failed (${response.statusCode})';
    throw ApiException(message);
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
