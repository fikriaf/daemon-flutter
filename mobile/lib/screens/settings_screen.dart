import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../config/api_config.dart';
import '../services/provider.dart';
import '../services/auth_state.dart';
import '../services/agent_service.dart';
import '../services/error_handler.dart' show isAuthError;
import '../widgets/skeleton.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  AgentInfo? _agentInfo;
  AgentBalance? _balance;
  List<McpServer> _mcpServers = [];
  List<ApiKey> _apiKeys = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Free models — hardcoded
  static final List<Map<String, String>> _freeModels = ApiConfig.freeModels;

  late TextEditingController _systemPromptController;
  late TextEditingController _walletController;
  String? _selectedModel;

  @override
  void initState() {
    super.initState();
    _systemPromptController = TextEditingController();
    _walletController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _systemPromptController.dispose();
    _walletController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final api = apiProvider;
      final agentInfo = await api.agentService.getAgentMe();
      final balance = await api.agentService.getBalance();
      final mcpServers = await api.agentService.getMcpServers();
      final apiKeys = await api.agentService.getApiKeys();

      if (mounted) {
        final freeIds = _freeModels.map((m) => m['id']!).toSet();
        final currentModel = agentInfo.defaultModelId;
        final initialModel = (currentModel != null && freeIds.contains(currentModel))
            ? currentModel
            : ApiConfig.defaultFreeModelId;

        setState(() {
          _agentInfo = agentInfo;
          _balance = balance;
          _mcpServers = mcpServers;
          _apiKeys = apiKeys;
          _systemPromptController.text = agentInfo.systemPrompt ?? '';
          _walletController.text = agentInfo.walletAddress ?? '';
          _selectedModel = initialModel;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
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

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await apiProvider.agentService.updateSettings(AgentSettings(
        systemPrompt: _systemPromptController.text.trim().isEmpty
            ? null
            : _systemPromptController.text.trim(),
        defaultModelId: _selectedModel,
        walletAddress: _walletController.text.trim().isEmpty
            ? null
            : _walletController.text.trim(),
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggleMcpServer(McpServer server) async {
    final wasEnabled = server.isEnabled;
    // Optimistic update
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
      // Revert on failure
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
          SnackBar(
            content: Text('Failed to toggle ${server.displayName}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Settings'),
          centerTitle: true,
        ),
        body: const _SettingsSkeleton(),
      );
    }

    final user = _agentInfo?.user;
    final subscription = _agentInfo?.subscription;
    final email = user?.email ?? 'No email';
    final plan = subscription?.plan ?? 'free';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Settings'),
        centerTitle: true,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveSettings,
              child: const Text('Save'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          // Profile avatar
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppTheme.avatarBg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  email.isNotEmpty ? email[0].toUpperCase() : 'U',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              email,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.accentLink.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                plan.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.accentLink,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Account info row
          _SectionHeader(label: 'ACCOUNT'),
          _InfoTile(
            label: 'Balance',
            value: '\$${_balance?.balanceUsdc.toStringAsFixed(4) ?? '0.0000'} USDC',
          ),
          _ApiKeyInfoTile(
            apiKeys: _apiKeys,
            onManage: () => context.push('/library'),
          ),
          const SizedBox(height: 24),

          // AI Settings
          _SectionHeader(label: 'AI SETTINGS'),
          const SizedBox(height: 12),

          // Default model
          Text(
            'Default Model',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _freeModels.any((m) => m['id'] == _selectedModel)
                    ? _selectedModel
                    : _freeModels.first['id'],
                isExpanded: true,
                dropdownColor: AppTheme.surface,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                items: _freeModels
                    .map((m) => DropdownMenuItem(
                          value: m['id'],
                          child: Text(
                            m['name']!,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedModel = val),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // System prompt
          Text(
            'System Prompt',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: TextField(
              controller: _systemPromptController,
              maxLines: 5,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textPrimary,
                  ),
              decoration: InputDecoration(
                hintText: 'You are a helpful assistant...',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPlaceholder,
                    ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Wallet address
          Text(
            'Wallet Address',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: TextField(
              controller: _walletController,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontFamily: 'monospace',
                  ),
              decoration: InputDecoration(
                hintText: 'Solana wallet address',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPlaceholder,
                    ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // MCP Tools
          if (_mcpServers.isNotEmpty) ...[
            _SectionHeader(label: 'AI TOOLS (MCP)'),
            const SizedBox(height: 8),
            for (final server in _mcpServers)
              _McpToggleTile(
                server: server,
                onToggle: () => _toggleMcpServer(server),
              ),
            const SizedBox(height: 32),
          ],

          // Logout
          Center(
            child: TextButton(
              onPressed: () async {
                final router = GoRouter.of(context);
                await ref.read(authStateProvider.notifier).logout();
                router.go('/');
              },
              child: Text(
                'Log Out',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppTheme.textSecondary,
            ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: Theme.of(context).textTheme.bodyLarge),
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
      ),
    );
  }
}

class _ApiKeyInfoTile extends StatefulWidget {
  final List<ApiKey> apiKeys;
  final VoidCallback onManage;
  const _ApiKeyInfoTile({required this.apiKeys, required this.onManage});

  @override
  State<_ApiKeyInfoTile> createState() => _ApiKeyInfoTileState();
}

class _ApiKeyInfoTileState extends State<_ApiKeyInfoTile> {
  bool _copied = false;

  Future<void> _copyPrefix(String prefix) async {
    await Clipboard.setData(ClipboardData(text: prefix));
    if (mounted) setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final hasKeys = widget.apiKeys.isNotEmpty;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('API Key', style: Theme.of(context).textTheme.bodyLarge),
      subtitle: hasKeys
          ? GestureDetector(
              onTap: () => _copyPrefix(widget.apiKeys.first.keyPrefix),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.apiKeys.first.keyPrefix}••••••••',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _copied ? Icons.check : Icons.copy_outlined,
                    size: 13,
                    color: _copied ? Colors.green : AppTheme.textPlaceholder,
                  ),
                ],
              ),
            )
          : Text(
              'No keys — tap Manage to create one',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textPlaceholder,
              ),
            ),
      trailing: TextButton(
        onPressed: widget.onManage,
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.accentLink,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text('Manage', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _McpToggleTile extends StatelessWidget {
  final McpServer server;
  final VoidCallback onToggle;
  const _McpToggleTile({required this.server, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
          onChanged: (_) => onToggle(),
          activeThumbColor: AppTheme.accentLink,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings skeleton
// ---------------------------------------------------------------------------
class _SettingsSkeleton extends StatelessWidget {
  const _SettingsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      children: [
        // Avatar circle
        Center(
          child: SkeletonBox(width: 72, height: 72, radius: 36),
        ),
        const SizedBox(height: 12),
        // Email line
        Center(child: SkeletonBox(width: 160, height: 12)),
        const SizedBox(height: 8),
        // Plan badge
        Center(child: SkeletonBox(width: 52, height: 20, radius: 10)),
        const SizedBox(height: 32),

        // ACCOUNT section
        SkeletonBox(width: 72, height: 10),
        const SizedBox(height: 12),
        SkeletonBox(width: double.infinity, height: 44, radius: 8),
        const SizedBox(height: 24),

        // AI SETTINGS section
        SkeletonBox(width: 88, height: 10),
        const SizedBox(height: 12),
        // Model dropdown
        SkeletonBox(width: double.infinity, height: 48, radius: 12),
        const SizedBox(height: 16),
        // System prompt
        SkeletonBox(width: 110, height: 10),
        const SizedBox(height: 8),
        SkeletonBox(width: double.infinity, height: 110, radius: 12),
        const SizedBox(height: 16),
        // Wallet
        SkeletonBox(width: 100, height: 10),
        const SizedBox(height: 8),
        SkeletonBox(width: double.infinity, height: 48, radius: 12),
        const SizedBox(height: 32),

        // MCP section
        SkeletonBox(width: 96, height: 10),
        const SizedBox(height: 12),
        SkeletonBox(width: double.infinity, height: 64, radius: 12),
        const SizedBox(height: 8),
        SkeletonBox(width: double.infinity, height: 64, radius: 12),
      ],
    );
  }
}
