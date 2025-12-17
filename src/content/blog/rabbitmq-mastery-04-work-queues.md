---
title: "第04章：工作队列模式 (Work Queues)"
description: "工作队列（又称任务队列）模式用于在多个消费者之间分发耗时任务，避免立即执行资源密集型任务。"
pubDate: "2025-12-17"
tags: ["rabbitmq","mq","backend"]
category: "rabbitmq"
series: "RabbitMQ 消息队列"
order: 4
---

## 4.1 概述

工作队列（又称任务队列）模式用于在多个消费者之间分发耗时任务，避免立即执行资源密集型任务。

### 工作模式

```
                              ┌──────────────┐
                         ┌───▶│  Consumer 1  │
┌──────────────┐         │    └──────────────┘
│   Producer   │────▶ Queue                    
└──────────────┘         │    ┌──────────────┐
                         └───▶│  Consumer 2  │
                              └──────────────┘
```

### 应用场景

- 后台任务处理（图片处理、视频转码）
- 批量数据处理
- 邮件/短信发送
- 报表生成

---

## 4.2 轮询分发 (Round-Robin)

默认情况下，RabbitMQ 使用轮询方式将消息依次发送给各消费者。

### 生产者 (new_task.py)

```python
#!/usr/bin/env python
import pika
import sys

credentials = pika.PlainCredentials('admin', 'admin123')
connection = pika.BlockingConnection(
    pika.ConnectionParameters('localhost', credentials=credentials)
)
channel = connection.channel()

# 声明持久化队列
channel.queue_declare(queue='task_queue', durable=True)

# 从命令行获取消息，用 . 表示任务耗时
message = ' '.join(sys.argv[1:]) or "Hello World!"

channel.basic_publish(
    exchange='',
    routing_key='task_queue',
    body=message,
    properties=pika.BasicProperties(
        delivery_mode=pika.DeliveryMode.Persistent,  # 消息持久化
    )
)

print(f" [x] Sent '{message}'")
connection.close()
```

### 消费者 (worker.py)

```python
#!/usr/bin/env python
import pika
import time

credentials = pika.PlainCredentials('admin', 'admin123')
connection = pika.BlockingConnection(
    pika.ConnectionParameters('localhost', credentials=credentials)
)
channel = connection.channel()

channel.queue_declare(queue='task_queue', durable=True)

def callback(ch, method, properties, body):
    message = body.decode()
    print(f" [x] Received '{message}'")
    
    # 模拟耗时任务（每个 . 代表1秒）
    time.sleep(message.count('.'))
    
    print(" [x] Done")
    
    # 手动确认
    ch.basic_ack(delivery_tag=method.delivery_tag)

channel.basic_consume(queue='task_queue', on_message_callback=callback)

print(' [*] Waiting for messages. To exit press CTRL+C')
channel.start_consuming()
```

### 测试轮询分发

```bash
# 终端1: 启动 worker1
python worker.py

# 终端2: 启动 worker2
python worker.py

# 终端3: 发送多条消息
python new_task.py First message.
python new_task.py Second message..
python new_task.py Third message...
python new_task.py Fourth message....
```

结果：消息1和3发给 worker1，消息2和4发给 worker2。

---

## 4.3 消息确认 (Message Acknowledgment)

### 为什么需要确认

如果消费者在处理消息过程中崩溃，消息会丢失。开启手动确认可以确保消息不会丢失。

### 自动确认 vs 手动确认

| 模式 | 说明 | 风险 |
|------|------|------|
| `auto_ack=True` | 消息发送后立即确认 | 消息可能丢失 |
| `auto_ack=False` | 处理完成后手动确认 | 安全可靠 |

### 手动确认代码

```python
def callback(ch, method, properties, body):
    try:
        # 处理消息
        process_message(body)
        # 确认成功
        ch.basic_ack(delivery_tag=method.delivery_tag)
    except Exception as e:
        # 拒绝消息，重新入队
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True)

channel.basic_consume(
    queue='task_queue',
    on_message_callback=callback,
    auto_ack=False  # 关闭自动确认
)
```

### 确认方法

| 方法 | 说明 |
|------|------|
| `basic_ack` | 确认消息已成功处理 |
| `basic_nack` | 拒绝消息，可选择是否重新入队 |
| `basic_reject` | 拒绝单条消息 |

```python
# 确认
ch.basic_ack(delivery_tag=method.delivery_tag)

# 拒绝并重新入队
ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True)

# 拒绝并丢弃
ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)

# 批量确认
ch.basic_ack(delivery_tag=method.delivery_tag, multiple=True)
```

### 忘记确认的后果

如果忘记调用 `basic_ack`，消息会持续堆积在 Unacked 状态：

```bash
# 查看未确认消息
rabbitmqctl list_queues name messages_ready messages_unacknowledged
```

---

## 4.4 消息持久化

### 队列持久化

```python
channel.queue_declare(queue='task_queue', durable=True)
```

### 消息持久化

```python
channel.basic_publish(
    exchange='',
    routing_key='task_queue',
    body=message,
    properties=pika.BasicProperties(
        delivery_mode=pika.DeliveryMode.Persistent,  # 值为2
    )
)
```

### 持久化注意事项

```
                    ┌─────────────────────────────────────┐
                    │         持久化并非绝对可靠           │
                    ├─────────────────────────────────────┤
                    │                                     │
                    │  1. 消息接收后、写入磁盘前可能丢失  │
                    │  2. 需要配合发布确认机制            │
                    │  3. 性能会有所下降                  │
                    │                                     │
                    │  完全可靠需要:                       │
                    │  - 队列持久化 (durable=True)        │
                    │  - 消息持久化 (delivery_mode=2)     │
                    │  - 发布确认 (publisher confirms)    │
                    │                                     │
                    └─────────────────────────────────────┘
```

---

## 4.5 公平分发 (Fair Dispatch)

### 问题

轮询分发不考虑消费者的处理能力，可能导致某些消费者忙碌而另一些空闲。

### 解决方案：prefetch

设置 `prefetch_count` 限制每个消费者最多同时处理的消息数。

```python
# 每次只处理一条消息，处理完再获取下一条
channel.basic_qos(prefetch_count=1)
```

### 对比图示

```
轮询分发 (无 prefetch):
┌─────────────────────────────────────────────────────────┐
│ Producer: 1  2  3  4  5  6  7  8  9  10                │
│                                                         │
│ Consumer1: 1     3     5     7     9      (处理慢)     │
│ Consumer2: 2     4     6     8     10     (空闲等待)   │
└─────────────────────────────────────────────────────────┘

公平分发 (prefetch=1):
┌─────────────────────────────────────────────────────────┐
│ Producer: 1  2  3  4  5  6  7  8  9  10                │
│                                                         │
│ Consumer1: 1  4  7  10                  (处理慢)       │
│ Consumer2: 2  3  5  6  8  9             (多处理)       │
└─────────────────────────────────────────────────────────┘
```

---

## 4.6 完整示例

### 生产者 (Python)

```python
#!/usr/bin/env python
import pika
import sys

def main():
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()

    # 持久化队列
    channel.queue_declare(queue='task_queue', durable=True)

    message = ' '.join(sys.argv[1:]) or "Hello World!"

    channel.basic_publish(
        exchange='',
        routing_key='task_queue',
        body=message,
        properties=pika.BasicProperties(
            delivery_mode=pika.DeliveryMode.Persistent,
        )
    )
    print(f" [x] Sent '{message}'")
    connection.close()

if __name__ == '__main__':
    main()
```

### 消费者 (Python)

```python
#!/usr/bin/env python
import pika
import time

def main():
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()

    channel.queue_declare(queue='task_queue', durable=True)

    # 公平分发
    channel.basic_qos(prefetch_count=1)

    def callback(ch, method, properties, body):
        message = body.decode()
        print(f" [x] Received '{message}'")
        time.sleep(message.count('.'))
        print(" [x] Done")
        ch.basic_ack(delivery_tag=method.delivery_tag)

    channel.basic_consume(queue='task_queue', on_message_callback=callback)

    print(' [*] Waiting for messages. To exit press CTRL+C')
    channel.start_consuming()

if __name__ == '__main__':
    main()
```

### Java 版本

```java
// 生产者
public class NewTask {
    private static final String QUEUE_NAME = "task_queue";

    public static void main(String[] args) throws Exception {
        ConnectionFactory factory = new ConnectionFactory();
        factory.setHost("localhost");
        factory.setUsername("admin");
        factory.setPassword("admin123");
        
        try (Connection connection = factory.newConnection();
             Channel channel = connection.createChannel()) {
            
            // 持久化队列
            channel.queueDeclare(QUEUE_NAME, true, false, false, null);
            
            String message = String.join(" ", args);
            if (message.isEmpty()) message = "Hello World!";
            
            // 持久化消息
            channel.basicPublish("", QUEUE_NAME,
                MessageProperties.PERSISTENT_TEXT_PLAIN,
                message.getBytes(StandardCharsets.UTF_8));
            
            System.out.println(" [x] Sent '" + message + "'");
        }
    }
}

// 消费者
public class Worker {
    private static final String QUEUE_NAME = "task_queue";

    public static void main(String[] args) throws Exception {
        ConnectionFactory factory = new ConnectionFactory();
        factory.setHost("localhost");
        factory.setUsername("admin");
        factory.setPassword("admin123");
        
        Connection connection = factory.newConnection();
        Channel channel = connection.createChannel();
        
        channel.queueDeclare(QUEUE_NAME, true, false, false, null);
        
        // 公平分发
        channel.basicQos(1);
        
        DeliverCallback deliverCallback = (consumerTag, delivery) -> {
            String message = new String(delivery.getBody(), StandardCharsets.UTF_8);
            System.out.println(" [x] Received '" + message + "'");
            try {
                doWork(message);
            } finally {
                System.out.println(" [x] Done");
                channel.basicAck(delivery.getEnvelope().getDeliveryTag(), false);
            }
        };
        
        channel.basicConsume(QUEUE_NAME, false, deliverCallback, consumerTag -> {});
    }
    
    private static void doWork(String task) throws InterruptedException {
        for (char ch : task.toCharArray()) {
            if (ch == '.') Thread.sleep(1000);
        }
    }
}
```

---

## 4.7 本章小结

| 特性 | 配置 |
|------|------|
| **轮询分发** | 默认行为 |
| **消息确认** | `auto_ack=False` + `basic_ack` |
| **队列持久化** | `durable=True` |
| **消息持久化** | `delivery_mode=2` |
| **公平分发** | `prefetch_count=1` |

---

## 4.8 思考题

1. 如果消费者处理消息时抛出异常，应该如何处理？
2. prefetch_count 设置多大合适？
3. 如何实现优先级任务处理？

---

**下一章**: [发布/订阅模式](../05-publish-subscribe/README.md)
