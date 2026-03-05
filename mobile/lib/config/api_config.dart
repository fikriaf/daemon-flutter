import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://daemon-ai-production.up.railway.app',
  );
  
  static const String sandboxBaseUrl = String.fromEnvironment(
    'SANDBOX_API_BASE_URL',
    defaultValue: 'https://daemon-ai-production.up.railway.app',
  );
  
  static const String apiVersion = '/v1';
  
  // Get the appropriate base URL based on context
  static String getBaseUrl({bool isSandbox = false}) {
    return isSandbox ? sandboxBaseUrl : baseUrl;
  }

  // Chat
  static String chatEndpoint({bool isSandbox = false}) => 
    '${getBaseUrl(isSandbox: isSandbox)}$apiVersion/chat/completions';
  
  // Agent endpoints
  static String agentMeEndpoint({bool isSandbox = false}) => 
    '${getBaseUrl(isSandbox: isSandbox)}$apiVersion/agent/me';
  
  static String agentBalanceEndpoint({bool isSandbox = false}) => 
    '${getBaseUrl(isSandbox: isSandbox)}$apiVersion/agent/balance';
  
  static String agentUsageEndpoint({bool isSandbox = false}) => 
    '${getBaseUrl(isSandbox: isSandbox)}$apiVersion/agent/usage';
  
  static String agentChatsEndpoint({bool isSandbox = false}) => 
    '${getBaseUrl(isSandbox: isSandbox)}$apiVersion/agent/chats';
  
  static String agentSettingsEndpoint({bool isSandbox = false}) => 
    '${getBaseUrl(isSandbox: isSandbox)}$apiVersion/agent/settings';
  
  static String agentApiKeysEndpoint({bool isSandbox = false}) => 
    '${getBaseUrl(isSandbox: isSandbox)}$apiVersion/agent/api-keys';
  
  static String agentMcpServersEndpoint({bool isSandbox = false}) => 
    '${getBaseUrl(isSandbox: isSandbox)}$apiVersion/agent/mcp-servers';
  
  // Discover & Finance
  static String discoverEndpoint({bool isSandbox = false}) => 
    '${getBaseUrl(isSandbox: isSandbox)}$apiVersion/agent/discover';
  
  static String financeEndpoint({bool isSandbox = false}) => 
    '${getBaseUrl(isSandbox: isSandbox)}$apiVersion/agent/finance';
  
  // Models & Auth
  static String modelsEndpoint({bool isSandbox = false}) => 
    '${getBaseUrl(isSandbox: isSandbox)}$apiVersion/models';
  
  static String authLoginEndpoint({bool isSandbox = false}) => 
    '${getBaseUrl(isSandbox: isSandbox)}$apiVersion/auth/login';
  
  static String authRegisterEndpoint({bool isSandbox = false}) => 
    '${getBaseUrl(isSandbox: isSandbox)}$apiVersion/auth/register';
  
  static bool get isDebug => kDebugMode;

  // Free models available to all users (hardcoded — source of truth)
  static const List<Map<String, String>> freeModels = [
    {
      'id': 'stepfun/step-3.5-flash:free',
      'name': 'StepFun 3.5 Flash (Free)',
      'short': 'StepFun',
    },
    {
      'id': 'arcee-ai/trinity-large-preview:free',
      'name': 'Trinity Large (Free)',
      'short': 'Trinity',
    },
  ];

  static const String defaultFreeModelId = 'stepfun/step-3.5-flash:free';

  /// Short display label for chat input button. Returns null if id not found.
  static String? shortLabelForModel(String? id) {
    if (id == null) return null;
    for (final m in freeModels) {
      if (m['id'] == id) return m['short'];
    }
    // Paid / unknown model — use last segment before ':' of the id
    final slug = id.split('/').last.split(':').first;
    return slug.length > 10 ? '${slug.substring(0, 10)}…' : slug;
  }
}
