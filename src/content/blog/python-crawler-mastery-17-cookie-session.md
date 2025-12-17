---
title: "Cookie 与 Session 管理"
description: "1. [Cookie 基础](#1-cookie-基础)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 17
---

> 本文介绍如何管理 Cookie 和 Session 进行登录态维护。

---

## 目录

1. [Cookie 基础](#1-cookie-基础)
2. [Session 管理](#2-session-管理)
3. [登录状态维护](#3-登录状态维护)
4. [Cookie 持久化](#4-cookie-持久化)
5. [实战应用](#5-实战应用)

---

## 1. Cookie 基础

### 1.1 Cookie 属性

| 属性 | 说明 |
|------|------|
| name | Cookie 名称 |
| value | Cookie 值 |
| domain | 作用域名 |
| path | 作用路径 |
| expires | 过期时间 |
| max-age | 有效期（秒） |
| secure | 仅 HTTPS |
| httponly | 禁止 JS 访问 |

### 1.2 Requests Cookie 操作

```python
import requests

# 发送 Cookie
cookies = {'session_id': 'abc123', 'user': 'test'}
response = requests.get('https://httpbin.org/cookies', cookies=cookies)
print(response.json())

# 获取响应 Cookie
response = requests.get('https://httpbin.org/cookies/set/name/value')
print(response.cookies.get_dict())

# Cookie 对象
from requests.cookies import RequestsCookieJar

jar = RequestsCookieJar()
jar.set('cookie1', 'value1', domain='example.com', path='/')
jar.set('cookie2', 'value2', domain='example.com', path='/api')

response = requests.get('https://example.com', cookies=jar)
```

### 1.3 解析 Cookie 字符串

```python
def parse_cookie_string(cookie_str):
    """解析 Cookie 字符串"""
    cookies = {}
    for item in cookie_str.split(';'):
        item = item.strip()
        if '=' in item:
            key, value = item.split('=', 1)
            cookies[key.strip()] = value.strip()
    return cookies

# 使用
cookie_str = "session=abc123; user=test; token=xyz"
cookies = parse_cookie_string(cookie_str)
print(cookies)
# {'session': 'abc123', 'user': 'test', 'token': 'xyz'}
```

---

## 2. Session 管理

### 2.1 使用 Session

```python
import requests

# 创建 Session
session = requests.Session()

# Session 会自动保持 Cookie
session.get('https://httpbin.org/cookies/set/session_id/abc123')
response = session.get('https://httpbin.org/cookies')
print(response.json())  # 包含 session_id

# 设置默认请求头
session.headers.update({
    'User-Agent': 'Mozilla/5.0...',
    'Accept-Language': 'zh-CN,zh;q=0.9'
})

# 设置默认参数
session.params = {'api_key': 'xxx'}

# 设置代理
session.proxies = {
    'http': 'http://proxy:8080',
    'https': 'http://proxy:8080'
}

# 设置超时
session.timeout = 10

# 关闭 Session
session.close()

# 使用上下文管理器
with requests.Session() as session:
    response = session.get('https://example.com')
```

### 2.2 Session 适配器

```python
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

# 创建重试策略
retry_strategy = Retry(
    total=3,
    backoff_factor=1,
    status_forcelist=[500, 502, 503, 504]
)

# 创建适配器
adapter = HTTPAdapter(
    max_retries=retry_strategy,
    pool_connections=10,
    pool_maxsize=10
)

# 挂载适配器
session = requests.Session()
session.mount('http://', adapter)
session.mount('https://', adapter)
```

### 2.3 Session 封装

```python
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import logging

class CrawlerSession:
    """爬虫 Session 封装"""
    
    def __init__(
        self,
        timeout=30,
        max_retries=3,
        pool_size=10
    ):
        self.session = requests.Session()
        self.timeout = timeout
        
        # 设置请求头
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive'
        })
        
        # 设置重试
        retry = Retry(
            total=max_retries,
            backoff_factor=0.5,
            status_forcelist=[500, 502, 503, 504]
        )
        
        adapter = HTTPAdapter(
            max_retries=retry,
            pool_connections=pool_size,
            pool_maxsize=pool_size
        )
        
        self.session.mount('http://', adapter)
        self.session.mount('https://', adapter)
    
    def get(self, url, **kwargs):
        kwargs.setdefault('timeout', self.timeout)
        return self.session.get(url, **kwargs)
    
    def post(self, url, **kwargs):
        kwargs.setdefault('timeout', self.timeout)
        return self.session.post(url, **kwargs)
    
    def set_cookies(self, cookies):
        """设置 Cookie"""
        if isinstance(cookies, str):
            cookies = parse_cookie_string(cookies)
        self.session.cookies.update(cookies)
    
    def get_cookies(self):
        """获取 Cookie"""
        return self.session.cookies.get_dict()
    
    def close(self):
        self.session.close()
    
    def __enter__(self):
        return self
    
    def __exit__(self, *args):
        self.close()

# 使用
with CrawlerSession() as session:
    response = session.get('https://example.com')
    print(response.status_code)
```

---

## 3. 登录状态维护

### 3.1 表单登录

```python
import requests

def login_with_form(username, password):
    """表单登录"""
    session = requests.Session()
    
    # 获取登录页面（可能需要 CSRF token）
    login_page = session.get('https://example.com/login')
    
    # 提取 CSRF token
    from bs4 import BeautifulSoup
    soup = BeautifulSoup(login_page.text, 'lxml')
    csrf_token = soup.find('input', {'name': 'csrf_token'})['value']
    
    # 提交登录
    login_data = {
        'username': username,
        'password': password,
        'csrf_token': csrf_token
    }
    
    response = session.post(
        'https://example.com/login',
        data=login_data,
        headers={'Referer': 'https://example.com/login'}
    )
    
    # 检查登录是否成功
    if 'dashboard' in response.url or '欢迎' in response.text:
        return session
    
    return None

# 使用
session = login_with_form('user', 'pass')
if session:
    # 访问需要登录的页面
    response = session.get('https://example.com/profile')
```

### 3.2 API 登录

```python
import requests

def login_with_api(username, password):
    """API 登录"""
    session = requests.Session()
    
    # 登录请求
    response = session.post(
        'https://api.example.com/auth/login',
        json={
            'username': username,
            'password': password
        }
    )
    
    data = response.json()
    
    if data.get('code') == 0:
        # 设置 Token
        token = data['data']['token']
        session.headers['Authorization'] = f'Bearer {token}'
        return session
    
    return None

# 使用
session = login_with_api('user', 'pass')
if session:
    response = session.get('https://api.example.com/user/info')
```

### 3.3 OAuth 登录

```python
import requests
from urllib.parse import urlencode, parse_qs, urlparse

class OAuthClient:
    """OAuth 客户端"""
    
    def __init__(self, client_id, client_secret, redirect_uri):
        self.client_id = client_id
        self.client_secret = client_secret
        self.redirect_uri = redirect_uri
        self.session = requests.Session()
    
    def get_auth_url(self, auth_endpoint, scope='read'):
        """获取授权 URL"""
        params = {
            'client_id': self.client_id,
            'redirect_uri': self.redirect_uri,
            'response_type': 'code',
            'scope': scope
        }
        return f"{auth_endpoint}?{urlencode(params)}"
    
    def get_token(self, token_endpoint, code):
        """获取 Token"""
        response = self.session.post(
            token_endpoint,
            data={
                'client_id': self.client_id,
                'client_secret': self.client_secret,
                'code': code,
                'redirect_uri': self.redirect_uri,
                'grant_type': 'authorization_code'
            }
        )
        
        data = response.json()
        self.access_token = data.get('access_token')
        self.refresh_token = data.get('refresh_token')
        
        self.session.headers['Authorization'] = f'Bearer {self.access_token}'
        return data
    
    def refresh_access_token(self, token_endpoint):
        """刷新 Token"""
        response = self.session.post(
            token_endpoint,
            data={
                'client_id': self.client_id,
                'client_secret': self.client_secret,
                'refresh_token': self.refresh_token,
                'grant_type': 'refresh_token'
            }
        )
        
        data = response.json()
        self.access_token = data.get('access_token')
        self.session.headers['Authorization'] = f'Bearer {self.access_token}'
        return data
```

---

## 4. Cookie 持久化

### 4.1 保存和加载 Cookie

```python
import requests
import json
import pickle

def save_cookies_json(session, filepath):
    """保存 Cookie 为 JSON"""
    cookies = session.cookies.get_dict()
    with open(filepath, 'w') as f:
        json.dump(cookies, f)

def load_cookies_json(session, filepath):
    """从 JSON 加载 Cookie"""
    with open(filepath, 'r') as f:
        cookies = json.load(f)
    session.cookies.update(cookies)

def save_cookies_pickle(session, filepath):
    """保存 Cookie 为 Pickle"""
    with open(filepath, 'wb') as f:
        pickle.dump(session.cookies, f)

def load_cookies_pickle(session, filepath):
    """从 Pickle 加载 Cookie"""
    with open(filepath, 'rb') as f:
        session.cookies = pickle.load(f)

# 使用
session = requests.Session()
session.get('https://example.com/login')

# 保存
save_cookies_json(session, 'cookies.json')

# 加载
new_session = requests.Session()
load_cookies_json(new_session, 'cookies.json')
```

### 4.2 使用 http.cookiejar

```python
import requests
from http.cookiejar import LWPCookieJar, MozillaCookieJar

# LWP 格式
session = requests.Session()
session.cookies = LWPCookieJar('cookies.txt')

# 加载已有 Cookie
try:
    session.cookies.load(ignore_discard=True)
except FileNotFoundError:
    pass

# 请求后保存
session.get('https://example.com')
session.cookies.save(ignore_discard=True)

# Mozilla 格式（Netscape）
session.cookies = MozillaCookieJar('cookies.txt')
```

### 4.3 Cookie 管理器

```python
import requests
import json
import os
from datetime import datetime

class CookieManager:
    """Cookie 管理器"""
    
    def __init__(self, storage_path='cookies'):
        self.storage_path = storage_path
        os.makedirs(storage_path, exist_ok=True)
    
    def _get_filepath(self, domain):
        """获取存储路径"""
        safe_domain = domain.replace('.', '_').replace(':', '_')
        return os.path.join(self.storage_path, f'{safe_domain}.json')
    
    def save(self, session, domain):
        """保存 Cookie"""
        filepath = self._get_filepath(domain)
        
        cookies = []
        for cookie in session.cookies:
            cookies.append({
                'name': cookie.name,
                'value': cookie.value,
                'domain': cookie.domain,
                'path': cookie.path,
                'expires': cookie.expires,
                'secure': cookie.secure
            })
        
        data = {
            'domain': domain,
            'cookies': cookies,
            'saved_at': datetime.now().isoformat()
        }
        
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)
    
    def load(self, session, domain):
        """加载 Cookie"""
        filepath = self._get_filepath(domain)
        
        if not os.path.exists(filepath):
            return False
        
        with open(filepath, 'r') as f:
            data = json.load(f)
        
        for cookie in data['cookies']:
            session.cookies.set(
                cookie['name'],
                cookie['value'],
                domain=cookie['domain'],
                path=cookie['path']
            )
        
        return True
    
    def is_valid(self, domain, max_age=3600):
        """检查 Cookie 是否有效"""
        filepath = self._get_filepath(domain)
        
        if not os.path.exists(filepath):
            return False
        
        with open(filepath, 'r') as f:
            data = json.load(f)
        
        saved_at = datetime.fromisoformat(data['saved_at'])
        age = (datetime.now() - saved_at).total_seconds()
        
        return age < max_age
    
    def clear(self, domain):
        """清除 Cookie"""
        filepath = self._get_filepath(domain)
        if os.path.exists(filepath):
            os.remove(filepath)

# 使用
manager = CookieManager()

session = requests.Session()

# 尝试加载已有 Cookie
if manager.is_valid('example.com', max_age=3600):
    manager.load(session, 'example.com')
else:
    # 重新登录
    session.post('https://example.com/login', data={'user': 'test', 'pass': 'test'})
    manager.save(session, 'example.com')
```

---

## 5. 实战应用

### 5.1 自动登录爬虫

```python
import requests
from bs4 import BeautifulSoup
import json
import os

class LoginCrawler:
    """自动登录爬虫"""
    
    def __init__(self, base_url, cookie_file='cookies.json'):
        self.base_url = base_url
        self.cookie_file = cookie_file
        self.session = requests.Session()
        
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0...'
        })
    
    def load_cookies(self):
        """加载 Cookie"""
        if os.path.exists(self.cookie_file):
            with open(self.cookie_file, 'r') as f:
                cookies = json.load(f)
            self.session.cookies.update(cookies)
            return True
        return False
    
    def save_cookies(self):
        """保存 Cookie"""
        with open(self.cookie_file, 'w') as f:
            json.dump(self.session.cookies.get_dict(), f)
    
    def is_logged_in(self):
        """检查是否已登录"""
        response = self.session.get(f'{self.base_url}/user/profile')
        return response.status_code == 200 and '登录' not in response.text
    
    def login(self, username, password):
        """登录"""
        # 获取登录页
        login_page = self.session.get(f'{self.base_url}/login')
        soup = BeautifulSoup(login_page.text, 'lxml')
        
        # 提取隐藏字段
        hidden_inputs = {}
        for inp in soup.select('form input[type="hidden"]'):
            hidden_inputs[inp['name']] = inp.get('value', '')
        
        # 提交登录
        login_data = {
            **hidden_inputs,
            'username': username,
            'password': password
        }
        
        response = self.session.post(
            f'{self.base_url}/login',
            data=login_data
        )
        
        if self.is_logged_in():
            self.save_cookies()
            return True
        
        return False
    
    def ensure_logged_in(self, username, password):
        """确保已登录"""
        self.load_cookies()
        
        if not self.is_logged_in():
            return self.login(username, password)
        
        return True
    
    def get(self, path):
        """发送 GET 请求"""
        return self.session.get(f'{self.base_url}{path}')
    
    def post(self, path, **kwargs):
        """发送 POST 请求"""
        return self.session.post(f'{self.base_url}{path}', **kwargs)

# 使用
crawler = LoginCrawler('https://example.com')

if crawler.ensure_logged_in('user', 'pass'):
    response = crawler.get('/user/orders')
    print(response.text)
```

### 5.2 多账号管理

```python
import requests
import json
import os
from typing import Dict, Optional

class MultiAccountManager:
    """多账号管理器"""
    
    def __init__(self, storage_dir='accounts'):
        self.storage_dir = storage_dir
        self.sessions: Dict[str, requests.Session] = {}
        os.makedirs(storage_dir, exist_ok=True)
    
    def _get_filepath(self, account_id):
        return os.path.join(self.storage_dir, f'{account_id}.json')
    
    def add_account(self, account_id, cookies):
        """添加账号"""
        session = requests.Session()
        session.cookies.update(cookies)
        self.sessions[account_id] = session
        
        # 保存
        with open(self._get_filepath(account_id), 'w') as f:
            json.dump(cookies, f)
    
    def get_session(self, account_id) -> Optional[requests.Session]:
        """获取账号 Session"""
        if account_id in self.sessions:
            return self.sessions[account_id]
        
        filepath = self._get_filepath(account_id)
        if os.path.exists(filepath):
            with open(filepath, 'r') as f:
                cookies = json.load(f)
            
            session = requests.Session()
            session.cookies.update(cookies)
            self.sessions[account_id] = session
            return session
        
        return None
    
    def remove_account(self, account_id):
        """移除账号"""
        if account_id in self.sessions:
            del self.sessions[account_id]
        
        filepath = self._get_filepath(account_id)
        if os.path.exists(filepath):
            os.remove(filepath)
    
    def list_accounts(self):
        """列出所有账号"""
        accounts = []
        for filename in os.listdir(self.storage_dir):
            if filename.endswith('.json'):
                accounts.append(filename[:-5])
        return accounts
    
    def rotate_account(self):
        """轮换账号"""
        accounts = self.list_accounts()
        if not accounts:
            return None
        
        # 简单轮换
        if not hasattr(self, '_current_index'):
            self._current_index = 0
        
        account_id = accounts[self._current_index % len(accounts)]
        self._current_index += 1
        
        return self.get_session(account_id)

# 使用
manager = MultiAccountManager()

# 添加账号
manager.add_account('account1', {'session': 'xxx'})
manager.add_account('account2', {'session': 'yyy'})

# 轮换使用
for i in range(5):
    session = manager.rotate_account()
    response = session.get('https://example.com/api/data')
```

---

## 下一步

下一篇我们将学习浏览器指纹与反检测。

---

## 参考资料

- [Requests Session](https://docs.python-requests.org/en/latest/user/advanced/#session-objects)
- [HTTP Cookie](https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Cookies)
