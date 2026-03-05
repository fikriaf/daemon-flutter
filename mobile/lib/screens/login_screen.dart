import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/auth_state.dart';
import '../services/wallet_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _walletService = WalletService();

  /// Set after a successful wallet connect+sign, or after manual address entry.
  String? _walletAddress;
  bool _isConnecting = false;
  bool _isLoggingIn = false;
  bool _isSignUp = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkExistingWallet();
  }

  Future<void> _checkExistingWallet() async {
    await _walletService.loadSavedWallet();
    if (_walletService.isConnected) {
      setState(() {
        _walletAddress = _walletService.connectedAddress;
      });
    }
  }

  /// Full wallet login flow:
  /// 1. MWA connect/authorize (get wallet address + auth token)
  /// 2. Fetch one-time nonce from backend
  /// 3. MWA sign nonce
  /// 4. POST signature to backend → session token + api key
  /// 5. Navigate to home on success
  Future<void> _connectAndSignIn() async {
    setState(() {
      _isConnecting = true;
      _error = null;
    });

    try {
      // Step 1 — Connect wallet
      final address = await _walletService.connectWallet();
      if (!mounted) return;
      if (address == null) {
        setState(() {
          _isConnecting = false;
          _error = 'Wallet connect was cancelled or failed. Make sure a Solana wallet (Phantom, Solflare, Backpack) is installed.';
        });
        return;
      }
      setState(() {
        _walletAddress = address;
        _isLoggingIn = true;
        _isConnecting = false;
      });

      // Step 2 — Fetch nonce
      final authService = ref.read(authStateProvider.notifier);
      final nonce = await _walletService.fetchNonce(address);
      if (!mounted) return;
      if (nonce == null) {
        setState(() {
          _isLoggingIn = false;
          _error = 'Failed to get sign challenge from server. Check your connection and try again.';
        });
        return;
      }

      // Step 3 — Sign nonce
      final signResult = await _walletService.signMessage(nonce);
      if (!mounted) return;
      if (signResult == null) {
        setState(() {
          _isLoggingIn = false;
          _error = 'Wallet sign was cancelled or failed.';
        });
        return;
      }

      // Step 4 — Authenticate with backend
      await authService.loginWithWalletSignature(
        walletAddress: signResult.walletAddress,
        publicKey: signResult.publicKeyBase58,
        signature: signResult.signatureBase58,
      );

      // Step 5 — Navigate
      if (mounted) context.go('/');
    } catch (e) {
      if (!mounted) return;
      String msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('email_not_verified') || msg.contains('verify your email')) {
        msg = 'Please verify your email before logging in. Check your inbox.';
      }
      setState(() {
        _error = msg;
        _isConnecting = false;
        _isLoggingIn = false;
      });
    }
  }

  Future<void> _login() async {
    if (_walletAddress == null) {
      setState(() => _error = 'Please connect your wallet first');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isLoggingIn = true; _error = null; });

    try {
      if (_isSignUp) {
        await ref.read(authStateProvider.notifier).registerWithWalletAndEmail(
          walletAddress: _walletAddress!,
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (mounted) _showVerificationPending(_emailController.text.trim());
      } else {
        await ref.read(authStateProvider.notifier).loginWithWalletAndEmail(
          walletAddress: _walletAddress!,
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (mounted) context.go('/');
      }
    } catch (e) {
      String msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('email_not_verified') || msg.contains('verify your email')) {
        msg = 'Please verify your email before logging in. Check your inbox.';
      }
      setState(() { _error = msg; _isLoggingIn = false; });
    }
  }

  void _showVerificationPending(String email) {
    setState(() => _isLoggingIn = false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_unread_outlined, color: Colors.blue, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Check your email',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We sent a verification link to\n$email\n\nTap the link in the email to activate your account.',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _isSignUp = false;
                    _passwordController.clear();
                    _confirmPasswordController.clear();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/daemonprotocol_logo_White_transparent.png',
                    width: 72,
                    height: 72,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome to Daemon',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect your wallet and sign in',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                _buildWalletSection(),
                const SizedBox(height: 32),

                if (_walletAddress != null) _buildEmailSection(),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWalletSection() {
    final isBusy = _isConnecting || _isLoggingIn;

    // Wallet already connected — show address chip + disconnect option
    if (_walletAddress != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wallet Connected',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wallet Connected',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      ),
                      Text(
                        '${_walletAddress!.substring(0, 8)}...${_walletAddress!.substring(_walletAddress!.length - 4)}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: isBusy ? null : () async {
                    await _walletService.disconnectWallet();
                    setState(() { _walletAddress = null; _error = null; });
                  },
                ),
              ],
            ),
          ),
        ],
      );
    }

    // No wallet yet — show the primary connect+sign button
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connect Wallet',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isBusy ? null : _connectAndSignIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: isBusy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.account_balance_wallet),
            label: Text(
              _isConnecting
                  ? 'Opening wallet...'
                  : _isLoggingIn
                      ? 'Signing in...'
                      : 'Connect & Sign In with Wallet',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Opens your Solana wallet to connect and sign. No seed phrase needed.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: isBusy ? null : _showManualWalletEntry,
            child: const Text(
              'Or enter address manually',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isSignUp ? 'Sign Up with Email' : 'Sign In with Email',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        // Email
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: _inputDecoration('Email', Icons.email_outlined),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Enter your email';
            if (!value.contains('@') || !value.contains('.')) return 'Enter a valid email';
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Password
        TextFormField(
          controller: _passwordController,
          obscureText: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: _inputDecoration('Password', Icons.lock_outlined),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Enter your password';
            if (value.length < 8) return 'Password must be at least 8 characters';
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Confirm password — only on sign-up
        if (_isSignUp) ...[
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: true,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: _inputDecoration('Confirm Password', Icons.lock_outlined),
            validator: (value) {
              if (!_isSignUp) return null;
              if (value == null || value.isEmpty) return 'Please confirm your password';
              if (value != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A verification email will be sent. Your account activates only after you verify.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.blue,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        ElevatedButton(
          onPressed: _isLoggingIn ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.textPrimary,
            foregroundColor: AppTheme.background,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoggingIn
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.background),
                )
              : Text(
                  _isSignUp ? 'Sign Up' : 'Sign In',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
        ),
        const SizedBox(height: 12),

        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                _isSignUp = !_isSignUp;
                _error = null;
                _confirmPasswordController.clear();
              });
            },
            child: Text(
              _isSignUp ? 'Already have an account? Sign In' : "Don't have an account? Sign Up",
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textSecondary),
      prefixIcon: Icon(icon, color: AppTheme.textSecondary),
      filled: true,
      fillColor: AppTheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.textPrimary),
      ),
    );
  }

  void _showManualWalletEntry() {
    final addressController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Enter Wallet Address'),
        content: TextField(
          controller: addressController,
          decoration: const InputDecoration(
            hintText: 'Enter your Solana wallet address',
            hintStyle: TextStyle(color: AppTheme.textPlaceholder),
          ),
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final address = addressController.text.trim();
              if (address.length > 30) {
                setState(() { _walletAddress = address; _error = null; });
                Navigator.pop(context);
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}
