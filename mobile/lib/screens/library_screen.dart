import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/sidebar_drawer.dart';
import '../services/provider.dart';
import '../services/agent_service.dart';
import '../services/error_handler.dart' show isAuthError;
import 'package:go_router/go_router.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<ChatSession> _chats = [];
  AgentUsage? _usage;
  List<ApiKey> _apiKeys = [];
  List<ModelInfo> _models = [];
  List<McpServer> _mcpServers = [];

  bool _loadingChats = true;
  bool _loadingUsage = true;
  bool _loadingApiKeys = true;
  bool _loadingModels = true;
  bool _loadingMcp = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadChats();
    _loadUsage();
    _loadApiKeys();
    _loadModels();
    _loadMcpServers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    setState(() => _loadingChats = true);
    try {
      final chats = await apiProvider.agentService.getChats(page: 1, limit: 50);
      if (mounted) {
        setState(() {
          _chats = chats;
          _loadingChats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingChats = false);
        if (isAuthError(e)) {
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
        }
      }
    }
  }

  Future<void> _loadUsage() async {
    setState(() => _loadingUsage = true);
    try {
      final usage = await apiProvider.agentService.getUsage();
      if (mounted) {
        setState(() {
          _usage = usage;
          _loadingUsage = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingUsage = false);
    }
  }

  Future<void> _loadApiKeys() async {
    setState(() => _loadingApiKeys = true);
    try {
      final keys = await apiProvider.agentService.getApiKeys();
      if (mounted) {
        setState(() {
          _apiKeys = keys;
          _loadingApiKeys = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingApiKeys = false);
    }
  }

  Future<void> _loadModels() async {
    setState(() => _loadingModels = true);
    try {
      final models = await apiProvider.agentService.getModels();
      if (mounted) {
        setState(() {
          _models = models;
          _loadingModels = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  Future<void> _loadMcpServers() async {
    setState(() => _loadingMcp = true);
    try {
      final servers = await apiProvider.agentService.getMcpServers();
      if (mounted) {
        setState(() {
          _mcpServers = servers;
          _loadingMcp = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingMcp = false);
    }
  }

  Future<void> _toggleMcpServer(McpServer server) async {
    final wasEnabled = server.isEnabled;
    setState(() {
      final idx = _mcpServers.indexWhere((s) => s.id == server.id);
      if (idx != -1) {
        _mcpServers[idx] = McpServer(
          id: server.id,
          name: server.name,
          displayName: server.displayName,
          description: server.description,
          transport: server.transport,
          isEnabled: !wasEnabled,
          config: server.config,
          createdAt: server.createdAt,
        );
      }
    });
    try {
      if (wasEnabled) {
        await apiProvider.agentService.disableMcpServer(server.id);
      } else {
        await apiProvider.agentService.enableMcpServer(server.id, {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final idx = _mcpServers.indexWhere((s) => s.id == server.id);
          if (idx != -1) {
            _mcpServers[idx] = McpServer(
              id: server.id,
              name: server.name,
              displayName: server.displayName,
              description: server.description,
              transport: server.transport,
              isEnabled: wasEnabled,
              config: server.config,
              createdAt: server.createdAt,
            );
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle ${server.displayName}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _createApiKey() async {
    String? label;
    final confirm = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('New API Key', style: TextStyle(color: AppTheme.textPrimary)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Label (e.g. "Production")',
              hintStyle: TextStyle(color: AppTheme.textPlaceholder),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.borderLight)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accentLink)),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim().isEmpty ? 'Default' : v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim().isEmpty ? 'Default' : ctrl.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    if (confirm == null) return;
    label = confirm;

    try {
      final newKey = await apiProvider.agentService.createApiKey(label);
      if (!mounted) return;

      // Show full key — only visible once
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _NewKeyDialog(apiKey: newKey),
      );

      _loadApiKeys();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create key: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteApiKey(ApiKey key) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete API Key', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Delete "${key.label ?? key.keyPrefix}"? This cannot be undone.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await apiProvider.agentService.deleteApiKey(key.id);
      _loadApiKeys();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete key: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const SidebarDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Image.asset(
          'assets/images/daemonprotocol_logo_White_transparent_text.png',
          height: 24,
          fit: BoxFit.contain,
        ),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.accentLink,
          indicatorWeight: 2,
          labelColor: AppTheme.textPrimary,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
          tabs: const [
            Tab(text: 'Chats'),
            Tab(text: 'Usage'),
            Tab(text: 'API Keys'),
            Tab(text: 'Models'),
            Tab(text: 'Tools'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ChatHistoryTab(
            chats: _chats,
            isLoading: _loadingChats,
            onRefresh: _loadChats,
          ),
          _UsageTab(
            usage: _usage,
            isLoading: _loadingUsage,
            onRefresh: _loadUsage,
          ),
          _ApiKeysTab(
            apiKeys: _apiKeys,
            isLoading: _loadingApiKeys,
            onRefresh: _loadApiKeys,
            onCreate: _createApiKey,
            onDelete: _deleteApiKey,
          ),
          _ModelsTab(
            models: _models,
            isLoading: _loadingModels,
            onRefresh: _loadModels,
          ),
          _McpTab(
            servers: _mcpServers,
            isLoading: _loadingMcp,
            onRefresh: _loadMcpServers,
            onToggle: _toggleMcpServer,
          ),
        ],
      ),
    );
  }
}

// ─── New Key Dialog ──────────────────────────────────────────────────────────

class _NewKeyDialog extends StatefulWidget {
  final ApiKey apiKey;
  const _NewKeyDialog({required this.apiKey});

  @override
  State<_NewKeyDialog> createState() => _NewKeyDialogState();
}

class _NewKeyDialogState extends State<_NewKeyDialog> {
  bool _copied = false;

  // The full key is returned in the `keyPrefix` field on creation
  // (backend returns full key once, stored in keyPrefix at creation time)
  String get _fullKey => widget.apiKey.keyPrefix;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _fullKey));
    if (mounted) setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Row(
        children: [
          const Icon(Icons.key, color: AppTheme.accentLink, size: 20),
          const SizedBox(width: 8),
          const Text('API Key Created', style: TextStyle(color: AppTheme.textPrimary)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Copy this key now — it will never be shown again.',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Label: ${widget.apiKey.label ?? 'Default'}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _copy,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _fullKey,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _copied ? Icons.check : Icons.copy_outlined,
                    size: 16,
                    color: _copied ? Colors.green : AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

// ─── Chat History Tab ────────────────────────────────────────────────────────

class _ChatHistoryTab extends StatelessWidget {
  final List<ChatSession> chats;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _ChatHistoryTab({
    required this.chats,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentLink),
      );
    }

    if (chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: const Icon(Icons.chat_bubble_outline, size: 28, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              'No chats yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              'Start a conversation to see it here',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textPlaceholder),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppTheme.accentLink,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: chats.length,
        separatorBuilder: (context, index) => Divider(
          color: AppTheme.borderLight.withValues(alpha: 0.4),
          height: 1,
        ),
        itemBuilder: (context, i) => _ChatItem(chat: chats[i]),
      ),
    );
  }
}

class _ChatItem extends StatelessWidget {
  final ChatSession chat;

  const _ChatItem({required this.chat});

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _modelShort(String modelId) {
    final parts = modelId.split('/');
    final name = parts.last.split(':').first;
    final words = name.split('-');
    return words.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accent bar
          Container(
            width: 3,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppTheme.accentLink, Color(0xFF3A8B89)],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        chat.title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(chat.updatedAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textPlaceholder,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 11, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${chat.messageCount} messages',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentLink.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.accentLink.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        _modelShort(chat.modelId),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.accentLink,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Usage Analytics Tab ─────────────────────────────────────────────────────

class _UsageTab extends StatelessWidget {
  final AgentUsage? usage;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _UsageTab({
    required this.usage,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentLink),
      );
    }

    final u = usage;
    if (u == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(
              'Usage data unavailable',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRefresh, child: const Text('Retry')),
          ],
        ),
      );
    }

    final usedPct = u.monthlyTokenLimit > 0
        ? (u.totalTokens / u.monthlyTokenLimit).clamp(0.0, 1.0)
        : 0.0;

    final progressColor = usedPct > 0.9
        ? Colors.redAccent
        : usedPct > 0.7
            ? Colors.orange
            : AppTheme.accentLink;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppTheme.accentLink,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Month banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text(
                  u.month,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  'Current month',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textPlaceholder),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Token ring + stats
          _TokenRingCard(
            used: u.totalTokens,
            limit: u.monthlyTokenLimit,
            usedPct: usedPct,
            progressColor: progressColor,
            promptTokens: u.promptTokens,
            completionTokens: u.completionTokens,
            remainingTokens: u.remainingTokens,
          ),

          const SizedBox(height: 16),

          // Cost card
          _UsageCard(
            title: 'Cost This Month',
            subtitle: '\$${u.costUsdc.toStringAsFixed(4)} USDC',
            children: [
              _StatRow(
                label: 'Avg cost / 1K tokens',
                value: u.totalTokens > 0
                    ? '\$${((u.costUsdc / u.totalTokens) * 1000).toStringAsFixed(4)}'
                    : '-',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TokenRingCard extends StatelessWidget {
  final int used;
  final int limit;
  final double usedPct;
  final Color progressColor;
  final int promptTokens;
  final int completionTokens;
  final int remainingTokens;

  const _TokenRingCard({
    required this.used,
    required this.limit,
    required this.usedPct,
    required this.progressColor,
    required this.promptTokens,
    required this.completionTokens,
    required this.remainingTokens,
  });

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Token Usage',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Donut ring
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: usedPct,
                      strokeWidth: 8,
                      backgroundColor: AppTheme.borderLight,
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      strokeCap: StrokeCap.round,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(usedPct * 100).toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: progressColor,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          'used',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.textPlaceholder,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmt(used),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'of ${_fmt(limit)} tokens',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _MiniStat(label: 'Prompt', value: _fmt(promptTokens), color: AppTheme.accentLink),
                    const SizedBox(height: 4),
                    _MiniStat(label: 'Completion', value: _fmt(completionTokens), color: const Color(0xFFB388FF)),
                    const SizedBox(height: 4),
                    _MiniStat(label: 'Remaining', value: _fmt(remainingTokens), color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textSecondary,
            fontSize: 11,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _UsageCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _UsageCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...children,
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
          Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── API Keys Tab ─────────────────────────────────────────────────────────────

class _ApiKeysTab extends StatelessWidget {
  final List<ApiKey> apiKeys;
  final bool isLoading;
  final VoidCallback onRefresh;
  final VoidCallback onCreate;
  final Future<void> Function(ApiKey) onDelete;

  const _ApiKeysTab({
    required this.apiKeys,
    required this.isLoading,
    required this.onRefresh,
    required this.onCreate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onCreate,
        backgroundColor: AppTheme.accentLink,
        foregroundColor: AppTheme.primaryActionText,
        icon: const Icon(Icons.add),
        label: const Text('New Key', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentLink),
            )
          : RefreshIndicator(
              onRefresh: () async => onRefresh(),
              color: AppTheme.accentLink,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentLink.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accentLink.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppTheme.accentLink),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'API keys authenticate requests to the Daemon API. The full key is only shown once at creation.',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.accentLink,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (apiKeys.isEmpty) ...[
                    const SizedBox(height: 40),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: const Icon(Icons.key_off_outlined, size: 28, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No API keys yet',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap "New Key" to create your first API key',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textPlaceholder,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    for (final key in apiKeys) _ApiKeyTile(apiKey: key, onDelete: onDelete),
                  ],
                ],
              ),
            ),
    );
  }
}

class _ApiKeyTile extends StatelessWidget {
  final ApiKey apiKey;
  final Future<void> Function(ApiKey) onDelete;

  const _ApiKeyTile({required this.apiKey, required this.onDelete});

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return 'Never';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return _formatDate(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: apiKey.isActive
              ? AppTheme.accentLink.withValues(alpha: 0.2)
              : AppTheme.borderLight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Key icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.accentLink.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.key, size: 18, color: AppTheme.accentLink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        apiKey.label ?? 'API Key',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${apiKey.keyPrefix}••••••••••••',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: apiKey.isActive
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    apiKey.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: apiKey.isActive ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: AppTheme.borderLight.withValues(alpha: 0.5), height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                _KeyMeta(label: 'Created', value: _formatDate(apiKey.createdAt)),
                const SizedBox(width: 16),
                _KeyMeta(label: 'Last used', value: _timeAgo(apiKey.lastUsedAt)),
                const Spacer(),
                GestureDetector(
                  onTap: () => onDelete(apiKey),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.delete_outline, size: 13, color: Colors.redAccent),
                        const SizedBox(width: 4),
                        const Text(
                          'Delete',
                          style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyMeta extends StatelessWidget {
  final String label;
  final String value;

  const _KeyMeta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textPlaceholder,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ─── Models Tab ───────────────────────────────────────────────────────────────

class _ModelsTab extends StatelessWidget {
  final List<ModelInfo> models;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _ModelsTab({
    required this.models,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentLink),
      );
    }

    if (models.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_toy_outlined, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(
              'No models available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRefresh, child: const Text('Retry')),
          ],
        ),
      );
    }

    // Group by free vs paid
    final freeModels = models.where((m) => m.isFree).toList();
    final paidModels = models.where((m) => !m.isFree).toList();

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppTheme.accentLink,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (freeModels.isNotEmpty) ...[
            _ModelSectionHeader(label: 'FREE MODELS', count: freeModels.length),
            const SizedBox(height: 8),
            for (final model in freeModels) _ModelTile(model: model),
            const SizedBox(height: 16),
          ],
          if (paidModels.isNotEmpty) ...[
            _ModelSectionHeader(label: 'PAID MODELS', count: paidModels.length),
            const SizedBox(height: 8),
            for (final model in paidModels) _ModelTile(model: model),
          ],
        ],
      ),
    );
  }
}

class _ModelSectionHeader extends StatelessWidget {
  final String label;
  final int count;
  const _ModelSectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.textPlaceholder,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
}

class _ModelTile extends StatelessWidget {
  final ModelInfo model;
  const _ModelTile({required this.model});

  String _providerShort(String id) {
    return id.split('/').first;
  }

  String _modelName(String id) {
    final parts = id.split('/');
    final name = parts.last.split(':').first;
    return name;
  }

  String _contextLabel(int? ctx) {
    if (ctx == null) return '';
    if (ctx >= 1000000) return '${(ctx / 1000000).toStringAsFixed(1)}M ctx';
    if (ctx >= 1000) return '${(ctx / 1000).toStringAsFixed(0)}K ctx';
    return '$ctx ctx';
  }

  bool _isNew(int? createdAtOpenrouter) {
    if (createdAtOpenrouter == null) return false;
    final created = DateTime.fromMillisecondsSinceEpoch(createdAtOpenrouter * 1000);
    return DateTime.now().difference(created).inDays <= 30;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: model.isFree
              ? AppTheme.accentLink.withValues(alpha: 0.2)
              : AppTheme.borderLight,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: model.isFree
                  ? AppTheme.accentLink.withValues(alpha: 0.1)
                  : AppTheme.borderLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.smart_toy_outlined,
              size: 18,
              color: model.isFree ? AppTheme.accentLink : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.name.isNotEmpty ? model.name : _modelName(model.id),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _providerShort(model.id),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Badges
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (model.isFree)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentLink.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'FREE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentLink,
                    ),
                  ),
                ),
              if (_isNew(model.createdAtOpenrouter)) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
              if (model.supportsTools) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'TOOLS',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.purple,
                    ),
                  ),
                ),
              ],
              if (model.contextLength != null) ...[
                const SizedBox(height: 4),
                Text(
                  _contextLabel(model.contextLength),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textPlaceholder,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── MCP Tools Tab ────────────────────────────────────────────────────────────

class _McpTab extends StatelessWidget {
  final List<McpServer> servers;
  final bool isLoading;
  final VoidCallback onRefresh;
  final Future<void> Function(McpServer) onToggle;

  const _McpTab({
    required this.servers,
    required this.isLoading,
    required this.onRefresh,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentLink),
      );
    }

    if (servers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.extension_outlined, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(
              'No tools available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              'MCP tools extend your agent\'s capabilities',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textPlaceholder),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRefresh, child: const Text('Retry')),
          ],
        ),
      );
    }

    final enabled = servers.where((s) => s.isEnabled).length;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppTheme.accentLink,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              children: [
                const Icon(Icons.extension_outlined, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text(
                  '$enabled of ${servers.length} tools enabled',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final server in servers)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: server.isEnabled
                      ? AppTheme.accentLink.withValues(alpha: 0.25)
                      : AppTheme.borderLight,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: server.isEnabled
                        ? AppTheme.accentLink.withValues(alpha: 0.1)
                        : AppTheme.borderLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.extension_outlined,
                    size: 18,
                    color: server.isEnabled ? AppTheme.accentLink : AppTheme.textSecondary,
                  ),
                ),
                title: Text(
                  server.displayName,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                subtitle: server.description != null
                    ? Text(
                        server.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      )
                    : null,
                trailing: Switch(
                  value: server.isEnabled,
                  onChanged: (_) => onToggle(server),
                  activeThumbColor: AppTheme.accentLink,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
