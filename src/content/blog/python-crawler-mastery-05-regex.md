---
title: "正则表达式"
description: "1. [正则基础](#1-正则基础)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 5
---

> 本文介绍 Python 正则表达式在爬虫中的应用，用于灵活的文本匹配和数据提取。

---

## 目录

1. [正则基础](#1-正则基础)
2. [常用模式](#2-常用模式)
3. [re 模块详解](#3-re-模块详解)
4. [爬虫实战应用](#4-爬虫实战应用)
5. [性能优化](#5-性能优化)

---

## 1. 正则基础

### 1.1 基本语法

| 字符 | 描述 | 示例 |
|------|------|------|
| `.` | 匹配任意字符（除换行） | `a.c` → abc, aXc |
| `*` | 匹配 0 次或多次 | `ab*` → a, ab, abb |
| `+` | 匹配 1 次或多次 | `ab+` → ab, abb |
| `?` | 匹配 0 次或 1 次 | `ab?` → a, ab |
| `{n}` | 匹配 n 次 | `a{3}` → aaa |
| `{n,m}` | 匹配 n 到 m 次 | `a{2,4}` → aa, aaa, aaaa |
| `^` | 匹配开头 | `^Hello` |
| `$` | 匹配结尾 | `world$` |
| `\|` | 或 | `cat\|dog` |
| `()` | 分组 | `(ab)+` → ab, abab |
| `[]` | 字符集 | `[abc]` → a, b, c |
| `[^]` | 否定字符集 | `[^abc]` → 非 a,b,c |

### 1.2 特殊字符

| 字符 | 描述 | 等价于 |
|------|------|--------|
| `\d` | 数字 | `[0-9]` |
| `\D` | 非数字 | `[^0-9]` |
| `\w` | 单词字符 | `[a-zA-Z0-9_]` |
| `\W` | 非单词字符 | `[^a-zA-Z0-9_]` |
| `\s` | 空白字符 | `[ \t\n\r\f\v]` |
| `\S` | 非空白字符 | `[^ \t\n\r\f\v]` |
| `\b` | 单词边界 | |
| `\B` | 非单词边界 | |

### 1.3 基本示例

```python
import re

text = "我的电话是 13812345678，邮箱是 test@example.com"

# 匹配手机号
phone = re.search(r'1[3-9]\d{9}', text)
print(phone.group())  # 13812345678

# 匹配邮箱
email = re.search(r'[\w.-]+@[\w.-]+\.\w+', text)
print(email.group())  # test@example.com
```

---

## 2. 常用模式

### 2.1 数字匹配

```python
import re

# 整数
pattern = r'-?\d+'
print(re.findall(pattern, 'a1b-2c3'))  # ['1', '-2', '3']

# 浮点数
pattern = r'-?\d+\.?\d*'
print(re.findall(pattern, '价格: 12.5 元，折扣: -0.8'))  # ['12.5', '-0.8']

# 价格
pattern = r'[¥$]\d+(?:\.\d{2})?'
print(re.findall(pattern, '价格: ¥99.00 或 $12.50'))  # ['¥99.00', '$12.50']
```

### 2.2 URL 匹配

```python
# 完整 URL
url_pattern = r'https?://[^\s<>"{}|\\^`\[\]]+'

text = '访问 https://example.com/path?q=1 或 http://test.org'
urls = re.findall(url_pattern, text)
print(urls)  # ['https://example.com/path?q=1', 'http://test.org']

# 提取域名
domain_pattern = r'https?://([^/]+)'
domains = re.findall(domain_pattern, text)
print(domains)  # ['example.com', 'test.org']
```

### 2.3 HTML 标签

```python
html = '<div class="content"><p>Hello</p><a href="/link">Link</a></div>'

# 提取标签内容
pattern = r'<p>(.*?)</p>'
content = re.findall(pattern, html)
print(content)  # ['Hello']

# 提取链接
pattern = r'<a\s+href=["\']([^"\']+)["\']'
links = re.findall(pattern, html)
print(links)  # ['/link']

# 提取所有属性
pattern = r'(\w+)=["\']([^"\']+)["\']'
attrs = re.findall(pattern, html)
print(attrs)  # [('class', 'content'), ('href', '/link')]

# 去除 HTML 标签
clean = re.sub(r'<[^>]+>', '', html)
print(clean)  # HelloLink
```

### 2.4 中文匹配

```python
text = "Hello 你好 World 世界 123"

# 匹配中文
pattern = r'[\u4e00-\u9fa5]+'
chinese = re.findall(pattern, text)
print(chinese)  # ['你好', '世界']

# 匹配中文和标点
pattern = r'[\u4e00-\u9fa5\u3000-\u303f\uff00-\uffef]+'
```

### 2.5 日期时间

```python
text = "日期: 2024-01-15, 时间: 14:30:00"

# 日期 YYYY-MM-DD
date_pattern = r'\d{4}-\d{2}-\d{2}'
dates = re.findall(date_pattern, text)
print(dates)  # ['2024-01-15']

# 时间 HH:MM:SS
time_pattern = r'\d{2}:\d{2}:\d{2}'
times = re.findall(time_pattern, text)
print(times)  # ['14:30:00']

# 日期时间
datetime_pattern = r'\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}'
```

---

## 3. re 模块详解

### 3.1 常用函数

```python
import re

text = "Python 3.10 is great. Python 3.11 is better."

# search - 搜索第一个匹配
match = re.search(r'Python \d+\.\d+', text)
if match:
    print(match.group())   # Python 3.10
    print(match.start())   # 0
    print(match.end())     # 10
    print(match.span())    # (0, 10)

# match - 从开头匹配
match = re.match(r'Python', text)
print(match.group() if match else None)  # Python

# findall - 查找所有匹配
matches = re.findall(r'Python \d+\.\d+', text)
print(matches)  # ['Python 3.10', 'Python 3.11']

# finditer - 返回迭代器
for match in re.finditer(r'Python (\d+\.\d+)', text):
    print(f"版本: {match.group(1)}, 位置: {match.span()}")

# sub - 替换
new_text = re.sub(r'Python', 'Java', text)
print(new_text)

# subn - 替换并返回次数
new_text, count = re.subn(r'Python', 'Java', text)
print(f"替换了 {count} 次")

# split - 分割
parts = re.split(r'\s+', "a  b   c")
print(parts)  # ['a', 'b', 'c']
```

### 3.2 分组

```python
import re

text = "张三的电话是13812345678，李四的电话是13987654321"

# 命名分组
pattern = r'(?P<name>\w+)的电话是(?P<phone>1[3-9]\d{9})'

for match in re.finditer(pattern, text):
    print(f"姓名: {match.group('name')}, 电话: {match.group('phone')}")

# 分组引用
html = '<div>content</div>'
pattern = r'<(\w+)>(.*?)</\1>'
match = re.search(pattern, html)
if match:
    print(f"标签: {match.group(1)}, 内容: {match.group(2)}")

# 非捕获分组
pattern = r'(?:https?://)?(\w+\.com)'
urls = re.findall(pattern, 'https://example.com and test.com')
print(urls)  # ['example.com', 'test.com']
```

### 3.3 修饰符

```python
import re

text = """
Hello World
hello python
HELLO REGEX
"""

# re.I - 忽略大小写
matches = re.findall(r'hello', text, re.I)
print(matches)  # ['Hello', 'hello', 'HELLO']

# re.M - 多行模式
matches = re.findall(r'^hello', text, re.I | re.M)
print(matches)  # ['Hello', 'hello', 'HELLO']

# re.S - 点号匹配换行
html = "<div>\nContent\n</div>"
match = re.search(r'<div>(.*?)</div>', html, re.S)
print(match.group(1))  # \nContent\n

# re.X - 详细模式（允许注释）
pattern = re.compile(r'''
    (\d{4})     # 年
    -
    (\d{2})     # 月
    -
    (\d{2})     # 日
''', re.X)
match = pattern.search('2024-01-15')
print(match.groups())  # ('2024', '01', '15')
```

### 3.4 编译正则

```python
import re

# 编译正则表达式（提高性能）
phone_pattern = re.compile(r'1[3-9]\d{9}')
email_pattern = re.compile(r'[\w.-]+@[\w.-]+\.\w+')

text = "电话: 13812345678, 邮箱: test@example.com"

phone = phone_pattern.search(text)
email = email_pattern.search(text)

print(phone.group())  # 13812345678
print(email.group())  # test@example.com
```

---

## 4. 爬虫实战应用

### 4.1 提取网页数据

```python
import re
import requests

def extract_page_data(html):
    """从 HTML 提取数据"""
    data = {}
    
    # 提取标题
    title_match = re.search(r'<title>(.*?)</title>', html, re.S)
    data['title'] = title_match.group(1).strip() if title_match else ''
    
    # 提取所有链接
    data['links'] = re.findall(r'href=["\']([^"\']+)["\']', html)
    
    # 提取所有图片
    data['images'] = re.findall(r'src=["\']([^"\']+\.(?:jpg|png|gif))["\']', html, re.I)
    
    # 提取 meta 描述
    desc_match = re.search(r'<meta\s+name=["\']description["\']\s+content=["\']([^"\']+)["\']', html, re.I)
    data['description'] = desc_match.group(1) if desc_match else ''
    
    return data

# 使用
response = requests.get('https://example.com')
data = extract_page_data(response.text)
print(data)
```

### 4.2 清洗文本

```python
import re

def clean_text(text):
    """清洗文本"""
    # 去除 HTML 标签
    text = re.sub(r'<[^>]+>', '', text)
    
    # 去除多余空白
    text = re.sub(r'\s+', ' ', text)
    
    # 去除特殊字符
    text = re.sub(r'[^\w\s\u4e00-\u9fa5.,!?，。！？]', '', text)
    
    return text.strip()

html = "<p>Hello   World!</p><script>alert('xss')</script>"
print(clean_text(html))  # Hello World!
```

### 4.3 提取 JSON 数据

```python
import re
import json

def extract_json_from_html(html, var_name):
    """从 HTML 中提取 JavaScript 变量中的 JSON"""
    pattern = rf'{var_name}\s*=\s*(\{{.*?\}}|\[.*?\]);'
    match = re.search(pattern, html, re.S)
    
    if match:
        json_str = match.group(1)
        try:
            return json.loads(json_str)
        except json.JSONDecodeError:
            return None
    return None

html = '''
<script>
var pageData = {"title": "Test", "items": [1, 2, 3]};
</script>
'''

data = extract_json_from_html(html, 'pageData')
print(data)  # {'title': 'Test', 'items': [1, 2, 3]}
```

### 4.4 验证数据格式

```python
import re

class Validator:
    """数据验证器"""
    
    PATTERNS = {
        'phone': r'^1[3-9]\d{9}$',
        'email': r'^[\w.-]+@[\w.-]+\.\w+$',
        'url': r'^https?://[^\s]+$',
        'id_card': r'^\d{17}[\dXx]$',
        'ip': r'^(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d\d?)$',
    }
    
    @classmethod
    def validate(cls, value, pattern_name):
        pattern = cls.PATTERNS.get(pattern_name)
        if not pattern:
            raise ValueError(f"未知的验证类型: {pattern_name}")
        return bool(re.match(pattern, value))

# 使用
print(Validator.validate('13812345678', 'phone'))  # True
print(Validator.validate('test@example.com', 'email'))  # True
print(Validator.validate('192.168.1.1', 'ip'))  # True
```

---

## 5. 性能优化

### 5.1 编译正则

```python
import re
import time

text = "test " * 10000

# 不编译（每次都要编译）
start = time.time()
for _ in range(1000):
    re.findall(r'\w+', text)
print(f"不编译: {time.time() - start:.3f}s")

# 预编译
pattern = re.compile(r'\w+')
start = time.time()
for _ in range(1000):
    pattern.findall(text)
print(f"预编译: {time.time() - start:.3f}s")
```

### 5.2 避免回溯

```python
import re

# 贪婪匹配可能导致回溯
bad_pattern = r'<.*>'  # 贪婪
good_pattern = r'<[^>]*>'  # 非贪婪，更高效

# 使用原子组或占有量词（Python 3.11+）
# pattern = r'<(?>[^>]*)>'
```

### 5.3 使用合适的方法

```python
import re

text = "Hello World"

# 只需检查是否匹配，用 search 而不是 findall
if re.search(r'World', text):
    print("找到了")

# 只需第一个匹配，用 search 而不是 findall
match = re.search(r'\w+', text)
if match:
    print(match.group())
```

---

## 常用正则表达式速查

```python
PATTERNS = {
    # 基础
    'phone': r'1[3-9]\d{9}',
    'email': r'[\w.-]+@[\w.-]+\.\w+',
    'url': r'https?://[^\s<>"]+',
    'ip': r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}',
    
    # 中国特色
    'id_card': r'\d{17}[\dXx]',
    'postal_code': r'\d{6}',
    'qq': r'[1-9]\d{4,10}',
    
    # HTML
    'html_tag': r'<[^>]+>',
    'html_comment': r'<!--.*?-->',
    'script': r'<script[^>]*>.*?</script>',
    
    # 日期时间
    'date_ymd': r'\d{4}-\d{2}-\d{2}',
    'time_hms': r'\d{2}:\d{2}:\d{2}',
    
    # 数字
    'integer': r'-?\d+',
    'float': r'-?\d+\.?\d*',
    'price': r'[¥$€]\d+(?:\.\d{2})?',
}
```

---

## 下一步

下一篇我们将学习 XPath 详解，这是另一种强大的数据提取方式。

---

## 参考资料

- [Python re 模块文档](https://docs.python.org/3/library/re.html)
- [正则表达式在线测试](https://regex101.com/)
