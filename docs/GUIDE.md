# 🚀 GameDevMap 完整部署流程

## 目录
1. 环境准备
2. MongoDB 配置
3. 项目配置
4. 初始化数据
5. Nginx 配置
6. 启动服务
7. 验证测试
8. 故障排查

---

## 1. 环境准备

### 1.1 系统要求
```bash
# 确认 Node.js 版本 (推荐 16.x 或更高)
node -v  # 应输出 v16.x.x 或更高

# 确认 npm 版本
npm -v

# 确认 MongoDB 安装（宝塔面板已安装）
mongod --version

# 确认 PM2 安装
pm2 -v
# 如果未安装: npm install -g pm2

# 确认 Nginx 安装（宝塔已安装）
nginx -v
```

### 1.2 项目克隆与依赖安装
```bash
# 切换到项目目录
cd /home/www/GameDevMap

# 拉取最新代码（包含 trust proxy 修复）
git pull origin main

# 安装依赖
npm install

# 验证依赖安装
npm list --depth=0
```

---

## 2. MongoDB 配置

### 2.1 启动 MongoDB (宝塔面板)
```bash
# 方式1: 通过宝塔面板
# 软件商店 → MongoDB → 启动

# 方式2: 命令行（如果宝塔未启动）
systemctl start mongodb
systemctl enable mongodb  # 设置开机自启

# 验证 MongoDB 运行
systemctl status mongodb

# 或者
ps aux | grep mongod
```

### 2.2 创建数据库和用户（可选，开发环境可跳过）
```bash
# 连接 MongoDB
mongosh

# 创建数据库和用户
use gamedevmap

db.createUser({
  user: "gamedevmap_user",
  pwd: "your_secure_password",
  roles: [
    { role: "readWrite", db: "gamedevmap" }
  ]
})

# 退出
exit
```

### 2.3 测试连接
```bash
# 使用项目脚本测试连接
node -e "
  require('dotenv').config();
  const mongoose = require('mongoose');
  mongoose.connect(process.env.MONGODB_URI)
    .then(() => console.log('✅ MongoDB 连接成功'))
    .catch(err => console.error('❌ 连接失败:', err));
"
```

---

## 3. 项目配置

### 3.1 创建 .env 文件
```bash
cd /home/www/GameDevMap

# 创建环境变量文件
nano .env
```

**内容示例**:
```env
# 服务器配置
PORT=3001
NODE_ENV=production

# MongoDB 配置（本地安装，无需密码）
MONGODB_URI=mongodb://localhost:27017/gamedevmap

# 如果设置了用户名密码（推荐生产环境）
# MONGODB_URI=mongodb://gamedevmap_user:your_secure_password@localhost:27017/gamedevmap
****
# JWT 配置
JWT_SECRET=your_super_secret_jwt_key_change_in_production_must_be_long
JWT_EXPIRES_IN=24h

# 可选: Sentry 错误追踪
# SENTRY_DSN=https://your-sentry-dsn
```

**保存并设置权限**:
```bash
chmod 600 .env  # 仅所有者可读写
chown www:www .env  # 确保 www 用户可访问
```

### 3.2 创建必要目录
```bash
# 创建数据目录
mkdir -p /home/www/GameDevMap/data/submissions
mkdir -p /home/www/GameDevMap/data/pending_submissions

# 创建日志目录
mkdir -p /home/www/GameDevMap/logs

# 设置权限
chown -R www:www /home/www/GameDevMap/data
chown -R www:www /home/www/GameDevMap/logs
chmod -R 755 /home/www/GameDevMap/data
chmod -R 755 /home/www/GameDevMap/logs
```

### 3.3 迁移现有上传文件（如果有）
```bash
# 从旧位置迁移到新位置
if [ -d "/home/www/GameDevMap/public/assets/submissions" ]; then
  cp -r /home/www/GameDevMap/public/assets/submissions/* /home/www/GameDevMap/data/submissions/
  echo "✅ 文件迁移完成"
fi
```

### 3.4 可用的 npm 脚本命令

项目提供了丰富的 npm 脚本命令来简化各种操作：

#### 基础运行命令
```bash
npm start          # 生产环境启动
npm run dev        # 开发环境启动（带热重载）
```

#### 数据管理命令
```bash
npm run seed:admin         # 创建管理员账户
npm run migrate:clubs      # 从 clubs.json 导入数据到 MongoDB
npm run migrate:logos      # 迁移社团logo文件
```

#### 数据同步命令（新增）
```bash
npm run sync:json          # 完全替换模式：用数据库覆盖 JSON（默认）
npm run sync:merge         # 智能合并模式：保留手动修改，更新数据库数据
npm run sync:update        # 仅更新模式：只更新现有记录
npm run sync:addOnly       # 仅添加模式：只添加新记录
```

#### 工具命令
```bash
npm run generate:jwt       # 生成 JWT 密钥
npm run compress:images    # 压缩图片文件（需要 Python Pillow）
```

**数据同步模式说明**:
- `sync:json`: 生产环境标准同步，完全覆盖 JSON
- `sync:merge`: 开发环境使用，保留手动修改
- `sync:update`: 数据刷新，只更新现有记录
- `sync:addOnly`: 增量添加，只添加新社团

---

## 4. 初始化数据

### 4.1 创建管理员账户
```bash
cd /home/www/GameDevMap

# 运行管理员创建脚本
node server/scripts/seedAdmin.js

# 根据提示输入：
# Username: admin
# Password: your_admin_password (至少8位)
# Role: admin
```

**输出示例**:
```
✅ Connected to MongoDB
✅ Admin user created successfully
Username: admin
Role: admin
✅ Seed complete
```

### 4.2 导入现有社团数据（如果有 clubs.json）
```bash
# 确保 public/data/clubs.json 存在
ls -la public/data/clubs.json

# 导入到 MongoDB
node server/scripts/migrateClubs.js
```

**输出示例**:
```
✅ Connected to MongoDB
📄 Found 45 clubs in clubs.json
  ✓ Imported: 游戏开发社 (清华大学)
  ✓ Imported: 电竞社 (北京大学)
  ...
📊 Migration Summary:
  ✓ Imported: 45
  ↻ Updated: 0
  ✗ Skipped: 0
  Total: 45
✅ Migration complete
```

### 4.3 验证数据
```bash
# 方式1: 使用 mongosh
mongosh gamedevmap

# 查询社团数量
db.clubs.countDocuments()

# 查询管理员
db.adminusers.find()

# 退出
exit

# 方式2: 使用 Node 脚本
node -e "
  require('dotenv').config();
  const mongoose = require('mongoose');
  const Club = require('./server/models/Club');
  const AdminUser = require('./server/models/AdminUser');
  
  mongoose.connect(process.env.MONGODB_URI).then(async () => {
    const clubCount = await Club.countDocuments();
    const adminCount = await AdminUser.countDocuments();
    console.log('📊 社团数量:', clubCount);
    console.log('👤 管理员数量:', adminCount);
    process.exit(0);
  });
"
```

---

## 5. Nginx 配置

### 5.1 创建 Nginx 配置文件
```bash
# 宝塔面板方式（推荐）
# 网站 → 添加站点 → 输入域名 → 创建

# 或手动创建
nano /www/server/panel/vhost/nginx/gamedevmap.conf
```

**配置内容**:
```nginx
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    
    # 日志
    access_log /home/www/GameDevMap/logs/nginx_access.log;
    error_log /home/www/GameDevMap/logs/nginx_error.log;
    
    # 根目录（静态文件）
    root /home/www/GameDevMap/public;
    index index.html;
    
    # 静态文件直接服务
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # 上传文件（新位置）
    location /assets/submissions/ {
        alias /home/www/GameDevMap/data/submissions/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    # API 代理到 Node.js
    location /api/ {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        
        # 关键：设置代理头（trust proxy 需要）
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # 管理面板
    location /admin {
        try_files $uri $uri/ /admin/index.html;
    }
    
    # 禁止访问敏感文件
    location ~ /\. {
        deny all;
    }
    
    location ~ \.(env|git)$ {
        deny all;
    }
}
```

### 5.2 测试 Nginx 配置
```bash
# 测试配置语法
nginx -t

# 应该输出:
# nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
# nginx: configuration file /etc/nginx/nginx.conf test is successful
```

### 5.3 重载 Nginx
```bash
# 方式1: 宝塔面板
# 软件商店 → Nginx → 重载配置

# 方式2: 命令行
systemctl reload nginx

# 或
nginx -s reload
```

---

## 6. 启动服务

### 6.1 使用 PM2 启动 Node.js 服务
```bash
cd /home/www/GameDevMap

# 方式1: 使用 ecosystem 配置文件（推荐）
pm2 start ecosystem.config.js

# 方式2: 直接启动
pm2 start server/index.js --name gamedevmap-api

# 设置开机自启
pm2 save
pm2 startup
# 按照提示复制并执行 sudo 命令
```

**ecosystem.config.js 检查**:
```javascript
module.exports = {
  apps: [{
    name: 'gamedevmap-api',
    script: 'server/index.js',
    cwd: '/home/www/GameDevMap',
    instances: 1,
    exec_mode: 'fork',
    watch: false,
    max_memory_restart: '500M',
    env: {
      NODE_ENV: 'production',
      PORT: 3001
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss',
    merge_logs: true
  }]
}
```

### 6.2 验证服务状态
```bash
# 查看 PM2 进程列表
pm2 list

# 应该看到:
# ┌─────┬──────────────────┬─────────┬─────────┬───────┬────────┐
# │ id  │ name             │ status  │ restart │ cpu   │ memory │
# ├─────┼──────────────────┼─────────┼─────────┼───────┼────────┤
# │ 0   │ gamedevmap-api   │ online  │ 0       │ 0%    │ 50.0mb │
# └─────┴──────────────────┴─────────┴─────────┴───────┴────────┘

# 查看实时日志
pm2 logs gamedevmap-api

# 应该看到:
# ✅ MongoDB Connected: localhost
# 🚀 Server running on http://localhost:3001
# 📊 Admin panel: http://localhost:3001/admin
# 🗺️  Map view: http://localhost:3001
```

### 6.3 检查端口监听
```bash
# 检查 3001 端口是否被监听
netstat -tlnp | grep 3001

# 或
ss -tlnp | grep 3001

# 应该看到类似:
# tcp    0    0 0.0.0.0:3001    0.0.0.0:*    LISTEN    12345/node
```

---

## 7. 验证测试

### 7.1 测试 API 端点
```bash
# 测试健康检查
curl http://localhost:3001/api/health

# 应该返回:
# {"success":true,"message":"Server is running","timestamp":"2025-11-11T..."}

# 测试社团列表
curl http://localhost:3001/api/clubs

# 应该返回:
# {"success":true,"data":[...],"total":45}
```

### 7.2 测试静态文件
```bash
# 测试首页
curl -I http://yourdomain.com/

# 应该返回 200 OK

# 测试 clubs.json
curl http://yourdomain.com/data/clubs.json

# 应该返回 JSON 数据
```

### 7.3 测试上传文件访问
```bash
# 假设有文件 20251111_xxx_logo.png
curl -I http://yourdomain.com/assets/submissions/20251111_xxx_logo.png

# 应该返回 200 OK（如果文件存在）
```

### 7.4 测试管理面板登录
```bash
# 测试登录 API
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"your_admin_password"}'

# 应该返回:
# {"success":true,"message":"登录成功","data":{"token":"eyJ...","user":{...}}}
```

### 7.5 浏览器测试
```bash
# 1. 访问首页
http://yourdomain.com/

# 2. 访问管理面板
http://yourdomain.com/admin

# 3. 访问提交表单
http://yourdomain.com/submit.html
```

---

## 8. 故障排查

### 8.1 服务无法启动

**检查日志**:
```bash
# PM2 日志
pm2 logs gamedevmap-api --lines 100

# 错误日志
cat /home/www/GameDevMap/logs/err.log

# 输出日志
cat /home/www/GameDevMap/logs/out.log
```

**常见问题**:

1. **端口被占用**:
```bash
# 查找占用 3001 的进程
lsof -i :3001
# 或
netstat -tlnp | grep 3001

# 杀死进程
kill -9 <PID>

# 重启服务
pm2 restart gamedevmap-api
```

2. **MongoDB 连接失败**:
```bash
# 检查 MongoDB 是否运行
systemctl status mongodb

# 启动 MongoDB
systemctl start mongodb

# 检查连接字符串
cat .env | grep MONGODB_URI
```

3. **权限问题**:
```bash
# 确保文件所有权正确
chown -R www:www /home/www/GameDevMap

# 确保可执行
chmod +x server/index.js
```

### 8.2 Nginx 错误

**检查配置**:
```bash
# 测试配置
nginx -t

# 查看错误日志
tail -f /home/www/GameDevMap/logs/nginx_error.log
```

**常见问题**:

1. **502 Bad Gateway**:
```bash
# 检查 Node.js 服务是否运行
pm2 list

# 检查端口是否正确
curl http://localhost:3001/api/health
```

2. **403 Forbidden**:
```bash
# 检查文件权限
ls -la /home/www/GameDevMap/public/

# 修正权限
chmod -R 755 /home/www/GameDevMap/public/
```

### 8.3 Trust Proxy 错误

**检查是否修复**:
```bash
# 查看日志中是否还有 ERR_ERL_UNEXPECTED_X_FORWARDED_FOR
pm2 logs gamedevmap-api | grep "ERR_ERL"

# 应该没有输出（表示已修复）
```

**如果仍有错误**:
```bash
# 1. 确认代码已更新
grep "trust proxy" server/index.js

# 应该看到: app.set('trust proxy', 1);

# 2. 重启服务
pm2 restart gamedevmap-api

# 3. 清除 PM2 日志重新测试
pm2 flush
pm2 logs gamedevmap-api
```

### 8.4 上传文件无法访问

**检查路径**:
```bash
# 确认文件存在
ls -la /home/www/GameDevMap/data/submissions/

# 确认 Nginx 配置正确
nginx -T | grep "submissions"

# 应该看到 alias 指向 /home/www/GameDevMap/data/submissions/
```

**测试访问**:
```bash
# 直接访问文件
curl -I http://yourdomain.com/assets/submissions/test.png
```

---

## 9. 完整启动流程（快速参考）

### 9.1 首次部署
```bash
# 1. 准备环境
cd /home/www/GameDevMap
git pull origin main
npm install

# 2. 配置环境
nano .env  # 填写配置
mkdir -p data/submissions data/pending_submissions logs
chown -R www:www data logs

# 3. 启动 MongoDB
systemctl start mongodb
systemctl enable mongodb

# 4. 初始化数据
node server/scripts/seedAdmin.js
node server/scripts/migrateClubs.js  # 如果有数据

# 5. 配置 Nginx
# 通过宝塔面板或手动配置
nginx -t
systemctl reload nginx

# 6. 启动服务
pm2 start ecosystem.config.js
pm2 save
pm2 startup

# 7. 验证
curl http://localhost:3001/api/health
pm2 logs gamedevmap-api
```

### 9.2 日常重启
```bash
# 重启 Node.js
pm2 restart gamedevmap-api

# 重启 Nginx
systemctl reload nginx

# 重启 MongoDB
systemctl restart mongodb

# 查看状态
pm2 list
systemctl status nginx
systemctl status mongodb
```

### 9.3 更新代码
```bash
cd /home/www/GameDevMap

# 拉取最新代码
git pull origin main

# 安装新依赖（如果有）
npm install

# 运行迁移（如果有数据库变更）
node server/scripts/migrateClubs.js

# 重启服务
pm2 restart gamedevmap-api

# 监控日志
pm2 logs gamedevmap-api --lines 50
```

---

## 10. 监控与维护

### 10.1 日志监控
```bash
# 实时查看所有日志
pm2 logs gamedevmap-api

# 查看最近 100 行
pm2 logs gamedevmap-api --lines 100

# 仅查看错误
pm2 logs gamedevmap-api --err

# Nginx 访问日志
tail -f /home/www/GameDevMap/logs/nginx_access.log

# Nginx 错误日志
tail -f /home/www/GameDevMap/logs/nginx_error.log
```

### 10.2 性能监控
```bash
# PM2 监控面板
pm2 monit

# 查看详细信息
pm2 show gamedevmap-api

# 系统资源
htop
# 或
top
```

### 10.3 定期备份
```bash
# 备份脚本示例
cat > /home/www/GameDevMap/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/home/www/backup"
DATE=$(date +%Y%m%d_%H%M%S)

# 备份 MongoDB
mongodump --db gamedevmap --out $BACKUP_DIR/mongo_$DATE

# 备份上传文件
tar -czf $BACKUP_DIR/submissions_$DATE.tar.gz /home/www/GameDevMap/data/submissions

# 备份配置
cp /home/www/GameDevMap/.env $BACKUP_DIR/env_$DATE

echo "✅ Backup completed: $DATE"
EOF

chmod +x /home/www/GameDevMap/backup.sh

# 添加到 crontab（每天凌晨 2 点备份）
crontab -e
# 添加: 0 2 * * * /home/www/GameDevMap/backup.sh
```

---

## ✅ 完成检查清单

部署完成后，确认以下所有项：

- [ ] MongoDB 服务运行中
- [ ] Node.js 服务通过 PM2 运行（status: online）
- [ ] Nginx 配置正确且已重载
- [ ] .env 文件配置正确
- [ ] 管理员账户创建成功
- [ ] 数据已导入（如果有）
- [ ] API 健康检查返回成功
- [ ] 首页可以访问
- [ ] 管理面板可以登录
- [ ] 上传文件可以访问
- [ ] 无 `ERR_ERL_UNEXPECTED_X_FORWARDED_FOR` 错误
- [ ] PM2 设置为开机自启
- [ ] 日志目录权限正确

---

**全部完成后，你的 GameDevMap 应该已经完全运行！** 🎉