---
title: "爬虫概述与法律边界"
description: "1. [什么是网络爬虫](#1-什么是网络爬虫)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 1
---

> 本文介绍网络爬虫的基本概念、工作原理以及法律边界。

---

## 目录

1. [什么是网络爬虫](#1-什么是网络爬虫)
2. [爬虫工作原理](#2-爬虫工作原理)
3. [爬虫分类](#3-爬虫分类)
4. [法律与道德边界](#4-法律与道德边界)
5. [robots.txt 协议](#5-robotstxt-协议)

---

## 1. 什么是网络爬虫

### 1.1 定义

**网络爬虫**（Web Crawler/Spider）是一种自动化程序，按照一定规则自动抓取互联网上的信息。

### 1.2 应用场景

| 场景 | 描述 | 示例 |
|------|------|------|
| 搜索引擎 | 索引网页内容 | Google、Bing、百度 |
| 数据分析 | 采集分析数据 | 舆情监控、市场调研 |
| 价格监控 | 追踪商品价格 | 比价网站 |
| 内容聚合 | 聚合多源内容 | 新闻聚合、RSS |
| 学术研究 | 采集研究数据 | 论文分析、社交网络研究 |

### 1.3 爬虫 vs API

| 对比项 | 爬虫 | API |
|--------|------|-----|
| 数据来源 | HTML 页面 | 结构化接口 |
| 稳定性 | 页面变化可能失效 | 相对稳定 |
| 效率 | 需要解析 HTML | 直接获取数据 |
| 合规性 | 需遵守 robots.txt | 需遵守使用条款 |
| 数据范围 | 可获取展示的所有内容 | 仅限开放的接口 |

---

## 2. 爬虫工作原理

### 2.1 基本流程

```
发送请求 → 获取响应 → 解析内容 → 提取数据 → 存储数据
    ↑                                          ↓
    ←←←←←←←←← 发现新链接 ←←←←←←←←←←←←←←←←←←←←←←
```

### 2.2 核心组件

```python
# 1. 请求器 - 发送 HTTP 请求
import requests
response = requests.get('https://example.com')

# 2. 解析器 - 解析 HTML 内容
from bs4 import BeautifulSoup
soup = BeautifulSoup(response.text, 'html.parser')

# 3. 提取器 - 提取目标数据
title = soup.find('title').text
links = [a['href'] for a in soup.find_all('a')]

# 4. 存储器 - 保存数据
import json
with open('data.json', 'w') as f:
    json.dump({'title': title, 'links': links}, f)
```

### 2.3 简单示例

```python
import requests
from bs4 import BeautifulSoup

def simple_crawler(url):
    """简单爬虫示例"""
    # 发送请求
    headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}
    response = requests.get(url, headers=headers)
    
    # 检查响应
    if response.status_code != 200:
        print(f"请求失败: {response.status_code}")
        return None
    
    # 解析内容
    soup = BeautifulSoup(response.text, 'html.parser')
    
    # 提取数据
    data = {
        'title': soup.title.string if soup.title else '',
        'paragraphs': [p.text for p in soup.find_all('p')[:5]],
        'links': [a.get('href') for a in soup.find_all('a')[:10]]
    }
    
    return data

# 使用
result = simple_crawler('https://example.com')
print(result)
```

---

## 3. 爬虫分类

### 3.1 按目标分类

| 类型 | 描述 | 特点 |
|------|------|------|
| 通用爬虫 | 抓取整个互联网 | 广度优先、大规模 |
| 聚焦爬虫 | 抓取特定主题 | 深度优先、精准 |
| 增量爬虫 | 只抓取更新内容 | 高效、去重 |
| 深层爬虫 | 抓取动态内容 | 模拟浏览器 |

### 3.2 按技术分类

| 类型 | 技术 | 适用场景 |
|------|------|----------|
| 静态爬虫 | Requests + BeautifulSoup | 静态 HTML 页面 |
| 动态爬虫 | Selenium/Playwright | JavaScript 渲染页面 |
| API 爬虫 | Requests + JSON | 接口数据 |
| 分布式爬虫 | Scrapy-Redis | 大规模采集 |

---

## 4. 法律与道德边界

### 4.1 法律风险

⚠️ **可能涉及的法律问题**：

1. **侵犯著作权**：未经授权复制受版权保护的内容
2. **侵犯隐私**：采集个人隐私数据
3. **破坏计算机系统**：对服务器造成过大负担
4. **不正当竞争**：采集竞争对手商业数据
5. **违反服务条款**：违反网站使用协议

### 4.2 相关法规

| 法规 | 适用范围 | 要点 |
|------|----------|------|
| 《网络安全法》 | 中国 | 数据安全、个人信息保护 |
| 《个人信息保护法》 | 中国 | 个人信息采集需授权 |
| GDPR | 欧盟 | 严格的数据保护要求 |
| CFAA | 美国 | 未授权访问计算机系统 |

### 4.3 合规建议

✅ **应该做的**：
- 遵守 robots.txt 规则
- 控制请求频率，避免对服务器造成负担
- 仅采集公开可访问的数据
- 尊重版权，注明数据来源
- 不采集个人隐私信息

❌ **不应该做的**：
- 绕过登录验证采集数据
- 破解验证码大规模采集
- 采集并出售个人信息
- 对网站发起 DDoS 式请求
- 采集后用于非法用途

---

## 5. robots.txt 协议

### 5.1 什么是 robots.txt

`robots.txt` 是网站根目录下的文本文件，用于告诉爬虫哪些页面可以抓取，哪些不可以。

```
https://example.com/robots.txt
```

### 5.2 语法规则

```txt
# 允许所有爬虫访问所有内容
User-agent: *
Allow: /

# 禁止所有爬虫访问
User-agent: *
Disallow: /

# 禁止访问特定目录
User-agent: *
Disallow: /admin/
Disallow: /private/

# 针对特定爬虫
User-agent: Googlebot
Allow: /
User-agent: Baiduspider
Disallow: /

# 设置爬取延迟（秒）
Crawl-delay: 10

# 站点地图
Sitemap: https://example.com/sitemap.xml
```

### 5.3 Python 解析 robots.txt

```python
from urllib.robotparser import RobotFileParser
from urllib.parse import urljoin

def check_robots(base_url, path, user_agent='*'):
    """检查是否允许爬取"""
    robots_url = urljoin(base_url, '/robots.txt')
    
    rp = RobotFileParser()
    rp.set_url(robots_url)
    
    try:
        rp.read()
    except Exception as e:
        print(f"无法读取 robots.txt: {e}")
        return True  # 如果无法读取，默认允许
    
    full_url = urljoin(base_url, path)
    can_fetch = rp.can_fetch(user_agent, full_url)
    
    return can_fetch

# 使用
base_url = 'https://www.example.com'

# 检查是否允许爬取
print(check_robots(base_url, '/'))  # True
print(check_robots(base_url, '/admin/'))  # 取决于 robots.txt
```

### 5.4 常见网站 robots.txt 示例

**Google**:
```txt
User-agent: *
Disallow: /search
Allow: /search/about
```

**GitHub**:
```txt
User-agent: *
Disallow: /*/pulse
Disallow: /*/tree/
```

---

## 爬虫开发最佳实践

### 1. 请求控制

```python
import time
import random

def polite_request(url, min_delay=1, max_delay=3):
    """礼貌请求，带随机延迟"""
    # 随机延迟
    delay = random.uniform(min_delay, max_delay)
    time.sleep(delay)
    
    headers = {
        'User-Agent': 'MyBot/1.0 (+https://mysite.com/bot)',
        'Accept': 'text/html',
    }
    
    response = requests.get(url, headers=headers, timeout=10)
    return response
```

### 2. 错误处理

```python
def safe_request(url, max_retries=3):
    """安全请求，带重试"""
    for attempt in range(max_retries):
        try:
            response = requests.get(url, timeout=10)
            response.raise_for_status()
            return response
        except requests.exceptions.RequestException as e:
            print(f"请求失败 (尝试 {attempt + 1}/{max_retries}): {e}")
            if attempt < max_retries - 1:
                time.sleep(2 ** attempt)  # 指数退避
    
    return None
```

### 3. 日志记录

```python
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('crawler.log'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

def logged_request(url):
    logger.info(f"请求: {url}")
    try:
        response = requests.get(url)
        logger.info(f"响应: {response.status_code}")
        return response
    except Exception as e:
        logger.error(f"错误: {e}")
        return None
```

---

## 下一步

下一篇我们将学习 HTTP 协议基础，这是理解爬虫工作原理的关键。

---

## 参考资料

- [robots.txt 标准](https://www.robotstxt.org/)
- [Web Scraping 法律指南](https://www.eff.org/issues/coders/reverse-engineering-faq)
