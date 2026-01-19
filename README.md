# LinkWeb

把任意网页“打包成独立 App”的轻量 WebView 壳应用（Flutter）。

> 这一版已按“可上架/可长期维护”的思路做了结构化重构和功能补齐：
> - 安卓返回键适配（优先网页后退，不会直接退出）
> - 更完善的导航栏/常用操作：分享、复制链接、外部浏览器打开
> - URL 输入支持“搜索词”直接搜索（像浏览器地址栏一样）
> - 网络离线提示 + 失败重试提示
> - 书签（收藏）+ 历史记录（可清空）
> - 桌面模式（Desktop UA）开关、JavaScript 开关
> - 一键清缓存/清 Cookie
> - 代码结构拆分（可测、可扩展）、全局异常日志
> - 预置应用图标 + 可一键生成上架所需图标/启动页（flutter_launcher_icons / flutter_native_splash）

## 目录结构

- `app/lib/main.dart`：入口（含全局异常处理）
- `app/lib/src/core/`：状态/工具/日志
- `app/lib/src/models/`：数据模型（书签等）
- `app/lib/src/ui/`：页面与组件

## 快速开始

```bash
cd app
flutter pub get
flutter run
```

## 打包发布（Android）

```bash
cd app
flutter build apk --release
# 或：flutter build appbundle --release
```

### 生成应用图标/启动页

项目已配置：
- 图标：`flutter_launcher_icons`
- 启动页：`flutter_native_splash`

命令：
```bash
cd app
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

图标源文件：`app/assets/icon.png`（你可以换成自己的 1024x1024 PNG）。

## 使用说明

- 右下角“打开”按钮：输入 URL 或直接输入搜索词
- 顶部工具栏：后退/前进/主页/刷新/收藏/设置
- 设置：应用标题、主页网址、主题、飘落特效、桌面模式、JS 开关、书签、历史记录、清缓存/清 Cookie

## 上架建议（你可以按需完善）

- 配置 `android/app/src/main/AndroidManifest.xml` 的 `android:label`、`package`、权限说明
- 补齐隐私政策与数据收集声明（如果要上架 Google Play 基本都需要）
- 增加 Sentry / Firebase Crashlytics 等崩溃采集（可选）
- 针对你的目标站点做 scheme/深链处理（例如 `weixin://`、`alipays://` 等）

---

如果你告诉我：
1) 目标上架平台（Google Play / 国内应用市场 / iOS App Store）
2) 你希望的默认主页、品牌名、配色、包名（applicationId）

我可以继续把 Android/iOS 的工程侧（包名、签名、启动页、权限、隐私文案）也一起做成更“交付级”。
