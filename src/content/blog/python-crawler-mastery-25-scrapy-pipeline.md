---
title: "Scrapy Pipeline 数据处理"
description: "1. [Pipeline 基础](#1-pipeline-基础)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 25
---

> 本文介绍 Scrapy Pipeline 的使用，实现数据清洗、验证和存储。

---

## 目录

1. [Pipeline 基础](#1-pipeline-基础)
2. [数据清洗](#2-数据清洗)
3. [数据验证](#3-数据验证)
4. [数据存储](#4-数据存储)
5. [实战案例](#5-实战案例)

---

## 1. Pipeline 基础

### 1.1 Pipeline 作用

Pipeline 用于处理 Spider 提取的 Item：
- **数据清洗**：去除空白、格式化
- **数据验证**：检查必填字段
- **数据去重**：过滤重复数据
- **数据存储**：保存到数据库/文件

### 1.2 Pipeline 结构

```python
# pipelines.py

class MyPipeline:
    
    def open_spider(self, spider):
        """爬虫启动时调用"""
        pass
    
    def close_spider(self, spider):
        """爬虫关闭时调用"""
        pass
    
    def process_item(self, item, spider):
        """处理每个 Item"""
        # 处理逻辑
        return item  # 返回 Item 传递给下一个 Pipeline
        # 或 raise DropItem("reason")  # 丢弃 Item
```

### 1.3 启用 Pipeline

```python
# settings.py

ITEM_PIPELINES = {
    'myproject.pipelines.CleanPipeline': 100,     # 数字越小优先级越高
    'myproject.pipelines.ValidatePipeline': 200,
    'myproject.pipelines.DuplicatesPipeline': 300,
    'myproject.pipelines.DatabasePipeline': 400,
}
```

---

## 2. 数据清洗

### 2.1 基础清洗

```python
import re
from scrapy.exceptions import DropItem

class CleanPipeline:
    """数据清洗 Pipeline"""
    
    def process_item(self, item, spider):
        # 去除空白
        for field in item.fields:
            if field in item and isinstance(item[field], str):
                item[field] = item[field].strip()
        
        # 清洗标题
        if 'title' in item:
            item['title'] = self.clean_title(item['title'])
        
        # 清洗价格
        if 'price' in item:
            item['price'] = self.clean_price(item['price'])
        
        # 清洗日期
        if 'date' in item:
            item['date'] = self.clean_date(item['date'])
        
        return item
    
    def clean_title(self, title):
        """清洗标题"""
        if not title:
            return ''
        
        # 去除多余空白
        title = ' '.join(title.split())
        
        # 去除特殊字符
        title = re.sub(r'[\x00-\x1f\x7f-\x9f]', '', title)
        
        return title
    
    def clean_price(self, price):
        """清洗价格"""
        if not price:
            return 0.0
        
        # 提取数字
        match = re.search(r'[\d,]+\.?\d*', str(price))
        if match:
            price_str = match.group().replace(',', '')
            return float(price_str)
        
        return 0.0
    
    def clean_date(self, date_str):
        """清洗日期"""
        from datetime import datetime
        
        if not date_str:
            return None
        
        # 尝试多种格式
        formats = [
            '%Y-%m-%d',
            '%Y/%m/%d',
            '%Y年%m月%d日',
            '%d/%m/%Y',
            '%m/%d/%Y',
        ]
        
        for fmt in formats:
            try:
                return datetime.strptime(date_str.strip(), fmt)
            except ValueError:
                continue
        
        return None
```

### 2.2 HTML 清洗

```python
import re
from w3lib.html import remove_tags, replace_entities

class HTMLCleanPipeline:
    """HTML 清洗 Pipeline"""
    
    def process_item(self, item, spider):
        # 清洗 HTML 内容
        if 'content' in item:
            item['content'] = self.clean_html(item['content'])
        
        if 'description' in item:
            item['description'] = self.clean_html(item['description'])
        
        return item
    
    def clean_html(self, html):
        """清洗 HTML"""
        if not html:
            return ''
        
        # 移除 HTML 标签
        text = remove_tags(html)
        
        # 替换 HTML 实体
        text = replace_entities(text)
        
        # 去除多余空白
        text = re.sub(r'\s+', ' ', text).strip()
        
        return text
```

### 2.3 图片处理

```python
from scrapy.pipelines.images import ImagesPipeline
from scrapy import Request
import hashlib

class MyImagesPipeline(ImagesPipeline):
    """自定义图片 Pipeline"""
    
    def get_media_requests(self, item, info):
        """生成图片下载请求"""
        for image_url in item.get('image_urls', []):
            yield Request(image_url, meta={'item': item})
    
    def file_path(self, request, response=None, info=None, *, item=None):
        """自定义文件路径"""
        url = request.url
        image_guid = hashlib.md5(url.encode()).hexdigest()
        
        # 按分类存储
        category = item.get('category', 'default') if item else 'default'
        
        return f'{category}/{image_guid}.jpg'
    
    def item_completed(self, results, item, info):
        """下载完成后处理"""
        image_paths = [x['path'] for ok, x in results if ok]
        
        if not image_paths:
            # 没有成功下载的图片
            pass
        
        item['image_paths'] = image_paths
        return item

# settings.py
ITEM_PIPELINES = {
    'myproject.pipelines.MyImagesPipeline': 1,
}
IMAGES_STORE = '/path/to/images'
IMAGES_EXPIRES = 30  # 30 天过期
```

---

## 3. 数据验证

### 3.1 必填字段验证

```python
from scrapy.exceptions import DropItem

class ValidatePipeline:
    """数据验证 Pipeline"""
    
    # 必填字段
    REQUIRED_FIELDS = ['title', 'url']
    
    def process_item(self, item, spider):
        # 检查必填字段
        for field in self.REQUIRED_FIELDS:
            if not item.get(field):
                raise DropItem(f"缺少必填字段: {field}")
        
        # 验证 URL
        if 'url' in item:
            if not self.is_valid_url(item['url']):
                raise DropItem(f"无效 URL: {item['url']}")
        
        # 验证价格
        if 'price' in item:
            if not self.is_valid_price(item['price']):
                raise DropItem(f"无效价格: {item['price']}")
        
        return item
    
    def is_valid_url(self, url):
        """验证 URL"""
        import re
        pattern = r'^https?://[^\s<>"{}|\\^`\[\]]+'
        return bool(re.match(pattern, url))
    
    def is_valid_price(self, price):
        """验证价格"""
        try:
            p = float(price)
            return p >= 0
        except (ValueError, TypeError):
            return False
```

### 3.2 使用 ItemLoader

```python
from scrapy.loader import ItemLoader
from itemloaders.processors import TakeFirst, MapCompose, Join
from w3lib.html import remove_tags

class ProductLoader(ItemLoader):
    """商品 ItemLoader"""
    
    default_output_processor = TakeFirst()
    
    # 标题处理
    title_in = MapCompose(remove_tags, str.strip)
    
    # 价格处理
    price_in = MapCompose(remove_tags, str.strip, lambda x: x.replace('¥', ''))
    price_out = TakeFirst()
    
    # 描述处理
    description_in = MapCompose(remove_tags, str.strip)
    description_out = Join(' ')
    
    # 标签处理
    tags_out = lambda x: x  # 保持列表

# 在 Spider 中使用
def parse(self, response):
    loader = ProductLoader(item=ProductItem(), response=response)
    
    loader.add_xpath('title', '//h1/text()')
    loader.add_xpath('price', '//span[@class="price"]/text()')
    loader.add_css('description', '.description::text')
    loader.add_css('tags', '.tag::text')
    
    yield loader.load_item()
```

### 3.3 Schema 验证

```python
from scrapy.exceptions import DropItem

class SchemaPipeline:
    """Schema 验证 Pipeline"""
    
    SCHEMA = {
        'title': {'type': str, 'required': True, 'max_length': 200},
        'price': {'type': (int, float), 'required': True, 'min': 0},
        'url': {'type': str, 'required': True, 'pattern': r'^https?://'},
        'category': {'type': str, 'required': False},
    }
    
    def process_item(self, item, spider):
        errors = self.validate(item)
        
        if errors:
            raise DropItem(f"验证失败: {errors}")
        
        return item
    
    def validate(self, item):
        """验证 Item"""
        import re
        errors = []
        
        for field, rules in self.SCHEMA.items():
            value = item.get(field)
            
            # 必填检查
            if rules.get('required') and not value:
                errors.append(f"{field} 是必填字段")
                continue
            
            if value is None:
                continue
            
            # 类型检查
            if 'type' in rules:
                if not isinstance(value, rules['type']):
                    errors.append(f"{field} 类型错误")
            
            # 长度检查
            if 'max_length' in rules and isinstance(value, str):
                if len(value) > rules['max_length']:
                    errors.append(f"{field} 超过最大长度")
            
            # 最小值检查
            if 'min' in rules and isinstance(value, (int, float)):
                if value < rules['min']:
                    errors.append(f"{field} 小于最小值")
            
            # 正则检查
            if 'pattern' in rules and isinstance(value, str):
                if not re.match(rules['pattern'], value):
                    errors.append(f"{field} 格式不正确")
        
        return errors
```

---

## 4. 数据存储

### 4.1 JSON 存储

```python
import json

class JsonPipeline:
    """JSON 存储 Pipeline"""
    
    def open_spider(self, spider):
        self.file = open('items.json', 'w', encoding='utf-8')
        self.file.write('[\n')
        self.first_item = True
    
    def close_spider(self, spider):
        self.file.write('\n]')
        self.file.close()
    
    def process_item(self, item, spider):
        if not self.first_item:
            self.file.write(',\n')
        self.first_item = False
        
        line = json.dumps(dict(item), ensure_ascii=False)
        self.file.write(line)
        
        return item
```

### 4.2 MySQL 存储

```python
import pymysql
from scrapy.exceptions import DropItem

class MySQLPipeline:
    """MySQL 存储 Pipeline"""
    
    def __init__(self, host, database, user, password):
        self.host = host
        self.database = database
        self.user = user
        self.password = password
    
    @classmethod
    def from_crawler(cls, crawler):
        return cls(
            host=crawler.settings.get('MYSQL_HOST', 'localhost'),
            database=crawler.settings.get('MYSQL_DATABASE'),
            user=crawler.settings.get('MYSQL_USER'),
            password=crawler.settings.get('MYSQL_PASSWORD'),
        )
    
    def open_spider(self, spider):
        self.conn = pymysql.connect(
            host=self.host,
            database=self.database,
            user=self.user,
            password=self.password,
            charset='utf8mb4'
        )
        self.cursor = self.conn.cursor()
    
    def close_spider(self, spider):
        self.conn.commit()
        self.cursor.close()
        self.conn.close()
    
    def process_item(self, item, spider):
        try:
            self.cursor.execute('''
                INSERT INTO products (title, price, url, created_at)
                VALUES (%s, %s, %s, NOW())
                ON DUPLICATE KEY UPDATE
                price = VALUES(price),
                updated_at = NOW()
            ''', (item['title'], item['price'], item['url']))
            
            self.conn.commit()
        except Exception as e:
            spider.logger.error(f"MySQL 插入失败: {e}")
            self.conn.rollback()
        
        return item
```

### 4.3 MongoDB 存储

```python
import pymongo

class MongoPipeline:
    """MongoDB 存储 Pipeline"""
    
    def __init__(self, mongo_uri, mongo_db):
        self.mongo_uri = mongo_uri
        self.mongo_db = mongo_db
    
    @classmethod
    def from_crawler(cls, crawler):
        return cls(
            mongo_uri=crawler.settings.get('MONGO_URI', 'mongodb://localhost:27017'),
            mongo_db=crawler.settings.get('MONGO_DATABASE', 'scrapy')
        )
    
    def open_spider(self, spider):
        self.client = pymongo.MongoClient(self.mongo_uri)
        self.db = self.client[self.mongo_db]
    
    def close_spider(self, spider):
        self.client.close()
    
    def process_item(self, item, spider):
        collection = self.db[spider.name]
        
        # 使用 upsert
        collection.update_one(
            {'url': item['url']},
            {'$set': dict(item)},
            upsert=True
        )
        
        return item
```

### 4.4 去重 Pipeline

```python
from scrapy.exceptions import DropItem
import hashlib

class DuplicatesPipeline:
    """去重 Pipeline"""
    
    def __init__(self):
        self.seen = set()
    
    def process_item(self, item, spider):
        # 生成唯一标识
        unique_id = self.get_unique_id(item)
        
        if unique_id in self.seen:
            raise DropItem(f"重复 Item: {item.get('url', '')}")
        
        self.seen.add(unique_id)
        return item
    
    def get_unique_id(self, item):
        """生成唯一标识"""
        # 基于 URL
        if 'url' in item:
            return hashlib.md5(item['url'].encode()).hexdigest()
        
        # 基于多个字段
        key = f"{item.get('title', '')}-{item.get('price', '')}"
        return hashlib.md5(key.encode()).hexdigest()


class RedisDuplicatesPipeline:
    """Redis 去重 Pipeline"""
    
    def __init__(self, redis_url):
        self.redis_url = redis_url
    
    @classmethod
    def from_crawler(cls, crawler):
        return cls(
            redis_url=crawler.settings.get('REDIS_URL', 'redis://localhost:6379')
        )
    
    def open_spider(self, spider):
        import redis
        self.redis = redis.from_url(self.redis_url)
        self.key = f"scrapy:{spider.name}:seen"
    
    def process_item(self, item, spider):
        unique_id = hashlib.md5(item['url'].encode()).hexdigest()
        
        if self.redis.sismember(self.key, unique_id):
            raise DropItem(f"重复 Item: {item['url']}")
        
        self.redis.sadd(self.key, unique_id)
        return item
```

---

## 5. 实战案例

### 5.1 完整 Pipeline 配置

```python
# pipelines.py

from scrapy.exceptions import DropItem
import pymongo
import json
import logging

logger = logging.getLogger(__name__)


class CleanPipeline:
    """数据清洗"""
    
    def process_item(self, item, spider):
        # 清洗所有字符串字段
        for field in item.fields:
            if field in item and isinstance(item[field], str):
                item[field] = item[field].strip()
        
        return item


class ValidatePipeline:
    """数据验证"""
    
    REQUIRED = ['title', 'url']
    
    def process_item(self, item, spider):
        for field in self.REQUIRED:
            if not item.get(field):
                raise DropItem(f"缺少字段: {field}")
        
        return item


class DuplicatesPipeline:
    """去重"""
    
    def __init__(self):
        self.seen = set()
    
    def process_item(self, item, spider):
        url = item.get('url', '')
        
        if url in self.seen:
            raise DropItem(f"重复: {url}")
        
        self.seen.add(url)
        return item


class StatsPipeline:
    """统计"""
    
    def __init__(self):
        self.stats = {'total': 0, 'success': 0, 'dropped': 0}
    
    def process_item(self, item, spider):
        self.stats['total'] += 1
        self.stats['success'] += 1
        return item
    
    def close_spider(self, spider):
        logger.info(f"统计: {self.stats}")


class MongoPipeline:
    """MongoDB 存储"""
    
    @classmethod
    def from_crawler(cls, crawler):
        return cls(
            mongo_uri=crawler.settings.get('MONGO_URI'),
            mongo_db=crawler.settings.get('MONGO_DATABASE')
        )
    
    def __init__(self, mongo_uri, mongo_db):
        self.mongo_uri = mongo_uri
        self.mongo_db = mongo_db
    
    def open_spider(self, spider):
        self.client = pymongo.MongoClient(self.mongo_uri)
        self.db = self.client[self.mongo_db]
    
    def close_spider(self, spider):
        self.client.close()
    
    def process_item(self, item, spider):
        self.db[spider.name].update_one(
            {'url': item['url']},
            {'$set': dict(item)},
            upsert=True
        )
        return item


# settings.py
ITEM_PIPELINES = {
    'myproject.pipelines.CleanPipeline': 100,
    'myproject.pipelines.ValidatePipeline': 200,
    'myproject.pipelines.DuplicatesPipeline': 300,
    'myproject.pipelines.StatsPipeline': 400,
    'myproject.pipelines.MongoPipeline': 500,
}

MONGO_URI = 'mongodb://localhost:27017'
MONGO_DATABASE = 'scrapy_data'
```

---

## 下一步

下一篇我们将学习 Scrapy 中间件开发。

---

## 参考资料

- [Scrapy Item Pipeline](https://docs.scrapy.org/en/latest/topics/item-pipeline.html)
- [Scrapy Images Pipeline](https://docs.scrapy.org/en/latest/topics/media-pipeline.html)
