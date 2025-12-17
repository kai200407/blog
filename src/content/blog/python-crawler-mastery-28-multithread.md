---
title: "多线程与多进程爬虫"
description: "1. [并发基础](#1-并发基础)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 28
---

> 本文介绍如何使用多线程和多进程提升爬虫性能。

---

## 目录

1. [并发基础](#1-并发基础)
2. [多线程爬虫](#2-多线程爬虫)
3. [多进程爬虫](#3-多进程爬虫)
4. [线程池与进程池](#4-线程池与进程池)
5. [最佳实践](#5-最佳实践)

---

## 1. 并发基础

### 1.1 并发 vs 并行

| 概念 | 描述 | 适用场景 |
|------|------|----------|
| 并发 | 交替执行多个任务 | IO 密集型 |
| 并行 | 同时执行多个任务 | CPU 密集型 |

### 1.2 GIL 限制

Python 的 GIL（全局解释器锁）限制了多线程的并行执行：
- **多线程**：适合 IO 密集型（网络请求、文件读写）
- **多进程**：适合 CPU 密集型（数据处理、计算）

### 1.3 选择建议

| 场景 | 推荐方案 |
|------|----------|
| 大量网络请求 | 多线程 / 异步 |
| 数据解析处理 | 多进程 |
| 混合场景 | 多进程 + 多线程 |

---

## 2. 多线程爬虫

### 2.1 基本用法

```python
import threading
import requests
from queue import Queue
import time

def worker(url_queue, results):
    """工作线程"""
    while True:
        try:
            url = url_queue.get(timeout=3)
        except:
            break
        
        try:
            response = requests.get(url, timeout=10)
            results.append({
                'url': url,
                'status': response.status_code,
                'length': len(response.text)
            })
        except Exception as e:
            results.append({
                'url': url,
                'error': str(e)
            })
        finally:
            url_queue.task_done()

def crawl_with_threads(urls, num_threads=10):
    """多线程爬取"""
    url_queue = Queue()
    results = []
    
    # 添加 URL 到队列
    for url in urls:
        url_queue.put(url)
    
    # 创建线程
    threads = []
    for _ in range(num_threads):
        t = threading.Thread(target=worker, args=(url_queue, results))
        t.daemon = True
        t.start()
        threads.append(t)
    
    # 等待完成
    url_queue.join()
    
    return results

# 使用
urls = [f'https://httpbin.org/delay/1?id={i}' for i in range(20)]
start = time.time()
results = crawl_with_threads(urls, num_threads=10)
print(f"耗时: {time.time() - start:.2f}s")
print(f"成功: {len([r for r in results if 'status' in r])}")
```

### 2.2 线程安全

```python
import threading
from collections import defaultdict

class ThreadSafeCrawler:
    """线程安全的爬虫"""
    
    def __init__(self):
        self.lock = threading.Lock()
        self.visited = set()
        self.results = []
        self.stats = defaultdict(int)
    
    def is_visited(self, url):
        with self.lock:
            if url in self.visited:
                return True
            self.visited.add(url)
            return False
    
    def add_result(self, result):
        with self.lock:
            self.results.append(result)
    
    def update_stats(self, key, value=1):
        with self.lock:
            self.stats[key] += value
    
    def crawl(self, url):
        if self.is_visited(url):
            return
        
        try:
            response = requests.get(url, timeout=10)
            self.add_result({
                'url': url,
                'status': response.status_code
            })
            self.update_stats('success')
        except Exception as e:
            self.update_stats('error')
```

### 2.3 生产者-消费者模式

```python
import threading
from queue import Queue
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin

class ProducerConsumerCrawler:
    """生产者-消费者爬虫"""
    
    def __init__(self, start_url, max_depth=2, num_workers=5):
        self.start_url = start_url
        self.max_depth = max_depth
        self.num_workers = num_workers
        
        self.url_queue = Queue()
        self.result_queue = Queue()
        self.visited = set()
        self.lock = threading.Lock()
    
    def producer(self):
        """生产者：解析页面，提取新 URL"""
        while True:
            try:
                item = self.result_queue.get(timeout=5)
            except:
                break
            
            if item['depth'] >= self.max_depth:
                continue
            
            soup = BeautifulSoup(item['html'], 'lxml')
            for a in soup.find_all('a', href=True):
                url = urljoin(item['url'], a['href'])
                
                with self.lock:
                    if url not in self.visited:
                        self.visited.add(url)
                        self.url_queue.put({
                            'url': url,
                            'depth': item['depth'] + 1
                        })
    
    def consumer(self):
        """消费者：下载页面"""
        while True:
            try:
                item = self.url_queue.get(timeout=5)
            except:
                break
            
            try:
                response = requests.get(item['url'], timeout=10)
                self.result_queue.put({
                    'url': item['url'],
                    'depth': item['depth'],
                    'html': response.text
                })
            except:
                pass
            finally:
                self.url_queue.task_done()
    
    def run(self):
        # 初始化
        self.visited.add(self.start_url)
        self.url_queue.put({'url': self.start_url, 'depth': 0})
        
        # 启动消费者
        consumers = []
        for _ in range(self.num_workers):
            t = threading.Thread(target=self.consumer)
            t.daemon = True
            t.start()
            consumers.append(t)
        
        # 启动生产者
        producer = threading.Thread(target=self.producer)
        producer.daemon = True
        producer.start()
        
        # 等待完成
        self.url_queue.join()
        
        return list(self.visited)
```

---

## 3. 多进程爬虫

### 3.1 基本用法

```python
import multiprocessing as mp
import requests

def fetch_url(url):
    """获取 URL"""
    try:
        response = requests.get(url, timeout=10)
        return {
            'url': url,
            'status': response.status_code,
            'length': len(response.text)
        }
    except Exception as e:
        return {
            'url': url,
            'error': str(e)
        }

def crawl_with_processes(urls, num_processes=4):
    """多进程爬取"""
    with mp.Pool(processes=num_processes) as pool:
        results = pool.map(fetch_url, urls)
    return results

# 使用
if __name__ == '__main__':
    urls = [f'https://httpbin.org/get?id={i}' for i in range(20)]
    results = crawl_with_processes(urls, num_processes=4)
    print(f"成功: {len([r for r in results if 'status' in r])}")
```

### 3.2 进程间通信

```python
import multiprocessing as mp
from multiprocessing import Queue, Manager
import requests

def worker(url_queue, result_queue, visited):
    """工作进程"""
    while True:
        try:
            url = url_queue.get(timeout=5)
        except:
            break
        
        if url in visited:
            continue
        
        visited[url] = True
        
        try:
            response = requests.get(url, timeout=10)
            result_queue.put({
                'url': url,
                'status': response.status_code
            })
        except Exception as e:
            result_queue.put({
                'url': url,
                'error': str(e)
            })

def crawl_with_shared_memory(urls, num_processes=4):
    """使用共享内存的多进程爬虫"""
    manager = Manager()
    url_queue = manager.Queue()
    result_queue = manager.Queue()
    visited = manager.dict()
    
    # 添加 URL
    for url in urls:
        url_queue.put(url)
    
    # 创建进程
    processes = []
    for _ in range(num_processes):
        p = mp.Process(target=worker, args=(url_queue, result_queue, visited))
        p.start()
        processes.append(p)
    
    # 等待完成
    for p in processes:
        p.join()
    
    # 收集结果
    results = []
    while not result_queue.empty():
        results.append(result_queue.get())
    
    return results

if __name__ == '__main__':
    urls = [f'https://httpbin.org/get?id={i}' for i in range(20)]
    results = crawl_with_shared_memory(urls)
    print(f"结果数: {len(results)}")
```

### 3.3 多进程 + 多线程

```python
import multiprocessing as mp
from concurrent.futures import ThreadPoolExecutor
import requests

def process_batch(urls, num_threads=5):
    """单个进程内使用多线程处理一批 URL"""
    def fetch(url):
        try:
            response = requests.get(url, timeout=10)
            return {'url': url, 'status': response.status_code}
        except Exception as e:
            return {'url': url, 'error': str(e)}
    
    with ThreadPoolExecutor(max_workers=num_threads) as executor:
        results = list(executor.map(fetch, urls))
    
    return results

def crawl_hybrid(urls, num_processes=4, num_threads=5):
    """混合模式：多进程 + 多线程"""
    # 将 URL 分成多批
    batch_size = len(urls) // num_processes + 1
    batches = [urls[i:i+batch_size] for i in range(0, len(urls), batch_size)]
    
    with mp.Pool(processes=num_processes) as pool:
        # 每个进程处理一批
        results = pool.starmap(
            process_batch,
            [(batch, num_threads) for batch in batches]
        )
    
    # 合并结果
    return [item for batch in results for item in batch]

if __name__ == '__main__':
    urls = [f'https://httpbin.org/get?id={i}' for i in range(100)]
    results = crawl_hybrid(urls, num_processes=4, num_threads=10)
    print(f"结果数: {len(results)}")
```

---

## 4. 线程池与进程池

### 4.1 ThreadPoolExecutor

```python
from concurrent.futures import ThreadPoolExecutor, as_completed
import requests

def fetch_url(url):
    response = requests.get(url, timeout=10)
    return {'url': url, 'status': response.status_code}

def crawl_with_thread_pool(urls, max_workers=10):
    """使用线程池"""
    results = []
    
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        # 方式1：map
        # results = list(executor.map(fetch_url, urls))
        
        # 方式2：submit + as_completed（可以处理异常）
        futures = {executor.submit(fetch_url, url): url for url in urls}
        
        for future in as_completed(futures):
            url = futures[future]
            try:
                result = future.result()
                results.append(result)
            except Exception as e:
                results.append({'url': url, 'error': str(e)})
    
    return results

# 使用
urls = [f'https://httpbin.org/get?id={i}' for i in range(50)]
results = crawl_with_thread_pool(urls, max_workers=20)
```

### 4.2 ProcessPoolExecutor

```python
from concurrent.futures import ProcessPoolExecutor, as_completed
import requests

def fetch_and_parse(url):
    """获取并解析页面"""
    response = requests.get(url, timeout=10)
    # CPU 密集型处理
    from bs4 import BeautifulSoup
    soup = BeautifulSoup(response.text, 'lxml')
    return {
        'url': url,
        'title': soup.title.string if soup.title else '',
        'links': len(soup.find_all('a'))
    }

def crawl_with_process_pool(urls, max_workers=4):
    """使用进程池"""
    results = []
    
    with ProcessPoolExecutor(max_workers=max_workers) as executor:
        futures = {executor.submit(fetch_and_parse, url): url for url in urls}
        
        for future in as_completed(futures):
            url = futures[future]
            try:
                result = future.result()
                results.append(result)
            except Exception as e:
                results.append({'url': url, 'error': str(e)})
    
    return results

if __name__ == '__main__':
    urls = [f'https://example.com/page/{i}' for i in range(20)]
    results = crawl_with_process_pool(urls)
```

### 4.3 带进度条

```python
from concurrent.futures import ThreadPoolExecutor, as_completed
from tqdm import tqdm
import requests

def fetch_url(url):
    response = requests.get(url, timeout=10)
    return {'url': url, 'status': response.status_code}

def crawl_with_progress(urls, max_workers=10):
    """带进度条的爬取"""
    results = []
    
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {executor.submit(fetch_url, url): url for url in urls}
        
        with tqdm(total=len(urls), desc="爬取进度") as pbar:
            for future in as_completed(futures):
                try:
                    result = future.result()
                    results.append(result)
                except Exception as e:
                    results.append({'error': str(e)})
                pbar.update(1)
    
    return results
```

---

## 5. 最佳实践

### 5.1 完整爬虫示例

```python
from concurrent.futures import ThreadPoolExecutor, as_completed
from queue import Queue
import threading
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse
from dataclasses import dataclass
from typing import Set, List
import time
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class CrawlResult:
    url: str
    title: str
    status: int
    links: List[str]

class ThreadedCrawler:
    """多线程爬虫"""
    
    def __init__(
        self,
        max_workers: int = 10,
        max_depth: int = 2,
        delay: float = 0.5,
        allowed_domains: List[str] = None
    ):
        self.max_workers = max_workers
        self.max_depth = max_depth
        self.delay = delay
        self.allowed_domains = allowed_domains or []
        
        self.visited: Set[str] = set()
        self.results: List[CrawlResult] = []
        self.lock = threading.Lock()
        
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        })
    
    def is_valid_url(self, url: str) -> bool:
        parsed = urlparse(url)
        
        if parsed.scheme not in ('http', 'https'):
            return False
        
        if self.allowed_domains:
            if not any(parsed.netloc.endswith(d) for d in self.allowed_domains):
                return False
        
        return True
    
    def fetch(self, url: str) -> CrawlResult:
        time.sleep(self.delay)
        
        try:
            response = self.session.get(url, timeout=10)
            soup = BeautifulSoup(response.text, 'lxml')
            
            title = soup.title.string if soup.title else ''
            
            links = []
            for a in soup.find_all('a', href=True):
                link = urljoin(url, a['href'])
                if self.is_valid_url(link):
                    links.append(link)
            
            return CrawlResult(
                url=url,
                title=title,
                status=response.status_code,
                links=list(set(links))
            )
        
        except Exception as e:
            logger.error(f"获取失败 {url}: {e}")
            return CrawlResult(url=url, title='', status=0, links=[])
    
    def crawl(self, start_urls: List[str]) -> List[CrawlResult]:
        # 初始化队列
        queue = [(url, 0) for url in start_urls]
        
        while queue:
            # 获取当前层的 URL
            current_batch = []
            next_queue = []
            
            for url, depth in queue:
                with self.lock:
                    if url in self.visited:
                        continue
                    self.visited.add(url)
                
                if depth <= self.max_depth:
                    current_batch.append((url, depth))
            
            if not current_batch:
                break
            
            # 并发爬取
            with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
                futures = {
                    executor.submit(self.fetch, url): (url, depth)
                    for url, depth in current_batch
                }
                
                for future in as_completed(futures):
                    url, depth = futures[future]
                    
                    try:
                        result = future.result()
                        self.results.append(result)
                        
                        logger.info(f"[深度 {depth}] {result.title or url}")
                        
                        # 添加新链接
                        if depth < self.max_depth:
                            for link in result.links[:10]:
                                next_queue.append((link, depth + 1))
                    
                    except Exception as e:
                        logger.error(f"处理失败 {url}: {e}")
            
            queue = next_queue
        
        return self.results

def main():
    crawler = ThreadedCrawler(
        max_workers=10,
        max_depth=2,
        delay=0.5,
        allowed_domains=['example.com']
    )
    
    start_time = time.time()
    results = crawler.crawl(['https://example.com'])
    elapsed = time.time() - start_time
    
    print(f"\n爬取完成!")
    print(f"总页面: {len(results)}")
    print(f"总耗时: {elapsed:.2f}s")
    print(f"平均速度: {len(results)/elapsed:.2f} 页/秒")

if __name__ == '__main__':
    main()
```

### 5.2 性能对比

| 方案 | 优点 | 缺点 | 适用场景 |
|------|------|------|----------|
| 单线程 | 简单 | 慢 | 少量请求 |
| 多线程 | IO 高效 | GIL 限制 | 网络请求 |
| 多进程 | 真并行 | 开销大 | CPU 密集 |
| 异步 | 高并发 | 复杂 | 大量 IO |

---

## 下一步

下一篇我们将学习增量爬虫的实现。

---

## 参考资料

- [threading 文档](https://docs.python.org/3/library/threading.html)
- [multiprocessing 文档](https://docs.python.org/3/library/multiprocessing.html)
- [concurrent.futures 文档](https://docs.python.org/3/library/concurrent.futures.html)
