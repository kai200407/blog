---
title: "HTTP 协议基础"
description: "1. [HTTP 概述](#1-http-概述)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 2
---

> 本文介绍 HTTP 协议的核心概念，这是理解爬虫工作原理的基础。

---

## 目录

1. [HTTP 概述](#1-http-概述)
2. [请求方法](#2-请求方法)
3. [HTTP Headers](#3-http-headers)
4. [状态码](#4-状态码)
5. [Cookie 与 Session](#5-cookie-与-session)

---

## 1. HTTP 概述

### 1.1 什么是 HTTP

**HTTP**（HyperText Transfer Protocol）是用于传输超文本的应用层协议，是 Web 的基础。

### 1.2 HTTP 请求/响应模型

```
客户端                                    服务器
   |                                        |
   |  -------- HTTP 请求 -------->          |
   |     GET /index.html HTTP/1.1           |
   |     Host: example.com                  |
   |                                        |
   |  <------- HTTP 响应 ---------          |
   |     HTTP/1.1 200 OK                    |
   |     Content-Type: text/html            |
   |     <html>...</html>                   |
   |                                        |
```

### 1.3 URL 结构

```
https://www.example.com:443/path/page.html?key=value&foo=bar#section
|____| |_______________||__||_____________||________________||______|
协议        主机        端口    路径           查询参数         锚点
```

```python
from urllib.parse import urlparse, parse_qs

url = 'https://www.example.com:443/path/page.html?key=value&foo=bar#section'
parsed = urlparse(url)

print(f"协议: {parsed.scheme}")      # https
print(f"主机: {parsed.netloc}")      # www.example.com:443
print(f"路径: {parsed.path}")        # /path/page.html
print(f"查询: {parsed.query}")       # key=value&foo=bar
print(f"锚点: {parsed.fragment}")    # section

# 解析查询参数
params = parse_qs(parsed.query)
print(f"参数: {params}")  # {'key': ['value'], 'foo': ['bar']}
```

---

## 2. 请求方法

### 2.1 常用方法

| 方法 | 描述 | 幂等性 | 爬虫使用 |
|------|------|--------|----------|
| GET | 获取资源 | 是 | ⭐⭐⭐ 最常用 |
| POST | 提交数据 | 否 | ⭐⭐ 表单/登录 |
| PUT | 更新资源 | 是 | ⭐ 少用 |
| DELETE | 删除资源 | 是 | ⭐ 少用 |
| HEAD | 获取响应头 | 是 | ⭐ 检查资源 |
| OPTIONS | 获取支持的方法 | 是 | ⭐ CORS 预检 |

### 2.2 GET 请求

```python
import requests

# 基本 GET 请求
response = requests.get('https://httpbin.org/get')
print(response.text)

# 带参数的 GET 请求
params = {'key': 'value', 'page': 1}
response = requests.get('https://httpbin.org/get', params=params)
print(response.url)  # https://httpbin.org/get?key=value&page=1
```

### 2.3 POST 请求

```python
# 表单数据
data = {'username': 'user', 'password': 'pass'}
response = requests.post('https://httpbin.org/post', data=data)

# JSON 数据
import json
json_data = {'name': 'test', 'value': 123}
response = requests.post(
    'https://httpbin.org/post',
    json=json_data  # 自动设置 Content-Type: application/json
)

# 文件上传
files = {'file': open('test.txt', 'rb')}
response = requests.post('https://httpbin.org/post', files=files)
```

---

## 3. HTTP Headers

### 3.1 请求头

| Header | 描述 | 示例 |
|--------|------|------|
| User-Agent | 客户端标识 | Mozilla/5.0... |
| Accept | 接受的内容类型 | text/html, application/json |
| Accept-Language | 接受的语言 | zh-CN,zh;q=0.9,en;q=0.8 |
| Accept-Encoding | 接受的编码 | gzip, deflate, br |
| Referer | 来源页面 | https://google.com |
| Cookie | 客户端 Cookie | session_id=abc123 |
| Authorization | 认证信息 | Bearer token123 |
| Content-Type | 请求体类型 | application/x-www-form-urlencoded |

### 3.2 响应头

| Header | 描述 | 示例 |
|--------|------|------|
| Content-Type | 响应内容类型 | text/html; charset=utf-8 |
| Content-Length | 响应体长度 | 1234 |
| Content-Encoding | 响应编码 | gzip |
| Set-Cookie | 设置 Cookie | session_id=abc123; Path=/ |
| Cache-Control | 缓存控制 | max-age=3600 |
| Location | 重定向地址 | https://example.com/new |

### 3.3 设置请求头

```python
headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    'Accept-Encoding': 'gzip, deflate, br',
    'Referer': 'https://www.google.com/',
    'Connection': 'keep-alive',
}

response = requests.get('https://example.com', headers=headers)
```

### 3.4 常用 User-Agent

```python
USER_AGENTS = [
    # Chrome Windows
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    # Chrome Mac
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    # Firefox Windows
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
    # Safari Mac
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15',
    # Edge
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0',
]

import random
headers = {'User-Agent': random.choice(USER_AGENTS)}
```

---

## 4. 状态码

### 4.1 状态码分类

| 范围 | 类别 | 描述 |
|------|------|------|
| 1xx | 信息 | 请求已接收，继续处理 |
| 2xx | 成功 | 请求已成功处理 |
| 3xx | 重定向 | 需要进一步操作 |
| 4xx | 客户端错误 | 请求有误 |
| 5xx | 服务器错误 | 服务器处理失败 |

### 4.2 常见状态码

| 状态码 | 含义 | 爬虫处理 |
|--------|------|----------|
| 200 | 成功 | 正常解析 |
| 301 | 永久重定向 | 跟随重定向 |
| 302 | 临时重定向 | 跟随重定向 |
| 304 | 未修改 | 使用缓存 |
| 400 | 请求错误 | 检查参数 |
| 401 | 未授权 | 需要登录 |
| 403 | 禁止访问 | 可能被反爬 |
| 404 | 未找到 | 跳过该 URL |
| 429 | 请求过多 | 降低频率 |
| 500 | 服务器错误 | 稍后重试 |
| 502 | 网关错误 | 稍后重试 |
| 503 | 服务不可用 | 稍后重试 |

### 4.3 状态码处理

```python
def handle_response(response):
    """根据状态码处理响应"""
    status = response.status_code
    
    if status == 200:
        return response.text
    
    elif status in (301, 302):
        # requests 默认会自动跟随重定向
        print(f"重定向到: {response.url}")
        return response.text
    
    elif status == 403:
        print("访问被禁止，可能触发反爬")
        return None
    
    elif status == 404:
        print("页面不存在")
        return None
    
    elif status == 429:
        # 获取重试时间
        retry_after = response.headers.get('Retry-After', 60)
        print(f"请求过多，{retry_after} 秒后重试")
        return None
    
    elif status >= 500:
        print(f"服务器错误: {status}")
        return None
    
    else:
        print(f"未知状态码: {status}")
        return None
```

---

## 5. Cookie 与 Session

### 5.1 Cookie 基础

Cookie 是服务器发送到浏览器并保存的小数据，用于维持状态。

```python
# 获取响应中的 Cookie
response = requests.get('https://httpbin.org/cookies/set/name/value')
print(response.cookies.get_dict())  # {'name': 'value'}

# 发送 Cookie
cookies = {'session_id': 'abc123', 'user': 'test'}
response = requests.get('https://httpbin.org/cookies', cookies=cookies)
print(response.json())
```

### 5.2 Session 会话

Session 可以在多个请求之间保持状态（Cookie、Headers 等）。

```python
# 创建 Session
session = requests.Session()

# 设置默认 Headers
session.headers.update({
    'User-Agent': 'Mozilla/5.0...',
    'Accept-Language': 'zh-CN,zh;q=0.9'
})

# 登录（Cookie 会自动保存）
login_data = {'username': 'user', 'password': 'pass'}
session.post('https://example.com/login', data=login_data)

# 后续请求会自动携带 Cookie
response = session.get('https://example.com/profile')
print(response.text)

# 查看当前 Cookie
print(session.cookies.get_dict())
```

### 5.3 Cookie 持久化

```python
import pickle

# 保存 Cookie
with open('cookies.pkl', 'wb') as f:
    pickle.dump(session.cookies, f)

# 加载 Cookie
with open('cookies.pkl', 'rb') as f:
    session.cookies = pickle.load(f)
```

---

## HTTP/2 与 HTTP/3

### HTTP/2 特性

- 多路复用：单连接多请求
- 头部压缩：减少传输量
- 服务器推送：主动推送资源

```python
# 使用 httpx 支持 HTTP/2
import httpx

# HTTP/2 客户端
with httpx.Client(http2=True) as client:
    response = client.get('https://example.com')
    print(f"HTTP 版本: {response.http_version}")
```

---

## 实战：分析 HTTP 请求

### 使用浏览器开发者工具

1. 打开浏览器，按 F12 打开开发者工具
2. 切换到 Network 标签
3. 访问目标网站
4. 查看请求详情：Headers、Payload、Response

### 使用 Python 查看请求详情

```python
import requests

# 准备请求
req = requests.Request('GET', 'https://httpbin.org/get', headers={'X-Custom': 'test'})
prepared = req.prepare()

# 查看请求详情
print("=== 请求 ===")
print(f"方法: {prepared.method}")
print(f"URL: {prepared.url}")
print(f"Headers: {dict(prepared.headers)}")

# 发送请求
session = requests.Session()
response = session.send(prepared)

# 查看响应详情
print("\n=== 响应 ===")
print(f"状态码: {response.status_code}")
print(f"Headers: {dict(response.headers)}")
print(f"内容: {response.text[:200]}...")
```

---

## 下一步

下一篇我们将学习 Requests 库的详细使用，这是 Python 爬虫最常用的 HTTP 库。

---

## 参考资料

- [HTTP 协议 - MDN](https://developer.mozilla.org/zh-CN/docs/Web/HTTP)
- [HTTP 状态码](https://httpstatuses.com/)
- [Requests 文档](https://docs.python-requests.org/)
