// Shared chat engine — models, stream logic, and UI widgets
// used by root_screen, discover_screen, and finance_screen.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../config/api_config.dart';
import '../services/provider.dart';
import '../services/agent_service.dart';
import '../services/error_handler.dart';
import 'global_chat_input.dart';

// ─── Stream step enum ─────────────────────────────────────────────────────────

enum StreamStep { thinking, writing, executingTool, searching, fetching, done }

// ─── Block-based message model ────────────────────────────────────────────────

enum BlockType { reasoning, toolCall, content }

class MessageBlock {
  final BlockType type;
  String reasoning;
  bool reasoningDone;
  String? toolName;
  Map<String, dynamic>? toolArgs;
  Map<String, dynamic>? toolResult;
  String contentChunk;

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
  final String role;
  final String userContent;
  final List<MessageBlock> blocks;
  final DateTime timestamp;
  String? modelName;
  int stepCount;
  StreamStep streamStep;
  int likeState; // 0=none, 1=liked, -1=unliked
  /// The context label that was active when this user message was submitted.
  /// Used by [ChatMessagesView] to show a [ContextSummaryCard] above this
  /// bubble whenever the context changes relative to the previous inject.
  String? injectedContextLabel;

  ChatMessage.user(this.userContent, {this.injectedContextLabel})
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

class ChatSource {
  final String title;
  final String domain;
  final String url;
  ChatSource({required this.title, required this.domain, required this.url});
}

// ─── ChatController: reusable state logic ─────────────────────────────────────

/// Manages messages, streaming, model selection.
/// Screens create one instance, hold it in state, dispose it.
class ChatController {
  final void Function(void Function()) setState;
  final ScrollController scrollController;
  final TextEditingController textController = TextEditingController();
  final VoidCallback onLoginRequired;

  AgentInfo? agentInfo;
  String? selectedModelId;
  String? selectedModelName;

  final List<ChatMessage> messages = [];
  List<ChatSource> sources = [];
  String? currentSessionId;
  bool isSearching = false;

  ChatController({
    required this.setState,
    required this.scrollController,
    required this.onLoginRequired,
  });

  void dispose() {
    textController.dispose();
  }

  Future<void> loadInitialData() async {
    try {
      final info = await apiProvider.agentService.getAgentMe();
      setState(() {
        agentInfo = info;
      });
    } catch (_) {}
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String get _modelId =>
      selectedModelId ??
      agentInfo?.defaultModelId ??
      'stepfun/step-3.5-flash:free';

  String get _modelDisplayName =>
      selectedModelName ?? _modelId.split('/').last.split(':').first;

  /// [contextPrefix] is prepended as a system message so the AI knows
  /// what data the screen is showing.
  /// [contextLabel] is stored on the user message for UI display purposes.
  Future<void> handleSubmit({String? contextPrefix, String? contextLabel}) async {
    final text = textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      isSearching = true;
      messages.add(ChatMessage.user(text, injectedContextLabel: contextLabel));
      messages.add(ChatMessage.assistant(modelName: _modelDisplayName));
      sources = [];
    });
    textController.clear();
    scrollToBottom();
    await _streamChat(text, contextPrefix: contextPrefix);
  }

  Future<void> _streamChat(String message, {String? contextPrefix}) async {
    if (!apiProvider.isAuthenticated) {
      onLoginRequired();
      setState(() => isSearching = false);
      return;
    }

    try {
      // Build history; exclude empty trailing assistant slot
      final hist = messages
          .where((m) =>
              !(m.role == 'assistant' &&
                  m.fullContent.isEmpty &&
                  m.blocks.isEmpty))
          .map((m) => {
                'role': m.role,
                'content': m.role == 'user' ? m.userContent : m.fullContent,
              })
          .toList();

      // Inject screen context as a leading system message
      final apiMessages = <Map<String, dynamic>>[
        if (contextPrefix != null && contextPrefix.isNotEmpty)
          {'role': 'system', 'content': contextPrefix},
        ...hist,
      ];

      final stream = apiProvider.agentService.api.streamPost(
        '/v1/chat/completions',
        {
          'model': _modelId,
          'messages': apiMessages,
          'stream': true,
          if (currentSessionId != null) 'session_id': currentSessionId,
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
              final last = messages.last;
              last.streamStep = StreamStep.thinking;
              if (last.blocks.isNotEmpty &&
                  last.blocks.last.type == BlockType.reasoning) {
                last.blocks.last.reasoning += text;
              } else {
                last.blocks.add(MessageBlock.reasoning(text));
                last.stepCount++;
              }
            });
            scrollToBottom();
          } else if (type == 'tool_call') {
            final toolName = (data['tool'] as String?) ?? '';
            final rawArgs = data['arguments'];
            final args = rawArgs is String
                ? (jsonDecode(rawArgs) as Map<String, dynamic>? ?? {})
                : (rawArgs as Map<String, dynamic>? ?? {});
            setState(() {
              final last = messages.last;
              final lower = toolName.toLowerCase();
              if (lower.contains('search') || lower.contains('web')) {
                last.streamStep = StreamStep.searching;
              } else if (lower.contains('fetch') ||
                  lower.contains('browse') ||
                  lower.contains('http')) {
                last.streamStep = StreamStep.fetching;
              } else {
                last.streamStep = StreamStep.executingTool;
              }
              for (final b in last.blocks) {
                if (b.type == BlockType.reasoning) b.reasoningDone = true;
              }
              last.blocks.add(MessageBlock.toolCall(toolName, args));
              last.stepCount++;
            });
            scrollToBottom();
          } else if (type == 'tool_result') {
            final result = data['result'];
            setState(() {
              final last = messages.last;
              final chip = last.blocks
                  .where((b) =>
                      b.type == BlockType.toolCall && b.toolResult == null)
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
              final last = messages.last;
              last.streamStep = StreamStep.writing;
              for (final b in last.blocks) {
                if (b.type == BlockType.reasoning) b.reasoningDone = true;
              }
              if (last.blocks.isNotEmpty &&
                  last.blocks.last.type == BlockType.content) {
                last.blocks.last.contentChunk += chunk;
              } else {
                last.blocks.add(MessageBlock.content(chunk));
                last.stepCount++;
              }
            });
            scrollToBottom();
          } else if (type == 'done') {
            final sid = data['session_id'] as String?;
            if (sid != null) setState(() => currentSessionId = sid);
            final rawSources = data['sources'];
            if (rawSources is List && rawSources.isNotEmpty) {
              setState(() {
                sources = rawSources
                    .map((s) => ChatSource(
                          title: (s['title'] as String?) ?? '',
                          domain: (s['domain'] as String?) ?? '',
                          url: (s['url'] as String?) ?? '',
                        ))
                    .toList();
              });
            }
          }
        } catch (e) {
          debugPrint('Parse error: $e');
        }
      }

      setState(() {
        isSearching = false;
        if (messages.isNotEmpty && messages.last.role == 'assistant') {
          messages.last.streamStep = StreamStep.done;
        }
      });
    } catch (e) {
      debugPrint('Chat error: $e');
      if (isAuthError(e)) {
        onLoginRequired();
        setState(() => isSearching = false);
        return;
      }
      setState(() {
        isSearching = false;
        if (messages.isNotEmpty && messages.last.role == 'assistant') {
          final last = messages.last;
          last.streamStep = StreamStep.done;
          if (last.blocks.isEmpty) {
            last.blocks.add(MessageBlock.content('Error: $e'));
          }
        }
      });
    }
  }

  void editMessage(int userIdx, String newText, {String? contextPrefix, String? contextLabel}) {
    setState(() {
      messages.removeRange(userIdx, messages.length);
    });
    textController.text = newText;
    setState(() {
      isSearching = true;
      messages.add(ChatMessage.user(newText, injectedContextLabel: contextLabel));
      messages.add(ChatMessage.assistant(modelName: _modelDisplayName));
      sources = [];
    });
    textController.clear();
    scrollToBottom();
    _streamChat(newText, contextPrefix: contextPrefix);
  }

  void deleteMessage(int userIdx) {
    setState(() {
      messages.removeRange(userIdx, messages.length);
      isSearching = false;
    });
  }

  /// Load a past chat session into this controller.
  /// Fetches messages from the API, replaces current messages, and sets [currentSessionId].
  Future<void> loadSession(ChatSession session) async {
    setState(() {
      isSearching = true;
      messages.clear();
      sources = [];
      currentSessionId = session.id;
    });
    try {
      final fetched = await apiProvider.agentService.getChatMessages(session.id);
      setState(() {
        for (final m in fetched) {
          if (m.role == 'user') {
            messages.add(ChatMessage.user(m.content));
          } else if (m.role == 'assistant') {
            messages.add(ChatMessage.assistantText(m.content));
          }
        }
        isSearching = false;
      });
      scrollToBottom();
    } catch (e) {
      debugPrint('loadSession error: $e');
      if (isAuthError(e)) {
        onLoginRequired();
      }
      setState(() => isSearching = false);
    }
  }
}

// ─── ChatBody widget ──────────────────────────────────────────────────────────

/// Drop-in chat body for any screen. Renders messages + input.
class ChatBody extends StatelessWidget {
  final ChatController controller;
  final bool isSearching;
  final List<ChatMessage> messages;
  final List<ChatSource> sources;
  final String? contextPrefix;
  final Widget Function(BuildContext) buildContent;

  const ChatBody({
    super.key,
    required this.controller,
    required this.isSearching,
    required this.messages,
    required this.sources,
    this.contextPrefix,
    required this.buildContent,
  });

  @override
  Widget build(BuildContext context) {
    return buildContent(context);
  }
}

// ─── ContextSummaryCard ───────────────────────────────────────────────────────

/// Shown once at the top of the chat view (above the first user bubble) to
/// tell the user what data was injected as AI context.
class ContextSummaryCard extends StatelessWidget {
  /// Short label, e.g. "US Markets" or "Top News · 12 articles"
  final String label;

  /// Optional icon to show beside the label.
  final IconData icon;

  const ContextSummaryCard({
    super.key,
    required this.label,
    this.icon = Icons.data_usage_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.accentLink.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.accentLink.withValues(alpha: 0.22),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.accentLink),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Context: $label',
                style: const TextStyle(
                  color: AppTheme.accentLink,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ContextIndicatorBar ─────────────────────────────────────────────────────

/// Thin pill shown above the chat input bar indicating which data is loaded
/// into context. Only shown when [label] is non-null and non-empty.
class ContextIndicatorBar extends StatelessWidget {
  final String label;
  final IconData icon;

  const ContextIndicatorBar({
    super.key,
    required this.label,
    this.icon = Icons.data_usage_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.background,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        children: [
          Icon(icon, size: 12, color: AppTheme.accentLink),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.accentLink,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ChatMessagesView ─────────────────────────────────────────────────────────

/// The scrollable list of messages. Place inside Expanded.
class ChatMessagesView extends StatelessWidget {
  final List<ChatMessage> messages;
  final List<ChatSource> sources;
  final bool isSearching;
  final ScrollController scrollController;
  final void Function(int idx, String newText) onEdit;
  final void Function(int idx) onDelete;
  final void Function(int idx, int likeState) onLikeChanged;
  final void Function(String text) onShare;
  /// When set, a [ContextSummaryCard] is shown above the first user bubble.
  final String? contextSummary;
  final IconData contextIcon;

  const ChatMessagesView({
    super.key,
    required this.messages,
    required this.sources,
    required this.isSearching,
    required this.scrollController,
    required this.onEdit,
    required this.onDelete,
    required this.onLikeChanged,
    required this.onShare,
    this.contextSummary,
    this.contextIcon = Icons.data_usage_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final lastAssistantMsg =
        messages.where((m) => m.role == 'assistant').lastOrNull;

    // Track the last context label that was rendered so we only show a card
    // when the context changes (i.e. user switched tab/menu before sending).
    String? lastRenderedLabel;

    final List<Widget> items = [];
    for (final (idx, msg) in messages.indexed) {
      if (msg.role == 'user') {
        // Show a ContextSummaryCard whenever this message was sent with a
        // context label that differs from the previously-shown one.
        final label = msg.injectedContextLabel;
        if (label != null && label.isNotEmpty && label != lastRenderedLabel) {
          items.add(ContextSummaryCard(
            key: ValueKey('context_card_$idx'),
            label: label,
            icon: contextIcon,
          ));
          lastRenderedLabel = label;
        }

        items.add(ChatAnimatedEntry(
          key: ValueKey('user_$idx'),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ChatUserBubble(
              message: msg,
              onEdit: (newText) => onEdit(idx, newText),
              onDelete: () => onDelete(idx),
            ),
          ),
        ));
      } else {
        items.add(Padding(
          key: ValueKey('ai_$idx'),
          padding: const EdgeInsets.only(bottom: 24),
          child: ChatAIBubble(
            msg: msg,
            msgIdx: idx,
            isLast: identical(msg, lastAssistantMsg),
            isSearching: isSearching,
            sources: sources,
            onLikeChanged: (state) => onLikeChanged(idx, state),
            onShare: () => onShare(msg.fullContent),
          ),
        ));
      }
    }

    // Initial thinking spinner — shown only before first block arrives.
    // Also show a context card for the in-flight message if needed.
    if (isSearching &&
        (messages.isEmpty ||
            messages.last.role != 'assistant' ||
            messages.last.blocks.isEmpty)) {
      // Find the pending user message label (last user message in list)
      final pendingLabel = messages.lastOrNull?.role == 'user'
          ? messages.last.injectedContextLabel
          : null;
      if (pendingLabel != null &&
          pendingLabel.isNotEmpty &&
          pendingLabel != lastRenderedLabel) {
        items.add(ContextSummaryCard(
          key: ValueKey('context_card_pending'),
          label: pendingLabel,
          icon: contextIcon,
        ));
      } else if (pendingLabel == null &&
          contextSummary != null &&
          contextSummary!.isNotEmpty &&
          lastRenderedLabel == null) {
        // Fallback: no messages yet but context exists
        items.add(ContextSummaryCard(
          key: const ValueKey('context_card_initial'),
          label: contextSummary!,
          icon: contextIcon,
        ));
      }
      items.add(const ChatThinkingIndicator());
    }

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items,
      ),
    );
  }
}

// ─── ChatAIBubble ─────────────────────────────────────────────────────────────

class ChatAIBubble extends StatelessWidget {
  final ChatMessage msg;
  final int msgIdx;
  final bool isLast;
  final bool isSearching;
  final List<ChatSource> sources;
  final ValueChanged<int> onLikeChanged;
  final VoidCallback onShare;

  const ChatAIBubble({
    super.key,
    required this.msg,
    required this.msgIdx,
    required this.isLast,
    required this.isSearching,
    required this.sources,
    required this.onLikeChanged,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final isStreaming = isLast && isSearching;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stream status at top
        ChatAnimatedEntry(
          key: ValueKey('status_$msgIdx'),
          child: ChatStreamStatusIndicator(
            step: msg.streamStep,
            stepCount: msg.stepCount,
            modelName: msg.modelName ?? '',
            isStreaming: isStreaming,
          ),
        ),
        const SizedBox(height: 8),

        // Blocks in arrival order
        for (int i = 0; i < msg.blocks.length; i++)
          ChatAnimatedEntry(
            key: ValueKey('block_${msgIdx}_$i'),
            child: ChatBlockWidget(
              block: msg.blocks[i],
              isLast: isLast,
              isStreaming: isStreaming,
            ),
          ),

        // Sources
        if (!isSearching && isLast && sources.isNotEmpty) ...[
          const SizedBox(height: 16),
          ChatAnimatedEntry(
            key: ValueKey('sources_$msgIdx'),
            child: _SourcesWidget(sources: sources),
          ),
        ],

        const SizedBox(height: 8),
        ChatAIActionBar(
          message: msg,
          onLikeChanged: onLikeChanged,
          onShare: onShare,
        ),
      ],
    );
  }
}

class _SourcesWidget extends StatelessWidget {
  final List<ChatSource> sources;
  const _SourcesWidget({required this.sources});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sources',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: AppTheme.accentLink)),
        const SizedBox(height: 8),
        for (final s in sources)
          ChatSourceItem(title: s.title, domain: s.domain, url: s.url),
      ],
    );
  }
}

// ─── ChatBlockWidget ──────────────────────────────────────────────────────────

class ChatBlockWidget extends StatelessWidget {
  final MessageBlock block;
  final bool isLast;
  final bool isStreaming;

  const ChatBlockWidget({
    super.key,
    required this.block,
    required this.isLast,
    required this.isStreaming,
  });

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case BlockType.reasoning:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ChatReasoningBlock(
            reasoning: block.reasoning,
            isStreaming: isLast && isStreaming && !block.reasoningDone,
          ),
        );
      case BlockType.toolCall:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChatToolChip(block: block),
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
                    width: 3,
                  ),
                ),
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
}

// ─── ChatAnimatedEntry ────────────────────────────────────────────────────────

class ChatAnimatedEntry extends StatefulWidget {
  final Widget child;
  const ChatAnimatedEntry({super.key, required this.child});

  @override
  State<ChatAnimatedEntry> createState() => _ChatAnimatedEntryState();
}

class _ChatAnimatedEntryState extends State<ChatAnimatedEntry>
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

// ─── ChatThinkingIndicator ────────────────────────────────────────────────────

class ChatThinkingIndicator extends StatefulWidget {
  const ChatThinkingIndicator({super.key});

  @override
  State<ChatThinkingIndicator> createState() => _ChatThinkingIndicatorState();
}

class _ChatThinkingIndicatorState extends State<ChatThinkingIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 1500), vsync: this)
      ..repeat();
    _anim = Tween<double>(begin: 0, end: 1)
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
                    final opacity =
                        ((_anim.value + i * 0.2) % 1.0).clamp(0.3, 1.0);
                    return Container(
                      margin: const EdgeInsets.only(right: 4),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppTheme.accentLink.withValues(alpha: opacity),
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

// ─── ChatReasoningBlock ───────────────────────────────────────────────────────

class ChatReasoningBlock extends StatefulWidget {
  final String reasoning;
  final bool isStreaming;
  const ChatReasoningBlock(
      {super.key, required this.reasoning, this.isStreaming = false});

  @override
  State<ChatReasoningBlock> createState() => _ChatReasoningBlockState();
}

class _ChatReasoningBlockState extends State<ChatReasoningBlock>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late final AnimationController _ctrl;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isStreaming;
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _expandAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    if (_expanded) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(ChatReasoningBlock old) {
    super.didUpdateWidget(old);
    if (old.isStreaming && !widget.isStreaming && _expanded) _toggle();
    if (!old.isStreaming && widget.isStreaming && !_expanded) _toggle();
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
              : AppTheme.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  if (widget.isStreaming)
                    const ChatPulsingDot()
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

// ─── ChatPulsingDot ───────────────────────────────────────────────────────────

class ChatPulsingDot extends StatefulWidget {
  const ChatPulsingDot({super.key});

  @override
  State<ChatPulsingDot> createState() => _ChatPulsingDotState();
}

class _ChatPulsingDotState extends State<ChatPulsingDot>
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
      builder: (context, child) => Container(
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

// ─── ChatToolChip ─────────────────────────────────────────────────────────────

class ChatToolChip extends StatefulWidget {
  final MessageBlock block;
  const ChatToolChip({super.key, required this.block});

  @override
  State<ChatToolChip> createState() => _ChatToolChipState();
}

class _ChatToolChipState extends State<ChatToolChip>
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
  void didUpdateWidget(ChatToolChip old) {
    super.didUpdateWidget(old);
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

  String _labelFor(String name) => name
      .replaceAll('_', ' ')
      .replaceAllMapped(
          RegExp(r'([A-Z])'), (m) => ' ${m.group(1)!.toLowerCase()}')
      .trim();

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
            const ChatSpinnerIcon(),
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

// ─── ChatSpinnerIcon ──────────────────────────────────────────────────────────

class ChatSpinnerIcon extends StatefulWidget {
  const ChatSpinnerIcon({super.key});

  @override
  State<ChatSpinnerIcon> createState() => _ChatSpinnerIconState();
}

class _ChatSpinnerIconState extends State<ChatSpinnerIcon>
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

// ─── ChatStreamStatusIndicator ────────────────────────────────────────────────

class ChatStreamStatusIndicator extends StatefulWidget {
  final StreamStep step;
  final int stepCount;
  final String modelName;
  final bool isStreaming;

  const ChatStreamStatusIndicator({
    super.key,
    required this.step,
    required this.stepCount,
    required this.modelName,
    required this.isStreaming,
  });

  @override
  State<ChatStreamStatusIndicator> createState() =>
      _ChatStreamStatusIndicatorState();
}

class _ChatStreamStatusIndicatorState extends State<ChatStreamStatusIndicator>
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
  void didUpdateWidget(ChatStreamStatusIndicator old) {
    super.didUpdateWidget(old);
    if (!widget.isStreaming && old.isStreaming) _shimmerCtrl.stop();
    if (widget.isStreaming && !old.isStreaming) _shimmerCtrl.repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  String _label(StreamStep step) {
    switch (step) {
      case StreamStep.thinking: return 'Thinking';
      case StreamStep.writing: return 'Writing';
      case StreamStep.executingTool: return 'Execute Tool';
      case StreamStep.searching: return 'Searching';
      case StreamStep.fetching: return 'Fetching';
      case StreamStep.done: return 'Done';
    }
  }

  IconData _icon(StreamStep step) {
    switch (step) {
      case StreamStep.thinking: return Icons.psychology_outlined;
      case StreamStep.writing: return Icons.edit_outlined;
      case StreamStep.executingTool: return Icons.terminal_outlined;
      case StreamStep.searching: return Icons.search;
      case StreamStep.fetching: return Icons.download_outlined;
      case StreamStep.done: return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.modelName.isNotEmpty ? widget.modelName : 'AI';
    final isDone = !widget.isStreaming;

    if (isDone) {
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
            Text(label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    )),
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

    final label = '${_label(widget.step)}... ($model)';
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(_shimmer.value - 1, 0),
            end: Alignment(_shimmer.value + 1, 0),
            colors: [
              AppTheme.textSecondary,
              AppTheme.accentLink,
              AppTheme.textSecondary,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(bounds),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon(widget.step), size: 13, color: Colors.white),
              const SizedBox(width: 5),
              Text(label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      )),
              const SizedBox(width: 4),
              const ChatPulsingDot(),
            ],
          ),
        );
      },
    );
  }
}

// ─── ChatAIActionBar ──────────────────────────────────────────────────────────

class ChatAIActionBar extends StatelessWidget {
  final ChatMessage message;
  final ValueChanged<int> onLikeChanged;
  final VoidCallback onShare;

  const ChatAIActionBar({
    super.key,
    required this.message,
    required this.onLikeChanged,
    required this.onShare,
  });

  String _fmt(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(_fmt(message.timestamp),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                )),
        const Spacer(),
        ChatActionIconBtn(icon: Icons.share_outlined, onTap: onShare),
        const SizedBox(width: 4),
        ChatActionIconBtn(
          icon: message.likeState == 1 ? Icons.thumb_up : Icons.thumb_up_outlined,
          active: message.likeState == 1,
          onTap: () => onLikeChanged(message.likeState == 1 ? 0 : 1),
        ),
        const SizedBox(width: 4),
        ChatActionIconBtn(
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

class ChatActionIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const ChatActionIconBtn({
    super.key,
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
        child: Icon(icon,
            size: 15,
            color: active ? AppTheme.accentLink : AppTheme.textSecondary),
      ),
    );
  }
}

// ─── ChatUserBubble ───────────────────────────────────────────────────────────

class ChatUserBubble extends StatefulWidget {
  final ChatMessage message;
  final ValueChanged<String> onEdit;
  final VoidCallback onDelete;

  const ChatUserBubble({
    super.key,
    required this.message,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<ChatUserBubble> createState() => _ChatUserBubbleState();
}

class _ChatUserBubbleState extends State<ChatUserBubble> {
  bool _hovered = false;

  String _fmt(DateTime dt) {
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
        title: Text('Edit message',
            style: Theme.of(ctx).textTheme.titleMedium),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: null,
          style: Theme.of(ctx)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppTheme.textPrimary),
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
            child:
                Text('Send', style: TextStyle(color: AppTheme.accentLink)),
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
              AnimatedOpacity(
                opacity: _hovered ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: Row(
                  children: [
                    ChatActionIconBtn(
                      icon: Icons.edit_outlined,
                      onTap: () => _showEditDialog(context),
                    ),
                    ChatActionIconBtn(
                      icon: Icons.delete_outline,
                      onTap: widget.onDelete,
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
              GestureDetector(
                onLongPress: () => setState(() => _hovered = !_hovered),
                child: Container(
                  constraints: BoxConstraints(
                      maxWidth:
                          MediaQuery.of(context).size.width * 0.75),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    widget.message.userContent,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppTheme.textPrimary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              _fmt(widget.message.timestamp),
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

// ─── ChatSourceItem ───────────────────────────────────────────────────────────

class ChatSourceItem extends StatelessWidget {
  final String title;
  final String domain;
  final String url;
  const ChatSourceItem(
      {super.key, required this.title, required this.domain, required this.url});

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

// ─── ChatInputBar: GlobalChatInput wired to a ChatController ─────────────────

class ChatInputBar extends StatelessWidget {
  final ChatController controller;
  /// If provided as a direct value, it is evaluated at widget-build time.
  /// Prefer [contextPrefixBuilder] when the prefix is computed from async data
  /// (e.g. scraped page text) so it is re-evaluated after [onBeforeSubmit] completes.
  final String? contextPrefix;
  /// Lazy getter for the context prefix — evaluated *after* [onBeforeSubmit]
  /// completes, so async data populated during that callback is included.
  /// Takes precedence over [contextPrefix] when both are set.
  final String? Function()? contextPrefixBuilder;
  /// Short human-readable label describing what data is loaded into context.
  /// When set, a [ContextIndicatorBar] is shown above the input.
  /// Prefer [contextLabelBuilder] when the label depends on async data.
  final String? contextLabel;
  /// Lazy getter for the context label — evaluated *after* [onBeforeSubmit]
  /// completes so the data-point count reflects freshly scraped data.
  /// Takes precedence over [contextLabel] when both are set.
  final String? Function()? contextLabelBuilder;
  final IconData contextIcon;
  /// Awaited before the submit — use for async work (e.g. page scrape) that
  /// must complete before the AI context prefix is read.
  final Future<void> Function()? onBeforeSubmit;

  const ChatInputBar({
    super.key,
    required this.controller,
    this.contextPrefix,
    this.contextPrefixBuilder,
    this.contextLabel,
    this.contextLabelBuilder,
    this.contextIcon = Icons.data_usage_rounded,
    this.onBeforeSubmit,
  });

  @override
  Widget build(BuildContext context) {
    // Use the static label for the indicator bar (updates on next rebuild
    // once setState fires after the scrape).
    final displayLabel = contextLabel;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (displayLabel != null && displayLabel.isNotEmpty)
            ContextIndicatorBar(label: displayLabel, icon: contextIcon),
          GlobalChatInput(
            controller: controller.textController,
            onSubmit: () async {
              if (onBeforeSubmit != null) await onBeforeSubmit!();
              // Re-evaluate prefix AND label AFTER onBeforeSubmit so any async
              // data (e.g. scraped page text) is captured correctly.
              final prefix = contextPrefixBuilder?.call() ?? contextPrefix;
              final label  = contextLabelBuilder?.call() ?? contextLabel;
              controller.handleSubmit(
                contextPrefix: prefix,
                contextLabel: label,
              );
            },
            selectedModelId: controller.selectedModelId,
            selectedModelName: controller.selectedModelName,
            onModelChanged: (modelId) {
              final short = ApiConfig.shortLabelForModel(modelId)
                  ?? modelId.split('/').last.split(':').first;
              controller.setState(() {
                controller.selectedModelId = modelId;
                controller.selectedModelName = short;
              });
            },
          ),
        ],
      ),
    );
  }
}
