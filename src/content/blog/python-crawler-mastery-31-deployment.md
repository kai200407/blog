---
title: "爬虫部署与运维"
description: "1. [部署方式](#1-部署方式)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 31
---

> 本文介绍如何部署和运维爬虫项目。

---

## 目录

1. [部署方式](#1-部署方式)
2. [Docker 部署](#2-docker-部署)
3. [定时任务](#3-定时任务)
4. [进程管理](#4-进程管理)
5. [运维实践](#5-运维实践)

---

## 1. 部署方式

### 1.1 部署选项

| 方式 | 优点 | 缺点 | 适用场景 |
|------|------|------|----------|
| 直接运行 | 简单 | 不稳定 | 开发测试 |
| Supervisor | 进程管理 | 单机 | 小型项目 |
| Docker | 隔离、可移植 | 学习成本 | 中型项目 |
| Kubernetes | 弹性伸缩 | 复杂 | 大型项目 |
| Serverless | 按需付费 | 限制多 | 轻量任务 |

### 1.2 环境准备

```bash
# 创建虚拟环境
python -m venv venv
source venv/bin/activate

# 安装依赖
pip install -r requirements.txt

# 导出依赖
pip freeze > requirements.txt
```

### 1.3 配置管理

```python
# config.py
import os
from dataclasses import dataclass

@dataclass
class Config:
    """配置类"""
    # 数据库
    MONGO_URI: str = os.getenv('MONGO_URI', 'mongodb://localhost:27017')
    REDIS_URL: str = os.getenv('REDIS_URL', 'redis://localhost:6379')
    
    # 爬虫设置
    CONCURRENT_REQUESTS: int = int(os.getenv('CONCURRENT_REQUESTS', '16'))
    DOWNLOAD_DELAY: float = float(os.getenv('DOWNLOAD_DELAY', '0.5'))
    
    # 代理
    PROXY_URL: str = os.getenv('PROXY_URL', '')
    
    # 日志
    LOG_LEVEL: str = os.getenv('LOG_LEVEL', 'INFO')
    LOG_FILE: str = os.getenv('LOG_FILE', 'crawler.log')

config = Config()
```

---

## 2. Docker 部署

### 2.1 Dockerfile

```dockerfile
# Dockerfile
FROM python:3.11-slim

# 设置工作目录
WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    gcc \
    libxml2-dev \
    libxslt-dev \
    && rm -rf /var/lib/apt/lists/*

# 复制依赖文件
COPY requirements.txt .

# 安装 Python 依赖
RUN pip install --no-cache-dir -r requirements.txt

# 复制项目文件
COPY . .

# 设置环境变量
ENV PYTHONUNBUFFERED=1
ENV LOG_LEVEL=INFO

# 运行爬虫
CMD ["python", "main.py"]
```

### 2.2 Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  crawler:
    build: .
    container_name: crawler
    restart: unless-stopped
    environment:
      - MONGO_URI=mongodb://mongo:27017
      - REDIS_URL=redis://redis:6379
      - LOG_LEVEL=INFO
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
    depends_on:
      - mongo
      - redis
    networks:
      - crawler-network

  mongo:
    image: mongo:6
    container_name: crawler-mongo
    restart: unless-stopped
    volumes:
      - mongo-data:/data/db
    networks:
      - crawler-network

  redis:
    image: redis:7-alpine
    container_name: crawler-redis
    restart: unless-stopped
    volumes:
      - redis-data:/data
    networks:
      - crawler-network

  # 可选：监控
  prometheus:
    image: prom/prometheus
    container_name: crawler-prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"
    networks:
      - crawler-network

volumes:
  mongo-data:
  redis-data:

networks:
  crawler-network:
    driver: bridge
```

### 2.3 Playwright Docker

```dockerfile
# Dockerfile.playwright
FROM mcr.microsoft.com/playwright/python:v1.40.0-jammy

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["python", "main.py"]
```

### 2.4 Docker 命令

```bash
# 构建镜像
docker build -t crawler:latest .

# 运行容器
docker run -d --name crawler \
    -e MONGO_URI=mongodb://host.docker.internal:27017 \
    -v $(pwd)/data:/app/data \
    crawler:latest

# 查看日志
docker logs -f crawler

# 进入容器
docker exec -it crawler bash

# Docker Compose
docker-compose up -d
docker-compose logs -f crawler
docker-compose down
```

---

## 3. 定时任务

### 3.1 Cron

```bash
# 编辑 crontab
crontab -e

# 每小时执行
0 * * * * cd /path/to/crawler && /path/to/venv/bin/python main.py >> /var/log/crawler.log 2>&1

# 每天凌晨 2 点执行
0 2 * * * cd /path/to/crawler && /path/to/venv/bin/python main.py

# 每 30 分钟执行
*/30 * * * * cd /path/to/crawler && /path/to/venv/bin/python main.py
```

### 3.2 APScheduler

```python
from apscheduler.schedulers.blocking import BlockingScheduler
from apscheduler.triggers.cron import CronTrigger
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def run_crawler():
    """运行爬虫"""
    logger.info("开始爬取...")
    # 爬虫逻辑
    logger.info("爬取完成")

def main():
    scheduler = BlockingScheduler()
    
    # 每小时执行
    scheduler.add_job(
        run_crawler,
        CronTrigger(minute=0),
        id='hourly_crawl',
        name='每小时爬取'
    )
    
    # 每天凌晨 2 点执行
    scheduler.add_job(
        run_crawler,
        CronTrigger(hour=2, minute=0),
        id='daily_crawl',
        name='每日爬取'
    )
    
    # 每 30 分钟执行
    scheduler.add_job(
        run_crawler,
        'interval',
        minutes=30,
        id='interval_crawl',
        name='间隔爬取'
    )
    
    logger.info("调度器启动")
    scheduler.start()

if __name__ == '__main__':
    main()
```

### 3.3 Celery

```python
# tasks.py
from celery import Celery
from celery.schedules import crontab

app = Celery('crawler')

app.conf.update(
    broker_url='redis://localhost:6379/0',
    result_backend='redis://localhost:6379/0',
    timezone='Asia/Shanghai',
)

# 定时任务配置
app.conf.beat_schedule = {
    'crawl-every-hour': {
        'task': 'tasks.crawl_task',
        'schedule': crontab(minute=0),
    },
    'crawl-daily': {
        'task': 'tasks.crawl_task',
        'schedule': crontab(hour=2, minute=0),
    },
}

@app.task
def crawl_task():
    """爬虫任务"""
    print("开始爬取...")
    # 爬虫逻辑
    return "完成"

@app.task
def crawl_url(url):
    """爬取单个 URL"""
    print(f"爬取: {url}")
    # 爬取逻辑
    return f"完成: {url}"
```

```bash
# 启动 Worker
celery -A tasks worker --loglevel=info

# 启动 Beat（定时任务）
celery -A tasks beat --loglevel=info

# 同时启动
celery -A tasks worker --beat --loglevel=info
```

---

## 4. 进程管理

### 4.1 Supervisor

```ini
; /etc/supervisor/conf.d/crawler.conf

[program:crawler]
command=/path/to/venv/bin/python /path/to/crawler/main.py
directory=/path/to/crawler
user=www-data
autostart=true
autorestart=true
startsecs=10
startretries=3
stopwaitsecs=10
redirect_stderr=true
stdout_logfile=/var/log/crawler/crawler.log
stdout_logfile_maxbytes=50MB
stdout_logfile_backups=10
environment=
    MONGO_URI="mongodb://localhost:27017",
    REDIS_URL="redis://localhost:6379",
    LOG_LEVEL="INFO"

[program:crawler-worker]
command=/path/to/venv/bin/celery -A tasks worker --loglevel=info
directory=/path/to/crawler
user=www-data
autostart=true
autorestart=true
numprocs=2
process_name=%(program_name)s_%(process_num)02d
redirect_stderr=true
stdout_logfile=/var/log/crawler/worker.log
```

```bash
# 更新配置
sudo supervisorctl reread
sudo supervisorctl update

# 管理进程
sudo supervisorctl start crawler
sudo supervisorctl stop crawler
sudo supervisorctl restart crawler
sudo supervisorctl status
```

### 4.2 Systemd

```ini
# /etc/systemd/system/crawler.service

[Unit]
Description=Web Crawler Service
After=network.target mongodb.service redis.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/path/to/crawler
Environment=MONGO_URI=mongodb://localhost:27017
Environment=REDIS_URL=redis://localhost:6379
ExecStart=/path/to/venv/bin/python main.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
# 重载配置
sudo systemctl daemon-reload

# 管理服务
sudo systemctl start crawler
sudo systemctl stop crawler
sudo systemctl restart crawler
sudo systemctl status crawler
sudo systemctl enable crawler  # 开机自启
```

### 4.3 PM2 (Node.js 生态)

```bash
# 安装 PM2
npm install -g pm2

# 启动爬虫
pm2 start main.py --interpreter python3 --name crawler

# 管理进程
pm2 list
pm2 logs crawler
pm2 restart crawler
pm2 stop crawler
pm2 delete crawler

# 保存配置
pm2 save
pm2 startup  # 开机自启
```

---

## 5. 运维实践

### 5.1 健康检查

```python
# health.py
from flask import Flask, jsonify
import psutil
import os

app = Flask(__name__)

@app.route('/health')
def health():
    """健康检查"""
    return jsonify({
        'status': 'healthy',
        'pid': os.getpid()
    })

@app.route('/metrics')
def metrics():
    """指标"""
    process = psutil.Process(os.getpid())
    
    return jsonify({
        'cpu_percent': process.cpu_percent(),
        'memory_mb': process.memory_info().rss / 1024 / 1024,
        'threads': process.num_threads(),
        'open_files': len(process.open_files())
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

### 5.2 日志轮转

```python
# logrotate 配置
# /etc/logrotate.d/crawler

/var/log/crawler/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 www-data www-data
    postrotate
        supervisorctl restart crawler > /dev/null 2>&1 || true
    endscript
}
```

### 5.3 备份策略

```bash
#!/bin/bash
# backup.sh

DATE=$(date +%Y%m%d)
BACKUP_DIR=/backup/crawler

# 创建备份目录
mkdir -p $BACKUP_DIR

# 备份 MongoDB
mongodump --uri="mongodb://localhost:27017" --out=$BACKUP_DIR/mongo_$DATE

# 备份 Redis
redis-cli BGSAVE
cp /var/lib/redis/dump.rdb $BACKUP_DIR/redis_$DATE.rdb

# 备份配置
tar -czf $BACKUP_DIR/config_$DATE.tar.gz /path/to/crawler/config

# 清理 30 天前的备份
find $BACKUP_DIR -mtime +30 -delete

echo "备份完成: $DATE"
```

### 5.4 完整部署脚本

```bash
#!/bin/bash
# deploy.sh

set -e

PROJECT_DIR=/opt/crawler
VENV_DIR=$PROJECT_DIR/venv
REPO_URL=https://github.com/user/crawler.git

echo "=== 开始部署 ==="

# 拉取代码
if [ -d "$PROJECT_DIR" ]; then
    cd $PROJECT_DIR
    git pull
else
    git clone $REPO_URL $PROJECT_DIR
    cd $PROJECT_DIR
fi

# 创建虚拟环境
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv $VENV_DIR
fi

# 激活虚拟环境
source $VENV_DIR/bin/activate

# 安装依赖
pip install -r requirements.txt

# 运行迁移（如果有）
# python manage.py migrate

# 重启服务
sudo supervisorctl restart crawler

echo "=== 部署完成 ==="
```

---

## 下一步

恭喜！您已完成 Python 爬虫专栏的学习。

---

## 参考资料

- [Docker 文档](https://docs.docker.com/)
- [Supervisor 文档](http://supervisord.org/)
- [Celery 文档](https://docs.celeryproject.org/)
- [APScheduler 文档](https://apscheduler.readthedocs.io/)
