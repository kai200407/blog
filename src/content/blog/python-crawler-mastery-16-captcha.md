---
title: "验证码识别"
description: "1. [验证码类型](#1-验证码类型)"
pubDate: "2025-12-17"
tags: ["python","crawler","scraping"]
category: "python"
series: "Python 爬虫实战"
order: 16
---

> 本文介绍常见验证码类型及其识别方法。

---

## 目录

1. [验证码类型](#1-验证码类型)
2. [图片验证码](#2-图片验证码)
3. [滑块验证码](#3-滑块验证码)
4. [点选验证码](#4-点选验证码)
5. [第三方服务](#5-第三方服务)

---

## 1. 验证码类型

| 类型 | 描述 | 难度 |
|------|------|------|
| 图片验证码 | 识别图片中的字符 | 低-中 |
| 滑块验证码 | 拖动滑块到缺口位置 | 中 |
| 点选验证码 | 按顺序点击指定内容 | 中-高 |
| 行为验证码 | 分析用户行为轨迹 | 高 |
| reCAPTCHA | Google 验证码 | 高 |

---

## 2. 图片验证码

### 2.1 简单验证码识别

```python
# 安装依赖
# pip install pytesseract pillow
# 还需安装 Tesseract OCR

import pytesseract
from PIL import Image
import requests
from io import BytesIO

def recognize_captcha(image_url):
    """识别简单图片验证码"""
    # 下载图片
    response = requests.get(image_url)
    image = Image.open(BytesIO(response.content))
    
    # 预处理
    image = image.convert('L')  # 灰度化
    image = image.point(lambda x: 0 if x < 128 else 255)  # 二值化
    
    # OCR 识别
    text = pytesseract.image_to_string(
        image,
        config='--psm 7 -c tessedit_char_whitelist=0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    )
    
    return text.strip()

# 使用
captcha_text = recognize_captcha('https://example.com/captcha.png')
print(f"验证码: {captcha_text}")
```

### 2.2 图片预处理

```python
from PIL import Image, ImageFilter, ImageEnhance
import numpy as np

def preprocess_captcha(image):
    """验证码图片预处理"""
    # 转为灰度图
    image = image.convert('L')
    
    # 增强对比度
    enhancer = ImageEnhance.Contrast(image)
    image = enhancer.enhance(2.0)
    
    # 去噪
    image = image.filter(ImageFilter.MedianFilter(size=3))
    
    # 二值化
    threshold = 128
    image = image.point(lambda x: 255 if x > threshold else 0)
    
    # 去除边框
    image = remove_border(image)
    
    return image

def remove_border(image, border_width=2):
    """去除边框"""
    width, height = image.size
    pixels = image.load()
    
    # 将边框像素设为白色
    for x in range(width):
        for y in range(border_width):
            pixels[x, y] = 255
            pixels[x, height - 1 - y] = 255
    
    for y in range(height):
        for x in range(border_width):
            pixels[x, y] = 255
            pixels[width - 1 - x, y] = 255
    
    return image

def remove_noise(image, threshold=2):
    """去除噪点"""
    pixels = np.array(image)
    height, width = pixels.shape
    
    for y in range(1, height - 1):
        for x in range(1, width - 1):
            if pixels[y, x] == 0:  # 黑色像素
                # 统计周围黑色像素数量
                neighbors = pixels[y-1:y+2, x-1:x+2]
                black_count = np.sum(neighbors == 0)
                
                if black_count < threshold:
                    pixels[y, x] = 255  # 去除孤立噪点
    
    return Image.fromarray(pixels)
```

### 2.3 使用深度学习

```python
# pip install ddddocr

import ddddocr

def recognize_with_ddddocr(image_bytes):
    """使用 ddddocr 识别验证码"""
    ocr = ddddocr.DdddOcr()
    result = ocr.classification(image_bytes)
    return result

# 使用
import requests

response = requests.get('https://example.com/captcha.png')
captcha_text = recognize_with_ddddocr(response.content)
print(f"验证码: {captcha_text}")
```

---

## 3. 滑块验证码

### 3.1 缺口检测

```python
import cv2
import numpy as np
from PIL import Image

def detect_gap(bg_image, slider_image):
    """检测滑块缺口位置"""
    # 转换为 OpenCV 格式
    bg = cv2.cvtColor(np.array(bg_image), cv2.COLOR_RGB2BGR)
    slider = cv2.cvtColor(np.array(slider_image), cv2.COLOR_RGB2BGR)
    
    # 边缘检测
    bg_edge = cv2.Canny(bg, 100, 200)
    slider_edge = cv2.Canny(slider, 100, 200)
    
    # 模板匹配
    result = cv2.matchTemplate(bg_edge, slider_edge, cv2.TM_CCOEFF_NORMED)
    
    # 获取最佳匹配位置
    _, _, _, max_loc = cv2.minMaxLoc(result)
    
    return max_loc[0]  # 返回 x 坐标

def detect_gap_by_diff(bg_image, full_image):
    """通过对比完整图和缺口图检测位置"""
    bg = np.array(bg_image)
    full = np.array(full_image)
    
    # 计算差异
    diff = cv2.absdiff(bg, full)
    gray = cv2.cvtColor(diff, cv2.COLOR_RGB2GRAY)
    
    # 二值化
    _, thresh = cv2.threshold(gray, 30, 255, cv2.THRESH_BINARY)
    
    # 找轮廓
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    # 找最大轮廓
    if contours:
        max_contour = max(contours, key=cv2.contourArea)
        x, y, w, h = cv2.boundingRect(max_contour)
        return x
    
    return 0
```

### 3.2 模拟滑动轨迹

```python
import random
import time

def generate_track(distance):
    """生成滑动轨迹"""
    track = []
    current = 0
    mid = distance * 3 / 4  # 减速点
    t = 0.2  # 时间间隔
    v = 0  # 初始速度
    
    while current < distance:
        if current < mid:
            a = 2  # 加速
        else:
            a = -3  # 减速
        
        v0 = v
        v = v0 + a * t
        move = v0 * t + 0.5 * a * t * t
        current += move
        
        track.append(round(move))
    
    # 微调
    track.append(distance - sum(track))
    
    return track

def generate_human_track(distance):
    """生成更像人类的轨迹"""
    track = []
    current = 0
    
    # 快速移动到接近目标
    while current < distance - 10:
        move = random.randint(5, 15)
        if current + move > distance - 10:
            move = distance - 10 - current
        track.append(move)
        current += move
    
    # 慢速微调
    while current < distance:
        move = random.randint(1, 3)
        if current + move > distance:
            move = distance - current
        track.append(move)
        current += move
    
    # 添加回退
    track.append(-random.randint(1, 3))
    track.append(random.randint(1, 3))
    
    return track
```

### 3.3 Selenium 滑动

```python
from selenium import webdriver
from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.common.by import By
import time

def slide_captcha(driver, slider_element, distance):
    """滑动验证码"""
    action = ActionChains(driver)
    
    # 点击并按住滑块
    action.click_and_hold(slider_element).perform()
    time.sleep(0.2)
    
    # 生成轨迹
    track = generate_human_track(distance)
    
    # 按轨迹移动
    for move in track:
        action.move_by_offset(move, random.randint(-2, 2)).perform()
        time.sleep(random.uniform(0.01, 0.03))
    
    time.sleep(0.2)
    
    # 释放
    action.release().perform()

# 使用示例
driver = webdriver.Chrome()
driver.get('https://example.com/login')

# 获取滑块元素
slider = driver.find_element(By.CLASS_NAME, 'slider-button')

# 获取背景图和滑块图，计算距离
# distance = detect_gap(bg_image, slider_image)
distance = 200  # 示例距离

slide_captcha(driver, slider, distance)
```

### 3.4 Playwright 滑动

```python
from playwright.sync_api import sync_playwright
import random

def slide_with_playwright(page, slider_selector, distance):
    """使用 Playwright 滑动"""
    slider = page.locator(slider_selector)
    box = slider.bounding_box()
    
    # 起始位置
    start_x = box['x'] + box['width'] / 2
    start_y = box['y'] + box['height'] / 2
    
    # 生成轨迹
    track = generate_human_track(distance)
    
    # 移动到滑块
    page.mouse.move(start_x, start_y)
    page.mouse.down()
    
    current_x = start_x
    for move in track:
        current_x += move
        page.mouse.move(current_x, start_y + random.randint(-2, 2))
        page.wait_for_timeout(random.randint(10, 30))
    
    page.mouse.up()

# 使用
with sync_playwright() as p:
    browser = p.chromium.launch(headless=False)
    page = browser.new_page()
    page.goto('https://example.com/login')
    
    slide_with_playwright(page, '.slider-button', 200)
```

---

## 4. 点选验证码

### 4.1 文字点选

```python
import ddddocr

def detect_click_captcha(image_bytes, target_text):
    """检测点选验证码中的文字位置"""
    det = ddddocr.DdddOcr(det=True)
    
    # 检测所有文字位置
    boxes = det.detection(image_bytes)
    
    ocr = ddddocr.DdddOcr()
    
    results = []
    for box in boxes:
        # 裁剪文字区域
        x1, y1, x2, y2 = box
        # 识别文字
        # text = ocr.classification(cropped_image)
        # if text in target_text:
        #     results.append((x1 + (x2-x1)//2, y1 + (y2-y1)//2))
        
        # 返回中心点
        center_x = (x1 + x2) // 2
        center_y = (y1 + y2) // 2
        results.append((center_x, center_y))
    
    return results
```

### 4.2 图标点选

```python
import cv2
import numpy as np

def find_icon_positions(bg_image, icon_image):
    """在背景图中找到图标位置"""
    bg = cv2.cvtColor(np.array(bg_image), cv2.COLOR_RGB2BGR)
    icon = cv2.cvtColor(np.array(icon_image), cv2.COLOR_RGB2BGR)
    
    # 模板匹配
    result = cv2.matchTemplate(bg, icon, cv2.TM_CCOEFF_NORMED)
    
    # 设置阈值
    threshold = 0.8
    locations = np.where(result >= threshold)
    
    # 获取所有匹配位置
    positions = []
    h, w = icon.shape[:2]
    
    for pt in zip(*locations[::-1]):
        center_x = pt[0] + w // 2
        center_y = pt[1] + h // 2
        positions.append((center_x, center_y))
    
    # 去重（合并相近的点）
    return merge_close_points(positions, threshold=20)

def merge_close_points(points, threshold=20):
    """合并相近的点"""
    if not points:
        return []
    
    merged = [points[0]]
    
    for point in points[1:]:
        is_close = False
        for existing in merged:
            dist = ((point[0] - existing[0])**2 + (point[1] - existing[1])**2)**0.5
            if dist < threshold:
                is_close = True
                break
        
        if not is_close:
            merged.append(point)
    
    return merged
```

---

## 5. 第三方服务

### 5.1 打码平台

```python
import requests
import base64
import time

class CaptchaSolver:
    """验证码打码服务"""
    
    def __init__(self, api_key):
        self.api_key = api_key
        self.base_url = 'https://api.captcha-service.com'
    
    def solve_image(self, image_bytes):
        """识别图片验证码"""
        image_base64 = base64.b64encode(image_bytes).decode()
        
        # 提交任务
        response = requests.post(
            f'{self.base_url}/createTask',
            json={
                'clientKey': self.api_key,
                'task': {
                    'type': 'ImageToTextTask',
                    'body': image_base64
                }
            }
        )
        
        task_id = response.json()['taskId']
        
        # 轮询结果
        for _ in range(30):
            time.sleep(2)
            
            result = requests.post(
                f'{self.base_url}/getTaskResult',
                json={
                    'clientKey': self.api_key,
                    'taskId': task_id
                }
            )
            
            data = result.json()
            if data['status'] == 'ready':
                return data['solution']['text']
        
        return None
    
    def solve_recaptcha(self, site_key, page_url):
        """识别 reCAPTCHA"""
        response = requests.post(
            f'{self.base_url}/createTask',
            json={
                'clientKey': self.api_key,
                'task': {
                    'type': 'RecaptchaV2TaskProxyless',
                    'websiteURL': page_url,
                    'websiteKey': site_key
                }
            }
        )
        
        task_id = response.json()['taskId']
        
        # 轮询结果
        for _ in range(60):
            time.sleep(3)
            
            result = requests.post(
                f'{self.base_url}/getTaskResult',
                json={
                    'clientKey': self.api_key,
                    'taskId': task_id
                }
            )
            
            data = result.json()
            if data['status'] == 'ready':
                return data['solution']['gRecaptchaResponse']
        
        return None

# 使用
solver = CaptchaSolver('your_api_key')
captcha_text = solver.solve_image(image_bytes)
```

### 5.2 常用打码平台

| 平台 | 特点 |
|------|------|
| 2Captcha | 支持多种验证码 |
| Anti-Captcha | 价格实惠 |
| CapMonster | 自动化友好 |
| 超级鹰 | 国内平台 |

---

## 注意事项

⚠️ **法律与道德**：
- 仅用于学习研究
- 遵守网站服务条款
- 不要用于恶意目的
- 考虑对网站的影响

---

## 下一步

下一篇我们将学习 Cookie 和 Session 管理。

---

## 参考资料

- [Tesseract OCR](https://github.com/tesseract-ocr/tesseract)
- [ddddocr](https://github.com/sml2h3/ddddocr)
- [OpenCV 文档](https://docs.opencv.org/)
