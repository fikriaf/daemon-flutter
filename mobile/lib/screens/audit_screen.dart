import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/sidebar_drawer.dart';
import '../theme/app_theme.dart';
import '../services/agent_service.dart';
import '../widgets/chat_engine.dart';

class AuditScreen extends ConsumerStatefulWidget {
  final ChatSession? initialSession;
  const AuditScreen({super.key, this.initialSession});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  late final ScrollController _chatScrollController;
  late final ChatController _chatController;
  bool _isChatActive = false;

  final List<Map<String, dynamic>> _quickPrompts = [
    {
      'icon': Icons.code,
      'title': 'Rust Security',
      'desc': 'Scan for unsafe blocks, memory issues',
      'prompt':
          'Perform a comprehensive security audit of this Rust code. Check for unsafe blocks, memory safety issues, integer overflow, and known CVE patterns.',
      'tag': 'Static Analysis',
    },
    {
      'icon': Icons.link,
      'title': 'Solana Audit',
      'desc': 'Smart contract vulnerabilities',
      'prompt':
          'Run a complete security audit on a Solana Anchor program for reentrancy, overflow, missing signer checks, and account validation issues.',
      'tag': 'Blockchain',
    },
    {
      'icon': Icons.tag,
      'title': 'Integer Overflow',
      'desc': 'Detect unchecked arithmetic bugs',
      'prompt':
          'Check for integer overflow and unchecked arithmetic operations in code with formal verification and checked-math analysis.',
      'tag': 'Math Safety',
    },
    {
      'icon': Icons.smart_toy,
      'title': 'AI Red Team',
      'desc': 'Prompt injection testing',
      'prompt':
          'Test for prompt injection and jailbreak vulnerabilities in an LLM-based system using adversarial prompts and red-team techniques.',
      'tag': 'AI Security',
    },
  ];

  @override
  void initState() {
    super.initState();
    _chatScrollController = ScrollController();
    _chatController = ChatController(
      setState: setState,
      scrollController: _chatScrollController,
      onLoginRequired: _onLoginRequired,
      onError: (msg) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      },
    );
    _chatController.loadInitialData();
  }

  @override
  void dispose() {
    _chatScrollController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _onSessionTap(ChatSession session) {
    setState(() => _isChatActive = true);
    _chatController.loadSession(session);
  }

  void _onLoginRequired() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Please log in to continue')));
    context.push('/login');
  }

  String _buildContextPrefix() {
    return 'You are an AI assistant in the Audit section of the Daemon app. '
        'Audit provides automated smart contract and code security analysis. '
        'Help users with security audits, vulnerability assessments, and code review.';
  }

  String _buildContextLabel() {
    return 'Audit · security analysis';
  }

  void _onQuickPrompt(String prompt) {
    _chatController.textController.text = prompt;
    _chatController.handleSubmit();
    setState(() => _isChatActive = true);
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.toString();
    final showDrawer = !currentPath.startsWith('/sandbox');

    if (_isChatActive || _chatController.messages.isNotEmpty) {
      return _buildChatView(showDrawer: showDrawer);
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      drawer: showDrawer ? SidebarDrawer(onSessionTap: _onSessionTap) : null,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Audit',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        leading: showDrawer
            ? IconButton(
                icon: const Icon(Icons.menu, color: AppTheme.textPrimary),
                onPressed: () => Scaffold.of(context).openDrawer(),
              )
            : null,
      ),
      body: SafeArea(child: _buildLandingView()),
    );
  }

  Widget _buildLandingView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Security Audit',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Automated smart contract & code security analysis',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          const Text(
            'Quick Start',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(_quickPrompts.length, (i) {
            final item = _quickPrompts[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _onQuickPrompt(item['prompt'] as String),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            item['icon'] as IconData,
                            color: Colors.purple,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title'] as String,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                item['desc'] as String,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item['tag'] as String,
                            style: const TextStyle(
                              color: Colors.purple,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChatView({required bool showDrawer}) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Audit',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () {
            setState(() => _isChatActive = false);
            _chatController.messages.clear();
            _chatController.textController.clear();
          },
        ),
      ),
      body: ChatMessagesView(
        messages: _chatController.messages,
        sources: _chatController.sources,
        isSearching: _chatController.isSearching,
        scrollController: _chatScrollController,
        contextSummary: _buildContextLabel(),
        contextIcon: Icons.security,
        onEdit: (idx, newText) => _chatController.editMessage(
          idx,
          newText,
          contextPrefix: _buildContextPrefix(),
          contextLabel: _buildContextLabel(),
        ),
        onDelete: (idx) => _chatController.deleteMessage(idx),
        onLikeChanged: (idx, state) =>
            setState(() => _chatController.messages[idx].likeState = state),
        onShare: (_) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Copied to clipboard'))),
      ),
      bottomNavigationBar: ChatInputBar(
        controller: _chatController,
        contextPrefixBuilder: _buildContextPrefix,
        contextLabelBuilder: _buildContextLabel,
        contextLabel: _buildContextLabel(),
        contextIcon: Icons.security,
        onBeforeSubmit: () async {
          if (mounted) setState(() => _isChatActive = true);
        },
      ),
    );
  }
}
