---
title: "auto 与类型推导"
description: "1. [auto 基础](#1-auto-基础)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 31
---

> 本文是 C++ 从入门到精通系列的第三十一篇,将深入讲解 C++11 引入的 auto 关键字和类型推导机制。

---

## 目录

1. [auto 基础](#1-auto-基础)
2. [decltype](#2-decltype)
3. [auto 与引用](#3-auto-与引用)
4. [返回类型推导](#4-返回类型推导)
5. [结构化绑定](#5-结构化绑定)
6. [最佳实践](#6-最佳实践)
7. [总结](#7-总结)

---

## 1. auto 基础

### 1.1 基本用法

```cpp
#include <iostream>
#include <vector>
#include <map>

int main() {
    // 基本类型推导
    auto i = 42;           // int
    auto d = 3.14;         // double
    auto c = 'a';          // char
    auto s = "hello";      // const char*
    
    std::cout << "i: " << i << " (int)" << std::endl;
    std::cout << "d: " << d << " (double)" << std::endl;
    
    // 复杂类型
    std::vector<int> vec = {1, 2, 3, 4, 5};
    auto it = vec.begin();  // std::vector<int>::iterator
    
    std::map<std::string, int> map = {{"one", 1}, {"two", 2}};
    auto mit = map.find("one");  // std::map<std::string, int>::iterator
    
    // 简化迭代器
    for (auto it = vec.begin(); it != vec.end(); ++it) {
        std::cout << *it << " ";
    }
    std::cout << std::endl;
    
    // 范围 for 循环
    for (auto x : vec) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

### 1.2 auto 的推导规则

```cpp
#include <iostream>

int main() {
    int x = 10;
    const int cx = 20;
    const int& rx = x;
    
    // auto 会忽略顶层 const 和引用
    auto a = x;    // int
    auto b = cx;   // int (忽略 const)
    auto c = rx;   // int (忽略 const 和引用)
    
    // 保留 const
    const auto d = x;  // const int
    
    // 保留引用
    auto& e = x;       // int&
    auto& f = cx;      // const int&
    
    // const 引用
    const auto& g = x;  // const int&
    
    // 指针
    int* px = &x;
    auto h = px;        // int*
    auto* i = px;       // int*
    const auto* j = px; // const int*
    
    // 修改测试
    a = 100;  // OK
    // b = 100;  // OK (b 不是 const)
    e = 200;  // 修改 x
    
    std::cout << "x: " << x << std::endl;  // 200
    
    return 0;
}
```

### 1.3 auto 与初始化列表

```cpp
#include <iostream>
#include <initializer_list>

int main() {
    // C++11
    auto x1 = {1, 2, 3};  // std::initializer_list<int>
    // auto x2{1, 2, 3};  // C++11: std::initializer_list<int>
    
    // C++17
    auto x3{42};          // int (单个元素)
    auto x4 = {42};       // std::initializer_list<int>
    
    std::cout << "x3: " << x3 << std::endl;
    
    for (auto v : x1) {
        std::cout << v << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

---

## 2. decltype

### 2.1 基本用法

```cpp
#include <iostream>
#include <vector>

int main() {
    int x = 10;
    const int cx = 20;
    const int& rx = x;
    
    // decltype 保留完整类型信息
    decltype(x) a = x;    // int
    decltype(cx) b = cx;  // const int
    decltype(rx) c = x;   // const int&
    
    // 表达式
    decltype(x + 1) d = 0;  // int
    
    // 函数返回类型
    std::vector<int> vec;
    decltype(vec.size()) size = 0;  // std::vector<int>::size_type
    
    std::cout << "a: " << a << std::endl;
    
    return 0;
}
```

### 2.2 decltype 与表达式

```cpp
#include <iostream>

int main() {
    int x = 10;
    int* px = &x;
    
    // 变量名: 返回变量类型
    decltype(x) a;    // int
    
    // 表达式: 返回表达式类型
    decltype((x)) b = x;  // int& (加括号变成表达式)
    decltype(*px) c = x;  // int& (解引用是左值)
    
    // 修改测试
    b = 100;
    std::cout << "x: " << x << std::endl;  // 100
    
    c = 200;
    std::cout << "x: " << x << std::endl;  // 200
    
    return 0;
}
```

### 2.3 decltype(auto) (C++14)

```cpp
#include <iostream>

int x = 10;

int& getRef() { return x; }
int getValue() { return x; }

int main() {
    // auto 会丢失引用
    auto a = getRef();  // int (不是引用)
    
    // decltype(auto) 保留完整类型
    decltype(auto) b = getRef();  // int&
    decltype(auto) c = getValue();  // int
    
    b = 100;
    std::cout << "x: " << x << std::endl;  // 100
    
    // 用于返回类型
    auto lambda = []() -> decltype(auto) {
        return getRef();
    };
    
    lambda() = 200;
    std::cout << "x: " << x << std::endl;  // 200
    
    return 0;
}
```

---

## 3. auto 与引用

### 3.1 auto 引用

```cpp
#include <iostream>
#include <vector>

int main() {
    std::vector<int> vec = {1, 2, 3, 4, 5};
    
    // 值拷贝 (不修改原容器)
    for (auto x : vec) {
        x *= 2;  // 不影响 vec
    }
    
    std::cout << "After value copy: ";
    for (auto x : vec) std::cout << x << " ";
    std::cout << std::endl;  // 1 2 3 4 5
    
    // 引用 (修改原容器)
    for (auto& x : vec) {
        x *= 2;  // 修改 vec
    }
    
    std::cout << "After reference: ";
    for (auto x : vec) std::cout << x << " ";
    std::cout << std::endl;  // 2 4 6 8 10
    
    // const 引用 (只读,避免拷贝)
    for (const auto& x : vec) {
        std::cout << x << " ";
        // x *= 2;  // 错误: 不能修改
    }
    std::cout << std::endl;
    
    return 0;
}
```

### 3.2 转发引用

```cpp
#include <iostream>
#include <utility>

template<typename T>
void process(T&& arg) {
    // T&& 是转发引用 (universal reference)
    // 可以绑定左值或右值
}

int main() {
    int x = 10;
    
    // auto&& 也是转发引用
    auto&& a = x;      // int& (x 是左值)
    auto&& b = 42;     // int&& (42 是右值)
    auto&& c = std::move(x);  // int&&
    
    // 在范围 for 中使用
    std::vector<bool> flags = {true, false, true};
    
    // auto& 对 vector<bool> 不工作
    // for (auto& f : flags) { }  // 错误!
    
    // auto&& 可以工作
    for (auto&& f : flags) {
        f = !f;
    }
    
    return 0;
}
```

---

## 4. 返回类型推导

### 4.1 尾置返回类型

```cpp
#include <iostream>
#include <vector>

// 传统方式
template<typename T, typename U>
auto add_old(T a, U b) -> decltype(a + b) {
    return a + b;
}

// C++14: 自动推导
template<typename T, typename U>
auto add(T a, U b) {
    return a + b;
}

// 复杂返回类型
template<typename Container>
auto getElement(Container& c, size_t index) -> decltype(c[index]) {
    return c[index];
}

int main() {
    std::cout << "add(1, 2): " << add(1, 2) << std::endl;
    std::cout << "add(1.5, 2): " << add(1.5, 2) << std::endl;
    
    std::vector<int> vec = {1, 2, 3};
    getElement(vec, 0) = 100;
    std::cout << "vec[0]: " << vec[0] << std::endl;
    
    return 0;
}
```

### 4.2 auto 返回类型

```cpp
#include <iostream>

// C++14: auto 返回类型
auto multiply(int a, int b) {
    return a * b;
}

// 多个 return 语句必须返回相同类型
auto getValue(bool flag) {
    if (flag) {
        return 1;
    } else {
        return 2;
    }
    // return 1.0;  // 错误: 类型不一致
}

// decltype(auto) 保留引用
int global = 10;

auto getGlobal() {
    return global;  // 返回 int (拷贝)
}

decltype(auto) getGlobalRef() {
    return (global);  // 返回 int& (引用)
}

int main() {
    std::cout << "multiply(3, 4): " << multiply(3, 4) << std::endl;
    
    getGlobalRef() = 100;
    std::cout << "global: " << global << std::endl;  // 100
    
    return 0;
}
```

---

## 5. 结构化绑定

### 5.1 基本用法 (C++17)

```cpp
#include <iostream>
#include <tuple>
#include <map>
#include <array>

std::tuple<int, double, std::string> getData() {
    return {42, 3.14, "hello"};
}

int main() {
    // 元组解构
    auto [i, d, s] = getData();
    std::cout << i << ", " << d << ", " << s << std::endl;
    
    // pair 解构
    std::pair<int, std::string> p = {1, "one"};
    auto [num, str] = p;
    std::cout << num << ": " << str << std::endl;
    
    // 数组解构
    int arr[] = {1, 2, 3};
    auto [a, b, c] = arr;
    std::cout << a << ", " << b << ", " << c << std::endl;
    
    // std::array 解构
    std::array<int, 3> stdArr = {10, 20, 30};
    auto [x, y, z] = stdArr;
    std::cout << x << ", " << y << ", " << z << std::endl;
    
    // map 遍历
    std::map<std::string, int> map = {{"one", 1}, {"two", 2}, {"three", 3}};
    for (const auto& [key, value] : map) {
        std::cout << key << ": " << value << std::endl;
    }
    
    return 0;
}
```

### 5.2 结构体解构

```cpp
#include <iostream>

struct Point {
    int x;
    int y;
    int z;
};

Point getPoint() {
    return {1, 2, 3};
}

int main() {
    // 结构体解构
    auto [x, y, z] = getPoint();
    std::cout << "Point: (" << x << ", " << y << ", " << z << ")" << std::endl;
    
    // 引用解构
    Point p = {10, 20, 30};
    auto& [a, b, c] = p;
    a = 100;
    std::cout << "p.x: " << p.x << std::endl;  // 100
    
    // const 引用
    const auto& [i, j, k] = p;
    // i = 200;  // 错误: 不能修改
    
    return 0;
}
```

---

## 6. 最佳实践

### 6.1 何时使用 auto

```cpp
#include <iostream>
#include <vector>
#include <memory>

int main() {
    // 推荐使用 auto 的场景
    
    // 1. 迭代器
    std::vector<int> vec = {1, 2, 3};
    auto it = vec.begin();  // 比 std::vector<int>::iterator 简洁
    
    // 2. 复杂类型
    auto ptr = std::make_unique<std::vector<std::map<std::string, int>>>();
    
    // 3. lambda
    auto lambda = [](int x) { return x * 2; };
    
    // 4. 范围 for
    for (const auto& x : vec) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    // 不推荐使用 auto 的场景
    
    // 1. 类型不明显
    // auto x = foo();  // 不清楚 x 的类型
    
    // 2. 需要特定类型
    // auto d = 0;  // int,但可能想要 double
    double d = 0;   // 更清晰
    
    return 0;
}
```

### 6.2 auto 陷阱

```cpp
#include <iostream>
#include <vector>

int main() {
    // 陷阱 1: 代理类型
    std::vector<bool> flags = {true, false, true};
    auto flag = flags[0];  // 不是 bool,是代理类型!
    // bool flag = flags[0];  // 推荐
    
    // 陷阱 2: 意外的类型
    auto x = {1};  // std::initializer_list<int>,不是 int
    
    // 陷阱 3: 丢失引用
    std::vector<int> vec = {1, 2, 3};
    auto first = vec[0];  // int (拷贝)
    first = 100;  // 不影响 vec
    
    auto& firstRef = vec[0];  // int& (引用)
    firstRef = 100;  // 修改 vec
    
    std::cout << "vec[0]: " << vec[0] << std::endl;  // 100
    
    return 0;
}
```

---

## 7. 总结

### 7.1 类型推导对比

| 特性 | auto | decltype | decltype(auto) |
|------|------|----------|----------------|
| 忽略引用 | 是 | 否 | 否 |
| 忽略顶层 const | 是 | 否 | 否 |
| 需要初始化 | 是 | 否 | 是 |
| 表达式求值 | 是 | 否 | 是 |

### 7.2 最佳实践

```
1. 迭代器和复杂类型使用 auto
2. 需要引用时使用 auto&
3. 只读访问使用 const auto&
4. 完美转发使用 auto&&
5. 保留完整类型使用 decltype(auto)
6. 类型不明显时避免 auto
```

### 7.3 下一篇预告

在下一篇文章中,我们将学习右值引用与移动语义。

---

> 作者: C++ 技术专栏  
> 系列: 现代 C++ (1/10)  
> 上一篇: [string 与字符串处理](../part4-stl/30-string.md)  
> 下一篇: [右值引用与移动语义](./32-rvalue-move.md)
