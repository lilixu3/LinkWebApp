import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LinkWebApp());
}

enum EffectType { none, snow, sakura }

class AppState extends ChangeNotifier {
  static const _kUrl = 'home_url';
  static const _kThemeMode = 'theme_mode'; // 0 system, 1 light, 2 dark
  static const _kEffect = 'effect_type'; // 0 none, 1 snow, 2 sakura

  final SharedPreferences _prefs;

  AppState._(this._prefs) {
    _url = _prefs.getString(_kUrl) ?? 'https://example.com';
    _themeMode = ThemeMode.values[_prefs.getInt(_kThemeMode) ?? 0];
    _effect = EffectType.values[_prefs.getInt(_kEffect) ?? 0];
  }

  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppState._(prefs);
  }

  late String _url;
  late ThemeMode _themeMode;
  late EffectType _effect;

  String get url => _url;
  ThemeMode get themeMode => _themeMode;
  EffectType get effect => _effect;

  Future<void> setUrl(String url) async {
    _url = _normalizeUrl(url);
    await _prefs.setString(_kUrl, _url);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt(_kThemeMode, mode.index);
    notifyListeners();
  }

  Future<void> setEffect(EffectType type) async {
    _effect = type;
    await _prefs.setInt(_kEffect, type.index);
    notifyListeners();
  }

  static String _normalizeUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'https://example.com';
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return 'https://example.com';
    if (uri.hasScheme) return trimmed;
    return 'https://$trimmed';
  }
}

class LinkWebApp extends StatefulWidget {
  const LinkWebApp({super.key});

  @override
  State<LinkWebApp> createState() => _LinkWebAppState();
}

class _LinkWebAppState extends State<LinkWebApp> {
  AppState? _state;

  @override
  void initState() {
    super.initState();
    AppState.load().then((s) => setState(() => _state = s));
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == null) {
      return const MaterialApp(home: Splash());
    }

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'LinkWeb',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
          ),
          themeMode: state.themeMode,
          home: HomePage(state: state),
        );
      },
    );
  }
}

class Splash extends StatelessWidget {
  const Splash({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class HomePage extends StatefulWidget {
  final AppState state;
  const HomePage({super.key, required this.state});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final WebViewController _controller;
  final ValueNotifier<int> _progress = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => _progress.value = p,
          onWebResourceError: (_) {},
        ),
      )
      ..loadRequest(Uri.parse(widget.state.url));
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SettingsSheet(
        state: widget.state,
        onOpenUrl: (url) async {
          await _controller.loadRequest(Uri.parse(url));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effect = widget.state.effect;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LinkWeb'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () => _controller.reload(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '设置',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
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
          WebViewWidget(controller: _controller),
          if (effect != EffectType.none)
            IgnorePointer(
              child: LayoutBuilder(
                builder: (context, constraints) => FallingEffectOverlay(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  type: effect,
                  dark: isDark,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SettingsSheet extends StatefulWidget {
  final AppState state;
  final Future<void> Function(String url) onOpenUrl;

  const SettingsSheet({
    super.key,
    required this.state,
    required this.onOpenUrl,
  });

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late final TextEditingController _urlCtrl;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: widget.state.url);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndOpen() async {
    final before = widget.state.url;
    await widget.state.setUrl(_urlCtrl.text);
    final after = widget.state.url;
    if (after != before) {
      await widget.onOpenUrl(after);
    } else {
      await widget.onOpenUrl(after);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, bottom: bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Text('网址（URL）', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _urlCtrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: '例如：https://news.ycombinator.com',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saveAndOpen,
            icon: const Icon(Icons.open_in_browser),
            label: const Text('保存并打开'),
          ),
          const SizedBox(height: 20),

          const Text('主题', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('跟随系统'),
                selected: state.themeMode == ThemeMode.system,
                onSelected: (_) => state.setThemeMode(ThemeMode.system),
              ),
              ChoiceChip(
                label: const Text('浅色'),
                selected: state.themeMode == ThemeMode.light,
                onSelected: (_) => state.setThemeMode(ThemeMode.light),
              ),
              ChoiceChip(
                label: const Text('深色'),
                selected: state.themeMode == ThemeMode.dark,
                onSelected: (_) => state.setThemeMode(ThemeMode.dark),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const Text('飘落特效', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('无'),
                selected: state.effect == EffectType.none,
                onSelected: (_) => state.setEffect(EffectType.none),
              ),
              ChoiceChip(
                label: const Text('雪花'),
                selected: state.effect == EffectType.snow,
                onSelected: (_) => state.setEffect(EffectType.snow),
              ),
              ChoiceChip(
                label: const Text('樱花'),
                selected: state.effect == EffectType.sakura,
                onSelected: (_) => state.setEffect(EffectType.sakura),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(
            '提示：如果你填的是不带 http/https 的域名，我会自动补上 https://',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class FallingEffectOverlay extends StatefulWidget {
  final double width;
  final double height;
  final EffectType type;
  final bool dark;

  const FallingEffectOverlay({
    super.key,
    required this.width,
    required this.height,
    required this.type,
    required this.dark,
  });

  @override
  State<FallingEffectOverlay> createState() => _FallingEffectOverlayState();
}

class _FallingEffectOverlayState extends State<FallingEffectOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tick;
  late final math.Random _rand;
  late List<_Particle> _particles;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _rand = math.Random();
    _tick = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_onFrame);
    _reseed();
    _tick.repeat();
  }

  @override
  void didUpdateWidget(covariant FallingEffectOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recreate particles when effect type changes or size changes significantly.
    if (oldWidget.type != widget.type ||
        (oldWidget.width - widget.width).abs() > 8 ||
        (oldWidget.height - widget.height).abs() > 8) {
      _reseed();
    }
  }

  void _reseed() {
    final area = widget.width * widget.height;
    // Rough density: 1 particle per ~18k px^2 (tuned for phones)
    _count = (area / 18000).clamp(18, 90).toInt();
    _particles = List.generate(_count, (_) => _Particle.random(_rand, widget));
    setState(() {});
  }

  void _onFrame() {
    for (final p in _particles) {
      p.update(widget, _rand);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(widget.width, widget.height),
        painter: _ParticlePainter(
          particles: _particles,
          type: widget.type,
          dark: widget.dark,
        ),
      ),
    );
  }
}

class _Particle {
  double x;
  double y;
  double size;
  double speed;
  double drift;
  double rotation;
  double spin;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.drift,
    required this.rotation,
    required this.spin,
  });

  static _Particle random(math.Random r, FallingEffectOverlay w) {
    final baseSize = w.type == EffectType.snow ? 3.0 : 6.0;
    final s = baseSize + r.nextDouble() * baseSize;
    final sp = (w.type == EffectType.snow ? 30.0 : 55.0) + r.nextDouble() * 80.0;
    final d = (r.nextDouble() - 0.5) * (w.type == EffectType.snow ? 18.0 : 28.0);
    return _Particle(
      x: r.nextDouble() * w.width,
      y: r.nextDouble() * w.height,
      size: s,
      speed: sp,
      drift: d,
      rotation: r.nextDouble() * math.pi * 2,
      spin: (r.nextDouble() - 0.5) * (w.type == EffectType.snow ? 0.8 : 1.6),
    );
  }

  void update(FallingEffectOverlay w, math.Random r) {
    final dt = 1 / 60.0;
    y += speed * dt;
    x += drift * dt;
    rotation += spin * dt;

    // Wrap around.
    if (y > w.height + 24) {
      y = -24 - r.nextDouble() * w.height * 0.2;
      x = r.nextDouble() * w.width;
    }
    if (x < -24) x = w.width + 24;
    if (x > w.width + 24) x = -24;
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final EffectType type;
  final bool dark;

  _ParticlePainter({
    required this.particles,
    required this.type,
    required this.dark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (type == EffectType.none) return;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final p in particles) {
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      if (type == EffectType.snow) {
        paint.color = (dark ? Colors.white : Colors.white).withOpacity(0.75);
        canvas.drawCircle(Offset.zero, p.size, paint);
      } else if (type == EffectType.sakura) {
        // Simple petal: teardrop-ish path.
        final s = p.size;
        paint.color = (dark ? const Color(0xFFFFC1D9) : const Color(0xFFFF8FBF))
            .withOpacity(0.75);
        final path = Path()
          ..moveTo(0, -s)
          ..quadraticBezierTo(s * 0.85, -s * 0.25, 0, s)
          ..quadraticBezierTo(-s * 0.85, -s * 0.25, 0, -s)
          ..close();
        canvas.drawPath(path, paint);

        // A tiny highlight line to make it less flat.
        final stroke = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = (dark ? Colors.white : Colors.white).withOpacity(0.25);
        canvas.drawLine(Offset(0, -s * 0.7), Offset(0, s * 0.7), stroke);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return true;
  }
}
