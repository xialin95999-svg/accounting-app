const express = require('express');
const { v4: uuidv4 } = require('uuid');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = 3848;
const DATA_DIR = path.join(__dirname, 'data');
const TOKENS_FILE = path.join(DATA_DIR, '.tokens.json');

// 确保数据目录存在
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

// ==================== Token 持久化 ====================
// Token 存储：Map<token, { phone, expireAt }>
const tokenStore = new Map();

// 启动时从文件加载 token
function loadTokens() {
  try {
    if (fs.existsSync(TOKENS_FILE)) {
      const data = JSON.parse(fs.readFileSync(TOKENS_FILE, 'utf8'));
      for (const [token, v] of Object.entries(data)) {
        if (v.expireAt > Date.now()) {
          tokenStore.set(token, v);
        }
      }
      console.log(`[TOKEN] 从文件加载了 ${tokenStore.size} 个有效token`);
    }
  } catch (e) {
    console.error('[TOKEN] 加载token文件失败:', e.message);
  }
}

// 保存 token 到文件
function saveTokens() {
  try {
    const data = Object.fromEntries(tokenStore);
    fs.writeFileSync(TOKENS_FILE, JSON.stringify(data, null, 2));
  } catch (e) {
    console.error('[TOKEN] 保存token文件失败:', e.message);
  }
}

loadTokens();

// 确保数据目录存在
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

app.use(cors());
app.use(express.json());

// 全局错误处理：根据Accept头决定返回HTML还是JSON
app.use((err, req, res, _next) => {
  console.error('[ERROR]', err.message);
  const accept = req.headers['accept'] || '';
  if (accept.includes('text/html')) {
    res.status(err.status || 500).type('text/html').send(
      `<html><body><h1>Error ${err.status || 500}</h1><p>${err.message || '服务器内部错误'}</p></body></html>`
    );
  } else {
    res.status(err.status || 500).json({ error: err.message || '服务器内部错误' });
  }
});

// Bug#010 fix: 未登录时根据Accept头返回HTML或JSON
app.use((req, res, next) => {
  // 仅在需要认证的路由上触发（已通过authMiddleware的请求会设置req.phone）
  // 这里检测：如果没有任何认证信息且是API请求，返回适当格式
  const accept = req.headers['accept'] || '';
  const isHtmlRequest = accept.includes('text/html');
  
  // 仅在真正没有认证时触发（authMiddleware会先运行）
  // 这个中间件作为fallback，确保所有错误响应格式一致
  // authMiddleware已经在需要认证的路由前运行，所以这里不需要重复检查
  next();
});

// 获取用户数据文件路径
function getUserFile(phone) {
  return path.join(DATA_DIR, `${phone}.json`);
}

// 读取用户数据
function readUserData(phone) {
  const file = getUserFile(phone);
  if (fs.existsSync(file)) {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  }
  return {
    user: null,
    categories: [],
    accounts: [],
    records: []
  };
}

// 保存用户数据
function saveUserData(phone, data) {
  const file = getUserFile(phone);
  fs.writeFileSync(file, JSON.stringify(data, null, 2), 'utf8');
}

// 默认支出分类
const DEFAULT_EXPENSE_CATEGORIES = [
  { name: '三餐', icon: '🍜' }, { name: '饮料', icon: '☕' }, { name: '零食', icon: '🍪' },
  { name: '水果', icon: '🍎' }, { name: '买菜', icon: '🥬' }, { name: '交通', icon: '🚇' },
  { name: '购物', icon: '🛒' }, { name: '娱乐', icon: '🎮' }, { name: '游戏', icon: '🎯' },
  { name: '学习', icon: '📚' }, { name: '烟酒', icon: '🚬' }, { name: '医疗', icon: '💊' },
  { name: '服饰', icon: '👔' }, { name: '住房', icon: '🏠' }, { name: '日用品', icon: '🧴' },
  { name: '理发', icon: '✂️' }, { name: '通讯', icon: '📱' }, { name: '旅行', icon: '✈️' },
  { name: '请客', icon: '🎁' }, { name: '会员', icon: '⭐' }, { name: '其他', icon: '📦' }
];

// 默认收入分类
const DEFAULT_INCOME_CATEGORIES = [
  { name: '工资', icon: '💰' }, { name: '奖金', icon: '🎉' }, { name: '收款', icon: '💵' },
  { name: '红包', icon: '🧧' }, { name: '投资', icon: '📈' }, { name: '其他', icon: '📦' }
];

// 默认账户
const DEFAULT_ACCOUNTS = ['现金', '中国邮政储蓄银行', '微信', '支付宝', '京东白条', '招商银行', '建设银行'];

// ==================== 验证码与会话存储（内存）====================
// 生产环境建议换 Redis，以下为本地开发演示
const CODE_EXPIRE_MS = 60 * 1000;          // 验证码有效期 60 秒
const TOKEN_EXPIRE_MS = 30 * 24 * 60 * 60 * 1000; // Token 有效期 30 天
const MAX_CODE_ATTEMPTS = 3;              // 验证码最多错 3 次
const SEND_COOLDOWN_MS = 60 * 1000;       // 同一手机号 60 秒内不能重复发

// 验证码存储：Map<phone, { code, expireAt, attempts }>
const codeStore = new Map();
// 注意：tokenStore 已在顶部声明（见第19行，支持持久化）

// 清理过期验证码和 token（启动时执行一次）
function cleanupExpired() {
  const now = Date.now();
  for (const [phone, v] of codeStore) {
    if (v.expireAt < now) codeStore.delete(phone);
  }
  let changed = false;
  for (const [token, v] of tokenStore) {
    if (v.expireAt < now) { tokenStore.delete(token); changed = true; }
  }
  if (changed) saveTokens();
}
cleanupExpired();

// 生成 6 位数字验证码
function generateCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// 生成 Token
function generateToken() {
  return uuidv4();
}

// ==================== 短信配置 ====================
// 阿里云 SMS 配置（生产环境）
const ALI_SMS = {
  accessKeyId:     process.env.ALIYUN_ACCESS_KEY_ID     || '',
  accessKeySecret: process.env.ALIYUN_ACCESS_KEY_SECRET || '',
  signName:       process.env.ALIYUN_SIGN_NAME         || '',
  templateCode:    process.env.ALIYUN_TEMPLATE_CODE     || '',
};

// 短信发送函数
// 优先级：1. 阿里云 SMS  2. 日志输出（开发/测试模式）
async function sendSms(phone, code) {
  const msg = `[SMS] → ${phone} 验证码: ${code} (${CODE_EXPIRE_MS/1000}秒有效)`;

  // 有阿里云配置 → 真实发短信
  if (ALI_SMS.accessKeyId && ALI_SMS.accessKeySecret) {
    try {
      const https = require('https');
      const querystring = require('querystring');

      const params = querystring.stringify({
        AccessKeyId:     ALI_SMS.accessKeyId,
        Action:          'SendSms',
        Format:          'JSON',
        Version:         '2017-05-25',
        SignatureMethod: 'HMAC-SHA1',
        Timestamp:       new Date().toISOString(),
        SignatureVersion: '1.0',
        SignatureNonce:   uuidv4(),
        PhoneNumbers:    phone,
        SignName:        ALI_SMS.signName,
        TemplateCode:    ALI_SMS.templateCode,
        TemplateParam:   JSON.stringify({ code }),
      });

      const body = `POST&${encodeURIComponent('/')}&${encodeURIComponent(params)}`;
      const signature = require('crypto')
        .createHmac('sha1', ALI_SMS.accessKeySecret + '&')
        .update(body).digest('base64');

      const fullParams = params + '&Signature=' + encodeURIComponent(signature);

      const options = {
        hostname: 'dysmsapi.aliyuncs.com',
        port: 443,
        path: '/?SignatureVersion=1.0&SignatureMethod=HMAC-SHA1&Format=JSON&SignatureNonce=' + uuidv4(),
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      };

      const result = await new Promise((resolve, reject) => {
        const req = https.request(options, res => {
          let data = '';
          res.on('data', chunk => data += chunk);
          res.on('end', () => resolve(JSON.parse(data)));
        });
        req.on('error', reject);
        req.write(fullParams);
        req.end();
      });

      if (result.Code === 'OK') {
        console.log(`✅ 短信发送成功: ${msg}`);
        return true;
      } else {
        console.error(`❌ 阿里云 SMS 失败: ${result.Code} - ${result.Message}`);
        return false;
      }
    } catch (e) {
      console.error(`❌ 短信发送异常: ${e.message}`);
      return false;
    }
  }

  // 无配置 → 开发模式：输出到日志
  console.log(`\n[SMS DEV] ${msg}\n`);
  console.log('  ⚠️ 生产部署请设置环境变量:');
  console.log('     ALIYUN_ACCESS_KEY_ID=xxx');
  console.log('     ALIYUN_ACCESS_KEY_SECRET=xxx');
  console.log('     ALIYUN_SIGN_NAME=小牛记账');
  console.log('     ALIYUN_TEMPLATE_CODE=SMS_xxx');
  return true;
}

// 统一认证中间件（支持 x-token 和 x-phone 两种方式）
function authMiddleware(req, res, next) {
  const token = req.headers['x-token'];
  // Bug#SEC01 fix: 必须有有效token，不允许仅靠x-phone绕过认证
  if (!token) {
    // Bug#010 fix: 始终返回JSON，不返回HTML
    return res.status(401).json({ error: '未登录，请重新登录' });
  }
  const info = tokenStore.get(token);
  if (!info || info.expireAt < Date.now()) {
    tokenStore.delete(token);
    // Bug#010 fix: 始终返回JSON，不返回HTML
    return res.status(401).json({ error: '登录已过期，请重新登录' });
  }
  req.phone = info.phone;
  next();
}

// ==================== 认证（v2.0.0 短信验证码）====================

// 发送验证码
app.post('/api/auth/send_code', async (req, res) => {
  const { phone } = req.body;
  if (!phone || !/^1\d{10}$/.test(phone))
    return res.status(400).json({ error: '请输入正确的11位手机号' });

  const now = Date.now();
  const existing = codeStore.get(phone);

  // 防刷：60秒内不能重复发
  if (existing && existing.expireAt > now && existing.code) {
    const left = Math.ceil((existing.expireAt - now) / 1000);
    return res.status(429).json({ error: `请${left}秒后再试` });
  }

  const code = generateCode();
  await sendSms(phone, code);

  codeStore.set(phone, {
    code,                       // 生产环境建议存 hash
    expireAt: now + CODE_EXPIRE_MS,
    attempts: 0
  });

  res.json({ success: true, message: '验证码已发送', expireSeconds: CODE_EXPIRE_MS / 1000 });
});

// 验证验证码（注册 + 登录合一）
app.post('/api/auth/verify_code', (req, res) => {
  const { phone, code } = req.body;
  if (!phone || !code) return res.status(400).json({ error: '手机号和验证码不能为空' });

  const now = Date.now();
  const stored = codeStore.get(phone);

  // 无验证码记录或已过期
  if (!stored || stored.expireAt < now) {
    return res.status(400).json({ error: '验证码已过期，请重新获取' });
  }

  // 验证码错误
  if (stored.code !== code) {
    stored.attempts += 1;
    const left = MAX_CODE_ATTEMPTS - stored.attempts;
    if (left <= 0) {
      codeStore.delete(phone); // 3次错，本地作废
      return res.status(400).json({ error: '验证码错误次数过多，请重新获取' });
    }
    return res.status(400).json({ error: `验证码错误，剩余${left}次尝试机会` });
  }

  // 验证通过，清除验证码
  codeStore.delete(phone);

  const data = readUserData(phone);
  const isNewUser = !data.user;

  // 新用户 → 创建账号
  if (isNewUser) {
    data.user = { phone, created_at: new Date().toISOString() };
    data.categories = [
      ...DEFAULT_EXPENSE_CATEGORIES.map(c => ({ ...c, type: 'expense' })),
      ...DEFAULT_INCOME_CATEGORIES.map(c => ({ ...c, type: 'income' }))
    ];
    data.accounts = DEFAULT_ACCOUNTS.map(name => ({ name }));
    saveUserData(phone, data);
  }

  // 生成 Token
  const token = generateToken();
  tokenStore.set(token, {
    phone,
    expireAt: now + TOKEN_EXPIRE_MS
  });
  saveTokens();

  res.json({
    success: true,
    token,
    phone,
    isNewUser,
    message: isNewUser ? '注册成功' : '登录成功'
  });
});

// 验证 Token 有效性（自动登录校验）
app.get('/api/auth/me', (req, res) => {
  const token = req.headers['x-token'];
  if (!token) return res.status(401).json({ error: '缺少 Token' });

  const info = tokenStore.get(token);
  if (!info || info.expireAt < Date.now()) {
    tokenStore.delete(token);
    return res.status(401).json({ error: '登录已过期' });
  }
  const data = readUserData(info.phone);
  res.json({ success: true, phone: info.phone, created_at: data.user?.created_at });
});

// 退出登录
app.delete('/api/auth/logout', (req, res) => {
  const token = req.headers['x-token'];
  if (token) { tokenStore.delete(token); saveTokens(); }
  res.json({ success: true });
});

// 删除账号（危险操作，需要 Token）
app.delete('/api/auth/account', (req, res) => {
  const token = req.headers['x-token'];
  if (!token) return res.status(401).json({ error: '缺少 Token' });
  const info = tokenStore.get(token);
  if (!info || info.expireAt < Date.now()) return res.status(401).json({ error: '登录已过期' });

  const phone = info.phone;
  const userFile = getUserFile(phone);
  if (fs.existsSync(userFile)) fs.unlinkSync(userFile);
  tokenStore.delete(token);
  res.json({ success: true, message: '账号已删除' });
});

// ==================== 旧版认证（兼容 v1.x PIN 登录，v2.1 废弃）====================

// 旧版注册（废弃警告）
app.post('/api/auth/register', (req, res) => {
  console.warn('[废弃] /api/auth/register 被调用，请升级到 /api/auth/verify_code');
  return res.status(410).json({ error: '此接口已废弃，请使用短信验证码登录' });
});

// 旧版登录（兼容老用户 PIN，标记废弃）
app.post('/api/auth/login', (req, res) => {
  const { phone, pin } = req.body;
  if (!phone || !pin) return res.status(400).json({ error: '手机号和PIN不能为空' });
  console.warn(`[废弃] PIN登录被调用 phone=${phone}，请引导用户升级到验证码登录`);
  const data = readUserData(phone);
  if (!data.user || data.user.pin !== pin) {
    return res.status(401).json({ error: '手机号或PIN错误' });
  }
  // 签发 Token（兼容老用户，自动迁移）
  const token = generateToken();
  tokenStore.set(token, { phone, expireAt: Date.now() + TOKEN_EXPIRE_MS });
  saveTokens();
  res.json({ success: true, token, phone: data.user.phone, migrated: true, message: '登录成功（请尽快升级到验证码登录）' });
});

// ==================== 账单 ====================

// 获取账单列表
app.get('/api/records', authMiddleware, (req, res) => {
  const phone = req.phone;

  const { page = 1, limit = 50, startDate, endDate, type, category } = req.query;
  const data = readUserData(phone);
  let records = [...data.records];

  if (startDate) {
    const sd = startDate.includes('T') ? startDate : startDate + 'T00:00:00';
    records = records.filter(r => r.date >= sd);
  }
  if (endDate) {
    const ed = endDate.includes('T') ? endDate : endDate + 'T23:59:59';
    records = records.filter(r => r.date <= ed);
  }
  if (type) records = records.filter(r => r.type === type);
  // Bug#005 fix: 统一解码策略，一次decodeURIComponent即可
  // - 如果category是URL编码的(如 %E5%85%89%E9%A4%90)，decode后变成 "三餐"
  // - 如果已经是原始中文 "三餐"，decode后保持不变
  // - 存储端只存原始中文，前端查询时统一编码后传递
  if (category) {
    // Bug#005 fix: 双重解码，防止前端/中间件已解码一次的情况
    const decoded = decodeURIComponent(category);
    const normalizedCategory = decodeURIComponent(decoded);
    records = records.filter(r => (r.category || '') === normalizedCategory);
  }

  records.sort((a, b) => new Date(b.date) - new Date(a.date));
  const total = records.length;
  const offset = (Number(page) - 1) * Number(limit);
  records = records.slice(offset, offset + Number(limit));

  res.json({ records, total, page: Number(page), limit: Number(limit) });
});

// 新增账单
app.post('/api/records', authMiddleware, (req, res) => {
  const phone = req.phone;

  const { type, amount, category, sub_category, account, to_account, remark, tag, date } = req.body;
  const numAmount = Number(amount);
  if (!type || isNaN(numAmount) || numAmount <= 0 || !date)
    return res.status(400).json({ error: '金额必须大于0，请输入正确金额' });

  const data = readUserData(phone);
  const record = {
    id: uuidv4(), type, amount: Number(amount), category: category || '',
    sub_category: sub_category || '', account: account || '', to_account: to_account || '',
    remark: remark || '', tag: tag || '', date,
    created_at: new Date().toISOString()
  };
  data.records.push(record);
  saveUserData(phone, data);

  res.json({ success: true, id: record.id, record });
});

// 修改账单
app.put('/api/records/:id', authMiddleware, (req, res) => {
  const phone = req.phone;

  const data = readUserData(phone);
  const idx = data.records.findIndex(r => r.id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: '账单不存在' });

  const { type, amount, category, sub_category, account, to_account, remark, tag, date } = req.body;

  // Bug#012 fix: PUT也要校验负数金额
  const numAmount = Number(amount);
  if (isNaN(numAmount) || numAmount <= 0) {
    return res.status(400).json({ error: '金额必须大于0' });
  }

  data.records[idx] = {
    ...data.records[idx],
    type: type || data.records[idx].type,
    amount: numAmount,
    category: category || data.records[idx].category,
    sub_category: sub_category || data.records[idx].sub_category,
    account: account || data.records[idx].account,
    to_account: to_account || data.records[idx].to_account,
    remark: remark !== undefined ? remark : data.records[idx].remark,
    tag: tag !== undefined ? tag : data.records[idx].tag,
    // Bug#014 fix: date只更新有传的情况，不传则保留原值
    date: date !== undefined ? date : data.records[idx].date,
  };
  saveUserData(phone, data);
  res.json({ success: true });
});

// 删除账单
app.delete('/api/records/:id', authMiddleware, (req, res) => {
  const phone = req.phone;

  const data = readUserData(phone);
  const idx = data.records.findIndex(r => r.id === req.params.id);
  if (idx !== -1) {
    data.records.splice(idx, 1);
    saveUserData(phone, data);
  }
  res.json({ success: true });
});

// ==================== 统计 ====================

// 月度统计
app.get('/api/stats/monthly', authMiddleware, (req, res) => {
  const phone = req.phone;

  const { year, month } = req.query;
  const y = Number(year) || new Date().getFullYear();
  let m = Number(month) || (new Date().getMonth() + 1);
  if (m < 1 || m > 12) m = new Date().getMonth() + 1;
  const mStr = String(m).padStart(2, '0');
  const prefix = `${y}-${mStr}`;
  const data = readUserData(phone);

  // Bug#014 fix: 防御性过滤，防止date为空的脏数据崩溃
  const monthRecords = data.records.filter(r => r && r.date && r.date.startsWith(prefix));
  const income = monthRecords.filter(r => r.type === 'income').reduce((s, r) => s + r.amount, 0);
  const expense = monthRecords.filter(r => r.type === 'expense').reduce((s, r) => s + r.amount, 0);

  // 每日支出
  const dailyMap = {};
  monthRecords.filter(r => r.type === 'expense').forEach(r => {
    const day = r.date.slice(0, 10);
    dailyMap[day] = (dailyMap[day] || 0) + r.amount;
  });
  const daily = Object.entries(dailyMap).sort().map(([day, total]) => ({ day, total }));

  res.json({ year: y, month: Number(m), income, expense, balance: income - expense, daily });
});

// 分类统计
app.get('/api/stats/category', authMiddleware, (req, res) => {
  const phone = req.phone;

  const { year, month, type = 'expense' } = req.query;
  const y = Number(year) || new Date().getFullYear();
  let m = Number(month) || (new Date().getMonth() + 1);
  if (m < 1 || m > 12) m = new Date().getMonth() + 1;
  const mStr = String(m).padStart(2, '0');
  const prefix = `${y}-${mStr}`;
  const data = readUserData(phone);

  const filtered = data.records.filter(r =>
    r.type === type && r.date.startsWith(prefix)
  );

  const map = {};
  filtered.forEach(r => {
    const cat = r.category || '其他';
    map[cat] = (map[cat] || 0) + r.amount;
  });

  const total = Object.values(map).reduce((s, v) => s + v, 0);
  const categories = Object.entries(map)
    .map(([category, total_amount]) => ({ category, total: total_amount, percent: total > 0 ? Math.round(total_amount / total * 100) : 0 }))
    .sort((a, b) => b.total - a.total);

  res.json({ categories, total });
});

// ==================== 分类管理 ====================

app.get('/api/categories', authMiddleware, (req, res) => {
  const phone = req.phone;

  const { type } = req.query;
  const data = readUserData(phone);
  let cats = data.categories;
  if (type) cats = cats.filter(c => c.type === type);
  res.json({ categories: cats });
});

app.post('/api/categories', authMiddleware, (req, res) => {
  const phone = req.phone;

  const { name, icon, type } = req.body;
  if (!name || !type) return res.status(400).json({ error: '名称和类型不能为空' });

  const data = readUserData(phone);
  const cat = { id: uuidv4(), name, icon: icon || '📦', type };
  data.categories.push(cat);
  saveUserData(phone, data);
  res.json({ success: true, id: cat.id, category: cat });
});

app.delete('/api/categories/:id', authMiddleware, (req, res) => {
  const phone = req.phone;

  const data = readUserData(phone);
  const idx = data.categories.findIndex(c => c.id === req.params.id);
  if (idx !== -1) {
    data.categories.splice(idx, 1);
    saveUserData(phone, data);
  }
  res.json({ success: true });
});

// ==================== 账户管理 ====================

app.get('/api/accounts', authMiddleware, (req, res) => {
  const phone = req.phone;

  const data = readUserData(phone);
  res.json({ accounts: data.accounts });
});

app.post('/api/accounts', authMiddleware, (req, res) => {
  const phone = req.phone;

  const { name } = req.body;
  if (!name) return res.status(400).json({ error: '账户名不能为空' });

  const data = readUserData(phone);
  const acc = { id: uuidv4(), name };
  data.accounts.push(acc);
  saveUserData(phone, data);
  res.json({ success: true, id: acc.id, account: acc });
});

app.delete('/api/accounts/:id', authMiddleware, (req, res) => {
  const phone = req.phone;

  const data = readUserData(phone);
  const idx = data.accounts.findIndex(a => a.id === req.params.id);
  if (idx !== -1) {
    data.accounts.splice(idx, 1);
    saveUserData(phone, data);
  }
  res.json({ success: true });
});

// ==================== 导出 ====================

app.get('/api/export/csv', authMiddleware, (req, res) => {
  const phone = req.phone;

  const { startDate, endDate } = req.query;
  const data = readUserData(phone);
  let records = [...data.records];

  if (startDate) {
    const sd = startDate.includes('T') ? startDate : startDate + 'T00:00:00';
    records = records.filter(r => r.date >= sd);
  }
  if (endDate) {
    const ed = endDate.includes('T') ? endDate : endDate + 'T23:59:59';
    records = records.filter(r => r.date <= ed);
  }
  records.sort((a, b) => new Date(b.date) - new Date(a.date));

  const header = 'ID,时间,分类,二级分类,类型,金额,币种,账户1,账户2,备注,标签\n';
  const rows = records.map(r =>
    `${r.id},${r.date},${r.category},${r.sub_category || ''},${r.type},${r.amount},CNY,${r.account},${r.to_account || ''},${(r.remark || '').replace(/,/g, '，')},${r.tag || ''}`
  ).join('\n');

  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  const dateStr = new Date().toISOString().slice(0, 10);
  const filename = `accounting_${dateStr}.csv`;
  res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
  res.send('\ufeff' + header + rows);
});

// ==================== 导入 ====================

// 钱迹CSV格式导入
app.post('/api/import/qianji', authMiddleware, (req, res) => {
  const phone = req.phone;

  // Bug#016 fix: 同时支持旧CSV格式和新版JSON格式
  const { csv, version, records } = req.body;
  const data = readUserData(phone);

  // 新版钱迹JSON格式（{"version":"1.0","records":[...]}）
  if (version && records && Array.isArray(records)) {
    let imported = 0, skipped = 0;
    for (const r of records) {
      try {
        const amount = parseFloat(r.amount);
        if (!r.date || isNaN(amount)) { skipped++; continue; }

        let type = 'expense';
        if (r.type === 'income' || (r.typeName && r.typeName.includes('收入'))) type = 'income';
        else if (r.type === 'transfer') type = 'transfer';

        // 格式化日期
        let formattedDate = r.date;
        if (formattedDate.includes('/')) {
          formattedDate = formattedDate.replace(/^(\d{2})\/(\d{2})\/(\d{4})/, '$3-$1-$2');
        }
        formattedDate = formattedDate.slice(0, 10);

        data.records.push({
          id: uuidv4(),
          type,
          amount,
          category: r.category || '',
          sub_category: r.subCategory || '',
          account: r.account || '',
          to_account: r.toAccount || '',
          remark: r.remark || '',
          tag: Array.isArray(r.tag) ? r.tag.join(',') : (r.tag || ''),
          date: formattedDate,
          created_at: new Date().toISOString()
        });
        imported++;
      } catch (_) { skipped++; }
    }
    saveUserData(phone, data);
    return res.json({ success: true, imported, skipped, total: records.length });
  }

  // 旧版CSV格式（{"csv":"时间,分类,...\n..."}）
  if (!csv) return res.status(400).json({ error: '缺少csv数据' });
  const lines = csv.trim().split('\n');
  if (lines.length < 2) return res.status(400).json({ error: 'CSV数据为空' });

  // 跳过表头
  const header = lines[0].toLowerCase();
  const hasBom = header.charCodeAt(0) === 0xfeff;

  // 找到列索引
  const getIdx = (h, cols) => {
    const normalized = hasBom ? h.slice(1) : h;
    const parts = normalized.split(',');
    for (const col of cols) {
      const idx = parts.findIndex(p => p.trim().includes(col));
      if (idx !== -1) return idx;
    }
    return -1;
  };

  const firstLine = hasBom ? lines[0].slice(1) : lines[0];
  const headers = firstLine.split(',').map(h => h.trim().replace(/^\ufeff/, ''));

  const idxTime = headers.findIndex(h => h.includes('时间'));
  const idxCat = headers.findIndex(h => h.includes('分类'));
  const idxSubCat = headers.findIndex(h => h.includes('二级'));
  const idxType = headers.findIndex(h => h.includes('类型'));
  const idxAmount = headers.findIndex(h => h.includes('金额'));
  const idxAccount = headers.findIndex(h => h.includes('账户1'));
  const idxToAccount = headers.findIndex(h => h.includes('账户2'));
  const idxRemark = headers.findIndex(h => h.includes('备注'));
  const idxTag = headers.findIndex(h => h.includes('标签'));

  let imported = 0;
  let skipped = 0;

  for (let i = 1; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line) continue;

    // 简单CSV解析（处理可能有引号包裹的字段）
    const parseRow = (row) => {
      const result = [];
      let current = '';
      let inQuotes = false;
      for (let j = 0; j < row.length; j++) {
        const ch = row[j];
        if (ch === '"') {
          inQuotes = !inQuotes;
        } else if (ch === ',' && !inQuotes) {
          result.push(current.trim());
          current = '';
        } else {
          current += ch;
        }
      }
      result.push(current.trim());
      return result;
    };

    const cols = parseRow(line);

    const getVal = (idx) => idx >= 0 && idx < cols.length ? cols[idx].trim() : '';

    const time = getVal(idxTime);
    const category = getVal(idxCat);
    const subCategory = getVal(idxSubCat);
    const typeRaw = getVal(idxType);
    const amount = parseFloat(getVal(idxAmount));
    const account = getVal(idxAccount);
    const toAccount = getVal(idxToAccount);
    const remark = getVal(idxRemark);
    const tag = getVal(idxTag);

    if (!time || isNaN(amount)) { skipped++; continue; }

    // 转换类型
    let type = 'expense';
    if (typeRaw.includes('收入') || typeRaw.includes('收红包') || typeRaw.includes('奖金')) {
      type = 'income';
    } else if (typeRaw.includes('转账')) {
      type = 'transfer';
    }

    // 格式化时间：钱迹格式是 yyyy-MM-dd HH:mm:ss
    const formattedDate = time.includes('/')
      ? time.replace(/^(\d{2})\/(\d{2})\/(\d{4})/, '$3-$1-$2')
      : time;

    const record = {
      id: uuidv4(),
      type,
      amount,
      category,
      sub_category: subCategory,
      account,
      to_account: toAccount,
      remark,
      tag,
      date: formattedDate,
      created_at: new Date().toISOString()
    };

    data.records.push(record);
    imported++;
  }

  saveUserData(phone, data);
  res.json({ success: true, imported, skipped, total: data.records.length });
});

// 健康检查
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

// 读取文件（用于导入）
app.get('/api/file/read', authMiddleware, (req, res) => {
  const phone = req.phone;

  const { path: filePath } = req.query;
  if (!filePath) return res.status(400).json({ error: '缺少文件路径' });

  try {
    // 安全检查：规范化路径，防止 ../ 穿越
    const normalizedPath = path.normalize(filePath);
    const allowedDirs = ['/vol1', '/mnt', '/home'];
    const isAllowed = allowedDirs.some(d => normalizedPath.startsWith(d)) && !normalizedPath.includes('..');
    if (!isAllowed) return res.status(403).json({ error: '路径不允许访问' });

    if (!fs.existsSync(normalizedPath)) {
      return res.status(404).json({ error: '文件不存在' });
    }

    const content = fs.readFileSync(normalizedPath, 'utf8');
    res.json({ content });
  } catch (err) {
    res.status(500).json({ error: '读取失败: ' + err.message });
  }
});

// 404 catch-all：所有未匹配路由返回JSON错误
app.use((req, res) => {
  res.status(404).json({ error: '接口不存在' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`小牛记账后端已启动: http://0.0.0.0:${PORT}`);
  console.log(`数据存储目录: ${DATA_DIR}`);
});
