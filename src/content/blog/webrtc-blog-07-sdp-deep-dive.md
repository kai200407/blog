---
title: "深度理解 SDP (Session Description Protocol)"
description: "1. [SDP 概述](#1-sdp-概述)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 7
---

> 本文是 WebRTC 系列专栏的第七篇,将深入剖析 SDP 协议的结构、Offer/Answer 模型以及关键参数的含义。掌握 SDP 是理解 WebRTC 信令的关键。

---

## 目录

1. [SDP 概述](#1-sdp-概述)
2. [SDP 结构详解](#2-sdp-结构详解)
3. [Offer/Answer 模型](#3-offeranswer-模型)
4. [SDP 关键参数解读](#4-sdp-关键参数解读)
5. [SDP 修改与优化](#5-sdp-修改与优化)
6. [实战案例分析](#6-实战案例分析)
7. [总结](#7-总结)

---

## 1. SDP 概述

### 1.1 什么是 SDP

SDP (Session Description Protocol) 是一种用于描述多媒体会话的文本协议,定义在 RFC 4566 中。在 WebRTC 中,SDP 用于描述:

- 媒体类型(音频、视频、数据)
- 编解码器及其参数
- 传输协议和端口
- 加密参数
- 网络连接信息

### 1.2 SDP 的作用

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        SDP 在 WebRTC 中的作用                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   用户 A                                              用户 B            │
│                                                                         │
│   ┌─────────────────┐                      ┌─────────────────┐         │
│   │ 我的媒体能力:    │                      │ 我的媒体能力:    │         │
│   │ - VP8, VP9, H264│      Offer SDP       │ - VP8, H264     │         │
│   │ - Opus, G711    │ ──────────────────>  │ - Opus          │         │
│   │ - 1280x720      │                      │ - 1920x1080     │         │
│   └─────────────────┘                      └─────────────────┘         │
│                                                                         │
│                                                     │                   │
│                                                     ▼                   │
│                                                                         │
│                                            ┌─────────────────┐         │
│                                            │ 协商结果:        │         │
│                            Answer SDP      │ - VP8 (共同支持) │         │
│                       <──────────────────  │ - Opus          │         │
│                                            │ - 1280x720      │         │
│                                            └─────────────────┘         │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.3 SDP 的特点

| 特点 | 说明 |
|------|------|
| 文本格式 | 纯文本,易于阅读和调试 |
| 行结构 | 每行以单个字符类型开头 |
| 顺序敏感 | 某些字段必须按特定顺序出现 |
| 可扩展 | 通过属性行(a=)扩展功能 |

---

## 2. SDP 结构详解

### 2.1 SDP 整体结构

SDP 由两部分组成:会话级描述和媒体级描述。

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           SDP 结构                                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │                    会话级描述 (Session-level)                    │  │
│   │                                                                 │  │
│   │   v=  (协议版本)                                                │  │
│   │   o=  (会话发起者)                                              │  │
│   │   s=  (会话名称)                                                │  │
│   │   t=  (会话时间)                                                │  │
│   │   a=  (会话级属性)                                              │  │
│   │                                                                 │  │
│   └─────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │                    媒体级描述 (Media-level) - 音频                │  │
│   │                                                                 │  │
│   │   m=  (媒体描述)                                                │  │
│   │   c=  (连接信息)                                                │  │
│   │   a=  (媒体级属性)                                              │  │
│   │                                                                 │  │
│   └─────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │                    媒体级描述 (Media-level) - 视频                │  │
│   │                                                                 │  │
│   │   m=  (媒体描述)                                                │  │
│   │   c=  (连接信息)                                                │  │
│   │   a=  (媒体级属性)                                              │  │
│   │                                                                 │  │
│   └─────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 完整 SDP 示例

以下是一个典型的 WebRTC SDP 示例:

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
a=ice-pwd:efghijklmnopqrstuvwxyz1234567890
a=ice-options:trickle
a=fingerprint:sha-256 AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99
a=setup:actpass
a=mid:0
a=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level
a=extmap:2 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time
a=sendrecv
a=msid:stream_id audio_track_id
a=rtcp-mux
a=rtpmap:111 opus/48000/2
a=rtcp-fb:111 transport-cc
a=fmtp:111 minptime=10;useinbandfec=1
a=rtpmap:103 ISAC/16000
a=rtpmap:104 ISAC/32000
a=rtpmap:9 G722/8000
a=rtpmap:0 PCMU/8000
a=rtpmap:8 PCMA/8000
a=ssrc:1234567890 cname:abcdefghij
a=ssrc:1234567890 msid:stream_id audio_track_id

m=video 9 UDP/TLS/RTP/SAVPF 96 97 98 99 100 101 102
c=IN IP4 0.0.0.0
a=rtcp:9 IN IP4 0.0.0.0
a=ice-ufrag:abcd
a=ice-pwd:efghijklmnopqrstuvwxyz1234567890
a=ice-options:trickle
a=fingerprint:sha-256 AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99
a=setup:actpass
a=mid:1
a=extmap:3 urn:ietf:params:rtp-hdrext:toffset
a=extmap:4 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time
a=extmap:5 urn:3gpp:video-orientation
a=sendrecv
a=msid:stream_id video_track_id
a=rtcp-mux
a=rtcp-rsize
a=rtpmap:96 VP8/90000
a=rtcp-fb:96 goog-remb
a=rtcp-fb:96 transport-cc
a=rtcp-fb:96 ccm fir
a=rtcp-fb:96 nack
a=rtcp-fb:96 nack pli
a=rtpmap:97 rtx/90000
a=fmtp:97 apt=96
a=rtpmap:98 VP9/90000
a=rtcp-fb:98 goog-remb
a=rtcp-fb:98 transport-cc
a=rtcp-fb:98 ccm fir
a=rtcp-fb:98 nack
a=rtcp-fb:98 nack pli
a=fmtp:98 profile-id=0
a=rtpmap:99 rtx/90000
a=fmtp:99 apt=98
a=rtpmap:100 H264/90000
a=rtcp-fb:100 goog-remb
a=rtcp-fb:100 transport-cc
a=rtcp-fb:100 ccm fir
a=rtcp-fb:100 nack
a=rtcp-fb:100 nack pli
a=fmtp:100 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42001f
a=ssrc:9876543210 cname:abcdefghij
a=ssrc:9876543210 msid:stream_id video_track_id
```

### 2.3 会话级字段详解

#### v= (版本)

```
v=0
```

SDP 协议版本,目前固定为 0。

#### o= (发起者)

```
o=- 4611731400430051336 2 IN IP4 127.0.0.1
```

格式: `o=<username> <sess-id> <sess-version> <nettype> <addrtype> <unicast-address>`

| 字段 | 示例值 | 说明 |
|------|--------|------|
| username | - | 用户名,"-" 表示无 |
| sess-id | 4611731400430051336 | 会话 ID,数字字符串 |
| sess-version | 2 | 会话版本,每次修改递增 |
| nettype | IN | 网络类型,固定为 IN (Internet) |
| addrtype | IP4 | 地址类型,IP4 或 IP6 |
| unicast-address | 127.0.0.1 | 创建者的地址 |

#### s= (会话名称)

```
s=-
```

会话名称,WebRTC 中通常为 "-"。

#### t= (时间)

```
t=0 0
```

格式: `t=<start-time> <stop-time>`

两个 0 表示会话永久有效。

#### a=group:BUNDLE

```
a=group:BUNDLE 0 1
```

表示多个媒体流复用同一个传输通道。0 和 1 是媒体的 mid 值。

#### a=msid-semantic

```
a=msid-semantic: WMS stream_id
```

定义媒体流的语义。WMS (WebRTC Media Streams) 表示 WebRTC 媒体流。

### 2.4 媒体级字段详解

#### m= (媒体描述)

```
m=audio 9 UDP/TLS/RTP/SAVPF 111 103 104 9 0 8
```

格式: `m=<media> <port> <proto> <fmt> ...`

| 字段 | 示例值 | 说明 |
|------|--------|------|
| media | audio | 媒体类型: audio, video, application |
| port | 9 | 端口号,WebRTC 中通常为 9 (实际端口由 ICE 确定) |
| proto | UDP/TLS/RTP/SAVPF | 传输协议 |
| fmt | 111 103 104... | 支持的负载类型列表 |

传输协议说明:
- UDP: 使用 UDP 传输
- TLS: 使用 DTLS 加密
- RTP: 使用 RTP 协议
- SAVPF: Secure Audio Video Profile with Feedback

#### c= (连接信息)

```
c=IN IP4 0.0.0.0
```

格式: `c=<nettype> <addrtype> <connection-address>`

WebRTC 中通常为 0.0.0.0,实际地址由 ICE 候选确定。

#### a=mid

```
a=mid:0
```

媒体标识符,用于 BUNDLE 分组。

#### a=sendrecv / sendonly / recvonly / inactive

```
a=sendrecv
```

媒体方向:
- sendrecv: 双向收发
- sendonly: 仅发送
- recvonly: 仅接收
- inactive: 不收不发

---

## 3. Offer/Answer 模型

### 3.1 模型概述

WebRTC 使用 Offer/Answer 模型进行媒体协商,定义在 RFC 3264 中。

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Offer/Answer 模型                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   发起方 (Offerer)                          接收方 (Answerer)            │
│                                                                         │
│   1. 创建 Offer                                                         │
│      ┌─────────────────┐                                                │
│      │ createOffer()   │                                                │
│      └────────┬────────┘                                                │
│               │                                                         │
│               ▼                                                         │
│   2. 设置本地描述                                                        │
│      ┌─────────────────────────┐                                        │
│      │ setLocalDescription()   │                                        │
│      └────────┬────────────────┘                                        │
│               │                                                         │
│               │  Offer SDP                                              │
│               │ ─────────────────────────────────────────────────────>  │
│               │                                                         │
│               │                           3. 设置远端描述                │
│               │                              ┌─────────────────────────┐│
│               │                              │ setRemoteDescription()  ││
│               │                              └────────┬────────────────┘│
│               │                                       │                 │
│               │                                       ▼                 │
│               │                           4. 创建 Answer                │
│               │                              ┌─────────────────┐        │
│               │                              │ createAnswer()  │        │
│               │                              └────────┬────────┘        │
│               │                                       │                 │
│               │                                       ▼                 │
│               │                           5. 设置本地描述                │
│               │                              ┌─────────────────────────┐│
│               │                              │ setLocalDescription()   ││
│               │                              └────────┬────────────────┘│
│               │                                       │                 │
│               │  Answer SDP                           │                 │
│               │ <─────────────────────────────────────┘                 │
│               │                                                         │
│               ▼                                                         │
│   6. 设置远端描述                                                        │
│      ┌─────────────────────────┐                                        │
│      │ setRemoteDescription()  │                                        │
│      └─────────────────────────┘                                        │
│                                                                         │
│   7. 协商完成,开始媒体传输                                               │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 协商规则

#### 编解码器协商

```
Offer 中的编解码器:          Answer 中的编解码器:
┌─────────────────┐          ┌─────────────────┐
│ VP8  (PT=96)    │          │ VP8  (PT=96)    │  <-- 保留,双方都支持
│ VP9  (PT=98)    │   ───>   │                 │  <-- 移除,B 不支持
│ H264 (PT=100)   │          │ H264 (PT=100)   │  <-- 保留,双方都支持
│ AV1  (PT=102)   │          │                 │  <-- 移除,B 不支持
└─────────────────┘          └─────────────────┘

规则: Answer 只能包含 Offer 中存在且自己也支持的编解码器
```

#### 媒体方向协商

| Offer 方向 | Answerer 期望 | Answer 方向 |
|-----------|--------------|-------------|
| sendrecv | sendrecv | sendrecv |
| sendrecv | sendonly | recvonly |
| sendrecv | recvonly | sendonly |
| sendonly | recvonly | recvonly |
| sendonly | sendonly | inactive |
| recvonly | sendonly | sendonly |
| recvonly | recvonly | inactive |

#### 端口协商

- Offer 中端口为 0 表示禁用该媒体
- Answer 中端口为 0 表示拒绝该媒体

### 3.3 重新协商

当需要修改媒体配置时(如添加视频轨道),需要重新协商:

```javascript
// 添加新轨道后触发重新协商
pc.onnegotiationneeded = async () => {
    const offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    // 发送新的 Offer
    sendOffer(offer);
};

// 添加视频轨道
const videoTrack = videoStream.getVideoTracks()[0];
pc.addTrack(videoTrack, videoStream);
// 这会触发 onnegotiationneeded 事件
```

### 3.4 Rollback

当协商过程中出现问题,可以回滚到稳定状态:

```javascript
// 回滚到稳定状态
await pc.setLocalDescription({ type: 'rollback' });
```

信令状态转换:

```
                    setLocalDescription(offer)
        stable ─────────────────────────────────> have-local-offer
           │                                            │
           │                                            │
           │  setRemoteDescription(offer)               │ setRemoteDescription(answer)
           │                                            │
           ▼                                            ▼
    have-remote-offer ─────────────────────────────> stable
                        setLocalDescription(answer)

    任何状态 ──── setLocalDescription({type:'rollback'}) ────> stable
```

---

## 4. SDP 关键参数解读

### 4.1 rtpmap (RTP 映射)

```
a=rtpmap:111 opus/48000/2
```

格式: `a=rtpmap:<payload type> <encoding name>/<clock rate>[/<encoding parameters>]`

| 字段 | 示例值 | 说明 |
|------|--------|------|
| payload type | 111 | 负载类型编号 |
| encoding name | opus | 编解码器名称 |
| clock rate | 48000 | 时钟频率 (Hz) |
| encoding parameters | 2 | 编码参数 (Opus 的声道数) |

常见编解码器:

| 编解码器 | 类型 | 典型 rtpmap |
|---------|------|------------|
| Opus | 音频 | opus/48000/2 |
| G.711 u-law | 音频 | PCMU/8000 |
| G.711 A-law | 音频 | PCMA/8000 |
| VP8 | 视频 | VP8/90000 |
| VP9 | 视频 | VP9/90000 |
| H.264 | 视频 | H264/90000 |
| AV1 | 视频 | AV1/90000 |

### 4.2 fmtp (格式参数)

```
a=fmtp:111 minptime=10;useinbandfec=1
a=fmtp:100 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42001f
```

格式: `a=fmtp:<payload type> <format specific parameters>`

#### Opus 参数

| 参数 | 说明 | 示例值 |
|------|------|--------|
| minptime | 最小打包时间 (ms) | 10 |
| useinbandfec | 启用带内 FEC | 1 |
| stereo | 立体声 | 1 |
| cbr | 固定码率 | 0 |
| maxplaybackrate | 最大播放采样率 | 48000 |
| maxaveragebitrate | 最大平均码率 | 128000 |

#### H.264 参数

| 参数 | 说明 | 示例值 |
|------|------|--------|
| profile-level-id | 配置文件和级别 | 42001f |
| packetization-mode | 打包模式 | 1 |
| level-asymmetry-allowed | 允许级别不对称 | 1 |

profile-level-id 解析 (42001f):
- 42: profile_idc (Baseline Profile)
- 00: profile-iop
- 1f: level_idc (Level 3.1)

#### VP9 参数

| 参数 | 说明 | 示例值 |
|------|------|--------|
| profile-id | 配置文件 ID | 0, 2 |

### 4.3 mid (媒体标识)

```
a=mid:0
a=mid:1
a=mid:audio
a=mid:video
```

mid 用于标识媒体流,在 BUNDLE 中用于区分不同媒体。

### 4.4 msid (媒体流标识)

```
a=msid:stream_id track_id
```

格式: `a=msid:<stream id> <track id>`

用于将 RTP 流与 MediaStream 和 MediaStreamTrack 关联。

### 4.5 ssrc (同步源)

```
a=ssrc:1234567890 cname:abcdefghij
a=ssrc:1234567890 msid:stream_id track_id
```

SSRC (Synchronization Source) 是 RTP 流的唯一标识符。

| 属性 | 说明 |
|------|------|
| cname | 规范名称,用于跨流同步 |
| msid | 媒体流和轨道标识 |
| label | 轨道标签 (已废弃) |
| mslabel | 流标签 (已废弃) |

### 4.6 ICE 相关参数

```
a=ice-ufrag:abcd
a=ice-pwd:efghijklmnopqrstuvwxyz1234567890
a=ice-options:trickle
```

| 参数 | 说明 |
|------|------|
| ice-ufrag | ICE 用户名片段 (至少 4 字符) |
| ice-pwd | ICE 密码 (至少 22 字符) |
| ice-options | ICE 选项 (trickle 表示支持 Trickle ICE) |

### 4.7 DTLS 相关参数

```
a=fingerprint:sha-256 AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99
a=setup:actpass
```

| 参数 | 说明 |
|------|------|
| fingerprint | DTLS 证书指纹 |
| setup | DTLS 角色: actpass/active/passive |

setup 值说明:
- actpass: 可以作为客户端或服务端 (Offer 中使用)
- active: 作为 DTLS 客户端 (Answer 中使用)
- passive: 作为 DTLS 服务端 (Answer 中使用)

### 4.8 RTCP 反馈

```
a=rtcp-fb:96 goog-remb
a=rtcp-fb:96 transport-cc
a=rtcp-fb:96 ccm fir
a=rtcp-fb:96 nack
a=rtcp-fb:96 nack pli
```

| 反馈类型 | 说明 |
|---------|------|
| goog-remb | Google 接收端带宽估计 |
| transport-cc | 传输层拥塞控制 |
| ccm fir | 全帧内请求 |
| nack | 丢包重传请求 |
| nack pli | 图片丢失指示 |

### 4.9 RTP 头扩展

```
a=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level
a=extmap:2 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time
a=extmap:3 urn:ietf:params:rtp-hdrext:toffset
```

常见扩展:

| 扩展 | 说明 |
|------|------|
| ssrc-audio-level | 音频电平 |
| abs-send-time | 绝对发送时间 |
| toffset | 传输时间偏移 |
| video-orientation | 视频方向 |
| transport-wide-cc | 传输层拥塞控制序列号 |

---

## 5. SDP 修改与优化

### 5.1 修改编解码器顺序

优先使用特定编解码器:

```javascript
function preferCodec(sdp, codecName) {
    const lines = sdp.split('\r\n');
    const mLineIndex = lines.findIndex(line => line.startsWith('m=video'));
    
    if (mLineIndex === -1) return sdp;
    
    const mLine = lines[mLineIndex];
    const parts = mLine.split(' ');
    const payloadTypes = parts.slice(3);
    
    // 找到目标编解码器的 payload type
    let targetPT = null;
    for (let i = mLineIndex + 1; i < lines.length; i++) {
        if (lines[i].startsWith('m=')) break;
        
        const match = lines[i].match(new RegExp(`a=rtpmap:(\\d+) ${codecName}/`));
        if (match) {
            targetPT = match[1];
            break;
        }
    }
    
    if (!targetPT) return sdp;
    
    // 将目标编解码器移到最前面
    const newPayloadTypes = [targetPT, ...payloadTypes.filter(pt => pt !== targetPT)];
    parts.splice(3, payloadTypes.length, ...newPayloadTypes);
    lines[mLineIndex] = parts.join(' ');
    
    return lines.join('\r\n');
}

// 使用示例
const modifiedSdp = preferCodec(offer.sdp, 'VP9');
```

### 5.2 移除不需要的编解码器

```javascript
function removeCodec(sdp, codecName) {
    const lines = sdp.split('\r\n');
    const result = [];
    let removePT = null;
    
    // 第一遍: 找到要移除的 payload type
    for (const line of lines) {
        const match = line.match(new RegExp(`a=rtpmap:(\\d+) ${codecName}/`));
        if (match) {
            removePT = match[1];
            break;
        }
    }
    
    if (!removePT) return sdp;
    
    // 第二遍: 移除相关行
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        
        // 移除 m= 行中的 payload type
        if (line.startsWith('m=')) {
            const parts = line.split(' ');
            const filtered = parts.filter((p, idx) => idx < 3 || p !== removePT);
            result.push(filtered.join(' '));
            continue;
        }
        
        // 移除与该 payload type 相关的属性行
        if (line.includes(`:${removePT} `) || line.includes(`:${removePT}\r`)) {
            continue;
        }
        
        result.push(line);
    }
    
    return result.join('\r\n');
}
```

### 5.3 修改带宽限制

```javascript
function setBandwidth(sdp, bandwidth) {
    const lines = sdp.split('\r\n');
    const result = [];
    
    for (let i = 0; i < lines.length; i++) {
        result.push(lines[i]);
        
        // 在 m=video 行后添加带宽限制
        if (lines[i].startsWith('m=video')) {
            result.push(`b=AS:${bandwidth}`);
        }
    }
    
    return result.join('\r\n');
}

// 限制视频带宽为 1000 kbps
const modifiedSdp = setBandwidth(offer.sdp, 1000);
```

### 5.4 修改分辨率和帧率

通过修改 fmtp 参数:

```javascript
function setVideoConstraints(sdp, maxWidth, maxHeight, maxFramerate) {
    // 对于 VP8/VP9,可以添加 max-fs 和 max-fr 参数
    // max-fs: 最大帧大小 (宏块数)
    // max-fr: 最大帧率
    
    const maxFs = Math.ceil((maxWidth * maxHeight) / 256);  // 宏块大小 16x16
    
    return sdp.replace(
        /(a=fmtp:(\d+).*)/g,
        (match, p1, pt) => {
            if (sdp.includes(`a=rtpmap:${pt} VP8`) || sdp.includes(`a=rtpmap:${pt} VP9`)) {
                return `${p1};max-fs=${maxFs};max-fr=${maxFramerate}`;
            }
            return match;
        }
    );
}
```

### 5.5 启用 Simulcast

```javascript
function enableSimulcast(sdp) {
    const lines = sdp.split('\r\n');
    const result = [];
    
    for (let i = 0; i < lines.length; i++) {
        result.push(lines[i]);
        
        // 在视频媒体描述后添加 simulcast 相关行
        if (lines[i].startsWith('a=mid:') && lines[i-1]?.includes('video')) {
            result.push('a=rid:high send');
            result.push('a=rid:medium send');
            result.push('a=rid:low send');
            result.push('a=simulcast:send high;medium;low');
        }
    }
    
    return result.join('\r\n');
}
```

---

## 6. 实战案例分析

### 6.1 案例一: 纯音频通话

```
v=0
o=- 123456789 2 IN IP4 127.0.0.1
s=-
t=0 0
a=msid-semantic: WMS

m=audio 9 UDP/TLS/RTP/SAVPF 111 0 8
c=IN IP4 0.0.0.0
a=rtcp:9 IN IP4 0.0.0.0
a=ice-ufrag:xxxx
a=ice-pwd:xxxxxxxxxxxxxxxxxxxxxxxx
a=fingerprint:sha-256 XX:XX:XX:...
a=setup:actpass
a=mid:audio
a=sendrecv
a=rtcp-mux
a=rtpmap:111 opus/48000/2
a=fmtp:111 minptime=10;useinbandfec=1
a=rtpmap:0 PCMU/8000
a=rtpmap:8 PCMA/8000
a=ssrc:111111111 cname:audio_cname
```

特点分析:
- 只有一个 m=audio 媒体描述
- 支持 Opus、PCMU、PCMA 三种编解码器
- Opus 启用了带内 FEC

### 6.2 案例二: 屏幕共享

```
v=0
o=- 123456789 2 IN IP4 127.0.0.1
s=-
t=0 0
a=group:BUNDLE 0
a=msid-semantic: WMS screen_share

m=video 9 UDP/TLS/RTP/SAVPF 96 98
c=IN IP4 0.0.0.0
a=rtcp:9 IN IP4 0.0.0.0
a=ice-ufrag:xxxx
a=ice-pwd:xxxxxxxxxxxxxxxxxxxxxxxx
a=fingerprint:sha-256 XX:XX:XX:...
a=setup:actpass
a=mid:0
a=sendonly
a=rtcp-mux
a=rtpmap:96 VP8/90000
a=rtcp-fb:96 nack
a=rtcp-fb:96 nack pli
a=rtcp-fb:96 goog-remb
a=rtpmap:98 VP9/90000
a=rtcp-fb:98 nack
a=rtcp-fb:98 nack pli
a=rtcp-fb:98 goog-remb
a=fmtp:98 profile-id=0
a=ssrc:222222222 cname:screen_cname
a=ssrc:222222222 msid:screen_share screen_track
a=content:slides
```

特点分析:
- 方向为 sendonly (只发送)
- 使用 VP8 和 VP9 编解码器
- a=content:slides 表示这是屏幕共享内容

### 6.3 案例三: Simulcast

```
v=0
o=- 123456789 2 IN IP4 127.0.0.1
s=-
t=0 0
a=group:BUNDLE 0 1
a=msid-semantic: WMS stream

m=audio 9 UDP/TLS/RTP/SAVPF 111
c=IN IP4 0.0.0.0
a=mid:0
a=sendrecv
a=rtcp-mux
a=rtpmap:111 opus/48000/2
a=ssrc:111111111 cname:cname

m=video 9 UDP/TLS/RTP/SAVPF 96
c=IN IP4 0.0.0.0
a=mid:1
a=sendrecv
a=rtcp-mux
a=rtpmap:96 VP8/90000
a=rtcp-fb:96 nack
a=rtcp-fb:96 nack pli
a=rtcp-fb:96 goog-remb
a=rtcp-fb:96 transport-cc
a=extmap:5 http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01
a=rid:high send
a=rid:medium send
a=rid:low send
a=simulcast:send high;medium;low
a=ssrc:333333331 cname:cname
a=ssrc:333333332 cname:cname
a=ssrc:333333333 cname:cname
a=ssrc-group:SIM 333333331 333333332 333333333
```

特点分析:
- 使用 a=rid 定义三个发送层
- a=simulcast 声明 simulcast 配置
- 三个 SSRC 对应三个质量层
- a=ssrc-group:SIM 将三个 SSRC 分组

---

## 7. 总结

### 7.1 SDP 核心要点

| 要点 | 说明 |
|------|------|
| 结构 | 会话级描述 + 媒体级描述 |
| 协商模型 | Offer/Answer |
| 关键字段 | m=, a=rtpmap, a=fmtp, a=mid, a=ssrc |
| ICE 参数 | ice-ufrag, ice-pwd, ice-options |
| DTLS 参数 | fingerprint, setup |

### 7.2 SDP 调试技巧

1. 使用 chrome://webrtc-internals 查看 SDP
2. 对比 Offer 和 Answer 的差异
3. 检查编解码器是否匹配
4. 验证 ICE 参数是否正确
5. 确认 DTLS fingerprint 匹配

### 7.3 下一篇预告

在下一篇文章中,我们将深入探讨 ICE 框架,包括:
- ICE 的角色和工作流程
- 候选地址发现与连通性检测
- ICE 状态机
- ICE Lite vs Full ICE

---

## 参考资料

1. [RFC 4566 - SDP: Session Description Protocol](https://datatracker.ietf.org/doc/html/rfc4566)
2. [RFC 3264 - An Offer/Answer Model with SDP](https://datatracker.ietf.org/doc/html/rfc3264)
3. [RFC 8829 - JavaScript Session Establishment Protocol (JSEP)](https://datatracker.ietf.org/doc/html/rfc8829)
4. [WebRTC SDP Anatomy - webrtcHacks](https://webrtchacks.com/sdp-anatomy/)

---

> 作者: WebRTC 技术专栏  
> 系列: 信令与会话管理 (2/6)  
> 上一篇: [信令是什么?为什么 WebRTC 需要信令?](./06-signaling-basics.md)  
> 下一篇: [ICE 框架](./08-ice-framework.md)
