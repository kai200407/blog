---
title: "爬虫监控与告警"
description: "1. [监控指标](#1-监控指标)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 30
---

> 本文介绍如何对爬虫进行监控和告警，确保稳定运行。

---

## 目录

1. [监控指标](#1-监控指标)
2. [日志系统](#2-日志系统)
3. [性能监控](#3-性能监控)
4. [告警通知](#4-告警通知)
5. [实战应用](#5-实战应用)

---

## 1. 监控指标

### 1.1 核心指标

| 指标 | 说明 | 告警阈值 |
|------|------|----------|
| 请求成功率 | 成功请求/总请求 | < 90% |
| 响应时间 | 平均响应时间 | > 5s |
| 爬取速度 | 每分钟爬取页面数 | < 10 |
| 错误率 | 错误请求/总请求 | > 10% |
| 数据量 | 爬取的数据条数 | 异常波动 |

### 1.2 系统指标

| 指标 | 说明 |
|------|------|
| CPU 使用率 | 进程 CPU 占用 |
| 内存使用 | 进程内存占用 |
| 网络流量 | 入站/出站流量 |
| 磁盘 IO | 读写速度 |

### 1.3 业务指标

```python
from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict
import time

@dataclass
class CrawlerStats:
    """爬虫统计"""
    start_time: datetime = field(default_factory=datetime.now)
    
    # 请求统计
    total_requests: int = 0
    success_requests: int = 0
    failed_requests: int = 0
    
    # 数据统计
    items_scraped: int = 0
    items_dropped: int = 0
    
    # 性能统计
    total_response_time: float = 0.0
    
    # 错误统计
    errors: Dict[str, int] = field(default_factory=dict)
    
    @property
    def success_rate(self) -> float:
        if self.total_requests == 0:
            return 0.0
        return self.success_requests / self.total_requests * 100
    
    @property
    def avg_response_time(self) -> float:
        if self.success_requests == 0:
            return 0.0
        return self.total_response_time / self.success_requests
    
    @property
    def requests_per_minute(self) -> float:
        elapsed = (datetime.now() - self.start_time).total_seconds() / 60
        if elapsed == 0:
            return 0.0
        return self.total_requests / elapsed
    
    def record_request(self, success: bool, response_time: float):
        self.total_requests += 1
        if success:
            self.success_requests += 1
            self.total_response_time += response_time
        else:
            self.failed_requests += 1
    
    def record_error(self, error_type: str):
        self.errors[error_type] = self.errors.get(error_type, 0) + 1
    
    def to_dict(self) -> dict:
        return {
            'total_requests': self.total_requests,
            'success_rate': f"{self.success_rate:.2f}%",
            'avg_response_time': f"{self.avg_response_time:.2f}s",
            'requests_per_minute': f"{self.requests_per_minute:.2f}",
            'items_scraped': self.items_scraped,
            'errors': self.errors
        }
```

---

## 2. 日志系统

### 2.1 日志配置

```python
import logging
import logging.handlers
from datetime import datetime
import os

def setup_logging(name: str, log_dir: str = 'logs'):
    """配置日志系统"""
    os.makedirs(log_dir, exist_ok=True)
    
    logger = logging.getLogger(name)
    logger.setLevel(logging.DEBUG)
    
    # 控制台处理器
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_format = logging.Formatter(
        '%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%H:%M:%S'
    )
    console_handler.setFormatter(console_format)
    
    # 文件处理器（按日期轮转）
    log_file = os.path.join(log_dir, f'{name}.log')
    file_handler = logging.handlers.TimedRotatingFileHandler(
        log_file,
        when='midnight',
        interval=1,
        backupCount=30,
        encoding='utf-8'
    )
    file_handler.setLevel(logging.DEBUG)
    file_format = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(filename)s:%(lineno)d - %(message)s'
    )
    file_handler.setFormatter(file_format)
    
    # 错误日志处理器
    error_file = os.path.join(log_dir, f'{name}_error.log')
    error_handler = logging.handlers.RotatingFileHandler(
        error_file,
        maxBytes=10*1024*1024,  # 10MB
        backupCount=5,
        encoding='utf-8'
    )
    error_handler.setLevel(logging.ERROR)
    error_handler.setFormatter(file_format)
    
    logger.addHandler(console_handler)
    logger.addHandler(file_handler)
    logger.addHandler(error_handler)
    
    return logger

# 使用
logger = setup_logging('crawler')
logger.info("爬虫启动")
logger.error("请求失败", exc_info=True)
```

### 2.2 结构化日志

```python
import json
import logging
from datetime import datetime

class JSONFormatter(logging.Formatter):
    """JSON 格式化器"""
    
    def format(self, record):
        log_data = {
            'timestamp': datetime.utcnow().isoformat(),
            'level': record.levelname,
            'logger': record.name,
            'message': record.getMessage(),
            'module': record.module,
            'function': record.funcName,
            'line': record.lineno
        }
        
        # 添加额外字段
        if hasattr(record, 'url'):
            log_data['url'] = record.url
        if hasattr(record, 'status_code'):
            log_data['status_code'] = record.status_code
        if hasattr(record, 'response_time'):
            log_data['response_time'] = record.response_time
        
        # 异常信息
        if record.exc_info:
            log_data['exception'] = self.formatException(record.exc_info)
        
        return json.dumps(log_data, ensure_ascii=False)

# 使用
handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())

logger = logging.getLogger('crawler')
logger.addHandler(handler)

# 添加额外字段
logger.info("请求完成", extra={
    'url': 'https://example.com',
    'status_code': 200,
    'response_time': 0.5
})
```

### 2.3 日志上下文

```python
import logging
import contextvars
from functools import wraps

# 上下文变量
request_id_var = contextvars.ContextVar('request_id', default=None)

class ContextFilter(logging.Filter):
    """上下文过滤器"""
    
    def filter(self, record):
        record.request_id = request_id_var.get()
        return True

def with_request_id(func):
    """装饰器：添加请求 ID"""
    @wraps(func)
    def wrapper(*args, **kwargs):
        import uuid
        request_id = str(uuid.uuid4())[:8]
        request_id_var.set(request_id)
        return func(*args, **kwargs)
    return wrapper

# 配置
logger = logging.getLogger('crawler')
logger.addFilter(ContextFilter())

formatter = logging.Formatter(
    '%(asctime)s - [%(request_id)s] - %(levelname)s - %(message)s'
)

# 使用
@with_request_id
def crawl_page(url):
    logger.info(f"开始爬取: {url}")
    # ...
    logger.info("爬取完成")
```

---

## 3. 性能监控

### 3.1 时间统计

```python
import time
from contextlib import contextmanager
from functools import wraps

@contextmanager
def timer(name: str):
    """计时上下文管理器"""
    start = time.time()
    yield
    elapsed = time.time() - start
    print(f"{name}: {elapsed:.3f}s")

def timed(func):
    """计时装饰器"""
    @wraps(func)
    def wrapper(*args, **kwargs):
        start = time.time()
        result = func(*args, **kwargs)
        elapsed = time.time() - start
        print(f"{func.__name__}: {elapsed:.3f}s")
        return result
    return wrapper

# 使用
with timer("页面解析"):
    # 解析逻辑
    pass

@timed
def fetch_page(url):
    # 请求逻辑
    pass
```

### 3.2 资源监控

```python
import psutil
import os
from dataclasses import dataclass

@dataclass
class ResourceStats:
    """资源统计"""
    cpu_percent: float
    memory_mb: float
    memory_percent: float
    threads: int
    open_files: int

def get_resource_stats() -> ResourceStats:
    """获取资源统计"""
    process = psutil.Process(os.getpid())
    
    return ResourceStats(
        cpu_percent=process.cpu_percent(),
        memory_mb=process.memory_info().rss / 1024 / 1024,
        memory_percent=process.memory_percent(),
        threads=process.num_threads(),
        open_files=len(process.open_files())
    )

class ResourceMonitor:
    """资源监控器"""
    
    def __init__(self, interval: int = 60):
        self.interval = interval
        self.running = False
    
    def start(self):
        """启动监控"""
        import threading
        
        self.running = True
        
        def monitor():
            while self.running:
                stats = get_resource_stats()
                print(f"CPU: {stats.cpu_percent}%, "
                      f"内存: {stats.memory_mb:.1f}MB ({stats.memory_percent:.1f}%), "
                      f"线程: {stats.threads}")
                time.sleep(self.interval)
        
        thread = threading.Thread(target=monitor, daemon=True)
        thread.start()
    
    def stop(self):
        """停止监控"""
        self.running = False

# 使用
monitor = ResourceMonitor(interval=30)
monitor.start()
```

### 3.3 Prometheus 指标

```python
from prometheus_client import Counter, Histogram, Gauge, start_http_server

# 定义指标
REQUEST_COUNT = Counter(
    'crawler_requests_total',
    'Total number of requests',
    ['status', 'domain']
)

REQUEST_LATENCY = Histogram(
    'crawler_request_latency_seconds',
    'Request latency in seconds',
    ['domain'],
    buckets=[0.1, 0.5, 1.0, 2.0, 5.0, 10.0]
)

ITEMS_SCRAPED = Counter(
    'crawler_items_scraped_total',
    'Total number of items scraped',
    ['spider']
)

ACTIVE_REQUESTS = Gauge(
    'crawler_active_requests',
    'Number of active requests'
)

class PrometheusMonitor:
    """Prometheus 监控"""
    
    def __init__(self, port: int = 8000):
        self.port = port
    
    def start(self):
        """启动指标服务器"""
        start_http_server(self.port)
        print(f"Prometheus 指标服务: http://localhost:{self.port}")
    
    def record_request(self, domain: str, status: str, latency: float):
        """记录请求"""
        REQUEST_COUNT.labels(status=status, domain=domain).inc()
        REQUEST_LATENCY.labels(domain=domain).observe(latency)
    
    def record_item(self, spider: str):
        """记录数据项"""
        ITEMS_SCRAPED.labels(spider=spider).inc()
    
    def set_active_requests(self, count: int):
        """设置活跃请求数"""
        ACTIVE_REQUESTS.set(count)

# 使用
monitor = PrometheusMonitor(port=8000)
monitor.start()

# 记录指标
monitor.record_request('example.com', 'success', 0.5)
monitor.record_item('news_spider')
```

---

## 4. 告警通知

### 4.1 告警规则

```python
from dataclasses import dataclass
from typing import Callable, List
from enum import Enum

class AlertLevel(Enum):
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"
    CRITICAL = "critical"

@dataclass
class AlertRule:
    """告警规则"""
    name: str
    condition: Callable[[], bool]
    level: AlertLevel
    message: str
    cooldown: int = 300  # 冷却时间（秒）

class AlertManager:
    """告警管理器"""
    
    def __init__(self):
        self.rules: List[AlertRule] = []
        self.last_alert = {}  # 上次告警时间
        self.handlers = []
    
    def add_rule(self, rule: AlertRule):
        """添加规则"""
        self.rules.append(rule)
    
    def add_handler(self, handler: Callable):
        """添加处理器"""
        self.handlers.append(handler)
    
    def check(self, stats: dict):
        """检查告警"""
        import time
        
        for rule in self.rules:
            try:
                if rule.condition(stats):
                    # 检查冷却
                    last = self.last_alert.get(rule.name, 0)
                    if time.time() - last < rule.cooldown:
                        continue
                    
                    # 触发告警
                    self.last_alert[rule.name] = time.time()
                    self._trigger(rule, stats)
            except Exception as e:
                print(f"规则检查失败 {rule.name}: {e}")
    
    def _trigger(self, rule: AlertRule, stats: dict):
        """触发告警"""
        alert = {
            'name': rule.name,
            'level': rule.level.value,
            'message': rule.message,
            'stats': stats
        }
        
        for handler in self.handlers:
            try:
                handler(alert)
            except Exception as e:
                print(f"告警处理失败: {e}")

# 使用
manager = AlertManager()

# 添加规则
manager.add_rule(AlertRule(
    name='low_success_rate',
    condition=lambda s: s.get('success_rate', 100) < 90,
    level=AlertLevel.WARNING,
    message='成功率低于 90%'
))

manager.add_rule(AlertRule(
    name='high_error_rate',
    condition=lambda s: s.get('error_rate', 0) > 10,
    level=AlertLevel.ERROR,
    message='错误率超过 10%'
))

# 添加处理器
manager.add_handler(lambda a: print(f"[{a['level']}] {a['message']}"))
```

### 4.2 通知渠道

```python
import requests
import smtplib
from email.mime.text import MIMEText
from abc import ABC, abstractmethod

class NotificationChannel(ABC):
    """通知渠道基类"""
    
    @abstractmethod
    def send(self, title: str, message: str, level: str):
        pass

class EmailNotifier(NotificationChannel):
    """邮件通知"""
    
    def __init__(self, smtp_host, smtp_port, username, password, recipients):
        self.smtp_host = smtp_host
        self.smtp_port = smtp_port
        self.username = username
        self.password = password
        self.recipients = recipients
    
    def send(self, title: str, message: str, level: str):
        msg = MIMEText(message, 'plain', 'utf-8')
        msg['Subject'] = f"[{level.upper()}] {title}"
        msg['From'] = self.username
        msg['To'] = ', '.join(self.recipients)
        
        with smtplib.SMTP(self.smtp_host, self.smtp_port) as server:
            server.starttls()
            server.login(self.username, self.password)
            server.send_message(msg)

class DingTalkNotifier(NotificationChannel):
    """钉钉通知"""
    
    def __init__(self, webhook_url):
        self.webhook_url = webhook_url
    
    def send(self, title: str, message: str, level: str):
        data = {
            "msgtype": "markdown",
            "markdown": {
                "title": title,
                "text": f"## {title}\n\n**级别**: {level}\n\n{message}"
            }
        }
        
        requests.post(self.webhook_url, json=data)

class SlackNotifier(NotificationChannel):
    """Slack 通知"""
    
    def __init__(self, webhook_url):
        self.webhook_url = webhook_url
    
    def send(self, title: str, message: str, level: str):
        color = {
            'info': '#36a64f',
            'warning': '#ffcc00',
            'error': '#ff0000',
            'critical': '#8b0000'
        }.get(level, '#808080')
        
        data = {
            "attachments": [{
                "color": color,
                "title": title,
                "text": message,
                "fields": [
                    {"title": "Level", "value": level, "short": True}
                ]
            }]
        }
        
        requests.post(self.webhook_url, json=data)

class TelegramNotifier(NotificationChannel):
    """Telegram 通知"""
    
    def __init__(self, bot_token, chat_id):
        self.bot_token = bot_token
        self.chat_id = chat_id
    
    def send(self, title: str, message: str, level: str):
        text = f"*{title}*\n\n级别: {level}\n\n{message}"
        
        url = f"https://api.telegram.org/bot{self.bot_token}/sendMessage"
        data = {
            "chat_id": self.chat_id,
            "text": text,
            "parse_mode": "Markdown"
        }
        
        requests.post(url, json=data)
```

### 4.3 告警聚合

```python
from collections import defaultdict
from datetime import datetime, timedelta
import threading

class AlertAggregator:
    """告警聚合器"""
    
    def __init__(self, window: int = 300, threshold: int = 5):
        self.window = window  # 时间窗口（秒）
        self.threshold = threshold  # 聚合阈值
        self.alerts = defaultdict(list)
        self.lock = threading.Lock()
    
    def add(self, alert_type: str, message: str) -> bool:
        """
        添加告警
        返回: 是否应该发送
        """
        now = datetime.now()
        
        with self.lock:
            # 清理过期告警
            cutoff = now - timedelta(seconds=self.window)
            self.alerts[alert_type] = [
                (t, m) for t, m in self.alerts[alert_type]
                if t > cutoff
            ]
            
            # 添加新告警
            self.alerts[alert_type].append((now, message))
            
            # 检查是否达到阈值
            count = len(self.alerts[alert_type])
            
            if count == 1:
                # 第一条，立即发送
                return True
            elif count == self.threshold:
                # 达到阈值，发送聚合告警
                return True
            
            return False
    
    def get_summary(self, alert_type: str) -> str:
        """获取告警摘要"""
        with self.lock:
            alerts = self.alerts.get(alert_type, [])
            if not alerts:
                return ""
            
            count = len(alerts)
            first_time = alerts[0][0].strftime('%H:%M:%S')
            last_time = alerts[-1][0].strftime('%H:%M:%S')
            
            return f"在 {first_time} - {last_time} 期间发生 {count} 次告警"

# 使用
aggregator = AlertAggregator(window=300, threshold=5)

if aggregator.add('request_error', '请求失败'):
    summary = aggregator.get_summary('request_error')
    # 发送告警
```

---

## 5. 实战应用

### 5.1 完整监控系统

```python
import time
import threading
import logging
from dataclasses import dataclass, field
from datetime import datetime
from typing import List, Dict, Callable

logger = logging.getLogger(__name__)

@dataclass
class CrawlerMetrics:
    """爬虫指标"""
    requests_total: int = 0
    requests_success: int = 0
    requests_failed: int = 0
    items_scraped: int = 0
    response_time_sum: float = 0.0
    errors: Dict[str, int] = field(default_factory=dict)
    start_time: datetime = field(default_factory=datetime.now)
    
    @property
    def success_rate(self) -> float:
        if self.requests_total == 0:
            return 100.0
        return self.requests_success / self.requests_total * 100
    
    @property
    def avg_response_time(self) -> float:
        if self.requests_success == 0:
            return 0.0
        return self.response_time_sum / self.requests_success
    
    @property
    def error_rate(self) -> float:
        if self.requests_total == 0:
            return 0.0
        return self.requests_failed / self.requests_total * 100
    
    @property
    def rpm(self) -> float:
        elapsed = (datetime.now() - self.start_time).total_seconds() / 60
        if elapsed == 0:
            return 0.0
        return self.requests_total / elapsed

class CrawlerMonitor:
    """爬虫监控器"""
    
    def __init__(self):
        self.metrics = CrawlerMetrics()
        self.lock = threading.Lock()
        self.alert_handlers: List[Callable] = []
        self.running = False
    
    def record_request(self, success: bool, response_time: float = 0):
        """记录请求"""
        with self.lock:
            self.metrics.requests_total += 1
            if success:
                self.metrics.requests_success += 1
                self.metrics.response_time_sum += response_time
            else:
                self.metrics.requests_failed += 1
    
    def record_item(self, count: int = 1):
        """记录数据项"""
        with self.lock:
            self.metrics.items_scraped += count
    
    def record_error(self, error_type: str):
        """记录错误"""
        with self.lock:
            self.metrics.errors[error_type] = \
                self.metrics.errors.get(error_type, 0) + 1
    
    def add_alert_handler(self, handler: Callable):
        """添加告警处理器"""
        self.alert_handlers.append(handler)
    
    def get_stats(self) -> dict:
        """获取统计"""
        with self.lock:
            return {
                'requests_total': self.metrics.requests_total,
                'success_rate': f"{self.metrics.success_rate:.2f}%",
                'error_rate': f"{self.metrics.error_rate:.2f}%",
                'avg_response_time': f"{self.metrics.avg_response_time:.3f}s",
                'rpm': f"{self.metrics.rpm:.2f}",
                'items_scraped': self.metrics.items_scraped,
                'errors': dict(self.metrics.errors)
            }
    
    def check_alerts(self):
        """检查告警"""
        alerts = []
        
        if self.metrics.success_rate < 90:
            alerts.append({
                'level': 'warning',
                'message': f"成功率低: {self.metrics.success_rate:.2f}%"
            })
        
        if self.metrics.error_rate > 10:
            alerts.append({
                'level': 'error',
                'message': f"错误率高: {self.metrics.error_rate:.2f}%"
            })
        
        if self.metrics.avg_response_time > 5:
            alerts.append({
                'level': 'warning',
                'message': f"响应慢: {self.metrics.avg_response_time:.2f}s"
            })
        
        for alert in alerts:
            for handler in self.alert_handlers:
                try:
                    handler(alert)
                except Exception as e:
                    logger.error(f"告警处理失败: {e}")
    
    def start_background_check(self, interval: int = 60):
        """启动后台检查"""
        self.running = True
        
        def check_loop():
            while self.running:
                self.check_alerts()
                time.sleep(interval)
        
        thread = threading.Thread(target=check_loop, daemon=True)
        thread.start()
    
    def stop(self):
        """停止监控"""
        self.running = False
    
    def print_stats(self):
        """打印统计"""
        stats = self.get_stats()
        print("\n=== 爬虫统计 ===")
        for key, value in stats.items():
            print(f"{key}: {value}")

# 使用示例
monitor = CrawlerMonitor()

# 添加告警处理
monitor.add_alert_handler(
    lambda a: print(f"[{a['level']}] {a['message']}")
)

# 启动后台检查
monitor.start_background_check(interval=60)

# 模拟爬取
for i in range(100):
    success = i % 10 != 0  # 90% 成功率
    monitor.record_request(success, response_time=0.5)
    if success:
        monitor.record_item()
    else:
        monitor.record_error('timeout')

# 打印统计
monitor.print_stats()
```

---

## 下一步

下一篇我们将学习爬虫部署与运维。

---

## 参考资料

- [Prometheus Python Client](https://github.com/prometheus/client_python)
- [Python Logging](https://docs.python.org/3/library/logging.html)
- [psutil](https://psutil.readthedocs.io/)
