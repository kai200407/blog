---
title: "音频处理: AEC、AGC、NS、VAD"
description: "1. [音频处理概述](#1-音频处理概述)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 19
---

> 本文是 WebRTC 系列专栏的第十九篇,将深入探讨 WebRTC 的音频处理技术,包括回声消除、自动增益控制、噪声抑制和语音活动检测。

---

## 目录

1. [音频处理概述](#1-音频处理概述)
2. [AEC 回声消除](#2-aec-回声消除)
3. [AGC 自动增益控制](#3-agc-自动增益控制)
4. [NS 噪声抑制](#4-ns-噪声抑制)
5. [VAD 语音活动检测](#5-vad-语音活动检测)
6. [音频处理流水线](#6-音频处理流水线)
7. [API 与配置](#7-api-与配置)
8. [总结](#8-总结)

---

## 1. 音频处理概述

### 1.1 为什么需要音频处理

```
实时通话中的音频问题:

1. 回声 (Echo)
   - 扬声器播放的声音被麦克风采集
   - 对方听到自己的声音

2. 噪声 (Noise)
   - 环境噪声: 风扇、空调、交通
   - 设备噪声: 电流声、底噪

3. 音量不一致
   - 不同设备音量差异大
   - 说话距离变化

4. 静音检测
   - 不说话时浪费带宽
   - 需要检测语音活动
```

### 1.2 WebRTC 音频处理模块

```
WebRTC 音频处理流水线:

麦克风 ──> 采集 ──> 前处理 ──> 编码 ──> 发送
                      │
                      ├── AEC (回声消除)
                      ├── NS (噪声抑制)
                      ├── AGC (自动增益)
                      └── VAD (语音检测)

接收 ──> 解码 ──> 后处理 ──> 播放 ──> 扬声器
                    │
                    └── AGC (播放增益)
```

### 1.3 音频参数

```
WebRTC 音频参数:

采样率: 16000 Hz (窄带) / 48000 Hz (全带)
位深: 16 bit
通道: 单声道 / 立体声
帧长: 10 ms / 20 ms

编码器:
- Opus (默认,推荐)
- G.711 (兼容)
- G.722 (宽带)
```

---

## 2. AEC 回声消除

### 2.1 回声产生原理

```
回声产生过程:

远端                                    本地
  │                                       │
  │  语音 A ────────────────────────────> │
  │                                       │
  │                                       ├──> 扬声器播放 A
  │                                       │
  │                                       ├──> 麦克风采集
  │                                       │    (包含 A 的回声)
  │                                       │
  │  <──────────────────────────── A + B  │
  │                                       │
  │  听到自己的声音 A (回声)               │

回声路径:
扬声器 ──> 空气传播 ──> 麦克风
         (房间反射)
```

### 2.2 AEC 工作原理

```
自适应滤波器原理:

         远端参考信号 x(n)
              │
              v
    +-------------------+
    |   自适应滤波器     |
    |   (估计回声路径)   |
    +-------------------+
              │
              v
         估计回声 y'(n)
              │
              v
    +-------------------+
    |      减法器        |  <── 麦克风信号 y(n)
    +-------------------+
              │
              v
         误差信号 e(n) = y(n) - y'(n)
         (近端语音 + 残余回声)

自适应算法:
- NLMS (Normalized Least Mean Squares)
- APA (Affine Projection Algorithm)
- RLS (Recursive Least Squares)
```

### 2.3 AEC 挑战

```
AEC 面临的挑战:

1. 非线性失真
   - 扬声器非线性
   - 需要非线性处理 (NLP)

2. 双讲 (Double Talk)
   - 双方同时说话
   - 需要检测并保护滤波器

3. 回声路径变化
   - 人移动
   - 物体移动
   - 需要快速收敛

4. 延迟对齐
   - 系统延迟不确定
   - 需要延迟估计
```

### 2.4 AEC3 (WebRTC 新一代 AEC)

```
AEC3 特点:

1. 基于子带处理
   - 64 个子带
   - 每个子带独立处理

2. 回声路径建模
   - 线性滤波器
   - 非线性处理

3. 残余回声抑制
   - 基于信号统计
   - 自适应抑制

4. 舒适噪声生成
   - 填补抑制后的空白
   - 避免"死寂"感
```

### 2.5 AEC 配置

```javascript
// 启用/配置 AEC
const stream = await navigator.mediaDevices.getUserMedia({
    audio: {
        echoCancellation: true,        // 启用回声消除
        autoGainControl: true,         // 启用 AGC
        noiseSuppression: true,        // 启用降噪
        // 高级配置 (部分浏览器支持)
        echoCancellationType: 'system' // 或 'browser'
    }
});

// 检查实际应用的约束
const track = stream.getAudioTracks()[0];
const settings = track.getSettings();
console.log('Echo Cancellation:', settings.echoCancellation);
```

---

## 3. AGC 自动增益控制

### 3.1 AGC 作用

```
AGC 解决的问题:

问题 1: 音量过小
输入: ▁▁▂▁▂▁▁▂▁▁
输出: ▃▃▅▃▅▃▃▅▃▃ (放大)

问题 2: 音量过大
输入: █████████
输出: ▆▆▆▆▆▆▆▆▆ (压缩)

问题 3: 音量变化
输入: ▁▁▂▅█▅▂▁▁
输出: ▄▄▅▆▆▆▅▄▄ (平滑)
```

### 3.2 AGC 工作原理

```
AGC 处理流程:

输入信号 ──> 电平检测 ──> 增益计算 ──> 增益应用 ──> 输出信号
                │              │
                v              v
           目标电平        增益限制
           (-18 dBFS)     (最大增益)

增益计算:
gain = target_level / input_level

增益平滑:
- 攻击时间 (Attack): 快速响应增大
- 释放时间 (Release): 缓慢响应减小
```

### 3.3 AGC 模式

```
WebRTC AGC 模式:

1. 模拟 AGC (Analog AGC)
   - 调整麦克风硬件增益
   - 在 ADC 之前
   - 减少量化噪声

2. 数字 AGC (Digital AGC)
   - 软件调整增益
   - 在 ADC 之后
   - 更精确控制

3. 自适应数字 AGC
   - 根据信号特性调整
   - 目标电平: -18 dBFS
   - 最大增益: 12 dB
```

### 3.4 AGC 实现示例

```javascript
class SimpleAGC {
    constructor(options = {}) {
        this.targetLevel = options.targetLevel || -18; // dBFS
        this.maxGain = options.maxGain || 12;          // dB
        this.minGain = options.minGain || -12;         // dB
        this.attackTime = options.attackTime || 0.01;  // 秒
        this.releaseTime = options.releaseTime || 0.1; // 秒
        this.currentGain = 0; // dB
    }
    
    // 计算信号电平 (dBFS)
    calculateLevel(samples) {
        let sum = 0;
        for (const sample of samples) {
            sum += sample * sample;
        }
        const rms = Math.sqrt(sum / samples.length);
        return 20 * Math.log10(rms + 1e-10);
    }
    
    // 处理音频帧
    process(samples, sampleRate) {
        const inputLevel = this.calculateLevel(samples);
        
        // 计算目标增益
        let targetGain = this.targetLevel - inputLevel;
        targetGain = Math.max(this.minGain, 
                    Math.min(this.maxGain, targetGain));
        
        // 平滑增益变化
        const frameTime = samples.length / sampleRate;
        if (targetGain > this.currentGain) {
            // 攻击: 快速增加
            const alpha = 1 - Math.exp(-frameTime / this.attackTime);
            this.currentGain += alpha * (targetGain - this.currentGain);
        } else {
            // 释放: 缓慢减少
            const alpha = 1 - Math.exp(-frameTime / this.releaseTime);
            this.currentGain += alpha * (targetGain - this.currentGain);
        }
        
        // 应用增益
        const linearGain = Math.pow(10, this.currentGain / 20);
        const output = new Float32Array(samples.length);
        for (let i = 0; i < samples.length; i++) {
            output[i] = samples[i] * linearGain;
            // 限幅
            output[i] = Math.max(-1, Math.min(1, output[i]));
        }
        
        return output;
    }
}
```

---

## 4. NS 噪声抑制

### 4.1 噪声类型

```
常见噪声类型:

1. 平稳噪声
   - 风扇、空调
   - 频谱相对稳定
   - 容易抑制

2. 非平稳噪声
   - 键盘敲击、咳嗽
   - 频谱快速变化
   - 较难抑制

3. 周期性噪声
   - 电流声 (50/60 Hz)
   - 可用陷波滤波器

4. 脉冲噪声
   - 突发噪声
   - 需要特殊处理
```

### 4.2 NS 工作原理

```
频谱减法原理:

1. 噪声估计
   - 在静音段估计噪声频谱
   - 持续更新噪声模型

2. 频谱减法
   |Y(f)|^2 = |X(f)|^2 - |N(f)|^2
   
   Y: 输出频谱
   X: 输入频谱
   N: 噪声频谱

3. 维纳滤波
   H(f) = |S(f)|^2 / (|S(f)|^2 + |N(f)|^2)
   
   H: 滤波器增益
   S: 语音频谱
   N: 噪声频谱

4. 相位保持
   - 只修改幅度
   - 保持原始相位
```

### 4.3 NS 处理流程

```
噪声抑制流程:

输入信号
    │
    v
+----------+
|   分帧    |  (20ms 帧, 50% 重叠)
+----------+
    │
    v
+----------+
|   加窗    |  (汉宁窗)
+----------+
    │
    v
+----------+
|   FFT    |  (时域 -> 频域)
+----------+
    │
    v
+----------+
| 噪声估计  |  (VAD 辅助)
+----------+
    │
    v
+----------+
| 频谱减法  |  (或维纳滤波)
+----------+
    │
    v
+----------+
|   IFFT   |  (频域 -> 时域)
+----------+
    │
    v
+----------+
| 重叠相加  |
+----------+
    │
    v
输出信号
```

### 4.4 NS 配置

```javascript
// 启用噪声抑制
const stream = await navigator.mediaDevices.getUserMedia({
    audio: {
        noiseSuppression: true,
        // 某些浏览器支持的高级选项
        // noiseSuppressionLevel: 'high' // low, moderate, high
    }
});

// 使用 AudioWorklet 自定义降噪
class NoiseSuppressionProcessor extends AudioWorkletProcessor {
    constructor() {
        super();
        this.noiseEstimate = new Float32Array(256);
        this.vadState = false;
    }
    
    process(inputs, outputs, parameters) {
        const input = inputs[0][0];
        const output = outputs[0][0];
        
        if (!input) return true;
        
        // 简化的降噪处理
        // 实际应使用 FFT 和频谱减法
        for (let i = 0; i < input.length; i++) {
            output[i] = input[i]; // 占位
        }
        
        return true;
    }
}
```

---

## 5. VAD 语音活动检测

### 5.1 VAD 作用

```
VAD 用途:

1. 带宽节省
   - 静音时不发送数据
   - 或发送舒适噪声

2. 辅助 AEC
   - 检测双讲
   - 保护滤波器

3. 辅助 NS
   - 在静音段更新噪声估计

4. 会议系统
   - 检测当前说话人
   - 自动切换焦点
```

### 5.2 VAD 特征

```
VAD 常用特征:

1. 短时能量
   E = sum(x[n]^2)
   语音能量 > 噪声能量

2. 过零率
   ZCR = count(x[n] * x[n-1] < 0)
   语音过零率较低

3. 频谱特征
   - 频谱质心
   - 频谱平坦度
   - 子带能量比

4. 基频 (F0)
   - 语音有基频
   - 噪声无基频
```

### 5.3 VAD 实现

```javascript
class SimpleVAD {
    constructor(options = {}) {
        this.energyThreshold = options.energyThreshold || -40; // dBFS
        this.hangoverFrames = options.hangoverFrames || 10;
        this.hangoverCount = 0;
        this.isActive = false;
    }
    
    // 计算帧能量
    calculateEnergy(samples) {
        let sum = 0;
        for (const sample of samples) {
            sum += sample * sample;
        }
        const rms = Math.sqrt(sum / samples.length);
        return 20 * Math.log10(rms + 1e-10);
    }
    
    // 处理一帧
    process(samples) {
        const energy = this.calculateEnergy(samples);
        
        if (energy > this.energyThreshold) {
            // 检测到语音
            this.isActive = true;
            this.hangoverCount = this.hangoverFrames;
        } else if (this.hangoverCount > 0) {
            // 挂起期间保持活动
            this.hangoverCount--;
            this.isActive = true;
        } else {
            // 静音
            this.isActive = false;
        }
        
        return this.isActive;
    }
}

// 使用示例
const vad = new SimpleVAD({ energyThreshold: -35 });

// 在音频处理中使用
function processAudioFrame(samples) {
    const isSpeech = vad.process(samples);
    
    if (isSpeech) {
        // 发送语音数据
        sendAudio(samples);
    } else {
        // 发送舒适噪声或不发送
        sendComfortNoise();
    }
}
```

### 5.4 WebRTC VAD

```
WebRTC VAD 特点:

1. 基于 GMM (高斯混合模型)
   - 语音模型
   - 噪声模型

2. 多模式
   - 模式 0: 质量优先 (少漏检)
   - 模式 1: 低比特率
   - 模式 2: 激进
   - 模式 3: 非常激进 (少误检)

3. 帧长
   - 10ms, 20ms, 30ms

4. 采样率
   - 8000, 16000, 32000, 48000 Hz
```

---

## 6. 音频处理流水线

### 6.1 完整流水线

```
WebRTC 音频处理流水线:

采集端:
+--------+    +-----+    +-----+    +-----+    +-----+    +--------+
| 麦克风 | -> | HPF | -> | AEC | -> | NS  | -> | AGC | -> | 编码器 |
+--------+    +-----+    +-----+    +-----+    +-----+    +--------+
                           ^
                           |
                    +------+------+
                    | 远端参考信号 |
                    +-------------+

播放端:
+--------+    +-----+    +-----+    +--------+
| 解码器 | -> | AGC | -> | 混音 | -> | 扬声器 |
+--------+    +-----+    +-----+    +--------+

HPF: 高通滤波器 (去除低频噪声)
```

### 6.2 处理顺序

```
处理顺序的重要性:

正确顺序: AEC -> NS -> AGC

原因:
1. AEC 需要原始信号
   - 增益变化会影响回声估计
   
2. NS 在 AEC 之后
   - 避免噪声影响回声消除
   
3. AGC 在最后
   - 对干净信号进行增益调整

错误顺序的后果:
- AGC -> AEC: 回声消除效果差
- NS -> AEC: 残余回声增加
```

### 6.3 延迟考虑

```
音频处理延迟:

组件          延迟
采集缓冲      10-20 ms
AEC           10-20 ms
NS            10-20 ms
编码          20-40 ms
网络传输      20-200 ms
解码          20-40 ms
播放缓冲      10-40 ms
-----------------------
总计          100-380 ms

优化方法:
- 减小缓冲区
- 使用低延迟编码
- 优化算法
```

### 6.4 AudioWorklet 实现

```javascript
// 自定义音频处理器
class AudioProcessor extends AudioWorkletProcessor {
    constructor() {
        super();
        this.aec = new AEC();
        this.ns = new NoiseSupression();
        this.agc = new AGC();
        this.vad = new VAD();
    }
    
    process(inputs, outputs, parameters) {
        const input = inputs[0][0];
        const output = outputs[0][0];
        const reference = inputs[1]?.[0]; // 远端参考
        
        if (!input) return true;
        
        // 1. 回声消除
        let processed = this.aec.process(input, reference);
        
        // 2. 噪声抑制
        processed = this.ns.process(processed);
        
        // 3. VAD 检测
        const isSpeech = this.vad.process(processed);
        
        // 4. AGC
        processed = this.agc.process(processed);
        
        // 输出
        for (let i = 0; i < processed.length; i++) {
            output[i] = processed[i];
        }
        
        // 通知主线程 VAD 状态
        this.port.postMessage({ isSpeech });
        
        return true;
    }
}

registerProcessor('audio-processor', AudioProcessor);
```

---

## 7. API 与配置

### 7.1 getUserMedia 约束

```javascript
// 完整的音频约束
const audioConstraints = {
    // 基本约束
    echoCancellation: true,
    noiseSuppression: true,
    autoGainControl: true,
    
    // 设备选择
    deviceId: { exact: 'specific-device-id' },
    
    // 采样参数
    sampleRate: { ideal: 48000 },
    sampleSize: { ideal: 16 },
    channelCount: { ideal: 1 },
    
    // 延迟
    latency: { ideal: 0.01 }, // 10ms
    
    // 高级选项 (部分浏览器)
    // googEchoCancellation: true,
    // googAutoGainControl: true,
    // googNoiseSuppression: true,
    // googHighpassFilter: true,
};

const stream = await navigator.mediaDevices.getUserMedia({
    audio: audioConstraints
});
```

### 7.2 检查和修改约束

```javascript
// 获取当前设置
const track = stream.getAudioTracks()[0];
const settings = track.getSettings();

console.log('当前设置:', {
    echoCancellation: settings.echoCancellation,
    noiseSuppression: settings.noiseSuppression,
    autoGainControl: settings.autoGainControl,
    sampleRate: settings.sampleRate,
    channelCount: settings.channelCount
});

// 获取能力
const capabilities = track.getCapabilities();
console.log('设备能力:', capabilities);

// 修改约束
await track.applyConstraints({
    echoCancellation: false,
    noiseSuppression: true
});
```

### 7.3 SDP 中的音频参数

```
SDP 音频配置:

m=audio 9 UDP/TLS/RTP/SAVPF 111 103 104
a=rtpmap:111 opus/48000/2
a=fmtp:111 minptime=10;useinbandfec=1;stereo=0;sprop-stereo=0;cbr=0

参数说明:
- minptime: 最小打包时间 (10ms)
- useinbandfec: 启用带内 FEC
- stereo: 立体声 (0=单声道)
- cbr: 恒定码率 (0=VBR)
```

### 7.4 Opus 编码配置

```javascript
// 通过 SDP 修改 Opus 参数
function modifyOpusParams(sdp) {
    return sdp.replace(
        /a=fmtp:111 .*/,
        'a=fmtp:111 minptime=10;useinbandfec=1;stereo=0;maxaveragebitrate=32000'
    );
}

// Opus 参数:
// maxaveragebitrate: 最大平均码率 (6000-510000)
// maxplaybackrate: 最大播放采样率
// stereo: 立体声
// sprop-stereo: 发送立体声
// cbr: 恒定码率
// useinbandfec: 带内 FEC
// usedtx: 不连续传输 (DTX)
```

---

## 8. 总结

### 8.1 音频处理核心要点

| 模块 | 功能 | 关键参数 |
|------|------|---------|
| AEC | 消除回声 | 滤波器长度、收敛速度 |
| AGC | 自动增益 | 目标电平、攻击/释放时间 |
| NS | 噪声抑制 | 抑制强度、噪声估计 |
| VAD | 语音检测 | 能量阈值、挂起时间 |

### 8.2 最佳实践

```
音频处理建议:

1. 默认启用所有处理
   echoCancellation: true
   noiseSuppression: true
   autoGainControl: true

2. 特殊场景调整
   - 音乐: 关闭 NS 和 AGC
   - 录音: 可能关闭 AEC
   - 会议: 全部启用

3. 监控音频质量
   - 检查 RTCStats
   - 监听用户反馈

4. 测试不同设备
   - 不同设备效果不同
   - 需要广泛测试
```

### 8.3 下一篇预告

在下一篇文章中,我们将深入探讨 Simulcast 与 SVC 技术。

---

## 参考资料

1. [WebRTC Audio Processing](https://webrtc.googlesource.com/src/+/refs/heads/main/modules/audio_processing/)
2. [Opus Codec](https://opus-codec.org/)
3. [MediaTrackConstraints](https://developer.mozilla.org/en-US/docs/Web/API/MediaTrackConstraints)

---

> 作者: WebRTC 技术专栏  
> 系列: 音视频编码与媒体处理 (2/3)  
> 上一篇: [WebRTC 视频编码基础](./18-video-codec.md)  
> 下一篇: [Simulcast 与 SVC](./20-simulcast-svc.md)
