---
title: "STUN: 外网地址发现 (含协议解析)"
description: "1. [STUN 概述](#1-stun-概述)"
pubDate: "2025-12-17"
tags: ["webrtc","audio","video"]
category: "webrtc"
series: "WebRTC 音视频开发"
order: 9
---

> 本文是 WebRTC 系列专栏的第九篇,将深入剖析 STUN 协议的工作原理、消息格式以及如何搭建 STUN 服务器。

---

## 目录

1. [STUN 概述](#1-stun-概述)
2. [STUN 协议格式](#2-stun-协议格式)
3. [STUN Binding 请求与响应](#3-stun-binding-请求与响应)
4. [STUN 属性详解](#4-stun-属性详解)
5. [NAT 类型检测](#5-nat-类型检测)
6. [STUN 服务器搭建](#6-stun-服务器搭建)
7. [总结](#7-总结)

---

## 1. STUN 概述

### 1.1 什么是 STUN

STUN (Session Traversal Utilities for NAT) 是一种网络协议,用于发现 NAT 设备并获取经过 NAT 映射后的公网地址。STUN 定义在 RFC 5389 中。

### 1.2 STUN 的作用

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        STUN 的核心作用                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   1. 发现公网地址                                                        │
│      客户端位于 NAT 后面,不知道自己的公网 IP 和端口                       │
│      STUN 服务器告诉客户端: "你的公网地址是 x.x.x.x:port"                │
│                                                                         │
│   2. 检测 NAT 类型                                                       │
│      不同类型的 NAT 有不同的穿透难度                                     │
│      STUN 可以帮助检测 NAT 的行为特征                                    │
│                                                                         │
│   3. 保持 NAT 映射                                                       │
│      NAT 映射有超时时间                                                  │
│      定期发送 STUN 请求可以保持映射活跃                                  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.3 STUN 工作原理

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        STUN 工作原理                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   客户端                          NAT                    STUN 服务器    │
│   192.168.1.100:5000                                    203.0.113.50   │
│        │                           │                         │         │
│        │  1. STUN Binding Request  │                         │         │
│        │  src: 192.168.1.100:5000  │                         │         │
│        │  dst: 203.0.113.50:3478   │                         │         │
│        │ ─────────────────────────>│                         │         │
│        │                           │                         │         │
│        │                           │  2. NAT 转换            │         │
│        │                           │  src: 1.2.3.4:12345     │         │
│        │                           │  dst: 203.0.113.50:3478 │         │
│        │                           │ ───────────────────────>│         │
│        │                           │                         │         │
│        │                           │  3. 服务器看到的源地址:  │         │
│        │                           │     1.2.3.4:12345       │         │
│        │                           │                         │         │
│        │                           │  4. STUN Binding Response         │
│        │                           │  XOR-MAPPED-ADDRESS:    │         │
│        │                           │  1.2.3.4:12345          │         │
│        │                           │<─────────────────────── │         │
│        │                           │                         │         │
│        │  5. 响应转发              │                         │         │
│        │<───────────────────────── │                         │         │
│        │                           │                         │         │
│        │  6. 客户端获知公网地址:                             │         │
│        │     1.2.3.4:12345                                   │         │
│        │                                                     │         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. STUN 协议格式

### 2.1 STUN 消息结构

所有 STUN 消息都遵循相同的格式:

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|0 0|     STUN Message Type     |         Message Length        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         Magic Cookie                          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                                                               |
|                     Transaction ID (96 bits)                  |
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         Attributes...                         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 2.2 消息头字段

| 字段 | 大小 | 说明 |
|------|------|------|
| 前两位 | 2 bits | 固定为 00,用于区分 STUN 和其他协议 |
| Message Type | 14 bits | 消息类型 |
| Message Length | 16 bits | 消息体长度 (不含头部) |
| Magic Cookie | 32 bits | 固定值 0x2112A442 |
| Transaction ID | 96 bits | 事务标识符 |

### 2.3 消息类型

消息类型由 14 位组成,包含方法 (Method) 和类别 (Class):

```
        0                 1
        0 1 2 3 4 5 6 7 8 9 0 1 2 3
       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+
       |M|M|M|M|M|C|M|M|M|C|M|M|M|M|
       |B|A|9|8|7|1|6|5|4|0|3|2|1|0|
       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+

M = Method bits (M0-MB)
C = Class bits (C0-C1)
```

类别 (Class):

| C1 | C0 | 类别 | 说明 |
|----|----|----|------|
| 0 | 0 | Request | 请求 |
| 0 | 1 | Indication | 指示 (无需响应) |
| 1 | 0 | Success Response | 成功响应 |
| 1 | 1 | Error Response | 错误响应 |

方法 (Method):

| 值 | 方法 | 说明 |
|----|------|------|
| 0x001 | Binding | 绑定请求 |
| 0x003 | Allocate | TURN 分配 |
| 0x004 | Refresh | TURN 刷新 |
| 0x006 | Send | TURN 发送 |
| 0x007 | Data | TURN 数据 |
| 0x008 | CreatePermission | TURN 创建权限 |
| 0x009 | ChannelBind | TURN 通道绑定 |

常见消息类型:

| 消息类型 | 值 | 说明 |
|---------|-----|------|
| Binding Request | 0x0001 | 绑定请求 |
| Binding Response | 0x0101 | 绑定成功响应 |
| Binding Error Response | 0x0111 | 绑定错误响应 |
| Binding Indication | 0x0011 | 绑定指示 |

### 2.4 Magic Cookie

Magic Cookie 是固定值 0x2112A442,用于:

1. 区分 STUN 和旧版协议 (RFC 3489)
2. 用于 XOR 编码地址

### 2.5 Transaction ID

Transaction ID 是 96 位 (12 字节) 的随机值,用于:

1. 匹配请求和响应
2. 防止重放攻击

---

## 3. STUN Binding 请求与响应

### 3.1 Binding Request

Binding Request 是最常用的 STUN 消息,用于发现公网地址。

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Binding Request 示例                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   00 01 00 00                    Message Type: Binding Request (0x0001) │
│                                  Message Length: 0                      │
│   21 12 A4 42                    Magic Cookie: 0x2112A442               │
│   74 72 61 6E 73 61 63 74        Transaction ID (12 bytes)              │
│   69 6F 6E 49                                                           │
│                                                                         │
│   完整的 20 字节请求 (无属性):                                           │
│   00 01 00 00 21 12 A4 42 74 72 61 6E 73 61 63 74 69 6F 6E 49           │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Binding Response

成功的 Binding Response 包含 XOR-MAPPED-ADDRESS 属性。

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Binding Response 示例                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   01 01 00 0C                    Message Type: Binding Response (0x0101)│
│                                  Message Length: 12                     │
│   21 12 A4 42                    Magic Cookie: 0x2112A442               │
│   74 72 61 6E 73 61 63 74        Transaction ID (与请求相同)             │
│   69 6F 6E 49                                                           │
│                                                                         │
│   属性:                                                                 │
│   00 20 00 08                    Attribute Type: XOR-MAPPED-ADDRESS     │
│                                  Attribute Length: 8                    │
│   00 01 E1 BA                    Family: IPv4, XOR'd Port               │
│   20 10 A5 46                    XOR'd IP Address                       │
│                                                                         │
│   解码后:                                                               │
│   Port: 0xE1BA XOR 0x2112 = 0xC0A8 = 49320                             │
│   IP: 0x2010A546 XOR 0x2112A442 = 0x01020304 = 1.2.3.4                 │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.3 Binding Error Response

当请求失败时,服务器返回错误响应。

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Binding Error Response 示例                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   01 11 00 14                    Message Type: Error Response (0x0111)  │
│                                  Message Length: 20                     │
│   21 12 A4 42                    Magic Cookie                           │
│   74 72 61 6E 73 61 63 74        Transaction ID                         │
│   69 6F 6E 49                                                           │
│                                                                         │
│   属性:                                                                 │
│   00 09 00 10                    Attribute Type: ERROR-CODE             │
│                                  Attribute Length: 16                   │
│   00 00 04 01                    Class: 4, Number: 1 (401)              │
│   55 6E 61 75 74 68 6F 72        Reason: "Unauthorized"                 │
│   69 7A 65 64                                                           │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.4 请求/响应流程

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        STUN 请求/响应流程                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   客户端                                              STUN 服务器       │
│      │                                                     │            │
│      │  1. Binding Request                                 │            │
│      │  Transaction ID: 0x123456789ABC                     │            │
│      │ ──────────────────────────────────────────────────> │            │
│      │                                                     │            │
│      │                                   2. 处理请求       │            │
│      │                                      记录源地址     │            │
│      │                                                     │            │
│      │  3. Binding Response                                │            │
│      │  Transaction ID: 0x123456789ABC (相同)              │            │
│      │  XOR-MAPPED-ADDRESS: 1.2.3.4:12345                  │            │
│      │ <────────────────────────────────────────────────── │            │
│      │                                                     │            │
│      │  4. 验证 Transaction ID                             │            │
│      │     解码 XOR-MAPPED-ADDRESS                         │            │
│      │     获得公网地址: 1.2.3.4:12345                     │            │
│      │                                                     │            │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 4. STUN 属性详解

### 4.1 属性格式

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|         Type                  |            Length             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         Value (variable)                ....
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

属性值需要 4 字节对齐,不足部分用 0 填充。

### 4.2 常用属性类型

| 类型值 | 属性名 | 说明 |
|--------|--------|------|
| 0x0001 | MAPPED-ADDRESS | 映射地址 (旧版) |
| 0x0006 | USERNAME | 用户名 |
| 0x0008 | MESSAGE-INTEGRITY | 消息完整性 |
| 0x0009 | ERROR-CODE | 错误码 |
| 0x000A | UNKNOWN-ATTRIBUTES | 未知属性 |
| 0x0014 | REALM | 域 |
| 0x0015 | NONCE | 随机数 |
| 0x0020 | XOR-MAPPED-ADDRESS | XOR 映射地址 |
| 0x8022 | SOFTWARE | 软件信息 |
| 0x8023 | ALTERNATE-SERVER | 备用服务器 |
| 0x8028 | FINGERPRINT | 指纹 |

### 4.3 XOR-MAPPED-ADDRESS

这是最重要的属性,包含经过 XOR 编码的公网地址。

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|0 0 0 0 0 0 0 0|    Family     |         X-Port                |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                X-Address (32 bits for IPv4)                   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

| 字段 | 说明 |
|------|------|
| Family | 0x01 = IPv4, 0x02 = IPv6 |
| X-Port | Port XOR (Magic Cookie 高 16 位) |
| X-Address | Address XOR Magic Cookie |

解码示例:

```
Magic Cookie: 0x2112A442

编码后的值:
X-Port: 0xE1BA
X-Address: 0x2010A546

解码:
Port = 0xE1BA XOR 0x2112 = 0xC0A8 = 49320
Address = 0x2010A546 XOR 0x2112A442 = 0x01020304

结果: 1.2.3.4:49320
```

为什么使用 XOR 编码:

1. 防止某些 NAT 设备修改消息中的 IP 地址
2. 某些 ALG (Application Layer Gateway) 会扫描并修改 IP 地址

### 4.4 MESSAGE-INTEGRITY

用于验证消息完整性,使用 HMAC-SHA1 计算。

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                                                               |
|                    HMAC-SHA1 (20 bytes)                       |
|                                                               |
|                                                               |
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

计算方法:

```
HMAC-SHA1(key, message)

其中:
- key: 密码 (在 ICE 中是 ice-pwd)
- message: STUN 消息 (不含 MESSAGE-INTEGRITY 和 FINGERPRINT)
```

### 4.5 FINGERPRINT

用于区分 STUN 消息和其他协议,使用 CRC-32 计算。

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                   CRC-32 XOR 0x5354554E                       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

计算方法:

```
FINGERPRINT = CRC32(message) XOR 0x5354554E

0x5354554E = "STUN" 的 ASCII 码
```

### 4.6 ERROR-CODE

错误响应中包含的错误信息。

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|           Reserved            |Class|     Number              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|      Reason Phrase (variable)                                 |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

错误码 = Class * 100 + Number

常见错误码:

| 错误码 | 说明 |
|--------|------|
| 300 | Try Alternate (尝试备用服务器) |
| 400 | Bad Request (请求格式错误) |
| 401 | Unauthorized (未授权) |
| 420 | Unknown Attribute (未知属性) |
| 438 | Stale Nonce (Nonce 过期) |
| 500 | Server Error (服务器错误) |

---

## 5. NAT 类型检测

### 5.1 NAT 类型分类

根据 RFC 3489 (已过时但概念仍有用),NAT 分为四种类型:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        NAT 类型分类                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   1. Full Cone NAT (完全锥形)                                           │
│      ┌─────────────────────────────────────────────────────────────┐   │
│      │ 内部地址 A:a 映射到外部地址 X:x 后                           │   │
│      │ 任何外部主机都可以通过 X:x 访问 A:a                          │   │
│      └─────────────────────────────────────────────────────────────┘   │
│                                                                         │
│   2. Restricted Cone NAT (受限锥形)                                     │
│      ┌─────────────────────────────────────────────────────────────┐   │
│      │ 内部地址 A:a 映射到外部地址 X:x 后                           │   │
│      │ 只有 A:a 曾经发送过数据的外部 IP 才能通过 X:x 访问           │   │
│      └─────────────────────────────────────────────────────────────┘   │
│                                                                         │
│   3. Port Restricted Cone NAT (端口受限锥形)                            │
│      ┌─────────────────────────────────────────────────────────────┐   │
│      │ 内部地址 A:a 映射到外部地址 X:x 后                           │   │
│      │ 只有 A:a 曾经发送过数据的外部 IP:Port 才能通过 X:x 访问      │   │
│      └─────────────────────────────────────────────────────────────┘   │
│                                                                         │
│   4. Symmetric NAT (对称型)                                             │
│      ┌─────────────────────────────────────────────────────────────┐   │
│      │ 内部地址 A:a 发送到不同目标时,使用不同的外部端口             │   │
│      │ A:a -> B:b 映射为 X:x                                       │   │
│      │ A:a -> C:c 映射为 X:y (不同端口)                            │   │
│      └─────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.2 NAT 类型检测流程

使用两个不同 IP 地址的 STUN 服务器进行检测:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        NAT 类型检测流程                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   测试 1: 基本连通性                                                     │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │ 客户端 ──> STUN Server (IP1:Port1)                              │  │
│   │ 如果无响应: 可能被防火墙阻止或 UDP 被禁用                        │  │
│   │ 如果有响应: 获得映射地址 X:x                                    │  │
│   └─────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│   测试 2: 检查是否在 NAT 后面                                           │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │ 比较本地地址和映射地址                                          │  │
│   │ 如果相同: 没有 NAT (公网 IP)                                    │  │
│   │ 如果不同: 在 NAT 后面,继续测试                                  │  │
│   └─────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│   测试 3: 检查 Full Cone                                                │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │ 请求 STUN 服务器从不同 IP 和端口发送响应                        │  │
│   │ 如果收到响应: Full Cone NAT                                     │  │
│   │ 如果无响应: 继续测试                                            │  │
│   └─────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│   测试 4: 检查 Symmetric NAT                                            │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │ 向 STUN Server (IP2:Port2) 发送请求                             │  │
│   │ 比较两次获得的映射端口                                          │  │
│   │ 如果端口不同: Symmetric NAT                                     │  │
│   │ 如果端口相同: Restricted 或 Port Restricted                     │  │
│   └─────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│   测试 5: 区分 Restricted 和 Port Restricted                            │
│   ┌─────────────────────────────────────────────────────────────────┐  │
│   │ 请求 STUN 服务器从相同 IP 不同端口发送响应                      │  │
│   │ 如果收到响应: Restricted Cone NAT                               │  │
│   │ 如果无响应: Port Restricted Cone NAT                            │  │
│   └─────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.3 NAT 类型与穿透成功率

| NAT 类型 | 穿透难度 | P2P 成功率 |
|---------|---------|-----------|
| Full Cone | 简单 | 约 95% |
| Restricted Cone | 中等 | 约 85% |
| Port Restricted Cone | 较难 | 约 70% |
| Symmetric | 困难 | 约 30% |

当两端都是 Symmetric NAT 时,通常需要 TURN 中继。

---

## 6. STUN 服务器搭建

### 6.1 公共 STUN 服务器

可以使用公共 STUN 服务器进行测试:

```javascript
const iceServers = [
    { urls: 'stun:stun.l.google.com:19302' },
    { urls: 'stun:stun1.l.google.com:19302' },
    { urls: 'stun:stun2.l.google.com:19302' },
    { urls: 'stun:stun3.l.google.com:19302' },
    { urls: 'stun:stun4.l.google.com:19302' },
    { urls: 'stun:stun.stunprotocol.org:3478' },
    { urls: 'stun:stun.voip.blackberry.com:3478' }
];
```

### 6.2 使用 coturn 搭建 STUN 服务器

coturn 是最流行的开源 STUN/TURN 服务器。

#### 安装

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install coturn

# CentOS/RHEL
sudo yum install coturn

# 从源码编译
git clone https://github.com/coturn/coturn.git
cd coturn
./configure
make
sudo make install
```

#### 配置文件 (/etc/turnserver.conf)

```ini
# 监听端口
listening-port=3478
tls-listening-port=5349

# 监听 IP (替换为你的服务器 IP)
listening-ip=0.0.0.0
external-ip=YOUR_PUBLIC_IP

# 日志
log-file=/var/log/turnserver.log
verbose

# 仅 STUN 模式 (不启用 TURN)
no-auth
no-turn

# 或者同时启用 STUN 和 TURN
# lt-cred-mech
# user=username:password
# realm=yourdomain.com

# 指纹
fingerprint

# 软件名称
server-name=my-stun-server
```

#### 启动服务

```bash
# 启动服务
sudo systemctl start coturn

# 设置开机启动
sudo systemctl enable coturn

# 查看状态
sudo systemctl status coturn

# 查看日志
sudo tail -f /var/log/turnserver.log
```

### 6.3 使用 Node.js 实现简单 STUN 服务器

```javascript
const dgram = require('dgram');
const crypto = require('crypto');

const MAGIC_COOKIE = 0x2112A442;
const STUN_BINDING_REQUEST = 0x0001;
const STUN_BINDING_RESPONSE = 0x0101;
const XOR_MAPPED_ADDRESS = 0x0020;

const server = dgram.createSocket('udp4');

server.on('message', (msg, rinfo) => {
    // 解析 STUN 请求
    const messageType = msg.readUInt16BE(0);
    const messageLength = msg.readUInt16BE(2);
    const magicCookie = msg.readUInt32BE(4);
    const transactionId = msg.slice(8, 20);
    
    // 验证是否为 STUN Binding Request
    if (messageType !== STUN_BINDING_REQUEST || magicCookie !== MAGIC_COOKIE) {
        console.log('Invalid STUN request');
        return;
    }
    
    console.log(`Received STUN request from ${rinfo.address}:${rinfo.port}`);
    
    // 构建响应
    const response = buildBindingResponse(transactionId, rinfo.address, rinfo.port);
    
    // 发送响应
    server.send(response, rinfo.port, rinfo.address, (err) => {
        if (err) {
            console.error('Error sending response:', err);
        } else {
            console.log(`Sent response to ${rinfo.address}:${rinfo.port}`);
        }
    });
});

function buildBindingResponse(transactionId, address, port) {
    // XOR 编码地址和端口
    const xorPort = port ^ (MAGIC_COOKIE >> 16);
    const ipParts = address.split('.').map(Number);
    const ipInt = (ipParts[0] << 24) | (ipParts[1] << 16) | (ipParts[2] << 8) | ipParts[3];
    const xorIp = ipInt ^ MAGIC_COOKIE;
    
    // XOR-MAPPED-ADDRESS 属性
    const attribute = Buffer.alloc(12);
    attribute.writeUInt16BE(XOR_MAPPED_ADDRESS, 0);  // Type
    attribute.writeUInt16BE(8, 2);                    // Length
    attribute.writeUInt8(0, 4);                       // Reserved
    attribute.writeUInt8(0x01, 5);                    // Family (IPv4)
    attribute.writeUInt16BE(xorPort, 6);              // X-Port
    attribute.writeUInt32BE(xorIp >>> 0, 8);          // X-Address
    
    // STUN 消息头
    const header = Buffer.alloc(20);
    header.writeUInt16BE(STUN_BINDING_RESPONSE, 0);   // Message Type
    header.writeUInt16BE(attribute.length, 2);        // Message Length
    header.writeUInt32BE(MAGIC_COOKIE, 4);            // Magic Cookie
    transactionId.copy(header, 8);                    // Transaction ID
    
    return Buffer.concat([header, attribute]);
}

server.on('listening', () => {
    const address = server.address();
    console.log(`STUN server listening on ${address.address}:${address.port}`);
});

server.on('error', (err) => {
    console.error('Server error:', err);
    server.close();
});

server.bind(3478);
```

### 6.4 测试 STUN 服务器

使用 stunclient 测试:

```bash
# 安装 stuntman
sudo apt-get install stuntman-client

# 测试 STUN 服务器
stunclient your-stun-server.com 3478
```

使用 JavaScript 测试:

```javascript
async function testStunServer(stunUrl) {
    return new Promise((resolve, reject) => {
        const pc = new RTCPeerConnection({
            iceServers: [{ urls: stunUrl }]
        });
        
        pc.createDataChannel('test');
        
        pc.onicecandidate = (event) => {
            if (event.candidate) {
                const candidate = event.candidate.candidate;
                if (candidate.includes('srflx')) {
                    // 找到了 Server Reflexive 候选
                    const match = candidate.match(/(\d+\.\d+\.\d+\.\d+) (\d+) typ srflx/);
                    if (match) {
                        resolve({
                            success: true,
                            publicIp: match[1],
                            publicPort: match[2]
                        });
                        pc.close();
                    }
                }
            } else {
                // 候选收集完成
                resolve({ success: false, reason: 'No srflx candidate found' });
                pc.close();
            }
        };
        
        pc.createOffer()
            .then(offer => pc.setLocalDescription(offer))
            .catch(reject);
        
        // 超时处理
        setTimeout(() => {
            resolve({ success: false, reason: 'Timeout' });
            pc.close();
        }, 5000);
    });
}

// 测试
testStunServer('stun:stun.l.google.com:19302')
    .then(result => console.log('STUN test result:', result));
```

---

## 7. 总结

### 7.1 STUN 核心要点

| 要点 | 说明 |
|------|------|
| 作用 | 发现 NAT 映射的公网地址 |
| 协议 | UDP 为主,也支持 TCP |
| 端口 | 默认 3478 (TLS: 5349) |
| 消息类型 | Binding Request/Response |
| 关键属性 | XOR-MAPPED-ADDRESS |
| 安全性 | MESSAGE-INTEGRITY, FINGERPRINT |

### 7.2 STUN 的局限性

1. 无法穿透 Symmetric NAT
2. 只能发现地址,不能中继数据
3. 需要 TURN 作为后备方案

### 7.3 下一篇预告

在下一篇文章中,我们将深入探讨 TURN 协议,包括:
- TURN 的工作原理
- Relay 数据流程
- Coturn 安装与配置实战

---

## 参考资料

1. [RFC 5389 - Session Traversal Utilities for NAT (STUN)](https://datatracker.ietf.org/doc/html/rfc5389)
2. [RFC 8489 - Session Traversal Utilities for NAT (STUN) - 更新版](https://datatracker.ietf.org/doc/html/rfc8489)
3. [coturn - Open Source TURN/STUN Server](https://github.com/coturn/coturn)
4. [WebRTC STUN - MDN](https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API/Protocols#stun)

---

> 作者: WebRTC 技术专栏  
> 系列: 信令与会话管理 (4/6)  
> 上一篇: [ICE 框架](./08-ice-framework.md)  
> 下一篇: [TURN: 中继服务器详解](./10-turn-server.md)
