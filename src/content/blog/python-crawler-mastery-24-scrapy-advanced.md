---
title: "Scrapy 进阶"
description: "1. [中间件](#1-中间件)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 24
---

> 本文介绍 Scrapy 的高级特性，包括中间件、扩展和分布式爬取。

---

## 目录

1. [中间件](#1-中间件)
2. [扩展](#2-扩展)
3. [信号](#3-信号)
4. [分布式爬取](#4-分布式爬取)
5. [性能优化](#5-性能优化)

---

## 1. 中间件

### 1.1 下载器中间件

```python
# middlewares.py
import random
from scrapy import signals

class RandomUserAgentMiddleware:
    """随机 User-Agent 中间件"""
    
    USER_AGENTS = [
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36...',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36...',
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36...',
    ]
    
    def process_request(self, request, spider):
        request.headers['User-Agent'] = random.choice(self.USER_AGENTS)

class RetryMiddleware:
    """自定义重试中间件"""
    
    def __init__(self, max_retry=3):
        self.max_retry = max_retry
    
    @classmethod
    def from_crawler(cls, crawler):
        return cls(
            max_retry=crawler.settings.getint('MAX_RETRY', 3)
        )
    
    def process_response(self, request, response, spider):
        if response.status in [500, 502, 503, 504]:
            retry_times = request.meta.get('retry_times', 0)
            
            if retry_times < self.max_retry:
                spider.logger.warning(f"重试 {request.url} (第 {retry_times + 1} 次)")
                
                new_request = request.copy()
                new_request.meta['retry_times'] = retry_times + 1
                new_request.dont_filter = True
                
                return new_request
        
        return response
    
    def process_exception(self, request, exception, spider):
        retry_times = request.meta.get('retry_times', 0)
        
        if retry_times < self.max_retry:
            spider.logger.warning(f"异常重试 {request.url}: {exception}")
            
            new_request = request.copy()
            new_request.meta['retry_times'] = retry_times + 1
            new_request.dont_filter = True
            
            return new_request

class ProxyMiddleware:
    """代理中间件"""
    
    def __init__(self, proxy_url):
        self.proxy_url = proxy_url
    
    @classmethod
    def from_crawler(cls, crawler):
        return cls(
            proxy_url=crawler.settings.get('PROXY_URL')
        )
    
    def process_request(self, request, spider):
        if self.proxy_url:
            request.meta['proxy'] = self.proxy_url
```

### 1.2 Spider 中间件

```python
class DepthMiddleware:
    """深度控制中间件"""
    
    def __init__(self, max_depth):
        self.max_depth = max_depth
    
    @classmethod
    def from_crawler(cls, crawler):
        return cls(
            max_depth=crawler.settings.getint('MAX_DEPTH', 3)
        )
    
    def process_spider_output(self, response, result, spider):
        depth = response.meta.get('depth', 0)
        
        for item in result:
            if hasattr(item, 'meta'):
                # 是 Request
                if depth < self.max_depth:
                    item.meta['depth'] = depth + 1
                    yield item
                else:
                    spider.logger.debug(f"超过最大深度: {item.url}")
            else:
                # 是 Item
                yield item

class FilterMiddleware:
    """过滤中间件"""
    
    def process_spider_output(self, response, result, spider):
        for item in result:
            if hasattr(item, 'meta'):
                # 过滤特定 URL
                if self.should_filter(item.url):
                    continue
            yield item
    
    def should_filter(self, url):
        # 过滤逻辑
        return 'logout' in url or 'login' in url
```

### 1.3 启用中间件

```python
# settings.py

DOWNLOADER_MIDDLEWARES = {
    'scrapy.downloadermiddlewares.useragent.UserAgentMiddleware': None,  # 禁用默认
    'myproject.middlewares.RandomUserAgentMiddleware': 400,
    'myproject.middlewares.ProxyMiddleware': 410,
    'myproject.middlewares.RetryMiddleware': 550,
}

SPIDER_MIDDLEWARES = {
    'myproject.middlewares.DepthMiddleware': 100,
    'myproject.middlewares.FilterMiddleware': 200,
}
```

---

## 2. 扩展

### 2.1 自定义扩展

```python
# extensions.py
from scrapy import signals
from scrapy.exceptions import NotConfigured
import logging

class StatsLoggerExtension:
    """统计日志扩展"""
    
    def __init__(self, stats, interval):
        self.stats = stats
        self.interval = interval
        self.logger = logging.getLogger(__name__)
    
    @classmethod
    def from_crawler(cls, crawler):
        if not crawler.settings.getbool('STATS_LOGGER_ENABLED', True):
            raise NotConfigured
        
        ext = cls(
            stats=crawler.stats,
            interval=crawler.settings.getint('STATS_LOGGER_INTERVAL', 60)
        )
        
        crawler.signals.connect(ext.spider_opened, signal=signals.spider_opened)
        crawler.signals.connect(ext.spider_closed, signal=signals.spider_closed)
        crawler.signals.connect(ext.item_scraped, signal=signals.item_scraped)
        
        return ext
    
    def spider_opened(self, spider):
        self.logger.info(f"Spider {spider.name} 已启动")
    
    def spider_closed(self, spider, reason):
        stats = self.stats.get_stats()
        self.logger.info(f"Spider {spider.name} 已关闭: {reason}")
        self.logger.info(f"统计: {stats}")
    
    def item_scraped(self, item, spider):
        count = self.stats.get_value('item_scraped_count', 0)
        if count % 100 == 0:
            self.logger.info(f"已爬取 {count} 个项目")

class MemoryDebugExtension:
    """内存调试扩展"""
    
    def __init__(self, stats):
        self.stats = stats
    
    @classmethod
    def from_crawler(cls, crawler):
        ext = cls(crawler.stats)
        crawler.signals.connect(ext.response_received, signal=signals.response_received)
        return ext
    
    def response_received(self, response, request, spider):
        import tracemalloc
        
        if not hasattr(self, 'started'):
            tracemalloc.start()
            self.started = True
        
        current, peak = tracemalloc.get_traced_memory()
        self.stats.set_value('memory/current', current / 1024 / 1024)
        self.stats.set_value('memory/peak', peak / 1024 / 1024)
```

### 2.2 启用扩展

```python
# settings.py

EXTENSIONS = {
    'myproject.extensions.StatsLoggerExtension': 500,
    'myproject.extensions.MemoryDebugExtension': 600,
}

STATS_LOGGER_ENABLED = True
STATS_LOGGER_INTERVAL = 60
```

---

## 3. 信号

### 3.1 常用信号

```python
from scrapy import signals

class SignalHandler:
    
    @classmethod
    def from_crawler(cls, crawler):
        ext = cls()
        
        # 引擎信号
        crawler.signals.connect(ext.engine_started, signal=signals.engine_started)
        crawler.signals.connect(ext.engine_stopped, signal=signals.engine_stopped)
        
        # Spider 信号
        crawler.signals.connect(ext.spider_opened, signal=signals.spider_opened)
        crawler.signals.connect(ext.spider_closed, signal=signals.spider_closed)
        crawler.signals.connect(ext.spider_idle, signal=signals.spider_idle)
        crawler.signals.connect(ext.spider_error, signal=signals.spider_error)
        
        # 请求/响应信号
        crawler.signals.connect(ext.request_scheduled, signal=signals.request_scheduled)
        crawler.signals.connect(ext.request_dropped, signal=signals.request_dropped)
        crawler.signals.connect(ext.response_received, signal=signals.response_received)
        crawler.signals.connect(ext.response_downloaded, signal=signals.response_downloaded)
        
        # Item 信号
        crawler.signals.connect(ext.item_scraped, signal=signals.item_scraped)
        crawler.signals.connect(ext.item_dropped, signal=signals.item_dropped)
        crawler.signals.connect(ext.item_error, signal=signals.item_error)
        
        return ext
    
    def engine_started(self):
        print("引擎启动")
    
    def engine_stopped(self):
        print("引擎停止")
    
    def spider_opened(self, spider):
        print(f"Spider {spider.name} 打开")
    
    def spider_closed(self, spider, reason):
        print(f"Spider {spider.name} 关闭: {reason}")
    
    def item_scraped(self, item, response, spider):
        print(f"Item 爬取: {item}")
    
    def response_received(self, response, request, spider):
        print(f"响应: {response.status} {response.url}")
```

### 3.2 自定义信号

```python
from scrapy import signals
from scrapy.signalmanager import SignalManager

# 定义信号
my_signal = object()

class MyExtension:
    
    @classmethod
    def from_crawler(cls, crawler):
        ext = cls()
        ext.crawler = crawler
        
        # 连接自定义信号
        crawler.signals.connect(ext.on_my_signal, signal=my_signal)
        
        return ext
    
    def on_my_signal(self, data):
        print(f"收到信号: {data}")
    
    def send_signal(self, data):
        # 发送信号
        self.crawler.signals.send_catch_log(my_signal, data=data)
```

---

## 4. 分布式爬取

### 4.1 Scrapy-Redis

```bash
pip install scrapy-redis
```

```python
# settings.py

# 使用 Redis 调度器
SCHEDULER = "scrapy_redis.scheduler.Scheduler"

# 使用 Redis 去重
DUPEFILTER_CLASS = "scrapy_redis.dupefilter.RFPDupeFilter"

# 持久化（不清空 Redis）
SCHEDULER_PERSIST = True

# Redis 连接
REDIS_URL = 'redis://localhost:6379'
# 或
REDIS_HOST = 'localhost'
REDIS_PORT = 6379

# 管道
ITEM_PIPELINES = {
    'scrapy_redis.pipelines.RedisPipeline': 300,
}
```

### 4.2 Redis Spider

```python
from scrapy_redis.spiders import RedisSpider

class MyRedisSpider(RedisSpider):
    name = 'myredis'
    redis_key = 'myspider:start_urls'
    
    def parse(self, response):
        # 解析逻辑
        yield {
            'url': response.url,
            'title': response.css('title::text').get()
        }
        
        # 跟踪链接
        for href in response.css('a::attr(href)').getall():
            yield response.follow(href, callback=self.parse)
```

### 4.3 添加起始 URL

```python
import redis

r = redis.Redis(host='localhost', port=6379)

# 添加起始 URL
r.lpush('myspider:start_urls', 'https://example.com')
r.lpush('myspider:start_urls', 'https://example.org')

# 查看队列
print(r.llen('myspider:start_urls'))
```

### 4.4 分布式部署

```yaml
# docker-compose.yml
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  spider:
    build: .
    depends_on:
      - redis
    environment:
      - REDIS_URL=redis://redis:6379
    deploy:
      replicas: 5
    command: scrapy crawl myredis
```

---

## 5. 性能优化

### 5.1 并发设置

```python
# settings.py

# 全局并发
CONCURRENT_REQUESTS = 32

# 每个域名并发
CONCURRENT_REQUESTS_PER_DOMAIN = 16

# 每个 IP 并发
CONCURRENT_REQUESTS_PER_IP = 16

# 下载延迟
DOWNLOAD_DELAY = 0.5

# 随机延迟
RANDOMIZE_DOWNLOAD_DELAY = True

# 自动限速
AUTOTHROTTLE_ENABLED = True
AUTOTHROTTLE_START_DELAY = 1
AUTOTHROTTLE_MAX_DELAY = 10
AUTOTHROTTLE_TARGET_CONCURRENCY = 8.0
```

### 5.2 内存优化

```python
# settings.py

# 禁用 Telnet
TELNETCONSOLE_ENABLED = False

# 限制响应大小
DOWNLOAD_MAXSIZE = 10 * 1024 * 1024  # 10MB

# 禁用 cookies（如果不需要）
COOKIES_ENABLED = False

# 禁用重定向（如果不需要）
REDIRECT_ENABLED = False

# 限制深度
DEPTH_LIMIT = 5

# 关闭日志
LOG_ENABLED = False
# 或降低日志级别
LOG_LEVEL = 'WARNING'
```

### 5.3 请求优化

```python
# settings.py

# DNS 缓存
DNSCACHE_ENABLED = True
DNSCACHE_SIZE = 10000

# 连接池
REACTOR_THREADPOOL_MAXSIZE = 20

# 超时设置
DOWNLOAD_TIMEOUT = 30

# 重试设置
RETRY_ENABLED = True
RETRY_TIMES = 2
RETRY_HTTP_CODES = [500, 502, 503, 504, 408]
```

### 5.4 缓存

```python
# settings.py

# HTTP 缓存
HTTPCACHE_ENABLED = True
HTTPCACHE_EXPIRATION_SECS = 86400  # 1 天
HTTPCACHE_DIR = 'httpcache'
HTTPCACHE_IGNORE_HTTP_CODES = [500, 502, 503, 504]
HTTPCACHE_STORAGE = 'scrapy.extensions.httpcache.FilesystemCacheStorage'

# 使用 DBM 存储（更快）
HTTPCACHE_STORAGE = 'scrapy.extensions.httpcache.DbmCacheStorage'
```

### 5.5 监控

```python
# 启用统计
STATS_DUMP = True

# 内存调试
MEMUSAGE_ENABLED = True
MEMUSAGE_LIMIT_MB = 1024
MEMUSAGE_WARNING_MB = 512
MEMUSAGE_NOTIFY_MAIL = ['admin@example.com']

# 关闭条件
CLOSESPIDER_TIMEOUT = 3600  # 1 小时
CLOSESPIDER_ITEMCOUNT = 10000
CLOSESPIDER_PAGECOUNT = 1000
CLOSESPIDER_ERRORCOUNT = 100
```

---

## 完整配置示例

```python
# settings.py

BOT_NAME = 'myproject'
SPIDER_MODULES = ['myproject.spiders']
NEWSPIDER_MODULE = 'myproject.spiders'

# 遵守 robots.txt
ROBOTSTXT_OBEY = True

# 并发
CONCURRENT_REQUESTS = 32
CONCURRENT_REQUESTS_PER_DOMAIN = 8
DOWNLOAD_DELAY = 0.5

# 中间件
DOWNLOADER_MIDDLEWARES = {
    'myproject.middlewares.RandomUserAgentMiddleware': 400,
    'myproject.middlewares.ProxyMiddleware': 410,
}

# 管道
ITEM_PIPELINES = {
    'myproject.pipelines.MongoPipeline': 300,
}

# 扩展
EXTENSIONS = {
    'myproject.extensions.StatsLoggerExtension': 500,
}

# 自动限速
AUTOTHROTTLE_ENABLED = True
AUTOTHROTTLE_START_DELAY = 1
AUTOTHROTTLE_MAX_DELAY = 10

# 缓存
HTTPCACHE_ENABLED = True
HTTPCACHE_EXPIRATION_SECS = 86400

# 日志
LOG_LEVEL = 'INFO'
LOG_FILE = 'scrapy.log'

# 分布式（可选）
# SCHEDULER = "scrapy_redis.scheduler.Scheduler"
# DUPEFILTER_CLASS = "scrapy_redis.dupefilter.RFPDupeFilter"
# REDIS_URL = 'redis://localhost:6379'
```

---

## 下一步

下一篇我们将学习 Scrapy-Redis 分布式爬虫的详细配置。

---

## 参考资料

- [Scrapy 文档](https://docs.scrapy.org/)
- [Scrapy-Redis](https://github.com/rmax/scrapy-redis)
