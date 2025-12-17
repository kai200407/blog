---
title: "带宽估计 BWE (WebRTC 的智能网络优化核心)"
description: "1. [带宽估计概述](#1-带宽估计概述)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 16
---

> 本文是 WebRTC 系列专栏的第十六篇,将深入剖析 WebRTC 的带宽估计算法,包括 Google Congestion Control (GCC) 的工作原理以及如何影响码率调节。

---

## 目录

1. [带宽估计概述](#1-带宽估计概述)
2. [Google BWE 算法框架](#2-google-bwe-算法框架)
3. [基于延迟的估计](#3-基于延迟的估计)
4. [基于丢包的估计](#4-基于丢包的估计)
5. [多路竞争处理](#5-多路竞争处理)
6. [码率调节](#6-码率调节)
7. [总结](#7-总结)

---

## 1. 带宽估计概述

### 1.1 为什么需要带宽估计

```
网络带宽动态变化:

时间 -->
带宽  |    ____
      |   /    \____
      |  /          \    ____
      | /            \__/    \
      |/                      \____
      +-------------------------------->

问题:
- 发送码率 > 可用带宽 -> 拥塞、丢包、延迟增加
- 发送码率 < 可用带宽 -> 浪费带宽、质量下降

目标:
- 实时估计可用带宽
- 动态调整发送码率
- 最大化质量,最小化延迟
```

### 1.2 带宽估计方法

| 方法 | 原理 | 优缺点 |
|------|------|--------|
| 基于丢包 | 丢包率高则降低码率 | 简单,但反应慢 |
| 基于延迟 | 延迟增加则降低码率 | 灵敏,但需要精确测量 |
| 基于 ACK | 根据确认计算吞吐量 | 准确,但需要反馈 |

### 1.3 WebRTC 的 BWE 演进

```
WebRTC BWE 发展历程:

2012: REMB (Receiver Estimated Maximum Bitrate)
      - 接收端估计
      - 基于到达时间

2017: Transport-wide CC (Send-side BWE)
      - 发送端估计
      - 更精确的反馈

2020: GCC v2
      - 改进的延迟估计
      - 更好的公平性
```

---

## 2. Google BWE 算法框架

### 2.1 整体架构

```
+-------------------------------------------------------------------+
|                      Google Congestion Control                     |
+-------------------------------------------------------------------+
|                                                                   |
|   发送端                                              接收端      |
|   +------------------+                    +------------------+    |
|   |   Pacer          |                    |  Arrival Filter  |    |
|   |   (发送调度)      |                    |  (到达时间过滤)   |    |
|   +--------+---------+                    +--------+---------+    |
|            |                                       |              |
|            v                                       v              |
|   +------------------+                    +------------------+    |
|   |   Rate Control   |<-------------------|  Delay Estimator |    |
|   |   (码率控制)      |    RTCP Feedback   |  (延迟估计)       |    |
|   +--------+---------+                    +------------------+    |
|            |                                       |              |
|            v                                       v              |
|   +------------------+                    +------------------+    |
|   |   Loss Control   |<-------------------|  Loss Detector   |    |
|   |   (丢包控制)      |                    |  (丢包检测)       |    |
|   +--------+---------+                    +------------------+    |
|            |                                                      |
|            v                                                      |
|   +------------------+                                            |
|   |   Encoder        |                                            |
|   |   (编码器)        |                                            |
|   +------------------+                                            |
|                                                                   |
+-------------------------------------------------------------------+
```

### 2.2 核心组件

| 组件 | 功能 |
|------|------|
| Delay Estimator | 估计单向延迟变化 |
| Loss Detector | 检测丢包率 |
| Rate Controller | 综合决策码率 |
| Pacer | 平滑发送数据 |

### 2.3 反馈机制

```
Transport-wide CC 反馈:

发送端:
- 为每个 RTP 包添加传输序列号
- 记录发送时间

接收端:
- 记录每个包的到达时间
- 定期发送 RTCP 反馈

反馈包内容:
+------------------+------------------+
| Transport Seq Nr | Arrival Time     |
+------------------+------------------+
| 1001             | 100.5 ms         |
| 1002             | 120.8 ms         |
| 1003             | 141.2 ms         |
| ...              | ...              |
+------------------+------------------+
```

---

## 3. 基于延迟的估计

### 3.1 延迟梯度

```
延迟梯度 (Delay Gradient):

发送间隔: S(i) = send_time(i) - send_time(i-1)
到达间隔: A(i) = arrival_time(i) - arrival_time(i-1)

延迟梯度: d(i) = A(i) - S(i)

解释:
d(i) > 0: 延迟增加,可能拥塞
d(i) = 0: 延迟稳定
d(i) < 0: 延迟减少,网络恢复
```

### 3.2 Trendline 滤波器

```
Trendline 滤波器用于平滑延迟梯度:

原理:
- 收集最近 N 个延迟梯度样本
- 使用线性回归计算趋势
- 趋势斜率表示拥塞程度

         延迟
          ^
          |     *
          |   *   *
          | *       *
          |*          *
          +-------------> 时间
          
          趋势线斜率 > 0: 拥塞
```

### 3.3 Trendline 实现

```javascript
class TrendlineEstimator {
    constructor(options = {}) {
        this.windowSize = options.windowSize || 20;
        this.samples = [];
        this.smoothingCoef = options.smoothingCoef || 0.9;
        this.threshold = options.threshold || 12.5;
    }
    
    // 添加延迟梯度样本
    update(sendDelta, arrivalDelta, sendTime) {
        const delayGradient = arrivalDelta - sendDelta;
        
        this.samples.push({
            time: sendTime,
            gradient: delayGradient,
            accumulatedDelay: this.getAccumulatedDelay() + delayGradient
        });
        
        // 保持窗口大小
        if (this.samples.length > this.windowSize) {
            this.samples.shift();
        }
        
        return this.computeTrend();
    }
    
    getAccumulatedDelay() {
        if (this.samples.length === 0) return 0;
        return this.samples[this.samples.length - 1].accumulatedDelay;
    }
    
    // 计算趋势斜率 (线性回归)
    computeTrend() {
        if (this.samples.length < 2) return 0;
        
        const n = this.samples.length;
        let sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
        
        for (let i = 0; i < n; i++) {
            const x = this.samples[i].time;
            const y = this.samples[i].accumulatedDelay;
            sumX += x;
            sumY += y;
            sumXY += x * y;
            sumX2 += x * x;
        }
        
        const slope = (n * sumXY - sumX * sumY) / 
                     (n * sumX2 - sumX * sumX);
        
        return slope;
    }
    
    // 获取网络状态
    getNetworkState() {
        const trend = this.computeTrend();
        
        if (trend > this.threshold) {
            return 'overuse';  // 过载
        } else if (trend < -this.threshold) {
            return 'underuse'; // 欠载
        } else {
            return 'normal';   // 正常
        }
    }
}
```

### 3.4 自适应阈值

```
自适应阈值调整:

问题:
- 固定阈值无法适应不同网络
- 需要根据网络状况动态调整

算法:
threshold = threshold + k * (|trend| - threshold)

其中:
- k_up = 0.0087 (增加阈值的速度)
- k_down = 0.039 (降低阈值的速度)

当 |trend| > threshold 时,增加阈值
当 |trend| < threshold 时,降低阈值
```

### 3.5 AIMD 码率控制

```
AIMD (Additive Increase Multiplicative Decrease):

状态机:
+----------+     overuse      +----------+
|          | ---------------> |          |
| Increase |                  | Decrease |
|          | <--------------- |          |
+----------+     underuse     +----------+
      ^                             |
      |         normal              |
      +-----------------------------+

码率调整:
- Increase: rate = rate * 1.08 (每秒)
- Decrease: rate = rate * 0.85 (立即)
- Hold: rate = rate (保持)
```

```javascript
class AimdRateControl {
    constructor(options = {}) {
        this.minBitrate = options.minBitrate || 100000;  // 100 kbps
        this.maxBitrate = options.maxBitrate || 5000000; // 5 Mbps
        this.currentBitrate = options.startBitrate || 300000;
        this.lastUpdateTime = Date.now();
        this.state = 'increase';
    }
    
    update(networkState, rtt) {
        const now = Date.now();
        const timeDelta = (now - this.lastUpdateTime) / 1000;
        this.lastUpdateTime = now;
        
        switch (networkState) {
            case 'overuse':
                // 乘性减少
                this.currentBitrate *= 0.85;
                this.state = 'decrease';
                break;
                
            case 'underuse':
                // 加性增加
                if (this.state !== 'decrease') {
                    const increase = this.currentBitrate * 0.08 * timeDelta;
                    this.currentBitrate += increase;
                }
                this.state = 'increase';
                break;
                
            case 'normal':
                if (this.state === 'increase') {
                    const increase = this.currentBitrate * 0.08 * timeDelta;
                    this.currentBitrate += increase;
                }
                break;
        }
        
        // 限制范围
        this.currentBitrate = Math.max(this.minBitrate,
            Math.min(this.maxBitrate, this.currentBitrate));
        
        return this.currentBitrate;
    }
    
    getBitrate() {
        return Math.floor(this.currentBitrate);
    }
}
```

---

## 4. 基于丢包的估计

### 4.1 丢包率计算

```
丢包率计算:

从 RTCP RR 获取:
- fraction_lost: 自上次报告以来的丢包率
- cumulative_lost: 累计丢包数

丢包率 = fraction_lost / 256

示例:
fraction_lost = 25
丢包率 = 25 / 256 = 9.8%
```

### 4.2 基于丢包的码率调整

```javascript
class LossBasedControl {
    constructor(options = {}) {
        this.lossThresholdLow = options.lossThresholdLow || 0.02;  // 2%
        this.lossThresholdHigh = options.lossThresholdHigh || 0.10; // 10%
        this.currentBitrate = options.startBitrate || 300000;
    }
    
    update(lossRate) {
        if (lossRate > this.lossThresholdHigh) {
            // 高丢包,大幅降低码率
            this.currentBitrate *= (1 - 0.5 * lossRate);
        } else if (lossRate > this.lossThresholdLow) {
            // 中等丢包,适度降低码率
            this.currentBitrate *= (1 - lossRate);
        }
        // 低丢包时不主动增加码率,由延迟估计决定
        
        return this.currentBitrate;
    }
}
```

### 4.3 综合延迟和丢包

```
综合估计:

delay_based_estimate = AIMD 输出
loss_based_estimate = 丢包调整输出

最终估计 = min(delay_based_estimate, loss_based_estimate)

原因:
- 取较小值更保守
- 避免过度发送导致更多丢包
```

```javascript
class CombinedBweEstimator {
    constructor(options = {}) {
        this.delayEstimator = new TrendlineEstimator(options);
        this.rateControl = new AimdRateControl(options);
        this.lossControl = new LossBasedControl(options);
    }
    
    // 处理到达时间反馈
    onArrivalFeedback(packets) {
        for (let i = 1; i < packets.length; i++) {
            const sendDelta = packets[i].sendTime - packets[i-1].sendTime;
            const arrivalDelta = packets[i].arrivalTime - packets[i-1].arrivalTime;
            
            this.delayEstimator.update(sendDelta, arrivalDelta, packets[i].sendTime);
        }
        
        const networkState = this.delayEstimator.getNetworkState();
        const delayBasedRate = this.rateControl.update(networkState, 0);
        
        return delayBasedRate;
    }
    
    // 处理丢包反馈
    onLossFeedback(lossRate) {
        const lossBasedRate = this.lossControl.update(lossRate);
        return lossBasedRate;
    }
    
    // 获取最终估计
    getEstimate() {
        const delayBased = this.rateControl.getBitrate();
        const lossBased = this.lossControl.currentBitrate;
        
        return Math.min(delayBased, lossBased);
    }
}
```

---

## 5. 多路竞争处理

### 5.1 公平性问题

```
多路竞争场景:

链路容量: 10 Mbps

流 1: WebRTC 视频通话
流 2: TCP 下载
流 3: 另一个 WebRTC 通话

目标:
- 每个流公平分享带宽
- 不被 TCP 饿死
- 不饿死其他流
```

### 5.2 与 TCP 竞争

```
TCP 拥塞控制特点:
- 基于丢包
- AIMD 算法
- 填满缓冲区

WebRTC GCC 特点:
- 基于延迟
- 更早检测拥塞
- 可能让出带宽给 TCP

解决方案:
- 适当增加探测强度
- 使用 BBR 风格的探测
- 周期性带宽探测
```

### 5.3 探测机制

```javascript
class BandwidthProber {
    constructor(options = {}) {
        this.probeInterval = options.probeInterval || 5000; // 5 秒
        this.probeRatio = options.probeRatio || 1.5; // 探测 1.5 倍当前码率
        this.lastProbeTime = 0;
        this.isProbing = false;
    }
    
    shouldProbe(currentBitrate, estimatedBitrate) {
        const now = Date.now();
        
        // 定期探测
        if (now - this.lastProbeTime > this.probeInterval) {
            // 当前码率接近估计值时探测
            if (currentBitrate > estimatedBitrate * 0.9) {
                return true;
            }
        }
        
        return false;
    }
    
    startProbe(currentBitrate) {
        this.isProbing = true;
        this.lastProbeTime = Date.now();
        this.probeBitrate = currentBitrate * this.probeRatio;
        
        return this.probeBitrate;
    }
    
    endProbe(success) {
        this.isProbing = false;
        
        if (success) {
            // 探测成功,可以使用更高码率
            return this.probeBitrate;
        } else {
            // 探测失败,回退
            return null;
        }
    }
}
```

---

## 6. 码率调节

### 6.1 Pacer (发送调度器)

```
Pacer 作用:
- 平滑发送数据
- 避免突发流量
- 配合带宽估计

发送模式:
+--------+--------+--------+--------+
| Pkt 1  | Pkt 2  | Pkt 3  | Pkt 4  |
+--------+--------+--------+--------+
|<- 间隔 ->|<- 间隔 ->|<- 间隔 ->|

间隔 = packet_size / target_bitrate
```

```javascript
class Pacer {
    constructor(options = {}) {
        this.targetBitrate = options.targetBitrate || 300000;
        this.queue = [];
        this.lastSendTime = 0;
        this.budget = 0;
    }
    
    setTargetBitrate(bitrate) {
        this.targetBitrate = bitrate;
    }
    
    enqueue(packet) {
        this.queue.push({
            packet: packet,
            size: packet.length,
            enqueuedAt: Date.now()
        });
    }
    
    // 获取下一个要发送的包
    getNextPacket() {
        if (this.queue.length === 0) {
            return null;
        }
        
        const now = Date.now();
        const timeDelta = now - this.lastSendTime;
        
        // 更新发送预算 (字节)
        this.budget += (this.targetBitrate / 8) * (timeDelta / 1000);
        this.budget = Math.min(this.budget, this.targetBitrate / 8 * 0.5); // 最多积累 500ms
        
        const entry = this.queue[0];
        
        if (this.budget >= entry.size) {
            this.queue.shift();
            this.budget -= entry.size;
            this.lastSendTime = now;
            return entry.packet;
        }
        
        // 计算等待时间
        const waitTime = (entry.size - this.budget) / (this.targetBitrate / 8) * 1000;
        return { wait: waitTime };
    }
    
    getQueueSize() {
        return this.queue.reduce((sum, e) => sum + e.size, 0);
    }
}
```

### 6.2 编码器码率调整

```javascript
class EncoderController {
    constructor(options = {}) {
        this.encoder = options.encoder;
        this.minBitrate = options.minBitrate || 100000;
        this.maxBitrate = options.maxBitrate || 5000000;
        this.currentBitrate = options.startBitrate || 300000;
    }
    
    // 根据 BWE 调整编码器
    onBweUpdate(estimatedBitrate) {
        // 预留一些余量给 RTCP 和其他开销
        const targetBitrate = estimatedBitrate * 0.95;
        
        // 平滑调整,避免剧烈变化
        const diff = targetBitrate - this.currentBitrate;
        const adjustment = diff * 0.5; // 每次调整 50%
        
        this.currentBitrate += adjustment;
        this.currentBitrate = Math.max(this.minBitrate,
            Math.min(this.maxBitrate, this.currentBitrate));
        
        // 更新编码器
        this.encoder.setTargetBitrate(Math.floor(this.currentBitrate));
        
        return this.currentBitrate;
    }
    
    // 根据帧类型调整
    onFrameEncoded(frameInfo) {
        if (frameInfo.isKeyFrame) {
            // 关键帧后可能需要降低码率
            // 因为关键帧通常很大
        }
        
        // 检查编码器输出是否匹配目标
        const actualBitrate = frameInfo.size * 8 * frameInfo.fps;
        if (actualBitrate > this.currentBitrate * 1.2) {
            // 编码器输出过高,降低目标
            this.currentBitrate *= 0.9;
            this.encoder.setTargetBitrate(Math.floor(this.currentBitrate));
        }
    }
}
```

### 6.3 分辨率和帧率调整

```
质量降级策略:

1. 首先降低码率
2. 然后降低帧率 (30 -> 15 -> 10)
3. 最后降低分辨率 (720p -> 480p -> 360p)

恢复策略:
1. 首先恢复分辨率
2. 然后恢复帧率
3. 最后增加码率
```

```javascript
class QualityController {
    constructor() {
        this.resolutions = [
            { width: 1280, height: 720, minBitrate: 1500000 },
            { width: 640, height: 480, minBitrate: 500000 },
            { width: 320, height: 240, minBitrate: 150000 }
        ];
        this.frameRates = [30, 15, 10];
        this.currentResIndex = 0;
        this.currentFpsIndex = 0;
    }
    
    onBitrateChange(bitrate) {
        // 检查是否需要降级
        const currentRes = this.resolutions[this.currentResIndex];
        
        if (bitrate < currentRes.minBitrate) {
            // 需要降级
            if (this.currentFpsIndex < this.frameRates.length - 1) {
                // 先降帧率
                this.currentFpsIndex++;
            } else if (this.currentResIndex < this.resolutions.length - 1) {
                // 再降分辨率
                this.currentResIndex++;
                this.currentFpsIndex = 0;
            }
        } else if (bitrate > currentRes.minBitrate * 1.5) {
            // 可以升级
            if (this.currentFpsIndex > 0) {
                this.currentFpsIndex--;
            } else if (this.currentResIndex > 0) {
                // 检查更高分辨率的最低码率
                const higherRes = this.resolutions[this.currentResIndex - 1];
                if (bitrate > higherRes.minBitrate) {
                    this.currentResIndex--;
                    this.currentFpsIndex = this.frameRates.length - 1;
                }
            }
        }
        
        return {
            resolution: this.resolutions[this.currentResIndex],
            frameRate: this.frameRates[this.currentFpsIndex]
        };
    }
}
```

---

## 7. 总结

### 7.1 BWE 核心要点

| 组件 | 作用 |
|------|------|
| Trendline | 检测延迟趋势 |
| AIMD | 码率增减控制 |
| Loss Control | 丢包响应 |
| Pacer | 平滑发送 |
| Prober | 带宽探测 |

### 7.2 算法流程

```
1. 接收端记录到达时间
2. 发送 RTCP 反馈
3. 发送端计算延迟梯度
4. Trendline 滤波
5. 判断网络状态
6. AIMD 调整码率
7. 结合丢包调整
8. 更新编码器和 Pacer
```

### 7.3 调优建议

```
低延迟场景:
- 减小 Trendline 窗口
- 更激进的降码率
- 更快的探测频率

高质量场景:
- 增大 Trendline 窗口
- 更保守的降码率
- 更大的缓冲区
```

### 7.4 下一篇预告

在下一篇文章中,我们将探讨媒体流与轨道模型。

---

## 参考资料

1. [draft-ietf-rmcat-gcc - Google Congestion Control](https://datatracker.ietf.org/doc/html/draft-ietf-rmcat-gcc)
2. [WebRTC Congestion Control](https://webrtc.googlesource.com/src/+/refs/heads/main/modules/congestion_controller/)
3. [A Google Congestion Control Algorithm for Real-Time Communication](https://dl.acm.org/doi/10.1145/2910017.2910605)

---

> 作者: WebRTC 技术专栏  
> 系列: 媒体传输深入讲解 (5/6)  
> 上一篇: [抖动缓冲区与网络抗性](./15-jitter-buffer.md)  
> 下一篇: [媒体流与轨道模型](./17-media-track-model.md)
