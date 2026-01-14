# LinkWeb（把网页当 App 用）

这是一个 Flutter 项目**源码包**：
- 你在 App 里填一个链接（URL）→ 保存
- 下次打开 App 自动打开这个链接
- 支持 主题：跟随系统 / 浅色 / 深色
- 支持 飘落特效：无 / 雪花 / 樱花

> 构建产物：Android APK（可直接装到手机）。

## 1) 把源码放到 GitHub（只用手机也可以）
1. 在 GitHub 新建一个仓库（Public/Private 都行）。
2. 把本压缩包解压后，**把里面所有文件**上传到仓库根目录。
   - GitHub 网页端有 “Add file → Upload files”
3. 进仓库的 Actions 标签页，等构建完成。

## 2) 下载 APK
- 方式 A（推荐）：你打一个 tag（例如 `v0.1.0`）后，Actions 会自动创建 Release 并把 APK 放到 Release 资产里。
- 方式 B：直接从 Actions 的 Artifacts 下载 `app-release.apk`。

## 3) 安装到 Android
手机开启「允许安装未知来源应用」后，点 APK 安装即可。

## 4) 自定义（可选）
- App 名称：在 `app/android/app/src/main/AndroidManifest.xml` 里改 `android:label`
- 包名（更复杂）：需要改 `flutter create` 的 `--org` 或手动修改 Android 工程（建议后续有电脑再弄）

---
