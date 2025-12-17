---
title: "WebRTC 的 API 全景图（API 体系篇）"
description: "1. [API 体系概览](#1-api-体系概览)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 5
---

> 本文是 WebRTC 系列专栏的第五篇，也是基础入门部分的收官之作。我们将全面梳理 WebRTC 的 API 体系，帮助你掌握所有核心 API 的职责与用法。

---

## 目录

1. [API 体系概览](#1-api-体系概览)
2. [getUserMedia 详解](#2-getusermedia-详解)
3. [RTCPeerConnection 完整 API](#3-rtcpeerconnection-完整-api)
4. [RTCRtpSender / Receiver](#4-rtcrtpsender--receiver)
5. [RTCDataChannel](#5-rtcdatachannel)
6. [其他重要 API](#6-其他重要-api)
7. [总结](#7-总结)

---

## 1. API 体系概览

### 1.1 WebRTC API 分类

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        WebRTC API 体系                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                      媒体捕获 API                                │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │   │
│  │  │ getUserMedia()  │  │getDisplayMedia()│  │enumerateDevices │  │   │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                      媒体流 API                                  │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │   │
│  │  │  MediaStream    │  │MediaStreamTrack │  │ MediaDevices    │  │   │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                      连接 API                                    │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │   │
│  │  │RTCPeerConnection│  │RTCSessionDescr. │  │ RTCIceCandidate │  │   │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                      RTP API                                     │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │   │
│  │  │  RTCRtpSender   │  │ RTCRtpReceiver  │  │RTCRtpTransceiver│  │   │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                      数据通道 API                                │   │
│  │  ┌─────────────────────────────────────────────────────────┐    │   │
│  │  │                   RTCDataChannel                         │    │   │
│  │  └─────────────────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                      统计 API                                    │   │
│  │  ┌─────────────────────────────────────────────────────────┐    │   │
│  │  │                    RTCStatsReport                        │    │   │
│  │  └─────────────────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 API 职责速查表

| API | 职责 | 关键方法/属性 |
|-----|------|--------------|
| `getUserMedia()` | 获取摄像头/麦克风 | constraints, stream |
| `getDisplayMedia()` | 屏幕共享 | constraints, stream |
| `MediaStream` | 媒体流容器 | getTracks(), addTrack() |
| `MediaStreamTrack` | 单个音视频轨道 | enabled, stop() |
| `RTCPeerConnection` | P2P 连接核心 | createOffer(), addTrack() |
| `RTCRtpSender` | 发送 RTP 流 | setParameters(), replaceTrack() |
| `RTCRtpReceiver` | 接收 RTP 流 | getStats(), track |
| `RTCRtpTransceiver` | 收发器 | direction, sender, receiver |
| `RTCDataChannel` | 数据通道 | send(), onmessage |

---

## 2. getUserMedia 详解

### 2.1 基本语法

```javascript
const stream = await navigator.mediaDevices.getUserMedia(constraints);
```

### 2.2 约束（Constraints）详解

#### 基础约束

```javascript
// 最简单的约束
const constraints = {
    video: true,
    audio: true
};

// 只获取音频
const audioOnly = {
    video: false,
    audio: true
};

// 只获取视频
const videoOnly = {
    video: true,
    audio: false
};
```

#### 视频约束

```javascript
const videoConstraints = {
    video: {
        // 分辨率约束
        width: { min: 640, ideal: 1280, max: 1920 },
        height: { min: 480, ideal: 720, max: 1080 },
        
        // 宽高比
        aspectRatio: { ideal: 16/9 },
        
        // 帧率
        frameRate: { min: 15, ideal: 30, max: 60 },
        
        // 摄像头选择
        facingMode: 'user',          // 'user' 前置, 'environment' 后置
        // facingMode: { exact: 'environment' },  // 强制后置
        
        // 指定设备
        deviceId: { exact: 'camera-device-id' },
        
        // 分组 ID（同一物理设备的多个功能）
        groupId: 'group-id'
    },
    audio: true
};
```

#### 音频约束

```javascript
const audioConstraints = {
    video: false,
    audio: {
        // 设备选择
        deviceId: { exact: 'microphone-device-id' },
        
        // 音频处理
        echoCancellation: true,      // 回声消除
        noiseSuppression: true,      // 噪声抑制
        autoGainControl: true,       // 自动增益控制
        
        // 采样参数
        sampleRate: 48000,           // 采样率
        sampleSize: 16,              // 采样位深
        channelCount: 2,             // 声道数
        
        // 延迟
        latency: { ideal: 0.01 }     // 目标延迟（秒）
    }
};
```

#### 约束语法详解

```javascript
// 约束值可以是以下形式：

// 1. 布尔值
video: true

// 2. 精确值
width: { exact: 1280 }

// 3. 理想值（尽量满足，不满足也可以）
width: { ideal: 1280 }

// 4. 范围
width: { min: 640, max: 1920 }

// 5. 组合
width: { min: 640, ideal: 1280, max: 1920 }
```

### 2.3 设备枚举

```javascript
// 获取所有媒体设备
async function getDevices() {
    const devices = await navigator.mediaDevices.enumerateDevices();
    
    const videoInputs = devices.filter(d => d.kind === 'videoinput');
    const audioInputs = devices.filter(d => d.kind === 'audioinput');
    const audioOutputs = devices.filter(d => d.kind === 'audiooutput');
    
    console.log('摄像头:', videoInputs);
    console.log('麦克风:', audioInputs);
    console.log('扬声器:', audioOutputs);
    
    return { videoInputs, audioInputs, audioOutputs };
}

// 设备信息结构
interface MediaDeviceInfo {
    deviceId: string;      // 设备唯一标识
    groupId: string;       // 设备组标识
    kind: 'videoinput' | 'audioinput' | 'audiooutput';
    label: string;         // 设备名称（需要权限才能获取）
}
```

### 2.4 设备变化监听

```javascript
// 监听设备插拔
navigator.mediaDevices.ondevicechange = async () => {
    console.log('设备列表已变化');
    const devices = await navigator.mediaDevices.enumerateDevices();
    updateDeviceList(devices);
};
```

### 2.5 屏幕共享

```javascript
// 获取屏幕共享
const screenStream = await navigator.mediaDevices.getDisplayMedia({
    video: {
        cursor: 'always',           // 'always' | 'motion' | 'never'
        displaySurface: 'monitor',  // 'monitor' | 'window' | 'browser'
        logicalSurface: true,
        width: { max: 1920 },
        height: { max: 1080 },
        frameRate: { max: 30 }
    },
    audio: true  // 系统音频（部分浏览器支持）
});

// 监听用户停止共享
screenStream.getVideoTracks()[0].onended = () => {
    console.log('用户停止了屏幕共享');
};
```

### 2.6 错误处理

```javascript
async function getMediaWithErrorHandling() {
    try {
        const stream = await navigator.mediaDevices.getUserMedia({
            video: true,
            audio: true
        });
        return stream;
    } catch (error) {
        switch (error.name) {
            case 'NotAllowedError':
                // 用户拒绝权限
                alert('请允许访问摄像头和麦克风');
                break;
            case 'NotFoundError':
                // 找不到设备
                alert('未找到摄像头或麦克风');
                break;
            case 'NotReadableError':
                // 设备被占用
                alert('设备被其他应用占用');
                break;
            case 'OverconstrainedError':
                // 约束无法满足
                console.log('无法满足的约束:', error.constraint);
                // 尝试降低约束
                return await navigator.mediaDevices.getUserMedia({
                    video: true,
                    audio: true
                });
            case 'SecurityError':
                // 安全错误（非 HTTPS）
                alert('请使用 HTTPS 访问');
                break;
            case 'TypeError':
                // 约束格式错误
                console.error('约束格式错误');
                break;
            default:
                console.error('未知错误:', error);
        }
        throw error;
    }
}
```

### 2.7 获取设备能力

```javascript
// 获取轨道的能力范围
const stream = await navigator.mediaDevices.getUserMedia({ video: true });
const videoTrack = stream.getVideoTracks()[0];

// 获取能力
const capabilities = videoTrack.getCapabilities();
console.log('设备能力:', capabilities);
// {
//     width: { min: 1, max: 1920 },
//     height: { min: 1, max: 1080 },
//     frameRate: { min: 1, max: 60 },
//     facingMode: ['user', 'environment'],
//     ...
// }

// 获取当前设置
const settings = videoTrack.getSettings();
console.log('当前设置:', settings);
// {
//     width: 1280,
//     height: 720,
//     frameRate: 30,
//     deviceId: '...',
//     ...
// }

// 获取约束
const constraints = videoTrack.getConstraints();
console.log('当前约束:', constraints);
```

### 2.8 动态调整约束

```javascript
// 应用新约束
async function applyConstraints(track, newConstraints) {
    try {
        await track.applyConstraints(newConstraints);
        console.log('约束应用成功');
    } catch (error) {
        console.error('约束应用失败:', error);
    }
}

// 示例：切换分辨率
const videoTrack = stream.getVideoTracks()[0];
await videoTrack.applyConstraints({
    width: { ideal: 1920 },
    height: { ideal: 1080 }
});
```

---

## 3. RTCPeerConnection 完整 API

### 3.1 构造函数与配置

```javascript
const configuration = {
    // ICE 服务器配置
    iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        {
            urls: ['turn:turn.example.com:3478', 'turns:turn.example.com:443'],
            username: 'user',
            credential: 'password',
            credentialType: 'password'  // 'password' | 'oauth'
        }
    ],
    
    // ICE 传输策略
    iceTransportPolicy: 'all',  // 'all' | 'relay'
    
    // Bundle 策略（多路复用）
    bundlePolicy: 'max-bundle',  // 'balanced' | 'max-compat' | 'max-bundle'
    
    // RTCP 复用策略
    rtcpMuxPolicy: 'require',    // 'require' | 'negotiate'
    
    // ICE 候选池大小
    iceCandidatePoolSize: 0,
    
    // 证书（可选，用于 DTLS）
    certificates: [await RTCPeerConnection.generateCertificate({
        name: 'ECDSA',
        namedCurve: 'P-256'
    })]
};

const pc = new RTCPeerConnection(configuration);
```

### 3.2 信令相关方法

#### 创建 Offer/Answer

```javascript
// 创建 Offer
const offerOptions = {
    offerToReceiveAudio: true,
    offerToReceiveVideo: true,
    iceRestart: false,           // 是否重启 ICE
    voiceActivityDetection: true // 语音活动检测
};
const offer = await pc.createOffer(offerOptions);

// 创建 Answer
const answerOptions = {
    voiceActivityDetection: true
};
const answer = await pc.createAnswer(answerOptions);
```

#### 设置描述

```javascript
// 设置本地描述
await pc.setLocalDescription(offer);
// 或使用隐式创建
await pc.setLocalDescription();  // 自动创建 offer 或 answer

// 设置远端描述
await pc.setRemoteDescription(new RTCSessionDescription({
    type: 'answer',
    sdp: remoteSdp
}));
```

#### ICE 候选

```javascript
// 添加远端 ICE 候选
await pc.addIceCandidate(new RTCIceCandidate({
    candidate: 'candidate:...',
    sdpMid: '0',
    sdpMLineIndex: 0
}));

// 也可以传入 null 表示候选收集完成
await pc.addIceCandidate(null);
```

### 3.3 媒体相关方法

#### 添加/移除轨道

```javascript
// 添加轨道
const sender = pc.addTrack(track, stream);

// 移除轨道
pc.removeTrack(sender);

// 获取所有发送器
const senders = pc.getSenders();

// 获取所有接收器
const receivers = pc.getReceivers();

// 获取所有收发器
const transceivers = pc.getTransceivers();
```

#### 添加收发器

```javascript
// 添加收发器（更精细的控制）
const transceiver = pc.addTransceiver('video', {
    direction: 'sendrecv',  // 'sendrecv' | 'sendonly' | 'recvonly' | 'inactive'
    streams: [stream],
    sendEncodings: [
        { rid: 'high', maxBitrate: 2500000 },
        { rid: 'medium', maxBitrate: 1000000, scaleResolutionDownBy: 2 },
        { rid: 'low', maxBitrate: 500000, scaleResolutionDownBy: 4 }
    ]
});

// 也可以传入轨道
const transceiver2 = pc.addTransceiver(videoTrack, {
    direction: 'sendonly'
});
```

### 3.4 数据通道

```javascript
// 创建数据通道
const dataChannel = pc.createDataChannel('myChannel', {
    ordered: true,              // 是否保证顺序
    maxPacketLifeTime: 3000,    // 最大生存时间（ms）
    // maxRetransmits: 3,       // 或最大重传次数（二选一）
    protocol: 'json',           // 子协议
    negotiated: false,          // 是否手动协商
    id: 0                       // 通道 ID
});

// 监听远端创建的数据通道
pc.ondatachannel = (event) => {
    const remoteChannel = event.channel;
};
```

### 3.5 状态属性

```javascript
// 连接状态
pc.connectionState;      // 'new' | 'connecting' | 'connected' | 'disconnected' | 'failed' | 'closed'

// 信令状态
pc.signalingState;       // 'stable' | 'have-local-offer' | 'have-remote-offer' | 
                         // 'have-local-pranswer' | 'have-remote-pranswer' | 'closed'

// ICE 连接状态
pc.iceConnectionState;   // 'new' | 'checking' | 'connected' | 'completed' | 
                         // 'failed' | 'disconnected' | 'closed'

// ICE 收集状态
pc.iceGatheringState;    // 'new' | 'gathering' | 'complete'

// 本地/远端描述
pc.localDescription;     // RTCSessionDescription | null
pc.remoteDescription;    // RTCSessionDescription | null
pc.currentLocalDescription;
pc.currentRemoteDescription;
pc.pendingLocalDescription;
pc.pendingRemoteDescription;

// SCTP 传输（用于 DataChannel）
pc.sctp;                 // RTCSctpTransport | null
```

### 3.6 事件处理

```javascript
// ===== 信令事件 =====

// 需要重新协商（如添加/移除轨道后）
pc.onnegotiationneeded = async () => {
    const offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    // 发送 offer 到远端
};

// 信令状态变化
pc.onsignalingstatechange = () => {
    console.log('信令状态:', pc.signalingState);
};


// ===== ICE 事件 =====

// 收集到 ICE 候选
pc.onicecandidate = (event) => {
    if (event.candidate) {
        // 发送候选到远端
    } else {
        // 候选收集完成
    }
};

// ICE 候选错误
pc.onicecandidateerror = (event) => {
    console.error('ICE 错误:', event.errorCode, event.errorText);
};

// ICE 连接状态变化
pc.oniceconnectionstatechange = () => {
    console.log('ICE 连接状态:', pc.iceConnectionState);
};

// ICE 收集状态变化
pc.onicegatheringstatechange = () => {
    console.log('ICE 收集状态:', pc.iceGatheringState);
};


// ===== 连接事件 =====

// 连接状态变化
pc.onconnectionstatechange = () => {
    console.log('连接状态:', pc.connectionState);
    
    switch (pc.connectionState) {
        case 'connected':
            console.log('连接成功！');
            break;
        case 'disconnected':
            console.log('连接断开，尝试重连...');
            break;
        case 'failed':
            console.log('连接失败');
            pc.close();
            break;
    }
};


// ===== 媒体事件 =====

// 收到远端轨道
pc.ontrack = (event) => {
    const { track, streams, receiver, transceiver } = event;
    console.log('收到轨道:', track.kind);
    
    // 绑定到视频元素
    if (streams[0]) {
        remoteVideo.srcObject = streams[0];
    }
};


// ===== 数据通道事件 =====

// 收到远端创建的数据通道
pc.ondatachannel = (event) => {
    const channel = event.channel;
    channel.onmessage = (e) => console.log('收到消息:', e.data);
};
```

### 3.7 统计信息

```javascript
// 获取所有统计信息
const stats = await pc.getStats();

// 遍历统计报告
stats.forEach(report => {
    console.log(`${report.type}: ${report.id}`);
    console.log(report);
});

// 获取特定发送器的统计
const senderStats = await pc.getStats(sender);

// 常用统计类型
stats.forEach(report => {
    switch (report.type) {
        case 'outbound-rtp':
            // 发送 RTP 统计
            console.log('发送统计:', {
                bytesSent: report.bytesSent,
                packetsSent: report.packetsSent,
                framesEncoded: report.framesEncoded,
                framesSent: report.framesSent
            });
            break;
            
        case 'inbound-rtp':
            // 接收 RTP 统计
            console.log('接收统计:', {
                bytesReceived: report.bytesReceived,
                packetsReceived: report.packetsReceived,
                packetsLost: report.packetsLost,
                jitter: report.jitter
            });
            break;
            
        case 'candidate-pair':
            // 候选对统计
            if (report.state === 'succeeded') {
                console.log('连接统计:', {
                    availableOutgoingBitrate: report.availableOutgoingBitrate,
                    currentRoundTripTime: report.currentRoundTripTime
                });
            }
            break;
    }
});
```

### 3.8 关闭连接

```javascript
// 关闭连接
pc.close();

// 关闭后状态
console.log(pc.connectionState);  // 'closed'
console.log(pc.signalingState);   // 'closed'
```

---

## 4. RTCRtpSender / Receiver

### 4.1 RTCRtpSender

RTCRtpSender 负责发送 RTP 流。

#### 属性

```javascript
const sender = pc.getSenders()[0];

// 关联的轨道
sender.track;           // MediaStreamTrack | null

// 关联的 DTLS 传输
sender.transport;       // RTCDtlsTransport | null

// 关联的 DTMF 发送器（音频轨道）
sender.dtmf;            // RTCDTMFSender | null
```

#### 方法

```javascript
// 替换轨道（无需重新协商）
await sender.replaceTrack(newTrack);

// 获取参数
const params = sender.getParameters();
console.log(params);
// {
//     encodings: [...],
//     transactionId: '...',
//     codecs: [...],
//     headerExtensions: [...],
//     rtcp: { cname: '...', reducedSize: true }
// }

// 设置参数
params.encodings[0].maxBitrate = 1000000;
await sender.setParameters(params);

// 获取统计
const stats = await sender.getStats();

// 获取能力（静态方法）
const capabilities = RTCRtpSender.getCapabilities('video');
console.log(capabilities);
// {
//     codecs: [
//         { mimeType: 'video/VP8', clockRate: 90000 },
//         { mimeType: 'video/VP9', clockRate: 90000 },
//         { mimeType: 'video/H264', clockRate: 90000, sdpFmtpLine: '...' },
//         ...
//     ],
//     headerExtensions: [...]
// }
```

#### 编码参数

```javascript
const params = sender.getParameters();

// 修改编码参数
params.encodings[0] = {
    active: true,                    // 是否激活
    maxBitrate: 2500000,             // 最大码率（bps）
    maxFramerate: 30,                // 最大帧率
    scaleResolutionDownBy: 1,        // 分辨率缩放因子
    priority: 'high',                // 'very-low' | 'low' | 'medium' | 'high'
    networkPriority: 'high'
};

await sender.setParameters(params);
```

#### Simulcast（同时发送多路）

```javascript
// 添加带 Simulcast 的收发器
const transceiver = pc.addTransceiver(videoTrack, {
    direction: 'sendonly',
    sendEncodings: [
        { rid: 'high', maxBitrate: 2500000 },
        { rid: 'medium', maxBitrate: 1000000, scaleResolutionDownBy: 2 },
        { rid: 'low', maxBitrate: 500000, scaleResolutionDownBy: 4 }
    ]
});

// 动态调整某一路
const params = transceiver.sender.getParameters();
params.encodings[2].active = false;  // 禁用低质量层
await transceiver.sender.setParameters(params);
```

### 4.2 RTCRtpReceiver

RTCRtpReceiver 负责接收 RTP 流。

#### 属性

```javascript
const receiver = pc.getReceivers()[0];

// 关联的轨道
receiver.track;         // MediaStreamTrack

// 关联的 DTLS 传输
receiver.transport;     // RTCDtlsTransport | null
```

#### 方法

```javascript
// 获取统计
const stats = await receiver.getStats();

// 获取贡献源（混音场景）
const contributingSources = receiver.getContributingSources();
// [{ source: 12345, timestamp: 1234567890, audioLevel: 0.5 }, ...]

// 获取同步源
const synchronizationSources = receiver.getSynchronizationSources();

// 获取能力（静态方法）
const capabilities = RTCRtpReceiver.getCapabilities('audio');
```

### 4.3 RTCRtpTransceiver

RTCRtpTransceiver 组合了 Sender 和 Receiver。

```javascript
const transceiver = pc.getTransceivers()[0];

// 属性
transceiver.mid;            // 媒体 ID（SDP 中的 mid）
transceiver.sender;         // RTCRtpSender
transceiver.receiver;       // RTCRtpReceiver
transceiver.direction;      // 'sendrecv' | 'sendonly' | 'recvonly' | 'inactive' | 'stopped'
transceiver.currentDirection; // 当前实际方向

// 设置方向
transceiver.direction = 'sendonly';

// 停止收发器
transceiver.stop();

// 设置编解码器偏好
const codecs = RTCRtpReceiver.getCapabilities('video').codecs;
const vp9Codecs = codecs.filter(c => c.mimeType === 'video/VP9');
transceiver.setCodecPreferences(vp9Codecs);
```

---

## 5. RTCDataChannel

### 5.1 创建数据通道

```javascript
// 发起方创建
const dataChannel = pc.createDataChannel('myChannel', {
    ordered: true,              // 保证顺序（默认 true）
    maxPacketLifeTime: 3000,    // 最大生存时间（ms）
    // maxRetransmits: 3,       // 最大重传次数（与上面二选一）
    protocol: '',               // 子协议
    negotiated: false,          // 是否手动协商
    id: undefined               // 通道 ID（negotiated 为 true 时必须指定）
});

// 接收方监听
pc.ondatachannel = (event) => {
    const receiveChannel = event.channel;
};
```

### 5.2 配置选项详解

| 选项 | 类型 | 默认值 | 说明 |
|------|------|-------|------|
| `ordered` | boolean | true | 是否保证消息顺序 |
| `maxPacketLifeTime` | number | - | 消息最大生存时间（ms） |
| `maxRetransmits` | number | - | 最大重传次数 |
| `protocol` | string | '' | 子协议名称 |
| `negotiated` | boolean | false | 是否手动协商 |
| `id` | number | 自动 | 通道 ID |

#### 可靠性配置

```javascript
// 可靠有序（默认，类似 TCP）
const reliable = pc.createDataChannel('reliable', {
    ordered: true
});

// 不可靠无序（类似 UDP）
const unreliable = pc.createDataChannel('unreliable', {
    ordered: false,
    maxRetransmits: 0
});

// 部分可靠（最多重传 3 次）
const partiallyReliable = pc.createDataChannel('partial', {
    ordered: true,
    maxRetransmits: 3
});

// 部分可靠（最多等待 3 秒）
const timedReliable = pc.createDataChannel('timed', {
    ordered: true,
    maxPacketLifeTime: 3000
});
```

#### 手动协商

```javascript
// 双方使用相同配置创建通道
// 发起方
const channel1 = pc.createDataChannel('sync', {
    negotiated: true,
    id: 0
});

// 接收方
const channel2 = pc.createDataChannel('sync', {
    negotiated: true,
    id: 0
});

// 无需等待 ondatachannel 事件
```

### 5.3 属性

```javascript
// 只读属性
dataChannel.label;              // 通道名称
dataChannel.ordered;            // 是否有序
dataChannel.maxPacketLifeTime;  // 最大生存时间
dataChannel.maxRetransmits;     // 最大重传次数
dataChannel.protocol;           // 子协议
dataChannel.negotiated;         // 是否手动协商
dataChannel.id;                 // 通道 ID
dataChannel.readyState;         // 'connecting' | 'open' | 'closing' | 'closed'
dataChannel.bufferedAmount;     // 缓冲区待发送字节数

// 可读写属性
dataChannel.binaryType;         // 'blob' | 'arraybuffer'（默认 'blob'）
dataChannel.bufferedAmountLowThreshold;  // 缓冲区低阈值
```

### 5.4 方法

```javascript
// 发送数据
dataChannel.send('text message');
dataChannel.send(new ArrayBuffer(1024));
dataChannel.send(new Blob(['binary data']));
dataChannel.send(new Uint8Array([1, 2, 3, 4]));

// 关闭通道
dataChannel.close();
```

### 5.5 事件

```javascript
// 通道打开
dataChannel.onopen = () => {
    console.log('通道已打开');
};

// 通道关闭
dataChannel.onclose = () => {
    console.log('通道已关闭');
};

// 收到消息
dataChannel.onmessage = (event) => {
    console.log('收到消息:', event.data);
    
    // 根据 binaryType 处理
    if (typeof event.data === 'string') {
        // 文本消息
    } else if (event.data instanceof ArrayBuffer) {
        // 二进制消息
    } else if (event.data instanceof Blob) {
        // Blob 消息
    }
};

// 错误
dataChannel.onerror = (error) => {
    console.error('通道错误:', error);
};

// 缓冲区低于阈值
dataChannel.onbufferedamountlow = () => {
    console.log('缓冲区已清空，可以继续发送');
};
```

### 5.6 流量控制

```javascript
// 设置缓冲区低阈值
dataChannel.bufferedAmountLowThreshold = 65536;  // 64KB

// 发送大文件时的流量控制
async function sendFile(file) {
    const chunkSize = 16384;  // 16KB
    const reader = file.stream().getReader();
    
    while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        
        // 等待缓冲区清空
        while (dataChannel.bufferedAmount > chunkSize * 10) {
            await new Promise(resolve => {
                dataChannel.onbufferedamountlow = resolve;
            });
        }
        
        dataChannel.send(value);
    }
}
```

### 5.7 实际应用示例

#### 文件传输

```javascript
// 发送端
async function sendFile(file, dataChannel) {
    // 发送文件元信息
    dataChannel.send(JSON.stringify({
        type: 'file-meta',
        name: file.name,
        size: file.size,
        mimeType: file.type
    }));
    
    // 分块发送文件内容
    const chunkSize = 16384;
    const reader = new FileReader();
    let offset = 0;
    
    const readNextChunk = () => {
        const slice = file.slice(offset, offset + chunkSize);
        reader.readAsArrayBuffer(slice);
    };
    
    reader.onload = (e) => {
        dataChannel.send(e.target.result);
        offset += e.target.result.byteLength;
        
        if (offset < file.size) {
            // 流量控制
            if (dataChannel.bufferedAmount < chunkSize * 10) {
                readNextChunk();
            } else {
                dataChannel.onbufferedamountlow = readNextChunk;
            }
        } else {
            dataChannel.send(JSON.stringify({ type: 'file-end' }));
        }
    };
    
    readNextChunk();
}

// 接收端
let fileBuffer = [];
let fileMeta = null;

dataChannel.onmessage = (event) => {
    if (typeof event.data === 'string') {
        const message = JSON.parse(event.data);
        
        if (message.type === 'file-meta') {
            fileMeta = message;
            fileBuffer = [];
        } else if (message.type === 'file-end') {
            const blob = new Blob(fileBuffer, { type: fileMeta.mimeType });
            downloadFile(blob, fileMeta.name);
        }
    } else {
        fileBuffer.push(event.data);
    }
};
```

---

## 6. 其他重要 API

### 6.1 MediaStream

```javascript
// 创建空的 MediaStream
const stream = new MediaStream();

// 从轨道创建
const stream2 = new MediaStream([videoTrack, audioTrack]);

// 克隆流
const clonedStream = stream.clone();

// 属性
stream.id;          // 流 ID
stream.active;      // 是否有活动轨道

// 方法
stream.getTracks();         // 获取所有轨道
stream.getVideoTracks();    // 获取视频轨道
stream.getAudioTracks();    // 获取音频轨道
stream.getTrackById(id);    // 根据 ID 获取轨道
stream.addTrack(track);     // 添加轨道
stream.removeTrack(track);  // 移除轨道

// 事件
stream.onaddtrack = (event) => {
    console.log('添加轨道:', event.track);
};

stream.onremovetrack = (event) => {
    console.log('移除轨道:', event.track);
};
```

### 6.2 MediaStreamTrack

```javascript
const track = stream.getVideoTracks()[0];

// 属性
track.id;               // 轨道 ID
track.kind;             // 'audio' | 'video'
track.label;            // 设备名称
track.enabled;          // 是否启用（可读写）
track.muted;            // 是否静音（只读）
track.readyState;       // 'live' | 'ended'
track.contentHint;      // 内容提示（可读写）

// 方法
track.clone();                      // 克隆轨道
track.stop();                       // 停止轨道
track.getCapabilities();            // 获取能力
track.getConstraints();             // 获取约束
track.getSettings();                // 获取当前设置
await track.applyConstraints({});   // 应用新约束

// 事件
track.onended = () => {
    console.log('轨道已结束');
};

track.onmute = () => {
    console.log('轨道已静音');
};

track.onunmute = () => {
    console.log('轨道已取消静音');
};
```

### 6.3 RTCSessionDescription

```javascript
// 创建会话描述
const description = new RTCSessionDescription({
    type: 'offer',  // 'offer' | 'answer' | 'pranswer' | 'rollback'
    sdp: sdpString
});

// 属性
description.type;   // 类型
description.sdp;    // SDP 字符串

// 转换为 JSON
const json = description.toJSON();
```

### 6.4 RTCIceCandidate

```javascript
// 创建 ICE 候选
const candidate = new RTCIceCandidate({
    candidate: 'candidate:...',
    sdpMid: '0',
    sdpMLineIndex: 0,
    usernameFragment: 'abcd'
});

// 属性
candidate.candidate;        // 候选字符串
candidate.sdpMid;           // 媒体 ID
candidate.sdpMLineIndex;    // 媒体行索引
candidate.foundation;       // 基础标识
candidate.component;        // 'rtp' | 'rtcp'
candidate.priority;         // 优先级
candidate.address;          // IP 地址
candidate.protocol;         // 'udp' | 'tcp'
candidate.port;             // 端口
candidate.type;             // 'host' | 'srflx' | 'prflx' | 'relay'
candidate.tcpType;          // TCP 类型
candidate.relatedAddress;   // 相关地址
candidate.relatedPort;      // 相关端口
candidate.usernameFragment; // 用户名片段

// 转换为 JSON
const json = candidate.toJSON();
```

### 6.5 RTCDTMFSender

用于发送 DTMF 音调（电话按键音）。

```javascript
const sender = pc.getSenders().find(s => s.track?.kind === 'audio');
const dtmfSender = sender.dtmf;

if (dtmfSender) {
    // 检查是否可以发送 DTMF
    console.log('可发送 DTMF:', dtmfSender.canInsertDTMF);
    
    // 发送 DTMF
    dtmfSender.insertDTMF('1234#', 100, 70);
    // 参数：音调序列, 每个音调持续时间(ms), 间隔时间(ms)
    
    // 当前音调队列
    console.log('音调队列:', dtmfSender.toneBuffer);
    
    // 音调发送事件
    dtmfSender.ontonechange = (event) => {
        console.log('发送音调:', event.tone);
    };
}
```

### 6.6 RTCCertificate

```javascript
// 生成证书
const certificate = await RTCPeerConnection.generateCertificate({
    name: 'ECDSA',
    namedCurve: 'P-256'
});

// 或使用 RSA
const rsaCertificate = await RTCPeerConnection.generateCertificate({
    name: 'RSASSA-PKCS1-v1_5',
    modulusLength: 2048,
    publicExponent: new Uint8Array([1, 0, 1]),
    hash: 'SHA-256'
});

// 属性
certificate.expires;        // 过期时间
certificate.getFingerprints();  // 获取指纹

// 使用证书
const pc = new RTCPeerConnection({
    certificates: [certificate]
});
```

---

## 7. 总结

### 7.1 API 速查表

#### 媒体捕获

| API | 用途 |
|-----|------|
| `getUserMedia()` | 获取摄像头/麦克风 |
| `getDisplayMedia()` | 屏幕共享 |
| `enumerateDevices()` | 枚举设备 |

#### 媒体流

| API | 用途 |
|-----|------|
| `MediaStream` | 媒体流容器 |
| `MediaStreamTrack` | 单个轨道 |
| `track.enabled` | 启用/禁用轨道 |
| `track.stop()` | 停止轨道 |

#### 连接管理

| API | 用途 |
|-----|------|
| `RTCPeerConnection` | P2P 连接 |
| `createOffer()` | 创建 Offer |
| `createAnswer()` | 创建 Answer |
| `setLocalDescription()` | 设置本地描述 |
| `setRemoteDescription()` | 设置远端描述 |
| `addIceCandidate()` | 添加 ICE 候选 |

#### RTP 控制

| API | 用途 |
|-----|------|
| `RTCRtpSender` | 发送控制 |
| `RTCRtpReceiver` | 接收控制 |
| `RTCRtpTransceiver` | 收发器 |
| `replaceTrack()` | 替换轨道 |
| `setParameters()` | 设置编码参数 |

#### 数据通道

| API | 用途 |
|-----|------|
| `createDataChannel()` | 创建数据通道 |
| `send()` | 发送数据 |
| `onmessage` | 接收数据 |

### 7.2 最佳实践

```javascript
// 1. 始终处理错误
try {
    const stream = await navigator.mediaDevices.getUserMedia({video: true});
} catch (error) {
    handleError(error);
}

// 2. 及时释放资源
window.addEventListener('beforeunload', () => {
    localStream?.getTracks().forEach(track => track.stop());
    peerConnection?.close();
});

// 3. 监控连接状态
pc.onconnectionstatechange = () => {
    if (pc.connectionState === 'failed') {
        // 尝试重连或通知用户
    }
};

// 4. 使用统计信息监控质量
setInterval(async () => {
    const stats = await pc.getStats();
    monitorQuality(stats);
}, 1000);

// 5. 优雅降级
const constraints = {
    video: {
        width: { ideal: 1280 },
        height: { ideal: 720 }
    }
};

try {
    stream = await navigator.mediaDevices.getUserMedia(constraints);
} catch (e) {
    // 降级到更低分辨率
    stream = await navigator.mediaDevices.getUserMedia({ video: true });
}
```

### 7.3 系列总结

恭喜你完成了 WebRTC 基础入门系列的学习！让我们回顾一下这五篇文章的核心内容：

| 篇章 | 主题 | 核心收获 |
|------|------|---------|
| 第 1 篇 | 概览篇 | 理解 WebRTC 的定位、能力和应用场景 |
| 第 2 篇 | 架构篇 | 掌握 WebRTC 的整体架构和组件关系 |
| 第 3 篇 | 实操篇 | 动手实现一个完整的音视频通话 Demo |
| 第 4 篇 | 理论篇 | 深入理解 NAT 穿透、RTP 协议、音频处理 |
| 第 5 篇 | API 篇 | 全面掌握 WebRTC API 体系 |

### 7.4 下一步学习建议

1. **深入信令设计**：学习如何设计可扩展的信令服务器
2. **SFU/MCU 架构**：了解大规模音视频会议的架构设计
3. **媒体服务器**：学习 Janus、mediasoup 等开源媒体服务器
4. **性能优化**：深入学习带宽估计、编码优化等高级主题
5. **移动端开发**：学习 iOS/Android 原生 WebRTC 开发

---

## 参考资料

1. [W3C WebRTC 1.0 Specification](https://www.w3.org/TR/webrtc/)
2. [MDN WebRTC API](https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API)
3. [WebRTC Samples](https://webrtc.github.io/samples/)
4. [WebRTC for the Curious](https://webrtcforthecurious.com/)
5. [High Performance Browser Networking - WebRTC](https://hpbn.co/webrtc/)

---

> **作者**：WebRTC 技术专栏  
> **系列**：WebRTC 基础与快速入门（5/5）  
> **上一篇**：[WebRTC 的三个关键技术（理论强化篇）](./04-webrtc-key-technologies.md)

---

**🎉 恭喜完成 WebRTC 基础入门系列！**

如果这个系列对你有帮助，欢迎分享给更多的开发者。期待在进阶系列中与你再次相遇！
