---
title: "WebRTC 视频编码基础 (VP8/VP9/H.264/AV1)"
description: "1. [视频编码概述](#1-视频编码概述)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 18
---

> 本文是 WebRTC 系列专栏的第十八篇,将深入探讨 WebRTC 支持的视频编码器,包括各编码器的特点、编码参数配置以及 Codec 协商机制。

---

## 目录

1. [视频编码概述](#1-视频编码概述)
2. [VP8 编码器](#2-vp8-编码器)
3. [VP9 编码器](#3-vp9-编码器)
4. [H.264/AVC 编码器](#4-h264avc-编码器)
5. [AV1 编码器](#5-av1-编码器)
6. [编码参数详解](#6-编码参数详解)
7. [Codec 协商](#7-codec-协商)
8. [总结](#8-总结)

---

## 1. 视频编码概述

### 1.1 为什么需要视频编码

```
原始视频数据量:

1080p @ 30fps:
- 分辨率: 1920 x 1080
- 颜色深度: 24 bits (RGB)
- 帧率: 30 fps

数据量 = 1920 x 1080 x 24 x 30 = 1.49 Gbps

经过编码后:
- H.264: 2-5 Mbps
- VP9: 1.5-4 Mbps
- AV1: 1-3 Mbps

压缩比: 300-1000 倍
```

### 1.2 视频编码基本原理

```
视频编码核心技术:

1. 帧内预测 (Intra Prediction)
   - 利用同一帧内的空间相关性
   - 生成 I 帧 (关键帧)

2. 帧间预测 (Inter Prediction)
   - 利用帧与帧之间的时间相关性
   - 生成 P 帧 (预测帧) 和 B 帧 (双向预测帧)

3. 变换编码 (Transform Coding)
   - DCT/DST 变换
   - 将空域转换为频域

4. 量化 (Quantization)
   - 降低精度以减少数据量
   - QP 值越大,压缩率越高,质量越低

5. 熵编码 (Entropy Coding)
   - CABAC/CAVLC (H.264)
   - 算术编码 (VP8/VP9/AV1)
```

### 1.3 帧类型

```
GOP (Group of Pictures) 结构:

I    P    P    P    P    I    P    P    P    P
|-------- GOP --------|-------- GOP --------|

I 帧 (Intra Frame):
- 完整的图像
- 不依赖其他帧
- 体积最大
- 用于随机访问

P 帧 (Predicted Frame):
- 参考前面的帧
- 只编码差异
- 体积较小

B 帧 (Bi-directional Frame):
- 参考前后的帧
- 体积最小
- WebRTC 通常不使用 (增加延迟)
```

### 1.4 WebRTC 支持的编码器

| 编码器 | 标准 | 许可 | 浏览器支持 |
|--------|------|------|-----------|
| VP8 | Google/IETF | 免费 | 全部 |
| VP9 | Google/IETF | 免费 | Chrome, Firefox |
| H.264 | ITU-T/ISO | 专利费 | 全部 |
| AV1 | AOMedia | 免费 | Chrome, Firefox |

---

## 2. VP8 编码器

### 2.1 VP8 特点

```
VP8 概述:
- 2010 年由 Google 开源
- WebRTC 强制支持的编码器
- 专为实时通信优化

优点:
+ 免专利费
+ 低延迟
+ 良好的错误恢复
+ 所有浏览器支持

缺点:
- 压缩效率不如 H.264/VP9
- 不支持 SVC
```

### 2.2 VP8 技术细节

```
VP8 编码结构:

帧类型:
- Key Frame (关键帧)
- Inter Frame (帧间帧)
- Golden Frame (黄金帧,用于错误恢复)
- Altref Frame (替代参考帧)

分块:
- 16x16 宏块
- 4x4 子块

预测模式:
- 帧内: DC, V, H, TM
- 帧间: 运动补偿

变换:
- 4x4 WHT (Walsh-Hadamard)
- 4x4 DCT

熵编码:
- 布尔算术编码
```

### 2.3 VP8 配置示例

```javascript
// 设置 VP8 编码参数
const sender = pc.getSenders().find(s => s.track?.kind === 'video');
const params = sender.getParameters();

// VP8 编码配置
params.encodings[0] = {
    maxBitrate: 2500000,      // 最大码率 2.5 Mbps
    maxFramerate: 30,         // 最大帧率 30 fps
    scaleResolutionDownBy: 1  // 不缩放
};

await sender.setParameters(params);
```

---

## 3. VP9 编码器

### 3.1 VP9 特点

```
VP9 概述:
- 2013 年由 Google 发布
- VP8 的继任者
- 支持 SVC (可伸缩视频编码)

优点:
+ 比 VP8 提升 30-50% 压缩效率
+ 支持 10/12 bit 色深
+ 支持 4:2:2, 4:4:4 色度采样
+ 原生 SVC 支持

缺点:
- 编码复杂度更高
- 部分浏览器不支持
```

### 3.2 VP9 Profile

| Profile | 色深 | 色度采样 | 说明 |
|---------|------|---------|------|
| Profile 0 | 8 bit | 4:2:0 | 最常用 |
| Profile 1 | 8 bit | 4:2:2, 4:4:4 | 高质量 |
| Profile 2 | 10/12 bit | 4:2:0 | HDR |
| Profile 3 | 10/12 bit | 4:2:2, 4:4:4 | 专业 |

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
// L1T1: 无 SVC
// L1T2, L1T3: 时间可伸缩
// L2T1, L2T2, L2T3: 2 空间层
// L3T1, L3T2, L3T3: 3 空间层
```

### 3.4 VP9 vs VP8 对比

```
相同质量下的码率对比:

分辨率      VP8        VP9        节省
720p       1.5 Mbps   1.0 Mbps   33%
1080p      3.0 Mbps   2.0 Mbps   33%
4K         12 Mbps    8 Mbps     33%
```

---

## 4. H.264/AVC 编码器

### 4.1 H.264 特点

```
H.264 概述:
- 2003 年由 ITU-T/ISO 发布
- 最广泛使用的视频编码标准
- 硬件加速支持最好

优点:
+ 硬件加速普及
+ 兼容性最好
+ 成熟稳定

缺点:
- 专利费用 (MPEG LA)
- 压缩效率不如新编码器
```

### 4.2 H.264 Profile

| Profile | 说明 | 应用场景 |
|---------|------|---------|
| Baseline | 最基础,无 B 帧 | 视频通话 |
| Main | 支持 B 帧,CABAC | 标清视频 |
| High | 8x8 变换,更多参考帧 | 高清视频 |
| High 10 | 10 bit 色深 | 专业视频 |

### 4.3 H.264 Level

```
Level 决定了编码的复杂度上限:

Level   最大分辨率      最大帧率    最大码率
3.0     720x480        30         10 Mbps
3.1     1280x720       30         14 Mbps
4.0     2048x1024      30         20 Mbps
4.1     2048x1024      30         50 Mbps
5.0     3840x2160      30         135 Mbps
5.1     4096x2160      60         240 Mbps
```

### 4.4 H.264 SDP 参数

```
SDP 中的 H.264 参数:

a=rtpmap:102 H264/90000
a=fmtp:102 level-asymmetry-allowed=1;
           packetization-mode=1;
           profile-level-id=42e01f

profile-level-id 解析:
42e01f = 42 e0 1f
- 42: profile_idc (66 = Baseline)
- e0: profile-iop (constraint flags)
- 1f: level_idc (31 = Level 3.1)

常见 profile-level-id:
- 42001f: Baseline Level 3.1
- 42e01f: Constrained Baseline Level 3.1
- 4d001f: Main Level 3.1
- 64001f: High Level 3.1
```

### 4.5 H.264 配置示例

```javascript
// 优先使用 H.264
async function preferH264(pc) {
    const transceivers = pc.getTransceivers();
    
    for (const transceiver of transceivers) {
        if (transceiver.receiver.track.kind !== 'video') continue;
        
        const codecs = RTCRtpReceiver.getCapabilities('video').codecs;
        
        // 将 H.264 排在前面
        const h264Codecs = codecs.filter(c => 
            c.mimeType === 'video/H264'
        );
        const otherCodecs = codecs.filter(c => 
            c.mimeType !== 'video/H264'
        );
        
        const sortedCodecs = [...h264Codecs, ...otherCodecs];
        transceiver.setCodecPreferences(sortedCodecs);
    }
}
```

---

## 5. AV1 编码器

### 5.1 AV1 特点

```
AV1 概述:
- 2018 年由 AOMedia 发布
- 下一代开放视频编码标准
- 成员: Google, Apple, Microsoft, Netflix, Amazon 等

优点:
+ 比 VP9/H.265 提升 30% 压缩效率
+ 免专利费
+ 支持 HDR, 宽色域
+ 强大的屏幕内容编码

缺点:
- 编码复杂度高
- 硬件支持有限
- 浏览器支持不完整
```

### 5.2 AV1 技术特点

```
AV1 关键技术:

1. 更大的块尺寸
   - 最大 128x128 超级块
   - 更灵活的分割方式

2. 更多预测模式
   - 帧内: 56 种方向预测
   - 帧间: 复合预测,全局运动

3. 新变换
   - 多种变换类型
   - 自适应选择

4. 循环滤波
   - CDEF (Constrained Directional Enhancement Filter)
   - Loop Restoration

5. 屏幕内容编码
   - 调色板模式
   - 帧内块复制
```

### 5.3 AV1 在 WebRTC 中的使用

```javascript
// 检查 AV1 支持
function checkAV1Support() {
    const capabilities = RTCRtpReceiver.getCapabilities('video');
    const av1 = capabilities.codecs.find(c => 
        c.mimeType === 'video/AV1'
    );
    return !!av1;
}

// 优先使用 AV1
async function preferAV1(pc) {
    if (!checkAV1Support()) {
        console.log('AV1 not supported');
        return;
    }
    
    const transceivers = pc.getTransceivers();
    
    for (const transceiver of transceivers) {
        if (transceiver.receiver.track.kind !== 'video') continue;
        
        const codecs = RTCRtpReceiver.getCapabilities('video').codecs;
        
        const av1Codecs = codecs.filter(c => 
            c.mimeType === 'video/AV1'
        );
        const otherCodecs = codecs.filter(c => 
            c.mimeType !== 'video/AV1'
        );
        
        transceiver.setCodecPreferences([...av1Codecs, ...otherCodecs]);
    }
}
```

### 5.4 编码器对比

```
编码效率对比 (相同质量):

编码器    相对码率    编码速度    解码速度
VP8       100%       快          快
H.264     85%        快          快
VP9       65%        中          中
AV1       50%        慢          中

推荐场景:
- 实时通话: VP8/H.264
- 高质量会议: VP9
- 录制/点播: AV1
```

---

## 6. 编码参数详解

### 6.1 码率 (Bitrate)

```
码率类型:

CBR (Constant Bitrate):
- 恒定码率
- 适合直播
- 带宽稳定

VBR (Variable Bitrate):
- 可变码率
- 适合录制
- 质量稳定

CRF (Constant Rate Factor):
- 恒定质量
- 码率自动调整
- 适合离线编码
```

```javascript
// 设置目标码率
const params = sender.getParameters();
params.encodings[0].maxBitrate = 2000000; // 2 Mbps
await sender.setParameters(params);

// 推荐码率:
// 360p: 400-800 kbps
// 480p: 500-1500 kbps
// 720p: 1000-3000 kbps
// 1080p: 2000-6000 kbps
```

### 6.2 帧率 (Framerate)

```javascript
// 设置最大帧率
const params = sender.getParameters();
params.encodings[0].maxFramerate = 30;
await sender.setParameters(params);

// 帧率建议:
// 视频通话: 15-30 fps
// 屏幕共享: 5-15 fps
// 游戏直播: 30-60 fps
```

### 6.3 分辨率

```javascript
// 设置分辨率缩放
const params = sender.getParameters();
params.encodings[0].scaleResolutionDownBy = 2; // 缩小一半
await sender.setParameters(params);

// 或通过约束设置
await videoTrack.applyConstraints({
    width: { ideal: 1280 },
    height: { ideal: 720 }
});
```

### 6.4 GOP 大小

```
GOP (Group of Pictures):

小 GOP (如 30 帧):
+ 错误恢复快
+ 随机访问快
- 压缩效率低

大 GOP (如 250 帧):
+ 压缩效率高
- 错误恢复慢
- 随机访问慢

WebRTC 建议:
- 关键帧间隔: 2-3 秒
- 即 60-90 帧 @ 30fps
```

### 6.5 QP (Quantization Parameter)

```
QP 值范围:
- H.264: 0-51
- VP8/VP9: 0-63
- AV1: 0-255

QP 越大:
- 压缩率越高
- 质量越低
- 码率越低

WebRTC 自动调整 QP 以适应目标码率
```

---

## 7. Codec 协商

### 7.1 协商流程

```
Codec 协商过程:

1. 获取本地支持的 Codec
   RTCRtpSender.getCapabilities('video')
   RTCRtpReceiver.getCapabilities('video')

2. 创建 Offer (包含所有支持的 Codec)
   m=video 9 UDP/TLS/RTP/SAVPF 96 97 98 99
   a=rtpmap:96 VP8/90000
   a=rtpmap:97 VP9/90000
   a=rtpmap:98 H264/90000
   a=rtpmap:99 AV1/90000

3. 创建 Answer (选择共同支持的 Codec)
   m=video 9 UDP/TLS/RTP/SAVPF 96 98
   a=rtpmap:96 VP8/90000
   a=rtpmap:98 H264/90000

4. 最终使用第一个 Codec (VP8)
```

### 7.2 设置 Codec 优先级

```javascript
// 设置 Codec 优先级
function setCodecPreferences(pc, preferredCodec) {
    const transceivers = pc.getTransceivers();
    
    for (const transceiver of transceivers) {
        const kind = transceiver.receiver.track?.kind;
        if (kind !== 'video') continue;
        
        const capabilities = RTCRtpReceiver.getCapabilities('video');
        const codecs = capabilities.codecs;
        
        // 按优先级排序
        const sorted = codecs.sort((a, b) => {
            const aMatch = a.mimeType.includes(preferredCodec);
            const bMatch = b.mimeType.includes(preferredCodec);
            if (aMatch && !bMatch) return -1;
            if (!aMatch && bMatch) return 1;
            return 0;
        });
        
        transceiver.setCodecPreferences(sorted);
    }
}

// 使用示例
setCodecPreferences(pc, 'VP9');
```

### 7.3 排除特定 Codec

```javascript
// 排除 VP8
function excludeCodec(pc, excludedCodec) {
    const transceivers = pc.getTransceivers();
    
    for (const transceiver of transceivers) {
        const kind = transceiver.receiver.track?.kind;
        if (kind !== 'video') continue;
        
        const capabilities = RTCRtpReceiver.getCapabilities('video');
        const codecs = capabilities.codecs.filter(c => 
            !c.mimeType.includes(excludedCodec)
        );
        
        transceiver.setCodecPreferences(codecs);
    }
}
```

### 7.4 动态切换 Codec

```javascript
// 运行时切换 Codec (需要重新协商)
async function switchCodec(pc, newCodec) {
    // 1. 设置新的 Codec 优先级
    setCodecPreferences(pc, newCodec);
    
    // 2. 触发重新协商
    const offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    
    // 3. 发送给对端
    signalingChannel.send({
        type: 'offer',
        sdp: offer.sdp
    });
}
```

---

## 8. 总结

### 8.1 编码器选择建议

| 场景 | 推荐编码器 | 原因 |
|------|-----------|------|
| 1:1 视频通话 | VP8/H.264 | 低延迟,兼容性好 |
| 多人会议 | VP9 | SVC 支持,带宽效率 |
| 屏幕共享 | VP9/AV1 | 屏幕内容优化 |
| 移动端 | H.264 | 硬件加速 |
| 高质量录制 | AV1 | 最佳压缩效率 |

### 8.2 编码参数建议

```
视频通话推荐参数:

分辨率: 720p (1280x720)
帧率: 30 fps
码率: 1.5-2.5 Mbps
GOP: 60-90 帧
Codec: VP8 或 H.264 Baseline
```

### 8.3 下一篇预告

在下一篇文章中,我们将探讨 WebRTC 的音频处理技术。

---

## 参考资料

1. [WebRTC Codec Requirements](https://www.w3.org/TR/webrtc/#codec-requirements)
2. [VP9 Bitstream Specification](https://www.webmproject.org/vp9/)
3. [AV1 Specification](https://aomediacodec.github.io/av1-spec/)
4. [H.264 Overview](https://www.itu.int/rec/T-REC-H.264)

---

> 作者: WebRTC 技术专栏  
> 系列: 音视频编码与媒体处理 (1/3)  
> 上一篇: [媒体流与轨道模型](../part3-media/17-media-track-model.md)  
> 下一篇: [音频处理: AEC、AGC、NS、VAD](./19-audio-processing.md)
