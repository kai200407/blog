---
title: "第08章：RPC 远程调用"
description: "RPC（Remote Procedure Call）模式使用 RabbitMQ 实现远程过程调用，客户端发送请求并等待响应。"
pubDate: "2025-12-17"
tags: ["rabbitmq","mq","backend"]
category: "rabbitmq"
series: "RabbitMQ 消息队列"
order: 8
---

## 8.1 概述

RPC（Remote Procedure Call）模式使用 RabbitMQ 实现远程过程调用，客户端发送请求并等待响应。

### 工作模式

```
┌──────────────┐                                    ┌──────────────┐
│    Client    │                                    │    Server    │
│  (RPC请求方)  │                                    │  (RPC服务方)  │
└──────┬───────┘                                    └──────┬───────┘
       │                                                   │
       │  1. 发送请求                                       │
       │  ─────────────────────────────────────▶          │
       │  routing_key=rpc_queue                           │
       │  reply_to=amq.gen-xxx                            │
       │  correlation_id=uuid                              │
       │                                                   │
       │                                   2. 处理请求      │
       │                                                   │
       │  3. 返回响应                                       │
       │  ◀─────────────────────────────────────          │
       │  routing_key=amq.gen-xxx                         │
       │  correlation_id=uuid                              │
       │                                                   │
       ▼                                                   ▼
```

### 核心属性

| 属性 | 说明 |
|------|------|
| `reply_to` | 回调队列名，服务端将响应发送到此队列 |
| `correlation_id` | 请求唯一标识，用于匹配请求和响应 |

---

## 8.2 回调队列

客户端需要一个队列来接收响应：

```python
# 创建回调队列
result = channel.queue_declare(queue='', exclusive=True)
callback_queue = result.method.queue

# 发送请求时指定 reply_to
channel.basic_publish(
    exchange='',
    routing_key='rpc_queue',
    properties=pika.BasicProperties(
        reply_to=callback_queue,
        correlation_id=str(uuid.uuid4()),
    ),
    body=request
)
```

---

## 8.3 Correlation ID

用于将响应与请求匹配：

```python
# 客户端生成唯一 ID
self.corr_id = str(uuid.uuid4())

# 服务端返回时携带相同 ID
ch.basic_publish(
    exchange='',
    routing_key=props.reply_to,
    properties=pika.BasicProperties(
        correlation_id=props.correlation_id,  # 返回相同的 ID
    ),
    body=str(response)
)

# 客户端校验
if self.corr_id == method.properties.correlation_id:
    self.response = body
```

---

## 8.4 完整实现

### RPC 服务端 (rpc_server.py)

```python
#!/usr/bin/env python
import pika

credentials = pika.PlainCredentials('admin', 'admin123')
connection = pika.BlockingConnection(
    pika.ConnectionParameters('localhost', credentials=credentials)
)
channel = connection.channel()

# 声明 RPC 队列
channel.queue_declare(queue='rpc_queue')

# 斐波那契函数
def fib(n):
    if n == 0:
        return 0
    elif n == 1:
        return 1
    else:
        return fib(n - 1) + fib(n - 2)

def on_request(ch, method, props, body):
    n = int(body)
    print(f" [.] fib({n})")
    
    response = fib(n)
    
    # 发送响应到回调队列
    ch.basic_publish(
        exchange='',
        routing_key=props.reply_to,
        properties=pika.BasicProperties(
            correlation_id=props.correlation_id,
        ),
        body=str(response)
    )
    
    # 确认消息
    ch.basic_ack(delivery_tag=method.delivery_tag)

# 公平分发
channel.basic_qos(prefetch_count=1)

channel.basic_consume(queue='rpc_queue', on_message_callback=on_request)

print(" [x] Awaiting RPC requests")
channel.start_consuming()
```

### RPC 客户端 (rpc_client.py)

```python
#!/usr/bin/env python
import pika
import uuid

class FibonacciRpcClient:
    def __init__(self):
        credentials = pika.PlainCredentials('admin', 'admin123')
        self.connection = pika.BlockingConnection(
            pika.ConnectionParameters('localhost', credentials=credentials)
        )
        self.channel = self.connection.channel()
        
        # 创建回调队列
        result = self.channel.queue_declare(queue='', exclusive=True)
        self.callback_queue = result.method.queue
        
        # 注册消费者
        self.channel.basic_consume(
            queue=self.callback_queue,
            on_message_callback=self.on_response,
            auto_ack=True
        )
        
        self.response = None
        self.corr_id = None
    
    def on_response(self, ch, method, props, body):
        if self.corr_id == props.correlation_id:
            self.response = body
    
    def call(self, n):
        self.response = None
        self.corr_id = str(uuid.uuid4())
        
        # 发送 RPC 请求
        self.channel.basic_publish(
            exchange='',
            routing_key='rpc_queue',
            properties=pika.BasicProperties(
                reply_to=self.callback_queue,
                correlation_id=self.corr_id,
            ),
            body=str(n)
        )
        
        # 等待响应
        while self.response is None:
            self.connection.process_data_events(time_limit=None)
        
        return int(self.response)


if __name__ == '__main__':
    fibonacci_rpc = FibonacciRpcClient()
    
    print(" [x] Requesting fib(30)")
    response = fibonacci_rpc.call(30)
    print(f" [.] Got {response}")
```

---

## 8.5 Java 实现

### RPC 服务端 (RPCServer.java)

```java
package com.example.rabbitmq;

import com.rabbitmq.client.*;

public class RPCServer {
    private static final String RPC_QUEUE_NAME = "rpc_queue";

    private static int fib(int n) {
        if (n == 0) return 0;
        if (n == 1) return 1;
        return fib(n - 1) + fib(n - 2);
    }

    public static void main(String[] args) throws Exception {
        ConnectionFactory factory = new ConnectionFactory();
        factory.setHost("localhost");
        factory.setUsername("admin");
        factory.setPassword("admin123");

        Connection connection = factory.newConnection();
        Channel channel = connection.createChannel();

        channel.queueDeclare(RPC_QUEUE_NAME, false, false, false, null);
        channel.queuePurge(RPC_QUEUE_NAME);
        channel.basicQos(1);

        System.out.println(" [x] Awaiting RPC requests");

        DeliverCallback deliverCallback = (consumerTag, delivery) -> {
            AMQP.BasicProperties replyProps = new AMQP.BasicProperties.Builder()
                .correlationId(delivery.getProperties().getCorrelationId())
                .build();

            String response = "";
            try {
                String message = new String(delivery.getBody(), "UTF-8");
                int n = Integer.parseInt(message);
                System.out.println(" [.] fib(" + n + ")");
                response = String.valueOf(fib(n));
            } catch (RuntimeException e) {
                System.out.println(" [.] " + e);
            } finally {
                // 发送响应
                channel.basicPublish("", delivery.getProperties().getReplyTo(),
                    replyProps, response.getBytes("UTF-8"));
                channel.basicAck(delivery.getEnvelope().getDeliveryTag(), false);
            }
        };

        channel.basicConsume(RPC_QUEUE_NAME, false, deliverCallback, consumerTag -> {});
    }
}
```

### RPC 客户端 (RPCClient.java)

```java
package com.example.rabbitmq;

import com.rabbitmq.client.*;

import java.io.IOException;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeoutException;

public class RPCClient implements AutoCloseable {
    private Connection connection;
    private Channel channel;
    private String requestQueueName = "rpc_queue";

    public RPCClient() throws IOException, TimeoutException {
        ConnectionFactory factory = new ConnectionFactory();
        factory.setHost("localhost");
        factory.setUsername("admin");
        factory.setPassword("admin123");

        connection = factory.newConnection();
        channel = connection.createChannel();
    }

    public static void main(String[] args) {
        try (RPCClient fibonacciRpc = new RPCClient()) {
            for (int i = 0; i < 32; i++) {
                String result = fibonacciRpc.call(String.valueOf(i));
                System.out.println(" [.] fib(" + i + ") = " + result);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public String call(String message) throws IOException, ExecutionException, InterruptedException {
        final String corrId = UUID.randomUUID().toString();

        // 创建回调队列
        String replyQueueName = channel.queueDeclare().getQueue();

        AMQP.BasicProperties props = new AMQP.BasicProperties.Builder()
            .correlationId(corrId)
            .replyTo(replyQueueName)
            .build();

        // 发送请求
        channel.basicPublish("", requestQueueName, props, message.getBytes("UTF-8"));

        final CompletableFuture<String> response = new CompletableFuture<>();

        // 接收响应
        String ctag = channel.basicConsume(replyQueueName, true, (consumerTag, delivery) -> {
            if (delivery.getProperties().getCorrelationId().equals(corrId)) {
                response.complete(new String(delivery.getBody(), "UTF-8"));
            }
        }, consumerTag -> {});

        String result = response.get();
        channel.basicCancel(ctag);
        return result;
    }

    @Override
    public void close() throws Exception {
        connection.close();
    }
}
```

---

## 8.6 异步 RPC

### 异步客户端示例

```python
import pika
import uuid
from concurrent.futures import Future

class AsyncFibonacciRpcClient:
    def __init__(self):
        credentials = pika.PlainCredentials('admin', 'admin123')
        self.connection = pika.BlockingConnection(
            pika.ConnectionParameters('localhost', credentials=credentials)
        )
        self.channel = self.connection.channel()
        
        result = self.channel.queue_declare(queue='', exclusive=True)
        self.callback_queue = result.method.queue
        
        self.futures = {}  # 存储待处理的请求
        
        self.channel.basic_consume(
            queue=self.callback_queue,
            on_message_callback=self.on_response,
            auto_ack=True
        )
    
    def on_response(self, ch, method, props, body):
        if props.correlation_id in self.futures:
            future = self.futures.pop(props.correlation_id)
            future.set_result(int(body))
    
    def call_async(self, n):
        corr_id = str(uuid.uuid4())
        future = Future()
        self.futures[corr_id] = future
        
        self.channel.basic_publish(
            exchange='',
            routing_key='rpc_queue',
            properties=pika.BasicProperties(
                reply_to=self.callback_queue,
                correlation_id=corr_id,
            ),
            body=str(n)
        )
        
        return future
    
    def process_events(self):
        self.connection.process_data_events(time_limit=0.1)


# 使用示例
if __name__ == '__main__':
    client = AsyncFibonacciRpcClient()
    
    # 发送多个异步请求
    futures = []
    for i in range(10, 20):
        future = client.call_async(i)
        futures.append((i, future))
        print(f" [x] Sent request for fib({i})")
    
    # 处理响应
    while any(not f.done() for _, f in futures):
        client.process_events()
    
    # 获取结果
    for n, future in futures:
        print(f" [.] fib({n}) = {future.result()}")
```

---

## 8.7 RPC 最佳实践

### 注意事项

```
┌─────────────────────────────────────────────────────────────────┐
│                      RPC 使用注意事项                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. 明确区分本地调用和远程调用                                  │
│     - 远程调用可能失败、超时                                    │
│     - 使用专门的 RPC 客户端类                                   │
│                                                                 │
│  2. 记录异常信息                                                │
│     - 服务端异常应该返回给客户端                                │
│     - 不要静默失败                                              │
│                                                                 │
│  3. 设置超时                                                    │
│     - 避免无限等待                                              │
│     - 客户端应该有超时机制                                      │
│                                                                 │
│  4. 考虑扩展性                                                  │
│     - 多个 RPC 服务端可以监听同一队列                           │
│     - 使用 prefetch_count=1 实现负载均衡                        │
│                                                                 │
│  5. 避免过度使用                                                │
│     - RPC 不适合所有场景                                        │
│     - 考虑异步消息模式是否更合适                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 超时处理

```python
import time

def call_with_timeout(self, n, timeout=30):
    self.response = None
    self.corr_id = str(uuid.uuid4())
    
    self.channel.basic_publish(
        exchange='',
        routing_key='rpc_queue',
        properties=pika.BasicProperties(
            reply_to=self.callback_queue,
            correlation_id=self.corr_id,
        ),
        body=str(n)
    )
    
    start_time = time.time()
    while self.response is None:
        if time.time() - start_time > timeout:
            raise TimeoutError(f"RPC call timed out after {timeout}s")
        self.connection.process_data_events(time_limit=1)
    
    return int(self.response)
```

---

## 8.8 本章小结

| 概念 | 说明 |
|------|------|
| **reply_to** | 回调队列，接收响应 |
| **correlation_id** | 请求唯一标识 |
| **RPC 服务端** | 处理请求，发送响应 |
| **RPC 客户端** | 发送请求，等待响应 |

### 流程总结

1. 客户端创建回调队列
2. 客户端发送请求（带 reply_to 和 correlation_id）
3. 服务端处理请求
4. 服务端发送响应到回调队列（带 correlation_id）
5. 客户端匹配 correlation_id，获取响应

---

## 8.9 思考题

1. 如果 RPC 服务端崩溃，请求会丢失吗？如何解决？
2. 如何实现 RPC 请求的重试机制？
3. RPC 模式与普通的 HTTP REST 调用有什么区别？

---

**下一章**: [消息持久化机制](../09-persistence/README.md)
