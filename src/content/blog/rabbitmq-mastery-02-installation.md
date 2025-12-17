---
title: "第02章：RabbitMQ 简介与安装"
description: "RabbitMQ 是一个由 Erlang 语言开发的 **AMQP（高级消息队列协议）** 的开源实现，由 Pivotal（现VMware）公司维护。"
pubDate: "2025-12-17"
tags: ["rabbitmq","mq","backend"]
category: "rabbitmq"
series: "RabbitMQ 消息队列"
order: 2
---

## 2.1 RabbitMQ 简介

### 什么是 RabbitMQ

RabbitMQ 是一个由 Erlang 语言开发的 **AMQP（高级消息队列协议）** 的开源实现，由 Pivotal（现VMware）公司维护。

### 核心特性

| 特性 | 说明 |
|------|------|
| **可靠性** | 持久化、传输确认、发布确认 |
| **灵活路由** | 内置多种交换器类型，支持插件扩展 |
| **集群** | 多节点集群，支持镜像队列 |
| **高可用** | 支持队列在集群中的复制 |
| **多协议** | AMQP、STOMP、MQTT、HTTP |
| **多语言** | Java、Python、Ruby、PHP、C#、Go等 |
| **管理界面** | 内置Web管理UI |
| **插件机制** | 丰富的插件扩展能力 |

### RabbitMQ 架构

```
┌────────────────────────────────────────────────────────────────────────┐
│                         RabbitMQ Broker                                │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                      Virtual Host (vhost)                        │  │
│  │  ┌──────────┐    ┌──────────────────────────────────────┐       │  │
│  │  │ Exchange │───▶│              Bindings                │       │  │
│  │  │          │    │  ┌─────────┐  ┌─────────┐  ┌───────┐ │       │  │
│  │  │ ┌──────┐ │    │  │ Queue 1 │  │ Queue 2 │  │Queue N│ │       │  │
│  │  │ │Direct│ │    │  └────┬────┘  └────┬────┘  └───┬───┘ │       │  │
│  │  │ ├──────┤ │    └───────│────────────│───────────│─────┘       │  │
│  │  │ │Fanout│ │            ▼            ▼           ▼             │  │
│  │  │ ├──────┤ │      ┌──────────┐ ┌──────────┐ ┌──────────┐      │  │
│  │  │ │Topic │ │      │Consumer 1│ │Consumer 2│ │Consumer N│      │  │
│  │  │ ├──────┤ │      └──────────┘ └──────────┘ └──────────┘      │  │
│  │  │ │Headers│ │                                                  │  │
│  │  │ └──────┘ │                                                   │  │
│  │  └──────────┘                                                   │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                        │
│  ┌─────────┐  ┌─────────────┐  ┌───────────┐  ┌─────────────────┐     │
│  │Erlang VM│  │ Mnesia DB   │  │ Plugins   │  │Management Plugin│     │
│  └─────────┘  └─────────────┘  └───────────┘  └─────────────────┘     │
└────────────────────────────────────────────────────────────────────────┘
          ▲                                               ▲
          │                                               │
   ┌──────┴──────┐                                 ┌──────┴──────┐
   │  Producer   │                                 │ Management  │
   │  (AMQP)     │                                 │  UI (:15672)│
   └─────────────┘                                 └─────────────┘
```

### 核心组件

| 组件 | 说明 |
|------|------|
| **Broker** | RabbitMQ服务实例 |
| **Virtual Host** | 虚拟主机，逻辑隔离单元 |
| **Connection** | TCP连接 |
| **Channel** | 信道，多路复用 |
| **Exchange** | 交换器，消息路由 |
| **Queue** | 队列，消息存储 |
| **Binding** | 绑定关系 |
| **Routing Key** | 路由键 |

---

## 2.2 安装方式总览

| 安装方式 | 适用场景 | 难度 |
|----------|----------|------|
| Docker（推荐）| 开发/测试/生产 | ⭐ |
| Docker Compose | 快速搭建环境 | ⭐ |
| 包管理器 | Linux生产环境 | ⭐⭐ |
| 二进制包 | 特定版本需求 | ⭐⭐⭐ |
| 源码编译 | 定制化需求 | ⭐⭐⭐⭐ |
| Kubernetes | 容器化生产环境 | ⭐⭐⭐ |

---

## 2.3 Docker 安装（推荐）

### 2.3.1 单节点快速启动

```bash
# 拉取官方镜像（带管理界面）
docker pull rabbitmq:3.12-management

# 启动容器
docker run -d \
  --name rabbitmq \
  --hostname rabbitmq-node1 \
  -p 5672:5672 \
  -p 15672:15672 \
  -e RABBITMQ_DEFAULT_USER=admin \
  -e RABBITMQ_DEFAULT_PASS=admin123 \
  rabbitmq:3.12-management

# 查看日志
docker logs -f rabbitmq
```

### 2.3.2 端口说明

| 端口 | 协议/用途 |
|------|-----------|
| 5672 | AMQP 客户端连接 |
| 15672 | 管理界面 HTTP |
| 25672 | 集群通信 |
| 4369 | epmd 端口映射 |
| 5671 | AMQP over TLS |
| 15671 | 管理界面 HTTPS |
| 61613 | STOMP |
| 1883 | MQTT |

### 2.3.3 持久化数据

```bash
# 创建数据卷
docker volume create rabbitmq_data

# 启动带持久化的容器
docker run -d \
  --name rabbitmq \
  --hostname rabbitmq-node1 \
  -p 5672:5672 \
  -p 15672:15672 \
  -v rabbitmq_data:/var/lib/rabbitmq \
  -e RABBITMQ_DEFAULT_USER=admin \
  -e RABBITMQ_DEFAULT_PASS=admin123 \
  rabbitmq:3.12-management
```

---

## 2.4 Docker Compose 安装

### docker-compose.yml

```yaml
version: '3.8'

services:
  rabbitmq:
    image: rabbitmq:3.12-management
    container_name: rabbitmq
    hostname: rabbitmq-node1
    ports:
      - "5672:5672"    # AMQP
      - "15672:15672"  # Management UI
    environment:
      RABBITMQ_DEFAULT_USER: admin
      RABBITMQ_DEFAULT_PASS: admin123
      RABBITMQ_DEFAULT_VHOST: /
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
      - rabbitmq_log:/var/log/rabbitmq
    networks:
      - rabbitmq-network
    healthcheck:
      test: rabbitmq-diagnostics -q ping
      interval: 30s
      timeout: 10s
      retries: 5
    restart: unless-stopped

volumes:
  rabbitmq_data:
  rabbitmq_log:

networks:
  rabbitmq-network:
    driver: bridge
```

### 启动命令

```bash
# 启动
docker-compose up -d

# 查看状态
docker-compose ps

# 查看日志
docker-compose logs -f rabbitmq

# 停止
docker-compose down

# 停止并删除数据
docker-compose down -v
```

---

## 2.5 Ubuntu/Debian 安装

### 2.5.1 添加官方仓库

```bash
# 安装依赖
sudo apt-get update
sudo apt-get install curl gnupg apt-transport-https -y

# 添加 RabbitMQ 签名密钥
curl -1sLf "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" | sudo gpg --dearmor | sudo tee /usr/share/keyrings/com.rabbitmq.team.gpg > /dev/null

# 添加 Erlang 仓库
curl -1sLf "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xf77f1eda57ebb1cc" | sudo gpg --dearmor | sudo tee /usr/share/keyrings/net.launchpad.ppa.rabbitmq.erlang.gpg > /dev/null

# 添加仓库源
sudo tee /etc/apt/sources.list.d/rabbitmq.list <<EOF
deb [signed-by=/usr/share/keyrings/net.launchpad.ppa.rabbitmq.erlang.gpg] http://ppa.launchpad.net/rabbitmq/rabbitmq-erlang/ubuntu jammy main
deb [signed-by=/usr/share/keyrings/com.rabbitmq.team.gpg] https://packagecloud.io/rabbitmq/rabbitmq-server/ubuntu/ jammy main
EOF
```

### 2.5.2 安装 RabbitMQ

```bash
# 更新仓库
sudo apt-get update

# 安装 Erlang
sudo apt-get install erlang-base \
  erlang-asn1 erlang-crypto erlang-eldap erlang-ftp erlang-inets \
  erlang-mnesia erlang-os-mon erlang-parsetools erlang-public-key \
  erlang-runtime-tools erlang-snmp erlang-ssl \
  erlang-syntax-tools erlang-tftp erlang-tools erlang-xmerl -y

# 安装 RabbitMQ
sudo apt-get install rabbitmq-server -y

# 启动服务
sudo systemctl enable rabbitmq-server
sudo systemctl start rabbitmq-server

# 查看状态
sudo systemctl status rabbitmq-server
```

### 2.5.3 启用管理插件

```bash
# 启用管理插件
sudo rabbitmq-plugins enable rabbitmq_management

# 创建管理员用户
sudo rabbitmqctl add_user admin admin123
sudo rabbitmqctl set_user_tags admin administrator
sudo rabbitmqctl set_permissions -p / admin ".*" ".*" ".*"

# 删除默认 guest 用户（生产环境）
sudo rabbitmqctl delete_user guest
```

---

## 2.6 CentOS/RHEL 安装

### 2.6.1 添加官方仓库

```bash
# 创建仓库文件
sudo tee /etc/yum.repos.d/rabbitmq.repo <<EOF
[rabbitmq_erlang]
name=rabbitmq_erlang
baseurl=https://packagecloud.io/rabbitmq/erlang/el/8/\$basearch
repo_gpgcheck=1
gpgcheck=1
enabled=1
gpgkey=https://packagecloud.io/rabbitmq/erlang/gpgkey
       https://github.com/rabbitmq/signing-keys/releases/download/2.0/rabbitmq-release-signing-key.asc
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300

[rabbitmq_server]
name=rabbitmq_server
baseurl=https://packagecloud.io/rabbitmq/rabbitmq-server/el/8/\$basearch
repo_gpgcheck=1
gpgcheck=1
enabled=1
gpgkey=https://packagecloud.io/rabbitmq/rabbitmq-server/gpgkey
       https://github.com/rabbitmq/signing-keys/releases/download/2.0/rabbitmq-release-signing-key.asc
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
EOF
```

### 2.6.2 安装

```bash
# 安装 Erlang
sudo yum install erlang -y

# 安装 RabbitMQ
sudo yum install rabbitmq-server -y

# 启动服务
sudo systemctl enable rabbitmq-server
sudo systemctl start rabbitmq-server

# 启用管理插件
sudo rabbitmq-plugins enable rabbitmq_management
```

---

## 2.7 macOS 安装

### 使用 Homebrew

```bash
# 安装
brew install rabbitmq

# 启动服务
brew services start rabbitmq

# 或者前台运行
rabbitmq-server

# 停止
brew services stop rabbitmq
```

### 环境变量

```bash
# 添加到 ~/.zshrc 或 ~/.bash_profile
export PATH=$PATH:/usr/local/opt/rabbitmq/sbin
```

---

## 2.8 Windows 安装

### 2.8.1 安装 Erlang

1. 下载 Erlang: https://www.erlang.org/downloads
2. 运行安装程序
3. 设置环境变量 `ERLANG_HOME`

### 2.8.2 安装 RabbitMQ

1. 下载 RabbitMQ: https://www.rabbitmq.com/install-windows.html
2. 运行安装程序
3. 启用管理插件:
```cmd
cd C:\Program Files\RabbitMQ Server\rabbitmq_server-3.12.x\sbin
rabbitmq-plugins.bat enable rabbitmq_management
```

### 2.8.3 服务管理

```cmd
# 启动
net start RabbitMQ

# 停止
net stop RabbitMQ

# 查看状态
rabbitmqctl status
```

---

## 2.9 管理界面访问

### 访问地址

- URL: `http://localhost:15672`
- 默认用户: `guest` (仅限localhost访问)
- 建议创建管理员账户

### 管理界面功能

```
┌─────────────────────────────────────────────────────────────────┐
│                    RabbitMQ Management UI                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Overview    ─── 集群概览、节点状态、消息速率                   │
│                                                                 │
│  Connections ─── 查看/关闭连接                                   │
│                                                                 │
│  Channels    ─── 查看信道状态                                    │
│                                                                 │
│  Exchanges   ─── 管理交换器                                      │
│                                                                 │
│  Queues      ─── 管理队列、查看消息                              │
│                                                                 │
│  Admin       ─── 用户管理、权限配置、策略管理                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2.10 常用命令

### rabbitmqctl 命令

```bash
# 节点状态
rabbitmqctl status

# 用户管理
rabbitmqctl list_users
rabbitmqctl add_user <username> <password>
rabbitmqctl delete_user <username>
rabbitmqctl change_password <username> <password>
rabbitmqctl set_user_tags <username> administrator

# 权限管理
rabbitmqctl list_permissions
rabbitmqctl set_permissions -p <vhost> <username> ".*" ".*" ".*"

# 队列管理
rabbitmqctl list_queues
rabbitmqctl list_queues name messages consumers
rabbitmqctl purge_queue <queue_name>
rabbitmqctl delete_queue <queue_name>

# 交换器
rabbitmqctl list_exchanges

# 绑定关系
rabbitmqctl list_bindings

# 连接和信道
rabbitmqctl list_connections
rabbitmqctl list_channels

# 虚拟主机
rabbitmqctl list_vhosts
rabbitmqctl add_vhost <vhost>
rabbitmqctl delete_vhost <vhost>
```

### rabbitmq-plugins 命令

```bash
# 列出所有插件
rabbitmq-plugins list

# 启用插件
rabbitmq-plugins enable <plugin_name>

# 禁用插件
rabbitmq-plugins disable <plugin_name>

# 常用插件
rabbitmq-plugins enable rabbitmq_management
rabbitmq-plugins enable rabbitmq_shovel
rabbitmq-plugins enable rabbitmq_federation
rabbitmq-plugins enable rabbitmq_delayed_message_exchange
```

---

## 2.11 验证安装

### Python 测试

```python
# pip install pika

import pika

# 建立连接
connection = pika.BlockingConnection(
    pika.ConnectionParameters(
        host='localhost',
        port=5672,
        credentials=pika.PlainCredentials('admin', 'admin123')
    )
)
channel = connection.channel()

# 声明队列
channel.queue_declare(queue='test_queue')

# 发送消息
channel.basic_publish(
    exchange='',
    routing_key='test_queue',
    body='Hello RabbitMQ!'
)
print("Message sent!")

connection.close()
```

### Java 测试

```java
// Maven: com.rabbitmq:amqp-client:5.18.0

import com.rabbitmq.client.*;

public class RabbitMQTest {
    public static void main(String[] args) throws Exception {
        ConnectionFactory factory = new ConnectionFactory();
        factory.setHost("localhost");
        factory.setPort(5672);
        factory.setUsername("admin");
        factory.setPassword("admin123");
        
        try (Connection connection = factory.newConnection();
             Channel channel = connection.createChannel()) {
            
            channel.queueDeclare("test_queue", false, false, false, null);
            channel.basicPublish("", "test_queue", null, "Hello RabbitMQ!".getBytes());
            System.out.println("Message sent!");
        }
    }
}
```

---

## 2.12 本章小结

本章介绍了 RabbitMQ 的基本概念和多种安装方式：

1. **RabbitMQ 架构**: Broker、Exchange、Queue、Binding
2. **推荐安装方式**: Docker / Docker Compose
3. **管理界面**: 端口 15672，可视化管理
4. **常用命令**: rabbitmqctl、rabbitmq-plugins

---

## 2.13 思考题

1. RabbitMQ 为什么选择 Erlang 语言开发？
2. Channel 和 Connection 有什么区别？为什么需要 Channel？
3. 生产环境中应该如何配置 RabbitMQ 用户权限？

---

**下一章**: [快速入门 Hello World](../03-hello-world/README.md)
