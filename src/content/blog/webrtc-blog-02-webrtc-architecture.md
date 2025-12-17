---
title: "WebRTC 架构概览（整体框架篇）"
description: "1. [WebRTC 在浏览器中的架构](#1-webrtc-在浏览器中的架构)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 2
---

> 本文是 WebRTC 系列专栏的第二篇，将深入剖析 WebRTC 的整体架构，包括浏览器中的实现架构、API 体系、信令流程以及底层媒体引擎 libwebrtc 的结构。

---

## 目录

1. [WebRTC 在浏览器中的架构](#1-webrtc-在浏览器中的架构)
2. [API 体系详解](#2-api-体系详解)
3. [WebRTC 信令流程概览](#3-webrtc-信令流程概览)
4. [媒体引擎结构（libwebrtc 概览）](#4-媒体引擎结构libwebrtc-概览)
5. [总结](#5-总结)

---

## 1. WebRTC 在浏览器中的架构

### 1.1 整体架构图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            Web Application                               │
│                         (JavaScript / HTML)                              │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           WebRTC JavaScript API                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────┐  │
│  │ getUserMedia()  │  │RTCPeerConnection│  │   RTCDataChannel        │  │
│  │ getDisplayMedia │  │                 │  │                         │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         WebRTC Native C++ API                            │
│                        (libwebrtc / webrtc.org)                          │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                        Session Management                          │  │
│  │              (Offe/Answer, ICE, SRTP Key Exchange)                │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────┐          ┌─────────────────────────────┐  │
│  │      Voice Engine       │          │       Video Engine          │  │
│  │  ┌─────────────────┐    │          │  ┌─────────────────────┐    │  │
│  │  │  Audio Codecs   │    │          │  │   Video Codecs      │    │  │
│  │  │  (Opus, G.711)  │    │          │  │  (VP8, VP9, H.264)  │    │  │
│  │  ├─────────────────┤    │          │  ├─────────────────────┤    │  │
│  │  │  Echo Cancel    │    │          │  │  Video Processing   │    │  │
│  │  │  Noise Suppress │    │          │  │  (Scaling, FEC)     │    │  │
│  │  ├─────────────────┤    │          │  ├─────────────────────┤    │  │
│  │  │  Jitter Buffer  │    │          │  │  Jitter Buffer      │    │  │
│  │  └─────────────────┘    │          │  └─────────────────────┘    │  │
│  └─────────────────────────┘          └─────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                         Transport Layer                            │  │
│  │         (ICE / STUN / TURN / DTLS / SRTP / SCTP)                  │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          Operating System                                │
│              (Audio/Video Capture, Network Socket, etc.)                 │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 架构层次说明

#### 第一层：Web 应用层

开发者编写的 JavaScript 代码，通过 WebRTC API 实现实时通信功能。

```javascript
// 应用层代码示例
const pc = new RTCPeerConnection(config);
const stream = await navigator.mediaDevices.getUserMedia({video: true});
stream.getTracks().forEach(track => pc.addTrack(track, stream));
```

#### 第二层：WebRTC JavaScript API

浏览器暴露给 JavaScript 的标准 API，由 W3C 定义：

| API | 职责 |
|-----|------|
| `navigator.mediaDevices.getUserMedia()` | 获取摄像头/麦克风 |
| `navigator.mediaDevices.getDisplayMedia()` | 获取屏幕共享 |
| `RTCPeerConnection` | 建立和管理 P2P 连接 |
| `RTCDataChannel` | 传输任意数据 |
| `MediaStream` / `MediaStreamTrack` | 管理媒体流和轨道 |

#### 第三层：WebRTC Native C++ API

这是 libwebrtc 提供的 C++ 接口层，主要包含：

- **PeerConnectionFactory**：创建 PeerConnection 的工厂类
- **PeerConnection**：核心连接管理类
- **MediaStreamInterface**：媒体流接口
- **DataChannelInterface**：数据通道接口

#### 第四层：核心引擎层

包含三个主要模块：

1. **Session Management**：会话管理
   - SDP 协商
   - ICE 候选收集与交换
   - DTLS 密钥交换

2. **Voice Engine**：音频引擎
   - 音频编解码（Opus、G.711）
   - 回声消除（AEC）
   - 噪声抑制（NS）
   - 自动增益控制（AGC）
   - 抖动缓冲（Jitter Buffer）

3. **Video Engine**：视频引擎
   - 视频编解码（VP8、VP9、H.264、AV1）
   - 视频处理（缩放、裁剪）
   - 前向纠错（FEC）
   - 抖动缓冲

#### 第五层：传输层

负责网络传输的协议栈：

```
┌─────────────────────────────────────────┐
│              Application                 │
├─────────────────────────────────────────┤
│    SRTP (媒体)    │    SCTP (数据)       │
├─────────────────────────────────────────┤
│              DTLS (加密)                 │
├─────────────────────────────────────────┤
│           ICE (NAT 穿透)                 │
├─────────────────────────────────────────┤
│         STUN / TURN (服务器)             │
├─────────────────────────────────────────┤
│              UDP / TCP                   │
└─────────────────────────────────────────┘
```

### 1.3 浏览器实现差异

不同浏览器的 WebRTC 实现有所差异：

| 浏览器 | 底层实现 | 特点 |
|--------|---------|------|
| Chrome | libwebrtc | 最完整、更新最快 |
| Firefox | 自研 + libwebrtc 部分 | 独立实现，兼容性好 |
| Safari | 基于 libwebrtc | 更新较慢，部分功能缺失 |
| Edge | Chromium 内核 | 与 Chrome 一致 |

---

## 2. API 体系详解

### 2.1 getUserMedia / getDisplayMedia

#### getUserMedia - 获取摄像头和麦克风

```javascript
// 基础用法
const stream = await navigator.mediaDevices.getUserMedia({
    video: true,
    audio: true
});

// 高级约束
const stream = await navigator.mediaDevices.getUserMedia({
    video: {
        width: { min: 640, ideal: 1280, max: 1920 },
        height: { min: 480, ideal: 720, max: 1080 },
        frameRate: { ideal: 30, max: 60 },
        facingMode: 'user',  // 'user' 前置, 'environment' 后置
        deviceId: { exact: 'specific-camera-id' }
    },
    audio: {
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true,
        sampleRate: 48000,
        channelCount: 2
    }
});
```

#### getDisplayMedia - 屏幕共享

```javascript
const screenStream = await navigator.mediaDevices.getDisplayMedia({
    video: {
        cursor: 'always',           // 是否显示鼠标
        displaySurface: 'monitor'   // 'monitor' | 'window' | 'browser'
    },
    audio: true  // 系统音频（部分浏览器支持）
});
```

#### 枚举设备

```javascript
const devices = await navigator.mediaDevices.enumerateDevices();

devices.forEach(device => {
    console.log(`${device.kind}: ${device.label} (${device.deviceId})`);
});

// 输出示例：
// videoinput: FaceTime HD Camera (abc123)
// audioinput: MacBook Pro Microphone (def456)
// audiooutput: MacBook Pro Speakers (ghi789)
```

### 2.2 RTCPeerConnection

RTCPeerConnection 是 WebRTC 的核心 API，负责建立和管理 P2P 连接。

#### 构造函数与配置

```javascript
const configuration = {
    // ICE 服务器配置
    iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        { 
            urls: 'turn:turn.example.com:3478',
            username: 'user',
            credential: 'password'
        }
    ],
    
    // ICE 传输策略
    iceTransportPolicy: 'all',  // 'all' | 'relay'
    
    // Bundle 策略
    bundlePolicy: 'max-bundle',  // 'balanced' | 'max-compat' | 'max-bundle'
    
    // RTCP 复用策略
    rtcpMuxPolicy: 'require',    // 'require' | 'negotiate'
    
    // 证书
    certificates: [certificate]
};

const pc = new RTCPeerConnection(configuration);
```

#### 核心方法

```javascript
// ===== 信令相关 =====

// 创建 Offer
const offer = await pc.createOffer({
    offerToReceiveAudio: true,
    offerToReceiveVideo: true,
    iceRestart: false
});

// 创建 Answer
const answer = await pc.createAnswer();

// 设置本地描述
await pc.setLocalDescription(offer);

// 设置远端描述
await pc.setRemoteDescription(remoteAnswer);

// 添加 ICE 候选
await pc.addIceCandidate(candidate);


// ===== 媒体相关 =====

// 添加轨道
const sender = pc.addTrack(track, stream);

// 移除轨道
pc.removeTrack(sender);

// 获取发送器
const senders = pc.getSenders();

// 获取接收器
const receivers = pc.getReceivers();

// 获取收发器
const transceivers = pc.getTransceivers();

// 添加收发器
const transceiver = pc.addTransceiver('video', {
    direction: 'sendrecv'  // 'sendrecv' | 'sendonly' | 'recvonly' | 'inactive'
});


// ===== 数据通道 =====

// 创建数据通道
const dataChannel = pc.createDataChannel('myChannel', {
    ordered: true,
    maxRetransmits: 3
});


// ===== 连接管理 =====

// 关闭连接
pc.close();

// 获取统计信息
const stats = await pc.getStats();
```

#### 核心事件

```javascript
// ICE 候选事件
pc.onicecandidate = (event) => {
    if (event.candidate) {
        // 发送候选到远端
        sendToRemote({ type: 'candidate', candidate: event.candidate });
    }
};

// ICE 连接状态变化
pc.oniceconnectionstatechange = () => {
    console.log('ICE state:', pc.iceConnectionState);
    // 'new' | 'checking' | 'connected' | 'completed' | 
    // 'failed' | 'disconnected' | 'closed'
};

// 连接状态变化
pc.onconnectionstatechange = () => {
    console.log('Connection state:', pc.connectionState);
    // 'new' | 'connecting' | 'connected' | 'disconnected' | 'failed' | 'closed'
};

// 信令状态变化
pc.onsignalingstatechange = () => {
    console.log('Signaling state:', pc.signalingState);
    // 'stable' | 'have-local-offer' | 'have-remote-offer' |
    // 'have-local-pranswer' | 'have-remote-pranswer' | 'closed'
};

// 收到远端轨道
pc.ontrack = (event) => {
    const [remoteStream] = event.streams;
    remoteVideo.srcObject = remoteStream;
};

// 收到数据通道
pc.ondatachannel = (event) => {
    const dataChannel = event.channel;
    dataChannel.onmessage = (e) => console.log(e.data);
};

// 需要重新协商
pc.onnegotiationneeded = async () => {
    const offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    sendToRemote({ type: 'offer', sdp: offer.sdp });
};
```

### 2.3 RTCDataChannel

DataChannel 提供了在 P2P 连接上传输任意数据的能力。

```javascript
// 创建数据通道（发起方）
const dataChannel = pc.createDataChannel('chat', {
    ordered: true,              // 保证顺序
    maxRetransmits: 3,          // 最大重传次数
    // maxPacketLifeTime: 3000, // 或者设置最大生存时间（ms）
    protocol: 'json',           // 子协议
    negotiated: false,          // 是否手动协商
    id: 0                       // 通道 ID（negotiated 为 true 时使用）
});

// 事件处理
dataChannel.onopen = () => {
    console.log('Data channel opened');
    dataChannel.send('Hello!');
};

dataChannel.onclose = () => {
    console.log('Data channel closed');
};

dataChannel.onmessage = (event) => {
    console.log('Received:', event.data);
};

dataChannel.onerror = (error) => {
    console.error('Data channel error:', error);
};

// 发送数据
dataChannel.send('text message');
dataChannel.send(new ArrayBuffer(1024));
dataChannel.send(new Blob(['binary data']));

// 检查缓冲区
if (dataChannel.bufferedAmount < dataChannel.bufferedAmountLowThreshold) {
    dataChannel.send(moreData);
}

// 接收方处理
pc.ondatachannel = (event) => {
    const receiveChannel = event.channel;
    receiveChannel.onmessage = (e) => {
        console.log('Received:', e.data);
    };
};
```

---

## 3. WebRTC 信令流程概览

### 3.1 什么是信令？

**信令（Signaling）** 是 WebRTC 建立连接前的协商过程，用于交换：

1. **会话描述（SDP）**：媒体能力、编解码器、传输参数
2. **网络候选（ICE Candidates）**：可用的网络路径

> ⚠️ WebRTC 标准**不定义**信令协议，开发者需要自行实现。

### 3.2 常见信令方案

| 方案 | 优点 | 缺点 |
|------|------|------|
| WebSocket | 实时、双向 | 需要维护长连接 |
| HTTP 轮询 | 简单 | 延迟高、效率低 |
| Socket.IO | 易用、自动重连 | 额外依赖 |
| Firebase | 无需服务器 | 依赖第三方 |
| MQTT | 适合 IoT | 复杂度较高 |

### 3.3 完整信令流程

```
┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│   Caller     │         │   Signaling  │         │   Callee     │
│   (发起方)    │         │   Server     │         │   (接收方)    │
└──────┬───────┘         └──────┬───────┘         └──────┬───────┘
       │                        │                        │
       │  1. 获取本地媒体流       │                        │
       │  getUserMedia()        │                        │
       │                        │                        │
       │  2. 创建 PeerConnection │                        │
       │  new RTCPeerConnection │                        │
       │                        │                        │
       │  3. 添加本地轨道         │                        │
       │  addTrack()            │                        │
       │                        │                        │
       │  4. 创建 Offer          │                        │
       │  createOffer()         │                        │
       │                        │                        │
       │  5. 设置本地描述         │                        │
       │  setLocalDescription() │                        │
       │                        │                        │
       │  6. 发送 Offer ─────────>│                        │
       │                        │  7. 转发 Offer ─────────>│
       │                        │                        │
       │                        │         8. 获取本地媒体流
       │                        │         getUserMedia()
       │                        │                        │
       │                        │         9. 创建 PeerConnection
       │                        │         new RTCPeerConnection
       │                        │                        │
       │                        │         10. 设置远端描述
       │                        │         setRemoteDescription()
       │                        │                        │
       │                        │         11. 添加本地轨道
       │                        │         addTrack()
       │                        │                        │
       │                        │         12. 创建 Answer
       │                        │         createAnswer()
       │                        │                        │
       │                        │         13. 设置本地描述
       │                        │         setLocalDescription()
       │                        │                        │
       │                        │<───────── 14. 发送 Answer
       │<───────── 15. 转发 Answer│                        │
       │                        │                        │
       │  16. 设置远端描述        │                        │
       │  setRemoteDescription() │                        │
       │                        │                        │
       │  ═══════════ 17. ICE 候选交换 (双向) ═══════════  │
       │  onicecandidate ──────>│<─────── onicecandidate │
       │<────── addIceCandidate │ addIceCandidate ──────>│
       │                        │                        │
       │  ═══════════════ 18. P2P 连接建立 ═══════════════│
       │<═══════════════════════════════════════════════>│
       │                        │                        │
       │  ═══════════════ 19. 媒体流传输 ═════════════════│
       │<═══════════════════════════════════════════════>│
       │                        │                        │
```

### 3.4 SDP 详解

SDP（Session Description Protocol）描述了会话的媒体能力。

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
a=fingerprint:sha-256 AA:BB:CC:DD:...
a=setup:actpass
a=mid:0
a=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level
a=sendrecv
a=rtcp-mux
a=rtpmap:111 opus/48000/2
a=fmtp:111 minptime=10;useinbandfec=1
...

m=video 9 UDP/TLS/RTP/SAVPF 96 97 98 99 100 101 102
c=IN IP4 0.0.0.0
a=rtcp:9 IN IP4 0.0.0.0
a=ice-ufrag:abcd
a=ice-pwd:efghijklmnopqrstuvwxyz
a=fingerprint:sha-256 AA:BB:CC:DD:...
a=setup:actpass
a=mid:1
a=sendrecv
a=rtcp-mux
a=rtcp-rsize
a=rtpmap:96 VP8/90000
a=rtpmap:97 rtx/90000
a=fmtp:97 apt=96
a=rtpmap:98 VP9/90000
...
```

#### SDP 关键字段

| 字段 | 含义 |
|------|------|
| `v=` | 协议版本 |
| `o=` | 会话发起者信息 |
| `s=` | 会话名称 |
| `t=` | 会话时间 |
| `m=` | 媒体描述（audio/video） |
| `a=rtpmap:` | RTP 负载类型映射 |
| `a=fmtp:` | 格式参数 |
| `a=ice-ufrag:` | ICE 用户名片段 |
| `a=ice-pwd:` | ICE 密码 |
| `a=fingerprint:` | DTLS 证书指纹 |
| `a=candidate:` | ICE 候选 |

### 3.5 ICE 候选类型

```javascript
// ICE 候选示例
{
    candidate: "candidate:842163049 1 udp 1677729535 192.168.1.100 54321 typ srflx raddr 10.0.0.1 rport 12345 generation 0",
    sdpMid: "0",
    sdpMLineIndex: 0
}
```

| 类型 | 说明 | 优先级 |
|------|------|-------|
| `host` | 本地 IP 地址 | 最高 |
| `srflx` | Server Reflexive（STUN 获取的公网地址） | 中 |
| `prflx` | Peer Reflexive（对端发现的地址） | 中 |
| `relay` | TURN 中继地址 | 最低 |

---

## 4. 媒体引擎结构（libwebrtc 概览）

### 4.1 libwebrtc 简介

**libwebrtc** 是 Google 开源的 WebRTC 实现，也是 Chrome、Firefox（部分）、Safari 等浏览器的底层实现。

- **代码仓库**：https://webrtc.googlesource.com/src/
- **许可证**：BSD 3-Clause
- **语言**：C++（核心）+ 各平台绑定

### 4.2 目录结构

```
src/
├── api/                    # 公共 API 接口
│   ├── audio_codecs/       # 音频编解码器接口
│   ├── video_codecs/       # 视频编解码器接口
│   ├── peer_connection_interface.h
│   └── ...
├── audio/                  # 音频处理
│   ├── audio_send_stream.cc
│   ├── audio_receive_stream.cc
│   └── ...
├── video/                  # 视频处理
│   ├── video_send_stream.cc
│   ├── video_receive_stream.cc
│   └── ...
├── call/                   # 呼叫管理
├── media/                  # 媒体引擎
│   ├── engine/
│   │   ├── webrtc_voice_engine.cc
│   │   └── webrtc_video_engine.cc
│   └── ...
├── modules/                # 核心模块
│   ├── audio_coding/       # 音频编解码
│   ├── audio_processing/   # 音频处理（AEC、NS、AGC）
│   ├── video_coding/       # 视频编解码
│   ├── rtp_rtcp/           # RTP/RTCP 协议
│   ├── congestion_controller/  # 拥塞控制
│   └── ...
├── pc/                     # PeerConnection 实现
│   ├── peer_connection.cc
│   ├── sdp_offer_answer.cc
│   └── ...
├── p2p/                    # P2P 连接
│   ├── base/
│   │   ├── stun.cc
│   │   ├── turn_port.cc
│   │   └── ...
│   └── client/
│       └── basic_port_allocator.cc
├── rtc_base/               # 基础库
│   ├── thread.cc
│   ├── async_socket.cc
│   └── ...
└── sdk/                    # 平台 SDK
    ├── android/
    ├── objc/               # iOS/macOS
    └── ...
```

### 4.3 核心模块详解

#### 4.3.1 音频处理模块 (Audio Processing Module, APM)

```
┌─────────────────────────────────────────────────────────────┐
│                  Audio Processing Module                     │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │    AEC      │  │     NS      │  │        AGC          │  │
│  │ (回声消除)   │  │  (噪声抑制)  │  │   (自动增益控制)     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │    VAD      │  │   Beamform  │  │   Level Estimator   │  │
│  │ (语音检测)   │  │  (波束成形)  │  │    (电平估计)        │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

**关键组件**：

| 组件 | 功能 | 文件位置 |
|------|------|---------|
| AEC3 | 回声消除（第三代） | `modules/audio_processing/aec3/` |
| NS | 噪声抑制 | `modules/audio_processing/ns/` |
| AGC2 | 自动增益控制 | `modules/audio_processing/agc2/` |
| VAD | 语音活动检测 | `modules/audio_processing/vad/` |

#### 4.3.2 视频编解码模块

```
┌─────────────────────────────────────────────────────────────┐
│                   Video Coding Module                        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐    │
│  │                    Encoders                          │    │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐ │    │
│  │  │   VP8   │  │   VP9   │  │  H.264  │  │   AV1   │ │    │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘ │    │
│  └─────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                    Decoders                          │    │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐ │    │
│  │  │   VP8   │  │   VP9   │  │  H.264  │  │   AV1   │ │    │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘ │    │
│  └─────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Video Processing                        │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │    │
│  │  │   Scaling   │  │     FEC     │  │  Jitter Buf │  │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

#### 4.3.3 RTP/RTCP 模块

```
┌─────────────────────────────────────────────────────────────┐
│                    RTP/RTCP Module                           │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐    │
│  │                   RTP Sender                         │    │
│  │  • 打包媒体数据                                       │    │
│  │  • 添加 RTP 头部                                      │    │
│  │  • 处理重传请求                                       │    │
│  └─────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                   RTP Receiver                       │    │
│  │  • 解析 RTP 包                                        │    │
│  │  • 处理丢包                                          │    │
│  │  • 抖动缓冲                                          │    │
│  └─────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                   RTCP Handler                       │    │
│  │  • SR/RR (发送/接收报告)                              │    │
│  │  • NACK (丢包重传请求)                                │    │
│  │  • PLI/FIR (关键帧请求)                               │    │
│  │  • REMB (带宽估计)                                    │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

#### 4.3.4 拥塞控制模块

WebRTC 使用 **GCC（Google Congestion Control）** 算法进行带宽估计和拥塞控制。

```
┌─────────────────────────────────────────────────────────────┐
│              Congestion Controller                           │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐    │
│  │            Send-side BWE (发送端带宽估计)             │    │
│  │  • 基于延迟梯度                                       │    │
│  │  • Transport-wide CC                                 │    │
│  └─────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │            Receive-side BWE (接收端带宽估计)          │    │
│  │  • REMB 反馈                                         │    │
│  │  • 基于丢包率                                        │    │
│  └─────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │            Pacer (发送节奏控制)                       │    │
│  │  • 平滑发送                                          │    │
│  │  • 避免突发                                          │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### 4.4 线程模型

libwebrtc 使用多线程架构：

```
┌─────────────────────────────────────────────────────────────┐
│                    Thread Architecture                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐                                        │
│  │  Signaling      │  信令线程：处理 API 调用、SDP 协商       │
│  │  Thread         │                                        │
│  └─────────────────┘                                        │
│           │                                                 │
│           ▼                                                 │
│  ┌─────────────────┐                                        │
│  │  Worker         │  工作线程：媒体处理、编解码              │
│  │  Thread         │                                        │
│  └─────────────────┘                                        │
│           │                                                 │
│           ▼                                                 │
│  ┌─────────────────┐                                        │
│  │  Network        │  网络线程：网络 I/O、ICE 处理           │
│  │  Thread         │                                        │
│  └─────────────────┘                                        │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐                   │
│  │  Audio          │  │  Video          │                   │
│  │  Device Thread  │  │  Capture Thread │  设备线程          │
│  └─────────────────┘  └─────────────────┘                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. 总结

### 架构要点回顾

| 层次 | 内容 |
|------|------|
| **应用层** | JavaScript 代码，调用 WebRTC API |
| **API 层** | getUserMedia、RTCPeerConnection、RTCDataChannel |
| **引擎层** | 音频引擎、视频引擎、会话管理 |
| **传输层** | ICE、DTLS、SRTP、SCTP |

### API 体系总结

| API | 职责 |
|-----|------|
| `getUserMedia()` | 获取摄像头/麦克风 |
| `getDisplayMedia()` | 屏幕共享 |
| `RTCPeerConnection` | P2P 连接管理 |
| `RTCDataChannel` | 任意数据传输 |

### 信令流程要点

1. **Offer/Answer 模型**：发起方创建 Offer，接收方回复 Answer
2. **SDP 交换**：描述媒体能力和传输参数
3. **ICE 候选交换**：发现可用的网络路径
4. **信令协议自定义**：WebRTC 不规定信令协议

### 下一篇预告

在下一篇文章中，我们将动手实践，**从零开始写一个最简单的 WebRTC Demo**，包括：
- 获取摄像头与麦克风
- 建立 RTCPeerConnection
- 实现 peer-to-peer 音视频通话

---

## 参考资料

1. [WebRTC 1.0: Real-Time Communication Between Browsers - W3C](https://www.w3.org/TR/webrtc/)
2. [libwebrtc Source Code](https://webrtc.googlesource.com/src/)
3. [WebRTC for the Curious](https://webrtcforthecurious.com/)
4. [High Performance Browser Networking - WebRTC](https://hpbn.co/webrtc/)
5. [RFC 8825 - Overview: Real-Time Protocols for Browser-Based Applications](https://datatracker.ietf.org/doc/html/rfc8825)

---

> **作者**：WebRTC 技术专栏  
> **系列**：WebRTC 基础与快速入门（2/5）  
> **上一篇**：[WebRTC 是什么？能做什么？（概览篇）](./01-webrtc-overview.md)  
> **下一篇**：[写一个最简单的 WebRTC Demo（实操篇）](./03-webrtc-demo.md)
