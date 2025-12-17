---
title: "Modules"
description: "1. [Modules 概述](#1-modules-概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 38
---

> 本文是 C++ 从入门到精通系列的第三十八篇,将深入讲解 C++20 引入的模块 (Modules) 系统。

---

## 目录

1. [Modules 概述](#1-modules-概述)
2. [模块基础](#2-模块基础)
3. [模块分区](#3-模块分区)
4. [模块与头文件](#4-模块与头文件)
5. [构建系统](#5-构建系统)
6. [最佳实践](#6-最佳实践)
7. [总结](#7-总结)

---

## 1. Modules 概述

### 1.1 为什么需要 Modules

```
传统头文件的问题:

1. 编译速度慢
   - 每个翻译单元重复解析头文件
   - 宏污染
   - 包含顺序敏感

2. 封装性差
   - 所有内容都暴露
   - 无法隐藏实现细节

3. 脆弱性
   - 宏定义冲突
   - 包含保护
   - ODR 违规风险

Modules 的优势:

1. 更快的编译
   - 只编译一次
   - 二进制模块接口

2. 更好的封装
   - 显式导出
   - 隐藏实现

3. 更安全
   - 无宏泄漏
   - 无包含顺序问题
```

### 1.2 基本概念

```
模块术语:

- 模块单元 (Module Unit): 包含模块声明的翻译单元
- 模块接口单元 (Module Interface Unit): 导出模块接口
- 模块实现单元 (Module Implementation Unit): 实现细节
- 模块分区 (Module Partition): 模块的子部分
- 导入声明 (Import Declaration): 导入模块
- 导出声明 (Export Declaration): 导出实体
```

---

## 2. 模块基础

### 2.1 创建模块

```cpp
// math.cppm (模块接口单元)
export module math;

// 导出函数
export int add(int a, int b) {
    return a + b;
}

export int subtract(int a, int b) {
    return a - b;
}

// 导出类
export class Calculator {
public:
    int multiply(int a, int b) const {
        return a * b;
    }
    
    int divide(int a, int b) const {
        return b != 0 ? a / b : 0;
    }
};

// 不导出的内部函数
int internalHelper(int x) {
    return x * 2;
}
```

### 2.2 使用模块

```cpp
// main.cpp
import math;

#include <iostream>

int main() {
    std::cout << "add(3, 4) = " << add(3, 4) << std::endl;
    std::cout << "subtract(10, 3) = " << subtract(10, 3) << std::endl;
    
    Calculator calc;
    std::cout << "multiply(5, 6) = " << calc.multiply(5, 6) << std::endl;
    std::cout << "divide(20, 4) = " << calc.divide(20, 4) << std::endl;
    
    // internalHelper(5);  // 错误: 未导出
    
    return 0;
}
```

### 2.3 导出声明

```cpp
// shapes.cppm
export module shapes;

// 导出单个实体
export struct Point {
    double x, y;
};

// 导出块
export {
    class Circle {
    public:
        Circle(Point center, double radius)
            : center(center), radius(radius) { }
        
        double area() const {
            return 3.14159 * radius * radius;
        }
        
    private:
        Point center;
        double radius;
    };
    
    class Rectangle {
    public:
        Rectangle(Point topLeft, double width, double height)
            : topLeft(topLeft), width(width), height(height) { }
        
        double area() const {
            return width * height;
        }
        
    private:
        Point topLeft;
        double width, height;
    };
}

// 导出命名空间
export namespace geometry {
    double distance(Point a, Point b) {
        double dx = a.x - b.x;
        double dy = a.y - b.y;
        return std::sqrt(dx * dx + dy * dy);
    }
}
```

### 2.4 模块实现单元

```cpp
// math.cppm (接口单元)
export module math;

export int add(int a, int b);
export int multiply(int a, int b);

// math_impl.cpp (实现单元)
module math;

int add(int a, int b) {
    return a + b;
}

int multiply(int a, int b) {
    return a * b;
}
```

---

## 3. 模块分区

### 3.1 接口分区

```cpp
// math-basic.cppm (接口分区)
export module math:basic;

export int add(int a, int b) {
    return a + b;
}

export int subtract(int a, int b) {
    return a - b;
}

// math-advanced.cppm (接口分区)
export module math:advanced;

export int power(int base, int exp) {
    int result = 1;
    for (int i = 0; i < exp; ++i) {
        result *= base;
    }
    return result;
}

export int factorial(int n) {
    int result = 1;
    for (int i = 2; i <= n; ++i) {
        result *= i;
    }
    return result;
}

// math.cppm (主接口单元)
export module math;

export import :basic;
export import :advanced;
```

### 3.2 实现分区

```cpp
// math-impl.cppm (实现分区,不导出)
module math:impl;

int gcd(int a, int b) {
    while (b != 0) {
        int temp = b;
        b = a % b;
        a = temp;
    }
    return a;
}

// math.cppm
export module math;

import :impl;  // 导入实现分区

export int simplifyFraction(int& num, int& den) {
    int g = gcd(num, den);  // 使用内部函数
    num /= g;
    den /= g;
    return g;
}
```

### 3.3 分区组织

```
模块分区结构示例:

mylib/
├── mylib.cppm              # 主接口单元
├── mylib-types.cppm        # 类型定义分区
├── mylib-utils.cppm        # 工具函数分区
├── mylib-impl.cppm         # 实现分区
└── mylib-internal.cpp      # 实现单元
```

---

## 4. 模块与头文件

### 4.1 导入头文件

```cpp
// 使用 import 导入标准库头文件
import <iostream>;
import <vector>;
import <string>;

// 或者使用传统方式
#include <iostream>

// 模块中使用头文件
export module mymodule;

// 全局模块片段 (用于包含头文件)
module;

#include <cmath>
#include <algorithm>

export module mymodule;

export double squareRoot(double x) {
    return std::sqrt(x);
}
```

### 4.2 头文件单元

```cpp
// 将头文件作为头文件单元导入
import "legacy_header.h";

// 或者
import <legacy_header.h>;
```

### 4.3 混合使用

```cpp
// mylib.cppm
export module mylib;

// 全局模块片段
module;

#include <vector>
#include <string>
#include <memory>

export module mylib;

export class DataProcessor {
public:
    void addData(const std::string& data) {
        data_.push_back(data);
    }
    
    size_t count() const {
        return data_.size();
    }
    
private:
    std::vector<std::string> data_;
};
```

---

## 5. 构建系统

### 5.1 编译器支持

```
编译器支持 (截至 2024):

MSVC:
- 完整支持
- 使用 /std:c++20 和 /experimental:module

GCC:
- 部分支持
- 使用 -fmodules-ts

Clang:
- 部分支持
- 使用 -fmodules

模块文件扩展名:
- .cppm (通用)
- .ixx (MSVC)
- .mpp
- .cxxm
```

### 5.2 CMake 支持

```cmake
# CMakeLists.txt
cmake_minimum_required(VERSION 3.28)
project(ModulesExample CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 启用模块扫描
set(CMAKE_CXX_SCAN_FOR_MODULES ON)

# 添加模块库
add_library(math)
target_sources(math
    PUBLIC
        FILE_SET CXX_MODULES FILES
            math.cppm
)

# 添加可执行文件
add_executable(main main.cpp)
target_link_libraries(main PRIVATE math)
```

### 5.3 手动编译

```bash
# MSVC
cl /std:c++20 /experimental:module /c math.cppm
cl /std:c++20 /experimental:module main.cpp math.obj

# GCC
g++ -std=c++20 -fmodules-ts -c math.cppm
g++ -std=c++20 -fmodules-ts main.cpp math.o -o main

# Clang
clang++ -std=c++20 -fmodules --precompile math.cppm -o math.pcm
clang++ -std=c++20 -fmodules -fmodule-file=math.pcm main.cpp -o main
```

---

## 6. 最佳实践

### 6.1 模块设计

```cpp
// 好的模块设计

// 1. 清晰的接口
export module graphics;

export namespace graphics {
    class Window { /* ... */ };
    class Renderer { /* ... */ };
    
    void initialize();
    void shutdown();
}

// 2. 隐藏实现细节
module graphics;

namespace graphics::detail {
    // 内部实现,不导出
    class InternalBuffer { /* ... */ };
}

// 3. 使用分区组织大型模块
export module graphics:window;
export module graphics:renderer;
export module graphics:utils;
```

### 6.2 迁移策略

```
从头文件迁移到模块:

1. 渐进式迁移
   - 保持头文件兼容
   - 逐步添加模块接口

2. 包装器模块
   // wrapper.cppm
   export module legacy_wrapper;
   
   module;
   #include "legacy.h"
   export module legacy_wrapper;
   
   export using legacy::SomeClass;
   export using legacy::someFunction;

3. 双重接口
   // 同时提供头文件和模块接口
   // mylib.h (传统)
   // mylib.cppm (模块)
```

### 6.3 常见问题

```cpp
// 问题 1: 循环依赖
// 解决: 使用前向声明或重构

// 问题 2: 宏
// 模块不导出宏
// 解决: 使用 constexpr 或 inline 变量

// 问题 3: 模板
// 模板必须在模块接口中定义
export module templates;

export template<typename T>
T max(T a, T b) {
    return a > b ? a : b;
}

// 问题 4: 内联函数
// 导出的函数自动 inline
export module mymodule;

export int getValue() {  // 隐式 inline
    return 42;
}
```

---

## 7. 总结

### 7.1 模块语法

| 语法 | 说明 |
|------|------|
| `export module name;` | 声明模块接口单元 |
| `module name;` | 声明模块实现单元 |
| `export` | 导出实体 |
| `import name;` | 导入模块 |
| `module name:partition;` | 模块分区 |
| `export import` | 重新导出 |

### 7.2 模块单元类型

| 类型 | 说明 |
|------|------|
| 主接口单元 | 模块的主要接口 |
| 接口分区 | 导出的子模块 |
| 实现分区 | 内部实现 |
| 实现单元 | 函数定义 |

### 7.3 下一篇预告

在下一篇文章中,我们将学习三路比较运算符。

---

> 作者: C++ 技术专栏  
> 系列: 现代 C++ (8/10)  
> 上一篇: [协程](./37-coroutines.md)  
> 下一篇: [三路比较运算符](./39-spaceship-operator.md)
