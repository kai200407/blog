---
title: "C++20/23 新特性"
description: "1. [C++20 特性回顾](#1-c20-特性回顾)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 40
---

> 本文是 C++ 从入门到精通系列的第四十篇,也是现代 C++ 部分的收官之作。我们将介绍 C++20 和 C++23 的其他重要新特性。

---

## 目录

1. [C++20 特性回顾](#1-c20-特性回顾)
2. [格式化库](#2-格式化库)
3. [日期时间库](#3-日期时间库)
4. [span](#4-span)
5. [其他 C++20 特性](#5-其他-c20-特性)
6. [C++23 预览](#6-c23-预览)
7. [总结](#7-总结)

---

## 1. C++20 特性回顾

### 1.1 四大特性

```
C++20 四大特性 (已在前文详细介绍):

1. Concepts (第 35 篇)
   - 模板约束
   - 更好的错误信息

2. Ranges (第 36 篇)
   - 惰性求值
   - 管道操作

3. Coroutines (第 37 篇)
   - 异步编程
   - 生成器

4. Modules (第 38 篇)
   - 更快的编译
   - 更好的封装
```

### 1.2 其他重要特性

```
本文将介绍:

- std::format: 类型安全的格式化
- Chrono 扩展: 日历和时区
- std::span: 非拥有视图
- constexpr 增强
- 指定初始化
- 更多...
```

---

## 2. 格式化库

### 2.1 std::format 基础

```cpp
#include <iostream>
#include <format>
#include <string>

int main() {
    // 基本格式化
    std::string s1 = std::format("Hello, {}!", "World");
    std::cout << s1 << std::endl;
    
    // 位置参数
    std::string s2 = std::format("{0} + {1} = {2}", 1, 2, 3);
    std::cout << s2 << std::endl;
    
    // 重复使用参数
    std::string s3 = std::format("{0} {0} {1}", "hello", "world");
    std::cout << s3 << std::endl;
    
    // 混合使用
    std::string s4 = std::format("{} {} {0}", "a", "b");
    std::cout << s4 << std::endl;  // a b a
    
    return 0;
}
```

### 2.2 格式说明符

```cpp
#include <iostream>
#include <format>
#include <numbers>

int main() {
    // 宽度和对齐
    std::cout << std::format("|{:10}|", "hello") << std::endl;   // 右对齐
    std::cout << std::format("|{:<10}|", "hello") << std::endl;  // 左对齐
    std::cout << std::format("|{:^10}|", "hello") << std::endl;  // 居中
    std::cout << std::format("|{:*^10}|", "hello") << std::endl; // 填充字符
    
    // 数字格式
    std::cout << std::format("{:d}", 42) << std::endl;      // 十进制
    std::cout << std::format("{:x}", 255) << std::endl;     // 十六进制
    std::cout << std::format("{:X}", 255) << std::endl;     // 大写十六进制
    std::cout << std::format("{:o}", 64) << std::endl;      // 八进制
    std::cout << std::format("{:b}", 10) << std::endl;      // 二进制
    std::cout << std::format("{:#x}", 255) << std::endl;    // 带前缀
    
    // 浮点数格式
    double pi = std::numbers::pi;
    std::cout << std::format("{}", pi) << std::endl;        // 默认
    std::cout << std::format("{:.2f}", pi) << std::endl;    // 2 位小数
    std::cout << std::format("{:.5e}", pi) << std::endl;    // 科学计数法
    std::cout << std::format("{:10.3f}", pi) << std::endl;  // 宽度和精度
    
    // 符号
    std::cout << std::format("{:+}", 42) << std::endl;      // 总是显示符号
    std::cout << std::format("{: }", 42) << std::endl;      // 正数前加空格
    
    return 0;
}
```

### 2.3 自定义类型格式化

```cpp
#include <iostream>
#include <format>
#include <string>

struct Point {
    double x, y;
};

// 自定义格式化器
template<>
struct std::formatter<Point> {
    // 解析格式说明符
    constexpr auto parse(std::format_parse_context& ctx) {
        return ctx.begin();
    }
    
    // 格式化
    auto format(const Point& p, std::format_context& ctx) const {
        return std::format_to(ctx.out(), "({}, {})", p.x, p.y);
    }
};

int main() {
    Point p{3.14, 2.71};
    std::cout << std::format("Point: {}", p) << std::endl;
    
    return 0;
}
```

### 2.4 std::print (C++23)

```cpp
#include <print>  // C++23

int main() {
    // C++23 的 print 函数
    std::print("Hello, {}!\n", "World");
    std::println("Value: {}", 42);  // 自动换行
    
    return 0;
}
```

---

## 3. 日期时间库

### 3.1 日历类型

```cpp
#include <iostream>
#include <chrono>

int main() {
    using namespace std::chrono;
    
    // 年月日
    year y{2024};
    month m{12};
    day d{25};
    
    // 组合
    year_month_day ymd{y, m, d};
    std::cout << "Date: " << ymd << std::endl;
    
    // 简写
    auto christmas = 2024y/December/25d;
    std::cout << "Christmas: " << christmas << std::endl;
    
    // 星期
    auto weekday = year_month_day{2024y/December/25d};
    weekday wd{sys_days{weekday}};
    std::cout << "Weekday: " << wd << std::endl;
    
    // 月末
    auto lastDay = 2024y/February/last;
    std::cout << "Last day of Feb 2024: " << lastDay << std::endl;
    
    // 第 n 个星期几
    auto thanksgiving = 2024y/November/Thursday[4];  // 11 月第 4 个周四
    std::cout << "Thanksgiving: " << thanksgiving << std::endl;
    
    return 0;
}
```

### 3.2 时区支持

```cpp
#include <iostream>
#include <chrono>

int main() {
    using namespace std::chrono;
    
    // 当前时间
    auto now = system_clock::now();
    
    // 转换为本地时间
    auto local = zoned_time{current_zone(), now};
    std::cout << "Local: " << local << std::endl;
    
    // 特定时区
    auto tokyo = zoned_time{"Asia/Tokyo", now};
    auto london = zoned_time{"Europe/London", now};
    auto newyork = zoned_time{"America/New_York", now};
    
    std::cout << "Tokyo: " << tokyo << std::endl;
    std::cout << "London: " << london << std::endl;
    std::cout << "New York: " << newyork << std::endl;
    
    // 时区转换
    auto utc_time = sys_days{2024y/July/4d} + 12h;
    auto la_time = zoned_time{"America/Los_Angeles", utc_time};
    std::cout << "July 4th noon UTC in LA: " << la_time << std::endl;
    
    return 0;
}
```

### 3.3 时间计算

```cpp
#include <iostream>
#include <chrono>

int main() {
    using namespace std::chrono;
    
    // 日期计算
    auto today = floor<days>(system_clock::now());
    auto tomorrow = today + days{1};
    auto nextWeek = today + weeks{1};
    
    // 月份计算
    year_month_day ymd{2024y/January/31d};
    auto nextMonth = ymd + months{1};  // 注意: 可能无效
    std::cout << "Next month: " << nextMonth << std::endl;
    
    // 年份计算
    auto nextYear = ymd + years{1};
    std::cout << "Next year: " << nextYear << std::endl;
    
    // 日期差
    auto date1 = 2024y/January/1d;
    auto date2 = 2024y/December/31d;
    auto diff = sys_days{date2} - sys_days{date1};
    std::cout << "Days in 2024: " << diff.count() << std::endl;
    
    // 检查有效性
    auto invalid = 2024y/February/30d;
    std::cout << "Feb 30 valid: " << invalid.ok() << std::endl;
    
    return 0;
}
```

---

## 4. span

### 4.1 基本用法

```cpp
#include <iostream>
#include <span>
#include <vector>
#include <array>

void printSpan(std::span<const int> s) {
    std::cout << "Size: " << s.size() << ", Elements: ";
    for (int x : s) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
}

int main() {
    // 从 C 数组创建
    int arr[] = {1, 2, 3, 4, 5};
    std::span<int> s1(arr);
    printSpan(s1);
    
    // 从 vector 创建
    std::vector<int> vec = {10, 20, 30, 40, 50};
    std::span<int> s2(vec);
    printSpan(s2);
    
    // 从 array 创建
    std::array<int, 5> stdArr = {100, 200, 300, 400, 500};
    std::span<int> s3(stdArr);
    printSpan(s3);
    
    // 部分视图
    std::span<int> s4(vec.data() + 1, 3);
    printSpan(s4);  // 20 30 40
    
    return 0;
}
```

### 4.2 固定大小 span

```cpp
#include <iostream>
#include <span>
#include <array>

// 固定大小的 span
void processFixed(std::span<int, 3> s) {
    std::cout << "Fixed span: ";
    for (int x : s) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
}

// 动态大小的 span
void processDynamic(std::span<int> s) {
    std::cout << "Dynamic span: ";
    for (int x : s) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
}

int main() {
    int arr[] = {1, 2, 3, 4, 5};
    
    // 固定大小
    std::span<int, 3> fixed(arr, 3);
    processFixed(fixed);
    
    // 动态大小
    std::span<int> dynamic(arr);
    processDynamic(dynamic);
    
    // 子 span
    auto first3 = dynamic.first(3);
    auto last3 = dynamic.last(3);
    auto sub = dynamic.subspan(1, 3);
    
    processDynamic(first3);  // 1 2 3
    processDynamic(last3);   // 3 4 5
    processDynamic(sub);     // 2 3 4
    
    return 0;
}
```

### 4.3 span 操作

```cpp
#include <iostream>
#include <span>
#include <algorithm>

int main() {
    int arr[] = {5, 2, 8, 1, 9, 3, 7, 4, 6};
    std::span<int> s(arr);
    
    // 访问元素
    std::cout << "First: " << s.front() << std::endl;
    std::cout << "Last: " << s.back() << std::endl;
    std::cout << "s[3]: " << s[3] << std::endl;
    
    // 大小信息
    std::cout << "Size: " << s.size() << std::endl;
    std::cout << "Size in bytes: " << s.size_bytes() << std::endl;
    std::cout << "Empty: " << s.empty() << std::endl;
    
    // 修改元素
    s[0] = 100;
    std::cout << "After modify: " << arr[0] << std::endl;
    
    // 与算法配合
    std::sort(s.begin(), s.end());
    std::cout << "Sorted: ";
    for (int x : s) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

---

## 5. 其他 C++20 特性

### 5.1 指定初始化

```cpp
#include <iostream>

struct Point {
    int x = 0;
    int y = 0;
    int z = 0;
};

struct Config {
    bool debug = false;
    int maxConnections = 100;
    std::string host = "localhost";
    int port = 8080;
};

int main() {
    // 指定初始化
    Point p1{.x = 1, .y = 2, .z = 3};
    Point p2{.x = 10, .z = 30};  // y 使用默认值
    
    std::cout << "p1: (" << p1.x << ", " << p1.y << ", " << p1.z << ")" << std::endl;
    std::cout << "p2: (" << p2.x << ", " << p2.y << ", " << p2.z << ")" << std::endl;
    
    // 配置对象
    Config config{
        .debug = true,
        .maxConnections = 50,
        .port = 9000
    };
    
    std::cout << "Config: debug=" << config.debug 
              << ", port=" << config.port << std::endl;
    
    return 0;
}
```

### 5.2 constexpr 增强

```cpp
#include <iostream>
#include <vector>
#include <string>
#include <algorithm>

// C++20: constexpr vector 和 string
constexpr int sumVector() {
    std::vector<int> v = {1, 2, 3, 4, 5};
    int sum = 0;
    for (int x : v) {
        sum += x;
    }
    return sum;
}

// C++20: constexpr 算法
constexpr int findMax() {
    int arr[] = {3, 1, 4, 1, 5, 9, 2, 6};
    return *std::max_element(std::begin(arr), std::end(arr));
}

// C++20: constexpr new/delete
constexpr int* createArray() {
    int* arr = new int[5]{1, 2, 3, 4, 5};
    int sum = 0;
    for (int i = 0; i < 5; ++i) {
        sum += arr[i];
    }
    delete[] arr;
    return nullptr;  // 必须在 constexpr 上下文中释放
}

int main() {
    constexpr int sum = sumVector();
    constexpr int max = findMax();
    
    std::cout << "Sum: " << sum << std::endl;
    std::cout << "Max: " << max << std::endl;
    
    static_assert(sum == 15);
    static_assert(max == 9);
    
    return 0;
}
```

### 5.3 source_location

```cpp
#include <iostream>
#include <source_location>

void log(const std::string& message,
         const std::source_location& loc = std::source_location::current()) {
    std::cout << loc.file_name() << ":" << loc.line() 
              << " [" << loc.function_name() << "] " 
              << message << std::endl;
}

void someFunction() {
    log("Inside someFunction");
}

int main() {
    log("Starting program");
    someFunction();
    log("Ending program");
    
    return 0;
}
```

### 5.4 likely 和 unlikely

```cpp
#include <iostream>

int processValue(int value) {
    if (value > 0) [[likely]] {
        // 大多数情况下会执行这里
        return value * 2;
    } else [[unlikely]] {
        // 很少执行这里
        return 0;
    }
}

int main() {
    for (int i = -2; i <= 10; ++i) {
        std::cout << "process(" << i << ") = " << processValue(i) << std::endl;
    }
    
    return 0;
}
```

### 5.5 std::bit_cast

```cpp
#include <iostream>
#include <bit>
#include <cstdint>

int main() {
    // 类型双关 (type punning)
    float f = 3.14f;
    
    // C++20 之前: 未定义行为或使用 memcpy
    // uint32_t bits = *reinterpret_cast<uint32_t*>(&f);  // UB
    
    // C++20: 安全的位转换
    uint32_t bits = std::bit_cast<uint32_t>(f);
    std::cout << "Float bits: 0x" << std::hex << bits << std::endl;
    
    // 反向转换
    float f2 = std::bit_cast<float>(bits);
    std::cout << "Back to float: " << std::dec << f2 << std::endl;
    
    return 0;
}
```

---

## 6. C++23 预览

### 6.1 std::expected

```cpp
#include <expected>  // C++23
#include <string>
#include <iostream>

std::expected<int, std::string> divide(int a, int b) {
    if (b == 0) {
        return std::unexpected("Division by zero");
    }
    return a / b;
}

int main() {
    auto result1 = divide(10, 2);
    if (result1) {
        std::cout << "Result: " << *result1 << std::endl;
    }
    
    auto result2 = divide(10, 0);
    if (!result2) {
        std::cout << "Error: " << result2.error() << std::endl;
    }
    
    // 使用 value_or
    std::cout << "Value or default: " << result2.value_or(-1) << std::endl;
    
    return 0;
}
```

### 6.2 std::mdspan

```cpp
#include <mdspan>  // C++23
#include <iostream>
#include <vector>

int main() {
    std::vector<int> data = {
        1, 2, 3,
        4, 5, 6,
        7, 8, 9
    };
    
    // 创建 2D 视图
    std::mdspan<int, std::extents<size_t, 3, 3>> matrix(data.data());
    
    // 访问元素
    std::cout << "matrix[1][2] = " << matrix[1, 2] << std::endl;  // 6
    
    // 遍历
    for (size_t i = 0; i < matrix.extent(0); ++i) {
        for (size_t j = 0; j < matrix.extent(1); ++j) {
            std::cout << matrix[i, j] << " ";
        }
        std::cout << std::endl;
    }
    
    return 0;
}
```

### 6.3 其他 C++23 特性

```cpp
// std::stacktrace: 堆栈跟踪
#include <stacktrace>

void printStacktrace() {
    std::cout << std::stacktrace::current() << std::endl;
}

// std::flat_map/flat_set: 扁平化关联容器
#include <flat_map>

std::flat_map<std::string, int> fm = {
    {"one", 1},
    {"two", 2}
};

// 范围增强
auto result = vec 
    | std::views::chunk(3)      // 分块
    | std::views::slide(2)      // 滑动窗口
    | std::views::zip(other);   // 压缩

// if consteval
constexpr int getValue() {
    if consteval {
        return 42;  // 编译时
    } else {
        return computeAtRuntime();  // 运行时
    }
}

// 多维下标运算符
matrix[i, j, k] = value;

// 显式 this 参数
struct Widget {
    void process(this Widget& self) {
        // ...
    }
};
```

---

## 7. 总结

### 7.1 C++20 特性总览

| 特性 | 说明 |
|------|------|
| Concepts | 模板约束 |
| Ranges | 惰性求值管道 |
| Coroutines | 协程 |
| Modules | 模块系统 |
| std::format | 格式化 |
| Chrono 扩展 | 日历时区 |
| std::span | 非拥有视图 |
| 三路比较 | <=> 运算符 |
| constexpr 增强 | 更多编译时计算 |

### 7.2 C++23 特性总览

| 特性 | 说明 |
|------|------|
| std::expected | 错误处理 |
| std::mdspan | 多维视图 |
| std::print | 格式化输出 |
| std::flat_map | 扁平化容器 |
| 范围增强 | 更多视图 |
| if consteval | 编译时分支 |

### 7.3 Part 5 完成

恭喜你完成了现代 C++ 部分的全部 10 篇文章!

**实战项目建议**: 现代 C++ 应用
- 使用 Ranges 实现数据处理管道
- 使用协程实现异步 I/O
- 使用 Concepts 设计类型安全的库

### 7.4 下一篇预告

在下一篇文章中,我们将进入并发编程部分,学习线程基础。

---

> 作者: C++ 技术专栏  
> 系列: 现代 C++ (10/10)  
> 上一篇: [三路比较运算符](./39-spaceship-operator.md)  
> 下一篇: [线程基础](../part6-concurrency/41-thread-basics.md)
