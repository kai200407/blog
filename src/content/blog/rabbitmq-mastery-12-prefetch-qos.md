---
title: "第12章：消费者预取与 QoS"
description: "QoS（Quality of Service）机制用于控制消费者接收消息的数量，防止消费者过载。"
pubDate: "2025-12-17"
tags: ["rabbitmq","mq","backend"]
category: "rabbitmq"
series: "RabbitMQ 消息队列"
order: 12
---

## 12.1 概述

QoS（Quality of Service）机制用于控制消费者接收消息的数量，防止消费者过载。

### 问题场景

```
┌─────────────────────────────────────────────────────────────────┐
│                    无 prefetch 的问题                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Queue: [M1][M2][M3][M4][M5][M6][M7][M8][M9][M10]...            │
│                     │                                           │
│                     ▼ 一次性推送所有消息                         │
│         ┌───────────────────────────────────────┐              │
│         │              Consumer                  │              │
│         │  处理中: [M1][M2][M3][M4][M5]...       │              │
│         │  内存溢出风险！                         │              │
│         └───────────────────────────────────────┘              │
│                                                                 │
│  问题:                                                          │
│  1. 消费者内存可能溢出                                          │
│  2. 消息分配不均匀                                              │
│  3. 处理慢的消费者堆积大量消息                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 12.2 设置 prefetch

```python
# 设置预取数量
channel.basic_qos(prefetch_count=1)
```

### 参数说明

| 参数 | 说明 |
|------|------|
| `prefetch_count` | 每个消费者最多未确认消息数 |
| `prefetch_size` | 未确认消息总大小（字节），0表示不限 |
| `global` | 是否应用于整个 Channel |

### global 参数

```python
# 每个消费者最多 10 条未确认
channel.basic_qos(prefetch_count=10, global_qos=False)

# 整个 Channel 最多 10 条未确认（所有消费者共享）
channel.basic_qos(prefetch_count=10, global_qos=True)
```

---

## 12.3 公平分发

设置 `prefetch_count=1` 实现公平分发。

```
┌─────────────────────────────────────────────────────────────────┐
│                    prefetch_count=1 效果                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Queue: [M1][M2][M3][M4][M5][M6]                                │
│            │     │                                              │
│            │     │                                              │
│            ▼     ▼                                              │
│  ┌─────────────┐  ┌─────────────┐                              │
│  │ Consumer 1  │  │ Consumer 2  │                              │
│  │ 处理: [M1]  │  │ 处理: [M2]  │                              │
│  │ (处理慢)    │  │ (处理快)    │                              │
│  └─────────────┘  └─────────────┘                              │
│                          │                                      │
│                          ▼ M2完成，获取M3                       │
│                   ┌─────────────┐                              │
│                   │ Consumer 2  │                              │
│                   │ 处理: [M3]  │                              │
│                   └─────────────┘                              │
│                                                                 │
│  结果: 快的消费者处理更多消息                                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 12.4 代码示例

### Python

```python
#!/usr/bin/env python
"""prefetch 示例"""
import pika
import time
import random

def consumer_with_qos():
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()
    
    channel.queue_declare(queue='qos_demo', durable=True)
    
    # 设置 prefetch
    channel.basic_qos(prefetch_count=1)
    
    def callback(ch, method, properties, body):
        message = body.decode()
        print(f"[x] Received: {message}")
        
        # 模拟处理时间
        process_time = random.uniform(0.5, 2.0)
        time.sleep(process_time)
        
        print(f"[x] Done: {message} ({process_time:.1f}s)")
        
        # 确认消息
        ch.basic_ack(delivery_tag=method.delivery_tag)
    
    channel.basic_consume(
        queue='qos_demo',
        on_message_callback=callback,
        auto_ack=False
    )
    
    print('[*] Waiting for messages. To exit press CTRL+C')
    channel.start_consuming()


if __name__ == '__main__':
    consumer_with_qos()
```

### Java

```java
// 设置 QoS
channel.basicQos(1);  // prefetch_count = 1

// 或者设置大小限制
channel.basicQos(
    0,      // prefetch_size: 0表示不限制
    10,     // prefetch_count: 最多10条
    false   // global: false表示每个消费者独立
);

// 消费消息
channel.basicConsume("qos_demo", false, deliverCallback, consumerTag -> {});
```

---

## 12.5 prefetch 值的选择

### 建议

| 场景 | prefetch_count | 说明 |
|------|----------------|------|
| CPU密集型处理 | 1 | 公平分发，避免堆积 |
| IO密集型处理 | 10-50 | 减少网络往返 |
| 快速处理 | 100-500 | 提高吞吐量 |
| 消费者数量多 | 较小值 | 避免单个消费者占用过多 |

### 性能对比

```
┌─────────────────────────────────────────────────────────────────┐
│                    prefetch_count 性能影响                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  测试场景: 10,000 条消息，单消费者                               │
│                                                                 │
│  prefetch=1:    处理时间 30s，吞吐量 333 msg/s                  │
│  prefetch=10:   处理时间 20s，吞吐量 500 msg/s                  │
│  prefetch=100:  处理时间 15s，吞吐量 667 msg/s                  │
│  prefetch=0:    处理时间 12s，吞吐量 833 msg/s（无限制）        │
│                                                                 │
│  注意: prefetch=0 可能导致内存问题                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 12.6 多消费者场景

```python
#!/usr/bin/env python
"""多消费者公平分发"""
import pika
import time
import sys
import os

def worker(worker_id):
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()
    
    channel.queue_declare(queue='work_queue', durable=True)
    
    # 公平分发
    channel.basic_qos(prefetch_count=1)
    
    processed = [0]
    
    def callback(ch, method, properties, body):
        message = body.decode()
        print(f"[Worker {worker_id}] Processing: {message}")
        
        # 模拟不同处理速度
        time.sleep(worker_id * 0.5)  # worker 1快，worker 2慢
        
        processed[0] += 1
        print(f"[Worker {worker_id}] Done. Total: {processed[0]}")
        
        ch.basic_ack(delivery_tag=method.delivery_tag)
    
    channel.basic_consume(
        queue='work_queue',
        on_message_callback=callback,
        auto_ack=False
    )
    
    print(f'[Worker {worker_id}] Started. To exit press CTRL+C')
    channel.start_consuming()


if __name__ == '__main__':
    worker_id = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    worker(worker_id)
```

---

## 12.7 本章小结

| 配置 | 效果 |
|------|------|
| `prefetch_count=0` | 无限制（不推荐） |
| `prefetch_count=1` | 公平分发 |
| `prefetch_count=N` | 每消费者最多 N 条未确认 |
| `global=True` | Channel 级别限制 |

### 最佳实践

1. **始终设置 prefetch**
2. 根据处理速度调整值
3. 配合手动确认使用
4. 监控未确认消息数量

---

**下一章**: [死信队列](../13-dead-letter/README.md)
