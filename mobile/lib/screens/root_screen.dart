import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/sidebar_drawer.dart';
import '../widgets/history_drawer.dart';
import '../widgets/global_chat_input.dart';
import '../widgets/address_graph_widget.dart';
import '../theme/app_theme.dart';
import '../config/api_config.dart';
import '../services/provider.dart';
import '../services/agent_service.dart';
import '../services/error_handler.dart';

// Streaming step status — determines label shown in the status indicator
enum StreamStep { thinking, writing, executingTool, searching, fetching, done }

class RootScreen extends StatefulWidget {
  final ChatSession? initialSession;
  const RootScreen({super.key, this.initialSession});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

// ─── Block-based message model ───────────────────────────────────────────────

enum BlockType { reasoning, toolCall, content }

class MessageBlock {
  final BlockType type;
  // For reasoning
  String reasoning;
  bool reasoningDone; // true once a non-reasoning block follows
  // For toolCall
  String? toolName;
  Map<String, dynamic>? toolArgs;
  Map<String, dynamic>? toolResult; // null = still running
  // For content
  String contentChunk; // accumulated markdown text

  MessageBlock.reasoning(this.reasoning)
      : type = BlockType.reasoning,
        reasoningDone = false,
        contentChunk = '';

  MessageBlock.toolCall(this.toolName, this.toolArgs)
      : type = BlockType.toolCall,
        reasoning = '',
        reasoningDone = false,
        contentChunk = '';

  MessageBlock.content(this.contentChunk)
      : type = BlockType.content,
        reasoning = '',
        reasoningDone = false;
}

class ChatMessage {
  final String role; // 'user' | 'assistant'
  // For user messages
  final String userContent;
  // For assistant messages — ordered list of blocks as they arrived in stream
  final List<MessageBlock> blocks;

  // Metadata
  final DateTime timestamp;
  String? modelName; // set after stream starts
  int stepCount; // incremented per reasoning/tool/content block added
  StreamStep streamStep; // current stream phase
  int likeState; // 0=none, 1=liked, -1=unliked
  /// Graph data injected by backend after a graph tool call.
  /// Set on `done` event so graph only appears when streaming ends.
  Map<String, dynamic>? graphData;

  ChatMessage.user(this.userContent)
      : role = 'user',
        blocks = [],
        timestamp = DateTime.now(),
        modelName = null,
        stepCount = 0,
        streamStep = StreamStep.done,
        likeState = 0;

  ChatMessage.assistant({this.modelName})
      : role = 'assistant',
        userContent = '',
        blocks = [],
        timestamp = DateTime.now(),
        stepCount = 0,
        streamStep = StreamStep.thinking,
        likeState = 0;

  // Helper for backwards-compat when loading history (plain text)
  ChatMessage.assistantText(String text)
      : role = 'assistant',
        userContent = '',
        blocks = [MessageBlock.content(text)],
        timestamp = DateTime.now(),
        modelName = null,
        stepCount = 1,
        streamStep = StreamStep.done,
        likeState = 0;

  String get fullContent => blocks
      .where((b) => b.type == BlockType.content)
      .map((b) => b.contentChunk)
      .join();
}

class Source {
  final String title;
  final String domain;
  final String url;
  Source({required this.title, required this.domain, required this.url});
}

// ─── Screen state ─────────────────────────────────────────────────────────────

class _RootScreenState extends State<RootScreen> {
  bool _isChatActive = false;
  bool _isSearching = false;
  String _activeTab = 'answer';
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  AgentInfo? _agentInfo;
  String? _selectedModelId;
  String? _selectedModelName;

  final List<ChatMessage> _messages = [];
  List<Source> _sources = [];
  String? _currentSessionId;
  // Temporary holder for graph_data received before the `done` event.
  Map<String, dynamic>? _pendingGraphData;

  // Typewriter animation
  final List<String> _animatedWords = ['know', 'interact', 'analyze'];
  int _currentWordIndex = 0;
  String _currentDisplayedText = '';
  Timer? _typewriterTimer;
  Timer? _delayTimer;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _startTypewriterAnimation();

    // If a session was passed (from sidebar history tap), load it immediately
    if (widget.initialSession != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSession(widget.initialSession!);
      });
    }
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    _delayTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadInitialData() async {
    try {
      final agentInfo = await apiProvider.agentService.getAgentMe();
      if (mounted) {
        setState(() {
          _agentInfo = agentInfo;
        });
      }
    } catch (e) {
      if (mounted && isAuthError(e)) _showLoginRequired();
    }
  }

  void _showLoginRequired() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Please login to continue'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Login',
          textColor: Colors.white,
          onPressed: () => context.push('/login'),
        ),
      ),
    );
  }

  Future<void> _loadSession(ChatSession session) async {
    _typewriterTimer?.cancel();
    _delayTimer?.cancel();
    setState(() {
      _isChatActive = true;
      _activeTab = 'answer';
      _isSearching = true;
      _messages.clear();
      _sources.clear();
      _currentSessionId = session.id;
    });
    try {
      final msgs = await apiProvider.agentService.getChatMessages(session.id);
      if (mounted) {
        setState(() {
          for (final m in msgs) {
            if (m.role == 'user') {
              _messages.add(ChatMessage.user(m.content));
            } else {
              _messages.add(ChatMessage.assistantText(m.content));
            }
          }
          _isSearching = false;
        });
        _scrollToBottom();
      }
    } catch (e, st) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load session: $e')),
        );
      }
    }
  }

  void _startTypewriterAnimation() {
    if (_isChatActive) return;
    final String targetWord = _animatedWords[_currentWordIndex];
    if (_isDeleting) {
      if (_currentDisplayedText.isNotEmpty) {
        setState(() {
          _currentDisplayedText = _currentDisplayedText.substring(
              0, _currentDisplayedText.length - 1);
        });
        _typewriterTimer =
            Timer(const Duration(milliseconds: 50), _startTypewriterAnimation);
      } else {
        _isDeleting = false;
        _currentWordIndex = (_currentWordIndex + 1) % _animatedWords.length;
        _typewriterTimer = Timer(
            const Duration(milliseconds: 200), _startTypewriterAnimation);
      }
    } else {
      if (_currentDisplayedText.length < targetWord.length) {
        setState(() {
          _currentDisplayedText =
              targetWord.substring(0, _currentDisplayedText.length + 1);
        });
        _typewriterTimer = Timer(
            const Duration(milliseconds: 100), _startTypewriterAnimation);
      } else {
        _isDeleting = true;
        _delayTimer =
            Timer(const Duration(seconds: 2), _startTypewriterAnimation);
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (_textController.text.trim().isEmpty) return;
    final userMessage = _textController.text.trim();
    _typewriterTimer?.cancel();
    _delayTimer?.cancel();

    final modelId = _selectedModelId ??
        _agentInfo?.defaultModelId ??
        'stepfun/step-3.5-flash:free';
    final modelDisplayName = _selectedModelName ??
        modelId.split('/').last.split(':').first;

    setState(() {
      _isChatActive = true;
      _isSearching = true;
      _activeTab = 'answer';
      _messages.add(ChatMessage.user(userMessage));
      _messages.add(ChatMessage.assistant(modelName: modelDisplayName));
      _sources = [];
      _pendingGraphData = null;
    });
    _textController.clear();
    _scrollToBottom();
    await _streamChat(userMessage);
  }

  Future<void> _streamChat(String message) async {
    if (!apiProvider.isAuthenticated) {
      _showLoginRequired();
      return;
    }
    final model = _selectedModelId ??
        _agentInfo?.defaultModelId ??
        'stepfun/step-3.5-flash:free';

    try {
      // Build history excluding the empty assistant slot at end
      final historyMessages = _messages
          .where((m) => !(m.role == 'assistant' && m.fullContent.isEmpty && m.blocks.isEmpty))
          .map((m) => {'role': m.role, 'content': m.role == 'user' ? m.userContent : m.fullContent})
          .toList();

      final stream = apiProvider.agentService.api.streamPost(
        '/v1/chat/completions',
        {
          'model': model,
          'messages': historyMessages,
          'stream': true,
          if (_currentSessionId != null) 'session_id': _currentSessionId,
        },
      );

      await for (final dataStr in stream) {
        debugPrint('Stream: $dataStr');
        try {
          final data = jsonDecode(dataStr) as Map<String, dynamic>;
          final type = data['type'] as String?;

          if (type == 'reasoning') {
            final text = (data['reasoning'] as String?) ?? '';
            setState(() {
              final last = _messages.last;
              last.streamStep = StreamStep.thinking;
              // Only append to the last block if it's ALREADY a reasoning block.
              // Otherwise create a NEW reasoning block (preserves order:
              //   reasoning → tool → reasoning → content stays as 4 separate blocks).
              if (last.blocks.isNotEmpty &&
                  last.blocks.last.type == BlockType.reasoning) {
                last.blocks.last.reasoning += text;
              } else {
                last.blocks.add(MessageBlock.reasoning(text));
                last.stepCount++;
              }
            });
            _scrollToBottom();
          } else if (type == 'tool_call') {
            final toolName = (data['tool'] as String?) ?? '';
            final rawArgs = data['arguments'];
            final args = rawArgs is String
                ? (jsonDecode(rawArgs) as Map<String, dynamic>? ?? {})
                : (rawArgs as Map<String, dynamic>? ?? {});
            setState(() {
              final last = _messages.last;
              // Determine tool step label from tool name
              final lowerTool = toolName.toLowerCase();
              if (lowerTool.contains('search') || lowerTool.contains('web')) {
                last.streamStep = StreamStep.searching;
              } else if (lowerTool.contains('fetch') || lowerTool.contains('browse') || lowerTool.contains('http')) {
                last.streamStep = StreamStep.fetching;
              } else {
                last.streamStep = StreamStep.executingTool;
              }
              // Mark any open reasoning block as done
              for (final b in last.blocks) {
                if (b.type == BlockType.reasoning) b.reasoningDone = true;
              }
              last.blocks.add(MessageBlock.toolCall(toolName, args));
              last.stepCount++;
            });
            _scrollToBottom();
          } else if (type == 'tool_result') {
            final result = data['result'];
            setState(() {
              final last = _messages.last;
              final chip = last.blocks
                  .where((b) => b.type == BlockType.toolCall && b.toolResult == null)
                  .lastOrNull;
              if (chip != null) {
                chip.toolResult = result is Map<String, dynamic>
                    ? result
                    : {'raw': result.toString()};
              }
            });
          } else if (type == 'content') {
            final chunk = (data['content'] as String?) ?? '';
            setState(() {
              final last = _messages.last;
              last.streamStep = StreamStep.writing;
              // Mark all reasoning blocks done once content arrives
              for (final b in last.blocks) {
                if (b.type == BlockType.reasoning) b.reasoningDone = true;
              }
              // Only append to last block if it's already a content block.
              // Otherwise create a new content block (preserves order after tools).
              if (last.blocks.isNotEmpty &&
                  last.blocks.last.type == BlockType.content) {
                last.blocks.last.contentChunk += chunk;
              } else {
                last.blocks.add(MessageBlock.content(chunk));
                last.stepCount++;
              }
            });
            _scrollToBottom();
          } else if (type == 'graph_data') {
            // Store temporarily; applied to message on `done`
            final nodes = data['nodes'];
            final edges = data['edges'];
            _pendingGraphData = {'nodes': nodes, 'edges': edges};
            debugPrint('Graph data stored: ${(nodes as List?)?.length ?? 0} nodes, ${(edges as List?)?.length ?? 0} edges');
          } else if (type == 'done') {
            final newSessionId = data['session_id'] as String?;
            if (newSessionId != null) {
              setState(() => _currentSessionId = newSessionId);
            }
            final rawSources = data['sources'];
            if (rawSources is List && rawSources.isNotEmpty) {
              setState(() {
                _sources = rawSources
                    .map((s) => Source(
                          title: (s['title'] as String?) ?? '',
                          domain: (s['domain'] as String?) ?? '',
                          url: (s['url'] as String?) ?? '',
                        ))
                    .toList();
              });
            }
            // Attach graph data + mark done in one setState so
            // (!_isSearching && msg.graphData != null) is true in same rebuild.
            final captured = _pendingGraphData;
            _pendingGraphData = null;
            setState(() {
              _isSearching = false;
              if (_messages.isNotEmpty && _messages.last.role == 'assistant') {
                _messages.last.streamStep = StreamStep.done;
                if (captured != null) {
                  _messages.last.graphData = captured;
                  debugPrint('Graph data attached: ${(captured['nodes'] as List?)?.length ?? 0} nodes');
                }
              }
            });
            // Scroll after frame so the graph widget has been laid out.
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
          }
        } catch (e) {
          debugPrint('Parse error: $e');
        }
      }

      setState(() {
        _isSearching = false;
        if (_messages.isNotEmpty && _messages.last.role == 'assistant') {
          _messages.last.streamStep = StreamStep.done;
        }
      });
    } catch (e) {
      debugPrint('Chat error: $e');
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('insufficient') ||
          errorStr.contains('balance') ||
          errorStr.contains('model_not_found')) {
        await _tryFallbackModel(message);
        return;
      }
      if (isAuthError(e)) {
        _showLoginRequired();
        return;
      }
      setState(() {
        _isSearching = false;
        if (_messages.isNotEmpty && _messages.last.role == 'assistant') {
          final last = _messages.last;
          last.streamStep = StreamStep.done;
          if (last.blocks.isEmpty) {
            last.blocks.add(MessageBlock.content('Error: $e'));
          }
        }
      });
    }
  }

  Future<void> _tryFallbackModel(String message) async {
    try {
      final fallbackModels = [
        'stepfun/step-3.5-flash:free',
        'arcee-ai/trinity-large-preview:free'
      ];
      for (final fallbackModel in fallbackModels) {
        try {
          final response = await apiProvider.agentService.api.post(
            '/v1/chat/completions',
            {
              'model': fallbackModel,
              'messages': [
                {'role': 'user', 'content': message}
              ],
              'stream': false,
            },
          );
          if (response['choices'] != null &&
              (response['choices'] as List).isNotEmpty) {
            final content =
                response['choices'][0]['message']['content'] ?? 'No response';
            setState(() {
              _isSearching = false;
              if (_messages.isNotEmpty &&
                  _messages.last.role == 'assistant') {
                final last = _messages.last;
                last.streamStep = StreamStep.done;
                last.blocks.clear();
                last.blocks.add(MessageBlock.content(content as String));
                last.stepCount = 1;
              }
            });
            return;
          }
        } catch (e2) {
          debugPrint('Fallback $fallbackModel failed: $e2');
        }
      }
      throw Exception('All models failed. Please try again later.');
    } catch (e) {
      setState(() {
        _isSearching = false;
        if (_messages.isNotEmpty && _messages.last.role == 'assistant') {
          _messages.last.blocks
              .add(MessageBlock.content('Error: $e'));
        }
      });
    }
  }

  // ─── AppBars ──────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildHomeAppBar() {
    return AppBar(
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
      actions: [
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.history, color: AppTheme.textSecondary),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildChatAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          setState(() {
            _isChatActive = false;
            _activeTab = 'answer';
            _textController.clear();
            _messages.clear();
            _sources.clear();
            _currentSessionId = null;
          });
        },
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _activeTab = 'answer'),
            child: _TopNavTab(
                title: 'Answer',
                icon: Icons.flash_on,
                isActive: _activeTab == 'answer'),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () {
              if (_sources.isNotEmpty) {
                setState(() => _activeTab = 'links');
              } else {
                _showSourcesSheet();
              }
            },
            child: _TopNavTab(
                title: 'Links',
                icon: Icons.link,
                isActive: _activeTab == 'links'),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, color: AppTheme.textSecondary),
          onPressed: _shareResponse,
        ),
        IconButton(
          icon: const Icon(Icons.more_horiz, color: AppTheme.textSecondary),
          onPressed: _showMoreMenu,
        ),
      ],
    );
  }

  void _showSourcesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _SourcesSheet(sources: _sources),
    );
  }

  void _shareResponse() {
    final lastAssistant = _messages
        .where((m) => m.role == 'assistant' && m.fullContent.isNotEmpty)
        .lastOrNull;
    if (lastAssistant == null) return;
    Clipboard.setData(ClipboardData(text: lastAssistant.fullContent));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Response copied to clipboard'),
          duration: Duration(seconds: 2)),
    );
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ChatMoreSheet(
        onCopyResponse: () {
          Navigator.pop(ctx);
          _shareResponse();
        },
        onNewChat: () {
          Navigator.pop(ctx);
          setState(() {
            _isChatActive = false;
            _activeTab = 'answer';
            _messages.clear();
            _sources.clear();
            _textController.clear();
            _currentSessionId = null;
          });
        },
      ),
    );
  }

  // ─── Body builders ────────────────────────────────────────────────────────

  Widget _buildHomeBody() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('What do you want to ',
                      style: Theme.of(context).textTheme.displaySmall,
                      textAlign: TextAlign.center),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentDisplayedText,
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(color: AppTheme.accentLink),
                      ),
                      AnimatedBuilder(
                        animation: AlwaysStoppedAnimation(
                            DateTime.now().millisecondsSinceEpoch),
                        builder: (context, child) => Opacity(
                          opacity:
                              (DateTime.now().millisecondsSinceEpoch % 1000 <
                                      500)
                                  ? 1.0
                                  : 0.0,
                          child: Text('|',
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(color: AppTheme.accentLink)),
                        ),
                      ),
                    ],
                  ),
                  Text('?', style: Theme.of(context).textTheme.displaySmall),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatBody() {
    if (_activeTab == 'links') return _buildLinksBody();

    // Pre-compute last assistant message once (avoids O(n²) in build)
    final lastAssistantMsg =
        _messages.where((m) => m.role == 'assistant').lastOrNull;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (idx, msg) in _messages.indexed)
            if (msg.role == 'user')
              _AnimatedEntry(
                key: ValueKey('user_$idx'),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _UserBubble(
                    message: msg,
                    onEdit: (newText) => _editUserMessage(idx, newText),
                    onDelete: () => _deleteUserMessage(idx),
                  ),
                ),
              )
            else
              Padding(
                key: ValueKey('ai_$idx'),
                padding: const EdgeInsets.only(bottom: 24),
                child: _buildAIBubble(msg, msgIdx: idx,
                    isLast: identical(msg, lastAssistantMsg)),
              ),

          // Thinking indicator: only while waiting for the very first block.
          // Disappears as soon as any block (reasoning/tool/content) arrives.
          if (_isSearching &&
              (_messages.isEmpty ||
                  _messages.last.role != 'assistant' ||
                  _messages.last.blocks.isEmpty))
            const _ThinkingIndicator(),
        ],
      ),
    );
  }

  void _editUserMessage(int userIdx, String newText) {
    setState(() {
      // Replace the user message text
      final newUserMsg = ChatMessage.user(newText);
      // Remove all messages from userIdx onwards, then re-add the edited user message
      _messages.removeRange(userIdx, _messages.length);
      _messages.add(newUserMsg);
    });
    // Re-submit with the new text
    _textController.text = newText;
    // Add a fresh assistant slot and stream
    final modelId = _selectedModelId ??
        _agentInfo?.defaultModelId ??
        'stepfun/step-3.5-flash:free';
    final modelDisplayName = _selectedModelName ??
        modelId.split('/').last.split(':').first;
    setState(() {
      _isSearching = true;
      _messages.add(ChatMessage.assistant(modelName: modelDisplayName));
      _sources = [];
    });
    _textController.clear();
    _scrollToBottom();
    _streamChat(newText);
  }

  void _deleteUserMessage(int userIdx) {
    setState(() {
      // Remove user message + everything after it
      _messages.removeRange(userIdx, _messages.length);
      _isSearching = false;
    });
  }

  Widget _buildLinksBody() {
    if (_sources.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off, color: AppTheme.textSecondary, size: 40),
            const SizedBox(height: 12),
            Text('No sources for this response',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _sources.length,
      itemBuilder: (context, i) {
        final s = _sources[i];
        return _SourceItem(title: s.title, domain: s.domain, url: s.url);
      },
    );
  }

  Widget _buildAIBubble(ChatMessage msg, {required int msgIdx, required bool isLast}) {
    final isStreaming = isLast && _isSearching;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Stream status indicator (always at TOP of AI response) ──
        _AnimatedEntry(
          key: ValueKey('status_$msgIdx'),
          child: _StreamStatusIndicator(
            step: msg.streamStep,
            stepCount: msg.stepCount,
            modelName: msg.modelName ?? '',
            isStreaming: isStreaming,
          ),
        ),
        const SizedBox(height: 8),

        // Render blocks in the exact order they arrived from the stream
        for (int i = 0; i < msg.blocks.length; i++)
          _AnimatedEntry(
            key: ValueKey('block_${msgIdx}_$i'),
            child: _buildBlock(msg.blocks[i],
                isLast: isLast,
                isStreaming: isStreaming),
          ),

        // Sources — only for the last assistant message, after streaming done
        if (!_isSearching && isLast && _sources.isNotEmpty) ...[
          const SizedBox(height: 16),
          _AnimatedEntry(
            key: ValueKey('sources_$msgIdx'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sources',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: AppTheme.accentLink)),
                const SizedBox(height: 8),
                for (final source in _sources)
                  _SourceItem(
                      title: source.title,
                      domain: source.domain,
                      url: source.url),
              ],
            ),
          ),
        ],

        // Address graph — shown after streaming ends if backend sent graph_data
        if (!_isSearching && isLast && msg.graphData != null) ...[
          const SizedBox(height: 16),
          _AnimatedEntry(
            key: ValueKey('graph_$msgIdx'),
            child: AddressGraphWidget(graphData: msg.graphData!),
          ),
        ],

        // ── AI action bar: timestamp + share + like/unlike ──
        const SizedBox(height: 8),
        _AIActionBar(
          message: msg,
          onLikeChanged: (state) => setState(() => msg.likeState = state),
          onShare: () {
            Clipboard.setData(ClipboardData(text: msg.fullContent));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Response copied to clipboard'),
                  duration: Duration(seconds: 2)),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBlock(MessageBlock block,
      {required bool isLast, required bool isStreaming}) {
    switch (block.type) {
      case BlockType.reasoning:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ReasoningBlock(
            reasoning: block.reasoning,
            isStreaming: isLast && isStreaming && !block.reasoningDone,
          ),
        );
      case BlockType.toolCall:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ToolChip(block: block),
        );
      case BlockType.content:
        if (block.contentChunk.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: MarkdownBody(
            data: block.contentChunk,
            styleSheet: MarkdownStyleSheet(
              p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    height: 1.6,
                  ),
              h1: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
              h2: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
              h3: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
              code: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.accentLink,
                    backgroundColor: AppTheme.surface,
                    fontFamily: 'monospace',
                  ),
              codeblockDecoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderLight),
              ),
              blockquoteDecoration: BoxDecoration(
                border: Border(
                    left: BorderSide(
                        color: AppTheme.accentLink.withValues(alpha: 0.5),
                        width: 3)),
              ),
              blockquote: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: SidebarDrawer(onSessionTap: _loadSession),
      endDrawer: HistoryDrawer(onSessionTap: _loadSession),
      resizeToAvoidBottomInset: false,
      appBar: _isChatActive ? _buildChatAppBar() : _buildHomeAppBar(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Expanded(
          child: _isChatActive ? _buildChatBody() : _buildHomeBody(),
        ),
        Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: GlobalChatInput(
            controller: _textController,
            onSubmit: _handleSubmit,
            selectedModelId: _selectedModelId,
            selectedModelName: _selectedModelName,
            onModelChanged: (modelId) {
              final short = ApiConfig.shortLabelForModel(modelId)
                  ?? modelId.split('/').last.split(':').first;
              setState(() {
                _selectedModelId = modelId;
                _selectedModelName = short;
              });
            },
          ),
        ),
      ],
    );
  }
}

// ─── Smooth entry animation ───────────────────────────────────────────────────

class _AnimatedEntry extends StatefulWidget {
  final Widget child;
  const _AnimatedEntry({super.key, required this.child});

  @override
  State<_AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<_AnimatedEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─── Top nav tab ──────────────────────────────────────────────────────────────

class _TopNavTab extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isActive;
  const _TopNavTab(
      {required this.title, required this.icon, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: isActive
            ? const Border(
                bottom: BorderSide(color: AppTheme.textPrimary, width: 2))
            : null,
      ),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary),
          const SizedBox(width: 4),
          if (isActive)
            Text(title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    )),
        ],
      ),
    );
  }
}

// ─── Thinking indicator ───────────────────────────────────────────────────────

class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator();

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 1500), vsync: this)
      ..repeat();
    _anim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.accentLink.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome,
                  color: AppTheme.accentLink, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thinking',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        )),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(3, (i) {
                    final opacity = ((_anim.value + i * 0.2) % 1.0)
                        .clamp(0.3, 1.0);
                    return Container(
                      margin: const EdgeInsets.only(right: 4),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color:
                            AppTheme.accentLink.withValues(alpha: opacity),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reasoning block ──────────────────────────────────────────────────────────

class _ReasoningBlock extends StatefulWidget {
  final String reasoning;
  final bool isStreaming; // true = currently receiving tokens

  const _ReasoningBlock({required this.reasoning, this.isStreaming = false});

  @override
  State<_ReasoningBlock> createState() => _ReasoningBlockState();
}

class _ReasoningBlockState extends State<_ReasoningBlock>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late final AnimationController _ctrl;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    // Auto-expand while streaming
    _expanded = widget.isStreaming;
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _expandAnim =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    if (_expanded) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_ReasoningBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When streaming ends, collapse automatically
    if (oldWidget.isStreaming && !widget.isStreaming && _expanded) {
      _toggle();
    }
    // If newly started streaming, expand
    if (!oldWidget.isStreaming && widget.isStreaming && !_expanded) {
      _toggle();
    }
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: widget.isStreaming
                ? AppTheme.accentLink.withValues(alpha: 0.4)
                : AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  if (widget.isStreaming)
                    _PulsingDot()
                  else
                    const Icon(Icons.auto_awesome,
                        size: 14, color: AppTheme.accentLink),
                  const SizedBox(width: 8),
                  Text(
                    widget.isStreaming ? 'Reasoning...' : 'Reasoning',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.accentLink,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(Icons.expand_more,
                        size: 16, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _expandAnim,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                widget.reasoning,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.6,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pulsing dot (used in reasoning header while streaming) ───────────────────

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AppTheme.accentLink.withValues(alpha: _anim.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─── Tool call chip ───────────────────────────────────────────────────────────

class _ToolChip extends StatefulWidget {
  final MessageBlock block;
  const _ToolChip({required this.block});

  @override
  State<_ToolChip> createState() => _ToolChipState();
}

class _ToolChipState extends State<_ToolChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _checkScale;
  bool _wasNull = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _checkScale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _wasNull = widget.block.toolResult == null;
    if (!_wasNull) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_ToolChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_wasNull && widget.block.toolResult != null) {
      _wasNull = false;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _labelFor(String name) {
    // Convert snake_case / camelCase to readable label
    return name
        .replaceAll('_', ' ')
        .replaceAllMapped(
            RegExp(r'([A-Z])'), (m) => ' ${m.group(1)!.toLowerCase()}')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final isDone = widget.block.toolResult != null;
    final label = _labelFor(widget.block.toolName ?? 'tool');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDone
            ? AppTheme.accentLink.withValues(alpha: 0.1)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone
              ? AppTheme.accentLink.withValues(alpha: 0.4)
              : AppTheme.borderLight,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDone)
            ScaleTransition(
              scale: _checkScale,
              child: const Icon(Icons.check_circle_outline,
                  size: 13, color: AppTheme.accentLink),
            )
          else
            _SpinnerIcon(),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isDone ? AppTheme.accentLink : AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

// ─── Spinner icon (for pending tool call) ─────────────────────────────────────

class _SpinnerIcon extends StatefulWidget {
  const _SpinnerIcon();
  @override
  State<_SpinnerIcon> createState() => _SpinnerIconState();
}

class _SpinnerIconState extends State<_SpinnerIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _ctrl,
      child: const Icon(Icons.sync, size: 13, color: AppTheme.textSecondary),
    );
  }
}

// ─── Stream status indicator ─────────────────────────────────────────────────

class _StreamStatusIndicator extends StatefulWidget {
  final StreamStep step;
  final int stepCount;
  final String modelName;
  final bool isStreaming;

  const _StreamStatusIndicator({
    required this.step,
    required this.stepCount,
    required this.modelName,
    required this.isStreaming,
  });

  @override
  State<_StreamStatusIndicator> createState() => _StreamStatusIndicatorState();
}

class _StreamStatusIndicatorState extends State<_StreamStatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmer;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _shimmer = Tween<double>(begin: -2, end: 2).animate(
        CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_StreamStatusIndicator old) {
    super.didUpdateWidget(old);
    if (!widget.isStreaming && old.isStreaming) {
      _shimmerCtrl.stop();
    } else if (widget.isStreaming && !old.isStreaming) {
      _shimmerCtrl.repeat();
    }
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  String _labelForStep(StreamStep step) {
    switch (step) {
      case StreamStep.thinking:
        return 'Thinking';
      case StreamStep.writing:
        return 'Writing';
      case StreamStep.executingTool:
        return 'Execute Tool';
      case StreamStep.searching:
        return 'Searching';
      case StreamStep.fetching:
        return 'Fetching';
      case StreamStep.done:
        return 'Done';
    }
  }

  IconData _iconForStep(StreamStep step) {
    switch (step) {
      case StreamStep.thinking:
        return Icons.psychology_outlined;
      case StreamStep.writing:
        return Icons.edit_outlined;
      case StreamStep.executingTool:
        return Icons.terminal_outlined;
      case StreamStep.searching:
        return Icons.search;
      case StreamStep.fetching:
        return Icons.download_outlined;
      case StreamStep.done:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.modelName.isNotEmpty ? widget.modelName : 'AI';
    final isDone = !widget.isStreaming;

    if (isDone) {
      // Done state: "Executed N steps (model) >"
      final count = widget.stepCount;
      final label = 'Executed $count step${count == 1 ? '' : 's'} ($model)';
      return GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 13, color: AppTheme.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            AnimatedRotation(
              turns: _expanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 180),
              child: const Icon(Icons.chevron_right,
                  size: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    // Streaming state: shimmer label
    final label = '${_labelForStep(widget.step)}... ($model)';
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(_shimmer.value - 1, 0),
              end: Alignment(_shimmer.value + 1, 0),
              colors: [
                AppTheme.textSecondary,
                AppTheme.accentLink,
                AppTheme.textSecondary,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_iconForStep(widget.step),
                  size: 13, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(width: 4),
              _PulsingDot(),
            ],
          ),
        );
      },
    );
  }
}

// ─── AI action bar (timestamp + share + like/unlike) ─────────────────────────

class _AIActionBar extends StatelessWidget {
  final ChatMessage message;
  final ValueChanged<int> onLikeChanged;
  final VoidCallback onShare;

  const _AIActionBar({
    required this.message,
    required this.onLikeChanged,
    required this.onShare,
  });

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          _formatTime(message.timestamp),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
              ),
        ),
        const Spacer(),
        // Share
        _ActionIconBtn(
          icon: Icons.share_outlined,
          onTap: onShare,
        ),
        const SizedBox(width: 4),
        // Like
        _ActionIconBtn(
          icon: message.likeState == 1
              ? Icons.thumb_up
              : Icons.thumb_up_outlined,
          active: message.likeState == 1,
          onTap: () => onLikeChanged(message.likeState == 1 ? 0 : 1),
        ),
        const SizedBox(width: 4),
        // Unlike
        _ActionIconBtn(
          icon: message.likeState == -1
              ? Icons.thumb_down
              : Icons.thumb_down_outlined,
          active: message.likeState == -1,
          onTap: () => onLikeChanged(message.likeState == -1 ? 0 : -1),
        ),
      ],
    );
  }
}

class _ActionIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _ActionIconBtn({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 15,
          color: active ? AppTheme.accentLink : AppTheme.textSecondary,
        ),
      ),
    );
  }
}

// ─── User bubble (with timestamp + hover edit/delete) ─────────────────────────

class _UserBubble extends StatefulWidget {
  final ChatMessage message;
  final ValueChanged<String> onEdit;
  final VoidCallback onDelete;

  const _UserBubble({
    required this.message,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_UserBubble> createState() => _UserBubbleState();
}

class _UserBubbleState extends State<_UserBubble> {
  bool _hovered = false;

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _showEditDialog(BuildContext context) {
    final ctrl = TextEditingController(text: widget.message.userContent);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          'Edit message',
          style: Theme.of(ctx).textTheme.titleMedium,
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: null,
          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimary,
              ),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.accentLink),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final newText = ctrl.text.trim();
              Navigator.pop(ctx);
              if (newText.isNotEmpty) widget.onEdit(newText);
            },
            child: Text('Send',
                style: TextStyle(color: AppTheme.accentLink)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Edit/Delete buttons — show on hover (or long press on mobile)
              AnimatedOpacity(
                opacity: _hovered ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: Row(
                  children: [
                    _ActionIconBtn(
                      icon: Icons.edit_outlined,
                      onTap: () => _showEditDialog(context),
                    ),
                    _ActionIconBtn(
                      icon: Icons.delete_outline,
                      onTap: widget.onDelete,
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
              // Bubble
              GestureDetector(
                onLongPress: () => setState(() => _hovered = !_hovered),
                child: Container(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    widget.message.userContent,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textPrimary,
                        ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              _formatTime(widget.message.timestamp),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Source item ──────────────────────────────────────────────────────────────

class _SourceItem extends StatelessWidget {
  final String title;
  final String domain;
  final String url;
  const _SourceItem(
      {required this.title, required this.domain, required this.url});

  Future<void> _open() async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: url.isNotEmpty ? _open : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                  color: AppTheme.borderLight.withValues(alpha: 0.5),
                  shape: BoxShape.circle),
              child: const Icon(Icons.article_outlined,
                  size: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (domain.isNotEmpty)
                    Text(domain,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (url.isNotEmpty)
              const Icon(Icons.open_in_new,
                  size: 14, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom sheets ────────────────────────────────────────────────────────────

class _SourcesSheet extends StatelessWidget {
  final List<Source> sources;
  const _SourcesSheet({required this.sources});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.borderLight,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.link, size: 18, color: AppTheme.accentLink),
                const SizedBox(width: 8),
                Text('Sources (${sources.length})',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: AppTheme.borderLight, height: 1),
          Expanded(
            child: sources.isEmpty
                ? Center(
                    child: Text('No sources',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppTheme.textSecondary)))
                : ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: sources.length,
                    separatorBuilder: (_, i) =>
                        const Divider(color: AppTheme.borderLight, height: 1),
                    itemBuilder: (context, i) {
                      final s = sources[i];
                      return _SourceItem(
                          title: s.title,
                          domain: s.domain,
                          url: s.url);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChatMoreSheet extends StatelessWidget {
  final VoidCallback onCopyResponse;
  final VoidCallback onNewChat;
  const _ChatMoreSheet(
      {required this.onCopyResponse, required this.onNewChat});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.borderLight,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 8),
          ListTile(
            leading:
                const Icon(Icons.copy_outlined, color: AppTheme.textPrimary),
            title: const Text('Copy response'),
            onTap: onCopyResponse,
          ),
          ListTile(
            leading: const Icon(Icons.add_comment_outlined,
                color: AppTheme.textPrimary),
            title: const Text('New chat'),
            onTap: onNewChat,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
