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
  final ValueNotifier<String> _currentUrl = ValueNotifier<String>('');
  final ValueNotifier<String> _pageTitle = ValueNotifier<String>('');

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _isOffline = false;
  bool _isFullscreen = false;
  bool _jsMode = true;
  bool _desktopMode = false;
  OrientationLock? _appliedOrientation;
  DateTime? _lastBack;
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
    if (!_isFullscreen && _appliedOrientation != state.orientationLock) {
      _appliedOrientation = state.orientationLock;
      unawaited(_applyOrientation(state.orientationLock));
    }

    if (!state.isConfigured) {
      _controller = null;
      return;
    }

    final needsController = _controller == null ||
        _jsMode != state.javascriptEnabled ||
        _desktopMode != state.desktopMode;
    if (needsController) {
      _jsMode = state.javascriptEnabled;
      _desktopMode = state.desktopMode;
      final target = _currentUrl.value.trim().isNotEmpty ? _currentUrl.value : state.launchUrl;
      unawaited(_createController(state, initialUrl: target));
    }
  }

  void _listenConnectivity() {
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      if (offline != _isOffline && mounted) {
        setState(() => _isOffline = offline);
      }
    });
  }

  Future<void> _createController(AppState state, {required String initialUrl}) async {
    final controller = WebViewController();
    controller
      ..setJavaScriptMode(state.javascriptEnabled ? JavaScriptMode.unrestricted : JavaScriptMode.disabled)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => _progress.value = p,
          onPageStarted: (url) {
            _lastError = null;
            _currentUrl.value = url;
            if (mounted) {
              unawaited(context.read<AppState>().rememberCurrentUrl(url));
              setState(() {});
            }
          },
          onPageFinished: (url) async {
            _currentUrl.value = url;
            _pageTitle.value = (await controller.getTitle()) ?? '';
            if (!mounted) return;
            unawaited(context.read<AppState>().rememberCurrentUrl(url));
            if (state.javascriptEnabled) {
              try {
                await controller.runJavaScript(_fullscreenHookJs);
              } catch (_) {
                // Some pages block injected scripts. This should not break normal browsing.
              }
            }
          },
          onWebResourceError: (error) {
            log.w('web error: ${error.errorType} ${error.description}');
            _lastError = error.description;
            if (mounted) setState(() {});
          },
          onNavigationRequest: (request) async {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            if (UrlUtils.isWebScheme(uri)) return NavigationDecision.navigate;
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
      )
      ..addJavaScriptChannel(
        'LinkWebFullscreen',
        onMessageReceived: (msg) => _handleFullscreenMessage(msg.message),
      );

    if (state.desktopMode) {
      await controller.setUserAgent(
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
      );
    }

    final url = UrlUtils.normalize(initialUrl);
    if (!mounted) return;
    setState(() {
      _controller = controller;
      _currentUrl.value = url;
      _lastError = null;
    });
    await controller.loadRequest(Uri.parse(url));
  }

  static const String _fullscreenHookJs = r"""
(function() {
  try {
    if (window.__linkweb_fullscreen_hooked) return;
    window.__linkweb_fullscreen_hooked = true;
    function post(v) {
      try { LinkWebFullscreen.postMessage(v ? '1' : '0'); } catch (e) {}
    }
    function handler() {
      var el = document.fullscreenElement || document.webkitFullscreenElement || document.mozFullScreenElement || document.msFullscreenElement;
      post(!!el);
    }
    document.addEventListener('fullscreenchange', handler);
    document.addEventListener('webkitfullscreenchange', handler);
    document.addEventListener('mozfullscreenchange', handler);
    document.addEventListener('MSFullscreenChange', handler);
    handler();
  } catch (e) {}
})();
""";

  Future<void> _handleFullscreenMessage(String message) async {
    final state = context.read<AppState>();
    if (!state.fullscreenLandscape) return;
    final m = message.trim().toLowerCase();
    final nextFullscreen = m == '1' || m == 'true' || m == 'yes' || m == 'on';
    if (nextFullscreen == _isFullscreen) return;
    _isFullscreen = nextFullscreen;
    if (nextFullscreen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations(
        const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
      );
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await _applyOrientation(state.orientationLock);
    }
  }

  Future<void> _applyOrientation(OrientationLock lock) async {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      switch (lock) {
        case OrientationLock.followSystem:
          await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
          break;
        case OrientationLock.portrait:
          await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
          break;
        case OrientationLock.landscape:
          await SystemChrome.setPreferredOrientations(
            const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
          );
          break;
        case OrientationLock.autoRotate:
          await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
          break;
      }
    } catch (_) {
      // Best effort. Some platforms ignore orientation constraints.
    }
  }

  @override
  void dispose() {
    _connSub?.cancel();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]));
    _progress.dispose();
    _currentUrl.dispose();
    _pageTitle.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    final controller = _controller;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SettingsSheet(
        currentUrl: _currentUrl.value,
        currentTitle: _pageTitle.value,
        onOpenUrl: _openUrl,
        onClearCache: () async {
          await controller?.clearCache();
        },
        onClearCookies: () async {
          final cookieManager = WebViewCookieManager();
          await cookieManager.clearCookies();
        },
      ),
    );
  }

  Future<void> _showOpenUrlSheet() async {
    final state = context.read<AppState>();
    final controller = TextEditingController(
      text: _currentUrl.value.trim().isNotEmpty ? _currentUrl.value : state.homeUrl,
    );
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('打开网页', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: (v) => Navigator.pop(context, v),
                decoration: const InputDecoration(
                  labelText: '网址或搜索词',
                  hintText: 'https://example.com',
                  prefixIcon: Icon(Icons.travel_explore),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, controller.text),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('打开'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (result == null) return;
    await _openUrl(result);
  }

  Future<void> _openUrl(String input) async {
    final normalized = UrlUtils.normalize(input);
    final state = context.read<AppState>();
    await state.rememberOpenedUrl(normalized);
    if (_controller == null) {
      await _createController(state, initialUrl: normalized);
      return;
    }
    _lastError = null;
    await _controller!.loadRequest(Uri.parse(normalized));
  }

  Future<void> _share() async {
    final url = _currentUrl.value.trim().isNotEmpty ? _currentUrl.value : context.read<AppState>().launchUrl;
    await Share.share(url);
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(_currentUrl.value.trim().isNotEmpty ? _currentUrl.value : context.read<AppState>().launchUrl);
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
    final url = _currentUrl.value.trim().isNotEmpty ? _currentUrl.value : state.launchUrl;
    final title = _pageTitle.value.trim().isNotEmpty ? _pageTitle.value : state.appTitle;
    await state.toggleBookmark(url: url, title: title);
    if (!mounted) return;
    final marked = state.isBookmarked(url);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(marked ? '已加入书签' : '已移除书签')),
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
    _lastError = null;
    await c.reload();
  }

  Future<void> _goHome() async => _openUrl(context.read<AppState>().homeUrl);

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
    if (!state.isConfigured) return const _SetupPage();

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
          titleSpacing: 0,
          title: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _showOpenUrlSheet,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(state.appTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ValueListenableBuilder<String>(
                    valueListenable: _currentUrl,
                    builder: (context, url, _) => Text(
                      url.trim().isEmpty ? state.launchUrl : url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              tooltip: '打开网址',
              onPressed: _showOpenUrlSheet,
              icon: const Icon(Icons.search),
            ),
            ValueListenableBuilder<String>(
              valueListenable: _currentUrl,
              builder: (context, url, _) {
                final marked = state.isBookmarked(url.trim().isEmpty ? state.launchUrl : url);
                return IconButton(
                  tooltip: marked ? '移除书签' : '加入书签',
                  onPressed: controller == null ? null : _toggleBookmark,
                  icon: Icon(marked ? Icons.bookmark : Icons.bookmark_border),
                );
              },
            ),
            IconButton(
              tooltip: '刷新',
              onPressed: controller == null ? null : () => _reload(),
              icon: const Icon(Icons.refresh),
            ),
            PopupMenuButton<String>(
              tooltip: '更多',
              onSelected: (value) async {
                switch (value) {
                  case 'back':
                    await _handleBack();
                    break;
                  case 'forward':
                    if (await (_controller?.canGoForward() ?? Future.value(false))) {
                      await _controller?.goForward();
                    }
                    break;
                  case 'home':
                    await _goHome();
                    break;
                  case 'share':
                    await _share();
                    break;
                  case 'copy':
                    await _copyLink();
                    break;
                  case 'external':
                    await _openExternal();
                    break;
                  case 'hardReload':
                    await _reload(hard: true);
                    break;
                  case 'settings':
                    await _openSettings();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'back', child: ListTile(leading: Icon(Icons.arrow_back), title: Text('后退'))),
                PopupMenuItem(value: 'forward', child: ListTile(leading: Icon(Icons.arrow_forward), title: Text('前进'))),
                PopupMenuItem(value: 'home', child: ListTile(leading: Icon(Icons.home_outlined), title: Text('回到主页'))),
                PopupMenuDivider(),
                PopupMenuItem(value: 'share', child: ListTile(leading: Icon(Icons.share), title: Text('分享'))),
                PopupMenuItem(value: 'copy', child: ListTile(leading: Icon(Icons.copy), title: Text('复制链接'))),
                PopupMenuItem(value: 'external', child: ListTile(leading: Icon(Icons.open_in_new), title: Text('外部浏览器打开'))),
                PopupMenuDivider(),
                PopupMenuItem(value: 'hardReload', child: ListTile(leading: Icon(Icons.delete_sweep), title: Text('清理缓存后刷新'))),
                PopupMenuItem(value: 'settings', child: ListTile(leading: Icon(Icons.tune), title: Text('设置'))),
              ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: ValueListenableBuilder<int>(
              valueListenable: _progress,
              builder: (context, p, _) => p >= 100 ? const SizedBox(height: 2) : LinearProgressIndicator(value: p / 100.0),
            ),
          ),
        ),
        body: Stack(
          children: [
            if (controller == null)
              const Center(child: CircularProgressIndicator())
            else
              WebViewWidget(controller: controller),
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
            if (_isOffline) _OfflineBanner(onRetry: () => _reload()),
            if (_lastError != null) _ErrorOverlay(error: _lastError!, onClose: () => setState(() => _lastError = null), onRetry: () => _reload()),
          ],
        ),
      ),
    );
  }
}

class _SetupPage extends StatefulWidget {
  const _SetupPage();

  @override
  State<_SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<_SetupPage> {
  final _titleCtrl = TextEditingController(text: 'LinkWeb');
  final _urlCtrl = TextEditingController();
  OrientationLock _orientation = OrientationLock.followSystem;
  bool _desktopMode = false;
  bool _javascriptEnabled = true;
  bool _resumeLastUrl = true;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<AppState>().saveInitialSetup(
            appTitle: _titleCtrl.text,
            homeUrl: _urlCtrl.text,
            orientationLock: _orientation,
            desktopMode: _desktopMode,
            javascriptEnabled: _javascriptEnabled,
            resumeLastUrl: _resumeLastUrl,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Invalid argument(s): ', ''))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 20),
            Icon(Icons.web_asset, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('输入网页，直接变成 App', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              '这里只保存真正会影响运行的配置。保存后刷新、重启都从已保存的网址和方向设置恢复。',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _titleCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'App 名称',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlCtrl,
              autofocus: true,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                labelText: '要打开的网页',
                hintText: 'https://example.com',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('方向锁定', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: OrientationLock.values
                  .map(
                    (lock) => ChoiceChip(
                      label: Text(lock.label),
                      selected: _orientation == lock,
                      onSelected: (_) => setState(() => _orientation = lock),
                    ),
                  )
                  .toList(),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_orientation.description, style: Theme.of(context).textTheme.bodySmall),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('重启后继续上次页面'),
              value: _resumeLastUrl,
              onChanged: (v) => setState(() => _resumeLastUrl = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('桌面模式'),
              subtitle: const Text('给网页使用桌面浏览器 UA'),
              value: _desktopMode,
              onChanged: (v) => setState(() => _desktopMode = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用 JavaScript'),
              value: _javascriptEnabled,
              onChanged: (v) => setState(() => _javascriptEnabled = v),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.rocket_launch),
              label: Text(_saving ? '保存中...' : '保存并进入 App'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final VoidCallback onRetry;

  const _OfflineBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Positioned(
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
              TextButton(onPressed: onRetry, child: const Text('重试')),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  final String error;
  final VoidCallback onClose;
  final VoidCallback onRetry;

  const _ErrorOverlay({required this.error, required this.onClose, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Theme.of(context).colorScheme.surface.withAlpha(235),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text('加载失败', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(error, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(onPressed: onClose, icon: const Icon(Icons.close), label: const Text('关闭')),
                    FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('重试')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
