---
title: "代理 IP 使用"
description: "1. [代理基础](#1-代理基础)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 15
---

> 本文介绍如何使用代理 IP 突破 IP 限制，以及代理池的搭建。

---

## 目录

1. [代理基础](#1-代理基础)
2. [代理使用](#2-代理使用)
3. [代理池搭建](#3-代理池搭建)
4. [代理验证](#4-代理验证)
5. [实战应用](#5-实战应用)

---

## 1. 代理基础

### 1.1 代理类型

| 类型 | 描述 | 匿名度 |
|------|------|--------|
| 透明代理 | 目标知道你的真实 IP | 低 |
| 匿名代理 | 目标知道使用了代理 | 中 |
| 高匿代理 | 目标无法识别代理 | 高 |

### 1.2 代理协议

| 协议 | 端口 | 特点 |
|------|------|------|
| HTTP | 80/8080 | 仅支持 HTTP |
| HTTPS | 443 | 支持 HTTPS |
| SOCKS4 | 1080 | 支持 TCP |
| SOCKS5 | 1080 | 支持 TCP/UDP，认证 |

### 1.3 代理来源

- **免费代理**：不稳定，速度慢
- **付费代理**：稳定，速度快
- **自建代理**：完全可控

---

## 2. 代理使用

### 2.1 Requests 使用代理

```python
import requests

# HTTP 代理
proxies = {
    'http': 'http://127.0.0.1:7890',
    'https': 'http://127.0.0.1:7890'
}

response = requests.get('https://httpbin.org/ip', proxies=proxies)
print(response.json())

# 带认证的代理
proxies = {
    'http': 'http://user:password@proxy.example.com:8080',
    'https': 'http://user:password@proxy.example.com:8080'
}

# SOCKS 代理
# pip install requests[socks]
proxies = {
    'http': 'socks5://127.0.0.1:1080',
    'https': 'socks5://127.0.0.1:1080'
}
```

### 2.2 aiohttp 使用代理

```python
import aiohttp
import asyncio

async def fetch_with_proxy():
    proxy = 'http://127.0.0.1:7890'
    
    async with aiohttp.ClientSession() as session:
        async with session.get(
            'https://httpbin.org/ip',
            proxy=proxy
        ) as response:
            return await response.json()

# 带认证
async def fetch_with_auth_proxy():
    proxy = 'http://127.0.0.1:7890'
    proxy_auth = aiohttp.BasicAuth('user', 'password')
    
    async with aiohttp.ClientSession() as session:
        async with session.get(
            'https://httpbin.org/ip',
            proxy=proxy,
            proxy_auth=proxy_auth
        ) as response:
            return await response.json()

asyncio.run(fetch_with_proxy())
```

### 2.3 Selenium 使用代理

```python
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

# HTTP 代理
options = Options()
options.add_argument('--proxy-server=http://127.0.0.1:7890')

driver = webdriver.Chrome(options=options)
driver.get('https://httpbin.org/ip')

# 带认证的代理（需要扩展）
from selenium.webdriver.common.proxy import Proxy, ProxyType

proxy = Proxy()
proxy.proxy_type = ProxyType.MANUAL
proxy.http_proxy = '127.0.0.1:7890'
proxy.ssl_proxy = '127.0.0.1:7890'

capabilities = webdriver.DesiredCapabilities.CHROME
proxy.add_to_capabilities(capabilities)
```

### 2.4 Playwright 使用代理

```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(
        proxy={
            'server': 'http://127.0.0.1:7890',
            # 'username': 'user',
            # 'password': 'password'
        }
    )
    
    page = browser.new_page()
    page.goto('https://httpbin.org/ip')
    print(page.content())
    browser.close()
```

---

## 3. 代理池搭建

### 3.1 代理池架构

```
┌─────────────────┐
│   代理采集器     │
│  (多个来源)      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   代理验证器     │
│  (可用性检测)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Redis 存储    │
│  (代理池)       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   API 服务      │
│  (获取代理)     │
└─────────────────┘
```

### 3.2 代理采集

```python
import requests
from bs4 import BeautifulSoup
from typing import List, Dict
import re

class ProxyFetcher:
    """代理采集器"""
    
    def __init__(self):
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
    
    def fetch_from_free_proxy_list(self) -> List[Dict]:
        """从 free-proxy-list.net 采集"""
        url = 'https://free-proxy-list.net/'
        proxies = []
        
        try:
            response = requests.get(url, headers=self.headers, timeout=10)
            soup = BeautifulSoup(response.text, 'lxml')
            
            table = soup.find('table')
            if table:
                for row in table.find_all('tr')[1:]:
                    cols = row.find_all('td')
                    if len(cols) >= 7:
                        proxies.append({
                            'ip': cols[0].text,
                            'port': cols[1].text,
                            'country': cols[3].text,
                            'anonymity': cols[4].text,
                            'https': cols[6].text == 'yes',
                            'source': 'free-proxy-list'
                        })
        except Exception as e:
            print(f"采集失败: {e}")
        
        return proxies
    
    def fetch_from_proxylist(self) -> List[Dict]:
        """从其他来源采集"""
        # 实现其他代理源
        pass
    
    def fetch_all(self) -> List[Dict]:
        """采集所有来源"""
        all_proxies = []
        
        all_proxies.extend(self.fetch_from_free_proxy_list())
        # all_proxies.extend(self.fetch_from_proxylist())
        
        return all_proxies
```

### 3.3 代理验证

```python
import asyncio
import aiohttp
from typing import List, Dict

class ProxyValidator:
    """代理验证器"""
    
    def __init__(self, timeout: int = 10, test_url: str = 'https://httpbin.org/ip'):
        self.timeout = aiohttp.ClientTimeout(total=timeout)
        self.test_url = test_url
    
    async def validate_one(self, proxy: Dict) -> Dict:
        """验证单个代理"""
        proxy_url = f"http://{proxy['ip']}:{proxy['port']}"
        
        try:
            async with aiohttp.ClientSession(timeout=self.timeout) as session:
                start = asyncio.get_event_loop().time()
                
                async with session.get(self.test_url, proxy=proxy_url) as response:
                    if response.status == 200:
                        data = await response.json()
                        elapsed = asyncio.get_event_loop().time() - start
                        
                        proxy['valid'] = True
                        proxy['speed'] = round(elapsed, 2)
                        proxy['real_ip'] = data.get('origin', '')
                        return proxy
        except Exception as e:
            pass
        
        proxy['valid'] = False
        return proxy
    
    async def validate_batch(self, proxies: List[Dict], max_concurrent: int = 50) -> List[Dict]:
        """批量验证代理"""
        semaphore = asyncio.Semaphore(max_concurrent)
        
        async def validate_with_semaphore(proxy):
            async with semaphore:
                return await self.validate_one(proxy)
        
        tasks = [validate_with_semaphore(p) for p in proxies]
        results = await asyncio.gather(*tasks)
        
        return [p for p in results if p.get('valid')]

# 使用
async def main():
    fetcher = ProxyFetcher()
    validator = ProxyValidator()
    
    # 采集
    proxies = fetcher.fetch_all()
    print(f"采集到 {len(proxies)} 个代理")
    
    # 验证
    valid_proxies = await validator.validate_batch(proxies)
    print(f"有效代理 {len(valid_proxies)} 个")
    
    return valid_proxies

asyncio.run(main())
```

### 3.4 Redis 存储

```python
import redis
import json
import random
from typing import Optional, List, Dict

class ProxyPool:
    """代理池"""
    
    def __init__(self, host='localhost', port=6379, db=0):
        self.redis = redis.Redis(host=host, port=port, db=db)
        self.key = 'proxy_pool'
    
    def add(self, proxy: Dict):
        """添加代理"""
        proxy_str = f"{proxy['ip']}:{proxy['port']}"
        score = proxy.get('speed', 10)  # 速度越快分数越低
        self.redis.zadd(self.key, {proxy_str: score})
        
        # 存储详细信息
        self.redis.hset(f'proxy:{proxy_str}', mapping=proxy)
    
    def add_batch(self, proxies: List[Dict]):
        """批量添加"""
        for proxy in proxies:
            self.add(proxy)
    
    def get(self) -> Optional[str]:
        """获取一个代理（按速度排序）"""
        proxies = self.redis.zrange(self.key, 0, 0)
        if proxies:
            return proxies[0].decode()
        return None
    
    def get_random(self) -> Optional[str]:
        """随机获取一个代理"""
        count = self.redis.zcard(self.key)
        if count == 0:
            return None
        
        index = random.randint(0, count - 1)
        proxies = self.redis.zrange(self.key, index, index)
        if proxies:
            return proxies[0].decode()
        return None
    
    def get_all(self) -> List[str]:
        """获取所有代理"""
        proxies = self.redis.zrange(self.key, 0, -1)
        return [p.decode() for p in proxies]
    
    def remove(self, proxy: str):
        """移除代理"""
        self.redis.zrem(self.key, proxy)
        self.redis.delete(f'proxy:{proxy}')
    
    def count(self) -> int:
        """代理数量"""
        return self.redis.zcard(self.key)
    
    def decrease_score(self, proxy: str, amount: float = 1):
        """降低代理分数（表示不可用）"""
        self.redis.zincrby(self.key, amount, proxy)
        
        # 分数过高则移除
        score = self.redis.zscore(self.key, proxy)
        if score and score > 100:
            self.remove(proxy)

# 使用
pool = ProxyPool()

# 添加代理
pool.add({'ip': '1.2.3.4', 'port': '8080', 'speed': 0.5})

# 获取代理
proxy = pool.get_random()
print(f"获取代理: {proxy}")

# 代理失效时
pool.decrease_score(proxy)
```

### 3.5 API 服务

```python
from fastapi import FastAPI, HTTPException
from typing import Optional

app = FastAPI(title="代理池 API")
pool = ProxyPool()

@app.get("/proxy")
def get_proxy(random: bool = True):
    """获取一个代理"""
    if random:
        proxy = pool.get_random()
    else:
        proxy = pool.get()
    
    if not proxy:
        raise HTTPException(status_code=404, detail="无可用代理")
    
    return {"proxy": f"http://{proxy}"}

@app.get("/proxies")
def get_all_proxies():
    """获取所有代理"""
    proxies = pool.get_all()
    return {"count": len(proxies), "proxies": proxies}

@app.delete("/proxy/{proxy}")
def remove_proxy(proxy: str):
    """移除代理"""
    pool.remove(proxy)
    return {"message": "已移除"}

@app.post("/proxy/{proxy}/fail")
def report_fail(proxy: str):
    """报告代理失效"""
    pool.decrease_score(proxy)
    return {"message": "已记录"}

@app.get("/stats")
def get_stats():
    """获取统计信息"""
    return {"count": pool.count()}

if __name__ == '__main__':
    import uvicorn
    uvicorn.run(app, host='0.0.0.0', port=5010)
```

---

## 4. 代理验证

### 4.1 验证代理可用性

```python
import requests
from concurrent.futures import ThreadPoolExecutor, as_completed

def check_proxy(proxy: str, timeout: int = 5) -> bool:
    """检查代理是否可用"""
    proxies = {
        'http': f'http://{proxy}',
        'https': f'http://{proxy}'
    }
    
    try:
        response = requests.get(
            'https://httpbin.org/ip',
            proxies=proxies,
            timeout=timeout
        )
        return response.status_code == 200
    except:
        return False

def check_proxies_batch(proxies: list, max_workers: int = 20) -> list:
    """批量检查代理"""
    valid = []
    
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_proxy = {
            executor.submit(check_proxy, p): p
            for p in proxies
        }
        
        for future in as_completed(future_to_proxy):
            proxy = future_to_proxy[future]
            try:
                if future.result():
                    valid.append(proxy)
            except:
                pass
    
    return valid
```

### 4.2 验证匿名度

```python
def check_anonymity(proxy: str) -> str:
    """检查代理匿名度"""
    proxies = {'http': f'http://{proxy}', 'https': f'http://{proxy}'}
    
    try:
        # 获取代理返回的 IP
        response = requests.get(
            'https://httpbin.org/headers',
            proxies=proxies,
            timeout=10
        )
        headers = response.json().get('headers', {})
        
        # 检查是否暴露真实 IP
        if 'X-Forwarded-For' in headers:
            return 'transparent'
        elif 'Via' in headers or 'Proxy-Connection' in headers:
            return 'anonymous'
        else:
            return 'elite'
    except:
        return 'unknown'
```

---

## 5. 实战应用

### 5.1 自动切换代理

```python
import requests
from typing import Optional

class ProxyRotator:
    """代理轮换器"""
    
    def __init__(self, pool_api: str = 'http://localhost:5010'):
        self.pool_api = pool_api
        self.current_proxy = None
        self.fail_count = 0
        self.max_fails = 3
    
    def get_proxy(self) -> Optional[str]:
        """获取代理"""
        try:
            response = requests.get(f'{self.pool_api}/proxy')
            if response.status_code == 200:
                return response.json()['proxy']
        except:
            pass
        return None
    
    def report_fail(self, proxy: str):
        """报告失败"""
        try:
            requests.post(f'{self.pool_api}/proxy/{proxy}/fail')
        except:
            pass
    
    def request(self, url: str, **kwargs) -> Optional[requests.Response]:
        """发送请求，自动切换代理"""
        for _ in range(self.max_fails):
            proxy = self.get_proxy()
            if not proxy:
                continue
            
            try:
                response = requests.get(
                    url,
                    proxies={'http': proxy, 'https': proxy},
                    timeout=10,
                    **kwargs
                )
                
                if response.status_code == 200:
                    return response
                else:
                    self.report_fail(proxy)
            
            except Exception as e:
                self.report_fail(proxy)
        
        return None

# 使用
rotator = ProxyRotator()
response = rotator.request('https://example.com')
```

### 5.2 Scrapy 代理中间件

```python
# middlewares.py
import requests
from scrapy import signals

class ProxyMiddleware:
    """Scrapy 代理中间件"""
    
    def __init__(self, pool_api):
        self.pool_api = pool_api
    
    @classmethod
    def from_crawler(cls, crawler):
        pool_api = crawler.settings.get('PROXY_POOL_API', 'http://localhost:5010')
        return cls(pool_api)
    
    def process_request(self, request, spider):
        proxy = self.get_proxy()
        if proxy:
            request.meta['proxy'] = proxy
    
    def process_exception(self, request, exception, spider):
        proxy = request.meta.get('proxy')
        if proxy:
            self.report_fail(proxy)
        
        # 重试
        return request
    
    def get_proxy(self):
        try:
            response = requests.get(f'{self.pool_api}/proxy', timeout=5)
            if response.status_code == 200:
                return response.json()['proxy']
        except:
            pass
        return None
    
    def report_fail(self, proxy):
        try:
            requests.post(f'{self.pool_api}/proxy/{proxy}/fail', timeout=5)
        except:
            pass

# settings.py
DOWNLOADER_MIDDLEWARES = {
    'myproject.middlewares.ProxyMiddleware': 543,
}
PROXY_POOL_API = 'http://localhost:5010'
```

---

## 下一步

下一篇我们将学习验证码识别技术。

---

## 参考资料

- [ProxyPool](https://github.com/jhao104/proxy_pool)
- [Requests 代理文档](https://docs.python-requests.org/en/latest/user/advanced/#proxies)
