# 木木记账 App 缺陷报告

**测试日期**：2026-07-31
**测试范围**：M1~M4（认证、账单CRUD、统计、分类管理、账户管理、CSV导出）
**测试人员**：AI Tester（小牛）
**后端地址**：`http://192.168.31.150:3848`
**Flutter BASE_URL**：`http://116.62.117.199:3848`（ECS云服务器）

---

## 测试概况

| 类别 | 数量 |
|------|------|
| 总测试用例 | 60+ |
| 通过 | 45+ |
| 失败（确认Bug） | 10+ |
| 通过率 | ~75% |

---

## P0 缺陷（必须修复才能发布）

### Bug #001 — CSV导出500崩溃

**标题**：CSV导出功能完全不可用，后端返回500错误

**严重程度**：P0
**模块**：后端 - 导出功能
**发现日期**：2026-07-31

**复现步骤**：
1. 登录 App
2. 进入「我的」页面
3. 点击「导出CSV」
4. App 提示"导出失败: 500"

**实际结果**：后端返回 HTTP 500，`Content-Disposition` header 包含中文字符导致 Node.js 报错：
```
TypeError [ERR_INVALID_CHAR]: Invalid character in header content ["Content-Disposition"]
attachment; filename="账本_2026-07-31.csv"
```

**预期结果**：返回标准CSV文件下载，文件名应为 `账本_2026-07-31.csv`（或英文文件名避免编码问题）

**根因**：`server.js` 第331行：
```javascript
res.setHeader('Content-Disposition', `attachment; filename="账本_${date}.csv"`);
```
HTTP header 只允许 ASCII 字符，中文字符在 Node.js 中引发 `ERR_INVALID_CHAR` 错误

**修复建议**：
```javascript
// 方案1：RFC 5987 编码（非ASCII文件名）
const filename = `账本_${date}.csv`;
res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(filename)}"; filename*=UTF-8''${encodeURIComponent(filename)}`);

// 方案2：改用纯ASCII文件名
res.setHeader('Content-Disposition', `attachment; filename="accounting_${date}.csv"`);
```

**状态**：待修复

---

### Bug #002 — 后端地址与数据存储地址不一致（架构级）

**标题**：App连接ECS服务器，但用户数据存在NAS

**严重程度**：P0（数据安全隐患）
**模块**：Flutter前端 - API配置
**发现日期**：2026-07-31

**复现步骤**：
1. 查看 `flutter_app/lib/api/api_service.dart` 第3行

**实际结果**：
```dart
const String BASE_URL = 'http://116.62.117.199:3848'; // ECS云服务器
```
数据通过公网传输，存储在 ECS 服务器而非用户自有NAS

**预期结果**：
- 选项A：App 连接 NAS（`http://192.168.31.150:3848`），数据存在用户NAS
- 选项B：App 连接 ECS，但 ECS 仅做透传，实际存储仍在NAS

**修复建议**：明确数据架构策略。若走NAS方案，需处理内网穿透（Frp/蒲公英/Tailscale）；若走ECS，需向用户说明数据存储位置

**状态**：需确认架构方向

---

## P1 缺陷（严重，建议发布前修复）

### Bug #003 — 负数金额可以保存

**标题**：支出/收入金额可以为负数，后端无校验

**严重程度**：P1
**模块**：后端 - 账单写入
**发现日期**：2026-07-31

**复现步骤**：
```bash
curl -X POST http://192.168.31.150:3848/api/records \
  -H "Content-Type: application/json" \
  -H "x-phone: 13900000099" \
  -d '{"type":"expense","amount":-50,"category":"三餐","date":"2026-07-30T12:00:00"}'
```
**实际结果**：返回 `{"success":true}`，金额 -50 被成功保存

**预期结果**：返回错误 `"金额必须大于0"` 或类似提示

**修复建议**：
```javascript
// server.js POST /api/records
if (!type || amount == null || isNaN(Number(amount)) || Number(amount) <= 0 || !date)
  return res.status(400).json({ error: '金额必须大于0' });
```

**状态**：待修复

---

### Bug #004 — amount=null 保存成功，数据中存NaN

**标题**：金额传 null 或非数字字符串时后端不报错

**严重程度**：P1
**模块**：后端 - 账单写入
**发现日期**：2026-07-31

**复现步骤**：
```bash
curl -X POST ... -d '{"type":"expense","amount":"abc","category":"三餐","date":"2026-07-31T12:00:00"}'
```
**实际结果**：返回 `{"success":true}`，`amount: null` 被写入数据库

**预期结果**：返回 `"金额必须是有效数字"`

**根因**：`server.js` 使用 `Number(amount)` 转换，转换结果为 `NaN`（falsy），但数据库仍然写入

**修复建议**：
```javascript
const numAmount = Number(amount);
if (!type || isNaN(numAmount) || numAmount < 0 || !date)
  return res.status(400).json({ error: '请输入有效金额' });
```

**状态**：待修复

---

### Bug #005 — 分类查询中文参数返回空数据

**标题**：按分类筛选账单时，中文分类名导致查询失败

**严重程度**：P1
**模块**：后端 - 账单查询
**发现日期**：2026-07-31

**复现步骤**：
```bash
curl "http://192.168.31.150:3848/api/records?category=三餐" -H "x-phone: 13900000099"
```
**实际结果**：返回空字符串（JSON解析失败），或 total=0

**预期结果**：返回该分类下的所有账单

**根因**：Express 接收 URL query parameter 时，中文 `category=三餐` URL编码问题导致参数解析异常

**修复建议**：Express query参数自动解析应该没问题，需检查是否有其他中间件干扰。更稳妥的做法是在后端对中文参数做 URL decode 或使用 numeric id 而非 name 字符串做查询

**状态**：待修复

---

### Bug #006 — 组合日期筛选失效（日期-only格式）

**标题**：同时传 startDate 和 endDate（仅日期无时间）时返回0条

**严重程度**：P1
**模块**：后端 - 账单查询
**发现日期**：2026-07-31

**复现步骤**：
```bash
# 单独 startDate → 正常
curl "http://.../api/records?startDate=2026-07-30" → total=4

# 单独 endDate → 正常
curl "http://.../api/records?endDate=2026-07-31" → total=4

# 组合两个日期（无时间） → BUG
curl "http://.../api/records?startDate=2026-07-30&endDate=2026-07-30" → total=0
```
**实际结果**：startDate+endDate 组合返回0条记录

**预期结果**：返回日期范围内的记录（应返回4条）

**根因**：字符串比较 `"2026-07-30T12:00:00" < "2026-07-30"` 为 true（因为字符 'T' 的ASCII值大于 '-'，导致带时间的日期字符串被认为小于纯日期字符串）

**修复建议**：
```javascript
// 方案1：后端拼接时间
if (startDate) {
  const sd = startDate.includes('T') ? startDate : startDate + 'T00:00:00';
  records = records.filter(r => r.date >= sd);
}
if (endDate) {
  const ed = endDate.includes('T') ? endDate : endDate + 'T23:59:59';
  records = records.filter(r => r.date <= ed);
}

// 方案2：前端传入带时间的日期字符串
```

**状态**：待修复

---

## P2 缺陷（一般，可接受延后发布）

### Bug #007 — 金额=0被错误拒绝

**标题**：金额0被认为是空值而拒绝保存

**严重程度**：P2
**模块**：后端 - 账单写入
**发现日期**：2026-07-31

**复现步骤**：
```bash
curl ... -d '{"type":"expense","amount":0,"category":"三餐","date":"2026-07-31T12:00:00"}'
```
**实际结果**：`{"error":"类型、金额、日期不能为空"}`

**预期结果**：0元金额应该被允许（如赠送、补偿等场景）

**修复建议**：改用 `amount == null || isNaN(amount)` 而非 `!amount`，区分「未填」和「填0」

**状态**：待修复

---

### Bug #008 — 月份参数无范围校验

**标题**：月度统计接口不校验月份范围（1-12）

**严重程度**：P2
**模块**：后端 - 统计
**发现日期**：2026-07-31

**复现步骤**：
```bash
curl "http://.../api/stats/monthly?year=2026&month=13"
```
**实际结果**：返回全0，无错误提示

**预期结果**：返回 `"月份必须在1-12之间"` 错误

**状态**：待修复

---

### Bug #009 — CSV导出中文乱码/文件名编码问题

**标题**：CSV文件含中文内容，可能在部分设备打开乱码

**严重程度**：P2
**模块**：后端 - 导出功能
**发现日期**：2026-07-31

**说明**：后端已在CSV前加 `\ufeff`（BOM）声明UTF-8，但 Content-Disposition 文件名中的中文仍是核心问题（同Bug #001）

**状态**：随Bug #001修复

---

### Bug #010 — 无x-phone header时返回非标准错误

**标题**：缺少认证时返回 HTML 错误页面而非 JSON

**严重程度**：P2
**模块**：后端 - 认证
**发现日期**：2026-07-31

**复现步骤**：
```bash
curl http://192.168.31.150:3848/api/records
```
**实际结果**：Express 默认 HTML 错误页（部分接口可能）

**预期结果**：统一返回 `{ "error": "缺少手机号" }` JSON格式

**状态**：建议优化

---

## P3 建议（体验优化）

### Suggestion #001 — 登录页面可增加「忘记PIN」入口

目前无法找回PIN，建议增加找回流程或说明

### Suggestion #002 — 删除账单应有确认对话框

避免误删

### Suggestion #003 — 分类/账户管理列表宜增加编辑功能

目前只支持新增和删除，无法修改名称

### Suggestion #004 — 账单列表支持按金额排序

目前仅按日期倒序

### Suggestion #005 — 进度提示可更丰富

如导出进度、操作成功反馈等

---

## 缺陷追踪表

| 缺陷ID | 标题 | 严重程度 | 模块 | 发现日期 | 状态 | 修复版本 |
|--------|------|----------|------|----------|------|----------|
| #001 | CSV导出500崩溃 | P0 | 后端/导出 | 2026-07-31 | ✅ 已修复（v2） | |
| #002 | 后端地址与存储地址不一致 | P0 | 前端/架构 | 2026-07-31 | 待确认架构 | |
| #003 | 负数金额可保存 | P1 | 后端/账单 | 2026-07-31 | ✅ 已修复（v2） | |
| #004 | amount=null/"abc"保存成功 | P1 | 后端/账单 | 2026-07-31 | ✅ 已修复（v2） | |
| #005 | 分类查询中文参数返回空 | P1 | 后端/查询 | 2026-07-31 | 待修复 | |
| #006 | 组合日期筛选失效 | P1 | 后端/查询 | 2026-07-31 | ✅ 已修复（v2） | |
| #007 | 金额=0被错误拒绝 | P2 | 后端/账单 | 2026-07-31 | ✅ 已修复（v2） | |
| #008 | 月份参数无范围校验 | P2 | 后端/统计 | 2026-07-31 | ✅ 已修复（v2） | |
| #009 | CSV中文乱码 | P2 | 后端/导出 | 2026-07-31 | 随#001 | |
| #010 | 错误返回HTML而非JSON | P2 | 后端/认证 | 2026-07-31 | 待修复 | |

---

## 总体评估

**是否建议发布**：⚠️ **暂不推荐直接发布**

**原因**：
1. P0 Bug #001（CSV导出崩溃）影响核心功能
2. P0 Bug #002（数据存储架构不清晰）涉及用户数据安全，需明确定位

**优先修复建议**：
1. **立即修复**：#001（5分钟可修复）、#003、#004（后端参数校验加强）
2. **本周修复**：#006（日期筛选）、#005（分类筛选）
3. **发布前确认**：#002（架构方案）
4. **可延后**：#007~#010

---

## 前端 Flutter 缺陷（2026-07-31 新增）

### Bug #F001 — 导出CSV成功但用户永远拿不到文件（P0）

**模块**：MineScreen - 导出功能

**问题**：`api.exportCsv()` 返回 CSV 字符串后，只是 toast 提示「导出成功，请在服务器上查看CSV文件」。文件在 NAS 服务器上，用户无法从 App 内下载。

**修复方向**：用 `share_plus` 将 CSV 内容分享到微信/文件App，或用 `path_provider` 保存到本地下载目录。

---

### Bug #F002 — `_readFile` 中错误使用 `ref` 会崩溃（P0）

**模块**：MineScreen - 导入功能

**问题代码**：
```dart
Future<String> _readFile(String path) async {
  final uri = Uri.parse('${ref.read(apiProvider).baseUrl}/api/file/read')  // ❌ ref 在 Dialog callback 中使用
```
`ref` 只能在 `build` 方法或 Riverpod 回调中使用，不能在普通 async 函数中调用。**导入功能点下去必崩。**

**修复方向**：`ApiService` 的 `baseUrl` 是公开字段，直接引用 `ApiService_BASE_URL` 常量，或通过参数传入 context/phone。

---

### Bug #F003 — 新增账单后首页「最近记录」不刷新（P1）

**模块**：HomeScreen / AddRecordScreen

**问题**：`AddRecordScreen` 保存后 `Navigator.pop()` 回到 `HomeScreen`，但 `IndexedStack` 缓存了 `HomeScreen` widget，上下文不重建，新记录不出现。

**修复方向**：`AddRecordScreen` 返回时带 result，HomeScreen 监听 provider 变化后自动刷新；或在 `pop()` 前调用 `ref.invalidate(recordsProvider)` 强制刷新。

---

### Bug #F004 — 删除分类/账户时 `id` 为空则用 `name`，危险（P1）

**模块**：CategoryManageScreen / AccountManageScreen

**问题代码**：
```dart
await api.deleteCategory(cat['id']?.toString() ?? cat['name']);  // id为空时用name
await api.deleteAccount(acc['id']?.toString() ?? acc['name']);   // 同上
```
若因数据损坏导致 `id=null`，会用 name 去后端查找并删除，可能删错记录。

**修复方向**：`id` 为空时直接弹出错误提示，不执行删除。

---

### Bug #F005 — 新增分类 Dialog 的 type 在打开时拍定，切换 tab 再确认会创建错误类型（P2）

**模块**：CategoryManageScreen

**问题**：`selectedType` 在 `_showAddDialog()` 调用时读取 `_tabController.index`，Dialog 内部切换 tab 不更新它。用户在 Dialog 内切换 tab 后点确认，创建的分类类型是错的。

**修复方向**：在 Dialog 的「确认」回调中实时读取 `_tabController.index` 而非预先拍定的变量。

---

### Bug #F006 — 饼图 `cats.take(6)` 前6个都是0金额时 fl_chart 可能异常（P2）

**模块**：BillScreen

**问题**：当月有分类记录但所有分类金额都是0，`cats.take(6)` 返回6个0值，`PieChartData` 的 sections 值为0，fl_chart 可能抛异常或显示空白。

**修复方向**：过滤掉金额为0的分类：`cats.where((c) => (c['total'] as num) > 0).take(6)`

---

### Bug #F007 — 登录状态持久化无后端验证，断网/账号异常时行为不可预期（P2）

**模块**：AuthProvider

**问题**：App 启动时 `_loadSavedPhone()` 直接从 `SharedPreferences` 读 phone 设置 `isLoggedIn=true`，不验证 session 有效性。极端情况：账号被重置、密码被改，App 仍显示已登录，所有 API 请求 401 但无降级处理。

**修复方向**：在 `AuthWrapper` 首次 build 时（或 app 启动时）发一个轻量 API 请求验证登录态，发现 401 后自动登出并提示。

---

### Bug #F008 — `dart:io` 未使用（P3）

**模块**：MineScreen

**问题**：`import 'dart:io';` 在文件顶部但未被使用，下个版本清理即可。

---

## 更新后缺陷追踪表

| 缺陷ID | 标题 | 严重程度 | 模块 | 发现日期 | 状态 | 修复版本 |
|--------|------|----------|------|----------|------|----------|
| #001 | CSV导出500崩溃 | P0 | 后端/导出 | 2026-07-31 | ✅ 已修复（v2） | |
| #002 | 后端地址与存储地址不一致 | P0 | 前端/架构 | 2026-07-31 | 待确认架构 | |
| #003 | 负数金额可保存 | P1 | 后端/账单 | 2026-07-31 | ✅ 已修复（v2） | |
| #004 | amount=null/"abc"保存成功 | P1 | 后端/账单 | 2026-07-31 | ✅ 已修复（v2） | |
| #005 | 分类查询中文参数返回空 | P1 | 后端/查询 | 2026-07-31 | 待修复 | |
| #006 | 组合日期筛选失效 | P1 | 后端/查询 | 2026-07-31 | ✅ 已修复（v2） | |
| #007 | 金额=0被错误拒绝 | P2 | 后端/账单 | 2026-07-31 | ✅ 已修复（v2） | |
| #008 | 月份参数无范围校验 | P2 | 后端/统计 | 2026-07-31 | ✅ 已修复（v2） | |
| #009 | CSV中文乱码 | P2 | 后端/导出 | 2026-07-31 | 随#001 | |
| #010 | 错误返回HTML而非JSON | P2 | 后端/认证 | 2026-07-31 | 待修复 | |
| #F001 | 导出CSV用户拿不到文件 | **P0** | 前端/MineScreen | 2026-07-31 | 待修复 | |
| #F002 | _readFile错误使用ref会崩溃 | **P0** | 前端/MineScreen | 2026-07-31 | 待修复 | |
| #F003 | 新增账单后首页列表不刷新 | P1 | 前端/HomeScreen | 2026-07-31 | 待修复 | |
| #F004 | 删除时id为空用name危险 | P1 | 前端/分类账户管理 | 2026-07-31 | 待修复 | |
| #F005 | 新增分类dialog的type拍定时机错误 | P2 | 前端/分类管理 | 2026-07-31 | 待修复 | |
| #F006 | 饼图0值数据可能导致异常 | P2 | 前端/BillScreen | 2026-07-31 | 待修复 | |
| #F007 | 登录态持久化无后端验证 | P2 | 前端/AuthProvider | 2026-07-31 | 待修复 | |
| #F008 | dart:io无用导入 | P3 | 前端/代码整洁 | 2026-07-31 | 待修复 | |

---

## v2.0.0 更新（2026-07-31）

### 新功能上线记录

#### 短信验证码登录/注册（v2.0.0）

| 变更文件 | 变更内容 |
|----------|----------|
| `backend/server.js` | 全新认证模块：send_code、verify_code、me、logout、account接口；token会话管理；旧PIN接口标记废弃但兼容 |
| `flutter_app/lib/api/api_service.dart` | 新增 sendCode、verifyCode、me、logout 方法；`_headers` 支持 x-token |
| `flutter_app/lib/providers/auth_provider.dart` | AuthState 增加 token 字段；SharedPreferences 存储 auth_phone + auth_token；verifyCode 替代 login/register |
| `flutter_app/lib/screens/login_screen.dart` | 全新UI：手机号+验证码+60秒倒计时按钮；支持老用户PIN兼容登录 |

#### 后端新增接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `/api/auth/send_code` | POST | 发送验证码，60秒防刷，返回expireSeconds |
| `/api/auth/verify_code` | POST | 验证注册/登录，返回token；自动注册新用户 |
| `/api/auth/me` | GET | Token有效性校验 |
| `/api/auth/logout` | DELETE | 退出登录 |
| `/api/auth/account` | DELETE | 删除账号（危险操作） |

#### 安全特性

- 验证码60秒有效期
- 同一手机号60秒防刷
- 验证码3次错误本地作废
- Token 30天有效期，自动续期
- 所有业务API支持 x-token 认证
- 旧版PIN登录兼容（自动迁移到token）

#### 待接入

⚠️ 短信服务商未接入：当前 `sendSms()` 只是 console.log 输出验证码，生产环境需接入阿里云/腾讯云 SMS SDK
