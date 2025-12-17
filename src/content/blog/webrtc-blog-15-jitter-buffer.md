---
title: "抖动缓冲区 (Jitter Buffer) 与网络抗性"
description: "1. [网络抖动概述](#1-网络抖动概述)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 15
---

> 本文是 WebRTC 系列专栏的第十五篇,将深入探讨抖动缓冲区的工作原理以及 WebRTC 的各种网络容错机制,包括 NACK、PLI 和 FEC。

---

## 目录

1. [网络抖动概述](#1-网络抖动概述)
2. [Jitter Buffer 原理](#2-jitter-buffer-原理)
3. [自适应 Jitter Buffer](#3-自适应-jitter-buffer)
4. [NACK 重传机制](#4-nack-重传机制)
5. [PLI 与 FIR](#5-pli-与-fir)
6. [FEC 前向纠错](#6-fec-前向纠错)
7. [延迟与丢包优化](#7-延迟与丢包优化)
8. [总结](#8-总结)

---

## 1. 网络抖动概述

### 1.1 什么是网络抖动

网络抖动 (Jitter) 是指数据包到达时间间隔的变化。

```
理想情况 (无抖动):
发送: |--20ms--|--20ms--|--20ms--|--20ms--|
      P1       P2       P3       P4       P5

接收: |--20ms--|--20ms--|--20ms--|--20ms--|
      P1       P2       P3       P4       P5


实际情况 (有抖动):
发送: |--20ms--|--20ms--|--20ms--|--20ms--|
      P1       P2       P3       P4       P5

接收: |--15ms--|--30ms--|--10ms--|--25ms--|
      P1       P2       P3       P4       P5
             ^        ^        ^
           抖动     抖动     抖动
```

### 1.2 抖动的来源

| 来源 | 说明 |
|------|------|
| 网络拥塞 | 路由器缓冲区排队 |
| 路由变化 | 数据包走不同路径 |
| 无线网络 | 信号干扰、重传 |
| 操作系统调度 | CPU 负载影响 |
| 编码延迟变化 | 关键帧编码更慢 |

### 1.3 抖动的影响

```
无 Jitter Buffer 时:

发送: P1(0ms) P2(20ms) P3(40ms) P4(60ms)
接收: P1(50ms) P2(85ms) P3(95ms) P4(130ms)

播放时间线:
0ms   50ms   70ms   90ms   110ms
|      |      |      |      |
       P1     ?      P2     ?
              ^             ^
            缺包          缺包

结果: 音频卡顿、视频花屏
```

---

## 2. Jitter Buffer 原理

### 2.1 基本概念

Jitter Buffer 是一个缓冲区,用于:
1. 吸收网络抖动
2. 重新排序乱序包
3. 等待丢失包的重传
4. 提供平滑的播放体验

### 2.2 工作原理

```
                    Jitter Buffer
                    +------------------+
网络 -----> 接收 -----> |  P3  P4  P5  P6  | -----> 播放
                    +------------------+
                         ^
                         |
                    缓冲延迟 (如 100ms)

时间线:
接收: P1(0ms) P3(15ms) P2(25ms) P4(45ms) P5(60ms)
      |       |        |        |        |
      v       v        v        v        v
缓冲: [P1]   [P1,P3]  [P1,P2,P3] [P1,P2,P3,P4] ...
      
播放: (等待 100ms 后开始)
      100ms: 播放 P1
      120ms: 播放 P2
      140ms: 播放 P3
      ...
```

### 2.3 缓冲区大小权衡

```
缓冲区大小的权衡:

小缓冲区:
+ 低延迟
- 容易欠载 (underrun)
- 对抖动敏感

大缓冲区:
+ 抗抖动能力强
+ 更多时间等待重传
- 高延迟
- 占用更多内存

理想大小:
buffer_size >= max_jitter + nack_rtt
```

### 2.4 基本实现

```javascript
class JitterBuffer {
    constructor(options = {}) {
        this.buffer = new Map(); // seq -> packet
        this.minDelay = options.minDelay || 50;  // ms
        this.maxDelay = options.maxDelay || 200; // ms
        this.targetDelay = options.targetDelay || 100; // ms
        this.nextSeqToPlay = null;
        this.clockRate = options.clockRate || 90000;
    }
    
    // 插入数据包
    insert(packet) {
        const seq = packet.sequenceNumber;
        
        // 检查是否太旧
        if (this.nextSeqToPlay !== null) {
            const diff = this.seqDiff(seq, this.nextSeqToPlay);
            if (diff < 0) {
                // 包太旧,丢弃
                return { action: 'discard', reason: 'too_old' };
            }
        }
        
        // 检查重复
        if (this.buffer.has(seq)) {
            return { action: 'discard', reason: 'duplicate' };
        }
        
        // 插入缓冲区
        this.buffer.set(seq, {
            packet: packet,
            arrivalTime: Date.now()
        });
        
        // 初始化播放序列号
        if (this.nextSeqToPlay === null) {
            this.nextSeqToPlay = seq;
        }
        
        return { action: 'buffered' };
    }
    
    // 获取下一个要播放的包
    getNextPacket() {
        if (this.nextSeqToPlay === null) {
            return null;
        }
        
        const entry = this.buffer.get(this.nextSeqToPlay);
        
        if (!entry) {
            // 包丢失
            return { missing: true, seq: this.nextSeqToPlay };
        }
        
        // 检查是否到达播放时间
        const waitTime = Date.now() - entry.arrivalTime;
        if (waitTime < this.targetDelay) {
            return { waiting: true, remainingMs: this.targetDelay - waitTime };
        }
        
        // 返回包并更新序列号
        this.buffer.delete(this.nextSeqToPlay);
        this.nextSeqToPlay = (this.nextSeqToPlay + 1) % 65536;
        
        return { packet: entry.packet };
    }
    
    // 序列号差值计算 (处理回绕)
    seqDiff(a, b) {
        let diff = a - b;
        if (diff > 32768) diff -= 65536;
        if (diff < -32768) diff += 65536;
        return diff;
    }
    
    // 获取缓冲区状态
    getStats() {
        return {
            size: this.buffer.size,
            targetDelay: this.targetDelay,
            nextSeq: this.nextSeqToPlay
        };
    }
}
```

---

## 3. 自适应 Jitter Buffer

### 3.1 自适应原理

自适应 Jitter Buffer 根据网络状况动态调整缓冲区大小。

```
网络状况好:
抖动小 -> 减小缓冲区 -> 降低延迟

网络状况差:
抖动大 -> 增大缓冲区 -> 保证流畅
```

### 3.2 抖动估计

```javascript
class JitterEstimator {
    constructor() {
        this.jitter = 0;
        this.lastArrivalTime = null;
        this.lastTimestamp = null;
        this.clockRate = 90000;
    }
    
    update(timestamp, arrivalTimeMs) {
        if (this.lastArrivalTime !== null) {
            // 计算到达间隔差
            const arrivalDiff = arrivalTimeMs - this.lastArrivalTime;
            const timestampDiff = (timestamp - this.lastTimestamp) / 
                                 this.clockRate * 1000;
            
            const d = Math.abs(arrivalDiff - timestampDiff);
            
            // 指数加权移动平均
            this.jitter = this.jitter + (d - this.jitter) / 16;
        }
        
        this.lastArrivalTime = arrivalTimeMs;
        this.lastTimestamp = timestamp;
        
        return this.jitter;
    }
    
    getJitterMs() {
        return this.jitter;
    }
}
```

### 3.3 缓冲区大小调整

```javascript
class AdaptiveJitterBuffer extends JitterBuffer {
    constructor(options = {}) {
        super(options);
        this.jitterEstimator = new JitterEstimator();
        this.underrunCount = 0;
        this.overrunCount = 0;
        this.adjustInterval = 1000; // ms
        this.lastAdjustTime = Date.now();
    }
    
    insert(packet) {
        // 更新抖动估计
        this.jitterEstimator.update(
            packet.timestamp, 
            Date.now()
        );
        
        // 定期调整缓冲区大小
        this.maybeAdjustBuffer();
        
        return super.insert(packet);
    }
    
    maybeAdjustBuffer() {
        const now = Date.now();
        if (now - this.lastAdjustTime < this.adjustInterval) {
            return;
        }
        this.lastAdjustTime = now;
        
        const jitter = this.jitterEstimator.getJitterMs();
        
        // 目标延迟 = 抖动 * 安全系数 + RTT/2 (用于 NACK)
        let newTarget = jitter * 2 + 50; // 50ms 用于 NACK
        
        // 根据欠载/过载调整
        if (this.underrunCount > 0) {
            // 欠载,增加缓冲
            newTarget += 20;
            this.underrunCount = 0;
        } else if (this.overrunCount > 5) {
            // 过载,减少缓冲
            newTarget -= 10;
            this.overrunCount = 0;
        }
        
        // 限制范围
        this.targetDelay = Math.max(this.minDelay, 
                          Math.min(this.maxDelay, newTarget));
    }
    
    getNextPacket() {
        const result = super.getNextPacket();
        
        if (result.missing) {
            this.underrunCount++;
        } else if (this.buffer.size > 10) {
            this.overrunCount++;
        }
        
        return result;
    }
}
```

### 3.4 NetEQ (WebRTC 音频)

WebRTC 使用 NetEQ 处理音频抖动:

```
NetEQ 功能:
1. 自适应抖动缓冲
2. 丢包隐藏 (PLC)
3. 加速/减速播放
4. 静音检测

加速播放:
- 缓冲区过大时
- 跳过部分静音帧
- 时域压缩

减速播放:
- 缓冲区过小时
- 重复部分帧
- 时域扩展
```

---

## 4. NACK 重传机制

### 4.1 NACK 概述

NACK (Negative Acknowledgement) 用于请求重传丢失的包。

```
发送端                                    接收端
   |                                         |
   |  RTP Seq=100                            |
   | ------> ------> ------> ------> ------> |
   |                                         |
   |  RTP Seq=101 (丢失)                     |
   | ------> ----X                           |
   |                                         |
   |  RTP Seq=102                            |
   | ------> ------> ------> ------> ------> |
   |                                         |
   |                    检测到 101 丢失      |
   |                                         |
   |  NACK (请求 Seq=101)                    |
   | <------ <------ <------ <------ <------ |
   |                                         |
   |  重传 RTP Seq=101                       |
   | ------> ------> ------> ------> ------> |
   |                                         |
```

### 4.2 NACK 包格式

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|V=2|P|  FMT=1  |   PT=205      |             length            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                  SSRC of packet sender                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                  SSRC of media source                         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|            PID                |             BLP               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

PID: 丢失的第一个包序列号
BLP: 位图,表示 PID+1 到 PID+16 的丢包情况
     bit 0 = PID+1, bit 1 = PID+2, ...
```

### 4.3 NACK 实现

```javascript
class NackManager {
    constructor(options = {}) {
        this.maxRetries = options.maxRetries || 3;
        this.retryInterval = options.retryInterval || 50; // ms
        this.maxAge = options.maxAge || 500; // ms
        this.pendingNacks = new Map(); // seq -> {retries, lastSent}
        this.receivedSeqs = new Set();
        this.highestSeq = -1;
    }
    
    // 收到 RTP 包时调用
    onRtpReceived(seq) {
        this.receivedSeqs.add(seq);
        
        // 从待重传列表移除
        this.pendingNacks.delete(seq);
        
        // 检测丢包
        if (this.highestSeq >= 0) {
            const missing = this.findMissingSeqs(seq);
            for (const missSeq of missing) {
                if (!this.pendingNacks.has(missSeq)) {
                    this.pendingNacks.set(missSeq, {
                        retries: 0,
                        lastSent: 0,
                        detectedAt: Date.now()
                    });
                }
            }
        }
        
        if (this.seqGreater(seq, this.highestSeq)) {
            this.highestSeq = seq;
        }
    }
    
    // 查找丢失的序列号
    findMissingSeqs(newSeq) {
        const missing = [];
        let seq = (this.highestSeq + 1) % 65536;
        
        while (seq !== newSeq) {
            if (!this.receivedSeqs.has(seq)) {
                missing.push(seq);
            }
            seq = (seq + 1) % 65536;
        }
        
        return missing;
    }
    
    // 获取需要发送的 NACK
    getNacksToSend() {
        const now = Date.now();
        const nacksToSend = [];
        
        for (const [seq, info] of this.pendingNacks) {
            // 检查是否过期
            if (now - info.detectedAt > this.maxAge) {
                this.pendingNacks.delete(seq);
                continue;
            }
            
            // 检查重试次数
            if (info.retries >= this.maxRetries) {
                this.pendingNacks.delete(seq);
                continue;
            }
            
            // 检查重试间隔
            if (now - info.lastSent >= this.retryInterval) {
                nacksToSend.push(seq);
                info.retries++;
                info.lastSent = now;
            }
        }
        
        return nacksToSend;
    }
    
    // 构建 NACK 包
    buildNackPacket(seqs, senderSsrc, mediaSsrc) {
        if (seqs.length === 0) return null;
        
        // 按序列号排序
        seqs.sort((a, b) => this.seqDiff(a, b));
        
        const nackItems = [];
        let i = 0;
        
        while (i < seqs.length) {
            const pid = seqs[i];
            let blp = 0;
            
            // 构建位图
            for (let j = 1; j <= 16 && i + j < seqs.length; j++) {
                const nextSeq = (pid + j) % 65536;
                if (seqs.includes(nextSeq)) {
                    blp |= (1 << (j - 1));
                }
            }
            
            nackItems.push({ pid, blp });
            
            // 跳过已包含在位图中的序列号
            i++;
            while (i < seqs.length && 
                   this.seqDiff(seqs[i], pid) <= 16) {
                i++;
            }
        }
        
        return { senderSsrc, mediaSsrc, items: nackItems };
    }
    
    seqGreater(a, b) {
        return this.seqDiff(a, b) > 0;
    }
    
    seqDiff(a, b) {
        let diff = a - b;
        if (diff > 32768) diff -= 65536;
        if (diff < -32768) diff += 65536;
        return diff;
    }
}
```

### 4.4 发送端重传处理

```javascript
class RtpSender {
    constructor() {
        this.packetHistory = new Map(); // seq -> packet
        this.historySize = 1000;
    }
    
    // 发送 RTP 包时保存
    send(packet) {
        this.packetHistory.set(packet.seq, {
            packet: packet,
            sentAt: Date.now()
        });
        
        // 清理旧包
        this.cleanupHistory();
        
        // 实际发送
        this.transport.send(packet);
    }
    
    // 处理 NACK 请求
    onNackReceived(nack) {
        for (const item of nack.items) {
            // 重传 PID
            this.retransmit(item.pid);
            
            // 重传位图中的包
            for (let i = 0; i < 16; i++) {
                if (item.blp & (1 << i)) {
                    this.retransmit((item.pid + i + 1) % 65536);
                }
            }
        }
    }
    
    retransmit(seq) {
        const entry = this.packetHistory.get(seq);
        if (entry) {
            // 重传包
            this.transport.send(entry.packet);
        }
    }
    
    cleanupHistory() {
        if (this.packetHistory.size > this.historySize) {
            // 删除最旧的包
            const oldest = this.packetHistory.keys().next().value;
            this.packetHistory.delete(oldest);
        }
    }
}
```

---

## 5. PLI 与 FIR

### 5.1 PLI (Picture Loss Indication)

PLI 用于请求发送关键帧。

```
使用场景:
1. 检测到关键帧丢失
2. 解码错误
3. 新参与者加入

PLI 包格式:
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|V=2|P|  FMT=1  |   PT=206      |             length=2          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                  SSRC of packet sender                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                  SSRC of media source                         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 5.2 FIR (Full Intra Request)

FIR 是强制性的关键帧请求。

```
FIR vs PLI:
- PLI: 提示性请求,发送者可以忽略
- FIR: 强制请求,发送者必须响应

FIR 包格式:
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|V=2|P|  FMT=4  |   PT=206      |             length            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                  SSRC of packet sender                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                  SSRC of media source                         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                              SSRC                             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Seq nr.       |    Reserved                                   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 5.3 关键帧请求策略

```javascript
class KeyframeRequester {
    constructor() {
        this.lastRequestTime = 0;
        this.minInterval = 1000; // 最小请求间隔 1 秒
        this.pendingRequest = false;
    }
    
    // 检测到需要关键帧
    onKeyframeNeeded(reason) {
        const now = Date.now();
        
        // 限制请求频率
        if (now - this.lastRequestTime < this.minInterval) {
            this.pendingRequest = true;
            return;
        }
        
        this.sendPLI();
        this.lastRequestTime = now;
        this.pendingRequest = false;
    }
    
    // 定期检查待处理请求
    tick() {
        if (this.pendingRequest) {
            const now = Date.now();
            if (now - this.lastRequestTime >= this.minInterval) {
                this.sendPLI();
                this.lastRequestTime = now;
                this.pendingRequest = false;
            }
        }
    }
    
    sendPLI() {
        // 构建并发送 PLI 包
        const pli = this.buildPLI();
        this.transport.send(pli);
    }
}
```

---

## 6. FEC 前向纠错

### 6.1 FEC 概述

FEC (Forward Error Correction) 通过发送冗余数据来恢复丢失的包。

```
FEC 原理:

发送: P1, P2, P3, FEC(P1,P2,P3)

如果 P2 丢失:
接收: P1, __, P3, FEC

恢复: P2 = FEC XOR P1 XOR P3
```

### 6.2 WebRTC 中的 FEC

WebRTC 支持两种 FEC:

| 类型 | 说明 | 适用场景 |
|------|------|---------|
| ULP FEC | RFC 5109,基于 XOR | 视频 |
| Opus FEC | 内置于 Opus 编解码器 | 音频 |
| FlexFEC | 更灵活的 FEC | 新标准 |

### 6.3 ULP FEC 结构

```
ULP FEC 包结构:

 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|E|L|P|X|  CC   |M| PT recovery |        SN base                |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                          TS recovery                          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|        length recovery        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    Protection Length                          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                           mask                                |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                      FEC Level 0 Payload                      |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 6.4 FEC 实现示例

```javascript
class SimpleFEC {
    constructor(options = {}) {
        this.groupSize = options.groupSize || 4; // 每 4 个包生成 1 个 FEC
        this.buffer = [];
    }
    
    // 添加包并可能生成 FEC
    addPacket(packet) {
        this.buffer.push(packet);
        
        if (this.buffer.length >= this.groupSize) {
            const fecPacket = this.generateFEC(this.buffer);
            this.buffer = [];
            return fecPacket;
        }
        
        return null;
    }
    
    // 生成 FEC 包
    generateFEC(packets) {
        // 找到最大长度
        const maxLen = Math.max(...packets.map(p => p.payload.length));
        
        // XOR 所有负载
        const fecPayload = Buffer.alloc(maxLen);
        for (const packet of packets) {
            for (let i = 0; i < packet.payload.length; i++) {
                fecPayload[i] ^= packet.payload[i];
            }
        }
        
        // XOR 头部信息
        let seqRecovery = 0;
        let tsRecovery = 0;
        let ptRecovery = 0;
        
        for (const packet of packets) {
            seqRecovery ^= packet.seq;
            tsRecovery ^= packet.timestamp;
            ptRecovery ^= packet.payloadType;
        }
        
        return {
            type: 'fec',
            snBase: packets[0].seq,
            mask: (1 << this.groupSize) - 1, // 覆盖所有包
            seqRecovery,
            tsRecovery,
            ptRecovery,
            payload: fecPayload
        };
    }
    
    // 使用 FEC 恢复丢失的包
    recover(receivedPackets, fecPacket) {
        // 检查是否只丢失一个包
        const received = new Set(receivedPackets.map(p => p.seq));
        const missing = [];
        
        for (let i = 0; i < this.groupSize; i++) {
            const seq = (fecPacket.snBase + i) % 65536;
            if (!received.has(seq)) {
                missing.push(seq);
            }
        }
        
        if (missing.length !== 1) {
            // 无法恢复 (丢失多个包)
            return null;
        }
        
        const missingSeq = missing[0];
        
        // XOR 恢复
        let recoveredPayload = Buffer.from(fecPacket.payload);
        let recoveredSeq = fecPacket.seqRecovery;
        let recoveredTs = fecPacket.tsRecovery;
        let recoveredPt = fecPacket.ptRecovery;
        
        for (const packet of receivedPackets) {
            for (let i = 0; i < packet.payload.length; i++) {
                recoveredPayload[i] ^= packet.payload[i];
            }
            recoveredSeq ^= packet.seq;
            recoveredTs ^= packet.timestamp;
            recoveredPt ^= packet.payloadType;
        }
        
        return {
            seq: recoveredSeq,
            timestamp: recoveredTs,
            payloadType: recoveredPt,
            payload: recoveredPayload
        };
    }
}
```

### 6.5 FEC 开销与效果

```
FEC 开销计算:

groupSize = 4 时:
每 4 个媒体包 + 1 个 FEC 包
开销 = 1/4 = 25%

groupSize = 10 时:
每 10 个媒体包 + 1 个 FEC 包
开销 = 1/10 = 10%

恢复能力:
- 简单 XOR FEC: 每组只能恢复 1 个丢包
- Reed-Solomon: 可以恢复多个丢包
```

---

## 7. 延迟与丢包优化

### 7.1 延迟优化策略

```
降低延迟的方法:

1. 减小 Jitter Buffer
   - 根据网络状况动态调整
   - 接受一定的欠载风险

2. 减少编码延迟
   - 使用低延迟编码模式
   - 减小 GOP 大小

3. 优化 NACK 策略
   - 快速检测丢包
   - 限制重传次数

4. 使用 FEC 替代重传
   - 不需要等待 RTT
   - 适合高丢包场景
```

### 7.2 丢包优化策略

```
处理丢包的方法:

1. NACK 重传
   - 适合 RTT < 100ms
   - 适合偶发丢包

2. FEC 前向纠错
   - 适合 RTT > 100ms
   - 适合持续丢包

3. 丢包隐藏 (PLC)
   - 音频: 重复/插值
   - 视频: 帧复制/运动补偿

4. 关键帧请求
   - 严重丢包时
   - 快速恢复
```

### 7.3 综合策略

```javascript
class NetworkAdaptation {
    constructor() {
        this.rtt = 100;
        this.lossRate = 0;
        this.jitter = 0;
    }
    
    updateStats(stats) {
        this.rtt = stats.rtt;
        this.lossRate = stats.lossRate;
        this.jitter = stats.jitter;
    }
    
    getStrategy() {
        const strategy = {
            useNack: true,
            useFec: false,
            fecRate: 0,
            jitterBufferMs: 100
        };
        
        // 根据 RTT 决定是否使用 NACK
        if (this.rtt > 150) {
            strategy.useNack = false;
            strategy.useFec = true;
        }
        
        // 根据丢包率决定 FEC 强度
        if (this.lossRate > 0.05) {
            strategy.useFec = true;
            strategy.fecRate = Math.min(0.5, this.lossRate * 2);
        }
        
        // 根据抖动决定缓冲区大小
        strategy.jitterBufferMs = Math.max(50, 
            this.jitter * 2 + this.rtt / 2);
        
        return strategy;
    }
}
```

---

## 8. 总结

### 8.1 核心要点

| 机制 | 作用 | 适用场景 |
|------|------|---------|
| Jitter Buffer | 吸收抖动 | 所有场景 |
| NACK | 请求重传 | 低 RTT |
| PLI/FIR | 请求关键帧 | 严重丢包 |
| FEC | 前向纠错 | 高 RTT/高丢包 |

### 8.2 权衡关系

```
延迟 <---> 质量

低延迟:
- 小 Jitter Buffer
- 少重传
- 可能有卡顿

高质量:
- 大 Jitter Buffer
- 充分重传
- 延迟较高
```

### 8.3 下一篇预告

在下一篇文章中,我们将深入探讨带宽估计 (BWE) 算法。

---

## 参考资料

1. [RFC 4585 - Extended RTP Profile for RTCP-Based Feedback](https://datatracker.ietf.org/doc/html/rfc4585)
2. [RFC 5109 - RTP Payload Format for Generic FEC](https://datatracker.ietf.org/doc/html/rfc5109)
3. [WebRTC NetEQ](https://webrtc.googlesource.com/src/+/refs/heads/main/modules/audio_coding/neteq/)

---

> 作者: WebRTC 技术专栏  
> 系列: 媒体传输深入讲解 (4/6)  
> 上一篇: [SRTP: 安全加密传输层](./14-srtp-dtls.md)  
> 下一篇: [带宽估计 BWE](./16-bandwidth-estimation.md)
