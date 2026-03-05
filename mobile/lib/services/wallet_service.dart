import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';
import 'package:solana/base58.dart';
import 'provider.dart';

/// Result of a successful wallet connect + sign.
class WalletSignResult {
  final String walletAddress;
  final String publicKeyBase58;
  final String signatureBase58;

  WalletSignResult({
    required this.walletAddress,
    required this.publicKeyBase58,
    required this.signatureBase58,
  });
}

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  String? _connectedAddress;
  String? _authToken;
  Uint8List? _publicKeyBytes;

  String? get connectedAddress => _connectedAddress;
  bool get isConnected => _connectedAddress != null;

  // App identity shown in the wallet connect/sign dialogs.
  static const _identityName = 'Daemon Protocol';
  static const _identityUri  = 'https://daemonprotocol.com';
  static const _iconUri      = 'favicon.ico';   // relative to identityUri, per MWA spec
  static const _cluster      = 'mainnet-beta';

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Check whether any MWA-compatible wallet is installed on this device.
  Future<bool> isMwaAvailable() => LocalAssociationScenario.isAvailable();

  /// Connect wallet via MWA — shows the wallet's connect/authorize dialog.
  /// Returns the wallet address (base58) on success, null on cancel/failure.
  /// The auth token and public key are stored for the subsequent [signMessage].
  Future<String?> connectWallet() async {
    debugPrint('[Wallet] connectWallet — starting MWA session');
    try {
      final session = await LocalAssociationScenario.create();

      // IMPORTANT: do NOT await — this future only resolves when the session
      // ends. Awaiting it here would deadlock before calling session.start().
      session.startActivityForResult(null).ignore();

      final client = await session.start();

      final result = await client.authorize(
        identityUri:  Uri.parse(_identityUri),
        iconUri:      Uri.parse(_iconUri),
        identityName: _identityName,
        cluster:      _cluster,
      );

      await session.close();

      if (result == null) {
        debugPrint('[Wallet] User rejected connect');
        return null;
      }

      _authToken      = result.authToken;
      _publicKeyBytes = result.publicKey;
      _connectedAddress = base58encode(result.publicKey);

      debugPrint('[Wallet] Connected: $_connectedAddress');

      await SharedPreferences.getInstance().then((prefs) {
        prefs.setString('wallet_address', _connectedAddress!);
      });

      return _connectedAddress;
    } catch (e, st) {
      debugPrint('[Wallet] connectWallet error: $e\n$st');
      return null;
    }
  }

  /// Fetch a one-time sign challenge (nonce message) from the backend.
  /// Returns the full message string to pass to [signMessage], or null on error.
  Future<String?> fetchNonce(String walletAddress) async {
    try {
      final nonce = await apiProvider.authService.getWalletNonce(walletAddress);
      return nonce.message;
    } catch (e) {
      debugPrint('[Wallet] fetchNonce error: $e');
      return null;
    }
  }

  /// Sign [nonceMessage] using an existing connected session.
  /// Must be called after a successful [connectWallet].
  /// Returns null on cancel / no session / failure.
  Future<WalletSignResult?> signMessage(String nonceMessage) async {
    final authToken = _authToken;
    final pubKeyBytes = _publicKeyBytes;
    final address = _connectedAddress;

    if (authToken == null || pubKeyBytes == null || address == null) {
      debugPrint('[Wallet] signMessage: no active session — call connectWallet first');
      return null;
    }

    debugPrint('[Wallet] signMessage — starting MWA sign session');
    try {
      final session = await LocalAssociationScenario.create();

      // Same rule: do NOT await
      session.startActivityForResult(null).ignore();

      final client = await session.start();

      // Reauthorize using the stored auth token from the connect step.
      final reauth = await client.reauthorize(
        identityUri:  Uri.parse(_identityUri),
        iconUri:      Uri.parse(_iconUri),
        identityName: _identityName,
        authToken:    authToken,
      );

      if (reauth == null) {
        debugPrint('[Wallet] Reauthorize rejected');
        await session.close();
        return null;
      }

      // signMessages expects raw UTF-8 bytes, NOT base64 or base58.
      final messageBytes = Uint8List.fromList(utf8.encode(nonceMessage));

      final signResult = await client.signMessages(
        messages:  [messageBytes],
        addresses: [pubKeyBytes],
      );

      await session.close();

      if (signResult.signedMessages.isEmpty) {
        debugPrint('[Wallet] No signed messages returned');
        return null;
      }

      final signed = signResult.signedMessages.first;
      if (signed.signatures.isEmpty) {
        debugPrint('[Wallet] No signatures in signed message');
        return null;
      }

      final signatureBytes = signed.signatures.first;
      final signatureB58   = base58encode(signatureBytes);
      final pubKeyB58      = base58encode(pubKeyBytes);

      debugPrint('[Wallet] Signed — pubkey: $pubKeyB58, sig len: ${signatureBytes.length}');

      return WalletSignResult(
        walletAddress:    address,
        publicKeyBase58:  pubKeyB58,
        signatureBase58:  signatureB58,
      );
    } catch (e, st) {
      debugPrint('[Wallet] signMessage error: $e\n$st');
      return null;
    }
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> loadSavedWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('wallet_address');
    if (saved != null) _connectedAddress = saved;
  }

  Future<void> setAddress(String address) async {
    _connectedAddress = address;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wallet_address', address);
  }

  Future<void> disconnectWallet() async {
    _connectedAddress = null;
    _authToken        = null;
    _publicKeyBytes   = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('wallet_address');
  }

  // ── Base58 ─────────────────────────────────────────────────────────────────
  // Removed — now using solana package's base58encode directly.
}
