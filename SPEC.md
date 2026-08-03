# 木木记账 产品规格说明书

## 1. 产品概述

- **产品名称**：木木记账
- **产品定位**：简洁、注重隐私的个人记账工具
- **slogan**：你的数据，存在你自己的硬盘里
- **目标用户**：个人用户，需要多端同步（iOS/Android）
- **核心价值**：简单记账，数据自持，无需订阅
- **架构确认**：走ECS方案（`http://116.62.117.199:3848`）

---

## 2. 技术架构

### 前端
- **框架**：Flutter（iOS + Android + Windows）
- **状态管理**：Riverpod
- **本地存储**：HTTP API 调用

### 后端
- **框架**：Node.js + Express
- **数据库**：SQLite（每个用户独立数据库文件）
- **存储路径**：`/vol1/@apphome/trim.openclaw/data/workspace/accounting-app/backend/data/<phone>.db`

### 认证
- 手机号 + 短信验证码
- 用户首次注册时获取验证码完成注册
- 登录时输入手机号+验证码
- Token 会话管理（JWT/UUID），有效期30天
- 支持自动登录（Token有效期内）

---

## 3. 数据模型

### 用户表 (users)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键 |
| phone | TEXT | 手机号（唯一）|
| pin | TEXT | PIN码（6位）|
| created_at | TEXT | 创建时间 |

### 账单表 (records)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | TEXT | 主键（UUID）|
| type | TEXT | expense/income/transfer |
| amount | REAL | 金额 |
| category | TEXT | 分类 |
| sub_category | TEXT | 二级分类 |
| account | TEXT | 账户 |
| to_account | TEXT | 对方账户（转账用）|
| remark | TEXT | 备注 |
| tag | TEXT | 标签 |
| date | TEXT | 日期时间 |
| created_at | TEXT | 创建时间 |

### 分类表 (categories)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键 |
| name | TEXT | 分类名 |
| icon | TEXT | Emoji图标 |
| type | TEXT | expense/income |
| user_id | TEXT | 用户ID |

### 账户表 (accounts)
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键 |
| name | TEXT | 账户名 |
| user_id | TEXT | 用户ID |

---

## 4. 功能清单

### P0（核心）
- [x] 手机号+PIN登录/注册
- [x] 记一笔（金额、分类、日期、备注）
- [x] 首页展示（本月结余、收入、支出）
- [x] 账单列表（最近记录）
- [x] 月账单（收支汇总）
- [x] 分类统计（饼图/柱状图）

### P1（重要）
- [x] 分类管理（增删分类）
- [x] 账户管理（增删账户）
- [x] 多设备同步（共用一个NAS数据库）
- [x] 导出CSV

### P2（可选）
- [ ] 标签管理
- [ ] 转账功能
- [ ] 债务记录
- [ ] 月度预算

---

## 5. 默认分类

### 支出分类
| 分类 | 图标 |
|------|------|
| 三餐 | 🍜 |
| 饮料 | ☕ |
| 零食 | 🍪 |
| 水果 | 🍎 |
| 买菜 | 🥬 |
| 交通 | 🚇 |
| 购物 | 🛒 |
| 娱乐 | 🎮 |
| 游戏 | 🎯 |
| 学习 | 📚 |
| 烟酒 | 🚬 |
| 医疗 | 💊 |
| 服饰 | 👔 |
| 住房 | 🏠 |
| 日用品 | 🧴 |
| 理发 | ✂️ |
| 通讯 | 📱 |
| 旅行 | ✈️ |
| 请客 | 🎁 |
| 会员 | ⭐ |
| 其他 | 📦 |

### 收入分类
| 分类 | 图标 |
|------|------|
| 工资 | 💰 |
| 奖金 | 🎉 |
| 收款 | 💵 |
| 红包 | 🧧 |
| 投资 | 📈 |
| 其他 | 📦 |

### 默认账户
- 现金
- 中国邮政储蓄银行
- 微信
- 支付宝
- 京东白条
- 招商银行
- 建设银行

---

## 6. API 接口

### 认证（v2.0.0 变更）
- `POST /api/auth/send_code` - 发送短信验证码（60秒有效）
- `POST /api/auth/verify_code` - 验证验证码（注册+登录共用）
- `GET /api/auth/me` - 验证Token有效性（自动登录校验）
- `DELETE /api/auth/logout` - 退出登录
- ~~`POST /api/auth/register`~~ - 废弃（v2.0.0）
- ~~`POST /api/auth/login`~~ - 废弃（v2.0.0）

### 账单
- `GET /api/records` - 获取账单列表（支持分页、日期筛选）
- `POST /api/records` - 新增账单
- `PUT /api/records/:id` - 修改账单
- `DELETE /api/records/:id` - 删除账单

### 统计
- `GET /api/stats/monthly` - 月度统计
- `GET /api/stats/category` - 分类统计

### 分类
- `GET /api/categories` - 获取分类列表
- `POST /api/categories` - 新增分类
- `DELETE /api/categories/:id` - 删除分类

### 账户
- `GET /api/accounts` - 获取账户列表
- `POST /api/accounts` - 新增账户
- `DELETE /api/accounts/:id` - 删除账户

### 导出
- `GET /api/export/csv` - 导出CSV

---

## 7. 里程碑

- **M1**：完成登录注册 + 记一笔 + 首页
- **M2**：月账单 + 分类统计图表
- **M3**：分类管理 + 账户管理 + 多设备同步
- **M4**：导出CSV
- **M5**：Flutter 打包 iOS/Android
