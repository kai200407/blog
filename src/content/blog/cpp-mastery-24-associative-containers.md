---
title: "关联容器"
description: "1. [关联容器概述](#1-关联容器概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 24
---

> 本文是 C++ 从入门到精通系列的第二十四篇,将深入讲解 STL 的关联容器,包括 set、multiset、map 和 multimap。

---

## 目录

1. [关联容器概述](#1-关联容器概述)
2. [set](#2-set)
3. [multiset](#3-multiset)
4. [map](#4-map)
5. [multimap](#5-multimap)
6. [自定义比较](#6-自定义比较)
7. [总结](#7-总结)

---

## 1. 关联容器概述

### 1.1 关联容器特点

```
关联容器特点:

1. 基于红黑树实现
2. 元素自动排序
3. 查找、插入、删除 O(log n)
4. 不支持随机访问
5. 迭代器遍历有序

容器类型:
- set: 有序集合,元素唯一
- multiset: 有序集合,允许重复
- map: 有序键值对,键唯一
- multimap: 有序键值对,允许重复键
```

### 1.2 通用操作

```cpp
#include <iostream>
#include <set>
#include <map>

int main() {
    std::set<int> s = {3, 1, 4, 1, 5, 9, 2, 6};
    
    // 大小
    std::cout << "size: " << s.size() << std::endl;
    std::cout << "empty: " << s.empty() << std::endl;
    
    // 查找
    auto it = s.find(4);
    if (it != s.end()) {
        std::cout << "Found: " << *it << std::endl;
    }
    
    // 计数
    std::cout << "count(1): " << s.count(1) << std::endl;
    
    // 边界
    auto lower = s.lower_bound(3);  // >= 3 的第一个
    auto upper = s.upper_bound(3);  // > 3 的第一个
    std::cout << "lower_bound(3): " << *lower << std::endl;
    std::cout << "upper_bound(3): " << *upper << std::endl;
    
    // 范围
    auto range = s.equal_range(3);
    std::cout << "equal_range(3): [" << *range.first 
              << ", " << *range.second << ")" << std::endl;
    
    // 包含 (C++20)
    // std::cout << "contains(4): " << s.contains(4) << std::endl;
    
    return 0;
}
```

---

## 2. set

### 2.1 基本操作

```cpp
#include <iostream>
#include <set>

int main() {
    // 创建
    std::set<int> s1;
    std::set<int> s2 = {3, 1, 4, 1, 5, 9};  // 重复的 1 会被忽略
    std::set<int> s3(s2);
    std::set<int> s4(s2.begin(), s2.end());
    
    // 插入
    s1.insert(10);
    s1.insert(20);
    s1.insert(30);
    
    auto result = s1.insert(20);  // 返回 pair<iterator, bool>
    if (!result.second) {
        std::cout << "20 already exists" << std::endl;
    }
    
    s1.emplace(40);  // 原地构造
    
    // 插入范围
    s1.insert({50, 60, 70});
    
    // 遍历 (有序)
    std::cout << "s1: ";
    for (int x : s1) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    // 查找
    auto it = s1.find(30);
    if (it != s1.end()) {
        std::cout << "Found: " << *it << std::endl;
    }
    
    // 删除
    s1.erase(20);           // 按值删除
    s1.erase(s1.begin());   // 按迭代器删除
    
    // 删除范围
    auto first = s1.find(40);
    auto last = s1.find(60);
    if (first != s1.end() && last != s1.end()) {
        s1.erase(first, last);
    }
    
    std::cout << "After erase: ";
    for (int x : s1) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

### 2.2 set 的应用

```cpp
#include <iostream>
#include <set>
#include <vector>
#include <algorithm>

int main() {
    // 去重
    std::vector<int> vec = {3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5};
    std::set<int> unique(vec.begin(), vec.end());
    
    std::cout << "Unique elements: ";
    for (int x : unique) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    // 集合运算
    std::set<int> a = {1, 2, 3, 4, 5};
    std::set<int> b = {4, 5, 6, 7, 8};
    
    // 交集
    std::set<int> intersection;
    std::set_intersection(a.begin(), a.end(), b.begin(), b.end(),
                          std::inserter(intersection, intersection.begin()));
    std::cout << "Intersection: ";
    for (int x : intersection) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    // 并集
    std::set<int> unionSet;
    std::set_union(a.begin(), a.end(), b.begin(), b.end(),
                   std::inserter(unionSet, unionSet.begin()));
    std::cout << "Union: ";
    for (int x : unionSet) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    // 差集
    std::set<int> difference;
    std::set_difference(a.begin(), a.end(), b.begin(), b.end(),
                        std::inserter(difference, difference.begin()));
    std::cout << "Difference (a - b): ";
    for (int x : difference) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

---

## 3. multiset

### 3.1 基本操作

```cpp
#include <iostream>
#include <set>

int main() {
    // multiset 允许重复元素
    std::multiset<int> ms = {3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5};
    
    std::cout << "multiset: ";
    for (int x : ms) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    // 计数
    std::cout << "count(5): " << ms.count(5) << std::endl;  // 3
    std::cout << "count(1): " << ms.count(1) << std::endl;  // 2
    
    // 插入 (总是成功)
    ms.insert(5);
    std::cout << "count(5) after insert: " << ms.count(5) << std::endl;  // 4
    
    // 删除所有匹配元素
    size_t removed = ms.erase(5);
    std::cout << "Removed " << removed << " elements with value 5" << std::endl;
    
    // 删除一个匹配元素
    auto it = ms.find(1);
    if (it != ms.end()) {
        ms.erase(it);  // 只删除一个
    }
    std::cout << "count(1) after erase one: " << ms.count(1) << std::endl;
    
    // equal_range 获取所有匹配元素
    ms.insert({3, 3, 3});
    auto range = ms.equal_range(3);
    std::cout << "All 3s: ";
    for (auto it = range.first; it != range.second; ++it) {
        std::cout << *it << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

---

## 4. map

### 4.1 基本操作

```cpp
#include <iostream>
#include <map>
#include <string>

int main() {
    // 创建
    std::map<std::string, int> ages;
    std::map<std::string, int> ages2 = {
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
    
    // [] 会插入不存在的键
    std::cout << "Unknown's age: " << ages2["Unknown"] << std::endl;  // 插入 0
    
    // at() 对不存在的键抛出异常
    try {
        std::cout << ages2.at("Nobody") << std::endl;
    } catch (const std::out_of_range& e) {
        std::cout << "Key not found" << std::endl;
    }
    
    // 遍历
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
    ages2.erase("Unknown");
    ages2.erase(ages2.find("Bob"));
    
    return 0;
}
```

### 4.2 map 的应用

```cpp
#include <iostream>
#include <map>
#include <string>
#include <vector>

int main() {
    // 词频统计
    std::vector<std::string> words = {
        "apple", "banana", "apple", "cherry", "banana", "apple"
    };
    
    std::map<std::string, int> wordCount;
    for (const auto& word : words) {
        ++wordCount[word];
    }
    
    std::cout << "Word frequency:" << std::endl;
    for (const auto& [word, count] : wordCount) {
        std::cout << word << ": " << count << std::endl;
    }
    
    // 分组
    std::vector<std::pair<std::string, int>> students = {
        {"Alice", 90}, {"Bob", 85}, {"Charlie", 90},
        {"David", 75}, {"Eve", 85}, {"Frank", 90}
    };
    
    std::map<int, std::vector<std::string>> scoreGroups;
    for (const auto& [name, score] : students) {
        scoreGroups[score].push_back(name);
    }
    
    std::cout << "\nScore groups:" << std::endl;
    for (const auto& [score, names] : scoreGroups) {
        std::cout << score << ": ";
        for (const auto& name : names) {
            std::cout << name << " ";
        }
        std::cout << std::endl;
    }
    
    return 0;
}
```

### 4.3 insert_or_assign 和 try_emplace (C++17)

```cpp
#include <iostream>
#include <map>
#include <string>

int main() {
    std::map<std::string, int> m = {{"a", 1}, {"b", 2}};
    
    // insert_or_assign: 插入或更新
    auto [it1, inserted1] = m.insert_or_assign("a", 100);
    std::cout << "a: " << it1->second << ", inserted: " << inserted1 << std::endl;
    
    auto [it2, inserted2] = m.insert_or_assign("c", 3);
    std::cout << "c: " << it2->second << ", inserted: " << inserted2 << std::endl;
    
    // try_emplace: 只在键不存在时插入
    auto [it3, inserted3] = m.try_emplace("a", 200);  // 不会更新
    std::cout << "a: " << it3->second << ", inserted: " << inserted3 << std::endl;
    
    auto [it4, inserted4] = m.try_emplace("d", 4);    // 会插入
    std::cout << "d: " << it4->second << ", inserted: " << inserted4 << std::endl;
    
    return 0;
}
```

---

## 5. multimap

### 5.1 基本操作

```cpp
#include <iostream>
#include <map>
#include <string>

int main() {
    // multimap 允许重复键
    std::multimap<std::string, int> scores;
    
    scores.insert({"Alice", 90});
    scores.insert({"Bob", 85});
    scores.insert({"Alice", 95});  // 允许重复键
    scores.insert({"Alice", 88});
    scores.insert({"Bob", 92});
    
    // 遍历
    std::cout << "All scores:" << std::endl;
    for (const auto& [name, score] : scores) {
        std::cout << name << ": " << score << std::endl;
    }
    
    // 计数
    std::cout << "\nAlice's score count: " << scores.count("Alice") << std::endl;
    
    // 获取某个键的所有值
    std::cout << "\nAlice's scores: ";
    auto range = scores.equal_range("Alice");
    for (auto it = range.first; it != range.second; ++it) {
        std::cout << it->second << " ";
    }
    std::cout << std::endl;
    
    // 删除某个键的所有值
    scores.erase("Alice");
    
    std::cout << "\nAfter erasing Alice:" << std::endl;
    for (const auto& [name, score] : scores) {
        std::cout << name << ": " << score << std::endl;
    }
    
    return 0;
}
```

---

## 6. 自定义比较

### 6.1 使用函数对象

```cpp
#include <iostream>
#include <set>
#include <map>
#include <string>

// 自定义比较器
struct CaseInsensitiveCompare {
    bool operator()(const std::string& a, const std::string& b) const {
        return std::lexicographical_compare(
            a.begin(), a.end(), b.begin(), b.end(),
            [](char c1, char c2) {
                return std::tolower(c1) < std::tolower(c2);
            }
        );
    }
};

// 降序比较
struct DescendingCompare {
    bool operator()(int a, int b) const {
        return a > b;
    }
};

int main() {
    // 大小写不敏感的 set
    std::set<std::string, CaseInsensitiveCompare> names;
    names.insert("Alice");
    names.insert("bob");
    names.insert("CHARLIE");
    names.insert("alice");  // 不会插入,因为已存在
    
    std::cout << "Names: ";
    for (const auto& name : names) {
        std::cout << name << " ";
    }
    std::cout << std::endl;
    
    // 降序 set
    std::set<int, DescendingCompare> descSet = {3, 1, 4, 1, 5, 9, 2, 6};
    
    std::cout << "Descending set: ";
    for (int x : descSet) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    // 使用 std::greater
    std::set<int, std::greater<int>> greaterSet = {3, 1, 4, 1, 5, 9, 2, 6};
    
    std::cout << "Greater set: ";
    for (int x : greaterSet) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

### 6.2 自定义类型

```cpp
#include <iostream>
#include <set>
#include <map>

struct Point {
    int x, y;
    
    // 方法 1: 重载 < 运算符
    bool operator<(const Point& other) const {
        if (x != other.x) return x < other.x;
        return y < other.y;
    }
};

// 方法 2: 外部比较器
struct PointCompare {
    bool operator()(const Point& a, const Point& b) const {
        if (a.x != b.x) return a.x < b.x;
        return a.y < b.y;
    }
};

int main() {
    // 使用重载的 < 运算符
    std::set<Point> points1;
    points1.insert({1, 2});
    points1.insert({3, 4});
    points1.insert({1, 3});
    
    std::cout << "Points (using operator<):" << std::endl;
    for (const auto& p : points1) {
        std::cout << "(" << p.x << ", " << p.y << ")" << std::endl;
    }
    
    // 使用外部比较器
    std::set<Point, PointCompare> points2;
    points2.insert({1, 2});
    points2.insert({3, 4});
    points2.insert({1, 3});
    
    // 使用 lambda
    auto cmp = [](const Point& a, const Point& b) {
        return a.x * a.x + a.y * a.y < b.x * b.x + b.y * b.y;
    };
    std::set<Point, decltype(cmp)> points3(cmp);
    points3.insert({1, 2});
    points3.insert({3, 4});
    points3.insert({2, 1});
    
    std::cout << "\nPoints (by distance from origin):" << std::endl;
    for (const auto& p : points3) {
        std::cout << "(" << p.x << ", " << p.y << ")" << std::endl;
    }
    
    return 0;
}
```

---

## 7. 总结

### 7.1 关联容器对比

| 容器 | 键唯一 | 有序 | 查找 | 插入 |
|------|--------|------|------|------|
| set | 是 | 是 | O(log n) | O(log n) |
| multiset | 否 | 是 | O(log n) | O(log n) |
| map | 是 | 是 | O(log n) | O(log n) |
| multimap | 否 | 是 | O(log n) | O(log n) |

### 7.2 最佳实践

```
1. 需要有序且唯一: set/map
2. 需要有序且可重复: multiset/multimap
3. 自定义类型需要定义比较
4. 使用 find() 而非 [] 检查存在性
5. 使用 emplace 代替 insert
6. 利用 lower_bound/upper_bound 进行范围查询
```

### 7.3 下一篇预告

在下一篇文章中,我们将学习无序容器 (unordered_set 和 unordered_map)。

---

> 作者: C++ 技术专栏  
> 系列: STL 标准模板库 (2/8)  
> 上一篇: [序列容器](./23-sequence-containers.md)  
> 下一篇: [无序容器](./25-unordered-containers.md)
