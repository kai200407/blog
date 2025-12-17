---
title: "Selenium 自动化"
description: "1. [Selenium 入门](#1-selenium-入门)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 11
---

> 本文介绍如何使用 Selenium 爬取 JavaScript 渲染的动态页面。

---

## 目录

1. [Selenium 入门](#1-selenium-入门)
2. [元素定位](#2-元素定位)
3. [页面交互](#3-页面交互)
4. [等待机制](#4-等待机制)
5. [高级技巧](#5-高级技巧)

---

## 1. Selenium 入门

### 1.1 安装

```bash
pip install selenium webdriver-manager
```

### 1.2 基本使用

```python
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager

# 配置选项
options = Options()
options.add_argument('--headless')  # 无头模式
options.add_argument('--no-sandbox')
options.add_argument('--disable-dev-shm-usage')

# 创建浏览器实例
service = Service(ChromeDriverManager().install())
driver = webdriver.Chrome(service=service, options=options)

# 访问页面
driver.get('https://example.com')

# 获取页面内容
print(driver.title)
print(driver.page_source)

# 关闭浏览器
driver.quit()
```

### 1.3 浏览器选项

```python
from selenium.webdriver.chrome.options import Options

options = Options()

# 无头模式
options.add_argument('--headless')

# 禁用 GPU
options.add_argument('--disable-gpu')

# 窗口大小
options.add_argument('--window-size=1920,1080')

# 禁用图片加载
prefs = {'profile.managed_default_content_settings.images': 2}
options.add_experimental_option('prefs', prefs)

# 禁用 JavaScript
prefs = {'profile.managed_default_content_settings.javascript': 2}
options.add_experimental_option('prefs', prefs)

# 设置 User-Agent
options.add_argument('--user-agent=Mozilla/5.0...')

# 禁用自动化检测
options.add_experimental_option('excludeSwitches', ['enable-automation'])
options.add_experimental_option('useAutomationExtension', False)

# 代理
options.add_argument('--proxy-server=http://127.0.0.1:7890')
```

---

## 2. 元素定位

### 2.1 定位方法

```python
from selenium.webdriver.common.by import By

driver.get('https://example.com')

# ID
element = driver.find_element(By.ID, 'main')

# Class Name
elements = driver.find_elements(By.CLASS_NAME, 'item')

# Tag Name
divs = driver.find_elements(By.TAG_NAME, 'div')

# Name
input_elem = driver.find_element(By.NAME, 'username')

# Link Text
link = driver.find_element(By.LINK_TEXT, '点击这里')

# Partial Link Text
link = driver.find_element(By.PARTIAL_LINK_TEXT, '点击')

# CSS Selector
element = driver.find_element(By.CSS_SELECTOR, 'div.content > p.intro')

# XPath
element = driver.find_element(By.XPATH, '//div[@class="content"]/p')
```

### 2.2 CSS 选择器

```python
# ID
driver.find_element(By.CSS_SELECTOR, '#main')

# Class
driver.find_element(By.CSS_SELECTOR, '.item')

# 属性
driver.find_element(By.CSS_SELECTOR, 'input[type="text"]')
driver.find_element(By.CSS_SELECTOR, 'a[href^="https"]')  # 开头
driver.find_element(By.CSS_SELECTOR, 'a[href$=".pdf"]')   # 结尾
driver.find_element(By.CSS_SELECTOR, 'a[href*="example"]')  # 包含

# 层级
driver.find_element(By.CSS_SELECTOR, 'div > p')  # 直接子元素
driver.find_element(By.CSS_SELECTOR, 'div p')    # 后代元素

# 伪类
driver.find_element(By.CSS_SELECTOR, 'li:first-child')
driver.find_element(By.CSS_SELECTOR, 'li:nth-child(2)')
```

### 2.3 XPath

```python
# 绝对路径
driver.find_element(By.XPATH, '/html/body/div/p')

# 相对路径
driver.find_element(By.XPATH, '//div[@id="main"]')

# 属性
driver.find_element(By.XPATH, '//input[@type="text"]')
driver.find_element(By.XPATH, '//a[contains(@href, "example")]')
driver.find_element(By.XPATH, '//a[starts-with(@href, "https")]')

# 文本
driver.find_element(By.XPATH, '//a[text()="点击"]')
driver.find_element(By.XPATH, '//a[contains(text(), "点击")]')

# 轴
driver.find_element(By.XPATH, '//div[@id="main"]/parent::*')  # 父元素
driver.find_element(By.XPATH, '//div[@id="main"]/following-sibling::div')  # 后续兄弟
```

---

## 3. 页面交互

### 3.1 基本操作

```python
from selenium.webdriver.common.keys import Keys

# 点击
button = driver.find_element(By.ID, 'submit')
button.click()

# 输入文本
input_elem = driver.find_element(By.NAME, 'username')
input_elem.clear()  # 清空
input_elem.send_keys('admin')

# 键盘操作
input_elem.send_keys(Keys.ENTER)
input_elem.send_keys(Keys.CONTROL, 'a')  # Ctrl+A

# 获取属性
href = driver.find_element(By.TAG_NAME, 'a').get_attribute('href')
text = driver.find_element(By.TAG_NAME, 'p').text
```

### 3.2 表单操作

```python
from selenium.webdriver.support.ui import Select

# 下拉框
select = Select(driver.find_element(By.ID, 'dropdown'))
select.select_by_value('option1')
select.select_by_visible_text('选项一')
select.select_by_index(0)

# 复选框
checkbox = driver.find_element(By.ID, 'agree')
if not checkbox.is_selected():
    checkbox.click()

# 单选框
radio = driver.find_element(By.XPATH, '//input[@value="male"]')
radio.click()

# 提交表单
form = driver.find_element(By.TAG_NAME, 'form')
form.submit()
```

### 3.3 鼠标操作

```python
from selenium.webdriver.common.action_chains import ActionChains

# 悬停
element = driver.find_element(By.ID, 'menu')
ActionChains(driver).move_to_element(element).perform()

# 右键
ActionChains(driver).context_click(element).perform()

# 双击
ActionChains(driver).double_click(element).perform()

# 拖拽
source = driver.find_element(By.ID, 'source')
target = driver.find_element(By.ID, 'target')
ActionChains(driver).drag_and_drop(source, target).perform()

# 滑动验证码
slider = driver.find_element(By.CLASS_NAME, 'slider')
ActionChains(driver).click_and_hold(slider).move_by_offset(200, 0).release().perform()
```

### 3.4 JavaScript 执行

```python
# 执行 JavaScript
driver.execute_script('alert("Hello")')

# 滚动页面
driver.execute_script('window.scrollTo(0, document.body.scrollHeight)')

# 滚动到元素
element = driver.find_element(By.ID, 'target')
driver.execute_script('arguments[0].scrollIntoView()', element)

# 修改元素属性
driver.execute_script('arguments[0].style.display = "block"', element)

# 获取返回值
title = driver.execute_script('return document.title')
```

---

## 4. 等待机制

### 4.1 隐式等待

```python
# 全局等待
driver.implicitly_wait(10)  # 最多等待 10 秒
```

### 4.2 显式等待

```python
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

wait = WebDriverWait(driver, 10)

# 等待元素可见
element = wait.until(EC.visibility_of_element_located((By.ID, 'content')))

# 等待元素可点击
button = wait.until(EC.element_to_be_clickable((By.ID, 'submit')))

# 等待元素存在
element = wait.until(EC.presence_of_element_located((By.CLASS_NAME, 'item')))

# 等待文本出现
wait.until(EC.text_to_be_present_in_element((By.ID, 'status'), '完成'))

# 等待 URL 变化
wait.until(EC.url_contains('success'))

# 等待新窗口
wait.until(EC.number_of_windows_to_be(2))
```

### 4.3 自定义等待条件

```python
from selenium.webdriver.support.ui import WebDriverWait

def element_has_class(locator, class_name):
    def _predicate(driver):
        element = driver.find_element(*locator)
        if class_name in element.get_attribute('class'):
            return element
        return False
    return _predicate

wait = WebDriverWait(driver, 10)
element = wait.until(element_has_class((By.ID, 'box'), 'active'))
```

---

## 5. 高级技巧

### 5.1 处理弹窗

```python
# Alert 弹窗
alert = driver.switch_to.alert
print(alert.text)
alert.accept()  # 确认
# alert.dismiss()  # 取消

# Confirm 弹窗
confirm = driver.switch_to.alert
confirm.accept()

# Prompt 弹窗
prompt = driver.switch_to.alert
prompt.send_keys('输入内容')
prompt.accept()
```

### 5.2 处理 iframe

```python
# 切换到 iframe
iframe = driver.find_element(By.TAG_NAME, 'iframe')
driver.switch_to.frame(iframe)

# 或者通过 name/id
driver.switch_to.frame('frame_name')

# 在 iframe 中操作
content = driver.find_element(By.ID, 'content')

# 切回主文档
driver.switch_to.default_content()

# 切换到父 frame
driver.switch_to.parent_frame()
```

### 5.3 处理多窗口

```python
# 获取当前窗口句柄
main_window = driver.current_window_handle

# 点击打开新窗口
driver.find_element(By.LINK_TEXT, '新窗口').click()

# 获取所有窗口句柄
all_windows = driver.window_handles

# 切换到新窗口
for window in all_windows:
    if window != main_window:
        driver.switch_to.window(window)
        break

# 在新窗口操作
print(driver.title)

# 关闭当前窗口
driver.close()

# 切回主窗口
driver.switch_to.window(main_window)
```

### 5.4 截图

```python
# 整页截图
driver.save_screenshot('screenshot.png')

# 元素截图
element = driver.find_element(By.ID, 'content')
element.screenshot('element.png')

# 获取截图二进制
png = driver.get_screenshot_as_png()
```

### 5.5 Cookie 操作

```python
# 获取所有 Cookie
cookies = driver.get_cookies()
print(cookies)

# 获取单个 Cookie
cookie = driver.get_cookie('session_id')

# 添加 Cookie
driver.add_cookie({'name': 'token', 'value': 'abc123'})

# 删除 Cookie
driver.delete_cookie('token')
driver.delete_all_cookies()

# 保存和加载 Cookie
import json

# 保存
with open('cookies.json', 'w') as f:
    json.dump(driver.get_cookies(), f)

# 加载
with open('cookies.json', 'r') as f:
    cookies = json.load(f)
    for cookie in cookies:
        driver.add_cookie(cookie)
```

---

## 完整爬虫示例

```python
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager
import time

class SeleniumCrawler:
    def __init__(self, headless=True):
        options = Options()
        if headless:
            options.add_argument('--headless')
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')
        options.add_argument('--window-size=1920,1080')
        
        service = Service(ChromeDriverManager().install())
        self.driver = webdriver.Chrome(service=service, options=options)
        self.wait = WebDriverWait(self.driver, 10)
    
    def get(self, url):
        self.driver.get(url)
        time.sleep(1)
    
    def scroll_to_bottom(self):
        last_height = self.driver.execute_script('return document.body.scrollHeight')
        while True:
            self.driver.execute_script('window.scrollTo(0, document.body.scrollHeight)')
            time.sleep(2)
            new_height = self.driver.execute_script('return document.body.scrollHeight')
            if new_height == last_height:
                break
            last_height = new_height
    
    def extract_items(self, selector):
        elements = self.driver.find_elements(By.CSS_SELECTOR, selector)
        return [elem.text for elem in elements]
    
    def close(self):
        self.driver.quit()

# 使用
crawler = SeleniumCrawler(headless=True)
crawler.get('https://example.com')
crawler.scroll_to_bottom()
items = crawler.extract_items('.item')
print(items)
crawler.close()
```

---

## 下一步

下一篇我们将学习 Playwright，这是更现代的浏览器自动化方案。

---

## 参考资料

- [Selenium Python 文档](https://selenium-python.readthedocs.io/)
- [WebDriver Manager](https://github.com/SergeyPirogov/webdriver_manager)
