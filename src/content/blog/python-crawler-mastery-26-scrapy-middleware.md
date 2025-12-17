---
title: "Scrapy 中间件开发"
description: "1. [中间件概述](#1-中间件概述)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 26
---

> 本文介绍 Scrapy 中间件的开发，实现请求拦截和响应处理。

---

## 目录

1. [中间件概述](#1-中间件概述)
2. [下载器中间件](#2-下载器中间件)
3. [Spider 中间件](#3-spider-中间件)
4. [常用中间件](#4-常用中间件)
5. [实战案例](#5-实战案例)

---

## 1. 中间件概述

### 1.1 中间件类型

| 类型 | 作用 | 位置 |
|------|------|------|
| 下载器中间件 | 处理请求和响应 | Engine ↔ Downloader |
| Spider 中间件 | 处理 Spider 输入输出 | Engine ↔ Spider |

### 1.2 处理流程

```
Spider → Engine → [Spider中间件] → Engine → [下载器中间件] → Downloader
                                                              ↓
Spider ← Engine ← [Spider中间件] ← Engine ← [下载器中间件] ← Response
```

### 1.3 中间件方法

```python
# 下载器中间件
class DownloaderMiddleware:
    def process_request(self, request, spider):
        """处理请求（发送前）"""
        pass
    
    def process_response(self, request, response, spider):
        """处理响应（返回后）"""
        return response
    
    def process_exception(self, request, exception, spider):
        """处理异常"""
        pass

# Spider 中间件
class SpiderMiddleware:
    def process_spider_input(self, response, spider):
        """处理 Spider 输入"""
        pass
    
    def process_spider_output(self, response, result, spider):
        """处理 Spider 输出"""
        return result
    
    def process_spider_exception(self, response, exception, spider):
        """处理 Spider 异常"""
        pass
    
    def process_start_requests(self, start_requests, spider):
        """处理起始请求"""
        return start_requests
```

---

## 2. 下载器中间件

### 2.1 基础结构

```python
# middlewares.py

from scrapy import signals
from scrapy.http import HtmlResponse

class MyDownloaderMiddleware:
    
    @classmethod
    def from_crawler(cls, crawler):
        """从 Crawler 创建中间件"""
        middleware = cls()
        crawler.signals.connect(
            middleware.spider_opened,
            signal=signals.spider_opened
        )
        return middleware
    
    def spider_opened(self, spider):
        """Spider 打开时调用"""
        spider.logger.info('Spider opened: %s' % spider.name)
    
    def process_request(self, request, spider):
        """
        处理请求
        返回值:
        - None: 继续处理
        - Response: 直接返回响应
        - Request: 重新调度请求
        - raise IgnoreRequest: 忽略请求
        """
        return None
    
    def process_response(self, request, response, spider):
        """
        处理响应
        返回值:
        - Response: 返回响应
        - Request: 重新请求
        - raise IgnoreRequest: 忽略
        """
        return response
    
    def process_exception(self, request, exception, spider):
        """
        处理异常
        返回值:
        - None: 继续处理异常
        - Response: 返回响应
        - Request: 重试请求
        """
        return None
```

### 2.2 请求处理

```python
import random

class RequestMiddleware:
    """请求处理中间件"""
    
    USER_AGENTS = [
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
    ]
    
    def process_request(self, request, spider):
        # 随机 User-Agent
        request.headers['User-Agent'] = random.choice(self.USER_AGENTS)
        
        # 添加自定义头
        request.headers['Accept-Language'] = 'zh-CN,zh;q=0.9'
        
        # 添加 Cookie
        request.cookies['session'] = 'xxx'
        
        # 修改 meta
        request.meta['download_timeout'] = 30
        
        spider.logger.debug(f"处理请求: {request.url}")
        
        return None
```

### 2.3 响应处理

```python
from scrapy.http import HtmlResponse
from scrapy.exceptions import IgnoreRequest

class ResponseMiddleware:
    """响应处理中间件"""
    
    def process_response(self, request, response, spider):
        # 检查状态码
        if response.status >= 400:
            spider.logger.warning(f"请求失败: {response.status} - {request.url}")
            
            # 重试
            if request.meta.get('retry_times', 0) < 3:
                request.meta['retry_times'] = request.meta.get('retry_times', 0) + 1
                return request.copy()
            
            raise IgnoreRequest(f"请求失败: {response.status}")
        
        # 检查内容
        if b'captcha' in response.body.lower():
            spider.logger.warning(f"遇到验证码: {request.url}")
            # 处理验证码或重试
        
        # 检查空响应
        if len(response.body) < 100:
            spider.logger.warning(f"响应过短: {request.url}")
        
        return response
```

### 2.4 异常处理

```python
from scrapy.exceptions import IgnoreRequest
from twisted.internet.error import TimeoutError, DNSLookupError

class ExceptionMiddleware:
    """异常处理中间件"""
    
    RETRY_EXCEPTIONS = (
        TimeoutError,
        DNSLookupError,
        ConnectionRefusedError,
    )
    
    def __init__(self):
        self.max_retries = 3
    
    def process_exception(self, request, exception, spider):
        # 记录异常
        spider.logger.error(f"请求异常: {type(exception).__name__} - {request.url}")
        
        # 可重试异常
        if isinstance(exception, self.RETRY_EXCEPTIONS):
            retry_times = request.meta.get('retry_times', 0)
            
            if retry_times < self.max_retries:
                spider.logger.info(f"重试 ({retry_times + 1}/{self.max_retries}): {request.url}")
                
                new_request = request.copy()
                new_request.meta['retry_times'] = retry_times + 1
                new_request.dont_filter = True
                
                return new_request
        
        # 不可重试，忽略请求
        raise IgnoreRequest(f"异常: {exception}")
```

---

## 3. Spider 中间件

### 3.1 基础结构

```python
class MySpiderMiddleware:
    
    @classmethod
    def from_crawler(cls, crawler):
        middleware = cls()
        crawler.signals.connect(
            middleware.spider_opened,
            signal=signals.spider_opened
        )
        return middleware
    
    def spider_opened(self, spider):
        spider.logger.info('Spider opened: %s' % spider.name)
    
    def process_spider_input(self, response, spider):
        """
        处理 Spider 输入（响应进入 Spider 前）
        返回值:
        - None: 继续处理
        - raise: 调用 process_spider_exception
        """
        return None
    
    def process_spider_output(self, response, result, spider):
        """
        处理 Spider 输出（Item 和 Request）
        返回值: 可迭代对象
        """
        for item in result:
            yield item
    
    def process_spider_exception(self, response, exception, spider):
        """
        处理 Spider 异常
        返回值:
        - None: 继续处理
        - 可迭代对象: 作为输出
        """
        pass
    
    def process_start_requests(self, start_requests, spider):
        """
        处理起始请求
        返回值: 可迭代对象
        """
        for request in start_requests:
            yield request
```

### 3.2 输出过滤

```python
class OutputFilterMiddleware:
    """输出过滤中间件"""
    
    def process_spider_output(self, response, result, spider):
        for item in result:
            # 过滤空 Item
            if hasattr(item, 'items'):
                if not any(item.values()):
                    spider.logger.debug("过滤空 Item")
                    continue
            
            # 过滤重复请求
            if hasattr(item, 'url'):
                if self.is_duplicate(item.url):
                    continue
            
            yield item
    
    def is_duplicate(self, url):
        # 去重逻辑
        return False
```

### 3.3 深度控制

```python
class DepthMiddleware:
    """深度控制中间件"""
    
    def __init__(self, max_depth):
        self.max_depth = max_depth
    
    @classmethod
    def from_crawler(cls, crawler):
        return cls(
            max_depth=crawler.settings.getint('DEPTH_LIMIT', 3)
        )
    
    def process_spider_output(self, response, result, spider):
        depth = response.meta.get('depth', 0)
        
        for item in result:
            if hasattr(item, 'url'):  # Request
                if depth >= self.max_depth:
                    spider.logger.debug(f"达到最大深度，跳过: {item.url}")
                    continue
                
                item.meta['depth'] = depth + 1
            
            yield item
```

---

## 4. 常用中间件

### 4.1 代理中间件

```python
import requests

class ProxyMiddleware:
    """代理中间件"""
    
    def __init__(self, proxy_url):
        self.proxy_url = proxy_url
        self.proxy = None
    
    @classmethod
    def from_crawler(cls, crawler):
        return cls(
            proxy_url=crawler.settings.get('PROXY_URL')
        )
    
    def get_proxy(self):
        """获取代理"""
        try:
            response = requests.get(self.proxy_url, timeout=5)
            return response.text.strip()
        except:
            return None
    
    def process_request(self, request, spider):
        # 获取代理
        if not self.proxy or request.meta.get('proxy_failed'):
            self.proxy = self.get_proxy()
        
        if self.proxy:
            request.meta['proxy'] = f'http://{self.proxy}'
            spider.logger.debug(f"使用代理: {self.proxy}")
    
    def process_exception(self, request, exception, spider):
        # 代理失败，标记并重试
        if 'proxy' in request.meta:
            spider.logger.warning(f"代理失败: {self.proxy}")
            request.meta['proxy_failed'] = True
            self.proxy = None
            
            return request.copy()
```

### 4.2 Cookie 中间件

```python
import json

class CookieMiddleware:
    """Cookie 中间件"""
    
    def __init__(self, cookie_file):
        self.cookie_file = cookie_file
        self.cookies = {}
    
    @classmethod
    def from_crawler(cls, crawler):
        return cls(
            cookie_file=crawler.settings.get('COOKIE_FILE')
        )
    
    def spider_opened(self, spider):
        """加载 Cookie"""
        try:
            with open(self.cookie_file, 'r') as f:
                self.cookies = json.load(f)
            spider.logger.info(f"加载 Cookie: {len(self.cookies)} 个")
        except:
            pass
    
    def process_request(self, request, spider):
        if self.cookies:
            request.cookies.update(self.cookies)
    
    def process_response(self, request, response, spider):
        # 更新 Cookie
        for cookie in response.headers.getlist('Set-Cookie'):
            # 解析并保存
            pass
        
        return response
```

### 4.3 重试中间件

```python
from scrapy.downloadermiddlewares.retry import RetryMiddleware
from scrapy.utils.response import response_status_message

class CustomRetryMiddleware(RetryMiddleware):
    """自定义重试中间件"""
    
    RETRY_HTTP_CODES = [500, 502, 503, 504, 408, 429]
    
    def process_response(self, request, response, spider):
        if response.status in self.RETRY_HTTP_CODES:
            reason = response_status_message(response.status)
            return self._retry(request, reason, spider) or response
        
        # 检查内容
        if self.should_retry_content(response):
            return self._retry(request, 'content_error', spider) or response
        
        return response
    
    def should_retry_content(self, response):
        """检查是否需要重试"""
        # 空响应
        if len(response.body) < 100:
            return True
        
        # 错误页面
        if b'error' in response.body.lower():
            return True
        
        return False
```

### 4.4 限速中间件

```python
import time
from collections import defaultdict

class RateLimitMiddleware:
    """限速中间件"""
    
    def __init__(self, rate_limit):
        self.rate_limit = rate_limit  # 每秒请求数
        self.last_request = defaultdict(float)
    
    @classmethod
    def from_crawler(cls, crawler):
        return cls(
            rate_limit=crawler.settings.getfloat('RATE_LIMIT', 1.0)
        )
    
    def process_request(self, request, spider):
        domain = request.url.split('/')[2]
        
        # 计算等待时间
        elapsed = time.time() - self.last_request[domain]
        wait_time = 1.0 / self.rate_limit - elapsed
        
        if wait_time > 0:
            time.sleep(wait_time)
        
        self.last_request[domain] = time.time()
```

---

## 5. 实战案例

### 5.1 完整中间件配置

```python
# middlewares.py

import random
import time
import logging
from scrapy import signals
from scrapy.exceptions import IgnoreRequest

logger = logging.getLogger(__name__)

class UserAgentMiddleware:
    """User-Agent 中间件"""
    
    USER_AGENTS = [
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
    ]
    
    def process_request(self, request, spider):
        request.headers['User-Agent'] = random.choice(self.USER_AGENTS)


class ProxyMiddleware:
    """代理中间件"""
    
    def __init__(self, proxy_list):
        self.proxies = proxy_list
    
    @classmethod
    def from_crawler(cls, crawler):
        proxy_list = crawler.settings.getlist('PROXY_LIST', [])
        return cls(proxy_list)
    
    def process_request(self, request, spider):
        if self.proxies:
            proxy = random.choice(self.proxies)
            request.meta['proxy'] = proxy


class RetryMiddleware:
    """重试中间件"""
    
    def __init__(self, max_retries):
        self.max_retries = max_retries
    
    @classmethod
    def from_crawler(cls, crawler):
        return cls(
            max_retries=crawler.settings.getint('MAX_RETRIES', 3)
        )
    
    def process_response(self, request, response, spider):
        if response.status >= 400:
            return self._retry(request, spider, f"HTTP {response.status}")
        return response
    
    def process_exception(self, request, exception, spider):
        return self._retry(request, spider, str(exception))
    
    def _retry(self, request, spider, reason):
        retries = request.meta.get('retry_times', 0)
        
        if retries < self.max_retries:
            logger.info(f"重试 ({retries + 1}/{self.max_retries}): {request.url} - {reason}")
            
            new_request = request.copy()
            new_request.meta['retry_times'] = retries + 1
            new_request.dont_filter = True
            
            return new_request
        
        logger.error(f"放弃请求: {request.url} - {reason}")
        raise IgnoreRequest(reason)


class StatsMiddleware:
    """统计中间件"""
    
    def __init__(self):
        self.stats = {
            'requests': 0,
            'responses': 0,
            'errors': 0
        }
    
    @classmethod
    def from_crawler(cls, crawler):
        middleware = cls()
        crawler.signals.connect(
            middleware.spider_closed,
            signal=signals.spider_closed
        )
        return middleware
    
    def process_request(self, request, spider):
        self.stats['requests'] += 1
    
    def process_response(self, request, response, spider):
        self.stats['responses'] += 1
        return response
    
    def process_exception(self, request, exception, spider):
        self.stats['errors'] += 1
    
    def spider_closed(self, spider):
        logger.info(f"统计: {self.stats}")


# settings.py
DOWNLOADER_MIDDLEWARES = {
    'myproject.middlewares.UserAgentMiddleware': 400,
    'myproject.middlewares.ProxyMiddleware': 410,
    'myproject.middlewares.RetryMiddleware': 500,
    'myproject.middlewares.StatsMiddleware': 900,
}

PROXY_LIST = [
    'http://proxy1:8080',
    'http://proxy2:8080',
]
MAX_RETRIES = 3
```

---

## 下一步

下一篇我们将学习异步爬虫进阶。

---

## 参考资料

- [Scrapy 下载器中间件](https://docs.scrapy.org/en/latest/topics/downloader-middleware.html)
- [Scrapy Spider 中间件](https://docs.scrapy.org/en/latest/topics/spider-middleware.html)
