---
title: "WebRTC 是什么？能做什么？（概览篇）"
description: "1. [WebRTC 的发展历史](#1-webrtc-的发展历史)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 1
---

> 本文是 WebRTC 系列专栏的第一篇，旨在帮助读者建立对 WebRTC 的整体认知，了解其发展历程、核心能力、主要组件以及优势与局限。

---

## 目录

1. [WebRTC 的发展历史](#1-webrtc-的发展历史)
2. [WebRTC 能解决什么问题](#2-webrtc-能解决什么问题)
3. [WebRTC 核心组件](#3-webrtc-核心组件)
4. [WebRTC 的优势与局限](#4-webrtc-的优势与局限)
5. [总结](#5-总结)

---

## 1. WebRTC 的发展历史

### 1.1 起源：从 GIPS 到 Google

WebRTC（Web Real-Time Communication）的故事要从一家名为 **Global IP Solutions（GIPS）** 的瑞典公司说起。GIPS 成立于 1999 年，专注于开发高质量的音视频编解码器和实时通信技术。他们的技术被广泛应用于 Skype、Yahoo Messenger、QQ 等知名即时通讯软件中。

**2010 年 5 月**，Google 以 6820 万美元收购了 GIPS。这次收购为 WebRTC 的诞生奠定了技术基础。

### 1.2 WebRTC 的诞生与标准化

| 时间 | 里程碑事件 |
|------|-----------|
| **2011 年 5 月** | Google 宣布开源 WebRTC 项目，将 GIPS 的核心技术贡献给开源社区 |
| **2011 年 10 月** | W3C 发布 WebRTC 1.0 的第一个工作草案 |
| **2012 年 1 月** | Chrome 稳定版开始支持 WebRTC |
| **2013 年 2 月** | Firefox 和 Chrome 之间首次实现跨浏览器 WebRTC 通话 |
| **2017 年 11 月** | Apple 在 Safari 11 中加入 WebRTC 支持 |
| **2021 年 1 月** | W3C 和 IETF 正式将 WebRTC 1.0 定为推荐标准（Recommendation） |

### 1.3 标准化组织

WebRTC 的标准化由两个组织共同推进：

- **W3C（World Wide Web Consortium）**：负责定义 JavaScript API 规范
- **IETF（Internet Engineering Task Force）**：负责定义底层协议规范（如 ICE、DTLS-SRTP 等）

### 1.4 版本演进

- **WebRTC 1.0**：2021 年正式成为 W3C 推荐标准，定义了核心 API
- **WebRTC NV（Next Version）**：正在开发中，包含 Insertable Streams、WebTransport 集成等新特性

---

## 2. WebRTC 能解决什么问题

WebRTC 的核心价值在于：**让浏览器具备原生的实时音视频通信能力，无需安装任何插件**。

### 2.1 典型应用场景

####  实时音视频通话

这是 WebRTC 最核心的应用场景。

```
用户 A 的浏览器 <-----> 用户 B 的浏览器
     |                      |
  摄像头/麦克风          摄像头/麦克风
```

**典型产品**：
- Google Meet
- Discord（Web 版）
- Facebook Messenger
- Zoom（Web 版）

####  直播互动

WebRTC 的低延迟特性（通常 < 500ms）使其非常适合需要实时互动的直播场景。

**应用场景**：
- 连麦直播
- 在线拍卖
- 体育赛事实时竞猜
- 电商直播带货

**对比传统直播协议**：

| 协议 | 典型延迟 | 适用场景 |
|------|---------|---------|
| HLS | 10-30 秒 | 点播、大规模直播 |
| RTMP | 3-5 秒 | 推流、传统直播 |
| **WebRTC** | **< 500ms** | **实时互动** |

####  在线教育

WebRTC 在在线教育领域的应用非常广泛：

- **1 对 1 辅导**：师生实时音视频互动
- **小班课**：多人音视频会议
- **大班课**：老师端使用 WebRTC，学生端可降级为 HLS
- **互动白板**：通过 DataChannel 实现实时协作

**典型产品**：ClassIn、腾讯课堂、VIPKID

####  P2P 文件传输

利用 WebRTC 的 DataChannel，可以实现浏览器之间的点对点文件传输：

```javascript
// 发送端
dataChannel.send(fileData);

// 接收端
dataChannel.onmessage = (event) => {
    saveFile(event.data);
};
```

**典型产品**：ShareDrop、Snapdrop、PairDrop

#### 云游戏与远程桌面

WebRTC 的低延迟特性使其成为云游戏和远程桌面的理想选择：

- **云游戏**：Google Stadia（已关闭）、NVIDIA GeForce NOW
- **远程桌面**：Parsec、Chrome Remote Desktop

####  IoT 与智能设备

- 智能门铃实时视频
- 无人机实时图传
- 工业设备远程监控

### 2.2 WebRTC 解决的核心痛点

在 WebRTC 出现之前，浏览器实现实时通信面临诸多挑战：

| 痛点 | 传统方案 | WebRTC 方案 |
|------|---------|------------|
| 需要安装插件 | Flash、Java Applet | 原生支持，无需插件 |
| 跨平台兼容性差 | 各平台独立开发 | 统一 API，跨浏览器 |
| 延迟高 | 服务器中转 | P2P 直连 |
| 开发成本高 | 需要深厚音视频背景 | 简单 API 封装 |

---

## 3. WebRTC 核心组件

WebRTC 的核心由三大组件构成：

```
┌─────────────────────────────────────────────────────────────┐
│                      WebRTC 核心组件                         │
├─────────────────┬─────────────────────┬─────────────────────┤
│  MediaStream    │  RTCPeerConnection  │   RTCDataChannel    │
│  (媒体流)        │   (对等连接)         │    (数据通道)        │
├─────────────────┼─────────────────────┼─────────────────────┤
│ 获取音视频数据   │ 建立 P2P 连接        │ 传输任意数据         │
│ 处理媒体轨道     │ 处理信令交换         │ 支持可靠/不可靠传输   │
│ 控制设备访问     │ 管理 ICE 候选        │ 类似 WebSocket API   │
└─────────────────┴─────────────────────┴─────────────────────┘
```

### 3.1 MediaStream（媒体流）

MediaStream 负责获取和管理音视频数据。

#### 获取媒体流

```javascript
// 获取摄像头和麦克风
const stream = await navigator.mediaDevices.getUserMedia({
    video: true,
    audio: true
});

// 获取屏幕共享
const screenStream = await navigator.mediaDevices.getDisplayMedia({
    video: true
});
```

#### 核心概念

- **MediaStream**：包含一个或多个轨道的媒体流
- **MediaStreamTrack**：单个音频或视频轨道
- **MediaDevices**：访问媒体设备的接口

#### 轨道操作

```javascript
// 获取所有视频轨道
const videoTracks = stream.getVideoTracks();

// 获取所有音频轨道
const audioTracks = stream.getAudioTracks();

// 禁用视频轨道（关闭摄像头但保持连接）
videoTracks[0].enabled = false;

// 停止轨道（完全释放设备）
videoTracks[0].stop();
```

### 3.2 RTCPeerConnection（对等连接）

RTCPeerConnection 是 WebRTC 的核心，负责建立和维护 P2P 连接。

#### 核心职责

1. **信令交换**：交换 SDP（Session Description Protocol）
2. **NAT 穿透**：通过 ICE 框架建立连接
3. **媒体传输**：使用 SRTP 加密传输音视频
4. **连接管理**：监控连接状态、处理重连

#### 基本使用

```javascript
// 创建 PeerConnection
const pc = new RTCPeerConnection({
    iceServers: [
        { urls: 'stun:stun.l.google.com:19302' }
    ]
});

// 添加本地媒体流
stream.getTracks().forEach(track => {
    pc.addTrack(track, stream);
});

// 创建 Offer
const offer = await pc.createOffer();
await pc.setLocalDescription(offer);

// 处理远端 Answer
await pc.setRemoteDescription(remoteAnswer);

// 监听远端媒体流
pc.ontrack = (event) => {
    remoteVideo.srcObject = event.streams[0];
};
```

#### 连接建立流程

```
    发起方 (Caller)                    接收方 (Callee)
         │                                  │
         │  1. createOffer()                │
         │──────────────────────────────────>
         │                                  │
         │  2. setLocalDescription(offer)   │
         │                                  │
         │  3. 通过信令服务器发送 Offer ────────>
         │                                  │
         │                    4. setRemoteDescription(offer)
         │                                  │
         │                    5. createAnswer()
         │                                  │
         │                    6. setLocalDescription(answer)
         │                                  │
         │  <──────── 7. 通过信令服务器发送 Answer
         │                                  │
         │  8. setRemoteDescription(answer) │
         │                                  │
         │  <═══════ 9. ICE 候选交换 ═══════>
         │                                  │
         │  <══════ 10. P2P 连接建立 ══════>
         │                                  │
```

### 3.3 RTCDataChannel（数据通道）

DataChannel 允许在 P2P 连接上传输任意数据。

#### 特点

- 基于 SCTP（Stream Control Transmission Protocol）
- 支持可靠传输和不可靠传输
- 支持有序和无序传输
- API 类似 WebSocket

#### 基本使用

```javascript
// 创建数据通道
const dataChannel = pc.createDataChannel('myChannel', {
    ordered: true,           // 是否保证顺序
    maxRetransmits: 3        // 最大重传次数
});

// 发送数据
dataChannel.send('Hello, WebRTC!');
dataChannel.send(new ArrayBuffer(1024));

// 接收数据
dataChannel.onmessage = (event) => {
    console.log('Received:', event.data);
};

// 监听状态变化
dataChannel.onopen = () => console.log('Channel opened');
dataChannel.onclose = () => console.log('Channel closed');
```

#### 配置选项

| 选项 | 说明 | 默认值 |
|------|------|-------|
| `ordered` | 是否保证消息顺序 | `true` |
| `maxPacketLifeTime` | 消息最大生存时间（ms） | - |
| `maxRetransmits` | 最大重传次数 | - |
| `protocol` | 子协议名称 | `''` |
| `negotiated` | 是否手动协商 | `false` |
| `id` | 通道 ID | 自动分配 |

> ⚠️ `maxPacketLifeTime` 和 `maxRetransmits` 互斥，只能设置其一。

---

## 4. WebRTC 的优势与局限

### 4.1 优势

#### ✅ 原生支持，无需插件

```html
<!-- 传统方案：需要 Flash -->
<object type="application/x-shockwave-flash">...</object>

<!-- WebRTC：原生支持 -->
<video id="localVideo" autoplay muted></video>
<script>
    navigator.mediaDevices.getUserMedia({video: true})
        .then(stream => localVideo.srcObject = stream);
</script>
```

#### ✅ 超低延迟

| 场景 | 延迟 |
|------|------|
| 局域网 P2P | < 50ms |
| 公网 P2P | 100-300ms |
| TURN 中转 | 200-500ms |

#### ✅ 端到端加密

WebRTC 强制使用加密：
- **DTLS**（Datagram Transport Layer Security）：密钥交换
- **SRTP**（Secure Real-time Transport Protocol）：媒体加密

```
┌──────────────────────────────────────────────────┐
│                  WebRTC 安全架构                  │
├──────────────────────────────────────────────────┤
│  应用层    │  SDP / ICE                          │
├──────────────────────────────────────────────────┤
│  安全层    │  DTLS (密钥交换) + SRTP (媒体加密)   │
├──────────────────────────────────────────────────┤
│  传输层    │  UDP / TCP                          │
└──────────────────────────────────────────────────┘
```

#### ✅ P2P 直连，节省带宽成本

```
传统方案（服务器中转）：
用户 A ──> 服务器 ──> 用户 B
         带宽成本 ×2

WebRTC P2P：
用户 A <────────────> 用户 B
         带宽成本 ×0
```

#### ✅ 跨平台支持

| 平台 | 支持情况 |
|------|---------|
| Chrome | ✅ 完整支持 |
| Firefox | ✅ 完整支持 |
| Safari | ✅ 支持（iOS 11+） |
| Edge | ✅ 完整支持 |
| Android WebView | ✅ 支持 |
| iOS WKWebView | ⚠️ 部分支持 |

#### ✅ 开源且免费

- libwebrtc 完全开源（BSD 许可证）
- 无需支付专利费用
- 活跃的社区支持

### 4.2 局限

#### ❌ 大规模场景的挑战

P2P 架构在大规模场景下面临挑战：

```
N 个用户全互联：
连接数 = N × (N-1) / 2

10 人会议 = 45 条连接
50 人会议 = 1225 条连接  ← 不可行！
```

**解决方案**：
- **SFU（Selective Forwarding Unit）**：服务器转发，每人只需 1 条上行
- **MCU（Multipoint Control Unit）**：服务器混流，带宽最优但 CPU 开销大

#### ❌ NAT 穿透成功率

不同 NAT 类型的穿透成功率：

| NAT 类型 | 穿透难度 | 成功率 |
|---------|---------|-------|
| Full Cone | 简单 | ~95% |
| Restricted Cone | 中等 | ~85% |
| Port Restricted Cone | 较难 | ~70% |
| Symmetric | 困难 | ~30% |

当 P2P 穿透失败时，需要 TURN 服务器中转，这会：
- 增加延迟
- 产生服务器带宽成本

#### ❌ 移动端的挑战

- **iOS WKWebView**：不支持 `getUserMedia`
- **后台运行**：App 切到后台时连接可能中断
- **网络切换**：WiFi/4G 切换时需要重新建立连接

#### ❌ 信令服务器仍然需要

WebRTC 本身不包含信令机制，开发者需要自行实现：

```javascript
// 需要自己实现信令服务器
const signalingServer = new WebSocket('wss://your-signaling-server.com');

signalingServer.send(JSON.stringify({
    type: 'offer',
    sdp: offer.sdp
}));
```

#### ❌ 调试困难

- 网络问题难以定位
- 编解码问题需要专业知识
- 缺乏统一的调试工具

**推荐调试工具**：
- `chrome://webrtc-internals`
- Wireshark（配合 SSLKEYLOGFILE）

#### ❌ 编解码器兼容性

| 编解码器 | Chrome | Firefox | Safari |
|---------|--------|---------|--------|
| VP8 | ✅ | ✅ | ✅ |
| VP9 | ✅ | ✅ | ❌ |
| H.264 | ✅ | ✅ | ✅ |
| AV1 | ✅ | ⚠️ | ❌ |
| Opus | ✅ | ✅ | ✅ |

---

## 5. 总结

### WebRTC 核心要点

| 方面 | 要点 |
|------|------|
| **定义** | 浏览器原生的实时音视频通信技术 |
| **标准化** | W3C（API）+ IETF（协议） |
| **核心组件** | MediaStream + RTCPeerConnection + RTCDataChannel |
| **核心优势** | 无插件、低延迟、端到端加密、P2P |
| **主要局限** | 大规模场景、NAT 穿透、移动端兼容 |

### 适用场景判断

```
是否需要实时互动？
    │
    ├── 是 ──> 延迟要求 < 1s？
    │              │
    │              ├── 是 ──> ✅ WebRTC
    │              │
    │              └── 否 ──> 考虑 RTMP/HLS
    │
    └── 否 ──> 考虑其他方案
```

### 下一篇预告

在下一篇文章中，我们将深入探讨 **WebRTC 的架构设计**，包括：
- 浏览器中的 WebRTC 架构
- API 体系详解
- 信令流程
- libwebrtc 媒体引擎结构

---

## 参考资料

1. [WebRTC 1.0: Real-Time Communication Between Browsers - W3C](https://www.w3.org/TR/webrtc/)
2. [WebRTC Official Website](https://webrtc.org/)
3. [High Performance Browser Networking - WebRTC Chapter](https://hpbn.co/webrtc/)
4. [Google's WebRTC Project](https://webrtc.googlesource.com/src/)
5. [MDN Web Docs - WebRTC API](https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API)

---

> **作者**：WebRTC 技术专栏  
> **系列**：WebRTC 基础与快速入门（1/5）  
> **下一篇**：[WebRTC 架构概览（整体框架篇）](./02-webrtc-architecture.md)
