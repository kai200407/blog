---
title: "第38章：常见问题排查"
description: "Error: Connection refused (111)"
pubDate: "2025-12-17"
tags: ["rabbitmq","mq","backend"]
category: "rabbitmq"
series: "RabbitMQ 消息队列"
order: 38
---

## 38.1 连接问题

### 问题1：连接被拒绝

```
Error: Connection refused (111)
```

**排查步骤：**

```bash
# 1. 检查 RabbitMQ 是否运行
systemctl status rabbitmq-server
# 或
docker ps | grep rabbitmq

# 2. 检查端口
netstat -tlnp | grep 5672
ss -tlnp | grep 5672

# 3. 检查防火墙
iptables -L -n | grep 5672
ufw status

# 4. 检查监听地址
rabbitmqctl status | grep listeners
```

**解决方案：**

```ini
# rabbitmq.conf - 监听所有地址
listeners.tcp.default = 0.0.0.0:5672
```

---

### 问题2：认证失败

```
Error: ACCESS_REFUSED - Login was refused
```

**排查步骤：**

```bash
# 1. 检查用户是否存在
rabbitmqctl list_users

# 2. 检查用户权限
rabbitmqctl list_permissions -p /

# 3. 检查 vhost
rabbitmqctl list_vhosts
```

**解决方案：**

```bash
# 创建用户
rabbitmqctl add_user admin admin123

# 设置管理员
rabbitmqctl set_user_tags admin administrator

# 设置权限
rabbitmqctl set_permissions -p / admin ".*" ".*" ".*"
```

---

### 问题3：连接超时

```
Error: Connection timed out
```

**可能原因：**
- 网络不通
- 防火墙阻止
- RabbitMQ 负载过高
- 心跳配置问题

**解决方案：**

```python
# 增加连接超时和心跳
connection = pika.BlockingConnection(
    pika.ConnectionParameters(
        host='localhost',
        connection_attempts=3,
        retry_delay=5,
        socket_timeout=10,
        heartbeat=600,
        blocked_connection_timeout=300,
    )
)
```

---

## 38.2 消息问题

### 问题4：消息丢失

**排查清单：**

```
┌─────────────────────────────────────────────────────────────────┐
│                    消息丢失排查清单                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  生产者端：                                                     │
│  [ ] 是否开启发布确认？                                         │
│  [ ] 是否设置 mandatory=True？                                  │
│  [ ] 是否处理了 nack 和 return？                                │
│                                                                 │
│  服务端：                                                       │
│  [ ] 交换器是否持久化？                                         │
│  [ ] 队列是否持久化？                                           │
│  [ ] 消息是否持久化（delivery_mode=2）？                        │
│                                                                 │
│  消费者端：                                                     │
│  [ ] 是否使用手动确认（auto_ack=False）？                       │
│  [ ] 是否在处理完成后才确认？                                   │
│  [ ] 确认是否成功发送？                                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### 问题5：消息重复

**可能原因：**
- 生产者重试发送
- 消费者处理后确认失败
- 网络分区恢复后重发

**解决方案：**

```python
# 消费者实现幂等性
def callback(ch, method, properties, body):
    message_id = properties.message_id
    
    # 幂等性检查
    if redis.exists(f"msg:{message_id}"):
        ch.basic_ack(delivery_tag=method.delivery_tag)
        return
    
    # 处理消息
    process(body)
    
    # 标记已处理
    redis.set(f"msg:{message_id}", "1", ex=86400)
    
    ch.basic_ack(delivery_tag=method.delivery_tag)
```

---

### 问题6：消息堆积

**排查命令：**

```bash
# 查看队列状态
rabbitmqctl list_queues name messages consumers message_bytes

# 查看消费者
rabbitmqctl list_consumers

# 查看信道状态
rabbitmqctl list_channels name consumer_count messages_unacknowledged
```

**解决方案：**

1. 增加消费者数量
2. 检查消费者处理速度
3. 检查下游服务性能
4. 考虑批量处理

---

## 38.3 性能问题

### 问题7：吞吐量低

**排查步骤：**

```bash
# 1. 检查资源使用
rabbitmqctl status

# 2. 检查内存
rabbitmqctl eval 'erlang:memory().'

# 3. 检查磁盘
df -h

# 4. 检查连接/信道数
rabbitmqctl list_connections | wc -l
rabbitmqctl list_channels | wc -l
```

**优化建议：**

```
┌─────────────────────────────────────────────────────────────────┐
│                    性能优化建议                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  连接优化：                                                     │
│  ├── 复用 Connection，不要频繁创建                              │
│  ├── 每个线程使用独立 Channel                                   │
│  └── 使用连接池                                                 │
│                                                                 │
│  发送优化：                                                     │
│  ├── 使用异步发布确认                                           │
│  ├── 批量发送                                                   │
│  └── 减小消息大小                                               │
│                                                                 │
│  消费优化：                                                     │
│  ├── 增加 prefetch_count                                        │
│  ├── 批量确认                                                   │
│  └── 多消费者并行                                               │
│                                                                 │
│  服务端优化：                                                   │
│  ├── 使用 SSD                                                   │
│  ├── 增加内存                                                   │
│  ├── 使用惰性队列                                               │
│  └── 合理配置内存阈值                                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### 问题8：内存告警

```
Error: {resource_alarm,[{mem,rabbit@hostname}]}
```

**解决方案：**

```bash
# 1. 查看内存使用
rabbitmqctl status | grep memory

# 2. 清除内存
rabbitmqctl eval 'rabbit_memory_monitor:gc().'

# 3. 调整阈值
rabbitmqctl set_vm_memory_high_watermark 0.8
```

```ini
# rabbitmq.conf
vm_memory_high_watermark.relative = 0.7
vm_memory_high_watermark_paging_ratio = 0.5
```

---

### 问题9：磁盘告警

```
Error: {resource_alarm,[{disk,rabbit@hostname}]}
```

**解决方案：**

```bash
# 1. 检查磁盘空间
df -h

# 2. 清理日志
rabbitmqctl rotate_logs

# 3. 清理过期消息（通过设置 TTL）
rabbitmqctl set_policy ttl ".*" '{"message-ttl":86400000}' --apply-to queues

# 4. 调整磁盘阈值
rabbitmqctl set_disk_free_limit 1GB
```

---

## 38.4 集群问题

### 问题10：节点无法加入集群

**排查步骤：**

```bash
# 1. 检查 Erlang Cookie
cat /var/lib/rabbitmq/.erlang.cookie
# 所有节点必须相同

# 2. 检查主机名解析
ping rabbit1
ping rabbit2

# 3. 检查集群状态
rabbitmqctl cluster_status

# 4. 检查防火墙
# 需要开放: 4369, 25672, 5672, 15672
```

**解决方案：**

```bash
# 强制重置节点
rabbitmqctl stop_app
rabbitmqctl force_reset
rabbitmqctl join_cluster rabbit@rabbit1
rabbitmqctl start_app
```

---

### 问题11：网络分区

```
Network partition detected
```

**排查：**

```bash
# 查看分区状态
rabbitmqctl cluster_status
```

**解决方案：**

```ini
# rabbitmq.conf
cluster_partition_handling = autoheal
# 或
cluster_partition_handling = pause_minority
```

```bash
# 手动恢复
# 1. 选择一个分区作为主分区
# 2. 在其他分区的节点上执行
rabbitmqctl stop_app
rabbitmqctl reset
rabbitmqctl join_cluster rabbit@rabbit1
rabbitmqctl start_app
```

---

## 38.5 常用诊断命令

```bash
# 集群状态
rabbitmqctl cluster_status

# 节点健康检查
rabbitmq-diagnostics check_running
rabbitmq-diagnostics check_local_alarms
rabbitmq-diagnostics check_port_connectivity

# 队列详情
rabbitmqctl list_queues name messages consumers state

# 连接详情
rabbitmqctl list_connections name user state recv_oct send_oct

# 信道详情
rabbitmqctl list_channels name consumer_count messages_unacknowledged

# 交换器详情
rabbitmqctl list_exchanges name type durable

# 绑定详情
rabbitmqctl list_bindings

# 内存使用
rabbitmqctl eval 'rabbit_vm:memory().'

# 环境变量
rabbitmqctl environment

# 报告
rabbitmq-diagnostics report > rabbitmq-report.txt
```

---

## 38.6 日志分析

**日志位置：**

```bash
# 默认位置
/var/log/rabbitmq/

# Docker
docker logs rabbitmq
```

**常见日志模式：**

```bash
# 连接建立
grep "connection" /var/log/rabbitmq/rabbit@*.log

# 连接关闭
grep "closing" /var/log/rabbitmq/rabbit@*.log

# 错误
grep -i "error" /var/log/rabbitmq/rabbit@*.log

# 告警
grep -i "alarm" /var/log/rabbitmq/rabbit@*.log
```

---

## 38.7 本章小结

| 问题类型 | 常见原因 | 排查工具 |
|----------|----------|----------|
| 连接问题 | 网络、认证、配置 | telnet, rabbitmqctl |
| 消息丢失 | 未持久化、未确认 | 代码审查 |
| 消息堆积 | 消费慢、消费者少 | list_queues |
| 性能问题 | 资源不足、配置不当 | status, diagnostics |
| 集群问题 | Cookie、网络 | cluster_status |

---

**下一章**: [版本升级指南](../39-upgrade/README.md)
