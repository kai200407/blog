---
title: "TURN: 中继服务器详解"
description: "1. [TURN 概述](#1-turn-概述)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 10
---

> 本文是 WebRTC 系列专栏的第十篇,将深入剖析 TURN 协议的工作原理、数据中继流程以及如何使用 coturn 搭建生产级 TURN 服务器。

---

## 目录

1. [TURN 概述](#1-turn-概述)
2. [TURN 协议详解](#2-turn-协议详解)
3. [TURN 数据中继流程](#3-turn-数据中继流程)
4. [TURN 认证机制](#4-turn-认证机制)
5. [coturn 安装与配置](#5-coturn-安装与配置)
6. [生产环境部署](#6-生产环境部署)
7. [总结](#7-总结)

---

## 1. TURN 概述

### 1.1 什么是 TURN

TURN (Traversal Using Relays around NAT) 是 STUN 的扩展协议,定义在 RFC 5766 中。当 P2P 直连失败时,TURN 服务器作为中继,转发双方的媒体数据。

### 1.2 为什么需要 TURN

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        TURN 的必要性                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   场景: 两端都是 Symmetric NAT,无法直接穿透                             │
│                                                                         │
│   用户 A                                              用户 B            │
│   (Symmetric NAT)                                    (Symmetric NAT)   │
│        │                                                  │             │
│        │  P2P 穿透失败                                    │             │
│        │  ─────────────────── X ──────────────────────────│             │
│        │                                                  │             │
│        │                                                  │             │
│        │              ┌─────────────────┐                 │             │
│        │              │   TURN 服务器   │                 │             │
│        │              │   (公网 IP)     │                 │             │
│        │              └────────┬────────┘                 │             │
│        │                       │                          │             │
│        │   中继连接            │            中继连接      │             │
│        │ ─────────────────────>│<───────────────────────  │             │
│        │                       │                          │             │
│        │   数据通过 TURN 中继  │                          │             │
│        │ <═══════════════════════════════════════════════>│             │
│        │                                                  │             │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.3 TURN vs STUN

| 特性 | STUN | TURN |
|------|------|------|
| 功能 | 发现公网地址 | 中继数据 |
| 数据流 | 不经过服务器 | 经过服务器 |
| 带宽消耗 | 极低 | 高 (所有数据) |
| 成本 | 低 | 高 |
| 适用场景 | NAT 可穿透 | NAT 不可穿透 |
| 延迟 | 低 | 较高 |

### 1.4 TURN 在 ICE 中的角色

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        ICE 候选优先级                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   优先级从高到低:                                                        │
│                                                                         │
│   1. host (本地地址)        ──>  最快,直接连接                          │
│   2. srflx (STUN 反射地址)  ──>  P2P 穿透                               │
│   3. prflx (对端反射地址)   ──>  动态发现                               │
│   4. relay (TURN 中继地址)  ──>  保底方案,确保连通                      │
│                                                                         │
│   TURN 作为最后的保障:                                                   │
│   - 当所有 P2P 尝试失败时使用                                           │
│   - 确保 100% 的连通性                                                  │
│   - 代价是更高的延迟和带宽成本                                          │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. TURN 协议详解

### 2.1 TURN 消息类型

TURN 扩展了 STUN 的消息类型:

| 方法 | 值 | 说明 |
|------|-----|------|
| Allocate | 0x003 | 请求分配中继地址 |
| Refresh | 0x004 | 刷新分配 |
| Send | 0x006 | 发送数据 (Indication) |
| Data | 0x007 | 接收数据 (Indication) |
| CreatePermission | 0x008 | 创建权限 |
| ChannelBind | 0x009 | 绑定通道 |

### 2.2 Allocate 请求

客户端首先发送 Allocate 请求,获取中继地址。

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Allocate 请求流程                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   客户端                                              TURN 服务器       │
│      │                                                     │            │
│      │  1. Allocate Request                                │            │
│      │  (无认证)                                           │            │
│      │ ──────────────────────────────────────────────────> │            │
│      │                                                     │            │
│      │  2. Allocate Error Response (401)                   │            │
│      │  REALM, NONCE                                       │            │
│      │ <────────────────────────────────────────────────── │            │
│      │                                                     │            │
│      │  3. Allocate Request                                │            │
│      │  USERNAME, REALM, NONCE, MESSAGE-INTEGRITY          │            │
│      │ ──────────────────────────────────────────────────> │            │
│      │                                                     │            │
│      │  4. Allocate Success Response                       │            │
│      │  XOR-RELAYED-ADDRESS: 198.51.100.1:49152           │            │
│      │  XOR-MAPPED-ADDRESS: 1.2.3.4:12345                 │            │
│      │  LIFETIME: 600                                      │            │
│      │ <────────────────────────────────────────────────── │            │
│      │                                                     │            │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.3 TURN 特有属性

| 属性 | 类型值 | 说明 |
|------|--------|------|
| CHANNEL-NUMBER | 0x000C | 通道号 |
| LIFETIME | 0x000D | 分配生存时间 |
| XOR-PEER-ADDRESS | 0x0012 | 对端地址 |
| DATA | 0x0013 | 数据 |
| XOR-RELAYED-ADDRESS | 0x0016 | 中继地址 |
| REQUESTED-TRANSPORT | 0x0019 | 请求的传输协议 |
| DONT-FRAGMENT | 0x001A | 不分片 |
| RESERVATION-TOKEN | 0x0022 | 预留令牌 |

### 2.4 分配 (Allocation)

分配是 TURN 的核心概念,表示服务器为客户端分配的中继资源。

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        TURN 分配结构                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   客户端                          TURN 服务器                           │
│   1.2.3.4:12345                  198.51.100.1                          │
│        │                              │                                 │
│        │                              │                                 │
│        │         分配 (Allocation)    │                                 │
│        │    ┌─────────────────────────┴─────────────────────────┐      │
│        │    │                                                   │      │
│        │    │  中继地址: 198.51.100.1:49152                     │      │
│        │    │  客户端地址: 1.2.3.4:12345                        │      │
│        │    │  生存时间: 600 秒                                 │      │
│        │    │  权限列表: []                                     │      │
│        │    │  通道绑定: []                                     │      │
│        │    │                                                   │      │
│        │    └───────────────────────────────────────────────────┘      │
│        │                              │                                 │
│        │                              │                                 │
│        │   对端可以向 198.51.100.1:49152 发送数据                       │
│        │   TURN 服务器会转发给客户端                                    │
│        │                              │                                 │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.5 权限 (Permission)

客户端必须为每个对端创建权限,才能接收来自该对端的数据。

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        CreatePermission 流程                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   客户端                                              TURN 服务器       │
│      │                                                     │            │
│      │  1. CreatePermission Request                        │            │
│      │  XOR-PEER-ADDRESS: 5.6.7.8 (对端 IP)                │            │
│      │ ──────────────────────────────────────────────────> │            │
│      │                                                     │            │
│      │  2. CreatePermission Success Response               │            │
│      │ <────────────────────────────────────────────────── │            │
│      │                                                     │            │
│      │  权限已创建:                                        │            │
│      │  - 允许接收来自 5.6.7.8 的数据                      │            │
│      │  - 权限有效期: 300 秒                               │            │
│      │  - 需要定期刷新                                     │            │
│      │                                                     │            │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.6 通道绑定 (Channel Binding)

通道绑定可以减少数据传输的开销。

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        ChannelBind 流程                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   客户端                                              TURN 服务器       │
│      │                                                     │            │
│      │  1. ChannelBind Request                             │            │
│      │  CHANNEL-NUMBER: 0x4001                             │            │
│      │  XOR-PEER-ADDRESS: 5.6.7.8:54321                    │            │
│      │ ──────────────────────────────────────────────────> │            │
│      │                                                     │            │
│      │  2. ChannelBind Success Response                    │            │
│      │ <────────────────────────────────────────────────── │            │
│      │                                                     │            │
│      │  通道已绑定:                                        │            │
│      │  - 通道号 0x4001 绑定到 5.6.7.8:54321               │            │
│      │  - 可以使用 ChannelData 消息发送数据                │            │
│      │  - 开销从 36 字节降低到 4 字节                      │            │
│      │                                                     │            │
└─────────────────────────────────────────────────────────────────────────┘
```

通道号范围: 0x4000 - 0x7FFF

---

## 3. TURN 数据中继流程

### 3.1 Send/Data Indication

使用 Send Indication 发送数据,使用 Data Indication 接收数据。

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Send/Data Indication 流程                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   客户端 A                    TURN 服务器                    客户端 B   │
│   1.2.3.4:12345              198.51.100.1                  5.6.7.8:54321│
│        │                          │                              │      │
│        │  1. Send Indication      │                              │      │
│        │  XOR-PEER-ADDRESS:       │                              │      │
│        │    5.6.7.8:54321         │                              │      │
│        │  DATA: "Hello"           │                              │      │
│        │ ────────────────────────>│                              │      │
│        │                          │                              │      │
│        │                          │  2. 转发数据                 │      │
│        │                          │  src: 198.51.100.1:49152     │      │
│        │                          │  dst: 5.6.7.8:54321          │      │
│        │                          │  data: "Hello"               │      │
│        │                          │ ────────────────────────────>│      │
│        │                          │                              │      │
│        │                          │  3. 对端响应                 │      │
│        │                          │  src: 5.6.7.8:54321          │      │
│        │                          │  dst: 198.51.100.1:49152     │      │
│        │                          │  data: "World"               │      │
│        │                          │<──────────────────────────── │      │
│        │                          │                              │      │
│        │  4. Data Indication      │                              │      │
│        │  XOR-PEER-ADDRESS:       │                              │      │
│        │    5.6.7.8:54321         │                              │      │
│        │  DATA: "World"           │                              │      │
│        │<──────────────────────── │                              │      │
│        │                          │                              │      │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 ChannelData 消息

使用通道绑定后,可以使用更高效的 ChannelData 消息格式。

```
ChannelData 消息格式:

 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|         Channel Number        |            Length             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                                                               |
|                       Application Data                        |
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

头部只有 4 字节,比 Send Indication 的 36+ 字节高效得多
```

### 3.3 完整的数据中继流程

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        完整的 TURN 数据中继流程                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   客户端 A                    TURN 服务器                    客户端 B   │
│        │                          │                              │      │
│   1. Allocate                     │                              │      │
│        │ ────────────────────────>│                              │      │
│        │<──────────────────────── │                              │      │
│        │  中继地址: 198.51.100.1:49152                           │      │
│        │                          │                              │      │
│   2. 通过信令交换中继地址         │                              │      │
│        │ ═══════════════════════════════════════════════════════>│      │
│        │                          │                              │      │
│   3. CreatePermission             │                              │      │
│        │ ────────────────────────>│                              │      │
│        │<──────────────────────── │                              │      │
│        │                          │                              │      │
│   4. ChannelBind (可选)           │                              │      │
│        │ ────────────────────────>│                              │      │
│        │<──────────────────────── │                              │      │
│        │                          │                              │      │
│   5. 媒体数据传输                 │                              │      │
│        │  ChannelData/Send        │                              │      │
│        │ ────────────────────────>│                              │      │
│        │                          │ ────────────────────────────>│      │
│        │                          │<──────────────────────────── │      │
│        │  ChannelData/Data        │                              │      │
│        │<──────────────────────── │                              │      │
│        │                          │                              │      │
│   6. 定期 Refresh                 │                              │      │
│        │ ────────────────────────>│                              │      │
│        │<──────────────────────── │                              │      │
│        │                          │                              │      │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 4. TURN 认证机制

### 4.1 长期凭据机制

TURN 使用长期凭据 (Long-Term Credential) 进行认证。

```
凭据计算:

key = MD5(username ":" realm ":" password)

MESSAGE-INTEGRITY = HMAC-SHA1(key, message)
```

### 4.2 认证流程

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        TURN 认证流程                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   客户端                                              TURN 服务器       │
│      │                                                     │            │
│      │  1. Allocate Request (无认证)                       │            │
│      │ ──────────────────────────────────────────────────> │            │
│      │                                                     │            │
│      │  2. Error Response (401 Unauthorized)               │            │
│      │  REALM: "example.com"                               │            │
│      │  NONCE: "abc123..."                                 │            │
│      │ <────────────────────────────────────────────────── │            │
│      │                                                     │            │
│      │  3. 计算凭据                                        │            │
│      │  key = MD5("user:example.com:pass")                 │            │
│      │                                                     │            │
│      │  4. Allocate Request (带认证)                       │            │
│      │  USERNAME: "user"                                   │            │
│      │  REALM: "example.com"                               │            │
│      │  NONCE: "abc123..."                                 │            │
│      │  MESSAGE-INTEGRITY: HMAC-SHA1(key, msg)             │            │
│      │ ──────────────────────────────────────────────────> │            │
│      │                                                     │            │
│      │  5. 服务器验证                                      │            │
│      │  - 检查 USERNAME 是否存在                           │            │
│      │  - 检查 NONCE 是否有效                              │            │
│      │  - 验证 MESSAGE-INTEGRITY                           │            │
│      │                                                     │            │
│      │  6. Allocate Success Response                       │            │
│      │ <────────────────────────────────────────────────── │            │
│      │                                                     │            │
└─────────────────────────────────────────────────────────────────────────┘
```

### 4.3 临时凭据 (TURN REST API)

生产环境通常使用临时凭据,通过 REST API 获取。

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        临时凭据流程                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   客户端                   应用服务器                    TURN 服务器    │
│      │                         │                              │         │
│      │  1. 请求 TURN 凭据      │                              │         │
│      │ ───────────────────────>│                              │         │
│      │                         │                              │         │
│      │                         │  2. 生成临时凭据             │         │
│      │                         │  username = timestamp:userid │         │
│      │                         │  password = HMAC(secret, username)     │
│      │                         │                              │         │
│      │  3. 返回凭据            │                              │         │
│      │  {                      │                              │         │
│      │    username: "...",     │                              │         │
│      │    password: "...",     │                              │         │
│      │    ttl: 86400,          │                              │         │
│      │    uris: ["turn:..."]   │                              │         │
│      │  }                      │                              │         │
│      │<─────────────────────── │                              │         │
│      │                         │                              │         │
│      │  4. 使用凭据连接 TURN   │                              │         │
│      │ ─────────────────────────────────────────────────────>│         │
│      │                         │                              │         │
│      │                         │  5. 验证凭据                 │         │
│      │                         │  - 检查时间戳是否过期        │         │
│      │                         │  - 验证 HMAC 签名            │         │
│      │                         │                              │         │
│      │  6. 连接成功            │                              │         │
│      │<───────────────────────────────────────────────────── │         │
│      │                         │                              │         │
└─────────────────────────────────────────────────────────────────────────┘
```

临时凭据生成示例 (Node.js):

```javascript
const crypto = require('crypto');

function generateTurnCredentials(userId, secret, ttl = 86400) {
    const timestamp = Math.floor(Date.now() / 1000) + ttl;
    const username = `${timestamp}:${userId}`;
    const password = crypto
        .createHmac('sha1', secret)
        .update(username)
        .digest('base64');
    
    return {
        username,
        password,
        ttl,
        uris: [
            'turn:turn.example.com:3478',
            'turn:turn.example.com:3478?transport=tcp',
            'turns:turn.example.com:5349'
        ]
    };
}

// 使用示例
const credentials = generateTurnCredentials('user123', 'my-secret-key');
console.log(credentials);
```

---

## 5. coturn 安装与配置

### 5.1 安装 coturn

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install coturn

# CentOS/RHEL
sudo yum install epel-release
sudo yum install coturn

# 从源码编译
git clone https://github.com/coturn/coturn.git
cd coturn
./configure --prefix=/usr/local
make
sudo make install
```

### 5.2 基础配置

配置文件位置: `/etc/turnserver.conf`

```ini
# ============ 网络配置 ============

# 监听端口
listening-port=3478
tls-listening-port=5349

# 监听 IP (0.0.0.0 表示所有接口)
listening-ip=0.0.0.0

# 外部 IP (公网 IP)
external-ip=YOUR_PUBLIC_IP

# 如果服务器在 NAT 后面
# external-ip=PUBLIC_IP/PRIVATE_IP

# 中继端口范围
min-port=49152
max-port=65535

# ============ 认证配置 ============

# 使用长期凭据机制
lt-cred-mech

# 域名
realm=example.com

# 静态用户 (测试用)
user=testuser:testpassword

# 或使用数据库
# userdb=/var/lib/turn/turndb

# ============ 安全配置 ============

# 指纹验证
fingerprint

# 禁止匿名访问
no-anonymous

# 禁止回环地址
no-loopback-peers

# 禁止多播
no-multicast-peers

# ============ TLS 配置 ============

# 证书文件
cert=/etc/letsencrypt/live/turn.example.com/fullchain.pem
pkey=/etc/letsencrypt/live/turn.example.com/privkey.pem

# 密码套件
cipher-list="ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256"

# ============ 日志配置 ============

# 日志文件
log-file=/var/log/turnserver.log

# 详细日志
verbose

# ============ 其他配置 ============

# 服务器名称
server-name=turn.example.com

# 进程用户
proc-user=turnserver
proc-group=turnserver

# PID 文件
pidfile=/var/run/turnserver.pid
```

### 5.3 启用服务

```bash
# 编辑 /etc/default/coturn
sudo sed -i 's/#TURNSERVER_ENABLED=1/TURNSERVER_ENABLED=1/' /etc/default/coturn

# 启动服务
sudo systemctl start coturn

# 设置开机启动
sudo systemctl enable coturn

# 查看状态
sudo systemctl status coturn

# 查看日志
sudo tail -f /var/log/turnserver.log
```

### 5.4 防火墙配置

```bash
# UFW (Ubuntu)
sudo ufw allow 3478/tcp
sudo ufw allow 3478/udp
sudo ufw allow 5349/tcp
sudo ufw allow 5349/udp
sudo ufw allow 49152:65535/udp

# firewalld (CentOS)
sudo firewall-cmd --permanent --add-port=3478/tcp
sudo firewall-cmd --permanent --add-port=3478/udp
sudo firewall-cmd --permanent --add-port=5349/tcp
sudo firewall-cmd --permanent --add-port=5349/udp
sudo firewall-cmd --permanent --add-port=49152-65535/udp
sudo firewall-cmd --reload

# iptables
sudo iptables -A INPUT -p tcp --dport 3478 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 3478 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 5349 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 5349 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 49152:65535 -j ACCEPT
```

### 5.5 测试 TURN 服务器

使用 turnutils_uclient 测试:

```bash
# 测试 STUN
turnutils_uclient -t -u testuser -w testpassword turn.example.com

# 测试 TURN
turnutils_uclient -T -u testuser -w testpassword turn.example.com
```

使用 WebRTC 测试:

```javascript
const pc = new RTCPeerConnection({
    iceServers: [{
        urls: [
            'turn:turn.example.com:3478',
            'turn:turn.example.com:3478?transport=tcp'
        ],
        username: 'testuser',
        credential: 'testpassword'
    }]
});

pc.createDataChannel('test');

pc.onicecandidate = (event) => {
    if (event.candidate) {
        console.log('Candidate:', event.candidate.candidate);
        if (event.candidate.candidate.includes('relay')) {
            console.log('TURN relay candidate found!');
        }
    }
};

pc.createOffer()
    .then(offer => pc.setLocalDescription(offer));
```

---

## 6. 生产环境部署

### 6.1 高可用架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        TURN 高可用架构                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                         ┌─────────────────┐                             │
│                         │   DNS 负载均衡   │                             │
│                         │ turn.example.com │                             │
│                         └────────┬────────┘                             │
│                                  │                                      │
│              ┌───────────────────┼───────────────────┐                  │
│              │                   │                   │                  │
│         ┌────┴────┐         ┌────┴────┐         ┌────┴────┐            │
│         │ TURN 1  │         │ TURN 2  │         │ TURN 3  │            │
│         │ 区域 A  │         │ 区域 B  │         │ 区域 C  │            │
│         └────┬────┘         └────┬────┘         └────┬────┘            │
│              │                   │                   │                  │
│              └───────────────────┼───────────────────┘                  │
│                                  │                                      │
│                         ┌────────┴────────┐                             │
│                         │   共享数据库     │                             │
│                         │   (Redis/MySQL)  │                             │
│                         └─────────────────┘                             │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 6.2 使用 Redis 存储凭据

配置 coturn 使用 Redis:

```ini
# /etc/turnserver.conf

# Redis 配置
redis-userdb="ip=127.0.0.1 dbname=0 password=redis_password connect_timeout=30"
redis-statsdb="ip=127.0.0.1 dbname=1 password=redis_password connect_timeout=30"
```

添加用户到 Redis:

```bash
# 计算密码哈希
# key = MD5(username:realm:password)
echo -n "user1:example.com:password123" | md5sum

# 添加到 Redis
redis-cli
> HSET turn/realm/example.com/user/user1/key "计算出的哈希值"
```

### 6.3 使用 MySQL/PostgreSQL

```ini
# /etc/turnserver.conf

# MySQL 配置
mysql-userdb="host=localhost dbname=coturn user=coturn password=db_password"

# PostgreSQL 配置
# psql-userdb="host=localhost dbname=coturn user=coturn password=db_password"
```

数据库表结构:

```sql
CREATE TABLE turnusers_lt (
    realm VARCHAR(127) DEFAULT 'example.com',
    name VARCHAR(512),
    hmackey CHAR(128),
    PRIMARY KEY (realm, name)
);

-- 添加用户
-- hmackey = HEX(MD5('username:realm:password'))
INSERT INTO turnusers_lt (realm, name, hmackey) 
VALUES ('example.com', 'user1', 'a1b2c3d4e5f6...');
```

### 6.4 监控与告警

```ini
# /etc/turnserver.conf

# 启用 CLI
cli-ip=127.0.0.1
cli-port=5766
cli-password=admin_password

# Prometheus 指标
prometheus
prometheus-port=9641
```

使用 CLI 监控:

```bash
# 连接 CLI
telnet 127.0.0.1 5766

# 查看会话
> ps
> pc

# 查看统计
> tc
```

Prometheus 指标:

```
# HELP turn_total_allocations Total number of allocations
# TYPE turn_total_allocations counter
turn_total_allocations 1234

# HELP turn_active_allocations Current number of active allocations
# TYPE turn_active_allocations gauge
turn_active_allocations 56
```

### 6.5 性能优化

```ini
# /etc/turnserver.conf

# 增加文件描述符限制
max-bps=0

# 禁用不需要的功能
no-cli
no-rest

# 优化内存使用
stale-nonce=600

# 多进程
# 根据 CPU 核心数设置
# 使用 systemd 或 supervisor 管理多个实例
```

系统优化:

```bash
# /etc/security/limits.conf
turnserver soft nofile 65535
turnserver hard nofile 65535

# /etc/sysctl.conf
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.udp_mem = 8388608 12582912 16777216
```

### 6.6 成本估算

TURN 服务器的主要成本是带宽:

```
假设:
- 1 路视频通话: 1.5 Mbps (上行 + 下行)
- 通过 TURN 中继: 带宽翻倍 (3 Mbps)
- 每天 1000 分钟通话

月带宽消耗:
3 Mbps * 60 秒 * 1000 分钟 * 30 天 = 5.4 TB

按云服务商带宽计费:
- AWS: 约 $0.09/GB = $486/月
- 阿里云: 约 $0.12/GB = $648/月
```

优化建议:
1. 优先使用 P2P,TURN 作为后备
2. 使用多个区域的 TURN 服务器
3. 监控 TURN 使用率,优化 ICE 配置

---

## 7. 总结

### 7.1 TURN 核心要点

| 要点 | 说明 |
|------|------|
| 作用 | P2P 失败时的中继方案 |
| 协议 | STUN 的扩展,RFC 5766 |
| 端口 | 3478 (UDP/TCP), 5349 (TLS) |
| 认证 | 长期凭据或临时凭据 |
| 开销 | 高带宽消耗 |
| 优先级 | ICE 中最低优先级 |

### 7.2 部署检查清单

```
[ ] 安装 coturn
[ ] 配置公网 IP
[ ] 配置 TLS 证书
[ ] 设置认证机制
[ ] 开放防火墙端口
[ ] 测试 STUN 功能
[ ] 测试 TURN 功能
[ ] 配置日志和监控
[ ] 设置自动启动
```

### 7.3 下一篇预告

在下一篇文章中,我们将完整梳理 WebRTC 的信令流程,从连接建立到关闭的全过程,包括:
- Offer/Answer 交换
- ICE Candidate Trickle
- DTLS 握手
- SRTP 建立
- 连接关闭

---

## 参考资料

1. [RFC 5766 - Traversal Using Relays around NAT (TURN)](https://datatracker.ietf.org/doc/html/rfc5766)
2. [RFC 8656 - TURN Extensions](https://datatracker.ietf.org/doc/html/rfc8656)
3. [coturn - Open Source TURN Server](https://github.com/coturn/coturn)
4. [WebRTC TURN - MDN](https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API/Protocols#turn)

---

> 作者: WebRTC 技术专栏  
> 系列: 信令与会话管理 (5/6)  
> 上一篇: [STUN: 外网地址发现](./09-stun-protocol.md)  
> 下一篇: [完整的 WebRTC 信令流程图](./11-complete-signaling-flow.md)
