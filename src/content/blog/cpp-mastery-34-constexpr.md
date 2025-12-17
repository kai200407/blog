---
title: "constexpr 与编译时计算"
description: "1. [constexpr 基础](#1-constexpr-基础)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 34
---

> 本文是 C++ 从入门到精通系列的第三十四篇,将深入讲解 constexpr 关键字和编译时计算技术。

---

## 目录

1. [constexpr 基础](#1-constexpr-基础)
2. [constexpr 函数](#2-constexpr-函数)
3. [constexpr 类](#3-constexpr-类)
4. [if constexpr](#4-if-constexpr)
5. [consteval 和 constinit](#5-consteval-和-constinit)
6. [实际应用](#6-实际应用)
7. [总结](#7-总结)

---

## 1. constexpr 基础

### 1.1 constexpr 变量

```cpp
#include <iostream>
#include <array>

int main() {
    // constexpr 变量: 编译时常量
    constexpr int size = 10;
    constexpr double pi = 3.14159;
    constexpr int arr[] = {1, 2, 3, 4, 5};
    
    // 可以用于需要编译时常量的地方
    std::array<int, size> array;
    int buffer[size];
    
    // const vs constexpr
    const int a = 10;        // 可能是编译时常量
    constexpr int b = 10;    // 一定是编译时常量
    
    int x = 5;
    const int c = x;         // 运行时常量
    // constexpr int d = x;  // 错误: x 不是编译时常量
    
    // constexpr 表达式
    constexpr int sum = 1 + 2 + 3;
    constexpr int product = size * 2;
    
    std::cout << "size: " << size << std::endl;
    std::cout << "sum: " << sum << std::endl;
    
    return 0;
}
```

### 1.2 编译时 vs 运行时

```cpp
#include <iostream>

constexpr int factorial(int n) {
    return n <= 1 ? 1 : n * factorial(n - 1);
}

int main() {
    // 编译时计算
    constexpr int f5 = factorial(5);  // 编译时计算
    static_assert(f5 == 120, "5! should be 120");
    
    // 运行时计算
    int n;
    std::cout << "Enter n: ";
    std::cin >> n;
    int fn = factorial(n);  // 运行时计算
    std::cout << n << "! = " << fn << std::endl;
    
    // 同一个函数可以在编译时或运行时使用
    
    return 0;
}
```

---

## 2. constexpr 函数

### 2.1 C++11 constexpr 函数

```cpp
#include <iostream>

// C++11: 函数体只能有一个 return 语句
constexpr int square_11(int x) {
    return x * x;
}

constexpr int abs_11(int x) {
    return x >= 0 ? x : -x;
}

// 递归
constexpr int fib_11(int n) {
    return n <= 1 ? n : fib_11(n - 1) + fib_11(n - 2);
}

int main() {
    constexpr int s = square_11(5);
    constexpr int a = abs_11(-10);
    constexpr int f = fib_11(10);
    
    std::cout << "square(5): " << s << std::endl;
    std::cout << "abs(-10): " << a << std::endl;
    std::cout << "fib(10): " << f << std::endl;
    
    return 0;
}
```

### 2.2 C++14 constexpr 函数

```cpp
#include <iostream>

// C++14: 允许更复杂的函数体
constexpr int factorial(int n) {
    int result = 1;
    for (int i = 2; i <= n; ++i) {
        result *= i;
    }
    return result;
}

constexpr int gcd(int a, int b) {
    while (b != 0) {
        int temp = b;
        b = a % b;
        a = temp;
    }
    return a;
}

constexpr bool isPrime(int n) {
    if (n <= 1) return false;
    if (n <= 3) return true;
    if (n % 2 == 0 || n % 3 == 0) return false;
    
    for (int i = 5; i * i <= n; i += 6) {
        if (n % i == 0 || n % (i + 2) == 0) {
            return false;
        }
    }
    return true;
}

int main() {
    constexpr int f10 = factorial(10);
    constexpr int g = gcd(48, 18);
    constexpr bool p17 = isPrime(17);
    constexpr bool p18 = isPrime(18);
    
    std::cout << "10! = " << f10 << std::endl;
    std::cout << "gcd(48, 18) = " << g << std::endl;
    std::cout << "isPrime(17) = " << p17 << std::endl;
    std::cout << "isPrime(18) = " << p18 << std::endl;
    
    return 0;
}
```

### 2.3 C++17/20 constexpr 增强

```cpp
#include <iostream>
#include <array>
#include <algorithm>

// C++17: constexpr lambda
constexpr auto square = [](int x) { return x * x; };

// C++20: constexpr std::vector, std::string
// constexpr std::vector<int> vec = {1, 2, 3};

// C++20: constexpr 算法
constexpr int sumArray() {
    std::array<int, 5> arr = {1, 2, 3, 4, 5};
    int sum = 0;
    for (int x : arr) {
        sum += x;
    }
    return sum;
}

// C++20: constexpr try-catch (有限制)
// C++20: constexpr 虚函数

int main() {
    constexpr int s = square(5);
    constexpr int sum = sumArray();
    
    std::cout << "square(5): " << s << std::endl;
    std::cout << "sumArray(): " << sum << std::endl;
    
    return 0;
}
```

---

## 3. constexpr 类

### 3.1 constexpr 构造函数

```cpp
#include <iostream>

class Point {
public:
    constexpr Point(double x = 0, double y = 0) : x(x), y(y) { }
    
    constexpr double getX() const { return x; }
    constexpr double getY() const { return y; }
    
    constexpr double distanceFromOrigin() const {
        return x * x + y * y;  // 简化: 返回距离的平方
    }
    
    constexpr Point operator+(const Point& other) const {
        return Point(x + other.x, y + other.y);
    }

private:
    double x, y;
};

int main() {
    constexpr Point p1(3, 4);
    constexpr Point p2(1, 2);
    constexpr Point p3 = p1 + p2;
    
    constexpr double dist = p1.distanceFromOrigin();
    
    static_assert(p3.getX() == 4, "x should be 4");
    static_assert(p3.getY() == 6, "y should be 6");
    static_assert(dist == 25, "distance^2 should be 25");
    
    std::cout << "p3: (" << p3.getX() << ", " << p3.getY() << ")" << std::endl;
    
    return 0;
}
```

### 3.2 constexpr 数组类

```cpp
#include <iostream>
#include <stdexcept>

template<typename T, size_t N>
class ConstexprArray {
public:
    constexpr ConstexprArray() : data{} { }
    
    constexpr ConstexprArray(std::initializer_list<T> init) : data{} {
        size_t i = 0;
        for (const auto& val : init) {
            if (i >= N) break;
            data[i++] = val;
        }
    }
    
    constexpr T& operator[](size_t index) {
        return data[index];
    }
    
    constexpr const T& operator[](size_t index) const {
        return data[index];
    }
    
    constexpr size_t size() const { return N; }
    
    constexpr T* begin() { return data; }
    constexpr T* end() { return data + N; }
    constexpr const T* begin() const { return data; }
    constexpr const T* end() const { return data + N; }

private:
    T data[N];
};

constexpr int sumArray(const ConstexprArray<int, 5>& arr) {
    int sum = 0;
    for (size_t i = 0; i < arr.size(); ++i) {
        sum += arr[i];
    }
    return sum;
}

int main() {
    constexpr ConstexprArray<int, 5> arr = {1, 2, 3, 4, 5};
    constexpr int sum = sumArray(arr);
    
    static_assert(sum == 15, "Sum should be 15");
    
    std::cout << "Sum: " << sum << std::endl;
    
    return 0;
}
```

---

## 4. if constexpr

### 4.1 基本用法 (C++17)

```cpp
#include <iostream>
#include <type_traits>
#include <string>

template<typename T>
auto getValue(T t) {
    if constexpr (std::is_integral_v<T>) {
        return t * 2;
    } else if constexpr (std::is_floating_point_v<T>) {
        return t * 1.5;
    } else if constexpr (std::is_same_v<T, std::string>) {
        return t + t;
    } else {
        return t;
    }
}

int main() {
    std::cout << "getValue(10): " << getValue(10) << std::endl;
    std::cout << "getValue(3.14): " << getValue(3.14) << std::endl;
    std::cout << "getValue(\"hello\"): " << getValue(std::string("hello")) << std::endl;
    
    return 0;
}
```

### 4.2 编译时分支

```cpp
#include <iostream>
#include <type_traits>

template<typename T>
void printType(const T& value) {
    std::cout << "Value: " << value << " - ";
    
    if constexpr (std::is_integral_v<T>) {
        std::cout << "Integral type";
        if constexpr (std::is_signed_v<T>) {
            std::cout << " (signed)";
        } else {
            std::cout << " (unsigned)";
        }
    } else if constexpr (std::is_floating_point_v<T>) {
        std::cout << "Floating point type";
    } else if constexpr (std::is_pointer_v<T>) {
        std::cout << "Pointer type";
    } else {
        std::cout << "Other type";
    }
    
    std::cout << std::endl;
}

int main() {
    printType(42);
    printType(42u);
    printType(3.14);
    printType("hello");
    
    int x = 10;
    printType(&x);
    
    return 0;
}
```

### 4.3 递归终止

```cpp
#include <iostream>

// 使用 if constexpr 替代模板特化
template<typename T, typename... Rest>
void print(T first, Rest... rest) {
    std::cout << first;
    
    if constexpr (sizeof...(rest) > 0) {
        std::cout << ", ";
        print(rest...);
    } else {
        std::cout << std::endl;
    }
}

// 编译时计算
template<size_t N>
constexpr auto fibonacci() {
    if constexpr (N <= 1) {
        return N;
    } else {
        return fibonacci<N - 1>() + fibonacci<N - 2>();
    }
}

int main() {
    print(1, 2.5, "hello", 'a');
    
    constexpr auto fib10 = fibonacci<10>();
    std::cout << "fibonacci<10>(): " << fib10 << std::endl;
    
    return 0;
}
```

---

## 5. consteval 和 constinit

### 5.1 consteval (C++20)

```cpp
#include <iostream>

// consteval: 必须在编译时求值
consteval int square(int x) {
    return x * x;
}

// constexpr: 可以在编译时或运行时求值
constexpr int cube(int x) {
    return x * x * x;
}

int main() {
    constexpr int s1 = square(5);  // OK: 编译时
    // int x = 5;
    // int s2 = square(x);  // 错误: x 不是编译时常量
    
    constexpr int c1 = cube(5);    // OK: 编译时
    int y = 5;
    int c2 = cube(y);              // OK: 运行时
    
    std::cout << "square(5): " << s1 << std::endl;
    std::cout << "cube(5): " << c1 << std::endl;
    std::cout << "cube(y): " << c2 << std::endl;
    
    return 0;
}
```

### 5.2 constinit (C++20)

```cpp
#include <iostream>

// constinit: 保证静态初始化
constinit int globalValue = 42;

// 避免静态初始化顺序问题
constinit const char* message = "Hello, World!";

class Config {
public:
    constexpr Config(int value) : value(value) { }
    int getValue() const { return value; }
private:
    int value;
};

constinit Config config(100);

int main() {
    std::cout << "globalValue: " << globalValue << std::endl;
    std::cout << "message: " << message << std::endl;
    std::cout << "config.getValue(): " << config.getValue() << std::endl;
    
    // constinit 变量可以修改 (如果不是 const)
    globalValue = 100;
    std::cout << "globalValue after modify: " << globalValue << std::endl;
    
    return 0;
}
```

---

## 6. 实际应用

### 6.1 编译时查找表

```cpp
#include <iostream>
#include <array>

// 编译时生成查找表
constexpr std::array<int, 256> generateSquareTable() {
    std::array<int, 256> table{};
    for (int i = 0; i < 256; ++i) {
        table[i] = i * i;
    }
    return table;
}

constexpr auto squareTable = generateSquareTable();

// 编译时生成 sin 查找表 (简化版)
constexpr double PI = 3.14159265358979323846;

constexpr double constexprSin(double x) {
    // 泰勒级数近似
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; ++i) {
        term *= -x * x / ((2 * i) * (2 * i + 1));
        result += term;
    }
    return result;
}

constexpr std::array<double, 360> generateSinTable() {
    std::array<double, 360> table{};
    for (int i = 0; i < 360; ++i) {
        table[i] = constexprSin(i * PI / 180.0);
    }
    return table;
}

constexpr auto sinTable = generateSinTable();

int main() {
    std::cout << "squareTable[16]: " << squareTable[16] << std::endl;
    std::cout << "sinTable[30]: " << sinTable[30] << std::endl;
    std::cout << "sinTable[90]: " << sinTable[90] << std::endl;
    
    return 0;
}
```

### 6.2 编译时字符串处理

```cpp
#include <iostream>
#include <array>

// 编译时字符串长度
constexpr size_t strLen(const char* str) {
    size_t len = 0;
    while (str[len] != '\0') {
        ++len;
    }
    return len;
}

// 编译时字符串比较
constexpr bool strEqual(const char* a, const char* b) {
    while (*a && *b) {
        if (*a != *b) return false;
        ++a;
        ++b;
    }
    return *a == *b;
}

// 编译时字符串哈希
constexpr size_t strHash(const char* str) {
    size_t hash = 5381;
    while (*str) {
        hash = ((hash << 5) + hash) + *str;
        ++str;
    }
    return hash;
}

int main() {
    constexpr size_t len = strLen("Hello, World!");
    constexpr bool eq = strEqual("hello", "hello");
    constexpr size_t hash = strHash("hello");
    
    static_assert(len == 13, "Length should be 13");
    static_assert(eq == true, "Strings should be equal");
    
    std::cout << "Length: " << len << std::endl;
    std::cout << "Equal: " << eq << std::endl;
    std::cout << "Hash: " << hash << std::endl;
    
    // 编译时 switch
    switch (strHash("hello")) {
        case strHash("hello"):
            std::cout << "Matched 'hello'" << std::endl;
            break;
        case strHash("world"):
            std::cout << "Matched 'world'" << std::endl;
            break;
    }
    
    return 0;
}
```

### 6.3 编译时类型检查

```cpp
#include <iostream>
#include <type_traits>

template<typename T>
constexpr bool isValidType() {
    return std::is_integral_v<T> || std::is_floating_point_v<T>;
}

template<typename T>
class NumericContainer {
    static_assert(isValidType<T>(), "T must be a numeric type");
    
public:
    constexpr NumericContainer(T value) : value(value) { }
    constexpr T get() const { return value; }
    
private:
    T value;
};

int main() {
    constexpr NumericContainer<int> c1(42);
    constexpr NumericContainer<double> c2(3.14);
    
    // NumericContainer<std::string> c3("hello");  // 编译错误
    
    std::cout << "c1: " << c1.get() << std::endl;
    std::cout << "c2: " << c2.get() << std::endl;
    
    return 0;
}
```

---

## 7. 总结

### 7.1 关键字对比

| 关键字 | 版本 | 说明 |
|--------|------|------|
| const | C++98 | 运行时常量 |
| constexpr | C++11 | 编译时或运行时 |
| consteval | C++20 | 必须编译时 |
| constinit | C++20 | 静态初始化 |

### 7.2 constexpr 演进

| 版本 | 新增功能 |
|------|---------|
| C++11 | 基本 constexpr 函数 |
| C++14 | 循环、局部变量 |
| C++17 | if constexpr, lambda |
| C++20 | 虚函数、try-catch、容器 |

### 7.3 下一篇预告

在下一篇文章中,我们将学习 Concepts 与约束。

---

> 作者: C++ 技术专栏  
> 系列: 现代 C++ (4/10)  
> 上一篇: [变参模板](./33-variadic-templates.md)  
> 下一篇: [Concepts 与约束](./35-concepts.md)
