---
title: "WebRTC 数据通道 (RTCDataChannel)"
description: "1. [DataChannel 概述](#1-datachannel-概述)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 24
---

> 本文是 WebRTC 系列专栏的第二十四篇,将深入探讨 RTCDataChannel 的工作原理,包括 SCTP over DTLS 协议栈以及实时消息传输的实现。

---

## 目录

1. [DataChannel 概述](#1-datachannel-概述)
2. [SCTP 协议](#2-sctp-协议)
3. [创建与配置](#3-创建与配置)
4. [消息传输](#4-消息传输)
5. [实战应用](#5-实战应用)
6. [DataChannel vs WebSocket](#6-datachannel-vs-websocket)
7. [总结](#7-总结)

---

## 1. DataChannel 概述

### 1.1 什么是 DataChannel

```
RTCDataChannel 特点:

- P2P 数据传输通道
- 支持任意数据 (文本/二进制)
- 可靠/不可靠传输可选
- 有序/无序传输可选
- 低延迟
```

### 1.2 协议栈

```
DataChannel 协议栈:

+------------------+
| Application Data |
+------------------+
|   DataChannel    |
+------------------+
|      SCTP        |  (流控制传输协议)
+------------------+
|      DTLS        |  (加密)
+------------------+
|      ICE/UDP     |  (NAT 穿透)
+------------------+

对比 WebSocket:
+------------------+
| Application Data |
+------------------+
|    WebSocket     |
+------------------+
|      TLS         |
+------------------+
|      TCP         |
+------------------+
```

### 1.3 应用场景

```
DataChannel 适用场景:

1. 实时聊天
   - 文字消息
   - 表情/贴纸

2. 文件传输
   - P2P 文件共享
   - 大文件分片传输

3. 游戏数据
   - 玩家位置同步
   - 游戏状态更新

4. 协同编辑
   - 文档同步
   - 白板数据

5. 远程控制
   - 键盘/鼠标事件
   - 命令传输
```

---

## 2. SCTP 协议

### 2.1 SCTP 特点

```
SCTP (Stream Control Transmission Protocol):

优点:
+ 多流复用 (单连接多通道)
+ 消息边界保持
+ 可配置可靠性
+ 拥塞控制
+ 心跳检测

对比 TCP:
- TCP: 字节流,严格有序,完全可靠
- SCTP: 消息流,可配置有序性和可靠性
```

### 2.2 SCTP 消息结构

```
SCTP 数据块:

 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|   Type = 0    | Reserved|U|B|E|    Length                     |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                              TSN                              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|      Stream Identifier        |   Stream Sequence Number      |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                  Payload Protocol Identifier                  |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         User Data                             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

U: Unordered (无序标志)
B: Beginning (分片开始)
E: Ending (分片结束)
TSN: 传输序列号
```

### 2.3 可靠性配置

```
SCTP 可靠性模式:

1. 完全可靠 (默认)
   - 保证送达
   - 无限重传

2. 部分可靠 (PR-SCTP)
   - 限制重传次数
   - 或限制重传时间

3. 不可靠
   - 不重传
   - 类似 UDP
```

---

## 3. 创建与配置

### 3.1 创建 DataChannel

```javascript
// 创建 PeerConnection
const pc = new RTCPeerConnection(config);

// 方式 1: 主动创建 (发起方)
const channel = pc.createDataChannel('myChannel', {
    ordered: true,           // 有序传输
    maxRetransmits: 3,       // 最大重传次数
    // maxPacketLifeTime: 3000, // 或最大重传时间 (ms)
    protocol: 'json',        // 子协议
    negotiated: false,       // 是否预协商
    id: null                 // 通道 ID (negotiated=true 时需要)
});

// 方式 2: 被动接收 (应答方)
pc.ondatachannel = (event) => {
    const channel = event.channel;
    setupChannel(channel);
};
```

### 3.2 配置选项

```javascript
// DataChannel 配置选项
const options = {
    // 有序性
    ordered: true,  // true: 有序, false: 无序
    
    // 可靠性 (二选一)
    maxRetransmits: 3,      // 最大重传次数 (不可靠)
    // maxPacketLifeTime: 3000, // 最大重传时间 ms (不可靠)
    // 都不设置 = 完全可靠
    
    // 子协议
    protocol: '',  // 应用层协议标识
    
    // 预协商
    negotiated: false,  // true: 双方预先约定 ID
    id: null,           // 通道 ID (0-65534)
    
    // 优先级 (部分浏览器支持)
    priority: 'high'  // 'very-low', 'low', 'medium', 'high'
};
```

### 3.3 预协商通道

```javascript
// 预协商: 双方使用相同 ID 创建通道
// 优点: 不需要通过信令交换通道信息

// 发起方
const channel1 = pc1.createDataChannel('chat', {
    negotiated: true,
    id: 0
});

// 应答方 (使用相同配置)
const channel2 = pc2.createDataChannel('chat', {
    negotiated: true,
    id: 0
});

// 两个通道自动配对
```

### 3.4 事件处理

```javascript
function setupChannel(channel) {
    // 通道打开
    channel.onopen = () => {
        console.log('DataChannel opened:', channel.label);
        console.log('State:', channel.readyState);
        console.log('Buffered amount:', channel.bufferedAmount);
    };
    
    // 通道关闭
    channel.onclose = () => {
        console.log('DataChannel closed');
    };
    
    // 收到消息
    channel.onmessage = (event) => {
        console.log('Received:', event.data);
        
        // 判断数据类型
        if (typeof event.data === 'string') {
            // 文本消息
            handleTextMessage(event.data);
        } else if (event.data instanceof ArrayBuffer) {
            // 二进制数据
            handleBinaryMessage(event.data);
        } else if (event.data instanceof Blob) {
            // Blob 数据
            handleBlobMessage(event.data);
        }
    };
    
    // 错误处理
    channel.onerror = (error) => {
        console.error('DataChannel error:', error);
    };
    
    // 缓冲区低水位 (可以继续发送)
    channel.onbufferedamountlow = () => {
        console.log('Buffer low, can send more');
    };
}
```

---

## 4. 消息传输

### 4.1 发送消息

```javascript
// 发送文本
channel.send('Hello, World!');

// 发送 JSON
channel.send(JSON.stringify({
    type: 'chat',
    message: 'Hi there!'
}));

// 发送 ArrayBuffer
const buffer = new ArrayBuffer(8);
const view = new Uint8Array(buffer);
view.set([1, 2, 3, 4, 5, 6, 7, 8]);
channel.send(buffer);

// 发送 Blob
const blob = new Blob(['Hello'], { type: 'text/plain' });
channel.send(blob);

// 设置二进制类型
channel.binaryType = 'arraybuffer'; // 或 'blob'
```

### 4.2 流量控制

```javascript
class DataChannelSender {
    constructor(channel) {
        this.channel = channel;
        this.queue = [];
        this.sending = false;
        
        // 设置缓冲区阈值
        this.channel.bufferedAmountLowThreshold = 65536; // 64KB
        
        this.channel.onbufferedamountlow = () => {
            this.processQueue();
        };
    }
    
    send(data) {
        this.queue.push(data);
        this.processQueue();
    }
    
    processQueue() {
        if (this.sending) return;
        this.sending = true;
        
        while (this.queue.length > 0) {
            // 检查缓冲区
            if (this.channel.bufferedAmount > 1048576) { // 1MB
                // 缓冲区满,等待
                this.sending = false;
                return;
            }
            
            const data = this.queue.shift();
            this.channel.send(data);
        }
        
        this.sending = false;
    }
}
```

### 4.3 大文件传输

```javascript
class FileTransfer {
    constructor(channel) {
        this.channel = channel;
        this.chunkSize = 16384; // 16KB
        this.receivedChunks = [];
        this.expectedChunks = 0;
    }
    
    // 发送文件
    async sendFile(file) {
        const totalChunks = Math.ceil(file.size / this.chunkSize);
        
        // 发送文件元信息
        this.channel.send(JSON.stringify({
            type: 'file-start',
            name: file.name,
            size: file.size,
            totalChunks
        }));
        
        // 分片发送
        for (let i = 0; i < totalChunks; i++) {
            const start = i * this.chunkSize;
            const end = Math.min(start + this.chunkSize, file.size);
            const chunk = file.slice(start, end);
            
            // 等待缓冲区
            await this.waitForBuffer();
            
            // 发送分片
            const buffer = await chunk.arrayBuffer();
            this.channel.send(buffer);
            
            // 进度回调
            this.onProgress?.(i + 1, totalChunks);
        }
        
        // 发送完成信号
        this.channel.send(JSON.stringify({
            type: 'file-end'
        }));
    }
    
    waitForBuffer() {
        return new Promise((resolve) => {
            if (this.channel.bufferedAmount < 1048576) {
                resolve();
            } else {
                const check = () => {
                    if (this.channel.bufferedAmount < 1048576) {
                        resolve();
                    } else {
                        setTimeout(check, 10);
                    }
                };
                check();
            }
        });
    }
    
    // 接收文件
    handleMessage(data) {
        if (typeof data === 'string') {
            const msg = JSON.parse(data);
            
            if (msg.type === 'file-start') {
                this.fileName = msg.name;
                this.fileSize = msg.size;
                this.expectedChunks = msg.totalChunks;
                this.receivedChunks = [];
            } else if (msg.type === 'file-end') {
                this.assembleFile();
            }
        } else {
            // 二进制分片
            this.receivedChunks.push(data);
            this.onProgress?.(this.receivedChunks.length, this.expectedChunks);
        }
    }
    
    assembleFile() {
        const blob = new Blob(this.receivedChunks);
        const url = URL.createObjectURL(blob);
        
        // 触发下载
        const a = document.createElement('a');
        a.href = url;
        a.download = this.fileName;
        a.click();
        
        URL.revokeObjectURL(url);
        this.receivedChunks = [];
    }
}
```

---

## 5. 实战应用

### 5.1 实时聊天

```javascript
class ChatChannel {
    constructor(pc) {
        this.channel = pc.createDataChannel('chat', {
            ordered: true
        });
        
        this.setupChannel();
    }
    
    setupChannel() {
        this.channel.onopen = () => {
            console.log('Chat channel ready');
        };
        
        this.channel.onmessage = (event) => {
            const msg = JSON.parse(event.data);
            this.onMessage?.(msg);
        };
    }
    
    sendMessage(text) {
        const msg = {
            type: 'chat',
            text,
            timestamp: Date.now()
        };
        this.channel.send(JSON.stringify(msg));
    }
    
    sendTyping() {
        this.channel.send(JSON.stringify({
            type: 'typing'
        }));
    }
}

// 使用示例
const chat = new ChatChannel(pc);
chat.onMessage = (msg) => {
    if (msg.type === 'chat') {
        displayMessage(msg.text, msg.timestamp);
    } else if (msg.type === 'typing') {
        showTypingIndicator();
    }
};

chat.sendMessage('Hello!');
```

### 5.2 游戏状态同步

```javascript
class GameChannel {
    constructor(pc) {
        // 使用不可靠通道减少延迟
        this.channel = pc.createDataChannel('game', {
            ordered: false,
            maxRetransmits: 0  // 不重传
        });
        
        this.setupChannel();
    }
    
    setupChannel() {
        this.channel.binaryType = 'arraybuffer';
        
        this.channel.onmessage = (event) => {
            const view = new DataView(event.data);
            const type = view.getUint8(0);
            
            switch (type) {
                case 0x01: // 位置更新
                    this.handlePosition(view);
                    break;
                case 0x02: // 动作
                    this.handleAction(view);
                    break;
            }
        };
    }
    
    // 发送位置 (紧凑二进制格式)
    sendPosition(x, y, z, rotation) {
        const buffer = new ArrayBuffer(17);
        const view = new DataView(buffer);
        
        view.setUint8(0, 0x01);        // 类型
        view.setFloat32(1, x);         // X
        view.setFloat32(5, y);         // Y
        view.setFloat32(9, z);         // Z
        view.setFloat32(13, rotation); // 旋转
        
        this.channel.send(buffer);
    }
    
    handlePosition(view) {
        const x = view.getFloat32(1);
        const y = view.getFloat32(5);
        const z = view.getFloat32(9);
        const rotation = view.getFloat32(13);
        
        this.onPositionUpdate?.(x, y, z, rotation);
    }
    
    // 发送动作
    sendAction(actionId) {
        const buffer = new ArrayBuffer(2);
        const view = new DataView(buffer);
        
        view.setUint8(0, 0x02);
        view.setUint8(1, actionId);
        
        this.channel.send(buffer);
    }
}
```

### 5.3 屏幕共享控制

```javascript
class RemoteControl {
    constructor(pc) {
        this.channel = pc.createDataChannel('control', {
            ordered: true
        });
        
        this.setupChannel();
    }
    
    setupChannel() {
        this.channel.onmessage = (event) => {
            const msg = JSON.parse(event.data);
            this.handleControlMessage(msg);
        };
    }
    
    // 发送鼠标事件
    sendMouseMove(x, y) {
        this.channel.send(JSON.stringify({
            type: 'mousemove',
            x, y
        }));
    }
    
    sendMouseClick(x, y, button) {
        this.channel.send(JSON.stringify({
            type: 'click',
            x, y, button
        }));
    }
    
    // 发送键盘事件
    sendKeyPress(key, modifiers) {
        this.channel.send(JSON.stringify({
            type: 'keypress',
            key,
            modifiers
        }));
    }
    
    // 处理控制消息 (被控端)
    handleControlMessage(msg) {
        switch (msg.type) {
            case 'mousemove':
                // 模拟鼠标移动
                break;
            case 'click':
                // 模拟点击
                break;
            case 'keypress':
                // 模拟按键
                break;
        }
    }
}
```

---

## 6. DataChannel vs WebSocket

### 6.1 对比表

| 特性 | DataChannel | WebSocket |
|------|-------------|-----------|
| 连接方式 | P2P | 客户端-服务器 |
| 协议 | SCTP/DTLS/UDP | TCP |
| NAT 穿透 | 需要 ICE | 不需要 |
| 延迟 | 低 | 中 |
| 可靠性 | 可配置 | 完全可靠 |
| 有序性 | 可配置 | 有序 |
| 加密 | DTLS (强制) | TLS (可选) |
| 服务器 | 不需要 | 需要 |

### 6.2 选择建议

```
选择 DataChannel:
- P2P 通信
- 低延迟要求
- 需要不可靠传输
- 已有 WebRTC 连接

选择 WebSocket:
- 需要服务器中转
- 需要广播
- 简单的客户端-服务器通信
- 不需要 P2P
```

### 6.3 混合使用

```javascript
// 混合架构: WebSocket 信令 + DataChannel 数据

class HybridConnection {
    constructor() {
        // WebSocket 用于信令
        this.ws = new WebSocket('wss://server.example.com');
        
        // PeerConnection 用于媒体和数据
        this.pc = new RTCPeerConnection(config);
        
        // DataChannel 用于 P2P 数据
        this.dataChannel = null;
    }
    
    async connect(peerId) {
        // 通过 WebSocket 交换信令
        this.ws.send(JSON.stringify({
            type: 'connect',
            targetId: peerId
        }));
        
        // 创建 DataChannel
        this.dataChannel = this.pc.createDataChannel('data');
        
        // 创建 Offer
        const offer = await this.pc.createOffer();
        await this.pc.setLocalDescription(offer);
        
        // 通过 WebSocket 发送 Offer
        this.ws.send(JSON.stringify({
            type: 'offer',
            targetId: peerId,
            sdp: offer
        }));
    }
    
    // 连接建立后,数据通过 DataChannel 传输
    sendData(data) {
        if (this.dataChannel?.readyState === 'open') {
            this.dataChannel.send(data);
        }
    }
}
```

---

## 7. 总结

### 7.1 核心要点

| 特性 | 说明 |
|------|------|
| 协议 | SCTP over DTLS |
| 可靠性 | 可配置 (可靠/不可靠) |
| 有序性 | 可配置 (有序/无序) |
| 数据类型 | 文本/二进制 |
| 流量控制 | bufferedAmount |

### 7.2 最佳实践

```
DataChannel 最佳实践:

1. 根据场景选择配置
   - 聊天: ordered=true, 可靠
   - 游戏: ordered=false, 不可靠
   - 文件: ordered=true, 可靠

2. 注意流量控制
   - 监控 bufferedAmount
   - 设置 bufferedAmountLowThreshold

3. 大数据分片
   - 单消息限制约 256KB
   - 大文件需要分片

4. 错误处理
   - 监听 onerror
   - 处理连接断开
```

### 7.3 下一篇预告

在下一篇文章中,我们将探讨在移动端使用 WebRTC。

---

## 参考资料

1. [RTCDataChannel API](https://developer.mozilla.org/en-US/docs/Web/API/RTCDataChannel)
2. [RFC 8831 - WebRTC Data Channels](https://datatracker.ietf.org/doc/html/rfc8831)
3. [SCTP Protocol](https://datatracker.ietf.org/doc/html/rfc4960)

---

> 作者: WebRTC 技术专栏  
> 系列: 工程实践 (4/5)  
> 上一篇: [搭建一个 SFU](./23-sfu-setup.md)  
> 下一篇: [在移动端使用 WebRTC](./25-mobile-webrtc.md)
