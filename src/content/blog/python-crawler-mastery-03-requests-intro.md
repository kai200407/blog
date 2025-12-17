---
title: "Requests 库入门"
description: "1. [安装与基础](#1-安装与基础)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 3
---

> 本文详细介绍 Python Requests 库的使用，这是爬虫开发最常用的 HTTP 库。

---

## 目录

1. [安装与基础](#1-安装与基础)
2. [GET 请求详解](#2-get-请求详解)
3. [POST 请求详解](#3-post-请求详解)
4. [响应处理](#4-响应处理)
5. [高级功能](#5-高级功能)

---

## 1. 安装与基础

### 1.1 安装

```bash
pip install requests
```

### 1.2 基本使用

```python
import requests

# 最简单的 GET 请求
response = requests.get('https://httpbin.org/get')
print(response.status_code)  # 200
print(response.text)         # 响应内容
```

### 1.3 请求方法

```python
# GET
r = requests.get('https://httpbin.org/get')

# POST
r = requests.post('https://httpbin.org/post', data={'key': 'value'})

# PUT
r = requests.put('https://httpbin.org/put', data={'key': 'value'})

# DELETE
r = requests.delete('https://httpbin.org/delete')

# HEAD
r = requests.head('https://httpbin.org/get')

# OPTIONS
r = requests.options('https://httpbin.org/get')
```

---

## 2. GET 请求详解

### 2.1 URL 参数

```python
# 方式1：直接拼接
response = requests.get('https://httpbin.org/get?key=value&page=1')

# 方式2：使用 params 参数（推荐）
params = {
    'key': 'value',
    'page': 1,
    'tags': ['python', 'crawler']  # 列表会自动处理
}
response = requests.get('https://httpbin.org/get', params=params)
print(response.url)  # https://httpbin.org/get?key=value&page=1&tags=python&tags=crawler
```

### 2.2 自定义 Headers

```python
headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'text/html,application/xhtml+xml',
    'Accept-Language': 'zh-CN,zh;q=0.9',
    'Referer': 'https://www.google.com/',
}

response = requests.get('https://httpbin.org/headers', headers=headers)
print(response.json())
```

### 2.3 超时设置

```python
# 设置超时（秒）
try:
    response = requests.get('https://httpbin.org/delay/5', timeout=3)
except requests.exceptions.Timeout:
    print("请求超时")

# 分别设置连接超时和读取超时
response = requests.get(
    'https://httpbin.org/get',
    timeout=(3.05, 27)  # (连接超时, 读取超时)
)
```

### 2.4 代理设置

```python
proxies = {
    'http': 'http://127.0.0.1:7890',
    'https': 'http://127.0.0.1:7890',
}

response = requests.get('https://httpbin.org/ip', proxies=proxies)
print(response.json())

# SOCKS 代理（需要安装 requests[socks]）
proxies = {
    'http': 'socks5://127.0.0.1:1080',
    'https': 'socks5://127.0.0.1:1080',
}
```

---

## 3. POST 请求详解

### 3.1 表单数据

```python
# application/x-www-form-urlencoded
data = {
    'username': 'admin',
    'password': '123456'
}
response = requests.post('https://httpbin.org/post', data=data)
print(response.json())
```

### 3.2 JSON 数据

```python
import json

# 方式1：使用 json 参数（推荐）
json_data = {
    'name': 'test',
    'value': 123,
    'items': [1, 2, 3]
}
response = requests.post('https://httpbin.org/post', json=json_data)

# 方式2：手动序列化
response = requests.post(
    'https://httpbin.org/post',
    data=json.dumps(json_data),
    headers={'Content-Type': 'application/json'}
)
```

### 3.3 文件上传

```python
# 单文件上传
files = {'file': open('test.txt', 'rb')}
response = requests.post('https://httpbin.org/post', files=files)

# 指定文件名和类型
files = {
    'file': ('custom_name.txt', open('test.txt', 'rb'), 'text/plain')
}
response = requests.post('https://httpbin.org/post', files=files)

# 多文件上传
files = [
    ('files', ('file1.txt', open('file1.txt', 'rb'))),
    ('files', ('file2.txt', open('file2.txt', 'rb'))),
]
response = requests.post('https://httpbin.org/post', files=files)

# 文件 + 表单数据
files = {'file': open('test.txt', 'rb')}
data = {'description': 'Test file'}
response = requests.post('https://httpbin.org/post', files=files, data=data)
```

### 3.4 原始数据

```python
# 发送原始字符串
response = requests.post(
    'https://httpbin.org/post',
    data='raw string data',
    headers={'Content-Type': 'text/plain'}
)

# 发送二进制数据
response = requests.post(
    'https://httpbin.org/post',
    data=b'\x00\x01\x02\x03',
    headers={'Content-Type': 'application/octet-stream'}
)
```

---

## 4. 响应处理

### 4.1 响应属性

```python
response = requests.get('https://httpbin.org/get')

# 状态码
print(response.status_code)  # 200
print(response.ok)           # True (status_code < 400)

# 响应头
print(response.headers)
print(response.headers['Content-Type'])

# 响应内容
print(response.text)         # 文本内容（自动解码）
print(response.content)      # 二进制内容
print(response.json())       # JSON 解析

# 编码
print(response.encoding)     # 响应编码
response.encoding = 'utf-8'  # 手动设置编码

# URL 和历史
print(response.url)          # 最终 URL
print(response.history)      # 重定向历史

# Cookie
print(response.cookies)
print(response.cookies.get_dict())
```

### 4.2 JSON 响应

```python
response = requests.get('https://httpbin.org/json')

# 解析 JSON
data = response.json()
print(data)

# 处理解析错误
try:
    data = response.json()
except requests.exceptions.JSONDecodeError:
    print("响应不是有效的 JSON")
    data = None
```

### 4.3 二进制内容

```python
# 下载图片
response = requests.get('https://httpbin.org/image/png')
with open('image.png', 'wb') as f:
    f.write(response.content)

# 流式下载大文件
response = requests.get('https://example.com/large_file.zip', stream=True)
with open('large_file.zip', 'wb') as f:
    for chunk in response.iter_content(chunk_size=8192):
        f.write(chunk)

# 带进度条下载
from tqdm import tqdm

response = requests.get('https://example.com/file.zip', stream=True)
total_size = int(response.headers.get('content-length', 0))

with open('file.zip', 'wb') as f:
    with tqdm(total=total_size, unit='B', unit_scale=True) as pbar:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)
            pbar.update(len(chunk))
```

### 4.4 编码处理

```python
response = requests.get('https://example.com')

# 自动检测编码
print(response.encoding)  # 可能是 ISO-8859-1

# 从内容检测编码
print(response.apparent_encoding)  # 可能是 utf-8

# 使用正确的编码
response.encoding = response.apparent_encoding
print(response.text)

# 或者直接使用 content 解码
text = response.content.decode('utf-8')
```

---

## 5. 高级功能

### 5.1 Session 会话

```python
# 创建 Session
session = requests.Session()

# 设置默认参数
session.headers.update({
    'User-Agent': 'Mozilla/5.0...',
    'Accept-Language': 'zh-CN,zh;q=0.9'
})

# 登录
login_data = {'username': 'user', 'password': 'pass'}
session.post('https://example.com/login', data=login_data)

# 后续请求自动携带 Cookie
response = session.get('https://example.com/profile')

# 查看 Cookie
print(session.cookies.get_dict())

# 关闭 Session
session.close()

# 使用 with 语句
with requests.Session() as session:
    session.get('https://example.com')
```

### 5.2 Cookie 处理

```python
# 发送 Cookie
cookies = {'session_id': 'abc123'}
response = requests.get('https://httpbin.org/cookies', cookies=cookies)

# 使用 CookieJar
from requests.cookies import RequestsCookieJar

jar = RequestsCookieJar()
jar.set('name', 'value', domain='httpbin.org', path='/')
response = requests.get('https://httpbin.org/cookies', cookies=jar)

# 从响应获取 Cookie
response = requests.get('https://httpbin.org/cookies/set/name/value')
print(response.cookies['name'])
```

### 5.3 SSL 证书

```python
# 忽略 SSL 证书验证（不推荐用于生产）
response = requests.get('https://example.com', verify=False)

# 指定证书
response = requests.get('https://example.com', verify='/path/to/cert.pem')

# 客户端证书
response = requests.get(
    'https://example.com',
    cert=('/path/to/client.cert', '/path/to/client.key')
)
```

### 5.4 重定向控制

```python
# 禁止重定向
response = requests.get('https://httpbin.org/redirect/3', allow_redirects=False)
print(response.status_code)  # 302
print(response.headers['Location'])

# 允许重定向（默认）
response = requests.get('https://httpbin.org/redirect/3', allow_redirects=True)
print(len(response.history))  # 3

# 限制重定向次数
session = requests.Session()
session.max_redirects = 5
```

### 5.5 认证

```python
# Basic 认证
from requests.auth import HTTPBasicAuth

response = requests.get(
    'https://httpbin.org/basic-auth/user/pass',
    auth=HTTPBasicAuth('user', 'pass')
)
# 或简写
response = requests.get(
    'https://httpbin.org/basic-auth/user/pass',
    auth=('user', 'pass')
)

# Digest 认证
from requests.auth import HTTPDigestAuth

response = requests.get(
    'https://httpbin.org/digest-auth/auth/user/pass',
    auth=HTTPDigestAuth('user', 'pass')
)

# Bearer Token
headers = {'Authorization': 'Bearer your_token_here'}
response = requests.get('https://api.example.com/data', headers=headers)
```

### 5.6 异常处理

```python
import requests
from requests.exceptions import (
    RequestException,
    ConnectionError,
    Timeout,
    TooManyRedirects,
    HTTPError
)

def safe_request(url, **kwargs):
    """安全的请求函数"""
    try:
        response = requests.get(url, timeout=10, **kwargs)
        response.raise_for_status()  # 抛出 HTTP 错误
        return response
    
    except ConnectionError:
        print("连接错误：无法连接到服务器")
    except Timeout:
        print("超时错误：请求超时")
    except TooManyRedirects:
        print("重定向错误：重定向次数过多")
    except HTTPError as e:
        print(f"HTTP 错误：{e.response.status_code}")
    except RequestException as e:
        print(f"请求错误：{e}")
    
    return None

# 使用
response = safe_request('https://httpbin.org/get')
if response:
    print(response.json())
```

---

## 完整爬虫示例

```python
import requests
from bs4 import BeautifulSoup
import time
import random

class SimpleCrawler:
    """简单爬虫类"""
    
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        })
    
    def get(self, url, **kwargs):
        """发送 GET 请求"""
        # 随机延迟
        time.sleep(random.uniform(1, 3))
        
        try:
            response = self.session.get(url, timeout=10, **kwargs)
            response.raise_for_status()
            return response
        except requests.RequestException as e:
            print(f"请求失败: {e}")
            return None
    
    def parse_html(self, html):
        """解析 HTML"""
        return BeautifulSoup(html, 'html.parser')
    
    def crawl(self, url):
        """爬取页面"""
        response = self.get(url)
        if not response:
            return None
        
        soup = self.parse_html(response.text)
        
        return {
            'title': soup.title.string if soup.title else '',
            'links': [a.get('href') for a in soup.find_all('a', href=True)],
            'text': soup.get_text()[:500]
        }

# 使用
crawler = SimpleCrawler()
result = crawler.crawl('https://example.com')
print(result)
```

---

## 下一步

下一篇我们将学习 HTML 解析基础，使用 BeautifulSoup 提取网页数据。

---

## 参考资料

- [Requests 官方文档](https://docs.python-requests.org/)
- [Requests 快速入门](https://docs.python-requests.org/en/latest/user/quickstart/)
