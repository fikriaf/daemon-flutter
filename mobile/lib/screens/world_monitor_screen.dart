import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../widgets/sidebar_drawer.dart';
import '../widgets/chat_engine.dart';
import '../services/agent_service.dart';

class WorldMonitorScreen extends StatefulWidget {
  final ChatSession? initialSession;
  const WorldMonitorScreen({super.key, this.initialSession});

  @override
  State<WorldMonitorScreen> createState() => _WorldMonitorScreenState();
}

class _WorldMonitorScreenState extends State<WorldMonitorScreen> {
  late final WebViewController _webController;
  bool _webLoading = true;
  bool _webError = false;

  // ── Chat ────────────────────────────────────────────────────────────────────
  late final ScrollController _chatScrollController;
  late final ChatController _chatController;
  bool _isChatActive = false;

  // Scraped page text — populated async when user opens chat input
  String _pageText = '';

  @override
  void initState() {
    super.initState();

    _chatScrollController = ScrollController();
    _chatController = ChatController(
      setState: setState,
      scrollController: _chatScrollController,
      onLoginRequired: _onLoginRequired,
    );
    _chatController.loadInitialData();

    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() {
            _webLoading = true;
            _webError = false;
            _pageText = ''; // reset stale text on reload
          }),
          onPageFinished: (_) => setState(() => _webLoading = false),
          onWebResourceError: (WebResourceError error) {
            final isFatal = error.isForMainFrame == true &&
                error.errorCode != -1;
            if (isFatal) {
              setState(() {
                _webLoading = false;
                _webError = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://worldmonitor.app/'));
  }

  @override
  void dispose() {
    _chatScrollController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _onLoginRequired() {
    if (!mounted) return;
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

  void _onSessionTap(ChatSession session) {
    setState(() => _isChatActive = true);
    _chatController.loadSession(session);
  }

  /// Injects JS into the WebView to extract visible text from the page.
  /// Strips script/style noise and trims to a reasonable token budget.
  Future<String> _scrapePageText() async {
    try {
      final raw = await _webController.runJavaScriptReturningResult(r'''
        (function() {
          // Remove script and style elements first
          var clone = document.body.cloneNode(true);
          clone.querySelectorAll('script,style,noscript').forEach(function(el){ el.remove(); });
          var text = clone.innerText || clone.textContent || '';
          // Collapse whitespace
          text = text.replace(/\s{3,}/g, '\n').trim();
          // Cap at ~8000 chars to stay within token budget
          return text.length > 8000 ? text.substring(0, 8000) + '...[truncated]' : text;
        })()
      ''');
      // runJavaScriptReturningResult returns a JSON-encoded string
      if (raw is String) {
        return raw.replaceAll(RegExp(r'^"|"$'), '').replaceAll(r'\"', '"').replaceAll(r'\n', '\n');
      }
      return raw.toString();
    } catch (_) {
      return '';
    }
  }

  String _buildContextPrefix() {
    if (_pageText.isEmpty) {
      return 'You are an AI assistant in the World Monitor section of the Daemon app. '
          'World Monitor is a real-time global intelligence dashboard showing live news, '
          'markets, military tracking, flight & ship AIS, earthquakes, and geopolitical data. '
          'Answer the user\'s questions about global events and geopolitics.';
    }
    return 'You are an AI assistant in the World Monitor section of the Daemon app. '
        'The user is viewing https://worldmonitor.app — a real-time global intelligence dashboard. '
        'Here is the current text content scraped from the page:\n\n'
        '$_pageText\n\n'
        'Use this data to answer the user\'s questions about current global events, '
        'markets, military activity, and geopolitical intelligence.';
  }

  String _buildContextLabel() {
    if (_pageText.isEmpty) return 'World Monitor · live dashboard';
    final lines = _pageText.split('\n').where((l) => l.trim().isNotEmpty).length;
    return 'World Monitor · $lines data points';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: SidebarDrawer(onSessionTap: _onSessionTap),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => _isChatActive
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _isChatActive = false),
                )
              : IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
        ),
        title: _isChatActive
            ? Text('World Monitor Chat',
                style: Theme.of(context).textTheme.titleLarge)
            : Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.public,
                        color: Color(0xFF00E676), size: 13),
                  ),
                  const SizedBox(width: 8),
                  Text('World Monitor',
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
        actions: _isChatActive
            ? []
            : [
                if (_webLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF00E676),
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () {
                      setState(() {
                        _webLoading = true;
                        _webError = false;
                        _pageText = '';
                      });
                      _webController.reload();
                    },
                    tooltip: 'Reload',
                  ),
              ],
      ),
      body: _isChatActive ? _buildChatView() : _buildWebView(),
      bottomNavigationBar: ChatInputBar(
        controller: _chatController,
        contextPrefixBuilder: _buildContextPrefix,
        contextLabelBuilder: _buildContextLabel,
        contextLabel: _buildContextLabel(),
        contextIcon: Icons.public,
        onBeforeSubmit: () async {
          // Scrape page text and wait for it before the message is sent.
          // contextPrefixBuilder + contextLabelBuilder are re-evaluated
          // AFTER this completes, so the AI always gets the live page data.
          if (_pageText.isEmpty && !_webLoading && !_webError) {
            final text = await _scrapePageText();
            if (mounted) setState(() => _pageText = text);
          }
          if (mounted) setState(() => _isChatActive = true);
        },
      ),
    );
  }

  Widget _buildWebView() {
    if (_webError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: Colors.white24),
              const SizedBox(height: 16),
              const Text(
                'Failed to load World Monitor',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _webLoading = true;
                    _webError = false;
                  });
                  _webController.reload();
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return WebViewWidget(controller: _webController);
  }

  Widget _buildChatView() {
    return ChatMessagesView(
      messages: _chatController.messages,
      sources: _chatController.sources,
      isSearching: _chatController.isSearching,
      scrollController: _chatScrollController,
      contextSummary: _buildContextLabel(),
      contextIcon: Icons.public,
      onEdit: (idx, newText) => _chatController.editMessage(
        idx,
        newText,
        contextPrefix: _buildContextPrefix(),
        contextLabel: _buildContextLabel(),
      ),
      onDelete: (idx) => _chatController.deleteMessage(idx),
      onLikeChanged: (idx, state) {
        setState(() => _chatController.messages[idx].likeState = state);
      },
      onShare: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied to clipboard')),
        );
      },
    );
  }
}
