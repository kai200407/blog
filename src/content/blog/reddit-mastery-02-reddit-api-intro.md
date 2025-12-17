---
title: "Reddit API 入门"
description: "1. [Reddit API 概述](#1-reddit-api-概述)"
pubDate: "2025-12-17"
tags: ["reddit","api","python"]
category: "reddit"
series: "Reddit API 开发"
order: 2
---

> 本文介绍 Reddit API 的基础知识，包括 API 类型、请求方式和基本使用方法。

---

## 目录

1. [Reddit API 概述](#1-reddit-api-概述)
2. [API 访问方式](#2-api-访问方式)
3. [无认证 API 请求](#3-无认证-api-请求)
4. [JSON 数据结构](#4-json-数据结构)
5. [常用 API 端点](#5-常用-api-端点)

---

## 1. Reddit API 概述

### 1.1 什么是 Reddit API

Reddit API 是一套 RESTful 接口，允许开发者：
- 读取 Reddit 公开数据
- 以用户身份发帖、评论、投票
- 管理 Subreddit 和用户设置
- 实时监听新内容

### 1.2 API 版本

Reddit 目前主要使用两种 API：

| API 类型 | 说明 | 认证要求 |
|----------|------|----------|
| JSON API | 在 URL 后添加 `.json` | 可选 |
| OAuth API | 官方推荐的完整 API | 必须 |

### 1.3 API 限制

| 限制类型 | 数值 |
|----------|------|
| 请求频率 | 60 次/分钟（OAuth） |
| 单次返回 | 最多 100 条记录 |
| 分页深度 | 最多 1000 条记录 |

---

## 2. API 访问方式

### 2.1 直接 JSON 访问（无需认证）

最简单的方式是在 Reddit URL 后添加 `.json`：

```
原始 URL: https://www.reddit.com/r/Python/hot
JSON URL: https://www.reddit.com/r/Python/hot.json
```

### 2.2 OAuth2 认证访问

完整功能需要 OAuth2 认证：

```
API 基础 URL: https://oauth.reddit.com
认证 URL: https://www.reddit.com/api/v1/authorize
Token URL: https://www.reddit.com/api/v1/access_token
```

### 2.3 使用封装库

推荐使用官方或社区维护的库：

| 语言 | 库名 | 安装命令 |
|------|------|----------|
| Python | PRAW | `pip install praw` |
| JavaScript | Snoowrap | `npm install snoowrap` |
| Go | go-reddit | `go get github.com/vartanbeno/go-reddit/v2` |

---

## 3. 无认证 API 请求

### 3.1 基本请求示例

使用 Python 的 `requests` 库：

```python
import requests

# 设置 User-Agent（必须）
headers = {
    'User-Agent': 'MyRedditApp/1.0 (by /u/your_username)'
}

# 获取 r/Python 热门帖子
url = 'https://www.reddit.com/r/Python/hot.json'
response = requests.get(url, headers=headers)

# 解析 JSON
data = response.json()

# 打印前 5 个帖子标题
for post in data['data']['children'][:5]:
    print(post['data']['title'])
```

### 3.2 添加查询参数

```python
import requests

headers = {'User-Agent': 'MyRedditApp/1.0'}

# 获取前 25 个帖子，按时间排序
params = {
    'limit': 25,
    't': 'day'  # 时间范围：hour, day, week, month, year, all
}

url = 'https://www.reddit.com/r/Python/top.json'
response = requests.get(url, headers=headers, params=params)
data = response.json()
```

### 3.3 分页请求

Reddit 使用 `after` 和 `before` 参数进行分页：

```python
import requests

headers = {'User-Agent': 'MyRedditApp/1.0'}

def get_all_posts(subreddit, limit=100):
    """获取指定数量的帖子"""
    posts = []
    after = None
    
    while len(posts) < limit:
        params = {'limit': 100}
        if after:
            params['after'] = after
        
        url = f'https://www.reddit.com/r/{subreddit}/new.json'
        response = requests.get(url, headers=headers, params=params)
        data = response.json()
        
        children = data['data']['children']
        if not children:
            break
        
        posts.extend(children)
        after = data['data']['after']
        
        if not after:
            break
    
    return posts[:limit]

# 获取 200 个帖子
posts = get_all_posts('Python', 200)
print(f'获取了 {len(posts)} 个帖子')
```

---

## 4. JSON 数据结构

### 4.1 响应结构概览

Reddit API 返回的 JSON 有固定结构：

```json
{
  "kind": "Listing",
  "data": {
    "after": "t3_abc123",
    "before": null,
    "children": [
      {
        "kind": "t3",
        "data": {
          "id": "abc123",
          "title": "帖子标题",
          "selftext": "帖子内容",
          ...
        }
      }
    ],
    "dist": 25
  }
}
```

### 4.2 Kind 类型说明

Reddit 使用 `kind` 字段标识数据类型：

| Kind | 类型 | 说明 |
|------|------|------|
| t1 | Comment | 评论 |
| t2 | Account | 用户账号 |
| t3 | Link | 帖子/提交 |
| t4 | Message | 私信 |
| t5 | Subreddit | 子版块 |
| t6 | Award | 奖励 |
| Listing | 列表 | 数据列表容器 |

### 4.3 帖子（t3）数据字段

```json
{
  "kind": "t3",
  "data": {
    "id": "abc123",
    "name": "t3_abc123",
    "title": "帖子标题",
    "selftext": "帖子正文（Self Post）",
    "selftext_html": "HTML 格式正文",
    "url": "链接地址",
    "permalink": "/r/Python/comments/abc123/...",
    "author": "用户名",
    "subreddit": "Python",
    "subreddit_id": "t5_2qh0y",
    "score": 1234,
    "upvote_ratio": 0.95,
    "num_comments": 56,
    "created_utc": 1234567890.0,
    "is_self": true,
    "over_18": false,
    "spoiler": false,
    "stickied": false,
    "locked": false,
    "distinguished": null,
    "link_flair_text": "Discussion",
    "thumbnail": "https://..."
  }
}
```

### 4.4 评论（t1）数据字段

```json
{
  "kind": "t1",
  "data": {
    "id": "xyz789",
    "name": "t1_xyz789",
    "body": "评论内容",
    "body_html": "HTML 格式内容",
    "author": "用户名",
    "parent_id": "t3_abc123",
    "link_id": "t3_abc123",
    "subreddit": "Python",
    "score": 42,
    "created_utc": 1234567890.0,
    "edited": false,
    "is_submitter": false,
    "stickied": false,
    "replies": { ... }
  }
}
```

---

## 5. 常用 API 端点

### 5.1 Subreddit 相关

| 端点 | 说明 |
|------|------|
| `/r/{subreddit}/hot.json` | 热门帖子 |
| `/r/{subreddit}/new.json` | 最新帖子 |
| `/r/{subreddit}/top.json` | 最高分帖子 |
| `/r/{subreddit}/rising.json` | 上升中帖子 |
| `/r/{subreddit}/controversial.json` | 争议帖子 |
| `/r/{subreddit}/about.json` | Subreddit 信息 |
| `/r/{subreddit}/about/rules.json` | 版规 |

### 5.2 帖子相关

| 端点 | 说明 |
|------|------|
| `/comments/{post_id}.json` | 帖子详情和评论 |
| `/r/{subreddit}/comments/{post_id}.json` | 同上 |
| `/duplicates/{post_id}.json` | 重复帖子 |

### 5.3 用户相关

| 端点 | 说明 |
|------|------|
| `/user/{username}/about.json` | 用户信息 |
| `/user/{username}/submitted.json` | 用户发帖 |
| `/user/{username}/comments.json` | 用户评论 |
| `/user/{username}/overview.json` | 用户活动概览 |

### 5.4 搜索相关

| 端点 | 说明 |
|------|------|
| `/search.json?q={query}` | 全站搜索 |
| `/r/{subreddit}/search.json?q={query}` | Subreddit 内搜索 |
| `/subreddits/search.json?q={query}` | 搜索 Subreddit |

### 5.5 示例：获取帖子评论

```python
import requests

headers = {'User-Agent': 'MyRedditApp/1.0'}

def get_post_comments(post_id, limit=100):
    """获取帖子的所有评论"""
    url = f'https://www.reddit.com/comments/{post_id}.json'
    params = {'limit': limit, 'depth': 10}
    
    response = requests.get(url, headers=headers, params=params)
    data = response.json()
    
    # data[0] 是帖子信息
    # data[1] 是评论列表
    post = data[0]['data']['children'][0]['data']
    comments = data[1]['data']['children']
    
    return post, comments

# 使用示例
post_id = 'abc123'  # 替换为实际帖子 ID
post, comments = get_post_comments(post_id)

print(f"帖子标题: {post['title']}")
print(f"评论数量: {len(comments)}")

for comment in comments[:5]:
    if comment['kind'] == 't1':
        print(f"- {comment['data']['author']}: {comment['data']['body'][:50]}...")
```

---

## 实践练习

### 练习 1：获取热门帖子

编写脚本获取 r/programming 的前 10 个热门帖子，打印标题和分数。

### 练习 2：搜索帖子

使用搜索 API 在 r/Python 中搜索 "machine learning" 相关帖子。

### 练习 3：获取用户信息

获取任意用户的基本信息和最近 5 条评论。

---

## 下一步

在下一篇文章中，我们将学习如何获取 Reddit API 凭证，进行 OAuth2 认证，解锁完整的 API 功能。

---

## 参考资料

- [Reddit API 官方文档](https://www.reddit.com/dev/api/)
- [Reddit JSON 文档解析](https://www.jcchouinard.com/documentation-on-reddit-apis-json/)
