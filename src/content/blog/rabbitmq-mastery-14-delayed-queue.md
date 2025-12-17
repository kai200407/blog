---
title: "第14章：延迟队列"
description: "延迟队列用于在指定时间后处理消息，常用于定时任务、订单超时等场景。"
pubDate: "2025-12-17"
tags: ["rabbitmq","mq","backend"]
category: "rabbitmq"
series: "RabbitMQ 消息队列"
order: 14
---

## 14.1 概述

延迟队列用于在指定时间后处理消息，常用于定时任务、订单超时等场景。

### 应用场景

- 订单30分钟未支付自动取消
- 会议开始前15分钟发送提醒
- 用户注册后24小时发送回访邮件
- 延迟重试失败的任务

### 实现方式

| 方式 | 说明 | 推荐度 |
|------|------|--------|
| TTL + 死信队列 | 利用消息过期后进入死信队列 | ⭐⭐⭐ |
| 延迟消息插件 | rabbitmq_delayed_message_exchange | ⭐⭐⭐⭐⭐ |
| 定时轮询 | 数据库 + 定时任务（非MQ方案） | ⭐⭐ |

---

## 14.2 方式一：TTL + 死信队列

### 原理

```
┌──────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Producer   │────▶│  Delay Queue    │     │   Work Queue    │
│              │     │  (TTL=30min)    │────▶│                 │
└──────────────┘     │  x-dead-letter  │ DLX └────────┬────────┘
                     └─────────────────┘              │
                                                      ▼
                                              ┌──────────────┐
                                              │   Consumer   │
                                              │  (处理超时)   │
                                              └──────────────┘

消息流程:
1. 生产者发送消息到延迟队列
2. 消息在延迟队列等待 TTL 时间
3. TTL 过期后，消息通过 DLX 转发到工作队列
4. 消费者从工作队列消费消息
```

### 实现代码

```python
#!/usr/bin/env python
"""
延迟队列实现 - TTL + 死信队列
"""
import pika
import json
import time

def setup_delay_queue(delay_ms=30000):
    """设置延迟队列，默认30秒延迟"""
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()

    # 1. 声明工作交换器和队列（最终处理消息的地方）
    channel.exchange_declare(exchange='work_exchange', exchange_type='direct', durable=True)
    channel.queue_declare(queue='work_queue', durable=True)
    channel.queue_bind(exchange='work_exchange', queue='work_queue', routing_key='work')

    # 2. 声明延迟队列（消息先进入这里等待）
    delay_queue_args = {
        'x-dead-letter-exchange': 'work_exchange',    # 死信交换器
        'x-dead-letter-routing-key': 'work',          # 死信路由键
        'x-message-ttl': delay_ms,                     # 消息过期时间
    }
    channel.queue_declare(queue='delay_queue', durable=True, arguments=delay_queue_args)

    print(f"Delay queue setup complete (delay: {delay_ms}ms)")
    connection.close()


def send_delayed_message(message, delay_ms=None):
    """发送延迟消息"""
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()

    properties = pika.BasicProperties(
        delivery_mode=2,
        content_type='application/json',
    )
    
    # 如果指定了消息级别的延迟时间
    if delay_ms:
        properties.expiration = str(delay_ms)

    channel.basic_publish(
        exchange='',
        routing_key='delay_queue',
        body=json.dumps(message),
        properties=properties
    )

    print(f"Sent delayed message: {message}")
    connection.close()


def consume_delayed_messages():
    """消费延迟后的消息"""
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()
    channel.basic_qos(prefetch_count=1)

    def callback(ch, method, properties, body):
        message = json.loads(body)
        print(f"Received delayed message: {message}")
        print(f"  -> Processing at {time.strftime('%H:%M:%S')}")
        ch.basic_ack(delivery_tag=method.delivery_tag)

    channel.basic_consume(queue='work_queue', on_message_callback=callback)

    print("Waiting for delayed messages...")
    channel.start_consuming()


if __name__ == '__main__':
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python delay_queue.py [setup|send|consume]")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == 'setup':
        delay = int(sys.argv[2]) if len(sys.argv) > 2 else 10000
        setup_delay_queue(delay)
    elif command == 'send':
        msg = {'order_id': '12345', 'action': 'timeout_check', 'time': time.strftime('%H:%M:%S')}
        send_delayed_message(msg)
    elif command == 'consume':
        consume_delayed_messages()
```

### 问题：消息顺序

TTL + 死信方式有一个问题：**消息只能按顺序过期**。

```
队列头                                           队列尾
┌──────────────────────────────────────────────────────┐
│  Msg1 (TTL=60s)  │  Msg2 (TTL=10s)  │  Msg3 (TTL=5s) │
└──────────────────────────────────────────────────────┘

问题: 即使 Msg3 的 TTL 先到期，也要等 Msg1 过期后才能被处理
```

**解决方案**：使用延迟消息插件，或为不同延迟时间创建不同队列。

---

## 14.3 方式二：延迟消息插件（推荐）

### 安装插件

```bash
# 下载插件
wget https://github.com/rabbitmq/rabbitmq-delayed-message-exchange/releases/download/v3.12.0/rabbitmq_delayed_message_exchange-3.12.0.ez

# 复制到插件目录
cp rabbitmq_delayed_message_exchange-3.12.0.ez /usr/lib/rabbitmq/plugins/

# 启用插件
rabbitmq-plugins enable rabbitmq_delayed_message_exchange

# Docker 方式
docker exec rabbitmq rabbitmq-plugins enable rabbitmq_delayed_message_exchange
```

### 原理

```
┌──────────────┐     ┌─────────────────────┐     ┌──────────────┐
│   Producer   │────▶│  Delayed Exchange   │────▶│    Queue     │
│              │     │  (x-delayed-type)   │     │              │
└──────────────┘     └─────────────────────┘     └──────┬───────┘
                              │                         │
                              │ 延迟存储                 ▼
                              │                  ┌──────────────┐
                              └─────────────────▶│   Consumer   │
                                   到期后投递     └──────────────┘
```

### 实现代码

```python
#!/usr/bin/env python
"""
延迟队列实现 - 延迟消息插件
"""
import pika
import json
import time

def setup_delayed_exchange():
    """设置延迟交换器"""
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()

    # 声明延迟交换器
    args = {'x-delayed-type': 'direct'}
    channel.exchange_declare(
        exchange='delayed_exchange',
        exchange_type='x-delayed-message',
        durable=True,
        arguments=args
    )

    # 声明队列
    channel.queue_declare(queue='delayed_queue', durable=True)
    
    # 绑定
    channel.queue_bind(
        exchange='delayed_exchange',
        queue='delayed_queue',
        routing_key='delayed'
    )

    print("Delayed exchange setup complete")
    connection.close()


def send_delayed_message(message, delay_ms):
    """发送延迟消息"""
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()

    # 通过 headers 设置延迟时间
    headers = {'x-delay': delay_ms}

    channel.basic_publish(
        exchange='delayed_exchange',
        routing_key='delayed',
        body=json.dumps(message),
        properties=pika.BasicProperties(
            delivery_mode=2,
            headers=headers,
        )
    )

    print(f"Sent message with {delay_ms}ms delay: {message}")
    connection.close()


def consume():
    """消费延迟消息"""
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()

    def callback(ch, method, properties, body):
        message = json.loads(body)
        print(f"[{time.strftime('%H:%M:%S')}] Received: {message}")
        ch.basic_ack(delivery_tag=method.delivery_tag)

    channel.basic_consume(queue='delayed_queue', on_message_callback=callback)

    print("Waiting for delayed messages...")
    channel.start_consuming()


if __name__ == '__main__':
    import sys
    
    if sys.argv[1] == 'setup':
        setup_delayed_exchange()
    elif sys.argv[1] == 'send':
        delay = int(sys.argv[2]) if len(sys.argv) > 2 else 5000
        msg = {'id': 1, 'time': time.strftime('%H:%M:%S'), 'delay': delay}
        send_delayed_message(msg, delay)
    elif sys.argv[1] == 'consume':
        consume()
```

### 测试

```bash
# 设置
python delayed_plugin.py setup

# 启动消费者
python delayed_plugin.py consume

# 发送不同延迟的消息
python delayed_plugin.py send 3000   # 3秒后
python delayed_plugin.py send 1000   # 1秒后
python delayed_plugin.py send 5000   # 5秒后

# 输出顺序: 1秒 -> 3秒 -> 5秒 (按延迟时间排序)
```

---

## 14.4 Java 实现

### Spring Boot 配置

```java
@Configuration
public class DelayedQueueConfig {

    @Bean
    public CustomExchange delayedExchange() {
        Map<String, Object> args = new HashMap<>();
        args.put("x-delayed-type", "direct");
        return new CustomExchange("delayed.exchange", "x-delayed-message", true, false, args);
    }

    @Bean
    public Queue delayedQueue() {
        return new Queue("delayed.queue", true);
    }

    @Bean
    public Binding delayedBinding() {
        return BindingBuilder
            .bind(delayedQueue())
            .to(delayedExchange())
            .with("delayed.routing.key")
            .noargs();
    }
}
```

### 发送延迟消息

```java
@Service
public class DelayedMessageService {

    @Autowired
    private RabbitTemplate rabbitTemplate;

    public void sendDelayedMessage(String message, long delayMs) {
        rabbitTemplate.convertAndSend(
            "delayed.exchange",
            "delayed.routing.key",
            message,
            msg -> {
                msg.getMessageProperties().setDelay((int) delayMs);
                return msg;
            }
        );
    }
}
```

### 消费延迟消息

```java
@Component
public class DelayedMessageConsumer {

    @RabbitListener(queues = "delayed.queue")
    public void handleDelayedMessage(String message) {
        System.out.println("Received delayed message: " + message);
    }
}
```

---

## 14.5 实战：订单超时取消

### 业务流程

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         订单超时取消流程                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  用户下单                                                               │
│     │                                                                   │
│     ▼                                                                   │
│  ┌─────────────┐                                                        │
│  │ 创建订单    │───────┐                                                │
│  │ status=待支付│       │                                                │
│  └─────────────┘       │ 发送延迟消息 (30分钟)                          │
│                        ▼                                                │
│              ┌─────────────────────┐                                    │
│              │   Delayed Exchange  │                                    │
│              └──────────┬──────────┘                                    │
│                         │                                               │
│         ┌───────────────┼───────────────┐                               │
│         │               │               │                               │
│         ▼               ▼               ▼                               │
│    用户支付         30分钟后        用户取消                            │
│    status=已支付    检查状态        status=已取消                       │
│         │               │                                               │
│         │               ▼                                               │
│         │     ┌─────────────────┐                                       │
│         │     │ 订单状态=待支付? │                                      │
│         │     └────────┬────────┘                                       │
│         │              │                                                │
│         │         是   │   否                                           │
│         │              ▼                                                │
│         │     ┌─────────────┐                                           │
│         │     │  自动取消    │                                          │
│         │     │ status=超时  │                                          │
│         │     │  释放库存    │                                          │
│         │     └─────────────┘                                           │
│         │                                                               │
│         ▼                                                               │
│    订单完成                                                             │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 完整代码

```python
#!/usr/bin/env python
"""
订单超时取消系统
"""
import pika
import json
import time
import uuid

# 模拟订单数据库
orders_db = {}

ORDER_TIMEOUT_MS = 30 * 60 * 1000  # 30分钟
# 测试用: 10秒
ORDER_TIMEOUT_MS = 10 * 1000

def setup():
    """初始化队列"""
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()

    # 延迟交换器
    args = {'x-delayed-type': 'direct'}
    channel.exchange_declare(
        exchange='order.delayed.exchange',
        exchange_type='x-delayed-message',
        durable=True,
        arguments=args
    )

    # 超时检查队列
    channel.queue_declare(queue='order.timeout.queue', durable=True)
    channel.queue_bind(
        exchange='order.delayed.exchange',
        queue='order.timeout.queue',
        routing_key='order.timeout'
    )

    print("Order timeout system setup complete")
    connection.close()


def create_order(user_id, product_id, amount):
    """创建订单"""
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()

    # 1. 创建订单
    order_id = str(uuid.uuid4())[:8]
    order = {
        'order_id': order_id,
        'user_id': user_id,
        'product_id': product_id,
        'amount': amount,
        'status': 'pending',
        'created_at': time.strftime('%Y-%m-%d %H:%M:%S'),
    }
    orders_db[order_id] = order
    print(f"Order created: {order_id}")

    # 2. 发送延迟消息（超时检查）
    message = {'order_id': order_id, 'action': 'timeout_check'}
    channel.basic_publish(
        exchange='order.delayed.exchange',
        routing_key='order.timeout',
        body=json.dumps(message),
        properties=pika.BasicProperties(
            delivery_mode=2,
            headers={'x-delay': ORDER_TIMEOUT_MS},
        )
    )
    print(f"Timeout check scheduled for order {order_id} in {ORDER_TIMEOUT_MS/1000}s")

    connection.close()
    return order_id


def pay_order(order_id):
    """支付订单"""
    if order_id in orders_db:
        order = orders_db[order_id]
        if order['status'] == 'pending':
            order['status'] = 'paid'
            order['paid_at'] = time.strftime('%Y-%m-%d %H:%M:%S')
            print(f"Order {order_id} paid successfully")
            return True
        else:
            print(f"Order {order_id} cannot be paid, status: {order['status']}")
            return False
    else:
        print(f"Order {order_id} not found")
        return False


def timeout_consumer():
    """超时检查消费者"""
    credentials = pika.PlainCredentials('admin', 'admin123')
    connection = pika.BlockingConnection(
        pika.ConnectionParameters('localhost', credentials=credentials)
    )
    channel = connection.channel()

    def callback(ch, method, properties, body):
        message = json.loads(body)
        order_id = message['order_id']
        
        print(f"\n[Timeout Check] Checking order: {order_id}")
        
        if order_id in orders_db:
            order = orders_db[order_id]
            
            if order['status'] == 'pending':
                # 订单仍未支付，自动取消
                order['status'] = 'timeout_cancelled'
                order['cancelled_at'] = time.strftime('%Y-%m-%d %H:%M:%S')
                print(f"  -> Order {order_id} cancelled due to timeout")
                print(f"  -> TODO: Release inventory, notify user...")
            else:
                print(f"  -> Order {order_id} already processed, status: {order['status']}")
        else:
            print(f"  -> Order {order_id} not found")
        
        ch.basic_ack(delivery_tag=method.delivery_tag)

    channel.basic_consume(queue='order.timeout.queue', on_message_callback=callback)

    print("Order timeout consumer started...")
    channel.start_consuming()


if __name__ == '__main__':
    import sys
    
    if sys.argv[1] == 'setup':
        setup()
    elif sys.argv[1] == 'create':
        create_order('user001', 'product001', 99.99)
    elif sys.argv[1] == 'pay':
        pay_order(sys.argv[2])
    elif sys.argv[1] == 'consume':
        timeout_consumer()
    elif sys.argv[1] == 'list':
        for oid, order in orders_db.items():
            print(f"{oid}: {order}")
```

---

## 14.6 本章小结

| 方式 | 优点 | 缺点 |
|------|------|------|
| **TTL + 死信** | 无需插件 | 消息顺序问题 |
| **延迟插件** | 精确延迟，无顺序问题 | 需要安装插件 |

### 最佳实践

1. 生产环境推荐使用延迟消息插件
2. 设置合理的延迟时间粒度
3. 延迟消息也需要持久化
4. 消费者需要处理业务状态已变更的情况

---

## 14.7 思考题

1. 如果延迟消息非常多，会对 RabbitMQ 性能有影响吗？
2. 如何实现可变延迟时间的消息？
3. 延迟队列适合用于哪些场景？

---

**下一章**: [优先级队列](../15-priority-queue/README.md)
