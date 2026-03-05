import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/provider.dart';
import '../services/auth_state.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String? token;
  final String? email; // for /verified route (already verified via browser)

  const VerifyEmailScreen({super.key, this.token, this.email});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  _State _state = _State.loading;
  String? _errorMsg;
  String? _verifiedEmail;

  @override
  void initState() {
    super.initState();
    if (widget.email != null) {
      // Came from browser redirect — already verified, just show success
      setState(() {
        _state = _State.alreadyVerified;
        _verifiedEmail = widget.email;
      });
    } else if (widget.token != null) {
      _verify(widget.token!);
    } else {
      setState(() {
        _state = _State.error;
        _errorMsg = 'Invalid verification link. No token found.';
      });
    }
  }

  Future<void> _verify(String token) async {
    setState(() => _state = _State.loading);
    try {
      final result = await apiProvider.authService.verifyEmail(token);
      if (!mounted) return;

      // Store session
      final agent = result['agent'] as Map<String, dynamic>?;
      final walletAddress = agent?['wallet_address'] as String?;
      await ref.read(authStateProvider.notifier).loginWithSession(
        sessionToken: result['session_token'] as String,
        email: result['email'] as String,
        apiKey: result['api_key'] as String,
        walletAddress: walletAddress,
      );

      setState(() {
        _state = _State.success;
        _verifiedEmail = result['email'] as String?;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _State.error;
        _errorMsg = _parseError(e.toString());
      });
    }
  }

  String _parseError(String raw) {
    if (raw.contains('token_expired')) return 'Verification link has expired. Please register again.';
    if (raw.contains('already_verified')) return 'Email already verified. You can log in now.';
    if (raw.contains('invalid_token')) return 'Invalid verification link. Please check your email.';
    return 'Verification failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Image.asset(
                  'assets/images/daemonprotocol_logo_White_transparent.png',
                  width: 64,
                  height: 64,
                ),
                const SizedBox(height: 32),

                if (_state == _State.loading) ...[
                  const CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentLink),
                  const SizedBox(height: 20),
                  Text(
                    'Verifying your email...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                  ),

                ] else if (_state == _State.success || _state == _State.alreadyVerified) ...[
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 34),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _state == _State.success ? 'Email Verified!' : 'Already Verified',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _verifiedEmail != null
                        ? 'Welcome, $_verifiedEmail.\nYour account is now active.'
                        : 'Your account is now active.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Start Using Daemon'),
                    ),
                  ),

                ] else ...[
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.error_outline, color: Colors.redAccent, size: 34),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Verification Failed',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMsg ?? 'Something went wrong.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Back to Login'),
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
}

enum _State { loading, success, alreadyVerified, error }
