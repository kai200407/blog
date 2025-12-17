---
title: "变参模板"
description: "1. [变参模板基础](#1-变参模板基础)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 33
---

> 本文是 C++ 从入门到精通系列的第三十三篇,将深入讲解 C++11 引入的变参模板 (Variadic Templates)。

---

## 目录

1. [变参模板基础](#1-变参模板基础)
2. [参数包展开](#2-参数包展开)
3. [折叠表达式](#3-折叠表达式)
4. [实际应用](#4-实际应用)
5. [高级技巧](#5-高级技巧)
6. [总结](#6-总结)

---

## 1. 变参模板基础

### 1.1 基本语法

```cpp
#include <iostream>

// 变参函数模板
template<typename... Args>
void print(Args... args) {
    // Args 是模板参数包
    // args 是函数参数包
    std::cout << "Number of arguments: " << sizeof...(args) << std::endl;
}

// 变参类模板
template<typename... Types>
class Tuple;

int main() {
    print();                    // 0 个参数
    print(1);                   // 1 个参数
    print(1, 2.0, "hello");     // 3 个参数
    print(1, 2, 3, 4, 5);       // 5 个参数
    
    return 0;
}
```

### 1.2 sizeof... 运算符

```cpp
#include <iostream>

template<typename... Args>
void countArgs(Args... args) {
    std::cout << "Type count: " << sizeof...(Args) << std::endl;
    std::cout << "Value count: " << sizeof...(args) << std::endl;
}

template<typename... Types>
class TypeCounter {
public:
    static constexpr size_t count = sizeof...(Types);
};

int main() {
    countArgs(1, 2.0, "hello", 'a');
    
    std::cout << "TypeCounter<int, double, char>::count = " 
              << TypeCounter<int, double, char>::count << std::endl;
    
    return 0;
}
```

---

## 2. 参数包展开

### 2.1 递归展开

```cpp
#include <iostream>

// 基础情况: 无参数
void print() {
    std::cout << std::endl;
}

// 递归情况: 至少一个参数
template<typename T, typename... Args>
void print(T first, Args... rest) {
    std::cout << first;
    if constexpr (sizeof...(rest) > 0) {
        std::cout << ", ";
    }
    print(rest...);  // 递归调用
}

int main() {
    print(1, 2.5, "hello", 'a');
    
    return 0;
}
```

### 2.2 逗号表达式展开

```cpp
#include <iostream>
#include <initializer_list>

template<typename... Args>
void printAll(Args... args) {
    // 使用初始化列表展开
    (void)std::initializer_list<int>{
        (std::cout << args << " ", 0)...
    };
    std::cout << std::endl;
}

template<typename... Args>
auto sum(Args... args) {
    // C++17 之前的求和方式
    using T = std::common_type_t<Args...>;
    T result{};
    (void)std::initializer_list<int>{
        (result += args, 0)...
    };
    return result;
}

int main() {
    printAll(1, 2.5, "hello", 'a');
    
    std::cout << "Sum: " << sum(1, 2, 3, 4, 5) << std::endl;
    
    return 0;
}
```

### 2.3 包展开的位置

```cpp
#include <iostream>
#include <vector>
#include <tuple>

template<typename... Args>
void examples(Args... args) {
    // 1. 函数调用
    // func(args...);
    
    // 2. 初始化列表
    std::vector<int> v = {args...};
    
    // 3. 表达式
    // auto sum = (args + ...);  // C++17 折叠表达式
    
    // 4. 模板参数
    std::tuple<Args...> t(args...);
    
    // 5. 基类列表
    // class Derived : public Bases... { };
}

// 展开模式
template<typename... Args>
void patterns(Args... args) {
    // 简单展开
    // args...
    
    // 带表达式展开
    // (args * 2)...
    
    // 带函数调用展开
    // func(args)...
}

int main() {
    examples(1, 2, 3);
    
    return 0;
}
```

---

## 3. 折叠表达式

### 3.1 基本折叠 (C++17)

```cpp
#include <iostream>
#include <string>

// 一元右折叠: (args op ...)
template<typename... Args>
auto sumRight(Args... args) {
    return (args + ...);  // arg1 + (arg2 + (arg3 + arg4))
}

// 一元左折叠: (... op args)
template<typename... Args>
auto sumLeft(Args... args) {
    return (... + args);  // ((arg1 + arg2) + arg3) + arg4
}

// 二元右折叠: (args op ... op init)
template<typename... Args>
auto sumWithInit(Args... args) {
    return (args + ... + 0);  // 有初始值,空包也能工作
}

// 二元左折叠: (init op ... op args)
template<typename... Args>
auto product(Args... args) {
    return (1 * ... * args);
}

int main() {
    std::cout << "sumRight(1,2,3,4): " << sumRight(1, 2, 3, 4) << std::endl;
    std::cout << "sumLeft(1,2,3,4): " << sumLeft(1, 2, 3, 4) << std::endl;
    std::cout << "sumWithInit(): " << sumWithInit() << std::endl;  // 0
    std::cout << "product(1,2,3,4): " << product(1, 2, 3, 4) << std::endl;
    
    // 字符串连接
    auto concat = [](auto... args) {
        return (std::string{} + ... + args);
    };
    std::cout << concat("Hello", " ", "World", "!") << std::endl;
    
    return 0;
}
```

### 3.2 逻辑折叠

```cpp
#include <iostream>
#include <type_traits>

// 所有参数都为真
template<typename... Args>
bool allTrue(Args... args) {
    return (... && args);
}

// 任意参数为真
template<typename... Args>
bool anyTrue(Args... args) {
    return (... || args);
}

// 所有类型都是整数
template<typename... Types>
constexpr bool allIntegral() {
    return (... && std::is_integral_v<Types>);
}

int main() {
    std::cout << "allTrue(true, true, true): " << allTrue(true, true, true) << std::endl;
    std::cout << "allTrue(true, false, true): " << allTrue(true, false, true) << std::endl;
    std::cout << "anyTrue(false, false, true): " << anyTrue(false, false, true) << std::endl;
    
    std::cout << "allIntegral<int, long, char>(): " 
              << allIntegral<int, long, char>() << std::endl;
    std::cout << "allIntegral<int, double>(): " 
              << allIntegral<int, double>() << std::endl;
    
    return 0;
}
```

### 3.3 逗号折叠

```cpp
#include <iostream>
#include <vector>

// 打印所有参数
template<typename... Args>
void printAll(Args... args) {
    ((std::cout << args << " "), ...);
    std::cout << std::endl;
}

// 对每个参数调用函数
template<typename F, typename... Args>
void forEach(F f, Args... args) {
    (f(args), ...);
}

// 添加到容器
template<typename Container, typename... Args>
void addAll(Container& c, Args... args) {
    (c.push_back(args), ...);
}

int main() {
    printAll(1, 2.5, "hello", 'a');
    
    forEach([](auto x) { std::cout << x * 2 << " "; }, 1, 2, 3, 4);
    std::cout << std::endl;
    
    std::vector<int> v;
    addAll(v, 1, 2, 3, 4, 5);
    for (int x : v) std::cout << x << " ";
    std::cout << std::endl;
    
    return 0;
}
```

---

## 4. 实际应用

### 4.1 类型安全的 printf

```cpp
#include <iostream>
#include <sstream>
#include <string>

template<typename T>
void formatArg(std::ostream& os, const T& arg) {
    os << arg;
}

template<typename... Args>
std::string format(const std::string& fmt, Args... args) {
    std::ostringstream oss;
    size_t argIndex = 0;
    
    // 将参数存入数组
    auto formatters = std::initializer_list<std::function<void()>>{
        [&]() { formatArg(oss, args); }...
    };
    auto it = formatters.begin();
    
    for (size_t i = 0; i < fmt.size(); ++i) {
        if (fmt[i] == '{' && i + 1 < fmt.size() && fmt[i + 1] == '}') {
            if (it != formatters.end()) {
                (*it)();
                ++it;
            }
            ++i;
        } else {
            oss << fmt[i];
        }
    }
    
    return oss.str();
}

// 简化版本使用折叠表达式
template<typename... Args>
void print(Args... args) {
    ((std::cout << args), ...);
}

int main() {
    print("Hello, ", "World", "! ", 42, "\n");
    
    return 0;
}
```

### 4.2 make 函数

```cpp
#include <iostream>
#include <memory>
#include <tuple>

// make_unique 实现
template<typename T, typename... Args>
std::unique_ptr<T> my_make_unique(Args&&... args) {
    return std::unique_ptr<T>(new T(std::forward<Args>(args)...));
}

// make_tuple 实现
template<typename... Args>
auto my_make_tuple(Args&&... args) {
    return std::tuple<std::decay_t<Args>...>(std::forward<Args>(args)...);
}

class Widget {
public:
    Widget(int id, const std::string& name) : id(id), name(name) {
        std::cout << "Widget(" << id << ", " << name << ")" << std::endl;
    }
    
    void show() const {
        std::cout << "Widget: " << id << ", " << name << std::endl;
    }

private:
    int id;
    std::string name;
};

int main() {
    auto w = my_make_unique<Widget>(42, "MyWidget");
    w->show();
    
    auto t = my_make_tuple(1, 2.5, "hello");
    std::cout << "Tuple: " << std::get<0>(t) << ", " 
              << std::get<1>(t) << ", " 
              << std::get<2>(t) << std::endl;
    
    return 0;
}
```

### 4.3 元组操作

```cpp
#include <iostream>
#include <tuple>
#include <utility>

// 打印元组
template<typename Tuple, size_t... Is>
void printTupleImpl(const Tuple& t, std::index_sequence<Is...>) {
    ((std::cout << (Is == 0 ? "" : ", ") << std::get<Is>(t)), ...);
}

template<typename... Args>
void printTuple(const std::tuple<Args...>& t) {
    std::cout << "(";
    printTupleImpl(t, std::index_sequence_for<Args...>{});
    std::cout << ")" << std::endl;
}

// 对元组每个元素应用函数
template<typename Tuple, typename F, size_t... Is>
void forEachImpl(Tuple& t, F f, std::index_sequence<Is...>) {
    (f(std::get<Is>(t)), ...);
}

template<typename... Args, typename F>
void forEach(std::tuple<Args...>& t, F f) {
    forEachImpl(t, f, std::index_sequence_for<Args...>{});
}

int main() {
    auto t = std::make_tuple(1, 2.5, "hello", 'a');
    printTuple(t);
    
    auto t2 = std::make_tuple(1, 2, 3, 4, 5);
    forEach(t2, [](auto& x) { x *= 2; });
    printTuple(t2);
    
    return 0;
}
```

---

## 5. 高级技巧

### 5.1 类型列表操作

```cpp
#include <iostream>
#include <type_traits>

// 类型列表
template<typename... Types>
struct TypeList { };

// 获取第一个类型
template<typename List>
struct Front;

template<typename T, typename... Rest>
struct Front<TypeList<T, Rest...>> {
    using type = T;
};

// 获取列表大小
template<typename List>
struct Size;

template<typename... Types>
struct Size<TypeList<Types...>> {
    static constexpr size_t value = sizeof...(Types);
};

// 追加类型
template<typename List, typename T>
struct PushBack;

template<typename... Types, typename T>
struct PushBack<TypeList<Types...>, T> {
    using type = TypeList<Types..., T>;
};

// 连接两个列表
template<typename List1, typename List2>
struct Concat;

template<typename... Types1, typename... Types2>
struct Concat<TypeList<Types1...>, TypeList<Types2...>> {
    using type = TypeList<Types1..., Types2...>;
};

int main() {
    using List1 = TypeList<int, double, char>;
    using List2 = TypeList<float, long>;
    
    std::cout << "Size of List1: " << Size<List1>::value << std::endl;
    
    using Combined = Concat<List1, List2>::type;
    std::cout << "Size of Combined: " << Size<Combined>::value << std::endl;
    
    static_assert(std::is_same_v<Front<List1>::type, int>);
    
    return 0;
}
```

### 5.2 编译时索引

```cpp
#include <iostream>
#include <utility>

// 获取第 N 个参数
template<size_t N, typename T, typename... Rest>
struct NthType {
    using type = typename NthType<N - 1, Rest...>::type;
};

template<typename T, typename... Rest>
struct NthType<0, T, Rest...> {
    using type = T;
};

template<size_t N, typename... Args>
using NthType_t = typename NthType<N, Args...>::type;

// 获取第 N 个值
template<size_t N, typename T, typename... Rest>
auto getNth(T first, Rest... rest) {
    if constexpr (N == 0) {
        return first;
    } else {
        return getNth<N - 1>(rest...);
    }
}

int main() {
    static_assert(std::is_same_v<NthType_t<0, int, double, char>, int>);
    static_assert(std::is_same_v<NthType_t<1, int, double, char>, double>);
    static_assert(std::is_same_v<NthType_t<2, int, double, char>, char>);
    
    std::cout << "getNth<0>: " << getNth<0>(1, 2.5, "hello") << std::endl;
    std::cout << "getNth<1>: " << getNth<1>(1, 2.5, "hello") << std::endl;
    std::cout << "getNth<2>: " << getNth<2>(1, 2.5, "hello") << std::endl;
    
    return 0;
}
```

---

## 6. 总结

### 6.1 关键概念

| 概念 | 说明 |
|------|------|
| 参数包 | typename... Args |
| sizeof... | 获取参数包大小 |
| 包展开 | args... |
| 折叠表达式 | (args op ...) |
| 递归展开 | 基础情况 + 递归情况 |

### 6.2 折叠表达式语法

| 形式 | 语法 | 展开 |
|------|------|------|
| 一元右折叠 | (E op ...) | E1 op (E2 op (E3 op E4)) |
| 一元左折叠 | (... op E) | ((E1 op E2) op E3) op E4 |
| 二元右折叠 | (E op ... op I) | E1 op (E2 op (E3 op I)) |
| 二元左折叠 | (I op ... op E) | ((I op E1) op E2) op E3 |

### 6.3 下一篇预告

在下一篇文章中,我们将学习 constexpr 与编译时计算。

---

> 作者: C++ 技术专栏  
> 系列: 现代 C++ (3/10)  
> 上一篇: [右值引用与移动语义](./32-rvalue-move.md)  
> 下一篇: [constexpr 与编译时计算](./34-constexpr.md)
