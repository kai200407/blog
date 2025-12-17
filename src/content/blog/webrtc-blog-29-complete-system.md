---
title: "构建一个完整的 WebRTC 通信系统 (架构篇)"
description: "1. [系统架构概述](#1-系统架构概述)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 29
---

> 本文是 WebRTC 系列专栏的第二十九篇,也是本系列的收官之作。我们将从架构角度,系统性地讲解如何构建一个端到端的 WebRTC 通信系统。

---

## 目录

1. [系统架构概述](#1-系统架构概述)
2. [信令服务器](#2-信令服务器)
3. [TURN/STUN 服务](#3-turnstun-服务)
4. [SFU 媒体服务器](#4-sfu-媒体服务器)
5. [Web 客户端](#5-web-客户端)
6. [移动端客户端](#6-移动端客户端)
7. [业务逻辑层](#7-业务逻辑层)
8. [部署与运维](#8-部署与运维)
9. [总结](#9-总结)

---

## 1. 系统架构概述

### 1.1 整体架构

```
完整 WebRTC 系统架构:

                    +------------------+
                    |   负载均衡器      |
                    +--------+---------+
                             |
        +--------------------+--------------------+
        |                    |                    |
+-------v-------+    +-------v-------+    +-------v-------+
|  信令服务器    |    |  API 服务器    |    |  Web 服务器   |
|  (WebSocket)  |    |  (REST)       |    |  (静态资源)   |
+-------+-------+    +-------+-------+    +---------------+
        |                    |
        |            +-------v-------+
        |            |   数据库      |
        |            |  (用户/房间)  |
        |            +---------------+
        |
+-------v-------+
|   消息队列    |
|  (Redis)     |
+-------+-------+
        |
+-------v-------+    +---------------+
|  SFU 集群     |    | TURN/STUN    |
|  (mediasoup) |<-->|  (coturn)    |
+---------------+    +---------------+
        ^
        |
+-------+-------+
|    客户端     |
| Web/iOS/Android|
+---------------+
```

### 1.2 组件职责

| 组件 | 职责 | 技术选型 |
|------|------|---------|
| 信令服务器 | 信令交换、房间管理 | Node.js + WebSocket |
| API 服务器 | 用户认证、业务逻辑 | Node.js/Go |
| SFU | 媒体转发 | mediasoup/Janus |
| TURN/STUN | NAT 穿透 | coturn |
| 数据库 | 持久化存储 | PostgreSQL/MongoDB |
| 消息队列 | 服务间通信 | Redis |

### 1.3 数据流

```
数据流示意:

1. 用户认证流
   客户端 -> API 服务器 -> 数据库 -> JWT Token

2. 信令流
   客户端 -> 信令服务器 -> Redis -> 其他信令服务器 -> 客户端

3. 媒体流
   客户端 -> TURN(可选) -> SFU -> TURN(可选) -> 客户端

4. 控制流
   信令服务器 -> SFU (创建房间/传输)
```

---

## 2. 信令服务器

### 2.1 架构设计

```javascript
// signaling-server/src/index.js
const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const Redis = require('ioredis');
const jwt = require('jsonwebtoken');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// Redis 用于集群通信
const redis = new Redis(process.env.REDIS_URL);
const redisSub = new Redis(process.env.REDIS_URL);

// 本地连接管理
const connections = new Map();

// 订阅 Redis 消息
redisSub.subscribe('signaling');
redisSub.on('message', (channel, message) => {
    const data = JSON.parse(message);
    handleRedisMessage(data);
});

// WebSocket 连接处理
wss.on('connection', async (ws, req) => {
    // 验证 JWT
    const token = req.url.split('token=')[1];
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        ws.userId = decoded.userId;
        connections.set(ws.userId, ws);
        
        ws.on('message', (data) => handleMessage(ws, data));
        ws.on('close', () => handleDisconnect(ws));
    } catch (error) {
        ws.close(4001, 'Unauthorized');
    }
});

// 消息处理
async function handleMessage(ws, data) {
    const message = JSON.parse(data);
    
    switch (message.type) {
        case 'join-room':
            await handleJoinRoom(ws, message);
            break;
        case 'leave-room':
            await handleLeaveRoom(ws, message);
            break;
        case 'offer':
        case 'answer':
        case 'candidate':
            await forwardToUser(message.targetId, message);
            break;
    }
}

// 跨服务器转发
async function forwardToUser(userId, message) {
    const localWs = connections.get(userId);
    
    if (localWs) {
        localWs.send(JSON.stringify(message));
    } else {
        // 通过 Redis 转发到其他服务器
        redis.publish('signaling', JSON.stringify({
            targetUserId: userId,
            message
        }));
    }
}

server.listen(8080);
```

### 2.2 房间管理

```javascript
// signaling-server/src/RoomManager.js
class RoomManager {
    constructor(redis) {
        this.redis = redis;
    }
    
    async createRoom(roomId, options = {}) {
        const room = {
            id: roomId,
            createdAt: Date.now(),
            maxParticipants: options.maxParticipants || 10,
            sfuEndpoint: null,
            participants: []
        };
        
        await this.redis.hset('rooms', roomId, JSON.stringify(room));
        return room;
    }
    
    async joinRoom(roomId, userId) {
        let room = await this.getRoom(roomId);
        
        if (!room) {
            room = await this.createRoom(roomId);
        }
        
        if (room.participants.length >= room.maxParticipants) {
            throw new Error('Room is full');
        }
        
        room.participants.push(userId);
        await this.redis.hset('rooms', roomId, JSON.stringify(room));
        
        // 分配 SFU
        if (!room.sfuEndpoint) {
            room.sfuEndpoint = await this.allocateSfu(roomId);
        }
        
        return room;
    }
    
    async leaveRoom(roomId, userId) {
        const room = await this.getRoom(roomId);
        if (!room) return;
        
        room.participants = room.participants.filter(id => id !== userId);
        
        if (room.participants.length === 0) {
            await this.redis.hdel('rooms', roomId);
        } else {
            await this.redis.hset('rooms', roomId, JSON.stringify(room));
        }
    }
    
    async getRoom(roomId) {
        const data = await this.redis.hget('rooms', roomId);
        return data ? JSON.parse(data) : null;
    }
    
    async allocateSfu(roomId) {
        // 从 SFU 集群中选择负载最低的
        const sfuList = await this.redis.smembers('sfu-nodes');
        let bestSfu = null;
        let minLoad = Infinity;
        
        for (const sfu of sfuList) {
            const load = await this.redis.get(`sfu-load:${sfu}`);
            if (parseInt(load) < minLoad) {
                minLoad = parseInt(load);
                bestSfu = sfu;
            }
        }
        
        return bestSfu;
    }
}

module.exports = RoomManager;
```

---

## 3. TURN/STUN 服务

### 3.1 coturn 配置

```bash
# /etc/turnserver.conf

# 基本配置
listening-port=3478
tls-listening-port=5349
listening-ip=0.0.0.0
relay-ip=<公网IP>
external-ip=<公网IP>

# 认证
lt-cred-mech
use-auth-secret
static-auth-secret=<长随机字符串>

# TLS 证书
cert=/etc/letsencrypt/live/turn.example.com/fullchain.pem
pkey=/etc/letsencrypt/live/turn.example.com/privkey.pem

# 日志
log-file=/var/log/turnserver.log
verbose

# 安全
no-multicast-peers
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=192.168.0.0-192.168.255.255
denied-peer-ip=172.16.0.0-172.31.255.255

# 性能
total-quota=100
bps-capacity=0
max-bps=3000000
```

### 3.2 动态凭证生成

```javascript
// api-server/src/turnCredentials.js
const crypto = require('crypto');

class TurnCredentialGenerator {
    constructor(secret, ttl = 86400) {
        this.secret = secret;
        this.ttl = ttl;
    }
    
    generate(userId) {
        const timestamp = Math.floor(Date.now() / 1000) + this.ttl;
        const username = `${timestamp}:${userId}`;
        
        const hmac = crypto.createHmac('sha1', this.secret);
        hmac.update(username);
        const credential = hmac.digest('base64');
        
        return {
            urls: [
                'stun:turn.example.com:3478',
                'turn:turn.example.com:3478',
                'turns:turn.example.com:5349'
            ],
            username,
            credential,
            ttl: this.ttl
        };
    }
}

// API 端点
app.get('/api/turn-credentials', authenticate, (req, res) => {
    const generator = new TurnCredentialGenerator(process.env.TURN_SECRET);
    const credentials = generator.generate(req.userId);
    res.json(credentials);
});
```

---

## 4. SFU 媒体服务器

### 4.1 mediasoup 服务

```javascript
// sfu-server/src/index.js
const mediasoup = require('mediasoup');
const express = require('express');
const https = require('https');
const WebSocket = require('ws');

const app = express();
const server = https.createServer(sslOptions, app);
const wss = new WebSocket.Server({ server });

// mediasoup 配置
const config = {
    worker: {
        rtcMinPort: 10000,
        rtcMaxPort: 10100,
        logLevel: 'warn'
    },
    router: {
        mediaCodecs: [
            {
                kind: 'audio',
                mimeType: 'audio/opus',
                clockRate: 48000,
                channels: 2
            },
            {
                kind: 'video',
                mimeType: 'video/VP8',
                clockRate: 90000
            },
            {
                kind: 'video',
                mimeType: 'video/VP9',
                clockRate: 90000
            }
        ]
    },
    webRtcTransport: {
        listenIps: [
            { ip: '0.0.0.0', announcedIp: process.env.PUBLIC_IP }
        ],
        initialAvailableOutgoingBitrate: 1000000,
        maxIncomingBitrate: 1500000
    }
};

// Worker 池
const workers = [];
let nextWorkerIndex = 0;

async function createWorkers() {
    const numWorkers = require('os').cpus().length;
    
    for (let i = 0; i < numWorkers; i++) {
        const worker = await mediasoup.createWorker(config.worker);
        workers.push(worker);
        
        worker.on('died', () => {
            console.error(`Worker ${i} died`);
            process.exit(1);
        });
    }
}

function getNextWorker() {
    const worker = workers[nextWorkerIndex];
    nextWorkerIndex = (nextWorkerIndex + 1) % workers.length;
    return worker;
}

// 房间管理
const rooms = new Map();

class Room {
    constructor(id, router) {
        this.id = id;
        this.router = router;
        this.peers = new Map();
    }
    
    async addPeer(peerId) {
        const peer = {
            id: peerId,
            transports: new Map(),
            producers: new Map(),
            consumers: new Map()
        };
        this.peers.set(peerId, peer);
        return peer;
    }
    
    async createWebRtcTransport(peerId) {
        const transport = await this.router.createWebRtcTransport(
            config.webRtcTransport
        );
        
        const peer = this.peers.get(peerId);
        peer.transports.set(transport.id, transport);
        
        return {
            id: transport.id,
            iceParameters: transport.iceParameters,
            iceCandidates: transport.iceCandidates,
            dtlsParameters: transport.dtlsParameters
        };
    }
    
    async produce(peerId, transportId, kind, rtpParameters) {
        const peer = this.peers.get(peerId);
        const transport = peer.transports.get(transportId);
        
        const producer = await transport.produce({ kind, rtpParameters });
        peer.producers.set(producer.id, producer);
        
        return producer;
    }
    
    async consume(peerId, producerId, rtpCapabilities) {
        const peer = this.peers.get(peerId);
        
        if (!this.router.canConsume({ producerId, rtpCapabilities })) {
            throw new Error('Cannot consume');
        }
        
        const transport = Array.from(peer.transports.values())
            .find(t => t.appData.consuming);
        
        const consumer = await transport.consume({
            producerId,
            rtpCapabilities,
            paused: true
        });
        
        peer.consumers.set(consumer.id, consumer);
        
        return {
            id: consumer.id,
            producerId,
            kind: consumer.kind,
            rtpParameters: consumer.rtpParameters
        };
    }
}

// 创建房间
async function getOrCreateRoom(roomId) {
    let room = rooms.get(roomId);
    
    if (!room) {
        const worker = getNextWorker();
        const router = await worker.createRouter({
            mediaCodecs: config.router.mediaCodecs
        });
        
        room = new Room(roomId, router);
        rooms.set(roomId, room);
    }
    
    return room;
}

// 启动
createWorkers().then(() => {
    server.listen(4443, () => {
        console.log('SFU server running on port 4443');
    });
});
```

---

## 5. Web 客户端

### 5.1 客户端架构

```javascript
// web-client/src/WebRTCClient.js
class WebRTCClient {
    constructor(config) {
        this.config = config;
        this.signaling = null;
        this.device = null;
        this.sendTransport = null;
        this.recvTransport = null;
        this.producers = new Map();
        this.consumers = new Map();
    }
    
    async connect(token) {
        // 获取 TURN 凭证
        const turnCredentials = await this.fetchTurnCredentials(token);
        
        // 连接信令服务器
        this.signaling = new SignalingClient(
            this.config.signalingUrl,
            token
        );
        await this.signaling.connect();
        
        // 设置事件处理
        this.setupSignalingHandlers();
    }
    
    async joinRoom(roomId) {
        // 加入房间
        const { rtpCapabilities, sfuEndpoint } = await this.signaling.joinRoom(roomId);
        
        // 加载 mediasoup Device
        this.device = new mediasoupClient.Device();
        await this.device.load({ routerRtpCapabilities: rtpCapabilities });
        
        // 创建传输
        await this.createTransports(sfuEndpoint);
        
        // 获取已有的 producers
        const producers = await this.signaling.getProducers();
        for (const producer of producers) {
            await this.consume(producer.producerId);
        }
    }
    
    async publish(stream) {
        for (const track of stream.getTracks()) {
            const producer = await this.sendTransport.produce({
                track,
                encodings: track.kind === 'video' ? [
                    { maxBitrate: 100000, scaleResolutionDownBy: 4 },
                    { maxBitrate: 300000, scaleResolutionDownBy: 2 },
                    { maxBitrate: 900000, scaleResolutionDownBy: 1 }
                ] : undefined
            });
            
            this.producers.set(producer.id, producer);
        }
    }
    
    async consume(producerId) {
        const consumerInfo = await this.signaling.consume({
            producerId,
            rtpCapabilities: this.device.rtpCapabilities
        });
        
        const consumer = await this.recvTransport.consume(consumerInfo);
        this.consumers.set(consumer.id, consumer);
        
        await this.signaling.resumeConsumer(consumer.id);
        
        return consumer.track;
    }
    
    setupSignalingHandlers() {
        this.signaling.on('new-producer', async ({ producerId }) => {
            const track = await this.consume(producerId);
            this.emit('track', track);
        });
        
        this.signaling.on('producer-closed', ({ producerId }) => {
            // 处理 producer 关闭
        });
    }
}
```

### 5.2 UI 组件

```jsx
// web-client/src/components/VideoRoom.jsx
import React, { useEffect, useRef, useState } from 'react';
import { WebRTCClient } from '../WebRTCClient';

function VideoRoom({ roomId, token }) {
    const [participants, setParticipants] = useState([]);
    const localVideoRef = useRef(null);
    const clientRef = useRef(null);
    
    useEffect(() => {
        const client = new WebRTCClient(config);
        clientRef.current = client;
        
        async function init() {
            await client.connect(token);
            
            // 获取本地媒体
            const stream = await navigator.mediaDevices.getUserMedia({
                video: true,
                audio: true
            });
            localVideoRef.current.srcObject = stream;
            
            // 加入房间
            await client.joinRoom(roomId);
            
            // 发布本地流
            await client.publish(stream);
            
            // 监听新轨道
            client.on('track', (track, peerId) => {
                setParticipants(prev => [...prev, { peerId, track }]);
            });
        }
        
        init();
        
        return () => {
            client.disconnect();
        };
    }, [roomId, token]);
    
    return (
        <div className="video-room">
            <div className="local-video">
                <video ref={localVideoRef} autoPlay muted playsInline />
            </div>
            <div className="remote-videos">
                {participants.map(p => (
                    <RemoteVideo key={p.peerId} track={p.track} />
                ))}
            </div>
            <div className="controls">
                <button onClick={() => toggleAudio()}>Mute</button>
                <button onClick={() => toggleVideo()}>Camera</button>
                <button onClick={() => leaveRoom()}>Leave</button>
            </div>
        </div>
    );
}

function RemoteVideo({ track }) {
    const videoRef = useRef(null);
    
    useEffect(() => {
        if (videoRef.current && track) {
            const stream = new MediaStream([track]);
            videoRef.current.srcObject = stream;
        }
    }, [track]);
    
    return <video ref={videoRef} autoPlay playsInline />;
}
```

---

## 6. 移动端客户端

### 6.1 Android 集成

```kotlin
// android/app/src/main/java/com/example/webrtc/WebRTCManager.kt
class WebRTCManager(
    private val context: Context,
    private val config: Config
) {
    private var peerConnectionFactory: PeerConnectionFactory? = null
    private var signaling: SignalingClient? = null
    private val transports = mutableMapOf<String, Transport>()
    
    fun initialize() {
        val options = PeerConnectionFactory.InitializationOptions
            .builder(context)
            .createInitializationOptions()
        PeerConnectionFactory.initialize(options)
        
        peerConnectionFactory = PeerConnectionFactory.builder()
            .setVideoEncoderFactory(DefaultVideoEncoderFactory(
                EglBase.create().eglBaseContext, true, true
            ))
            .setVideoDecoderFactory(DefaultVideoDecoderFactory(
                EglBase.create().eglBaseContext
            ))
            .createPeerConnectionFactory()
    }
    
    suspend fun connect(token: String) {
        signaling = SignalingClient(config.signalingUrl, token)
        signaling?.connect()
    }
    
    suspend fun joinRoom(roomId: String): RoomInfo {
        return signaling?.joinRoom(roomId) ?: throw Exception("Not connected")
    }
    
    suspend fun publish(videoTrack: VideoTrack, audioTrack: AudioTrack) {
        // 创建 Producer
    }
    
    suspend fun subscribe(producerId: String): MediaStreamTrack {
        // 创建 Consumer
    }
}
```

### 6.2 iOS 集成

```swift
// ios/WebRTCManager.swift
class WebRTCManager {
    private var peerConnectionFactory: RTCPeerConnectionFactory!
    private var signaling: SignalingClient?
    
    func initialize() {
        RTCInitializeSSL()
        
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        
        peerConnectionFactory = RTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )
    }
    
    func connect(token: String) async throws {
        signaling = SignalingClient(url: config.signalingUrl, token: token)
        try await signaling?.connect()
    }
    
    func joinRoom(roomId: String) async throws -> RoomInfo {
        guard let signaling = signaling else {
            throw WebRTCError.notConnected
        }
        return try await signaling.joinRoom(roomId)
    }
}
```

---

## 7. 业务逻辑层

### 7.1 用户认证

```javascript
// api-server/src/auth.js
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');

class AuthService {
    constructor(db) {
        this.db = db;
    }
    
    async register(email, password, name) {
        const hashedPassword = await bcrypt.hash(password, 10);
        
        const user = await this.db.user.create({
            data: {
                email,
                password: hashedPassword,
                name
            }
        });
        
        return this.generateToken(user);
    }
    
    async login(email, password) {
        const user = await this.db.user.findUnique({
            where: { email }
        });
        
        if (!user || !await bcrypt.compare(password, user.password)) {
            throw new Error('Invalid credentials');
        }
        
        return this.generateToken(user);
    }
    
    generateToken(user) {
        return jwt.sign(
            { userId: user.id, email: user.email },
            process.env.JWT_SECRET,
            { expiresIn: '7d' }
        );
    }
    
    verifyToken(token) {
        return jwt.verify(token, process.env.JWT_SECRET);
    }
}
```

### 7.2 房间权限

```javascript
// api-server/src/roomPermissions.js
class RoomPermissionService {
    constructor(db) {
        this.db = db;
    }
    
    async canJoinRoom(userId, roomId) {
        const room = await this.db.room.findUnique({
            where: { id: roomId },
            include: { members: true }
        });
        
        if (!room) return true; // 房间不存在,可以创建
        
        if (room.isPrivate) {
            return room.members.some(m => m.userId === userId);
        }
        
        return room.members.length < room.maxParticipants;
    }
    
    async canPublish(userId, roomId) {
        const membership = await this.db.roomMember.findUnique({
            where: {
                roomId_userId: { roomId, userId }
            }
        });
        
        return membership?.role === 'host' || membership?.role === 'speaker';
    }
    
    async setRole(roomId, userId, role) {
        await this.db.roomMember.update({
            where: {
                roomId_userId: { roomId, userId }
            },
            data: { role }
        });
    }
}
```

---

## 8. 部署与运维

### 8.1 Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  signaling:
    build: ./signaling-server
    ports:
      - "8080:8080"
    environment:
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET=${JWT_SECRET}
    depends_on:
      - redis
    deploy:
      replicas: 2

  api:
    build: ./api-server
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - JWT_SECRET=${JWT_SECRET}
      - TURN_SECRET=${TURN_SECRET}
    depends_on:
      - postgres

  sfu:
    build: ./sfu-server
    ports:
      - "4443:4443"
      - "10000-10100:10000-10100/udp"
    environment:
      - PUBLIC_IP=${PUBLIC_IP}
      - REDIS_URL=redis://redis:6379
    deploy:
      replicas: 2

  turn:
    image: coturn/coturn
    ports:
      - "3478:3478/udp"
      - "3478:3478/tcp"
      - "5349:5349/tcp"
      - "49152-65535:49152-65535/udp"
    volumes:
      - ./turnserver.conf:/etc/turnserver.conf
    command: -c /etc/turnserver.conf

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  postgres:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=webrtc
      - POSTGRES_USER=${DB_USER}
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./certs:/etc/nginx/certs
    depends_on:
      - signaling
      - api

volumes:
  postgres_data:
```

### 8.2 监控告警

```javascript
// monitoring/metrics.js
const prometheus = require('prom-client');

// 定义指标
const activeConnections = new prometheus.Gauge({
    name: 'webrtc_active_connections',
    help: 'Number of active WebRTC connections'
});

const roomCount = new prometheus.Gauge({
    name: 'webrtc_room_count',
    help: 'Number of active rooms'
});

const mediaBitrate = new prometheus.Histogram({
    name: 'webrtc_media_bitrate',
    help: 'Media bitrate distribution',
    buckets: [100000, 500000, 1000000, 2000000, 5000000]
});

const packetLoss = new prometheus.Histogram({
    name: 'webrtc_packet_loss',
    help: 'Packet loss rate distribution',
    buckets: [0.01, 0.02, 0.05, 0.1, 0.2]
});

// 导出指标端点
app.get('/metrics', async (req, res) => {
    res.set('Content-Type', prometheus.register.contentType);
    res.end(await prometheus.register.metrics());
});
```

---

## 9. 总结

### 9.1 系统组件总结

| 组件 | 技术 | 职责 |
|------|------|------|
| 信令服务器 | Node.js + WebSocket | 信令交换 |
| API 服务器 | Node.js/Go | 业务逻辑 |
| SFU | mediasoup | 媒体转发 |
| TURN | coturn | NAT 穿透 |
| 数据库 | PostgreSQL | 持久化 |
| 缓存 | Redis | 状态共享 |

### 9.2 扩展建议

```
系统扩展方向:

1. 功能扩展
   - 屏幕共享
   - 录制回放
   - 实时字幕
   - 虚拟背景

2. 性能扩展
   - SFU 集群
   - 地理分布部署
   - CDN 加速

3. 运维扩展
   - 自动扩缩容
   - 故障自愈
   - 全链路监控
```

### 9.3 系列总结

恭喜你完成了 WebRTC 技术专栏的全部 29 篇文章!

本系列涵盖了:
- **Part 1-2**: 基础概念与信令 (11 篇)
- **Part 3**: 媒体传输 (6 篇)
- **Part 4**: 编码与处理 (3 篇)
- **Part 5**: 工程实践 (5 篇)
- **Part 6**: 高级主题 (4 篇)

希望这个系列能帮助你全面掌握 WebRTC 技术,构建出色的实时通信应用!

---

## 参考资料

1. [mediasoup Documentation](https://mediasoup.org/documentation/)
2. [coturn Project](https://github.com/coturn/coturn)
3. [WebRTC Architecture](https://webrtc.org/architecture/)

---

> 作者: WebRTC 技术专栏  
> 系列: 高级主题与优化 (4/4)  
> 上一篇: [WebRTC 安全机制](./28-security.md)

---

感谢阅读 WebRTC 技术专栏全部 29 篇文章!
