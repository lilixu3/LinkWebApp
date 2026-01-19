import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/url_utils.dart';

class SettingsSheet extends StatefulWidget {
  final String currentUrl;
  final String currentTitle;
  final Future<void> Function(String url) onOpenUrl;
  final Future<void> Function() onClearCache;
  final Future<void> Function() onClearCookies;

  const SettingsSheet({
    super.key,
    required this.currentUrl,
    required this.currentTitle,
    required this.onOpenUrl,
    required this.onClearCache,
    required this.onClearCookies,
  });

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _homeCtrl;
  PackageInfo? _pkg;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _titleCtrl = TextEditingController(text: state.appTitle);
    _homeCtrl = TextEditingController(text: state.homeUrl);
    PackageInfo.fromPlatform().then((p) {
      if (mounted) setState(() => _pkg = p);
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _homeCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveBasics() async {
    final state = context.read<AppState>();
    await state.setAppTitle(_titleCtrl.text);
    await state.setHomeUrl(_homeCtrl.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
    }
  }

  Future<void> _confirmAndRun({
    required String title,
    required String content,
    required Future<void> Function() run,
    String confirmText = '确定',
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    if (ok == true) {
      await run();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已完成')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.only(left: 16, right: 16, bottom: bottom + 16, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),

          // App basics
          Text('基础设置', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),

          const Text('应用标题', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.title),
              hintText: '例如：我的网页 App',
            ),
          ),
          const SizedBox(height: 12),

          const Text('主页网址（Home URL）', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _homeCtrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.home),
              hintText: '例如：https://news.ycombinator.com',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '💡 支持直接输入关键词当搜索；不带 http/https 会自动补上 https://',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                ),
          ),
          const SizedBox(height: 12),

          FilledButton.icon(
            onPressed: _saveBasics,
            icon: const Icon(Icons.save),
            label: const Text('保存'),
          ),

          const Divider(height: 32),

          // Web settings
          Text('浏览设置', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('桌面模式（Desktop UA）'),
            subtitle: const Text('有些网站在桌面模式下布局更完整；切换后需重新加载页面生效'),
            value: state.desktopMode,
            onChanged: (v) => state.setDesktopMode(v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('启用 JavaScript'),
            subtitle: const Text('关闭可提升安全性，但可能导致部分站点不可用'),
            value: state.javascriptEnabled,
            onChanged: (v) => state.setJavascriptEnabled(v),
          ),

          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => widget.onOpenUrl(UrlUtils.normalize(widget.currentUrl)),
                icon: const Icon(Icons.refresh),
                label: const Text('重新加载当前页'),
              ),
              OutlinedButton.icon(
                onPressed: () => widget.onOpenUrl(state.homeUrl),
                icon: const Icon(Icons.home),
                label: const Text('回到主页'),
              ),
            ],
          ),

          const Divider(height: 32),

          // Theme
          Text('外观', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),

          const Text('主题', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('跟随系统'),
                avatar: const Icon(Icons.brightness_auto, size: 18),
                selected: state.themeMode == ThemeMode.system,
                onSelected: (_) => state.setThemeMode(ThemeMode.system),
              ),
              ChoiceChip(
                label: const Text('浅色'),
                avatar: const Icon(Icons.light_mode, size: 18),
                selected: state.themeMode == ThemeMode.light,
                onSelected: (_) => state.setThemeMode(ThemeMode.light),
              ),
              ChoiceChip(
                label: const Text('深色'),
                avatar: const Icon(Icons.dark_mode, size: 18),
                selected: state.themeMode == ThemeMode.dark,
                onSelected: (_) => state.setThemeMode(ThemeMode.dark),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const Text('飘落特效', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('无'),
                avatar: const Icon(Icons.block, size: 18),
                selected: state.effect == EffectType.none,
                onSelected: (_) => state.setEffect(EffectType.none),
              ),
              ChoiceChip(
                label: const Text('雪花 ❄️'),
                selected: state.effect == EffectType.snow,
                onSelected: (_) => state.setEffect(EffectType.snow),
              ),
              ChoiceChip(
                label: const Text('樱花 🌸'),
                selected: state.effect == EffectType.sakura,
                onSelected: (_) => state.setEffect(EffectType.sakura),
              ),
            ],
          ),

          const Divider(height: 32),

          // Data
          Text('数据', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bookmark_border),
            title: const Text('书签'),
            subtitle: Text('共 ${state.bookmarks.length} 个'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showBookmarks(context),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history),
            title: const Text('历史记录'),
            subtitle: Text('共 ${state.urlHistory.length} 条'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showHistory(context),
          ),

          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _confirmAndRun(
                  title: '清除缓存',
                  content: '将清除 WebView 缓存并建议重新加载页面。',
                  run: widget.onClearCache,
                ),
                icon: const Icon(Icons.layers_clear),
                label: const Text('清除缓存'),
              ),
              OutlinedButton.icon(
                onPressed: () => _confirmAndRun(
                  title: '清除 Cookies',
                  content: '将清除 WebView Cookies（可能会导致你退出登录）。',
                  run: widget.onClearCookies,
                ),
                icon: const Icon(Icons.cookie_outlined),
                label: const Text('清除 Cookies'),
              ),
            ],
          ),

          const Divider(height: 32),

          // About
          OutlinedButton.icon(
            onPressed: () => _showAbout(context),
            icon: const Icon(Icons.info_outline),
            label: const Text('关于'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAbout(BuildContext context) async {
    final p = _pkg;
    final v = p == null ? '' : '${p.version}+${p.buildNumber}';
    showAboutDialog(
      context: context,
      applicationName: context.read<AppState>().appTitle,
      applicationVersion: v,
      applicationIcon: const Icon(Icons.web, size: 48),
      children: const [
        Text('轻量级网页容器（WebView）应用：把任何网址变成独立 App。'),
        SizedBox(height: 8),
        Text('功能：书签、历史、离线提醒、桌面模式、JavaScript 开关、主题/特效、清理缓存与 Cookies。'),
      ],
    );
  }

  Future<void> _showBookmarks(BuildContext context) async {
    final state = context.read<AppState>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scroll) {
          final items = context.watch<AppState>().bookmarks;
          return ListView(
            controller: scroll,
            children: [
              const ListTile(
                title: Text('书签', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('点击打开；长按删除。'),
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('暂无书签')), 
                ),
              ...items.map(
                (b) => ListTile(
                  leading: const Icon(Icons.bookmark),
                  title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(b.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () async {
                    Navigator.pop(context);
                    await widget.onOpenUrl(b.url);
                    if (mounted) Navigator.pop(this.context);
                  },
                  onLongPress: () async {
                    await _confirmAndRun(
                      title: '删除书签',
                      content: '确定删除这个书签吗？',
                      run: () => state.removeBookmark(b.url),
                      confirmText: '删除',
                    );
                  },
                ),
              ),
              if (items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmAndRun(
                      title: '清空书签',
                      content: '确定清空所有书签吗？',
                      run: state.clearBookmarks,
                      confirmText: '清空',
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('清空全部'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showHistory(BuildContext context) async {
    final state = context.read<AppState>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scroll) {
          final items = context.watch<AppState>().urlHistory;
          return ListView(
            controller: scroll,
            children: [
              const ListTile(
                title: Text('历史记录', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('点击打开；最多保留 25 条。'),
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('暂无历史记录')),
                ),
              ...items.map(
                (url) => ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () async {
                    Navigator.pop(context);
                    await widget.onOpenUrl(url);
                    if (mounted) Navigator.pop(this.context);
                  },
                ),
              ),
              if (items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmAndRun(
                      title: '清空历史记录',
                      content: '确定清空历史记录吗？',
                      run: state.clearHistory,
                      confirmText: '清空',
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('清空全部'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
