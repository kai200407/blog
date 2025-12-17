---
title: "写一个最简单的 WebRTC Demo（实操篇）"
description: "1. [项目概述](#1-项目概述)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 3
---

> 本文是 WebRTC 系列专栏的第三篇，我们将动手实践，从零开始构建一个完整的 WebRTC 音视频通话 Demo。通过这个实战项目，你将深入理解 WebRTC 的工作流程。

---

## 目录

1. [项目概述](#1-项目概述)
2. [获取摄像头与麦克风](#2-获取摄像头与麦克风)
3. [建立 RTCPeerConnection](#3-建立-rtcpeerconnection)
4. [实现完整的 P2P 音视频通话](#4-实现完整的-p2p-音视频通话)
5. [运行与测试](#5-运行与测试)
6. [常见问题与调试](#6-常见问题与调试)
7. [总结](#7-总结)

---

## 1. 项目概述

### 1.1 我们要做什么？

我们将构建一个 **1 对 1 的实时音视频通话应用**，包含以下功能：

- 获取本地摄像头和麦克风
- 建立 P2P 连接
- 实现双向音视频通话
- 支持挂断功能

### 1.2 技术栈

| 组件 | 技术选型 |
|------|---------|
| 前端 | 原生 HTML/CSS/JavaScript |
| 信令服务器 | Node.js + WebSocket |
| WebRTC | 浏览器原生 API |

### 1.3 项目结构

```
webrtc-demo/
├── server/
│   ├── package.json
│   └── server.js          # 信令服务器
├── client/
│   ├── index.html         # 页面结构
│   ├── style.css          # 样式
│   └── main.js            # WebRTC 逻辑
└── README.md
```

---

## 2. 获取摄像头与麦克风

### 2.1 基础 API：getUserMedia

`getUserMedia` 是获取媒体设备的核心 API。

```javascript
// 最简单的用法
async function getLocalStream() {
    try {
        const stream = await navigator.mediaDevices.getUserMedia({
            video: true,
            audio: true
        });
        return stream;
    } catch (error) {
        console.error('获取媒体设备失败:', error);
        throw error;
    }
}
```

### 2.2 处理权限和错误

```javascript
async function getLocalStream() {
    // 检查浏览器支持
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error('浏览器不支持 getUserMedia');
    }

    try {
        const stream = await navigator.mediaDevices.getUserMedia({
            video: true,
            audio: true
        });
        return stream;
    } catch (error) {
        // 处理不同类型的错误
        switch (error.name) {
            case 'NotAllowedError':
                throw new Error('用户拒绝了摄像头/麦克风权限');
            case 'NotFoundError':
                throw new Error('找不到摄像头或麦克风设备');
            case 'NotReadableError':
                throw new Error('设备被其他应用占用');
            case 'OverconstrainedError':
                throw new Error('设备不满足指定的约束条件');
            default:
                throw error;
        }
    }
}
```

### 2.3 高级约束配置

```javascript
const constraints = {
    video: {
        width: { min: 640, ideal: 1280, max: 1920 },
        height: { min: 480, ideal: 720, max: 1080 },
        frameRate: { ideal: 30 },
        facingMode: 'user'  // 前置摄像头
    },
    audio: {
        echoCancellation: true,   // 回声消除
        noiseSuppression: true,   // 噪声抑制
        autoGainControl: true     // 自动增益
    }
};

const stream = await navigator.mediaDevices.getUserMedia(constraints);
```

### 2.4 显示本地视频

```html
<video id="localVideo" autoplay muted playsinline></video>
```

```javascript
const localVideo = document.getElementById('localVideo');
const stream = await getLocalStream();

// 将媒体流绑定到 video 元素
localVideo.srcObject = stream;
```

> ⚠️ **注意**：本地视频需要设置 `muted` 属性，否则会产生回声。

---

## 3. 建立 RTCPeerConnection

### 3.1 创建 PeerConnection

```javascript
const configuration = {
    iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' }
    ]
};

const peerConnection = new RTCPeerConnection(configuration);
```

### 3.2 添加本地媒体轨道

```javascript
// 将本地媒体流的所有轨道添加到 PeerConnection
localStream.getTracks().forEach(track => {
    peerConnection.addTrack(track, localStream);
});
```

### 3.3 处理远端媒体流

```javascript
const remoteVideo = document.getElementById('remoteVideo');

peerConnection.ontrack = (event) => {
    // 获取远端媒体流
    const [remoteStream] = event.streams;
    remoteVideo.srcObject = remoteStream;
};
```

### 3.4 Offer/Answer 交换

```javascript
// 发起方：创建 Offer
async function createOffer() {
    const offer = await peerConnection.createOffer();
    await peerConnection.setLocalDescription(offer);
    
    // 通过信令服务器发送 Offer
    sendToSignalingServer({
        type: 'offer',
        sdp: offer.sdp
    });
}

// 接收方：处理 Offer 并创建 Answer
async function handleOffer(offer) {
    await peerConnection.setRemoteDescription(
        new RTCSessionDescription(offer)
    );
    
    const answer = await peerConnection.createAnswer();
    await peerConnection.setLocalDescription(answer);
    
    // 通过信令服务器发送 Answer
    sendToSignalingServer({
        type: 'answer',
        sdp: answer.sdp
    });
}

// 发起方：处理 Answer
async function handleAnswer(answer) {
    await peerConnection.setRemoteDescription(
        new RTCSessionDescription(answer)
    );
}
```

### 3.5 ICE 候选交换

```javascript
// 收集 ICE 候选
peerConnection.onicecandidate = (event) => {
    if (event.candidate) {
        sendToSignalingServer({
            type: 'candidate',
            candidate: event.candidate
        });
    }
};

// 添加远端 ICE 候选
async function handleCandidate(candidate) {
    await peerConnection.addIceCandidate(
        new RTCIceCandidate(candidate)
    );
}
```

---

## 4. 实现完整的 P2P 音视频通话

现在让我们把所有部分组合起来，创建一个完整的项目。

### 4.1 信令服务器 (server/server.js)

```javascript
const WebSocket = require('ws');
const http = require('http');

// 创建 HTTP 服务器
const server = http.createServer();

// 创建 WebSocket 服务器
const wss = new WebSocket.Server({ server });

// 存储所有连接的客户端
const clients = new Map();
let clientIdCounter = 0;

wss.on('connection', (ws) => {
    // 为每个客户端分配唯一 ID
    const clientId = ++clientIdCounter;
    clients.set(clientId, ws);
    
    console.log(`客户端 ${clientId} 已连接，当前在线: ${clients.size}`);
    
    // 通知客户端其 ID
    ws.send(JSON.stringify({
        type: 'welcome',
        clientId: clientId,
        clientCount: clients.size
    }));
    
    // 通知其他客户端有新用户加入
    broadcastExcept(clientId, {
        type: 'user-joined',
        clientId: clientId,
        clientCount: clients.size
    });

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);
            console.log(`收到来自客户端 ${clientId} 的消息:`, data.type);
            
            // 转发消息给目标客户端
            if (data.target) {
                const targetWs = clients.get(data.target);
                if (targetWs && targetWs.readyState === WebSocket.OPEN) {
                    targetWs.send(JSON.stringify({
                        ...data,
                        from: clientId
                    }));
                }
            } else {
                // 广播给所有其他客户端
                broadcastExcept(clientId, {
                    ...data,
                    from: clientId
                });
            }
        } catch (error) {
            console.error('消息解析错误:', error);
        }
    });

    ws.on('close', () => {
        clients.delete(clientId);
        console.log(`客户端 ${clientId} 已断开，当前在线: ${clients.size}`);
        
        // 通知其他客户端
        broadcastExcept(clientId, {
            type: 'user-left',
            clientId: clientId,
            clientCount: clients.size
        });
    });

    ws.on('error', (error) => {
        console.error(`客户端 ${clientId} 错误:`, error);
    });
});

// 广播消息给除指定客户端外的所有客户端
function broadcastExcept(excludeId, message) {
    clients.forEach((ws, id) => {
        if (id !== excludeId && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify(message));
        }
    });
}

const PORT = process.env.PORT || 8080;
server.listen(PORT, () => {
    console.log(`信令服务器运行在 ws://localhost:${PORT}`);
});
```

### 4.2 package.json (server/package.json)

```json
{
  "name": "webrtc-signaling-server",
  "version": "1.0.0",
  "description": "WebRTC 信令服务器",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "ws": "^8.14.2"
  }
}
```

### 4.3 HTML 页面 (client/index.html)

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WebRTC 视频通话 Demo</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="container">
        <h1>WebRTC 视频通话</h1>
        
        <!-- 状态显示 -->
        <div class="status-bar">
            <span id="connectionStatus">未连接</span>
            <span id="clientInfo"></span>
        </div>
        
        <!-- 视频区域 -->
        <div class="video-container">
            <div class="video-wrapper">
                <video id="localVideo" autoplay muted playsinline></video>
                <span class="video-label">本地视频</span>
            </div>
            <div class="video-wrapper">
                <video id="remoteVideo" autoplay playsinline></video>
                <span class="video-label">远端视频</span>
            </div>
        </div>
        
        <!-- 控制按钮 -->
        <div class="controls">
            <button id="startBtn" class="btn btn-primary">开启摄像头</button>
            <button id="callBtn" class="btn btn-success" disabled>发起通话</button>
            <button id="hangupBtn" class="btn btn-danger" disabled>挂断</button>
        </div>
        
        <!-- 媒体控制 -->
        <div class="media-controls">
            <button id="toggleVideoBtn" class="btn btn-secondary" disabled>关闭视频</button>
            <button id="toggleAudioBtn" class="btn btn-secondary" disabled>静音</button>
        </div>
        
        <!-- 日志区域 -->
        <div class="log-container">
            <h3>连接日志</h3>
            <div id="logArea"></div>
        </div>
    </div>
    
    <script src="main.js"></script>
</body>
</html>
```

### 4.4 CSS 样式 (client/style.css)

```css
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
    background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
    min-height: 100vh;
    color: #fff;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
}

h1 {
    text-align: center;
    margin-bottom: 20px;
    font-size: 2rem;
    background: linear-gradient(90deg, #00d2ff, #3a7bd5);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
}

/* 状态栏 */
.status-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: rgba(255, 255, 255, 0.1);
    padding: 10px 20px;
    border-radius: 10px;
    margin-bottom: 20px;
}

#connectionStatus {
    padding: 5px 15px;
    border-radius: 20px;
    background: #e74c3c;
    font-size: 0.9rem;
}

#connectionStatus.connected {
    background: #27ae60;
}

#connectionStatus.calling {
    background: #f39c12;
}

/* 视频容器 */
.video-container {
    display: flex;
    gap: 20px;
    justify-content: center;
    flex-wrap: wrap;
    margin-bottom: 20px;
}

.video-wrapper {
    position: relative;
    background: #000;
    border-radius: 15px;
    overflow: hidden;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
}

.video-wrapper video {
    width: 480px;
    height: 360px;
    object-fit: cover;
    display: block;
}

.video-label {
    position: absolute;
    bottom: 10px;
    left: 10px;
    background: rgba(0, 0, 0, 0.7);
    padding: 5px 15px;
    border-radius: 20px;
    font-size: 0.85rem;
}

/* 按钮样式 */
.controls, .media-controls {
    display: flex;
    gap: 15px;
    justify-content: center;
    margin-bottom: 15px;
}

.btn {
    padding: 12px 30px;
    border: none;
    border-radius: 25px;
    font-size: 1rem;
    cursor: pointer;
    transition: all 0.3s ease;
    font-weight: 600;
}

.btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
}

.btn-primary {
    background: linear-gradient(90deg, #00d2ff, #3a7bd5);
    color: #fff;
}

.btn-primary:hover:not(:disabled) {
    transform: translateY(-2px);
    box-shadow: 0 5px 20px rgba(0, 210, 255, 0.4);
}

.btn-success {
    background: linear-gradient(90deg, #11998e, #38ef7d);
    color: #fff;
}

.btn-success:hover:not(:disabled) {
    transform: translateY(-2px);
    box-shadow: 0 5px 20px rgba(56, 239, 125, 0.4);
}

.btn-danger {
    background: linear-gradient(90deg, #eb3349, #f45c43);
    color: #fff;
}

.btn-danger:hover:not(:disabled) {
    transform: translateY(-2px);
    box-shadow: 0 5px 20px rgba(235, 51, 73, 0.4);
}

.btn-secondary {
    background: rgba(255, 255, 255, 0.2);
    color: #fff;
}

.btn-secondary:hover:not(:disabled) {
    background: rgba(255, 255, 255, 0.3);
}

.btn-secondary.active {
    background: #e74c3c;
}

/* 日志区域 */
.log-container {
    background: rgba(0, 0, 0, 0.3);
    border-radius: 15px;
    padding: 20px;
    margin-top: 20px;
}

.log-container h3 {
    margin-bottom: 15px;
    font-size: 1.1rem;
    color: #aaa;
}

#logArea {
    height: 200px;
    overflow-y: auto;
    font-family: 'Monaco', 'Menlo', monospace;
    font-size: 0.85rem;
    line-height: 1.6;
}

#logArea .log-item {
    padding: 3px 0;
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
}

#logArea .log-time {
    color: #888;
    margin-right: 10px;
}

#logArea .log-info { color: #3498db; }
#logArea .log-success { color: #27ae60; }
#logArea .log-warning { color: #f39c12; }
#logArea .log-error { color: #e74c3c; }

/* 响应式设计 */
@media (max-width: 768px) {
    .video-wrapper video {
        width: 100%;
        height: auto;
        aspect-ratio: 4/3;
    }
    
    .controls, .media-controls {
        flex-wrap: wrap;
    }
    
    .btn {
        flex: 1;
        min-width: 120px;
    }
}
```

### 4.5 JavaScript 主逻辑 (client/main.js)

```javascript
// ==================== 配置 ====================
const SIGNALING_SERVER_URL = 'ws://localhost:8080';

const ICE_SERVERS = {
    iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' },
        { urls: 'stun:stun2.l.google.com:19302' }
    ]
};

// ==================== 全局变量 ====================
let localStream = null;
let peerConnection = null;
let signalingSocket = null;
let myClientId = null;
let remoteClientId = null;
let isVideoEnabled = true;
let isAudioEnabled = true;

// ==================== DOM 元素 ====================
const localVideo = document.getElementById('localVideo');
const remoteVideo = document.getElementById('remoteVideo');
const startBtn = document.getElementById('startBtn');
const callBtn = document.getElementById('callBtn');
const hangupBtn = document.getElementById('hangupBtn');
const toggleVideoBtn = document.getElementById('toggleVideoBtn');
const toggleAudioBtn = document.getElementById('toggleAudioBtn');
const connectionStatus = document.getElementById('connectionStatus');
const clientInfo = document.getElementById('clientInfo');
const logArea = document.getElementById('logArea');

// ==================== 日志函数 ====================
function log(message, type = 'info') {
    const time = new Date().toLocaleTimeString();
    const logItem = document.createElement('div');
    logItem.className = 'log-item';
    logItem.innerHTML = `<span class="log-time">[${time}]</span><span class="log-${type}">${message}</span>`;
    logArea.appendChild(logItem);
    logArea.scrollTop = logArea.scrollHeight;
    console.log(`[${type.toUpperCase()}] ${message}`);
}

// ==================== 状态更新 ====================
function updateStatus(status, className = '') {
    connectionStatus.textContent = status;
    connectionStatus.className = className;
}

// ==================== 信令服务器连接 ====================
function connectSignalingServer() {
    log('正在连接信令服务器...');
    
    signalingSocket = new WebSocket(SIGNALING_SERVER_URL);
    
    signalingSocket.onopen = () => {
        log('信令服务器连接成功', 'success');
        updateStatus('已连接', 'connected');
    };
    
    signalingSocket.onclose = () => {
        log('信令服务器连接断开', 'warning');
        updateStatus('未连接');
        // 尝试重连
        setTimeout(connectSignalingServer, 3000);
    };
    
    signalingSocket.onerror = (error) => {
        log('信令服务器连接错误', 'error');
    };
    
    signalingSocket.onmessage = async (event) => {
        const message = JSON.parse(event.data);
        await handleSignalingMessage(message);
    };
}

// ==================== 处理信令消息 ====================
async function handleSignalingMessage(message) {
    log(`收到信令消息: ${message.type}`);
    
    switch (message.type) {
        case 'welcome':
            myClientId = message.clientId;
            clientInfo.textContent = `我的 ID: ${myClientId} | 在线人数: ${message.clientCount}`;
            log(`分配到客户端 ID: ${myClientId}`, 'success');
            break;
            
        case 'user-joined':
            clientInfo.textContent = `我的 ID: ${myClientId} | 在线人数: ${message.clientCount}`;
            log(`用户 ${message.clientId} 加入`, 'info');
            if (localStream) {
                callBtn.disabled = false;
            }
            break;
            
        case 'user-left':
            clientInfo.textContent = `我的 ID: ${myClientId} | 在线人数: ${message.clientCount}`;
            log(`用户 ${message.clientId} 离开`, 'warning');
            if (message.clientId === remoteClientId) {
                hangup();
            }
            break;
            
        case 'offer':
            log(`收到来自用户 ${message.from} 的通话请求`, 'info');
            remoteClientId = message.from;
            await handleOffer(message);
            break;
            
        case 'answer':
            log(`收到来自用户 ${message.from} 的应答`, 'success');
            await handleAnswer(message);
            break;
            
        case 'candidate':
            await handleCandidate(message);
            break;
            
        case 'hangup':
            log(`用户 ${message.from} 挂断了通话`, 'warning');
            hangup();
            break;
    }
}

// ==================== 发送信令消息 ====================
function sendSignalingMessage(message) {
    if (signalingSocket && signalingSocket.readyState === WebSocket.OPEN) {
        signalingSocket.send(JSON.stringify(message));
    }
}

// ==================== 获取本地媒体流 ====================
async function startLocalStream() {
    try {
        log('正在获取摄像头和麦克风...');
        
        localStream = await navigator.mediaDevices.getUserMedia({
            video: {
                width: { ideal: 1280 },
                height: { ideal: 720 },
                frameRate: { ideal: 30 }
            },
            audio: {
                echoCancellation: true,
                noiseSuppression: true,
                autoGainControl: true
            }
        });
        
        localVideo.srcObject = localStream;
        
        log('摄像头和麦克风获取成功', 'success');
        
        // 更新按钮状态
        startBtn.disabled = true;
        callBtn.disabled = false;
        toggleVideoBtn.disabled = false;
        toggleAudioBtn.disabled = false;
        
    } catch (error) {
        log(`获取媒体设备失败: ${error.message}`, 'error');
    }
}

// ==================== 创建 PeerConnection ====================
function createPeerConnection() {
    log('创建 PeerConnection...');
    
    peerConnection = new RTCPeerConnection(ICE_SERVERS);
    
    // 添加本地轨道
    localStream.getTracks().forEach(track => {
        peerConnection.addTrack(track, localStream);
        log(`添加本地轨道: ${track.kind}`);
    });
    
    // ICE 候选事件
    peerConnection.onicecandidate = (event) => {
        if (event.candidate) {
            log(`发送 ICE 候选: ${event.candidate.type || 'unknown'}`);
            sendSignalingMessage({
                type: 'candidate',
                target: remoteClientId,
                candidate: event.candidate
            });
        }
    };
    
    // ICE 连接状态变化
    peerConnection.oniceconnectionstatechange = () => {
        const state = peerConnection.iceConnectionState;
        log(`ICE 连接状态: ${state}`);
        
        switch (state) {
            case 'checking':
                updateStatus('正在连接...', 'calling');
                break;
            case 'connected':
            case 'completed':
                updateStatus('通话中', 'connected');
                log('P2P 连接建立成功！', 'success');
                break;
            case 'failed':
                log('连接失败', 'error');
                hangup();
                break;
            case 'disconnected':
                log('连接断开', 'warning');
                break;
        }
    };
    
    // 连接状态变化
    peerConnection.onconnectionstatechange = () => {
        log(`连接状态: ${peerConnection.connectionState}`);
    };
    
    // 收到远端轨道
    peerConnection.ontrack = (event) => {
        log(`收到远端轨道: ${event.track.kind}`, 'success');
        const [remoteStream] = event.streams;
        remoteVideo.srcObject = remoteStream;
    };
    
    return peerConnection;
}

// ==================== 发起通话 ====================
async function call() {
    log('发起通话...');
    
    createPeerConnection();
    
    try {
        const offer = await peerConnection.createOffer();
        await peerConnection.setLocalDescription(offer);
        
        log('发送 Offer...');
        sendSignalingMessage({
            type: 'offer',
            sdp: offer.sdp
        });
        
        updateStatus('等待应答...', 'calling');
        callBtn.disabled = true;
        hangupBtn.disabled = false;
        
    } catch (error) {
        log(`创建 Offer 失败: ${error.message}`, 'error');
    }
}

// ==================== 处理 Offer ====================
async function handleOffer(message) {
    createPeerConnection();
    
    try {
        await peerConnection.setRemoteDescription(
            new RTCSessionDescription({
                type: 'offer',
                sdp: message.sdp
            })
        );
        
        const answer = await peerConnection.createAnswer();
        await peerConnection.setLocalDescription(answer);
        
        log('发送 Answer...');
        sendSignalingMessage({
            type: 'answer',
            target: remoteClientId,
            sdp: answer.sdp
        });
        
        callBtn.disabled = true;
        hangupBtn.disabled = false;
        
    } catch (error) {
        log(`处理 Offer 失败: ${error.message}`, 'error');
    }
}

// ==================== 处理 Answer ====================
async function handleAnswer(message) {
    try {
        await peerConnection.setRemoteDescription(
            new RTCSessionDescription({
                type: 'answer',
                sdp: message.sdp
            })
        );
        log('Answer 处理完成', 'success');
    } catch (error) {
        log(`处理 Answer 失败: ${error.message}`, 'error');
    }
}

// ==================== 处理 ICE 候选 ====================
async function handleCandidate(message) {
    try {
        if (peerConnection && message.candidate) {
            await peerConnection.addIceCandidate(
                new RTCIceCandidate(message.candidate)
            );
            log('添加 ICE 候选成功');
        }
    } catch (error) {
        log(`添加 ICE 候选失败: ${error.message}`, 'error');
    }
}

// ==================== 挂断 ====================
function hangup() {
    log('挂断通话');
    
    // 通知对方
    if (remoteClientId) {
        sendSignalingMessage({
            type: 'hangup',
            target: remoteClientId
        });
    }
    
    // 关闭 PeerConnection
    if (peerConnection) {
        peerConnection.close();
        peerConnection = null;
    }
    
    // 清除远端视频
    remoteVideo.srcObject = null;
    remoteClientId = null;
    
    // 更新按钮状态
    callBtn.disabled = false;
    hangupBtn.disabled = true;
    
    updateStatus('已连接', 'connected');
}

// ==================== 切换视频 ====================
function toggleVideo() {
    if (localStream) {
        const videoTrack = localStream.getVideoTracks()[0];
        if (videoTrack) {
            isVideoEnabled = !isVideoEnabled;
            videoTrack.enabled = isVideoEnabled;
            toggleVideoBtn.textContent = isVideoEnabled ? '关闭视频' : '开启视频';
            toggleVideoBtn.classList.toggle('active', !isVideoEnabled);
            log(`视频已${isVideoEnabled ? '开启' : '关闭'}`);
        }
    }
}

// ==================== 切换音频 ====================
function toggleAudio() {
    if (localStream) {
        const audioTrack = localStream.getAudioTracks()[0];
        if (audioTrack) {
            isAudioEnabled = !isAudioEnabled;
            audioTrack.enabled = isAudioEnabled;
            toggleAudioBtn.textContent = isAudioEnabled ? '静音' : '取消静音';
            toggleAudioBtn.classList.toggle('active', !isAudioEnabled);
            log(`音频已${isAudioEnabled ? '开启' : '静音'}`);
        }
    }
}

// ==================== 事件绑定 ====================
startBtn.addEventListener('click', startLocalStream);
callBtn.addEventListener('click', call);
hangupBtn.addEventListener('click', hangup);
toggleVideoBtn.addEventListener('click', toggleVideo);
toggleAudioBtn.addEventListener('click', toggleAudio);

// ==================== 初始化 ====================
window.addEventListener('load', () => {
    log('WebRTC Demo 初始化...');
    connectSignalingServer();
});

// 页面关闭时清理
window.addEventListener('beforeunload', () => {
    if (localStream) {
        localStream.getTracks().forEach(track => track.stop());
    }
    if (peerConnection) {
        peerConnection.close();
    }
    if (signalingSocket) {
        signalingSocket.close();
    }
});
```

---

## 5. 运行与测试

### 5.1 启动信令服务器

```bash
# 进入 server 目录
cd server

# 安装依赖
npm install

# 启动服务器
npm start
```

输出：
```
信令服务器运行在 ws://localhost:8080
```

### 5.2 启动客户端

由于需要访问摄像头，浏览器要求使用 HTTPS 或 localhost。我们可以使用简单的 HTTP 服务器：

```bash
# 进入 client 目录
cd client

# 使用 Python 启动 HTTP 服务器
python3 -m http.server 3000

# 或使用 Node.js 的 http-server
npx http-server -p 3000
```

### 5.3 测试步骤

1. **打开两个浏览器窗口**（或两台设备）
2. 访问 `http://localhost:3000`
3. 在两个窗口中分别点击「开启摄像头」
4. 在其中一个窗口点击「发起通话」
5. 观察连接建立过程和视频通话效果

### 5.4 测试检查清单

| 检查项 | 预期结果 |
|--------|---------|
| 本地视频显示 | ✅ 能看到自己的摄像头画面 |
| 信令连接 | ✅ 状态显示「已连接」 |
| 发起通话 | ✅ 状态变为「等待应答」 |
| 连接建立 | ✅ 状态变为「通话中」 |
| 远端视频 | ✅ 能看到对方的视频 |
| 音频通话 | ✅ 能听到对方的声音 |
| 挂断功能 | ✅ 能正常挂断并重新通话 |

---

## 6. 常见问题与调试

### 6.1 调试工具

#### Chrome WebRTC Internals

在 Chrome 浏览器中访问：
```
chrome://webrtc-internals
```

可以查看：
- PeerConnection 状态
- ICE 候选收集情况
- SDP 内容
- 媒体统计信息

#### 获取连接统计

```javascript
async function getStats() {
    if (peerConnection) {
        const stats = await peerConnection.getStats();
        stats.forEach(report => {
            if (report.type === 'inbound-rtp' && report.kind === 'video') {
                console.log('视频接收统计:', {
                    packetsReceived: report.packetsReceived,
                    bytesReceived: report.bytesReceived,
                    packetsLost: report.packetsLost,
                    framesDecoded: report.framesDecoded
                });
            }
        });
    }
}
```

### 6.2 常见问题

#### 问题 1：摄像头权限被拒绝

**现象**：点击「开启摄像头」后报错

**解决方案**：
1. 检查浏览器地址栏的权限图标
2. 确保使用 `localhost` 或 `HTTPS`
3. 在浏览器设置中重置摄像头权限

#### 问题 2：ICE 连接失败

**现象**：状态一直显示「正在连接」

**可能原因**：
- 防火墙阻止 UDP 流量
- NAT 类型不兼容
- STUN 服务器不可用

**解决方案**：
```javascript
// 添加 TURN 服务器作为备选
const ICE_SERVERS = {
    iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        {
            urls: 'turn:your-turn-server.com:3478',
            username: 'user',
            credential: 'password'
        }
    ]
};
```

#### 问题 3：只有单向视频

**现象**：一方能看到对方，但对方看不到自己

**可能原因**：
- 轨道未正确添加
- `ontrack` 事件未触发

**调试方法**：
```javascript
// 检查轨道状态
console.log('发送器:', peerConnection.getSenders());
console.log('接收器:', peerConnection.getReceivers());
```

#### 问题 4：音频有回声

**现象**：通话时听到自己的声音

**解决方案**：
1. 确保本地视频设置了 `muted` 属性
2. 使用耳机进行测试
3. 检查 `echoCancellation` 是否启用

```html
<video id="localVideo" autoplay muted playsinline></video>
```

### 6.3 网络调试

```javascript
// 监控 ICE 候选收集
peerConnection.onicegatheringstatechange = () => {
    console.log('ICE 收集状态:', peerConnection.iceGatheringState);
};

// 打印所有收集到的候选
peerConnection.onicecandidate = (event) => {
    if (event.candidate) {
        console.log('ICE 候选:', {
            type: event.candidate.type,
            protocol: event.candidate.protocol,
            address: event.candidate.address,
            port: event.candidate.port
        });
    } else {
        console.log('ICE 候选收集完成');
    }
};
```

---

## 7. 总结

### 本文要点回顾

| 步骤 | 关键 API |
|------|---------|
| 获取媒体流 | `navigator.mediaDevices.getUserMedia()` |
| 创建连接 | `new RTCPeerConnection(config)` |
| 添加轨道 | `pc.addTrack(track, stream)` |
| 创建 Offer | `pc.createOffer()` |
| 设置描述 | `pc.setLocalDescription()` / `pc.setRemoteDescription()` |
| ICE 候选 | `pc.onicecandidate` / `pc.addIceCandidate()` |
| 接收媒体 | `pc.ontrack` |

### 完整流程图

```
┌─────────────────────────────────────────────────────────────────┐
│                        WebRTC 通话流程                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. getUserMedia()     获取本地媒体流                            │
│          ↓                                                      │
│  2. new RTCPeerConnection()  创建连接对象                        │
│          ↓                                                      │
│  3. addTrack()         添加本地轨道                              │
│          ↓                                                      │
│  4. createOffer()      创建 Offer                               │
│          ↓                                                      │
│  5. setLocalDescription()  设置本地描述                          │
│          ↓                                                      │
│  6. 信令服务器          交换 Offer/Answer/ICE                    │
│          ↓                                                      │
│  7. setRemoteDescription()  设置远端描述                         │
│          ↓                                                      │
│  8. addIceCandidate()  添加 ICE 候选                            │
│          ↓                                                      │
│  9. ontrack            接收远端媒体                              │
│          ↓                                                      │
│  10. 通话建立！                                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 下一篇预告

在下一篇文章中，我们将深入探讨 **WebRTC 的三个关键技术**：
- NAT 穿透原理与 ICE 框架
- 音视频实时传输协议（RTP/RTCP/SRTP）
- 回声消除、抗抖动与带宽控制

---

## 参考资料

1. [MDN - WebRTC API](https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API)
2. [WebRTC Samples](https://webrtc.github.io/samples/)
3. [Getting Started with WebRTC](https://webrtc.org/getting-started/overview)
4. [WebRTC for the Curious](https://webrtcforthecurious.com/)

---

> **作者**：WebRTC 技术专栏  
> **系列**：WebRTC 基础与快速入门（3/5）  
> **上一篇**：[WebRTC 架构概览（整体框架篇）](./02-webrtc-architecture.md)  
> **下一篇**：[WebRTC 的三个关键技术（理论强化篇）](./04-webrtc-key-technologies.md)
