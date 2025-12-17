---
title: "RTP 协议与 Media Stream 结构解析"
description: "1. [RTP 概述](#1-rtp-概述)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 12
---

> 本文是 WebRTC 系列专栏的第十二篇,也是第三部分"媒体传输深入讲解"的开篇。我们将深入剖析 RTP 协议的结构、关键字段的含义以及 RTP 包与媒体帧的关系。

---

## 目录

1. [RTP 概述](#1-rtp-概述)
2. [RTP 包结构](#2-rtp-包结构)
3. [RTP Header 详解](#3-rtp-header-详解)
4. [序号与时间戳](#4-序号与时间戳)
5. [SSRC 与 CSRC](#5-ssrc-与-csrc)
6. [RTP 与 Frame 的关系](#6-rtp-与-frame-的关系)
7. [RTP 扩展头](#7-rtp-扩展头)
8. [总结](#8-总结)

---

## 1. RTP 概述

### 1.1 什么是 RTP

RTP (Real-time Transport Protocol) 是一种用于在 IP 网络上传输实时数据(如音频和视频)的协议,定义在 RFC 3550 中。RTP 本身不保证数据的可靠传输或按序到达,而是提供了时间戳、序列号等机制,让接收端能够重建媒体流。

### 1.2 RTP 的设计目标

```
RTP 的核心设计目标:

1. 实时性优先
   - 允许丢包,不进行重传(由应用层决定)
   - 低延迟传输

2. 时间同步
   - 提供时间戳用于播放同步
   - 支持音视频同步(lip-sync)

3. 源标识
   - 每个媒体源有唯一标识(SSRC)
   - 支持混音场景(CSRC)

4. 负载类型标识
   - 标识编解码器类型
   - 支持动态负载类型协商
```

### 1.3 RTP 在 WebRTC 协议栈中的位置

```
+-------------------------------------------------------------------+
|                         应用层                                     |
|                    (音视频编解码数据)                               |
+-------------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------------+
|                          RTP                                       |
|              (打包、时间戳、序列号、源标识)                          |
+-------------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------------+
|                         SRTP                                       |
|                    (加密、完整性保护)                               |
+-------------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------------+
|                         DTLS                                       |
|                      (密钥交换)                                    |
+-------------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------------+
|                          ICE                                       |
|                      (NAT 穿透)                                    |
+-------------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------------+
|                        UDP/TCP                                     |
+-------------------------------------------------------------------+
```

---

## 2. RTP 包结构

### 2.1 RTP 包格式

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|V=2|P|X|  CC   |M|     PT      |       Sequence Number         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                           Timestamp                           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|           Synchronization Source (SSRC) identifier            |
+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
|            Contributing Source (CSRC) identifiers             |
|                             ....                              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    Header Extension (可选)                     |
|                             ....                              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                          Payload                              |
|                             ....                              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         Padding (可选)                         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 2.2 RTP 包组成部分

| 部分 | 大小 | 说明 |
|------|------|------|
| 固定头部 | 12 字节 | 必须存在 |
| CSRC 列表 | 0-60 字节 | 0-15 个 CSRC,每个 4 字节 |
| 扩展头部 | 可变 | 可选,由 X 位指示 |
| 负载 | 可变 | 实际媒体数据 |
| 填充 | 可变 | 可选,由 P 位指示 |

### 2.3 典型 RTP 包大小

```
音频 RTP 包 (Opus):
+------------------+------------------+------------------+
| RTP Header (12B) | Opus Payload     | 总计约 50-200B   |
|                  | (20-160B)        |                  |
+------------------+------------------+------------------+

视频 RTP 包 (VP8):
+------------------+------------------+------------------+
| RTP Header (12B) | VP8 Payload      | 总计约 1200B     |
|                  | (约 1188B)       | (MTU 限制)       |
+------------------+------------------+------------------+

注: 视频帧通常需要分割成多个 RTP 包
```

---

## 3. RTP Header 详解

### 3.1 固定头部字段

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|V=2|P|X|  CC   |M|     PT      |       Sequence Number         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                           Timestamp                           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|           Synchronization Source (SSRC) identifier            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 3.2 字段说明

| 字段 | 位数 | 说明 |
|------|------|------|
| V (Version) | 2 | RTP 版本,固定为 2 |
| P (Padding) | 1 | 是否有填充字节 |
| X (Extension) | 1 | 是否有扩展头部 |
| CC (CSRC Count) | 4 | CSRC 标识符数量 (0-15) |
| M (Marker) | 1 | 标记位,含义由负载类型定义 |
| PT (Payload Type) | 7 | 负载类型 (0-127) |
| Sequence Number | 16 | 序列号 |
| Timestamp | 32 | 时间戳 |
| SSRC | 32 | 同步源标识符 |

### 3.3 Version (V)

```
V = 2 (固定值)

历史版本:
- V=0: 最初的 vat 音频工具
- V=1: 第一版 RTP 草案
- V=2: 当前标准版本 (RFC 3550)
```

### 3.4 Padding (P)

```
当 P=1 时,包尾部有填充字节:

+------------------+------------------+------------------+
| RTP Header       | Payload          | Padding          |
|                  |                  | (最后一字节表示  |
|                  |                  |  填充长度)       |
+------------------+------------------+------------------+

填充用途:
- 满足加密算法的块大小要求
- 满足某些传输协议的对齐要求
```

### 3.5 Extension (X)

```
当 X=1 时,固定头部后有扩展头部:

+------------------+------------------+------------------+
| RTP Header (12B) | Extension Header | Payload          |
|                  | (至少 4 字节)    |                  |
+------------------+------------------+------------------+

扩展头部格式:
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|      defined by profile       |           length              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        header extension                       |
|                             ....                              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 3.6 Marker (M)

Marker 位的含义由负载类型定义:

| 媒体类型 | Marker 含义 |
|---------|-------------|
| 视频 | 帧的最后一个包 |
| 音频 | 静音后的第一个包 |
| 通用 | 应用自定义 |

```
视频帧分片示例:

帧 1 (3 个 RTP 包):
+--------+--------+--------+
| Pkt 1  | Pkt 2  | Pkt 3  |
| M=0    | M=0    | M=1    |  <-- 最后一个包 M=1
+--------+--------+--------+

帧 2 (2 个 RTP 包):
+--------+--------+
| Pkt 4  | Pkt 5  |
| M=0    | M=1    |  <-- 最后一个包 M=1
+--------+--------+
```

### 3.7 Payload Type (PT)

负载类型标识编解码器:

```
静态负载类型 (0-95):
+------+------------+--------+------------+
| PT   | 编码       | 类型   | 时钟频率   |
+------+------------+--------+------------+
| 0    | PCMU       | Audio  | 8000       |
| 3    | GSM        | Audio  | 8000       |
| 4    | G723       | Audio  | 8000       |
| 8    | PCMA       | Audio  | 8000       |
| 9    | G722       | Audio  | 8000       |
| 10   | L16 stereo | Audio  | 44100      |
| 11   | L16 mono   | Audio  | 44100      |
| 26   | JPEG       | Video  | 90000      |
| 31   | H261       | Video  | 90000      |
| 32   | MPV        | Video  | 90000      |
| 33   | MP2T       | AV     | 90000      |
| 34   | H263       | Video  | 90000      |
+------+------------+--------+------------+

动态负载类型 (96-127):
- 通过 SDP 协商
- WebRTC 常用:
  - 96-102: VP8, VP9, H264 等视频
  - 111: Opus 音频
```

---

## 4. 序号与时间戳

### 4.1 Sequence Number (序列号)

```
特性:
- 16 位无符号整数
- 初始值随机
- 每发送一个 RTP 包加 1
- 到达 65535 后回绕到 0

用途:
1. 检测丢包
2. 恢复包顺序
3. 计算丢包率

示例:
Seq: 1000 -> 1001 -> 1002 -> 1004 -> 1005
                             ^
                             包 1003 丢失
```

### 4.2 丢包检测

```javascript
// 丢包检测示例
let expectedSeq = null;
let lostPackets = 0;
let receivedPackets = 0;

function onRtpPacket(packet) {
    receivedPackets++;
    
    if (expectedSeq !== null) {
        // 计算序号差 (处理回绕)
        let diff = (packet.seq - expectedSeq + 65536) % 65536;
        
        if (diff > 1 && diff < 32768) {
            // 有丢包
            lostPackets += (diff - 1);
            console.log(`Lost ${diff - 1} packets`);
        }
    }
    
    expectedSeq = (packet.seq + 1) % 65536;
}

function getLossRate() {
    let total = receivedPackets + lostPackets;
    return total > 0 ? lostPackets / total : 0;
}
```

### 4.3 Timestamp (时间戳)

```
特性:
- 32 位无符号整数
- 初始值随机
- 按采样时钟递增
- 同一帧的所有包时间戳相同

时钟频率:
- 音频: 通常 8000 Hz, 16000 Hz, 48000 Hz
- 视频: 通常 90000 Hz

计算公式:
timestamp_increment = clock_rate / frame_rate

示例 (30fps 视频, 90000 Hz 时钟):
increment = 90000 / 30 = 3000

帧 1: timestamp = 1000
帧 2: timestamp = 4000
帧 3: timestamp = 7000
```

### 4.4 时间戳与帧的关系

```
视频 (30 fps, 90000 Hz):

帧 1 (分成 3 个 RTP 包):
+------------------+------------------+------------------+
| Seq=100          | Seq=101          | Seq=102          |
| TS=1000          | TS=1000          | TS=1000          |
| M=0              | M=0              | M=1              |
+------------------+------------------+------------------+
                   同一帧,时间戳相同

帧 2 (分成 2 个 RTP 包):
+------------------+------------------+
| Seq=103          | Seq=104          |
| TS=4000          | TS=4000          |
| M=0              | M=1              |
+------------------+------------------+
                   时间戳增加 3000


音频 (Opus, 48000 Hz, 20ms 帧):

帧 1:
+------------------+
| Seq=200          |
| TS=5000          |
+------------------+

帧 2:
+------------------+
| Seq=201          |
| TS=5960          |  (增加 48000 * 0.02 = 960)
+------------------+
```

### 4.5 时间戳回绕处理

```javascript
// 时间戳回绕处理
const MAX_TIMESTAMP = 0xFFFFFFFF;

function timestampDiff(ts1, ts2) {
    // 处理 32 位回绕
    let diff = ts1 - ts2;
    
    // 如果差值太大,说明发生了回绕
    if (diff > MAX_TIMESTAMP / 2) {
        diff -= MAX_TIMESTAMP + 1;
    } else if (diff < -MAX_TIMESTAMP / 2) {
        diff += MAX_TIMESTAMP + 1;
    }
    
    return diff;
}

// 将时间戳转换为毫秒
function timestampToMs(timestamp, clockRate) {
    return (timestamp / clockRate) * 1000;
}
```

---

## 5. SSRC 与 CSRC

### 5.1 SSRC (Synchronization Source)

```
SSRC 特性:
- 32 位随机数
- 标识 RTP 流的来源
- 同一会话中必须唯一
- 冲突时需要重新生成

用途:
1. 区分不同的媒体源
2. 关联 RTP 和 RTCP
3. 支持多流场景
```

### 5.2 SSRC 冲突处理

```
冲突场景:
两个参与者随机生成了相同的 SSRC

检测方法:
1. 收到来自不同源地址的相同 SSRC
2. 收到 RTCP BYE 后又收到相同 SSRC 的 RTP

处理流程:
1. 检测到冲突
2. 生成新的随机 SSRC
3. 发送 RTCP BYE (旧 SSRC)
4. 使用新 SSRC 继续发送
```

### 5.3 CSRC (Contributing Source)

```
CSRC 用于混音场景:

场景: MCU 混合多个音频源

参与者 A (SSRC=1001) ─┐
                      │
参与者 B (SSRC=1002) ─┼──> MCU ──> 混合后的 RTP
                      │           SSRC=9999
参与者 C (SSRC=1003) ─┘           CSRC=[1001,1002,1003]

混合后的 RTP 包:
+------------------+
| SSRC = 9999      |  MCU 的 SSRC
| CC = 3           |  3 个贡献源
| CSRC[0] = 1001   |  参与者 A
| CSRC[1] = 1002   |  参与者 B
| CSRC[2] = 1003   |  参与者 C
| Payload = 混合音频 |
+------------------+
```

### 5.4 WebRTC 中的 SSRC 使用

```javascript
// 获取发送器的 SSRC
const sender = pc.getSenders()[0];
const params = sender.getParameters();

params.encodings.forEach(encoding => {
    console.log('SSRC:', encoding.ssrc);
});

// 在 SDP 中查看 SSRC
// a=ssrc:1234567890 cname:user@example.com
// a=ssrc:1234567890 msid:stream_id track_id
```

---

## 6. RTP 与 Frame 的关系

### 6.1 帧分片 (Fragmentation)

```
为什么需要分片:
- MTU 限制 (通常 1500 字节)
- RTP 头部 + 负载不能超过 MTU
- 大的视频帧需要分成多个 RTP 包

分片示例 (VP8):

原始帧: 15000 字节

分片后:
+------------------+  RTP 包 1: 1200 字节负载
| RTP Header (12B) |
| VP8 Payload Desc |
| 帧数据 (部分)    |
+------------------+

+------------------+  RTP 包 2: 1200 字节负载
| RTP Header (12B) |
| VP8 Payload Desc |
| 帧数据 (部分)    |
+------------------+

... (共约 13 个包)

+------------------+  RTP 包 13: 最后部分, M=1
| RTP Header (12B) |
| VP8 Payload Desc |
| 帧数据 (剩余)    |
+------------------+
```

### 6.2 VP8 负载描述符

```
VP8 Payload Descriptor:

 0 1 2 3 4 5 6 7
+-+-+-+-+-+-+-+-+
|X|R|N|S|R| PID |
+-+-+-+-+-+-+-+-+
X: 扩展位
R: 保留
N: 非参考帧
S: 分区开始
PID: 分区 ID

扩展字节 (如果 X=1):
+-+-+-+-+-+-+-+-+
|I|L|T|K| RSV   |
+-+-+-+-+-+-+-+-+
I: PictureID 存在
L: TL0PICIDX 存在
T: TID 存在
K: KEYIDX 存在
```

### 6.3 H.264 负载格式

```
H.264 RTP 负载类型:

1. 单 NAL 单元模式 (类型 1-23)
   - 一个 RTP 包包含一个完整的 NAL 单元
   
2. STAP-A (类型 24)
   - 一个 RTP 包包含多个小的 NAL 单元
   
3. FU-A (类型 28)
   - 一个大的 NAL 单元分成多个 RTP 包

FU-A 头部:
 0 1 2 3 4 5 6 7
+-+-+-+-+-+-+-+-+
|S|E|R|  Type   |
+-+-+-+-+-+-+-+-+
S: 开始位
E: 结束位
R: 保留
Type: NAL 单元类型
```

### 6.4 帧重组

```javascript
// 帧重组示例
class FrameAssembler {
    constructor() {
        this.fragments = new Map(); // timestamp -> packets[]
    }
    
    addPacket(packet) {
        const ts = packet.timestamp;
        
        if (!this.fragments.has(ts)) {
            this.fragments.set(ts, []);
        }
        
        this.fragments.get(ts).push(packet);
        
        // 检查是否收到完整帧 (M=1)
        if (packet.marker) {
            return this.assembleFrame(ts);
        }
        
        return null;
    }
    
    assembleFrame(timestamp) {
        const packets = this.fragments.get(timestamp);
        
        // 按序列号排序
        packets.sort((a, b) => {
            let diff = a.seq - b.seq;
            if (diff > 32768) diff -= 65536;
            if (diff < -32768) diff += 65536;
            return diff;
        });
        
        // 检查是否有丢包
        for (let i = 1; i < packets.length; i++) {
            let expectedSeq = (packets[i-1].seq + 1) % 65536;
            if (packets[i].seq !== expectedSeq) {
                console.log('Frame incomplete, missing packets');
                return null;
            }
        }
        
        // 拼接负载
        const payloads = packets.map(p => p.payload);
        const frame = Buffer.concat(payloads);
        
        // 清理
        this.fragments.delete(timestamp);
        
        return {
            timestamp: timestamp,
            data: frame,
            isKeyFrame: this.isKeyFrame(packets[0])
        };
    }
    
    isKeyFrame(packet) {
        // 根据编解码器判断是否为关键帧
        // VP8: 检查 payload descriptor
        // H.264: 检查 NAL 类型
        return false; // 简化示例
    }
}
```

### 6.5 关键帧与非关键帧

```
关键帧 (I-Frame / IDR):
- 可以独立解码
- 不依赖其他帧
- 体积较大
- 用于随机访问和错误恢复

非关键帧 (P-Frame / B-Frame):
- 依赖其他帧解码
- 体积较小
- 丢失会导致解码错误

WebRTC 中请求关键帧:
1. PLI (Picture Loss Indication)
2. FIR (Full Intra Request)
```

---

## 7. RTP 扩展头

### 7.1 通用扩展头格式

```
RFC 5285 定义了两种扩展头格式:

One-Byte Header:
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|       0xBE    |    0xDE       |           length              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|  ID   | len   |     data...                                   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

Two-Byte Header:
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|       0x10    |    0x00       |           length              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|      ID       |     len       |     data...                   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 7.2 WebRTC 常用扩展

| 扩展 | URI | 用途 |
|------|-----|------|
| abs-send-time | http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time | 绝对发送时间 |
| transport-cc | http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01 | 传输层拥塞控制 |
| ssrc-audio-level | urn:ietf:params:rtp-hdrext:ssrc-audio-level | 音频电平 |
| video-orientation | urn:3gpp:video-orientation | 视频方向 |
| toffset | urn:ietf:params:rtp-hdrext:toffset | 传输时间偏移 |
| mid | urn:ietf:params:rtp-hdrext:sdes:mid | 媒体标识 |
| rid | urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id | 流标识 (Simulcast) |

### 7.3 abs-send-time 扩展

```
绝对发送时间扩展:

格式: 3 字节,24 位定点数
- 高 6 位: 秒 (模 64)
- 低 18 位: 秒的小数部分

精度: 约 3.8 微秒
范围: 约 64 秒后回绕

用途:
- 接收端带宽估计
- 延迟测量
- 拥塞控制
```

### 7.4 audio-level 扩展

```
音频电平扩展:

 0                   1
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|  ID   | len=0 |V|   level     |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

V: 语音活动标志 (1=有语音)
level: 音频电平 (0-127 dBov)
  0 = 0 dBov (最大)
  127 = -127 dBov (最小)

用途:
- 显示说话者指示
- 自动切换活跃说话者
- 静音检测
```

### 7.5 SDP 中的扩展声明

```
SDP 中声明 RTP 扩展:

a=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level
a=extmap:2 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time
a=extmap:3 urn:ietf:params:rtp-hdrext:toffset
a=extmap:4 http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01
a=extmap:5 urn:ietf:params:rtp-hdrext:sdes:mid

格式: a=extmap:<id> <uri>
id: 扩展 ID (1-14 for one-byte, 1-255 for two-byte)
uri: 扩展标识 URI
```

---

## 8. 总结

### 8.1 RTP 核心要点

| 要点 | 说明 |
|------|------|
| 版本 | V=2 (固定) |
| 序列号 | 16 位,检测丢包和排序 |
| 时间戳 | 32 位,播放同步 |
| SSRC | 32 位,标识媒体源 |
| Marker | 标记帧边界 |
| PT | 标识编解码器 |

### 8.2 RTP 与帧的关系

```
编码帧
   |
   v
+------------------+
| 帧分片           |  大帧分成多个 RTP 包
+------------------+
   |
   v
+------------------+
| RTP 打包         |  添加 RTP 头部
+------------------+
   |
   v
+------------------+
| 网络传输         |  可能乱序、丢包
+------------------+
   |
   v
+------------------+
| 帧重组           |  根据序号和时间戳重组
+------------------+
   |
   v
解码帧
```

### 8.3 下一篇预告

在下一篇文章中,我们将深入探讨 RTCP 协议,包括:
- Sender/Receiver Report
- 丢包、带宽、延迟分析
- 音视频同步 (lip-sync)

---

## 参考资料

1. [RFC 3550 - RTP: A Transport Protocol for Real-Time Applications](https://datatracker.ietf.org/doc/html/rfc3550)
2. [RFC 5285 - A General Mechanism for RTP Header Extensions](https://datatracker.ietf.org/doc/html/rfc5285)
3. [RFC 7741 - RTP Payload Format for VP8 Video](https://datatracker.ietf.org/doc/html/rfc7741)
4. [RFC 6184 - RTP Payload Format for H.264 Video](https://datatracker.ietf.org/doc/html/rfc6184)

---

> 作者: WebRTC 技术专栏  
> 系列: 媒体传输深入讲解 (1/6)  
> 上一篇: [完整的 WebRTC 信令流程图](../part2-signaling/11-complete-signaling-flow.md)  
> 下一篇: [RTCP: 统计、同步与网络自适应](./13-rtcp-protocol.md)
