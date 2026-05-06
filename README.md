# LinkWeb

把任意网页变成独立 App 的 Flutter WebView 壳应用。

这版重点重写了运行逻辑：先输入网页，再进入 App；所有会影响运行的输入都会写入持久化状态，刷新、重启、切换设置都不会回到旧值。

## 功能

- 首次启动配置页：App 名称、网页地址、方向锁定、桌面模式、JavaScript、是否继续上次页面。
- 网页容器：后退、前进、主页、刷新、分享、复制链接、外部浏览器打开。
- 地址输入：支持网址，也支持关键词搜索。
- 持久化恢复：主页网址、最近访问网址、方向锁定、主题、WebView 偏好、书签和历史都会保存。
- 方向控制：跟随系统、锁定竖屏、锁定横屏、允许旋转；网页视频全屏可临时横屏，退出全屏后恢复 App 自己的方向设置。
- 书签和历史：收藏当前页、历史记录、长按删除书签、清空书签/历史。
- 浏览能力：桌面 UA、JavaScript 开关、清缓存、清 Cookie。
- 离线提示和加载失败重试。

## 目录结构

- `app/lib/main.dart`：入口和全局异常处理。
- `app/lib/src/app.dart`：MaterialApp、主题和状态注入。
- `app/lib/src/core/app_state.dart`：唯一的持久化状态层。
- `app/lib/src/core/url_utils.dart`：网址和搜索词规范化。
- `app/lib/src/ui/home/home_page.dart`：首次配置页和 WebView 主工作台。
- `app/lib/src/ui/settings/settings_sheet.dart`：设置、书签、历史和清理操作。
- `app/lib/src/models/bookmark.dart`：书签模型。

## 本地运行

```bash
cd app
flutter pub get
flutter run
```

## 测试

```bash
cd app
flutter analyze
flutter test
```
