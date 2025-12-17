---
title: "RTCP: 统计、同步与网络自适应"
description: "1. [RTCP 概述](#1-rtcp-概述)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 13
---

> 本文是 WebRTC 系列专栏的第十三篇,将深入剖析 RTCP 协议的工作原理,包括 Sender/Receiver Report、网络质量反馈以及音视频同步机制。

---

## 目录

1. [RTCP 概述](#1-rtcp-概述)
2. [RTCP 包类型](#2-rtcp-包类型)
3. [Sender Report (SR)](#3-sender-report-sr)
4. [Receiver Report (RR)](#4-receiver-report-rr)
5. [丢包、带宽与延迟分析](#5-丢包带宽与延迟分析)
6. [音视频同步 (Lip-Sync)](#6-音视频同步-lip-sync)
7. [RTCP 反馈消息](#7-rtcp-反馈消息)
8. [总结](#8-总结)

---

## 1. RTCP 概述

### 1.1 什么是 RTCP

RTCP (RTP Control Protocol) 是 RTP 的伴随协议,定义在 RFC 3550 中。RTCP 提供了带外控制信息,用于:

- 传输统计信息(丢包率、延迟、抖动)
- 同步多个媒体流
- 标识参与者
- 控制 RTP 会话

### 1.2 RTCP 与 RTP 的关系

```
+-------------------------------------------------------------------+
|                        RTP 会话                                    |
+-------------------------------------------------------------------+
|                                                                   |
|   RTP 流 (媒体数据)                                                |
|   +-------+-------+-------+-------+-------+-------+               |
|   | Pkt 1 | Pkt 2 | Pkt 3 | Pkt 4 | Pkt 5 | Pkt 6 | ...           |
|   +-------+-------+-------+-------+-------+-------+               |
|                                                                   |
|   RTCP 流 (控制数据)                                               |
|   +--------+        +--------+        +--------+                  |
|   |   SR   |        |   RR   |        |   SR   | ...              |
|   +--------+        +--------+        +--------+                  |
|                                                                   |
|   特点:                                                           |
|   - RTP 和 RTCP 使用相邻端口 (RTP=偶数, RTCP=奇数)                 |
|   - WebRTC 使用 RTCP-mux,复用同一端口                             |
|   - RTCP 带宽通常限制在总带宽的 5%                                 |
|                                                                   |
+-------------------------------------------------------------------+
```

### 1.3 RTCP 发送间隔

```
RTCP 发送间隔计算:

基本原则:
- RTCP 带宽 = 总带宽 * 5%
- 最小间隔 = 5 秒 (可配置)
- 发送者占 25%,接收者占 75%

计算公式:
interval = max(min_interval, (avg_rtcp_size * 8 * n) / rtcp_bw)

其中:
- avg_rtcp_size: 平均 RTCP 包大小
- n: 参与者数量
- rtcp_bw: RTCP 带宽

WebRTC 优化:
- 使用 Reduced-Size RTCP
- 更频繁的反馈 (约 100ms)
```

---

## 2. RTCP 包类型

### 2.1 标准 RTCP 包类型

| 类型 | 值 | 名称 | 说明 |
|------|-----|------|------|
| SR | 200 | Sender Report | 发送者报告 |
| RR | 201 | Receiver Report | 接收者报告 |
| SDES | 202 | Source Description | 源描述 |
| BYE | 203 | Goodbye | 离开通知 |
| APP | 204 | Application-defined | 应用自定义 |

### 2.2 扩展 RTCP 包类型

| 类型 | 值 | 名称 | 说明 |
|------|-----|------|------|
| RTPFB | 205 | Transport Layer FB | 传输层反馈 |
| PSFB | 206 | Payload-specific FB | 负载特定反馈 |
| XR | 207 | Extended Report | 扩展报告 |

### 2.3 RTCP 包通用头部

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|V=2|P|    RC   |   PT=SR=200   |             length            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

V: 版本 (2)
P: 填充标志
RC: 报告计数 (或子类型)
PT: 包类型
length: 长度 (32位字为单位,不含头部)
```

### 2.4 复合 RTCP 包

```
RTCP 包通常组合发送:

+------------------+------------------+------------------+
|       SR         |      SDES        |      RR          |
+------------------+------------------+------------------+

规则:
1. 第一个包必须是 SR 或 RR
2. 必须包含 SDES (至少 CNAME)
3. 可以包含其他类型
```

---

## 3. Sender Report (SR)

### 3.1 SR 包结构

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|V=2|P|    RC   |   PT=SR=200   |             length            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         SSRC of sender                        |
+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
|              NTP timestamp, most significant word             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|             NTP timestamp, least significant word             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         RTP timestamp                         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     sender's packet count                     |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                      sender's octet count                     |
+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
|                      Report Block(s)...                       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 3.2 SR 字段说明

| 字段 | 大小 | 说明 |
|------|------|------|
| SSRC | 32 bits | 发送者的 SSRC |
| NTP timestamp | 64 bits | NTP 时间戳 (绝对时间) |
| RTP timestamp | 32 bits | 对应的 RTP 时间戳 |
| Packet count | 32 bits | 已发送的 RTP 包数量 |
| Octet count | 32 bits | 已发送的负载字节数 |

### 3.3 NTP 时间戳

```
NTP 时间戳格式:

 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         Seconds                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         Fraction                              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

Seconds: 自 1900-01-01 00:00:00 的秒数
Fraction: 秒的小数部分 (2^32 分之一秒)

转换公式:
ntp_time = (seconds << 32) + fraction
unix_time = ntp_time - 2208988800 (1900到1970的秒数)
```

### 3.4 NTP 与 RTP 时间戳的关系

```
SR 提供了 NTP 和 RTP 时间戳的对应关系:

时间线:
NTP:  |-------|-------|-------|-------|
      T1      T2      T3      T4
      
RTP:  |-------|-------|-------|-------|
      R1      R2      R3      R4

SR 报告:
SR1: NTP=T1, RTP=R1
SR2: NTP=T3, RTP=R3

用途:
1. 计算 RTP 时间戳对应的绝对时间
2. 音视频同步
3. 延迟测量
```

---

## 4. Receiver Report (RR)

### 4.1 RR 包结构

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|V=2|P|    RC   |   PT=RR=201   |             length            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     SSRC of packet sender                     |
+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
|                         Report Block(s)                       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 4.2 Report Block 结构

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                 SSRC_1 (SSRC of first source)                 |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| fraction lost |       cumulative number of packets lost       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|           extended highest sequence number received           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                      interarrival jitter                      |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         last SR (LSR)                         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                   delay since last SR (DLSR)                  |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 4.3 Report Block 字段说明

| 字段 | 大小 | 说明 |
|------|------|------|
| SSRC | 32 bits | 被报告的源 SSRC |
| Fraction lost | 8 bits | 自上次报告以来的丢包率 |
| Cumulative lost | 24 bits | 累计丢包数 |
| Extended highest seq | 32 bits | 收到的最高序列号 |
| Jitter | 32 bits | 到达间隔抖动 |
| LSR | 32 bits | 最后收到的 SR 时间戳 |
| DLSR | 32 bits | 收到 SR 后的延迟 |

### 4.4 丢包率计算

```
Fraction Lost 计算:

fraction_lost = (lost_interval * 256) / expected_interval

其中:
expected_interval = ext_max_seq - last_ext_max_seq
received_interval = received - last_received
lost_interval = expected_interval - received_interval

示例:
上次报告: ext_max_seq=1000, received=980
本次报告: ext_max_seq=1100, received=1070

expected_interval = 1100 - 1000 = 100
received_interval = 1070 - 980 = 90
lost_interval = 100 - 90 = 10

fraction_lost = (10 * 256) / 100 = 25 (约 10% 丢包)
```

### 4.5 抖动计算

```
Interarrival Jitter 计算:

对于每个收到的包 i:
D(i,j) = (Rj - Ri) - (Sj - Si)

其中:
Ri, Rj: 包 i 和 j 的到达时间
Si, Sj: 包 i 和 j 的 RTP 时间戳

抖动更新:
J(i) = J(i-1) + (|D(i-1,i)| - J(i-1)) / 16

这是一个指数加权移动平均,权重为 1/16
```

```javascript
// 抖动计算示例
class JitterCalculator {
    constructor(clockRate) {
        this.clockRate = clockRate;
        this.jitter = 0;
        this.lastRtpTimestamp = null;
        this.lastArrivalTime = null;
    }
    
    update(rtpTimestamp, arrivalTimeMs) {
        if (this.lastRtpTimestamp !== null) {
            // 转换到相同单位 (RTP 时间戳单位)
            const arrivalDiff = (arrivalTimeMs - this.lastArrivalTime) 
                              * this.clockRate / 1000;
            const rtpDiff = rtpTimestamp - this.lastRtpTimestamp;
            
            // 计算 D
            const d = Math.abs(arrivalDiff - rtpDiff);
            
            // 更新抖动 (指数加权)
            this.jitter = this.jitter + (d - this.jitter) / 16;
        }
        
        this.lastRtpTimestamp = rtpTimestamp;
        this.lastArrivalTime = arrivalTimeMs;
        
        return this.jitter;
    }
    
    getJitterMs() {
        return (this.jitter / this.clockRate) * 1000;
    }
}
```

---

## 5. 丢包、带宽与延迟分析

### 5.1 丢包分析

```
丢包类型:

1. 随机丢包
   - 网络拥塞
   - 无线信号差
   
2. 突发丢包
   - 路由切换
   - 缓冲区溢出
   
3. 周期性丢包
   - 带宽竞争
   - QoS 策略

丢包影响:
- 音频: 卡顿、杂音
- 视频: 马赛克、花屏
- 关键帧丢失: 长时间花屏
```

### 5.2 从 RTCP 提取丢包信息

```javascript
// 解析 Receiver Report
function parseReceiverReport(data) {
    const reports = [];
    let offset = 8; // 跳过头部
    const rc = data[0] & 0x1F; // 报告数量
    
    for (let i = 0; i < rc; i++) {
        const report = {
            ssrc: data.readUInt32BE(offset),
            fractionLost: data[offset + 4],
            packetsLost: (data[offset + 5] << 16) | 
                        (data[offset + 6] << 8) | 
                        data[offset + 7],
            highestSeq: data.readUInt32BE(offset + 8),
            jitter: data.readUInt32BE(offset + 12),
            lsr: data.readUInt32BE(offset + 16),
            dlsr: data.readUInt32BE(offset + 20)
        };
        
        // 计算丢包率百分比
        report.lossRate = (report.fractionLost / 256) * 100;
        
        reports.push(report);
        offset += 24;
    }
    
    return reports;
}
```

### 5.3 RTT 计算

```
RTT (Round-Trip Time) 计算:

使用 SR/RR 中的 LSR 和 DLSR:

发送者                                    接收者
   |                                         |
   |  SR (NTP=T1)                            |
   | --------------------------------------> |
   |                                         |
   |                                         | 处理延迟
   |                                         |
   |  RR (LSR=T1, DLSR=D)                    |
   | <-------------------------------------- |
   |                                         |
   |  收到 RR 时间 = T2                       |
   |                                         |

RTT = T2 - LSR - DLSR

注意:
- LSR 是 NTP 时间戳的中间 32 位
- DLSR 单位是 1/65536 秒
```

```javascript
// RTT 计算示例
function calculateRTT(receivedTime, lsr, dlsr) {
    // 将当前时间转换为 NTP 中间 32 位格式
    const now = getNtpMiddle32(receivedTime);
    
    // DLSR 单位是 1/65536 秒
    const dlsrSeconds = dlsr / 65536;
    
    // LSR 是 NTP 中间 32 位
    const lsrSeconds = lsr / 65536;
    const nowSeconds = now / 65536;
    
    // 计算 RTT
    const rtt = nowSeconds - lsrSeconds - dlsrSeconds;
    
    return rtt * 1000; // 返回毫秒
}

function getNtpMiddle32(unixTimeMs) {
    // Unix 时间转 NTP
    const ntpSeconds = unixTimeMs / 1000 + 2208988800;
    const fraction = (unixTimeMs % 1000) / 1000 * 0x10000;
    
    // 取中间 32 位
    return ((ntpSeconds & 0xFFFF) << 16) | (fraction & 0xFFFF);
}
```

### 5.4 带宽估计

```
基于 RTCP 的带宽估计:

1. 从 SR 获取发送速率
   send_rate = (octet_count_diff * 8) / time_diff

2. 从 RR 获取丢包率
   loss_rate = fraction_lost / 256

3. 调整发送码率
   if (loss_rate > threshold) {
       reduce_bitrate();
   } else if (loss_rate < threshold && rtt < limit) {
       increase_bitrate();
   }

WebRTC 使用更复杂的算法:
- Google Congestion Control (GCC)
- 基于延迟的带宽估计
- Transport-wide CC
```

---

## 6. 音视频同步 (Lip-Sync)

### 6.1 同步问题

```
音视频不同步的原因:

1. 采集时间差
   - 音频和视频设备独立采集
   - 采集延迟不同

2. 编码时间差
   - 视频编码比音频慢
   - 关键帧编码更慢

3. 网络传输差异
   - 不同的丢包和延迟
   - 不同的抖动

4. 解码和渲染差异
   - 视频解码更复杂
   - 缓冲策略不同
```

### 6.2 同步机制

```
使用 RTCP SR 进行同步:

音频流:
SR: NTP=T1, RTP_audio=A1
    NTP=T2, RTP_audio=A2

视频流:
SR: NTP=T1', RTP_video=V1
    NTP=T2', RTP_video=V2

同步计算:
1. 从 SR 建立 NTP-RTP 映射
   audio: NTP = f(RTP_audio)
   video: NTP = g(RTP_video)

2. 将两个流的 RTP 时间戳转换为 NTP
   ntp_audio = f(rtp_audio)
   ntp_video = g(rtp_video)

3. 计算时间差
   diff = ntp_video - ntp_audio

4. 调整播放时间
   if (diff > 0) delay_video();
   else delay_audio();
```

### 6.3 同步实现

```javascript
class LipSync {
    constructor() {
        this.audioMapping = null; // {ntp, rtp, clockRate}
        this.videoMapping = null;
    }
    
    // 收到 SR 时更新映射
    updateSR(ssrc, ntpTimestamp, rtpTimestamp, isAudio) {
        const mapping = {
            ntp: ntpTimestamp,
            rtp: rtpTimestamp,
            clockRate: isAudio ? 48000 : 90000
        };
        
        if (isAudio) {
            this.audioMapping = mapping;
        } else {
            this.videoMapping = mapping;
        }
    }
    
    // 将 RTP 时间戳转换为 NTP
    rtpToNtp(rtpTimestamp, mapping) {
        if (!mapping) return null;
        
        const rtpDiff = rtpTimestamp - mapping.rtp;
        const ntpDiff = rtpDiff / mapping.clockRate;
        
        return mapping.ntp + ntpDiff;
    }
    
    // 计算音视频偏移
    calculateOffset(audioRtp, videoRtp) {
        if (!this.audioMapping || !this.videoMapping) {
            return 0;
        }
        
        const audioNtp = this.rtpToNtp(audioRtp, this.audioMapping);
        const videoNtp = this.rtpToNtp(videoRtp, this.videoMapping);
        
        if (!audioNtp || !videoNtp) return 0;
        
        // 返回偏移量 (秒)
        // 正值表示视频超前,需要延迟视频
        // 负值表示音频超前,需要延迟音频
        return videoNtp - audioNtp;
    }
    
    // 获取播放延迟调整
    getPlayoutDelay(audioRtp, videoRtp) {
        const offset = this.calculateOffset(audioRtp, videoRtp);
        
        return {
            audioDelay: offset < 0 ? -offset * 1000 : 0,
            videoDelay: offset > 0 ? offset * 1000 : 0
        };
    }
}
```

### 6.4 CNAME 的作用

```
CNAME (Canonical Name) 用于关联同一参与者的多个流:

SDES 包中的 CNAME:
+------------------+
| SSRC = 1001      |  音频流
| CNAME = "user@x" |
+------------------+

+------------------+
| SSRC = 2002      |  视频流
| CNAME = "user@x" |
+------------------+

同步流程:
1. 收到 RTP 包,记录 SSRC
2. 收到 SDES,获取 CNAME
3. 根据 CNAME 关联音视频流
4. 使用 SR 进行同步
```

---

## 7. RTCP 反馈消息

### 7.1 RTCP-FB 类型

```
传输层反馈 (RTPFB, PT=205):
+------+------+----------------------------------+
| FMT  | 名称 | 说明                             |
+------+------+----------------------------------+
| 1    | NACK | 丢包重传请求                     |
| 3    | TMMBR| 临时最大媒体码率请求             |
| 4    | TMMBN| 临时最大媒体码率通知             |
| 15   | TCC  | Transport-wide CC                |
+------+------+----------------------------------+

负载特定反馈 (PSFB, PT=206):
+------+------+----------------------------------+
| FMT  | 名称 | 说明                             |
+------+------+----------------------------------+
| 1    | PLI  | Picture Loss Indication          |
| 2    | SLI  | Slice Loss Indication            |
| 3    | RPSI | Reference Picture Selection      |
| 4    | FIR  | Full Intra Request               |
| 15   | AFB  | Application Layer FB             |
+------+------+----------------------------------+
```

### 7.2 NACK (Negative Acknowledgement)

```
NACK 用于请求重传丢失的包:

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

PID: 丢失的包序列号
BLP: 位图,表示 PID+1 到 PID+16 的丢包情况

示例:
PID = 1000, BLP = 0x0005 (二进制: 0000000000000101)
表示丢失: 1000, 1001, 1003
```

### 7.3 PLI (Picture Loss Indication)

```
PLI 请求发送关键帧:

 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|V=2|P|  FMT=1  |   PT=206      |             length            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                  SSRC of packet sender                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                  SSRC of media source                         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

使用场景:
1. 检测到关键帧丢失
2. 新参与者加入
3. 解码错误
```

### 7.4 FIR (Full Intra Request)

```
FIR 强制请求关键帧:

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

FIR vs PLI:
- PLI: 提示性请求,发送者可以忽略
- FIR: 强制请求,发送者必须响应
```

### 7.5 REMB (Receiver Estimated Maximum Bitrate)

```
REMB 用于接收端带宽估计:

 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|V=2|P| FMT=15  |   PT=206      |             length            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                  SSRC of packet sender                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                  SSRC of media source                         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|  Unique identifier 'R' 'E' 'M' 'B'                            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|  Num SSRC     | BR Exp    |  BR Mantissa                      |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|   SSRC feedback                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

带宽计算:
bitrate = mantissa * 2^exp (bps)
```

### 7.6 Transport-wide CC

```
Transport-wide CC 提供更精确的拥塞控制:

特点:
1. 为每个 RTP 包分配传输序列号
2. 接收端报告每个包的到达时间
3. 发送端计算单向延迟变化
4. 更快速的带宽调整

RTP 扩展头:
+------------------+
| Transport Seq Nr |  16 bits
+------------------+

RTCP 反馈:
包含每个传输序列号的到达时间
```

---

## 8. 总结

### 8.1 RTCP 核心要点

| 要点 | 说明 |
|------|------|
| SR | 发送者统计和时间戳映射 |
| RR | 接收质量报告 |
| 丢包率 | fraction_lost / 256 |
| 抖动 | 指数加权移动平均 |
| RTT | T2 - LSR - DLSR |
| 同步 | 使用 NTP-RTP 映射 |

### 8.2 RTCP 反馈机制

```
丢包恢复:
NACK -> 重传丢失的包

关键帧请求:
PLI/FIR -> 发送新的关键帧

带宽调整:
REMB/TCC -> 调整发送码率
```

### 8.3 下一篇预告

在下一篇文章中,我们将深入探讨 SRTP 协议,包括:
- DTLS 握手过程
- SRTP 密钥导出
- 加密与解密流程

---

## 参考资料

1. [RFC 3550 - RTP: A Transport Protocol for Real-Time Applications](https://datatracker.ietf.org/doc/html/rfc3550)
2. [RFC 4585 - Extended RTP Profile for RTCP-Based Feedback](https://datatracker.ietf.org/doc/html/rfc4585)
3. [RFC 5104 - Codec Control Messages in AVPF](https://datatracker.ietf.org/doc/html/rfc5104)
4. [draft-alvestrand-rmcat-remb - REMB](https://datatracker.ietf.org/doc/html/draft-alvestrand-rmcat-remb)

---

> 作者: WebRTC 技术专栏  
> 系列: 媒体传输深入讲解 (2/6)  
> 上一篇: [RTP 协议与 Media Stream 结构解析](./12-rtp-protocol.md)  
> 下一篇: [SRTP: 安全加密传输层](./14-srtp-dtls.md)
