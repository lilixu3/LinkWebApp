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
  bool _savingBasics = false;

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

  Future<void> _saveBasics({bool openHome = false}) async {
    setState(() => _savingBasics = true);
    try {
      if (_homeCtrl.text.trim().isEmpty) {
        throw ArgumentError('请输入网页地址');
      }
      final state = context.read<AppState>();
      await state.setAppTitle(_titleCtrl.text);
      await state.setHomeUrl(_homeCtrl.text);
      if (openHome) await widget.onOpenUrl(state.homeUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Invalid argument(s): ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _savingBasics = false);
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmText)),
        ],
      ),
    );
    if (ok != true) return;
    await run();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已完成')));
    }
  }

  Future<void> _setCurrentAsHome() async {
    final current = widget.currentUrl.trim();
    if (current.isEmpty) return;
    _homeCtrl.text = current;
    await _saveBasics();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 16),
        children: [
          Row(
            children: [
              Expanded(child: Text('设置', style: Theme.of(context).textTheme.titleLarge)),
              IconButton(tooltip: '关闭', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          if (widget.currentUrl.trim().isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.public),
              title: Text(
                widget.currentTitle.trim().isEmpty ? '当前页面' : widget.currentTitle.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(widget.currentUrl, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          const SizedBox(height: 8),
          _SectionCard(
            title: '网页 App',
            subtitle: '这些配置会持久保存，重启和刷新不会回到旧值。',
            children: [
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
                controller: _homeCtrl,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _saveBasics(openHome: true),
                decoration: const InputDecoration(
                  labelText: '主页网址',
                  hintText: 'https://example.com',
                  prefixIcon: Icon(Icons.home_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _savingBasics ? null : () => _saveBasics(),
                    icon: const Icon(Icons.save),
                    label: Text(_savingBasics ? '保存中...' : '保存'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _savingBasics ? null : () => _saveBasics(openHome: true),
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('保存并打开主页'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.currentUrl.trim().isEmpty ? null : _setCurrentAsHome,
                    icon: const Icon(Icons.my_location),
                    label: const Text('当前页设为主页'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('启动时继续上次页面'),
                subtitle: const Text('关闭后每次启动都打开主页。'),
                value: state.resumeLastUrl,
                onChanged: state.setResumeLastUrl,
              ),
            ],
          ),
          _SectionCard(
            title: '方向锁定',
            subtitle: '方向由 App 状态统一控制，退出全屏后会恢复这里的设置。',
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: OrientationLock.values
                    .map(
                      (lock) => ChoiceChip(
                        label: Text(lock.label),
                        selected: state.orientationLock == lock,
                        onSelected: (_) => state.setOrientationLock(lock),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              Text(state.orientationLock.description, style: Theme.of(context).textTheme.bodySmall),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('网页全屏时临时横屏'),
                subtitle: const Text('视频全屏时横屏，退出全屏后恢复上方方向锁定。'),
                value: state.fullscreenLandscape,
                onChanged: state.setFullscreenLandscape,
              ),
            ],
          ),
          _SectionCard(
            title: '浏览能力',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('桌面模式（Desktop UA）'),
                subtitle: const Text('切换后会重建 WebView 并继续当前页面。'),
                value: state.desktopMode,
                onChanged: state.setDesktopMode,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('启用 JavaScript'),
                subtitle: const Text('关闭后很多网站无法正常运行。'),
                value: state.javascriptEnabled,
                onChanged: state.setJavascriptEnabled,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => widget.onOpenUrl(UrlUtils.normalize(widget.currentUrl.isEmpty ? state.launchUrl : widget.currentUrl)),
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
            ],
          ),
          _SectionCard(
            title: '外观',
            children: [
              const Text('主题', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
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
                  ChoiceChip(label: const Text('无'), selected: state.effect == EffectType.none, onSelected: (_) => state.setEffect(EffectType.none)),
                  ChoiceChip(label: const Text('雪花'), selected: state.effect == EffectType.snow, onSelected: (_) => state.setEffect(EffectType.snow)),
                  ChoiceChip(label: const Text('樱花'), selected: state.effect == EffectType.sakura, onSelected: (_) => state.setEffect(EffectType.sakura)),
                ],
              ),
            ],
          ),
          _SectionCard(
            title: '书签和历史',
            children: [
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _confirmAndRun(
                      title: '清除缓存',
                      content: '将清除 WebView 缓存。不会删除你保存的主页、方向、书签和历史。',
                      run: widget.onClearCache,
                    ),
                    icon: const Icon(Icons.layers_clear),
                    label: const Text('清除缓存'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _confirmAndRun(
                      title: '清除 Cookies',
                      content: '会退出网页登录状态，但不会影响 App 设置。',
                      run: widget.onClearCookies,
                    ),
                    icon: const Icon(Icons.cookie_outlined),
                    label: const Text('清除 Cookies'),
                  ),
                ],
              ),
            ],
          ),
          OutlinedButton.icon(onPressed: () => _showAbout(context), icon: const Icon(Icons.info_outline), label: const Text('关于')),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    final p = _pkg;
    final v = p == null ? '' : '${p.version}+${p.buildNumber}';
    showAboutDialog(
      context: context,
      applicationName: context.read<AppState>().appTitle,
      applicationVersion: v,
      applicationIcon: const Icon(Icons.web, size: 48),
      children: const [
        Text('LinkWeb 是一个网页 App 容器：输入一个网址，就可以像独立 App 一样运行。'),
        SizedBox(height: 8),
        Text('设置、方向、最近页面、书签和历史都持久保存，不依赖临时输入框状态。'),
      ],
    );
  }

  Future<void> _showBookmarks(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scroll) {
          final state = context.watch<AppState>();
          final items = state.bookmarks;
          return ListView(
            controller: scroll,
            children: [
              ListTile(
                title: const Text('书签', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('点击打开，长按删除。'),
                trailing: items.isEmpty
                    ? null
                    : TextButton(
                        onPressed: () => _confirmAndRun(
                          title: '清空书签',
                          content: '确定清空所有书签？',
                          run: state.clearBookmarks,
                        ),
                        child: const Text('清空'),
                      ),
              ),
              if (items.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('暂无书签'))),
              ...items.map(
                (b) => ListTile(
                  leading: const Icon(Icons.bookmark),
                  title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(b.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () async {
                    Navigator.pop(context);
                    Navigator.pop(this.context);
                    await widget.onOpenUrl(b.url);
                  },
                  onLongPress: () => state.removeBookmark(b.url),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showHistory(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scroll) {
          final state = context.watch<AppState>();
          final items = state.urlHistory;
          return ListView(
            controller: scroll,
            children: [
              ListTile(
                title: const Text('历史记录', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('点击打开。'),
                trailing: items.isEmpty
                    ? null
                    : TextButton(
                        onPressed: () => _confirmAndRun(
                          title: '清空历史记录',
                          content: '确定清空历史记录？',
                          run: state.clearHistory,
                        ),
                        child: const Text('清空'),
                      ),
              ),
              if (items.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('暂无历史'))),
              ...items.map(
                (url) => ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () async {
                    Navigator.pop(context);
                    Navigator.pop(this.context);
                    await widget.onOpenUrl(url);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _SectionCard({required this.title, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
