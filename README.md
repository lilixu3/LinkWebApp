# LinkWeb

把任意网页“打包成独立 App”的轻量 WebView 壳应用（Flutter）。
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
