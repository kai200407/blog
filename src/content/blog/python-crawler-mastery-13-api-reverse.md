---
title: "API 逆向分析"
description: "1. [API 逆向基础](#1-api-逆向基础)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 13
---

> 本文介绍如何分析网站 API 接口，直接获取数据。

---

## 目录

1. [API 逆向基础](#1-api-逆向基础)
2. [浏览器开发者工具](#2-浏览器开发者工具)
3. [请求分析](#3-请求分析)
4. [参数破解](#4-参数破解)
5. [实战案例](#5-实战案例)

---

## 1. API 逆向基础

### 1.1 为什么要逆向 API

| 方式 | 优点 | 缺点 |
|------|------|------|
| 渲染页面 | 简单直接 | 慢、资源消耗大 |
| API 接口 | 快速、数据结构化 | 需要分析 |

### 1.2 常见 API 类型

- **REST API**：标准 HTTP 接口
- **GraphQL**：查询语言接口
- **WebSocket**：实时通信接口
- **RPC**：远程过程调用

### 1.3 分析流程

```
1. 打开开发者工具
2. 操作页面触发请求
3. 找到数据接口
4. 分析请求参数
5. 复现请求
6. 处理加密参数
```

---

## 2. 浏览器开发者工具

### 2.1 Network 面板

```
打开方式：F12 或 右键 -> 检查 -> Network

常用过滤：
- XHR：Ajax 请求
- Fetch：Fetch API 请求
- Doc：文档请求
- JS：JavaScript 文件
```

### 2.2 请求信息

```
Headers：请求头和响应头
Payload：请求参数
Preview：响应预览
Response：原始响应
Timing：时间信息
```

### 2.3 复制请求

```
右键请求 -> Copy -> Copy as cURL
右键请求 -> Copy -> Copy as fetch
```

### 2.4 cURL 转 Python

```python
# 使用 curlconverter.com 或手动转换

# cURL:
# curl 'https://api.example.com/data' \
#   -H 'Authorization: Bearer token' \
#   -H 'Content-Type: application/json' \
#   --data-raw '{"page": 1}'

# Python:
import requests

headers = {
    'Authorization': 'Bearer token',
    'Content-Type': 'application/json'
}

data = {'page': 1}

response = requests.post(
    'https://api.example.com/data',
    headers=headers,
    json=data
)
```

---

## 3. 请求分析

### 3.1 分析请求头

```python
# 常见必要请求头
headers = {
    # 用户代理
    'User-Agent': 'Mozilla/5.0...',
    
    # 来源页面
    'Referer': 'https://example.com/page',
    
    # 内容类型
    'Content-Type': 'application/json',
    
    # 认证信息
    'Authorization': 'Bearer xxx',
    
    # Cookie
    'Cookie': 'session=xxx',
    
    # 自定义头（反爬）
    'X-Requested-With': 'XMLHttpRequest',
    'X-Token': 'xxx',
}
```

### 3.2 分析请求参数

```python
# GET 参数
params = {
    'page': 1,
    'size': 20,
    'keyword': '搜索词',
    'timestamp': 1234567890,
    'sign': 'abc123'  # 签名参数
}

response = requests.get(url, params=params)

# POST 表单
data = {
    'username': 'user',
    'password': 'pass'
}
response = requests.post(url, data=data)

# POST JSON
json_data = {
    'query': 'keyword',
    'filters': {'type': 'article'}
}
response = requests.post(url, json=json_data)
```

### 3.3 分析响应

```python
response = requests.get(url)

# JSON 响应
data = response.json()

# 常见响应结构
{
    "code": 0,           # 状态码
    "message": "success", # 消息
    "data": {            # 数据
        "list": [...],
        "total": 100,
        "page": 1
    }
}

# 分页处理
def fetch_all_pages(url, params):
    all_data = []
    page = 1
    
    while True:
        params['page'] = page
        response = requests.get(url, params=params)
        data = response.json()
        
        items = data['data']['list']
        if not items:
            break
        
        all_data.extend(items)
        
        if len(all_data) >= data['data']['total']:
            break
        
        page += 1
    
    return all_data
```

---

## 4. 参数破解

### 4.1 时间戳参数

```python
import time

# 秒级时间戳
timestamp = int(time.time())

# 毫秒级时间戳
timestamp_ms = int(time.time() * 1000)

params = {
    't': timestamp,
    '_': timestamp_ms
}
```

### 4.2 签名参数

```python
import hashlib
import hmac

def generate_sign(params, secret_key):
    """生成签名"""
    # 排序参数
    sorted_params = sorted(params.items())
    
    # 拼接字符串
    param_str = '&'.join(f'{k}={v}' for k, v in sorted_params)
    
    # MD5 签名
    sign = hashlib.md5((param_str + secret_key).encode()).hexdigest()
    
    return sign

# 使用
params = {
    'page': 1,
    'keyword': 'test',
    'timestamp': int(time.time())
}

params['sign'] = generate_sign(params, 'secret_key')
```

### 4.3 加密参数

```python
import base64
from Crypto.Cipher import AES
import json

def aes_encrypt(data, key):
    """AES 加密"""
    cipher = AES.new(key.encode(), AES.MODE_ECB)
    
    # 填充
    data = json.dumps(data)
    pad_len = 16 - len(data) % 16
    data += chr(pad_len) * pad_len
    
    encrypted = cipher.encrypt(data.encode())
    return base64.b64encode(encrypted).decode()

def aes_decrypt(encrypted_data, key):
    """AES 解密"""
    cipher = AES.new(key.encode(), AES.MODE_ECB)
    
    decrypted = cipher.decrypt(base64.b64decode(encrypted_data))
    
    # 去除填充
    pad_len = decrypted[-1]
    decrypted = decrypted[:-pad_len]
    
    return json.loads(decrypted.decode())
```

### 4.4 JavaScript 逆向

```python
# 使用 PyExecJS 执行 JavaScript
import execjs

js_code = """
function getSign(params) {
    // JavaScript 签名逻辑
    return md5(JSON.stringify(params) + 'secret');
}
"""

ctx = execjs.compile(js_code)
sign = ctx.call('getSign', {'page': 1})

# 或使用 Node.js
import subprocess

def run_js(js_file, *args):
    result = subprocess.run(
        ['node', js_file] + list(args),
        capture_output=True,
        text=True
    )
    return result.stdout.strip()
```

### 4.5 分析混淆 JS

```javascript
// 常见混淆方式

// 1. 变量名混淆
var _0x1234 = function(_0x5678) { ... }

// 2. 字符串加密
var str = atob('SGVsbG8=');  // Base64

// 3. 控制流平坦化
switch(state) {
    case 1: ... break;
    case 2: ... break;
}

// 4. 死代码插入
if (false) { ... }
```

```python
# 使用浏览器断点调试
# 1. 在 Sources 面板找到 JS 文件
# 2. 格式化代码（Pretty Print）
# 3. 设置断点
# 4. 分析变量值

# 使用 AST 解析
import esprima
import escodegen

js_code = "var a = 1 + 2;"
ast = esprima.parseScript(js_code)
# 分析和修改 AST
```

---

## 5. 实战案例

### 5.1 分析 Ajax 接口

```python
import requests
import json

class APIClient:
    """API 客户端"""
    
    def __init__(self):
        self.session = requests.Session()
        self.base_url = 'https://api.example.com'
        
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0...',
            'Referer': 'https://example.com',
            'Content-Type': 'application/json'
        })
    
    def login(self, username, password):
        """登录获取 token"""
        response = self.session.post(
            f'{self.base_url}/auth/login',
            json={
                'username': username,
                'password': password
            }
        )
        
        data = response.json()
        if data['code'] == 0:
            token = data['data']['token']
            self.session.headers['Authorization'] = f'Bearer {token}'
            return True
        return False
    
    def get_list(self, page=1, size=20):
        """获取列表数据"""
        response = self.session.get(
            f'{self.base_url}/data/list',
            params={
                'page': page,
                'size': size,
                '_': int(time.time() * 1000)
            }
        )
        return response.json()['data']
    
    def get_detail(self, item_id):
        """获取详情"""
        response = self.session.get(
            f'{self.base_url}/data/detail/{item_id}'
        )
        return response.json()['data']

# 使用
client = APIClient()
client.login('user', 'pass')
data = client.get_list(page=1)
```

### 5.2 处理 GraphQL

```python
import requests

def graphql_query(query, variables=None):
    """执行 GraphQL 查询"""
    response = requests.post(
        'https://api.example.com/graphql',
        json={
            'query': query,
            'variables': variables or {}
        },
        headers={
            'Content-Type': 'application/json'
        }
    )
    return response.json()

# 查询示例
query = """
query GetArticles($page: Int!, $size: Int!) {
    articles(page: $page, size: $size) {
        id
        title
        content
        author {
            name
        }
    }
}
"""

result = graphql_query(query, {'page': 1, 'size': 10})
articles = result['data']['articles']
```

### 5.3 WebSocket 数据

```python
import websocket
import json
import threading

class WebSocketClient:
    """WebSocket 客户端"""
    
    def __init__(self, url):
        self.url = url
        self.ws = None
        self.data = []
    
    def on_message(self, ws, message):
        data = json.loads(message)
        self.data.append(data)
        print(f"收到: {data}")
    
    def on_error(self, ws, error):
        print(f"错误: {error}")
    
    def on_close(self, ws, close_status_code, close_msg):
        print("连接关闭")
    
    def on_open(self, ws):
        print("连接建立")
        # 发送订阅消息
        ws.send(json.dumps({
            'type': 'subscribe',
            'channel': 'data'
        }))
    
    def connect(self):
        self.ws = websocket.WebSocketApp(
            self.url,
            on_message=self.on_message,
            on_error=self.on_error,
            on_close=self.on_close,
            on_open=self.on_open
        )
        
        # 在新线程中运行
        thread = threading.Thread(target=self.ws.run_forever)
        thread.daemon = True
        thread.start()
    
    def send(self, data):
        if self.ws:
            self.ws.send(json.dumps(data))
    
    def close(self):
        if self.ws:
            self.ws.close()

# 使用
client = WebSocketClient('wss://api.example.com/ws')
client.connect()
```

### 5.4 处理加密响应

```python
import requests
import base64
from Crypto.Cipher import AES

class EncryptedAPIClient:
    """处理加密响应的客户端"""
    
    def __init__(self, key):
        self.key = key.encode()
        self.session = requests.Session()
    
    def decrypt_response(self, encrypted_data):
        """解密响应数据"""
        cipher = AES.new(self.key, AES.MODE_ECB)
        
        decrypted = cipher.decrypt(base64.b64decode(encrypted_data))
        
        # 去除 PKCS7 填充
        pad_len = decrypted[-1]
        decrypted = decrypted[:-pad_len]
        
        return json.loads(decrypted.decode())
    
    def get(self, url, **kwargs):
        response = self.session.get(url, **kwargs)
        
        # 检查是否加密
        if response.headers.get('X-Encrypted') == 'true':
            return self.decrypt_response(response.text)
        
        return response.json()

# 使用
client = EncryptedAPIClient('1234567890123456')
data = client.get('https://api.example.com/data')
```

---

## 工具推荐

| 工具 | 用途 |
|------|------|
| Chrome DevTools | 请求分析 |
| Fiddler/Charles | 抓包代理 |
| Postman | API 测试 |
| mitmproxy | 请求拦截 |
| AST Explorer | JS 分析 |

---

## 下一步

下一篇我们将学习反爬虫策略与应对。

---

## 参考资料

- [Chrome DevTools](https://developer.chrome.com/docs/devtools/)
- [mitmproxy](https://mitmproxy.org/)
- [curlconverter](https://curlconverter.com/)
