# 数据同步系统 (Data Sync System)

## 概述

GameDevMap使用双数据源策略：
1. **MongoDB数据库** - 动态数据存储，支持实时更新
2. **clubs.json文件** - 静态数据备份，支持离线访问和开源贡献

系统自动保持两者同步，确保数据一致性。

## 数据流向

```
用户提交
    ↓
MongoDB (Submissions)
    ↓
管理员审批
    ↓
MongoDB (Clubs) ←→ clubs.json
    ↓              ↓
  API端点      静态备份
    ↓              ↓
  地图显示      离线访问
```

## 自动同步

### 审批时自动同步
当管理员批准社团提交时，系统会：
1. 将数据写入MongoDB的Club集合
2. 自动触发`syncToJson`脚本
3. 更新`public/data/clubs.json`文件

**实现位置**: `server/routes/submissions.js` (approve endpoint)

### 前端数据加载
前端优先从API加载数据，失败时回退到静态文件

**实现位置**: `public/js/script.js` (loadData function)

## 手动同步命令

### JSON → MongoDB (导入)
```bash
npm run migrate:clubs
```

**用途**:
- 初始化数据库
- 从静态文件恢复数据
- 导入社区贡献的新社团
- 同步：删除数据库中存在但 clubs.json 中不存在的社团

**脚本**: `server/scripts/migrateClubs.js`

### MongoDB → JSON (导出)
```bash
# 完全替换模式（默认）- 用数据库内容完全覆盖 JSON
npm run sync:json

# 智能合并模式 - 保留 JSON 中的手动修改，更新数据库中存在的记录
npm run sync:merge

# 仅更新模式 - 只更新 JSON 中已存在的记录，不添加新记录
npm run sync:update

# 仅添加模式 - 只添加 JSON 中不存在的新记录，不修改现有记录
npm run sync:addOnly
```

**用途**:
- `sync:json` (replace): 完全同步，生产环境部署时的标准操作
- `sync:merge`: 智能合并，开发环境保留手动修改
- `sync:update`: 仅更新现有记录，数据刷新场景
- `sync:addOnly`: 仅添加新记录，增量更新场景

**脚本**: `server/scripts/syncToJson.js`

## 同步模式详解

### 完全替换模式 (replace)
**命令**: `npm run sync:json` 或 `node server/scripts/syncToJson.js replace`

**行为**:
- 用数据库中的所有社团完全覆盖 `clubs.json`
- 删除 JSON 中存在但数据库中不存在的社团
- 添加数据库中存在但 JSON 中不存在的社团
- 更新所有字段为数据库最新值

**适用场景**:
- 生产环境部署
- 确保数据完全一致
- 初始化或重置静态文件

**统计输出**: 显示添加、更新、删除的数量

### 智能合并模式 (merge)
**命令**: `npm run sync:merge` 或 `node server/scripts/syncToJson.js merge`

**行为**:
- 保留 JSON 中可能的手动修改字段
- 更新数据库中存在的记录的标准字段
- 添加数据库中存在但 JSON 中不存在的新社团
- 标记数据库中已删除但 JSON 中仍存在的社团

**适用场景**:
- 开发环境保留手动调整
- 社区贡献的数据合并
- 渐进式数据更新

**统计输出**: 显示添加、更新、删除、未更改的数量

### 仅更新模式 (update)
**命令**: `npm run sync:update` 或 `node server/scripts/syncToJson.js update`

**行为**:
- 只更新 JSON 中已存在的记录
- 不添加新的社团
- 不删除 JSON 中存在的社团
- 适用于数据刷新而不改变集合范围

**适用场景**:
- 现有社团信息更新
- 数据质量改进
- 避免意外添加或删除

**统计输出**: 显示更新和未更改的数量

### 仅添加模式 (addOnly)
**命令**: `npm run sync:addOnly` 或 `node server/scripts/syncToJson.js addOnly`

**行为**:
- 只添加 JSON 中不存在的新社团
- 不修改任何现有记录
- 不删除任何记录
- 完全保留现有数据

**适用场景**:
- 增量数据导入
- 新社团批量添加
- 安全的数据扩展

**统计输出**: 显示添加数量和未更改的现有记录数

## 开源贡献工作流

### 场景1: 通过提交表单添加社团
```
开发者填写表单 → 管理员审批 → 自动同步到clubs.json → 无需手动操作
```

### 场景2: 直接修改clubs.json (GitHub PR)
```bash
# 1. Fork项目并修改 public/data/clubs.json
# 2. 提交PR并合并
# 3. 部署后运行迁移命令
npm run migrate:clubs
```

### 场景3: 直接在数据库中修改
```bash
# 1. 通过MongoDB工具修改数据
# 2. 运行同步命令
npm run sync:json
# 3. 提交更新后的clubs.json到Git
```
   
## 备份策略

### 自动备份
`syncToJson`脚本运行时会自动创建备份：
```
public/data/clubs.json.backup
```

### Git版本控制
clubs.json文件被Git跟踪，每次更新都会被记录：
```bash
git log public/data/clubs.json
```

## 故障恢复

### 情况1: clubs.json丢失
```bash
npm run sync:json
```

### 情况2: MongoDB数据丢失
```bash
npm run migrate:clubs
```

### 情况3: 数据不一致
```bash
# 以MongoDB为准
npm run sync:json

# 或以clubs.json为准
npm run migrate:clubs
```

## API端点

### 获取所有社团
```
GET /api/clubs
Response: {success: true, data: [...], total: 100}
```

### 获取单个社团
```
GET /api/clubs/:id
Response: {success: true, data: {...}}
```
## 监控和日志

所有同步操作都会输出详细日志：
```bash
# 查看服务器日志
pm2 logs gamedevmap-api
```