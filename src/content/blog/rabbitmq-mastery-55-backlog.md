---
title: "第55章：消息积压处理"
description: "消息积压是生产环境常见问题，当消费速度跟不上生产速度时，队列中会堆积大量消息。"
pubDate: "2025-12-17"
tags: ["rabbitmq","mq","backend"]
category: "rabbitmq"
series: "RabbitMQ 消息队列"
order: 55
---

## 55.1 概述

消息积压是生产环境常见问题，当消费速度跟不上生产速度时，队列中会堆积大量消息。

### 积压原因分析

```
┌─────────────────────────────────────────────────────────────────┐
│                     消息积压原因                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  生产端:                                                        │
│  ├── 流量突增（促销、热点事件）                                 │
│  ├── 批量任务执行                                               │
│  └── 上游系统故障恢复后重放                                     │
│                                                                 │
│  消费端:                                                        │
│  ├── 消费者处理速度慢                                           │
│  ├── 消费者故障/下线                                            │
│  ├── 下游依赖服务慢/超时                                        │
│  └── 数据库/缓存性能问题                                        │
│                                                                 │
│  消息端:                                                        │
│  ├── 大量消息重试                                               │
│  └── 消息处理失败循环                                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 55.2 监控与告警

### 关键指标

```bash
# 查看队列消息数
rabbitmqctl list_queues name messages messages_ready messages_unacknowledged

# 查看消费者数
rabbitmqctl list_queues name consumers
```

### Prometheus 告警规则

```yaml
groups:
  - name: rabbitmq_backlog
    rules:
      # 队列积压告警
      - alert: RabbitMQQueueBacklog
        expr: rabbitmq_queue_messages > 10000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Queue {{ $labels.queue }} has {{ $value }} messages"
      
      # 严重积压
      - alert: RabbitMQQueueBacklogCritical
        expr: rabbitmq_queue_messages > 100000
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Critical backlog in queue {{ $labels.queue }}"
      
      # 消息增长速率
      - alert: RabbitMQMessageGrowth
        expr: rate(rabbitmq_queue_messages[5m]) > 1000
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Queue {{ $labels.queue }} growing at {{ $value }}/s"
```

---

## 55.3 紧急处理方案

### 方案一：增加消费者

```python
#!/usr/bin/env python
"""紧急扩容消费者脚本"""
import subprocess
import sys
import time

def scale_consumers(queue_name, target_count):
    """扩容消费者"""
    current = get_current_consumer_count()
    
    if target_count > current:
        for i in range(target_count - current):
            # 启动新消费者进程
            subprocess.Popen([
                'python', 'consumer.py',
                '--queue', queue_name,
                '--id', str(current + i + 1)
            ])
            print(f"Started consumer {current + i + 1}")
        
        print(f"Scaled from {current} to {target_count} consumers")
    
    return target_count

# 使用示例
if __name__ == '__main__':
    queue = sys.argv[1]
    count = int(sys.argv[2])
    scale_consumers(queue, count)
```

### 方案二：批量消费

```python
import pika
import json

def batch_consumer(batch_size=100):
    """批量消费模式"""
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()
    
    # 增大 prefetch
    channel.basic_qos(prefetch_count=batch_size)
    
    batch = []
    delivery_tags = []
    
    def callback(ch, method, properties, body):
        nonlocal batch, delivery_tags
        
        batch.append(json.loads(body))
        delivery_tags.append(method.delivery_tag)
        
        if len(batch) >= batch_size:
            # 批量处理
            process_batch(batch)
            
            # 批量确认
            ch.basic_ack(delivery_tag=delivery_tags[-1], multiple=True)
            
            batch = []
            delivery_tags = []
    
    channel.basic_consume(
        queue='backlog_queue',
        on_message_callback=callback,
        auto_ack=False
    )
    
    channel.start_consuming()

def process_batch(messages):
    """批量处理消息"""
    # 批量写入数据库
    # 批量调用API
    print(f"Processed {len(messages)} messages")
```

### 方案三：临时跳过非关键消息

```python
def emergency_consumer():
    """紧急模式：只处理关键消息"""
    
    def callback(ch, method, properties, body):
        msg = json.loads(body)
        
        # 只处理高优先级消息
        priority = msg.get('priority', 'low')
        
        if priority == 'high':
            process_message(msg)
        else:
            # 低优先级消息发送到延迟队列稍后处理
            ch.basic_publish(
                exchange='delay_exchange',
                routing_key='delay_queue',
                body=body,
                properties=pika.BasicProperties(
                    headers={'x-delay': 3600000}  # 1小时后
                )
            )
        
        ch.basic_ack(delivery_tag=method.delivery_tag)
    
    # ...
```

### 方案四：消息转储

```python
def dump_messages(queue_name, output_file, count=None):
    """将消息转储到文件"""
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()
    
    dumped = 0
    
    with open(output_file, 'w') as f:
        while True:
            method, properties, body = channel.basic_get(
                queue=queue_name,
                auto_ack=True
            )
            
            if method is None:
                break
            
            f.write(json.dumps({
                'body': body.decode(),
                'properties': {
                    'message_id': properties.message_id,
                    'headers': properties.headers,
                }
            }) + '\n')
            
            dumped += 1
            
            if count and dumped >= count:
                break
            
            if dumped % 1000 == 0:
                print(f"Dumped {dumped} messages")
    
    print(f"Total dumped: {dumped} messages to {output_file}")
    connection.close()


def restore_messages(queue_name, input_file):
    """从文件恢复消息"""
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()
    
    restored = 0
    
    with open(input_file, 'r') as f:
        for line in f:
            msg = json.loads(line)
            
            channel.basic_publish(
                exchange='',
                routing_key=queue_name,
                body=msg['body'],
                properties=pika.BasicProperties(
                    delivery_mode=2
                )
            )
            
            restored += 1
            
            if restored % 1000 == 0:
                print(f"Restored {restored} messages")
    
    print(f"Total restored: {restored} messages")
    connection.close()
```

---

## 55.4 预防措施

### 限流配置

```python
class RateLimitedProducer:
    """限流生产者"""
    
    def __init__(self, rate_limit=1000):
        self.rate_limit = rate_limit  # 每秒最大消息数
        self.tokens = rate_limit
        self.last_time = time.time()
        self.lock = threading.Lock()
    
    def acquire(self):
        """获取发送许可"""
        with self.lock:
            now = time.time()
            elapsed = now - self.last_time
            self.tokens = min(
                self.rate_limit,
                self.tokens + elapsed * self.rate_limit
            )
            self.last_time = now
            
            if self.tokens >= 1:
                self.tokens -= 1
                return True
            return False
    
    def publish(self, message):
        """限流发送"""
        while not self.acquire():
            time.sleep(0.001)  # 等待
        
        self.channel.basic_publish(
            exchange='',
            routing_key='my_queue',
            body=message
        )
```

### 队列长度限制

```python
# 设置队列最大长度
args = {
    'x-max-length': 100000,
    'x-overflow': 'reject-publish',  # 达到上限时拒绝新消息
    # 或 'drop-head' 丢弃最老的消息
}

channel.queue_declare(
    queue='limited_queue',
    durable=True,
    arguments=args
)
```

### 惰性队列

```python
# 使用惰性队列减少内存压力
args = {
    'x-queue-mode': 'lazy'
}

channel.queue_declare(
    queue='lazy_queue',
    durable=True,
    arguments=args
)
```

---

## 55.5 积压处理流程

```
┌─────────────────────────────────────────────────────────────────┐
│                     积压处理流程                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. 发现积压                                                    │
│     ├── 监控告警触发                                            │
│     └── 定期巡检发现                                            │
│                         │                                       │
│                         ▼                                       │
│  2. 评估影响                                                    │
│     ├── 积压消息数量                                            │
│     ├── 增长速率                                                │
│     ├── 业务影响程度                                            │
│     └── 预计清理时间                                            │
│                         │                                       │
│                         ▼                                       │
│  3. 定位原因                                                    │
│     ├── 查看消费者状态                                          │
│     ├── 检查下游服务                                            │
│     └── 分析消息内容                                            │
│                         │                                       │
│                         ▼                                       │
│  4. 执行处理                                                    │
│     ├── 轻度: 增加消费者                                        │
│     ├── 中度: 批量消费 + 优化                                   │
│     └── 严重: 消息转储/丢弃                                     │
│                         │                                       │
│                         ▼                                       │
│  5. 事后复盘                                                    │
│     ├── 分析根本原因                                            │
│     ├── 完善监控告警                                            │
│     └── 优化系统架构                                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 55.6 本章小结

| 场景 | 处理方案 |
|------|----------|
| 轻度积压 | 增加消费者 |
| 中度积压 | 批量消费 + 增加消费者 |
| 严重积压 | 消息转储/优先处理关键消息 |
| 预防 | 限流 + 监控 + 队列限制 |

---

**下一章**: [灰度发布与消息](../56-gray-release/README.md)
