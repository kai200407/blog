---
title: "浏览器指纹与反检测"
description: "1. [浏览器指纹](#1-浏览器指纹)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 18
---

> 本文介绍浏览器指纹技术及如何绕过反爬检测。

---

## 目录

1. [浏览器指纹](#1-浏览器指纹)
2. [常见检测方式](#2-常见检测方式)
3. [反检测技术](#3-反检测技术)
4. [Playwright 反检测](#4-playwright-反检测)
5. [实战应用](#5-实战应用)

---

## 1. 浏览器指纹

### 1.1 什么是浏览器指纹

浏览器指纹是通过收集浏览器和设备信息生成的唯一标识：

| 类型 | 信息 |
|------|------|
| 基础信息 | User-Agent、语言、时区 |
| 屏幕信息 | 分辨率、色深、像素比 |
| 硬件信息 | CPU 核心数、内存大小 |
| 插件信息 | 已安装插件列表 |
| Canvas | Canvas 渲染指纹 |
| WebGL | WebGL 渲染器信息 |
| 音频 | AudioContext 指纹 |
| 字体 | 已安装字体列表 |

### 1.2 指纹检测示例

```javascript
// 网站检测脚本示例
const fingerprint = {
    userAgent: navigator.userAgent,
    language: navigator.language,
    platform: navigator.platform,
    hardwareConcurrency: navigator.hardwareConcurrency,
    deviceMemory: navigator.deviceMemory,
    screenResolution: `${screen.width}x${screen.height}`,
    colorDepth: screen.colorDepth,
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
    webdriver: navigator.webdriver,
    plugins: Array.from(navigator.plugins).map(p => p.name),
};

// Canvas 指纹
const canvas = document.createElement('canvas');
const ctx = canvas.getContext('2d');
ctx.textBaseline = 'top';
ctx.font = '14px Arial';
ctx.fillText('fingerprint', 0, 0);
fingerprint.canvas = canvas.toDataURL();

// WebGL 指纹
const gl = canvas.getContext('webgl');
fingerprint.webglVendor = gl.getParameter(gl.VENDOR);
fingerprint.webglRenderer = gl.getParameter(gl.RENDERER);
```

---

## 2. 常见检测方式

### 2.1 WebDriver 检测

```javascript
// 检测 navigator.webdriver
if (navigator.webdriver) {
    console.log('检测到自动化工具');
}

// 检测 window 属性
const automationProps = [
    'webdriver',
    '__webdriver_script_fn',
    '__driver_evaluate',
    '__webdriver_evaluate',
    '__selenium_evaluate',
    '__fxdriver_evaluate',
    '__driver_unwrapped',
    '__webdriver_unwrapped',
    '__selenium_unwrapped',
    '__fxdriver_unwrapped',
    '_Selenium_IDE_Recorder',
    '_selenium',
    'calledSelenium',
    '$cdc_asdjflasutopfhvcZLmcfl_',
    '$chrome_asyncScriptInfo',
    '__$webdriverAsyncExecutor',
];

for (const prop of automationProps) {
    if (window[prop] || document[prop]) {
        console.log(`检测到: ${prop}`);
    }
}
```

### 2.2 Headless 检测

```javascript
// 检测 Headless Chrome
function isHeadless() {
    // User-Agent 检测
    if (/HeadlessChrome/.test(navigator.userAgent)) {
        return true;
    }
    
    // 插件检测
    if (navigator.plugins.length === 0) {
        return true;
    }
    
    // 语言检测
    if (navigator.languages.length === 0) {
        return true;
    }
    
    // WebGL 检测
    const canvas = document.createElement('canvas');
    const gl = canvas.getContext('webgl');
    const debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
    const renderer = gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL);
    
    if (/SwiftShader/.test(renderer)) {
        return true;
    }
    
    return false;
}
```

### 2.3 行为检测

```javascript
// 鼠标移动检测
let mouseEvents = [];
document.addEventListener('mousemove', (e) => {
    mouseEvents.push({
        x: e.clientX,
        y: e.clientY,
        t: Date.now()
    });
});

// 分析鼠标轨迹
function analyzeMouseBehavior() {
    if (mouseEvents.length < 10) {
        return 'suspicious';  // 事件太少
    }
    
    // 检测直线移动（机器人特征）
    let straightLines = 0;
    for (let i = 2; i < mouseEvents.length; i++) {
        const p1 = mouseEvents[i - 2];
        const p2 = mouseEvents[i - 1];
        const p3 = mouseEvents[i];
        
        // 计算是否在同一直线上
        const cross = (p2.x - p1.x) * (p3.y - p1.y) - (p3.x - p1.x) * (p2.y - p1.y);
        if (Math.abs(cross) < 1) {
            straightLines++;
        }
    }
    
    if (straightLines / mouseEvents.length > 0.8) {
        return 'bot';
    }
    
    return 'human';
}
```

---

## 3. 反检测技术

### 3.1 修改 WebDriver 属性

```python
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

def create_stealth_driver():
    """创建隐身浏览器"""
    options = Options()
    
    # 禁用自动化标志
    options.add_argument('--disable-blink-features=AutomationControlled')
    
    # 排除自动化开关
    options.add_experimental_option('excludeSwitches', ['enable-automation'])
    options.add_experimental_option('useAutomationExtension', False)
    
    driver = webdriver.Chrome(options=options)
    
    # 修改 navigator.webdriver
    driver.execute_cdp_cmd('Page.addScriptToEvaluateOnNewDocument', {
        'source': '''
            Object.defineProperty(navigator, 'webdriver', {
                get: () => undefined
            });
        '''
    })
    
    return driver
```

### 3.2 使用 undetected-chromedriver

```python
# pip install undetected-chromedriver

import undetected_chromedriver as uc

def create_undetected_driver():
    """创建反检测浏览器"""
    options = uc.ChromeOptions()
    options.add_argument('--disable-popup-blocking')
    
    driver = uc.Chrome(options=options)
    return driver

# 使用
driver = create_undetected_driver()
driver.get('https://example.com')
```

### 3.3 修改浏览器指纹

```python
from selenium import webdriver

def inject_fingerprint(driver, fingerprint):
    """注入自定义指纹"""
    script = f'''
        // 修改 User-Agent
        Object.defineProperty(navigator, 'userAgent', {{
            get: () => '{fingerprint["userAgent"]}'
        }});
        
        // 修改平台
        Object.defineProperty(navigator, 'platform', {{
            get: () => '{fingerprint["platform"]}'
        }});
        
        // 修改语言
        Object.defineProperty(navigator, 'language', {{
            get: () => '{fingerprint["language"]}'
        }});
        
        Object.defineProperty(navigator, 'languages', {{
            get: () => {fingerprint["languages"]}
        }});
        
        // 修改硬件信息
        Object.defineProperty(navigator, 'hardwareConcurrency', {{
            get: () => {fingerprint["hardwareConcurrency"]}
        }});
        
        // 修改屏幕信息
        Object.defineProperty(screen, 'width', {{
            get: () => {fingerprint["screenWidth"]}
        }});
        
        Object.defineProperty(screen, 'height', {{
            get: () => {fingerprint["screenHeight"]}
        }});
        
        // 修改插件
        Object.defineProperty(navigator, 'plugins', {{
            get: () => {{
                const plugins = [];
                {fingerprint["plugins"]}.forEach(name => {{
                    plugins.push({{name: name, filename: name + '.dll'}});
                }});
                plugins.length = {len(fingerprint.get("plugins", []))};
                return plugins;
            }}
        }});
    '''
    
    driver.execute_cdp_cmd('Page.addScriptToEvaluateOnNewDocument', {
        'source': script
    })

# 使用
fingerprint = {
    'userAgent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'platform': 'Win32',
    'language': 'zh-CN',
    'languages': ['zh-CN', 'zh', 'en'],
    'hardwareConcurrency': 8,
    'screenWidth': 1920,
    'screenHeight': 1080,
    'plugins': ['Chrome PDF Plugin', 'Chrome PDF Viewer'],
}

inject_fingerprint(driver, fingerprint)
```

---

## 4. Playwright 反检测

### 4.1 基础配置

```python
from playwright.sync_api import sync_playwright

def create_stealth_browser():
    """创建隐身浏览器"""
    playwright = sync_playwright().start()
    
    browser = playwright.chromium.launch(
        headless=False,  # 非 Headless 更难检测
        args=[
            '--disable-blink-features=AutomationControlled',
            '--disable-dev-shm-usage',
            '--no-sandbox',
        ]
    )
    
    context = browser.new_context(
        viewport={'width': 1920, 'height': 1080},
        user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        locale='zh-CN',
        timezone_id='Asia/Shanghai',
        geolocation={'latitude': 39.9042, 'longitude': 116.4074},
        permissions=['geolocation'],
    )
    
    return playwright, browser, context
```

### 4.2 使用 playwright-stealth

```python
# pip install playwright-stealth

from playwright.sync_api import sync_playwright
from playwright_stealth import stealth_sync

def create_stealth_page():
    """创建隐身页面"""
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        
        # 应用隐身脚本
        stealth_sync(page)
        
        page.goto('https://bot.sannysoft.com/')
        page.screenshot(path='stealth_test.png')
        
        browser.close()

# 异步版本
from playwright.async_api import async_playwright
from playwright_stealth import stealth_async

async def create_stealth_page_async():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        
        await stealth_async(page)
        
        await page.goto('https://bot.sannysoft.com/')
        await browser.close()
```

### 4.3 自定义隐身脚本

```python
STEALTH_SCRIPT = '''
// 隐藏 webdriver
Object.defineProperty(navigator, 'webdriver', {
    get: () => undefined
});

// 修改 plugins
Object.defineProperty(navigator, 'plugins', {
    get: () => {
        const plugins = [
            {name: 'Chrome PDF Plugin', filename: 'internal-pdf-viewer'},
            {name: 'Chrome PDF Viewer', filename: 'mhjfbmdgcfjbbpaeojofohoefgiehjai'},
            {name: 'Native Client', filename: 'internal-nacl-plugin'},
        ];
        plugins.length = 3;
        return plugins;
    }
});

// 修改 languages
Object.defineProperty(navigator, 'languages', {
    get: () => ['zh-CN', 'zh', 'en']
});

// 修改 permissions
const originalQuery = window.navigator.permissions.query;
window.navigator.permissions.query = (parameters) => (
    parameters.name === 'notifications' ?
        Promise.resolve({ state: Notification.permission }) :
        originalQuery(parameters)
);

// 修改 chrome
window.chrome = {
    runtime: {},
    loadTimes: function() {},
    csi: function() {},
    app: {}
};

// 修改 WebGL
const getParameter = WebGLRenderingContext.prototype.getParameter;
WebGLRenderingContext.prototype.getParameter = function(parameter) {
    if (parameter === 37445) {
        return 'Intel Inc.';
    }
    if (parameter === 37446) {
        return 'Intel Iris OpenGL Engine';
    }
    return getParameter.call(this, parameter);
};
'''

def apply_stealth(page):
    """应用隐身脚本"""
    page.add_init_script(STEALTH_SCRIPT)
```

### 4.4 模拟人类行为

```python
import random
import time

class HumanBehavior:
    """模拟人类行为"""
    
    def __init__(self, page):
        self.page = page
    
    def random_delay(self, min_ms=100, max_ms=500):
        """随机延迟"""
        delay = random.randint(min_ms, max_ms)
        self.page.wait_for_timeout(delay)
    
    def human_type(self, selector, text):
        """模拟人类打字"""
        element = self.page.locator(selector)
        element.click()
        
        for char in text:
            element.type(char)
            # 随机打字间隔
            self.page.wait_for_timeout(random.randint(50, 150))
    
    def human_click(self, selector):
        """模拟人类点击"""
        element = self.page.locator(selector)
        box = element.bounding_box()
        
        if box:
            # 随机点击位置（在元素内）
            x = box['x'] + random.uniform(5, box['width'] - 5)
            y = box['y'] + random.uniform(5, box['height'] - 5)
            
            # 移动鼠标
            self.page.mouse.move(x, y)
            self.random_delay(100, 300)
            
            # 点击
            self.page.mouse.click(x, y)
        else:
            element.click()
    
    def random_scroll(self):
        """随机滚动"""
        scroll_y = random.randint(100, 500)
        self.page.evaluate(f'window.scrollBy(0, {scroll_y})')
        self.random_delay(500, 1500)
    
    def random_mouse_move(self):
        """随机鼠标移动"""
        viewport = self.page.viewport_size
        
        for _ in range(random.randint(3, 8)):
            x = random.randint(0, viewport['width'])
            y = random.randint(0, viewport['height'])
            self.page.mouse.move(x, y)
            self.page.wait_for_timeout(random.randint(50, 200))

# 使用
behavior = HumanBehavior(page)
behavior.human_click('#login-btn')
behavior.human_type('#username', 'user123')
behavior.random_scroll()
```

---

## 5. 实战应用

### 5.1 完整反检测爬虫

```python
from playwright.sync_api import sync_playwright
from playwright_stealth import stealth_sync
import random
import time

class StealthCrawler:
    """反检测爬虫"""
    
    def __init__(self, headless=False):
        self.headless = headless
        self.playwright = None
        self.browser = None
        self.context = None
    
    def __enter__(self):
        self.playwright = sync_playwright().start()
        
        self.browser = self.playwright.chromium.launch(
            headless=self.headless,
            args=[
                '--disable-blink-features=AutomationControlled',
                '--disable-dev-shm-usage',
            ]
        )
        
        self.context = self.browser.new_context(
            viewport={'width': 1920, 'height': 1080},
            user_agent=self._random_user_agent(),
            locale='zh-CN',
            timezone_id='Asia/Shanghai',
        )
        
        return self
    
    def __exit__(self, *args):
        if self.context:
            self.context.close()
        if self.browser:
            self.browser.close()
        if self.playwright:
            self.playwright.stop()
    
    def _random_user_agent(self):
        """随机 User-Agent"""
        user_agents = [
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
        ]
        return random.choice(user_agents)
    
    def new_page(self):
        """创建新页面"""
        page = self.context.new_page()
        stealth_sync(page)
        return page
    
    def crawl(self, url):
        """爬取页面"""
        page = self.new_page()
        
        try:
            page.goto(url, wait_until='networkidle')
            
            # 随机行为
            self._random_behavior(page)
            
            # 获取内容
            content = page.content()
            
            return content
        finally:
            page.close()
    
    def _random_behavior(self, page):
        """随机行为"""
        # 随机滚动
        for _ in range(random.randint(1, 3)):
            page.evaluate(f'window.scrollBy(0, {random.randint(100, 300)})')
            page.wait_for_timeout(random.randint(500, 1500))
        
        # 随机鼠标移动
        viewport = page.viewport_size
        for _ in range(random.randint(2, 5)):
            x = random.randint(0, viewport['width'])
            y = random.randint(0, viewport['height'])
            page.mouse.move(x, y)
            page.wait_for_timeout(random.randint(100, 300))

# 使用
with StealthCrawler(headless=True) as crawler:
    content = crawler.crawl('https://example.com')
    print(f"获取内容长度: {len(content)}")
```

---

## 检测测试网站

| 网站 | 用途 |
|------|------|
| bot.sannysoft.com | 综合检测 |
| browserleaks.com | 浏览器泄露检测 |
| fingerprintjs.com | 指纹检测 |
| amiunique.org | 唯一性检测 |

---

## 下一步

下一篇我们将学习数据库存储基础。

---

## 参考资料

- [undetected-chromedriver](https://github.com/ultrafunkamsterdam/undetected-chromedriver)
- [playwright-stealth](https://github.com/nickvdyck/playwright-stealth)
- [FingerprintJS](https://fingerprintjs.com/)
