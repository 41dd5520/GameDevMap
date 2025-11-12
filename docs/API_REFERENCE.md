# GameDevMap API 参考文档

**适用版本：** v1.0.0  
**最后更新：** 2025-11-12

---

## 概述

本文档提供 GameDevMap 系统的完整 API 参考。包含网站架构、服务端架构以及所有公开 API 端点的签名和参数说明。

GameDevMap 是一个全国高校游戏开发社团地图系统，提供社团信息的提交、审核、展示和管理功能。

---

## 目录

- [GameDevMap API 参考文档](#gamedevmap-api-参考文档)
  - [概述](#概述)
  - [目录](#目录)
  - [系统架构](#系统架构)
    - [网站架构图](#网站架构图)
    - [服务端架构图](#服务端架构图)
  - [认证 API](#认证-api)
    - [`POST /api/auth/login`](#post-apiauthlogin)
  - [文件上传 API](#文件上传-api)
    - [`POST /api/upload/logo`](#post-apiuploadlogo)
  - [提交管理 API](#提交管理-api)
    - [`POST /api/submissions`](#post-apisubmissions)
    - [`GET /api/submissions`](#get-apisubmissions)
    - [`GET /api/submissions/:id`](#get-apisubmissionsid)
    - [`PUT /api/submissions/:id/approve`](#put-apisubmissionsidapprove)
    - [`PUT /api/submissions/:id/reject`](#put-apisubmissionsidreject)
  - [社团管理 API](#社团管理-api)
    - [`GET /api/clubs`](#get-apiclubs)
    - [`GET /api/clubs/:id`](#get-apiclubsid)
    - [`PUT /api/clubs/:id`](#put-apiclubsid)
    - [`DELETE /api/clubs/:id`](#delete-apiclubsid)
  - [数据模型](#数据模型)
    - [`Submission` (提交)](#submission-提交)
    - [`Club` (社团)](#club-社团)
    - [`AdminUser` (管理员)](#adminuser-管理员)
  - [错误处理](#错误处理)
  - [延伸阅读](#延伸阅读)
  - [公开端点](#公开端点)
    - [POST /api/upload/logo](#post-apiuploadlogo-1)
    - [POST /api/submissions](#post-apisubmissions-1)
    - [GET /api/clubs](#get-apiclubs-1)
    - [GET /api/clubs/:id](#get-apiclubsid-1)
  - [管理端点](#管理端点)
    - [GET /api/submissions](#get-apisubmissions-1)
    - [GET /api/submissions/:id](#get-apisubmissionsid-1)
    - [PUT /api/submissions/:id/approve](#put-apisubmissionsidapprove-1)
    - [PUT /api/submissions/:id/reject](#put-apisubmissionsidreject-1)
  - [数据模型](#数据模型-1)
    - [Submission (提交)](#submission-提交-1)
    - [Club (社团)](#club-社团-1)
    - [AdminUser (管理员)](#adminuser-管理员-1)
  - [错误处理](#错误处理-1)
    - [错误响应格式](#错误响应格式)
    - [常见错误码](#常见错误码)
  - [提交生命周期](#提交生命周期)
    - [状态流转图](#状态流转图)
    - [详细步骤](#详细步骤)
      - [1. 提交 (Submission)](#1-提交-submission)
      - [2. 审核 (Review)](#2-审核-review)
      - [3. 批准 (Approve)](#3-批准-approve)
      - [4. 同步 (Sync)](#4-同步-sync)
      - [5. 展示 (Display)](#5-展示-display)
  - [数据同步机制](#数据同步机制)
    - [MongoDB ↔ clubs.json 双向同步](#mongodb--clubsjson-双向同步)
      - [JSON → MongoDB (迁移)](#json--mongodb-迁移)
      - [MongoDB → JSON (同步)](#mongodb--json-同步)
  - [容灾与恢复](#容灾与恢复)
    - [临时JSON (Pending Submissions)](#临时json-pending-submissions)
    - [备份策略](#备份策略)
  - [性能优化](#性能优化)
    - [频率限制 (Rate Limiting)](#频率限制-rate-limiting)
    - [数据库索引](#数据库索引)
  - [安全措施](#安全措施)
    - [输入验证](#输入验证)
    - [认证与授权](#认证与授权)
    - [安全头](#安全头)
    - [日志记录](#日志记录)
  - [附录](#附录)
    - [环境变量](#环境变量)
    - [启动命令](#启动命令)
    - [数据迁移](#数据迁移)
  - [联系方式](#联系方式)

---

## 系统架构

### 网站架构图

```mermaid
graph TB
    A[用户浏览器] --> B[index.html<br/>地图展示页面]
    A --> C[submit.html<br/>提交表单页面]
    A --> D[admin/index.html<br/>管理后台页面]

    B --> E[public/data/clubs.json<br/>静态社团数据]
    B --> F[public/assets/<br/>compressedLogos/<br/>社团Logo]

    C --> G[JavaScript<br/>表单验证]
    D --> H[JavaScript<br/>管理界面]

    G --> I[POST /api/submissions<br/>提交社团信息]
    H --> J[GET /api/submissions<br/>获取待审核列表]
    H --> K[PUT /api/submissions/:id/approve<br/>批准提交]
    H --> L[PUT /api/submissions/:id/reject<br/>拒绝提交]
    H --> M[GET /api/clubs<br/>获取社团列表]
    H --> N[PUT /api/clubs/:id<br/>编辑社团]
    H --> O[DELETE /api/clubs/:id<br/>删除社团]

    I --> P[Express.js Server<br/>端口 3000]
    J --> P
    K --> P
    L --> P
    M --> P
    N --> P
    O --> P
```

### 服务端架构图

```mermaid
graph TB
    subgraph "客户端层"
        A[浏览器]
    end

    subgraph "API网关层"
        B[Express.js Server<br/>端口 3000]
        B1[helmet<br/>安全头]
        B2[cors<br/>跨域支持]
        B3[express.json<br/>JSON解析]
        B4[morgan<br/>请求日志]
        B5[rateLimiter<br/>频率限制]
    end

    subgraph "业务逻辑层"
        C1[认证中间件<br/>JWT验证]
        C2[验证中间件<br/>Joi校验]
        C3[上传中间件<br/>multer文件处理]
    end

    subgraph "路由层"
        D1[/api/auth<br/>认证路由]
        D2[/api/upload<br/>文件上传路由]
        D3[/api/submissions<br/>提交管理路由]
        D4[/api/clubs<br/>社团查询路由]
    end

    subgraph "数据访问层"
        E1[MongoDB<br/>主数据库]
        E2[文件系统<br/>data/目录]
        E3[静态JSON<br/>public/data/]
    end

    subgraph "数据存储"
        F1[(Submissions<br/>待审核提交)]
        F2[(Clubs<br/>已批准社团)]
        F3[(AdminUsers<br/>管理员账户)]
        F4[data/submissions/<br/>上传的Logo文件]
        F5[data/pending_submissions/<br/>临时JSON备份]
        F6[public/data/clubs.json<br/>前端读取数据]
        F7[public/assets/logos/<br/>处理后Logo]
        F8[public/assets/compressedLogos/<br/>压缩Logo]
    end

    A --> B
    B --> B1
    B --> B2
    B --> B3
    B --> B4
    B --> B5

    B --> C1
    B --> C2
    B --> C3

    C1 --> D1
    C2 --> D2
    C3 --> D3
    C1 --> D4

    D1 --> E1
    D2 --> E2
    D3 --> E1
    D4 --> E1

    E1 --> F1
    E1 --> F2
    E1 --> F3
    E2 --> F4
    E2 --> F5
    E3 --> F6
    E2 --> F7
    E2 --> F8
```

---

## 认证 API

### `POST /api/auth/login`

**说明：**  
管理员用户登录，验证用户名和密码，返回JWT访问令牌。

**参数：**

| 参数名 | 类型 | 必填/可选 | 说明 | 默认值 |
|--------|------|----------|------|--------|
| `username` | `string` | 必填 | 管理员用户名 | - |
| `password` | `string` | 必填 | 管理员密码 | - |

**返回值：**
- **类型：** `Object`
- **成功情况：** 返回包含JWT令牌的用户信息
- **失败情况：** 返回错误信息

**使用示例：**

```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"your_password"}'
```

---

## 文件上传 API

### `POST /api/upload/logo`

**说明：**  
上传社团Logo图片文件，进行格式验证和存储。

**参数：**

| 参数名 | 类型 | 必填/可选 | 说明 | 默认值 |
|--------|------|----------|------|--------|
| `logo` | `File` | 必填 | Logo图片文件（PNG/JPG/GIF/SVG，最大20MB） | - |

**返回值：**
- **类型：** `Object`
- **成功情况：** 返回文件访问路径
- **失败情况：** 返回错误信息

**使用示例：**

```bash
curl -X POST http://localhost:3000/api/upload/logo \
  -F "logo=@logo.png"
```

---

## 提交管理 API

### `POST /api/submissions`

**说明：**  
提交新的社团信息，创建待审核的提交记录。

**参数：**

| 参数名 | 类型 | 必填/可选 | 说明 | 默认值 |
|--------|------|----------|------|--------|
| `submissionType` | `string` | 可选 | 提交类型：'new'或'edit' | 'new' |
| `name` | `string` | 必填 | 社团名称 | - |
| `school` | `string` | 必填 | 所属学校 | - |
| `province` | `string` | 必填 | 所在省份 | - |
| `city` | `string` | 可选 | 所在城市 | - |
| `coordinates` | `Object` | 必填 | 坐标对象 | - |
| `coordinates.latitude` | `number` | 必填 | 纬度 | - |
| `coordinates.longitude` | `number` | 必填 | 经度 | - |
| `short_description` | `string` | 可选 | 社团简介（短） | - |
| `long_description` | `string` | 可选 | 社团简介（长） | - |
| `tags` | `Array<string>` | 可选 | 标签数组 | [] |
| `external_links` | `Array<Object>` | 可选 | 外部链接数组 | [] |
| `logo` | `string` | 可选 | Logo文件路径 | - |
| `submitterEmail` | `string` | 必填 | 提交者邮箱 | - |
| `editingClubId` | `string` | 可选 | 编辑模式下的社团ID | - |

**返回值：**
- **类型：** `Object`
- **成功情况：** 返回提交ID和状态信息
- **失败情况：** 返回验证错误信息

---

### `GET /api/submissions`

**说明：**  
获取提交列表，支持分页、筛选和排序（需要管理员权限）。

**参数：**

| 参数名 | 类型 | 必填/可选 | 说明 | 默认值 |
|--------|------|----------|------|--------|
| `page` | `number` | 可选 | 页码（从1开始） | 1 |
| `limit` | `number` | 可选 | 每页数量（1-50） | 10 |
| `status` | `string` | 可选 | 状态筛选：'pending'/'approved'/'rejected'/'all' | 'pending' |
| `sort` | `string` | 可选 | 排序：'newest'/'oldest' | 'newest' |

**返回值：**
- **类型：** `Object`
- **成功情况：** 返回分页的提交列表
- **失败情况：** 返回错误信息

---

### `GET /api/submissions/:id`

**说明：**  
获取单个提交的详细信息（需要管理员权限）。

**参数：**

| 参数名 | 类型 | 必填/可选 | 说明 | 默认值 |
|--------|------|----------|------|--------|
| `id` | `string` | 必填 | 提交记录ID | - |

**返回值：**
- **类型：** `Object`
- **成功情况：** 返回提交详细信息
- **失败情况：** 返回错误信息

---

### `PUT /api/submissions/:id/approve`

**说明：**  
批准提交，将其转换为正式社团记录（需要管理员权限）。

**参数：**

| 参数名 | 类型 | 必填/可选 | 说明 | 默认值 |
|--------|------|----------|------|--------|
| `id` | `string` | 必填 | 提交记录ID | - |

**返回值：**
- **类型：** `Object`
- **成功情况：** 返回提交ID和新创建的社团ID
- **失败情况：** 返回错误信息

---

### `PUT /api/submissions/:id/reject`

**说明：**  
拒绝提交，标记为已拒绝状态（需要管理员权限）。

**参数：**

| 参数名 | 类型 | 必填/可选 | 说明 | 默认值 |
|--------|------|----------|------|--------|
| `id` | `string` | 必填 | 提交记录ID | - |
| `rejectionReason` | `string` | 必填 | 拒绝原因 | - |

**返回值：**
- **类型：** `Object`
- **成功情况：** 返回操作成功信息
- **失败情况：** 返回错误信息

---

## 社团管理 API

### `GET /api/clubs`

**说明：**  
获取所有已批准社团的列表，支持搜索筛选。

**参数：**

| 参数名 | 类型 | 必填/可选 | 说明 | 默认值 |
|--------|------|----------|------|--------|
| `search` | `string` | 可选 | 搜索关键词（名称、学校、省份等） | - |

**返回值：**
- **类型：** `Array`
- **成功情况：** 返回社团列表数组
- **失败情况：** 返回错误信息

---

### `GET /api/clubs/:id`

**说明：**  
获取单个社团的详细信息。

**参数：**

| 参数名 | 类型 | 必填/可选 | 说明 | 默认值 |
|--------|------|----------|------|--------|
| `id` | `string` | 必填 | 社团ID | - |

**返回值：**
- **类型：** `Object`
- **成功情况：** 返回社团详细信息
- **失败情况：** 返回错误信息

---

### `PUT /api/clubs/:id`

**说明：**  
编辑社团信息（需要管理员权限）。

**参数：**

| 参数名 | 类型 | 必填/可选 | 说明 | 默认值 |
|--------|------|----------|------|--------|
| `id` | `string` | 必填 | 社团ID | - |
| `name` | `string` | 可选 | 社团名称 | - |
| `school` | `string` | 可选 | 所属学校 | - |
| `province` | `string` | 可选 | 所在省份 | - |
| `city` | `string` | 可选 | 所在城市 | - |
| `description` | `string` | 可选 | 详细介绍 | - |
| `shortDescription` | `string` | 可选 | 简介 | - |
| `tags` | `Array<string>` | 可选 | 标签数组 | - |
| `website` | `string` | 可选 | 官方网站 | - |
| `contact` | `Object` | 可选 | 联系方式对象 | - |
| `coordinates` | `Array<number>` | 可选 | 坐标数组 [经度,纬度] | - |

**返回值：**
- **类型：** `Object`
- **成功情况：** 返回更新后的社团信息
- **失败情况：** 返回错误信息

---

### `DELETE /api/clubs/:id`

**说明：**  
删除社团记录及其相关Logo文件（需要管理员权限）。

**参数：**

| 参数名 | 类型 | 必填/可选 | 说明 | 默认值 |
|--------|------|----------|------|--------|
| `id` | `string` | 必填 | 社团ID | - |

**返回值：**
- **类型：** `Object`
- **成功情况：** 返回删除成功信息
- **失败情况：** 返回错误信息

---

## 数据模型

### `Submission` (提交)

**说明：**  
表示用户提交的社团信息记录，等待管理员审核。

**字段：**

| 字段名 | 类型 | 必填/可选 | 说明 |
|--------|------|----------|------|
| `submissionType` | `string` | 必填 | 提交类型：'new'或'edit' |
| `editingClubId` | `string` | 可选 | 编辑模式下的原社团ID |
| `status` | `string` | 必填 | 状态：'pending'/'approved'/'rejected' |
| `data` | `Object` | 必填 | 社团数据对象 |
| `submitterEmail` | `string` | 必填 | 提交者邮箱 |
| `submittedAt` | `Date` | 自动 | 提交时间 |
| `reviewedAt` | `Date` | 可选 | 审核时间 |
| `reviewedBy` | `string` | 可选 | 审核管理员 |
| `rejectionReason` | `string` | 可选 | 拒绝原因 |

---

### `Club` (社团)

**说明：**  
表示已批准的社团记录，用于前端地图展示。

**字段：**

| 字段名 | 类型 | 必填/可选 | 说明 |
|--------|------|----------|------|
| `name` | `string` | 必填 | 社团名称 |
| `school` | `string` | 必填 | 所属学校 |
| `province` | `string` | 必填 | 所在省份 |
| `city` | `string` | 可选 | 所在城市 |
| `coordinates` | `Array<number>` | 必填 | 坐标 [经度,纬度] |
| `description` | `string` | 可选 | 详细介绍 |
| `shortDescription` | `string` | 可选 | 简介 |
| `tags` | `Array<string>` | 可选 | 标签数组 |
| `logo` | `string` | 可选 | Logo文件名 |
| `website` | `string` | 可选 | 官方网站 |
| `contact` | `Object` | 可选 | 联系方式 |
| `createdAt` | `Date` | 自动 | 创建时间 |
| `updatedAt` | `Date` | 自动 | 更新时间 |

---

### `AdminUser` (管理员)

**说明：**  
系统管理员账户信息。

**字段：**

| 字段名 | 类型 | 必填/可选 | 说明 |
|--------|------|----------|------|
| `username` | `string` | 必填 | 用户名 |
| `password` | `string` | 必填 | 密码哈希 |
| `role` | `string` | 必填 | 角色：'admin' |
| `createdAt` | `Date` | 自动 | 创建时间 |

---

## 错误处理

API 错误响应统一格式：

```json
{
  "success": false,
  "error": "ERROR_CODE",
  "message": "错误描述信息"
}
```

**常见错误码：**

| 错误码 | HTTP状态码 | 说明 |
|--------|-----------|------|
| `INVALID_ID` | 400 | ID格式不正确 |
| `NOT_FOUND` | 404 | 资源不存在 |
| `INVALID_STATUS` | 409 | 状态不允许操作 |
| `MISSING_REASON` | 400 | 缺少必要参数 |
| `VALIDATION_ERROR` | 400 | 数据验证失败 |
| `SERVER_ERROR` | 500 | 服务器内部错误 |
| `UNAUTHORIZED` | 401 | 未授权访问 |

---

## 延伸阅读

- [数据同步机制](./DATA_SYNC.md) - MongoDB与JSON的双向同步
- [服务器配置](./CONFIG.md) - 服务器配置和部署指南
- [前端开发指南](./GUIDE.md) - 前端开发和使用说明
  "error": "INVALID_CREDENTIALS",
  "message": "用户名或密码错误"
}
```

**认证头格式**:
```http
Authorization: Bearer <token>
```

---

## 公开端点

### POST /api/upload/logo
**上传社团 Logo**

**请求**:
```http
POST /api/upload/logo
Content-Type: multipart/form-data

logo: <file> (PNG/JPG/GIF/SVG, 最大 20MB)
```

**响应**:
```json
{
  "success": true,
  "message": "文件上传成功",
  "data": {
    "path": "/assets/submissions/20251111_a1k74awi_logo.png",
    "filename": "20251111_a1k74awi_logo.png",
    "size": 34077,
    "mimetype": "image/png"
  }
}
```

**文件命名规则**:
```
格式: {YYYYMMDD}_{randomID}_{sanitized_basename}.{ext}
示例: 20251111_a1k74awi_logo.png

清理规则:
- 保留字母、数字、中文
- 其他字符替换为下划线
- 限制basename最长50字符
- 如果basename为空，使用 'logo'
```

**存储位置**:
- 物理路径: `data/submissions/`
- 公开URL: `/assets/submissions/{filename}`

**错误响应**:
```json
{
  "success": false,
  "error": "UPLOAD_ERROR",
  "message": "文件大小超过限制（最大 20MB）"
}
```

---

### POST /api/submissions
**提交新社团信息**

**频率限制**: 5 次/小时/IP

**请求**:
```http
POST /api/submissions
Content-Type: application/json

{
  "name": "游戏开发社",
  "school": "清华大学",
  "province": "北京市",
  "city": "海淀区",
  "coordinates": {
    "latitude": 39.9995,
    "longitude": 116.3267
  },
  "short_description": "致力于游戏开发的学生组织",
  "long_description": "我们是清华大学游戏开发社，成立于2020年，致力于推广游戏开发文化...",
  "tags": ["游戏开发", "Unity", "独立游戏"],
  "logo": "/assets/submissions/20251111_a1k74awi_logo.png",
  "submitterEmail": "submitter@example.com"
}
```

**字段说明**:
| 字段 | 类型 | 必填 | 长度限制 | 说明 |
|------|------|------|----------|------|
| name | string | ✅ | 2-100 | 社团名称 |
| school | string | ✅ | 2-100 | 学校名称 |
| province | string | ✅ | - | 必须是有效省份（34个省级行政区） |
| city | string | ❌ | 2-50 | 城市名称 |
| coordinates | object | ✅ | - | {latitude: number, longitude: number} |
| short_description | string | ❌ | 0-200 | **短描述，独立字段** |
| long_description | string | ❌ | 0-1000 | **长描述，独立字段** |
| tags | array | ❌ | 最多10个 | 每个标签最长20字符 |
| logo | string | ❌ | - | 上传后返回的路径 |
| submitterEmail | string | ✅ | - | 提交者邮箱 |

**重要说明**:
- ⚠️ `short_description` 和 `long_description` **是独立字段**，不会互相覆盖
- ⚠️ 系统不会自动截断 `long_description` 来填充 `short_description`
- 建议前端同时收集两个描述字段

**响应**:
```json
{
  "success": true,
  "message": "提交成功！您的社团信息正在审核中，预计 1-3 个工作日内完成审核",
  "data": {
    "submissionId": "673257b8c5e4f2a1d8b9e012",
    "estimatedReviewTime": "1-3 个工作日",
    "status": "pending"
  }
}
```

**后台处理流程**:
1. **Joi 验证** (validateSubmission 中间件)
2. **提取元数据** (IP、User-Agent)
3. **重复检测** (可降级，失败不阻塞)
4. **【关键】写入临时JSON** (`data/pending_submissions/{timestamp}_{random}.json`)
   - 目的: 防止 MongoDB 不可用时数据丢失
   - 内容: 完整的 validatedData + 元数据
5. **写入 MongoDB** (Submission 集合)
6. **返回成功响应**

**临时JSON示例**:
```json
{
  "timestamp": "2025-11-11T21:36:58.000Z",
  "ipAddress": "127.0.0.1",
  "userAgent": "Mozilla/5.0...",
  "duplicateCheck": {
    "passed": true,
    "similarClubs": []
  },
  "submission": {
    "submitterEmail": "user@example.com",
    "data": {
      "name": "游戏开发社",
      "school": "清华大学",
      "province": "北京市",
      "city": "海淀区",
      "coordinates": {
        "latitude": 39.9995,
        "longitude": 116.3267
      },
      "short_description": "致力于游戏开发的学生组织",
      "long_description": "详细介绍...",
      "tags": ["游戏开发"],
      "logo": "/assets/submissions/20251111_a1k74awi_logo.png"
    }
  }
}
```

**错误响应**:
```json
{
  "success": false,
  "error": "VALIDATION_ERROR",
  "message": "数据验证失败",
  "errors": [
    {
      "field": "name",
      "message": "社团名称至少需要 2 个字符"
    }
  ]
}
```

---

### GET /api/clubs
**获取所有已批准的社团**

**请求**:
```http
GET /api/clubs
```

**响应**:
```json
{
  "success": true,
  "data": [
    {
      "id": "673257b8c5e4f2a1d8b9e012",
      "name": "游戏开发社",
      "school": "清华大学",
      "city": "海淀区",
      "province": "北京市",
      "latitude": 39.9995,
      "longitude": 116.3267,
      "img_name": "/assets/submissions/20251111_a1k74awi_logo.png",
      "short_description": "致力于游戏开发的学生组织",
      "long_description": "我们是清华大学游戏开发社...",
      "tags": ["游戏开发", "Unity"],
      "website": "",
      "contact": {}
    }
  ],
  "total": 1
}
```

**数据格式转换**:
```javascript
// MongoDB 内部格式 -> 前端格式
{
  _id: ObjectId("..."),           → id: "..."
  coordinates: [116.3267, 39.9995] → latitude: 39.9995, longitude: 116.3267
  logo: "..."                     → img_name: "..."
  shortDescription: "..."         → short_description: "..." (不截断)
  description: "..."              → long_description: "..."
}
```

**⚠️ 重要变更**:
- `short_description` **直接读取** `shortDescription` 字段
- **不再**使用 `description.substring(0, 50)` 作为降级
- 如果 `shortDescription` 为空，返回空字符串 `""`

---

### GET /api/clubs/:id
**获取单个社团详情**

**请求**:
```http
GET /api/clubs/673257b8c5e4f2a1d8b9e012
```

**响应**:
```json
{
  "success": true,
  "data": {
    "id": "673257b8c5e4f2a1d8b9e012",
    "name": "游戏开发社",
    "school": "清华大学",
    "city": "海淀区",
    "province": "北京市",
    "latitude": 39.9995,
    "longitude": 116.3267,
    "img_name": "/assets/submissions/20251111_a1k74awi_logo.png",
    "short_description": "致力于游戏开发的学生组织",
    "long_description": "详细介绍...",
    "tags": ["游戏开发", "Unity"],
    "website": "https://example.com",
    "contact": {
      "qq": "123456789"
    }
  }
}
```

---

## 管理端点

所有管理端点需要在请求头中携带 JWT token:
```http
Authorization: Bearer <token>
```

### GET /api/submissions
**获取提交列表（管理员）**

**请求**:
```http
GET /api/submissions?page=1&limit=10&status=pending&sort=desc
Authorization: Bearer <token>
```

**查询参数**:
| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| page | number | 1 | 页码 (≥1) |
| limit | number | 10 | 每页条数 (1-50) |
| status | string | all | pending/approved/rejected/all |
| sort | string | desc | asc/desc (按提交时间) |

**响应**:
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "_id": "673257b8c5e4f2a1d8b9e012",
        "submitterEmail": "user@example.com",
        "status": "pending",
        "data": {
          "name": "游戏开发社",
          "school": "清华大学",
          "province": "北京市",
          "city": "海淀区",
          "coordinates": [116.3267, 39.9995],
          "description": "详细介绍...",
          "shortDescription": "简短介绍...",
          "tags": ["游戏开发"],
          "logo": "/assets/submissions/20251111_a1k74awi_logo.png",
          "website": "",
          "contact": {}
        },
        "metadata": {
          "ipAddress": "127.0.0.1",
          "userAgent": "Mozilla/5.0...",
          "duplicateCheck": {
            "passed": true,
            "similarClubs": []
          }
        },
        "submittedAt": "2025-11-11T12:00:00.000Z",
        "reviewedAt": null,
        "reviewedBy": null,
        "rejectionReason": null
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 10,
      "totalItems": 1,
      "totalPages": 1
    }
  }
}
```

---

### GET /api/submissions/:id
**获取单个提交详情（管理员）**

**请求**:
```http
GET /api/submissions/673257b8c5e4f2a1d8b9e012
Authorization: Bearer <token>
```

**响应**:
```json
{
  "success": true,
  "data": {
    "_id": "673257b8c5e4f2a1d8b9e012",
    "submitterEmail": "user@example.com",
    "status": "pending",
    "data": {
      "name": "游戏开发社",
      "school": "清华大学",
      "province": "北京市",
      "city": "海淀区",
      "coordinates": [116.3267, 39.9995],
      "description": "详细介绍...",
      "shortDescription": "简短介绍...",
      "tags": ["游戏开发"],
      "logo": "/assets/submissions/20251111_a1k74awi_logo.png",
      "website": "",
      "contact": {}
    },
    "metadata": {
      "ipAddress": "127.0.0.1",
      "userAgent": "Mozilla/5.0...",
      "duplicateCheck": {
        "passed": true,
        "similarClubs": [
          {
            "_id": "...",
            "name": "类似社团",
            "school": "类似学校",
            "similarity": 0.85
          }
        ]
      }
    },
    "submittedAt": "2025-11-11T12:00:00.000Z",
    "reviewedAt": null,
    "reviewedBy": null,
    "rejectionReason": null
  }
}
```

---

### PUT /api/submissions/:id/approve
**批准提交（管理员）**

**请求**:
```http
PUT /api/submissions/673257b8c5e4f2a1d8b9e012/approve
Authorization: Bearer <token>
```

**处理流程**:
1. **验证 JWT** (authenticate 中间件)
2. **检查 submission 状态** (必须是 `pending`)
3. **创建 Club 文档**:
   ```javascript
   {
     name: submission.data.name,
     school: submission.data.school,
     province: submission.data.province,
     city: submission.data.city,
     coordinates: [longitude, latitude],
     description: submission.data.description,        // 长描述
     shortDescription: submission.data.shortDescription || '',  // 短描述（不截断）
     tags: submission.data.tags,
     logo: submission.data.logo,
     website: submission.data.website,
     contact: submission.data.contact,
     sourceSubmission: submission._id,
     verifiedBy: req.user.username
   }
   ```
4. **更新 submission 状态**:
   ```javascript
   {
     status: 'approved',
     reviewedAt: new Date(),
     reviewedBy: req.user.username,
     rejectionReason: undefined
   }
   ```
5. **【异步】触发同步** `syncToJson()`:
   - 读取所有 Club 文档
   - 转换为 clubs.json 格式
   - 备份旧文件
   - 写入新文件

**响应**:
```json
{
  "success": true,
  "message": "提交已批准并生成社团记录",
  "data": {
    "submissionId": "673257b8c5e4f2a1d8b9e012",
    "clubId": "673257c0c5e4f2a1d8b9e013"
  }
}
```

**错误响应**:
```json
{
  "success": false,
  "error": "INVALID_STATUS",
  "message": "仅待审核状态的提交可以被批准"
}
```

---

### PUT /api/submissions/:id/reject
**拒绝提交（管理员）**

**请求**:
```http
PUT /api/submissions/673257b8c5e4f2a1d8b9e012/reject
Authorization: Bearer <token>
Content-Type: application/json

{
  "rejectionReason": "社团信息不完整，请补充详细介绍"
}
```

**字段说明**:
| 字段 | 类型 | 必填 | 长度限制 | 说明 |
|------|------|------|----------|------|
| rejectionReason | string | ✅ | 1-500 | 拒绝原因 |

**响应**:
```json
{
  "success": true,
  "message": "提交已拒绝，原因已记录",
  "data": {
    "submissionId": "673257b8c5e4f2a1d8b9e012"
  }
}
```

---

## 数据模型

### Submission (提交)
```javascript
{
  _id: ObjectId,
  submitterEmail: String,        // 提交者邮箱
  status: String,                // 'pending' | 'approved' | 'rejected'
  data: {
    name: String,                // 社团名称
    school: String,              // 学校名称
    province: String,            // 省份
    city: String,                // 城市
    coordinates: [Number],       // [经度, 纬度]
    description: String,         // 长描述 (独立字段)
    shortDescription: String,    // 短描述 (独立字段，不截断)
    tags: [String],              // 标签
    logo: String,                // Logo 路径
    website: String,             // 官网
    contact: Object              // 联系方式
  },
  metadata: {
    ipAddress: String,           // 提交者IP
    userAgent: String,           // 浏览器UA
    duplicateCheck: {
      passed: Boolean,           // 重复检测是否通过
      similarClubs: [ObjectId]   // 相似社团列表
    }
  },
  submittedAt: Date,             // 提交时间
  reviewedAt: Date,              // 审核时间
  reviewedBy: String,            // 审核人
  rejectionReason: String        // 拒绝原因
}
```

### Club (社团)
```javascript
{
  _id: ObjectId,
  name: String,                  // 社团名称
  school: String,                // 学校名称
  province: String,              // 省份
  city: String,                  // 城市
  coordinates: [Number],         // [经度, 纬度] (GeoJSON格式)
  description: String,           // 长描述 (独立字段)
  shortDescription: String,      // 短描述 (独立字段，不截断)
  tags: [String],                // 标签
  logo: String,                  // Logo 路径
  website: String,               // 官网
  contact: Object,               // 联系方式
  sourceSubmission: ObjectId,    // 关联的提交ID
  verifiedBy: String,            // 审核人
  createdAt: Date,               // 创建时间
  updatedAt: Date                // 更新时间
}
```

**关键字段说明**:
- `description`: 长描述，存储完整的社团介绍 (最长 1000 字符)
- `shortDescription`: 短描述，独立字段

### AdminUser (管理员)
```javascript
{
  _id: ObjectId,
  username: String,              // 用户名 (唯一)
  password: String,              // bcrypt 加密密码
  role: String,                  // 'admin' | 'superadmin'
  createdAt: Date,               // 创建时间
  lastLoginAt: Date              // 最后登录时间
}
```

---

## 错误处理

### 错误响应格式
```json
{
  "success": false,
  "error": "ERROR_CODE",
  "message": "用户友好的错误消息",
  "errors": [                    // 仅验证错误有此字段
    {
      "field": "name",
      "message": "社团名称至少需要 2 个字符"
    }
  ]
}
```

### 常见错误码

| 错误码 | HTTP状态码 | 说明 |
|--------|-----------|------|
| VALIDATION_ERROR | 400 | 请求参数验证失败 |
| INVALID_CREDENTIALS | 401 | 登录凭证错误 |
| INVALID_TOKEN | 401 | Token 无效 |
| TOKEN_EXPIRED | 401 | Token 已过期 |
| UNAUTHORIZED | 401 | 未认证 |
| NOT_FOUND | 404 | 资源不存在 |
| INVALID_STATUS | 409 | 状态冲突 |
| DUPLICATE_ERROR | 409 | 数据重复 |
| UPLOAD_ERROR | 400 | 文件上传错误 |
| SERVER_ERROR | 500 | 服务器内部错误 |

---

## 提交生命周期

### 状态流转图

```
           ┌─────────────┐
           │   用户提交   │
           └──────┬──────┘
                  │
                  ▼
         ┌────────────────┐
         │ 写入临时JSON   │  ← 【防数据丢失】
         └────────┬───────┘
                  │
                  ▼
         ┌────────────────┐
         │   pending      │  ← 初始状态
         │  (待审核)      │
         └────┬───────┬───┘
              │       │
      approve │       │ reject
              │       │
      ┌───────▼───┐   └───────▼───────┐
      │ approved  │       │  rejected  │
      │ (已批准)  │       │  (已拒绝)  │
      └─────┬─────┘       └────────────┘
            │
            ▼
    ┌───────────────┐
    │ 创建 Club 记录 │
    └───────┬───────┘
            │
            ▼
    ┌───────────────┐
    │ syncToJson()  │  ← 同步到静态文件
    └───────┬───────┘
            │
            ▼
    ┌───────────────┐
    │ 前端展示社团  │
    └───────────────┘
```

### 详细步骤

#### 1. 提交 (Submission)
- 用户填写表单
- 上传 Logo → `data/submissions/`
- POST /api/submissions
- **立即写入临时JSON** → `data/pending_submissions/`
- 写入 MongoDB (status: 'pending')

#### 2. 审核 (Review)
- 管理员登录
- 查看提交列表
- 检查重复、验证信息
- 选择批准或拒绝

#### 3. 批准 (Approve)
- PUT /api/submissions/:id/approve
- 创建 Club 文档 (description 和 shortDescription 独立保存)
- submission.status → 'approved'
- **异步触发** syncToJson()

#### 4. 同步 (Sync)
- 读取所有 Club 文档
- 转换格式 (MongoDB → JSON)
- 备份旧文件
- 写入 `public/data/clubs.json`

#### 5. 展示 (Display)
- 前端读取 /api/clubs 或 clubs.json
- 在地图上显示社团

---

## 数据同步机制

### MongoDB ↔ clubs.json 双向同步

#### JSON → MongoDB (迁移)
**脚本**: `server/scripts/migrateClubs.js`

```bash
node server/scripts/migrateClubs.js
```

**流程**:
1. 读取 `public/data/clubs.json`
2. 遍历每个社团
3. 检查是否已存在 (name + school)
4. 存在 → 更新；不存在 → 创建
5. 字段映射:
   ```javascript
   {
     long_description → description
     short_description → shortDescription  // 独立字段
     img_name → logo
     [longitude, latitude] → coordinates
   }
   ```

#### MongoDB → JSON (同步)
**脚本**: `server/scripts/syncToJson.js`

```bash
node server/scripts/syncToJson.js
```

**流程**:
1. 读取所有 Club 文档
2. 转换为 clubs.json 格式
3. 备份现有文件 → `clubs.json.backup`
4. 写入新文件
5. 字段映射:
   ```javascript
   {
     description → long_description
     shortDescription → short_description  // 直接映射，不截断
     logo → img_name
     coordinates → [longitude, latitude]
   }
   ```

**触发时机**:
- 管理员批准提交后 (异步触发)
- 手动运行脚本
- 定时任务 (可选)

**⚠️ 重要变更**:
- **不再**使用 `description.substring(0, 50)` 作为 `short_description` 的降级
- `short_description` 直接读取 `shortDescription` 字段
- 如果 `shortDescription` 为空，输出空字符串 `""`

---

## 容灾与恢复

### 临时JSON (Pending Submissions)

**位置**: `data/pending_submissions/`

**目的**: 防止 MongoDB 不可用时数据丢失

**格式**:
```
文件名: {timestamp}_{randomId}.json
内容: 完整的提交数据 + 元数据
```

**恢复流程**:
1. 扫描 `data/pending_submissions/` 目录
2. 读取每个 JSON 文件
3. 检查 MongoDB 中是否已存在
4. 不存在 → 写入 Submission 集合
5. 成功后归档或删除 JSON 文件

**建议**:
- 创建定时恢复脚本 (每5分钟执行一次)
- 监控目录大小，设置告警

### 备份策略

**数据库备份**:
```bash
# 导出 MongoDB
mongodump --uri="mongodb://localhost:27017/gamedevmap" --out=/backup/mongo

# 导入 MongoDB
mongorestore --uri="mongodb://localhost:27017/gamedevmap" /backup/mongo/gamedevmap
```

**文件备份**:
```bash
# 备份上传文件
tar -czf /backup/submissions_$(date +%Y%m%d).tar.gz data/submissions/

# 备份临时JSON
tar -czf /backup/pending_$(date +%Y%m%d).tar.gz data/pending_submissions/

# 备份静态JSON
cp public/data/clubs.json /backup/clubs_$(date +%Y%m%d).json
```

---

## 性能优化

### 频率限制 (Rate Limiting)

**提交端点**: 5 次/小时/IP
```javascript
submissionLimiter: {
  windowMs: 60 * 60 * 1000,  // 1小时
  max: 5                      // 最多5次
}
```

**API端点**: 100 次/15分钟/IP
```javascript
apiLimiter: {
  windowMs: 15 * 60 * 1000,  // 15分钟
  max: 100                    // 最多100次
}
```

### 数据库索引

**Submission 集合**:
```javascript
{ status: 1, submittedAt: -1 }  // 列表查询
{ submitterEmail: 1 }            // 按邮箱查询
```

**Club 集合**:
```javascript
{ name: 1, school: 1 }           // 重复检测
{ coordinates: '2dsphere' }      // 地理位置查询
```

---

## 安全措施

### 输入验证
- **Joi 验证**: 所有提交数据经过严格验证
- **文件类型**: 仅允许 PNG/JPG/GIF/SVG
- **文件大小**: 最大 20MB
- **文件名清理**: 移除特殊字符，防止路径遍历

### 认证与授权
- **JWT Token**: 管理端点需要认证
- **Token 过期**: 24小时
- **密码加密**: bcrypt (10 rounds)

### 安全头
- **helmet**: CSP、XSS保护、隐藏X-Powered-By
- **CORS**: 配置允许的来源

### 日志记录
- **morgan**: HTTP请求日志
- **console.log**: 关键操作日志
- **错误日志**: 失败提交数据记录

---

## 附录

### 环境变量

**.env 文件**:
```env
# 服务器配置
PORT=3000
NODE_ENV=development

# MongoDB 配置
MONGODB_URI=mongodb://localhost:27017/gamedevmap

# JWT 配置
JWT_SECRET=your_super_secret_jwt_key_change_in_production
JWT_EXPIRES_IN=24h

# 可选: Sentry (错误追踪)
# SENTRY_DSN=https://...
```

### 启动命令

**开发环境**:
```bash
npm run dev
```

**生产环境**:
```bash
# PM2 启动
pm2 start ecosystem.config.js

# PM2 查看日志
pm2 logs gamedevmap-api

# PM2 重启
pm2 restart gamedevmap-api
```

### 数据迁移

**首次部署**:
```bash
# 1. 导入现有数据
node server/scripts/migrateClubs.js

# 2. 创建管理员账户
node server/scripts/seedAdmin.js
```

**同步数据**:
```bash
# MongoDB → clubs.json
node server/scripts/syncToJson.js
```

---

## 联系方式

如有问题，请联系开发团队或查看项目仓库。
