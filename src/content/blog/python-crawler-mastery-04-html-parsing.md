---
title: "HTML 解析基础"
description: "1. [BeautifulSoup 入门](#1-beautifulsoup-入门)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 4
---

> 本文介绍如何使用 BeautifulSoup 和 lxml 解析 HTML，提取网页数据。

---

## 目录

1. [BeautifulSoup 入门](#1-beautifulsoup-入门)
2. [元素查找](#2-元素查找)
3. [CSS 选择器](#3-css-选择器)
4. [数据提取](#4-数据提取)
5. [lxml 解析](#5-lxml-解析)

---

## 1. BeautifulSoup 入门

### 1.1 安装

```bash
pip install beautifulsoup4 lxml
```

### 1.2 基本使用

```python
from bs4 import BeautifulSoup

html = """
<!DOCTYPE html>
<html>
<head>
    <title>示例页面</title>
</head>
<body>
    <div id="content" class="main">
        <h1>欢迎</h1>
        <p class="intro">这是一个示例页面。</p>
        <ul>
            <li><a href="/page1">链接1</a></li>
            <li><a href="/page2">链接2</a></li>
            <li><a href="/page3">链接3</a></li>
        </ul>
    </div>
</body>
</html>
"""

# 创建 BeautifulSoup 对象
soup = BeautifulSoup(html, 'lxml')  # 使用 lxml 解析器

# 获取标题
print(soup.title)         # <title>示例页面</title>
print(soup.title.string)  # 示例页面

# 获取第一个 p 标签
print(soup.p)             # <p class="intro">这是一个示例页面。</p>
print(soup.p.text)        # 这是一个示例页面。
```

### 1.3 解析器对比

| 解析器 | 安装 | 速度 | 容错性 |
|--------|------|------|--------|
| html.parser | 内置 | 中等 | 一般 |
| lxml | pip install lxml | 快 | 好 |
| lxml-xml | pip install lxml | 快 | XML 专用 |
| html5lib | pip install html5lib | 慢 | 最好 |

```python
# 不同解析器
soup = BeautifulSoup(html, 'html.parser')  # 内置
soup = BeautifulSoup(html, 'lxml')         # 推荐
soup = BeautifulSoup(html, 'html5lib')     # 最严格
```

---

## 2. 元素查找

### 2.1 find() 和 find_all()

```python
from bs4 import BeautifulSoup

html = """
<div class="container">
    <div class="item" id="first">Item 1</div>
    <div class="item" id="second">Item 2</div>
    <div class="item special" id="third">Item 3</div>
    <p class="item">Paragraph</p>
</div>
"""

soup = BeautifulSoup(html, 'lxml')

# find() - 返回第一个匹配的元素
first_div = soup.find('div')
print(first_div)

# find_all() - 返回所有匹配的元素列表
all_divs = soup.find_all('div')
print(len(all_divs))  # 4

# 按 class 查找
items = soup.find_all('div', class_='item')
print(len(items))  # 3

# 按 id 查找
second = soup.find(id='second')
print(second.text)  # Item 2

# 按属性查找
special = soup.find('div', attrs={'class': 'item special'})
print(special.text)  # Item 3

# 多个标签
elements = soup.find_all(['div', 'p'])
print(len(elements))  # 5
```

### 2.2 属性过滤

```python
html = """
<a href="https://example.com" class="link external">外部链接</a>
<a href="/page1" class="link internal">内部链接1</a>
<a href="/page2" class="link internal">内部链接2</a>
<a href="javascript:void(0)" class="link disabled">禁用链接</a>
"""

soup = BeautifulSoup(html, 'lxml')

# 按 class 查找
internal_links = soup.find_all('a', class_='internal')
print(len(internal_links))  # 2

# 按 href 查找
external = soup.find('a', href='https://example.com')
print(external.text)  # 外部链接

# 使用正则表达式
import re
page_links = soup.find_all('a', href=re.compile(r'^/page'))
print(len(page_links))  # 2

# 使用函数过滤
def is_valid_link(href):
    return href and not href.startswith('javascript')

valid_links = soup.find_all('a', href=is_valid_link)
print(len(valid_links))  # 3
```

### 2.3 文本搜索

```python
html = """
<p>Python 是一种编程语言</p>
<p>Java 也是一种编程语言</p>
<p>这是一段普通文本</p>
"""

soup = BeautifulSoup(html, 'lxml')

# 精确匹配文本
p = soup.find('p', string='这是一段普通文本')
print(p)

# 正则匹配文本
import re
programming = soup.find_all('p', string=re.compile('编程语言'))
print(len(programming))  # 2

# 使用函数
def contains_python(text):
    return text and 'Python' in text

python_p = soup.find('p', string=contains_python)
print(python_p.text)
```

### 2.4 层级导航

```python
html = """
<div class="parent">
    <div class="child">
        <span class="grandchild">文本</span>
    </div>
    <div class="child">
        <span class="grandchild">文本2</span>
    </div>
</div>
"""

soup = BeautifulSoup(html, 'lxml')

parent = soup.find('div', class_='parent')

# 子元素
print(parent.children)           # 迭代器
print(list(parent.children))     # 所有直接子元素
print(parent.contents)           # 子元素列表

# 后代元素
print(list(parent.descendants))  # 所有后代元素

# 父元素
child = soup.find('div', class_='child')
print(child.parent)              # 父元素
print(list(child.parents))       # 所有祖先元素

# 兄弟元素
print(child.next_sibling)        # 下一个兄弟
print(child.previous_sibling)    # 上一个兄弟
print(list(child.next_siblings)) # 所有后续兄弟
```

---

## 3. CSS 选择器

### 3.1 select() 方法

```python
html = """
<div id="main">
    <ul class="menu">
        <li class="item active"><a href="/home">首页</a></li>
        <li class="item"><a href="/about">关于</a></li>
        <li class="item"><a href="/contact">联系</a></li>
    </ul>
    <div class="content">
        <article>
            <h2>文章标题</h2>
            <p class="summary">摘要内容</p>
            <p>正文内容</p>
        </article>
    </div>
</div>
"""

soup = BeautifulSoup(html, 'lxml')

# 标签选择器
divs = soup.select('div')
print(len(divs))

# ID 选择器
main = soup.select_one('#main')
print(main)

# 类选择器
items = soup.select('.item')
print(len(items))  # 3

# 属性选择器
home_link = soup.select_one('a[href="/home"]')
print(home_link.text)  # 首页

# 后代选择器
menu_links = soup.select('.menu a')
print(len(menu_links))  # 3

# 子元素选择器
direct_children = soup.select('#main > div')
print(len(direct_children))

# 相邻兄弟选择器
h2_next = soup.select('h2 + p')
print(h2_next[0].text)  # 摘要内容

# 伪类选择器
first_item = soup.select_one('.item:first-child')
print(first_item.text)  # 首页

last_item = soup.select_one('.item:last-child')
print(last_item.text)  # 联系

# 组合选择器
elements = soup.select('h2, .summary')
print(len(elements))  # 2
```

### 3.2 常用选择器语法

| 选择器 | 描述 | 示例 |
|--------|------|------|
| tag | 标签选择器 | `div`, `a`, `p` |
| #id | ID 选择器 | `#main`, `#header` |
| .class | 类选择器 | `.item`, `.active` |
| [attr] | 属性存在 | `[href]`, `[data-id]` |
| [attr=value] | 属性等于 | `[href="/home"]` |
| [attr^=value] | 属性开头 | `[href^="http"]` |
| [attr$=value] | 属性结尾 | `[href$=".pdf"]` |
| [attr*=value] | 属性包含 | `[href*="example"]` |
| A B | 后代 | `div p` |
| A > B | 直接子元素 | `ul > li` |
| A + B | 相邻兄弟 | `h2 + p` |
| A ~ B | 后续兄弟 | `h2 ~ p` |
| :first-child | 第一个子元素 | `li:first-child` |
| :last-child | 最后一个子元素 | `li:last-child` |
| :nth-child(n) | 第 n 个子元素 | `li:nth-child(2)` |

---

## 4. 数据提取

### 4.1 获取文本

```python
html = """
<div class="article">
    <h1>标题</h1>
    <p>第一段 <strong>重要</strong> 内容</p>
    <p>第二段内容</p>
</div>
"""

soup = BeautifulSoup(html, 'lxml')
article = soup.find('div', class_='article')

# 获取直接文本
print(article.string)  # None（有多个子元素）

# 获取所有文本
print(article.text)
print(article.get_text())

# 指定分隔符
print(article.get_text(separator=' | '))

# 去除空白
print(article.get_text(strip=True))

# 获取子元素文本
for p in article.find_all('p'):
    print(p.get_text(strip=True))
```

### 4.2 获取属性

```python
html = """
<a href="https://example.com" class="link external" data-id="123" title="示例">
    链接文本
</a>
<img src="/image.png" alt="图片" width="100" height="100">
"""

soup = BeautifulSoup(html, 'lxml')

# 获取单个属性
link = soup.find('a')
print(link['href'])           # https://example.com
print(link.get('href'))       # https://example.com（推荐，不存在返回 None）
print(link.get('target', '_self'))  # 默认值

# 获取所有属性
print(link.attrs)  # {'href': '...', 'class': ['link', 'external'], ...}

# class 属性是列表
print(link['class'])  # ['link', 'external']

# 获取 data 属性
print(link['data-id'])  # 123

# 图片属性
img = soup.find('img')
print(img['src'])
print(img['alt'])
```

### 4.3 提取链接

```python
html = """
<nav>
    <a href="/">首页</a>
    <a href="/about">关于</a>
    <a href="https://external.com">外部</a>
    <a href="javascript:void(0)">无效</a>
    <a href="#section">锚点</a>
</nav>
"""

soup = BeautifulSoup(html, 'lxml')
from urllib.parse import urljoin

base_url = 'https://example.com'

def extract_links(soup, base_url):
    """提取所有有效链接"""
    links = []
    
    for a in soup.find_all('a', href=True):
        href = a['href']
        
        # 跳过无效链接
        if href.startswith(('javascript:', '#', 'mailto:')):
            continue
        
        # 转换为绝对 URL
        full_url = urljoin(base_url, href)
        
        links.append({
            'url': full_url,
            'text': a.get_text(strip=True)
        })
    
    return links

links = extract_links(soup, base_url)
for link in links:
    print(f"{link['text']}: {link['url']}")
```

### 4.4 提取表格

```python
html = """
<table>
    <thead>
        <tr>
            <th>姓名</th>
            <th>年龄</th>
            <th>城市</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>张三</td>
            <td>25</td>
            <td>北京</td>
        </tr>
        <tr>
            <td>李四</td>
            <td>30</td>
            <td>上海</td>
        </tr>
    </tbody>
</table>
"""

soup = BeautifulSoup(html, 'lxml')

def parse_table(table):
    """解析表格"""
    # 获取表头
    headers = []
    thead = table.find('thead')
    if thead:
        headers = [th.get_text(strip=True) for th in thead.find_all('th')]
    
    # 获取数据行
    rows = []
    tbody = table.find('tbody') or table
    for tr in tbody.find_all('tr'):
        cells = [td.get_text(strip=True) for td in tr.find_all(['td', 'th'])]
        if cells and cells != headers:
            if headers:
                rows.append(dict(zip(headers, cells)))
            else:
                rows.append(cells)
    
    return rows

data = parse_table(soup.find('table'))
print(data)
# [{'姓名': '张三', '年龄': '25', '城市': '北京'}, ...]
```

---

## 5. lxml 解析

### 5.1 lxml 基础

```python
from lxml import etree

html = """
<html>
<body>
    <div class="content">
        <h1>标题</h1>
        <p>段落1</p>
        <p>段落2</p>
    </div>
</body>
</html>
"""

# 解析 HTML
tree = etree.HTML(html)

# XPath 查询
title = tree.xpath('//h1/text()')[0]
print(title)  # 标题

paragraphs = tree.xpath('//p/text()')
print(paragraphs)  # ['段落1', '段落2']

# 获取属性
div_class = tree.xpath('//div/@class')[0]
print(div_class)  # content
```

### 5.2 lxml vs BeautifulSoup

| 特性 | lxml | BeautifulSoup |
|------|------|---------------|
| 速度 | 快 | 较慢 |
| 语法 | XPath | find/select |
| 学习曲线 | 较陡 | 平缓 |
| 容错性 | 一般 | 好 |
| 内存占用 | 低 | 较高 |

```python
# 结合使用
from bs4 import BeautifulSoup

soup = BeautifulSoup(html, 'lxml')  # 使用 lxml 作为解析器
# 然后使用 BeautifulSoup 的 API
```

---

## 实战示例

```python
import requests
from bs4 import BeautifulSoup

def scrape_news(url):
    """爬取新闻列表"""
    headers = {'User-Agent': 'Mozilla/5.0...'}
    response = requests.get(url, headers=headers)
    soup = BeautifulSoup(response.text, 'lxml')
    
    news_list = []
    
    for article in soup.select('article.news-item'):
        title = article.select_one('h2.title')
        link = article.select_one('a.read-more')
        summary = article.select_one('p.summary')
        date = article.select_one('span.date')
        
        news_list.append({
            'title': title.get_text(strip=True) if title else '',
            'url': link['href'] if link else '',
            'summary': summary.get_text(strip=True) if summary else '',
            'date': date.get_text(strip=True) if date else ''
        })
    
    return news_list
```

---

## 下一步

下一篇我们将学习正则表达式，用于更灵活的文本匹配和数据提取。

---

## 参考资料

- [BeautifulSoup 文档](https://www.crummy.com/software/BeautifulSoup/bs4/doc/)
- [lxml 文档](https://lxml.de/)
