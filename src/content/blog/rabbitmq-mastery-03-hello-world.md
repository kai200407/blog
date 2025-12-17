---
title: "第03章：快速入门 Hello World"
description: "本章通过一个简单的 \"Hello World\" 示例，帮助你快速理解 RabbitMQ 的基本工作流程。"
pubDate: "2025-12-17"
tags: ["rabbitmq","mq","backend"]
category: "rabbitmq"
series: "RabbitMQ 消息队列"
order: 3
---

## 3.1 概述

本章通过一个简单的 "Hello World" 示例，帮助你快速理解 RabbitMQ 的基本工作流程。

### 工作流程

```
┌──────────────┐     ┌─────────────┐     ┌──────────────┐
│   Producer   │────▶│    Queue    │────▶│   Consumer   │
│   (发送者)    │     │   (hello)   │     │   (接收者)    │
└──────────────┘     └─────────────┘     └──────────────┘
       │                   │                    │
   发送消息          存储消息              消费消息
```

### 学习目标

- 理解生产者/消费者模型
- 掌握连接 RabbitMQ 的基本方法
- 了解队列声明和消息发送/接收

---

## 3.2 环境准备

### 确保 RabbitMQ 运行

```bash
# Docker 方式
docker run -d --name rabbitmq \
  -p 5672:5672 -p 15672:15672 \
  -e RABBITMQ_DEFAULT_USER=admin \
  -e RABBITMQ_DEFAULT_PASS=admin123 \
  rabbitmq:3.12-management
```

---

## 3.3 Python 实现

### 安装依赖

```bash
pip install pika
```

### 生产者 (send.py)

```python
#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
RabbitMQ Hello World - 生产者
"""
import pika

# 1. 建立连接
credentials = pika.PlainCredentials('admin', 'admin123')
connection = pika.BlockingConnection(
    pika.ConnectionParameters(
        host='localhost',
        port=5672,
        credentials=credentials
    )
)

# 2. 创建信道
channel = connection.channel()

# 3. 声明队列（如果不存在则创建）
channel.queue_declare(queue='hello')

# 4. 发送消息
message = 'Hello World!'
channel.basic_publish(
    exchange='',           # 使用默认交换器
    routing_key='hello',   # 队列名作为路由键
    body=message
)

print(f" [x] Sent '{message}'")

# 5. 关闭连接
connection.close()
```

### 消费者 (receive.py)

```python
#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
RabbitMQ Hello World - 消费者
"""
import pika

# 1. 建立连接
credentials = pika.PlainCredentials('admin', 'admin123')
connection = pika.BlockingConnection(
    pika.ConnectionParameters(
        host='localhost',
        port=5672,
        credentials=credentials
    )
)

# 2. 创建信道
channel = connection.channel()

# 3. 声明队列（确保队列存在）
channel.queue_declare(queue='hello')

# 4. 定义回调函数
def callback(ch, method, properties, body):
    print(f" [x] Received '{body.decode()}'")

# 5. 设置消费者
channel.basic_consume(
    queue='hello',
    on_message_callback=callback,
    auto_ack=True  # 自动确认
)

print(' [*] Waiting for messages. To exit press CTRL+C')

# 6. 开始消费（阻塞）
channel.start_consuming()
```

### 运行测试

```bash
# 终端1：启动消费者
python receive.py

# 终端2：发送消息
python send.py
```

---

## 3.4 Java 实现

### Maven 依赖

```xml
<dependency>
    <groupId>com.rabbitmq</groupId>
    <artifactId>amqp-client</artifactId>
    <version>5.18.0</version>
</dependency>
```

### 生产者 (Send.java)

```java
package com.example.rabbitmq;

import com.rabbitmq.client.Channel;
import com.rabbitmq.client.Connection;
import com.rabbitmq.client.ConnectionFactory;

import java.nio.charset.StandardCharsets;

public class Send {
    private final static String QUEUE_NAME = "hello";

    public static void main(String[] args) throws Exception {
        // 1. 创建连接工厂
        ConnectionFactory factory = new ConnectionFactory();
        factory.setHost("localhost");
        factory.setPort(5672);
        factory.setUsername("admin");
        factory.setPassword("admin123");

        // 2. 创建连接和信道
        try (Connection connection = factory.newConnection();
             Channel channel = connection.createChannel()) {
            
            // 3. 声明队列
            channel.queueDeclare(QUEUE_NAME, false, false, false, null);
            
            // 4. 发送消息
            String message = "Hello World!";
            channel.basicPublish("", QUEUE_NAME, null, 
                message.getBytes(StandardCharsets.UTF_8));
            
            System.out.println(" [x] Sent '" + message + "'");
        }
    }
}
```

### 消费者 (Receive.java)

```java
package com.example.rabbitmq;

import com.rabbitmq.client.*;

import java.nio.charset.StandardCharsets;

public class Receive {
    private final static String QUEUE_NAME = "hello";

    public static void main(String[] args) throws Exception {
        // 1. 创建连接工厂
        ConnectionFactory factory = new ConnectionFactory();
        factory.setHost("localhost");
        factory.setPort(5672);
        factory.setUsername("admin");
        factory.setPassword("admin123");

        // 2. 创建连接和信道
        Connection connection = factory.newConnection();
        Channel channel = connection.createChannel();

        // 3. 声明队列
        channel.queueDeclare(QUEUE_NAME, false, false, false, null);

        System.out.println(" [*] Waiting for messages. To exit press CTRL+C");

        // 4. 定义回调
        DeliverCallback deliverCallback = (consumerTag, delivery) -> {
            String message = new String(delivery.getBody(), StandardCharsets.UTF_8);
            System.out.println(" [x] Received '" + message + "'");
        };

        // 5. 开始消费
        channel.basicConsume(QUEUE_NAME, true, deliverCallback, consumerTag -> {});
    }
}
```

---

## 3.5 Node.js 实现

### 安装依赖

```bash
npm install amqplib
```

### 生产者 (send.js)

```javascript
const amqp = require('amqplib');

const QUEUE_NAME = 'hello';

async function main() {
    // 1. 建立连接
    const connection = await amqp.connect('amqp://admin:admin123@localhost:5672');
    
    // 2. 创建信道
    const channel = await connection.createChannel();
    
    // 3. 声明队列
    await channel.assertQueue(QUEUE_NAME, { durable: false });
    
    // 4. 发送消息
    const message = 'Hello World!';
    channel.sendToQueue(QUEUE_NAME, Buffer.from(message));
    console.log(` [x] Sent '${message}'`);
    
    // 5. 关闭连接
    setTimeout(() => {
        connection.close();
        process.exit(0);
    }, 500);
}

main().catch(console.error);
```

### 消费者 (receive.js)

```javascript
const amqp = require('amqplib');

const QUEUE_NAME = 'hello';

async function main() {
    // 1. 建立连接
    const connection = await amqp.connect('amqp://admin:admin123@localhost:5672');
    
    // 2. 创建信道
    const channel = await connection.createChannel();
    
    // 3. 声明队列
    await channel.assertQueue(QUEUE_NAME, { durable: false });
    
    console.log(' [*] Waiting for messages. To exit press CTRL+C');
    
    // 4. 消费消息
    channel.consume(QUEUE_NAME, (msg) => {
        if (msg !== null) {
            console.log(` [x] Received '${msg.content.toString()}'`);
            channel.ack(msg);
        }
    });
}

main().catch(console.error);
```

---

## 3.6 Go 实现

### 安装依赖

```bash
go get github.com/rabbitmq/amqp091-go
```

### 生产者 (send.go)

```go
package main

import (
    "context"
    "log"
    "time"

    amqp "github.com/rabbitmq/amqp091-go"
)

func failOnError(err error, msg string) {
    if err != nil {
        log.Panicf("%s: %s", msg, err)
    }
}

func main() {
    // 1. 建立连接
    conn, err := amqp.Dial("amqp://admin:admin123@localhost:5672/")
    failOnError(err, "Failed to connect to RabbitMQ")
    defer conn.Close()

    // 2. 创建信道
    ch, err := conn.Channel()
    failOnError(err, "Failed to open a channel")
    defer ch.Close()

    // 3. 声明队列
    q, err := ch.QueueDeclare(
        "hello", // name
        false,   // durable
        false,   // delete when unused
        false,   // exclusive
        false,   // no-wait
        nil,     // arguments
    )
    failOnError(err, "Failed to declare a queue")

    // 4. 发送消息
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    body := "Hello World!"
    err = ch.PublishWithContext(ctx,
        "",     // exchange
        q.Name, // routing key
        false,  // mandatory
        false,  // immediate
        amqp.Publishing{
            ContentType: "text/plain",
            Body:        []byte(body),
        })
    failOnError(err, "Failed to publish a message")
    log.Printf(" [x] Sent %s\n", body)
}
```

### 消费者 (receive.go)

```go
package main

import (
    "log"

    amqp "github.com/rabbitmq/amqp091-go"
)

func failOnError(err error, msg string) {
    if err != nil {
        log.Panicf("%s: %s", msg, err)
    }
}

func main() {
    // 1. 建立连接
    conn, err := amqp.Dial("amqp://admin:admin123@localhost:5672/")
    failOnError(err, "Failed to connect to RabbitMQ")
    defer conn.Close()

    // 2. 创建信道
    ch, err := conn.Channel()
    failOnError(err, "Failed to open a channel")
    defer ch.Close()

    // 3. 声明队列
    q, err := ch.QueueDeclare(
        "hello",
        false,
        false,
        false,
        false,
        nil,
    )
    failOnError(err, "Failed to declare a queue")

    // 4. 注册消费者
    msgs, err := ch.Consume(
        q.Name,
        "",    // consumer
        true,  // auto-ack
        false, // exclusive
        false, // no-local
        false, // no-wait
        nil,   // args
    )
    failOnError(err, "Failed to register a consumer")

    // 5. 消费消息
    var forever chan struct{}
    go func() {
        for d := range msgs {
            log.Printf(" [x] Received %s", d.Body)
        }
    }()

    log.Printf(" [*] Waiting for messages. To exit press CTRL+C")
    <-forever
}
```

---

## 3.7 核心概念解析

### Connection vs Channel

```
┌─────────────────────────────────────────────────────┐
│                   Connection (TCP)                  │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐   │
│  │  Channel 1  │ │  Channel 2  │ │  Channel N  │   │
│  └─────────────┘ └─────────────┘ └─────────────┘   │
└─────────────────────────────────────────────────────┘
```

| 概念 | 说明 |
|------|------|
| **Connection** | TCP 连接，开销大，应复用 |
| **Channel** | 虚拟连接，轻量级，可创建多个 |

**最佳实践**: 一个应用维护一个 Connection，每个线程使用独立的 Channel。

### 队列声明参数

```python
channel.queue_declare(
    queue='hello',      # 队列名
    durable=False,      # 持久化
    exclusive=False,    # 排他队列
    auto_delete=False,  # 自动删除
    arguments=None      # 额外参数
)
```

| 参数 | 说明 |
|------|------|
| `durable` | 队列是否持久化到磁盘 |
| `exclusive` | 是否为排他队列（仅当前连接可用，断开即删除） |
| `auto_delete` | 无消费者时是否自动删除 |

### 默认交换器

当 `exchange=''` 时，使用默认交换器（AMQP default），它会将消息路由到与 `routing_key` 同名的队列。

```python
channel.basic_publish(
    exchange='',           # 默认交换器
    routing_key='hello',   # 目标队列名
    body=message
)
```

---

## 3.8 管理界面查看

访问 http://localhost:15672 查看：

1. **Queues** 标签页：可以看到 `hello` 队列
2. **Get messages**: 可以手动获取队列中的消息
3. **Publish message**: 可以手动发送测试消息

---

## 3.9 常见问题

### Q1: 连接被拒绝

```
Connection refused
```

**解决**: 确认 RabbitMQ 正在运行，端口 5672 可访问。

### Q2: 认证失败

```
ACCESS_REFUSED - Login was refused
```

**解决**: 检查用户名密码是否正确，guest 用户默认只能本地访问。

### Q3: 队列已存在但参数不同

```
PRECONDITION_FAILED - inequivalent arg 'durable'
```

**解决**: 删除已存在的队列或使用相同参数声明。

---

## 3.10 本章小结

本章实现了最简单的 RabbitMQ "Hello World" 示例：

1. **生产者**: 连接 → 声明队列 → 发送消息 → 关闭连接
2. **消费者**: 连接 → 声明队列 → 设置回调 → 开始消费
3. **核心概念**: Connection、Channel、Queue

---

## 3.11 完整代码

代码位置: `code-examples/` 目录下各语言文件夹

---

**下一章**: [工作队列模式](../04-work-queues/README.md)
