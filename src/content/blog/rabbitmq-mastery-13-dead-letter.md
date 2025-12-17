---
title: "第13章：死信队列 (Dead Letter Exchange)"
description: "死信队列（Dead Letter Queue，DLQ）用于存储无法被正常消费的消息，是 RabbitMQ 的重要特性。"
pubDate: "2025-12-17"
tags: ["rabbitmq","mq","backend"]
category: "rabbitmq"
series: "RabbitMQ 消息队列"
order: 13
---

## 13.1 概述

死信队列（Dead Letter Queue，DLQ）用于存储无法被正常消费的消息，是 RabbitMQ 的重要特性。

### 什么是死信

当消息满足以下条件之一时，会变成"死信"：

1. **消息被拒绝** (basic.reject / basic.nack) 且 `requeue=false`
2. **消息 TTL 过期**
3. **队列达到最大长度** (max-length)

### 死信流程

```
┌──────────────┐     ┌─────────────────┐     ┌──────────────────────┐
│   Producer   │────▶│  Normal Queue   │────▶│   Consumer           │
└──────────────┘     └────────┬────────┘     │   ↓ 处理失败/拒绝     │
                              │              └──────────┬───────────┘
                              │                         │
                      消息变成死信                       │
                              │                         │
                              ▼                         │
                     ┌─────────────────┐               │
                     │   Dead Letter   │◀──────────────┘
                     │   Exchange (DLX)│
                     └────────┬────────┘
                              │
                              ▼
                     ┌─────────────────┐     ┌──────────────────────┐
                     │  Dead Letter    │────▶│  DLQ Consumer        │
                     │  Queue (DLQ)    │     │  (告警/日志/重试)     │
                     └─────────────────┘     └──────────────────────┘
```

---

## 13.2 配置死信队列

### 队列参数

| 参数 | 说明 |
|------|------|
| `x-dead-letter-exchange` | 死信交换器名称 |
| `x-dead-letter-routing-key` | 死信路由键（可选） |

### Python 示例

```python
import pika

credentials = pika.PlainCredentials('admin', 'admin123')
connection = pika.BlockingConnection(
    pika.ConnectionParameters('localhost', credentials=credentials)
)
channel = connection.channel()

# 1. 声明死信交换器
channel.exchange_declare(exchange='dlx_exchange', exchange_type='direct')

# 2. 声明死信队列
channel.queue_declare(queue='dead_letter_queue', durable=True)

# 3. 绑定死信队列到死信交换器
channel.queue_bind(
    exchange='dlx_exchange',
    queue='dead_letter_queue',
    routing_key='dead_letter'
)

# 4. 声明业务队列，配置死信参数
args = {
    'x-dead-letter-exchange': 'dlx_exchange',
    'x-dead-letter-routing-key': 'dead_letter',
    'x-message-ttl': 10000,  # 可选：消息10秒后过期
    'x-max-length': 100,     # 可选：队列最大长度
}
channel.queue_declare(queue='business_queue', durable=True, arguments=args)

print("Queues declared with dead letter configuration")
connection.close()
```

---

## 13.3 触发死信的场景

### 场景1：消息被拒绝

```python
# 生产者
channel.basic_publish(
    exchange='',
    routing_key='business_queue',
    body='Test message'
)

# 消费者 - 拒绝消息
def callback(ch, method, properties, body):
    try:
        # 处理消息
        process(body)
        ch.basic_ack(delivery_tag=method.delivery_tag)
    except Exception as e:
        # 拒绝消息，不重新入队 -> 进入死信队列
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)

channel.basic_consume(queue='business_queue', on_message_callback=callback)
```

### 场景2：消息 TTL 过期

```python
# 方式1：队列级别 TTL
args = {
    'x-dead-letter-exchange': 'dlx_exchange',
    'x-message-ttl': 60000,  # 60秒
}
channel.queue_declare(queue='ttl_queue', arguments=args)

# 方式2：消息级别 TTL
channel.basic_publish(
    exchange='',
    routing_key='business_queue',
    body='Expiring message',
    properties=pika.BasicProperties(
        expiration='30000',  # 30秒后过期
    )
)
```

### 场景3：队列超出最大长度

```python
args = {
    'x-dead-letter-exchange': 'dlx_exchange',
    'x-max-length': 10,  # 最多10条消息
}
channel.queue_declare(queue='limited_queue', arguments=args)

# 当第11条消息到达时，最老的消息进入死信队列
```

---

## 13.4 完整示例

### 设置脚本 (setup_dlx.py)

```python
#!/usr/bin/env python
import pika

def setup():
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()

    # 死信交换器和队列
    channel.exchange_declare(exchange='dlx', exchange_type='direct', durable=True)
    channel.queue_declare(queue='dlq', durable=True)
    channel.queue_bind(exchange='dlx', queue='dlq', routing_key='dlq_routing_key')

    # 业务队列
    channel.queue_declare(
        queue='order_queue',
        durable=True,
        arguments={
            'x-dead-letter-exchange': 'dlx',
            'x-dead-letter-routing-key': 'dlq_routing_key',
        }
    )

    print("Setup complete!")
    connection.close()

if __name__ == '__main__':
    setup()
```

### 生产者 (producer.py)

```python
#!/usr/bin/env python
import pika
import json

credentials = pika.PlainCredentials('admin', 'admin123')
connection = pika.BlockingConnection(
    pika.ConnectionParameters('localhost', credentials=credentials)
)
channel = connection.channel()

for i in range(10):
    order = {'order_id': i, 'status': 'pending'}
    channel.basic_publish(
        exchange='',
        routing_key='order_queue',
        body=json.dumps(order),
        properties=pika.BasicProperties(delivery_mode=2)
    )
    print(f"Sent order {i}")

connection.close()
```

### 业务消费者 (consumer.py)

```python
#!/usr/bin/env python
import pika
import json
import random

credentials = pika.PlainCredentials('admin', 'admin123')
connection = pika.BlockingConnection(
    pika.ConnectionParameters('localhost', credentials=credentials)
)
channel = connection.channel()
channel.basic_qos(prefetch_count=1)

def callback(ch, method, properties, body):
    order = json.loads(body)
    print(f"Processing order {order['order_id']}")
    
    # 模拟随机失败
    if random.random() < 0.3:
        print(f"  -> Failed! Sending to DLQ")
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)
    else:
        print(f"  -> Success!")
        ch.basic_ack(delivery_tag=method.delivery_tag)

channel.basic_consume(queue='order_queue', on_message_callback=callback)

print("Waiting for orders...")
channel.start_consuming()
```

### 死信消费者 (dlq_consumer.py)

```python
#!/usr/bin/env python
import pika
import json

credentials = pika.PlainCredentials('admin', 'admin123')
connection = pika.BlockingConnection(
    pika.ConnectionParameters('localhost', credentials=credentials)
)
channel = connection.channel()

def callback(ch, method, properties, body):
    order = json.loads(body)
    print(f"[DLQ] Received failed order: {order}")
    
    # 记录日志、发送告警、或重试处理
    # ...
    
    ch.basic_ack(delivery_tag=method.delivery_tag)

channel.basic_consume(queue='dlq', on_message_callback=callback)

print("Waiting for dead letters...")
channel.start_consuming()
```

---

## 13.5 死信消息属性

当消息变成死信后，会在 headers 中添加以下属性：

| 属性 | 说明 |
|------|------|
| `x-first-death-exchange` | 第一次死亡时的交换器 |
| `x-first-death-queue` | 第一次死亡时的队列 |
| `x-first-death-reason` | 死亡原因 (rejected/expired/maxlen) |
| `x-death` | 死亡历史记录（数组） |

### 获取死信信息

```python
def dlq_callback(ch, method, properties, body):
    headers = properties.headers or {}
    
    if 'x-death' in headers:
        death_info = headers['x-death'][0]
        print(f"Death reason: {death_info.get('reason')}")
        print(f"Original queue: {death_info.get('queue')}")
        print(f"Death count: {death_info.get('count')}")
        print(f"Death time: {death_info.get('time')}")
    
    # 处理死信...
```

---

## 13.6 消息重试机制

### 重试架构

```
┌─────────────────────────────────────────────────────────────────────┐
│                         消息重试机制                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐     ┌─────────────┐     ┌──────────────────────┐  │
│  │  Producer   │────▶│ Work Queue  │────▶│     Consumer         │  │
│  └─────────────┘     └──────┬──────┘     └───────────┬──────────┘  │
│                             │                        │              │
│                             │◀───── 重试 ────────────┤ 失败        │
│                             │                        │              │
│                             │                        ▼              │
│                      ┌──────┴──────┐         ┌─────────────┐       │
│                      │  Retry DLX  │◀────────│  判断重试   │       │
│                      └──────┬──────┘         │  次数 < 3   │       │
│                             │                └──────┬──────┘       │
│                             ▼                       │ 超过3次      │
│                      ┌─────────────┐                ▼              │
│                      │ Retry Queue │         ┌─────────────┐       │
│                      │  (TTL=30s)  │         │  Final DLQ  │       │
│                      └─────────────┘         │  (人工处理)  │       │
│                                              └─────────────┘       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 重试实现

```python
import pika
import json

MAX_RETRY = 3
RETRY_DELAY = 30000  # 30秒

def setup_retry_queues():
    channel.exchange_declare(exchange='retry_exchange', exchange_type='direct')
    channel.exchange_declare(exchange='final_dlx', exchange_type='direct')
    
    # 重试队列（带延迟）
    channel.queue_declare(
        queue='retry_queue',
        arguments={
            'x-dead-letter-exchange': '',  # 默认交换器
            'x-dead-letter-routing-key': 'work_queue',
            'x-message-ttl': RETRY_DELAY,
        }
    )
    channel.queue_bind(exchange='retry_exchange', queue='retry_queue', routing_key='retry')
    
    # 最终死信队列
    channel.queue_declare(queue='final_dlq')
    channel.queue_bind(exchange='final_dlx', queue='final_dlq', routing_key='final_dead')

def callback(ch, method, properties, body):
    headers = properties.headers or {}
    retry_count = headers.get('x-retry-count', 0)
    
    try:
        # 处理消息
        process(body)
        ch.basic_ack(delivery_tag=method.delivery_tag)
    except Exception as e:
        ch.basic_ack(delivery_tag=method.delivery_tag)  # 先确认
        
        if retry_count < MAX_RETRY:
            # 重试
            new_headers = {'x-retry-count': retry_count + 1}
            ch.basic_publish(
                exchange='retry_exchange',
                routing_key='retry',
                body=body,
                properties=pika.BasicProperties(headers=new_headers)
            )
            print(f"Retry {retry_count + 1}/{MAX_RETRY}")
        else:
            # 超过重试次数，进入最终死信队列
            ch.basic_publish(
                exchange='final_dlx',
                routing_key='final_dead',
                body=body
            )
            print(f"Max retry exceeded, sent to final DLQ")
```

---

## 13.7 应用场景

| 场景 | 说明 |
|------|------|
| **异常处理** | 处理失败的消息单独存储分析 |
| **消息重试** | 结合延迟队列实现消息重试 |
| **订单超时** | 订单超时未支付自动取消 |
| **监控告警** | 监控死信队列发送告警 |
| **数据恢复** | 保留失败消息便于人工处理 |

---

## 13.8 本章小结

| 概念 | 说明 |
|------|------|
| **死信** | 无法正常消费的消息 |
| **DLX** | Dead Letter Exchange，死信交换器 |
| **DLQ** | Dead Letter Queue，死信队列 |
| **触发条件** | 拒绝、过期、超长度 |
| **x-death** | 死信消息携带的历史信息 |

---

## 13.9 思考题

1. 死信队列的消息是否可以再次变成死信？
2. 如何监控死信队列的消息堆积？
3. 死信队列与消息重试如何结合使用？

---

**下一章**: [延迟队列](../14-delayed-queue/README.md)
