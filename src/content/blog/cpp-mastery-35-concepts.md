---
title: "Concepts 与约束"
description: "1. [Concepts 概述](#1-concepts-概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 35
---

> 本文是 C++ 从入门到精通系列的第三十五篇,将深入讲解 C++20 引入的 Concepts 和约束机制。

---

## 目录

1. [Concepts 概述](#1-concepts-概述)
2. [定义 Concepts](#2-定义-concepts)
3. [使用 Concepts](#3-使用-concepts)
4. [标准库 Concepts](#4-标准库-concepts)
5. [requires 表达式](#5-requires-表达式)
6. [高级应用](#6-高级应用)
7. [总结](#7-总结)

---

## 1. Concepts 概述

### 1.1 为什么需要 Concepts

```cpp
#include <iostream>
#include <vector>
#include <list>

// C++20 之前: 模板错误信息难以理解
template<typename T>
T add(T a, T b) {
    return a + b;
}

// 调用 add(std::vector<int>{}, std::vector<int>{})
// 会产生冗长的错误信息

// C++20: 使用 Concepts 提供清晰的约束
template<typename T>
concept Addable = requires(T a, T b) {
    { a + b } -> std::convertible_to<T>;
};

template<Addable T>
T addWithConcept(T a, T b) {
    return a + b;
}

int main() {
    std::cout << add(1, 2) << std::endl;
    std::cout << addWithConcept(1, 2) << std::endl;
    
    // addWithConcept(std::vector<int>{}, std::vector<int>{});
    // 错误信息: 约束 'Addable<std::vector<int>>' 不满足
    
    return 0;
}
```

### 1.2 Concepts 的优势

```
Concepts 的优势:

1. 更清晰的错误信息
2. 更好的文档化
3. 更强的类型安全
4. 支持重载
5. 编译时检查
```

---

## 2. 定义 Concepts

### 2.1 基本语法

```cpp
#include <iostream>
#include <concepts>
#include <type_traits>

// 基本 concept 定义
template<typename T>
concept Integral = std::is_integral_v<T>;

template<typename T>
concept FloatingPoint = std::is_floating_point_v<T>;

template<typename T>
concept Numeric = Integral<T> || FloatingPoint<T>;

// 使用 requires 子句
template<typename T>
concept Hashable = requires(T a) {
    { std::hash<T>{}(a) } -> std::convertible_to<std::size_t>;
};

// 复合 concept
template<typename T>
concept Comparable = requires(T a, T b) {
    { a == b } -> std::convertible_to<bool>;
    { a != b } -> std::convertible_to<bool>;
    { a < b } -> std::convertible_to<bool>;
    { a > b } -> std::convertible_to<bool>;
    { a <= b } -> std::convertible_to<bool>;
    { a >= b } -> std::convertible_to<bool>;
};

int main() {
    static_assert(Integral<int>);
    static_assert(FloatingPoint<double>);
    static_assert(Numeric<int>);
    static_assert(Numeric<double>);
    static_assert(!Numeric<std::string>);
    static_assert(Comparable<int>);
    
    std::cout << "All concepts satisfied!" << std::endl;
    
    return 0;
}
```

### 2.2 requires 表达式

```cpp
#include <iostream>
#include <concepts>
#include <string>

// 简单要求
template<typename T>
concept HasSize = requires(T t) {
    t.size();  // 必须有 size() 方法
};

// 类型要求
template<typename T>
concept HasValueType = requires {
    typename T::value_type;  // 必须有 value_type 类型
};

// 复合要求
template<typename T>
concept Container = requires(T t) {
    { t.size() } -> std::convertible_to<std::size_t>;
    { t.begin() } -> std::input_or_output_iterator;
    { t.end() } -> std::input_or_output_iterator;
    typename T::value_type;
    typename T::iterator;
};

// 嵌套要求
template<typename T>
concept Sortable = requires(T t) {
    requires std::random_access_iterator<typename T::iterator>;
    requires std::totally_ordered<typename T::value_type>;
};

int main() {
    static_assert(HasSize<std::string>);
    static_assert(HasSize<std::vector<int>>);
    static_assert(HasValueType<std::vector<int>>);
    static_assert(Container<std::vector<int>>);
    
    std::cout << "All concepts satisfied!" << std::endl;
    
    return 0;
}
```

---

## 3. 使用 Concepts

### 3.1 约束模板参数

```cpp
#include <iostream>
#include <concepts>

template<typename T>
concept Printable = requires(std::ostream& os, T t) {
    { os << t } -> std::same_as<std::ostream&>;
};

// 方式 1: 作为模板参数约束
template<Printable T>
void print1(const T& value) {
    std::cout << value << std::endl;
}

// 方式 2: 使用 requires 子句
template<typename T>
    requires Printable<T>
void print2(const T& value) {
    std::cout << value << std::endl;
}

// 方式 3: 尾置 requires 子句
template<typename T>
void print3(const T& value) requires Printable<T> {
    std::cout << value << std::endl;
}

// 方式 4: 简写语法 (auto)
void print4(Printable auto const& value) {
    std::cout << value << std::endl;
}

int main() {
    print1(42);
    print2("Hello");
    print3(3.14);
    print4('A');
    
    return 0;
}
```

### 3.2 约束重载

```cpp
#include <iostream>
#include <concepts>
#include <vector>

template<typename T>
concept Integral = std::is_integral_v<T>;

template<typename T>
concept FloatingPoint = std::is_floating_point_v<T>;

// 整数版本
void process(Integral auto value) {
    std::cout << "Integral: " << value << std::endl;
}

// 浮点版本
void process(FloatingPoint auto value) {
    std::cout << "Floating point: " << value << std::endl;
}

// 容器版本
template<typename T>
concept Container = requires(T t) {
    t.begin();
    t.end();
    t.size();
};

void process(Container auto const& container) {
    std::cout << "Container with " << container.size() << " elements" << std::endl;
}

int main() {
    process(42);
    process(3.14);
    process(std::vector<int>{1, 2, 3});
    
    return 0;
}
```

### 3.3 约束类模板

```cpp
#include <iostream>
#include <concepts>

template<typename T>
concept Numeric = std::is_arithmetic_v<T>;

// 约束类模板
template<Numeric T>
class Calculator {
public:
    Calculator(T value) : value(value) { }
    
    T add(T other) const { return value + other; }
    T multiply(T other) const { return value * other; }
    
private:
    T value;
};

// 部分特化与 concepts
template<typename T>
class Container {
public:
    void add(const T& item) {
        std::cout << "Generic add" << std::endl;
    }
};

template<std::integral T>
class Container<T> {
public:
    void add(T item) {
        std::cout << "Integral add: " << item << std::endl;
    }
};

int main() {
    Calculator<int> calc(10);
    std::cout << "add: " << calc.add(5) << std::endl;
    std::cout << "multiply: " << calc.multiply(3) << std::endl;
    
    // Calculator<std::string> strCalc("hello");  // 编译错误
    
    Container<int> intContainer;
    Container<std::string> strContainer;
    
    intContainer.add(42);
    strContainer.add("hello");
    
    return 0;
}
```

---

## 4. 标准库 Concepts

### 4.1 核心语言 Concepts

```cpp
#include <iostream>
#include <concepts>

void testCoreConcepts() {
    // same_as: 类型相同
    static_assert(std::same_as<int, int>);
    static_assert(!std::same_as<int, long>);
    
    // derived_from: 派生关系
    struct Base { };
    struct Derived : Base { };
    static_assert(std::derived_from<Derived, Base>);
    
    // convertible_to: 可转换
    static_assert(std::convertible_to<int, double>);
    static_assert(std::convertible_to<double, int>);
    
    // common_reference_with: 共同引用类型
    static_assert(std::common_reference_with<int&, double&>);
    
    // common_with: 共同类型
    static_assert(std::common_with<int, double>);
    
    std::cout << "Core concepts test passed!" << std::endl;
}

int main() {
    testCoreConcepts();
    return 0;
}
```

### 4.2 比较 Concepts

```cpp
#include <iostream>
#include <concepts>

void testComparisonConcepts() {
    // equality_comparable: 可比较相等
    static_assert(std::equality_comparable<int>);
    static_assert(std::equality_comparable<std::string>);
    
    // totally_ordered: 全序
    static_assert(std::totally_ordered<int>);
    static_assert(std::totally_ordered<double>);
    
    // three_way_comparable: 三路比较 (C++20)
    static_assert(std::three_way_comparable<int>);
    
    std::cout << "Comparison concepts test passed!" << std::endl;
}

// 使用比较 concepts
template<std::totally_ordered T>
T findMax(const std::vector<T>& vec) {
    if (vec.empty()) throw std::runtime_error("Empty vector");
    T max = vec[0];
    for (const auto& item : vec) {
        if (item > max) max = item;
    }
    return max;
}

int main() {
    testComparisonConcepts();
    
    std::vector<int> nums = {3, 1, 4, 1, 5, 9, 2, 6};
    std::cout << "Max: " << findMax(nums) << std::endl;
    
    return 0;
}
```

### 4.3 对象 Concepts

```cpp
#include <iostream>
#include <concepts>
#include <memory>

void testObjectConcepts() {
    // movable: 可移动
    static_assert(std::movable<std::string>);
    static_assert(std::movable<std::unique_ptr<int>>);
    
    // copyable: 可复制
    static_assert(std::copyable<std::string>);
    static_assert(!std::copyable<std::unique_ptr<int>>);
    
    // semiregular: 半正则 (默认构造 + 可复制)
    static_assert(std::semiregular<std::string>);
    
    // regular: 正则 (半正则 + 可比较相等)
    static_assert(std::regular<std::string>);
    
    std::cout << "Object concepts test passed!" << std::endl;
}

// 使用对象 concepts
template<std::copyable T>
class CopyableContainer {
public:
    void add(const T& item) {
        items.push_back(item);
    }
    
private:
    std::vector<T> items;
};

int main() {
    testObjectConcepts();
    
    CopyableContainer<std::string> container;
    container.add("hello");
    
    // CopyableContainer<std::unique_ptr<int>> ptrContainer;  // 编译错误
    
    return 0;
}
```

### 4.4 可调用 Concepts

```cpp
#include <iostream>
#include <concepts>
#include <functional>

void testCallableConcepts() {
    // invocable: 可调用
    auto lambda = [](int x) { return x * 2; };
    static_assert(std::invocable<decltype(lambda), int>);
    
    // regular_invocable: 正则可调用 (无副作用)
    static_assert(std::regular_invocable<decltype(lambda), int>);
    
    // predicate: 谓词 (返回 bool)
    auto pred = [](int x) { return x > 0; };
    static_assert(std::predicate<decltype(pred), int>);
    
    std::cout << "Callable concepts test passed!" << std::endl;
}

// 使用可调用 concepts
template<typename F, typename... Args>
    requires std::invocable<F, Args...>
auto invoke(F&& f, Args&&... args) {
    return std::forward<F>(f)(std::forward<Args>(args)...);
}

template<std::predicate<int> P>
int countIf(const std::vector<int>& vec, P pred) {
    int count = 0;
    for (int x : vec) {
        if (pred(x)) ++count;
    }
    return count;
}

int main() {
    testCallableConcepts();
    
    auto result = invoke([](int a, int b) { return a + b; }, 3, 4);
    std::cout << "invoke result: " << result << std::endl;
    
    std::vector<int> nums = {1, -2, 3, -4, 5};
    int positiveCount = countIf(nums, [](int x) { return x > 0; });
    std::cout << "Positive count: " << positiveCount << std::endl;
    
    return 0;
}
```

---

## 5. requires 表达式

### 5.1 简单要求

```cpp
#include <iostream>
#include <concepts>

template<typename T>
concept HasPrint = requires(T t) {
    t.print();  // 简单要求: 表达式必须有效
};

template<typename T>
concept HasToString = requires(T t) {
    t.toString();
    t.length();
};

class Printable {
public:
    void print() const {
        std::cout << "Printable::print()" << std::endl;
    }
};

class NotPrintable { };

int main() {
    static_assert(HasPrint<Printable>);
    static_assert(!HasPrint<NotPrintable>);
    
    Printable p;
    p.print();
    
    return 0;
}
```

### 5.2 类型要求

```cpp
#include <iostream>
#include <concepts>
#include <vector>

template<typename T>
concept HasIterator = requires {
    typename T::iterator;
    typename T::const_iterator;
    typename T::value_type;
};

template<typename T>
concept HasAllocator = requires {
    typename T::allocator_type;
};

template<typename T>
concept StdContainer = HasIterator<T> && requires(T t) {
    { t.begin() } -> std::same_as<typename T::iterator>;
    { t.end() } -> std::same_as<typename T::iterator>;
    { t.size() } -> std::convertible_to<std::size_t>;
};

int main() {
    static_assert(HasIterator<std::vector<int>>);
    static_assert(HasAllocator<std::vector<int>>);
    static_assert(StdContainer<std::vector<int>>);
    
    std::cout << "Type requirements test passed!" << std::endl;
    
    return 0;
}
```

### 5.3 复合要求

```cpp
#include <iostream>
#include <concepts>

template<typename T>
concept Arithmetic = requires(T a, T b) {
    // 复合要求: { 表达式 } noexcept -> 类型约束
    { a + b } -> std::same_as<T>;
    { a - b } -> std::same_as<T>;
    { a * b } -> std::same_as<T>;
    { a / b } -> std::same_as<T>;
    { -a } -> std::same_as<T>;
};

template<typename T>
concept Incrementable = requires(T t) {
    { ++t } -> std::same_as<T&>;
    { t++ } -> std::same_as<T>;
};

template<typename T>
concept Swappable = requires(T a, T b) {
    { std::swap(a, b) } noexcept;
};

int main() {
    static_assert(Arithmetic<int>);
    static_assert(Arithmetic<double>);
    static_assert(Incrementable<int>);
    static_assert(Swappable<int>);
    
    std::cout << "Compound requirements test passed!" << std::endl;
    
    return 0;
}
```

### 5.4 嵌套要求

```cpp
#include <iostream>
#include <concepts>

template<typename T>
concept SignedIntegral = requires {
    requires std::is_integral_v<T>;
    requires std::is_signed_v<T>;
};

template<typename T>
concept UnsignedIntegral = requires {
    requires std::is_integral_v<T>;
    requires std::is_unsigned_v<T>;
};

template<typename T>
concept SmallType = requires {
    requires sizeof(T) <= 4;
};

template<typename T>
concept SmallSignedIntegral = SignedIntegral<T> && SmallType<T>;

int main() {
    static_assert(SignedIntegral<int>);
    static_assert(!SignedIntegral<unsigned int>);
    static_assert(UnsignedIntegral<unsigned int>);
    static_assert(SmallSignedIntegral<int>);
    static_assert(!SmallSignedIntegral<long long>);
    
    std::cout << "Nested requirements test passed!" << std::endl;
    
    return 0;
}
```

---

## 6. 高级应用

### 6.1 Concept 组合

```cpp
#include <iostream>
#include <concepts>

// 基础 concepts
template<typename T>
concept Addable = requires(T a, T b) {
    { a + b } -> std::convertible_to<T>;
};

template<typename T>
concept Subtractable = requires(T a, T b) {
    { a - b } -> std::convertible_to<T>;
};

template<typename T>
concept Multipliable = requires(T a, T b) {
    { a * b } -> std::convertible_to<T>;
};

template<typename T>
concept Dividable = requires(T a, T b) {
    { a / b } -> std::convertible_to<T>;
};

// 组合 concept
template<typename T>
concept FullArithmetic = Addable<T> && Subtractable<T> && 
                         Multipliable<T> && Dividable<T>;

template<FullArithmetic T>
class MathOperations {
public:
    static T add(T a, T b) { return a + b; }
    static T subtract(T a, T b) { return a - b; }
    static T multiply(T a, T b) { return a * b; }
    static T divide(T a, T b) { return a / b; }
};

int main() {
    std::cout << "add: " << MathOperations<double>::add(3.0, 4.0) << std::endl;
    std::cout << "multiply: " << MathOperations<int>::multiply(3, 4) << std::endl;
    
    return 0;
}
```

### 6.2 Concept 继承

```cpp
#include <iostream>
#include <concepts>
#include <iterator>

// 迭代器 concepts 层次
template<typename T>
concept Iterator = requires(T it) {
    *it;
    ++it;
};

template<typename T>
concept ForwardIterator = Iterator<T> && requires(T it) {
    { it++ } -> std::same_as<T>;
};

template<typename T>
concept BidirectionalIterator = ForwardIterator<T> && requires(T it) {
    --it;
    { it-- } -> std::same_as<T>;
};

template<typename T>
concept RandomAccessIterator = BidirectionalIterator<T> && requires(T it, int n) {
    it + n;
    it - n;
    it[n];
    { it - it } -> std::convertible_to<std::ptrdiff_t>;
};

// 根据迭代器类型选择算法
template<Iterator I>
void advance(I& it, int n) {
    while (n > 0) { ++it; --n; }
}

template<RandomAccessIterator I>
void advance(I& it, int n) {
    it += n;
}

int main() {
    std::vector<int> vec = {1, 2, 3, 4, 5};
    auto it = vec.begin();
    advance(it, 3);
    std::cout << "*it: " << *it << std::endl;
    
    return 0;
}
```

---

## 7. 总结

### 7.1 Concepts 语法

| 语法 | 说明 |
|------|------|
| `template<C T>` | 约束模板参数 |
| `requires C<T>` | requires 子句 |
| `C auto` | 简写语法 |
| `requires { }` | requires 表达式 |

### 7.2 标准库 Concepts

| 类别 | Concepts |
|------|---------|
| 核心 | same_as, derived_from, convertible_to |
| 比较 | equality_comparable, totally_ordered |
| 对象 | movable, copyable, regular |
| 可调用 | invocable, predicate |
| 迭代器 | input_iterator, random_access_iterator |

### 7.3 下一篇预告

在下一篇文章中,我们将学习 Ranges 库。

---

> 作者: C++ 技术专栏  
> 系列: 现代 C++ (5/10)  
> 上一篇: [constexpr 与编译时计算](./34-constexpr.md)  
> 下一篇: [Ranges 库](./36-ranges.md)
