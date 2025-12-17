---
title: "WebRTC 安全机制 (DTLS、SRTP、ICE、权限管理)"
description: "1. [安全概述](#1-安全概述)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 28
---

> 本文是 WebRTC 系列专栏的第二十八篇,将深入探讨 WebRTC 的安全机制,包括安全威胁、加密机制以及权限模型。

---

## 目录

1. [安全概述](#1-安全概述)
2. [安全威胁](#2-安全威胁)
3. [DTLS 加密](#3-dtls-加密)
4. [SRTP 媒体加密](#4-srtp-媒体加密)
5. [ICE 安全](#5-ice-安全)
6. [权限管理](#6-权限管理)
7. [安全最佳实践](#7-安全最佳实践)
8. [总结](#8-总结)

---

## 1. 安全概述

### 1.1 WebRTC 安全架构

```
WebRTC 安全层次:

+------------------+
|   应用层安全     |  身份认证、授权
+------------------+
|   信令层安全     |  HTTPS/WSS
+------------------+
|   媒体层安全     |  SRTP/SRTCP
+------------------+
|   传输层安全     |  DTLS
+------------------+
|   网络层安全     |  ICE 验证
+------------------+

特点:
- 强制加密 (无明文传输)
- 端到端加密 (媒体)
- 身份验证
- 完整性保护
```

### 1.2 安全目标

```
WebRTC 安全目标:

1. 机密性 (Confidentiality)
   - 媒体数据加密
   - 防止窃听

2. 完整性 (Integrity)
   - 数据完整性校验
   - 防止篡改

3. 认证 (Authentication)
   - 对端身份验证
   - 防止冒充

4. 可用性 (Availability)
   - 防止 DoS 攻击
   - 服务稳定性
```

---

## 2. 安全威胁

### 2.1 威胁模型

```
WebRTC 面临的威胁:

1. 窃听 (Eavesdropping)
   - 网络中间人监听
   - 媒体流截获

2. 中间人攻击 (MITM)
   - 信令篡改
   - 媒体劫持

3. 身份伪造 (Impersonation)
   - 冒充合法用户
   - 伪造身份

4. 拒绝服务 (DoS)
   - 资源耗尽
   - 服务中断

5. 隐私泄露
   - IP 地址暴露
   - 设备指纹
```

### 2.2 攻击场景

```
常见攻击场景:

1. 信令劫持
   攻击者 ──> 篡改 SDP ──> 替换 ICE 候选
   结果: 媒体流被重定向

2. SRTP 密钥窃取
   攻击者 ──> 破解 DTLS ──> 获取 SRTP 密钥
   结果: 媒体被解密

3. ICE 候选注入
   攻击者 ──> 注入恶意候选 ──> 流量劫持
   结果: 媒体流被截获

4. 资源耗尽
   攻击者 ──> 大量连接请求 ──> 服务器过载
   结果: 服务不可用
```

### 2.3 IP 地址泄露

```javascript
// IP 泄露风险
// WebRTC 会收集所有网络接口的 IP

// 防护措施 1: 使用 TURN 中继
const config = {
    iceServers: [
        { urls: 'turn:turn.example.com', username: 'user', credential: 'pass' }
    ],
    iceTransportPolicy: 'relay'  // 只使用 TURN
};

// 防护措施 2: 限制 ICE 候选类型
pc.onicecandidate = (event) => {
    if (event.candidate) {
        // 过滤掉 host 候选
        if (event.candidate.type !== 'host') {
            sendCandidate(event.candidate);
        }
    }
};

// 浏览器设置 (Chrome)
// chrome://flags/#enable-webrtc-hide-local-ips-with-mdns
```

---

## 3. DTLS 加密

### 3.1 DTLS 概述

```
DTLS (Datagram Transport Layer Security):

- TLS 的 UDP 版本
- 提供加密和认证
- WebRTC 强制使用

DTLS 版本:
- DTLS 1.0 (基于 TLS 1.1)
- DTLS 1.2 (基于 TLS 1.2) - WebRTC 推荐
- DTLS 1.3 (基于 TLS 1.3) - 未来
```

### 3.2 DTLS 握手流程

```
DTLS 握手:

客户端                                服务端
   |                                    |
   |  ClientHello                       |
   | ---------------------------------> |
   |                                    |
   |  HelloVerifyRequest (Cookie)       |
   | <--------------------------------- |
   |                                    |
   |  ClientHello (with Cookie)         |
   | ---------------------------------> |
   |                                    |
   |  ServerHello                       |
   |  Certificate                       |
   |  ServerKeyExchange                 |
   |  CertificateRequest                |
   |  ServerHelloDone                   |
   | <--------------------------------- |
   |                                    |
   |  Certificate                       |
   |  ClientKeyExchange                 |
   |  CertificateVerify                 |
   |  ChangeCipherSpec                  |
   |  Finished                          |
   | ---------------------------------> |
   |                                    |
   |  ChangeCipherSpec                  |
   |  Finished                          |
   | <--------------------------------- |
   |                                    |
   |  ====== 加密通信开始 ======        |
```

### 3.3 证书指纹验证

```javascript
// SDP 中的证书指纹
// a=fingerprint:sha-256 AB:CD:EF:...

// 验证流程:
// 1. 信令交换 SDP (包含指纹)
// 2. DTLS 握手交换证书
// 3. 计算证书指纹
// 4. 与 SDP 中的指纹比对
// 5. 匹配则验证通过

// 获取本地证书指纹
async function getLocalFingerprint(pc) {
    const stats = await pc.getStats();
    let fingerprint = null;
    
    stats.forEach(report => {
        if (report.type === 'certificate') {
            fingerprint = report.fingerprint;
        }
    });
    
    return fingerprint;
}

// 验证远程指纹
function verifyRemoteFingerprint(remoteSdp, expectedFingerprint) {
    const match = remoteSdp.match(/a=fingerprint:sha-256 ([^\r\n]+)/);
    if (match) {
        return match[1] === expectedFingerprint;
    }
    return false;
}
```

### 3.4 密码套件

```
WebRTC 支持的密码套件:

推荐:
- TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
- TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256

支持:
- TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA
- TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA

密钥交换: ECDHE (椭圆曲线 Diffie-Hellman)
认证: ECDSA 或 RSA
加密: AES-128-GCM 或 AES-256-CBC
哈希: SHA-256
```

---

## 4. SRTP 媒体加密

### 4.1 SRTP 概述

```
SRTP (Secure Real-time Transport Protocol):

功能:
- RTP 数据加密
- 数据完整性
- 重放攻击防护

SRTP 包结构:
+--------------------+
|    RTP Header      |  (明文)
+--------------------+
|  Encrypted Payload |  (密文)
+--------------------+
| Authentication Tag |  (HMAC)
+--------------------+
```

### 4.2 SRTP 密钥导出

```
DTLS-SRTP 密钥导出:

DTLS 主密钥
     |
     v
+--------------------+
|  PRF (伪随机函数)   |
+--------------------+
     |
     +---> 客户端写密钥
     |
     +---> 服务端写密钥
     |
     +---> 客户端写盐值
     |
     +---> 服务端写盐值

密钥材料:
- 加密密钥: 128 位 (AES-128)
- 盐值: 112 位
- 认证密钥: 从主密钥导出
```

### 4.3 SRTP 加密过程

```javascript
// SRTP 加密伪代码
class SrtpEncryptor {
    constructor(key, salt) {
        this.key = key;
        this.salt = salt;
        this.roc = 0;  // 翻转计数器
    }
    
    encrypt(rtpPacket) {
        // 1. 构造 IV
        const ssrc = rtpPacket.ssrc;
        const seq = rtpPacket.sequenceNumber;
        const iv = this.generateIV(ssrc, seq);
        
        // 2. AES-CTR 加密负载
        const encryptedPayload = this.aesCtrEncrypt(
            rtpPacket.payload,
            this.key,
            iv
        );
        
        // 3. 计算认证标签
        const authTag = this.hmacSha1(
            rtpPacket.header + encryptedPayload,
            this.authKey
        );
        
        // 4. 组装 SRTP 包
        return {
            header: rtpPacket.header,
            payload: encryptedPayload,
            authTag: authTag.slice(0, 10)  // 80 位
        };
    }
    
    generateIV(ssrc, seq) {
        // IV = salt XOR (SSRC || ROC || SEQ)
        const packetIndex = (this.roc << 16) | seq;
        // ... 计算 IV
    }
}
```

### 4.4 SRTCP 加密

```
SRTCP 与 SRTP 的区别:

1. 加密范围
   - SRTP: 只加密负载
   - SRTCP: 加密整个复合包

2. 认证范围
   - SRTP: Header + Payload
   - SRTCP: 整个包 + E 标志 + SRTCP 索引

3. 索引
   - SRTP: 使用 ROC + SEQ
   - SRTCP: 使用 31 位 SRTCP 索引

SRTCP 包结构:
+--------------------+
|   RTCP Header      |
+--------------------+
| Encrypted Content  |
+--------------------+
|   E | SRTCP Index  |  (E=1 表示加密)
+--------------------+
| Authentication Tag |
+--------------------+
```

---

## 5. ICE 安全

### 5.1 ICE 认证

```
ICE 认证机制:

1. 短期凭证
   - ufrag: ICE 用户名片段
   - pwd: ICE 密码
   - 在 SDP 中交换

2. STUN 消息认证
   - MESSAGE-INTEGRITY 属性
   - HMAC-SHA1 计算
   - 使用 ICE 密码

SDP 示例:
a=ice-ufrag:F7gI
a=ice-pwd:x9cml/YzichV2+XlhiMu8g

STUN Binding Request:
- USERNAME: 远端ufrag:本地ufrag
- MESSAGE-INTEGRITY: HMAC(远端pwd)
```

### 5.2 ICE 安全验证

```javascript
// ICE 凭证验证
class IceCredentialValidator {
    constructor(localUfrag, localPwd, remoteUfrag, remotePwd) {
        this.localUfrag = localUfrag;
        this.localPwd = localPwd;
        this.remoteUfrag = remoteUfrag;
        this.remotePwd = remotePwd;
    }
    
    validateRequest(stunMessage) {
        // 1. 验证 USERNAME 格式
        const username = stunMessage.getAttribute('USERNAME');
        const expectedUsername = `${this.localUfrag}:${this.remoteUfrag}`;
        
        if (username !== expectedUsername) {
            return false;
        }
        
        // 2. 验证 MESSAGE-INTEGRITY
        const messageIntegrity = stunMessage.getAttribute('MESSAGE-INTEGRITY');
        const computed = this.computeHmac(stunMessage, this.localPwd);
        
        return messageIntegrity === computed;
    }
    
    computeHmac(message, key) {
        // HMAC-SHA1 计算
        // 消息不包含 MESSAGE-INTEGRITY 和 FINGERPRINT
    }
}
```

### 5.3 防止 ICE 攻击

```javascript
// 防止 ICE 候选注入攻击
class IceCandidateValidator {
    constructor() {
        this.allowedTypes = ['host', 'srflx', 'relay'];
        this.trustedTurnServers = ['turn.example.com'];
    }
    
    validate(candidate) {
        // 1. 检查候选类型
        if (!this.allowedTypes.includes(candidate.type)) {
            return false;
        }
        
        // 2. 检查 relay 候选的服务器
        if (candidate.type === 'relay') {
            const relayAddress = candidate.relatedAddress;
            if (!this.trustedTurnServers.includes(relayAddress)) {
                return false;
            }
        }
        
        // 3. 检查 IP 地址格式
        if (!this.isValidIp(candidate.address)) {
            return false;
        }
        
        return true;
    }
    
    isValidIp(ip) {
        // IPv4 或 IPv6 格式验证
        const ipv4Regex = /^(\d{1,3}\.){3}\d{1,3}$/;
        const ipv6Regex = /^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$/;
        return ipv4Regex.test(ip) || ipv6Regex.test(ip);
    }
}
```

---

## 6. 权限管理

### 6.1 浏览器权限模型

```
浏览器媒体权限:

1. 权限类型
   - camera: 摄像头
   - microphone: 麦克风
   - display-capture: 屏幕共享

2. 权限状态
   - granted: 已授权
   - denied: 已拒绝
   - prompt: 待询问

3. 权限范围
   - 按源 (origin) 隔离
   - 持久化存储
   - 可随时撤销
```

### 6.2 权限请求

```javascript
// 检查权限状态
async function checkPermissions() {
    const permissions = {};
    
    try {
        const camera = await navigator.permissions.query({ name: 'camera' });
        permissions.camera = camera.state;
        
        const microphone = await navigator.permissions.query({ name: 'microphone' });
        permissions.microphone = microphone.state;
    } catch (error) {
        console.error('Permission query failed:', error);
    }
    
    return permissions;
}

// 请求权限
async function requestMediaPermissions() {
    try {
        const stream = await navigator.mediaDevices.getUserMedia({
            video: true,
            audio: true
        });
        
        // 权限已授予
        stream.getTracks().forEach(track => track.stop());
        return true;
    } catch (error) {
        if (error.name === 'NotAllowedError') {
            console.log('Permission denied');
        } else if (error.name === 'NotFoundError') {
            console.log('No media devices found');
        }
        return false;
    }
}

// 监听权限变化
async function watchPermissions() {
    const camera = await navigator.permissions.query({ name: 'camera' });
    
    camera.onchange = () => {
        console.log('Camera permission changed:', camera.state);
        if (camera.state === 'denied') {
            handlePermissionDenied();
        }
    };
}
```

### 6.3 安全上下文要求

```
WebRTC 安全上下文要求:

1. HTTPS 要求
   - getUserMedia 需要安全上下文
   - 本地开发: localhost 例外
   - 生产环境: 必须 HTTPS

2. 跨域限制
   - 同源策略
   - CORS 配置

3. iframe 限制
   - 需要 allow 属性
   - <iframe allow="camera; microphone">

// 检查安全上下文
if (window.isSecureContext) {
    console.log('Secure context - WebRTC available');
} else {
    console.log('Insecure context - WebRTC may be limited');
}
```

### 6.4 信令安全

```javascript
// 信令服务器安全配置
const https = require('https');
const fs = require('fs');
const WebSocket = require('ws');

// HTTPS 服务器
const server = https.createServer({
    cert: fs.readFileSync('/path/to/cert.pem'),
    key: fs.readFileSync('/path/to/key.pem')
});

// WSS WebSocket
const wss = new WebSocket.Server({ server });

// 身份验证中间件
wss.on('connection', (ws, req) => {
    // 验证 JWT token
    const token = req.headers['authorization'];
    
    if (!verifyToken(token)) {
        ws.close(4001, 'Unauthorized');
        return;
    }
    
    // 设置用户信息
    ws.userId = decodeToken(token).userId;
});

// 消息验证
function validateMessage(message, userId) {
    // 检查消息格式
    if (!message.type || !message.data) {
        return false;
    }
    
    // 检查权限
    if (message.type === 'offer' || message.type === 'answer') {
        // 验证用户是否有权限发送给目标
        return checkPermission(userId, message.targetId);
    }
    
    return true;
}
```

---

## 7. 安全最佳实践

### 7.1 安全检查清单

```
WebRTC 安全检查清单:

[ ] 使用 HTTPS/WSS 传输信令
[ ] 验证 DTLS 证书指纹
[ ] 实现用户身份认证
[ ] 验证 ICE 候选来源
[ ] 限制媒体权限范围
[ ] 实现速率限制
[ ] 记录安全日志
[ ] 定期安全审计
```

### 7.2 安全配置示例

```javascript
// 安全的 PeerConnection 配置
const secureConfig = {
    iceServers: [
        {
            urls: 'turns:turn.example.com:443',
            username: 'user',
            credential: 'pass'
        }
    ],
    // 只使用 TURN (隐藏真实 IP)
    iceTransportPolicy: 'relay',
    // 使用 bundle 减少端口
    bundlePolicy: 'max-bundle',
    // 使用 RTCP mux
    rtcpMuxPolicy: 'require',
    // 证书配置
    certificates: [await RTCPeerConnection.generateCertificate({
        name: 'ECDSA',
        namedCurve: 'P-256'
    })]
};

const pc = new RTCPeerConnection(secureConfig);
```

### 7.3 端到端加密 (E2EE)

```javascript
// 端到端加密 (使用 Insertable Streams)
class E2EEManager {
    constructor() {
        this.key = null;
    }
    
    async generateKey() {
        this.key = await crypto.subtle.generateKey(
            { name: 'AES-GCM', length: 256 },
            true,
            ['encrypt', 'decrypt']
        );
    }
    
    setupSenderTransform(sender) {
        const senderStreams = sender.createEncodedStreams();
        const transformStream = new TransformStream({
            transform: async (chunk, controller) => {
                const encrypted = await this.encryptFrame(chunk);
                controller.enqueue(encrypted);
            }
        });
        
        senderStreams.readable
            .pipeThrough(transformStream)
            .pipeTo(senderStreams.writable);
    }
    
    setupReceiverTransform(receiver) {
        const receiverStreams = receiver.createEncodedStreams();
        const transformStream = new TransformStream({
            transform: async (chunk, controller) => {
                const decrypted = await this.decryptFrame(chunk);
                controller.enqueue(decrypted);
            }
        });
        
        receiverStreams.readable
            .pipeThrough(transformStream)
            .pipeTo(receiverStreams.writable);
    }
    
    async encryptFrame(frame) {
        const iv = crypto.getRandomValues(new Uint8Array(12));
        const encrypted = await crypto.subtle.encrypt(
            { name: 'AES-GCM', iv },
            this.key,
            frame.data
        );
        
        // 组合 IV + 密文
        const result = new Uint8Array(iv.length + encrypted.byteLength);
        result.set(iv);
        result.set(new Uint8Array(encrypted), iv.length);
        
        frame.data = result.buffer;
        return frame;
    }
    
    async decryptFrame(frame) {
        const data = new Uint8Array(frame.data);
        const iv = data.slice(0, 12);
        const ciphertext = data.slice(12);
        
        const decrypted = await crypto.subtle.decrypt(
            { name: 'AES-GCM', iv },
            this.key,
            ciphertext
        );
        
        frame.data = decrypted;
        return frame;
    }
}
```

---

## 8. 总结

### 8.1 安全层次总结

| 层次 | 机制 | 保护目标 |
|------|------|---------|
| 信令层 | HTTPS/WSS | 信令数据 |
| 传输层 | DTLS | 密钥交换 |
| 媒体层 | SRTP | 音视频数据 |
| 网络层 | ICE 认证 | 连接建立 |
| 应用层 | E2EE | 端到端隐私 |

### 8.2 安全建议

```
WebRTC 安全建议:

1. 基础安全
   - 始终使用 HTTPS
   - 验证证书指纹
   - 实现用户认证

2. 隐私保护
   - 使用 TURN 隐藏 IP
   - 限制设备信息暴露
   - 实现 E2EE

3. 运维安全
   - 定期更新依赖
   - 监控异常行为
   - 安全日志审计
```

### 8.3 下一篇预告

在下一篇文章中,我们将构建一个完整的 WebRTC 通信系统。

---

## 参考资料

1. [RFC 5764 - DTLS-SRTP](https://datatracker.ietf.org/doc/html/rfc5764)
2. [RFC 3711 - SRTP](https://datatracker.ietf.org/doc/html/rfc3711)
3. [WebRTC Security](https://webrtc-security.github.io/)

---

> 作者: WebRTC 技术专栏  
> 系列: 高级主题与优化 (3/4)  
> 上一篇: [WebRTC 质量优化](./27-quality-optimization.md)  
> 下一篇: [构建完整的 WebRTC 通信系统](./29-complete-system.md)
