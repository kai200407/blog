---
title: "WebRTC SFU 架构详解: 为什么需要 SFU?"
description: "1. [多人通信架构概述](#1-多人通信架构概述)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 22
---

> 本文是 WebRTC 系列专栏的第二十二篇,将深入探讨 SFU (Selective Forwarding Unit) 架构,理解它与 MCU 的区别以及 RTP 重写机制。

---

## 目录

1. [多人通信架构概述](#1-多人通信架构概述)
2. [Mesh 架构](#2-mesh-架构)
3. [MCU 架构](#3-mcu-架构)
4. [SFU 架构](#4-sfu-架构)
5. [RTP 转发机制](#5-rtp-转发机制)
6. [SFU 核心功能](#6-sfu-核心功能)
7. [架构选择](#7-架构选择)
8. [总结](#8-总结)

---

## 1. 多人通信架构概述

### 1.1 架构类型

```
WebRTC 多人通信三种架构:

1. Mesh (网状)
   - 每个参与者直接连接其他所有人
   - 纯 P2P,无服务器

2. MCU (Multipoint Control Unit)
   - 所有流汇聚到服务器
   - 服务器混流后分发

3. SFU (Selective Forwarding Unit)
   - 所有流汇聚到服务器
   - 服务器选择性转发
```

### 1.2 架构对比

| 特性 | Mesh | MCU | SFU |
|------|------|-----|-----|
| 服务器负载 | 无 | 高 (转码) | 中 (转发) |
| 客户端负载 | 高 | 低 | 中 |
| 上行带宽 | N-1 路 | 1 路 | 1 路 |
| 下行带宽 | N-1 路 | 1 路 | N-1 路 |
| 延迟 | 低 | 高 | 低 |
| 扩展性 | 差 | 中 | 好 |
| 灵活性 | 低 | 低 | 高 |

---

## 2. Mesh 架构

### 2.1 Mesh 原理

```
Mesh 架构 (4 人会议):

    A <---------> B
    ^  \      /  ^
    |   \    /   |
    |    \  /    |
    |     \/     |
    |     /\     |
    |    /  \    |
    |   /    \   |
    v  /      \  v
    D <---------> C

连接数 = N * (N-1) / 2 = 4 * 3 / 2 = 6

每个参与者:
- 上行: 3 路视频
- 下行: 3 路视频
```

### 2.2 Mesh 优缺点

```
优点:
+ 无需服务器
+ 延迟最低
+ 端到端加密

缺点:
- 连接数随人数指数增长
- 客户端 CPU/带宽消耗大
- 通常只适合 3-4 人
```

### 2.3 Mesh 实现

```javascript
// Mesh 架构客户端
class MeshClient {
    constructor() {
        this.peers = new Map(); // peerId -> RTCPeerConnection
        this.localStream = null;
    }
    
    // 与新参与者建立连接
    async connectToPeer(peerId, isInitiator) {
        const pc = new RTCPeerConnection(this.config);
        this.peers.set(peerId, pc);
        
        // 添加本地流
        this.localStream.getTracks().forEach(track => {
            pc.addTrack(track, this.localStream);
        });
        
        // 处理远程流
        pc.ontrack = (event) => {
            this.onRemoteStream(peerId, event.streams[0]);
        };
        
        // ICE 候选
        pc.onicecandidate = (event) => {
            if (event.candidate) {
                this.signaling.send({
                    type: 'candidate',
                    targetId: peerId,
                    candidate: event.candidate
                });
            }
        };
        
        if (isInitiator) {
            const offer = await pc.createOffer();
            await pc.setLocalDescription(offer);
            this.signaling.send({
                type: 'offer',
                targetId: peerId,
                sdp: offer
            });
        }
        
        return pc;
    }
    
    // 计算连接数
    getConnectionCount() {
        return this.peers.size;
    }
    
    // 计算带宽需求
    getBandwidthRequirement(bitrate) {
        const n = this.peers.size + 1; // 包括自己
        return {
            upload: bitrate * (n - 1),
            download: bitrate * (n - 1)
        };
    }
}
```

---

## 3. MCU 架构

### 3.1 MCU 原理

```
MCU 架构 (4 人会议):

    A ----\          /---- A
           \        /
    B -----> [MCU] <----- B
           /        \
    C ----/          \---- C
           \        /
    D ----/          \---- D

每个参与者:
- 上行: 1 路视频
- 下行: 1 路混合视频

MCU 处理:
1. 接收所有流
2. 解码
3. 混合 (画中画/宫格)
4. 编码
5. 分发
```

### 3.2 MCU 混流布局

```
常见混流布局:

1. 宫格布局 (Grid)
+-------+-------+
|   A   |   B   |
+-------+-------+
|   C   |   D   |
+-------+-------+

2. 演讲者模式 (Speaker)
+---------------+
|               |
|   Speaker     |
|               |
+---+---+---+---+
| A | B | C | D |
+---+---+---+---+

3. 画中画 (PiP)
+---------------+
|               |
|   Main        |
|           +---+
|           |PiP|
+-----------+---+
```

### 3.3 MCU 优缺点

```
优点:
+ 客户端带宽需求低
+ 客户端处理简单
+ 统一的视频布局

缺点:
- 服务器 CPU 消耗极高
- 延迟较高 (编解码)
- 扩展性差
- 灵活性低
```

---

## 4. SFU 架构

### 4.1 SFU 原理

```
SFU 架构 (4 人会议):

    A ----\          /---- B,C,D 的流
           \        /
    B -----> [SFU] <----- A,C,D 的流
           /        \
    C ----/          \---- A,B,D 的流
           \        /
    D ----/          \---- A,B,C 的流

每个参与者:
- 上行: 1 路视频
- 下行: N-1 路视频

SFU 处理:
1. 接收所有流
2. 选择性转发 (不解码)
3. 可能的 RTP 重写
```

### 4.2 SFU 数据流

```
SFU 内部数据流:

接收端:
+--------+    +--------+    +--------+
| UDP    | -> | SRTP   | -> | RTP    |
| Socket |    | Decrypt|    | Parser |
+--------+    +--------+    +--------+
                               |
                               v
                        +------------+
                        | Router     |
                        | (选择转发)  |
                        +------------+
                               |
                               v
发送端:
+--------+    +--------+    +--------+
| RTP    | -> | SRTP   | -> | UDP    |
| Rewrite|    | Encrypt|    | Socket |
+--------+    +--------+    +--------+
```

### 4.3 SFU 优缺点

```
优点:
+ 服务器负载低 (无转码)
+ 延迟低
+ 灵活性高 (客户端控制布局)
+ 支持 Simulcast/SVC
+ 扩展性好

缺点:
- 客户端下行带宽需求高
- 客户端需要解码多路
- 实现复杂度较高
```

---

## 5. RTP 转发机制

### 5.1 为什么需要 RTP 重写

```
RTP 转发问题:

发送端 A -> SFU -> 接收端 B

问题 1: SSRC 冲突
- A 的 SSRC 可能与 B 本地 SSRC 冲突
- 需要重写 SSRC

问题 2: 序列号不连续
- 丢包或层切换导致序列号跳跃
- 接收端可能误判为丢包

问题 3: 时间戳不连续
- 层切换时时间戳可能跳跃
- 影响播放平滑性
```

### 5.2 SSRC 重写

```javascript
class SsrcRewriter {
    constructor() {
        this.ssrcMap = new Map(); // originalSsrc -> newSsrc
        this.nextSsrc = 1000;
    }
    
    // 获取或分配新 SSRC
    getNewSsrc(originalSsrc) {
        if (!this.ssrcMap.has(originalSsrc)) {
            this.ssrcMap.set(originalSsrc, this.nextSsrc++);
        }
        return this.ssrcMap.get(originalSsrc);
    }
    
    // 重写 RTP 包
    rewritePacket(packet) {
        const originalSsrc = packet.ssrc;
        const newSsrc = this.getNewSsrc(originalSsrc);
        
        // 修改 SSRC
        packet.ssrc = newSsrc;
        
        return packet;
    }
}
```

### 5.3 序列号重写

```javascript
class SequenceNumberRewriter {
    constructor() {
        this.streams = new Map(); // ssrc -> state
    }
    
    getState(ssrc) {
        if (!this.streams.has(ssrc)) {
            this.streams.set(ssrc, {
                lastOriginalSeq: -1,
                lastRewrittenSeq: -1,
                offset: 0
            });
        }
        return this.streams.get(ssrc);
    }
    
    // 重写序列号
    rewrite(ssrc, originalSeq) {
        const state = this.getState(ssrc);
        
        if (state.lastOriginalSeq === -1) {
            // 第一个包
            state.lastOriginalSeq = originalSeq;
            state.lastRewrittenSeq = originalSeq;
            return originalSeq;
        }
        
        // 计算期望的序列号
        const expectedSeq = (state.lastOriginalSeq + 1) % 65536;
        
        if (originalSeq !== expectedSeq) {
            // 序列号跳跃,调整偏移
            const gap = this.seqDiff(originalSeq, expectedSeq);
            state.offset -= gap;
        }
        
        // 计算新序列号
        let newSeq = (originalSeq + state.offset) % 65536;
        if (newSeq < 0) newSeq += 65536;
        
        state.lastOriginalSeq = originalSeq;
        state.lastRewrittenSeq = newSeq;
        
        return newSeq;
    }
    
    seqDiff(a, b) {
        let diff = a - b;
        if (diff > 32768) diff -= 65536;
        if (diff < -32768) diff += 65536;
        return diff;
    }
}
```

### 5.4 时间戳重写

```javascript
class TimestampRewriter {
    constructor() {
        this.streams = new Map();
    }
    
    getState(ssrc) {
        if (!this.streams.has(ssrc)) {
            this.streams.set(ssrc, {
                lastOriginalTs: -1,
                lastRewrittenTs: -1,
                offset: 0
            });
        }
        return this.streams.get(ssrc);
    }
    
    rewrite(ssrc, originalTs, clockRate = 90000) {
        const state = this.getState(ssrc);
        
        if (state.lastOriginalTs === -1) {
            state.lastOriginalTs = originalTs;
            state.lastRewrittenTs = originalTs;
            return originalTs;
        }
        
        // 计算时间戳差值
        const tsDiff = originalTs - state.lastOriginalTs;
        
        // 检测时间戳跳跃 (超过 1 秒)
        const maxDiff = clockRate; // 1 秒
        if (Math.abs(tsDiff) > maxDiff) {
            // 时间戳跳跃,调整偏移
            const expectedTs = state.lastRewrittenTs + 
                              (clockRate / 30); // 假设 30fps
            state.offset = expectedTs - originalTs;
        }
        
        const newTs = (originalTs + state.offset) >>> 0;
        
        state.lastOriginalTs = originalTs;
        state.lastRewrittenTs = newTs;
        
        return newTs;
    }
}
```

---

## 6. SFU 核心功能

### 6.1 路由器 (Router)

```javascript
class Router {
    constructor() {
        this.producers = new Map(); // producerId -> Producer
        this.consumers = new Map(); // consumerId -> Consumer
    }
    
    // 添加生产者 (发布流)
    addProducer(producerId, track) {
        const producer = {
            id: producerId,
            track,
            consumers: new Set()
        };
        this.producers.set(producerId, producer);
        return producer;
    }
    
    // 添加消费者 (订阅流)
    addConsumer(consumerId, producerId) {
        const producer = this.producers.get(producerId);
        if (!producer) return null;
        
        const consumer = {
            id: consumerId,
            producerId,
            ssrcRewriter: new SsrcRewriter(),
            seqRewriter: new SequenceNumberRewriter(),
            tsRewriter: new TimestampRewriter()
        };
        
        this.consumers.set(consumerId, consumer);
        producer.consumers.add(consumerId);
        
        return consumer;
    }
    
    // 转发 RTP 包
    forwardPacket(producerId, packet) {
        const producer = this.producers.get(producerId);
        if (!producer) return;
        
        for (const consumerId of producer.consumers) {
            const consumer = this.consumers.get(consumerId);
            if (!consumer) continue;
            
            // 重写 RTP 包
            const rewrittenPacket = this.rewritePacket(consumer, packet);
            
            // 发送给消费者
            this.sendToConsumer(consumerId, rewrittenPacket);
        }
    }
    
    rewritePacket(consumer, packet) {
        const newPacket = { ...packet };
        
        newPacket.ssrc = consumer.ssrcRewriter.getNewSsrc(packet.ssrc);
        newPacket.sequenceNumber = consumer.seqRewriter.rewrite(
            packet.ssrc, packet.sequenceNumber
        );
        newPacket.timestamp = consumer.tsRewriter.rewrite(
            packet.ssrc, packet.timestamp
        );
        
        return newPacket;
    }
}
```

### 6.2 Simulcast 选择

```javascript
class SimulcastSelector {
    constructor() {
        this.subscriptions = new Map(); // consumerId -> layer
    }
    
    // 设置订阅层
    setLayer(consumerId, layer) {
        this.subscriptions.set(consumerId, layer);
    }
    
    // 判断是否转发
    shouldForward(consumerId, packet) {
        const targetLayer = this.subscriptions.get(consumerId);
        if (!targetLayer) return true; // 默认转发
        
        const packetLayer = this.getPacketLayer(packet);
        return packetLayer === targetLayer;
    }
    
    getPacketLayer(packet) {
        // 根据 SSRC 或 RID 判断层
        // 实际实现需要维护 SSRC -> layer 映射
        return packet.rid || 'high';
    }
    
    // 自动选择层
    autoSelectLayer(consumerId, bandwidth) {
        let layer = 'low';
        
        if (bandwidth >= 2000000) {
            layer = 'high';
        } else if (bandwidth >= 500000) {
            layer = 'mid';
        }
        
        this.setLayer(consumerId, layer);
        return layer;
    }
}
```

### 6.3 带宽估计

```javascript
class BandwidthEstimator {
    constructor() {
        this.estimates = new Map(); // consumerId -> estimate
    }
    
    // 处理 RTCP 反馈
    onRtcpFeedback(consumerId, feedback) {
        if (feedback.type === 'receiver-report') {
            this.processReceiverReport(consumerId, feedback);
        } else if (feedback.type === 'transport-cc') {
            this.processTransportCC(consumerId, feedback);
        }
    }
    
    processReceiverReport(consumerId, rr) {
        const lossRate = rr.fractionLost / 256;
        const jitter = rr.jitter;
        
        // 简单的带宽估计
        let estimate = this.estimates.get(consumerId) || 2000000;
        
        if (lossRate > 0.1) {
            // 高丢包,降低估计
            estimate *= 0.8;
        } else if (lossRate < 0.02) {
            // 低丢包,增加估计
            estimate *= 1.05;
        }
        
        // 限制范围
        estimate = Math.max(100000, Math.min(5000000, estimate));
        
        this.estimates.set(consumerId, estimate);
        return estimate;
    }
    
    getEstimate(consumerId) {
        return this.estimates.get(consumerId) || 2000000;
    }
}
```

### 6.4 关键帧请求

```javascript
class KeyframeRequester {
    constructor() {
        this.lastRequestTime = new Map(); // producerId -> timestamp
        this.minInterval = 1000; // 最小请求间隔
    }
    
    // 请求关键帧
    requestKeyframe(producerId) {
        const now = Date.now();
        const lastTime = this.lastRequestTime.get(producerId) || 0;
        
        if (now - lastTime < this.minInterval) {
            return false; // 太频繁
        }
        
        this.lastRequestTime.set(producerId, now);
        
        // 发送 PLI 或 FIR
        this.sendPLI(producerId);
        return true;
    }
    
    // 层切换时请求关键帧
    onLayerSwitch(producerId, fromLayer, toLayer) {
        // 切换到更高层时需要关键帧
        if (this.isHigherLayer(toLayer, fromLayer)) {
            this.requestKeyframe(producerId);
        }
    }
    
    isHigherLayer(a, b) {
        const order = { 'low': 0, 'mid': 1, 'high': 2 };
        return order[a] > order[b];
    }
}
```

---

## 7. 架构选择

### 7.1 选择指南

```
选择 Mesh:
- 参与者 <= 4 人
- 对延迟要求极高
- 不想部署服务器
- 需要端到端加密

选择 MCU:
- 客户端能力有限
- 需要统一布局
- 需要录制混合流
- 参与者带宽受限

选择 SFU:
- 参与者 > 4 人
- 需要灵活布局
- 需要 Simulcast/SVC
- 服务器资源有限
```

### 7.2 混合架构

```
混合架构示例:

1. SFU + 选择性 MCU
   - 大部分流 SFU 转发
   - 特定场景 MCU 混流 (如录制)

2. 级联 SFU
   - 多个 SFU 级联
   - 跨地域部署
   - 就近接入

3. SFU + Mesh
   - 小房间用 Mesh
   - 大房间用 SFU
```

### 7.3 性能对比

```
10 人会议性能对比:

Mesh:
- 连接数: 45
- 上行: 9 路
- 下行: 9 路
- 客户端 CPU: 极高

MCU:
- 连接数: 10
- 上行: 1 路
- 下行: 1 路
- 服务器 CPU: 极高 (10 路解码 + 混流 + 10 路编码)

SFU:
- 连接数: 10
- 上行: 1 路
- 下行: 9 路
- 服务器 CPU: 低 (仅转发)
```

---

## 8. 总结

### 8.1 核心要点

| 架构 | 适用场景 | 关键特点 |
|------|---------|---------|
| Mesh | 小型通话 | 无服务器,延迟低 |
| MCU | 传统会议 | 混流,客户端简单 |
| SFU | 现代会议 | 转发,灵活高效 |

### 8.2 SFU 关键技术

```
SFU 核心技术:
1. RTP 转发 (无解码)
2. SSRC/序列号/时间戳重写
3. Simulcast/SVC 层选择
4. 带宽估计与自适应
5. 关键帧请求
```

### 8.3 下一篇预告

在下一篇文章中,我们将实战搭建一个 SFU 服务器。

---

## 参考资料

1. [mediasoup Documentation](https://mediasoup.org/documentation/)
2. [Pion WebRTC](https://github.com/pion/webrtc)
3. [RFC 7667 - RTP Topologies](https://datatracker.ietf.org/doc/html/rfc7667)

---

> 作者: WebRTC 技术专栏  
> 系列: 工程实践 (2/5)  
> 上一篇: [构建自己的 WebRTC 信令服务器](./21-signaling-server.md)  
> 下一篇: [搭建一个 SFU](./23-sfu-setup.md)
