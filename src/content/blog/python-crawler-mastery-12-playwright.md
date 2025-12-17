---
title: "Playwright 自动化"
description: "1. [Playwright 入门](#1-playwright-入门)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 12
---

> 本文介绍 Playwright，一个更现代的浏览器自动化方案。

---

## 目录

1. [Playwright 入门](#1-playwright-入门)
2. [页面操作](#2-页面操作)
3. [元素交互](#3-元素交互)
4. [网络拦截](#4-网络拦截)
5. [实战技巧](#5-实战技巧)

---

## 1. Playwright 入门

### 1.1 安装

```bash
pip install playwright
playwright install  # 安装浏览器
```

### 1.2 基本使用

```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    # 启动浏览器
    browser = p.chromium.launch(headless=True)
    
    # 创建页面
    page = browser.new_page()
    
    # 访问网页
    page.goto('https://example.com')
    
    # 获取内容
    print(page.title())
    print(page.content())
    
    # 关闭浏览器
    browser.close()
```

### 1.3 异步使用

```python
import asyncio
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        
        await page.goto('https://example.com')
        print(await page.title())
        
        await browser.close()

asyncio.run(main())
```

### 1.4 浏览器选项

```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(
        headless=True,           # 无头模式
        slow_mo=100,             # 操作延迟（毫秒）
        devtools=False,          # 开发者工具
        args=[
            '--disable-gpu',
            '--no-sandbox',
        ]
    )
    
    # 创建上下文（类似隐身窗口）
    context = browser.new_context(
        viewport={'width': 1920, 'height': 1080},
        user_agent='Mozilla/5.0...',
        locale='zh-CN',
        timezone_id='Asia/Shanghai',
        geolocation={'latitude': 39.9, 'longitude': 116.4},
        permissions=['geolocation'],
    )
    
    page = context.new_page()
```

---

## 2. 页面操作

### 2.1 导航

```python
# 访问页面
page.goto('https://example.com')
page.goto('https://example.com', wait_until='networkidle')

# 等待选项
# 'load' - load 事件
# 'domcontentloaded' - DOMContentLoaded 事件
# 'networkidle' - 网络空闲

# 前进后退
page.go_back()
page.go_forward()

# 刷新
page.reload()

# 获取 URL
print(page.url)
```

### 2.2 等待

```python
# 等待元素
page.wait_for_selector('.content')
page.wait_for_selector('.content', state='visible')
page.wait_for_selector('.content', timeout=10000)

# 等待状态
# 'attached' - 元素存在于 DOM
# 'detached' - 元素不存在于 DOM
# 'visible' - 元素可见
# 'hidden' - 元素隐藏

# 等待加载状态
page.wait_for_load_state('networkidle')

# 等待 URL
page.wait_for_url('**/success')

# 等待函数
page.wait_for_function('document.querySelector(".data").innerText.length > 0')

# 等待超时
page.wait_for_timeout(1000)  # 毫秒
```

### 2.3 截图

```python
# 整页截图
page.screenshot(path='screenshot.png')

# 全页截图（包括滚动区域）
page.screenshot(path='full.png', full_page=True)

# 元素截图
element = page.locator('.content')
element.screenshot(path='element.png')

# 截图选项
page.screenshot(
    path='screenshot.png',
    type='png',           # png 或 jpeg
    quality=80,           # jpeg 质量
    full_page=True,
    clip={'x': 0, 'y': 0, 'width': 800, 'height': 600}
)
```

### 2.4 PDF 导出

```python
# 导出 PDF（仅 Chromium）
page.pdf(path='page.pdf')

page.pdf(
    path='page.pdf',
    format='A4',
    print_background=True,
    margin={'top': '1cm', 'bottom': '1cm'}
)
```

---

## 3. 元素交互

### 3.1 定位器

```python
# CSS 选择器
page.locator('div.content')
page.locator('#main')
page.locator('[data-testid="submit"]')

# XPath
page.locator('xpath=//div[@class="content"]')

# 文本
page.locator('text=登录')
page.locator('text=/正则.*匹配/')

# 组合
page.locator('div.container >> text=提交')

# 过滤
page.locator('li').filter(has_text='Python')
page.locator('div').filter(has=page.locator('button'))

# 第 N 个
page.locator('li').nth(0)
page.locator('li').first
page.locator('li').last
```

### 3.2 点击和输入

```python
# 点击
page.click('button#submit')
page.locator('button#submit').click()

# 双击
page.dblclick('button')

# 右键
page.click('button', button='right')

# 输入
page.fill('input[name="username"]', 'admin')
page.locator('input[name="password"]').fill('123456')

# 清空并输入
page.fill('input', '')
page.fill('input', 'new value')

# 逐字输入（模拟打字）
page.type('input', 'hello', delay=100)

# 按键
page.press('input', 'Enter')
page.keyboard.press('Control+A')
```

### 3.3 表单操作

```python
# 下拉框
page.select_option('select#city', 'beijing')
page.select_option('select', value='option1')
page.select_option('select', label='选项一')
page.select_option('select', index=0)

# 多选
page.select_option('select', ['opt1', 'opt2'])

# 复选框
page.check('input[type="checkbox"]')
page.uncheck('input[type="checkbox"]')

# 单选框
page.check('input[value="male"]')

# 文件上传
page.set_input_files('input[type="file"]', 'file.txt')
page.set_input_files('input[type="file"]', ['file1.txt', 'file2.txt'])
```

### 3.4 获取内容

```python
# 获取文本
text = page.locator('h1').inner_text()
text = page.locator('h1').text_content()

# 获取属性
href = page.locator('a').get_attribute('href')

# 获取 HTML
html = page.locator('div').inner_html()
html = page.content()  # 整个页面

# 获取所有元素
items = page.locator('li').all()
for item in items:
    print(item.inner_text())

# 获取数量
count = page.locator('li').count()

# 判断状态
is_visible = page.locator('button').is_visible()
is_enabled = page.locator('button').is_enabled()
is_checked = page.locator('input').is_checked()
```

---

## 4. 网络拦截

### 4.1 监听请求

```python
# 监听请求
def handle_request(request):
    print(f"请求: {request.method} {request.url}")

page.on('request', handle_request)

# 监听响应
def handle_response(response):
    print(f"响应: {response.status} {response.url}")

page.on('response', handle_response)

# 等待特定请求
with page.expect_request('**/api/data') as request_info:
    page.click('button')
request = request_info.value
print(request.post_data)

# 等待特定响应
with page.expect_response('**/api/data') as response_info:
    page.click('button')
response = response_info.value
print(response.json())
```

### 4.2 拦截和修改

```python
# 拦截请求
def handle_route(route):
    if 'analytics' in route.request.url:
        route.abort()  # 阻止请求
    else:
        route.continue_()  # 继续请求

page.route('**/*', handle_route)

# 修改请求
def modify_request(route):
    headers = route.request.headers
    headers['Authorization'] = 'Bearer token'
    route.continue_(headers=headers)

page.route('**/api/**', modify_request)

# Mock 响应
def mock_response(route):
    route.fulfill(
        status=200,
        content_type='application/json',
        body='{"data": "mocked"}'
    )

page.route('**/api/data', mock_response)
```

### 4.3 HAR 录制

```python
# 录制 HAR
context = browser.new_context(record_har_path='network.har')
page = context.new_page()
page.goto('https://example.com')
context.close()  # 保存 HAR

# 使用 HAR 回放
context = browser.new_context()
page = context.new_page()
page.route_from_har('network.har')
page.goto('https://example.com')
```

---

## 5. 实战技巧

### 5.1 Cookie 管理

```python
# 获取 Cookie
cookies = context.cookies()
print(cookies)

# 设置 Cookie
context.add_cookies([
    {'name': 'token', 'value': 'abc123', 'domain': 'example.com', 'path': '/'}
])

# 保存和加载
import json

# 保存
cookies = context.cookies()
with open('cookies.json', 'w') as f:
    json.dump(cookies, f)

# 加载
with open('cookies.json', 'r') as f:
    cookies = json.load(f)
context.add_cookies(cookies)

# 保存存储状态（包括 localStorage）
context.storage_state(path='state.json')

# 加载存储状态
context = browser.new_context(storage_state='state.json')
```

### 5.2 处理弹窗

```python
# Alert/Confirm/Prompt
def handle_dialog(dialog):
    print(f"弹窗: {dialog.message}")
    dialog.accept()  # 或 dialog.dismiss()

page.on('dialog', handle_dialog)

# 新窗口
with context.expect_page() as new_page_info:
    page.click('a[target="_blank"]')
new_page = new_page_info.value
print(new_page.url)
```

### 5.3 iframe 处理

```python
# 获取 iframe
frame = page.frame_locator('iframe#myframe')

# 在 iframe 中操作
frame.locator('button').click()
text = frame.locator('p').inner_text()

# 嵌套 iframe
inner_frame = frame.frame_locator('iframe.inner')
```

### 5.4 完整爬虫示例

```python
from playwright.sync_api import sync_playwright
from dataclasses import dataclass
from typing import List
import json

@dataclass
class Product:
    name: str
    price: str
    url: str
    image: str

class PlaywrightCrawler:
    def __init__(self, headless=True):
        self.headless = headless
        self.playwright = None
        self.browser = None
    
    def __enter__(self):
        self.playwright = sync_playwright().start()
        self.browser = self.playwright.chromium.launch(headless=self.headless)
        return self
    
    def __exit__(self, *args):
        self.browser.close()
        self.playwright.stop()
    
    def crawl_products(self, url: str) -> List[Product]:
        context = self.browser.new_context(
            user_agent='Mozilla/5.0...',
            viewport={'width': 1920, 'height': 1080}
        )
        page = context.new_page()
        
        products = []
        
        try:
            page.goto(url, wait_until='networkidle')
            
            # 滚动加载更多
            for _ in range(3):
                page.evaluate('window.scrollBy(0, 1000)')
                page.wait_for_timeout(1000)
            
            # 提取产品
            items = page.locator('.product-item').all()
            
            for item in items:
                products.append(Product(
                    name=item.locator('.name').inner_text(),
                    price=item.locator('.price').inner_text(),
                    url=item.locator('a').get_attribute('href'),
                    image=item.locator('img').get_attribute('src')
                ))
        
        finally:
            context.close()
        
        return products

# 使用
with PlaywrightCrawler(headless=True) as crawler:
    products = crawler.crawl_products('https://shop.example.com')
    
    for p in products[:5]:
        print(f"{p.name}: {p.price}")
```

---

## Playwright vs Selenium

| 特性 | Playwright | Selenium |
|------|------------|----------|
| 安装 | 简单 | 需要 WebDriver |
| 速度 | 快 | 较慢 |
| 自动等待 | 内置 | 需手动 |
| 网络拦截 | 内置 | 需扩展 |
| 多浏览器 | 内置 | 需配置 |
| 异步支持 | 原生 | 需封装 |
| 社区 | 较新 | 成熟 |

---

## 下一步

下一篇我们将学习 API 逆向分析。

---

## 参考资料

- [Playwright Python 文档](https://playwright.dev/python/)
- [Playwright GitHub](https://github.com/microsoft/playwright-python)
