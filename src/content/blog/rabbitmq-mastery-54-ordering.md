---
title: "第54章：消息顺序性保证"
description: "在某些业务场景中，消息必须按照特定顺序处理。RabbitMQ 默认只保证单个队列内消息的顺序。"
pubDate: "2025-12-17"
tags: ["rabbitmq","mq","backend"]
category: "rabbitmq"
series: "RabbitMQ 消息队列"
order: 54
---

## 54.1 概述

在某些业务场景中，消息必须按照特定顺序处理。RabbitMQ 默认只保证单个队列内消息的顺序。

### 顺序性问题场景

```
┌─────────────────────────────────────────────────────────────────┐
│                    顺序性问题场景                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  场景1: 多消费者并行                                             │
│  Queue: [M1, M2, M3] ──▶ Consumer1 处理 M1                      │
│                      ──▶ Consumer2 处理 M2（先完成）            │
│  结果: M2 先于 M1 处理完成                                       │
│                                                                 │
│  场景2: 消息重试                                                 │
│  M1 处理失败 ──▶ 重新入队 ──▶ M1 排到 M2, M3 后面               │
│  结果: 顺序变成 M2, M3, M1                                       │
│                                                                 │
│  场景3: 多队列                                                   │
│  Exchange ──▶ Queue1: M1 ──▶ Consumer1                          │
│           ──▶ Queue2: M2 ──▶ Consumer2                          │
│  结果: 无法保证 M1 和 M2 的处理顺序                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 54.2 保证顺序的方案

| 方案 | 实现复杂度 | 吞吐量 | 适用场景 |
|------|------------|--------|----------|
| 单队列单消费者 | 低 | 低 | 强顺序要求 |
| 分区队列 | 中 | 高 | 分组顺序 |
| 序号+缓冲区 | 高 | 中 | 全局顺序 |

---

## 54.3 方案一：单队列单消费者

最简单的方案，但吞吐量受限。

```python
import pika

def ordered_consumer():
    """单消费者保证顺序"""
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()
    
    channel.queue_declare(queue='ordered_queue', durable=True)
    
    # 关键：prefetch=1，一次只处理一条
    channel.basic_qos(prefetch_count=1)
    
    def callback(ch, method, properties, body):
        message = body.decode()
        print(f"Processing: {message}")
        
        # 处理消息...
        
        # 处理完成后才确认
        ch.basic_ack(delivery_tag=method.delivery_tag)
    
    channel.basic_consume(
        queue='ordered_queue',
        on_message_callback=callback,
        auto_ack=False  # 必须手动确认
    )
    
    print('[*] Waiting for messages...')
    channel.start_consuming()
```

### 注意事项

- `prefetch_count=1` 确保一次只处理一条
- 必须使用手动确认
- 处理失败时 **不要 requeue**（会打乱顺序）

---

## 54.4 方案二：分区队列

按业务键（如用户ID、订单ID）路由到不同队列，保证同一业务键的消息顺序。

```
┌─────────────────────────────────────────────────────────────────┐
│                      分区队列架构                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Producer ──▶ hash(user_id) % 4 ──▶ Partition                  │
│                                                                 │
│  Partition 0 ──▶ Queue 0 ──▶ Consumer 0                        │
│  Partition 1 ──▶ Queue 1 ──▶ Consumer 1                        │
│  Partition 2 ──▶ Queue 2 ──▶ Consumer 2                        │
│  Partition 3 ──▶ Queue 3 ──▶ Consumer 3                        │
│                                                                 │
│  同一用户的消息总是路由到同一队列                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 生产者实现

```python
import pika
import hashlib

class PartitionedProducer:
    """分区生产者"""
    
    def __init__(self, num_partitions=4):
        self.num_partitions = num_partitions
        credentials = pika.PlainCredentials('admin', 'admin123')
        self.connection = pika.BlockingConnection(
            pika.ConnectionParameters('localhost', credentials=credentials)
        )
        self.channel = self.connection.channel()
        
        # 声明分区队列
        for i in range(num_partitions):
            self.channel.queue_declare(
                queue=f'partition_{i}',
                durable=True
            )
    
    def get_partition(self, partition_key):
        """根据分区键计算分区"""
        hash_value = int(hashlib.md5(
            partition_key.encode()
        ).hexdigest(), 16)
        return hash_value % self.num_partitions
    
    def publish(self, partition_key, message):
        """发送消息到对应分区"""
        partition = self.get_partition(partition_key)
        queue_name = f'partition_{partition}'
        
        self.channel.basic_publish(
            exchange='',
            routing_key=queue_name,
            body=message,
            properties=pika.BasicProperties(
                delivery_mode=2,
                headers={'x-partition-key': partition_key}
            )
        )
        
        print(f"Sent to partition {partition}: {message}")
    
    def close(self):
        self.connection.close()


# 使用示例
producer = PartitionedProducer(num_partitions=4)

# 同一用户的消息会发到同一分区
producer.publish('user_001', 'Order created')
producer.publish('user_001', 'Order paid')
producer.publish('user_001', 'Order shipped')

# 另一个用户可能在不同分区
producer.publish('user_002', 'Order created')

producer.close()
```

### 消费者实现

```python
import pika
import sys

def partition_consumer(partition_id):
    """分区消费者"""
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()
    
    queue_name = f'partition_{partition_id}'
    channel.queue_declare(queue=queue_name, durable=True)
    
    # 单消费者 + prefetch=1 保证分区内顺序
    channel.basic_qos(prefetch_count=1)
    
    def callback(ch, method, properties, body):
        partition_key = properties.headers.get('x-partition-key')
        print(f"[Partition {partition_id}] Key: {partition_key}, Message: {body.decode()}")
        
        # 处理消息...
        
        ch.basic_ack(delivery_tag=method.delivery_tag)
    
    channel.basic_consume(
        queue=queue_name,
        on_message_callback=callback,
        auto_ack=False
    )
    
    print(f'[Partition {partition_id}] Waiting for messages...')
    channel.start_consuming()


if __name__ == '__main__':
    partition_id = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    partition_consumer(partition_id)
```

### 使用 Consistent Hash Exchange

RabbitMQ 提供了 Consistent Hash Exchange 插件，自动实现分区路由。

```bash
# 启用插件
rabbitmq-plugins enable rabbitmq_consistent_hash_exchange
```

```python
# 声明 Consistent Hash Exchange
channel.exchange_declare(
    exchange='order_events',
    exchange_type='x-consistent-hash',
    durable=True
)

# 绑定队列，权重为 1
for i in range(4):
    channel.queue_declare(queue=f'order_queue_{i}', durable=True)
    channel.queue_bind(
        exchange='order_events',
        queue=f'order_queue_{i}',
        routing_key='1'  # 权重
    )

# 发送消息，routing_key 作为哈希键
channel.basic_publish(
    exchange='order_events',
    routing_key='user_001',  # 同一 key 路由到同一队列
    body='message'
)
```

---

## 54.5 方案三：序号+缓冲区

通过消息序号和消费端缓冲区实现全局顺序。

```python
import pika
import json
import threading
import time
from collections import defaultdict
from queue import PriorityQueue

class OrderedConsumer:
    """基于序号的有序消费者"""
    
    def __init__(self, queue_name):
        self.queue_name = queue_name
        self.expected_seq = defaultdict(lambda: 1)  # 期望的下一个序号
        self.buffer = defaultdict(PriorityQueue)    # 缓冲区
        self.lock = threading.Lock()
        
        credentials = pika.PlainCredentials('admin', 'admin123')
        self.connection = pika.BlockingConnection(
            pika.ConnectionParameters('localhost', credentials=credentials)
        )
        self.channel = self.connection.channel()
        self.channel.queue_declare(queue=queue_name, durable=True)
        self.channel.basic_qos(prefetch_count=10)
    
    def process_message(self, group_key, seq, data):
        """实际处理消息"""
        print(f"[{group_key}] Processing seq={seq}: {data}")
    
    def try_process_buffered(self, group_key):
        """尝试处理缓冲区中的消息"""
        with self.lock:
            while not self.buffer[group_key].empty():
                # 查看最小序号
                seq, data = self.buffer[group_key].queue[0]
                
                if seq == self.expected_seq[group_key]:
                    # 序号匹配，处理
                    self.buffer[group_key].get()
                    self.process_message(group_key, seq, data)
                    self.expected_seq[group_key] += 1
                else:
                    # 还没到
                    break
    
    def callback(self, ch, method, properties, body):
        """消息回调"""
        msg = json.loads(body)
        group_key = msg['group_key']
        seq = msg['seq']
        data = msg['data']
        
        with self.lock:
            expected = self.expected_seq[group_key]
            
            if seq == expected:
                # 序号匹配，直接处理
                self.process_message(group_key, seq, data)
                self.expected_seq[group_key] += 1
                ch.basic_ack(delivery_tag=method.delivery_tag)
                
                # 检查缓冲区
                self.try_process_buffered(group_key)
                
            elif seq > expected:
                # 序号超前，放入缓冲区
                print(f"[{group_key}] Buffering seq={seq}, expected={expected}")
                self.buffer[group_key].put((seq, data))
                ch.basic_ack(delivery_tag=method.delivery_tag)
                
            else:
                # 序号过期（重复消息）
                print(f"[{group_key}] Duplicate seq={seq}, discarding")
                ch.basic_ack(delivery_tag=method.delivery_tag)
    
    def start(self):
        self.channel.basic_consume(
            queue=self.queue_name,
            on_message_callback=self.callback,
            auto_ack=False
        )
        print('[*] Waiting for ordered messages...')
        self.channel.start_consuming()


# 生产者发送带序号的消息
def send_ordered_messages():
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()
    
    channel.queue_declare(queue='ordered_queue', durable=True)
    
    # 为每个 group 维护序号
    sequences = defaultdict(lambda: 1)
    
    def publish(group_key, data):
        seq = sequences[group_key]
        sequences[group_key] += 1
        
        message = json.dumps({
            'group_key': group_key,
            'seq': seq,
            'data': data
        })
        
        channel.basic_publish(
            exchange='',
            routing_key='ordered_queue',
            body=message,
            properties=pika.BasicProperties(delivery_mode=2)
        )
        print(f"Sent: group={group_key}, seq={seq}")
    
    # 发送测试消息
    publish('user_001', 'Step 1')
    publish('user_001', 'Step 2')
    publish('user_001', 'Step 3')
    publish('user_002', 'Step 1')
    publish('user_001', 'Step 4')
    
    connection.close()
```

---

## 54.6 失败处理

顺序消息的失败处理比较复杂：

```python
def callback_with_failure_handling(ch, method, properties, body):
    """带失败处理的顺序消费"""
    msg = json.loads(body)
    group_key = msg['group_key']
    seq = msg['seq']
    
    try:
        process_message(msg)
        ch.basic_ack(delivery_tag=method.delivery_tag)
        
    except TemporaryError:
        # 临时错误，暂停该分组的处理
        # 将消息发送到延迟队列稍后重试
        ch.basic_publish(
            exchange='delay_exchange',
            routing_key='delay_queue',
            body=body,
            properties=pika.BasicProperties(
                headers={'x-delay': 5000}  # 5秒后重试
            )
        )
        ch.basic_ack(delivery_tag=method.delivery_tag)
        
    except PermanentError:
        # 永久错误，发送到死信队列，同时需要告警
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)
        
        # 发送告警
        alert(f"Order {group_key} seq {seq} failed permanently")
```

---

## 54.7 本章小结

| 方案 | 顺序保证范围 | 吞吐量 | 适用场景 |
|------|--------------|--------|----------|
| 单队列单消费者 | 全局 | 低 | 消息量少 |
| 分区队列 | 分组内 | 高 | 大多数场景 |
| 序号+缓冲区 | 分组内 | 中 | 需要乱序容忍 |

### 最佳实践

1. **优先使用分区方案**
2. **合理设计分区键**（如用户ID、订单ID）
3. **失败时不要 requeue**
4. **考虑是否真的需要全局顺序**

---

**下一章**: [消息积压处理](../55-backlog/README.md)
