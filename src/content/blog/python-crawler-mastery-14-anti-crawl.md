---
title: "常见反爬机制"
description: "1. [反爬概述](#1-反爬概述)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 14
---

> 本文介绍网站常见的反爬虫机制及其应对策略。

---

## 目录

1. [反爬概述](#1-反爬概述)
2. [请求层反爬](#2-请求层反爬)
3. [内容层反爬](#3-内容层反爬)
4. [行为层反爬](#4-行为层反爬)
5. [应对策略](#5-应对策略)

---

## 1. 反爬概述

### 1.1 为什么要反爬

- 保护数据资产
- 防止恶意采集
- 保障服务器性能
- 维护用户体验
- 合规要求

### 1.2 反爬分类

| 类型 | 描述 | 难度 |
|------|------|------|
| 请求层 | 检测请求特征 | ⭐⭐ |
| 内容层 | 混淆/加密内容 | ⭐⭐⭐ |
| 行为层 | 分析访问行为 | ⭐⭐⭐⭐ |
| 验证层 | 验证码/登录 | ⭐⭐⭐⭐⭐ |

---

## 2. 请求层反爬

### 2.1 User-Agent 检测

**检测方式**：检查 User-Agent 是否为浏览器

```python
# 反爬检测
if 'python' in user_agent.lower():
    return 403

# 应对：使用真实浏览器 UA
import random

USER_AGENTS = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
]

headers = {'User-Agent': random.choice(USER_AGENTS)}
```

### 2.2 Referer 检测

**检测方式**：检查请求来源

```python
# 应对：设置正确的 Referer
headers = {
    'Referer': 'https://www.example.com/',
    'User-Agent': '...'
}
```

### 2.3 Cookie 检测

**检测方式**：检查是否携带有效 Cookie

```python
# 应对：使用 Session 保持 Cookie
session = requests.Session()

# 先访问首页获取 Cookie
session.get('https://www.example.com/')

# 再访问目标页面
response = session.get('https://www.example.com/data')
```

### 2.4 IP 限制

**检测方式**：限制单 IP 请求频率

```python
# 应对：使用代理 IP
proxies = {
    'http': 'http://proxy_ip:port',
    'https': 'http://proxy_ip:port'
}
response = requests.get(url, proxies=proxies)
```

### 2.5 请求头完整性

**检测方式**：检查请求头是否完整

```python
# 应对：模拟完整的浏览器请求头
headers = {
    'User-Agent': 'Mozilla/5.0...',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    'Accept-Encoding': 'gzip, deflate, br',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Sec-Fetch-User': '?1',
}
```

---

## 3. 内容层反爬

### 3.1 JavaScript 渲染

**反爬方式**：数据通过 JS 动态加载

```python
# 应对1：使用 Selenium/Playwright
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    page.goto('https://example.com')
    page.wait_for_selector('.data')
    content = page.content()
    browser.close()

# 应对2：分析 API 接口
# 使用浏览器开发者工具找到数据接口
response = requests.get('https://api.example.com/data')
data = response.json()
```

### 3.2 字体加密

**反爬方式**：使用自定义字体映射数字/文字

```python
# 应对：解析字体文件
from fontTools.ttLib import TTFont
import base64
import re

def decode_font(font_base64, encoded_text):
    # 解码字体
    font_data = base64.b64decode(font_base64)
    with open('temp.woff', 'wb') as f:
        f.write(font_data)
    
    font = TTFont('temp.woff')
    cmap = font.getBestCmap()
    
    # 建立映射
    mapping = {}
    for code, name in cmap.items():
        # 根据字体结构建立映射
        mapping[chr(code)] = name
    
    # 解码文本
    decoded = ''
    for char in encoded_text:
        decoded += mapping.get(char, char)
    
    return decoded
```

### 3.3 CSS 偏移

**反爬方式**：使用 CSS 打乱文字顺序

```python
# 应对：解析 CSS 获取真实顺序
from bs4 import BeautifulSoup
import re

def decode_css_offset(html):
    soup = BeautifulSoup(html, 'lxml')
    
    # 获取所有带偏移的元素
    elements = []
    for span in soup.select('span[style]'):
        style = span.get('style', '')
        # 提取 left 值
        match = re.search(r'left:\s*(-?\d+)px', style)
        if match:
            left = int(match.group(1))
            elements.append((left, span.text))
    
    # 按位置排序
    elements.sort(key=lambda x: x[0])
    
    return ''.join([e[1] for e in elements])
```

### 3.4 图片验证码

**反爬方式**：关键信息以图片形式展示

```python
# 应对：OCR 识别
import pytesseract
from PIL import Image

def ocr_image(image_path):
    image = Image.open(image_path)
    text = pytesseract.image_to_string(image, lang='chi_sim')
    return text

# 或使用 ddddocr
import ddddocr

ocr = ddddocr.DdddOcr()
with open('captcha.png', 'rb') as f:
    result = ocr.classification(f.read())
print(result)
```

### 3.5 数据加密

**反爬方式**：API 返回加密数据

```python
# 应对：逆向加密算法
import base64
import json

def decrypt_data(encrypted):
    # 示例：Base64 解码
    decoded = base64.b64decode(encrypted)
    return json.loads(decoded)

# 复杂加密需要分析 JS 代码
# 使用 PyExecJS 执行 JS
import execjs

with open('decrypt.js', 'r') as f:
    js_code = f.read()

ctx = execjs.compile(js_code)
result = ctx.call('decrypt', encrypted_data)
```

---

## 4. 行为层反爬

### 4.1 请求频率限制

**检测方式**：限制单位时间内请求次数

```python
# 应对：控制请求频率
import time
import random

def polite_request(url, min_delay=1, max_delay=3):
    delay = random.uniform(min_delay, max_delay)
    time.sleep(delay)
    return requests.get(url)
```

### 4.2 访问模式检测

**检测方式**：分析访问路径是否异常

```python
# 应对：模拟真实访问路径
def simulate_browsing(session, target_url):
    # 先访问首页
    session.get('https://example.com/')
    time.sleep(random.uniform(1, 2))
    
    # 访问列表页
    session.get('https://example.com/list')
    time.sleep(random.uniform(1, 2))
    
    # 最后访问目标页
    return session.get(target_url)
```

### 4.3 鼠标轨迹检测

**检测方式**：检测是否有真实鼠标移动

```python
# 应对：使用 Selenium 模拟鼠标
from selenium.webdriver.common.action_chains import ActionChains
import random

def human_like_mouse(driver, element):
    action = ActionChains(driver)
    
    # 获取元素位置
    x = element.location['x'] + element.size['width'] / 2
    y = element.location['y'] + element.size['height'] / 2
    
    # 模拟人类移动（分多步）
    steps = random.randint(5, 10)
    for i in range(steps):
        offset_x = random.randint(-5, 5)
        offset_y = random.randint(-5, 5)
        action.move_by_offset(offset_x, offset_y)
        action.pause(random.uniform(0.01, 0.05))
    
    action.move_to_element(element)
    action.click()
    action.perform()
```

### 4.4 浏览器指纹

**检测方式**：收集浏览器特征生成指纹

```python
# 应对：使用 undetected-chromedriver
import undetected_chromedriver as uc

driver = uc.Chrome()
driver.get('https://example.com')

# 或修改 WebDriver 特征
from selenium import webdriver

options = webdriver.ChromeOptions()
options.add_argument('--disable-blink-features=AutomationControlled')
options.add_experimental_option('excludeSwitches', ['enable-automation'])
options.add_experimental_option('useAutomationExtension', False)

driver = webdriver.Chrome(options=options)

# 修改 navigator.webdriver
driver.execute_cdp_cmd('Page.addScriptToEvaluateOnNewDocument', {
    'source': '''
        Object.defineProperty(navigator, 'webdriver', {
            get: () => undefined
        })
    '''
})
```

---

## 5. 应对策略

### 5.1 综合反反爬方案

```python
import requests
import random
import time
from fake_useragent import UserAgent

class AntiAntiCrawler:
    def __init__(self, proxies=None):
        self.session = requests.Session()
        self.ua = UserAgent()
        self.proxies = proxies or []
        self.request_count = 0
    
    def get_headers(self):
        return {
            'User-Agent': self.ua.random,
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
        }
    
    def get_proxy(self):
        if self.proxies:
            return {'http': random.choice(self.proxies), 'https': random.choice(self.proxies)}
        return None
    
    def request(self, url, method='GET', **kwargs):
        # 请求间隔
        if self.request_count > 0:
            time.sleep(random.uniform(1, 3))
        
        # 设置请求头
        headers = kwargs.pop('headers', {})
        headers.update(self.get_headers())
        
        # 设置代理
        proxies = kwargs.pop('proxies', None) or self.get_proxy()
        
        # 发送请求
        response = self.session.request(
            method, url,
            headers=headers,
            proxies=proxies,
            timeout=10,
            **kwargs
        )
        
        self.request_count += 1
        return response
    
    def get(self, url, **kwargs):
        return self.request(url, 'GET', **kwargs)
    
    def post(self, url, **kwargs):
        return self.request(url, 'POST', **kwargs)

# 使用
crawler = AntiAntiCrawler(proxies=['http://proxy1:port', 'http://proxy2:port'])
response = crawler.get('https://example.com')
```

### 5.2 重试机制

```python
from tenacity import retry, stop_after_attempt, wait_exponential

@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
def fetch_with_retry(url):
    response = requests.get(url, timeout=10)
    response.raise_for_status()
    return response
```

### 5.3 验证码处理

```python
import ddddocr

class CaptchaSolver:
    def __init__(self):
        self.ocr = ddddocr.DdddOcr()
    
    def solve_image(self, image_bytes):
        """识别图片验证码"""
        return self.ocr.classification(image_bytes)
    
    def solve_slider(self, background_bytes, slider_bytes):
        """识别滑块验证码"""
        det = ddddocr.DdddOcr(det=False, ocr=False)
        result = det.slide_match(slider_bytes, background_bytes)
        return result['target'][0]  # 返回滑动距离
```

---

## 反爬检测清单

| 检测项 | 检测方法 | 应对策略 |
|--------|----------|----------|
| User-Agent | 检查 UA 字符串 | 使用真实浏览器 UA |
| Referer | 检查来源 | 设置正确 Referer |
| Cookie | 检查会话 | 使用 Session |
| IP | 频率限制 | 使用代理池 |
| JS 渲染 | 动态加载 | Selenium/API 分析 |
| 验证码 | 人机验证 | OCR/打码平台 |
| 指纹 | 浏览器特征 | undetected-chromedriver |

---

## 下一步

下一篇我们将学习代理 IP 的使用和代理池搭建。

---

## 参考资料

- [反爬虫技术](https://github.com/luyishisi/Anti-Anti-Spider)
- [undetected-chromedriver](https://github.com/ultrafunkamsterdam/undetected-chromedriver)
