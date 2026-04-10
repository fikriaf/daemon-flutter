import 'package:flutter/foundation.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _api;

  AuthService(this._api);

  Future<AuthResult> loginWithEmail(
    String email,
    String password, {
    String? walletAddress,
  }) async {
    final body = <String, dynamic>{'email': email, 'password': password};
    if (walletAddress != null && walletAddress.isNotEmpty) {
      body['wallet_address'] = walletAddress;
    }
    final data = await _api.post('/v1/auth/login', body);
    return AuthResult.fromJson(data);
  }

  /// Step 1: Get a one-time nonce to sign
  Future<WalletNonce> getWalletNonce(String walletAddress) async {
    final data = await _api.get('/v1/auth/wallet/nonce?wallet=$walletAddress');
    return WalletNonce.fromJson(data);
  }

  /// Step 2: Login with wallet — requires nonce signature from MWA
  Future<AuthResult> loginWithWallet({
    required String walletAddress,
    required String publicKey,
    required String signature,
  }) async {
    debugPrint(
      '[Auth] loginWithWallet POST body — wallet_address: "$walletAddress" (len ${walletAddress.length}), public_key: "$publicKey" (len ${publicKey.length}), signature: "${signature.substring(0, signature.length.clamp(0, 12))}..." (len ${signature.length})',
    );
    final data = await _api.post('/v1/auth/login', {
      'wallet_address': walletAddress,
      'public_key': publicKey,
      'signature': signature,
    });
    return AuthResult.fromJson(data);
  }

  Future<UserRegisterResult> register(
    String email,
    String password, {
    String? walletAddress,
  }) async {
    final body = <String, dynamic>{'email': email, 'password': password};
    if (walletAddress != null && walletAddress.isNotEmpty) {
      body['wallet_address'] = walletAddress;
    }
    final data = await _api.post('/v1/auth/register', body);
    return UserRegisterResult.fromJson(data);
  }

  /// Verify email with token from deep link — returns full auth payload
  Future<Map<String, dynamic>> verifyEmail(String token) async {
    final data = await _api.post('/v1/auth/verify-email', {'token': token});
    return data;
  }

  /// Retrieve the current API key using a valid session token.
  /// Returns the API key string.
  /// Throws [ApiException] with specific error codes:
  /// - `no_agent`: User has no agent yet
  /// - `no_api_key`: No active API key
  /// - `key_not_recoverable`: Key created before key_encrypted, needs regenerate
  /// - `decrypt_failed`: Decryption failed
  Future<String> getApiKey(String sessionToken) async {
    final data = await _api.getWithBearer(
      '/v1/auth/api-key',
      bearerToken: sessionToken,
    );
    final key = data['api_key'] as String?;
    if (key == null || key.isEmpty) {
      throw ApiException('Server did not return an API key');
    }
    return key;
  }

  /// Deactivates the existing API key and generates a fresh one.
  /// [sessionToken] must be a valid, unexpired session token.
  /// Returns the new plaintext API key on success.
  Future<String> regenerateApiKey(String sessionToken) async {
    // Temporarily set Authorization header by creating a one-shot ApiService
    // call with the session token (not an API key) as the Bearer token.
    final data = await _api.postWithBearer(
      '/v1/auth/regenerate-key',
      {},
      bearerToken: sessionToken,
    );
    final key = data['api_key'] as String?;
    if (key == null || key.isEmpty) {
      throw Exception('Server did not return a new API key');
    }
    return key;
  }
}

class WalletNonce {
  final String nonce;
  final String message;
  final int expiresIn;

  WalletNonce({
    required this.nonce,
    required this.message,
    required this.expiresIn,
  });

  factory WalletNonce.fromJson(Map<String, dynamic> json) {
    return WalletNonce(
      nonce: json['nonce'] ?? '',
      message: json['message'] ?? '',
      expiresIn: json['expires_in'] ?? 300,
    );
  }
}

class AuthResult {
  final String userId;
  final String? email;
  final String? sessionToken;
  final String? apiKey;
  final List<AgentSummary> agents;
  final AgentSummary? agent;

  AuthResult({
    required this.userId,
    this.email,
    this.sessionToken,
    this.apiKey,
    this.agents = const [],
    this.agent,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      userId: json['user_id'] ?? '',
      email: json['email'],
      sessionToken: json['session_token'],
      apiKey: json['api_key'],
      agents:
          (json['agents'] as List?)
              ?.map((e) => AgentSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      agent: json['agent'] != null
          ? AgentSummary.fromJson(json['agent'] as Map<String, dynamic>)
          : null,
    );
  }
}

class UserRegisterResult {
  final String userId;
  final String email;
  final String? sessionToken;
  final String? apiKey;

  UserRegisterResult({
    required this.userId,
    required this.email,
    this.sessionToken,
    this.apiKey,
  });

  factory UserRegisterResult.fromJson(Map<String, dynamic> json) {
    return UserRegisterResult(
      userId: json['user_id'] ?? '',
      email: json['email'] ?? '',
      sessionToken: json['session_token'],
      apiKey: json['api_key'],
    );
  }
}

class AgentSummary {
  final String id;
  final String name;
  final String? defaultModelId;
  final bool isActive;
  final String? walletAddress;

  AgentSummary({
    required this.id,
    required this.name,
    this.defaultModelId,
    required this.isActive,
    this.walletAddress,
  });

  factory AgentSummary.fromJson(Map<String, dynamic> json) {
    return AgentSummary(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      defaultModelId: json['default_model_id'],
      isActive: json['is_active'] ?? true,
      walletAddress: json['wallet_address'],
    );
  }
}
