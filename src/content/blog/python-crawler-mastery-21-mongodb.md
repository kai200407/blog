---
title: "MongoDB 存储"
description: "1. [MongoDB 基础](#1-mongodb-基础)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 21
---

> 本文介绍如何使用 MongoDB 存储爬虫数据，适合存储非结构化数据。

---

## 目录

1. [MongoDB 基础](#1-mongodb-基础)
2. [PyMongo 使用](#2-pymongo-使用)
3. [数据操作](#3-数据操作)
4. [索引与性能](#4-索引与性能)
5. [实战应用](#5-实战应用)

---

## 1. MongoDB 基础

### 1.1 MongoDB 特点

- **文档型数据库**：存储 JSON 格式文档
- **灵活模式**：无需预定义结构
- **高性能**：支持索引、分片
- **易扩展**：水平扩展能力强

### 1.2 核心概念

| SQL | MongoDB | 说明 |
|-----|---------|------|
| Database | Database | 数据库 |
| Table | Collection | 集合 |
| Row | Document | 文档 |
| Column | Field | 字段 |
| Index | Index | 索引 |
| Primary Key | _id | 主键 |

### 1.3 安装

```bash
# 安装 PyMongo
pip install pymongo

# Docker 启动 MongoDB
docker run -d -p 27017:27017 --name mongodb mongo:6
```

---

## 2. PyMongo 使用

### 2.1 连接数据库

```python
from pymongo import MongoClient

# 连接
client = MongoClient('mongodb://localhost:27017/')

# 带认证
client = MongoClient('mongodb://user:password@localhost:27017/')

# 连接选项
client = MongoClient(
    'mongodb://localhost:27017/',
    maxPoolSize=50,
    minPoolSize=10,
    serverSelectionTimeoutMS=5000
)

# 选择数据库
db = client['crawler']

# 选择集合
collection = db['articles']

# 或者
collection = client.crawler.articles
```

### 2.2 插入文档

```python
from datetime import datetime

# 插入单个文档
doc = {
    'title': '文章标题',
    'url': 'https://example.com/article/1',
    'content': '文章内容...',
    'tags': ['Python', '爬虫'],
    'created_at': datetime.now()
}

result = collection.insert_one(doc)
print(f"插入 ID: {result.inserted_id}")

# 插入多个文档
docs = [
    {'title': '文章1', 'url': 'https://example.com/1'},
    {'title': '文章2', 'url': 'https://example.com/2'},
    {'title': '文章3', 'url': 'https://example.com/3'}
]

result = collection.insert_many(docs)
print(f"插入 {len(result.inserted_ids)} 个文档")
```

### 2.3 查询文档

```python
# 查询单个
doc = collection.find_one({'title': '文章标题'})
print(doc)

# 查询多个
docs = collection.find({'tags': 'Python'})
for doc in docs:
    print(doc['title'])

# 条件查询
docs = collection.find({
    'created_at': {'$gte': datetime(2024, 1, 1)}
})

# 限制字段
docs = collection.find(
    {'tags': 'Python'},
    {'title': 1, 'url': 1, '_id': 0}  # 只返回 title 和 url
)

# 排序
docs = collection.find().sort('created_at', -1)  # -1 降序

# 分页
docs = collection.find().skip(10).limit(10)

# 计数
count = collection.count_documents({'tags': 'Python'})
```

### 2.4 更新文档

```python
# 更新单个
result = collection.update_one(
    {'url': 'https://example.com/1'},
    {'$set': {'title': '新标题', 'updated_at': datetime.now()}}
)
print(f"匹配 {result.matched_count}, 修改 {result.modified_count}")

# 更新多个
result = collection.update_many(
    {'tags': 'Python'},
    {'$addToSet': {'tags': '编程'}}  # 添加标签
)

# upsert（不存在则插入）
result = collection.update_one(
    {'url': 'https://example.com/new'},
    {'$set': {'title': '新文章'}},
    upsert=True
)

# 替换文档
collection.replace_one(
    {'url': 'https://example.com/1'},
    {'title': '完全替换', 'url': 'https://example.com/1'}
)
```

### 2.5 删除文档

```python
# 删除单个
result = collection.delete_one({'url': 'https://example.com/1'})
print(f"删除 {result.deleted_count} 个")

# 删除多个
result = collection.delete_many({'tags': 'test'})

# 删除所有
collection.delete_many({})

# 删除集合
collection.drop()
```

---

## 3. 数据操作

### 3.1 查询操作符

```python
# 比较操作符
collection.find({'views': {'$gt': 100}})    # 大于
collection.find({'views': {'$gte': 100}})   # 大于等于
collection.find({'views': {'$lt': 100}})    # 小于
collection.find({'views': {'$lte': 100}})   # 小于等于
collection.find({'views': {'$ne': 100}})    # 不等于
collection.find({'views': {'$in': [100, 200]}})   # 在列表中
collection.find({'views': {'$nin': [100, 200]}})  # 不在列表中

# 逻辑操作符
collection.find({
    '$and': [
        {'views': {'$gt': 100}},
        {'tags': 'Python'}
    ]
})

collection.find({
    '$or': [
        {'tags': 'Python'},
        {'tags': 'JavaScript'}
    ]
})

collection.find({
    'views': {'$not': {'$gt': 100}}
})

# 元素操作符
collection.find({'tags': {'$exists': True}})   # 字段存在
collection.find({'views': {'$type': 'int'}})   # 类型匹配

# 数组操作符
collection.find({'tags': {'$all': ['Python', '爬虫']}})  # 包含所有
collection.find({'tags': {'$size': 3}})  # 数组长度
collection.find({'tags': {'$elemMatch': {'$regex': '^P'}}})

# 正则表达式
collection.find({'title': {'$regex': '.*Python.*', '$options': 'i'}})
```

### 3.2 更新操作符

```python
# 字段操作
collection.update_one(
    {'_id': doc_id},
    {
        '$set': {'title': '新标题'},      # 设置字段
        '$unset': {'temp': ''},           # 删除字段
        '$rename': {'old': 'new'},        # 重命名
        '$inc': {'views': 1},             # 增加
        '$mul': {'price': 0.9},           # 乘以
        '$min': {'low': 10},              # 取最小
        '$max': {'high': 100},            # 取最大
        '$currentDate': {'updated': True} # 当前时间
    }
)

# 数组操作
collection.update_one(
    {'_id': doc_id},
    {
        '$push': {'tags': 'new_tag'},           # 添加元素
        '$addToSet': {'tags': 'unique_tag'},    # 添加唯一元素
        '$pop': {'tags': 1},                    # 移除最后一个
        '$pull': {'tags': 'remove_tag'},        # 移除指定元素
        '$pullAll': {'tags': ['a', 'b']}        # 移除多个
    }
)

# 批量添加
collection.update_one(
    {'_id': doc_id},
    {'$push': {'tags': {'$each': ['a', 'b', 'c']}}}
)
```

### 3.3 聚合管道

```python
# 聚合查询
pipeline = [
    # 匹配
    {'$match': {'tags': 'Python'}},
    
    # 分组
    {'$group': {
        '_id': '$author',
        'count': {'$sum': 1},
        'total_views': {'$sum': '$views'},
        'avg_views': {'$avg': '$views'}
    }},
    
    # 排序
    {'$sort': {'count': -1}},
    
    # 限制
    {'$limit': 10},
    
    # 投影
    {'$project': {
        'author': '$_id',
        'count': 1,
        'avg_views': {'$round': ['$avg_views', 2]}
    }}
]

results = collection.aggregate(pipeline)
for doc in results:
    print(doc)

# 常用聚合阶段
# $match - 过滤
# $group - 分组
# $sort - 排序
# $limit - 限制
# $skip - 跳过
# $project - 投影
# $unwind - 展开数组
# $lookup - 关联查询
# $count - 计数
```

---

## 4. 索引与性能

### 4.1 创建索引

```python
# 单字段索引
collection.create_index('url')

# 唯一索引
collection.create_index('url', unique=True)

# 复合索引
collection.create_index([('author', 1), ('created_at', -1)])

# 文本索引
collection.create_index([('title', 'text'), ('content', 'text')])

# TTL 索引（自动过期）
collection.create_index('created_at', expireAfterSeconds=86400)

# 查看索引
for index in collection.list_indexes():
    print(index)

# 删除索引
collection.drop_index('url_1')
collection.drop_indexes()  # 删除所有
```

### 4.2 查询优化

```python
# 使用 explain 分析查询
result = collection.find({'tags': 'Python'}).explain()
print(result['executionStats'])

# 批量操作
from pymongo import InsertOne, UpdateOne, DeleteOne

operations = [
    InsertOne({'title': 'doc1'}),
    UpdateOne({'title': 'doc2'}, {'$set': {'updated': True}}),
    DeleteOne({'title': 'doc3'})
]

result = collection.bulk_write(operations, ordered=False)
print(f"插入: {result.inserted_count}, 修改: {result.modified_count}")
```

---

## 5. 实战应用

### 5.1 爬虫数据存储

```python
from pymongo import MongoClient
from datetime import datetime
from typing import Dict, List, Optional
import hashlib

class MongoStorage:
    """MongoDB 存储类"""
    
    def __init__(self, uri: str = 'mongodb://localhost:27017/', db_name: str = 'crawler'):
        self.client = MongoClient(uri)
        self.db = self.client[db_name]
        self._init_indexes()
    
    def _init_indexes(self):
        """初始化索引"""
        # 文章集合
        self.db.articles.create_index('url', unique=True)
        self.db.articles.create_index('crawled_at')
        self.db.articles.create_index([('title', 'text'), ('content', 'text')])
        
        # 图片集合
        self.db.images.create_index('url', unique=True)
        self.db.images.create_index('article_id')
    
    def save_article(self, article: Dict) -> Optional[str]:
        """保存文章"""
        article['crawled_at'] = datetime.now()
        article['url_hash'] = hashlib.md5(article['url'].encode()).hexdigest()
        
        try:
            result = self.db.articles.update_one(
                {'url': article['url']},
                {'$set': article},
                upsert=True
            )
            return str(result.upserted_id) if result.upserted_id else None
        except Exception as e:
            print(f"保存失败: {e}")
            return None
    
    def save_articles(self, articles: List[Dict]) -> int:
        """批量保存文章"""
        from pymongo import UpdateOne
        
        operations = []
        for article in articles:
            article['crawled_at'] = datetime.now()
            operations.append(
                UpdateOne(
                    {'url': article['url']},
                    {'$set': article},
                    upsert=True
                )
            )
        
        if operations:
            result = self.db.articles.bulk_write(operations, ordered=False)
            return result.upserted_count + result.modified_count
        return 0
    
    def get_article(self, url: str) -> Optional[Dict]:
        """获取文章"""
        return self.db.articles.find_one({'url': url})
    
    def search_articles(self, keyword: str, limit: int = 20) -> List[Dict]:
        """搜索文章"""
        return list(self.db.articles.find(
            {'$text': {'$search': keyword}},
            {'score': {'$meta': 'textScore'}}
        ).sort([('score', {'$meta': 'textScore'})]).limit(limit))
    
    def get_recent_articles(self, limit: int = 50) -> List[Dict]:
        """获取最新文章"""
        return list(self.db.articles.find().sort('crawled_at', -1).limit(limit))
    
    def is_crawled(self, url: str) -> bool:
        """检查是否已爬取"""
        return self.db.articles.find_one({'url': url}) is not None
    
    def get_stats(self) -> Dict:
        """获取统计信息"""
        return {
            'total_articles': self.db.articles.count_documents({}),
            'today_articles': self.db.articles.count_documents({
                'crawled_at': {'$gte': datetime.now().replace(hour=0, minute=0, second=0)}
            })
        }
    
    def close(self):
        """关闭连接"""
        self.client.close()

# 使用
storage = MongoStorage()

# 保存文章
storage.save_article({
    'title': '文章标题',
    'url': 'https://example.com/article/1',
    'content': '文章内容...',
    'author': '作者',
    'tags': ['Python', '爬虫']
})

# 搜索
results = storage.search_articles('Python')
for article in results:
    print(article['title'])

# 统计
print(storage.get_stats())
```

### 5.2 Scrapy Pipeline

```python
# pipelines.py
from pymongo import MongoClient
from datetime import datetime

class MongoPipeline:
    """Scrapy MongoDB Pipeline"""
    
    def __init__(self, mongo_uri, mongo_db):
        self.mongo_uri = mongo_uri
        self.mongo_db = mongo_db
    
    @classmethod
    def from_crawler(cls, crawler):
        return cls(
            mongo_uri=crawler.settings.get('MONGO_URI', 'mongodb://localhost:27017/'),
            mongo_db=crawler.settings.get('MONGO_DATABASE', 'crawler')
        )
    
    def open_spider(self, spider):
        self.client = MongoClient(self.mongo_uri)
        self.db = self.client[self.mongo_db]
        
        # 创建索引
        self.db[spider.name].create_index('url', unique=True)
    
    def close_spider(self, spider):
        self.client.close()
    
    def process_item(self, item, spider):
        item_dict = dict(item)
        item_dict['crawled_at'] = datetime.now()
        item_dict['spider'] = spider.name
        
        self.db[spider.name].update_one(
            {'url': item_dict['url']},
            {'$set': item_dict},
            upsert=True
        )
        
        return item

# settings.py
ITEM_PIPELINES = {
    'myproject.pipelines.MongoPipeline': 300,
}
MONGO_URI = 'mongodb://localhost:27017/'
MONGO_DATABASE = 'crawler'
```

### 5.3 异步 MongoDB

```python
import asyncio
from motor.motor_asyncio import AsyncIOMotorClient
from typing import Dict, List

class AsyncMongoStorage:
    """异步 MongoDB 存储"""
    
    def __init__(self, uri: str = 'mongodb://localhost:27017/', db_name: str = 'crawler'):
        self.client = AsyncIOMotorClient(uri)
        self.db = self.client[db_name]
    
    async def save_article(self, article: Dict):
        await self.db.articles.update_one(
            {'url': article['url']},
            {'$set': article},
            upsert=True
        )
    
    async def save_articles(self, articles: List[Dict]):
        from pymongo import UpdateOne
        
        operations = [
            UpdateOne({'url': a['url']}, {'$set': a}, upsert=True)
            for a in articles
        ]
        
        if operations:
            await self.db.articles.bulk_write(operations)
    
    async def get_article(self, url: str) -> Dict:
        return await self.db.articles.find_one({'url': url})
    
    async def get_articles(self, limit: int = 50) -> List[Dict]:
        cursor = self.db.articles.find().limit(limit)
        return await cursor.to_list(length=limit)

# 使用
async def main():
    storage = AsyncMongoStorage()
    
    await storage.save_article({
        'title': '测试',
        'url': 'https://example.com/1'
    })
    
    articles = await storage.get_articles()
    print(articles)

asyncio.run(main())
```

---

## 下一步

下一篇我们将学习 Redis 缓存的使用。

---

## 参考资料

- [PyMongo 文档](https://pymongo.readthedocs.io/)
- [MongoDB 文档](https://docs.mongodb.com/)
- [Motor 异步驱动](https://motor.readthedocs.io/)
