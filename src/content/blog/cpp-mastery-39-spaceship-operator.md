---
title: "三路比较运算符"
description: "1. [三路比较概述](#1-三路比较概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 39
---

> 本文是 C++ 从入门到精通系列的第三十九篇,将深入讲解 C++20 引入的三路比较运算符 (Spaceship Operator)。

---

## 目录

1. [三路比较概述](#1-三路比较概述)
2. [比较类别](#2-比较类别)
3. [自动生成比较](#3-自动生成比较)
4. [自定义比较](#4-自定义比较)
5. [实际应用](#5-实际应用)
6. [总结](#6-总结)

---

## 1. 三路比较概述

### 1.1 什么是三路比较

```cpp
#include <iostream>
#include <compare>

int main() {
    int a = 5, b = 10;
    
    // 传统比较
    if (a < b) std::cout << "a < b" << std::endl;
    if (a == b) std::cout << "a == b" << std::endl;
    if (a > b) std::cout << "a > b" << std::endl;
    
    // 三路比较 (C++20)
    auto result = a <=> b;
    
    if (result < 0) std::cout << "a < b" << std::endl;
    if (result == 0) std::cout << "a == b" << std::endl;
    if (result > 0) std::cout << "a > b" << std::endl;
    
    return 0;
}
```

### 1.2 为什么需要三路比较

```
传统方式的问题:

1. 需要定义 6 个比较运算符
   ==, !=, <, >, <=, >=

2. 容易出错
   - 不一致的实现
   - 遗漏某些运算符

3. 代码冗余
   - 大量重复逻辑

三路比较的优势:

1. 只需定义一个运算符
2. 自动生成其他比较
3. 更清晰的语义
4. 更好的性能
```

---

## 2. 比较类别

### 2.1 三种比较类别

```cpp
#include <iostream>
#include <compare>

int main() {
    // 1. strong_ordering: 强序 (可替换性)
    // 如果 a == b,则 a 和 b 在任何情况下都可互换
    int x = 5, y = 5;
    std::strong_ordering so = x <=> y;
    std::cout << "strong_ordering: " << (so == 0) << std::endl;
    
    // 2. weak_ordering: 弱序 (等价但不相等)
    // 如果 a == b,a 和 b 等价但可能不完全相同
    // 例如: 大小写不敏感的字符串比较
    
    // 3. partial_ordering: 偏序 (可能无法比较)
    // 某些值可能无法比较
    double d1 = 1.0, d2 = std::nan("");
    std::partial_ordering po = d1 <=> d2;
    std::cout << "partial_ordering unordered: " 
              << (po == std::partial_ordering::unordered) << std::endl;
    
    return 0;
}
```

### 2.2 比较类别详解

```cpp
#include <iostream>
#include <compare>

void demonstrateOrdering() {
    // strong_ordering 的值
    std::strong_ordering so_less = std::strong_ordering::less;
    std::strong_ordering so_equal = std::strong_ordering::equal;
    std::strong_ordering so_equiv = std::strong_ordering::equivalent;
    std::strong_ordering so_greater = std::strong_ordering::greater;
    
    // equal 和 equivalent 在 strong_ordering 中相同
    std::cout << "equal == equivalent: " 
              << (so_equal == so_equiv) << std::endl;
    
    // weak_ordering 的值
    std::weak_ordering wo_less = std::weak_ordering::less;
    std::weak_ordering wo_equiv = std::weak_ordering::equivalent;
    std::weak_ordering wo_greater = std::weak_ordering::greater;
    // weak_ordering 没有 equal,只有 equivalent
    
    // partial_ordering 的值
    std::partial_ordering po_less = std::partial_ordering::less;
    std::partial_ordering po_equiv = std::partial_ordering::equivalent;
    std::partial_ordering po_greater = std::partial_ordering::greater;
    std::partial_ordering po_unord = std::partial_ordering::unordered;
    
    // 类别转换 (从强到弱)
    std::weak_ordering wo = so_less;  // OK
    std::partial_ordering po = wo;     // OK
    // std::strong_ordering so = wo;  // 错误: 不能从弱到强
}

int main() {
    demonstrateOrdering();
    return 0;
}
```

### 2.3 比较类别层次

```
比较类别层次:

strong_ordering (最强)
    ↓
weak_ordering
    ↓
partial_ordering (最弱)

转换规则:
- 可以从强到弱隐式转换
- 不能从弱到强转换

选择指南:
- 整数、指针: strong_ordering
- 大小写不敏感比较: weak_ordering
- 浮点数: partial_ordering
```

---

## 3. 自动生成比较

### 3.1 默认三路比较

```cpp
#include <iostream>
#include <compare>
#include <string>

struct Person {
    std::string name;
    int age;
    
    // 默认三路比较
    auto operator<=>(const Person&) const = default;
};

int main() {
    Person p1{"Alice", 30};
    Person p2{"Bob", 25};
    Person p3{"Alice", 30};
    
    // 自动生成所有比较运算符
    std::cout << "p1 < p2: " << (p1 < p2) << std::endl;
    std::cout << "p1 > p2: " << (p1 > p2) << std::endl;
    std::cout << "p1 == p3: " << (p1 == p3) << std::endl;
    std::cout << "p1 != p2: " << (p1 != p2) << std::endl;
    std::cout << "p1 <= p3: " << (p1 <= p3) << std::endl;
    std::cout << "p1 >= p3: " << (p1 >= p3) << std::endl;
    
    return 0;
}
```

### 3.2 成员比较顺序

```cpp
#include <iostream>
#include <compare>
#include <string>

struct Point {
    int x;
    int y;
    int z;
    
    // 按声明顺序比较: x, y, z
    auto operator<=>(const Point&) const = default;
};

int main() {
    Point p1{1, 2, 3};
    Point p2{1, 2, 4};
    Point p3{1, 3, 0};
    Point p4{2, 0, 0};
    
    // 先比较 x,相等则比较 y,相等则比较 z
    std::cout << "p1 < p2: " << (p1 < p2) << std::endl;  // true (z: 3 < 4)
    std::cout << "p1 < p3: " << (p1 < p3) << std::endl;  // true (y: 2 < 3)
    std::cout << "p1 < p4: " << (p1 < p4) << std::endl;  // true (x: 1 < 2)
    
    return 0;
}
```

### 3.3 自动生成 == 和 !=

```cpp
#include <iostream>
#include <compare>
#include <string>

struct Data {
    int id;
    std::string value;
    
    // 只定义 <=> 时,== 和 != 也会自动生成
    auto operator<=>(const Data&) const = default;
    
    // 或者单独定义 ==
    // bool operator==(const Data&) const = default;
};

struct OptimizedData {
    int id;
    std::string value;
    
    // 分别定义以优化 == 的性能
    auto operator<=>(const OptimizedData& other) const {
        // 先比较 id,再比较 value
        if (auto cmp = id <=> other.id; cmp != 0) return cmp;
        return value <=> other.value;
    }
    
    // 单独定义 == 可能更高效
    bool operator==(const OptimizedData& other) const {
        return id == other.id && value == other.value;
    }
};

int main() {
    Data d1{1, "hello"};
    Data d2{1, "hello"};
    Data d3{2, "world"};
    
    std::cout << "d1 == d2: " << (d1 == d2) << std::endl;
    std::cout << "d1 != d3: " << (d1 != d3) << std::endl;
    
    return 0;
}
```

---

## 4. 自定义比较

### 4.1 自定义三路比较

```cpp
#include <iostream>
#include <compare>
#include <string>
#include <cctype>

class CaseInsensitiveString {
public:
    CaseInsensitiveString(std::string s) : str(std::move(s)) { }
    
    // 自定义三路比较 (大小写不敏感)
    std::weak_ordering operator<=>(const CaseInsensitiveString& other) const {
        auto toLower = [](char c) { return std::tolower(c); };
        
        auto it1 = str.begin();
        auto it2 = other.str.begin();
        
        while (it1 != str.end() && it2 != other.str.end()) {
            char c1 = toLower(*it1);
            char c2 = toLower(*it2);
            
            if (c1 < c2) return std::weak_ordering::less;
            if (c1 > c2) return std::weak_ordering::greater;
            
            ++it1;
            ++it2;
        }
        
        if (str.size() < other.str.size()) return std::weak_ordering::less;
        if (str.size() > other.str.size()) return std::weak_ordering::greater;
        return std::weak_ordering::equivalent;
    }
    
    // 需要单独定义 ==
    bool operator==(const CaseInsensitiveString& other) const {
        return (*this <=> other) == 0;
    }
    
    const std::string& get() const { return str; }

private:
    std::string str;
};

int main() {
    CaseInsensitiveString s1("Hello");
    CaseInsensitiveString s2("HELLO");
    CaseInsensitiveString s3("World");
    
    std::cout << "s1 == s2: " << (s1 == s2) << std::endl;  // true
    std::cout << "s1 < s3: " << (s1 < s3) << std::endl;    // true
    
    return 0;
}
```

### 4.2 混合类型比较

```cpp
#include <iostream>
#include <compare>

class Fraction {
public:
    Fraction(int num, int den = 1) : numerator(num), denominator(den) { }
    
    // 与同类型比较
    std::strong_ordering operator<=>(const Fraction& other) const {
        // 交叉相乘避免除法
        long long left = static_cast<long long>(numerator) * other.denominator;
        long long right = static_cast<long long>(other.numerator) * denominator;
        return left <=> right;
    }
    
    bool operator==(const Fraction& other) const {
        return (*this <=> other) == 0;
    }
    
    // 与整数比较
    std::strong_ordering operator<=>(int value) const {
        return *this <=> Fraction(value);
    }
    
    bool operator==(int value) const {
        return *this == Fraction(value);
    }

private:
    int numerator;
    int denominator;
};

int main() {
    Fraction f1(1, 2);
    Fraction f2(2, 4);
    Fraction f3(3, 4);
    
    std::cout << "1/2 == 2/4: " << (f1 == f2) << std::endl;  // true
    std::cout << "1/2 < 3/4: " << (f1 < f3) << std::endl;    // true
    
    // 与整数比较
    Fraction f4(4, 2);
    std::cout << "4/2 == 2: " << (f4 == 2) << std::endl;     // true
    std::cout << "1/2 < 1: " << (f1 < 1) << std::endl;       // true
    
    return 0;
}
```

### 4.3 继承中的比较

```cpp
#include <iostream>
#include <compare>
#include <string>

class Base {
public:
    Base(int v) : value(v) { }
    
    auto operator<=>(const Base&) const = default;

protected:
    int value;
};

class Derived : public Base {
public:
    Derived(int v, std::string n) : Base(v), name(std::move(n)) { }
    
    // 需要显式定义以包含基类比较
    auto operator<=>(const Derived& other) const {
        // 先比较基类
        if (auto cmp = Base::operator<=>(other); cmp != 0) {
            return cmp;
        }
        // 再比较派生类成员
        return name <=> other.name;
    }
    
    bool operator==(const Derived& other) const {
        return (*this <=> other) == 0;
    }

private:
    std::string name;
};

int main() {
    Derived d1(1, "Alice");
    Derived d2(1, "Bob");
    Derived d3(2, "Alice");
    
    std::cout << "d1 < d2: " << (d1 < d2) << std::endl;  // true (name)
    std::cout << "d1 < d3: " << (d1 < d3) << std::endl;  // true (value)
    
    return 0;
}
```

---

## 5. 实际应用

### 5.1 容器排序

```cpp
#include <iostream>
#include <compare>
#include <vector>
#include <algorithm>
#include <string>

struct Product {
    std::string name;
    double price;
    int quantity;
    
    // 按价格排序,价格相同按名称排序
    auto operator<=>(const Product& other) const {
        if (auto cmp = price <=> other.price; cmp != 0) {
            return cmp;
        }
        return name <=> other.name;
    }
    
    bool operator==(const Product& other) const = default;
};

int main() {
    std::vector<Product> products = {
        {"Apple", 1.5, 100},
        {"Banana", 0.75, 150},
        {"Orange", 1.5, 80},
        {"Grape", 2.0, 50}
    };
    
    std::sort(products.begin(), products.end());
    
    std::cout << "Sorted products:" << std::endl;
    for (const auto& p : products) {
        std::cout << "  " << p.name << ": $" << p.price << std::endl;
    }
    
    return 0;
}
```

### 5.2 版本号比较

```cpp
#include <iostream>
#include <compare>
#include <sstream>
#include <vector>

class Version {
public:
    Version(int major, int minor, int patch)
        : major_(major), minor_(minor), patch_(patch) { }
    
    Version(const std::string& str) {
        char dot;
        std::istringstream iss(str);
        iss >> major_ >> dot >> minor_ >> dot >> patch_;
    }
    
    std::strong_ordering operator<=>(const Version& other) const {
        if (auto cmp = major_ <=> other.major_; cmp != 0) return cmp;
        if (auto cmp = minor_ <=> other.minor_; cmp != 0) return cmp;
        return patch_ <=> other.patch_;
    }
    
    bool operator==(const Version& other) const = default;
    
    friend std::ostream& operator<<(std::ostream& os, const Version& v) {
        return os << v.major_ << "." << v.minor_ << "." << v.patch_;
    }

private:
    int major_, minor_, patch_;
};

int main() {
    Version v1("1.2.3");
    Version v2("1.2.4");
    Version v3("1.3.0");
    Version v4("2.0.0");
    
    std::cout << v1 << " < " << v2 << ": " << (v1 < v2) << std::endl;
    std::cout << v2 << " < " << v3 << ": " << (v2 < v3) << std::endl;
    std::cout << v3 << " < " << v4 << ": " << (v3 < v4) << std::endl;
    
    std::vector<Version> versions = {v4, v1, v3, v2};
    std::sort(versions.begin(), versions.end());
    
    std::cout << "\nSorted versions:" << std::endl;
    for (const auto& v : versions) {
        std::cout << "  " << v << std::endl;
    }
    
    return 0;
}
```

### 5.3 复合键

```cpp
#include <iostream>
#include <compare>
#include <map>
#include <string>

struct CompositeKey {
    std::string category;
    int priority;
    std::string name;
    
    auto operator<=>(const CompositeKey&) const = default;
};

int main() {
    std::map<CompositeKey, std::string> items;
    
    items[{"A", 1, "Item1"}] = "First A priority 1";
    items[{"A", 2, "Item2"}] = "First A priority 2";
    items[{"B", 1, "Item3"}] = "First B priority 1";
    items[{"A", 1, "Item4"}] = "Second A priority 1";
    
    std::cout << "Items in order:" << std::endl;
    for (const auto& [key, value] : items) {
        std::cout << "  [" << key.category << ", " 
                  << key.priority << ", " 
                  << key.name << "]: " << value << std::endl;
    }
    
    return 0;
}
```

---

## 6. 总结

### 6.1 比较类别

| 类别 | 说明 | 示例 |
|------|------|------|
| strong_ordering | 强序,可替换 | 整数 |
| weak_ordering | 弱序,等价 | 大小写不敏感字符串 |
| partial_ordering | 偏序,可能无法比较 | 浮点数 |

### 6.2 运算符生成

| 定义 | 自动生成 |
|------|---------|
| `<=>` | `<`, `>`, `<=`, `>=` |
| `<=>` + `==` | 所有 6 个比较运算符 |
| `= default` | 按成员顺序比较 |

### 6.3 最佳实践

```
1. 优先使用 = default
2. 需要自定义时选择正确的比较类别
3. 考虑单独定义 == 以优化性能
4. 混合类型比较需要额外的运算符
5. 继承时注意包含基类比较
```

### 6.4 下一篇预告

在下一篇文章中,我们将学习其他 C++20/23 新特性。

---

> 作者: C++ 技术专栏  
> 系列: 现代 C++ (9/10)  
> 上一篇: [Modules](./38-modules.md)  
> 下一篇: [C++20/23 新特性](./40-cpp20-23-features.md)
