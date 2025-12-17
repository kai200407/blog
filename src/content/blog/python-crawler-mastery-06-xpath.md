---
title: "XPath 详解"
description: "1. [XPath 基础](#1-xpath-基础)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 6
---

> 本文详细介绍 XPath 语法，这是爬虫中最强大的数据提取方式之一。

---

## 目录

1. [XPath 基础](#1-xpath-基础)
2. [路径表达式](#2-路径表达式)
3. [谓语与函数](#3-谓语与函数)
4. [轴选择器](#4-轴选择器)
5. [实战技巧](#5-实战技巧)

---

## 1. XPath 基础

### 1.1 什么是 XPath

XPath（XML Path Language）是一种在 XML/HTML 文档中查找信息的语言。

### 1.2 Python 中使用 XPath

```python
from lxml import etree

html = """
<html>
<body>
    <div id="content">
        <h1 class="title">标题</h1>
        <p class="intro">介绍文本</p>
        <ul>
            <li>项目1</li>
            <li>项目2</li>
            <li>项目3</li>
        </ul>
    </div>
</body>
</html>
"""

# 解析 HTML
tree = etree.HTML(html)

# 基本查询
title = tree.xpath('//h1/text()')[0]
print(title)  # 标题
```

### 1.3 基本语法

| 表达式 | 描述 |
|--------|------|
| `/` | 从根节点选取 |
| `//` | 从任意位置选取 |
| `.` | 当前节点 |
| `..` | 父节点 |
| `@` | 选取属性 |
| `*` | 匹配任意元素 |
| `@*` | 匹配任意属性 |
| `node()` | 匹配任意节点 |

---

## 2. 路径表达式

### 2.1 绝对路径与相对路径

```python
# 绝对路径（从根开始）
tree.xpath('/html/body/div/h1')

# 相对路径（从任意位置）
tree.xpath('//h1')

# 当前节点的相对路径
div = tree.xpath('//div[@id="content"]')[0]
div.xpath('.//p')  # 在 div 内查找
```

### 2.2 选取节点

```python
# 选取所有 div
tree.xpath('//div')

# 选取特定 id 的 div
tree.xpath('//div[@id="content"]')

# 选取特定 class 的元素
tree.xpath('//*[@class="title"]')

# 选取所有 li
tree.xpath('//ul/li')

# 选取第一个 li
tree.xpath('//ul/li[1]')

# 选取最后一个 li
tree.xpath('//ul/li[last()]')
```

### 2.3 选取属性

```python
html = '<a href="https://example.com" class="link" data-id="123">链接</a>'
tree = etree.HTML(html)

# 获取 href 属性
href = tree.xpath('//a/@href')[0]
print(href)  # https://example.com

# 获取所有属性
attrs = tree.xpath('//a/@*')
print(attrs)  # ['https://example.com', 'link', '123']

# 获取 data 属性
data_id = tree.xpath('//a/@data-id')[0]
print(data_id)  # 123
```

### 2.4 选取文本

```python
html = '<p>Hello <strong>World</strong>!</p>'
tree = etree.HTML(html)

# 直接子文本
text = tree.xpath('//p/text()')
print(text)  # ['Hello ', '!']

# 所有文本（包括子元素）
all_text = tree.xpath('//p//text()')
print(all_text)  # ['Hello ', 'World', '!']

# 合并文本
full_text = ''.join(tree.xpath('//p//text()'))
print(full_text)  # Hello World!

# 使用 string() 函数
full_text = tree.xpath('string(//p)')
print(full_text)  # Hello World!
```

---

## 3. 谓语与函数

### 3.1 谓语（条件过滤）

```python
html = """
<ul>
    <li class="item active">Item 1</li>
    <li class="item">Item 2</li>
    <li class="item">Item 3</li>
    <li class="item special">Item 4</li>
</ul>
"""
tree = etree.HTML(html)

# 位置谓语
tree.xpath('//li[1]')        # 第一个
tree.xpath('//li[last()]')   # 最后一个
tree.xpath('//li[position() < 3]')  # 前两个

# 属性谓语
tree.xpath('//li[@class="item"]')
tree.xpath('//li[@class="item active"]')

# 文本谓语
tree.xpath('//li[text()="Item 2"]')

# 组合谓语
tree.xpath('//li[@class="item"][2]')  # 第二个 class="item" 的 li
```

### 3.2 常用函数

```python
# contains() - 包含
tree.xpath('//li[contains(@class, "item")]')
tree.xpath('//li[contains(text(), "Item")]')

# starts-with() - 开头
tree.xpath('//a[starts-with(@href, "https")]')

# ends-with() - 结尾（XPath 2.0，lxml 不支持）
# 替代方案
tree.xpath('//a[substring(@href, string-length(@href) - 3) = ".pdf"]')

# not() - 否定
tree.xpath('//li[not(@class="special")]')

# and/or - 逻辑运算
tree.xpath('//li[@class="item" and contains(text(), "1")]')
tree.xpath('//li[@class="active" or @class="special"]')

# normalize-space() - 去除空白
tree.xpath('//p[normalize-space(text())="Hello"]')

# count() - 计数
tree.xpath('count(//li)')  # 返回数字

# string-length() - 字符串长度
tree.xpath('//p[string-length(text()) > 10]')
```

### 3.3 数值比较

```python
html = """
<div>
    <span class="price">99</span>
    <span class="price">199</span>
    <span class="price">299</span>
</div>
"""
tree = etree.HTML(html)

# 数值比较
tree.xpath('//span[@class="price" and number(text()) > 100]')
tree.xpath('//span[@class="price" and number(text()) < 200]')
```

---

## 4. 轴选择器

### 4.1 轴的概念

轴定义了相对于当前节点的节点集。

```python
html = """
<div class="container">
    <div class="header">Header</div>
    <div class="content">
        <p>Paragraph 1</p>
        <p>Paragraph 2</p>
    </div>
    <div class="footer">Footer</div>
</div>
"""
tree = etree.HTML(html)
```

### 4.2 常用轴

| 轴 | 描述 |
|-----|------|
| `ancestor` | 所有祖先节点 |
| `ancestor-or-self` | 祖先节点及自身 |
| `parent` | 父节点 |
| `child` | 子节点 |
| `descendant` | 所有后代节点 |
| `descendant-or-self` | 后代节点及自身 |
| `following` | 之后的所有节点 |
| `following-sibling` | 之后的兄弟节点 |
| `preceding` | 之前的所有节点 |
| `preceding-sibling` | 之前的兄弟节点 |

### 4.3 轴使用示例

```python
# 父节点
tree.xpath('//p/parent::div')
tree.xpath('//p/..')  # 简写

# 祖先节点
tree.xpath('//p/ancestor::div')
tree.xpath('//p/ancestor::div[@class="container"]')

# 子节点
tree.xpath('//div[@class="content"]/child::p')
tree.xpath('//div[@class="content"]/p')  # 简写

# 后代节点
tree.xpath('//div[@class="container"]/descendant::p')
tree.xpath('//div[@class="container"]//p')  # 简写

# 后续兄弟
tree.xpath('//div[@class="header"]/following-sibling::div')

# 前置兄弟
tree.xpath('//div[@class="footer"]/preceding-sibling::div')

# 之后所有节点
tree.xpath('//div[@class="header"]/following::*')
```

---

## 5. 实战技巧

### 5.1 提取表格数据

```python
html = """
<table>
    <tr><th>姓名</th><th>年龄</th><th>城市</th></tr>
    <tr><td>张三</td><td>25</td><td>北京</td></tr>
    <tr><td>李四</td><td>30</td><td>上海</td></tr>
</table>
"""
tree = etree.HTML(html)

# 提取表头
headers = tree.xpath('//table/tr[1]/th/text()')
print(headers)  # ['姓名', '年龄', '城市']

# 提取数据行
rows = []
for tr in tree.xpath('//table/tr[position() > 1]'):
    row = tr.xpath('./td/text()')
    rows.append(dict(zip(headers, row)))

print(rows)
# [{'姓名': '张三', '年龄': '25', '城市': '北京'}, ...]
```

### 5.2 提取链接

```python
html = """
<nav>
    <a href="/">首页</a>
    <a href="/about">关于</a>
    <a href="https://external.com">外部</a>
</nav>
"""
tree = etree.HTML(html)

# 提取所有链接
links = []
for a in tree.xpath('//a'):
    links.append({
        'text': a.xpath('string(.)'),
        'href': a.xpath('@href')[0]
    })

print(links)

# 只提取内部链接
internal = tree.xpath('//a[starts-with(@href, "/")]/@href')
print(internal)  # ['/', '/about']
```

### 5.3 处理复杂结构

```python
html = """
<div class="product">
    <h2>产品名称</h2>
    <div class="info">
        <span class="price">¥99.00</span>
        <span class="stock">有货</span>
    </div>
    <ul class="features">
        <li>特性1</li>
        <li>特性2</li>
    </ul>
</div>
"""
tree = etree.HTML(html)

product = tree.xpath('//div[@class="product"]')[0]

data = {
    'name': product.xpath('.//h2/text()')[0],
    'price': product.xpath('.//span[@class="price"]/text()')[0],
    'stock': product.xpath('.//span[@class="stock"]/text()')[0],
    'features': product.xpath('.//ul[@class="features"]/li/text()')
}

print(data)
```

### 5.4 XPath 调试技巧

```python
from lxml import etree

def xpath_debug(tree, xpath_expr):
    """调试 XPath 表达式"""
    try:
        result = tree.xpath(xpath_expr)
        print(f"表达式: {xpath_expr}")
        print(f"结果数量: {len(result) if isinstance(result, list) else 1}")
        print(f"结果: {result}")
        return result
    except Exception as e:
        print(f"错误: {e}")
        return None

# 使用
tree = etree.HTML(html)
xpath_debug(tree, '//div[@class="product"]//span')
```

---

## XPath vs CSS 选择器

| 特性 | XPath | CSS |
|------|-------|-----|
| 语法复杂度 | 较复杂 | 简单 |
| 功能 | 更强大 | 基础 |
| 轴选择 | 支持 | 不支持 |
| 文本选择 | 支持 | 不支持 |
| 父元素选择 | 支持 | 不支持 |
| 性能 | 稍慢 | 稍快 |

---

## 下一步

下一篇我们将学习 CSS 选择器的详细用法。

---

## 参考资料

- [XPath 教程](https://www.w3schools.com/xml/xpath_intro.asp)
- [lxml XPath 文档](https://lxml.de/xpathxslt.html)
