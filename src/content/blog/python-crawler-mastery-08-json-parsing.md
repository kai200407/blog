---
title: "JSON 数据解析"
description: "1. [JSON 基础](#1-json-基础)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 8
---

> 本文介绍如何解析 API 返回的 JSON 数据。

---

## 目录

1. [JSON 基础](#1-json-基础)
2. [Python JSON 模块](#2-python-json-模块)
3. [复杂 JSON 处理](#3-复杂-json-处理)
4. [JSONPath](#4-jsonpath)
5. [实战应用](#5-实战应用)

---

## 1. JSON 基础

### 1.1 JSON 格式

```json
{
    "name": "张三",
    "age": 25,
    "active": true,
    "email": null,
    "hobbies": ["读书", "编程"],
    "address": {
        "city": "北京",
        "street": "中关村"
    }
}
```

### 1.2 JSON 数据类型

| JSON 类型 | Python 类型 |
|-----------|-------------|
| object | dict |
| array | list |
| string | str |
| number | int/float |
| true/false | True/False |
| null | None |

---

## 2. Python JSON 模块

### 2.1 解析 JSON

```python
import json

# 从字符串解析
json_str = '{"name": "张三", "age": 25}'
data = json.loads(json_str)
print(data['name'])  # 张三

# 从文件解析
with open('data.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

# 从 requests 响应解析
import requests
response = requests.get('https://api.example.com/data')
data = response.json()
```

### 2.2 生成 JSON

```python
import json

data = {
    'name': '张三',
    'age': 25,
    'hobbies': ['读书', '编程']
}

# 转为字符串
json_str = json.dumps(data, ensure_ascii=False, indent=2)
print(json_str)

# 写入文件
with open('output.json', 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
```

### 2.3 常用参数

```python
import json

data = {'name': '张三', 'age': 25}

# ensure_ascii: 是否转义非 ASCII 字符
json.dumps(data, ensure_ascii=False)  # 中文不转义

# indent: 缩进空格数
json.dumps(data, indent=2)

# sort_keys: 按键排序
json.dumps(data, sort_keys=True)

# separators: 分隔符
json.dumps(data, separators=(',', ':'))  # 紧凑格式

# default: 自定义序列化
from datetime import datetime

def custom_encoder(obj):
    if isinstance(obj, datetime):
        return obj.isoformat()
    raise TypeError(f"Object of type {type(obj)} is not JSON serializable")

data = {'time': datetime.now()}
json.dumps(data, default=custom_encoder)
```

---

## 3. 复杂 JSON 处理

### 3.1 嵌套数据访问

```python
data = {
    "users": [
        {
            "id": 1,
            "name": "张三",
            "profile": {
                "email": "zhangsan@example.com",
                "phone": "13800138000"
            }
        },
        {
            "id": 2,
            "name": "李四",
            "profile": {
                "email": "lisi@example.com",
                "phone": "13900139000"
            }
        }
    ],
    "total": 2
}

# 访问嵌套数据
first_user = data['users'][0]
first_email = data['users'][0]['profile']['email']

# 安全访问（避免 KeyError）
def safe_get(data, *keys, default=None):
    for key in keys:
        try:
            data = data[key]
        except (KeyError, IndexError, TypeError):
            return default
    return data

email = safe_get(data, 'users', 0, 'profile', 'email')
missing = safe_get(data, 'users', 0, 'profile', 'address', default='未知')
```

### 3.2 列表处理

```python
data = {
    "articles": [
        {"id": 1, "title": "文章1", "views": 100},
        {"id": 2, "title": "文章2", "views": 200},
        {"id": 3, "title": "文章3", "views": 150}
    ]
}

# 提取所有标题
titles = [article['title'] for article in data['articles']]

# 过滤
popular = [a for a in data['articles'] if a['views'] > 100]

# 排序
sorted_articles = sorted(data['articles'], key=lambda x: x['views'], reverse=True)

# 转换为字典
articles_dict = {a['id']: a for a in data['articles']}
```

### 3.3 数据扁平化

```python
def flatten_json(data, prefix=''):
    """将嵌套 JSON 扁平化"""
    result = {}
    
    if isinstance(data, dict):
        for key, value in data.items():
            new_key = f"{prefix}.{key}" if prefix else key
            result.update(flatten_json(value, new_key))
    elif isinstance(data, list):
        for i, value in enumerate(data):
            new_key = f"{prefix}[{i}]"
            result.update(flatten_json(value, new_key))
    else:
        result[prefix] = data
    
    return result

data = {
    "user": {
        "name": "张三",
        "contacts": [
            {"type": "email", "value": "test@example.com"},
            {"type": "phone", "value": "13800138000"}
        ]
    }
}

flat = flatten_json(data)
# {'user.name': '张三', 'user.contacts[0].type': 'email', ...}
```

---

## 4. JSONPath

### 4.1 安装

```bash
pip install jsonpath-ng
```

### 4.2 基本语法

| 表达式 | 说明 |
|--------|------|
| `$` | 根节点 |
| `.` | 子节点 |
| `..` | 递归下降 |
| `*` | 通配符 |
| `[]` | 下标/过滤 |
| `[start:end]` | 切片 |
| `@` | 当前节点 |

### 4.3 使用示例

```python
from jsonpath_ng import parse
from jsonpath_ng.ext import parse as parse_ext

data = {
    "store": {
        "books": [
            {"title": "Python入门", "price": 29.99, "category": "编程"},
            {"title": "Java入门", "price": 39.99, "category": "编程"},
            {"title": "小说", "price": 19.99, "category": "文学"}
        ],
        "name": "书店"
    }
}

# 获取所有书籍标题
expr = parse('$.store.books[*].title')
titles = [match.value for match in expr.find(data)]
# ['Python入门', 'Java入门', '小说']

# 获取第一本书
expr = parse('$.store.books[0]')
first_book = [match.value for match in expr.find(data)][0]

# 递归获取所有价格
expr = parse('$..price')
prices = [match.value for match in expr.find(data)]
# [29.99, 39.99, 19.99]

# 过滤（使用扩展语法）
expr = parse_ext('$.store.books[?@.price < 30]')
cheap_books = [match.value for match in expr.find(data)]

# 切片
expr = parse('$.store.books[0:2]')
first_two = [match.value for match in expr.find(data)]
```

### 4.4 封装工具类

```python
from jsonpath_ng.ext import parse

class JSONExtractor:
    """JSON 数据提取器"""
    
    def __init__(self, data):
        self.data = data
    
    def get(self, path, default=None):
        """获取单个值"""
        try:
            expr = parse(path)
            matches = expr.find(self.data)
            return matches[0].value if matches else default
        except Exception:
            return default
    
    def get_all(self, path):
        """获取所有匹配值"""
        try:
            expr = parse(path)
            return [match.value for match in expr.find(self.data)]
        except Exception:
            return []
    
    def exists(self, path):
        """检查路径是否存在"""
        return len(self.get_all(path)) > 0

# 使用
extractor = JSONExtractor(data)
title = extractor.get('$.store.books[0].title')
all_prices = extractor.get_all('$..price')
```

---

## 5. 实战应用

### 5.1 解析 API 响应

```python
import requests

def fetch_github_repos(username):
    """获取 GitHub 用户仓库"""
    url = f'https://api.github.com/users/{username}/repos'
    response = requests.get(url)
    
    if response.status_code != 200:
        return []
    
    repos = response.json()
    
    return [
        {
            'name': repo['name'],
            'description': repo['description'],
            'stars': repo['stargazers_count'],
            'forks': repo['forks_count'],
            'url': repo['html_url'],
            'language': repo['language']
        }
        for repo in repos
    ]

repos = fetch_github_repos('python')
for repo in repos[:5]:
    print(f"{repo['name']}: {repo['stars']} stars")
```

### 5.2 处理分页数据

```python
import requests

def fetch_all_pages(base_url, params=None):
    """获取所有分页数据"""
    params = params or {}
    all_data = []
    page = 1
    
    while True:
        params['page'] = page
        response = requests.get(base_url, params=params)
        data = response.json()
        
        # 检查数据结构
        if 'results' in data:
            items = data['results']
        elif 'data' in data:
            items = data['data']
        elif isinstance(data, list):
            items = data
        else:
            break
        
        if not items:
            break
        
        all_data.extend(items)
        
        # 检查是否有下一页
        if 'next' in data and data['next'] is None:
            break
        if len(items) < params.get('per_page', 20):
            break
        
        page += 1
    
    return all_data
```

### 5.3 处理嵌套 API 数据

```python
import requests
from concurrent.futures import ThreadPoolExecutor

def fetch_article_with_comments(article_id):
    """获取文章及其评论"""
    # 获取文章
    article_resp = requests.get(f'https://api.example.com/articles/{article_id}')
    article = article_resp.json()
    
    # 获取评论
    comments_resp = requests.get(f'https://api.example.com/articles/{article_id}/comments')
    comments = comments_resp.json()
    
    article['comments'] = comments
    return article

def fetch_articles_batch(article_ids, max_workers=5):
    """批量获取文章"""
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        results = list(executor.map(fetch_article_with_comments, article_ids))
    return results
```

### 5.4 JSON 数据验证

```python
from dataclasses import dataclass
from typing import List, Optional
import json

@dataclass
class User:
    id: int
    name: str
    email: str
    age: Optional[int] = None

def parse_user(data: dict) -> User:
    """解析用户数据"""
    return User(
        id=data['id'],
        name=data['name'],
        email=data['email'],
        age=data.get('age')
    )

def parse_users(json_str: str) -> List[User]:
    """解析用户列表"""
    data = json.loads(json_str)
    return [parse_user(u) for u in data['users']]

# 使用 Pydantic 进行更严格的验证
from pydantic import BaseModel, EmailStr

class UserModel(BaseModel):
    id: int
    name: str
    email: EmailStr
    age: Optional[int] = None

# 自动验证
user = UserModel(**{'id': 1, 'name': '张三', 'email': 'test@example.com'})
```

---

## 常见问题

### 处理特殊字符

```python
import json

# 处理单引号
bad_json = "{'name': 'test'}"
fixed = bad_json.replace("'", '"')
data = json.loads(fixed)

# 处理注释（JSON 不支持注释）
import re
json_with_comments = """
{
    // 这是注释
    "name": "test"
}
"""
clean_json = re.sub(r'//.*?\n', '\n', json_with_comments)
data = json.loads(clean_json)
```

### 处理大文件

```python
import json

# 流式读取
def read_large_json(filepath):
    with open(filepath, 'r') as f:
        for line in f:
            yield json.loads(line)

# 使用 ijson 处理超大文件
import ijson

def parse_large_json(filepath):
    with open(filepath, 'rb') as f:
        for item in ijson.items(f, 'items.item'):
            yield item
```

---

## 下一步

下一篇我们将学习 XML 数据解析。

---

## 参考资料

- [Python JSON 文档](https://docs.python.org/3/library/json.html)
- [JSONPath 语法](https://goessner.net/articles/JsonPath/)
- [Pydantic 文档](https://docs.pydantic.dev/)
