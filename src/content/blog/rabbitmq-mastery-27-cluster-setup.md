---
title: "第27章：集群搭建实战"
description: "RabbitMQ 集群可以提供高可用性和更高的吞吐量。本章介绍使用 Docker 和 Docker Compose 搭建集群。"
pubDate: "2025-12-17"
tags: ["rabbitmq","mq","backend"]
category: "rabbitmq"
series: "RabbitMQ 消息队列"
order: 27
---

## 27.1 概述

RabbitMQ 集群可以提供高可用性和更高的吞吐量。本章介绍使用 Docker 和 Docker Compose 搭建集群。

### 集群架构

```
┌────────────────────────────────────────────────────────────────────────┐
│                        RabbitMQ Cluster                                │
│                                                                        │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐            │
│  │    Node 1    │◀──▶│    Node 2    │◀──▶│    Node 3    │            │
│  │   (rabbit1)  │    │   (rabbit2)  │    │   (rabbit3)  │            │
│  │   Disk Node  │    │   RAM Node   │    │   Disk Node  │            │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘            │
│         │                   │                   │                     │
│         └───────────────────┼───────────────────┘                     │
│                             │                                         │
│                     ┌───────┴───────┐                                 │
│                     │   HAProxy     │                                 │
│                     │  Load Balancer│                                 │
│                     └───────┬───────┘                                 │
│                             │                                         │
└─────────────────────────────┼─────────────────────────────────────────┘
                              │
                        ┌─────┴─────┐
                        │  Clients  │
                        └───────────┘
```

---

## 27.2 Docker Compose 集群部署

### docker-compose.yml

```yaml
version: '3.8'

services:
  rabbitmq1:
    image: rabbitmq:3.12-management
    hostname: rabbit1
    container_name: rabbitmq1
    environment:
      RABBITMQ_ERLANG_COOKIE: "SWQOKODSQALRPCLNMEQG"
      RABBITMQ_DEFAULT_USER: admin
      RABBITMQ_DEFAULT_PASS: admin123
      RABBITMQ_DEFAULT_VHOST: /
    ports:
      - "5672:5672"
      - "15672:15672"
    volumes:
      - rabbitmq1_data:/var/lib/rabbitmq
      - ./rabbitmq.conf:/etc/rabbitmq/rabbitmq.conf:ro
      - ./enabled_plugins:/etc/rabbitmq/enabled_plugins:ro
    networks:
      - rabbitmq-cluster
    healthcheck:
      test: rabbitmq-diagnostics -q ping
      interval: 30s
      timeout: 10s
      retries: 5

  rabbitmq2:
    image: rabbitmq:3.12-management
    hostname: rabbit2
    container_name: rabbitmq2
    environment:
      RABBITMQ_ERLANG_COOKIE: "SWQOKODSQALRPCLNMEQG"
      RABBITMQ_DEFAULT_USER: admin
      RABBITMQ_DEFAULT_PASS: admin123
    ports:
      - "5673:5672"
      - "15673:15672"
    volumes:
      - rabbitmq2_data:/var/lib/rabbitmq
      - ./rabbitmq.conf:/etc/rabbitmq/rabbitmq.conf:ro
      - ./enabled_plugins:/etc/rabbitmq/enabled_plugins:ro
    depends_on:
      - rabbitmq1
    networks:
      - rabbitmq-cluster

  rabbitmq3:
    image: rabbitmq:3.12-management
    hostname: rabbit3
    container_name: rabbitmq3
    environment:
      RABBITMQ_ERLANG_COOKIE: "SWQOKODSQALRPCLNMEQG"
      RABBITMQ_DEFAULT_USER: admin
      RABBITMQ_DEFAULT_PASS: admin123
    ports:
      - "5674:5672"
      - "15674:15672"
    volumes:
      - rabbitmq3_data:/var/lib/rabbitmq
      - ./rabbitmq.conf:/etc/rabbitmq/rabbitmq.conf:ro
      - ./enabled_plugins:/etc/rabbitmq/enabled_plugins:ro
    depends_on:
      - rabbitmq1
    networks:
      - rabbitmq-cluster

  haproxy:
    image: haproxy:2.8
    container_name: haproxy
    ports:
      - "5670:5672"
      - "15670:15672"
      - "1936:1936"
    volumes:
      - ./haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
    depends_on:
      - rabbitmq1
      - rabbitmq2
      - rabbitmq3
    networks:
      - rabbitmq-cluster

volumes:
  rabbitmq1_data:
  rabbitmq2_data:
  rabbitmq3_data:

networks:
  rabbitmq-cluster:
    driver: bridge
```

### rabbitmq.conf

```ini
# 集群配置
cluster_formation.peer_discovery_backend = rabbit_peer_discovery_classic_config
cluster_formation.classic_config.nodes.1 = rabbit@rabbit1
cluster_formation.classic_config.nodes.2 = rabbit@rabbit2
cluster_formation.classic_config.nodes.3 = rabbit@rabbit3

# 网络分区处理
cluster_partition_handling = autoheal

# 队列镜像（高可用）
# 通过策略配置，见下文

# 性能调优
vm_memory_high_watermark.relative = 0.7
disk_free_limit.relative = 1.5

# 日志
log.file.level = info
```

### enabled_plugins

```
[rabbitmq_management,rabbitmq_peer_discovery_common].
```

### haproxy.cfg

```
global
    log stdout format raw local0
    maxconn 4096

defaults
    log global
    mode tcp
    option tcplog
    option dontlognull
    retries 3
    timeout connect 5s
    timeout client 120s
    timeout server 120s

# 统计页面
listen stats
    bind *:1936
    mode http
    stats enable
    stats uri /
    stats refresh 5s
    stats auth admin:admin

# AMQP 负载均衡
listen rabbitmq_amqp
    bind *:5672
    mode tcp
    balance roundrobin
    option tcpka
    server rabbit1 rabbitmq1:5672 check inter 5s rise 2 fall 3
    server rabbit2 rabbitmq2:5672 check inter 5s rise 2 fall 3
    server rabbit3 rabbitmq3:5672 check inter 5s rise 2 fall 3

# Management UI 负载均衡
listen rabbitmq_management
    bind *:15672
    mode http
    balance roundrobin
    option httpchk GET /api/health/checks/alarms
    http-check expect status 200
    server rabbit1 rabbitmq1:15672 check inter 5s rise 2 fall 3
    server rabbit2 rabbitmq2:15672 check inter 5s rise 2 fall 3
    server rabbit3 rabbitmq3:15672 check inter 5s rise 2 fall 3
```

---

## 27.3 启动集群

### 启动命令

```bash
# 创建目录和文件
mkdir -p rabbitmq-cluster && cd rabbitmq-cluster

# 创建配置文件（上面的内容）
# docker-compose.yml
# rabbitmq.conf
# enabled_plugins
# haproxy.cfg

# 启动集群
docker-compose up -d

# 查看状态
docker-compose ps

# 查看日志
docker-compose logs -f

# 检查集群状态
docker exec rabbitmq1 rabbitmqctl cluster_status
```

### 手动加入集群

如果自动发现不工作，可以手动加入：

```bash
# 在 rabbit2 上
docker exec rabbitmq2 rabbitmqctl stop_app
docker exec rabbitmq2 rabbitmqctl reset
docker exec rabbitmq2 rabbitmqctl join_cluster rabbit@rabbit1
docker exec rabbitmq2 rabbitmqctl start_app

# 在 rabbit3 上
docker exec rabbitmq3 rabbitmqctl stop_app
docker exec rabbitmq3 rabbitmqctl reset
docker exec rabbitmq3 rabbitmqctl join_cluster rabbit@rabbit1
docker exec rabbitmq3 rabbitmqctl start_app

# 检查集群状态
docker exec rabbitmq1 rabbitmqctl cluster_status
```

---

## 27.4 配置镜像队列（高可用）

### 通过策略配置

```bash
# 所有队列镜像到所有节点
docker exec rabbitmq1 rabbitmqctl set_policy ha-all \
    "^" '{"ha-mode":"all","ha-sync-mode":"automatic"}' \
    --priority 0 --apply-to queues

# 以 ha. 开头的队列镜像到2个节点
docker exec rabbitmq1 rabbitmqctl set_policy ha-two \
    "^ha\." '{"ha-mode":"exactly","ha-params":2,"ha-sync-mode":"automatic"}' \
    --priority 1 --apply-to queues

# 查看策略
docker exec rabbitmq1 rabbitmqctl list_policies
```

### 策略参数说明

| 参数 | 说明 |
|------|------|
| `ha-mode: all` | 镜像到所有节点 |
| `ha-mode: exactly` | 镜像到指定数量节点 |
| `ha-mode: nodes` | 镜像到指定节点 |
| `ha-sync-mode` | automatic/manual |
| `ha-promote-on-shutdown` | 主节点关闭时的行为 |

---

## 27.5 Quorum Queue（推荐）

RabbitMQ 3.8+ 推荐使用 Quorum Queue 替代镜像队列。

### 创建 Quorum Queue

```python
import pika

credentials = pika.PlainCredentials('admin', 'admin123')
connection = pika.BlockingConnection(
    pika.ConnectionParameters('localhost', 5670, credentials=credentials)
)
channel = connection.channel()

# 声明 Quorum Queue
args = {'x-queue-type': 'quorum'}
channel.queue_declare(queue='quorum_queue', durable=True, arguments=args)

print("Quorum queue created")
connection.close()
```

### Quorum Queue vs 镜像队列

| 特性 | 镜像队列 | Quorum Queue |
|------|----------|--------------|
| 一致性 | 异步复制 | Raft 协议，强一致 |
| 性能 | 较高 | 稍低（换取一致性） |
| 消息顺序 | 可能乱序 | 严格顺序 |
| 推荐度 | 已废弃 | 推荐使用 |

---

## 27.6 集群管理

### 常用命令

```bash
# 查看集群状态
rabbitmqctl cluster_status

# 移除节点
rabbitmqctl forget_cluster_node rabbit@rabbit3

# 修改节点类型
rabbitmqctl change_cluster_node_type disc  # 或 ram

# 停止应用（不退出 Erlang）
rabbitmqctl stop_app

# 重置节点（清除所有数据）
rabbitmqctl reset

# 强制重置（即使不在集群中）
rabbitmqctl force_reset

# 启动应用
rabbitmqctl start_app
```

### 节点类型

| 类型 | 说明 |
|------|------|
| **Disc** | 元数据存储到磁盘，重启后保留 |
| **RAM** | 元数据只在内存，性能更高 |

**注意**: 至少需要一个 Disc 节点。

---

## 27.7 网络分区处理

### 分区策略

| 策略 | 说明 |
|------|------|
| `ignore` | 忽略分区（默认） |
| `pause_minority` | 少数派节点暂停 |
| `autoheal` | 自动选择胜者并重启败者 |
| `pause_if_all_down` | 指定节点全部下线时暂停 |

### 配置

```ini
# rabbitmq.conf
cluster_partition_handling = autoheal
```

---

## 27.8 监控集群

### 访问地址

- HAProxy 统计: http://localhost:1936 (admin/admin)
- RabbitMQ 管理界面: http://localhost:15670 (admin/admin123)
- 单节点管理界面:
  - http://localhost:15672 (rabbit1)
  - http://localhost:15673 (rabbit2)
  - http://localhost:15674 (rabbit3)

### Prometheus 监控

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'rabbitmq'
    static_configs:
      - targets:
        - 'rabbitmq1:15692'
        - 'rabbitmq2:15692'
        - 'rabbitmq3:15692'
```

启用 Prometheus 插件：
```bash
docker exec rabbitmq1 rabbitmq-plugins enable rabbitmq_prometheus
```

---

## 27.9 生产环境建议

```
┌─────────────────────────────────────────────────────────────────┐
│                    生产环境集群建议                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  节点配置:                                                      │
│  ├── 至少 3 个节点（奇数个，用于选举）                          │
│  ├── 至少 2 个 Disc 节点                                        │
│  ├── 各节点分布在不同物理机/可用区                              │
│  └── 网络延迟 < 1ms                                             │
│                                                                 │
│  高可用配置:                                                    │
│  ├── 使用 Quorum Queue                                          │
│  ├── 配置负载均衡（HAProxy/Nginx）                              │
│  ├── 设置合理的分区处理策略                                     │
│  └── 配置监控和告警                                             │
│                                                                 │
│  资源配置:                                                      │
│  ├── 内存: 8GB+                                                 │
│  ├── 磁盘: SSD，至少 50GB                                       │
│  ├── CPU: 4核+                                                  │
│  └── 预留足够的文件描述符                                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 27.10 本章小结

| 组件 | 说明 |
|------|------|
| **Erlang Cookie** | 集群认证，所有节点必须相同 |
| **节点类型** | Disc/RAM |
| **镜像队列** | 传统高可用方案 |
| **Quorum Queue** | 新一代高可用队列（推荐） |
| **HAProxy** | 负载均衡 |

---

**下一章**: [镜像队列](../28-mirror-queue/README.md)
