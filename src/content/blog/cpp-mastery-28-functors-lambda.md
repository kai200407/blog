---
title: "函数对象与 Lambda"
description: "1. [函数对象概述](#1-函数对象概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 28
---

> 本文是 C++ 从入门到精通系列的第二十八篇,将深入讲解函数对象、Lambda 表达式以及 std::function。

---

## 目录

1. [函数对象概述](#1-函数对象概述)
2. [标准函数对象](#2-标准函数对象)
3. [Lambda 表达式](#3-lambda-表达式)
4. [std::function](#4-stdfunction)
5. [std::bind](#5-stdbind)
6. [高级应用](#6-高级应用)
7. [总结](#7-总结)

---

## 1. 函数对象概述

### 1.1 什么是函数对象

```cpp
#include <iostream>
#include <vector>
#include <algorithm>

// 函数对象 (Functor): 重载了 operator() 的类
class Square {
public:
    int operator()(int x) const {
        return x * x;
    }
};

class Adder {
public:
    Adder(int n) : value(n) { }
    
    int operator()(int x) const {
        return x + value;
    }
    
private:
    int value;
};

int main() {
    Square square;
    std::cout << "square(5): " << square(5) << std::endl;
    
    Adder add10(10);
    std::cout << "add10(5): " << add10(5) << std::endl;
    
    // 与算法配合使用
    std::vector<int> vec = {1, 2, 3, 4, 5};
    std::vector<int> result(vec.size());
    
    std::transform(vec.begin(), vec.end(), result.begin(), Square());
    
    std::cout << "Squared: ";
    for (int x : result) std::cout << x << " ";
    std::cout << std::endl;
    
    return 0;
}
```

### 1.2 函数对象的优势

```
函数对象 vs 函数指针:

1. 可以保存状态
2. 可以内联优化
3. 类型安全
4. 可以作为模板参数

函数对象 vs Lambda:

1. 可重用
2. 可以有复杂逻辑
3. 可以有多个 operator()
```

---

## 2. 标准函数对象

### 2.1 算术函数对象

```cpp
#include <iostream>
#include <functional>
#include <vector>
#include <algorithm>
#include <numeric>

int main() {
    std::vector<int> vec = {1, 2, 3, 4, 5};
    
    // plus: 加法
    int sum = std::accumulate(vec.begin(), vec.end(), 0, std::plus<int>());
    std::cout << "sum: " << sum << std::endl;
    
    // multiplies: 乘法
    int product = std::accumulate(vec.begin(), vec.end(), 1, std::multiplies<int>());
    std::cout << "product: " << product << std::endl;
    
    // minus: 减法
    std::cout << "minus: " << std::minus<int>()(10, 3) << std::endl;
    
    // divides: 除法
    std::cout << "divides: " << std::divides<int>()(10, 3) << std::endl;
    
    // modulus: 取模
    std::cout << "modulus: " << std::modulus<int>()(10, 3) << std::endl;
    
    // negate: 取反
    std::cout << "negate: " << std::negate<int>()(5) << std::endl;
    
    return 0;
}
```

### 2.2 比较函数对象

```cpp
#include <iostream>
#include <functional>
#include <vector>
#include <algorithm>

int main() {
    std::vector<int> vec = {3, 1, 4, 1, 5, 9, 2, 6};
    
    // less: 小于 (默认排序)
    std::sort(vec.begin(), vec.end(), std::less<int>());
    std::cout << "Ascending: ";
    for (int x : vec) std::cout << x << " ";
    std::cout << std::endl;
    
    // greater: 大于 (降序排序)
    std::sort(vec.begin(), vec.end(), std::greater<int>());
    std::cout << "Descending: ";
    for (int x : vec) std::cout << x << " ";
    std::cout << std::endl;
    
    // equal_to, not_equal_to
    std::cout << "equal_to: " << std::equal_to<int>()(5, 5) << std::endl;
    std::cout << "not_equal_to: " << std::not_equal_to<int>()(5, 3) << std::endl;
    
    // less_equal, greater_equal
    std::cout << "less_equal: " << std::less_equal<int>()(5, 5) << std::endl;
    std::cout << "greater_equal: " << std::greater_equal<int>()(5, 3) << std::endl;
    
    return 0;
}
```

### 2.3 逻辑函数对象

```cpp
#include <iostream>
#include <functional>
#include <vector>
#include <algorithm>

int main() {
    // logical_and
    std::cout << "logical_and: " << std::logical_and<bool>()(true, false) << std::endl;
    
    // logical_or
    std::cout << "logical_or: " << std::logical_or<bool>()(true, false) << std::endl;
    
    // logical_not
    std::cout << "logical_not: " << std::logical_not<bool>()(true) << std::endl;
    
    // 应用示例
    std::vector<bool> a = {true, true, false, false};
    std::vector<bool> b = {true, false, true, false};
    std::vector<bool> result(4);
    
    std::transform(a.begin(), a.end(), b.begin(), result.begin(), std::logical_and<bool>());
    
    std::cout << "a AND b: ";
    for (bool x : result) std::cout << x << " ";
    std::cout << std::endl;
    
    return 0;
}
```

---

## 3. Lambda 表达式

### 3.1 基本语法

```cpp
#include <iostream>
#include <vector>
#include <algorithm>

int main() {
    // 基本语法: [捕获列表](参数列表) -> 返回类型 { 函数体 }
    
    // 最简单的 lambda
    auto hello = []() { std::cout << "Hello, Lambda!" << std::endl; };
    hello();
    
    // 带参数
    auto add = [](int a, int b) { return a + b; };
    std::cout << "add(3, 4): " << add(3, 4) << std::endl;
    
    // 显式返回类型
    auto divide = [](int a, int b) -> double { return static_cast<double>(a) / b; };
    std::cout << "divide(5, 2): " << divide(5, 2) << std::endl;
    
    // 与算法配合
    std::vector<int> vec = {3, 1, 4, 1, 5, 9, 2, 6};
    std::sort(vec.begin(), vec.end(), [](int a, int b) { return a > b; });
    
    std::cout << "Sorted: ";
    for (int x : vec) std::cout << x << " ";
    std::cout << std::endl;
    
    return 0;
}
```

### 3.2 捕获列表

```cpp
#include <iostream>
#include <vector>
#include <algorithm>

int main() {
    int x = 10;
    int y = 20;
    
    // 值捕获
    auto byValue = [x, y]() { return x + y; };
    std::cout << "byValue: " << byValue() << std::endl;
    
    // 引用捕获
    auto byRef = [&x, &y]() { x++; y++; };
    byRef();
    std::cout << "After byRef: x=" << x << ", y=" << y << std::endl;
    
    // 隐式值捕获所有
    auto allByValue = [=]() { return x + y; };
    std::cout << "allByValue: " << allByValue() << std::endl;
    
    // 隐式引用捕获所有
    auto allByRef = [&]() { x *= 2; y *= 2; };
    allByRef();
    std::cout << "After allByRef: x=" << x << ", y=" << y << std::endl;
    
    // 混合捕获
    int z = 30;
    auto mixed = [=, &z]() { z = x + y; };  // x, y 值捕获,z 引用捕获
    mixed();
    std::cout << "z: " << z << std::endl;
    
    // 初始化捕获 (C++14)
    auto initCapture = [a = x * 2, b = std::move(y)]() { return a + b; };
    std::cout << "initCapture: " << initCapture() << std::endl;
    
    return 0;
}
```

### 3.3 mutable Lambda

```cpp
#include <iostream>

int main() {
    int x = 10;
    
    // 默认情况下,值捕获的变量是 const
    // auto lambda = [x]() { x++; };  // 错误!
    
    // 使用 mutable 允许修改
    auto mutableLambda = [x]() mutable {
        x++;
        return x;
    };
    
    std::cout << "mutableLambda(): " << mutableLambda() << std::endl;  // 11
    std::cout << "mutableLambda(): " << mutableLambda() << std::endl;  // 12
    std::cout << "x: " << x << std::endl;  // 10 (原值不变)
    
    return 0;
}
```

### 3.4 泛型 Lambda (C++14)

```cpp
#include <iostream>
#include <vector>
#include <string>

int main() {
    // 泛型 lambda
    auto print = [](const auto& x) { std::cout << x << std::endl; };
    
    print(42);
    print(3.14);
    print("Hello");
    print(std::string("World"));
    
    // 泛型 lambda 与算法
    auto add = [](auto a, auto b) { return a + b; };
    
    std::cout << "add(1, 2): " << add(1, 2) << std::endl;
    std::cout << "add(1.5, 2.5): " << add(1.5, 2.5) << std::endl;
    std::cout << "add(\"Hello\", \" World\"): " << add(std::string("Hello"), std::string(" World")) << std::endl;
    
    // 完美转发 (C++14)
    auto forward = [](auto&&... args) {
        return print(std::forward<decltype(args)>(args)...);
    };
    
    return 0;
}
```

### 3.5 Lambda 模板 (C++20)

```cpp
#include <iostream>
#include <vector>
#include <concepts>

int main() {
    // C++20 模板 lambda
    auto print = []<typename T>(const std::vector<T>& vec) {
        for (const auto& x : vec) {
            std::cout << x << " ";
        }
        std::cout << std::endl;
    };
    
    print(std::vector<int>{1, 2, 3});
    print(std::vector<std::string>{"a", "b", "c"});
    
    // 带约束的模板 lambda
    auto add = []<typename T>(T a, T b) requires std::integral<T> {
        return a + b;
    };
    
    std::cout << "add(1, 2): " << add(1, 2) << std::endl;
    // add(1.5, 2.5);  // 错误: 不满足约束
    
    return 0;
}
```

---

## 4. std::function

### 4.1 基本用法

```cpp
#include <iostream>
#include <functional>

int add(int a, int b) { return a + b; }

class Adder {
public:
    int operator()(int a, int b) const { return a + b; }
};

int main() {
    // std::function 可以存储任何可调用对象
    
    // 存储函数指针
    std::function<int(int, int)> f1 = add;
    std::cout << "f1(3, 4): " << f1(3, 4) << std::endl;
    
    // 存储函数对象
    std::function<int(int, int)> f2 = Adder();
    std::cout << "f2(3, 4): " << f2(3, 4) << std::endl;
    
    // 存储 lambda
    std::function<int(int, int)> f3 = [](int a, int b) { return a + b; };
    std::cout << "f3(3, 4): " << f3(3, 4) << std::endl;
    
    // 检查是否为空
    std::function<void()> f4;
    if (!f4) {
        std::cout << "f4 is empty" << std::endl;
    }
    
    f4 = []() { std::cout << "Hello" << std::endl; };
    if (f4) {
        f4();
    }
    
    return 0;
}
```

### 4.2 回调函数

```cpp
#include <iostream>
#include <functional>
#include <vector>

class Button {
public:
    using Callback = std::function<void()>;
    
    void setOnClick(Callback callback) {
        onClick = std::move(callback);
    }
    
    void click() {
        if (onClick) {
            onClick();
        }
    }
    
private:
    Callback onClick;
};

class EventEmitter {
public:
    using Handler = std::function<void(const std::string&)>;
    
    void on(const std::string& event, Handler handler) {
        handlers[event].push_back(std::move(handler));
    }
    
    void emit(const std::string& event, const std::string& data) {
        if (handlers.count(event)) {
            for (const auto& handler : handlers[event]) {
                handler(data);
            }
        }
    }
    
private:
    std::map<std::string, std::vector<Handler>> handlers;
};

int main() {
    Button button;
    button.setOnClick([]() {
        std::cout << "Button clicked!" << std::endl;
    });
    button.click();
    
    EventEmitter emitter;
    emitter.on("message", [](const std::string& msg) {
        std::cout << "Received: " << msg << std::endl;
    });
    emitter.emit("message", "Hello, World!");
    
    return 0;
}
```

---

## 5. std::bind

### 5.1 基本用法

```cpp
#include <iostream>
#include <functional>

int add(int a, int b, int c) {
    return a + b + c;
}

class Calculator {
public:
    int multiply(int a, int b) const {
        return a * b;
    }
};

int main() {
    using namespace std::placeholders;
    
    // 绑定参数
    auto add5 = std::bind(add, 5, _1, _2);  // 第一个参数固定为 5
    std::cout << "add5(3, 4): " << add5(3, 4) << std::endl;  // 5 + 3 + 4 = 12
    
    // 重排参数
    auto swapAdd = std::bind(add, _2, _1, _3);  // 交换前两个参数
    std::cout << "swapAdd(1, 2, 3): " << swapAdd(1, 2, 3) << std::endl;  // 2 + 1 + 3 = 6
    
    // 绑定成员函数
    Calculator calc;
    auto mul = std::bind(&Calculator::multiply, &calc, _1, _2);
    std::cout << "mul(3, 4): " << mul(3, 4) << std::endl;
    
    // 绑定成员函数的第一个参数
    auto mul5 = std::bind(&Calculator::multiply, &calc, 5, _1);
    std::cout << "mul5(4): " << mul5(4) << std::endl;
    
    return 0;
}
```

### 5.2 bind vs Lambda

```cpp
#include <iostream>
#include <functional>

int add(int a, int b) { return a + b; }

int main() {
    using namespace std::placeholders;
    
    // 使用 bind
    auto add5_bind = std::bind(add, 5, _1);
    
    // 使用 lambda (推荐)
    auto add5_lambda = [](int x) { return add(5, x); };
    
    std::cout << "bind: " << add5_bind(3) << std::endl;
    std::cout << "lambda: " << add5_lambda(3) << std::endl;
    
    // Lambda 更清晰,更容易优化
    // 现代 C++ 推荐使用 lambda 代替 bind
    
    return 0;
}
```

---

## 6. 高级应用

### 6.1 函数组合

```cpp
#include <iostream>
#include <functional>

template<typename F, typename G>
auto compose(F f, G g) {
    return [f, g](auto x) { return f(g(x)); };
}

int main() {
    auto square = [](int x) { return x * x; };
    auto addOne = [](int x) { return x + 1; };
    
    // 组合: (x + 1)^2
    auto composed = compose(square, addOne);
    std::cout << "composed(3): " << composed(3) << std::endl;  // (3+1)^2 = 16
    
    // 链式组合
    auto triple = [](int x) { return x * 3; };
    auto pipeline = compose(triple, compose(square, addOne));
    std::cout << "pipeline(2): " << pipeline(2) << std::endl;  // ((2+1)^2)*3 = 27
    
    return 0;
}
```

### 6.2 柯里化

```cpp
#include <iostream>
#include <functional>

// 柯里化: 将多参数函数转换为一系列单参数函数
auto curry(auto f) {
    return [f](auto a) {
        return [f, a](auto b) {
            return f(a, b);
        };
    };
}

int main() {
    auto add = [](int a, int b) { return a + b; };
    
    auto curriedAdd = curry(add);
    auto add5 = curriedAdd(5);
    
    std::cout << "add5(3): " << add5(3) << std::endl;  // 8
    std::cout << "curriedAdd(2)(3): " << curriedAdd(2)(3) << std::endl;  // 5
    
    return 0;
}
```

### 6.3 记忆化

```cpp
#include <iostream>
#include <functional>
#include <map>

template<typename F>
auto memoize(F f) {
    using ArgType = decltype(f(0));
    std::map<int, ArgType> cache;
    
    return [f, cache](int n) mutable -> ArgType {
        if (cache.count(n)) {
            return cache[n];
        }
        auto result = f(n);
        cache[n] = result;
        return result;
    };
}

int main() {
    // 斐波那契 (无记忆化)
    std::function<long long(int)> fib = [&fib](int n) -> long long {
        if (n <= 1) return n;
        return fib(n - 1) + fib(n - 2);
    };
    
    // 斐波那契 (有记忆化)
    std::map<int, long long> cache;
    std::function<long long(int)> fibMemo = [&fibMemo, &cache](int n) -> long long {
        if (n <= 1) return n;
        if (cache.count(n)) return cache[n];
        cache[n] = fibMemo(n - 1) + fibMemo(n - 2);
        return cache[n];
    };
    
    std::cout << "fib(30): " << fib(30) << std::endl;
    std::cout << "fibMemo(50): " << fibMemo(50) << std::endl;
    
    return 0;
}
```

---

## 7. 总结

### 7.1 可调用对象对比

| 类型 | 优点 | 缺点 |
|------|------|------|
| 函数指针 | 简单 | 无状态,无法内联 |
| 函数对象 | 可保存状态,可内联 | 需要定义类 |
| Lambda | 简洁,可内联 | 类型不可命名 |
| std::function | 类型擦除,通用 | 有开销 |

### 7.2 最佳实践

```
1. 优先使用 lambda
2. 需要类型擦除时使用 std::function
3. 避免使用 std::bind,用 lambda 代替
4. 注意捕获的生命周期
5. 大型 lambda 考虑提取为函数
```

### 7.3 下一篇预告

在下一篇文章中,我们将学习容器适配器。

---

> 作者: C++ 技术专栏  
> 系列: STL 标准模板库 (6/8)  
> 上一篇: [STL 算法](./27-algorithms.md)  
> 下一篇: [容器适配器](./29-container-adapters.md)
