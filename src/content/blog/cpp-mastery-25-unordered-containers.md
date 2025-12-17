---
title: "无序容器"
description: "1. [无序容器概述](#1-无序容器概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 25
---

> 本文是 C++ 从入门到精通系列的第二十五篇,将深入讲解 STL 的无序容器,包括 unordered_set、unordered_multiset、unordered_map 和 unordered_multimap。

---

## 目录

1. [无序容器概述](#1-无序容器概述)
2. [unordered_set](#2-unordered_set)
3. [unordered_map](#3-unordered_map)
4. [哈希函数](#4-哈希函数)
5. [桶接口](#5-桶接口)
6. [性能优化](#6-性能优化)
7. [总结](#7-总结)

---

## 1. 无序容器概述

### 1.1 无序容器特点

```
无序容器特点:

1. 基于哈希表实现
2. 元素无序存储
3. 平均查找、插入、删除 O(1)
4. 最坏情况 O(n)
5. 需要哈希函数和相等比较

容器类型:
- unordered_set: 无序集合,元素唯一
- unordered_multiset: 无序集合,允许重复
- unordered_map: 无序键值对,键唯一
- unordered_multimap: 无序键值对,允许重复键
```

### 1.2 哈希表原理

```
哈希表工作原理:

1. 计算哈希值
   hash(key) -> index

2. 存储到对应桶
   buckets[index].insert(element)

3. 处理冲突
   - 链地址法: 每个桶是链表
   - 开放地址法: 探测下一个位置

┌─────┐
│  0  │ -> [elem1] -> [elem2]
├─────┤
│  1  │ -> [elem3]
├─────┤
│  2  │ -> (empty)
├─────┤
│  3  │ -> [elem4] -> [elem5] -> [elem6]
├─────┤
│ ... │
└─────┘
```

---

## 2. unordered_set

### 2.1 基本操作

```cpp
#include <iostream>
#include <unordered_set>

int main() {
    // 创建
    std::unordered_set<int> us1;
    std::unordered_set<int> us2 = {3, 1, 4, 1, 5, 9, 2, 6};
    
    // 插入
    us1.insert(10);
    us1.insert(20);
    us1.insert(30);
    us1.emplace(40);
    us1.insert({50, 60, 70});
    
    auto result = us1.insert(20);  // 返回 pair<iterator, bool>
    std::cout << "Insert 20: " << (result.second ? "success" : "failed") << std::endl;
    
    // 遍历 (无序)
    std::cout << "us2: ";
    for (int x : us2) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    // 查找
    auto it = us2.find(4);
    if (it != us2.end()) {
        std::cout << "Found: " << *it << std::endl;
    }
    
    // 计数
    std::cout << "count(1): " << us2.count(1) << std::endl;
    
    // 包含 (C++20)
    // std::cout << "contains(5): " << us2.contains(5) << std::endl;
    
    // 删除
    us2.erase(1);
    us2.erase(us2.find(4));
    
    std::cout << "After erase: ";
    for (int x : us2) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

### 2.2 unordered_set vs set

```cpp
#include <iostream>
#include <set>
#include <unordered_set>
#include <chrono>
#include <random>

int main() {
    const int N = 1000000;
    
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(1, N * 10);
    
    std::vector<int> data(N);
    for (int i = 0; i < N; ++i) {
        data[i] = dis(gen);
    }
    
    // 测试 set
    auto start1 = std::chrono::high_resolution_clock::now();
    std::set<int> s;
    for (int x : data) {
        s.insert(x);
    }
    auto end1 = std::chrono::high_resolution_clock::now();
    
    // 测试 unordered_set
    auto start2 = std::chrono::high_resolution_clock::now();
    std::unordered_set<int> us;
    for (int x : data) {
        us.insert(x);
    }
    auto end2 = std::chrono::high_resolution_clock::now();
    
    auto duration1 = std::chrono::duration_cast<std::chrono::milliseconds>(end1 - start1);
    auto duration2 = std::chrono::duration_cast<std::chrono::milliseconds>(end2 - start2);
    
    std::cout << "set insert: " << duration1.count() << " ms" << std::endl;
    std::cout << "unordered_set insert: " << duration2.count() << " ms" << std::endl;
    
    // 查找测试
    start1 = std::chrono::high_resolution_clock::now();
    for (int x : data) {
        s.find(x);
    }
    end1 = std::chrono::high_resolution_clock::now();
    
    start2 = std::chrono::high_resolution_clock::now();
    for (int x : data) {
        us.find(x);
    }
    end2 = std::chrono::high_resolution_clock::now();
    
    duration1 = std::chrono::duration_cast<std::chrono::milliseconds>(end1 - start1);
    duration2 = std::chrono::duration_cast<std::chrono::milliseconds>(end2 - start2);
    
    std::cout << "set find: " << duration1.count() << " ms" << std::endl;
    std::cout << "unordered_set find: " << duration2.count() << " ms" << std::endl;
    
    return 0;
}
```

---

## 3. unordered_map

### 3.1 基本操作

```cpp
#include <iostream>
#include <unordered_map>
#include <string>

int main() {
    // 创建
    std::unordered_map<std::string, int> ages;
    std::unordered_map<std::string, int> ages2 = {
        {"Alice", 25},
        {"Bob", 30},
        {"Charlie", 35}
    };
    
    // 插入
    ages["David"] = 28;
    ages.insert({"Eve", 22});
    ages.insert(std::make_pair("Frank", 40));
    ages.emplace("Grace", 33);
    
    // 访问
    std::cout << "Alice's age: " << ages2["Alice"] << std::endl;
    std::cout << "Bob's age: " << ages2.at("Bob") << std::endl;
    
    // 遍历 (无序)
    std::cout << "\nAll ages:" << std::endl;
    for (const auto& [name, age] : ages2) {
        std::cout << name << ": " << age << std::endl;
    }
    
    // 查找
    auto it = ages2.find("Charlie");
    if (it != ages2.end()) {
        std::cout << "\nFound: " << it->first << " = " << it->second << std::endl;
    }
    
    // 删除
    ages2.erase("Bob");
    
    // insert_or_assign (C++17)
    ages2.insert_or_assign("Alice", 26);
    
    // try_emplace (C++17)
    ages2.try_emplace("Alice", 27);  // 不会更新
    ages2.try_emplace("Henry", 45);  // 会插入
    
    return 0;
}
```

### 3.2 unordered_map 应用

```cpp
#include <iostream>
#include <unordered_map>
#include <string>
#include <vector>

int main() {
    // 词频统计
    std::string text = "the quick brown fox jumps over the lazy dog the fox";
    std::unordered_map<std::string, int> wordCount;
    
    std::istringstream iss(text);
    std::string word;
    while (iss >> word) {
        ++wordCount[word];
    }
    
    std::cout << "Word frequency:" << std::endl;
    for (const auto& [w, count] : wordCount) {
        std::cout << w << ": " << count << std::endl;
    }
    
    // 两数之和
    std::vector<int> nums = {2, 7, 11, 15};
    int target = 9;
    
    std::unordered_map<int, int> numIndex;
    for (int i = 0; i < nums.size(); ++i) {
        int complement = target - nums[i];
        if (numIndex.count(complement)) {
            std::cout << "\nTwo sum: [" << numIndex[complement] 
                      << ", " << i << "]" << std::endl;
            break;
        }
        numIndex[nums[i]] = i;
    }
    
    // 字符计数
    std::string s = "hello world";
    std::unordered_map<char, int> charCount;
    for (char c : s) {
        ++charCount[c];
    }
    
    std::cout << "\nCharacter count:" << std::endl;
    for (const auto& [c, count] : charCount) {
        std::cout << "'" << c << "': " << count << std::endl;
    }
    
    return 0;
}
```

---

## 4. 哈希函数

### 4.1 标准哈希函数

```cpp
#include <iostream>
#include <functional>
#include <string>

int main() {
    // 标准库提供的哈希函数
    std::hash<int> intHash;
    std::hash<std::string> strHash;
    std::hash<double> doubleHash;
    
    std::cout << "hash(42): " << intHash(42) << std::endl;
    std::cout << "hash(\"hello\"): " << strHash("hello") << std::endl;
    std::cout << "hash(3.14): " << doubleHash(3.14) << std::endl;
    
    // 相同值产生相同哈希
    std::cout << "\nhash(\"hello\") again: " << strHash("hello") << std::endl;
    
    // 不同值通常产生不同哈希
    std::cout << "hash(\"world\"): " << strHash("world") << std::endl;
    
    return 0;
}
```

### 4.2 自定义哈希函数

```cpp
#include <iostream>
#include <unordered_set>
#include <unordered_map>

struct Point {
    int x, y;
    
    bool operator==(const Point& other) const {
        return x == other.x && y == other.y;
    }
};

// 方法 1: 特化 std::hash
namespace std {
    template<>
    struct hash<Point> {
        size_t operator()(const Point& p) const {
            return hash<int>()(p.x) ^ (hash<int>()(p.y) << 1);
        }
    };
}

// 方法 2: 自定义哈希函数对象
struct PointHash {
    size_t operator()(const Point& p) const {
        // 更好的哈希组合方式
        size_t h1 = std::hash<int>()(p.x);
        size_t h2 = std::hash<int>()(p.y);
        return h1 ^ (h2 * 0x9e3779b9 + (h1 << 6) + (h1 >> 2));
    }
};

struct PointEqual {
    bool operator()(const Point& a, const Point& b) const {
        return a.x == b.x && a.y == b.y;
    }
};

int main() {
    // 使用特化的 std::hash
    std::unordered_set<Point> points1;
    points1.insert({1, 2});
    points1.insert({3, 4});
    points1.insert({1, 2});  // 重复,不会插入
    
    std::cout << "points1 size: " << points1.size() << std::endl;
    
    // 使用自定义哈希函数
    std::unordered_set<Point, PointHash, PointEqual> points2;
    points2.insert({1, 2});
    points2.insert({3, 4});
    
    // 使用 lambda
    auto hash = [](const Point& p) {
        return std::hash<int>()(p.x) ^ std::hash<int>()(p.y);
    };
    auto equal = [](const Point& a, const Point& b) {
        return a.x == b.x && a.y == b.y;
    };
    std::unordered_set<Point, decltype(hash), decltype(equal)> points3(10, hash, equal);
    
    return 0;
}
```

### 4.3 组合哈希

```cpp
#include <iostream>
#include <unordered_map>
#include <string>
#include <tuple>

// 通用哈希组合函数
template<typename T>
inline void hash_combine(size_t& seed, const T& v) {
    std::hash<T> hasher;
    seed ^= hasher(v) + 0x9e3779b9 + (seed << 6) + (seed >> 2);
}

// 为 pair 定义哈希
struct PairHash {
    template<typename T1, typename T2>
    size_t operator()(const std::pair<T1, T2>& p) const {
        size_t seed = 0;
        hash_combine(seed, p.first);
        hash_combine(seed, p.second);
        return seed;
    }
};

// 为 tuple 定义哈希
template<typename... Args>
struct TupleHash {
    size_t operator()(const std::tuple<Args...>& t) const {
        size_t seed = 0;
        std::apply([&seed](const auto&... args) {
            (hash_combine(seed, args), ...);
        }, t);
        return seed;
    }
};

int main() {
    // pair 作为键
    std::unordered_map<std::pair<int, int>, std::string, PairHash> pairMap;
    pairMap[{1, 2}] = "one-two";
    pairMap[{3, 4}] = "three-four";
    
    std::cout << "pairMap[{1,2}]: " << pairMap[{1, 2}] << std::endl;
    
    // tuple 作为键
    using Key = std::tuple<int, std::string, double>;
    std::unordered_map<Key, int, TupleHash<int, std::string, double>> tupleMap;
    tupleMap[{1, "hello", 3.14}] = 100;
    
    std::cout << "tupleMap[{1,\"hello\",3.14}]: " 
              << tupleMap[{1, "hello", 3.14}] << std::endl;
    
    return 0;
}
```

---

## 5. 桶接口

### 5.1 桶操作

```cpp
#include <iostream>
#include <unordered_set>

int main() {
    std::unordered_set<int> us = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    
    // 桶数量
    std::cout << "bucket_count: " << us.bucket_count() << std::endl;
    
    // 最大桶数量
    std::cout << "max_bucket_count: " << us.max_bucket_count() << std::endl;
    
    // 每个桶的大小
    std::cout << "\nBucket sizes:" << std::endl;
    for (size_t i = 0; i < us.bucket_count(); ++i) {
        if (us.bucket_size(i) > 0) {
            std::cout << "  Bucket " << i << ": " << us.bucket_size(i) << " elements" << std::endl;
        }
    }
    
    // 元素所在的桶
    std::cout << "\nElement buckets:" << std::endl;
    for (int x : us) {
        std::cout << "  " << x << " is in bucket " << us.bucket(x) << std::endl;
    }
    
    // 负载因子
    std::cout << "\nload_factor: " << us.load_factor() << std::endl;
    std::cout << "max_load_factor: " << us.max_load_factor() << std::endl;
    
    return 0;
}
```

### 5.2 重哈希

```cpp
#include <iostream>
#include <unordered_set>

int main() {
    std::unordered_set<int> us;
    
    std::cout << "Initial bucket_count: " << us.bucket_count() << std::endl;
    
    // 预留桶数量
    us.reserve(100);
    std::cout << "After reserve(100): " << us.bucket_count() << std::endl;
    
    // 插入元素
    for (int i = 0; i < 50; ++i) {
        us.insert(i);
    }
    std::cout << "After 50 inserts: " << us.bucket_count() 
              << ", load_factor: " << us.load_factor() << std::endl;
    
    // 手动重哈希
    us.rehash(200);
    std::cout << "After rehash(200): " << us.bucket_count() 
              << ", load_factor: " << us.load_factor() << std::endl;
    
    // 设置最大负载因子
    us.max_load_factor(0.5);
    std::cout << "After max_load_factor(0.5): " << us.bucket_count() 
              << ", load_factor: " << us.load_factor() << std::endl;
    
    return 0;
}
```

---

## 6. 性能优化

### 6.1 预分配

```cpp
#include <iostream>
#include <unordered_map>
#include <chrono>

int main() {
    const int N = 1000000;
    
    // 不预分配
    auto start1 = std::chrono::high_resolution_clock::now();
    std::unordered_map<int, int> map1;
    for (int i = 0; i < N; ++i) {
        map1[i] = i;
    }
    auto end1 = std::chrono::high_resolution_clock::now();
    
    // 预分配
    auto start2 = std::chrono::high_resolution_clock::now();
    std::unordered_map<int, int> map2;
    map2.reserve(N);
    for (int i = 0; i < N; ++i) {
        map2[i] = i;
    }
    auto end2 = std::chrono::high_resolution_clock::now();
    
    auto duration1 = std::chrono::duration_cast<std::chrono::milliseconds>(end1 - start1);
    auto duration2 = std::chrono::duration_cast<std::chrono::milliseconds>(end2 - start2);
    
    std::cout << "Without reserve: " << duration1.count() << " ms" << std::endl;
    std::cout << "With reserve: " << duration2.count() << " ms" << std::endl;
    
    return 0;
}
```

### 6.2 选择合适的容器

```cpp
/*
选择指南:

1. 需要有序遍历: set/map
2. 只需要快速查找: unordered_set/unordered_map
3. 小数据集 (<100): 可能 vector 更快
4. 字符串键: unordered_map 通常更快
5. 整数键: 两者差异不大

性能考虑:
- unordered 容器: 平均 O(1),最坏 O(n)
- ordered 容器: 稳定 O(log n)
- 哈希冲突多时 unordered 性能下降
- 内存使用: unordered 通常更多
*/
```

---

## 7. 总结

### 7.1 无序容器对比

| 容器 | 键唯一 | 有序 | 平均查找 | 最坏查找 |
|------|--------|------|---------|---------|
| unordered_set | 是 | 否 | O(1) | O(n) |
| unordered_multiset | 否 | 否 | O(1) | O(n) |
| unordered_map | 是 | 否 | O(1) | O(n) |
| unordered_multimap | 否 | 否 | O(1) | O(n) |

### 7.2 有序 vs 无序

| 特性 | 有序容器 | 无序容器 |
|------|---------|---------|
| 实现 | 红黑树 | 哈希表 |
| 查找 | O(log n) | O(1) 平均 |
| 有序遍历 | 是 | 否 |
| 内存 | 较少 | 较多 |
| 自定义类型 | 需要 < | 需要 hash |

### 7.3 下一篇预告

在下一篇文章中,我们将学习迭代器。

---

> 作者: C++ 技术专栏  
> 系列: STL 标准模板库 (3/8)  
> 上一篇: [关联容器](./24-associative-containers.md)  
> 下一篇: [迭代器](./26-iterators.md)
