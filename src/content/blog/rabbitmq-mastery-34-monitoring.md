---
title: "第34章：监控与告警"
description: "RabbitMQ 提供多种监控方式，包括管理界面、CLI 工具、HTTP API 和 Prometheus 集成。"
pubDate: "2025-12-17"
tags: ["rabbitmq","mq","backend"]
category: "rabbitmq"
series: "RabbitMQ 消息队列"
order: 34
---

## 34.1 概述

RabbitMQ 提供多种监控方式，包括管理界面、CLI 工具、HTTP API 和 Prometheus 集成。

### 监控架构

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         RabbitMQ 监控架构                                │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐      │
│  │   RabbitMQ 1    │    │   RabbitMQ 2    │    │   RabbitMQ 3    │      │
│  │   :15692        │    │   :15692        │    │   :15692        │      │
│  └────────┬────────┘    └────────┬────────┘    └────────┬────────┘      │
│           │                      │                      │               │
│           └──────────────────────┼──────────────────────┘               │
│                                  │                                       │
│                                  ▼                                       │
│                        ┌─────────────────┐                              │
│                        │   Prometheus    │                              │
│                        │   :9090         │                              │
│                        └────────┬────────┘                              │
│                                 │                                        │
│                                 ▼                                        │
│                        ┌─────────────────┐                              │
│                        │    Grafana      │                              │
│                        │    :3000        │                              │
│                        └────────┬────────┘                              │
│                                 │                                        │
│                                 ▼                                        │
│                        ┌─────────────────┐                              │
│                        │   AlertManager  │ ──▶ Slack/Email/PagerDuty   │
│                        └─────────────────┘                              │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 34.2 Management UI

### 访问地址

```
http://localhost:15672
```

### 功能概览

| 标签页 | 功能 |
|--------|------|
| **Overview** | 集群概览、消息速率、连接数 |
| **Connections** | 连接列表、连接详情 |
| **Channels** | 信道列表、信道状态 |
| **Exchanges** | 交换器管理 |
| **Queues** | 队列管理、消息查看 |
| **Admin** | 用户、权限、策略管理 |

### 关键指标

```
┌─────────────────────────────────────────────────────────────────┐
│                    Overview 页面关键指标                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Queued messages:                                               │
│  ├── Ready: 待消费消息数                                        │
│  └── Unacked: 已发送未确认消息数                                │
│                                                                 │
│  Message rates:                                                 │
│  ├── Publish: 发布速率 (msg/s)                                  │
│  ├── Deliver: 投递速率 (msg/s)                                  │
│  └── Ack: 确认速率 (msg/s)                                      │
│                                                                 │
│  Global counts:                                                 │
│  ├── Connections: 连接数                                        │
│  ├── Channels: 信道数                                           │
│  ├── Exchanges: 交换器数                                        │
│  └── Queues: 队列数                                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 34.3 HTTP API

### API 端点

```bash
# 集群概览
curl -u admin:admin123 http://localhost:15672/api/overview

# 节点列表
curl -u admin:admin123 http://localhost:15672/api/nodes

# 队列列表
curl -u admin:admin123 http://localhost:15672/api/queues

# 特定队列
curl -u admin:admin123 http://localhost:15672/api/queues/%2F/my_queue

# 连接列表
curl -u admin:admin123 http://localhost:15672/api/connections

# 信道列表
curl -u admin:admin123 http://localhost:15672/api/channels

# 健康检查
curl -u admin:admin123 http://localhost:15672/api/health/checks/alarms
```

### Python 监控脚本

```python
#!/usr/bin/env python
"""RabbitMQ 监控脚本"""
import requests
from requests.auth import HTTPBasicAuth

class RabbitMQMonitor:
    def __init__(self, host='localhost', port=15672, user='admin', password='admin123'):
        self.base_url = f'http://{host}:{port}/api'
        self.auth = HTTPBasicAuth(user, password)
    
    def get_overview(self):
        """获取概览"""
        resp = requests.get(f'{self.base_url}/overview', auth=self.auth)
        return resp.json()
    
    def get_queues(self):
        """获取队列列表"""
        resp = requests.get(f'{self.base_url}/queues', auth=self.auth)
        return resp.json()
    
    def get_queue_depth(self, queue_name, vhost='/'):
        """获取队列深度"""
        vhost_encoded = requests.utils.quote(vhost, safe='')
        resp = requests.get(
            f'{self.base_url}/queues/{vhost_encoded}/{queue_name}',
            auth=self.auth
        )
        data = resp.json()
        return {
            'ready': data.get('messages_ready', 0),
            'unacked': data.get('messages_unacknowledged', 0),
            'total': data.get('messages', 0),
        }
    
    def check_health(self):
        """健康检查"""
        resp = requests.get(
            f'{self.base_url}/health/checks/alarms',
            auth=self.auth
        )
        return resp.status_code == 200
    
    def print_status(self):
        """打印状态"""
        overview = self.get_overview()
        
        print("=" * 50)
        print("RabbitMQ Status")
        print("=" * 50)
        print(f"Version: {overview.get('rabbitmq_version')}")
        print(f"Erlang: {overview.get('erlang_version')}")
        print(f"Cluster: {overview.get('cluster_name')}")
        print()
        
        # 消息统计
        queue_totals = overview.get('queue_totals', {})
        print("Messages:")
        print(f"  Ready: {queue_totals.get('messages_ready', 0)}")
        print(f"  Unacked: {queue_totals.get('messages_unacknowledged', 0)}")
        print()
        
        # 消息速率
        msg_stats = overview.get('message_stats', {})
        print("Message Rates:")
        print(f"  Publish: {msg_stats.get('publish_details', {}).get('rate', 0):.1f}/s")
        print(f"  Deliver: {msg_stats.get('deliver_get_details', {}).get('rate', 0):.1f}/s")
        print()
        
        # 对象统计
        obj_totals = overview.get('object_totals', {})
        print("Objects:")
        print(f"  Connections: {obj_totals.get('connections', 0)}")
        print(f"  Channels: {obj_totals.get('channels', 0)}")
        print(f"  Queues: {obj_totals.get('queues', 0)}")
        print(f"  Exchanges: {obj_totals.get('exchanges', 0)}")
        print("=" * 50)


if __name__ == '__main__':
    monitor = RabbitMQMonitor()
    monitor.print_status()
```

---

## 34.4 Prometheus 集成

### 启用插件

```bash
rabbitmq-plugins enable rabbitmq_prometheus
```

### Prometheus 配置

```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'rabbitmq'
    static_configs:
      - targets:
        - 'rabbitmq1:15692'
        - 'rabbitmq2:15692'
        - 'rabbitmq3:15692'
    metrics_path: /metrics
```

### 关键指标

| 指标 | 说明 |
|------|------|
| `rabbitmq_queue_messages` | 队列消息数 |
| `rabbitmq_queue_messages_ready` | 待消费消息数 |
| `rabbitmq_queue_messages_unacked` | 未确认消息数 |
| `rabbitmq_queue_consumers` | 消费者数 |
| `rabbitmq_connections` | 连接数 |
| `rabbitmq_channels` | 信道数 |
| `rabbitmq_process_resident_memory_bytes` | 内存使用 |
| `rabbitmq_disk_space_available_bytes` | 可用磁盘 |

---

## 34.5 Docker Compose 监控栈

```yaml
version: '3.8'

services:
  rabbitmq:
    image: rabbitmq:3.12-management
    container_name: rabbitmq
    ports:
      - "5672:5672"
      - "15672:15672"
      - "15692:15692"
    environment:
      RABBITMQ_DEFAULT_USER: admin
      RABBITMQ_DEFAULT_PASS: admin123
    command: >
      bash -c "rabbitmq-plugins enable rabbitmq_prometheus && rabbitmq-server"

  prometheus:
    image: prom/prometheus:v2.47.0
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'

  grafana:
    image: grafana/grafana:10.1.0
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: admin123
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning

  alertmanager:
    image: prom/alertmanager:v0.26.0
    container_name: alertmanager
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml

volumes:
  prometheus_data:
  grafana_data:
```

---

## 34.6 告警规则

### Prometheus 告警规则

```yaml
# rabbitmq_alerts.yml
groups:
  - name: rabbitmq
    rules:
      # 队列消息堆积
      - alert: RabbitMQQueueBacklog
        expr: rabbitmq_queue_messages > 10000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Queue backlog detected"
          description: "Queue {{ $labels.queue }} has {{ $value }} messages"

      # 无消费者
      - alert: RabbitMQNoConsumers
        expr: rabbitmq_queue_consumers == 0 and rabbitmq_queue_messages > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Queue has no consumers"
          description: "Queue {{ $labels.queue }} has messages but no consumers"

      # 内存告警
      - alert: RabbitMQHighMemory
        expr: rabbitmq_process_resident_memory_bytes > 1073741824
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage"
          description: "RabbitMQ memory usage is {{ $value | humanize1024 }}"

      # 节点下线
      - alert: RabbitMQNodeDown
        expr: up{job="rabbitmq"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "RabbitMQ node down"
          description: "Node {{ $labels.instance }} is down"

      # 未确认消息过多
      - alert: RabbitMQHighUnacked
        expr: rabbitmq_queue_messages_unacked > 1000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High unacknowledged messages"
          description: "Queue {{ $labels.queue }} has {{ $value }} unacked messages"
```

---

## 34.7 CLI 监控命令

```bash
# 集群状态
rabbitmqctl cluster_status

# 节点健康检查
rabbitmq-diagnostics check_running
rabbitmq-diagnostics check_local_alarms
rabbitmq-diagnostics check_port_connectivity

# 队列列表
rabbitmqctl list_queues name messages consumers

# 连接列表
rabbitmqctl list_connections name user state

# 信道列表
rabbitmqctl list_channels name consumer_count messages_unacknowledged

# 内存使用
rabbitmqctl status | grep memory

# 磁盘使用
rabbitmq-diagnostics check_if_node_is_quorum_critical
```

---

## 34.8 关键监控项

```
┌─────────────────────────────────────────────────────────────────┐
│                      关键监控指标                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ❗ 必须监控:                                                    │
│  ├── 队列消息数 (messages_ready)                                 │
│  ├── 未确认消息数 (messages_unacked)                             │
│  ├── 消费者数量 (consumers)                                      │
│  ├── 内存使用率                                                  │
│  └── 磁盘空间                                                    │
│                                                                 │
│  📊 性能指标:                                                    │
│  ├── 消息发布速率                                                │
│  ├── 消息投递速率                                                │
│  ├── 消息确认速率                                                │
│  └── 连接/信道数                                                 │
│                                                                 │
│  🚨 告警阈值建议:                                                │
│  ├── 队列堆积 > 10000: Warning                                   │
│  ├── 队列堆积 > 100000: Critical                                 │
│  ├── 无消费者 + 有消息: Critical                                 │
│  ├── 内存 > 70%: Warning                                        │
│  └── 磁盘 < 2GB: Critical                                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 34.9 本章小结

| 监控方式 | 适用场景 |
|----------|----------|
| Management UI | 日常查看、调试 |
| HTTP API | 自定义监控、脚本 |
| Prometheus | 生产环境、告警 |
| CLI | 运维排查 |

---

**下一章**: [日志分析](../35-logging/README.md)
