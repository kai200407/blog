---
title: "第07章：主题模式 (Topics)"
description: "主题模式使用通配符进行 routing key 匹配，比 Direct 交换器更灵活。"
pubDate: "2025-12-17"
tags: ["rabbitmq","mq","backend"]
category: "rabbitmq"
series: "RabbitMQ 消息队列"
order: 7
---

## 7.1 概述

主题模式使用通配符进行 routing key 匹配，比 Direct 交换器更灵活。

### 工作模式

```
                              ┌─────────┐     ┌──────────────┐
              *.orange.* ────▶│ Queue 1 │────▶│  Consumer 1  │
┌──────────────┐              └─────────┘     └──────────────┘
│   Producer   │────▶ Exchange                              
└──────────────┘   (topic)              
              *.*.rabbit ────▶┌─────────┐     ┌──────────────┐
              lazy.# ────────▶│ Queue 2 │────▶│  Consumer 2  │
                              └─────────┘     └──────────────┘
```

### 应用场景

- 多维度消息过滤
- 复杂的日志系统
- 事件订阅系统

---

## 7.2 Topic 交换器

### Routing Key 格式

Topic 交换器的 routing key 由点号分隔的单词组成：

```
<word1>.<word2>.<word3>...

示例:
- stock.usd.nyse
- kern.critical
- user.order.created
- app.payment.success
```

### 通配符

| 通配符 | 说明 | 示例 |
|--------|------|------|
| `*` | 匹配一个单词 | `*.orange.*` 匹配 `a.orange.b` |
| `#` | 匹配零个或多个单词 | `lazy.#` 匹配 `lazy` 或 `lazy.a.b.c` |

### 匹配示例

```
Routing Key: quick.orange.rabbit

Binding Key          匹配结果
──────────────────────────────
*.orange.*           ✓ 匹配
*.*.rabbit           ✓ 匹配
lazy.#               ✗ 不匹配
quick.#              ✓ 匹配
#.rabbit             ✓ 匹配
*.orange.rabbit      ✗ 不匹配 (只有2个*)
```

---

## 7.3 特殊情况

### Topic 变成 Fanout

当绑定键为 `#` 时，Topic 交换器会接收所有消息，类似 Fanout：

```python
channel.queue_bind(exchange='topic_logs', queue=queue_name, routing_key='#')
```

### Topic 变成 Direct

当绑定键不包含通配符时，Topic 交换器的行为类似 Direct：

```python
channel.queue_bind(exchange='topic_logs', queue=queue_name, routing_key='error')
```

---

## 7.4 代码实现

### 生产者 (emit_log_topic.py)

```python
#!/usr/bin/env python
import pika
import sys

credentials = pika.PlainCredentials('admin', 'admin123')
connection = pika.BlockingConnection(
    pika.ConnectionParameters('localhost', credentials=credentials)
)
channel = connection.channel()

# 声明 topic 交换器
channel.exchange_declare(exchange='topic_logs', exchange_type='topic')

# routing key 格式: <facility>.<severity>
# 例如: kern.critical, auth.error, cron.info
routing_key = sys.argv[1] if len(sys.argv) > 1 else 'anonymous.info'
message = ' '.join(sys.argv[2:]) or 'Hello World!'

channel.basic_publish(
    exchange='topic_logs',
    routing_key=routing_key,
    body=message
)

print(f" [x] Sent '{routing_key}':'{message}'")
connection.close()
```

### 消费者 (receive_logs_topic.py)

```python
#!/usr/bin/env python
import pika
import sys

credentials = pika.PlainCredentials('admin', 'admin123')
connection = pika.BlockingConnection(
    pika.ConnectionParameters('localhost', credentials=credentials)
)
channel = connection.channel()

channel.exchange_declare(exchange='topic_logs', exchange_type='topic')

result = channel.queue_declare(queue='', exclusive=True)
queue_name = result.method.queue

# 从命令行获取绑定键
binding_keys = sys.argv[1:]
if not binding_keys:
    sys.stderr.write("Usage: %s [binding_key]...\n" % sys.argv[0])
    sys.exit(1)

for binding_key in binding_keys:
    channel.queue_bind(
        exchange='topic_logs',
        queue=queue_name,
        routing_key=binding_key
    )

print(f' [*] Waiting for logs. Binding keys: {binding_keys}')

def callback(ch, method, properties, body):
    print(f" [x] {method.routing_key}:{body.decode()}")

channel.basic_consume(
    queue=queue_name,
    on_message_callback=callback,
    auto_ack=True
)

channel.start_consuming()
```

### 测试场景

```bash
# 终端1: 接收所有 error 级别日志
python receive_logs_topic.py "*.error"

# 终端2: 接收 kern 相关的所有日志
python receive_logs_topic.py "kern.*"

# 终端3: 接收所有日志
python receive_logs_topic.py "#"

# 终端4: 发送各种日志
python emit_log_topic.py kern.critical "A critical kernel error"
python emit_log_topic.py kern.info "Kernel boot complete"
python emit_log_topic.py auth.error "Authentication failed"
python emit_log_topic.py cron.info "Cron job executed"
```

---

## 7.5 Java 实现

### 生产者 (EmitLogTopic.java)

```java
package com.example.rabbitmq;

import com.rabbitmq.client.Channel;
import com.rabbitmq.client.Connection;
import com.rabbitmq.client.ConnectionFactory;

public class EmitLogTopic {
    private static final String EXCHANGE_NAME = "topic_logs";

    public static void main(String[] args) throws Exception {
        ConnectionFactory factory = new ConnectionFactory();
        factory.setHost("localhost");
        factory.setUsername("admin");
        factory.setPassword("admin123");

        try (Connection connection = factory.newConnection();
             Channel channel = connection.createChannel()) {
            
            channel.exchangeDeclare(EXCHANGE_NAME, "topic");

            String routingKey = args.length < 1 ? "anonymous.info" : args[0];
            String message = args.length < 2 ? "Hello World!" : 
                String.join(" ", java.util.Arrays.copyOfRange(args, 1, args.length));

            channel.basicPublish(EXCHANGE_NAME, routingKey, null, message.getBytes("UTF-8"));
            System.out.println(" [x] Sent '" + routingKey + "':'" + message + "'");
        }
    }
}
```

### 消费者 (ReceiveLogsTopic.java)

```java
package com.example.rabbitmq;

import com.rabbitmq.client.*;

public class ReceiveLogsTopic {
    private static final String EXCHANGE_NAME = "topic_logs";

    public static void main(String[] args) throws Exception {
        if (args.length < 1) {
            System.err.println("Usage: ReceiveLogsTopic [binding_key]...");
            System.exit(1);
        }

        ConnectionFactory factory = new ConnectionFactory();
        factory.setHost("localhost");
        factory.setUsername("admin");
        factory.setPassword("admin123");

        Connection connection = factory.newConnection();
        Channel channel = connection.createChannel();

        channel.exchangeDeclare(EXCHANGE_NAME, "topic");
        
        String queueName = channel.queueDeclare().getQueue();

        for (String bindingKey : args) {
            channel.queueBind(queueName, EXCHANGE_NAME, bindingKey);
            System.out.println(" [*] Bound to: " + bindingKey);
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

## 7.6 Node.js 实现

### 生产者 (emit_log_topic.js)

```javascript
const amqp = require('amqplib');

const EXCHANGE_NAME = 'topic_logs';

async function main() {
    const connection = await amqp.connect('amqp://admin:admin123@localhost');
    const channel = await connection.createChannel();

    await channel.assertExchange(EXCHANGE_NAME, 'topic', { durable: false });

    const routingKey = process.argv[2] || 'anonymous.info';
    const msg = process.argv.slice(3).join(' ') || 'Hello World!';

    channel.publish(EXCHANGE_NAME, routingKey, Buffer.from(msg));
    console.log(` [x] Sent '${routingKey}':'${msg}'`);

    setTimeout(() => {
        connection.close();
        process.exit(0);
    }, 500);
}

main().catch(console.error);
```

### 消费者 (receive_logs_topic.js)

```javascript
const amqp = require('amqplib');

const EXCHANGE_NAME = 'topic_logs';

async function main() {
    const args = process.argv.slice(2);
    if (args.length === 0) {
        console.log('Usage: node receive_logs_topic.js [binding_key]...');
        process.exit(1);
    }

    const connection = await amqp.connect('amqp://admin:admin123@localhost');
    const channel = await connection.createChannel();

    await channel.assertExchange(EXCHANGE_NAME, 'topic', { durable: false });

    const { queue } = await channel.assertQueue('', { exclusive: true });

    for (const key of args) {
        await channel.bindQueue(queue, EXCHANGE_NAME, key);
        console.log(` [*] Bound to: ${key}`);
    }

    console.log(' [*] Waiting for messages.');

    channel.consume(queue, (msg) => {
        if (msg.content) {
            console.log(` [x] ${msg.fields.routingKey}:${msg.content.toString()}`);
        }
    }, { noAck: true });
}

main().catch(console.error);
```

---

## 7.7 实际应用：多维度事件系统

### 事件命名规范

```
<domain>.<entity>.<action>

示例:
- order.payment.success
- order.payment.failed
- user.profile.updated
- product.stock.low
- system.health.warning
```

### 订阅示例

```python
# 订阅所有订单事件
channel.queue_bind(exchange='events', queue=queue_name, routing_key='order.#')

# 订阅所有支付成功事件
channel.queue_bind(exchange='events', queue=queue_name, routing_key='*.payment.success')

# 订阅所有系统警告
channel.queue_bind(exchange='events', queue=queue_name, routing_key='system.*.warning')

# 订阅所有失败事件
channel.queue_bind(exchange='events', queue=queue_name, routing_key='*.*.failed')
```

### 架构图

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        多维度事件订阅系统                                     │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐  order.payment.success                                      │
│  │ Order       │─────────────────┐                                           │
│  │ Service     │                 │                                           │
│  └─────────────┘                 │                                           │
│                                  ▼                                           │
│  ┌─────────────┐        ┌─────────────────────┐        ┌─────────────────┐  │
│  │ User        │───────▶│  Topic Exchange:    │───────▶│ order.#         │  │
│  │ Service     │        │      events         │        │ (订单服务)       │  │
│  └─────────────┘        └─────────────────────┘        └─────────────────┘  │
│                                  │                                           │
│  ┌─────────────┐                 │                     ┌─────────────────┐  │
│  │ Product     │─────────────────┤────────────────────▶│ *.*.failed      │  │
│  │ Service     │                 │                     │ (告警服务)       │  │
│  └─────────────┘                 │                     └─────────────────┘  │
│                                  │                                           │
│                                  │                     ┌─────────────────┐  │
│                                  └────────────────────▶│ #               │  │
│                                                        │ (日志服务)       │  │
│                                                        └─────────────────┘  │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 7.8 本章小结

### 交换器类型对比

| 类型 | Routing Key | 匹配方式 | 使用场景 |
|------|-------------|----------|----------|
| **fanout** | 忽略 | 广播 | 通知所有 |
| **direct** | 精确匹配 | = | 单一条件 |
| **topic** | 通配符匹配 | *, # | 多维度 |

### 通配符规则

| 通配符 | 匹配规则 |
|--------|----------|
| `*` | 匹配恰好一个单词 |
| `#` | 匹配零个或多个单词 |

---

## 7.9 思考题

1. `*.*.rabbit` 和 `#.rabbit` 有什么区别？
2. Topic 交换器的性能相比 Direct 如何？
3. 如何设计一个良好的 routing key 命名规范？

---

**下一章**: [RPC 远程调用](../08-rpc/README.md)
