---
title: "WebRTC 中的 Simulcast 与 SVC (多路与分层编码)"
description: "1. [多流技术概述](#1-多流技术概述)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 20
---

> 本文是 WebRTC 系列专栏的第二十篇,将深入探讨 Simulcast 和 SVC 技术,理解它们在直播互动、视频会议系统中的应用。

---

## 目录

1. [多流技术概述](#1-多流技术概述)
2. [Simulcast 详解](#2-simulcast-详解)
3. [SVC 详解](#3-svc-详解)
4. [Simulcast vs SVC](#4-simulcast-vs-svc)
5. [SFU 中的应用](#5-sfu-中的应用)
6. [实战配置](#6-实战配置)
7. [总结](#7-总结)

---

## 1. 多流技术概述

### 1.1 为什么需要多流

```
多人视频会议场景:

发送端 (1080p 摄像头)
    │
    v
+--------+
|  SFU   |
+--------+
    │
    ├──> 接收端 A (大屏幕, 高带宽) -> 需要 1080p
    │
    ├──> 接收端 B (笔记本, 中带宽) -> 需要 720p
    │
    └──> 接收端 C (手机, 低带宽) -> 需要 360p

问题:
- 单一码流无法满足所有接收端
- 需要多种质量的视频流
```

### 1.2 解决方案

```
方案对比:

1. MCU 转码
   发送端 ──> MCU ──> 转码 ──> 多路输出
   缺点: 服务器负载高, 延迟大

2. Simulcast (多路编码)
   发送端同时编码多路不同质量的流
   SFU 选择合适的流转发
   缺点: 发送端带宽和 CPU 消耗大

3. SVC (分层编码)
   发送端编码一路分层流
   SFU 选择合适的层转发
   缺点: 编码器支持有限
```

### 1.3 技术选择

| 场景 | 推荐方案 | 原因 |
|------|---------|------|
| 1:1 通话 | 单流 | 简单,无需多流 |
| 小型会议 | Simulcast | 兼容性好 |
| 大型会议 | SVC | 带宽效率高 |
| 直播 | Simulcast + CDN | 适配多种终端 |

---

## 2. Simulcast 详解

### 2.1 Simulcast 原理

```
Simulcast 架构:

发送端:
+------------------+
|    摄像头 1080p   |
+--------+---------+
         |
    +----+----+----+
    |    |    |    |
    v    v    v    v
+------+------+------+
| 编码 | 编码 | 编码 |
| 1080p| 720p | 360p |
| high | mid  | low  |
+------+------+------+
    |    |    |
    +----+----+----+
         |
         v
    RTP 发送 (3 路 SSRC)

SFU:
接收 3 路流,根据接收端情况选择转发
```

### 2.2 SDP 中的 Simulcast

```
Simulcast SDP 示例:

m=video 9 UDP/TLS/RTP/SAVPF 96 97
a=mid:1
a=sendonly

# RID (Restriction Identifier)
a=rid:high send
a=rid:mid send
a=rid:low send

# Simulcast 声明
a=simulcast:send high;mid;low

# SSRC 组
a=ssrc-group:SIM 1001 1002 1003
a=ssrc:1001 cname:user@example.com
a=ssrc:1002 cname:user@example.com
a=ssrc:1003 cname:user@example.com

# 每个 RID 的参数
a=rid:high send pt=96;max-width=1920;max-height=1080;max-fps=30
a=rid:mid send pt=96;max-width=1280;max-height=720;max-fps=30
a=rid:low send pt=96;max-width=640;max-height=360;max-fps=15
```

### 2.3 启用 Simulcast

```javascript
// 方式 1: addTransceiver 配置
const transceiver = pc.addTransceiver(videoTrack, {
    direction: 'sendonly',
    sendEncodings: [
        {
            rid: 'high',
            maxBitrate: 2500000,
            maxFramerate: 30,
            scaleResolutionDownBy: 1
        },
        {
            rid: 'mid',
            maxBitrate: 500000,
            maxFramerate: 30,
            scaleResolutionDownBy: 2
        },
        {
            rid: 'low',
            maxBitrate: 150000,
            maxFramerate: 15,
            scaleResolutionDownBy: 4
        }
    ]
});

// 方式 2: 修改现有 sender
const sender = pc.getSenders().find(s => s.track?.kind === 'video');
const params = sender.getParameters();

params.encodings = [
    { rid: 'high', maxBitrate: 2500000, scaleResolutionDownBy: 1 },
    { rid: 'mid', maxBitrate: 500000, scaleResolutionDownBy: 2 },
    { rid: 'low', maxBitrate: 150000, scaleResolutionDownBy: 4 }
];

await sender.setParameters(params);
```

### 2.4 动态控制 Simulcast

```javascript
// 禁用/启用某一层
async function toggleLayer(sender, rid, active) {
    const params = sender.getParameters();
    const encoding = params.encodings.find(e => e.rid === rid);
    if (encoding) {
        encoding.active = active;
        await sender.setParameters(params);
    }
}

// 调整码率
async function adjustBitrate(sender, rid, maxBitrate) {
    const params = sender.getParameters();
    const encoding = params.encodings.find(e => e.rid === rid);
    if (encoding) {
        encoding.maxBitrate = maxBitrate;
        await sender.setParameters(params);
    }
}

// 根据网络状况动态调整
function adaptToNetwork(sender, bandwidth) {
    if (bandwidth < 500000) {
        // 低带宽: 只发送 low
        toggleLayer(sender, 'high', false);
        toggleLayer(sender, 'mid', false);
        toggleLayer(sender, 'low', true);
    } else if (bandwidth < 1500000) {
        // 中带宽: 发送 low + mid
        toggleLayer(sender, 'high', false);
        toggleLayer(sender, 'mid', true);
        toggleLayer(sender, 'low', true);
    } else {
        // 高带宽: 全部发送
        toggleLayer(sender, 'high', true);
        toggleLayer(sender, 'mid', true);
        toggleLayer(sender, 'low', true);
    }
}
```

### 2.5 Simulcast 统计

```javascript
// 获取每层的统计信息
async function getSimulcastStats(sender) {
    const stats = await sender.getStats();
    const layers = {};
    
    stats.forEach(report => {
        if (report.type === 'outbound-rtp' && report.kind === 'video') {
            const rid = report.rid || 'default';
            layers[rid] = {
                bytesSent: report.bytesSent,
                packetsSent: report.packetsSent,
                framesEncoded: report.framesEncoded,
                frameWidth: report.frameWidth,
                frameHeight: report.frameHeight,
                framesPerSecond: report.framesPerSecond,
                qualityLimitationReason: report.qualityLimitationReason
            };
        }
    });
    
    return layers;
}

// 监控示例
setInterval(async () => {
    const stats = await getSimulcastStats(sender);
    console.log('Simulcast Stats:', stats);
}, 1000);
```

---

## 3. SVC 详解

### 3.1 SVC 原理

```
SVC 分层结构:

空间可伸缩 (Spatial Scalability):
+------------------+
|     S2 (1080p)   |  增强层
+------------------+
|     S1 (720p)    |  增强层
+------------------+
|     S0 (360p)    |  基础层
+------------------+

时间可伸缩 (Temporal Scalability):
T0: |  K  |     |     |  P  |     |     |  15 fps
T1: |  K  |  P  |     |  P  |  P  |     |  30 fps
T2: |  K  |  P  |  P  |  P  |  P  |  P  |  60 fps

质量可伸缩 (Quality/SNR Scalability):
Q0: 低质量 (高压缩)
Q1: 中质量
Q2: 高质量 (低压缩)
```

### 3.2 SVC 依赖关系

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

依赖规则:
- 高空间层依赖低空间层
- 高时间层依赖低时间层
- 可以丢弃高层而不影响低层解码
```

### 3.3 VP9 SVC 配置

```javascript
// VP9 SVC 配置
const transceiver = pc.addTransceiver(videoTrack, {
    direction: 'sendonly',
    sendEncodings: [
        {
            scalabilityMode: 'L3T3',  // 3 空间层, 3 时间层
            maxBitrate: 2500000
        }
    ]
});

// 可用的 scalabilityMode:
const scalabilityModes = {
    // 无 SVC
    'L1T1': '1 空间层, 1 时间层',
    
    // 时间可伸缩
    'L1T2': '1 空间层, 2 时间层',
    'L1T3': '1 空间层, 3 时间层',
    
    // 空间 + 时间可伸缩
    'L2T1': '2 空间层, 1 时间层',
    'L2T2': '2 空间层, 2 时间层',
    'L2T3': '2 空间层, 3 时间层',
    'L3T1': '3 空间层, 1 时间层',
    'L3T2': '3 空间层, 2 时间层',
    'L3T3': '3 空间层, 3 时间层',
    
    // K-SVC (关键帧 SVC)
    'L2T1_KEY': '2 空间层, 关键帧依赖',
    'L2T2_KEY': '2 空间层, 2 时间层, 关键帧依赖',
    'L3T1_KEY': '3 空间层, 关键帧依赖',
    'L3T2_KEY': '3 空间层, 2 时间层, 关键帧依赖',
    'L3T3_KEY': '3 空间层, 3 时间层, 关键帧依赖'
};
```

### 3.4 AV1 SVC

```javascript
// AV1 SVC 配置
const transceiver = pc.addTransceiver(videoTrack, {
    direction: 'sendonly',
    sendEncodings: [
        {
            scalabilityMode: 'L2T2',
            maxBitrate: 2000000
        }
    ]
});

// 设置 AV1 编码器优先
const codecs = RTCRtpReceiver.getCapabilities('video').codecs;
const av1Codecs = codecs.filter(c => c.mimeType === 'video/AV1');
transceiver.setCodecPreferences([...av1Codecs, ...codecs.filter(c => c.mimeType !== 'video/AV1')]);
```

### 3.5 SVC 层选择

```javascript
// SFU 端: 选择 SVC 层
class SvcLayerSelector {
    constructor() {
        this.spatialLayers = 3;
        this.temporalLayers = 3;
    }
    
    // 根据接收端带宽选择层
    selectLayers(availableBandwidth) {
        let spatial = 0;
        let temporal = 0;
        
        // 空间层选择 (分辨率)
        if (availableBandwidth >= 2000000) {
            spatial = 2; // 1080p
        } else if (availableBandwidth >= 800000) {
            spatial = 1; // 720p
        } else {
            spatial = 0; // 360p
        }
        
        // 时间层选择 (帧率)
        if (availableBandwidth >= 1500000) {
            temporal = 2; // 30 fps
        } else if (availableBandwidth >= 500000) {
            temporal = 1; // 15 fps
        } else {
            temporal = 0; // 7.5 fps
        }
        
        return { spatial, temporal };
    }
    
    // 判断是否转发某个包
    shouldForward(packet, targetLayers) {
        const packetSpatial = this.getSpatialLayer(packet);
        const packetTemporal = this.getTemporalLayer(packet);
        
        return packetSpatial <= targetLayers.spatial &&
               packetTemporal <= targetLayers.temporal;
    }
    
    getSpatialLayer(packet) {
        // 从 RTP 扩展或负载中解析
        return packet.spatialId || 0;
    }
    
    getTemporalLayer(packet) {
        return packet.temporalId || 0;
    }
}
```

---

## 4. Simulcast vs SVC

### 4.1 对比表

| 特性 | Simulcast | SVC |
|------|-----------|-----|
| 编码次数 | 多次 (每层一次) | 一次 |
| 发送带宽 | 高 (多流) | 低 (单流) |
| CPU 消耗 | 高 | 中 |
| 编码器支持 | VP8, H.264, VP9 | VP9, AV1 |
| 灵活性 | 高 | 中 |
| SFU 复杂度 | 低 | 高 |
| 错误恢复 | 独立 | 层间依赖 |

### 4.2 带宽对比

```
相同质量下的带宽消耗:

Simulcast (3 层):
- high: 2.5 Mbps
- mid:  0.5 Mbps
- low:  0.15 Mbps
- 总计: 3.15 Mbps

SVC L3T3:
- 基础层 + 增强层: 2.5 Mbps
- 节省: 20-30%

原因:
- SVC 层间共享信息
- Simulcast 完全独立编码
```

### 4.3 选择建议

```
选择 Simulcast:
- 需要最大兼容性
- 使用 VP8 或 H.264
- SFU 不支持 SVC
- 需要独立控制每层

选择 SVC:
- 带宽受限
- 使用 VP9 或 AV1
- SFU 支持 SVC 层选择
- 大规模会议
```

### 4.4 混合方案

```javascript
// Simulcast + SVC 混合
const transceiver = pc.addTransceiver(videoTrack, {
    direction: 'sendonly',
    sendEncodings: [
        {
            rid: 'high',
            maxBitrate: 2500000,
            scalabilityMode: 'L1T3'  // 每层内使用时间 SVC
        },
        {
            rid: 'mid',
            maxBitrate: 500000,
            scalabilityMode: 'L1T3'
        },
        {
            rid: 'low',
            maxBitrate: 150000,
            scalabilityMode: 'L1T2'
        }
    ]
});
```

---

## 5. SFU 中的应用

### 5.1 SFU 层选择逻辑

```javascript
class SfuLayerManager {
    constructor() {
        this.subscribers = new Map(); // participantId -> layerConfig
    }
    
    // 订阅者加入
    addSubscriber(participantId, initialBandwidth) {
        const layers = this.selectLayers(initialBandwidth);
        this.subscribers.set(participantId, {
            bandwidth: initialBandwidth,
            spatialLayer: layers.spatial,
            temporalLayer: layers.temporal,
            lastKeyframeRequest: 0
        });
    }
    
    // 更新订阅者带宽
    updateBandwidth(participantId, newBandwidth) {
        const config = this.subscribers.get(participantId);
        if (!config) return;
        
        const oldLayers = {
            spatial: config.spatialLayer,
            temporal: config.temporalLayer
        };
        
        const newLayers = this.selectLayers(newBandwidth);
        
        // 检查是否需要切换层
        if (newLayers.spatial !== oldLayers.spatial) {
            // 空间层变化,可能需要请求关键帧
            this.requestKeyframe(participantId);
        }
        
        config.bandwidth = newBandwidth;
        config.spatialLayer = newLayers.spatial;
        config.temporalLayer = newLayers.temporal;
    }
    
    selectLayers(bandwidth) {
        // 根据带宽选择层
        if (bandwidth >= 2000000) {
            return { spatial: 2, temporal: 2 };
        } else if (bandwidth >= 1000000) {
            return { spatial: 1, temporal: 2 };
        } else if (bandwidth >= 500000) {
            return { spatial: 1, temporal: 1 };
        } else if (bandwidth >= 200000) {
            return { spatial: 0, temporal: 1 };
        } else {
            return { spatial: 0, temporal: 0 };
        }
    }
    
    requestKeyframe(participantId) {
        const config = this.subscribers.get(participantId);
        const now = Date.now();
        
        // 限制关键帧请求频率
        if (now - config.lastKeyframeRequest > 1000) {
            config.lastKeyframeRequest = now;
            // 发送 PLI 或 FIR
            this.sendPLI(participantId);
        }
    }
    
    // 判断是否转发包给订阅者
    shouldForward(participantId, packet) {
        const config = this.subscribers.get(participantId);
        if (!config) return false;
        
        const packetSpatial = packet.spatialId || 0;
        const packetTemporal = packet.temporalId || 0;
        
        return packetSpatial <= config.spatialLayer &&
               packetTemporal <= config.temporalLayer;
    }
}
```

### 5.2 Simulcast 选择逻辑

```javascript
class SimulcastSelector {
    constructor() {
        this.subscribers = new Map();
    }
    
    // 选择最佳 Simulcast 层
    selectSimulcastLayer(participantId, availableLayers) {
        const config = this.subscribers.get(participantId);
        if (!config) return 'low';
        
        const bandwidth = config.bandwidth;
        
        // 根据带宽选择层
        if (bandwidth >= 2000000 && availableLayers.includes('high')) {
            return 'high';
        } else if (bandwidth >= 500000 && availableLayers.includes('mid')) {
            return 'mid';
        } else {
            return 'low';
        }
    }
    
    // 处理层切换
    handleLayerSwitch(participantId, fromLayer, toLayer) {
        console.log(`Participant ${participantId}: ${fromLayer} -> ${toLayer}`);
        
        // 切换到更高层时请求关键帧
        if (this.isHigherLayer(toLayer, fromLayer)) {
            this.requestKeyframe(participantId, toLayer);
        }
    }
    
    isHigherLayer(a, b) {
        const order = { 'low': 0, 'mid': 1, 'high': 2 };
        return order[a] > order[b];
    }
}
```

### 5.3 自适应切换策略

```javascript
class AdaptiveLayerSwitcher {
    constructor() {
        this.switchHistory = [];
        this.minSwitchInterval = 2000; // 最小切换间隔 2 秒
        this.lastSwitchTime = 0;
    }
    
    // 决定是否切换层
    shouldSwitch(currentLayer, targetLayer, bandwidth, packetLoss) {
        const now = Date.now();
        
        // 检查切换间隔
        if (now - this.lastSwitchTime < this.minSwitchInterval) {
            return false;
        }
        
        // 向下切换: 带宽不足或丢包高
        if (this.isLowerLayer(targetLayer, currentLayer)) {
            if (bandwidth < this.getLayerMinBandwidth(currentLayer) ||
                packetLoss > 0.05) {
                return true;
            }
        }
        
        // 向上切换: 带宽充足且丢包低
        if (this.isHigherLayer(targetLayer, currentLayer)) {
            if (bandwidth > this.getLayerMinBandwidth(targetLayer) * 1.2 &&
                packetLoss < 0.02) {
                return true;
            }
        }
        
        return false;
    }
    
    getLayerMinBandwidth(layer) {
        const bandwidths = {
            'low': 150000,
            'mid': 500000,
            'high': 2000000
        };
        return bandwidths[layer] || 150000;
    }
    
    recordSwitch(fromLayer, toLayer) {
        this.lastSwitchTime = Date.now();
        this.switchHistory.push({
            time: this.lastSwitchTime,
            from: fromLayer,
            to: toLayer
        });
    }
}
```

---

## 6. 实战配置

### 6.1 完整 Simulcast 示例

```javascript
class SimulcastManager {
    constructor(pc) {
        this.pc = pc;
        this.sender = null;
    }
    
    async setupSimulcast(videoTrack) {
        // 创建带 Simulcast 的 transceiver
        const transceiver = this.pc.addTransceiver(videoTrack, {
            direction: 'sendonly',
            sendEncodings: [
                {
                    rid: 'high',
                    maxBitrate: 2500000,
                    maxFramerate: 30,
                    scaleResolutionDownBy: 1,
                    priority: 'high'
                },
                {
                    rid: 'mid',
                    maxBitrate: 500000,
                    maxFramerate: 30,
                    scaleResolutionDownBy: 2,
                    priority: 'medium'
                },
                {
                    rid: 'low',
                    maxBitrate: 150000,
                    maxFramerate: 15,
                    scaleResolutionDownBy: 4,
                    priority: 'low'
                }
            ]
        });
        
        this.sender = transceiver.sender;
        
        // 设置编码器优先级 (优先 VP8)
        const codecs = RTCRtpReceiver.getCapabilities('video').codecs;
        const vp8Codecs = codecs.filter(c => c.mimeType === 'video/VP8');
        transceiver.setCodecPreferences([...vp8Codecs, ...codecs.filter(c => c.mimeType !== 'video/VP8')]);
        
        return transceiver;
    }
    
    // 根据网络状况调整
    async adaptToNetwork(stats) {
        if (!this.sender) return;
        
        const params = this.sender.getParameters();
        
        // 根据 RTT 和丢包调整
        if (stats.rtt > 200 || stats.packetLoss > 0.1) {
            // 网络差: 只发送 low
            params.encodings[0].active = false;
            params.encodings[1].active = false;
            params.encodings[2].active = true;
        } else if (stats.rtt > 100 || stats.packetLoss > 0.05) {
            // 网络中等: 发送 low + mid
            params.encodings[0].active = false;
            params.encodings[1].active = true;
            params.encodings[2].active = true;
        } else {
            // 网络好: 全部发送
            params.encodings[0].active = true;
            params.encodings[1].active = true;
            params.encodings[2].active = true;
        }
        
        await this.sender.setParameters(params);
    }
    
    // 获取统计
    async getStats() {
        if (!this.sender) return null;
        
        const stats = await this.sender.getStats();
        const result = { layers: {} };
        
        stats.forEach(report => {
            if (report.type === 'outbound-rtp' && report.kind === 'video') {
                const rid = report.rid || 'default';
                result.layers[rid] = {
                    active: report.active,
                    bytesSent: report.bytesSent,
                    framesSent: report.framesSent,
                    framesEncoded: report.framesEncoded,
                    frameWidth: report.frameWidth,
                    frameHeight: report.frameHeight,
                    framesPerSecond: report.framesPerSecond
                };
            }
        });
        
        return result;
    }
}

// 使用示例
const pc = new RTCPeerConnection(config);
const simulcast = new SimulcastManager(pc);

const stream = await navigator.mediaDevices.getUserMedia({ video: true });
const videoTrack = stream.getVideoTracks()[0];

await simulcast.setupSimulcast(videoTrack);

// 监控并调整
setInterval(async () => {
    const stats = await simulcast.getStats();
    console.log('Simulcast stats:', stats);
}, 1000);
```

### 6.2 SVC 配置示例

```javascript
class SvcManager {
    constructor(pc) {
        this.pc = pc;
        this.sender = null;
    }
    
    async setupSvc(videoTrack, mode = 'L3T3') {
        const transceiver = this.pc.addTransceiver(videoTrack, {
            direction: 'sendonly',
            sendEncodings: [
                {
                    scalabilityMode: mode,
                    maxBitrate: 2500000
                }
            ]
        });
        
        this.sender = transceiver.sender;
        
        // 优先使用 VP9
        const codecs = RTCRtpReceiver.getCapabilities('video').codecs;
        const vp9Codecs = codecs.filter(c => c.mimeType === 'video/VP9');
        
        if (vp9Codecs.length > 0) {
            transceiver.setCodecPreferences([...vp9Codecs, ...codecs.filter(c => c.mimeType !== 'video/VP9')]);
        }
        
        return transceiver;
    }
    
    // 动态调整 SVC 模式
    async changeScalabilityMode(newMode) {
        if (!this.sender) return;
        
        const params = this.sender.getParameters();
        params.encodings[0].scalabilityMode = newMode;
        await this.sender.setParameters(params);
    }
}
```

---

## 7. 总结

### 7.1 核心要点

| 技术 | 适用场景 | 关键配置 |
|------|---------|---------|
| Simulcast | 多人会议,兼容性优先 | sendEncodings, rid |
| SVC | 大规模会议,带宽优先 | scalabilityMode |
| 混合 | 复杂场景 | Simulcast + 时间 SVC |

### 7.2 最佳实践

```
Simulcast 最佳实践:
1. 配置 3 层: high/mid/low
2. 合理设置码率比例 (如 10:3:1)
3. 根据网络动态启用/禁用层
4. 监控每层的编码统计

SVC 最佳实践:
1. 优先使用 VP9 或 AV1
2. 根据场景选择 scalabilityMode
3. SFU 需要支持 SVC 层选择
4. 注意层间依赖关系
```

### 7.3 下一篇预告

在下一篇文章中,我们将进入工程实践部分,学习如何构建自己的 WebRTC 信令服务器。

---

## 参考资料

1. [RFC 8853 - Simulcast](https://datatracker.ietf.org/doc/html/rfc8853)
2. [VP9 SVC](https://www.webmproject.org/vp9/)
3. [WebRTC Scalable Video Coding](https://www.w3.org/TR/webrtc-svc/)

---

> 作者: WebRTC 技术专栏  
> 系列: 音视频编码与媒体处理 (3/3)  
> 上一篇: [音频处理: AEC、AGC、NS、VAD](./19-audio-processing.md)  
> 下一篇: [构建自己的 WebRTC 信令服务器](../part5-practice/21-signaling-server.md)
