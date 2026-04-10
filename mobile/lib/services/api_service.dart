import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';

  bool get isUnauthorized => statusCode == 401;
}

class ApiService {
  String? _apiKey;

  ApiService({String? apiKey, bool isSandbox = false}) : _apiKey = apiKey;

  void setApiKey(String? key) => _apiKey = key;
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_apiKey != null) 'Authorization': 'Bearer $_apiKey',
  };

  Future<Map<String, dynamic>> get(String endpoint, {bool? isSandbox}) async {
    final baseUrl = isSandbox == true
        ? ApiConfig.sandboxBaseUrl
        : ApiConfig.baseUrl;
    final url = '$baseUrl$endpoint';

    try {
      final response = await http.get(Uri.parse(url), headers: _headers);
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool? isSandbox,
  }) async {
    final baseUrl = isSandbox == true
        ? ApiConfig.sandboxBaseUrl
        : ApiConfig.baseUrl;
    final url = '$baseUrl$endpoint';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  /// Like [get] but uses [bearerToken] as the Authorization header instead of
  /// the stored API key. Used for session-authenticated endpoints (e.g. get api-key).
  Future<Map<String, dynamic>> getWithBearer(
    String endpoint, {
    required String bearerToken,
    bool? isSandbox,
  }) async {
    final baseUrl = isSandbox == true
        ? ApiConfig.sandboxBaseUrl
        : ApiConfig.baseUrl;
    final url = '$baseUrl$endpoint';

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $bearerToken',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  /// Like [post] but uses [bearerToken] as the Authorization header instead of
  /// the stored API key. Used for session-authenticated endpoints (e.g. regenerate-key).
  Future<Map<String, dynamic>> postWithBearer(
    String endpoint,
    Map<String, dynamic> body, {
    required String bearerToken,
    bool? isSandbox,
  }) async {
    final baseUrl = isSandbox == true
        ? ApiConfig.sandboxBaseUrl
        : ApiConfig.baseUrl;
    final url = '$baseUrl$endpoint';

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $bearerToken',
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  Stream<String> streamPost(
    String endpoint,
    Map<String, dynamic> body, {
    bool? isSandbox,
  }) async* {
    final baseUrl = isSandbox == true
        ? ApiConfig.sandboxBaseUrl
        : ApiConfig.baseUrl;
    final url = '$baseUrl$endpoint';

    try {
      final client = http.Client();
      final request = http.Request('POST', Uri.parse(url));
      request.headers.addAll(_headers);
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';
      request.body = jsonEncode(body);

      final response = await client.send(request);

      await for (final chunk
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (chunk.startsWith('data: ')) {
          final data = chunk.substring(6);
          if (data == '[DONE]') break;
          yield data;
          // Stop after yielding the done event so caller can parse sources
          try {
            final parsed = jsonDecode(data);
            if (parsed['type'] == 'done') break;
          } catch (_) {}
        }
      }
    } catch (e) {
      throw ApiException('Stream error: $e');
    }
  }

  Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> body, {
    bool? isSandbox,
  }) async {
    final baseUrl = isSandbox == true
        ? ApiConfig.sandboxBaseUrl
        : ApiConfig.baseUrl;
    final url = '$baseUrl$endpoint';

    try {
      final response = await http.patch(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool? isSandbox,
  }) async {
    final baseUrl = isSandbox == true
        ? ApiConfig.sandboxBaseUrl
        : ApiConfig.baseUrl;
    final url = '$baseUrl$endpoint';

    try {
      final response = await http.delete(Uri.parse(url), headers: _headers);
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      final decoded = jsonDecode(response.body);
      // If the response is a JSON array, wrap it
      if (decoded is List) return {'data': decoded};
      return decoded as Map<String, dynamic>;
    }

    dynamic errorData;
    try {
      errorData = jsonDecode(response.body);
    } catch (_) {
      errorData = response.body;
    }

    throw ApiException(
      errorData['error']?['message'] ?? 'Request failed',
      statusCode: response.statusCode,
      data: errorData,
    );
  }
}
