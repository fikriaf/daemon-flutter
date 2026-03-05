import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import 'api_service.dart';
import 'agent_service.dart';
import 'discover_service.dart';
import 'finance_service.dart';
import 'auth_service.dart';

class ApiProvider extends ChangeNotifier {
  late final ApiService _apiService;
  late final AgentService agentService;
  late final DiscoverService discoverService;
  late final FinanceService financeService;
  late final AuthService authService;

  String? _apiKey;
  bool _isSandbox = false;

  String? get apiKey => _apiKey;
  bool get isSandbox => _isSandbox;
  bool get isAuthenticated => _apiKey != null && _apiKey!.isNotEmpty;

  ApiProvider() {
    _apiService = ApiService();
    agentService = AgentService(_apiService);
    discoverService = DiscoverService(_apiService);
    financeService = FinanceService(_apiService);
    authService = AuthService(_apiService);
  }

  void setApiKey(String? key) {
    _apiKey = key;
    _apiService.setApiKey(key);
    notifyListeners();
  }

  void setSandbox(bool value) {
    _isSandbox = value;
    notifyListeners();
  }

  String get baseUrl => ApiConfig.getBaseUrl(isSandbox: _isSandbox);
}

// Global instance
final apiProvider = ApiProvider();