---
title: "CSS 选择器"
description: "1. [CSS 选择器基础](#1-css-选择器基础)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 7
---

> 本文介绍如何使用 CSS 选择器提取网页数据。

---

## 目录

1. [CSS 选择器基础](#1-css-选择器基础)
2. [常用选择器](#2-常用选择器)
3. [组合选择器](#3-组合选择器)
4. [伪类选择器](#4-伪类选择器)
5. [实战应用](#5-实战应用)

---

## 1. CSS 选择器基础

### 1.1 什么是 CSS 选择器

CSS 选择器是用于选择 HTML 元素的模式。在爬虫中，我们使用它来定位和提取数据。

### 1.2 使用方式

```python
from bs4 import BeautifulSoup

html = """
<html>
<body>
    <div class="container">
        <h1 id="title">标题</h1>
        <p class="content">内容</p>
        <ul>
            <li>项目1</li>
            <li>项目2</li>
        </ul>
    </div>
</body>
</html>
"""

soup = BeautifulSoup(html, 'lxml')

# 使用 select 返回列表
elements = soup.select('div.container p')

# 使用 select_one 返回单个元素
element = soup.select_one('#title')
```

---

## 2. 常用选择器

### 2.1 基本选择器

| 选择器 | 示例 | 说明 |
|--------|------|------|
| 元素 | `div` | 选择所有 div 元素 |
| 类 | `.class` | 选择 class="class" 的元素 |
| ID | `#id` | 选择 id="id" 的元素 |
| 通配符 | `*` | 选择所有元素 |

```python
# 元素选择器
soup.select('div')       # 所有 div
soup.select('p')         # 所有 p

# 类选择器
soup.select('.content')  # class="content"
soup.select('.a.b')      # 同时有 class a 和 b

# ID 选择器
soup.select('#title')    # id="title"

# 通配符
soup.select('*')         # 所有元素
```

### 2.2 属性选择器

| 选择器 | 说明 |
|--------|------|
| `[attr]` | 有该属性 |
| `[attr=value]` | 属性等于值 |
| `[attr~=value]` | 属性包含单词 |
| `[attr^=value]` | 属性以值开头 |
| `[attr$=value]` | 属性以值结尾 |
| `[attr*=value]` | 属性包含值 |

```python
# 有 href 属性
soup.select('[href]')

# href 等于特定值
soup.select('[href="https://example.com"]')

# href 以 https 开头
soup.select('[href^="https"]')

# href 以 .pdf 结尾
soup.select('[href$=".pdf"]')

# href 包含 example
soup.select('[href*="example"]')

# data 属性
soup.select('[data-id="123"]')
soup.select('[data-type^="article"]')
```

---

## 3. 组合选择器

### 3.1 后代选择器

```python
# 空格 - 所有后代
soup.select('div p')           # div 内所有 p
soup.select('.container a')    # .container 内所有 a

# > - 直接子元素
soup.select('div > p')         # div 的直接子 p
soup.select('ul > li')         # ul 的直接子 li

# + - 相邻兄弟
soup.select('h1 + p')          # h1 后面紧邻的 p

# ~ - 所有兄弟
soup.select('h1 ~ p')          # h1 后面所有的 p 兄弟
```

### 3.2 多选择器

```python
# 逗号 - 多个选择器
soup.select('h1, h2, h3')      # 所有 h1, h2, h3
soup.select('.a, .b')          # class a 或 b
```

### 3.3 组合示例

```python
html = """
<div class="article">
    <h2 class="title">文章标题</h2>
    <div class="meta">
        <span class="author">作者</span>
        <span class="date">2024-01-01</span>
    </div>
    <div class="content">
        <p>第一段</p>
        <p>第二段</p>
    </div>
</div>
"""

soup = BeautifulSoup(html, 'lxml')

# 文章标题
title = soup.select_one('.article > .title')

# 作者
author = soup.select_one('.article .meta .author')

# 所有段落
paragraphs = soup.select('.article .content p')

# 第一段
first_p = soup.select_one('.article .content > p')
```

---

## 4. 伪类选择器

### 4.1 位置伪类

```python
# 第一个/最后一个
soup.select('li:first-child')   # 第一个 li
soup.select('li:last-child')    # 最后一个 li

# 第 n 个
soup.select('li:nth-child(2)')  # 第 2 个 li
soup.select('li:nth-child(odd)')   # 奇数位置
soup.select('li:nth-child(even)')  # 偶数位置
soup.select('li:nth-child(3n)')    # 3 的倍数位置

# 倒数第 n 个
soup.select('li:nth-last-child(1)')  # 倒数第 1 个

# 唯一子元素
soup.select('p:only-child')     # 是唯一子元素的 p
```

### 4.2 类型伪类

```python
# 同类型第一个/最后一个
soup.select('p:first-of-type')
soup.select('p:last-of-type')

# 同类型第 n 个
soup.select('p:nth-of-type(2)')

# 唯一同类型
soup.select('p:only-of-type')
```

### 4.3 否定伪类

```python
# 不匹配的元素
soup.select('li:not(.active)')     # 没有 .active 的 li
soup.select('a:not([href^="http"])')  # 非外链
```

### 4.4 内容伪类

```python
# 空元素
soup.select('p:empty')

# 包含文本（BeautifulSoup 扩展）
soup.select('p:-soup-contains("关键词")')
soup.select('a:-soup-contains-own("点击")')
```

---

## 5. 实战应用

### 5.1 提取文章列表

```python
from bs4 import BeautifulSoup

html = """
<div class="article-list">
    <article class="post">
        <h2 class="title"><a href="/post/1">文章1</a></h2>
        <div class="meta">
            <span class="author">作者A</span>
            <time datetime="2024-01-01">2024年1月1日</time>
        </div>
        <p class="summary">摘要内容...</p>
        <div class="tags">
            <a href="/tag/python">Python</a>
            <a href="/tag/crawler">爬虫</a>
        </div>
    </article>
    <article class="post">
        <h2 class="title"><a href="/post/2">文章2</a></h2>
        <div class="meta">
            <span class="author">作者B</span>
            <time datetime="2024-01-02">2024年1月2日</time>
        </div>
        <p class="summary">摘要内容...</p>
        <div class="tags">
            <a href="/tag/web">Web</a>
        </div>
    </article>
</div>
"""

soup = BeautifulSoup(html, 'lxml')

articles = []
for post in soup.select('.article-list > article.post'):
    article = {
        'title': post.select_one('.title a').get_text(strip=True),
        'url': post.select_one('.title a')['href'],
        'author': post.select_one('.meta .author').get_text(strip=True),
        'date': post.select_one('.meta time')['datetime'],
        'summary': post.select_one('.summary').get_text(strip=True),
        'tags': [a.get_text(strip=True) for a in post.select('.tags a')]
    }
    articles.append(article)

for article in articles:
    print(article)
```

### 5.2 提取表格数据

```python
html = """
<table class="data-table">
    <thead>
        <tr>
            <th>名称</th>
            <th>价格</th>
            <th>库存</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>商品A</td>
            <td>¥99.00</td>
            <td>100</td>
        </tr>
        <tr>
            <td>商品B</td>
            <td>¥199.00</td>
            <td>50</td>
        </tr>
    </tbody>
</table>
"""

soup = BeautifulSoup(html, 'lxml')

# 提取表头
headers = [th.get_text(strip=True) for th in soup.select('.data-table thead th')]

# 提取数据行
rows = []
for tr in soup.select('.data-table tbody tr'):
    row = [td.get_text(strip=True) for td in tr.select('td')]
    rows.append(dict(zip(headers, row)))

print(rows)
# [{'名称': '商品A', '价格': '¥99.00', '库存': '100'}, ...]
```

### 5.3 提取嵌套数据

```python
html = """
<div class="comment-list">
    <div class="comment" data-id="1">
        <div class="user">用户A</div>
        <div class="content">评论内容1</div>
        <div class="replies">
            <div class="comment" data-id="2">
                <div class="user">用户B</div>
                <div class="content">回复内容1</div>
            </div>
            <div class="comment" data-id="3">
                <div class="user">用户C</div>
                <div class="content">回复内容2</div>
            </div>
        </div>
    </div>
</div>
"""

soup = BeautifulSoup(html, 'lxml')

def parse_comment(elem):
    comment = {
        'id': elem['data-id'],
        'user': elem.select_one('> .user').get_text(strip=True),
        'content': elem.select_one('> .content').get_text(strip=True),
        'replies': []
    }
    
    replies_elem = elem.select_one('> .replies')
    if replies_elem:
        for reply in replies_elem.select('> .comment'):
            comment['replies'].append(parse_comment(reply))
    
    return comment

# 解析顶级评论
comments = []
for comment_elem in soup.select('.comment-list > .comment'):
    comments.append(parse_comment(comment_elem))

import json
print(json.dumps(comments, ensure_ascii=False, indent=2))
```

---

## CSS 选择器 vs XPath

| 特性 | CSS 选择器 | XPath |
|------|-----------|-------|
| 语法 | 简洁 | 复杂 |
| 学习曲线 | 低 | 高 |
| 功能 | 基础 | 强大 |
| 向上选择 | 不支持 | 支持 |
| 文本匹配 | 有限 | 强大 |
| 性能 | 快 | 较慢 |

**选择建议**：
- 简单场景用 CSS 选择器
- 复杂场景用 XPath
- 需要向上查找用 XPath

---

## 下一步

下一篇我们将学习 JSON 数据解析。

---

## 参考资料

- [CSS 选择器参考](https://developer.mozilla.org/zh-CN/docs/Web/CSS/CSS_Selectors)
- [BeautifulSoup 文档](https://www.crummy.com/software/BeautifulSoup/bs4/doc/)
