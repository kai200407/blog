---
title: "Ranges 库"
description: "1. [Ranges 概述](#1-ranges-概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 36
---

> 本文是 C++ 从入门到精通系列的第三十六篇,将深入讲解 C++20 引入的 Ranges 库。

---

## 目录

1. [Ranges 概述](#1-ranges-概述)
2. [Range 概念](#2-range-概念)
3. [Views](#3-views)
4. [Range 算法](#4-range-算法)
5. [Range 工厂](#5-range-工厂)
6. [实际应用](#6-实际应用)
7. [总结](#7-总结)

---

## 1. Ranges 概述

### 1.1 什么是 Ranges

```cpp
#include <iostream>
#include <vector>
#include <ranges>
#include <algorithm>

int main() {
    std::vector<int> vec = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    
    // 传统 STL 方式
    std::vector<int> result1;
    std::copy_if(vec.begin(), vec.end(), std::back_inserter(result1),
                 [](int x) { return x % 2 == 0; });
    
    // Ranges 方式
    auto result2 = vec | std::views::filter([](int x) { return x % 2 == 0; });
    
    std::cout << "Traditional: ";
    for (int x : result1) std::cout << x << " ";
    std::cout << std::endl;
    
    std::cout << "Ranges: ";
    for (int x : result2) std::cout << x << " ";
    std::cout << std::endl;
    
    return 0;
}
```

### 1.2 Ranges 的优势

```
Ranges 的优势:

1. 更简洁的语法
2. 惰性求值
3. 可组合的操作
4. 更好的类型安全
5. 避免迭代器对
```

---

## 2. Range 概念

### 2.1 基本概念

```cpp
#include <iostream>
#include <vector>
#include <list>
#include <ranges>

void testRangeConcepts() {
    // range: 可以迭代的东西
    static_assert(std::ranges::range<std::vector<int>>);
    static_assert(std::ranges::range<std::list<int>>);
    static_assert(std::ranges::range<int[10]>);
    
    // sized_range: 有 size() 的 range
    static_assert(std::ranges::sized_range<std::vector<int>>);
    
    // input_range: 可以读取的 range
    static_assert(std::ranges::input_range<std::vector<int>>);
    
    // forward_range: 可以多次遍历
    static_assert(std::ranges::forward_range<std::vector<int>>);
    
    // bidirectional_range: 可以双向遍历
    static_assert(std::ranges::bidirectional_range<std::list<int>>);
    
    // random_access_range: 可以随机访问
    static_assert(std::ranges::random_access_range<std::vector<int>>);
    
    // contiguous_range: 连续内存
    static_assert(std::ranges::contiguous_range<std::vector<int>>);
    
    std::cout << "All range concepts satisfied!" << std::endl;
}

int main() {
    testRangeConcepts();
    return 0;
}
```

### 2.2 Range 访问函数

```cpp
#include <iostream>
#include <vector>
#include <ranges>

int main() {
    std::vector<int> vec = {1, 2, 3, 4, 5};
    
    // std::ranges 版本的访问函数
    auto b = std::ranges::begin(vec);
    auto e = std::ranges::end(vec);
    auto s = std::ranges::size(vec);
    auto d = std::ranges::data(vec);
    
    std::cout << "Size: " << s << std::endl;
    std::cout << "First: " << *b << std::endl;
    std::cout << "Data ptr: " << d << std::endl;
    
    // 也适用于 C 数组
    int arr[] = {10, 20, 30};
    std::cout << "Array size: " << std::ranges::size(arr) << std::endl;
    
    // 反向迭代
    for (auto it = std::ranges::rbegin(vec); it != std::ranges::rend(vec); ++it) {
        std::cout << *it << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

---

## 3. Views

### 3.1 基本 Views

```cpp
#include <iostream>
#include <vector>
#include <ranges>

int main() {
    std::vector<int> vec = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    
    // filter: 过滤
    auto evens = vec | std::views::filter([](int x) { return x % 2 == 0; });
    std::cout << "Evens: ";
    for (int x : evens) std::cout << x << " ";
    std::cout << std::endl;
    
    // transform: 变换
    auto squares = vec | std::views::transform([](int x) { return x * x; });
    std::cout << "Squares: ";
    for (int x : squares) std::cout << x << " ";
    std::cout << std::endl;
    
    // take: 取前 n 个
    auto first5 = vec | std::views::take(5);
    std::cout << "First 5: ";
    for (int x : first5) std::cout << x << " ";
    std::cout << std::endl;
    
    // drop: 跳过前 n 个
    auto after3 = vec | std::views::drop(3);
    std::cout << "After 3: ";
    for (int x : after3) std::cout << x << " ";
    std::cout << std::endl;
    
    // reverse: 反转
    auto reversed = vec | std::views::reverse;
    std::cout << "Reversed: ";
    for (int x : reversed) std::cout << x << " ";
    std::cout << std::endl;
    
    return 0;
}
```

### 3.2 组合 Views

```cpp
#include <iostream>
#include <vector>
#include <ranges>

int main() {
    std::vector<int> vec = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    
    // 管道组合
    auto result = vec 
        | std::views::filter([](int x) { return x % 2 == 0; })
        | std::views::transform([](int x) { return x * x; })
        | std::views::take(3);
    
    std::cout << "Result: ";
    for (int x : result) std::cout << x << " ";
    std::cout << std::endl;  // 4 16 36
    
    // 等价的函数调用方式
    auto result2 = std::views::take(
        std::views::transform(
            std::views::filter(vec, [](int x) { return x % 2 == 0; }),
            [](int x) { return x * x; }
        ),
        3
    );
    
    std::cout << "Result2: ";
    for (int x : result2) std::cout << x << " ";
    std::cout << std::endl;
    
    return 0;
}
```

### 3.3 更多 Views

```cpp
#include <iostream>
#include <vector>
#include <string>
#include <ranges>

int main() {
    // take_while: 取满足条件的前缀
    std::vector<int> vec = {1, 2, 3, 10, 4, 5};
    auto prefix = vec | std::views::take_while([](int x) { return x < 5; });
    std::cout << "take_while: ";
    for (int x : prefix) std::cout << x << " ";
    std::cout << std::endl;  // 1 2 3
    
    // drop_while: 跳过满足条件的前缀
    auto suffix = vec | std::views::drop_while([](int x) { return x < 5; });
    std::cout << "drop_while: ";
    for (int x : suffix) std::cout << x << " ";
    std::cout << std::endl;  // 10 4 5
    
    // elements: 获取 tuple 的特定元素
    std::vector<std::pair<int, std::string>> pairs = {
        {1, "one"}, {2, "two"}, {3, "three"}
    };
    auto keys = pairs | std::views::keys;
    auto values = pairs | std::views::values;
    
    std::cout << "Keys: ";
    for (int k : keys) std::cout << k << " ";
    std::cout << std::endl;
    
    std::cout << "Values: ";
    for (const auto& v : values) std::cout << v << " ";
    std::cout << std::endl;
    
    // common: 转换为 common_range
    // all: 获取所有元素的 view
    auto all = std::views::all(vec);
    
    return 0;
}
```

### 3.4 split 和 join

```cpp
#include <iostream>
#include <string>
#include <string_view>
#include <ranges>
#include <vector>

int main() {
    // split: 分割
    std::string text = "hello,world,foo,bar";
    auto words = text | std::views::split(',');
    
    std::cout << "Split: ";
    for (auto word : words) {
        // word 是一个 subrange
        for (char c : word) std::cout << c;
        std::cout << " ";
    }
    std::cout << std::endl;
    
    // 使用 string_view 分割
    std::string_view sv = "one two three four";
    for (auto word : sv | std::views::split(' ')) {
        std::string_view w(word.begin(), word.end());
        std::cout << w << std::endl;
    }
    
    // join: 连接嵌套 range
    std::vector<std::vector<int>> nested = {{1, 2}, {3, 4}, {5, 6}};
    auto flat = nested | std::views::join;
    
    std::cout << "Join: ";
    for (int x : flat) std::cout << x << " ";
    std::cout << std::endl;  // 1 2 3 4 5 6
    
    return 0;
}
```

---

## 4. Range 算法

### 4.1 基本算法

```cpp
#include <iostream>
#include <vector>
#include <ranges>
#include <algorithm>

int main() {
    std::vector<int> vec = {3, 1, 4, 1, 5, 9, 2, 6, 5, 3};
    
    // ranges::sort
    std::ranges::sort(vec);
    std::cout << "Sorted: ";
    for (int x : vec) std::cout << x << " ";
    std::cout << std::endl;
    
    // ranges::find
    auto it = std::ranges::find(vec, 5);
    if (it != vec.end()) {
        std::cout << "Found 5 at index: " << (it - vec.begin()) << std::endl;
    }
    
    // ranges::count
    int count = std::ranges::count(vec, 5);
    std::cout << "Count of 5: " << count << std::endl;
    
    // ranges::for_each
    std::cout << "for_each: ";
    std::ranges::for_each(vec, [](int x) { std::cout << x << " "; });
    std::cout << std::endl;
    
    // ranges::copy
    std::vector<int> dest(vec.size());
    std::ranges::copy(vec, dest.begin());
    
    return 0;
}
```

### 4.2 投影 (Projections)

```cpp
#include <iostream>
#include <vector>
#include <string>
#include <ranges>
#include <algorithm>

struct Person {
    std::string name;
    int age;
};

int main() {
    std::vector<Person> people = {
        {"Alice", 30},
        {"Bob", 25},
        {"Charlie", 35},
        {"David", 28}
    };
    
    // 使用投影按年龄排序
    std::ranges::sort(people, {}, &Person::age);
    
    std::cout << "Sorted by age:" << std::endl;
    for (const auto& p : people) {
        std::cout << "  " << p.name << ": " << p.age << std::endl;
    }
    
    // 使用投影按名字排序
    std::ranges::sort(people, {}, &Person::name);
    
    std::cout << "\nSorted by name:" << std::endl;
    for (const auto& p : people) {
        std::cout << "  " << p.name << ": " << p.age << std::endl;
    }
    
    // 使用投影查找
    auto it = std::ranges::find(people, 30, &Person::age);
    if (it != people.end()) {
        std::cout << "\nFound person with age 30: " << it->name << std::endl;
    }
    
    // 使用 lambda 作为投影
    std::ranges::sort(people, std::greater{}, [](const Person& p) {
        return p.name.length();
    });
    
    std::cout << "\nSorted by name length (desc):" << std::endl;
    for (const auto& p : people) {
        std::cout << "  " << p.name << std::endl;
    }
    
    return 0;
}
```

### 4.3 Range 算法返回值

```cpp
#include <iostream>
#include <vector>
#include <ranges>
#include <algorithm>

int main() {
    std::vector<int> vec = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    
    // ranges::find 返回迭代器
    auto found = std::ranges::find(vec, 5);
    
    // ranges::minmax 返回 min_max_result
    auto [min, max] = std::ranges::minmax(vec);
    std::cout << "Min: " << min << ", Max: " << max << std::endl;
    
    // ranges::copy 返回 in_out_result
    std::vector<int> dest(5);
    auto [in, out] = std::ranges::copy(vec | std::views::take(5), dest.begin());
    
    // ranges::partition 返回 subrange
    std::vector<int> vec2 = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    auto [first, last] = std::ranges::partition(vec2, [](int x) { return x % 2 == 0; });
    
    std::cout << "Evens: ";
    for (auto it = vec2.begin(); it != first; ++it) {
        std::cout << *it << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

---

## 5. Range 工厂

### 5.1 iota

```cpp
#include <iostream>
#include <ranges>

int main() {
    // iota: 生成递增序列
    
    // 无限序列
    auto infinite = std::views::iota(1);
    std::cout << "First 10: ";
    for (int x : infinite | std::views::take(10)) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    // 有界序列
    auto bounded = std::views::iota(1, 11);
    std::cout << "1 to 10: ";
    for (int x : bounded) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    // 与其他 views 组合
    auto evenSquares = std::views::iota(1, 20)
        | std::views::filter([](int x) { return x % 2 == 0; })
        | std::views::transform([](int x) { return x * x; });
    
    std::cout << "Even squares: ";
    for (int x : evenSquares) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

### 5.2 repeat 和 single

```cpp
#include <iostream>
#include <ranges>

int main() {
    // repeat: 重复值 (C++23)
    // auto repeated = std::views::repeat(42, 5);
    
    // single: 单个元素
    auto single = std::views::single(42);
    std::cout << "Single: ";
    for (int x : single) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    // empty: 空 range
    auto empty = std::views::empty<int>;
    std::cout << "Empty size: " << std::ranges::size(empty) << std::endl;
    
    return 0;
}
```

### 5.3 counted

```cpp
#include <iostream>
#include <vector>
#include <ranges>

int main() {
    std::vector<int> vec = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    
    // counted: 从迭代器开始取 n 个元素
    auto counted = std::views::counted(vec.begin() + 2, 5);
    
    std::cout << "Counted: ";
    for (int x : counted) {
        std::cout << x << " ";
    }
    std::cout << std::endl;  // 3 4 5 6 7
    
    return 0;
}
```

---

## 6. 实际应用

### 6.1 数据处理管道

```cpp
#include <iostream>
#include <vector>
#include <string>
#include <ranges>
#include <algorithm>

struct Product {
    std::string name;
    double price;
    int quantity;
};

int main() {
    std::vector<Product> products = {
        {"Apple", 1.5, 100},
        {"Banana", 0.75, 150},
        {"Orange", 2.0, 80},
        {"Grape", 3.5, 50},
        {"Mango", 2.5, 120}
    };
    
    // 找出价格大于 1.5 的产品,计算总价值,取前 3 个
    auto pipeline = products
        | std::views::filter([](const Product& p) { return p.price > 1.5; })
        | std::views::transform([](const Product& p) {
            return std::make_pair(p.name, p.price * p.quantity);
        })
        | std::views::take(3);
    
    std::cout << "Top products by value:" << std::endl;
    for (const auto& [name, value] : pipeline) {
        std::cout << "  " << name << ": $" << value << std::endl;
    }
    
    // 计算总库存价值
    double totalValue = 0;
    for (const auto& p : products) {
        totalValue += p.price * p.quantity;
    }
    std::cout << "\nTotal inventory value: $" << totalValue << std::endl;
    
    return 0;
}
```

### 6.2 字符串处理

```cpp
#include <iostream>
#include <string>
#include <string_view>
#include <ranges>
#include <vector>
#include <algorithm>

int main() {
    std::string text = "  Hello,  World,  Foo,  Bar  ";
    
    // 分割并去除空白
    auto words = text 
        | std::views::split(',')
        | std::views::transform([](auto word) {
            // 转换为 string_view
            auto sv = std::string_view(word.begin(), word.end());
            // 去除前后空白
            auto start = sv.find_first_not_of(' ');
            auto end = sv.find_last_not_of(' ');
            if (start == std::string_view::npos) return std::string_view{};
            return sv.substr(start, end - start + 1);
        })
        | std::views::filter([](auto sv) { return !sv.empty(); });
    
    std::cout << "Words:" << std::endl;
    for (auto word : words) {
        std::cout << "  \"" << word << "\"" << std::endl;
    }
    
    return 0;
}
```

### 6.3 惰性求值

```cpp
#include <iostream>
#include <ranges>

int main() {
    // 惰性求值: 只在需要时计算
    
    int computeCount = 0;
    
    auto expensiveCompute = [&computeCount](int x) {
        ++computeCount;
        std::cout << "Computing for " << x << std::endl;
        return x * x;
    };
    
    // 创建 view (不会立即计算)
    auto view = std::views::iota(1, 100)
        | std::views::filter([](int x) { return x % 10 == 0; })
        | std::views::transform(expensiveCompute)
        | std::views::take(3);
    
    std::cout << "View created, computeCount: " << computeCount << std::endl;
    
    // 遍历时才计算
    std::cout << "\nIterating:" << std::endl;
    for (int x : view) {
        std::cout << "Result: " << x << std::endl;
    }
    
    std::cout << "\nTotal computations: " << computeCount << std::endl;
    
    return 0;
}
```

---

## 7. 总结

### 7.1 常用 Views

| View | 功能 |
|------|------|
| filter | 过滤元素 |
| transform | 变换元素 |
| take | 取前 n 个 |
| drop | 跳过前 n 个 |
| reverse | 反转 |
| split | 分割 |
| join | 连接 |
| iota | 生成序列 |

### 7.2 最佳实践

```
1. 使用管道操作符组合 views
2. 利用惰性求值优化性能
3. 使用投影简化算法调用
4. 注意 view 的生命周期
5. 优先使用 ranges 算法
```

### 7.3 下一篇预告

在下一篇文章中,我们将学习协程。

---

> 作者: C++ 技术专栏  
> 系列: 现代 C++ (6/10)  
> 上一篇: [Concepts 与约束](./35-concepts.md)  
> 下一篇: [协程](./37-coroutines.md)
