---
title: "Reddit 数据结构详解"
description: "1. [Thing 基类](#1-thing-基类)"
pubDate: "2025-12-17"
tags: ["reddit","api","python"]
category: "reddit"
series: "Reddit API 开发"
order: 4
---

> 本文深入解析 Reddit API 返回的数据结构，帮助你理解和操作各类 Reddit 实体。

---

## 目录

1. [Thing 基类](#1-thing-基类)
2. [Subreddit 结构](#2-subreddit-结构)
3. [Submission 结构](#3-submission-结构)
4. [Comment 结构](#4-comment-结构)
5. [Redditor 结构](#5-redditor-结构)
6. [Listing 容器](#6-listing-容器)

---

## 1. Thing 基类

Reddit 中所有实体都继承自 "Thing" 基类，具有统一的标识系统。

### 1.1 Fullname 格式

每个 Thing 都有唯一的 fullname，格式为 `{kind}_{id}`：

```
t1_abc123  → 评论
t2_def456  → 用户
t3_ghi789  → 帖子
t4_jkl012  → 私信
t5_mno345  → Subreddit
t6_pqr678  → 奖励
```

### 1.2 Kind 类型对照表

| Kind | 类型 | Python 类 | 说明 |
|------|------|-----------|------|
| t1 | Comment | `praw.models.Comment` | 评论 |
| t2 | Account | `praw.models.Redditor` | 用户账号 |
| t3 | Link | `praw.models.Submission` | 帖子/提交 |
| t4 | Message | `praw.models.Message` | 私信 |
| t5 | Subreddit | `praw.models.Subreddit` | 子版块 |
| t6 | Award | - | 奖励 |

### 1.3 通用属性

所有 Thing 都具有以下属性：

```python
{
    "id": "abc123",           # 短 ID
    "name": "t3_abc123",      # Fullname
    "kind": "t3",             # 类型标识
    "created": 1234567890.0,  # 创建时间（本地）
    "created_utc": 1234567890.0  # 创建时间（UTC）
}
```

---

## 2. Subreddit 结构

### 2.1 完整字段

```python
{
    # 基本信息
    "id": "2qh0y",
    "name": "t5_2qh0y",
    "display_name": "Python",
    "display_name_prefixed": "r/Python",
    "title": "Python",
    "public_description": "News about the programming language Python...",
    "description": "完整的版块描述（Markdown）",
    "description_html": "HTML 格式描述",
    
    # 统计数据
    "subscribers": 1234567,
    "accounts_active": 5678,
    "active_user_count": 5678,
    
    # 设置
    "subreddit_type": "public",  # public, private, restricted
    "submission_type": "any",     # any, link, self
    "over18": false,
    "spoilers_enabled": true,
    "allow_videos": true,
    "allow_images": true,
    
    # 外观
    "header_img": "https://...",
    "header_title": "Python",
    "icon_img": "https://...",
    "banner_img": "https://...",
    "primary_color": "#0079d3",
    "key_color": "#0079d3",
    
    # 用户关系
    "user_is_subscriber": true,
    "user_is_moderator": false,
    "user_is_banned": false,
    
    # 时间
    "created_utc": 1234567890.0
}
```

### 2.2 使用 PRAW 获取

```python
import praw

reddit = praw.Reddit(...)

# 获取 Subreddit
subreddit = reddit.subreddit('Python')

# 访问属性
print(f"名称: {subreddit.display_name}")
print(f"标题: {subreddit.title}")
print(f"订阅者: {subreddit.subscribers:,}")
print(f"描述: {subreddit.public_description[:100]}...")
print(f"类型: {subreddit.subreddit_type}")
print(f"NSFW: {subreddit.over18}")

# 检查用户关系
print(f"已订阅: {subreddit.user_is_subscriber}")
print(f"是版主: {subreddit.user_is_moderator}")
```

### 2.3 Subreddit 类型

| 类型 | 说明 |
|------|------|
| public | 公开，任何人可查看和发帖 |
| restricted | 受限，任何人可查看，仅批准用户可发帖 |
| private | 私有，仅批准用户可查看和发帖 |
| gold_restricted | 仅 Reddit Premium 用户可访问 |
| archived | 已归档，只读 |

---

## 3. Submission 结构

### 3.1 完整字段

```python
{
    # 基本信息
    "id": "abc123",
    "name": "t3_abc123",
    "title": "帖子标题",
    "selftext": "帖子正文（Self Post）",
    "selftext_html": "HTML 格式正文",
    "url": "https://example.com/link",  # Link Post 的链接
    "permalink": "/r/Python/comments/abc123/post_title/",
    
    # 作者和版块
    "author": "username",
    "author_fullname": "t2_xyz789",
    "subreddit": "Python",
    "subreddit_id": "t5_2qh0y",
    "subreddit_name_prefixed": "r/Python",
    
    # 投票和评论
    "score": 1234,
    "upvote_ratio": 0.95,
    "ups": 1300,
    "downs": 66,
    "num_comments": 56,
    
    # 状态标记
    "is_self": true,           # 是否为 Self Post
    "is_video": false,
    "is_original_content": false,
    "over_18": false,          # NSFW
    "spoiler": false,
    "stickied": false,         # 置顶
    "locked": false,           # 锁定
    "archived": false,         # 归档
    "hidden": false,
    "saved": false,
    
    # 分类和标签
    "link_flair_text": "Discussion",
    "link_flair_css_class": "discussion",
    "link_flair_template_id": "xxx",
    "category": null,
    
    # 媒体
    "thumbnail": "https://...",
    "thumbnail_height": 140,
    "thumbnail_width": 140,
    "preview": { ... },        # 预览图信息
    "media": { ... },          # 媒体信息
    "gallery_data": { ... },   # 图库数据
    
    # 奖励
    "all_awardings": [...],
    "total_awards_received": 5,
    "gilded": 2,
    
    # 编辑信息
    "edited": false,           # 或编辑时间戳
    "distinguished": null,     # null, "moderator", "admin"
    
    # 交叉发帖
    "crosspost_parent": "t3_xyz789",
    "crosspost_parent_list": [...],
    "num_crossposts": 3,
    
    # 时间
    "created_utc": 1234567890.0
}
```

### 3.2 使用 PRAW 获取

```python
import praw
from datetime import datetime

reddit = praw.Reddit(...)

# 方式 1：通过 ID 获取
submission = reddit.submission(id='abc123')
# 或使用 URL
submission = reddit.submission(url='https://www.reddit.com/r/Python/comments/abc123/...')

# 访问属性
print(f"标题: {submission.title}")
print(f"作者: {submission.author}")
print(f"分数: {submission.score}")
print(f"评论数: {submission.num_comments}")
print(f"链接: {submission.url}")

# 判断帖子类型
if submission.is_self:
    print(f"正文: {submission.selftext[:200]}...")
else:
    print(f"链接: {submission.url}")

# 时间处理
created_time = datetime.utcfromtimestamp(submission.created_utc)
print(f"发布时间: {created_time}")

# 遍历热门帖子
for submission in reddit.subreddit('Python').hot(limit=10):
    print(f"[{submission.score}] {submission.title}")
```

### 3.3 帖子排序方式

```python
subreddit = reddit.subreddit('Python')

# 不同排序方式
hot_posts = subreddit.hot(limit=10)
new_posts = subreddit.new(limit=10)
top_posts = subreddit.top(limit=10, time_filter='week')
rising_posts = subreddit.rising(limit=10)
controversial_posts = subreddit.controversial(limit=10, time_filter='day')

# time_filter 选项：hour, day, week, month, year, all
```

---

## 4. Comment 结构

### 4.1 完整字段

```python
{
    # 基本信息
    "id": "xyz789",
    "name": "t1_xyz789",
    "body": "评论内容",
    "body_html": "HTML 格式内容",
    
    # 关联信息
    "author": "username",
    "author_fullname": "t2_abc123",
    "link_id": "t3_abc123",        # 所属帖子
    "parent_id": "t3_abc123",      # 父级（帖子或评论）
    "subreddit": "Python",
    "subreddit_id": "t5_2qh0y",
    
    # 投票
    "score": 42,
    "ups": 45,
    "downs": 3,
    "score_hidden": false,
    
    # 状态
    "stickied": false,
    "locked": false,
    "archived": false,
    "collapsed": false,
    "is_submitter": false,         # 是否为帖子作者
    "edited": false,
    "distinguished": null,
    
    # 子评论
    "replies": { ... },            # Listing 或空字符串
    "depth": 0,                    # 嵌套深度
    
    # 奖励
    "all_awardings": [...],
    "total_awards_received": 1,
    
    # 时间
    "created_utc": 1234567890.0
}
```

### 4.2 使用 PRAW 获取

```python
import praw

reddit = praw.Reddit(...)

# 获取帖子的评论
submission = reddit.submission(id='abc123')

# 展开所有评论（替换 "More Comments"）
submission.comments.replace_more(limit=None)

# 遍历顶级评论
for comment in submission.comments:
    print(f"[{comment.score}] {comment.author}: {comment.body[:50]}...")

# 遍历所有评论（扁平化）
for comment in submission.comments.list():
    print(f"[深度 {comment.depth}] {comment.author}: {comment.body[:30]}...")
```

### 4.3 评论树遍历

```python
def print_comment_tree(comment, indent=0):
    """递归打印评论树"""
    prefix = "  " * indent
    print(f"{prefix}├─ [{comment.score}] {comment.author}: {comment.body[:30]}...")
    
    # 递归处理子评论
    if hasattr(comment, 'replies'):
        for reply in comment.replies:
            if isinstance(reply, praw.models.Comment):
                print_comment_tree(reply, indent + 1)

# 使用
submission = reddit.submission(id='abc123')
submission.comments.replace_more(limit=0)

for top_comment in submission.comments:
    print_comment_tree(top_comment)
```

### 4.4 处理 MoreComments

```python
submission = reddit.submission(id='abc123')

# 方式 1：完全展开（可能很慢）
submission.comments.replace_more(limit=None)

# 方式 2：限制展开数量
submission.comments.replace_more(limit=10)

# 方式 3：不展开，跳过 MoreComments
submission.comments.replace_more(limit=0)

# 方式 4：手动处理
for item in submission.comments:
    if isinstance(item, praw.models.MoreComments):
        print(f"还有 {item.count} 条评论未加载")
    else:
        print(f"评论: {item.body[:50]}...")
```

---

## 5. Redditor 结构

### 5.1 完整字段

```python
{
    # 基本信息
    "id": "abc123",
    "name": "username",
    
    # Karma
    "link_karma": 12345,
    "comment_karma": 67890,
    "total_karma": 80235,
    "awardee_karma": 100,
    "awarder_karma": 50,
    
    # 状态
    "is_employee": false,
    "is_mod": true,
    "is_gold": true,           # Reddit Premium
    "has_verified_email": true,
    "verified": true,
    
    # 外观
    "icon_img": "https://...",
    "snoovatar_img": "https://...",
    
    # 设置（仅自己可见）
    "pref_show_snoovatar": true,
    "accept_followers": true,
    "has_subscribed": true,
    
    # 时间
    "created_utc": 1234567890.0
}
```

### 5.2 使用 PRAW 获取

```python
import praw
from datetime import datetime

reddit = praw.Reddit(...)

# 获取用户
redditor = reddit.redditor('spez')

# 基本信息
print(f"用户名: {redditor.name}")
print(f"Link Karma: {redditor.link_karma:,}")
print(f"Comment Karma: {redditor.comment_karma:,}")

# 账号年龄
created = datetime.utcfromtimestamp(redditor.created_utc)
age = datetime.utcnow() - created
print(f"账号年龄: {age.days} 天")

# 获取当前登录用户
me = reddit.user.me()
print(f"当前用户: {me.name}")
```

### 5.3 获取用户活动

```python
redditor = reddit.redditor('username')

# 用户发帖
for submission in redditor.submissions.new(limit=10):
    print(f"帖子: {submission.title}")

# 用户评论
for comment in redditor.comments.new(limit=10):
    print(f"评论: {comment.body[:50]}...")

# 用户活动（帖子+评论混合）
for item in redditor.new(limit=10):
    if isinstance(item, praw.models.Submission):
        print(f"[帖子] {item.title}")
    else:
        print(f"[评论] {item.body[:50]}...")

# 用户点赞（仅自己可见）
for item in redditor.upvoted(limit=10):
    print(f"点赞: {item.title}")

# 用户保存（仅自己可见）
for item in redditor.saved(limit=10):
    print(f"保存: {item}")
```

---

## 6. Listing 容器

### 6.1 Listing 结构

Listing 是 Reddit API 返回列表数据的容器：

```python
{
    "kind": "Listing",
    "data": {
        "after": "t3_abc123",    # 下一页游标
        "before": null,          # 上一页游标
        "dist": 25,              # 返回数量
        "modhash": "xxx",        # 安全令牌
        "geo_filter": null,
        "children": [            # 实际数据
            { "kind": "t3", "data": { ... } },
            { "kind": "t3", "data": { ... } },
            ...
        ]
    }
}
```

### 6.2 分页处理

```python
import requests

headers = {'User-Agent': 'MyBot/1.0'}

def get_all_posts(subreddit, max_posts=500):
    """分页获取所有帖子"""
    posts = []
    after = None
    
    while len(posts) < max_posts:
        params = {'limit': 100}
        if after:
            params['after'] = after
        
        url = f'https://www.reddit.com/r/{subreddit}/new.json'
        response = requests.get(url, headers=headers, params=params)
        data = response.json()
        
        children = data['data']['children']
        if not children:
            break
        
        posts.extend([child['data'] for child in children])
        after = data['data']['after']
        
        if not after:
            break
        
        # 遵守速率限制
        import time
        time.sleep(1)
    
    return posts[:max_posts]
```

### 6.3 PRAW 的 ListingGenerator

PRAW 自动处理分页：

```python
import praw

reddit = praw.Reddit(...)

# 自动分页，获取 500 个帖子
for i, submission in enumerate(reddit.subreddit('Python').new(limit=500)):
    print(f"{i+1}. {submission.title}")
    if i >= 499:
        break

# 无限迭代（小心使用）
for submission in reddit.subreddit('Python').new(limit=None):
    print(submission.title)
    # 需要自己控制退出条件
```

---

## 数据结构速查表

| 实体 | Kind | ID 示例 | 主要属性 |
|------|------|---------|----------|
| Subreddit | t5 | t5_2qh0y | display_name, subscribers, description |
| Submission | t3 | t3_abc123 | title, selftext, score, num_comments |
| Comment | t1 | t1_xyz789 | body, score, parent_id, replies |
| Redditor | t2 | t2_def456 | name, link_karma, comment_karma |
| Message | t4 | t4_ghi789 | subject, body, author |

---

## 下一步

现在你已经了解了 Reddit 的核心数据结构，下一篇我们将学习 API 的速率限制和最佳实践，确保你的应用稳定运行。

---

## 参考资料

- [Reddit API 类型文档](https://www.reddit.com/dev/api/#fullnames)
- [PRAW 模型文档](https://praw.readthedocs.io/en/stable/code_overview/models/)
