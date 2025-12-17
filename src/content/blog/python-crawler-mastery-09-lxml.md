---
title: "lxml 高效解析"
description: "1. [lxml 简介](#1-lxml-简介)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 9
---

> 本文介绍如何使用 lxml 库进行高效的 HTML/XML 解析。

---

## 目录

1. [lxml 简介](#1-lxml-简介)
2. [基础用法](#2-基础用法)
3. [XPath 查询](#3-xpath-查询)
4. [CSS 选择器](#4-css-选择器)
5. [实战应用](#5-实战应用)

---

## 1. lxml 简介

### 1.1 lxml 特点

| 特点 | 说明 |
|------|------|
| 高性能 | C 语言实现，速度快 |
| 功能丰富 | 支持 XPath、CSS 选择器 |
| 容错性强 | 能处理不规范 HTML |
| 标准兼容 | 符合 XML/HTML 标准 |

### 1.2 安装

```bash
pip install lxml
```

### 1.3 解析器对比

| 解析器 | 速度 | 容错性 | 依赖 |
|--------|------|--------|------|
| lxml | 快 | 好 | C 库 |
| html.parser | 中 | 中 | 内置 |
| html5lib | 慢 | 最好 | 纯 Python |

---

## 2. 基础用法

### 2.1 解析 HTML

```python
from lxml import etree

# 从字符串解析
html = """
<html>
<head><title>测试页面</title></head>
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

# 获取标题
title = tree.xpath('//title/text()')[0]
print(title)  # 测试页面

# 从文件解析
tree = etree.parse('page.html', etree.HTMLParser())

# 从 URL 解析（配合 requests）
import requests
response = requests.get('https://example.com')
tree = etree.HTML(response.content)
```

### 2.2 解析 XML

```python
from lxml import etree

xml = """
<?xml version="1.0" encoding="UTF-8"?>
<catalog>
    <book id="1">
        <title>Python 编程</title>
        <author>张三</author>
        <price>59.00</price>
    </book>
    <book id="2">
        <title>Web 开发</title>
        <author>李四</author>
        <price>69.00</price>
    </book>
</catalog>
"""

# 解析 XML
root = etree.fromstring(xml.encode())

# 遍历
for book in root.findall('book'):
    book_id = book.get('id')
    title = book.find('title').text
    author = book.find('author').text
    price = book.find('price').text
    print(f"[{book_id}] {title} - {author}: ¥{price}")
```

### 2.3 元素操作

```python
from lxml import etree

html = "<div><p>段落</p></div>"
tree = etree.HTML(html)

# 获取元素
div = tree.xpath('//div')[0]

# 元素属性
print(div.tag)        # div
print(div.text)       # None（文本在子元素中）
print(div.tail)       # 元素后的文本

# 获取属性
p = tree.xpath('//p')[0]
p.set('class', 'text')  # 设置属性
print(p.get('class'))   # text
print(p.attrib)         # {'class': 'text'}

# 子元素
for child in div:
    print(child.tag)

# 父元素
parent = p.getparent()
print(parent.tag)  # div

# 兄弟元素
prev = p.getprevious()  # 前一个兄弟
next = p.getnext()      # 后一个兄弟
```

### 2.4 文本提取

```python
from lxml import etree

html = """
<div>
    文本1
    <span>内部文本</span>
    文本2
    <a href="#">链接</a>
    文本3
</div>
"""

tree = etree.HTML(html)
div = tree.xpath('//div')[0]

# 直接文本
print(div.text)  # 文本1

# 所有文本（包括子元素）
all_text = div.xpath('.//text()')
print(all_text)  # ['文本1', '内部文本', '文本2', '链接', '文本3']

# 合并文本
text = ''.join(div.itertext())
print(text.strip())

# 使用 string() 函数
text = tree.xpath('string(//div)')
print(text.strip())
```

---

## 3. XPath 查询

### 3.1 基础选择器

```python
from lxml import etree

html = """
<html>
<body>
    <div id="main" class="container">
        <ul class="list">
            <li>项目1</li>
            <li class="active">项目2</li>
            <li>项目3</li>
        </ul>
        <div class="content">
            <p>段落1</p>
            <p>段落2</p>
        </div>
    </div>
    <div id="sidebar">
        <a href="/link1">链接1</a>
        <a href="/link2">链接2</a>
    </div>
</body>
</html>
"""

tree = etree.HTML(html)

# 基础选择
tree.xpath('//div')           # 所有 div
tree.xpath('//div[@id="main"]')  # id="main" 的 div
tree.xpath('//li[@class="active"]')  # class="active" 的 li

# 层级选择
tree.xpath('//div/ul/li')     # div 下的 ul 下的 li
tree.xpath('//div//li')       # div 下所有 li（任意层级）

# 索引选择（从 1 开始）
tree.xpath('//li[1]')         # 第一个 li
tree.xpath('//li[last()]')    # 最后一个 li
tree.xpath('//li[position()<=2]')  # 前两个 li

# 属性选择
tree.xpath('//a/@href')       # 所有 a 的 href 属性
tree.xpath('//div/@*')        # div 的所有属性
```

### 3.2 高级选择器

```python
# 包含选择
tree.xpath('//div[contains(@class, "container")]')  # class 包含 container
tree.xpath('//p[contains(text(), "段落")]')  # 文本包含"段落"

# 开头/结尾
tree.xpath('//a[starts-with(@href, "/")]')  # href 以 / 开头
tree.xpath('//a[ends-with(@href, ".html")]')  # href 以 .html 结尾（XPath 2.0）

# 逻辑运算
tree.xpath('//li[@class="active" and position()=2]')  # 同时满足
tree.xpath('//li[@class="active" or position()=1]')   # 满足其一
tree.xpath('//li[not(@class)]')  # 没有 class 属性

# 轴选择
tree.xpath('//li[@class="active"]/following-sibling::li')  # 后续兄弟
tree.xpath('//li[@class="active"]/preceding-sibling::li')  # 前面兄弟
tree.xpath('//li[@class="active"]/parent::ul')  # 父元素
tree.xpath('//li[@class="active"]/ancestor::div')  # 祖先元素
```

### 3.3 函数使用

```python
# 文本函数
tree.xpath('//p/text()')  # 获取文本
tree.xpath('string(//div[@id="main"])')  # 合并文本
tree.xpath('normalize-space(//p[1])')  # 规范化空白

# 数值函数
tree.xpath('count(//li)')  # 计数
tree.xpath('sum(//price)')  # 求和（XML）

# 字符串函数
tree.xpath('//a[string-length(@href) > 5]')  # 长度大于 5
tree.xpath('//p[translate(text(), "ABC", "abc")]')  # 转换

# 条件判断
tree.xpath('//li[position() mod 2 = 0]')  # 偶数位置
```

---

## 4. CSS 选择器

### 4.1 cssselect 使用

```python
from lxml import etree
from lxml.cssselect import CSSSelector

html = """
<div class="container">
    <ul id="menu">
        <li class="item active">首页</li>
        <li class="item">产品</li>
        <li class="item">关于</li>
    </ul>
</div>
"""

tree = etree.HTML(html)

# 创建选择器
sel = CSSSelector('li.item')
items = sel(tree)
for item in items:
    print(item.text)

# 直接使用 cssselect 方法
items = tree.cssselect('li.item')
for item in items:
    print(item.text)

# 常用选择器
tree.cssselect('#menu')           # ID 选择器
tree.cssselect('.item')           # 类选择器
tree.cssselect('li.active')       # 标签+类
tree.cssselect('ul > li')         # 直接子元素
tree.cssselect('ul li')           # 后代元素
tree.cssselect('li:first-child')  # 第一个子元素
tree.cssselect('li:nth-child(2)') # 第二个子元素
tree.cssselect('[href]')          # 有 href 属性
tree.cssselect('[href^="/"]')     # href 以 / 开头
```

### 4.2 CSS 转 XPath

```python
from lxml.cssselect import CSSSelector

# 查看转换后的 XPath
sel = CSSSelector('div.container > ul#menu li.active')
print(sel.path)
# descendant-or-self::div[@class and contains(concat(' ', normalize-space(@class), ' '), ' container ')]/ul[@id = 'menu']/descendant-or-self::li[@class and contains(concat(' ', normalize-space(@class), ' '), ' active ')]
```

---

## 5. 实战应用

### 5.1 新闻列表爬取

```python
from lxml import etree
import requests

def crawl_news(url):
    """爬取新闻列表"""
    response = requests.get(url, headers={
        'User-Agent': 'Mozilla/5.0...'
    })
    
    tree = etree.HTML(response.content)
    
    news_list = []
    
    # 提取新闻列表
    items = tree.xpath('//div[@class="news-list"]//li')
    
    for item in items:
        # 标题
        title = item.xpath('.//a[@class="title"]/text()')
        title = title[0].strip() if title else ''
        
        # 链接
        link = item.xpath('.//a[@class="title"]/@href')
        link = link[0] if link else ''
        
        # 时间
        time = item.xpath('.//span[@class="time"]/text()')
        time = time[0].strip() if time else ''
        
        # 摘要
        summary = item.xpath('.//p[@class="summary"]/text()')
        summary = summary[0].strip() if summary else ''
        
        news_list.append({
            'title': title,
            'link': link,
            'time': time,
            'summary': summary
        })
    
    return news_list

# 使用
news = crawl_news('https://example.com/news')
for item in news:
    print(f"{item['time']} - {item['title']}")
```

### 5.2 表格数据提取

```python
from lxml import etree

def parse_table(html):
    """解析 HTML 表格"""
    tree = etree.HTML(html)
    
    # 获取表头
    headers = tree.xpath('//table//th/text()')
    headers = [h.strip() for h in headers]
    
    # 获取数据行
    rows = tree.xpath('//table//tbody/tr')
    
    data = []
    for row in rows:
        cells = row.xpath('.//td')
        row_data = {}
        
        for i, cell in enumerate(cells):
            if i < len(headers):
                # 获取单元格文本
                text = ''.join(cell.itertext()).strip()
                row_data[headers[i]] = text
        
        data.append(row_data)
    
    return data

# 示例
html = """
<table>
    <thead>
        <tr><th>姓名</th><th>年龄</th><th>城市</th></tr>
    </thead>
    <tbody>
        <tr><td>张三</td><td>25</td><td>北京</td></tr>
        <tr><td>李四</td><td>30</td><td>上海</td></tr>
    </tbody>
</table>
"""

data = parse_table(html)
for row in data:
    print(row)
# {'姓名': '张三', '年龄': '25', '城市': '北京'}
# {'姓名': '李四', '年龄': '30', '城市': '上海'}
```

### 5.3 高性能解析

```python
from lxml import etree
from io import BytesIO

def parse_large_html(html_bytes):
    """解析大型 HTML"""
    # 使用增量解析
    parser = etree.HTMLParser()
    
    # 分块解析
    chunk_size = 1024 * 1024  # 1MB
    
    for i in range(0, len(html_bytes), chunk_size):
        chunk = html_bytes[i:i+chunk_size]
        parser.feed(chunk)
    
    tree = parser.close()
    return tree

def parse_with_cleanup(html):
    """解析并清理内存"""
    tree = etree.HTML(html)
    
    # 提取数据
    data = tree.xpath('//div[@class="item"]/text()')
    
    # 清理
    tree.getroottree().getroot().clear()
    
    return data

# 使用 iterparse 处理大型 XML
def parse_large_xml(filepath):
    """增量解析大型 XML"""
    context = etree.iterparse(filepath, events=('end',), tag='item')
    
    for event, elem in context:
        # 处理元素
        data = {
            'id': elem.get('id'),
            'name': elem.findtext('name'),
            'value': elem.findtext('value')
        }
        
        yield data
        
        # 清理已处理的元素
        elem.clear()
        while elem.getprevious() is not None:
            del elem.getparent()[0]
```

### 5.4 封装解析器

```python
from lxml import etree
from typing import List, Optional, Any

class HTMLParser:
    """HTML 解析器封装"""
    
    def __init__(self, html: str):
        self.tree = etree.HTML(html)
    
    def xpath(self, expr: str) -> List[Any]:
        """XPath 查询"""
        return self.tree.xpath(expr)
    
    def xpath_first(self, expr: str, default: Any = None) -> Any:
        """XPath 查询第一个结果"""
        result = self.tree.xpath(expr)
        return result[0] if result else default
    
    def css(self, selector: str) -> List[Any]:
        """CSS 选择器查询"""
        return self.tree.cssselect(selector)
    
    def css_first(self, selector: str) -> Optional[Any]:
        """CSS 选择器查询第一个结果"""
        result = self.tree.cssselect(selector)
        return result[0] if result else None
    
    def text(self, expr: str, strip: bool = True) -> str:
        """获取文本"""
        result = self.xpath_first(expr, '')
        if isinstance(result, str):
            return result.strip() if strip else result
        if hasattr(result, 'text'):
            text = result.text or ''
            return text.strip() if strip else text
        return ''
    
    def texts(self, expr: str, strip: bool = True) -> List[str]:
        """获取多个文本"""
        results = self.xpath(expr)
        texts = []
        for r in results:
            if isinstance(r, str):
                texts.append(r.strip() if strip else r)
            elif hasattr(r, 'text') and r.text:
                texts.append(r.text.strip() if strip else r.text)
        return texts
    
    def attr(self, expr: str, attr_name: str, default: str = '') -> str:
        """获取属性"""
        elem = self.xpath_first(expr)
        if elem is not None and hasattr(elem, 'get'):
            return elem.get(attr_name, default)
        return default

# 使用
html = "<div><a href='/link' class='btn'>点击</a></div>"
parser = HTMLParser(html)

print(parser.text('//a'))           # 点击
print(parser.attr('//a', 'href'))   # /link
print(parser.xpath('//a/@class'))   # ['btn']
```

---

## 下一步

下一篇我们将学习 Selenium 浏览器自动化。

---

## 参考资料

- [lxml 官方文档](https://lxml.de/)
- [XPath 教程](https://www.w3schools.com/xml/xpath_intro.asp)
- [CSS 选择器](https://www.w3schools.com/cssref/css_selectors.asp)
