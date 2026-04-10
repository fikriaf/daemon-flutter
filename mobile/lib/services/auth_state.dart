import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'provider.dart';

class AuthState {
  final bool isLoggedIn;
  final bool isLoading;
  final String? walletAddress;
  final String? email;
  final String? userId;
  final String? error;

  const AuthState({
    this.isLoggedIn = false,
    this.isLoading = false,
    this.walletAddress,
    this.email,
    this.userId,
    this.error,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    bool? isLoading,
    String? walletAddress,
    String? email,
    String? userId,
    String? error,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isLoading: isLoading ?? this.isLoading,
      walletAddress: walletAddress ?? this.walletAddress,
      email: email ?? this.email,
      userId: userId ?? this.userId,
      error: error,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _loadFromStorage();
    return const AuthState();
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final walletAddress = prefs.getString('wallet_address');
    final email = prefs.getString('user_email');
    final userId = prefs.getString('user_id');
    final apiKey = prefs.getString('api_key');

    if (walletAddress != null && email != null && apiKey != null) {
      apiProvider.setApiKey(apiKey);
      state = state.copyWith(
        isLoggedIn: true,
        walletAddress: walletAddress,
        email: email,
        userId: userId,
      );
    }
  }

  Future<void> loginWithWalletAndEmail({
    required String walletAddress,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final authService = apiProvider.authService;

      // Do NOT pass walletAddress here — the /v1/auth/login endpoint requires
      // signature + public_key when wallet_address is present (wallet-only flow).
      // Email+password login stands alone; wallet association happens server-side.
      final result = await authService.loginWithEmail(email, password);

      final prefs = await SharedPreferences.getInstance();

      final apiKey = result.apiKey;
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('No API key received. Please contact support.');
      }

      await prefs.setString('wallet_address', walletAddress);
      await prefs.setString('user_email', email);
      await prefs.setString('user_id', result.userId);
      await prefs.setString('api_key', apiKey);
      if (result.sessionToken != null) {
        await prefs.setString('session_token', result.sessionToken!);
      }

      apiProvider.setApiKey(apiKey);
      apiProvider.agentService.autoEnableMcpServers();

      state = state.copyWith(
        isLoggedIn: true,
        isLoading: false,
        walletAddress: walletAddress,
        email: email,
        userId: result.userId,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Login using Solana wallet signature proof (CRIT-2 fix).
  /// Caller must have already obtained [signature] and [publicKey] from MWA.
  Future<void> loginWithWalletSignature({
    required String walletAddress,
    required String publicKey,
    required String signature,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final authService = apiProvider.authService;

      final result = await authService.loginWithWallet(
        walletAddress: walletAddress,
        publicKey: publicKey,
        signature: signature,
      );

      final prefs = await SharedPreferences.getInstance();

      final apiKey = result.apiKey;
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('No API key received. Please contact support.');
      }

      await prefs.setString('wallet_address', walletAddress);
      await prefs.setString('user_email', result.email ?? '');
      await prefs.setString('user_id', result.userId);
      await prefs.setString('api_key', apiKey);
      if (result.sessionToken != null) {
        await prefs.setString('session_token', result.sessionToken!);
      }

      apiProvider.setApiKey(apiKey);
      apiProvider.agentService.autoEnableMcpServers();

      state = state.copyWith(
        isLoggedIn: true,
        isLoading: false,
        walletAddress: walletAddress,
        email: result.email,
        userId: result.userId,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> registerWithWalletAndEmail({
    required String walletAddress,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final authService = apiProvider.authService;
      // Pass walletAddress so backend stores it as pending_wallet_address;
      // it will be linked to the agent when the user verifies their email.
      await authService.register(email, password, walletAddress: walletAddress);

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    // Keep 'api_key' and 'wallet_address' — they are long-lived credentials
    // that survive logout. Clearing them forces a regenerate-key call on every
    // re-login, which creates a new key and breaks existing integrations.
    await prefs.remove('session_token');
    await prefs.remove('user_email');
    await prefs.remove('user_id');
    apiProvider.setApiKey(null);
    state = const AuthState();
  }

  /// Called after email verification — stores session and marks logged in
  Future<void> loginWithSession({
    required String sessionToken,
    required String email,
    required String apiKey,
    String? walletAddress,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', email);
    await prefs.setString('api_key', apiKey);
    if (walletAddress != null && walletAddress.isNotEmpty) {
      await prefs.setString('wallet_address', walletAddress);
    }

    apiProvider.setApiKey(apiKey);
    apiProvider.agentService.autoEnableMcpServers();

    state = state.copyWith(
      isLoggedIn: true,
      isLoading: false,
      email: email,
      walletAddress: walletAddress,
    );
  }

  bool get isConnected => state.isLoggedIn;
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).isLoggedIn;
});
