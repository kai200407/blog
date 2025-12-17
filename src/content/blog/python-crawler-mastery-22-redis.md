---
title: "Redis 缓存"
description: "1. [Redis 基础](#1-redis-基础)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 22
---

> 本文介绍如何使用 Redis 进行爬虫数据缓存和去重。

---

## 目录

1. [Redis 基础](#1-redis-基础)
2. [Python Redis 操作](#2-python-redis-操作)
3. [爬虫去重](#3-爬虫去重)
4. [任务队列](#4-任务队列)
5. [实战应用](#5-实战应用)

---

## 1. Redis 基础

### 1.1 Redis 特点

- **内存存储**：速度快
- **数据结构丰富**：字符串、列表、集合、哈希、有序集合
- **持久化**：RDB、AOF
- **原子操作**：线程安全

### 1.2 安装

```bash
# 安装 redis-py
pip install redis

# Docker 启动 Redis
docker run -d -p 6379:6379 --name redis redis:7-alpine
```

### 1.3 数据类型

| 类型 | 描述 | 爬虫用途 |
|------|------|----------|
| String | 字符串 | 缓存页面 |
| List | 列表 | 任务队列 |
| Set | 集合 | URL 去重 |
| Hash | 哈希 | 存储对象 |
| Sorted Set | 有序集合 | 优先级队列 |

---

## 2. Python Redis 操作

### 2.1 连接

```python
import redis

# 简单连接
r = redis.Redis(host='localhost', port=6379, db=0)

# 连接池
pool = redis.ConnectionPool(
    host='localhost',
    port=6379,
    db=0,
    max_connections=10,
    decode_responses=True  # 自动解码
)
r = redis.Redis(connection_pool=pool)

# URL 连接
r = redis.from_url('redis://localhost:6379/0')

# 测试连接
print(r.ping())  # True
```

### 2.2 字符串操作

```python
# 设置
r.set('key', 'value')
r.set('key', 'value', ex=3600)  # 过期时间（秒）
r.set('key', 'value', px=3600000)  # 过期时间（毫秒）
r.setnx('key', 'value')  # 不存在时设置

# 获取
value = r.get('key')

# 批量操作
r.mset({'k1': 'v1', 'k2': 'v2'})
values = r.mget(['k1', 'k2'])

# 自增
r.set('counter', 0)
r.incr('counter')  # 1
r.incrby('counter', 10)  # 11

# 过期
r.expire('key', 3600)
r.ttl('key')  # 剩余时间
```

### 2.3 列表操作

```python
# 添加
r.lpush('list', 'a', 'b', 'c')  # 左侧添加
r.rpush('list', 'd', 'e')  # 右侧添加

# 弹出
item = r.lpop('list')  # 左侧弹出
item = r.rpop('list')  # 右侧弹出
item = r.blpop('list', timeout=5)  # 阻塞弹出

# 获取
items = r.lrange('list', 0, -1)  # 所有元素
length = r.llen('list')  # 长度

# 索引
item = r.lindex('list', 0)  # 第一个元素
```

### 2.4 集合操作

```python
# 添加
r.sadd('set', 'a', 'b', 'c')

# 检查
exists = r.sismember('set', 'a')  # True

# 获取
members = r.smembers('set')  # 所有成员
count = r.scard('set')  # 数量

# 随机
item = r.srandmember('set')
item = r.spop('set')  # 随机弹出

# 集合运算
r.sadd('set1', 'a', 'b')
r.sadd('set2', 'b', 'c')
r.sinter('set1', 'set2')  # 交集 {'b'}
r.sunion('set1', 'set2')  # 并集 {'a', 'b', 'c'}
r.sdiff('set1', 'set2')   # 差集 {'a'}
```

### 2.5 哈希操作

```python
# 设置
r.hset('hash', 'field', 'value')
r.hmset('hash', {'f1': 'v1', 'f2': 'v2'})

# 获取
value = r.hget('hash', 'field')
values = r.hmget('hash', ['f1', 'f2'])
all_data = r.hgetall('hash')

# 检查
exists = r.hexists('hash', 'field')

# 删除
r.hdel('hash', 'field')

# 自增
r.hincrby('hash', 'count', 1)
```

### 2.6 有序集合

```python
# 添加（带分数）
r.zadd('zset', {'a': 1, 'b': 2, 'c': 3})

# 获取
items = r.zrange('zset', 0, -1)  # 按分数升序
items = r.zrevrange('zset', 0, -1)  # 按分数降序
items = r.zrange('zset', 0, -1, withscores=True)  # 带分数

# 分数范围
items = r.zrangebyscore('zset', 1, 2)

# 排名
rank = r.zrank('zset', 'a')  # 升序排名
rank = r.zrevrank('zset', 'a')  # 降序排名

# 分数
score = r.zscore('zset', 'a')
r.zincrby('zset', 1, 'a')  # 增加分数
```

---

## 3. 爬虫去重

### 3.1 Set 去重

```python
import redis
import hashlib

class URLDeduplicator:
    """URL 去重器"""
    
    def __init__(self, redis_url='redis://localhost:6379/0', key='visited_urls'):
        self.redis = redis.from_url(redis_url)
        self.key = key
    
    def _hash_url(self, url):
        """URL 哈希"""
        return hashlib.md5(url.encode()).hexdigest()
    
    def is_visited(self, url):
        """检查是否已访问"""
        url_hash = self._hash_url(url)
        return self.redis.sismember(self.key, url_hash)
    
    def mark_visited(self, url):
        """标记为已访问"""
        url_hash = self._hash_url(url)
        self.redis.sadd(self.key, url_hash)
    
    def add_if_not_exists(self, url):
        """添加 URL，返回是否新增"""
        url_hash = self._hash_url(url)
        return self.redis.sadd(self.key, url_hash) == 1
    
    def count(self):
        """已访问数量"""
        return self.redis.scard(self.key)
    
    def clear(self):
        """清空"""
        self.redis.delete(self.key)

# 使用
dedup = URLDeduplicator()

urls = [
    'https://example.com/1',
    'https://example.com/2',
    'https://example.com/1',  # 重复
]

for url in urls:
    if dedup.add_if_not_exists(url):
        print(f"新 URL: {url}")
    else:
        print(f"重复 URL: {url}")
```

### 3.2 Bloom Filter 去重

```python
# pip install pybloom-live

from pybloom_live import BloomFilter
import redis
import pickle

class BloomDeduplicator:
    """Bloom Filter 去重器（内存更小）"""
    
    def __init__(self, capacity=1000000, error_rate=0.001):
        self.bloom = BloomFilter(capacity=capacity, error_rate=error_rate)
    
    def is_visited(self, url):
        return url in self.bloom
    
    def mark_visited(self, url):
        self.bloom.add(url)
    
    def add_if_not_exists(self, url):
        if url in self.bloom:
            return False
        self.bloom.add(url)
        return True

# Redis Bloom Filter（使用 RedisBloom 模块）
class RedisBloomDeduplicator:
    """Redis Bloom Filter 去重器"""
    
    def __init__(self, redis_url='redis://localhost:6379/0', key='bloom_filter'):
        self.redis = redis.from_url(redis_url)
        self.key = key
    
    def create(self, capacity=1000000, error_rate=0.001):
        """创建 Bloom Filter"""
        try:
            self.redis.execute_command(
                'BF.RESERVE', self.key, error_rate, capacity
            )
        except:
            pass  # 已存在
    
    def add(self, url):
        """添加 URL"""
        return self.redis.execute_command('BF.ADD', self.key, url)
    
    def exists(self, url):
        """检查是否存在"""
        return self.redis.execute_command('BF.EXISTS', self.key, url)
    
    def add_if_not_exists(self, url):
        """添加并返回是否新增"""
        return self.add(url) == 1
```

### 3.3 增量去重

```python
import redis
import time

class IncrementalDeduplicator:
    """增量去重器（支持过期）"""
    
    def __init__(self, redis_url='redis://localhost:6379/0', key='visited', expire_days=7):
        self.redis = redis.from_url(redis_url)
        self.key = key
        self.expire_seconds = expire_days * 86400
    
    def is_visited(self, url):
        """检查是否已访问"""
        return self.redis.zscore(self.key, url) is not None
    
    def mark_visited(self, url):
        """标记为已访问"""
        now = time.time()
        self.redis.zadd(self.key, {url: now})
    
    def add_if_not_exists(self, url):
        """添加 URL，返回是否新增"""
        now = time.time()
        
        # 使用 NX 选项：仅当不存在时添加
        result = self.redis.zadd(self.key, {url: now}, nx=True)
        return result == 1
    
    def cleanup_expired(self):
        """清理过期 URL"""
        cutoff = time.time() - self.expire_seconds
        self.redis.zremrangebyscore(self.key, '-inf', cutoff)
    
    def count(self):
        return self.redis.zcard(self.key)
```

---

## 4. 任务队列

### 4.1 简单队列

```python
import redis
import json

class TaskQueue:
    """简单任务队列"""
    
    def __init__(self, redis_url='redis://localhost:6379/0', queue_name='task_queue'):
        self.redis = redis.from_url(redis_url)
        self.queue_name = queue_name
    
    def push(self, task):
        """添加任务"""
        self.redis.rpush(self.queue_name, json.dumps(task))
    
    def pop(self, timeout=0):
        """获取任务"""
        if timeout:
            result = self.redis.blpop(self.queue_name, timeout=timeout)
            if result:
                return json.loads(result[1])
            return None
        else:
            result = self.redis.lpop(self.queue_name)
            if result:
                return json.loads(result)
            return None
    
    def size(self):
        """队列大小"""
        return self.redis.llen(self.queue_name)
    
    def clear(self):
        """清空队列"""
        self.redis.delete(self.queue_name)

# 使用
queue = TaskQueue()

# 生产者
queue.push({'url': 'https://example.com/1', 'depth': 0})
queue.push({'url': 'https://example.com/2', 'depth': 0})

# 消费者
while True:
    task = queue.pop(timeout=5)
    if task is None:
        break
    print(f"处理: {task['url']}")
```

### 4.2 优先级队列

```python
import redis
import json
import time

class PriorityQueue:
    """优先级队列"""
    
    def __init__(self, redis_url='redis://localhost:6379/0', queue_name='priority_queue'):
        self.redis = redis.from_url(redis_url)
        self.queue_name = queue_name
    
    def push(self, task, priority=0):
        """添加任务（priority 越小优先级越高）"""
        self.redis.zadd(self.queue_name, {json.dumps(task): priority})
    
    def pop(self):
        """获取最高优先级任务"""
        # 获取并删除分数最低的元素
        result = self.redis.zpopmin(self.queue_name)
        if result:
            return json.loads(result[0][0])
        return None
    
    def size(self):
        return self.redis.zcard(self.queue_name)

# 使用
pq = PriorityQueue()

# 添加任务（优先级：0 最高）
pq.push({'url': 'https://example.com/important'}, priority=0)
pq.push({'url': 'https://example.com/normal'}, priority=5)
pq.push({'url': 'https://example.com/low'}, priority=10)

# 获取任务（按优先级）
while pq.size() > 0:
    task = pq.pop()
    print(f"处理: {task['url']}")
```

### 4.3 延迟队列

```python
import redis
import json
import time

class DelayQueue:
    """延迟队列"""
    
    def __init__(self, redis_url='redis://localhost:6379/0', queue_name='delay_queue'):
        self.redis = redis.from_url(redis_url)
        self.queue_name = queue_name
    
    def push(self, task, delay_seconds=0):
        """添加延迟任务"""
        execute_at = time.time() + delay_seconds
        self.redis.zadd(self.queue_name, {json.dumps(task): execute_at})
    
    def pop(self):
        """获取到期任务"""
        now = time.time()
        
        # 获取分数小于当前时间的任务
        results = self.redis.zrangebyscore(
            self.queue_name, '-inf', now, start=0, num=1
        )
        
        if results:
            task_str = results[0]
            # 删除任务
            if self.redis.zrem(self.queue_name, task_str):
                return json.loads(task_str)
        
        return None
    
    def pop_blocking(self, timeout=0):
        """阻塞获取到期任务"""
        end_time = time.time() + timeout if timeout else float('inf')
        
        while time.time() < end_time:
            task = self.pop()
            if task:
                return task
            time.sleep(0.1)
        
        return None

# 使用
dq = DelayQueue()

# 添加延迟任务
dq.push({'url': 'https://example.com/1'}, delay_seconds=0)   # 立即执行
dq.push({'url': 'https://example.com/2'}, delay_seconds=5)   # 5秒后执行
dq.push({'url': 'https://example.com/3'}, delay_seconds=10)  # 10秒后执行

# 处理任务
while True:
    task = dq.pop_blocking(timeout=15)
    if task is None:
        break
    print(f"处理: {task['url']}")
```

---

## 5. 实战应用

### 5.1 页面缓存

```python
import redis
import requests
import hashlib
import json

class PageCache:
    """页面缓存"""
    
    def __init__(self, redis_url='redis://localhost:6379/0', expire=3600):
        self.redis = redis.from_url(redis_url)
        self.expire = expire
    
    def _cache_key(self, url):
        return f"page:{hashlib.md5(url.encode()).hexdigest()}"
    
    def get(self, url):
        """获取缓存"""
        key = self._cache_key(url)
        data = self.redis.get(key)
        if data:
            return json.loads(data)
        return None
    
    def set(self, url, content, headers=None):
        """设置缓存"""
        key = self._cache_key(url)
        data = {
            'content': content,
            'headers': headers or {},
            'cached_at': time.time()
        }
        self.redis.setex(key, self.expire, json.dumps(data))
    
    def fetch(self, url, force=False):
        """获取页面（优先使用缓存）"""
        if not force:
            cached = self.get(url)
            if cached:
                return cached['content']
        
        response = requests.get(url)
        self.set(url, response.text, dict(response.headers))
        return response.text

# 使用
cache = PageCache(expire=3600)

# 第一次请求（从网络获取）
content = cache.fetch('https://example.com')

# 第二次请求（从缓存获取）
content = cache.fetch('https://example.com')
```

### 5.2 分布式爬虫状态

```python
import redis
import json
import time

class CrawlerState:
    """分布式爬虫状态管理"""
    
    def __init__(self, redis_url='redis://localhost:6379/0', crawler_id='crawler'):
        self.redis = redis.from_url(redis_url)
        self.crawler_id = crawler_id
    
    def heartbeat(self):
        """心跳"""
        key = f"crawler:{self.crawler_id}:heartbeat"
        self.redis.setex(key, 30, time.time())
    
    def is_alive(self, crawler_id):
        """检查爬虫是否存活"""
        key = f"crawler:{crawler_id}:heartbeat"
        return self.redis.exists(key)
    
    def update_stats(self, stats):
        """更新统计"""
        key = f"crawler:{self.crawler_id}:stats"
        self.redis.hset(key, mapping=stats)
    
    def get_stats(self, crawler_id=None):
        """获取统计"""
        crawler_id = crawler_id or self.crawler_id
        key = f"crawler:{crawler_id}:stats"
        return self.redis.hgetall(key)
    
    def incr_stat(self, field, amount=1):
        """增加统计"""
        key = f"crawler:{self.crawler_id}:stats"
        self.redis.hincrby(key, field, amount)
    
    def get_all_crawlers(self):
        """获取所有活跃爬虫"""
        pattern = "crawler:*:heartbeat"
        keys = self.redis.keys(pattern)
        return [k.decode().split(':')[1] for k in keys]

# 使用
state = CrawlerState(crawler_id='worker-1')

# 定期心跳
state.heartbeat()

# 更新统计
state.incr_stat('pages_crawled')
state.incr_stat('items_scraped', 5)

# 获取统计
print(state.get_stats())
```

### 5.3 请求限流

```python
import redis
import time

class RateLimiter:
    """请求限流器"""
    
    def __init__(self, redis_url='redis://localhost:6379/0'):
        self.redis = redis.from_url(redis_url)
    
    def is_allowed(self, key, limit, window):
        """
        检查是否允许请求
        key: 限流键
        limit: 窗口内最大请求数
        window: 时间窗口（秒）
        """
        now = time.time()
        window_start = now - window
        
        pipe = self.redis.pipeline()
        
        # 移除窗口外的请求
        pipe.zremrangebyscore(key, '-inf', window_start)
        
        # 统计窗口内请求数
        pipe.zcard(key)
        
        # 添加当前请求
        pipe.zadd(key, {str(now): now})
        
        # 设置过期时间
        pipe.expire(key, window)
        
        results = pipe.execute()
        current_count = results[1]
        
        return current_count < limit
    
    def wait_if_needed(self, key, limit, window):
        """等待直到允许请求"""
        while not self.is_allowed(key, limit, window):
            time.sleep(0.1)

# 使用
limiter = RateLimiter()

# 每秒最多 10 个请求
for i in range(20):
    if limiter.is_allowed('api:example.com', limit=10, window=1):
        print(f"请求 {i}: 允许")
    else:
        print(f"请求 {i}: 限流")
    time.sleep(0.05)
```

---

## 下一步

下一篇我们将学习 Scrapy 框架入门。

---

## 参考资料

- [redis-py 文档](https://redis-py.readthedocs.io/)
- [Redis 命令参考](https://redis.io/commands/)
- [RedisBloom](https://redis.io/docs/stack/bloom/)
