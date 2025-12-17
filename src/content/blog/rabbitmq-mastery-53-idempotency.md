---
title: "第53章：消息幂等性设计"
description: "幂等性是指一个操作执行多次与执行一次的效果相同。在消息队列系统中，由于网络问题、消费者重启等原因，消息可能被重复投递，因此必须保证消息处理的幂等性。"
pubDate: "2025-12-17"
tags: ["rabbitmq","mq","backend"]
category: "rabbitmq"
series: "RabbitMQ 消息队列"
order: 53
---

## 53.1 概述

幂等性是指一个操作执行多次与执行一次的效果相同。在消息队列系统中，由于网络问题、消费者重启等原因，消息可能被重复投递，因此必须保证消息处理的幂等性。

### 消息重复的场景

```
┌─────────────────────────────────────────────────────────────────┐
│                   消息重复投递场景                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  场景1: 生产者重试                                               │
│  ├── 发送消息后网络超时                                          │
│  ├── 生产者重试发送                                              │
│  └── 实际消息已成功，导致重复                                    │
│                                                                 │
│  场景2: 消费者重启                                               │
│  ├── 消费者处理消息后未确认                                      │
│  ├── 消费者重启                                                  │
│  └── 消息重新投递                                                │
│                                                                 │
│  场景3: 网络分区                                                 │
│  ├── 消费者已确认但确认消息丢失                                  │
│  ├── RabbitMQ 认为未确认                                         │
│  └── 消息重新投递                                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 53.2 幂等性实现方案

### 方案对比

| 方案 | 实现复杂度 | 性能 | 适用场景 |
|------|------------|------|----------|
| 唯一消息ID + 去重表 | 中 | 中 | 通用 |
| 业务状态机 | 中 | 高 | 状态流转业务 |
| 乐观锁（版本号）| 低 | 高 | 更新操作 |
| Redis 去重 | 低 | 高 | 高并发场景 |
| 数据库唯一约束 | 低 | 中 | 插入操作 |

---

## 53.3 方案一：唯一消息ID + 去重表

### 数据库表设计

```sql
CREATE TABLE message_dedup (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    message_id VARCHAR(64) NOT NULL UNIQUE,
    business_key VARCHAR(128),
    status TINYINT DEFAULT 0 COMMENT '0:处理中 1:成功 2:失败',
    result TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_message_id (message_id),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB;
```

### 实现代码

```python
import uuid
import pymysql
from contextlib import contextmanager

class IdempotentProcessor:
    """基于数据库的幂等处理器"""
    
    def __init__(self, db_config):
        self.db_config = db_config
    
    @contextmanager
    def get_connection(self):
        conn = pymysql.connect(**self.db_config)
        try:
            yield conn
        finally:
            conn.close()
    
    def process_message(self, message_id, business_key, handler):
        """
        幂等处理消息
        
        Args:
            message_id: 消息唯一ID
            business_key: 业务标识
            handler: 实际处理函数
        
        Returns:
            (success, result, is_duplicate)
        """
        with self.get_connection() as conn:
            cursor = conn.cursor()
            
            try:
                # 1. 尝试插入去重记录
                cursor.execute("""
                    INSERT INTO message_dedup (message_id, business_key, status)
                    VALUES (%s, %s, 0)
                """, (message_id, business_key))
                conn.commit()
                
            except pymysql.err.IntegrityError:
                # 记录已存在，查询状态
                cursor.execute("""
                    SELECT status, result FROM message_dedup 
                    WHERE message_id = %s
                """, (message_id,))
                row = cursor.fetchone()
                
                if row:
                    status, result = row
                    if status == 1:
                        # 已成功处理
                        return (True, result, True)
                    elif status == 2:
                        # 已失败
                        return (False, result, True)
                    else:
                        # 处理中，可能是并发请求
                        return (False, "Processing", True)
            
            # 2. 执行业务处理
            try:
                result = handler()
                
                # 3. 更新为成功
                cursor.execute("""
                    UPDATE message_dedup 
                    SET status = 1, result = %s 
                    WHERE message_id = %s
                """, (str(result), message_id))
                conn.commit()
                
                return (True, result, False)
                
            except Exception as e:
                # 4. 更新为失败
                cursor.execute("""
                    UPDATE message_dedup 
                    SET status = 2, result = %s 
                    WHERE message_id = %s
                """, (str(e), message_id))
                conn.commit()
                
                return (False, str(e), False)


# 使用示例
def callback(ch, method, properties, body):
    message_id = properties.message_id or str(uuid.uuid4())
    
    processor = IdempotentProcessor(db_config)
    
    def handler():
        # 实际业务逻辑
        data = json.loads(body)
        return process_order(data)
    
    success, result, is_duplicate = processor.process_message(
        message_id=message_id,
        business_key=f"order:{data.get('order_id')}",
        handler=handler
    )
    
    if is_duplicate:
        print(f"Duplicate message {message_id}, skipping")
    
    ch.basic_ack(delivery_tag=method.delivery_tag)
```

---

## 53.4 方案二：Redis 去重

```python
import redis
import json
import time

class RedisIdempotent:
    """基于 Redis 的幂等处理器"""
    
    def __init__(self, redis_client, key_prefix="msg:dedup:", ttl=86400):
        self.redis = redis_client
        self.key_prefix = key_prefix
        self.ttl = ttl
    
    def get_key(self, message_id):
        return f"{self.key_prefix}{message_id}"
    
    def is_processed(self, message_id):
        """检查是否已处理"""
        return self.redis.exists(self.get_key(message_id))
    
    def try_lock(self, message_id):
        """
        尝试获取处理锁
        返回 True 表示获取成功，可以处理
        """
        key = self.get_key(message_id)
        # SET NX EX 原子操作
        return self.redis.set(key, "processing", nx=True, ex=300)
    
    def mark_success(self, message_id, result=None):
        """标记处理成功"""
        key = self.get_key(message_id)
        data = {
            'status': 'success',
            'result': result,
            'time': time.time()
        }
        self.redis.set(key, json.dumps(data), ex=self.ttl)
    
    def mark_failed(self, message_id, error=None):
        """标记处理失败，删除锁允许重试"""
        key = self.get_key(message_id)
        self.redis.delete(key)
    
    def process(self, message_id, handler):
        """
        幂等处理
        
        Returns:
            (success, result, is_duplicate)
        """
        # 1. 检查是否已处理
        key = self.get_key(message_id)
        existing = self.redis.get(key)
        
        if existing:
            data = json.loads(existing)
            if data.get('status') == 'success':
                return (True, data.get('result'), True)
            elif data == "processing":
                # 正在处理中
                return (False, "Processing by another consumer", True)
        
        # 2. 尝试获取锁
        if not self.try_lock(message_id):
            return (False, "Failed to acquire lock", True)
        
        # 3. 执行处理
        try:
            result = handler()
            self.mark_success(message_id, result)
            return (True, result, False)
        except Exception as e:
            self.mark_failed(message_id, str(e))
            raise


# 使用示例
redis_client = redis.Redis(host='localhost', port=6379, decode_responses=True)
idempotent = RedisIdempotent(redis_client)

def callback(ch, method, properties, body):
    message_id = properties.message_id
    
    if not message_id:
        # 如果没有消息ID，用内容哈希
        import hashlib
        message_id = hashlib.md5(body).hexdigest()
    
    try:
        success, result, is_duplicate = idempotent.process(
            message_id,
            lambda: process_message(json.loads(body))
        )
        
        if is_duplicate:
            print(f"Duplicate message: {message_id}")
        
        ch.basic_ack(delivery_tag=method.delivery_tag)
        
    except Exception as e:
        print(f"Error: {e}")
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True)
```

---

## 53.5 方案三：业务状态机

```python
from enum import Enum

class OrderStatus(Enum):
    CREATED = 'created'
    PAID = 'paid'
    SHIPPED = 'shipped'
    COMPLETED = 'completed'
    CANCELLED = 'cancelled'

# 状态转换规则
STATE_TRANSITIONS = {
    OrderStatus.CREATED: [OrderStatus.PAID, OrderStatus.CANCELLED],
    OrderStatus.PAID: [OrderStatus.SHIPPED, OrderStatus.CANCELLED],
    OrderStatus.SHIPPED: [OrderStatus.COMPLETED],
    OrderStatus.COMPLETED: [],
    OrderStatus.CANCELLED: [],
}

class OrderStateMachine:
    """订单状态机"""
    
    def __init__(self, db):
        self.db = db
    
    def can_transition(self, current_status, target_status):
        """检查状态转换是否合法"""
        allowed = STATE_TRANSITIONS.get(current_status, [])
        return target_status in allowed
    
    def transition(self, order_id, target_status, handler):
        """
        执行状态转换（幂等）
        
        使用乐观锁确保并发安全
        """
        # 获取当前状态
        order = self.db.get_order(order_id)
        if not order:
            raise Exception(f"Order {order_id} not found")
        
        current_status = OrderStatus(order['status'])
        
        # 已经是目标状态，幂等返回
        if current_status == target_status:
            return {'success': True, 'message': 'Already in target status'}
        
        # 检查转换是否合法
        if not self.can_transition(current_status, target_status):
            raise Exception(
                f"Invalid transition: {current_status} -> {target_status}"
            )
        
        # 执行业务逻辑
        result = handler(order)
        
        # 使用乐观锁更新状态
        updated = self.db.update_order_status(
            order_id=order_id,
            old_status=current_status.value,
            new_status=target_status.value,
            version=order['version']
        )
        
        if not updated:
            raise Exception("Concurrent modification detected")
        
        return {'success': True, 'result': result}


# 数据库层面的乐观锁
"""
UPDATE orders 
SET status = 'paid', version = version + 1, updated_at = NOW()
WHERE order_id = '12345' 
  AND status = 'created' 
  AND version = 1
"""
```

---

## 53.6 方案四：数据库唯一约束

```python
def create_order_idempotent(order_data):
    """
    创建订单（幂等）
    利用数据库唯一约束
    """
    try:
        # 使用请求ID作为幂等键
        idempotency_key = order_data.get('idempotency_key')
        
        cursor.execute("""
            INSERT INTO orders (
                idempotency_key, user_id, product_id, amount, status
            ) VALUES (%s, %s, %s, %s, 'created')
        """, (
            idempotency_key,
            order_data['user_id'],
            order_data['product_id'],
            order_data['amount']
        ))
        
        order_id = cursor.lastrowid
        conn.commit()
        
        return {'success': True, 'order_id': order_id, 'is_new': True}
        
    except pymysql.err.IntegrityError as e:
        if 'Duplicate entry' in str(e):
            # 已存在，查询返回
            cursor.execute("""
                SELECT order_id, status FROM orders 
                WHERE idempotency_key = %s
            """, (idempotency_key,))
            
            row = cursor.fetchone()
            return {
                'success': True, 
                'order_id': row[0], 
                'is_new': False,
                'status': row[1]
            }
        raise
```

---

## 53.7 生产者端幂等

```python
import pika
import uuid

class IdempotentProducer:
    """幂等生产者"""
    
    def __init__(self, channel):
        self.channel = channel
        self.sent_messages = {}  # 内存缓存已发送消息
    
    def publish(self, exchange, routing_key, body, idempotency_key=None):
        """
        幂等发送消息
        
        Args:
            idempotency_key: 幂等键，相同的键只发送一次
        """
        if idempotency_key is None:
            idempotency_key = str(uuid.uuid4())
        
        # 检查是否已发送
        if idempotency_key in self.sent_messages:
            print(f"Message {idempotency_key} already sent, skipping")
            return self.sent_messages[idempotency_key]
        
        message_id = str(uuid.uuid4())
        
        self.channel.basic_publish(
            exchange=exchange,
            routing_key=routing_key,
            body=body,
            properties=pika.BasicProperties(
                message_id=message_id,
                headers={'x-idempotency-key': idempotency_key},
                delivery_mode=2,
            )
        )
        
        # 记录已发送
        self.sent_messages[idempotency_key] = message_id
        
        return message_id
```

---

## 53.8 最佳实践

```
┌─────────────────────────────────────────────────────────────────┐
│                      幂等性最佳实践                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. 消息必须携带唯一ID                                          │
│     - 生产者生成 message_id                                     │
│     - 使用 UUID 或业务ID                                        │
│                                                                 │
│  2. 选择合适的去重方案                                          │
│     - 高并发：Redis                                             │
│     - 需要持久化：数据库                                        │
│     - 状态流转：状态机                                          │
│                                                                 │
│  3. 设置合理的去重时间窗口                                      │
│     - 太短：重复消息可能漏掉                                    │
│     - 太长：占用存储空间                                        │
│     - 建议：24小时-7天                                          │
│                                                                 │
│  4. 处理并发场景                                                │
│     - 使用分布式锁                                              │
│     - 使用乐观锁                                                │
│                                                                 │
│  5. 业务层面保证                                                │
│     - 更新操作使用幂等SQL                                       │
│     - 插入操作使用唯一约束                                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 53.9 本章小结

| 方案 | 优点 | 缺点 |
|------|------|------|
| DB去重表 | 持久化、可靠 | 性能一般 |
| Redis去重 | 高性能 | 需要Redis |
| 状态机 | 业务语义清晰 | 仅适用状态场景 |
| 唯一约束 | 简单可靠 | 仅适用插入 |

---

**下一章**: [消息顺序性保证](../54-ordering/README.md)
