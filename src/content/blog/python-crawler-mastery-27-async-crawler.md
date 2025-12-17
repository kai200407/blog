---
title: "异步爬虫"
description: "1. [异步编程基础](#1-异步编程基础)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 27
---

> 本文介绍如何使用 asyncio 和 aiohttp 构建高性能异步爬虫。

---

## 目录

1. [异步编程基础](#1-异步编程基础)
2. [aiohttp 使用](#2-aiohttp-使用)
3. [并发控制](#3-并发控制)
4. [异步爬虫框架](#4-异步爬虫框架)
5. [性能对比](#5-性能对比)

---

## 1. 异步编程基础

### 1.1 同步 vs 异步

```python
# 同步方式（阻塞）
import requests
import time

def sync_fetch(urls):
    results = []
    for url in urls:
        response = requests.get(url)
        results.append(response.text)
    return results

# 异步方式（非阻塞）
import asyncio
import aiohttp

async def async_fetch(urls):
    async with aiohttp.ClientSession() as session:
        tasks = [fetch_one(session, url) for url in urls]
        return await asyncio.gather(*tasks)

async def fetch_one(session, url):
    async with session.get(url) as response:
        return await response.text()
```

### 1.2 asyncio 基础

```python
import asyncio

# 定义协程
async def hello():
    print("Hello")
    await asyncio.sleep(1)  # 非阻塞等待
    print("World")

# 运行协程
asyncio.run(hello())

# 并发执行多个协程
async def main():
    task1 = asyncio.create_task(hello())
    task2 = asyncio.create_task(hello())
    await task1
    await task2

asyncio.run(main())
```

### 1.3 常用异步操作

```python
import asyncio

# gather - 并发执行，收集结果
async def main():
    results = await asyncio.gather(
        fetch('url1'),
        fetch('url2'),
        fetch('url3')
    )
    return results

# wait - 等待完成
async def main():
    tasks = [asyncio.create_task(fetch(url)) for url in urls]
    done, pending = await asyncio.wait(tasks, timeout=10)
    
    for task in done:
        result = task.result()

# as_completed - 按完成顺序处理
async def main():
    tasks = [asyncio.create_task(fetch(url)) for url in urls]
    
    for coro in asyncio.as_completed(tasks):
        result = await coro
        print(f"完成: {result}")
```

---

## 2. aiohttp 使用

### 2.1 安装

```bash
pip install aiohttp
```

### 2.2 基本请求

```python
import aiohttp
import asyncio

async def fetch(url):
    async with aiohttp.ClientSession() as session:
        async with session.get(url) as response:
            print(f"状态码: {response.status}")
            return await response.text()

# 运行
result = asyncio.run(fetch('https://example.com'))
print(result)
```

### 2.3 请求配置

```python
import aiohttp
import asyncio

async def fetch_with_options():
    # 自定义超时
    timeout = aiohttp.ClientTimeout(total=30, connect=10)
    
    # 自定义请求头
    headers = {
        'User-Agent': 'Mozilla/5.0...',
        'Accept': 'text/html'
    }
    
    # 创建 Session
    async with aiohttp.ClientSession(
        timeout=timeout,
        headers=headers
    ) as session:
        
        # GET 请求
        async with session.get('https://httpbin.org/get') as resp:
            data = await resp.json()
        
        # POST 请求
        async with session.post(
            'https://httpbin.org/post',
            data={'key': 'value'}
        ) as resp:
            data = await resp.json()
        
        # JSON POST
        async with session.post(
            'https://httpbin.org/post',
            json={'key': 'value'}
        ) as resp:
            data = await resp.json()
        
        return data

asyncio.run(fetch_with_options())
```

### 2.4 代理和 Cookie

```python
async def fetch_with_proxy():
    # 代理
    async with aiohttp.ClientSession() as session:
        async with session.get(
            'https://httpbin.org/ip',
            proxy='http://proxy:port'
        ) as resp:
            return await resp.json()

async def fetch_with_cookies():
    # Cookie
    cookies = {'session_id': 'abc123'}
    
    async with aiohttp.ClientSession(cookies=cookies) as session:
        async with session.get('https://httpbin.org/cookies') as resp:
            return await resp.json()
```

### 2.5 响应处理

```python
async def handle_response(url):
    async with aiohttp.ClientSession() as session:
        async with session.get(url) as response:
            # 状态码
            print(response.status)
            
            # 响应头
            print(response.headers)
            
            # 文本内容
            text = await response.text()
            
            # JSON
            # json_data = await response.json()
            
            # 二进制
            # binary = await response.read()
            
            # 流式读取
            # async for chunk in response.content.iter_chunked(1024):
            #     process(chunk)
            
            return text
```

---

## 3. 并发控制

### 3.1 信号量限制并发

```python
import asyncio
import aiohttp

async def fetch_with_semaphore(session, url, semaphore):
    async with semaphore:
        async with session.get(url) as response:
            return await response.text()

async def main(urls, max_concurrent=10):
    semaphore = asyncio.Semaphore(max_concurrent)
    
    async with aiohttp.ClientSession() as session:
        tasks = [
            fetch_with_semaphore(session, url, semaphore)
            for url in urls
        ]
        return await asyncio.gather(*tasks)

# 使用
urls = [f'https://example.com/page/{i}' for i in range(100)]
results = asyncio.run(main(urls, max_concurrent=10))
```

### 3.2 连接池限制

```python
async def main_with_connector():
    # 限制连接数
    connector = aiohttp.TCPConnector(
        limit=100,              # 总连接数
        limit_per_host=10,      # 每个主机连接数
        ttl_dns_cache=300       # DNS 缓存时间
    )
    
    async with aiohttp.ClientSession(connector=connector) as session:
        tasks = [session.get(url) for url in urls]
        responses = await asyncio.gather(*tasks)
        return responses
```

### 3.3 请求速率限制

```python
import asyncio
from asyncio import Semaphore
import time

class RateLimiter:
    """速率限制器"""
    
    def __init__(self, rate: float, per: float = 1.0):
        """
        rate: 允许的请求数
        per: 时间窗口（秒）
        """
        self.rate = rate
        self.per = per
        self.tokens = rate
        self.last_update = time.monotonic()
        self.lock = asyncio.Lock()
    
    async def acquire(self):
        async with self.lock:
            now = time.monotonic()
            elapsed = now - self.last_update
            self.tokens = min(self.rate, self.tokens + elapsed * (self.rate / self.per))
            self.last_update = now
            
            if self.tokens < 1:
                wait_time = (1 - self.tokens) * (self.per / self.rate)
                await asyncio.sleep(wait_time)
                self.tokens = 0
            else:
                self.tokens -= 1

# 使用
rate_limiter = RateLimiter(rate=10, per=1.0)  # 每秒 10 个请求

async def fetch_with_rate_limit(session, url):
    await rate_limiter.acquire()
    async with session.get(url) as response:
        return await response.text()
```

---

## 4. 异步爬虫框架

### 4.1 完整异步爬虫

```python
import asyncio
import aiohttp
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse
import logging
from dataclasses import dataclass
from typing import Set, List, Optional
import time

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class CrawlResult:
    url: str
    title: str
    links: List[str]
    content: str

class AsyncCrawler:
    """异步爬虫"""
    
    def __init__(
        self,
        max_concurrent: int = 10,
        max_depth: int = 3,
        delay: float = 0.5,
        timeout: int = 30
    ):
        self.max_concurrent = max_concurrent
        self.max_depth = max_depth
        self.delay = delay
        self.timeout = aiohttp.ClientTimeout(total=timeout)
        
        self.visited: Set[str] = set()
        self.results: List[CrawlResult] = []
        self.semaphore: Optional[asyncio.Semaphore] = None
    
    async def fetch(self, session: aiohttp.ClientSession, url: str) -> Optional[str]:
        """获取页面内容"""
        try:
            async with self.semaphore:
                await asyncio.sleep(self.delay)
                async with session.get(url) as response:
                    if response.status == 200:
                        return await response.text()
                    else:
                        logger.warning(f"状态码 {response.status}: {url}")
                        return None
        except Exception as e:
            logger.error(f"请求失败 {url}: {e}")
            return None
    
    def parse(self, url: str, html: str) -> CrawlResult:
        """解析页面"""
        soup = BeautifulSoup(html, 'lxml')
        
        title = soup.title.string if soup.title else ''
        
        links = []
        for a in soup.find_all('a', href=True):
            href = a['href']
            full_url = urljoin(url, href)
            if self.is_valid_url(full_url):
                links.append(full_url)
        
        content = soup.get_text(separator=' ', strip=True)[:1000]
        
        return CrawlResult(
            url=url,
            title=title,
            links=links,
            content=content
        )
    
    def is_valid_url(self, url: str) -> bool:
        """验证 URL"""
        parsed = urlparse(url)
        if parsed.scheme not in ('http', 'https'):
            return False
        if any(url.endswith(ext) for ext in ['.jpg', '.png', '.gif', '.pdf', '.zip']):
            return False
        return True
    
    async def crawl_url(
        self,
        session: aiohttp.ClientSession,
        url: str,
        depth: int
    ):
        """爬取单个 URL"""
        if url in self.visited or depth > self.max_depth:
            return
        
        self.visited.add(url)
        logger.info(f"爬取 [深度 {depth}]: {url}")
        
        html = await self.fetch(session, url)
        if not html:
            return
        
        result = self.parse(url, html)
        self.results.append(result)
        
        # 递归爬取链接
        if depth < self.max_depth:
            tasks = [
                self.crawl_url(session, link, depth + 1)
                for link in result.links[:10]  # 限制每页链接数
                if link not in self.visited
            ]
            await asyncio.gather(*tasks, return_exceptions=True)
    
    async def run(self, start_urls: List[str]) -> List[CrawlResult]:
        """运行爬虫"""
        self.semaphore = asyncio.Semaphore(self.max_concurrent)
        
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
        
        connector = aiohttp.TCPConnector(limit=self.max_concurrent * 2)
        
        async with aiohttp.ClientSession(
            headers=headers,
            timeout=self.timeout,
            connector=connector
        ) as session:
            tasks = [
                self.crawl_url(session, url, depth=0)
                for url in start_urls
            ]
            await asyncio.gather(*tasks, return_exceptions=True)
        
        return self.results

# 使用
async def main():
    crawler = AsyncCrawler(
        max_concurrent=10,
        max_depth=2,
        delay=0.5
    )
    
    start_time = time.time()
    results = await crawler.run(['https://example.com'])
    elapsed = time.time() - start_time
    
    print(f"爬取完成: {len(results)} 个页面, 耗时 {elapsed:.2f} 秒")
    
    for result in results[:5]:
        print(f"- {result.title}: {result.url}")

asyncio.run(main())
```

### 4.2 异步生产者-消费者模式

```python
import asyncio
import aiohttp
from asyncio import Queue

class AsyncProducerConsumer:
    """生产者-消费者模式爬虫"""
    
    def __init__(self, num_workers: int = 5):
        self.num_workers = num_workers
        self.url_queue: Queue = Queue()
        self.result_queue: Queue = Queue()
        self.visited: set = set()
    
    async def producer(self, start_urls: list):
        """生产者：添加 URL 到队列"""
        for url in start_urls:
            await self.url_queue.put(url)
    
    async def worker(self, session: aiohttp.ClientSession, worker_id: int):
        """消费者：处理 URL"""
        while True:
            try:
                url = await asyncio.wait_for(
                    self.url_queue.get(),
                    timeout=5.0
                )
            except asyncio.TimeoutError:
                break
            
            if url in self.visited:
                self.url_queue.task_done()
                continue
            
            self.visited.add(url)
            
            try:
                async with session.get(url) as response:
                    if response.status == 200:
                        html = await response.text()
                        await self.result_queue.put({
                            'url': url,
                            'html': html
                        })
            except Exception as e:
                print(f"Worker {worker_id} 错误: {e}")
            
            self.url_queue.task_done()
    
    async def run(self, start_urls: list):
        """运行爬虫"""
        async with aiohttp.ClientSession() as session:
            # 启动生产者
            await self.producer(start_urls)
            
            # 启动消费者
            workers = [
                asyncio.create_task(self.worker(session, i))
                for i in range(self.num_workers)
            ]
            
            # 等待队列处理完成
            await self.url_queue.join()
            
            # 取消 workers
            for worker in workers:
                worker.cancel()
        
        # 收集结果
        results = []
        while not self.result_queue.empty():
            results.append(await self.result_queue.get())
        
        return results

# 使用
crawler = AsyncProducerConsumer(num_workers=10)
results = asyncio.run(crawler.run(['https://example.com']))
```

---

## 5. 性能对比

### 5.1 同步 vs 异步对比

```python
import time
import requests
import aiohttp
import asyncio

urls = [f'https://httpbin.org/delay/1' for _ in range(10)]

# 同步
def sync_crawl():
    start = time.time()
    for url in urls:
        requests.get(url)
    return time.time() - start

# 异步
async def async_crawl():
    start = time.time()
    async with aiohttp.ClientSession() as session:
        tasks = [session.get(url) for url in urls]
        await asyncio.gather(*tasks)
    return time.time() - start

print(f"同步耗时: {sync_crawl():.2f}s")  # ~10s
print(f"异步耗时: {asyncio.run(async_crawl()):.2f}s")  # ~1s
```

### 5.2 性能建议

| 场景 | 建议 |
|------|------|
| 少量请求 | 同步即可 |
| 大量 IO 密集 | 异步 |
| CPU 密集 | 多进程 |
| 混合场景 | 异步 + 进程池 |

---

## 下一步

下一篇我们将学习多线程和多进程爬虫。

---

## 参考资料

- [asyncio 文档](https://docs.python.org/3/library/asyncio.html)
- [aiohttp 文档](https://docs.aiohttp.org/)
