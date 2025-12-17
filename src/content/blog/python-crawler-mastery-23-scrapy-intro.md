---
title: "Scrapy 入门"
description: "1. [Scrapy 概述](#1-scrapy-概述)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 23
---

> 本文介绍 Scrapy 爬虫框架的基础使用，包括项目结构、Spider 编写和数据处理。

---

## 目录

1. [Scrapy 概述](#1-scrapy-概述)
2. [项目创建](#2-项目创建)
3. [Spider 编写](#3-spider-编写)
4. [数据提取](#4-数据提取)
5. [Pipeline 处理](#5-pipeline-处理)

---

## 1. Scrapy 概述

### 1.1 什么是 Scrapy

Scrapy 是一个快速、高层次的 Web 爬虫框架，用于抓取网站并从页面中提取结构化数据。

### 1.2 架构组件

```
                                        ┌─────────────┐
                                        │   Spider    │
                                        └──────┬──────┘
                                               │
                    ┌──────────────────────────┼──────────────────────────┐
                    │                          ▼                          │
              ┌─────┴─────┐              ┌─────────────┐            ┌─────┴─────┐
              │  Engine   │◄────────────►│  Scheduler  │            │  Pipeline │
              └─────┬─────┘              └─────────────┘            └───────────┘
                    │
                    ▼
           ┌───────────────┐
           │  Downloader   │
           └───────────────┘
                    │
                    ▼
           ┌───────────────┐
           │   Internet    │
           └───────────────┘
```

| 组件 | 功能 |
|------|------|
| Engine | 控制数据流，触发事件 |
| Scheduler | 接收请求，按顺序调度 |
| Downloader | 下载网页，返回响应 |
| Spider | 解析响应，提取数据和新请求 |
| Pipeline | 处理提取的数据 |
| Middleware | 处理请求和响应的钩子 |

### 1.3 安装

```bash
pip install scrapy
```

---

## 2. 项目创建

### 2.1 创建项目

```bash
# 创建项目
scrapy startproject myproject

# 项目结构
myproject/
├── scrapy.cfg              # 部署配置
└── myproject/
    ├── __init__.py
    ├── items.py            # 数据模型
    ├── middlewares.py      # 中间件
    ├── pipelines.py        # 数据处理管道
    ├── settings.py         # 项目设置
    └── spiders/            # 爬虫目录
        └── __init__.py
```

### 2.2 创建 Spider

```bash
cd myproject
scrapy genspider example example.com
```

### 2.3 运行 Spider

```bash
# 运行爬虫
scrapy crawl example

# 输出到文件
scrapy crawl example -o output.json
scrapy crawl example -o output.csv

# 指定日志级别
scrapy crawl example --loglevel=INFO
```

---

## 3. Spider 编写

### 3.1 基本 Spider

```python
# spiders/example.py
import scrapy

class ExampleSpider(scrapy.Spider):
    name = 'example'
    allowed_domains = ['example.com']
    start_urls = ['https://example.com']
    
    def parse(self, response):
        # 提取数据
        title = response.css('title::text').get()
        
        yield {
            'title': title,
            'url': response.url
        }
        
        # 跟踪链接
        for link in response.css('a::attr(href)').getall():
            yield response.follow(link, callback=self.parse)
```

### 3.2 带分页的 Spider

```python
import scrapy

class NewsSpider(scrapy.Spider):
    name = 'news'
    start_urls = ['https://news.example.com/page/1']
    
    def parse(self, response):
        # 提取新闻列表
        for article in response.css('article.news-item'):
            yield {
                'title': article.css('h2::text').get(),
                'summary': article.css('p.summary::text').get(),
                'url': article.css('a::attr(href)').get(),
            }
        
        # 下一页
        next_page = response.css('a.next-page::attr(href)').get()
        if next_page:
            yield response.follow(next_page, callback=self.parse)
```

### 3.3 带详情页的 Spider

```python
import scrapy

class ProductSpider(scrapy.Spider):
    name = 'products'
    start_urls = ['https://shop.example.com/products']
    
    def parse(self, response):
        # 列表页：提取产品链接
        for product_link in response.css('a.product-link::attr(href)').getall():
            yield response.follow(product_link, callback=self.parse_product)
        
        # 下一页
        next_page = response.css('a.next::attr(href)').get()
        if next_page:
            yield response.follow(next_page, callback=self.parse)
    
    def parse_product(self, response):
        # 详情页：提取产品信息
        yield {
            'name': response.css('h1.product-name::text').get(),
            'price': response.css('span.price::text').get(),
            'description': response.css('div.description::text').get(),
            'images': response.css('img.product-image::attr(src)').getall(),
            'url': response.url,
        }
```

### 3.4 CrawlSpider

```python
from scrapy.spiders import CrawlSpider, Rule
from scrapy.linkextractors import LinkExtractor

class MyCrawlSpider(CrawlSpider):
    name = 'mycrawl'
    allowed_domains = ['example.com']
    start_urls = ['https://example.com']
    
    rules = (
        # 跟踪分类页面
        Rule(LinkExtractor(allow=r'/category/\w+'), follow=True),
        
        # 提取产品页面
        Rule(LinkExtractor(allow=r'/product/\d+'), callback='parse_product'),
    )
    
    def parse_product(self, response):
        yield {
            'name': response.css('h1::text').get(),
            'price': response.css('.price::text').get(),
        }
```

---

## 4. 数据提取

### 4.1 CSS 选择器

```python
def parse(self, response):
    # 获取单个元素
    title = response.css('h1::text').get()
    
    # 获取所有元素
    links = response.css('a::attr(href)').getall()
    
    # 获取属性
    img_src = response.css('img::attr(src)').get()
    
    # 嵌套选择
    for item in response.css('div.item'):
        yield {
            'title': item.css('h2::text').get(),
            'link': item.css('a::attr(href)').get(),
        }
```

### 4.2 XPath

```python
def parse(self, response):
    # 获取文本
    title = response.xpath('//h1/text()').get()
    
    # 获取属性
    href = response.xpath('//a/@href').get()
    
    # 条件查询
    price = response.xpath('//span[@class="price"]/text()').get()
    
    # 包含文本
    link = response.xpath('//a[contains(text(), "更多")]/@href').get()
    
    # 遍历
    for item in response.xpath('//div[@class="item"]'):
        yield {
            'title': item.xpath('.//h2/text()').get(),
            'desc': item.xpath('.//p/text()').get(),
        }
```

### 4.3 正则提取

```python
import re

def parse(self, response):
    # 使用 re() 方法
    prices = response.css('span.price::text').re(r'\d+\.?\d*')
    
    # 使用 re_first()
    price = response.css('span.price::text').re_first(r'\d+\.?\d*')
    
    # 结合 Python re
    text = response.css('div.content::text').get()
    phone = re.search(r'1[3-9]\d{9}', text)
```

---

## 5. Pipeline 处理

### 5.1 定义 Item

```python
# items.py
import scrapy

class ProductItem(scrapy.Item):
    name = scrapy.Field()
    price = scrapy.Field()
    description = scrapy.Field()
    url = scrapy.Field()
    crawled_at = scrapy.Field()
```

### 5.2 使用 Item

```python
# spiders/product.py
from myproject.items import ProductItem

class ProductSpider(scrapy.Spider):
    name = 'product'
    
    def parse(self, response):
        item = ProductItem()
        item['name'] = response.css('h1::text').get()
        item['price'] = response.css('.price::text').get()
        item['url'] = response.url
        yield item
```

### 5.3 编写 Pipeline

```python
# pipelines.py
import json
from datetime import datetime

class CleanPipeline:
    """数据清洗"""
    
    def process_item(self, item, spider):
        # 清洗价格
        if 'price' in item and item['price']:
            item['price'] = float(item['price'].replace('¥', '').strip())
        
        # 添加时间戳
        item['crawled_at'] = datetime.now().isoformat()
        
        return item

class JsonPipeline:
    """保存为 JSON"""
    
    def open_spider(self, spider):
        self.file = open('output.json', 'w', encoding='utf-8')
        self.file.write('[')
        self.first = True
    
    def close_spider(self, spider):
        self.file.write(']')
        self.file.close()
    
    def process_item(self, item, spider):
        if not self.first:
            self.file.write(',\n')
        self.first = False
        
        line = json.dumps(dict(item), ensure_ascii=False)
        self.file.write(line)
        
        return item

class DatabasePipeline:
    """保存到数据库"""
    
    def open_spider(self, spider):
        import sqlite3
        self.conn = sqlite3.connect('products.db')
        self.cursor = self.conn.cursor()
        self.cursor.execute('''
            CREATE TABLE IF NOT EXISTS products (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT,
                price REAL,
                url TEXT,
                crawled_at TEXT
            )
        ''')
    
    def close_spider(self, spider):
        self.conn.commit()
        self.conn.close()
    
    def process_item(self, item, spider):
        self.cursor.execute('''
            INSERT INTO products (name, price, url, crawled_at)
            VALUES (?, ?, ?, ?)
        ''', (item['name'], item['price'], item['url'], item['crawled_at']))
        
        return item
```

### 5.4 启用 Pipeline

```python
# settings.py
ITEM_PIPELINES = {
    'myproject.pipelines.CleanPipeline': 100,
    'myproject.pipelines.JsonPipeline': 200,
    'myproject.pipelines.DatabasePipeline': 300,
}
```

---

## 常用设置

```python
# settings.py

# 基本设置
BOT_NAME = 'myproject'
ROBOTSTXT_OBEY = True

# 并发设置
CONCURRENT_REQUESTS = 16
CONCURRENT_REQUESTS_PER_DOMAIN = 8
DOWNLOAD_DELAY = 1

# 请求头
DEFAULT_REQUEST_HEADERS = {
    'Accept': 'text/html,application/xhtml+xml',
    'Accept-Language': 'zh-CN,zh;q=0.9',
}
USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'

# 重试
RETRY_ENABLED = True
RETRY_TIMES = 3
RETRY_HTTP_CODES = [500, 502, 503, 504, 408]

# 日志
LOG_LEVEL = 'INFO'
LOG_FILE = 'scrapy.log'

# 缓存
HTTPCACHE_ENABLED = True
HTTPCACHE_EXPIRATION_SECS = 86400
HTTPCACHE_DIR = 'httpcache'

# 管道
ITEM_PIPELINES = {
    'myproject.pipelines.CleanPipeline': 100,
}
```

---

## 下一步

下一篇我们将学习 Scrapy 进阶，包括中间件、扩展和分布式爬取。

---

## 参考资料

- [Scrapy 官方文档](https://docs.scrapy.org/)
- [Scrapy 教程](https://docs.scrapy.org/en/latest/intro/tutorial.html)
