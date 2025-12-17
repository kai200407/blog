---
title: "第15章：优先级队列"
description: "优先级队列允许消息按优先级顺序被消费，高优先级消息先被处理。"
pubDate: "2025-12-17"
tags: ["rabbitmq","mq","backend"]
category: "rabbitmq"
series: "RabbitMQ 消息队列"
order: 15
---

## 15.1 概述

优先级队列允许消息按优先级顺序被消费，高优先级消息先被处理。

### 使用场景

- VIP 用户订单优先处理
- 紧急告警优先发送
- 重要任务优先执行

---

## 15.2 创建优先级队列

```python
import pika

credentials = pika.PlainCredentials('admin', 'admin123')
connection = pika.BlockingConnection(
    pika.ConnectionParameters('localhost', credentials=credentials)
)
channel = connection.channel()

# 声明优先级队列，设置最大优先级
channel.queue_declare(
    queue='priority_queue',
    durable=True,
    arguments={
        'x-max-priority': 10  # 优先级范围 0-10
    }
)

print("Priority queue created")
connection.close()
```

### 参数说明

| 参数 | 说明 |
|------|------|
| `x-max-priority` | 最大优先级值（建议 1-10） |

**注意**：值越大消耗的 CPU 和内存越多，建议不超过 10。

---

## 15.3 发送优先级消息

```python
import pika

def send_priority_message(message, priority):
    """发送带优先级的消息"""
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()
    
    channel.basic_publish(
        exchange='',
        routing_key='priority_queue',
        body=message,
        properties=pika.BasicProperties(
            delivery_mode=2,
            priority=priority,  # 设置优先级
        )
    )
    
    print(f"Sent [{priority}]: {message}")
    connection.close()

# 发送不同优先级的消息
send_priority_message("Low priority task", priority=1)
send_priority_message("Normal priority task", priority=5)
send_priority_message("High priority task", priority=10)
send_priority_message("Another low priority", priority=2)
send_priority_message("VIP task", priority=10)
```

---

## 15.4 消费优先级消息

```python
import pika
import time

def priority_consumer():
    """消费优先级队列"""
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()
    
    channel.queue_declare(
        queue='priority_queue',
        durable=True,
        arguments={'x-max-priority': 10}
    )
    
    # prefetch=1 确保按优先级逐条处理
    channel.basic_qos(prefetch_count=1)
    
    def callback(ch, method, properties, body):
        priority = properties.priority or 0
        print(f"[Priority {priority}] Received: {body.decode()}")
        
        # 模拟处理
        time.sleep(0.5)
        
        ch.basic_ack(delivery_tag=method.delivery_tag)
    
    channel.basic_consume(
        queue='priority_queue',
        on_message_callback=callback,
        auto_ack=False
    )
    
    print('Waiting for priority messages...')
    channel.start_consuming()

if __name__ == '__main__':
    priority_consumer()
```

---

## 15.5 完整示例

```python
#!/usr/bin/env python
"""优先级队列完整示例"""
import pika
import time
import sys
import random

QUEUE_NAME = 'task_priority_queue'
MAX_PRIORITY = 10

def setup():
    """初始化队列"""
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()
    
    channel.queue_declare(
        queue=QUEUE_NAME,
        durable=True,
        arguments={'x-max-priority': MAX_PRIORITY}
    )
    
    print(f"Queue '{QUEUE_NAME}' ready (max priority: {MAX_PRIORITY})")
    connection.close()


def producer(count=20):
    """生产者：发送随机优先级的任务"""
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()
    
    priorities = {
        'low': 1,
        'normal': 5,
        'high': 8,
        'urgent': 10,
    }
    
    for i in range(count):
        level = random.choice(list(priorities.keys()))
        priority = priorities[level]
        message = f"Task-{i+1} ({level})"
        
        channel.basic_publish(
            exchange='',
            routing_key=QUEUE_NAME,
            body=message,
            properties=pika.BasicProperties(
                delivery_mode=2,
                priority=priority,
            )
        )
        print(f"Sent: {message} [priority={priority}]")
    
    connection.close()
    print(f"\nSent {count} tasks with random priorities")


def consumer():
    """消费者：按优先级处理任务"""
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()
    
    channel.basic_qos(prefetch_count=1)
    
    processed = []
    
    def callback(ch, method, properties, body):
        priority = properties.priority or 0
        message = body.decode()
        
        print(f"Processing [{priority:2d}]: {message}")
        processed.append((priority, message))
        
        time.sleep(0.2)
        ch.basic_ack(delivery_tag=method.delivery_tag)
    
    channel.basic_consume(
        queue=QUEUE_NAME,
        on_message_callback=callback,
        auto_ack=False
    )
    
    print("Waiting for tasks (Ctrl+C to stop)...\n")
    
    try:
        channel.start_consuming()
    except KeyboardInterrupt:
        print(f"\n\nProcessed {len(processed)} tasks")
        print("Processing order (by priority):")
        for p, m in processed[:10]:
            print(f"  [{p:2d}] {m}")
    
    connection.close()


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python priority_queue.py [setup|producer|consumer]")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == 'setup':
        setup()
    elif command == 'producer':
        count = int(sys.argv[2]) if len(sys.argv) > 2 else 20
        producer(count)
    elif command == 'consumer':
        consumer()
```

---

## 15.6 优先级队列行为

```
┌─────────────────────────────────────────────────────────────────┐
│                    优先级队列行为说明                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  消息入队:                                                      │
│  ├── 队列空时：新消息直接可被消费                               │
│  └── 队列非空时：按优先级插入到合适位置                         │
│                                                                 │
│  消息出队:                                                      │
│  ├── 高优先级消息先出队                                         │
│  └── 相同优先级按 FIFO 顺序                                     │
│                                                                 │
│  注意事项:                                                      │
│  ├── 消费者空闲时，优先级不起作用                               │
│  ├── 只在消息堆积时优先级才有意义                               │
│  └── prefetch=1 可确保严格按优先级处理                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 15.7 Java 实现

```java
// 声明优先级队列
Map<String, Object> args = new HashMap<>();
args.put("x-max-priority", 10);

channel.queueDeclare("priority_queue", true, false, false, args);

// 发送优先级消息
AMQP.BasicProperties props = new AMQP.BasicProperties.Builder()
    .deliveryMode(2)
    .priority(10)  // 高优先级
    .build();

channel.basicPublish("", "priority_queue", props, message.getBytes());
```

---

## 15.8 最佳实践

1. **优先级范围不要太大** - 建议 1-10
2. **设置 prefetch=1** - 确保按优先级处理
3. **合理使用** - 只在需要时设置高优先级
4. **监控** - 监控各优先级消息数量

---

## 15.9 本章小结

| 配置 | 说明 |
|------|------|
| `x-max-priority` | 队列最大优先级 |
| `properties.priority` | 消息优先级 |
| 默认优先级 | 0 |

---

**下一章**: [消息确认与事务](../16-transactions/README.md)
