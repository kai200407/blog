---
title: "媒体流与轨道模型 (Track / Stream / Transceiver)"
description: "1. [媒体模型概述](#1-媒体模型概述)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 17
---

> 本文是 WebRTC 系列专栏的第十七篇,也是第三部分"媒体传输深入讲解"的收官之作。我们将深入探讨 WebRTC 的媒体模型,包括 MediaStreamTrack、RtpSender/Receiver、Transceiver 以及 Simulcast 和 SVC。

---

## 目录

1. [媒体模型概述](#1-媒体模型概述)
2. [MediaStreamTrack](#2-mediastreamtrack)
3. [RtpSender 与 RtpReceiver](#3-rtpsender-与-rtpreceiver)
4. [RTCRtpTransceiver](#4-rtcrtptransceiver)
5. [Simulcast](#5-simulcast)
6. [SVC (可伸缩视频编码)](#6-svc-可伸缩视频编码)
7. [总结](#7-总结)

---

## 1. 媒体模型概述

### 1.1 WebRTC 媒体层次

```
+-------------------------------------------------------------------+
|                      WebRTC 媒体模型层次                           |
+-------------------------------------------------------------------+
|                                                                   |
|   应用层                                                          |
|   +------------------+                                            |
|   | MediaStream      |  包含多个 Track                            |
|   | +------------+   |                                            |
|   | | AudioTrack |   |                                            |
|   | +------------+   |                                            |
|   | +------------+   |                                            |
|   | | VideoTrack |   |                                            |
|   | +------------+   |                                            |
|   +------------------+                                            |
|            |                                                      |
|            v                                                      |
|   传输层                                                          |
|   +------------------+    +------------------+                    |
|   | RTCRtpSender     |    | RTCRtpReceiver   |                    |
|   | (发送轨道)        |    | (接收轨道)        |                    |
|   +------------------+    +------------------+                    |
|            |                      |                               |
|            v                      v                               |
|   +------------------+                                            |
|   | RTCRtpTransceiver|  双向媒体通道                               |
|   +------------------+                                            |
|            |                                                      |
|            v                                                      |
|   +------------------+                                            |
|   | RTCPeerConnection|  管理所有 Transceiver                      |
|   +------------------+                                            |
|                                                                   |
+-------------------------------------------------------------------+
```

### 1.2 核心概念关系

```
MediaStream
    |
    +-- MediaStreamTrack (audio)
    |       |
    |       +-- RTCRtpSender ----+
    |                            |
    +-- MediaStreamTrack (video) +-- RTCRtpTransceiver
            |                    |
            +-- RTCRtpSender ----+
                                 |
RTCRtpReceiver -----------------+
```

### 1.3 SDP 中的媒体描述

```
SDP 中每个 m= 行对应一个 Transceiver:

v=0
o=- 123456 2 IN IP4 127.0.0.1
s=-
t=0 0
a=group:BUNDLE 0 1
a=msid-semantic: WMS stream1

m=audio 9 UDP/TLS/RTP/SAVPF 111
a=mid:0
a=sendrecv
a=msid:stream1 audio_track_id
a=ssrc:1001 cname:user@example.com
...

m=video 9 UDP/TLS/RTP/SAVPF 96 97
a=mid:1
a=sendrecv
a=msid:stream1 video_track_id
a=ssrc:2001 cname:user@example.com
...
```

---

## 2. MediaStreamTrack

### 2.1 Track 基础

MediaStreamTrack 表示单个媒体轨道(音频或视频)。

```javascript
// 获取媒体轨道
const stream = await navigator.mediaDevices.getUserMedia({
    audio: true,
    video: true
});

const audioTrack = stream.getAudioTracks()[0];
const videoTrack = stream.getVideoTracks()[0];

// Track 属性
console.log('Track ID:', videoTrack.id);
console.log('Kind:', videoTrack.kind);        // 'audio' 或 'video'
console.log('Label:', videoTrack.label);      // 设备名称
console.log('Enabled:', videoTrack.enabled);  // 是否启用
console.log('Muted:', videoTrack.muted);      // 是否静音
console.log('ReadyState:', videoTrack.readyState); // 'live' 或 'ended'
```

### 2.2 Track 状态

```
Track 状态转换:

         +-------+
         | live  |  正常工作
         +---+---+
             |
             | stop() 或设备断开
             v
         +-------+
         | ended |  已结束
         +-------+

事件:
- onmute: 轨道被静音
- onunmute: 轨道取消静音
- onended: 轨道结束
```

### 2.3 Track 约束

```javascript
// 获取当前约束
const constraints = videoTrack.getConstraints();
console.log(constraints);

// 获取当前设置
const settings = videoTrack.getSettings();
console.log('Width:', settings.width);
console.log('Height:', settings.height);
console.log('FrameRate:', settings.frameRate);
console.log('DeviceId:', settings.deviceId);

// 获取能力
const capabilities = videoTrack.getCapabilities();
console.log('Width range:', capabilities.width);
console.log('Height range:', capabilities.height);
console.log('FrameRate range:', capabilities.frameRate);

// 应用新约束
await videoTrack.applyConstraints({
    width: { ideal: 1280 },
    height: { ideal: 720 },
    frameRate: { max: 30 }
});
```

### 2.4 Track 克隆

```javascript
// 克隆轨道
const clonedTrack = originalTrack.clone();

// 用途:
// 1. 发送到多个 PeerConnection
// 2. 本地预览和发送使用不同设置
// 3. 录制和发送分离

// 克隆的轨道是独立的
clonedTrack.enabled = false; // 不影响原轨道
```

---

## 3. RtpSender 与 RtpReceiver

### 3.1 RTCRtpSender

RTCRtpSender 负责发送媒体数据。

```javascript
// 获取所有发送器
const senders = pc.getSenders();

for (const sender of senders) {
    console.log('Track:', sender.track?.kind);
    console.log('Transport:', sender.transport);
    console.log('DTMF:', sender.dtmf); // 仅音频
}

// 获取发送参数
const params = sender.getParameters();
console.log('Encodings:', params.encodings);
console.log('Codecs:', params.codecs);
console.log('Header Extensions:', params.headerExtensions);
```

### 3.2 发送参数

```javascript
// 发送参数结构
const params = {
    transactionId: 'abc123',
    encodings: [
        {
            rid: 'high',
            active: true,
            maxBitrate: 2500000,
            scaleResolutionDownBy: 1,
            maxFramerate: 30
        },
        {
            rid: 'mid',
            active: true,
            maxBitrate: 500000,
            scaleResolutionDownBy: 2
        },
        {
            rid: 'low',
            active: true,
            maxBitrate: 150000,
            scaleResolutionDownBy: 4
        }
    ],
    codecs: [
        {
            mimeType: 'video/VP8',
            payloadType: 96,
            clockRate: 90000
        }
    ],
    headerExtensions: [
        {
            uri: 'urn:ietf:params:rtp-hdrext:sdes:mid',
            id: 1,
            encrypted: false
        }
    ]
};

// 修改发送参数
params.encodings[0].maxBitrate = 1500000;
await sender.setParameters(params);
```

### 3.3 RTCRtpReceiver

RTCRtpReceiver 负责接收媒体数据。

```javascript
// 获取所有接收器
const receivers = pc.getReceivers();

for (const receiver of receivers) {
    console.log('Track:', receiver.track.kind);
    console.log('Transport:', receiver.transport);
    
    // 获取同步源
    const sources = receiver.getSynchronizationSources();
    for (const source of sources) {
        console.log('SSRC:', source.source);
        console.log('Timestamp:', source.timestamp);
        console.log('Audio Level:', source.audioLevel);
    }
    
    // 获取贡献源 (混音场景)
    const csrcs = receiver.getContributingSources();
}
```

### 3.4 统计信息

```javascript
// 获取发送统计
const senderStats = await sender.getStats();
senderStats.forEach(report => {
    if (report.type === 'outbound-rtp') {
        console.log('Bytes sent:', report.bytesSent);
        console.log('Packets sent:', report.packetsSent);
        console.log('Frames encoded:', report.framesEncoded);
        console.log('Key frames:', report.keyFramesEncoded);
        console.log('QP sum:', report.qpSum);
    }
});

// 获取接收统计
const receiverStats = await receiver.getStats();
receiverStats.forEach(report => {
    if (report.type === 'inbound-rtp') {
        console.log('Bytes received:', report.bytesReceived);
        console.log('Packets received:', report.packetsReceived);
        console.log('Packets lost:', report.packetsLost);
        console.log('Jitter:', report.jitter);
        console.log('Frames decoded:', report.framesDecoded);
    }
});
```

### 3.5 替换轨道

```javascript
// 替换发送的轨道 (不重新协商)
const newVideoTrack = newStream.getVideoTracks()[0];
await sender.replaceTrack(newVideoTrack);

// 用途:
// 1. 切换摄像头
// 2. 切换屏幕共享
// 3. 静音/取消静音 (replaceTrack(null))
```

---

## 4. RTCRtpTransceiver

### 4.1 Transceiver 概念

RTCRtpTransceiver 表示一个双向媒体通道,包含一个 Sender 和一个 Receiver。

```
Transceiver 结构:

+--------------------------------------------------+
|                 RTCRtpTransceiver                |
+--------------------------------------------------+
|                                                  |
|   +------------------+    +------------------+   |
|   | RTCRtpSender     |    | RTCRtpReceiver   |   |
|   | (发送)            |    | (接收)            |   |
|   +------------------+    +------------------+   |
|                                                  |
|   mid: "0"                                       |
|   direction: "sendrecv"                          |
|   currentDirection: "sendrecv"                   |
|   stopped: false                                 |
|                                                  |
+--------------------------------------------------+
```

### 4.2 创建 Transceiver

```javascript
// 方式 1: addTrack 自动创建
const sender = pc.addTrack(videoTrack, stream);
// 自动创建 Transceiver,direction = sendrecv

// 方式 2: addTransceiver 手动创建
const transceiver = pc.addTransceiver('video', {
    direction: 'sendonly',
    streams: [stream],
    sendEncodings: [
        { rid: 'high', maxBitrate: 2500000 },
        { rid: 'mid', maxBitrate: 500000 },
        { rid: 'low', maxBitrate: 150000 }
    ]
});

// 方式 3: 接收 Offer 时自动创建
// 当收到包含新 m= 行的 Offer 时
```

### 4.3 Direction (方向)

```
Transceiver 方向:

+------------+------------------+------------------+
| direction  | 发送             | 接收             |
+------------+------------------+------------------+
| sendrecv   | 是               | 是               |
| sendonly   | 是               | 否               |
| recvonly   | 否               | 是               |
| inactive   | 否               | 否               |
+------------+------------------+------------------+

设置方向:
transceiver.direction = 'sendonly';

注意:
- direction: 期望的方向
- currentDirection: 协商后的实际方向
```

### 4.4 mid (媒体标识)

```javascript
// mid 用于标识 SDP 中的 m= 行
console.log('mid:', transceiver.mid);

// SDP 中:
// m=video 9 UDP/TLS/RTP/SAVPF 96
// a=mid:0
//        ^
//        这就是 mid

// mid 在协商完成后才有值
pc.onnegotiationneeded = async () => {
    const offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    // 此时 transceiver.mid 有值
};
```

### 4.5 停止 Transceiver

```javascript
// 停止 Transceiver
transceiver.stop();

// 停止后:
// - stopped = true
// - direction = 'stopped'
// - sender.track = null
// - 需要重新协商

// 注意: 停止是不可逆的
// 如果需要暂停,使用 direction = 'inactive'
```

### 4.6 Transceiver 复用

```javascript
// 查找可复用的 Transceiver
function findReusableTransceiver(pc, kind) {
    for (const transceiver of pc.getTransceivers()) {
        if (transceiver.stopped) continue;
        if (transceiver.sender.track) continue;
        if (transceiver.receiver.track.kind !== kind) continue;
        return transceiver;
    }
    return null;
}

// 复用 Transceiver 添加轨道
const transceiver = findReusableTransceiver(pc, 'video');
if (transceiver) {
    await transceiver.sender.replaceTrack(videoTrack);
    transceiver.direction = 'sendrecv';
} else {
    pc.addTrack(videoTrack, stream);
}
```

---

## 5. Simulcast

### 5.1 Simulcast 概念

Simulcast 同时发送多个不同质量的视频流。

```
Simulcast 架构:

发送端:
+------------------+
|    摄像头        |
+--------+---------+
         |
         v
+------------------+
|    编码器        |
+--------+---------+
         |
    +----+----+----+
    |    |    |    |
    v    v    v    v
  720p  480p  240p
  high  mid   low
    |    |    |
    +----+----+----+
         |
         v
+------------------+
|   RTP 发送       |
+------------------+
         |
         v
      网络

接收端 (SFU):
选择合适的流转发给不同的接收者
```

### 5.2 启用 Simulcast

```javascript
// 方式 1: addTransceiver
const transceiver = pc.addTransceiver(videoTrack, {
    direction: 'sendonly',
    sendEncodings: [
        {
            rid: 'high',
            maxBitrate: 2500000,
            scaleResolutionDownBy: 1,
            maxFramerate: 30
        },
        {
            rid: 'mid',
            maxBitrate: 500000,
            scaleResolutionDownBy: 2,
            maxFramerate: 30
        },
        {
            rid: 'low',
            maxBitrate: 150000,
            scaleResolutionDownBy: 4,
            maxFramerate: 15
        }
    ]
});

// 方式 2: 修改 SDP (旧方法)
// 在 SDP 中添加 a=simulcast 和 a=rid 行
```

### 5.3 SDP 中的 Simulcast

```
Simulcast SDP 示例:

m=video 9 UDP/TLS/RTP/SAVPF 96
a=mid:1
a=sendonly
a=rid:high send
a=rid:mid send
a=rid:low send
a=simulcast:send high;mid;low
a=ssrc-group:SIM 1001 1002 1003
a=ssrc:1001 cname:user@example.com
a=ssrc:1002 cname:user@example.com
a=ssrc:1003 cname:user@example.com
```

### 5.4 控制 Simulcast 层

```javascript
// 获取发送参数
const params = sender.getParameters();

// 禁用某一层
params.encodings[2].active = false; // 禁用 low

// 调整码率
params.encodings[0].maxBitrate = 1500000;

// 应用更改
await sender.setParameters(params);
```

### 5.5 SFU 选择层

```javascript
// SFU 端: 根据接收者情况选择层
function selectLayer(receiverBandwidth, availableLayers) {
    // 按码率排序
    const sorted = availableLayers.sort((a, b) => b.bitrate - a.bitrate);
    
    // 选择不超过接收者带宽的最高层
    for (const layer of sorted) {
        if (layer.bitrate <= receiverBandwidth) {
            return layer;
        }
    }
    
    // 返回最低层
    return sorted[sorted.length - 1];
}
```

---

## 6. SVC (可伸缩视频编码)

### 6.1 SVC 概念

SVC (Scalable Video Coding) 将视频编码为多个可分离的层。

```
SVC 层次结构:

时间可伸缩 (Temporal):
+-------+-------+-------+-------+
| T0    | T1    | T0    | T1    |  帧
+-------+-------+-------+-------+
  15fps   30fps

空间可伸缩 (Spatial):
+------------------+
|     S2 (720p)    |
+------------------+
|     S1 (480p)    |
+------------------+
|     S0 (240p)    |
+------------------+

质量可伸缩 (Quality/SNR):
+------------------+
|     Q2 (高质量)   |
+------------------+
|     Q1 (中质量)   |
+------------------+
|     Q0 (低质量)   |
+------------------+
```

### 6.2 SVC vs Simulcast

| 特性 | Simulcast | SVC |
|------|-----------|-----|
| 编码 | 多次独立编码 | 一次分层编码 |
| 带宽 | 较高 (多流) | 较低 (分层) |
| CPU | 较高 | 较低 |
| 灵活性 | 高 | 中 |
| 编解码器支持 | VP8, H.264 | VP9, AV1 |

### 6.3 VP9 SVC

```javascript
// 启用 VP9 SVC
const transceiver = pc.addTransceiver(videoTrack, {
    direction: 'sendonly',
    sendEncodings: [
        {
            scalabilityMode: 'L3T3', // 3 空间层, 3 时间层
            maxBitrate: 2500000
        }
    ]
});

// 可用的 scalabilityMode:
// L1T1: 1 空间层, 1 时间层 (无 SVC)
// L1T2: 1 空间层, 2 时间层
// L1T3: 1 空间层, 3 时间层
// L2T1: 2 空间层, 1 时间层
// L2T2: 2 空间层, 2 时间层
// L2T3: 2 空间层, 3 时间层
// L3T1: 3 空间层, 1 时间层
// L3T2: 3 空间层, 2 时间层
// L3T3: 3 空间层, 3 时间层
```

### 6.4 SVC 依赖结构

```
L3T3 依赖结构:

时间 -->
      T0      T1      T2      T0      T1      T2
S2    K -----> P -----> P -----> P -----> P -----> P
      |        |        |        |        |        |
      v        v        v        v        v        v
S1    K -----> P -----> P -----> P -----> P -----> P
      |        |        |        |        |        |
      v        v        v        v        v        v
S0    K -----> P -----> P -----> P -----> P -----> P

K: 关键帧
P: 预测帧
箭头: 依赖关系

丢弃规则:
- 丢弃高层不影响低层
- 丢弃 T2 仍可播放 15fps
- 丢弃 S2 仍可播放 480p
```

### 6.5 SFU 处理 SVC

```javascript
// SFU 端: 根据接收者选择 SVC 层
function selectSvcLayers(receiverBandwidth, receiverResolution) {
    // 选择空间层
    let spatialLayer = 0;
    if (receiverResolution >= 720) spatialLayer = 2;
    else if (receiverResolution >= 480) spatialLayer = 1;
    
    // 选择时间层
    let temporalLayer = 2; // 默认最高帧率
    if (receiverBandwidth < 500000) temporalLayer = 1;
    if (receiverBandwidth < 200000) temporalLayer = 0;
    
    return { spatialLayer, temporalLayer };
}

// 转发时只发送选定的层
function forwardSvcPacket(packet, targetLayers) {
    const packetLayer = parseSvcLayer(packet);
    
    if (packetLayer.spatial <= targetLayers.spatialLayer &&
        packetLayer.temporal <= targetLayers.temporalLayer) {
        forward(packet);
    }
    // 否则丢弃
}
```

---

## 7. 总结

### 7.1 媒体模型核心要点

| 概念 | 说明 |
|------|------|
| MediaStreamTrack | 单个媒体轨道 |
| RTCRtpSender | 发送媒体 |
| RTCRtpReceiver | 接收媒体 |
| RTCRtpTransceiver | 双向通道 |
| Simulcast | 多流发送 |
| SVC | 分层编码 |

### 7.2 选择建议

```
场景选择:

1:1 通话:
- 单流即可
- 可选 SVC 应对网络波动

小型会议 (< 10 人):
- Simulcast 或 SVC
- SFU 架构

大型会议 (> 10 人):
- Simulcast + SFU
- 或 SVC + SFU
- 考虑 MCU 混流

直播:
- 单向 Simulcast
- CDN 分发
```

### 7.3 第三部分总结

恭喜你完成了 WebRTC 媒体传输系列的学习。让我们回顾这六篇文章的核心内容:

| 篇章 | 主题 | 核心收获 |
|------|------|---------|
| 第 12 篇 | RTP 协议 | 理解媒体包结构 |
| 第 13 篇 | RTCP | 掌握反馈和同步机制 |
| 第 14 篇 | SRTP | 理解安全传输 |
| 第 15 篇 | Jitter Buffer | 掌握网络容错 |
| 第 16 篇 | BWE | 理解带宽估计 |
| 第 17 篇 | 媒体模型 | 掌握现代媒体协商 |

### 7.4 下一步学习建议

1. **服务端架构**: 学习 SFU/MCU 设计
2. **编解码器**: 深入 VP8/VP9/H.264/AV1
3. **音频处理**: 回声消除、降噪
4. **生产实践**: 监控、调试、优化

---

## 参考资料

1. [W3C WebRTC API](https://www.w3.org/TR/webrtc/)
2. [RFC 8829 - JSEP](https://datatracker.ietf.org/doc/html/rfc8829)
3. [RFC 8853 - Simulcast](https://datatracker.ietf.org/doc/html/rfc8853)
4. [WebRTC Samples - Simulcast](https://webrtc.github.io/samples/src/content/peerconnection/simulcast/)

---

> 作者: WebRTC 技术专栏  
> 系列: 媒体传输深入讲解 (6/6)  
> 上一篇: [带宽估计 BWE](./16-bandwidth-estimation.md)

---

恭喜完成 WebRTC 媒体传输系列!
