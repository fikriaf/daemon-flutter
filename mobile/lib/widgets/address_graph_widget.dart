import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';

/// Renders an interactive address/entity relationship graph using
/// React Flow inside a WebView. The [graphData] map must have the
/// shape `{ "nodes": [...], "edges": [...] }` as emitted by the
/// backend's `graph_data` SSE event.
class AddressGraphWidget extends StatefulWidget {
  final Map<String, dynamic> graphData;

  const AddressGraphWidget({super.key, required this.graphData});

  @override
  State<AddressGraphWidget> createState() => _AddressGraphWidgetState();
}

class _AddressGraphWidgetState extends State<AddressGraphWidget> {
  late final WebViewController _controller;
  bool _loaded = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterGraphReady',
        onMessageReceived: (msg) {
          // HTML calls FlutterGraphReady.postMessage('ready') once React+ReactFlow loaded
          debugPrint('AddressGraphWidget: JS ready signal received — injecting data');
          _injectGraphData();
        },
      )
      ..addJavaScriptChannel(
        'FlutterGraphError',
        onMessageReceived: (msg) {
          debugPrint('AddressGraphWidget: JS error — ${msg.message}');
          if (mounted) setState(() => _error = true);
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) => debugPrint('AddressGraphWidget: page started $url'),
        onPageFinished: (url) => debugPrint('AddressGraphWidget: page finished $url'),
        onWebResourceError: (err) {
          // Only treat fatal errors (not CDN sub-resource errors which are recoverable)
          debugPrint('AddressGraphWidget: resource error [${err.errorCode}] ${err.description} url=${err.url}');
        },
      ));
    _loadHtml();
  }

  Future<void> _loadHtml() async {
    try {
      final html = await rootBundle.loadString('assets/graph_viewer.html');
      debugPrint('AddressGraphWidget: HTML loaded (${html.length} bytes), loading into WebView');
      // baseUrl must be an https:// URL so the WebView allows CDN network requests.
      // Without this, Android WebView blocks all external fetches from a null origin.
      _controller.loadHtmlString(html, baseUrl: 'https://localhost');
    } catch (e) {
      debugPrint('AddressGraphWidget: loadHtml error: $e');
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _injectGraphData() async {
    try {
      // Encode data as JSON and pass via JSON.parse to avoid any string escaping issues
      final jsonStr = jsonEncode(widget.graphData);
      debugPrint('AddressGraphWidget: injecting graph data (${jsonStr.length} bytes)');
      // Use JSON.parse with a base64-encoded payload to avoid quote/escape issues
      final b64 = base64Encode(utf8.encode(jsonStr));
      await _controller.runJavaScript(
        "window.setGraphData(JSON.parse(atob('$b64')))",
      );
      debugPrint('AddressGraphWidget: injection complete');
      if (mounted) setState(() => _loaded = true);
    } catch (e) {
      debugPrint('AddressGraphWidget: inject error: $e');
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: const Color(0xFF0d0d0d),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),

          // Loading overlay — hidden once injected
          if (!_loaded && !_error)
            Container(
              color: const Color(0xFF0d0d0d),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppTheme.accentLink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Building graph…',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ],
              ),
            ),

          // Error state
          if (_error)
            Container(
              color: const Color(0xFF0d0d0d),
              alignment: Alignment.center,
              child: Text(
                'Unable to render graph',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}
