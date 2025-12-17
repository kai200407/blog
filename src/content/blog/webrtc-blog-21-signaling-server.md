---
title: "构建自己的 WebRTC 信令服务器 (Node.js 实战)"
description: "1. [信令服务器概述](#1-信令服务器概述)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 21
---

> 本文是 WebRTC 系列专栏的第二十一篇,将手把手教你使用 Node.js 构建一个完整的 WebRTC 信令服务器,包括 WebSocket 通信、房间管理和 Offer/Answer 交换。

---

## 目录

1. [信令服务器概述](#1-信令服务器概述)
2. [项目结构](#2-项目结构)
3. [WebSocket 服务器](#3-websocket-服务器)
4. [房间管理](#4-房间管理)
5. [信令消息处理](#5-信令消息处理)
6. [客户端实现](#6-客户端实现)
7. [完整代码](#7-完整代码)
8. [部署与测试](#8-部署与测试)
9. [总结](#9-总结)

---

## 1. 信令服务器概述

### 1.1 信令服务器的作用

```
信令服务器职责:

1. 用户管理
   - 用户连接/断开
   - 用户身份标识

2. 房间管理
   - 创建/加入/离开房间
   - 房间成员列表

3. 消息转发
   - SDP Offer/Answer
   - ICE Candidate
   - 自定义消息

4. 状态同步
   - 用户状态
   - 房间状态
```

### 1.2 信令流程

```
完整信令流程:

用户 A                  信令服务器                  用户 B
  |                         |                         |
  |  1. 连接 WebSocket      |                         |
  | ----------------------> |                         |
  |                         |                         |
  |  2. 加入房间 "room1"    |                         |
  | ----------------------> |                         |
  |                         |                         |
  |                         |  3. 连接 WebSocket      |
  |                         | <---------------------- |
  |                         |                         |
  |                         |  4. 加入房间 "room1"    |
  |                         | <---------------------- |
  |                         |                         |
  |  5. 通知: B 加入        |                         |
  | <---------------------- |                         |
  |                         |                         |
  |  6. 发送 Offer 给 B     |                         |
  | ----------------------> |                         |
  |                         |  7. 转发 Offer          |
  |                         | ----------------------> |
  |                         |                         |
  |                         |  8. 发送 Answer         |
  |                         | <---------------------- |
  |  9. 转发 Answer         |                         |
  | <---------------------- |                         |
  |                         |                         |
  |  10. ICE Candidate 交换 (双向)                    |
  | <---------------------------------------------->  |
  |                         |                         |
```

### 1.3 技术选型

| 技术 | 选择 | 原因 |
|------|------|------|
| 运行时 | Node.js | 异步 I/O,适合实时应用 |
| WebSocket | ws | 轻量,性能好 |
| HTTP | Express | 可选,提供 REST API |
| 数据存储 | 内存/Redis | 简单场景用内存 |

---

## 2. 项目结构

### 2.1 目录结构

```
signaling-server/
├── package.json
├── server.js              # 主入口
├── src/
│   ├── SignalingServer.js # 信令服务器类
│   ├── RoomManager.js     # 房间管理
│   ├── MessageHandler.js  # 消息处理
│   └── utils.js           # 工具函数
├── client/
│   ├── index.html         # 客户端页面
│   ├── app.js             # 客户端逻辑
│   └── style.css          # 样式
└── README.md
```

### 2.2 package.json

```json
{
  "name": "webrtc-signaling-server",
  "version": "1.0.0",
  "description": "WebRTC Signaling Server",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "ws": "^8.14.2",
    "uuid": "^9.0.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
```

---

## 3. WebSocket 服务器

### 3.1 基础服务器

```javascript
// server.js
const WebSocket = require('ws');
const http = require('http');
const { SignalingServer } = require('./src/SignalingServer');

const PORT = process.env.PORT || 8080;

// 创建 HTTP 服务器
const server = http.createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('WebRTC Signaling Server');
});

// 创建 WebSocket 服务器
const wss = new WebSocket.Server({ server });

// 创建信令服务器实例
const signalingServer = new SignalingServer(wss);

// 启动服务器
server.listen(PORT, () => {
    console.log(`Signaling server running on port ${PORT}`);
});
```

### 3.2 SignalingServer 类

```javascript
// src/SignalingServer.js
const { v4: uuidv4 } = require('uuid');
const { RoomManager } = require('./RoomManager');
const { MessageHandler } = require('./MessageHandler');

class SignalingServer {
    constructor(wss) {
        this.wss = wss;
        this.clients = new Map(); // clientId -> { ws, userId, roomId }
        this.roomManager = new RoomManager();
        this.messageHandler = new MessageHandler(this);
        
        this.init();
    }
    
    init() {
        this.wss.on('connection', (ws, req) => {
            this.handleConnection(ws, req);
        });
    }
    
    handleConnection(ws, req) {
        const clientId = uuidv4();
        
        // 保存客户端信息
        this.clients.set(clientId, {
            ws,
            userId: null,
            roomId: null,
            connectedAt: Date.now()
        });
        
        console.log(`Client connected: ${clientId}`);
        
        // 发送欢迎消息
        this.send(ws, {
            type: 'welcome',
            clientId
        });
        
        // 处理消息
        ws.on('message', (data) => {
            try {
                const message = JSON.parse(data);
                this.messageHandler.handle(clientId, message);
            } catch (error) {
                console.error('Invalid message:', error);
                this.send(ws, {
                    type: 'error',
                    message: 'Invalid message format'
                });
            }
        });
        
        // 处理断开连接
        ws.on('close', () => {
            this.handleDisconnect(clientId);
        });
        
        // 处理错误
        ws.on('error', (error) => {
            console.error(`Client ${clientId} error:`, error);
        });
        
        // 心跳检测
        ws.isAlive = true;
        ws.on('pong', () => {
            ws.isAlive = true;
        });
    }
    
    handleDisconnect(clientId) {
        const client = this.clients.get(clientId);
        if (!client) return;
        
        // 离开房间
        if (client.roomId) {
            this.roomManager.leaveRoom(client.roomId, clientId);
            
            // 通知房间内其他人
            this.broadcastToRoom(client.roomId, {
                type: 'user-left',
                userId: client.userId,
                clientId
            }, clientId);
        }
        
        // 删除客户端
        this.clients.delete(clientId);
        console.log(`Client disconnected: ${clientId}`);
    }
    
    // 发送消息给单个客户端
    send(ws, message) {
        if (ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify(message));
        }
    }
    
    // 发送消息给指定客户端
    sendTo(clientId, message) {
        const client = this.clients.get(clientId);
        if (client) {
            this.send(client.ws, message);
        }
    }
    
    // 广播给房间内所有人
    broadcastToRoom(roomId, message, excludeClientId = null) {
        const room = this.roomManager.getRoom(roomId);
        if (!room) return;
        
        for (const memberId of room.members) {
            if (memberId !== excludeClientId) {
                this.sendTo(memberId, message);
            }
        }
    }
    
    // 启动心跳检测
    startHeartbeat() {
        setInterval(() => {
            this.wss.clients.forEach((ws) => {
                if (ws.isAlive === false) {
                    return ws.terminate();
                }
                ws.isAlive = false;
                ws.ping();
            });
        }, 30000);
    }
}

module.exports = { SignalingServer };
```

---

## 4. 房间管理

### 4.1 RoomManager 类

```javascript
// src/RoomManager.js
class RoomManager {
    constructor() {
        this.rooms = new Map(); // roomId -> Room
    }
    
    // 创建房间
    createRoom(roomId, options = {}) {
        if (this.rooms.has(roomId)) {
            return this.rooms.get(roomId);
        }
        
        const room = {
            id: roomId,
            members: new Set(),
            createdAt: Date.now(),
            maxMembers: options.maxMembers || 10,
            isLocked: false,
            metadata: options.metadata || {}
        };
        
        this.rooms.set(roomId, room);
        console.log(`Room created: ${roomId}`);
        return room;
    }
    
    // 加入房间
    joinRoom(roomId, clientId) {
        let room = this.rooms.get(roomId);
        
        // 房间不存在则创建
        if (!room) {
            room = this.createRoom(roomId);
        }
        
        // 检查房间是否已满
        if (room.members.size >= room.maxMembers) {
            return { success: false, error: 'Room is full' };
        }
        
        // 检查房间是否锁定
        if (room.isLocked) {
            return { success: false, error: 'Room is locked' };
        }
        
        room.members.add(clientId);
        console.log(`Client ${clientId} joined room ${roomId}`);
        
        return {
            success: true,
            room: this.getRoomInfo(roomId)
        };
    }
    
    // 离开房间
    leaveRoom(roomId, clientId) {
        const room = this.rooms.get(roomId);
        if (!room) return;
        
        room.members.delete(clientId);
        console.log(`Client ${clientId} left room ${roomId}`);
        
        // 房间为空则删除
        if (room.members.size === 0) {
            this.rooms.delete(roomId);
            console.log(`Room deleted: ${roomId}`);
        }
    }
    
    // 获取房间
    getRoom(roomId) {
        return this.rooms.get(roomId);
    }
    
    // 获取房间信息 (不包含敏感数据)
    getRoomInfo(roomId) {
        const room = this.rooms.get(roomId);
        if (!room) return null;
        
        return {
            id: room.id,
            memberCount: room.members.size,
            members: Array.from(room.members),
            maxMembers: room.maxMembers,
            isLocked: room.isLocked
        };
    }
    
    // 获取所有房间列表
    getRoomList() {
        const list = [];
        for (const [roomId, room] of this.rooms) {
            list.push({
                id: roomId,
                memberCount: room.members.size,
                maxMembers: room.maxMembers
            });
        }
        return list;
    }
    
    // 锁定/解锁房间
    setRoomLock(roomId, isLocked) {
        const room = this.rooms.get(roomId);
        if (room) {
            room.isLocked = isLocked;
        }
    }
}

module.exports = { RoomManager };
```

---

## 5. 信令消息处理

### 5.1 MessageHandler 类

```javascript
// src/MessageHandler.js
class MessageHandler {
    constructor(server) {
        this.server = server;
    }
    
    handle(clientId, message) {
        const { type } = message;
        
        switch (type) {
            case 'register':
                this.handleRegister(clientId, message);
                break;
            case 'join':
                this.handleJoin(clientId, message);
                break;
            case 'leave':
                this.handleLeave(clientId, message);
                break;
            case 'offer':
                this.handleOffer(clientId, message);
                break;
            case 'answer':
                this.handleAnswer(clientId, message);
                break;
            case 'candidate':
                this.handleCandidate(clientId, message);
                break;
            case 'message':
                this.handleMessage(clientId, message);
                break;
            default:
                console.log(`Unknown message type: ${type}`);
        }
    }
    
    // 用户注册
    handleRegister(clientId, message) {
        const { userId } = message;
        const client = this.server.clients.get(clientId);
        
        if (client) {
            client.userId = userId || clientId;
            
            this.server.sendTo(clientId, {
                type: 'registered',
                userId: client.userId
            });
        }
    }
    
    // 加入房间
    handleJoin(clientId, message) {
        const { roomId } = message;
        const client = this.server.clients.get(clientId);
        
        if (!client) return;
        
        // 如果已在其他房间,先离开
        if (client.roomId) {
            this.handleLeave(clientId, { roomId: client.roomId });
        }
        
        // 加入新房间
        const result = this.server.roomManager.joinRoom(roomId, clientId);
        
        if (result.success) {
            client.roomId = roomId;
            
            // 通知加入者
            this.server.sendTo(clientId, {
                type: 'joined',
                roomId,
                members: result.room.members.filter(id => id !== clientId)
            });
            
            // 通知房间内其他人
            this.server.broadcastToRoom(roomId, {
                type: 'user-joined',
                userId: client.userId,
                clientId
            }, clientId);
        } else {
            this.server.sendTo(clientId, {
                type: 'join-error',
                error: result.error
            });
        }
    }
    
    // 离开房间
    handleLeave(clientId, message) {
        const { roomId } = message;
        const client = this.server.clients.get(clientId);
        
        if (!client || client.roomId !== roomId) return;
        
        this.server.roomManager.leaveRoom(roomId, clientId);
        
        // 通知房间内其他人
        this.server.broadcastToRoom(roomId, {
            type: 'user-left',
            userId: client.userId,
            clientId
        });
        
        client.roomId = null;
        
        this.server.sendTo(clientId, {
            type: 'left',
            roomId
        });
    }
    
    // 处理 Offer
    handleOffer(clientId, message) {
        const { targetId, sdp } = message;
        const client = this.server.clients.get(clientId);
        
        if (!client) return;
        
        this.server.sendTo(targetId, {
            type: 'offer',
            fromId: clientId,
            fromUserId: client.userId,
            sdp
        });
    }
    
    // 处理 Answer
    handleAnswer(clientId, message) {
        const { targetId, sdp } = message;
        const client = this.server.clients.get(clientId);
        
        if (!client) return;
        
        this.server.sendTo(targetId, {
            type: 'answer',
            fromId: clientId,
            fromUserId: client.userId,
            sdp
        });
    }
    
    // 处理 ICE Candidate
    handleCandidate(clientId, message) {
        const { targetId, candidate } = message;
        const client = this.server.clients.get(clientId);
        
        if (!client) return;
        
        this.server.sendTo(targetId, {
            type: 'candidate',
            fromId: clientId,
            candidate
        });
    }
    
    // 处理自定义消息
    handleMessage(clientId, message) {
        const { targetId, content } = message;
        const client = this.server.clients.get(clientId);
        
        if (!client) return;
        
        if (targetId) {
            // 发送给指定用户
            this.server.sendTo(targetId, {
                type: 'message',
                fromId: clientId,
                fromUserId: client.userId,
                content
            });
        } else if (client.roomId) {
            // 广播给房间
            this.server.broadcastToRoom(client.roomId, {
                type: 'message',
                fromId: clientId,
                fromUserId: client.userId,
                content
            }, clientId);
        }
    }
}

module.exports = { MessageHandler };
```

---

## 6. 客户端实现

### 6.1 HTML 页面

```html
<!-- client/index.html -->
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WebRTC Video Chat</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="container">
        <h1>WebRTC Video Chat</h1>
        
        <div class="controls">
            <input type="text" id="roomId" placeholder="房间 ID">
            <button id="joinBtn">加入房间</button>
            <button id="leaveBtn" disabled>离开房间</button>
        </div>
        
        <div class="video-container">
            <div class="video-wrapper">
                <video id="localVideo" autoplay muted playsinline></video>
                <span class="label">本地视频</span>
            </div>
            <div id="remoteVideos"></div>
        </div>
        
        <div class="status">
            <span id="connectionStatus">未连接</span>
        </div>
    </div>
    
    <script src="app.js"></script>
</body>
</html>
```

### 6.2 客户端 JavaScript

```javascript
// client/app.js
class WebRTCClient {
    constructor() {
        this.ws = null;
        this.clientId = null;
        this.roomId = null;
        this.localStream = null;
        this.peerConnections = new Map(); // peerId -> RTCPeerConnection
        
        this.config = {
            iceServers: [
                { urls: 'stun:stun.l.google.com:19302' }
            ]
        };
        
        this.init();
    }
    
    init() {
        // 绑定 UI 事件
        document.getElementById('joinBtn').onclick = () => this.joinRoom();
        document.getElementById('leaveBtn').onclick = () => this.leaveRoom();
        
        // 连接信令服务器
        this.connectSignaling();
    }
    
    // 连接信令服务器
    connectSignaling() {
        const wsUrl = `ws://${window.location.hostname}:8080`;
        this.ws = new WebSocket(wsUrl);
        
        this.ws.onopen = () => {
            console.log('Connected to signaling server');
            this.updateStatus('已连接');
        };
        
        this.ws.onclose = () => {
            console.log('Disconnected from signaling server');
            this.updateStatus('已断开');
            // 尝试重连
            setTimeout(() => this.connectSignaling(), 3000);
        };
        
        this.ws.onerror = (error) => {
            console.error('WebSocket error:', error);
        };
        
        this.ws.onmessage = (event) => {
            const message = JSON.parse(event.data);
            this.handleMessage(message);
        };
    }
    
    // 处理信令消息
    handleMessage(message) {
        console.log('Received:', message.type);
        
        switch (message.type) {
            case 'welcome':
                this.clientId = message.clientId;
                break;
            case 'joined':
                this.handleJoined(message);
                break;
            case 'user-joined':
                this.handleUserJoined(message);
                break;
            case 'user-left':
                this.handleUserLeft(message);
                break;
            case 'offer':
                this.handleOffer(message);
                break;
            case 'answer':
                this.handleAnswer(message);
                break;
            case 'candidate':
                this.handleCandidate(message);
                break;
        }
    }
    
    // 发送信令消息
    send(message) {
        if (this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify(message));
        }
    }
    
    // 加入房间
    async joinRoom() {
        const roomId = document.getElementById('roomId').value.trim();
        if (!roomId) {
            alert('请输入房间 ID');
            return;
        }
        
        // 获取本地媒体流
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
        
        // 发送加入请求
        this.send({
            type: 'join',
            roomId
        });
        
        this.roomId = roomId;
        document.getElementById('joinBtn').disabled = true;
        document.getElementById('leaveBtn').disabled = false;
    }
    
    // 离开房间
    leaveRoom() {
        this.send({
            type: 'leave',
            roomId: this.roomId
        });
        
        // 关闭所有连接
        for (const [peerId, pc] of this.peerConnections) {
            pc.close();
        }
        this.peerConnections.clear();
        
        // 停止本地流
        if (this.localStream) {
            this.localStream.getTracks().forEach(track => track.stop());
            this.localStream = null;
        }
        
        // 清理远程视频
        document.getElementById('remoteVideos').innerHTML = '';
        document.getElementById('localVideo').srcObject = null;
        
        this.roomId = null;
        document.getElementById('joinBtn').disabled = false;
        document.getElementById('leaveBtn').disabled = true;
    }
    
    // 处理加入成功
    handleJoined(message) {
        console.log('Joined room, members:', message.members);
        
        // 向房间内已有成员发起连接
        for (const memberId of message.members) {
            this.createPeerConnection(memberId, true);
        }
    }
    
    // 处理新用户加入
    handleUserJoined(message) {
        console.log('User joined:', message.clientId);
        // 等待新用户发起 Offer
    }
    
    // 处理用户离开
    handleUserLeft(message) {
        console.log('User left:', message.clientId);
        
        const pc = this.peerConnections.get(message.clientId);
        if (pc) {
            pc.close();
            this.peerConnections.delete(message.clientId);
        }
        
        // 移除远程视频
        const videoEl = document.getElementById(`video-${message.clientId}`);
        if (videoEl) {
            videoEl.parentElement.remove();
        }
    }
    
    // 创建 PeerConnection
    async createPeerConnection(peerId, isInitiator) {
        const pc = new RTCPeerConnection(this.config);
        this.peerConnections.set(peerId, pc);
        
        // 添加本地流
        if (this.localStream) {
            this.localStream.getTracks().forEach(track => {
                pc.addTrack(track, this.localStream);
            });
        }
        
        // 处理 ICE Candidate
        pc.onicecandidate = (event) => {
            if (event.candidate) {
                this.send({
                    type: 'candidate',
                    targetId: peerId,
                    candidate: event.candidate
                });
            }
        };
        
        // 处理远程流
        pc.ontrack = (event) => {
            this.addRemoteVideo(peerId, event.streams[0]);
        };
        
        // 处理连接状态变化
        pc.onconnectionstatechange = () => {
            console.log(`Connection state with ${peerId}:`, pc.connectionState);
        };
        
        // 如果是发起方,创建 Offer
        if (isInitiator) {
            try {
                const offer = await pc.createOffer();
                await pc.setLocalDescription(offer);
                
                this.send({
                    type: 'offer',
                    targetId: peerId,
                    sdp: offer
                });
            } catch (error) {
                console.error('Failed to create offer:', error);
            }
        }
        
        return pc;
    }
    
    // 处理 Offer
    async handleOffer(message) {
        const { fromId, sdp } = message;
        
        let pc = this.peerConnections.get(fromId);
        if (!pc) {
            pc = await this.createPeerConnection(fromId, false);
        }
        
        try {
            await pc.setRemoteDescription(new RTCSessionDescription(sdp));
            const answer = await pc.createAnswer();
            await pc.setLocalDescription(answer);
            
            this.send({
                type: 'answer',
                targetId: fromId,
                sdp: answer
            });
        } catch (error) {
            console.error('Failed to handle offer:', error);
        }
    }
    
    // 处理 Answer
    async handleAnswer(message) {
        const { fromId, sdp } = message;
        
        const pc = this.peerConnections.get(fromId);
        if (pc) {
            try {
                await pc.setRemoteDescription(new RTCSessionDescription(sdp));
            } catch (error) {
                console.error('Failed to handle answer:', error);
            }
        }
    }
    
    // 处理 ICE Candidate
    async handleCandidate(message) {
        const { fromId, candidate } = message;
        
        const pc = this.peerConnections.get(fromId);
        if (pc) {
            try {
                await pc.addIceCandidate(new RTCIceCandidate(candidate));
            } catch (error) {
                console.error('Failed to add ICE candidate:', error);
            }
        }
    }
    
    // 添加远程视频
    addRemoteVideo(peerId, stream) {
        let videoEl = document.getElementById(`video-${peerId}`);
        
        if (!videoEl) {
            const wrapper = document.createElement('div');
            wrapper.className = 'video-wrapper';
            
            videoEl = document.createElement('video');
            videoEl.id = `video-${peerId}`;
            videoEl.autoplay = true;
            videoEl.playsinline = true;
            
            const label = document.createElement('span');
            label.className = 'label';
            label.textContent = `远程: ${peerId.slice(0, 8)}`;
            
            wrapper.appendChild(videoEl);
            wrapper.appendChild(label);
            document.getElementById('remoteVideos').appendChild(wrapper);
        }
        
        videoEl.srcObject = stream;
    }
    
    // 更新状态显示
    updateStatus(status) {
        document.getElementById('connectionStatus').textContent = status;
    }
}

// 启动客户端
const client = new WebRTCClient();
```

### 6.3 CSS 样式

```css
/* client/style.css */
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
    max-width: 1200px;
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

.video-container {
    display: flex;
    flex-wrap: wrap;
    gap: 20px;
    justify-content: center;
}

.video-wrapper {
    position: relative;
    background: #16213e;
    border-radius: 10px;
    overflow: hidden;
}

video {
    width: 400px;
    height: 300px;
    object-fit: cover;
}

.label {
    position: absolute;
    bottom: 10px;
    left: 10px;
    background: rgba(0, 0, 0, 0.7);
    padding: 5px 10px;
    border-radius: 5px;
    font-size: 14px;
}

.status {
    text-align: center;
    margin-top: 20px;
    color: #888;
}

#remoteVideos {
    display: flex;
    flex-wrap: wrap;
    gap: 20px;
}
```

---

## 7. 完整代码

### 7.1 工具函数

```javascript
// src/utils.js
function generateId(length = 8) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let result = '';
    for (let i = 0; i < length; i++) {
        result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
}

function formatTime(timestamp) {
    return new Date(timestamp).toISOString();
}

module.exports = { generateId, formatTime };
```

---

## 8. 部署与测试

### 8.1 本地运行

```bash
# 安装依赖
npm install

# 启动服务器
npm start

# 开发模式 (自动重启)
npm run dev
```

### 8.2 测试步骤

```
1. 启动信令服务器
   npm start

2. 启动静态文件服务器 (客户端)
   cd client
   npx http-server -p 3000

3. 打开两个浏览器窗口
   http://localhost:3000

4. 两个窗口输入相同的房间 ID
   点击"加入房间"

5. 允许摄像头/麦克风权限

6. 观察视频通话是否建立
```

### 8.3 生产部署

```javascript
// 使用 HTTPS (生产环境必需)
const https = require('https');
const fs = require('fs');

const server = https.createServer({
    cert: fs.readFileSync('/path/to/cert.pem'),
    key: fs.readFileSync('/path/to/key.pem')
});

// 使用 wss:// 连接
const wss = new WebSocket.Server({ server });
```

---

## 9. 总结

### 9.1 核心要点

| 组件 | 功能 |
|------|------|
| WebSocket | 实时双向通信 |
| RoomManager | 房间创建/加入/离开 |
| MessageHandler | 信令消息路由 |
| 客户端 | PeerConnection 管理 |

### 9.2 扩展建议

```
可扩展功能:
1. 用户认证 (JWT)
2. 房间密码
3. 屏幕共享
4. 文字聊天
5. 录制功能
6. Redis 集群支持
```

### 9.3 下一篇预告

在下一篇文章中,我们将深入探讨 SFU 架构。

---

## 参考资料

1. [ws - WebSocket library](https://github.com/websockets/ws)
2. [WebRTC API](https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API)

---

> 作者: WebRTC 技术专栏  
> 系列: 工程实践 (1/5)  
> 上一篇: [Simulcast 与 SVC](../part4-codec/20-simulcast-svc.md)  
> 下一篇: [WebRTC SFU 架构详解](./22-sfu-architecture.md)
