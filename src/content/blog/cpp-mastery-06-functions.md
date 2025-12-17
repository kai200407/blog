---
title: "函数"
description: "1. [函数基础](#1-函数基础)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 6
---

> 本文是 C++ 从入门到精通系列的第六篇,将全面讲解 C++ 的函数定义、参数传递、函数重载、默认参数以及内联函数等核心概念。

---

## 目录

1. [函数基础](#1-函数基础)
2. [参数传递](#2-参数传递)
3. [函数重载](#3-函数重载)
4. [默认参数](#4-默认参数)
5. [内联函数](#5-内联函数)
6. [递归函数](#6-递归函数)
7. [函数指针](#7-函数指针)
8. [总结](#8-总结)

---

## 1. 函数基础

### 1.1 函数定义

```cpp
#include <iostream>

// 函数声明 (原型)
int add(int a, int b);
void greet(const std::string& name);
double calculateArea(double radius);

// 函数定义
int add(int a, int b) {
    return a + b;
}

void greet(const std::string& name) {
    std::cout << "Hello, " << name << "!" << std::endl;
}

double calculateArea(double radius) {
    const double PI = 3.14159265358979;
    return PI * radius * radius;
}

int main() {
    int sum = add(3, 4);
    std::cout << "3 + 4 = " << sum << std::endl;
    
    greet("World");
    
    double area = calculateArea(5.0);
    std::cout << "Area = " << area << std::endl;
    
    return 0;
}
```

### 1.2 函数组成部分

```
函数结构:

返回类型 函数名(参数列表) {
    函数体
    return 返回值;
}

示例:
int add(int a, int b) {
    return a + b;
}

- 返回类型: int
- 函数名: add
- 参数列表: int a, int b
- 函数体: return a + b;
```

### 1.3 返回类型

```cpp
#include <iostream>
#include <string>
#include <tuple>
#include <optional>

// 返回基本类型
int getInt() {
    return 42;
}

// 返回 void
void printMessage() {
    std::cout << "Hello" << std::endl;
    // 可以省略 return; 或写 return;
}

// 返回引用
int& getElement(int arr[], int index) {
    return arr[index];
}

// 返回多个值 (C++11 tuple)
std::tuple<int, double, std::string> getMultiple() {
    return {42, 3.14, "hello"};
}

// 返回 optional (C++17)
std::optional<int> findValue(int arr[], int size, int target) {
    for (int i = 0; i < size; ++i) {
        if (arr[i] == target) {
            return i;
        }
    }
    return std::nullopt;
}

// 自动推导返回类型 (C++14)
auto multiply(int a, int b) {
    return a * b;
}

// 尾置返回类型 (C++11)
auto divide(double a, double b) -> double {
    return a / b;
}

int main() {
    // 使用 tuple
    auto [i, d, s] = getMultiple();  // C++17 结构化绑定
    std::cout << i << ", " << d << ", " << s << std::endl;
    
    // 使用 optional
    int arr[] = {1, 2, 3, 4, 5};
    if (auto result = findValue(arr, 5, 3)) {
        std::cout << "Found at index: " << *result << std::endl;
    }
    
    return 0;
}
```

---

## 2. 参数传递

### 2.1 值传递

```cpp
#include <iostream>

// 值传递: 复制参数
void increment(int x) {
    x++;  // 修改的是副本
    std::cout << "Inside function: x = " << x << std::endl;
}

int main() {
    int a = 10;
    increment(a);
    std::cout << "After function: a = " << a << std::endl;  // a 仍然是 10
    
    return 0;
}
```

### 2.2 引用传递

```cpp
#include <iostream>

// 引用传递: 直接操作原变量
void increment(int& x) {
    x++;  // 修改原变量
}

// const 引用: 只读,避免拷贝
void print(const std::string& str) {
    std::cout << str << std::endl;
    // str = "new";  // 错误: 不能修改 const 引用
}

// 交换两个值
void swap(int& a, int& b) {
    int temp = a;
    a = b;
    b = temp;
}

int main() {
    int x = 10;
    increment(x);
    std::cout << "x = " << x << std::endl;  // x = 11
    
    int a = 1, b = 2;
    swap(a, b);
    std::cout << "a = " << a << ", b = " << b << std::endl;  // a = 2, b = 1
    
    return 0;
}
```

### 2.3 指针传递

```cpp
#include <iostream>

// 指针传递
void increment(int* x) {
    if (x != nullptr) {
        (*x)++;
    }
}

// 交换两个值 (指针版)
void swap(int* a, int* b) {
    int temp = *a;
    *a = *b;
    *b = temp;
}

// 修改指针本身
void allocate(int*& ptr, int size) {
    ptr = new int[size];
}

int main() {
    int x = 10;
    increment(&x);
    std::cout << "x = " << x << std::endl;  // x = 11
    
    int a = 1, b = 2;
    swap(&a, &b);
    std::cout << "a = " << a << ", b = " << b << std::endl;
    
    int* arr = nullptr;
    allocate(arr, 10);
    delete[] arr;
    
    return 0;
}
```

### 2.4 数组参数

```cpp
#include <iostream>
#include <array>
#include <span>

// 数组参数 (退化为指针)
void printArray(int arr[], int size) {
    for (int i = 0; i < size; ++i) {
        std::cout << arr[i] << " ";
    }
    std::cout << std::endl;
}

// 指针形式 (等价)
void printArray2(int* arr, int size) {
    for (int i = 0; i < size; ++i) {
        std::cout << arr[i] << " ";
    }
    std::cout << std::endl;
}

// 引用到数组 (保留大小信息)
void printArray3(int (&arr)[5]) {
    for (int x : arr) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
}

// 模板版本 (任意大小)
template<size_t N>
void printArray4(int (&arr)[N]) {
    std::cout << "Size: " << N << std::endl;
    for (int x : arr) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
}

// std::array (推荐)
void printStdArray(const std::array<int, 5>& arr) {
    for (int x : arr) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
}

// std::span (C++20)
void printSpan(std::span<int> arr) {
    for (int x : arr) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
}

int main() {
    int arr[] = {1, 2, 3, 4, 5};
    
    printArray(arr, 5);
    printArray3(arr);
    printArray4(arr);
    
    std::array<int, 5> stdArr = {1, 2, 3, 4, 5};
    printStdArray(stdArr);
    
    printSpan(arr);
    
    return 0;
}
```

### 2.5 参数传递最佳实践

```cpp
#include <iostream>
#include <string>
#include <vector>

// 小型基本类型: 值传递
void process(int value) { }

// 大型对象只读: const 引用
void process(const std::string& str) { }
void process(const std::vector<int>& vec) { }

// 需要修改: 引用
void modify(std::string& str) { }

// 可能为空: 指针
void process(int* ptr) {
    if (ptr) { /* ... */ }
}

// 转移所有权: 右值引用 (C++11)
void takeOwnership(std::string&& str) {
    std::string local = std::move(str);
}

// 输出参数: 引用或指针
bool parse(const std::string& input, int& result) {
    // ...
    return true;
}

// 多个返回值: 使用 tuple 或 struct
struct Result {
    bool success;
    int value;
    std::string message;
};

Result compute() {
    return {true, 42, "OK"};
}
```

---

## 3. 函数重载

### 3.1 基本重载

```cpp
#include <iostream>
#include <string>

// 函数重载: 同名函数,不同参数
int add(int a, int b) {
    return a + b;
}

double add(double a, double b) {
    return a + b;
}

std::string add(const std::string& a, const std::string& b) {
    return a + b;
}

int add(int a, int b, int c) {
    return a + b + c;
}

int main() {
    std::cout << add(1, 2) << std::endl;           // 调用 int 版本
    std::cout << add(1.5, 2.5) << std::endl;       // 调用 double 版本
    std::cout << add("Hello, ", "World") << std::endl;  // 调用 string 版本
    std::cout << add(1, 2, 3) << std::endl;        // 调用三参数版本
    
    return 0;
}
```

### 3.2 重载解析

```cpp
#include <iostream>

void func(int x) {
    std::cout << "int: " << x << std::endl;
}

void func(double x) {
    std::cout << "double: " << x << std::endl;
}

void func(int x, int y) {
    std::cout << "int, int: " << x << ", " << y << std::endl;
}

void func(const char* s) {
    std::cout << "const char*: " << s << std::endl;
}

int main() {
    func(10);       // int
    func(3.14);     // double
    func(10, 20);   // int, int
    func("hello");  // const char*
    
    func(10.0f);    // float -> double (标准转换)
    func('A');      // char -> int (整数提升)
    
    // func(10L);   // 歧义: long -> int 或 long -> double?
    
    return 0;
}
```

### 3.3 重载与 const

```cpp
#include <iostream>

class MyClass {
public:
    // const 重载
    void print() {
        std::cout << "Non-const version" << std::endl;
    }
    
    void print() const {
        std::cout << "Const version" << std::endl;
    }
};

// 引用的 const 重载
void process(int& x) {
    std::cout << "Non-const ref" << std::endl;
}

void process(const int& x) {
    std::cout << "Const ref" << std::endl;
}

int main() {
    MyClass obj;
    const MyClass constObj;
    
    obj.print();       // Non-const version
    constObj.print();  // Const version
    
    int a = 10;
    const int b = 20;
    
    process(a);   // Non-const ref
    process(b);   // Const ref
    process(30);  // Const ref (临时对象)
    
    return 0;
}
```

### 3.4 不能重载的情况

```cpp
// 以下情况不能构成重载:

// 1. 仅返回类型不同
// int func();
// double func();  // 错误

// 2. 仅 const 修饰参数 (值传递)
// void func(int x);
// void func(const int x);  // 错误: 等价

// 3. typedef 别名
// typedef int Integer;
// void func(int x);
// void func(Integer x);  // 错误: 等价
```

---

## 4. 默认参数

### 4.1 基本用法

```cpp
#include <iostream>
#include <string>

// 默认参数
void greet(const std::string& name = "World") {
    std::cout << "Hello, " << name << "!" << std::endl;
}

int add(int a, int b = 0, int c = 0) {
    return a + b + c;
}

// 默认参数必须从右到左
// void func(int a = 1, int b);  // 错误

int main() {
    greet();           // Hello, World!
    greet("Alice");    // Hello, Alice!
    
    std::cout << add(1) << std::endl;        // 1
    std::cout << add(1, 2) << std::endl;     // 3
    std::cout << add(1, 2, 3) << std::endl;  // 6
    
    return 0;
}
```

### 4.2 声明与定义

```cpp
// header.h
#ifndef HEADER_H
#define HEADER_H

// 默认参数在声明中指定
void func(int a, int b = 10, int c = 20);

#endif

// source.cpp
#include "header.h"
#include <iostream>

// 定义中不重复默认参数
void func(int a, int b, int c) {
    std::cout << a << ", " << b << ", " << c << std::endl;
}

// 或者只在定义中指定 (如果没有单独的声明)
void anotherFunc(int x = 5) {
    std::cout << x << std::endl;
}
```

### 4.3 默认参数与重载

```cpp
#include <iostream>

// 注意: 默认参数可能导致歧义

void func(int a, int b = 10) {
    std::cout << "Two params: " << a << ", " << b << std::endl;
}

// void func(int a) {  // 错误: 与上面的函数歧义
//     std::cout << "One param: " << a << std::endl;
// }

int main() {
    func(1);      // 调用 func(int, int) with b = 10
    func(1, 2);   // 调用 func(int, int)
    
    return 0;
}
```

---

## 5. 内联函数

### 5.1 inline 关键字

```cpp
#include <iostream>

// 内联函数: 建议编译器在调用处展开
inline int square(int x) {
    return x * x;
}

inline int max(int a, int b) {
    return (a > b) ? a : b;
}

// 类内定义的成员函数默认是内联的
class Point {
public:
    int x, y;
    
    // 隐式内联
    int getX() const { return x; }
    int getY() const { return y; }
};

int main() {
    int result = square(5);  // 可能被展开为: int result = 5 * 5;
    std::cout << "square(5) = " << result << std::endl;
    
    return 0;
}
```

### 5.2 constexpr 函数 (C++11)

```cpp
#include <iostream>
#include <array>

// constexpr 函数: 可在编译时求值
constexpr int factorial(int n) {
    return (n <= 1) ? 1 : n * factorial(n - 1);
}

constexpr int fibonacci(int n) {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

// C++14 允许更复杂的 constexpr 函数
constexpr int sum(int n) {
    int result = 0;
    for (int i = 1; i <= n; ++i) {
        result += i;
    }
    return result;
}

int main() {
    // 编译时计算
    constexpr int fact5 = factorial(5);
    constexpr int fib10 = fibonacci(10);
    
    // 可用于数组大小
    std::array<int, factorial(5)> arr;
    
    std::cout << "5! = " << fact5 << std::endl;
    std::cout << "fib(10) = " << fib10 << std::endl;
    std::cout << "sum(100) = " << sum(100) << std::endl;
    
    // 运行时调用也可以
    int n = 6;
    int factN = factorial(n);  // 运行时计算
    
    return 0;
}
```

### 5.3 consteval (C++20)

```cpp
#include <iostream>

// consteval: 必须在编译时求值
consteval int compileTimeOnly(int x) {
    return x * x;
}

int main() {
    constexpr int a = compileTimeOnly(5);  // OK: 编译时
    
    // int x = 5;
    // int b = compileTimeOnly(x);  // 错误: x 不是编译时常量
    
    std::cout << "a = " << a << std::endl;
    
    return 0;
}
```

---

## 6. 递归函数

### 6.1 基本递归

```cpp
#include <iostream>

// 阶乘
int factorial(int n) {
    if (n <= 1) return 1;  // 基本情况
    return n * factorial(n - 1);  // 递归情况
}

// 斐波那契数列
int fibonacci(int n) {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

// 求和
int sum(int n) {
    if (n <= 0) return 0;
    return n + sum(n - 1);
}

int main() {
    std::cout << "5! = " << factorial(5) << std::endl;
    std::cout << "fib(10) = " << fibonacci(10) << std::endl;
    std::cout << "sum(10) = " << sum(10) << std::endl;
    
    return 0;
}
```

### 6.2 尾递归

```cpp
#include <iostream>

// 普通递归
int factorial(int n) {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}

// 尾递归优化
int factorialTail(int n, int acc = 1) {
    if (n <= 1) return acc;
    return factorialTail(n - 1, n * acc);  // 尾调用
}

// 尾递归求和
int sumTail(int n, int acc = 0) {
    if (n <= 0) return acc;
    return sumTail(n - 1, acc + n);
}

int main() {
    std::cout << "5! = " << factorialTail(5) << std::endl;
    std::cout << "sum(10) = " << sumTail(10) << std::endl;
    
    return 0;
}
```

### 6.3 递归与迭代

```cpp
#include <iostream>
#include <vector>

// 递归版本
int fibRecursive(int n) {
    if (n <= 1) return n;
    return fibRecursive(n - 1) + fibRecursive(n - 2);
}

// 迭代版本 (更高效)
int fibIterative(int n) {
    if (n <= 1) return n;
    
    int prev = 0, curr = 1;
    for (int i = 2; i <= n; ++i) {
        int next = prev + curr;
        prev = curr;
        curr = next;
    }
    return curr;
}

// 记忆化递归
int fibMemo(int n, std::vector<int>& memo) {
    if (n <= 1) return n;
    if (memo[n] != -1) return memo[n];
    
    memo[n] = fibMemo(n - 1, memo) + fibMemo(n - 2, memo);
    return memo[n];
}

int main() {
    int n = 40;
    
    // 递归版本很慢
    // std::cout << "fib(" << n << ") = " << fibRecursive(n) << std::endl;
    
    // 迭代版本快
    std::cout << "fib(" << n << ") = " << fibIterative(n) << std::endl;
    
    // 记忆化版本也快
    std::vector<int> memo(n + 1, -1);
    std::cout << "fib(" << n << ") = " << fibMemo(n, memo) << std::endl;
    
    return 0;
}
```

---

## 7. 函数指针

### 7.1 基本用法

```cpp
#include <iostream>

int add(int a, int b) { return a + b; }
int subtract(int a, int b) { return a - b; }
int multiply(int a, int b) { return a * b; }

int main() {
    // 函数指针声明
    int (*operation)(int, int);
    
    // 赋值
    operation = add;
    std::cout << "add(3, 4) = " << operation(3, 4) << std::endl;
    
    operation = subtract;
    std::cout << "subtract(3, 4) = " << operation(3, 4) << std::endl;
    
    operation = multiply;
    std::cout << "multiply(3, 4) = " << operation(3, 4) << std::endl;
    
    // 使用 typedef 简化
    typedef int (*BinaryOp)(int, int);
    BinaryOp op = add;
    
    // 使用 using (C++11, 推荐)
    using BinaryOp2 = int (*)(int, int);
    BinaryOp2 op2 = subtract;
    
    return 0;
}
```

### 7.2 函数指针作为参数

```cpp
#include <iostream>
#include <vector>
#include <algorithm>

// 比较函数
bool ascending(int a, int b) { return a < b; }
bool descending(int a, int b) { return a > b; }

// 接受函数指针的函数
void sortArray(int arr[], int size, bool (*compare)(int, int)) {
    for (int i = 0; i < size - 1; ++i) {
        for (int j = 0; j < size - i - 1; ++j) {
            if (compare(arr[j + 1], arr[j])) {
                std::swap(arr[j], arr[j + 1]);
            }
        }
    }
}

void printArray(int arr[], int size) {
    for (int i = 0; i < size; ++i) {
        std::cout << arr[i] << " ";
    }
    std::cout << std::endl;
}

int main() {
    int arr[] = {5, 2, 8, 1, 9, 3};
    int size = sizeof(arr) / sizeof(arr[0]);
    
    sortArray(arr, size, ascending);
    std::cout << "Ascending: ";
    printArray(arr, size);
    
    sortArray(arr, size, descending);
    std::cout << "Descending: ";
    printArray(arr, size);
    
    return 0;
}
```

### 7.3 std::function (C++11)

```cpp
#include <iostream>
#include <functional>

int add(int a, int b) { return a + b; }

class Calculator {
public:
    int multiply(int a, int b) { return a * b; }
};

int main() {
    // std::function 可以存储任何可调用对象
    std::function<int(int, int)> func;
    
    // 普通函数
    func = add;
    std::cout << "add(3, 4) = " << func(3, 4) << std::endl;
    
    // Lambda
    func = [](int a, int b) { return a - b; };
    std::cout << "lambda(3, 4) = " << func(3, 4) << std::endl;
    
    // 成员函数 (需要 std::bind)
    Calculator calc;
    func = std::bind(&Calculator::multiply, &calc, 
                     std::placeholders::_1, std::placeholders::_2);
    std::cout << "multiply(3, 4) = " << func(3, 4) << std::endl;
    
    // 函数对象
    struct Divider {
        int operator()(int a, int b) { return a / b; }
    };
    func = Divider();
    std::cout << "divide(12, 4) = " << func(12, 4) << std::endl;
    
    return 0;
}
```

---

## 8. 总结

### 8.1 函数特性一览

| 特性 | 说明 |
|------|------|
| 重载 | 同名函数,不同参数 |
| 默认参数 | 从右到左指定默认值 |
| 内联 | 建议编译器展开 |
| constexpr | 编译时求值 |
| 递归 | 函数调用自身 |
| 函数指针 | 指向函数的指针 |

### 8.2 参数传递选择

```
基本类型 (int, double, etc.): 值传递
大型对象只读: const 引用
需要修改: 引用
可能为空: 指针
转移所有权: 右值引用
```

### 8.3 下一篇预告

在下一篇文章中,我们将学习 C++ 的数组与指针基础。

---

## 参考资料

1. [C++ Functions](https://en.cppreference.com/w/cpp/language/functions)
2. [Function Overloading](https://en.cppreference.com/w/cpp/language/overload_resolution)

---

> 作者: C++ 技术专栏  
> 系列: C++ 基础入门 (6/8)  
> 上一篇: [控制流语句](./05-control-flow.md)  
> 下一篇: [数组与指针基础](./07-arrays-pointers.md)
