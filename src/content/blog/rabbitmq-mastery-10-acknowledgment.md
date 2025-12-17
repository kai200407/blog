---
title: "第10章：消息确认机制"
description: "消息确认机制确保消息被正确处理后才从队列删除，防止消息丢失。"
pubDate: "2025-12-17"
tags: ["rabbitmq","mq","backend"]
category: "rabbitmq"
series: "RabbitMQ 消息队列"
order: 10
---

## 10.1 概述

消息确认机制确保消息被正确处理后才从队列删除，防止消息丢失。

### 确认类型

```
┌─────────────────────────────────────────────────────────────────┐
│                     消息确认机制                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  自动确认 (auto_ack=True)                                       │
│  └── 消息发送给消费者后立即确认                                  │
│  └── 消息可能丢失                                                │
│                                                                 │
│  手动确认 (auto_ack=False)                                      │
│  ├── basic_ack   - 确认消息已成功处理                           │
│  ├── basic_nack  - 拒绝消息（可批量）                           │
│  └── basic_reject - 拒绝单条消息                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 10.2 自动确认

```python
# 自动确认模式（不推荐用于重要消息）
channel.basic_consume(
    queue='my_queue',
    on_message_callback=callback,
    auto_ack=True  # 自动确认
)
```

### 风险

- 消息发送后立即确认
- 消费者处理失败时消息已被删除
- 适用于允许丢失的场景

---

## 10.3 手动确认

### basic_ack - 确认成功

```python
def callback(ch, method, properties, body):
    try:
        # 处理消息
        process_message(body)
        
        # 确认消息
        ch.basic_ack(delivery_tag=method.delivery_tag)
        print("Message acknowledged")
        
    except Exception as e:
        # 处理失败，拒绝消息
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)
        print(f"Message rejected: {e}")

channel.basic_consume(
    queue='my_queue',
    on_message_callback=callback,
    auto_ack=False  # 手动确认
)
```

### basic_nack - 拒绝消息

```python
# 拒绝单条消息，不重新入队
ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)

# 拒绝单条消息，重新入队
ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True)

# 批量拒绝（拒绝该 delivery_tag 之前的所有消息）
ch.basic_nack(delivery_tag=method.delivery_tag, multiple=True, requeue=False)
```

### basic_reject - 拒绝单条

```python
# 拒绝单条，不重新入队
ch.basic_reject(delivery_tag=method.delivery_tag, requeue=False)

# 拒绝单条，重新入队
ch.basic_reject(delivery_tag=method.delivery_tag, requeue=True)
```

---

## 10.4 确认方法对比

| 方法 | 说明 | 参数 |
|------|------|------|
| `basic_ack` | 确认成功 | delivery_tag, multiple |
| `basic_nack` | 拒绝（可批量）| delivery_tag, multiple, requeue |
| `basic_reject` | 拒绝单条 | delivery_tag, requeue |

### 参数说明

| 参数 | 说明 |
|------|------|
| `delivery_tag` | 消息唯一标识 |
| `multiple` | 是否批量确认/拒绝 |
| `requeue` | 是否重新入队 |

---

## 10.5 完整示例

```python
#!/usr/bin/env python
"""手动确认完整示例"""
import pika
import time

def process_message(body):
    """处理消息（模拟业务逻辑）"""
    message = body.decode()
    print(f"Processing: {message}")
    
    # 模拟处理
    time.sleep(1)
    
    # 模拟随机失败
    if "fail" in message.lower():
        raise Exception("Processing failed!")
    
    return True


def callback(ch, method, properties, body):
    """消息回调函数"""
    delivery_tag = method.delivery_tag
    
    try:
        process_message(body)
        
        # 成功，确认消息
        ch.basic_ack(delivery_tag=delivery_tag)
        print(f"  -> Acknowledged")
        
    except Exception as e:
        print(f"  -> Error: {e}")
        
        # 检查是否是重投递的消息
        if method.redelivered:
            # 已重试过，进入死信队列
            ch.basic_nack(delivery_tag=delivery_tag, requeue=False)
            print(f"  -> Sent to DLQ (already redelivered)")
        else:
            # 第一次失败，重新入队
            ch.basic_nack(delivery_tag=delivery_tag, requeue=True)
            print(f"  -> Requeued for retry")


def main():
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()
    
    # 声明队列
    channel.queue_declare(queue='ack_demo', durable=True)
    
    # 设置 prefetch
    channel.basic_qos(prefetch_count=1)
    
    # 消费
    channel.basic_consume(
        queue='ack_demo',
        on_message_callback=callback,
        auto_ack=False  # 手动确认
    )
    
    print(' [*] Waiting for messages. To exit press CTRL+C')
    channel.start_consuming()


if __name__ == '__main__':
    main()
```

---

## 10.6 Java 实现

```java
// 手动确认消费者
Channel channel = connection.createChannel();
channel.queueDeclare("ack_demo", true, false, false, null);
channel.basicQos(1);

DeliverCallback deliverCallback = (consumerTag, delivery) -> {
    long deliveryTag = delivery.getEnvelope().getDeliveryTag();
    
    try {
        String message = new String(delivery.getBody(), "UTF-8");
        System.out.println("Received: " + message);
        
        // 处理消息
        processMessage(message);
        
        // 确认
        channel.basicAck(deliveryTag, false);
        
    } catch (Exception e) {
        System.err.println("Error: " + e.getMessage());
        
        if (delivery.getEnvelope().isRedeliver()) {
            // 已重试，拒绝不重入队
            channel.basicNack(deliveryTag, false, false);
        } else {
            // 重新入队
            channel.basicNack(deliveryTag, false, true);
        }
    }
};

// auto_ack = false
channel.basicConsume("ack_demo", false, deliverCallback, consumerTag -> {});
```

---

## 10.7 未确认消息处理

### 查看未确认消息

```bash
rabbitmqctl list_queues name messages_ready messages_unacknowledged
```

### 消费者断开后

- `auto_ack=True`: 消息已确认，不会重投
- `auto_ack=False`: 消息重新入队，投递给其他消费者

---

## 10.8 最佳实践

```
┌─────────────────────────────────────────────────────────────────┐
│                      确认机制最佳实践                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. 重要消息使用手动确认                                        │
│                                                                 │
│  2. 处理完成后再确认                                            │
│     - 不要在处理前确认                                          │
│     - 不要在回调外确认                                          │
│                                                                 │
│  3. 合理使用 requeue                                            │
│     - 暂时性错误：requeue=True                                  │
│     - 永久性错误：requeue=False (进入死信队列)                  │
│                                                                 │
│  4. 设置 prefetch_count                                         │
│     - 控制未确认消息数量                                        │
│     - 避免内存溢出                                              │
│                                                                 │
│  5. 处理重投递消息                                               │
│     - 检查 method.redelivered                                    │
│     - 避免无限重试                                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 10.9 本章小结

| 确认方式 | 配置 | 说明 |
|----------|------|------|
| 自动确认 | `auto_ack=True` | 发送后立即确认 |
| 手动确认 | `auto_ack=False` | 处理后手动确认 |
| 批量确认 | `multiple=True` | 批量确认多条 |

---

**下一章**: [发布确认机制](../11-publisher-confirms/README.md)
