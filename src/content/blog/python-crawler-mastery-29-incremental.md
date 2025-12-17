---
title: "增量爬虫"
description: "1. [增量爬虫原理](#1-增量爬虫原理)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 29
---

> 本文介绍如何实现增量爬虫，只爬取新增或更新的内容。

---

## 目录

1. [增量爬虫原理](#1-增量爬虫原理)
2. [去重策略](#2-去重策略)
3. [更新检测](#3-更新检测)
4. [增量存储](#4-增量存储)
5. [实战应用](#5-实战应用)

---

## 1. 增量爬虫原理

### 1.1 什么是增量爬虫

增量爬虫只爬取：
- **新增内容**：之前没有爬取过的
- **更新内容**：已爬取但发生变化的

### 1.2 增量爬虫优势

| 优势 | 说明 |
|------|------|
| 节省资源 | 减少请求次数 |
| 提高效率 | 只处理变化数据 |
| 减少压力 | 降低目标站点负载 |
| 数据新鲜 | 及时获取更新 |

### 1.3 实现方式

```
1. URL 去重：跳过已爬取的 URL
2. 内容指纹：检测内容是否变化
3. 时间戳：基于更新时间判断
4. 版本号：基于版本号判断
5. ETag/Last-Modified：HTTP 缓存头
```

---

## 2. 去重策略

### 2.1 URL 去重

```python
import hashlib
import redis

class URLDeduplicator:
    """URL 去重器"""
    
    def __init__(self, redis_url='redis://localhost:6379/0'):
        self.redis = redis.from_url(redis_url)
        self.key = 'crawled_urls'
    
    def _hash(self, url):
        """URL 哈希"""
        # 规范化 URL
        url = url.lower().rstrip('/')
        return hashlib.md5(url.encode()).hexdigest()
    
    def is_crawled(self, url):
        """检查是否已爬取"""
        return self.redis.sismember(self.key, self._hash(url))
    
    def mark_crawled(self, url):
        """标记为已爬取"""
        self.redis.sadd(self.key, self._hash(url))
    
    def add_if_new(self, url):
        """添加新 URL，返回是否新增"""
        url_hash = self._hash(url)
        return self.redis.sadd(self.key, url_hash) == 1
    
    def count(self):
        """已爬取数量"""
        return self.redis.scard(self.key)

# 使用
dedup = URLDeduplicator()

urls = [
    'https://example.com/article/1',
    'https://example.com/article/2',
    'https://example.com/article/1',  # 重复
]

for url in urls:
    if dedup.add_if_new(url):
        print(f"新 URL: {url}")
        # 爬取逻辑
    else:
        print(f"跳过: {url}")
```

### 2.2 内容指纹

```python
import hashlib
from typing import Optional

class ContentFingerprint:
    """内容指纹"""
    
    def __init__(self, redis_url='redis://localhost:6379/0'):
        self.redis = redis.from_url(redis_url)
    
    def _content_hash(self, content):
        """计算内容哈希"""
        return hashlib.sha256(content.encode()).hexdigest()
    
    def _url_key(self, url):
        """URL 键"""
        url_hash = hashlib.md5(url.encode()).hexdigest()
        return f"fingerprint:{url_hash}"
    
    def is_changed(self, url, content) -> bool:
        """检查内容是否变化"""
        key = self._url_key(url)
        new_hash = self._content_hash(content)
        
        old_hash = self.redis.get(key)
        if old_hash:
            old_hash = old_hash.decode()
        
        if old_hash == new_hash:
            return False
        
        # 更新指纹
        self.redis.set(key, new_hash)
        return True
    
    def get_fingerprint(self, url) -> Optional[str]:
        """获取指纹"""
        key = self._url_key(url)
        fp = self.redis.get(key)
        return fp.decode() if fp else None

# 使用
fp = ContentFingerprint()

url = 'https://example.com/article/1'
content = "文章内容..."

if fp.is_changed(url, content):
    print("内容已更新，需要重新处理")
else:
    print("内容未变化，跳过")
```

### 2.3 Bloom Filter

```python
from pybloom_live import ScalableBloomFilter
import pickle
import os

class BloomDeduplicator:
    """Bloom Filter 去重器（内存高效）"""
    
    def __init__(self, filepath='bloom.pkl', error_rate=0.001):
        self.filepath = filepath
        self.error_rate = error_rate
        self.bloom = self._load_or_create()
    
    def _load_or_create(self):
        """加载或创建 Bloom Filter"""
        if os.path.exists(self.filepath):
            with open(self.filepath, 'rb') as f:
                return pickle.load(f)
        return ScalableBloomFilter(
            initial_capacity=100000,
            error_rate=self.error_rate
        )
    
    def save(self):
        """保存到文件"""
        with open(self.filepath, 'wb') as f:
            pickle.dump(self.bloom, f)
    
    def is_crawled(self, url):
        """检查是否已爬取"""
        return url in self.bloom
    
    def mark_crawled(self, url):
        """标记为已爬取"""
        self.bloom.add(url)
    
    def add_if_new(self, url):
        """添加新 URL"""
        if url in self.bloom:
            return False
        self.bloom.add(url)
        return True

# 使用
dedup = BloomDeduplicator()

for url in urls:
    if dedup.add_if_new(url):
        # 爬取
        pass

# 保存
dedup.save()
```

---

## 3. 更新检测

### 3.1 HTTP 缓存头

```python
import requests
from datetime import datetime

class HTTPCacheChecker:
    """HTTP 缓存检查器"""
    
    def __init__(self, redis_url='redis://localhost:6379/0'):
        self.redis = redis.from_url(redis_url)
        self.session = requests.Session()
    
    def _cache_key(self, url):
        return f"http_cache:{hashlib.md5(url.encode()).hexdigest()}"
    
    def check_modified(self, url) -> tuple:
        """
        检查是否修改
        返回: (is_modified, response)
        """
        key = self._cache_key(url)
        cache = self.redis.hgetall(key)
        
        headers = {}
        
        if cache:
            if b'etag' in cache:
                headers['If-None-Match'] = cache[b'etag'].decode()
            if b'last_modified' in cache:
                headers['If-Modified-Since'] = cache[b'last_modified'].decode()
        
        response = self.session.get(url, headers=headers)
        
        if response.status_code == 304:
            # 未修改
            return False, None
        
        if response.status_code == 200:
            # 更新缓存
            cache_data = {}
            if 'ETag' in response.headers:
                cache_data['etag'] = response.headers['ETag']
            if 'Last-Modified' in response.headers:
                cache_data['last_modified'] = response.headers['Last-Modified']
            
            if cache_data:
                self.redis.hset(key, mapping=cache_data)
            
            return True, response
        
        return False, response

# 使用
checker = HTTPCacheChecker()

is_modified, response = checker.check_modified('https://example.com/feed.xml')
if is_modified:
    print("内容已更新")
    # 处理 response
else:
    print("内容未变化")
```

### 3.2 时间戳检测

```python
import redis
import time
from datetime import datetime

class TimestampChecker:
    """时间戳检测器"""
    
    def __init__(self, redis_url='redis://localhost:6379/0'):
        self.redis = redis.from_url(redis_url)
    
    def _key(self, url):
        return f"timestamp:{hashlib.md5(url.encode()).hexdigest()}"
    
    def should_update(self, url, update_interval=3600) -> bool:
        """
        检查是否需要更新
        update_interval: 更新间隔（秒）
        """
        key = self._key(url)
        last_crawl = self.redis.get(key)
        
        if last_crawl is None:
            return True
        
        last_crawl = float(last_crawl)
        return time.time() - last_crawl > update_interval
    
    def mark_updated(self, url):
        """标记更新时间"""
        key = self._key(url)
        self.redis.set(key, time.time())
    
    def get_last_update(self, url) -> datetime:
        """获取上次更新时间"""
        key = self._key(url)
        ts = self.redis.get(key)
        if ts:
            return datetime.fromtimestamp(float(ts))
        return None

# 使用
checker = TimestampChecker()

url = 'https://example.com/article/1'

if checker.should_update(url, update_interval=3600):
    print("需要更新")
    # 爬取
    checker.mark_updated(url)
else:
    print("无需更新")
```

### 3.3 版本号检测

```python
class VersionChecker:
    """版本号检测器"""
    
    def __init__(self, redis_url='redis://localhost:6379/0'):
        self.redis = redis.from_url(redis_url)
    
    def _key(self, item_id):
        return f"version:{item_id}"
    
    def is_new_version(self, item_id, version) -> bool:
        """检查是否是新版本"""
        key = self._key(item_id)
        old_version = self.redis.get(key)
        
        if old_version is None:
            self.redis.set(key, version)
            return True
        
        old_version = old_version.decode()
        
        if version != old_version:
            self.redis.set(key, version)
            return True
        
        return False

# 使用
checker = VersionChecker()

# 从 API 获取数据
data = {
    'id': '12345',
    'version': 'v2.0',
    'content': '...'
}

if checker.is_new_version(data['id'], data['version']):
    print("新版本，需要处理")
else:
    print("版本未变化")
```

---

## 4. 增量存储

### 4.1 增量数据库

```python
from datetime import datetime
import sqlite3
import hashlib

class IncrementalDB:
    """增量数据库"""
    
    def __init__(self, db_path='incremental.db'):
        self.conn = sqlite3.connect(db_path)
        self._init_db()
    
    def _init_db(self):
        """初始化数据库"""
        self.conn.execute('''
            CREATE TABLE IF NOT EXISTS items (
                id TEXT PRIMARY KEY,
                url TEXT UNIQUE,
                content_hash TEXT,
                created_at TIMESTAMP,
                updated_at TIMESTAMP,
                version INTEGER DEFAULT 1
            )
        ''')
        
        self.conn.execute('''
            CREATE INDEX IF NOT EXISTS idx_url ON items(url)
        ''')
        
        self.conn.commit()
    
    def _content_hash(self, content):
        return hashlib.sha256(content.encode()).hexdigest()
    
    def upsert(self, url, content) -> str:
        """
        插入或更新
        返回: 'new', 'updated', 'unchanged'
        """
        content_hash = self._content_hash(content)
        now = datetime.now()
        
        cursor = self.conn.execute(
            'SELECT id, content_hash, version FROM items WHERE url = ?',
            (url,)
        )
        row = cursor.fetchone()
        
        if row is None:
            # 新记录
            item_id = hashlib.md5(url.encode()).hexdigest()
            self.conn.execute('''
                INSERT INTO items (id, url, content_hash, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?)
            ''', (item_id, url, content_hash, now, now))
            self.conn.commit()
            return 'new'
        
        item_id, old_hash, version = row
        
        if old_hash != content_hash:
            # 内容更新
            self.conn.execute('''
                UPDATE items SET content_hash = ?, updated_at = ?, version = ?
                WHERE id = ?
            ''', (content_hash, now, version + 1, item_id))
            self.conn.commit()
            return 'updated'
        
        return 'unchanged'
    
    def get_new_items(self, since):
        """获取新增项目"""
        cursor = self.conn.execute(
            'SELECT url FROM items WHERE created_at > ?',
            (since,)
        )
        return [row[0] for row in cursor.fetchall()]
    
    def get_updated_items(self, since):
        """获取更新项目"""
        cursor = self.conn.execute(
            'SELECT url FROM items WHERE updated_at > ? AND created_at <= ?',
            (since, since)
        )
        return [row[0] for row in cursor.fetchall()]

# 使用
db = IncrementalDB()

result = db.upsert('https://example.com/1', '内容1')
print(f"结果: {result}")  # new

result = db.upsert('https://example.com/1', '内容1')
print(f"结果: {result}")  # unchanged

result = db.upsert('https://example.com/1', '更新的内容')
print(f"结果: {result}")  # updated
```

### 4.2 变更日志

```python
from datetime import datetime
import json

class ChangeLog:
    """变更日志"""
    
    def __init__(self, redis_url='redis://localhost:6379/0'):
        self.redis = redis.from_url(redis_url)
        self.key = 'changelog'
    
    def log(self, action, url, data=None):
        """记录变更"""
        entry = {
            'action': action,  # 'new', 'update', 'delete'
            'url': url,
            'data': data,
            'timestamp': datetime.now().isoformat()
        }
        
        self.redis.lpush(self.key, json.dumps(entry))
        
        # 保留最近 10000 条
        self.redis.ltrim(self.key, 0, 9999)
    
    def get_recent(self, count=100):
        """获取最近变更"""
        entries = self.redis.lrange(self.key, 0, count - 1)
        return [json.loads(e) for e in entries]
    
    def get_by_action(self, action, count=100):
        """按操作类型获取"""
        all_entries = self.get_recent(count * 10)
        return [e for e in all_entries if e['action'] == action][:count]

# 使用
log = ChangeLog()

log.log('new', 'https://example.com/1', {'title': '新文章'})
log.log('update', 'https://example.com/2', {'title': '更新文章'})

recent = log.get_recent(10)
for entry in recent:
    print(f"{entry['action']}: {entry['url']}")
```

---

## 5. 实战应用

### 5.1 完整增量爬虫

```python
import requests
from bs4 import BeautifulSoup
import hashlib
import redis
import time
from datetime import datetime
from dataclasses import dataclass
from typing import List, Optional
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class Article:
    url: str
    title: str
    content: str
    content_hash: str

class IncrementalCrawler:
    """增量爬虫"""
    
    def __init__(
        self,
        redis_url='redis://localhost:6379/0',
        update_interval=3600
    ):
        self.redis = redis.from_url(redis_url)
        self.update_interval = update_interval
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0...'
        })
    
    def _url_key(self, url):
        return f"url:{hashlib.md5(url.encode()).hexdigest()}"
    
    def _content_hash(self, content):
        return hashlib.sha256(content.encode()).hexdigest()
    
    def should_crawl(self, url) -> bool:
        """判断是否需要爬取"""
        key = self._url_key(url)
        data = self.redis.hgetall(key)
        
        if not data:
            return True
        
        last_crawl = float(data.get(b'last_crawl', 0))
        return time.time() - last_crawl > self.update_interval
    
    def is_content_changed(self, url, content) -> bool:
        """检查内容是否变化"""
        key = self._url_key(url)
        old_hash = self.redis.hget(key, 'content_hash')
        new_hash = self._content_hash(content)
        
        if old_hash:
            old_hash = old_hash.decode()
        
        return old_hash != new_hash
    
    def save_state(self, url, content_hash):
        """保存爬取状态"""
        key = self._url_key(url)
        self.redis.hset(key, mapping={
            'content_hash': content_hash,
            'last_crawl': time.time()
        })
    
    def fetch(self, url) -> Optional[str]:
        """获取页面"""
        try:
            response = self.session.get(url, timeout=10)
            response.raise_for_status()
            return response.text
        except Exception as e:
            logger.error(f"获取失败 {url}: {e}")
            return None
    
    def parse(self, url, html) -> Optional[Article]:
        """解析页面"""
        soup = BeautifulSoup(html, 'lxml')
        
        title = soup.select_one('h1, .title')
        title = title.get_text(strip=True) if title else ''
        
        content = soup.select_one('article, .content')
        content = content.get_text(strip=True) if content else ''
        
        if not title or not content:
            return None
        
        return Article(
            url=url,
            title=title,
            content=content,
            content_hash=self._content_hash(content)
        )
    
    def crawl_url(self, url) -> tuple:
        """
        爬取单个 URL
        返回: (status, article)
        status: 'new', 'updated', 'unchanged', 'skipped', 'error'
        """
        # 检查是否需要爬取
        if not self.should_crawl(url):
            return 'skipped', None
        
        # 获取页面
        html = self.fetch(url)
        if not html:
            return 'error', None
        
        # 解析
        article = self.parse(url, html)
        if not article:
            return 'error', None
        
        # 检查内容变化
        key = self._url_key(url)
        old_hash = self.redis.hget(key, 'content_hash')
        
        if old_hash is None:
            status = 'new'
        elif old_hash.decode() != article.content_hash:
            status = 'updated'
        else:
            status = 'unchanged'
        
        # 保存状态
        self.save_state(url, article.content_hash)
        
        return status, article
    
    def crawl(self, urls: List[str]) -> dict:
        """批量爬取"""
        stats = {'new': 0, 'updated': 0, 'unchanged': 0, 'skipped': 0, 'error': 0}
        articles = []
        
        for url in urls:
            status, article = self.crawl_url(url)
            stats[status] += 1
            
            if status in ('new', 'updated') and article:
                articles.append(article)
                logger.info(f"[{status}] {article.title}")
            
            time.sleep(0.5)  # 请求间隔
        
        return {
            'stats': stats,
            'articles': articles
        }

# 使用
crawler = IncrementalCrawler(update_interval=3600)

urls = [
    'https://example.com/article/1',
    'https://example.com/article/2',
    'https://example.com/article/3',
]

result = crawler.crawl(urls)
print(f"统计: {result['stats']}")
print(f"新增/更新文章: {len(result['articles'])}")
```

### 5.2 Scrapy 增量中间件

```python
# middlewares.py
import hashlib
import redis

class IncrementalMiddleware:
    """Scrapy 增量中间件"""
    
    def __init__(self, redis_url, update_interval):
        self.redis = redis.from_url(redis_url)
        self.update_interval = update_interval
    
    @classmethod
    def from_crawler(cls, crawler):
        return cls(
            redis_url=crawler.settings.get('REDIS_URL', 'redis://localhost:6379/0'),
            update_interval=crawler.settings.getint('UPDATE_INTERVAL', 3600)
        )
    
    def _url_key(self, url):
        return f"scrapy:url:{hashlib.md5(url.encode()).hexdigest()}"
    
    def process_request(self, request, spider):
        """处理请求"""
        if request.meta.get('force_crawl'):
            return None
        
        key = self._url_key(request.url)
        last_crawl = self.redis.hget(key, 'last_crawl')
        
        if last_crawl:
            import time
            last_crawl = float(last_crawl)
            if time.time() - last_crawl < self.update_interval:
                spider.logger.debug(f"跳过: {request.url}")
                from scrapy.exceptions import IgnoreRequest
                raise IgnoreRequest(f"Recently crawled: {request.url}")
        
        return None
    
    def process_response(self, request, response, spider):
        """处理响应"""
        import time
        
        key = self._url_key(request.url)
        content_hash = hashlib.sha256(response.body).hexdigest()
        
        old_hash = self.redis.hget(key, 'content_hash')
        
        if old_hash and old_hash.decode() == content_hash:
            request.meta['content_unchanged'] = True
        else:
            request.meta['content_unchanged'] = False
        
        self.redis.hset(key, mapping={
            'content_hash': content_hash,
            'last_crawl': time.time()
        })
        
        return response

# settings.py
DOWNLOADER_MIDDLEWARES = {
    'myproject.middlewares.IncrementalMiddleware': 543,
}
REDIS_URL = 'redis://localhost:6379/0'
UPDATE_INTERVAL = 3600
```

---

## 下一步

下一篇我们将学习爬虫监控与告警。

---

## 参考资料

- [Bloom Filter](https://en.wikipedia.org/wiki/Bloom_filter)
- [HTTP 缓存](https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Caching)
