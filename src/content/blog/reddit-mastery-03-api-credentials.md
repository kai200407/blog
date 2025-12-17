---
title: "获取 Reddit API 凭证"
description: "1. [创建 Reddit 应用](#1-创建-reddit-应用)"
pubDate: "2025-12-17"
tags: ["reddit","api","python"]
category: "reddit"
series: "Reddit API 开发"
order: 3
---

> 本文详细介绍如何创建 Reddit 应用、获取 API 凭证，并完成 OAuth2 认证流程。

---

## 目录

1. [创建 Reddit 应用](#1-创建-reddit-应用)
2. [理解 OAuth2 认证](#2-理解-oauth2-认证)
3. [获取 Access Token](#3-获取-access-token)
4. [使用 PRAW 简化认证](#4-使用-praw-简化认证)
5. [凭证安全管理](#5-凭证安全管理)

---

## 1. 创建 Reddit 应用

### 1.1 前置条件

- 一个 Reddit 账号
- 账号邮箱已验证

### 1.2 创建步骤

1. **登录 Reddit** 并访问 [Reddit Apps](https://www.reddit.com/prefs/apps)

2. **点击 "create another app..."** 或 "are you a developer? create an app..."

3. **填写应用信息**：

| 字段 | 说明 | 示例 |
|------|------|------|
| name | 应用名称 | MyRedditBot |
| App type | 应用类型 | script（个人使用） |
| description | 描述（可选） | A bot for learning Reddit API |
| about url | 关于页面（可选） | 留空 |
| redirect uri | 重定向 URI | http://localhost:8080 |

4. **选择应用类型**：

| 类型 | 适用场景 |
|------|----------|
| **script** | 个人脚本，只访问自己账号 |
| **web app** | 网站应用，需要用户授权 |
| **installed app** | 移动/桌面应用 |

5. **点击 "create app"**

### 1.3 获取凭证

创建成功后，你会看到：

```
MyRedditBot
personal use script

client_id: AbCdEfGhIjKlMn    ← 在应用名称下方
secret: OpQrStUvWxYz123456   ← 标记为 "secret"
```

**重要**：
- `client_id`：14 字符的字符串
- `client_secret`：27 字符的字符串
- 妥善保管，不要泄露

---

## 2. 理解 OAuth2 认证

### 2.1 OAuth2 流程概述

```
┌─────────┐     ┌─────────┐     ┌─────────┐
│  你的   │     │ Reddit  │     │ Reddit  │
│  应用   │     │  Auth   │     │   API   │
└────┬────┘     └────┬────┘     └────┬────┘
     │               │               │
     │ 1. 请求授权   │               │
     │──────────────▶│               │
     │               │               │
     │ 2. 用户登录授权│               │
     │◀──────────────│               │
     │               │               │
     │ 3. 获取 Token │               │
     │──────────────▶│               │
     │               │               │
     │ 4. 返回 Token │               │
     │◀──────────────│               │
     │               │               │
     │ 5. 使用 Token 请求 API        │
     │──────────────────────────────▶│
     │               │               │
     │ 6. 返回数据   │               │
     │◀──────────────────────────────│
```

### 2.2 认证类型

#### Script 类型（Password Grant）

最简单的方式，适合个人脚本：

```python
import requests

# 认证信息
client_id = 'your_client_id'
client_secret = 'your_client_secret'
username = 'your_reddit_username'
password = 'your_reddit_password'

# 获取 Access Token
auth = requests.auth.HTTPBasicAuth(client_id, client_secret)
data = {
    'grant_type': 'password',
    'username': username,
    'password': password
}
headers = {'User-Agent': 'MyRedditBot/1.0'}

response = requests.post(
    'https://www.reddit.com/api/v1/access_token',
    auth=auth,
    data=data,
    headers=headers
)

token = response.json()
print(token)
# {'access_token': 'xxx', 'token_type': 'bearer', 'expires_in': 86400, 'scope': '*'}
```

#### Web App 类型（Authorization Code Grant）

适合需要用户授权的应用：

```python
import requests
import webbrowser
from urllib.parse import urlencode

client_id = 'your_client_id'
client_secret = 'your_client_secret'
redirect_uri = 'http://localhost:8080'

# 步骤 1：生成授权 URL
state = 'random_string_for_security'
params = {
    'client_id': client_id,
    'response_type': 'code',
    'state': state,
    'redirect_uri': redirect_uri,
    'duration': 'permanent',
    'scope': 'identity read submit'
}
auth_url = f"https://www.reddit.com/api/v1/authorize?{urlencode(params)}"

print(f"请访问以下 URL 进行授权：\n{auth_url}")
webbrowser.open(auth_url)

# 步骤 2：用户授权后，从回调 URL 获取 code
# 回调 URL 格式：http://localhost:8080?state=xxx&code=yyy
code = input("请输入回调 URL 中的 code 参数：")

# 步骤 3：用 code 换取 Access Token
auth = requests.auth.HTTPBasicAuth(client_id, client_secret)
data = {
    'grant_type': 'authorization_code',
    'code': code,
    'redirect_uri': redirect_uri
}
headers = {'User-Agent': 'MyRedditBot/1.0'}

response = requests.post(
    'https://www.reddit.com/api/v1/access_token',
    auth=auth,
    data=data,
    headers=headers
)

token = response.json()
print(token)
# {'access_token': 'xxx', 'token_type': 'bearer', 'expires_in': 86400, 
#  'refresh_token': 'yyy', 'scope': 'identity read submit'}
```

### 2.3 权限范围（Scope）

| Scope | 说明 |
|-------|------|
| identity | 读取用户身份信息 |
| read | 读取帖子和评论 |
| submit | 发帖和评论 |
| vote | 投票 |
| edit | 编辑帖子和评论 |
| delete | 删除帖子和评论 |
| history | 读取用户历史 |
| subscribe | 订阅/取消订阅 |
| modposts | 版主操作 |
| * | 所有权限 |

---

## 3. 获取 Access Token

### 3.1 完整的 Token 获取脚本

```python
import requests
import json
from datetime import datetime, timedelta

class RedditAuth:
    """Reddit OAuth2 认证管理器"""
    
    def __init__(self, client_id, client_secret, username, password, user_agent):
        self.client_id = client_id
        self.client_secret = client_secret
        self.username = username
        self.password = password
        self.user_agent = user_agent
        self.access_token = None
        self.token_expires = None
    
    def get_token(self):
        """获取或刷新 Access Token"""
        if self.access_token and self.token_expires > datetime.now():
            return self.access_token
        
        auth = requests.auth.HTTPBasicAuth(self.client_id, self.client_secret)
        data = {
            'grant_type': 'password',
            'username': self.username,
            'password': self.password
        }
        headers = {'User-Agent': self.user_agent}
        
        response = requests.post(
            'https://www.reddit.com/api/v1/access_token',
            auth=auth,
            data=data,
            headers=headers
        )
        
        if response.status_code == 200:
            token_data = response.json()
            self.access_token = token_data['access_token']
            expires_in = token_data.get('expires_in', 3600)
            self.token_expires = datetime.now() + timedelta(seconds=expires_in - 60)
            return self.access_token
        else:
            raise Exception(f"认证失败: {response.text}")
    
    def get_headers(self):
        """获取带认证的请求头"""
        token = self.get_token()
        return {
            'Authorization': f'bearer {token}',
            'User-Agent': self.user_agent
        }

# 使用示例
auth = RedditAuth(
    client_id='your_client_id',
    client_secret='your_client_secret',
    username='your_username',
    password='your_password',
    user_agent='MyRedditBot/1.0 (by /u/your_username)'
)

# 发起认证请求
headers = auth.get_headers()
response = requests.get('https://oauth.reddit.com/api/v1/me', headers=headers)
print(response.json())
```

### 3.2 使用 Refresh Token

对于 Web App 类型，使用 Refresh Token 获取新的 Access Token：

```python
def refresh_access_token(client_id, client_secret, refresh_token, user_agent):
    """使用 Refresh Token 获取新的 Access Token"""
    auth = requests.auth.HTTPBasicAuth(client_id, client_secret)
    data = {
        'grant_type': 'refresh_token',
        'refresh_token': refresh_token
    }
    headers = {'User-Agent': user_agent}
    
    response = requests.post(
        'https://www.reddit.com/api/v1/access_token',
        auth=auth,
        data=data,
        headers=headers
    )
    
    return response.json()
```

---

## 4. 使用 PRAW 简化认证

### 4.1 安装 PRAW

```bash
pip install praw
```

### 4.2 Script 类型认证

```python
import praw

reddit = praw.Reddit(
    client_id='your_client_id',
    client_secret='your_client_secret',
    username='your_username',
    password='your_password',
    user_agent='MyRedditBot/1.0 (by /u/your_username)'
)

# 验证认证成功
print(f"已登录为: {reddit.user.me()}")
print(f"只读模式: {reddit.read_only}")
```

### 4.3 只读模式（无需用户名密码）

```python
import praw

reddit = praw.Reddit(
    client_id='your_client_id',
    client_secret='your_client_secret',
    user_agent='MyRedditBot/1.0 (by /u/your_username)'
)

# 只读模式
print(f"只读模式: {reddit.read_only}")  # True

# 可以读取公开数据
for submission in reddit.subreddit('Python').hot(limit=5):
    print(submission.title)
```

### 4.4 使用配置文件

创建 `praw.ini` 文件：

```ini
[bot1]
client_id=your_client_id
client_secret=your_client_secret
username=your_username
password=your_password
user_agent=MyRedditBot/1.0 (by /u/your_username)

[readonly]
client_id=your_client_id
client_secret=your_client_secret
user_agent=MyReadOnlyApp/1.0
```

使用配置：

```python
import praw

# 使用 bot1 配置
reddit = praw.Reddit('bot1')

# 使用 readonly 配置
reddit_readonly = praw.Reddit('readonly')
```

---

## 5. 凭证安全管理

### 5.1 使用环境变量

```python
import os
import praw

reddit = praw.Reddit(
    client_id=os.environ['REDDIT_CLIENT_ID'],
    client_secret=os.environ['REDDIT_CLIENT_SECRET'],
    username=os.environ['REDDIT_USERNAME'],
    password=os.environ['REDDIT_PASSWORD'],
    user_agent=os.environ.get('REDDIT_USER_AGENT', 'MyBot/1.0')
)
```

设置环境变量：

```bash
# Linux/Mac
export REDDIT_CLIENT_ID='your_client_id'
export REDDIT_CLIENT_SECRET='your_client_secret'
export REDDIT_USERNAME='your_username'
export REDDIT_PASSWORD='your_password'

# Windows
set REDDIT_CLIENT_ID=your_client_id
set REDDIT_CLIENT_SECRET=your_client_secret
```

### 5.2 使用 .env 文件

安装 python-dotenv：

```bash
pip install python-dotenv
```

创建 `.env` 文件：

```env
REDDIT_CLIENT_ID=your_client_id
REDDIT_CLIENT_SECRET=your_client_secret
REDDIT_USERNAME=your_username
REDDIT_PASSWORD=your_password
REDDIT_USER_AGENT=MyRedditBot/1.0 (by /u/your_username)
```

使用：

```python
from dotenv import load_dotenv
import os
import praw

load_dotenv()

reddit = praw.Reddit(
    client_id=os.getenv('REDDIT_CLIENT_ID'),
    client_secret=os.getenv('REDDIT_CLIENT_SECRET'),
    username=os.getenv('REDDIT_USERNAME'),
    password=os.getenv('REDDIT_PASSWORD'),
    user_agent=os.getenv('REDDIT_USER_AGENT')
)
```

### 5.3 安全最佳实践

1. **永远不要**将凭证提交到 Git
   ```gitignore
   # .gitignore
   .env
   praw.ini
   *_secrets.json
   ```

2. **使用最小权限原则**：只申请需要的 scope

3. **定期轮换密码**：尤其是 script 类型应用

4. **监控 API 使用**：检查异常活动

5. **使用 2FA**：为 Reddit 账号启用两步验证

---

## 常见问题

### Q1: 认证失败，返回 401

检查：
- client_id 和 client_secret 是否正确
- 用户名密码是否正确
- 账号是否启用了 2FA（需要使用 app password）

### Q2: 返回 "invalid_grant"

可能原因：
- 密码错误
- 账号被锁定
- 需要验证邮箱

### Q3: 返回 "too many requests"

解决方案：
- 降低请求频率
- 添加请求间隔
- 检查是否有其他程序在使用同一凭证

---

## 下一步

现在你已经获得了 API 凭证并完成了认证，下一篇我们将深入学习 Reddit 的数据结构，了解如何解析和使用 API 返回的数据。

---

## 参考资料

- [Reddit OAuth2 文档](https://github.com/reddit-archive/reddit/wiki/OAuth2)
- [PRAW 认证文档](https://praw.readthedocs.io/en/stable/getting_started/authentication.html)
