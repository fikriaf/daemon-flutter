import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import 'auth_state.dart';

void handleApiError(BuildContext context, dynamic error, WidgetRef ref) {
  if (error is ApiException && error.isUnauthorized) {
    // Show snackbar and navigate to login
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Please login to continue'),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Login',
          textColor: Colors.white,
          onPressed: () => context.push('/login'),
        ),
      ),
    );
    
    // Optionally logout to clear any stale state
    try {
      ref.read(authStateProvider.notifier).logout();
    } catch (_) {}
    
    // Navigate to login
    context.push('/login');
  } else {
    // Show generic error
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        backgroundColor: Colors.red,
      ),
    );
  }
}

bool isAuthError(dynamic error) {
  if (error is ApiException) {
    return error.isUnauthorized;
  }
  if (error is String) {
    return error.toLowerCase().contains('unauthorized') || 
           error.toLowerCase().contains('invalid api key') ||
           error.toLowerCase().contains('missing api key');
  }
  return false;
}

void handleAuthError(BuildContext context, WidgetRef ref) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('Session expired. Please login again.'),
      backgroundColor: Colors.red,
      action: SnackBarAction(
        label: 'Login',
        textColor: Colors.white,
        onPressed: () => context.push('/login'),
      ),
    ),
  );
  try {
    ref.read(authStateProvider.notifier).logout();
  } catch (_) {}
  context.push('/login');
}
