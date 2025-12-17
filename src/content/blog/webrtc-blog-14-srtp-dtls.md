---
title: "SRTP: 安全加密传输层 (DTLS-SRTP)"
description: "1. [安全传输概述](#1-安全传输概述)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 14
---

> 本文是 WebRTC 系列专栏的第十四篇,将深入剖析 WebRTC 的安全传输机制,包括 DTLS 握手过程、SRTP 密钥导出以及加密解密流程。

---

## 目录

1. [安全传输概述](#1-安全传输概述)
2. [DTLS 握手](#2-dtls-握手)
3. [SRTP 密钥导出](#3-srtp-密钥导出)
4. [SRTP 加密流程](#4-srtp-加密流程)
5. [SRTCP 加密](#5-srtcp-加密)
6. [总结](#6-总结)

---

## 1. 安全传输概述

### 1.1 WebRTC 安全架构

```
+-------------------------------------------------------------------+
|                      WebRTC 安全层次                               |
+-------------------------------------------------------------------+
|                                                                   |
|   应用数据 (音视频/DataChannel)                                    |
|        |                                                          |
|        v                                                          |
|   +------------------+    +------------------+                    |
|   |      SRTP        |    |      SCTP        |                    |
|   | (媒体数据加密)    |    | (数据通道)       |                    |
|   +------------------+    +------------------+                    |
|        |                        |                                 |
|        +------------------------+                                 |
|                    |                                              |
|                    v                                              |
|   +------------------+                                            |
|   |      DTLS        |                                            |
|   | (密钥交换/认证)   |                                            |
|   +------------------+                                            |
|        |                                                          |
|        v                                                          |
|   +------------------+                                            |
|   |      ICE/UDP     |                                            |
|   +------------------+                                            |
|                                                                   |
+-------------------------------------------------------------------+
```

### 1.2 为什么使用 DTLS-SRTP

| 方案 | 说明 | WebRTC 选择 |
|------|------|-------------|
| SDES | SDP 中明文传输密钥 | 不安全,不使用 |
| DTLS-SRTP | DTLS 握手交换密钥 | 强制使用 |
| ZRTP | 端到端密钥协商 | 可选 |

DTLS-SRTP 优势:
- 端到端加密
- 完美前向保密 (PFS)
- 身份验证 (通过 fingerprint)

---

## 2. DTLS 握手

### 2.1 DTLS vs TLS

| 特性 | TLS | DTLS |
|------|-----|------|
| 传输层 | TCP | UDP |
| 可靠性 | 依赖 TCP | 自己处理重传 |
| 顺序 | 依赖 TCP | 自己处理乱序 |
| 版本 | 1.2, 1.3 | 1.0, 1.2 |

### 2.2 DTLS 握手流程

```
Client                                          Server
   |                                               |
   |  ClientHello                                  |
   |  (随机数, 密码套件列表)                        |
   | --------------------------------------------> |
   |                                               |
   |  HelloVerifyRequest                           |
   |  (Cookie)                                     |
   | <-------------------------------------------- |
   |                                               |
   |  ClientHello                                  |
   |  (带 Cookie)                                  |
   | --------------------------------------------> |
   |                                               |
   |  ServerHello                                  |
   |  Certificate                                  |
   |  ServerKeyExchange                            |
   |  CertificateRequest                           |
   |  ServerHelloDone                              |
   | <-------------------------------------------- |
   |                                               |
   |  Certificate                                  |
   |  ClientKeyExchange                            |
   |  CertificateVerify                            |
   |  ChangeCipherSpec                             |
   |  Finished                                     |
   | --------------------------------------------> |
   |                                               |
   |  ChangeCipherSpec                             |
   |  Finished                                     |
   | <-------------------------------------------- |
   |                                               |
   |  ========= DTLS 握手完成 =========            |
   |                                               |
```

### 2.3 HelloVerifyRequest

DTLS 特有的防 DoS 机制:

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|     server_version            |      cookie_length            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         cookie                                |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

作用:
1. 验证客户端地址真实性
2. 防止 IP 欺骗攻击
3. 减轻放大攻击
```

### 2.4 证书验证

WebRTC 使用自签名证书,通过 SDP fingerprint 验证:

```
SDP 中:
a=fingerprint:sha-256 AA:BB:CC:DD:EE:FF:...

验证流程:
1. 收到对方 DTLS 证书
2. 计算证书的 SHA-256 哈希
3. 与 SDP 中的 fingerprint 比较
4. 匹配则验证通过
```

### 2.5 DTLS 角色

```
SDP 中的 setup 属性:

Offer:  a=setup:actpass  (可以是客户端或服务端)
Answer: a=setup:active   (作为 DTLS 客户端)
        a=setup:passive  (作为 DTLS 服务端)

通常:
- Answer 方选择 active,主动发起握手
- Offer 方作为 passive,等待握手
```

---

## 3. SRTP 密钥导出

### 3.1 密钥导出过程

```
DTLS 握手完成后:

                    Master Secret
                         |
                         v
            +------------------------+
            |    Key Derivation      |
            |    Function (KDF)      |
            +------------------------+
                         |
     +-------------------+-------------------+
     |                   |                   |
     v                   v                   v
Client Write Key   Server Write Key    Salt
```

### 3.2 SRTP 密钥材料

```
使用 DTLS-SRTP 扩展导出密钥:

PRF(master_secret, "EXTRACTOR-dtls_srtp",
    client_random + server_random)

导出的密钥材料:
+------------------+------------------+
| Client Write Key | 16 bytes (AES-128) |
+------------------+------------------+
| Server Write Key | 16 bytes         |
+------------------+------------------+
| Client Write Salt| 14 bytes         |
+------------------+------------------+
| Server Write Salt| 14 bytes         |
+------------------+------------------+

总计: 60 bytes
```

### 3.3 密码套件

WebRTC 常用的 SRTP 密码套件:

| 套件 | 加密 | 认证 | 密钥长度 |
|------|------|------|---------|
| AES_CM_128_HMAC_SHA1_80 | AES-CM | HMAC-SHA1 | 128 bits |
| AES_CM_128_HMAC_SHA1_32 | AES-CM | HMAC-SHA1 | 128 bits |
| AEAD_AES_128_GCM | AES-GCM | - | 128 bits |
| AEAD_AES_256_GCM | AES-GCM | - | 256 bits |

---

## 4. SRTP 加密流程

### 4.1 SRTP 包结构

```
RTP 包:
+------------------+------------------+
| RTP Header (12B) | Payload          |
+------------------+------------------+

SRTP 包:
+------------------+------------------+------------------+
| RTP Header (12B) | Encrypted Payload| Auth Tag (10B)  |
+------------------+------------------+------------------+

注意:
- RTP Header 不加密,但包含在认证范围内
- Payload 加密
- Auth Tag 用于完整性验证
```

### 4.2 加密过程

```
加密步骤:

1. 生成会话密钥
   session_key = KDF(master_key, label, index)

2. 生成密钥流
   keystream = AES_CM(session_key, IV)
   
   IV = salt XOR (SSRC || ROC || SEQ)

3. 加密负载
   encrypted_payload = payload XOR keystream

4. 计算认证标签
   auth_tag = HMAC_SHA1(auth_key, header || encrypted_payload)

5. 组装 SRTP 包
   srtp_packet = header || encrypted_payload || auth_tag
```

### 4.3 AES Counter Mode

```
AES-CM 密钥流生成:

IV (128 bits):
+------------------+------------------+------------------+
|   Salt (112b)    |    0 (16b)       |                  |
+------------------+------------------+------------------+
        XOR
+------------------+------------------+------------------+
|   SSRC (32b)     |   ROC+SEQ (48b)  |   Counter (16b)  |
+------------------+------------------+------------------+
        =
+------------------+------------------+------------------+
|                    IV (128 bits)                       |
+------------------+------------------+------------------+

Keystream:
Block 0: AES(key, IV || 0)
Block 1: AES(key, IV || 1)
Block 2: AES(key, IV || 2)
...
```

### 4.4 ROC (Rollover Counter)

```
ROC 用于扩展序列号空间:

RTP 序列号: 16 bits (0-65535)
ROC: 32 bits

扩展序列号 = (ROC << 16) | SEQ

序列号回绕时:
SEQ: 65534 -> 65535 -> 0 -> 1
ROC:   0   ->   0   -> 1 -> 1

ROC 同步:
- 发送端和接收端独立维护
- 通过序列号跳变检测回绕
```

### 4.5 解密过程

```javascript
// SRTP 解密示例
function decryptSrtp(srtpPacket, sessionKey, authKey, salt) {
    // 1. 分离各部分
    const header = srtpPacket.slice(0, 12);
    const encryptedPayload = srtpPacket.slice(12, -10);
    const authTag = srtpPacket.slice(-10);
    
    // 2. 验证认证标签
    const expectedTag = hmacSha1(authKey, 
        Buffer.concat([header, encryptedPayload])).slice(0, 10);
    
    if (!authTag.equals(expectedTag)) {
        throw new Error('Authentication failed');
    }
    
    // 3. 提取序列号和 SSRC
    const seq = header.readUInt16BE(2);
    const ssrc = header.readUInt32BE(8);
    
    // 4. 计算 IV
    const iv = computeIV(salt, ssrc, roc, seq);
    
    // 5. 生成密钥流
    const keystream = aesCM(sessionKey, iv, encryptedPayload.length);
    
    // 6. 解密
    const payload = xor(encryptedPayload, keystream);
    
    return Buffer.concat([header, payload]);
}
```

---

## 5. SRTCP 加密

### 5.1 SRTCP 包结构

```
RTCP 包:
+------------------+------------------+
| RTCP Header      | RTCP Payload     |
+------------------+------------------+

SRTCP 包:
+------------------+------------------+------------------+------------------+
| RTCP Header      | Encrypted Payload| SRTCP Index (4B) | Auth Tag (10B)  |
+------------------+------------------+------------------+------------------+

SRTCP Index:
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|E|                         SRTCP Index                         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

E: 加密标志 (1=加密, 0=未加密)
SRTCP Index: 31 bits 序列号
```

### 5.2 SRTCP vs SRTP

| 特性 | SRTP | SRTCP |
|------|------|-------|
| 序列号 | RTP 序列号 + ROC | SRTCP Index |
| 加密范围 | Payload | Payload (可选) |
| 认证范围 | Header + Payload | 全部 |
| E 标志 | 无 | 有 |

---

## 6. 总结

### 6.1 DTLS-SRTP 核心要点

| 要点 | 说明 |
|------|------|
| DTLS | UDP 上的 TLS,用于密钥交换 |
| 证书验证 | 通过 SDP fingerprint |
| 密钥导出 | 从 DTLS master secret 导出 |
| SRTP 加密 | AES-CM + HMAC-SHA1 |
| 认证 | 10 字节 Auth Tag |

### 6.2 安全保障

```
DTLS-SRTP 提供:
1. 机密性 - AES 加密
2. 完整性 - HMAC 认证
3. 身份验证 - 证书 + fingerprint
4. 前向保密 - ECDHE 密钥交换
5. 防重放 - 序列号检查
```

### 6.3 下一篇预告

在下一篇文章中,我们将探讨抖动缓冲区与网络抗性机制。

---

## 参考资料

1. [RFC 3711 - SRTP](https://datatracker.ietf.org/doc/html/rfc3711)
2. [RFC 5764 - DTLS-SRTP](https://datatracker.ietf.org/doc/html/rfc5764)
3. [RFC 6347 - DTLS 1.2](https://datatracker.ietf.org/doc/html/rfc6347)

---

> 作者: WebRTC 技术专栏  
> 系列: 媒体传输深入讲解 (3/6)  
> 上一篇: [RTCP: 统计、同步与网络自适应](./13-rtcp-protocol.md)  
> 下一篇: [抖动缓冲区与网络抗性](./15-jitter-buffer.md)
