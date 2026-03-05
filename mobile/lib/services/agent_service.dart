import 'api_service.dart';

class AgentService {
  final ApiService _api;

  AgentService(this._api);

  ApiService get api => _api; // Public getter for streaming

  // Get agent info (user + subscription)
  Future<AgentInfo> getAgentMe() async {
    final data = await _api.get('/v1/agent/me');
    return AgentInfo.fromJson(data);
  }

  // Get balance
  Future<AgentBalance> getBalance() async {
    final data = await _api.get('/v1/agent/balance');
    return AgentBalance.fromJson(data);
  }

  // Get usage stats
  Future<AgentUsage> getUsage() async {
    final data = await _api.get('/v1/agent/usage');
    return AgentUsage.fromJson(data);
  }

  // Get chat history
  Future<List<ChatSession>> getChats({int page = 1, int limit = 20}) async {
    final data = await _api.get('/v1/agent/chats?page=$page&limit=$limit');
    final list = data['data'] as List? ?? [];
    return list.map((e) => ChatSession.fromJson(e)).toList();
  }

  // Get messages for a specific chat session
  Future<List<SessionMessage>> getChatMessages(String chatId) async {
    final data = await _api.get('/v1/agent/chats/$chatId/messages');
    final list = data['data'] as List? ?? [];
    return list.map((e) => SessionMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Get available models — fetches all pages automatically.
  Future<List<ModelInfo>> getModels({bool? isFree, bool? supportsTools}) async {
    const int pageSize = 100;
    final baseParams = <String>['limit=$pageSize'];
    if (isFree != null) baseParams.add('is_free=$isFree');
    if (supportsTools != null) baseParams.add('supports_tools=$supportsTools');

    final allModels = <ModelInfo>[];
    int page = 1;

    while (true) {
      final params = [...baseParams, 'page=$page'];
      final endpoint = '/v1/models?${params.join('&')}';
      final data = await _api.get(endpoint);
      final list = data['data'] as List? ?? [];
      final total = (data['total'] as num?)?.toInt() ?? 0;

      allModels.addAll(
        list.map((e) => ModelInfo.fromJson(e as Map<String, dynamic>)),
      );

      // Stop when we've collected all models
      if (allModels.length >= total || list.isEmpty) break;
      page++;
    }

    return allModels;
  }

  // Update settings
  Future<void> updateSettings(AgentSettings settings) async {
    await _api.patch('/v1/agent/settings', settings.toJson());
  }

  // Get API keys
  Future<List<ApiKey>> getApiKeys() async {
    try {
      final data = await _api.get('/v1/agent/api-keys');
      if (data.containsKey('data') && data['data'] is List) {
        final List<dynamic> list = data['data'] as List;
        return list.map((e) => ApiKey.fromJson(e as Map<String, dynamic>)).toList();
      }
      if (data is List) {
        return (data as List).map((e) => ApiKey.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Create API key
  Future<ApiKey> createApiKey(String label) async {
    final data = await _api.post('/v1/agent/api-keys', {'label': label});
    return ApiKey.fromJson(data);
  }

  // Delete API key
  Future<void> deleteApiKey(String id) async {
    await _api.delete('/v1/agent/api-keys/$id');
  }

  // Get MCP servers
  Future<List<McpServer>> getMcpServers() async {
    try {
      final data = await _api.get('/v1/agent/mcp-servers');
      if (data.containsKey('data') && data['data'] is List) {
        final List<dynamic> list = data['data'] as List;
        return list.map((e) => McpServer.fromJson(e as Map<String, dynamic>)).toList();
      }
      if (data is List) {
        return (data as List).map((e) => McpServer.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Enable MCP server
  Future<void> enableMcpServer(String serverId, Map<String, dynamic> config) async {
    await _api.post('/v1/agent/mcp-servers', {
      'mcp_server_id': serverId,
      'config': config,
    });
  }

  // Disable MCP server
  Future<void> disableMcpServer(String serverId) async {
    await _api.delete('/v1/agent/mcp-servers/$serverId');
  }

  // Auto-enable all available MCP servers that are not yet enabled.
  // Called after login/register so new accounts get tools out of the box.
  Future<void> autoEnableMcpServers() async {
    try {
      final servers = await getMcpServers();
      for (final server in servers) {
        if (!server.isEnabled) {
          try {
            await enableMcpServer(server.id, {});
          } catch (e) {
            // 'already_enabled' or other non-fatal errors — ignore
          }
        }
      }
    } catch (_) {
      // Non-fatal: if MCP list fetch fails, continue silently
    }
  }
}

// Models

class AgentInfo {
  final String agentId;
  final String name;
  final AgentUser? user;
  final Subscription? subscription;
  final String? systemPrompt;
  final String? defaultModelId;
  final String? walletAddress;
  final int monthlyTokenLimit;
  final bool isActive;
  final List<McpServerStatus> mcpServers;
  final DateTime? createdAt;

  AgentInfo({
    required this.agentId,
    required this.name,
    this.user,
    this.subscription,
    this.systemPrompt,
    this.defaultModelId,
    this.walletAddress,
    required this.monthlyTokenLimit,
    required this.isActive,
    this.mcpServers = const [],
    this.createdAt,
  });

  factory AgentInfo.fromJson(Map<String, dynamic> json) {
    return AgentInfo(
      agentId: json['agent_id'] ?? '',
      name: json['name'] ?? '',
      user: json['user'] != null ? AgentUser.fromJson(json['user']) : null,
      subscription: json['subscription'] != null 
          ? Subscription.fromJson(json['subscription']) 
          : null,
      systemPrompt: json['system_prompt'],
      defaultModelId: json['default_model_id'],
      walletAddress: json['wallet_address'],
      monthlyTokenLimit: json['monthly_token_limit'] ?? 1000000,
      isActive: json['is_active'] ?? true,
      mcpServers: (json['mcp_servers'] as List?)
              ?.map((e) => McpServerStatus.fromJson(e))
              .toList() ??
          [],
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at']) 
          : null,
    );
  }
}

class AgentUser {
  final String userId;
  final String email;
  final String? avatar;

  AgentUser({required this.userId, required this.email, this.avatar});

  factory AgentUser.fromJson(Map<String, dynamic> json) {
    return AgentUser(
      userId: json['user_id'] ?? '',
      email: json['email'] ?? '',
      avatar: json['avatar'],
    );
  }
}

class Subscription {
  final String plan;
  final int monthlyTokenLimit;
  final List<String> features;

  Subscription({
    required this.plan,
    required this.monthlyTokenLimit,
    required this.features,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      plan: json['plan'] ?? 'free',
      monthlyTokenLimit: json['monthly_token_limit'] ?? 1000000,
      features: List<String>.from(json['features'] ?? []),
    );
  }
}

class AgentBalance {
  final String agentId;
  final double balanceUsdc;
  final DateTime updatedAt;

  AgentBalance({
    required this.agentId,
    required this.balanceUsdc,
    required this.updatedAt,
  });

  factory AgentBalance.fromJson(Map<String, dynamic> json) {
    return AgentBalance(
      agentId: json['agent_id'] ?? '',
      balanceUsdc: double.tryParse(json['balance_usdc']?.toString() ?? '0') ?? 0,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : DateTime.now(),
    );
  }
}

class AgentUsage {
  final String agentId;
  final String month;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final int monthlyTokenLimit;
  final double costUsdc;
  final int remainingTokens;

  AgentUsage({
    required this.agentId,
    required this.month,
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.monthlyTokenLimit,
    required this.costUsdc,
    required this.remainingTokens,
  });

  factory AgentUsage.fromJson(Map<String, dynamic> json) {
    return AgentUsage(
      agentId: json['agent_id'] ?? '',
      month: json['month'] ?? '',
      promptTokens: json['prompt_tokens'] ?? 0,
      completionTokens: json['completion_tokens'] ?? 0,
      totalTokens: json['total_tokens'] ?? 0,
      monthlyTokenLimit: json['monthly_token_limit'] ?? 1000000,
      costUsdc: double.tryParse(json['cost_usdc']?.toString() ?? '0') ?? 0,
      remainingTokens: json['remaining_tokens'] ?? 0,
    );
  }
}

class ChatSession {
  final String id;
  final String title;
  final String modelId;
  final int messageCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatSession({
    required this.id,
    required this.title,
    required this.modelId,
    required this.messageCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled',
      modelId: json['model_id'] ?? '',
      messageCount: json['message_count'] ?? 0,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : DateTime.now(),
    );
  }
}

class AgentSettings {
  final String? systemPrompt;
  final String? defaultModelId;
  final String? walletAddress;
  final int? monthlyTokenLimit;

  AgentSettings({
    this.systemPrompt,
    this.defaultModelId,
    this.walletAddress,
    this.monthlyTokenLimit,
  });

  Map<String, dynamic> toJson() => {
    if (systemPrompt != null) 'system_prompt': systemPrompt,
    if (defaultModelId != null) 'default_model_id': defaultModelId,
    if (walletAddress != null) 'wallet_address': walletAddress,
    if (monthlyTokenLimit != null) 'monthly_token_limit': monthlyTokenLimit,
  };
}

class ApiKey {
  final String id;
  final String keyPrefix;
  final String? label;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  ApiKey({
    required this.id,
    required this.keyPrefix,
    this.label,
    required this.isActive,
    required this.createdAt,
    this.lastUsedAt,
  });

  factory ApiKey.fromJson(Map<String, dynamic> json) {
    return ApiKey(
      id: json['id'] ?? '',
      keyPrefix: json['key_prefix'] ?? '',
      label: json['label'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      lastUsedAt: json['last_used_at'] != null 
          ? DateTime.parse(json['last_used_at']) 
          : null,
    );
  }
}

class McpServer {
  final String id;
  final String name;
  final String displayName;
  final String? description;
  final String transport;
  final bool isEnabled;
  final Map<String, dynamic> config;
  final DateTime? createdAt;

  McpServer({
    required this.id,
    required this.name,
    required this.displayName,
    this.description,
    required this.transport,
    required this.isEnabled,
    this.config = const {},
    this.createdAt,
  });

  factory McpServer.fromJson(Map<String, dynamic> json) {
    return McpServer(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      displayName: json['display_name'] ?? json['name'] ?? '',
      description: json['description'],
      transport: json['transport'] ?? 'stdio',
      isEnabled: json['is_enabled'] ?? false,
      config: Map<String, dynamic>.from(json['config'] ?? {}),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
    );
  }
}

class McpServerStatus {
  final String name;
  final String displayName;
  final bool isActive;

  McpServerStatus({
    required this.name,
    required this.displayName,
    required this.isActive,
  });

  factory McpServerStatus.fromJson(Map<String, dynamic> json) {
    return McpServerStatus(
      name: json['name'] ?? '',
      displayName: json['display_name'] ?? json['name'] ?? '',
      isActive: json['is_active'] ?? false,
    );
  }
}

class SessionMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime createdAt;

  SessionMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory SessionMessage.fromJson(Map<String, dynamic> json) {
    return SessionMessage(
      id: json['id'] ?? '',
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

class ModelInfo {
  final String id;
  final String name;
  final String? provider;
  final bool isFree;
  final bool supportsTools;
  final int? contextLength;
  /// Unix timestamp (seconds) from OpenRouter indicating when the model was created.
  /// Null for models synced before this field was added.
  final int? createdAtOpenrouter;

  ModelInfo({
    required this.id,
    required this.name,
    this.provider,
    required this.isFree,
    required this.supportsTools,
    this.contextLength,
    this.createdAtOpenrouter,
  });

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? json['id'] ?? '',
      provider: json['provider'],
      isFree: json['is_free'] ?? false,
      supportsTools: json['supports_tools'] ?? false,
      contextLength: json['context_length'],
      createdAtOpenrouter: json['created_at_openrouter'],
    );
  }
}
