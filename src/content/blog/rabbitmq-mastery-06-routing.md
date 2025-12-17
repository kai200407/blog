---
title: "第06章：路由模式 (Routing)"
description: "路由模式允许消费者选择性地接收消息，根据 routing key 进行精确匹配。"
pubDate: "2025-12-17"
tags: ["rabbitmq","mq","backend"]
category: "rabbitmq"
series: "RabbitMQ 消息队列"
order: 6
---

## 6.1 概述

路由模式允许消费者选择性地接收消息，根据 routing key 进行精确匹配。

### 工作模式

```
                              ┌─────────┐     ┌──────────────┐
                    error ───▶│ Queue 1 │────▶│  Consumer 1  │
┌──────────────┐              └─────────┘     │  (仅 error)   │
│   Producer   │────▶ Exchange                └──────────────┘
└──────────────┘   (direct)              
                    error ───▶┌─────────┐     ┌──────────────┐
                    warning ─▶│ Queue 2 │────▶│  Consumer 2  │
                    info ────▶└─────────┘     │  (所有级别)   │
                                              └──────────────┘
```

### 应用场景

- 日志分级处理
- 订单路由（按地区/类型）
- 消息过滤

---

## 6.2 Direct 交换器

Direct 交换器根据 routing key 进行精确匹配，只有 routing key 完全相同的队列才会收到消息。

```
┌─────────────────────────────────────────────────────────────────┐
│                      Direct Exchange                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Message (routing_key="error") ──▶ Queue with binding="error"   │
│                                                                 │
│  消息的 routing key 必须与绑定的 binding key 完全匹配           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6.3 多重绑定

一个队列可以绑定多个 routing key，多个队列也可以绑定同一个 routing key。

```
                         ┌──────────────────────────────────┐
                         │        Direct Exchange           │
                         └───────────────┬──────────────────┘
                                         │
           ┌─────────────────────────────┼─────────────────────────────┐
           │                             │                             │
           ▼                             ▼                             ▼
    binding: error               binding: error               binding: info
    binding: warning             binding: warning              
           │                             │                             │
           ▼                             ▼                             ▼
    ┌─────────────┐              ┌─────────────┐              ┌─────────────┐
    │   Queue 1   │              │   Queue 2   │              │   Queue 3   │
    │ (错误日志)   │              │ (警告日志)   │              │ (信息日志)  │
    └─────────────┘              └─────────────┘              └─────────────┘
```

---

## 6.4 代码实现

### 生产者 (emit_log_direct.py)

```python
#!/usr/bin/env python
import pika
import sys

credentials = pika.PlainCredentials('admin', 'admin123')
connection = pika.BlockingConnection(
    pika.ConnectionParameters('localhost', credentials=credentials)
)
channel = connection.channel()

# 声明 direct 交换器
channel.exchange_declare(exchange='direct_logs', exchange_type='direct')

# 从命令行获取日志级别，默认 info
severity = sys.argv[1] if len(sys.argv) > 1 else 'info'
message = ' '.join(sys.argv[2:]) or 'Hello World!'

# 发布消息，使用 severity 作为 routing key
channel.basic_publish(
    exchange='direct_logs',
    routing_key=severity,
    body=message
)

print(f" [x] Sent '{severity}':'{message}'")
connection.close()
```

### 消费者 (receive_logs_direct.py)

```python
#!/usr/bin/env python
import pika
import sys

credentials = pika.PlainCredentials('admin', 'admin123')
connection = pika.BlockingConnection(
    pika.ConnectionParameters('localhost', credentials=credentials)
)
channel = connection.channel()

# 声明 direct 交换器
channel.exchange_declare(exchange='direct_logs', exchange_type='direct')

# 创建临时队列
result = channel.queue_declare(queue='', exclusive=True)
queue_name = result.method.queue

# 从命令行获取要订阅的日志级别
severities = sys.argv[1:]
if not severities:
    sys.stderr.write("Usage: %s [info] [warning] [error]\n" % sys.argv[0])
    sys.exit(1)

# 绑定多个 routing key
for severity in severities:
    channel.queue_bind(
        exchange='direct_logs',
        queue=queue_name,
        routing_key=severity
    )

print(f' [*] Waiting for logs. Subscribed to: {severities}')

def callback(ch, method, properties, body):
    print(f" [x] {method.routing_key}:{body.decode()}")

channel.basic_consume(
    queue=queue_name,
    on_message_callback=callback,
    auto_ack=True
)

channel.start_consuming()
```

### 测试

```bash
# 终端1: 只接收 error 日志
python receive_logs_direct.py error

# 终端2: 接收所有级别日志
python receive_logs_direct.py info warning error

# 终端3: 发送不同级别日志
python emit_log_direct.py error "This is an error"
python emit_log_direct.py warning "This is a warning"
python emit_log_direct.py info "This is info"
```

---

## 6.5 Java 实现

### 生产者 (EmitLogDirect.java)

```java
package com.example.rabbitmq;

import com.rabbitmq.client.Channel;
import com.rabbitmq.client.Connection;
import com.rabbitmq.client.ConnectionFactory;

public class EmitLogDirect {
    private static final String EXCHANGE_NAME = "direct_logs";

    public static void main(String[] args) throws Exception {
        ConnectionFactory factory = new ConnectionFactory();
        factory.setHost("localhost");
        factory.setUsername("admin");
        factory.setPassword("admin123");

        try (Connection connection = factory.newConnection();
             Channel channel = connection.createChannel()) {
            
            channel.exchangeDeclare(EXCHANGE_NAME, "direct");

            String severity = args.length < 1 ? "info" : args[0];
            String message = args.length < 2 ? "Hello World!" : 
                String.join(" ", java.util.Arrays.copyOfRange(args, 1, args.length));

            channel.basicPublish(EXCHANGE_NAME, severity, null, message.getBytes("UTF-8"));
            System.out.println(" [x] Sent '" + severity + "':'" + message + "'");
        }
    }
}
```

### 消费者 (ReceiveLogsDirect.java)

```java
package com.example.rabbitmq;

import com.rabbitmq.client.*;

public class ReceiveLogsDirect {
    private static final String EXCHANGE_NAME = "direct_logs";

    public static void main(String[] args) throws Exception {
        if (args.length < 1) {
            System.err.println("Usage: ReceiveLogsDirect [info] [warning] [error]");
            System.exit(1);
        }

        ConnectionFactory factory = new ConnectionFactory();
        factory.setHost("localhost");
        factory.setUsername("admin");
        factory.setPassword("admin123");

        Connection connection = factory.newConnection();
        Channel channel = connection.createChannel();

        channel.exchangeDeclare(EXCHANGE_NAME, "direct");
        
        String queueName = channel.queueDeclare().getQueue();

        // 绑定多个 routing key
        for (String severity : args) {
            channel.queueBind(queueName, EXCHANGE_NAME, severity);
            System.out.println(" [*] Subscribed to: " + severity);
        }

        System.out.println(" [*] Waiting for messages. To exit press CTRL+C");

        DeliverCallback deliverCallback = (consumerTag, delivery) -> {
            String message = new String(delivery.getBody(), "UTF-8");
            System.out.println(" [x] " + delivery.getEnvelope().getRoutingKey() + 
                ":" + message);
        };

        channel.basicConsume(queueName, true, deliverCallback, consumerTag -> {});
    }
}
```

---

## 6.6 Node.js 实现

### 生产者 (emit_log_direct.js)

```javascript
const amqp = require('amqplib');

const EXCHANGE_NAME = 'direct_logs';

async function main() {
    const connection = await amqp.connect('amqp://admin:admin123@localhost');
    const channel = await connection.createChannel();

    await channel.assertExchange(EXCHANGE_NAME, 'direct', { durable: false });

    const severity = process.argv[2] || 'info';
    const msg = process.argv.slice(3).join(' ') || 'Hello World!';

    channel.publish(EXCHANGE_NAME, severity, Buffer.from(msg));
    console.log(` [x] Sent '${severity}':'${msg}'`);

    setTimeout(() => {
        connection.close();
        process.exit(0);
    }, 500);
}

main().catch(console.error);
```

### 消费者 (receive_logs_direct.js)

```javascript
const amqp = require('amqplib');

const EXCHANGE_NAME = 'direct_logs';

async function main() {
    const args = process.argv.slice(2);
    if (args.length === 0) {
        console.log('Usage: node receive_logs_direct.js [info] [warning] [error]');
        process.exit(1);
    }

    const connection = await amqp.connect('amqp://admin:admin123@localhost');
    const channel = await connection.createChannel();

    await channel.assertExchange(EXCHANGE_NAME, 'direct', { durable: false });

    const { queue } = await channel.assertQueue('', { exclusive: true });

    // 绑定多个 routing key
    for (const severity of args) {
        await channel.bindQueue(queue, EXCHANGE_NAME, severity);
    }

    console.log(` [*] Waiting for logs. Subscribed to: ${args.join(', ')}`);

    channel.consume(queue, (msg) => {
        if (msg.content) {
            console.log(` [x] ${msg.fields.routingKey}:${msg.content.toString()}`);
        }
    }, { noAck: true });
}

main().catch(console.error);
```

---

## 6.7 实际应用：日志分级系统

### 架构设计

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          日志分级处理系统                                 │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌────────────────┐                                                      │
│  │  Application   │                                                      │
│  │    Servers     │                                                      │
│  └───────┬────────┘                                                      │
│          │                                                               │
│          ▼                                                               │
│  ┌─────────────────────────────────────────────────────┐                │
│  │           Direct Exchange: log_levels               │                │
│  └─────────────────────────────────────────────────────┘                │
│          │                    │                    │                     │
│          │ error              │ warning            │ info                │
│          ▼                    ▼                    ▼                     │
│  ┌─────────────┐      ┌─────────────┐      ┌─────────────┐              │
│  │ Error Queue │      │Warning Queue│      │  Info Queue │              │
│  └──────┬──────┘      └──────┬──────┘      └──────┬──────┘              │
│         │                    │                    │                      │
│         ▼                    ▼                    ▼                      │
│  ┌─────────────┐      ┌─────────────┐      ┌─────────────┐              │
│  │ PagerDuty   │      │   Slack     │      │   ELK       │              │
│  │ (紧急告警)   │      │  (通知)     │      │  (存储)     │              │
│  └─────────────┘      └─────────────┘      └─────────────┘              │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 6.8 本章小结

| 概念 | 说明 |
|------|------|
| **Direct Exchange** | 精确匹配 routing key |
| **Routing Key** | 消息路由的依据 |
| **Binding Key** | 队列绑定时指定的 key |
| **多重绑定** | 一个队列可绑定多个 key |

### 对比 Fanout vs Direct

| 特性 | Fanout | Direct |
|------|--------|--------|
| Routing Key | 忽略 | 精确匹配 |
| 消息分发 | 广播 | 选择性 |
| 使用场景 | 发布/订阅 | 路由过滤 |

---

## 6.9 思考题

1. 如果需要模糊匹配 routing key，应该使用什么交换器？
2. 如何实现优先级队列结合路由模式？
3. Direct 交换器的性能如何？

---

**下一章**: [主题模式](../07-topics/README.md)
