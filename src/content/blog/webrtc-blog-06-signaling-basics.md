---
title: "信令是什么?为什么 WebRTC 需要信令?"
description: "1. [什么是信令](#1-什么是信令)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 6
---

> 本文是 WebRTC 系列专栏的第六篇,也是第二部分"信令与会话管理"的开篇。我们将深入探讨信令的概念、作用以及如何设计自己的信令服务器。

---

## 目录

1. [什么是信令](#1-什么是信令)
2. [信令不是 WebRTC 标准的一部分](#2-信令不是-webrtc-标准的一部分)
3. [信令传输的内容](#3-信令传输的内容)
4. [信令传输方式](#4-信令传输方式)
5. [信令服务器设计](#5-信令服务器设计)
6. [信令服务器实现示例](#6-信令服务器实现示例)
7. [总结](#7-总结)

---

## 1. 什么是信令

### 1.1 信令的定义

信令(Signaling)是指在建立实时通信会话之前,通信双方交换控制信息的过程。这些控制信息包括:

- 会话的发起和终止
- 媒体能力的协商(编解码器、分辨率等)
- 网络连接信息的交换(IP地址、端口等)
- 会话状态的同步

在 WebRTC 中,信令是建立点对点连接的前置步骤。没有信令,两个浏览器无法知道对方的存在,更无法建立连接。

### 1.2 信令在通信中的位置

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        WebRTC 通信建立过程                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   阶段一: 信令阶段                                                       │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │                                                                 │  │
│   │   用户 A                 信令服务器                 用户 B       │  │
│   │     │                       │                       │          │  │
│   │     │  1. 发送 Offer ────>  │                       │          │  │
│   │     │                       │  2. 转发 Offer ────>  │          │  │
│   │     │                       │                       │          │  │
│   │     │                       │  <──── 3. 发送 Answer │          │  │
│   │     │  <──── 4. 转发 Answer │                       │          │  │
│   │     │                       │                       │          │  │
│   │     │  <════ 5. ICE 候选交换 ════>                  │          │  │
│   │     │                       │                       │          │  │
│   └─────────────────────────────────────────────────────────────────┘  │
│                                    │                                    │
│                                    ▼                                    │
│   阶段二: 媒体传输阶段                                                   │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │                                                                 │  │
│   │   用户 A  <═══════════ P2P 连接 ═══════════>  用户 B            │  │
│   │           (音视频数据直接传输,不经过服务器)                       │  │
│   │                                                                 │  │
│   └─────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.3 信令与媒体传输的区别

| 特性 | 信令 | 媒体传输 |
|------|------|---------|
| 传输内容 | 控制信息(SDP、ICE候选) | 音视频数据 |
| 传输方式 | 通过服务器中转 | 点对点直连(P2P) |
| 协议 | 自定义(WebSocket/HTTP等) | RTP/SRTP |
| 数据量 | 小(几KB) | 大(持续流) |
| 时效性 | 建立连接时使用 | 连接建立后持续使用 |

---

## 2. 信令不是 WebRTC 标准的一部分

### 2.1 为什么 WebRTC 不定义信令协议

WebRTC 标准(W3C 和 IETF)故意不定义信令协议,原因如下:

**灵活性考虑**

不同的应用场景有不同的需求:
- 视频会议可能需要房间管理、用户列表等功能
- 一对一通话可能只需要简单的呼叫/应答机制
- 直播场景可能需要与现有的直播系统集成

**兼容性考虑**

开发者可以:
- 复用现有的信令基础设施(如 SIP、XMPP)
- 与现有的业务系统集成
- 使用最适合自己技术栈的传输协议

**安全性考虑**

信令涉及用户身份验证、房间权限等业务逻辑,这些应该由应用层自行设计。

### 2.2 WebRTC 标准定义了什么

WebRTC 标准定义的是:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        WebRTC 标准范围                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   W3C 定义 (JavaScript API):                                            │
│   ├── RTCPeerConnection                                                 │
│   ├── MediaStream / MediaStreamTrack                                    │
│   ├── RTCDataChannel                                                    │
│   └── getUserMedia / getDisplayMedia                                    │
│                                                                         │
│   IETF 定义 (底层协议):                                                  │
│   ├── ICE (RFC 8445) - 连接建立                                         │
│   ├── STUN (RFC 5389) - 地址发现                                        │
│   ├── TURN (RFC 5766) - 中继传输                                        │
│   ├── DTLS (RFC 6347) - 密钥交换                                        │
│   ├── SRTP (RFC 3711) - 媒体加密                                        │
│   └── SDP (RFC 4566) - 会话描述                                         │
│                                                                         │
│   不在标准范围内:                                                        │
│   └── 信令协议 (由开发者自行设计)                                        │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.3 开发者需要自行实现的部分

作为开发者,你需要自行实现:

1. **信令服务器**: 负责转发信令消息
2. **信令协议**: 定义消息格式和交互流程
3. **用户管理**: 用户注册、登录、在线状态
4. **房间管理**: 房间创建、加入、离开
5. **权限控制**: 谁可以呼叫谁、谁可以加入房间

---

## 3. 信令传输的内容

### 3.1 SDP (Session Description Protocol)

SDP 是信令传输的核心内容,用于描述会话的媒体能力。

#### SDP 的作用

```
用户 A 的 SDP (Offer):                    用户 B 的 SDP (Answer):
┌─────────────────────────┐              ┌─────────────────────────┐
│ 我支持的视频编码:        │              │ 我支持的视频编码:        │
│ - VP8                   │              │ - VP8                   │
│ - VP9                   │   协商结果    │ - H.264                 │
│ - H.264                 │ ──────────>  │                         │
│                         │              │ 共同支持: VP8, H.264    │
│ 我支持的音频编码:        │              │                         │
│ - Opus                  │              │ 我支持的音频编码:        │
│ - G.711                 │              │ - Opus                  │
│                         │              │                         │
│ 我的网络信息:            │              │ 我的网络信息:            │
│ - IP: x.x.x.x           │              │ - IP: y.y.y.y           │
│ - Port: 12345           │              │ - Port: 54321           │
└─────────────────────────┘              └─────────────────────────┘
```

#### SDP 示例

```
v=0
o=- 4611731400430051336 2 IN IP4 127.0.0.1
s=-
t=0 0
a=group:BUNDLE 0 1
a=extmap-allow-mixed
a=msid-semantic: WMS stream_id

m=audio 9 UDP/TLS/RTP/SAVPF 111 103 104 9 0 8 106 105 13 110 112 113 126
c=IN IP4 0.0.0.0
a=rtcp:9 IN IP4 0.0.0.0
a=ice-ufrag:abcd
a=ice-pwd:efghijklmnopqrstuvwxyz
a=ice-options:trickle
a=fingerprint:sha-256 AA:BB:CC:DD:EE:FF:...
a=setup:actpass
a=mid:0
a=sendrecv
a=rtcp-mux
a=rtpmap:111 opus/48000/2
a=fmtp:111 minptime=10;useinbandfec=1

m=video 9 UDP/TLS/RTP/SAVPF 96 97 98 99 100 101 102
c=IN IP4 0.0.0.0
a=rtcp:9 IN IP4 0.0.0.0
a=ice-ufrag:abcd
a=ice-pwd:efghijklmnopqrstuvwxyz
a=fingerprint:sha-256 AA:BB:CC:DD:EE:FF:...
a=setup:actpass
a=mid:1
a=sendrecv
a=rtcp-mux
a=rtpmap:96 VP8/90000
a=rtpmap:98 VP9/90000
a=rtpmap:100 H264/90000
```

### 3.2 ICE Candidate

ICE Candidate 描述了可用于建立连接的网络路径。

#### ICE Candidate 的类型

| 类型 | 说明 | 示例 |
|------|------|------|
| host | 本地网络接口地址 | 192.168.1.100:54321 |
| srflx | 通过 STUN 发现的公网地址 | 203.0.113.1:12345 |
| prflx | 连通性检查中发现的地址 | 动态发现 |
| relay | TURN 服务器分配的中继地址 | 198.51.100.1:3478 |

#### ICE Candidate 示例

```javascript
// ICE Candidate 对象
{
    candidate: "candidate:842163049 1 udp 1677729535 192.168.1.100 54321 typ srflx raddr 10.0.0.1 rport 12345 generation 0 ufrag abcd network-cost 999",
    sdpMid: "0",
    sdpMLineIndex: 0,
    usernameFragment: "abcd"
}
```

#### Candidate 字符串解析

```
candidate:842163049 1 udp 1677729535 192.168.1.100 54321 typ srflx raddr 10.0.0.1 rport 12345
    │         │    │  │       │           │         │    │      │        │         │
    │         │    │  │       │           │         │    │      │        │         └─ 相关端口
    │         │    │  │       │           │         │    │      │        └─ 相关地址
    │         │    │  │       │           │         │    │      └─ 候选类型
    │         │    │  │       │           │         │    └─ 类型标识
    │         │    │  │       │           │         └─ 端口
    │         │    │  │       │           └─ IP 地址
    │         │    │  │       └─ 优先级
    │         │    │  └─ 协议
    │         │    └─ 组件 ID (1=RTP, 2=RTCP)
    │         └─ 基础标识
    └─ 候选标识
```

### 3.3 信令消息类型

一个完整的信令系统通常需要处理以下消息类型:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        信令消息类型                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   会话控制消息:                                                          │
│   ├── offer      - 发起方的会话描述                                      │
│   ├── answer     - 接收方的会话描述                                      │
│   ├── candidate  - ICE 候选                                             │
│   ├── hangup     - 挂断通话                                             │
│   └── reject     - 拒绝通话                                             │
│                                                                         │
│   房间管理消息:                                                          │
│   ├── join       - 加入房间                                             │
│   ├── leave      - 离开房间                                             │
│   ├── user-list  - 房间用户列表                                         │
│   └── user-state - 用户状态变化                                         │
│                                                                         │
│   系统消息:                                                              │
│   ├── ping/pong  - 心跳检测                                             │
│   ├── error      - 错误通知                                             │
│   └── notify     - 系统通知                                             │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 4. 信令传输方式

### 4.1 WebSocket

WebSocket 是最常用的信令传输方式,提供全双工通信能力。

#### 优点

- 实时性好,延迟低
- 双向通信,服务器可主动推送
- 连接持久,无需重复握手
- 协议开销小

#### 缺点

- 需要维护长连接
- 连接断开需要重连机制
- 部分网络环境可能不支持

#### 实现示例

```javascript
// 客户端
const socket = new WebSocket('wss://signaling.example.com');

socket.onopen = () => {
    console.log('信令连接已建立');
};

socket.onmessage = (event) => {
    const message = JSON.parse(event.data);
    handleSignalingMessage(message);
};

socket.send(JSON.stringify({
    type: 'offer',
    sdp: offer.sdp,
    target: 'user-123'
}));
```

### 4.2 Socket.IO

Socket.IO 是基于 WebSocket 的封装库,提供了更多高级功能。

#### 优点

- 自动重连机制
- 房间和命名空间支持
- 降级支持(WebSocket 不可用时使用轮询)
- 事件驱动的 API

#### 缺点

- 额外的协议开销
- 需要客户端和服务端都使用 Socket.IO

#### 实现示例

```javascript
// 客户端
const socket = io('https://signaling.example.com');

socket.on('connect', () => {
    socket.emit('join-room', { roomId: 'room-123' });
});

socket.on('offer', (data) => {
    handleOffer(data);
});

socket.emit('answer', {
    sdp: answer.sdp,
    target: 'user-123'
});
```

### 4.3 HTTP 轮询

使用 HTTP 请求定期查询服务器获取新消息。

#### 优点

- 实现简单
- 兼容性最好
- 无需长连接

#### 缺点

- 延迟高
- 服务器压力大
- 效率低

#### 实现示例

```javascript
// 客户端
async function pollMessages() {
    while (true) {
        const response = await fetch('/api/messages');
        const messages = await response.json();
        
        for (const message of messages) {
            handleSignalingMessage(message);
        }
        
        await new Promise(resolve => setTimeout(resolve, 1000));
    }
}

async function sendMessage(message) {
    await fetch('/api/messages', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(message)
    });
}
```

### 4.4 MQTT

MQTT 是一种轻量级的发布/订阅消息协议,适合 IoT 场景。

#### 优点

- 协议轻量,适合低带宽环境
- 发布/订阅模式,易于扩展
- QoS 支持,消息可靠性保证
- 适合 IoT 设备

#### 缺点

- 需要 MQTT Broker
- 学习成本较高

#### 实现示例

```javascript
// 客户端
const client = mqtt.connect('wss://mqtt.example.com');

client.on('connect', () => {
    client.subscribe('room/123/signaling');
});

client.on('message', (topic, message) => {
    const data = JSON.parse(message.toString());
    handleSignalingMessage(data);
});

client.publish('room/123/signaling', JSON.stringify({
    type: 'offer',
    sdp: offer.sdp,
    from: 'user-456'
}));
```

### 4.5 传输方式对比

| 特性 | WebSocket | Socket.IO | HTTP 轮询 | MQTT |
|------|-----------|-----------|-----------|------|
| 实时性 | 高 | 高 | 低 | 高 |
| 实现复杂度 | 中 | 低 | 低 | 中 |
| 兼容性 | 好 | 很好 | 最好 | 好 |
| 服务器压力 | 低 | 低 | 高 | 低 |
| 适用场景 | 通用 | 快速开发 | 简单场景 | IoT |

---

## 5. 信令服务器设计

### 5.1 架构设计

#### 单服务器架构

适用于小规模应用:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        单服务器架构                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                         ┌─────────────────┐                             │
│                         │   信令服务器     │                             │
│                         │                 │                             │
│                         │  ┌───────────┐  │                             │
│                         │  │ 连接管理  │  │                             │
│                         │  ├───────────┤  │                             │
│                         │  │ 房间管理  │  │                             │
│                         │  ├───────────┤  │                             │
│                         │  │ 消息路由  │  │                             │
│                         │  └───────────┘  │                             │
│                         │                 │                             │
│                         └────────┬────────┘                             │
│                                  │                                      │
│              ┌───────────────────┼───────────────────┐                  │
│              │                   │                   │                  │
│         ┌────┴────┐         ┌────┴────┐         ┌────┴────┐            │
│         │ 客户端 A │         │ 客户端 B │         │ 客户端 C │            │
│         └─────────┘         └─────────┘         └─────────┘            │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### 分布式架构

适用于大规模应用:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        分布式架构                                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                         ┌─────────────────┐                             │
│                         │   负载均衡器     │                             │
│                         └────────┬────────┘                             │
│                                  │                                      │
│              ┌───────────────────┼───────────────────┐                  │
│              │                   │                   │                  │
│         ┌────┴────┐         ┌────┴────┐         ┌────┴────┐            │
│         │ 信令节点1│         │ 信令节点2│         │ 信令节点3│            │
│         └────┬────┘         └────┬────┘         └────┬────┘            │
│              │                   │                   │                  │
│              └───────────────────┼───────────────────┘                  │
│                                  │                                      │
│                         ┌────────┴────────┐                             │
│                         │   消息队列       │                             │
│                         │  (Redis Pub/Sub) │                             │
│                         └─────────────────┘                             │
│                                                                         │
│   说明: 不同节点上的客户端通过消息队列实现跨节点通信                       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.2 核心功能模块

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        信令服务器核心模块                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   1. 连接管理模块                                                        │
│      ├── 连接建立与断开处理                                              │
│      ├── 心跳检测与超时处理                                              │
│      └── 连接状态维护                                                    │
│                                                                         │
│   2. 用户管理模块                                                        │
│      ├── 用户身份验证                                                    │
│      ├── 用户在线状态                                                    │
│      └── 用户信息存储                                                    │
│                                                                         │
│   3. 房间管理模块                                                        │
│      ├── 房间创建与销毁                                                  │
│      ├── 用户加入与离开                                                  │
│      ├── 房间成员列表                                                    │
│      └── 房间权限控制                                                    │
│                                                                         │
│   4. 消息路由模块                                                        │
│      ├── 点对点消息转发                                                  │
│      ├── 房间广播                                                        │
│      └── 消息过滤与验证                                                  │
│                                                                         │
│   5. 安全模块                                                            │
│      ├── 身份认证 (JWT/Token)                                           │
│      ├── 消息加密                                                        │
│      └── 防攻击保护                                                      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.3 消息协议设计

#### 消息格式

```javascript
// 基础消息结构
{
    "type": "offer",           // 消息类型
    "from": "user-123",        // 发送者 ID
    "to": "user-456",          // 接收者 ID (可选)
    "room": "room-789",        // 房间 ID (可选)
    "data": {                  // 消息数据
        "sdp": "v=0\r\n..."
    },
    "timestamp": 1699123456789 // 时间戳
}
```

#### 消息类型定义

```javascript
// 会话控制消息
const MessageTypes = {
    // Offer/Answer
    OFFER: 'offer',
    ANSWER: 'answer',
    
    // ICE
    CANDIDATE: 'candidate',
    
    // 通话控制
    CALL: 'call',
    ACCEPT: 'accept',
    REJECT: 'reject',
    HANGUP: 'hangup',
    
    // 房间管理
    JOIN: 'join',
    LEAVE: 'leave',
    USER_JOINED: 'user-joined',
    USER_LEFT: 'user-left',
    
    // 系统消息
    ERROR: 'error',
    PING: 'ping',
    PONG: 'pong'
};
```

---

## 6. 信令服务器实现示例

### 6.1 基于 WebSocket 的信令服务器

#### 服务端代码 (Node.js)

```javascript
const WebSocket = require('ws');
const http = require('http');

const server = http.createServer();
const wss = new WebSocket.Server({ server });

// 存储连接和房间信息
const clients = new Map();  // clientId -> WebSocket
const rooms = new Map();    // roomId -> Set<clientId>

// 生成唯一 ID
function generateId() {
    return Math.random().toString(36).substring(2, 15);
}

// 发送消息给指定客户端
function sendTo(clientId, message) {
    const client = clients.get(clientId);
    if (client && client.readyState === WebSocket.OPEN) {
        client.send(JSON.stringify(message));
    }
}

// 广播消息给房间内所有成员(排除发送者)
function broadcastToRoom(roomId, message, excludeId) {
    const room = rooms.get(roomId);
    if (room) {
        room.forEach(clientId => {
            if (clientId !== excludeId) {
                sendTo(clientId, message);
            }
        });
    }
}

// 处理连接
wss.on('connection', (ws) => {
    const clientId = generateId();
    clients.set(clientId, ws);
    
    console.log(`客户端连接: ${clientId}`);
    
    // 发送欢迎消息
    sendTo(clientId, {
        type: 'welcome',
        clientId: clientId
    });
    
    // 处理消息
    ws.on('message', (data) => {
        try {
            const message = JSON.parse(data);
            handleMessage(clientId, message);
        } catch (error) {
            console.error('消息解析错误:', error);
        }
    });
    
    // 处理断开
    ws.on('close', () => {
        handleDisconnect(clientId);
    });
    
    // 处理错误
    ws.on('error', (error) => {
        console.error(`客户端 ${clientId} 错误:`, error);
    });
});

// 处理消息
function handleMessage(clientId, message) {
    console.log(`收到消息 [${clientId}]:`, message.type);
    
    switch (message.type) {
        case 'join':
            handleJoin(clientId, message);
            break;
            
        case 'leave':
            handleLeave(clientId, message);
            break;
            
        case 'offer':
        case 'answer':
        case 'candidate':
            handleSignaling(clientId, message);
            break;
            
        case 'hangup':
            handleHangup(clientId, message);
            break;
            
        case 'ping':
            sendTo(clientId, { type: 'pong' });
            break;
            
        default:
            console.log('未知消息类型:', message.type);
    }
}

// 处理加入房间
function handleJoin(clientId, message) {
    const { roomId } = message;
    
    if (!rooms.has(roomId)) {
        rooms.set(roomId, new Set());
    }
    
    const room = rooms.get(roomId);
    
    // 获取房间内现有成员
    const existingMembers = Array.from(room);
    
    // 加入房间
    room.add(clientId);
    
    // 通知新成员房间内的其他用户
    sendTo(clientId, {
        type: 'room-joined',
        roomId: roomId,
        members: existingMembers
    });
    
    // 通知房间内其他成员有新用户加入
    broadcastToRoom(roomId, {
        type: 'user-joined',
        clientId: clientId
    }, clientId);
    
    console.log(`客户端 ${clientId} 加入房间 ${roomId}`);
}

// 处理离开房间
function handleLeave(clientId, message) {
    const { roomId } = message;
    
    const room = rooms.get(roomId);
    if (room) {
        room.delete(clientId);
        
        // 通知房间内其他成员
        broadcastToRoom(roomId, {
            type: 'user-left',
            clientId: clientId
        }, clientId);
        
        // 如果房间为空,删除房间
        if (room.size === 0) {
            rooms.delete(roomId);
        }
    }
    
    console.log(`客户端 ${clientId} 离开房间 ${roomId}`);
}

// 处理信令消息(offer/answer/candidate)
function handleSignaling(clientId, message) {
    const { to, roomId } = message;
    
    // 添加发送者信息
    message.from = clientId;
    
    if (to) {
        // 点对点消息
        sendTo(to, message);
    } else if (roomId) {
        // 房间广播
        broadcastToRoom(roomId, message, clientId);
    }
}

// 处理挂断
function handleHangup(clientId, message) {
    const { to, roomId } = message;
    
    message.from = clientId;
    
    if (to) {
        sendTo(to, message);
    } else if (roomId) {
        broadcastToRoom(roomId, message, clientId);
    }
}

// 处理断开连接
function handleDisconnect(clientId) {
    console.log(`客户端断开: ${clientId}`);
    
    // 从所有房间中移除
    rooms.forEach((members, roomId) => {
        if (members.has(clientId)) {
            members.delete(clientId);
            
            // 通知房间内其他成员
            broadcastToRoom(roomId, {
                type: 'user-left',
                clientId: clientId
            }, clientId);
            
            // 如果房间为空,删除房间
            if (members.size === 0) {
                rooms.delete(roomId);
            }
        }
    });
    
    // 删除客户端
    clients.delete(clientId);
}

// 启动服务器
const PORT = process.env.PORT || 8080;
server.listen(PORT, () => {
    console.log(`信令服务器运行在端口 ${PORT}`);
});
```

#### 客户端代码

```javascript
class SignalingClient {
    constructor(serverUrl) {
        this.serverUrl = serverUrl;
        this.socket = null;
        this.clientId = null;
        this.handlers = new Map();
    }
    
    // 连接服务器
    connect() {
        return new Promise((resolve, reject) => {
            this.socket = new WebSocket(this.serverUrl);
            
            this.socket.onopen = () => {
                console.log('信令连接已建立');
            };
            
            this.socket.onmessage = (event) => {
                const message = JSON.parse(event.data);
                this.handleMessage(message);
                
                if (message.type === 'welcome') {
                    this.clientId = message.clientId;
                    resolve(this.clientId);
                }
            };
            
            this.socket.onerror = (error) => {
                reject(error);
            };
            
            this.socket.onclose = () => {
                console.log('信令连接已断开');
                this.emit('disconnected');
            };
        });
    }
    
    // 发送消息
    send(message) {
        if (this.socket && this.socket.readyState === WebSocket.OPEN) {
            this.socket.send(JSON.stringify(message));
        }
    }
    
    // 加入房间
    joinRoom(roomId) {
        this.send({ type: 'join', roomId });
    }
    
    // 离开房间
    leaveRoom(roomId) {
        this.send({ type: 'leave', roomId });
    }
    
    // 发送 Offer
    sendOffer(sdp, to) {
        this.send({ type: 'offer', sdp, to });
    }
    
    // 发送 Answer
    sendAnswer(sdp, to) {
        this.send({ type: 'answer', sdp, to });
    }
    
    // 发送 ICE Candidate
    sendCandidate(candidate, to) {
        this.send({ type: 'candidate', candidate, to });
    }
    
    // 挂断
    hangup(to) {
        this.send({ type: 'hangup', to });
    }
    
    // 注册事件处理器
    on(type, handler) {
        if (!this.handlers.has(type)) {
            this.handlers.set(type, []);
        }
        this.handlers.get(type).push(handler);
    }
    
    // 触发事件
    emit(type, data) {
        const handlers = this.handlers.get(type);
        if (handlers) {
            handlers.forEach(handler => handler(data));
        }
    }
    
    // 处理消息
    handleMessage(message) {
        this.emit(message.type, message);
    }
    
    // 断开连接
    disconnect() {
        if (this.socket) {
            this.socket.close();
        }
    }
}

// 使用示例
const signaling = new SignalingClient('ws://localhost:8080');

signaling.on('offer', async (message) => {
    console.log('收到 Offer:', message);
    // 处理 Offer
});

signaling.on('answer', async (message) => {
    console.log('收到 Answer:', message);
    // 处理 Answer
});

signaling.on('candidate', async (message) => {
    console.log('收到 Candidate:', message);
    // 处理 ICE Candidate
});

signaling.on('user-joined', (message) => {
    console.log('用户加入:', message.clientId);
});

signaling.on('user-left', (message) => {
    console.log('用户离开:', message.clientId);
});

// 连接并加入房间
signaling.connect().then((clientId) => {
    console.log('我的 ID:', clientId);
    signaling.joinRoom('room-123');
});
```

---

## 7. 总结

### 7.1 核心要点

| 要点 | 说明 |
|------|------|
| 信令定义 | 建立通信前交换控制信息的过程 |
| 不在标准内 | WebRTC 故意不定义信令协议,给开发者灵活性 |
| 传输内容 | SDP(会话描述)和 ICE Candidate(网络候选) |
| 传输方式 | WebSocket、Socket.IO、HTTP、MQTT 等 |
| 服务器职责 | 消息转发、房间管理、用户管理 |

### 7.2 信令流程回顾

```
1. 用户 A 创建 Offer (createOffer)
2. 用户 A 设置本地描述 (setLocalDescription)
3. 用户 A 通过信令服务器发送 Offer 给用户 B
4. 用户 B 收到 Offer,设置远端描述 (setRemoteDescription)
5. 用户 B 创建 Answer (createAnswer)
6. 用户 B 设置本地描述 (setLocalDescription)
7. 用户 B 通过信令服务器发送 Answer 给用户 A
8. 用户 A 收到 Answer,设置远端描述 (setRemoteDescription)
9. 双方交换 ICE Candidate
10. P2P 连接建立
```

### 7.3 下一篇预告

在下一篇文章中,我们将深入探讨 SDP(Session Description Protocol),包括:
- SDP 的完整结构
- Offer/Answer 模型
- 关键参数解读
- SDP 的修改与优化

---

## 参考资料

1. [RFC 4566 - SDP: Session Description Protocol](https://datatracker.ietf.org/doc/html/rfc4566)
2. [WebRTC Signaling - MDN](https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API/Signaling_and_video_calling)
3. [WebRTC for the Curious - Signaling](https://webrtcforthecurious.com/docs/02-signaling/)
4. [Socket.IO Documentation](https://socket.io/docs/v4/)

---

> 作者: WebRTC 技术专栏  
> 系列: 信令与会话管理 (1/6)  
> 上一篇: [WebRTC 的 API 全景图](../part1-basics/05-webrtc-api-overview.md)  
> 下一篇: [深度理解 SDP](./07-sdp-deep-dive.md)
