import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/app_logger.dart';
import '../../core/app_state.dart';
import '../../core/url_utils.dart';
import '../settings/settings_sheet.dart';
import '../widgets/falling_effect_overlay.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  WebViewController? _controller;
  final ValueNotifier<int> _progress = ValueNotifier<int>(0);
  final ValueNotifier<bool> _canGoBack = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _canGoForward = ValueNotifier<bool>(false);
  final ValueNotifier<String> _currentUrl = ValueNotifier<String>(UrlUtils.fallback);
  final ValueNotifier<String> _pageTitle = ValueNotifier<String>('');

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _isOffline = false;
  DateTime? _lastBack;

  // Web errors
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _listenConnectivity();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.watch<AppState>();

    // (Re)create controller when first time, or when JS mode needs to change.
    final shouldRecreate = _controller == null || (_controller != null && _jsMode != state.javascriptEnabled);
    if (shouldRecreate) {
      _jsMode = state.javascriptEnabled;
      _createController(state);
    }
  }

  bool _jsMode = true;

  void _listenConnectivity() {
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      if (offline != _isOffline && mounted) {
        setState(() => _isOffline = offline);
      }
    });
  }

  Future<void> _createController(AppState state, {String? initialUrl}) async {
    final url = initialUrl ?? state.homeUrl;

    // NOTE: Don't reference a local variable inside its own initializer.
    // We declare first, then configure, to keep `flutter analyze` happy.
    final controller = WebViewController();
    controller
      ..setJavaScriptMode(state.javascriptEnabled ? JavaScriptMode.unrestricted : JavaScriptMode.disabled)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => _progress.value = p,
          onPageStarted: (u) {
            _lastError = null;
            _currentUrl.value = u;
            _updateNavButtons();
          },
          onPageFinished: (u) async {
            _currentUrl.value = u;
            _pageTitle.value = (await controller.getTitle()) ?? '';
            _updateNavButtons();
          },
          onWebResourceError: (error) {
            log.w('web error: ${error.errorType} ${error.description}');
            _lastError = error.description;
            if (mounted) setState(() {});
          },
          onNavigationRequest: (request) async {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;

            // Allow normal web schemes inside WebView.
            if (UrlUtils.isWebScheme(uri)) return NavigationDecision.navigate;

            // Try open other schemes externally (tel:, wechat:, mailto:, intent:, etc.)
            try {
              final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (!ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('无法打开：${uri.scheme}')),
                );
              }
            } catch (e) {
              log.w('launch external failed: $e');
            }
            return NavigationDecision.prevent;
          },
        ),
      );

    // Desktop mode (User-Agent)
    if (state.desktopMode) {
      await controller.setUserAgent(
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36',
      );
    }

    await controller.loadRequest(Uri.parse(UrlUtils.normalize(url)));

    if (!mounted) return;
    setState(() => _controller = controller);
  }

  Future<void> _updateNavButtons() async {
    final c = _controller;
    if (c == null) return;
    _canGoBack.value = await c.canGoBack();
    _canGoForward.value = await c.canGoForward();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _progress.dispose();
    _canGoBack.dispose();
    _canGoForward.dispose();
    _currentUrl.dispose();
    _pageTitle.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    final c = _controller;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SettingsSheet(
        currentUrl: _currentUrl.value,
        currentTitle: _pageTitle.value,
        onOpenUrl: (url) async {
          final normalized = UrlUtils.normalize(url);
          await c?.loadRequest(Uri.parse(normalized));
        },
        onClearCache: () async {
          await c?.clearCache();
        },
        onClearCookies: () async {
          final cookieManager = WebViewCookieManager();
          await cookieManager.clearCookies();
        },
      ),
    );
  }

  Future<void> _promptGoTo() async {
    final c = _controller;
    if (c == null) return;

    final ctrl = TextEditingController(text: _currentUrl.value);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('打开链接 / 搜索'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          onSubmitted: (v) => Navigator.pop(context, v),
          decoration: const InputDecoration(
            hintText: '输入网址或关键词',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('打开')),
        ],
      ),
    );

    if (result == null) return;
    final url = UrlUtils.normalize(result);
    await c.loadRequest(Uri.parse(url));
  }

  Future<void> _share() async {
    final url = _currentUrl.value;
    await Share.share(url);
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(_currentUrl.value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _currentUrl.value));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('链接已复制')));
    }
  }

  Future<void> _toggleBookmark() async {
    final state = context.read<AppState>();
    final url = _currentUrl.value;
    final title = _pageTitle.value;
    await state.toggleBookmark(url: url, title: title);

    if (!mounted) return;
    final isNow = state.isBookmarked(UrlUtils.normalize(url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isNow ? '已加入书签' : '已移除书签')),
    );
  }

  Future<void> _reload({bool hard = false}) async {
    final c = _controller;
    if (c == null) return;
    if (hard) {
      await c.clearCache();
      final cookieManager = WebViewCookieManager();
      await cookieManager.clearCookies();
    }
    await c.reload();
  }

  Future<void> _handleBack() async {
    final c = _controller;
    if (c == null) return;

    if (await c.canGoBack()) {
      await c.goBack();
      return;
    }

    final now = DateTime.now();
    if (_lastBack == null || now.difference(_lastBack!) > const Duration(seconds: 2)) {
      _lastBack = now;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('再按一次返回退出')),
        );
      }
      return;
    }

    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final controller = _controller;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            onTap: _promptGoTo,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.appTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                ValueListenableBuilder<String>(
                  valueListenable: _currentUrl,
                  builder: (context, url, _) => Text(
                    url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ValueListenableBuilder<bool>(
              valueListenable: _canGoBack,
              builder: (context, canBack, _) => IconButton(
                tooltip: '后退',
                onPressed: canBack && controller != null ? () => controller.goBack() : null,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _canGoForward,
              builder: (context, canForward, _) => IconButton(
                tooltip: '前进',
                onPressed: canForward && controller != null ? () => controller.goForward() : null,
                icon: const Icon(Icons.arrow_forward),
              ),
            ),
            IconButton(
              tooltip: '主页',
              onPressed: controller == null
                  ? null
                  : () async {
                      await controller.loadRequest(Uri.parse(state.homeUrl));
                    },
              icon: const Icon(Icons.home_outlined),
            ),
            IconButton(
              tooltip: '刷新（长按清理后刷新）',
              onPressed: controller == null ? null : () => _reload(),
              onLongPress: controller == null ? null : () => _reload(hard: true),
              icon: const Icon(Icons.refresh),
            ),
            ValueListenableBuilder<String>(
              valueListenable: _currentUrl,
              builder: (context, url, _) {
                final marked = state.isBookmarked(UrlUtils.normalize(url));
                return IconButton(
                  tooltip: marked ? '移除书签' : '加入书签',
                  onPressed: controller == null ? null : _toggleBookmark,
                  icon: Icon(marked ? Icons.bookmark : Icons.bookmark_border),
                );
              },
            ),
            PopupMenuButton<String>(
              tooltip: '更多',
              onSelected: (v) async {
                switch (v) {
                  case 'share':
                    await _share();
                    break;
                  case 'external':
                    await _openExternal();
                    break;
                  case 'copy':
                    await _copyLink();
                    break;
                  case 'settings':
                    await _openSettings();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'share', child: ListTile(leading: Icon(Icons.share), title: Text('分享'))),
                PopupMenuItem(value: 'copy', child: ListTile(leading: Icon(Icons.copy), title: Text('复制链接'))),
                PopupMenuItem(value: 'external', child: ListTile(leading: Icon(Icons.open_in_new), title: Text('外部打开'))),
                PopupMenuDivider(),
                PopupMenuItem(value: 'settings', child: ListTile(leading: Icon(Icons.settings), title: Text('设置'))),
              ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: ValueListenableBuilder<int>(
              valueListenable: _progress,
              builder: (context, p, _) {
                if (p >= 100) return const SizedBox(height: 2);
                return LinearProgressIndicator(value: p / 100.0);
              },
            ),
          ),
        ),
        body: Stack(
          children: [
            if (controller == null)
              const Center(child: CircularProgressIndicator())
            else
              WebViewWidget(controller: controller),

            // Falling effect overlay
            if (state.effect != EffectType.none)
              IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, constraints) => FallingEffectOverlay(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    type: state.effect,
                    dark: isDark,
                  ),
                ),
              ),

            // Offline banner
            if (_isOffline)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('当前离线：请检查网络连接')),
                        TextButton(
                          onPressed: () => _reload(),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Error overlay
            if (_lastError != null)
              Positioned.fill(
                child: Container(
                  // Avoid deprecated withOpacity (precision loss). Use alpha channel explicitly.
                  color: Theme.of(context).colorScheme.surface.withAlpha(235),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            '加载失败',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _lastError!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => setState(() => _lastError = null),
                                icon: const Icon(Icons.close),
                                label: const Text('关闭'),
                              ),
                              FilledButton.icon(
                                onPressed: () async {
                                  setState(() => _lastError = null);
                                  await _reload();
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('重试'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _promptGoTo,
          icon: const Icon(Icons.search),
          label: const Text('打开'),
        ),
      ),
    );
  }
}
