---
title: "WebRTC 调试: 抓包、RTCStats、webrtc-internals"
description: "1. [调试概述](#1-调试概述)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 26
---

> 本文是 WebRTC 系列专栏的第二十六篇,将深入探讨 WebRTC 的调试工具和方法,包括 Chrome webrtc-internals、RTP/RTCP 抓包分析以及性能指标解读。

---

## 目录

1. [调试概述](#1-调试概述)
2. [webrtc-internals](#2-webrtc-internals)
3. [RTCStats API](#3-rtcstats-api)
4. [抓包分析](#4-抓包分析)
5. [常见问题诊断](#5-常见问题诊断)
6. [监控系统搭建](#6-监控系统搭建)
7. [总结](#7-总结)

---

## 1. 调试概述

### 1.1 WebRTC 调试挑战

```
WebRTC 调试难点:

1. 实时性
   - 问题转瞬即逝
   - 难以复现

2. 复杂性
   - 多协议栈 (ICE/DTLS/SRTP/RTP/RTCP)
   - 多组件交互

3. 网络依赖
   - NAT 穿透问题
   - 网络波动影响

4. 端到端
   - 发送端/接收端/服务器
   - 需要多点协同调试
```

### 1.2 调试工具概览

| 工具 | 用途 | 适用场景 |
|------|------|---------|
| webrtc-internals | 浏览器内置调试 | 快速诊断 |
| RTCStats API | 程序化获取统计 | 监控系统 |
| Wireshark | 网络抓包 | 协议分析 |
| Chrome DevTools | 网络/控制台 | 信令调试 |

---

## 2. webrtc-internals

### 2.1 访问方式

```
Chrome: chrome://webrtc-internals
Firefox: about:webrtc
Edge: edge://webrtc-internals

功能:
- 查看所有 PeerConnection
- 实时统计图表
- 事件日志
- 导出调试信息
```

### 2.2 界面解读

```
webrtc-internals 主要区域:

+------------------------------------------------------------------+
|  Create Dump  |  Download the PeerConnection updates              |
+------------------------------------------------------------------+
|                                                                  |
|  PeerConnection (id=1)                                           |
|  +------------------------------------------------------------+  |
|  | url: https://example.com                                   |  |
|  | iceConnectionState: connected                              |  |
|  | iceGatheringState: complete                                |  |
|  | signalingState: stable                                     |  |
|  +------------------------------------------------------------+  |
|                                                                  |
|  [Stats Tables]  [Stats Graphs]  [Event Log]                     |
|                                                                  |
+------------------------------------------------------------------+
```

### 2.3 关键指标

```
重要统计指标:

1. 连接状态
   - iceConnectionState
   - iceGatheringState
   - signalingState
   - connectionState

2. 视频发送
   - bytesSent: 发送字节数
   - packetsSent: 发送包数
   - framesEncoded: 编码帧数
   - framesSent: 发送帧数
   - qualityLimitationReason: 质量限制原因

3. 视频接收
   - bytesReceived: 接收字节数
   - packetsReceived: 接收包数
   - packetsLost: 丢包数
   - framesDecoded: 解码帧数
   - framesDropped: 丢弃帧数
   - jitter: 抖动

4. 音频
   - audioLevel: 音量级别
   - totalAudioEnergy: 总音频能量
   - echoReturnLoss: 回声损耗
```

### 2.4 图表分析

```
常用图表:

1. Bitrate (码率)
   - 发送/接收码率变化
   - 识别带宽问题

2. Packets (包)
   - 发送/接收/丢失包数
   - 识别丢包问题

3. Frame Rate (帧率)
   - 编码/发送/接收/解码帧率
   - 识别性能问题

4. RTT (往返时延)
   - 网络延迟变化
   - 识别网络问题
```

### 2.5 导出调试信息

```javascript
// 在 webrtc-internals 页面
// 点击 "Create Dump" 按钮
// 或 "Download the PeerConnection updates and stats data"

// 导出格式为 JSON,包含:
{
    "getUserMedia": [...],
    "PeerConnections": [
        {
            "pid": 12345,
            "url": "https://example.com",
            "rtcConfiguration": {...},
            "constraints": {...},
            "stats": {...},
            "updateLog": [...]
        }
    ]
}
```

---

## 3. RTCStats API

### 3.1 获取统计信息

```javascript
// 获取所有统计
const stats = await pc.getStats();

stats.forEach(report => {
    console.log(`${report.type}: ${report.id}`);
    console.log(report);
});

// 获取特定 sender/receiver 的统计
const sender = pc.getSenders()[0];
const senderStats = await sender.getStats();

const receiver = pc.getReceivers()[0];
const receiverStats = await receiver.getStats();
```

### 3.2 统计报告类型

```javascript
// 主要报告类型
const reportTypes = {
    // 入站 RTP 流
    'inbound-rtp': {
        kind: 'video',           // 'audio' 或 'video'
        packetsReceived: 1000,
        bytesReceived: 500000,
        packetsLost: 5,
        jitter: 0.01,
        framesDecoded: 300,
        framesDropped: 2,
        frameWidth: 1280,
        frameHeight: 720
    },
    
    // 出站 RTP 流
    'outbound-rtp': {
        kind: 'video',
        packetsSent: 1000,
        bytesSent: 500000,
        framesEncoded: 300,
        framesSent: 300,
        qualityLimitationReason: 'none', // 'cpu', 'bandwidth', 'other'
        qualityLimitationDurations: {
            none: 10000,
            cpu: 0,
            bandwidth: 500,
            other: 0
        }
    },
    
    // 远端入站 RTP (从 RTCP RR 获取)
    'remote-inbound-rtp': {
        packetsLost: 5,
        jitter: 0.01,
        roundTripTime: 0.05
    },
    
    // ICE 候选对
    'candidate-pair': {
        state: 'succeeded',
        localCandidateId: 'xxx',
        remoteCandidateId: 'yyy',
        bytesSent: 1000000,
        bytesReceived: 1000000,
        currentRoundTripTime: 0.05,
        availableOutgoingBitrate: 2000000
    },
    
    // 本地候选
    'local-candidate': {
        candidateType: 'host', // 'srflx', 'relay'
        protocol: 'udp',
        address: '192.168.1.100',
        port: 50000
    },
    
    // 媒体源
    'media-source': {
        kind: 'video',
        width: 1280,
        height: 720,
        framesPerSecond: 30
    }
};
```

### 3.3 统计监控类

```javascript
class WebRTCStatsMonitor {
    constructor(pc, interval = 1000) {
        this.pc = pc;
        this.interval = interval;
        this.previousStats = null;
        this.callbacks = [];
    }
    
    start() {
        this.timer = setInterval(() => this.collect(), this.interval);
    }
    
    stop() {
        clearInterval(this.timer);
    }
    
    onStats(callback) {
        this.callbacks.push(callback);
    }
    
    async collect() {
        const stats = await this.pc.getStats();
        const report = this.processStats(stats);
        
        this.callbacks.forEach(cb => cb(report));
        this.previousStats = stats;
    }
    
    processStats(stats) {
        const report = {
            timestamp: Date.now(),
            video: { send: {}, recv: {} },
            audio: { send: {}, recv: {} },
            connection: {}
        };
        
        stats.forEach(s => {
            if (s.type === 'outbound-rtp') {
                const target = s.kind === 'video' ? report.video.send : report.audio.send;
                target.bitrate = this.calculateBitrate(s, 'bytesSent');
                target.packetsSent = s.packetsSent;
                target.framesEncoded = s.framesEncoded;
                target.frameWidth = s.frameWidth;
                target.frameHeight = s.frameHeight;
                target.qualityLimitationReason = s.qualityLimitationReason;
            }
            
            if (s.type === 'inbound-rtp') {
                const target = s.kind === 'video' ? report.video.recv : report.audio.recv;
                target.bitrate = this.calculateBitrate(s, 'bytesReceived');
                target.packetsReceived = s.packetsReceived;
                target.packetsLost = s.packetsLost;
                target.jitter = s.jitter;
                target.framesDecoded = s.framesDecoded;
                target.framesDropped = s.framesDropped;
            }
            
            if (s.type === 'candidate-pair' && s.state === 'succeeded') {
                report.connection.rtt = s.currentRoundTripTime * 1000;
                report.connection.availableBandwidth = s.availableOutgoingBitrate;
            }
        });
        
        return report;
    }
    
    calculateBitrate(current, field) {
        if (!this.previousStats) return 0;
        
        let previous = null;
        this.previousStats.forEach(s => {
            if (s.id === current.id) previous = s;
        });
        
        if (!previous) return 0;
        
        const bytesDiff = current[field] - previous[field];
        const timeDiff = (current.timestamp - previous.timestamp) / 1000;
        
        return Math.round((bytesDiff * 8) / timeDiff);
    }
}

// 使用示例
const monitor = new WebRTCStatsMonitor(pc);
monitor.onStats(report => {
    console.log('Video send bitrate:', report.video.send.bitrate);
    console.log('Video recv bitrate:', report.video.recv.bitrate);
    console.log('RTT:', report.connection.rtt);
});
monitor.start();
```

### 3.4 丢包率计算

```javascript
class PacketLossCalculator {
    constructor() {
        this.history = [];
    }
    
    update(packetsReceived, packetsLost) {
        this.history.push({
            timestamp: Date.now(),
            received: packetsReceived,
            lost: packetsLost
        });
        
        // 保留最近 60 秒
        const cutoff = Date.now() - 60000;
        this.history = this.history.filter(h => h.timestamp > cutoff);
    }
    
    // 计算瞬时丢包率
    getInstantLossRate() {
        if (this.history.length < 2) return 0;
        
        const latest = this.history[this.history.length - 1];
        const previous = this.history[this.history.length - 2];
        
        const receivedDiff = latest.received - previous.received;
        const lostDiff = latest.lost - previous.lost;
        
        if (receivedDiff + lostDiff === 0) return 0;
        return lostDiff / (receivedDiff + lostDiff);
    }
    
    // 计算平均丢包率
    getAverageLossRate() {
        if (this.history.length < 2) return 0;
        
        const first = this.history[0];
        const last = this.history[this.history.length - 1];
        
        const totalReceived = last.received - first.received;
        const totalLost = last.lost - first.lost;
        
        if (totalReceived + totalLost === 0) return 0;
        return totalLost / (totalReceived + totalLost);
    }
}
```

---

## 4. 抓包分析

### 4.1 Wireshark 配置

```
Wireshark 抓取 WebRTC 流量:

1. 捕获过滤器
   udp port 3478 or udp portrange 10000-60000

2. 显示过滤器
   stun || dtls || rtp || rtcp

3. 解码设置
   - 右键 UDP 包 -> Decode As -> RTP
   - 或设置 RTP 端口范围
```

### 4.2 STUN 包分析

```
STUN Binding Request:

Frame: 96 bytes
    STUN Message Type: Binding Request (0x0001)
    Message Length: 68
    Message Cookie: 0x2112a442
    Message Transaction ID: xxx
    Attributes:
        USERNAME: user:pass
        ICE-CONTROLLING: xxx
        PRIORITY: xxx
        MESSAGE-INTEGRITY: xxx
        FINGERPRINT: xxx

分析要点:
- 检查 USERNAME 格式
- 检查 MESSAGE-INTEGRITY
- 观察请求/响应配对
```

### 4.3 DTLS 握手分析

```
DTLS 握手流程:

1. ClientHello
   - 版本: DTLS 1.2
   - 随机数
   - 密码套件列表
   - 扩展 (use_srtp)

2. HelloVerifyRequest
   - Cookie

3. ClientHello (带 Cookie)

4. ServerHello
   - 选择的密码套件
   - 选择的 SRTP 配置

5. Certificate
   - 服务器证书

6. ServerKeyExchange
   - ECDHE 参数

7. CertificateRequest

8. ServerHelloDone

9. Certificate (客户端)

10. ClientKeyExchange

11. CertificateVerify

12. ChangeCipherSpec

13. Finished

分析要点:
- 检查证书是否正确
- 检查密码套件协商
- 检查 SRTP 配置
```

### 4.4 RTP 包分析

```
RTP 包结构:

 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|V=2|P|X|  CC   |M|     PT      |       sequence number         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                           timestamp                           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|           synchronization source (SSRC) identifier            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

Wireshark 显示:
Real-Time Transport Protocol
    Version: 2
    Padding: False
    Extension: True
    Contributing source identifiers count: 0
    Marker: False
    Payload type: VP8 (96)
    Sequence number: 12345
    Timestamp: 1234567890
    Synchronization Source identifier: 0x12345678

分析要点:
- 序列号是否连续
- 时间戳增量是否正确
- Marker 位是否正确标记帧边界
```

### 4.5 RTCP 包分析

```
RTCP Sender Report:

Sender Report
    Version: 2
    Padding: False
    Reception report count: 1
    Packet type: Sender Report (200)
    Length: 12
    Sender SSRC: 0x12345678
    NTP timestamp: xxx
    RTP timestamp: xxx
    Sender's packet count: 1000
    Sender's octet count: 500000
    
    Source 1
        SSRC: 0x87654321
        Fraction lost: 0
        Cumulative lost: 5
        Extended highest sequence number: 12345
        Interarrival jitter: 100
        Last SR timestamp: xxx
        Delay since last SR: xxx

分析要点:
- 丢包数 (Cumulative lost)
- 丢包率 (Fraction lost)
- 抖动 (Jitter)
- RTT 计算 (通过 LSR 和 DLSR)
```

---

## 5. 常见问题诊断

### 5.1 连接失败

```javascript
// 诊断连接失败
function diagnoseConnectionFailure(pc) {
    // 1. 检查 ICE 状态
    console.log('ICE Connection State:', pc.iceConnectionState);
    console.log('ICE Gathering State:', pc.iceGatheringState);
    
    // 2. 检查候选收集
    pc.getStats().then(stats => {
        let localCandidates = [];
        let remoteCandidates = [];
        
        stats.forEach(report => {
            if (report.type === 'local-candidate') {
                localCandidates.push({
                    type: report.candidateType,
                    protocol: report.protocol,
                    address: report.address
                });
            }
            if (report.type === 'remote-candidate') {
                remoteCandidates.push({
                    type: report.candidateType,
                    protocol: report.protocol,
                    address: report.address
                });
            }
        });
        
        console.log('Local candidates:', localCandidates);
        console.log('Remote candidates:', remoteCandidates);
        
        // 3. 检查是否有 relay 候选
        const hasRelay = localCandidates.some(c => c.type === 'relay');
        if (!hasRelay) {
            console.warn('No relay candidates - TURN may not be configured');
        }
    });
}

// 常见原因:
// 1. ICE 服务器配置错误
// 2. 防火墙阻止 UDP
// 3. 对称 NAT 无法穿透
// 4. TURN 服务器不可用
```

### 5.2 视频卡顿

```javascript
// 诊断视频卡顿
async function diagnoseVideoStutter(pc) {
    const stats = await pc.getStats();
    
    stats.forEach(report => {
        if (report.type === 'inbound-rtp' && report.kind === 'video') {
            // 检查丢包
            const lossRate = report.packetsLost / 
                (report.packetsReceived + report.packetsLost);
            console.log('Packet loss rate:', (lossRate * 100).toFixed(2) + '%');
            
            // 检查丢帧
            const dropRate = report.framesDropped / 
                (report.framesDecoded + report.framesDropped);
            console.log('Frame drop rate:', (dropRate * 100).toFixed(2) + '%');
            
            // 检查抖动
            console.log('Jitter:', report.jitter * 1000, 'ms');
            
            // 检查解码延迟
            if (report.totalDecodeTime && report.framesDecoded) {
                const avgDecodeTime = report.totalDecodeTime / report.framesDecoded;
                console.log('Avg decode time:', avgDecodeTime * 1000, 'ms');
            }
        }
        
        if (report.type === 'candidate-pair' && report.state === 'succeeded') {
            console.log('RTT:', report.currentRoundTripTime * 1000, 'ms');
            console.log('Available bandwidth:', 
                report.availableOutgoingBitrate / 1000, 'kbps');
        }
    });
}

// 卡顿原因:
// 1. 网络丢包 > 5%
// 2. 抖动 > 50ms
// 3. 带宽不足
// 4. CPU 解码能力不足
```

### 5.3 音频问题

```javascript
// 诊断音频问题
async function diagnoseAudioIssues(pc) {
    const stats = await pc.getStats();
    
    stats.forEach(report => {
        if (report.type === 'inbound-rtp' && report.kind === 'audio') {
            console.log('Audio packets received:', report.packetsReceived);
            console.log('Audio packets lost:', report.packetsLost);
            console.log('Audio jitter:', report.jitter * 1000, 'ms');
            
            // 检查音频级别
            if (report.audioLevel !== undefined) {
                console.log('Audio level:', report.audioLevel);
                if (report.audioLevel < 0.01) {
                    console.warn('Audio level very low - possible mute or no input');
                }
            }
        }
        
        if (report.type === 'media-source' && report.kind === 'audio') {
            console.log('Audio source level:', report.audioLevel);
            console.log('Echo return loss:', report.echoReturnLoss);
        }
    });
}

// 音频问题原因:
// 1. 麦克风未授权或静音
// 2. 回声消除失效
// 3. 音频丢包
// 4. 采样率不匹配
```

---

## 6. 监控系统搭建

### 6.1 数据收集

```javascript
class WebRTCMetricsCollector {
    constructor(pc, endpoint) {
        this.pc = pc;
        this.endpoint = endpoint;
        this.sessionId = this.generateSessionId();
    }
    
    generateSessionId() {
        return Math.random().toString(36).substring(2, 15);
    }
    
    async collect() {
        const stats = await this.pc.getStats();
        const metrics = {
            sessionId: this.sessionId,
            timestamp: Date.now(),
            video: {},
            audio: {},
            connection: {}
        };
        
        stats.forEach(report => {
            this.processReport(report, metrics);
        });
        
        return metrics;
    }
    
    processReport(report, metrics) {
        switch (report.type) {
            case 'outbound-rtp':
                if (report.kind === 'video') {
                    metrics.video.send = {
                        bitrate: this.calculateBitrate(report),
                        frameRate: report.framesPerSecond,
                        width: report.frameWidth,
                        height: report.frameHeight,
                        qualityLimitation: report.qualityLimitationReason
                    };
                }
                break;
                
            case 'inbound-rtp':
                if (report.kind === 'video') {
                    metrics.video.recv = {
                        bitrate: this.calculateBitrate(report),
                        packetsLost: report.packetsLost,
                        jitter: report.jitter,
                        framesDropped: report.framesDropped
                    };
                }
                break;
                
            case 'candidate-pair':
                if (report.state === 'succeeded') {
                    metrics.connection = {
                        rtt: report.currentRoundTripTime,
                        availableBandwidth: report.availableOutgoingBitrate,
                        localType: report.localCandidateType,
                        remoteType: report.remoteCandidateType
                    };
                }
                break;
        }
    }
    
    async send(metrics) {
        try {
            await fetch(this.endpoint, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(metrics)
            });
        } catch (error) {
            console.error('Failed to send metrics:', error);
        }
    }
    
    start(interval = 5000) {
        this.timer = setInterval(async () => {
            const metrics = await this.collect();
            await this.send(metrics);
        }, interval);
    }
    
    stop() {
        clearInterval(this.timer);
    }
}
```

### 6.2 服务端存储

```javascript
// metrics-server.js
const express = require('express');
const app = express();

app.use(express.json());

// 存储指标 (实际应使用时序数据库如 InfluxDB)
const metricsStore = [];

app.post('/metrics', (req, res) => {
    const metrics = req.body;
    metrics.receivedAt = Date.now();
    metricsStore.push(metrics);
    
    // 保留最近 1 小时
    const cutoff = Date.now() - 3600000;
    while (metricsStore.length > 0 && metricsStore[0].receivedAt < cutoff) {
        metricsStore.shift();
    }
    
    res.json({ status: 'ok' });
});

// 查询接口
app.get('/metrics/:sessionId', (req, res) => {
    const { sessionId } = req.params;
    const sessionMetrics = metricsStore.filter(m => m.sessionId === sessionId);
    res.json(sessionMetrics);
});

// 聚合统计
app.get('/stats/summary', (req, res) => {
    const summary = {
        totalSessions: new Set(metricsStore.map(m => m.sessionId)).size,
        avgRtt: 0,
        avgPacketLoss: 0,
        avgBitrate: 0
    };
    
    // 计算平均值...
    
    res.json(summary);
});

app.listen(3001);
```

---

## 7. 总结

### 7.1 调试工具对比

| 工具 | 优点 | 缺点 | 适用场景 |
|------|------|------|---------|
| webrtc-internals | 无需代码,实时 | 仅限浏览器 | 快速诊断 |
| RTCStats API | 可编程,灵活 | 需要开发 | 监控系统 |
| Wireshark | 协议级分析 | 学习曲线高 | 深度调试 |

### 7.2 关键指标阈值

```
健康指标参考值:

丢包率: < 2%
抖动: < 30ms
RTT: < 150ms
帧率: >= 24fps
解码延迟: < 50ms
```

### 7.3 下一篇预告

在下一篇文章中,我们将探讨 WebRTC 质量优化策略。

---

## 参考资料

1. [RTCStats Identifiers](https://www.w3.org/TR/webrtc-stats/)
2. [Chrome webrtc-internals](https://webrtc.github.io/webrtc-org/native-code/logging/)
3. [Wireshark WebRTC](https://wiki.wireshark.org/WebRTC)

---

> 作者: WebRTC 技术专栏  
> 系列: 高级主题与优化 (1/4)  
> 上一篇: [移动端 WebRTC](../part5-practice/25-mobile-webrtc.md)  
> 下一篇: [WebRTC 质量优化](./27-quality-optimization.md)
