---
title: "搭建一个 SFU (以 mediasoup 为例)"
description: "1. [mediasoup 简介](#1-mediasoup-简介)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 23
---

> 本文是 WebRTC 系列专栏的第二十三篇,将手把手教你使用 mediasoup 搭建一个功能完整的 SFU 服务器,实现多人视频会议。

---

## 目录

1. [mediasoup 简介](#1-mediasoup-简介)
2. [环境准备](#2-环境准备)
3. [服务端实现](#3-服务端实现)
4. [客户端实现](#4-客户端实现)
5. [Simulcast 配置](#5-simulcast-配置)
6. [运行与测试](#6-运行与测试)
7. [生产部署](#7-生产部署)
8. [总结](#8-总结)

---

## 1. mediasoup 简介

### 1.1 什么是 mediasoup

```
mediasoup 特点:

- 高性能 SFU 媒体服务器
- Node.js API + C++ 核心
- 支持 WebRTC 和 ORTC
- 支持 Simulcast 和 SVC
- 开源免费 (ISC License)
```

### 1.2 核心概念

```
mediasoup 核心对象:

Worker
  └── Router (房间)
        ├── Transport (传输通道)
        │     ├── Producer (发布流)
        │     └── Consumer (订阅流)
        └── Transport
              ├── Producer
              └── Consumer

Worker: 独立进程,处理媒体
Router: 路由器,管理房间内的流
Transport: WebRTC 传输通道
Producer: 发布媒体流
Consumer: 消费媒体流
```

### 1.3 数据流

```
客户端 A (发布)                mediasoup                客户端 B (订阅)
     |                            |                           |
     |  WebRTC Transport          |                           |
     | -------------------------> |                           |
     |                            |                           |
     |  Producer (video)          |                           |
     | -------------------------> |                           |
     |                            |                           |
     |                            |  WebRTC Transport         |
     |                            | <------------------------ |
     |                            |                           |
     |                            |  Consumer (video)         |
     |                            | ------------------------> |
     |                            |                           |
```

---

## 2. 环境准备

### 2.1 系统要求

```bash
# Node.js 16+
node --version

# Python 3 (编译依赖)
python3 --version

# GCC/G++ (Linux)
gcc --version

# 或 Xcode Command Line Tools (macOS)
xcode-select --install
```

### 2.2 项目初始化

```bash
mkdir mediasoup-demo
cd mediasoup-demo
npm init -y

# 安装依赖
npm install mediasoup express socket.io uuid
npm install -D nodemon
```

### 2.3 项目结构

```
mediasoup-demo/
├── package.json
├── server.js              # 主入口
├── src/
│   ├── config.js          # 配置
│   ├── Room.js            # 房间管理
│   └── Peer.js            # 参与者管理
├── public/
│   ├── index.html         # 客户端页面
│   ├── client.js          # 客户端逻辑
│   └── style.css          # 样式
└── README.md
```

---

## 3. 服务端实现

### 3.1 配置文件

```javascript
// src/config.js
module.exports = {
    // HTTP/HTTPS 服务器配置
    http: {
        listenPort: 3000
    },
    
    // mediasoup Worker 配置
    mediasoup: {
        // Worker 数量 (通常等于 CPU 核心数)
        numWorkers: require('os').cpus().length,
        
        worker: {
            rtcMinPort: 10000,
            rtcMaxPort: 10100,
            logLevel: 'warn',
            logTags: [
                'info',
                'ice',
                'dtls',
                'rtp',
                'srtp',
                'rtcp'
            ]
        },
        
        // Router 配置
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
                    clockRate: 90000,
                    parameters: {
                        'x-google-start-bitrate': 1000
                    }
                },
                {
                    kind: 'video',
                    mimeType: 'video/VP9',
                    clockRate: 90000,
                    parameters: {
                        'profile-id': 2,
                        'x-google-start-bitrate': 1000
                    }
                },
                {
                    kind: 'video',
                    mimeType: 'video/H264',
                    clockRate: 90000,
                    parameters: {
                        'packetization-mode': 1,
                        'profile-level-id': '42e01f',
                        'level-asymmetry-allowed': 1,
                        'x-google-start-bitrate': 1000
                    }
                }
            ]
        },
        
        // WebRTC Transport 配置
        webRtcTransport: {
            listenIps: [
                {
                    ip: '0.0.0.0',
                    announcedIp: null // 替换为公网 IP
                }
            ],
            initialAvailableOutgoingBitrate: 1000000,
            minimumAvailableOutgoingBitrate: 600000,
            maxSctpMessageSize: 262144,
            maxIncomingBitrate: 1500000
        }
    }
};
```

### 3.2 主服务器

```javascript
// server.js
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const mediasoup = require('mediasoup');
const config = require('./src/config');
const Room = require('./src/Room');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
    cors: { origin: '*' }
});

// 静态文件
app.use(express.static('public'));

// mediasoup Workers
let workers = [];
let nextWorkerIndex = 0;

// 房间管理
const rooms = new Map();

// 初始化 Workers
async function createWorkers() {
    for (let i = 0; i < config.mediasoup.numWorkers; i++) {
        const worker = await mediasoup.createWorker(config.mediasoup.worker);
        
        worker.on('died', () => {
            console.error(`Worker ${i} died, exiting...`);
            process.exit(1);
        });
        
        workers.push(worker);
        console.log(`Worker ${i} created`);
    }
}

// 获取下一个 Worker (轮询)
function getNextWorker() {
    const worker = workers[nextWorkerIndex];
    nextWorkerIndex = (nextWorkerIndex + 1) % workers.length;
    return worker;
}

// 获取或创建房间
async function getOrCreateRoom(roomId) {
    let room = rooms.get(roomId);
    
    if (!room) {
        const worker = getNextWorker();
        room = new Room(roomId, worker, config.mediasoup.router);
        await room.init();
        rooms.set(roomId, room);
        
        room.on('close', () => {
            rooms.delete(roomId);
        });
    }
    
    return room;
}

// Socket.IO 连接处理
io.on('connection', (socket) => {
    console.log('Client connected:', socket.id);
    
    let currentRoom = null;
    let currentPeer = null;
    
    // 加入房间
    socket.on('joinRoom', async ({ roomId, displayName }, callback) => {
        try {
            currentRoom = await getOrCreateRoom(roomId);
            currentPeer = await currentRoom.addPeer(socket.id, displayName);
            
            socket.join(roomId);
            
            // 返回 Router RTP Capabilities
            callback({
                rtpCapabilities: currentRoom.router.rtpCapabilities
            });
            
            // 通知其他人
            socket.to(roomId).emit('newPeer', {
                peerId: socket.id,
                displayName
            });
        } catch (error) {
            console.error('joinRoom error:', error);
            callback({ error: error.message });
        }
    });
    
    // 创建 WebRTC Transport
    socket.on('createWebRtcTransport', async ({ producing }, callback) => {
        try {
            const transport = await currentRoom.createWebRtcTransport(
                socket.id,
                producing,
                config.mediasoup.webRtcTransport
            );
            
            callback({
                id: transport.id,
                iceParameters: transport.iceParameters,
                iceCandidates: transport.iceCandidates,
                dtlsParameters: transport.dtlsParameters,
                sctpParameters: transport.sctpParameters
            });
        } catch (error) {
            console.error('createWebRtcTransport error:', error);
            callback({ error: error.message });
        }
    });
    
    // 连接 Transport
    socket.on('connectTransport', async ({ transportId, dtlsParameters }, callback) => {
        try {
            await currentRoom.connectTransport(socket.id, transportId, dtlsParameters);
            callback({});
        } catch (error) {
            console.error('connectTransport error:', error);
            callback({ error: error.message });
        }
    });
    
    // 发布流
    socket.on('produce', async ({ transportId, kind, rtpParameters, appData }, callback) => {
        try {
            const producer = await currentRoom.produce(
                socket.id,
                transportId,
                kind,
                rtpParameters,
                appData
            );
            
            callback({ id: producer.id });
            
            // 通知其他人有新的 Producer
            socket.to(currentRoom.id).emit('newProducer', {
                peerId: socket.id,
                producerId: producer.id,
                kind
            });
        } catch (error) {
            console.error('produce error:', error);
            callback({ error: error.message });
        }
    });
    
    // 订阅流
    socket.on('consume', async ({ producerId, rtpCapabilities }, callback) => {
        try {
            const consumer = await currentRoom.consume(
                socket.id,
                producerId,
                rtpCapabilities
            );
            
            callback({
                id: consumer.id,
                producerId: consumer.producerId,
                kind: consumer.kind,
                rtpParameters: consumer.rtpParameters
            });
        } catch (error) {
            console.error('consume error:', error);
            callback({ error: error.message });
        }
    });
    
    // 恢复 Consumer
    socket.on('resumeConsumer', async ({ consumerId }, callback) => {
        try {
            await currentRoom.resumeConsumer(socket.id, consumerId);
            callback({});
        } catch (error) {
            console.error('resumeConsumer error:', error);
            callback({ error: error.message });
        }
    });
    
    // 获取房间内的 Producers
    socket.on('getProducers', (callback) => {
        if (!currentRoom) {
            callback({ producers: [] });
            return;
        }
        
        const producers = currentRoom.getProducersExcept(socket.id);
        callback({ producers });
    });
    
    // 断开连接
    socket.on('disconnect', () => {
        console.log('Client disconnected:', socket.id);
        
        if (currentRoom) {
            currentRoom.removePeer(socket.id);
            socket.to(currentRoom.id).emit('peerClosed', {
                peerId: socket.id
            });
        }
    });
});

// 启动服务器
async function main() {
    await createWorkers();
    
    server.listen(config.http.listenPort, () => {
        console.log(`Server running on port ${config.http.listenPort}`);
    });
}

main().catch(console.error);
```

### 3.3 Room 类

```javascript
// src/Room.js
const EventEmitter = require('events');
const Peer = require('./Peer');

class Room extends EventEmitter {
    constructor(id, worker, routerConfig) {
        super();
        this.id = id;
        this.worker = worker;
        this.routerConfig = routerConfig;
        this.router = null;
        this.peers = new Map();
    }
    
    async init() {
        this.router = await this.worker.createRouter({
            mediaCodecs: this.routerConfig.mediaCodecs
        });
        
        console.log(`Room ${this.id} created`);
    }
    
    async addPeer(peerId, displayName) {
        const peer = new Peer(peerId, displayName);
        this.peers.set(peerId, peer);
        
        console.log(`Peer ${peerId} joined room ${this.id}`);
        return peer;
    }
    
    removePeer(peerId) {
        const peer = this.peers.get(peerId);
        if (!peer) return;
        
        // 关闭所有 Transport
        for (const transport of peer.transports.values()) {
            transport.close();
        }
        
        this.peers.delete(peerId);
        console.log(`Peer ${peerId} left room ${this.id}`);
        
        // 房间为空时关闭
        if (this.peers.size === 0) {
            this.close();
        }
    }
    
    close() {
        this.router.close();
        this.emit('close');
        console.log(`Room ${this.id} closed`);
    }
    
    async createWebRtcTransport(peerId, producing, options) {
        const peer = this.peers.get(peerId);
        if (!peer) throw new Error('Peer not found');
        
        const transport = await this.router.createWebRtcTransport(options);
        
        transport.on('dtlsstatechange', (dtlsState) => {
            if (dtlsState === 'closed') {
                transport.close();
            }
        });
        
        peer.addTransport(transport, producing);
        return transport;
    }
    
    async connectTransport(peerId, transportId, dtlsParameters) {
        const peer = this.peers.get(peerId);
        if (!peer) throw new Error('Peer not found');
        
        const transport = peer.transports.get(transportId);
        if (!transport) throw new Error('Transport not found');
        
        await transport.connect({ dtlsParameters });
    }
    
    async produce(peerId, transportId, kind, rtpParameters, appData) {
        const peer = this.peers.get(peerId);
        if (!peer) throw new Error('Peer not found');
        
        const transport = peer.transports.get(transportId);
        if (!transport) throw new Error('Transport not found');
        
        const producer = await transport.produce({
            kind,
            rtpParameters,
            appData
        });
        
        producer.on('transportclose', () => {
            producer.close();
        });
        
        peer.addProducer(producer);
        return producer;
    }
    
    async consume(peerId, producerId, rtpCapabilities) {
        const peer = this.peers.get(peerId);
        if (!peer) throw new Error('Peer not found');
        
        // 检查是否可以消费
        if (!this.router.canConsume({ producerId, rtpCapabilities })) {
            throw new Error('Cannot consume');
        }
        
        // 获取接收 Transport
        const transport = peer.getRecvTransport();
        if (!transport) throw new Error('No recv transport');
        
        const consumer = await transport.consume({
            producerId,
            rtpCapabilities,
            paused: true // 初始暂停,等待客户端准备好
        });
        
        consumer.on('transportclose', () => {
            consumer.close();
        });
        
        consumer.on('producerclose', () => {
            consumer.close();
            peer.removeConsumer(consumer.id);
        });
        
        peer.addConsumer(consumer);
        return consumer;
    }
    
    async resumeConsumer(peerId, consumerId) {
        const peer = this.peers.get(peerId);
        if (!peer) throw new Error('Peer not found');
        
        const consumer = peer.consumers.get(consumerId);
        if (!consumer) throw new Error('Consumer not found');
        
        await consumer.resume();
    }
    
    getProducersExcept(excludePeerId) {
        const producers = [];
        
        for (const [peerId, peer] of this.peers) {
            if (peerId === excludePeerId) continue;
            
            for (const producer of peer.producers.values()) {
                producers.push({
                    peerId,
                    producerId: producer.id,
                    kind: producer.kind
                });
            }
        }
        
        return producers;
    }
}

module.exports = Room;
```

### 3.4 Peer 类

```javascript
// src/Peer.js
class Peer {
    constructor(id, displayName) {
        this.id = id;
        this.displayName = displayName;
        this.transports = new Map();
        this.producers = new Map();
        this.consumers = new Map();
        this.sendTransportId = null;
        this.recvTransportId = null;
    }
    
    addTransport(transport, producing) {
        this.transports.set(transport.id, transport);
        
        if (producing) {
            this.sendTransportId = transport.id;
        } else {
            this.recvTransportId = transport.id;
        }
    }
    
    getSendTransport() {
        return this.transports.get(this.sendTransportId);
    }
    
    getRecvTransport() {
        return this.transports.get(this.recvTransportId);
    }
    
    addProducer(producer) {
        this.producers.set(producer.id, producer);
    }
    
    addConsumer(consumer) {
        this.consumers.set(consumer.id, consumer);
    }
    
    removeConsumer(consumerId) {
        this.consumers.delete(consumerId);
    }
}

module.exports = Peer;
```

---

## 4. 客户端实现

### 4.1 HTML 页面

```html
<!-- public/index.html -->
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>mediasoup Demo</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="container">
        <h1>mediasoup Video Conference</h1>
        
        <div class="controls">
            <input type="text" id="roomId" placeholder="房间 ID" value="test-room">
            <input type="text" id="displayName" placeholder="显示名称" value="User">
            <button id="joinBtn">加入房间</button>
            <button id="leaveBtn" disabled>离开房间</button>
        </div>
        
        <div class="video-grid" id="videoGrid">
            <div class="video-item local">
                <video id="localVideo" autoplay muted playsinline></video>
                <span class="name">本地</span>
            </div>
        </div>
    </div>
    
    <script src="/socket.io/socket.io.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/mediasoup-client@3/lib/mediasoup-client.min.js"></script>
    <script src="client.js"></script>
</body>
</html>
```

### 4.2 客户端 JavaScript

```javascript
// public/client.js
class MediasoupClient {
    constructor() {
        this.socket = null;
        this.device = null;
        this.sendTransport = null;
        this.recvTransport = null;
        this.producers = new Map();
        this.consumers = new Map();
        this.localStream = null;
        
        this.init();
    }
    
    init() {
        document.getElementById('joinBtn').onclick = () => this.join();
        document.getElementById('leaveBtn').onclick = () => this.leave();
    }
    
    async join() {
        const roomId = document.getElementById('roomId').value;
        const displayName = document.getElementById('displayName').value;
        
        // 获取本地媒体
        try {
            this.localStream = await navigator.mediaDevices.getUserMedia({
                video: true,
                audio: true
            });
            document.getElementById('localVideo').srcObject = this.localStream;
        } catch (error) {
            console.error('Failed to get media:', error);
            alert('无法获取摄像头/麦克风');
            return;
        }
        
        // 连接 Socket.IO
        this.socket = io();
        
        this.socket.on('connect', async () => {
            console.log('Connected to server');
            
            // 加入房间
            const { rtpCapabilities, error } = await this.request('joinRoom', {
                roomId,
                displayName
            });
            
            if (error) {
                console.error('Join room error:', error);
                return;
            }
            
            // 加载 mediasoup Device
            await this.loadDevice(rtpCapabilities);
            
            // 创建 Transport
            await this.createSendTransport();
            await this.createRecvTransport();
            
            // 发布本地流
            await this.produce();
            
            // 获取已有的 Producers
            const { producers } = await this.request('getProducers');
            for (const producer of producers) {
                await this.consume(producer.producerId, producer.peerId);
            }
            
            document.getElementById('joinBtn').disabled = true;
            document.getElementById('leaveBtn').disabled = false;
        });
        
        // 新的 Producer
        this.socket.on('newProducer', async ({ peerId, producerId, kind }) => {
            console.log('New producer:', producerId);
            await this.consume(producerId, peerId);
        });
        
        // Peer 离开
        this.socket.on('peerClosed', ({ peerId }) => {
            console.log('Peer closed:', peerId);
            this.removeRemoteVideo(peerId);
        });
    }
    
    async loadDevice(rtpCapabilities) {
        this.device = new mediasoupClient.Device();
        await this.device.load({ routerRtpCapabilities: rtpCapabilities });
    }
    
    async createSendTransport() {
        const transportInfo = await this.request('createWebRtcTransport', {
            producing: true
        });
        
        this.sendTransport = this.device.createSendTransport(transportInfo);
        
        this.sendTransport.on('connect', async ({ dtlsParameters }, callback, errback) => {
            try {
                await this.request('connectTransport', {
                    transportId: this.sendTransport.id,
                    dtlsParameters
                });
                callback();
            } catch (error) {
                errback(error);
            }
        });
        
        this.sendTransport.on('produce', async ({ kind, rtpParameters, appData }, callback, errback) => {
            try {
                const { id } = await this.request('produce', {
                    transportId: this.sendTransport.id,
                    kind,
                    rtpParameters,
                    appData
                });
                callback({ id });
            } catch (error) {
                errback(error);
            }
        });
    }
    
    async createRecvTransport() {
        const transportInfo = await this.request('createWebRtcTransport', {
            producing: false
        });
        
        this.recvTransport = this.device.createRecvTransport(transportInfo);
        
        this.recvTransport.on('connect', async ({ dtlsParameters }, callback, errback) => {
            try {
                await this.request('connectTransport', {
                    transportId: this.recvTransport.id,
                    dtlsParameters
                });
                callback();
            } catch (error) {
                errback(error);
            }
        });
    }
    
    async produce() {
        // 发布视频
        const videoTrack = this.localStream.getVideoTracks()[0];
        if (videoTrack) {
            const videoProducer = await this.sendTransport.produce({
                track: videoTrack
            });
            this.producers.set('video', videoProducer);
        }
        
        // 发布音频
        const audioTrack = this.localStream.getAudioTracks()[0];
        if (audioTrack) {
            const audioProducer = await this.sendTransport.produce({
                track: audioTrack
            });
            this.producers.set('audio', audioProducer);
        }
    }
    
    async consume(producerId, peerId) {
        const { id, kind, rtpParameters, error } = await this.request('consume', {
            producerId,
            rtpCapabilities: this.device.rtpCapabilities
        });
        
        if (error) {
            console.error('Consume error:', error);
            return;
        }
        
        const consumer = await this.recvTransport.consume({
            id,
            producerId,
            kind,
            rtpParameters
        });
        
        this.consumers.set(consumer.id, consumer);
        
        // 恢复 Consumer
        await this.request('resumeConsumer', { consumerId: consumer.id });
        
        // 添加到视频元素
        this.addRemoteTrack(peerId, consumer.track);
    }
    
    addRemoteTrack(peerId, track) {
        let videoItem = document.getElementById(`video-${peerId}`);
        
        if (!videoItem) {
            videoItem = document.createElement('div');
            videoItem.id = `video-${peerId}`;
            videoItem.className = 'video-item';
            
            const video = document.createElement('video');
            video.autoplay = true;
            video.playsinline = true;
            
            const name = document.createElement('span');
            name.className = 'name';
            name.textContent = peerId.slice(0, 8);
            
            videoItem.appendChild(video);
            videoItem.appendChild(name);
            document.getElementById('videoGrid').appendChild(videoItem);
        }
        
        const video = videoItem.querySelector('video');
        
        // 添加 track 到 MediaStream
        let stream = video.srcObject;
        if (!stream) {
            stream = new MediaStream();
            video.srcObject = stream;
        }
        stream.addTrack(track);
    }
    
    removeRemoteVideo(peerId) {
        const videoItem = document.getElementById(`video-${peerId}`);
        if (videoItem) {
            videoItem.remove();
        }
    }
    
    leave() {
        // 关闭 Producers
        for (const producer of this.producers.values()) {
            producer.close();
        }
        this.producers.clear();
        
        // 关闭 Consumers
        for (const consumer of this.consumers.values()) {
            consumer.close();
        }
        this.consumers.clear();
        
        // 关闭 Transports
        if (this.sendTransport) {
            this.sendTransport.close();
            this.sendTransport = null;
        }
        if (this.recvTransport) {
            this.recvTransport.close();
            this.recvTransport = null;
        }
        
        // 停止本地流
        if (this.localStream) {
            this.localStream.getTracks().forEach(track => track.stop());
            this.localStream = null;
        }
        
        // 断开 Socket
        if (this.socket) {
            this.socket.disconnect();
            this.socket = null;
        }
        
        // 清理 UI
        document.getElementById('localVideo').srcObject = null;
        document.getElementById('videoGrid').innerHTML = `
            <div class="video-item local">
                <video id="localVideo" autoplay muted playsinline></video>
                <span class="name">本地</span>
            </div>
        `;
        
        document.getElementById('joinBtn').disabled = false;
        document.getElementById('leaveBtn').disabled = true;
    }
    
    // Socket.IO 请求封装
    request(event, data = {}) {
        return new Promise((resolve) => {
            this.socket.emit(event, data, resolve);
        });
    }
}

// 启动客户端
const client = new MediasoupClient();
```

### 4.3 CSS 样式

```css
/* public/style.css */
* {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: #1a1a2e;
    color: #eee;
    min-height: 100vh;
}

.container {
    max-width: 1400px;
    margin: 0 auto;
    padding: 20px;
}

h1 {
    text-align: center;
    margin-bottom: 20px;
    color: #00d9ff;
}

.controls {
    display: flex;
    gap: 10px;
    justify-content: center;
    margin-bottom: 20px;
    flex-wrap: wrap;
}

input {
    padding: 10px 15px;
    border: none;
    border-radius: 5px;
    background: #16213e;
    color: #eee;
    font-size: 16px;
}

button {
    padding: 10px 20px;
    border: none;
    border-radius: 5px;
    background: #00d9ff;
    color: #1a1a2e;
    font-size: 16px;
    cursor: pointer;
    transition: background 0.3s;
}

button:hover:not(:disabled) {
    background: #00b8d9;
}

button:disabled {
    background: #555;
    cursor: not-allowed;
}

.video-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 20px;
}

.video-item {
    position: relative;
    background: #16213e;
    border-radius: 10px;
    overflow: hidden;
    aspect-ratio: 4/3;
}

.video-item.local {
    border: 2px solid #00d9ff;
}

.video-item video {
    width: 100%;
    height: 100%;
    object-fit: cover;
}

.video-item .name {
    position: absolute;
    bottom: 10px;
    left: 10px;
    background: rgba(0, 0, 0, 0.7);
    padding: 5px 10px;
    border-radius: 5px;
    font-size: 14px;
}
```

---

## 5. Simulcast 配置

### 5.1 启用 Simulcast

```javascript
// 客户端发布时启用 Simulcast
async produce() {
    const videoTrack = this.localStream.getVideoTracks()[0];
    
    if (videoTrack) {
        const videoProducer = await this.sendTransport.produce({
            track: videoTrack,
            encodings: [
                { maxBitrate: 100000, scaleResolutionDownBy: 4, rid: 'low' },
                { maxBitrate: 300000, scaleResolutionDownBy: 2, rid: 'mid' },
                { maxBitrate: 900000, scaleResolutionDownBy: 1, rid: 'high' }
            ],
            codecOptions: {
                videoGoogleStartBitrate: 1000
            }
        });
        
        this.producers.set('video', videoProducer);
    }
}
```

### 5.2 服务端层选择

```javascript
// 服务端: 设置 Consumer 的首选层
socket.on('setPreferredLayers', async ({ consumerId, spatialLayer, temporalLayer }, callback) => {
    try {
        const consumer = peer.consumers.get(consumerId);
        if (consumer) {
            await consumer.setPreferredLayers({ spatialLayer, temporalLayer });
        }
        callback({});
    } catch (error) {
        callback({ error: error.message });
    }
});
```

---

## 6. 运行与测试

### 6.1 启动服务器

```bash
# 开发模式
npm run dev

# 或生产模式
npm start
```

### 6.2 测试步骤

```
1. 打开浏览器访问 http://localhost:3000

2. 输入房间 ID 和显示名称

3. 点击"加入房间"

4. 允许摄像头/麦克风权限

5. 打开另一个浏览器窗口,加入同一房间

6. 观察视频是否正常显示
```

---

## 7. 生产部署

### 7.1 HTTPS 配置

```javascript
// 使用 HTTPS
const https = require('https');
const fs = require('fs');

const server = https.createServer({
    cert: fs.readFileSync('/path/to/cert.pem'),
    key: fs.readFileSync('/path/to/key.pem')
}, app);
```

### 7.2 公网 IP 配置

```javascript
// config.js
webRtcTransport: {
    listenIps: [
        {
            ip: '0.0.0.0',
            announcedIp: '你的公网IP' // 必须设置
        }
    ]
}
```

### 7.3 Docker 部署

```dockerfile
FROM node:18

WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .

EXPOSE 3000
EXPOSE 10000-10100/udp

CMD ["npm", "start"]
```

---

## 8. 总结

### 8.1 核心要点

| 组件 | 功能 |
|------|------|
| Worker | 媒体处理进程 |
| Router | 房间路由 |
| Transport | WebRTC 传输 |
| Producer | 发布流 |
| Consumer | 订阅流 |

### 8.2 下一篇预告

在下一篇文章中,我们将探讨 RTCDataChannel 数据通道。

---

## 参考资料

1. [mediasoup Documentation](https://mediasoup.org/documentation/)
2. [mediasoup-demo](https://github.com/versatica/mediasoup-demo)

---

> 作者: WebRTC 技术专栏  
> 系列: 工程实践 (3/5)  
> 上一篇: [WebRTC SFU 架构详解](./22-sfu-architecture.md)  
> 下一篇: [WebRTC 数据通道](./24-data-channel.md)
