---
title: "第05章：发布/订阅模式 (Publish/Subscribe)"
description: "发布/订阅模式用于将消息广播给多个消费者。每个消费者都有自己的队列，收到完整的消息副本。"
pubDate: "2025-12-17"
tags: ["rabbitmq","mq","backend"]
category: "rabbitmq"
series: "RabbitMQ 消息队列"
order: 5
---

## 5.1 概述

发布/订阅模式用于将消息广播给多个消费者。每个消费者都有自己的队列，收到完整的消息副本。

### 工作模式

```
                              ┌─────────┐     ┌──────────────┐
                         ┌───▶│ Queue 1 │────▶│  Consumer 1  │
┌──────────────┐         │    └─────────┘     └──────────────┘
│   Producer   │────▶ Exchange                              
└──────────────┘   (fanout) │    ┌─────────┐     ┌──────────────┐
                         └───▶│ Queue 2 │────▶│  Consumer 2  │
                              └─────────┘     └──────────────┘
```

### 应用场景

- 日志广播系统
- 实时通知推送
- 配置更新通知
- 事件广播

---

## 5.2 Exchange（交换器）

### 什么是交换器

交换器是消息路由的核心组件，生产者将消息发送到交换器，交换器根据规则将消息路由到队列。

```
Producer ──▶ Exchange ──▶ Binding ──▶ Queue ──▶ Consumer
```

### 交换器类型

| 类型 | 路由规则 | 使用场景 |
|------|----------|----------|
| **fanout** | 广播到所有绑定队列 | 发布/订阅 |
| **direct** | 精确匹配 routing key | 路由模式 |
| **topic** | 通配符匹配 routing key | 主题模式 |
| **headers** | 根据消息头匹配 | 特殊场景 |

### 默认交换器

当 `exchange=''` 时，使用默认交换器（无名交换器），它会将消息路由到与 routing key 同名的队列。

---

## 5.3 Fanout 交换器

Fanout 交换器将消息广播到所有绑定的队列，忽略 routing key。

```
                    ┌────────────────────────────────────┐
                    │         Fanout Exchange            │
                    │    (忽略 routing key，广播消息)     │
                    └──────────────┬─────────────────────┘
                                   │
               ┌───────────────────┼───────────────────┐
               ▼                   ▼                   ▼
          ┌─────────┐         ┌─────────┐         ┌─────────┐
          │ Queue 1 │         │ Queue 2 │         │ Queue 3 │
          └────┬────┘         └────┬────┘         └────┬────┘
               ▼                   ▼                   ▼
          Consumer 1          Consumer 2          Consumer 3
```

---

## 5.4 临时队列

在发布/订阅模式中，每个消费者需要独立的队列。可以使用临时队列（排他队列）：

```python
# 创建临时队列，名称由 RabbitMQ 自动生成
result = channel.queue_declare(queue='', exclusive=True)
queue_name = result.method.queue  # 例如: amq.gen-JzTY20BRgKO-HjmUJj0wLg
```

特点：
- 队列名自动生成
- 连接断开时自动删除
- 仅当前连接可用

---

## 5.5 绑定 (Binding)

绑定是交换器和队列之间的关联关系。

```python
# 将队列绑定到交换器
channel.queue_bind(exchange='logs', queue=queue_name)
```

```
Exchange ═══════════════════ Binding ═══════════════════ Queue
   │                                                        │
logs (fanout)                                          amq.gen-xxx
```

---

## 5.6 代码实现

### 生产者 (emit_log.py)

```python
#!/usr/bin/env python
import pika
import sys

credentials = pika.PlainCredentials('admin', 'admin123')
connection = pika.BlockingConnection(
    pika.ConnectionParameters('localhost', credentials=credentials)
)
channel = connection.channel()

# 声明 fanout 交换器
channel.exchange_declare(exchange='logs', exchange_type='fanout')

message = ' '.join(sys.argv[1:]) or "info: Hello World!"

# 发布消息到交换器（routing_key 被忽略）
channel.basic_publish(
    exchange='logs',
    routing_key='',  # fanout 忽略 routing_key
    body=message
)

print(f" [x] Sent '{message}'")
connection.close()
```

### 消费者 (receive_logs.py)

```python
#!/usr/bin/env python
import pika

credentials = pika.PlainCredentials('admin', 'admin123')
connection = pika.BlockingConnection(
    pika.ConnectionParameters('localhost', credentials=credentials)
)
channel = connection.channel()

# 声明 fanout 交换器
channel.exchange_declare(exchange='logs', exchange_type='fanout')

# 创建临时队列
result = channel.queue_declare(queue='', exclusive=True)
queue_name = result.method.queue

# 将队列绑定到交换器
channel.queue_bind(exchange='logs', queue=queue_name)

print(' [*] Waiting for logs. To exit press CTRL+C')

def callback(ch, method, properties, body):
    print(f" [x] {body.decode()}")

channel.basic_consume(
    queue=queue_name,
    on_message_callback=callback,
    auto_ack=True
)

channel.start_consuming()
```

### 测试

```bash
# 终端1: 启动消费者1（保存到文件）
python receive_logs.py > logs_from_rabbit.log

# 终端2: 启动消费者2（打印到屏幕）
python receive_logs.py

# 终端3: 发送日志
python emit_log.py "First log message"
python emit_log.py "Second log message"
```

两个消费者都会收到所有消息。

---

## 5.7 Java 实现

### 生产者 (EmitLog.java)

```java
package com.example.rabbitmq;

import com.rabbitmq.client.Channel;
import com.rabbitmq.client.Connection;
import com.rabbitmq.client.ConnectionFactory;

public class EmitLog {
    private static final String EXCHANGE_NAME = "logs";

    public static void main(String[] args) throws Exception {
        ConnectionFactory factory = new ConnectionFactory();
        factory.setHost("localhost");
        factory.setUsername("admin");
        factory.setPassword("admin123");

        try (Connection connection = factory.newConnection();
             Channel channel = connection.createChannel()) {
            
            // 声明 fanout 交换器
            channel.exchangeDeclare(EXCHANGE_NAME, "fanout");

            String message = args.length < 1 ? "info: Hello World!" : String.join(" ", args);

            channel.basicPublish(EXCHANGE_NAME, "", null, message.getBytes("UTF-8"));
            System.out.println(" [x] Sent '" + message + "'");
        }
    }
}
```

### 消费者 (ReceiveLogs.java)

```java
package com.example.rabbitmq;

import com.rabbitmq.client.*;

public class ReceiveLogs {
    private static final String EXCHANGE_NAME = "logs";

    public static void main(String[] args) throws Exception {
        ConnectionFactory factory = new ConnectionFactory();
        factory.setHost("localhost");
        factory.setUsername("admin");
        factory.setPassword("admin123");

        Connection connection = factory.newConnection();
        Channel channel = connection.createChannel();

        // 声明 fanout 交换器
        channel.exchangeDeclare(EXCHANGE_NAME, "fanout");
        
        // 创建临时队列
        String queueName = channel.queueDeclare().getQueue();
        
        // 绑定队列到交换器
        channel.queueBind(queueName, EXCHANGE_NAME, "");

        System.out.println(" [*] Waiting for messages. To exit press CTRL+C");

        DeliverCallback deliverCallback = (consumerTag, delivery) -> {
            String message = new String(delivery.getBody(), "UTF-8");
            System.out.println(" [x] Received '" + message + "'");
        };
        
        channel.basicConsume(queueName, true, deliverCallback, consumerTag -> {});
    }
}
```

---

## 5.8 Node.js 实现

### 生产者 (emit_log.js)

```javascript
const amqp = require('amqplib');

const EXCHANGE_NAME = 'logs';

async function main() {
    const connection = await amqp.connect('amqp://admin:admin123@localhost');
    const channel = await connection.createChannel();

    // 声明 fanout 交换器
    await channel.assertExchange(EXCHANGE_NAME, 'fanout', { durable: false });

    const msg = process.argv.slice(2).join(' ') || 'Hello World!';
    
    channel.publish(EXCHANGE_NAME, '', Buffer.from(msg));
    console.log(` [x] Sent '${msg}'`);

    setTimeout(() => {
        connection.close();
        process.exit(0);
    }, 500);
}

main().catch(console.error);
```

### 消费者 (receive_logs.js)

```javascript
const amqp = require('amqplib');

const EXCHANGE_NAME = 'logs';

async function main() {
    const connection = await amqp.connect('amqp://admin:admin123@localhost');
    const channel = await connection.createChannel();

    await channel.assertExchange(EXCHANGE_NAME, 'fanout', { durable: false });

    // 创建临时队列
    const { queue } = await channel.assertQueue('', { exclusive: true });

    // 绑定队列到交换器
    await channel.bindQueue(queue, EXCHANGE_NAME, '');

    console.log(' [*] Waiting for messages. To exit press CTRL+C');

    channel.consume(queue, (msg) => {
        if (msg.content) {
            console.log(` [x] ${msg.content.toString()}`);
        }
    }, { noAck: true });
}

main().catch(console.error);
```

---

## 5.9 实际应用：日志系统

### 架构图

```
┌──────────────┐                                    ┌───────────────────┐
│ Application  │                                    │   Console Logger  │
│   Server 1   │───┐                           ┌───▶│   (实时显示)      │
└──────────────┘   │    ┌───────────────────┐  │    └───────────────────┘
                   │    │                   │  │
┌──────────────┐   ├───▶│  Exchange: logs   │──┤    ┌───────────────────┐
│ Application  │───┤    │  (fanout)         │  ├───▶│   File Logger     │
│   Server 2   │   │    │                   │  │    │   (保存到文件)    │
└──────────────┘   │    └───────────────────┘  │    └───────────────────┘
                   │                           │
┌──────────────┐   │                           │    ┌───────────────────┐
│ Application  │───┘                           └───▶│   Alert Service   │
│   Server 3   │                                    │   (发送告警)      │
└──────────────┘                                    └───────────────────┘
```

### 特点

- 日志发送方只需发送到 `logs` 交换器
- 任意数量的消费者可以订阅
- 新增消费者不影响现有系统
- 完全解耦

---

## 5.10 本章小结

| 概念 | 说明 |
|------|------|
| **Exchange** | 消息路由组件 |
| **Fanout** | 广播到所有绑定队列 |
| **Binding** | 交换器与队列的关联 |
| **临时队列** | 自动命名、排他、自动删除 |
| **发布/订阅** | 一对多消息分发 |

---

## 5.11 思考题

1. fanout 交换器的消息如果没有绑定队列会怎样？
2. 如何实现只接收特定类型的日志？
3. 发布/订阅模式和工作队列模式有什么区别？

---

**下一章**: [路由模式](../06-routing/README.md)
