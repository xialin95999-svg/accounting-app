# 小牛记账 App

数据存在你自己 NAS 的个人记账应用，支持 iOS、Android、Windows。

---

## 文件结构

```
accounting-app/
├── SPEC.md                    ← 产品规格说明书
├── backend/
│   ├── server.js              ← 后端 API 服务
│   ├── package.json
│   └── data/                  ← 用户数据（每个手机号一个 .json 文件）
└── flutter_app/               ← Flutter 前端
    ├── pubspec.yaml
    ├── lib/
    │   ├── main.dart
    │   ├── api/api_service.dart
    │   ├── providers/auth_provider.dart
    │   └── screens/
    │       ├── login_screen.dart
    │       ├── home_screen.dart
    │       ├── add_record_screen.dart
    │       ├── bill_screen.dart
    │       ├── mine_screen.dart
    │       ├── category_manage_screen.dart
    │       └── account_manage_screen.dart
    └── android/app/src/main/AndroidManifest.xml
```

---

## 后端部署（NAS）

后端已启动在：`http://192.168.31.150:3848`

**手动重启后端：**
```bash
cd /vol1/@apphome/trim.openclaw/data/workspace/accounting-app/backend
node server.js
```

**开机自启（可选）：**
将上面的命令加到 NAS 的启动脚本里。

---

## 前端构建

### 1. 安装 Flutter SDK

访问 [flutter.dev](https://flutter.dev) 下载安装（Mac/Windows/Linux 都支持）。

### 2. 修改 API 地址

打开 `lib/api/api_service.dart`，把 `BASE_URL` 改成你的 NAS 地址：

```dart
const String BASE_URL = 'http://192.168.31.150:3848';
```

如果是外网访问，改为你的公网地址或内网穿透地址。

### 3. 构建 iOS（需要 Mac）

```bash
cd flutter_app
flutter pub get
flutter build ios --release
```

### 4. 构建 Android

```bash
cd flutter_app
flutter pub get
flutter build apk --release
```

APK 文件生成在：`build/app/outputs/flutter-apk/app-release.apk`

### 5. 构建 Windows

```bash
cd flutter_app
flutter pub get
flutter build windows --release
```

---

## 功能清单

| 功能 | 状态 |
|------|------|
| 手机号+PIN 注册/登录 | ✅ |
| 记一笔（金额/分类/日期/备注） | ✅ |
| 首页（本月结余、收入、支出） | ✅ |
| 最近记录列表 | ✅ |
| 月账单（收支汇总） | ✅ |
| 日支出趋势图 | ✅ |
| 分类统计（饼图+列表） | ✅ |
| 分类管理（增删） | ✅ |
| 账户管理（增删） | ✅ |
| 导出 CSV | ✅ |
| 多设备同步 | ✅（共用NAS数据）|
| iOS 打包 | 待用户Mac |
| Android 打包 | 待Flutter SDK |
| Windows 打包 | 待Flutter SDK |

---

## 技术栈

- **前端**：Flutter + Riverpod
- **后端**：Node.js + Express（JSON 文件存储）
- **数据**：每个用户一个 JSON 文件在 NAS 上
- **协议**：HTTP REST API
