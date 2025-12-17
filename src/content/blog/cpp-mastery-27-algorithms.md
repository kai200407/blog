---
title: "STL 算法"
description: "1. [算法概述](#1-算法概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 27
---

> 本文是 C++ 从入门到精通系列的第二十七篇,将深入讲解 STL 算法库,包括常用算法的分类和使用方法。

---

## 目录

1. [算法概述](#1-算法概述)
2. [非修改算法](#2-非修改算法)
3. [修改算法](#3-修改算法)
4. [排序算法](#4-排序算法)
5. [数值算法](#5-数值算法)
6. [并行算法](#6-并行算法)
7. [总结](#7-总结)

---

## 1. 算法概述

### 1.1 算法特点

```
STL 算法特点:

1. 泛型: 适用于任何容器
2. 基于迭代器: 通过迭代器访问元素
3. 函数对象: 支持自定义操作
4. 高效: 经过优化的实现

头文件:
- <algorithm>: 大多数算法
- <numeric>: 数值算法
- <execution>: 并行执行策略 (C++17)
```

### 1.2 算法分类

```cpp
#include <iostream>
#include <vector>
#include <algorithm>
#include <numeric>

int main() {
    std::vector<int> vec = {3, 1, 4, 1, 5, 9, 2, 6, 5, 3};
    
    // 非修改算法
    auto it = std::find(vec.begin(), vec.end(), 5);
    int count = std::count(vec.begin(), vec.end(), 1);
    
    // 修改算法
    std::replace(vec.begin(), vec.end(), 1, 10);
    
    // 排序算法
    std::sort(vec.begin(), vec.end());
    
    // 数值算法
    int sum = std::accumulate(vec.begin(), vec.end(), 0);
    
    std::cout << "Sum: " << sum << std::endl;
    
    return 0;
}
```

---

## 2. 非修改算法

### 2.1 查找算法

```cpp
#include <iostream>
#include <vector>
#include <algorithm>

int main() {
    std::vector<int> vec = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    
    // find: 查找值
    auto it = std::find(vec.begin(), vec.end(), 5);
    if (it != vec.end()) {
        std::cout << "Found 5 at index: " << (it - vec.begin()) << std::endl;
    }
    
    // find_if: 查找满足条件的元素
    auto it2 = std::find_if(vec.begin(), vec.end(), [](int x) { return x > 7; });
    if (it2 != vec.end()) {
        std::cout << "First > 7: " << *it2 << std::endl;
    }
    
    // find_if_not: 查找不满足条件的元素
    auto it3 = std::find_if_not(vec.begin(), vec.end(), [](int x) { return x < 5; });
    std::cout << "First >= 5: " << *it3 << std::endl;
    
    // find_first_of: 查找任意匹配
    std::vector<int> targets = {7, 8, 9};
    auto it4 = std::find_first_of(vec.begin(), vec.end(), targets.begin(), targets.end());
    std::cout << "First of {7,8,9}: " << *it4 << std::endl;
    
    // adjacent_find: 查找相邻相等元素
    std::vector<int> vec2 = {1, 2, 2, 3, 4, 4, 4, 5};
    auto it5 = std::adjacent_find(vec2.begin(), vec2.end());
    std::cout << "Adjacent equal: " << *it5 << std::endl;
    
    // search: 查找子序列
    std::vector<int> sub = {3, 4, 5};
    auto it6 = std::search(vec.begin(), vec.end(), sub.begin(), sub.end());
    if (it6 != vec.end()) {
        std::cout << "Subsequence found at: " << (it6 - vec.begin()) << std::endl;
    }
    
    return 0;
}
```

### 2.2 计数和比较

```cpp
#include <iostream>
#include <vector>
#include <algorithm>

int main() {
    std::vector<int> vec = {1, 2, 3, 2, 4, 2, 5, 2};
    
    // count: 计数
    int c = std::count(vec.begin(), vec.end(), 2);
    std::cout << "Count of 2: " << c << std::endl;
    
    // count_if: 条件计数
    int c2 = std::count_if(vec.begin(), vec.end(), [](int x) { return x > 2; });
    std::cout << "Count > 2: " << c2 << std::endl;
    
    // all_of, any_of, none_of
    bool allPositive = std::all_of(vec.begin(), vec.end(), [](int x) { return x > 0; });
    bool anyEven = std::any_of(vec.begin(), vec.end(), [](int x) { return x % 2 == 0; });
    bool noneNegative = std::none_of(vec.begin(), vec.end(), [](int x) { return x < 0; });
    
    std::cout << "All positive: " << allPositive << std::endl;
    std::cout << "Any even: " << anyEven << std::endl;
    std::cout << "None negative: " << noneNegative << std::endl;
    
    // equal: 比较两个范围
    std::vector<int> vec2 = {1, 2, 3, 2, 4, 2, 5, 2};
    bool eq = std::equal(vec.begin(), vec.end(), vec2.begin());
    std::cout << "Equal: " << eq << std::endl;
    
    // mismatch: 找到第一个不匹配
    std::vector<int> vec3 = {1, 2, 3, 9, 4, 2, 5, 2};
    auto [it1, it2] = std::mismatch(vec.begin(), vec.end(), vec3.begin());
    if (it1 != vec.end()) {
        std::cout << "Mismatch at: " << *it1 << " vs " << *it2 << std::endl;
    }
    
    return 0;
}
```

### 2.3 遍历算法

```cpp
#include <iostream>
#include <vector>
#include <algorithm>

int main() {
    std::vector<int> vec = {1, 2, 3, 4, 5};
    
    // for_each: 对每个元素执行操作
    std::cout << "for_each: ";
    std::for_each(vec.begin(), vec.end(), [](int x) {
        std::cout << x * 2 << " ";
    });
    std::cout << std::endl;
    
    // for_each_n (C++17): 对前 n 个元素执行操作
    std::cout << "for_each_n: ";
    std::for_each_n(vec.begin(), 3, [](int x) {
        std::cout << x << " ";
    });
    std::cout << std::endl;
    
    // 修改元素
    std::for_each(vec.begin(), vec.end(), [](int& x) {
        x *= 2;
    });
    
    std::cout << "After modify: ";
    for (int x : vec) std::cout << x << " ";
    std::cout << std::endl;
    
    return 0;
}
```

---

## 3. 修改算法

### 3.1 复制和移动

```cpp
#include <iostream>
#include <vector>
#include <algorithm>
#include <iterator>

int main() {
    std::vector<int> src = {1, 2, 3, 4, 5};
    
    // copy: 复制
    std::vector<int> dest1(5);
    std::copy(src.begin(), src.end(), dest1.begin());
    
    // copy_n: 复制 n 个元素
    std::vector<int> dest2(3);
    std::copy_n(src.begin(), 3, dest2.begin());
    
    // copy_if: 条件复制
    std::vector<int> dest3;
    std::copy_if(src.begin(), src.end(), std::back_inserter(dest3),
                 [](int x) { return x % 2 == 0; });
    
    std::cout << "copy_if (even): ";
    for (int x : dest3) std::cout << x << " ";
    std::cout << std::endl;
    
    // copy_backward: 从后向前复制
    std::vector<int> dest4(7, 0);
    std::copy_backward(src.begin(), src.end(), dest4.end());
    
    std::cout << "copy_backward: ";
    for (int x : dest4) std::cout << x << " ";
    std::cout << std::endl;
    
    // move: 移动
    std::vector<std::string> strs = {"hello", "world"};
    std::vector<std::string> dest5(2);
    std::move(strs.begin(), strs.end(), dest5.begin());
    
    return 0;
}
```

### 3.2 变换和替换

```cpp
#include <iostream>
#include <vector>
#include <algorithm>
#include <string>

int main() {
    std::vector<int> vec = {1, 2, 3, 4, 5};
    
    // transform: 变换
    std::vector<int> result(vec.size());
    std::transform(vec.begin(), vec.end(), result.begin(),
                   [](int x) { return x * x; });
    
    std::cout << "transform (square): ";
    for (int x : result) std::cout << x << " ";
    std::cout << std::endl;
    
    // transform: 两个范围
    std::vector<int> vec2 = {10, 20, 30, 40, 50};
    std::vector<int> sum(vec.size());
    std::transform(vec.begin(), vec.end(), vec2.begin(), sum.begin(),
                   [](int a, int b) { return a + b; });
    
    std::cout << "transform (sum): ";
    for (int x : sum) std::cout << x << " ";
    std::cout << std::endl;
    
    // replace: 替换值
    std::vector<int> vec3 = {1, 2, 3, 2, 4, 2, 5};
    std::replace(vec3.begin(), vec3.end(), 2, 0);
    
    std::cout << "replace 2 with 0: ";
    for (int x : vec3) std::cout << x << " ";
    std::cout << std::endl;
    
    // replace_if: 条件替换
    std::vector<int> vec4 = {1, 2, 3, 4, 5, 6, 7, 8};
    std::replace_if(vec4.begin(), vec4.end(),
                    [](int x) { return x % 2 == 0; }, 0);
    
    std::cout << "replace_if (even with 0): ";
    for (int x : vec4) std::cout << x << " ";
    std::cout << std::endl;
    
    return 0;
}
```

### 3.3 填充和生成

```cpp
#include <iostream>
#include <vector>
#include <algorithm>
#include <random>

int main() {
    // fill: 填充
    std::vector<int> vec1(5);
    std::fill(vec1.begin(), vec1.end(), 42);
    
    std::cout << "fill: ";
    for (int x : vec1) std::cout << x << " ";
    std::cout << std::endl;
    
    // fill_n: 填充 n 个
    std::vector<int> vec2(10, 0);
    std::fill_n(vec2.begin(), 5, 100);
    
    std::cout << "fill_n: ";
    for (int x : vec2) std::cout << x << " ";
    std::cout << std::endl;
    
    // generate: 生成
    std::vector<int> vec3(5);
    int n = 0;
    std::generate(vec3.begin(), vec3.end(), [&n]() { return n++; });
    
    std::cout << "generate: ";
    for (int x : vec3) std::cout << x << " ";
    std::cout << std::endl;
    
    // generate_n: 生成 n 个
    std::vector<int> vec4(5);
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(1, 100);
    std::generate_n(vec4.begin(), 5, [&]() { return dis(gen); });
    
    std::cout << "generate_n (random): ";
    for (int x : vec4) std::cout << x << " ";
    std::cout << std::endl;
    
    // iota: 递增填充
    std::vector<int> vec5(5);
    std::iota(vec5.begin(), vec5.end(), 10);
    
    std::cout << "iota: ";
    for (int x : vec5) std::cout << x << " ";
    std::cout << std::endl;
    
    return 0;
}
```

### 3.4 删除和去重

```cpp
#include <iostream>
#include <vector>
#include <algorithm>

int main() {
    // remove: 移除元素 (不改变容器大小)
    std::vector<int> vec1 = {1, 2, 3, 2, 4, 2, 5};
    auto newEnd = std::remove(vec1.begin(), vec1.end(), 2);
    vec1.erase(newEnd, vec1.end());  // 真正删除
    
    std::cout << "remove 2: ";
    for (int x : vec1) std::cout << x << " ";
    std::cout << std::endl;
    
    // remove_if: 条件移除
    std::vector<int> vec2 = {1, 2, 3, 4, 5, 6, 7, 8};
    vec2.erase(std::remove_if(vec2.begin(), vec2.end(),
                              [](int x) { return x % 2 == 0; }),
               vec2.end());
    
    std::cout << "remove_if (even): ";
    for (int x : vec2) std::cout << x << " ";
    std::cout << std::endl;
    
    // unique: 去除相邻重复
    std::vector<int> vec3 = {1, 1, 2, 2, 2, 3, 3, 4};
    vec3.erase(std::unique(vec3.begin(), vec3.end()), vec3.end());
    
    std::cout << "unique: ";
    for (int x : vec3) std::cout << x << " ";
    std::cout << std::endl;
    
    // 去除所有重复 (先排序)
    std::vector<int> vec4 = {3, 1, 4, 1, 5, 9, 2, 6, 5, 3};
    std::sort(vec4.begin(), vec4.end());
    vec4.erase(std::unique(vec4.begin(), vec4.end()), vec4.end());
    
    std::cout << "sort + unique: ";
    for (int x : vec4) std::cout << x << " ";
    std::cout << std::endl;
    
    return 0;
}
```

---

## 4. 排序算法

### 4.1 排序

```cpp
#include <iostream>
#include <vector>
#include <algorithm>

int main() {
    std::vector<int> vec = {3, 1, 4, 1, 5, 9, 2, 6, 5, 3};
    
    // sort: 排序
    std::sort(vec.begin(), vec.end());
    std::cout << "sort: ";
    for (int x : vec) std::cout << x << " ";
    std::cout << std::endl;
    
    // 降序排序
    std::sort(vec.begin(), vec.end(), std::greater<int>());
    std::cout << "sort (desc): ";
    for (int x : vec) std::cout << x << " ";
    std::cout << std::endl;
    
    // stable_sort: 稳定排序
    std::vector<std::pair<int, char>> pairs = {{1, 'a'}, {2, 'b'}, {1, 'c'}, {2, 'd'}};
    std::stable_sort(pairs.begin(), pairs.end(),
                     [](const auto& a, const auto& b) { return a.first < b.first; });
    
    std::cout << "stable_sort: ";
    for (const auto& [n, c] : pairs) std::cout << "(" << n << "," << c << ") ";
    std::cout << std::endl;
    
    // partial_sort: 部分排序
    vec = {3, 1, 4, 1, 5, 9, 2, 6, 5, 3};
    std::partial_sort(vec.begin(), vec.begin() + 3, vec.end());
    std::cout << "partial_sort (top 3): ";
    for (int x : vec) std::cout << x << " ";
    std::cout << std::endl;
    
    // nth_element: 第 n 个元素
    vec = {3, 1, 4, 1, 5, 9, 2, 6, 5, 3};
    std::nth_element(vec.begin(), vec.begin() + 4, vec.end());
    std::cout << "nth_element (5th): " << vec[4] << std::endl;
    
    return 0;
}
```

### 4.2 二分查找

```cpp
#include <iostream>
#include <vector>
#include <algorithm>

int main() {
    std::vector<int> vec = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    
    // binary_search: 是否存在
    bool found = std::binary_search(vec.begin(), vec.end(), 5);
    std::cout << "binary_search(5): " << found << std::endl;
    
    // lower_bound: >= 的第一个位置
    auto lower = std::lower_bound(vec.begin(), vec.end(), 5);
    std::cout << "lower_bound(5): " << *lower << " at " << (lower - vec.begin()) << std::endl;
    
    // upper_bound: > 的第一个位置
    auto upper = std::upper_bound(vec.begin(), vec.end(), 5);
    std::cout << "upper_bound(5): " << *upper << " at " << (upper - vec.begin()) << std::endl;
    
    // equal_range: 等于的范围
    std::vector<int> vec2 = {1, 2, 3, 3, 3, 4, 5};
    auto [first, last] = std::equal_range(vec2.begin(), vec2.end(), 3);
    std::cout << "equal_range(3): [" << (first - vec2.begin()) 
              << ", " << (last - vec2.begin()) << ")" << std::endl;
    
    return 0;
}
```

### 4.3 合并和集合操作

```cpp
#include <iostream>
#include <vector>
#include <algorithm>
#include <iterator>

int main() {
    std::vector<int> a = {1, 3, 5, 7, 9};
    std::vector<int> b = {2, 4, 6, 8, 10};
    
    // merge: 合并两个有序序列
    std::vector<int> merged;
    std::merge(a.begin(), a.end(), b.begin(), b.end(), std::back_inserter(merged));
    
    std::cout << "merge: ";
    for (int x : merged) std::cout << x << " ";
    std::cout << std::endl;
    
    // inplace_merge: 原地合并
    std::vector<int> vec = {1, 3, 5, 2, 4, 6};
    std::inplace_merge(vec.begin(), vec.begin() + 3, vec.end());
    
    std::cout << "inplace_merge: ";
    for (int x : vec) std::cout << x << " ";
    std::cout << std::endl;
    
    // 集合操作
    std::vector<int> s1 = {1, 2, 3, 4, 5};
    std::vector<int> s2 = {3, 4, 5, 6, 7};
    
    // set_union: 并集
    std::vector<int> unionSet;
    std::set_union(s1.begin(), s1.end(), s2.begin(), s2.end(), std::back_inserter(unionSet));
    std::cout << "union: ";
    for (int x : unionSet) std::cout << x << " ";
    std::cout << std::endl;
    
    // set_intersection: 交集
    std::vector<int> intersection;
    std::set_intersection(s1.begin(), s1.end(), s2.begin(), s2.end(), std::back_inserter(intersection));
    std::cout << "intersection: ";
    for (int x : intersection) std::cout << x << " ";
    std::cout << std::endl;
    
    // set_difference: 差集
    std::vector<int> difference;
    std::set_difference(s1.begin(), s1.end(), s2.begin(), s2.end(), std::back_inserter(difference));
    std::cout << "difference (s1 - s2): ";
    for (int x : difference) std::cout << x << " ";
    std::cout << std::endl;
    
    return 0;
}
```

---

## 5. 数值算法

### 5.1 累积和归约

```cpp
#include <iostream>
#include <vector>
#include <numeric>
#include <functional>

int main() {
    std::vector<int> vec = {1, 2, 3, 4, 5};
    
    // accumulate: 累加
    int sum = std::accumulate(vec.begin(), vec.end(), 0);
    std::cout << "sum: " << sum << std::endl;
    
    // 自定义操作
    int product = std::accumulate(vec.begin(), vec.end(), 1, std::multiplies<int>());
    std::cout << "product: " << product << std::endl;
    
    // 字符串连接
    std::vector<std::string> strs = {"hello", " ", "world"};
    std::string concat = std::accumulate(strs.begin(), strs.end(), std::string(""));
    std::cout << "concat: " << concat << std::endl;
    
    // reduce (C++17): 可并行的累积
    // int sum2 = std::reduce(vec.begin(), vec.end());
    
    // inner_product: 内积
    std::vector<int> a = {1, 2, 3};
    std::vector<int> b = {4, 5, 6};
    int dot = std::inner_product(a.begin(), a.end(), b.begin(), 0);
    std::cout << "inner_product: " << dot << std::endl;  // 1*4 + 2*5 + 3*6 = 32
    
    return 0;
}
```

### 5.2 前缀和

```cpp
#include <iostream>
#include <vector>
#include <numeric>

int main() {
    std::vector<int> vec = {1, 2, 3, 4, 5};
    
    // partial_sum: 前缀和
    std::vector<int> prefix(vec.size());
    std::partial_sum(vec.begin(), vec.end(), prefix.begin());
    
    std::cout << "partial_sum: ";
    for (int x : prefix) std::cout << x << " ";
    std::cout << std::endl;  // 1, 3, 6, 10, 15
    
    // 前缀积
    std::vector<int> prefixProduct(vec.size());
    std::partial_sum(vec.begin(), vec.end(), prefixProduct.begin(), std::multiplies<int>());
    
    std::cout << "partial_product: ";
    for (int x : prefixProduct) std::cout << x << " ";
    std::cout << std::endl;  // 1, 2, 6, 24, 120
    
    // adjacent_difference: 相邻差
    std::vector<int> diff(vec.size());
    std::adjacent_difference(vec.begin(), vec.end(), diff.begin());
    
    std::cout << "adjacent_difference: ";
    for (int x : diff) std::cout << x << " ";
    std::cout << std::endl;  // 1, 1, 1, 1, 1
    
    // inclusive_scan (C++17): 包含当前元素的前缀和
    // exclusive_scan (C++17): 不包含当前元素的前缀和
    
    return 0;
}
```

---

## 6. 并行算法

### 6.1 执行策略 (C++17)

```cpp
#include <iostream>
#include <vector>
#include <algorithm>
#include <execution>
#include <chrono>

int main() {
    const int N = 10000000;
    std::vector<int> vec(N);
    std::iota(vec.begin(), vec.end(), 0);
    
    // 顺序执行
    auto start1 = std::chrono::high_resolution_clock::now();
    std::sort(std::execution::seq, vec.begin(), vec.end(), std::greater<int>());
    auto end1 = std::chrono::high_resolution_clock::now();
    
    // 并行执行
    auto start2 = std::chrono::high_resolution_clock::now();
    std::sort(std::execution::par, vec.begin(), vec.end());
    auto end2 = std::chrono::high_resolution_clock::now();
    
    // 并行无序执行
    auto start3 = std::chrono::high_resolution_clock::now();
    std::sort(std::execution::par_unseq, vec.begin(), vec.end(), std::greater<int>());
    auto end3 = std::chrono::high_resolution_clock::now();
    
    auto d1 = std::chrono::duration_cast<std::chrono::milliseconds>(end1 - start1);
    auto d2 = std::chrono::duration_cast<std::chrono::milliseconds>(end2 - start2);
    auto d3 = std::chrono::duration_cast<std::chrono::milliseconds>(end3 - start3);
    
    std::cout << "Sequential: " << d1.count() << " ms" << std::endl;
    std::cout << "Parallel: " << d2.count() << " ms" << std::endl;
    std::cout << "Parallel unsequenced: " << d3.count() << " ms" << std::endl;
    
    return 0;
}
```

### 6.2 并行算法示例

```cpp
#include <iostream>
#include <vector>
#include <algorithm>
#include <execution>
#include <numeric>

int main() {
    std::vector<int> vec(1000000);
    std::iota(vec.begin(), vec.end(), 1);
    
    // 并行 for_each
    std::for_each(std::execution::par, vec.begin(), vec.end(),
                  [](int& x) { x *= 2; });
    
    // 并行 transform
    std::vector<int> result(vec.size());
    std::transform(std::execution::par, vec.begin(), vec.end(), result.begin(),
                   [](int x) { return x * x; });
    
    // 并行 reduce
    long long sum = std::reduce(std::execution::par, vec.begin(), vec.end(), 0LL);
    std::cout << "Sum: " << sum << std::endl;
    
    // 并行 find_if
    auto it = std::find_if(std::execution::par, vec.begin(), vec.end(),
                           [](int x) { return x > 1000000; });
    if (it != vec.end()) {
        std::cout << "Found: " << *it << std::endl;
    }
    
    return 0;
}
```

---

## 7. 总结

### 7.1 常用算法速查

| 类别 | 算法 | 功能 |
|------|------|------|
| 查找 | find, find_if | 查找元素 |
| 计数 | count, count_if | 计数 |
| 比较 | equal, mismatch | 比较范围 |
| 复制 | copy, copy_if | 复制元素 |
| 变换 | transform | 变换元素 |
| 删除 | remove, unique | 删除元素 |
| 排序 | sort, stable_sort | 排序 |
| 二分 | binary_search, lower_bound | 二分查找 |
| 数值 | accumulate, partial_sum | 数值计算 |

### 7.2 最佳实践

```
1. 优先使用标准算法
2. 使用 lambda 自定义操作
3. 注意迭代器失效
4. 考虑使用并行算法
5. 选择合适的算法复杂度
```

### 7.3 下一篇预告

在下一篇文章中,我们将学习函数对象与 Lambda。

---

> 作者: C++ 技术专栏  
> 系列: STL 标准模板库 (5/8)  
> 上一篇: [迭代器](./26-iterators.md)  
> 下一篇: [函数对象与 Lambda](./28-functors-lambda.md)
