---
title: "序列容器"
description: "1. [STL 容器概述](#1-stl-容器概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 23
---

> 本文是 C++ 从入门到精通系列的第二十三篇,将深入讲解 STL 的序列容器,包括 vector、deque、list、array 和 forward_list。

---

## 目录

1. [STL 容器概述](#1-stl-容器概述)
2. [vector](#2-vector)
3. [deque](#3-deque)
4. [list](#4-list)
5. [array](#5-array)
6. [forward_list](#6-forward_list)
7. [容器选择](#7-容器选择)
8. [总结](#8-总结)

---

## 1. STL 容器概述

### 1.1 容器分类

```
STL 容器分类:

1. 序列容器 (Sequence Containers)
   - vector: 动态数组
   - deque: 双端队列
   - list: 双向链表
   - forward_list: 单向链表
   - array: 固定大小数组

2. 关联容器 (Associative Containers)
   - set/multiset: 有序集合
   - map/multimap: 有序映射

3. 无序容器 (Unordered Containers)
   - unordered_set/unordered_multiset
   - unordered_map/unordered_multimap

4. 容器适配器 (Container Adapters)
   - stack: 栈
   - queue: 队列
   - priority_queue: 优先队列
```

### 1.2 通用操作

```cpp
#include <iostream>
#include <vector>

int main() {
    std::vector<int> vec = {1, 2, 3, 4, 5};
    
    // 大小相关
    std::cout << "size: " << vec.size() << std::endl;
    std::cout << "empty: " << vec.empty() << std::endl;
    std::cout << "max_size: " << vec.max_size() << std::endl;
    
    // 迭代器
    for (auto it = vec.begin(); it != vec.end(); ++it) {
        std::cout << *it << " ";
    }
    std::cout << std::endl;
    
    // 范围 for
    for (const auto& x : vec) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    // 比较
    std::vector<int> vec2 = {1, 2, 3, 4, 5};
    std::cout << "equal: " << (vec == vec2) << std::endl;
    
    // 交换
    std::vector<int> vec3 = {10, 20, 30};
    vec.swap(vec3);
    
    // 清空
    vec.clear();
    
    return 0;
}
```

---

## 2. vector

### 2.1 基本操作

```cpp
#include <iostream>
#include <vector>

int main() {
    // 创建
    std::vector<int> v1;                    // 空 vector
    std::vector<int> v2(5);                 // 5 个 0
    std::vector<int> v3(5, 10);             // 5 个 10
    std::vector<int> v4 = {1, 2, 3, 4, 5};  // 初始化列表
    std::vector<int> v5(v4);                // 拷贝
    std::vector<int> v6(v4.begin(), v4.end()); // 迭代器范围
    
    // 访问元素
    std::cout << "v4[0]: " << v4[0] << std::endl;
    std::cout << "v4.at(1): " << v4.at(1) << std::endl;
    std::cout << "v4.front(): " << v4.front() << std::endl;
    std::cout << "v4.back(): " << v4.back() << std::endl;
    std::cout << "v4.data(): " << v4.data() << std::endl;
    
    // 修改
    v4[0] = 100;
    v4.at(1) = 200;
    
    // 添加元素
    v1.push_back(1);
    v1.push_back(2);
    v1.emplace_back(3);  // 原地构造
    
    // 插入
    v1.insert(v1.begin(), 0);           // 在开头插入
    v1.insert(v1.end(), 4);             // 在末尾插入
    v1.insert(v1.begin() + 2, 10);      // 在位置 2 插入
    v1.insert(v1.end(), {5, 6, 7});     // 插入多个
    
    // 删除
    v1.pop_back();                       // 删除末尾
    v1.erase(v1.begin());               // 删除开头
    v1.erase(v1.begin(), v1.begin() + 2); // 删除范围
    
    // 调整大小
    v1.resize(10);       // 扩展到 10 个元素
    v1.resize(5);        // 缩小到 5 个元素
    v1.resize(8, 100);   // 扩展,新元素为 100
    
    // 打印
    for (int x : v1) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

### 2.2 容量管理

```cpp
#include <iostream>
#include <vector>

int main() {
    std::vector<int> vec;
    
    std::cout << "Initial - size: " << vec.size() 
              << ", capacity: " << vec.capacity() << std::endl;
    
    // 预留空间
    vec.reserve(100);
    std::cout << "After reserve(100) - size: " << vec.size() 
              << ", capacity: " << vec.capacity() << std::endl;
    
    // 添加元素
    for (int i = 0; i < 50; ++i) {
        vec.push_back(i);
    }
    std::cout << "After 50 push_back - size: " << vec.size() 
              << ", capacity: " << vec.capacity() << std::endl;
    
    // 收缩到适合大小
    vec.shrink_to_fit();
    std::cout << "After shrink_to_fit - size: " << vec.size() 
              << ", capacity: " << vec.capacity() << std::endl;
    
    // 容量增长策略 (通常是 1.5x 或 2x)
    std::vector<int> vec2;
    for (int i = 0; i < 20; ++i) {
        size_t oldCap = vec2.capacity();
        vec2.push_back(i);
        if (vec2.capacity() != oldCap) {
            std::cout << "Capacity changed: " << oldCap 
                      << " -> " << vec2.capacity() << std::endl;
        }
    }
    
    return 0;
}
```

### 2.3 vector<bool> 特化

```cpp
#include <iostream>
#include <vector>
#include <bitset>

int main() {
    // vector<bool> 是特化版本,每个 bool 只占 1 bit
    std::vector<bool> flags(8, false);
    flags[0] = true;
    flags[3] = true;
    flags[7] = true;
    
    for (bool b : flags) {
        std::cout << b;
    }
    std::cout << std::endl;
    
    // 注意: vector<bool> 的引用行为不同
    // auto& ref = flags[0];  // 这不是真正的引用!
    
    // 如果需要真正的 bool 数组,使用 deque<bool> 或 bitset
    std::bitset<8> bits;
    bits[0] = 1;
    bits[3] = 1;
    bits[7] = 1;
    std::cout << bits << std::endl;
    
    return 0;
}
```

---

## 3. deque

### 3.1 基本操作

```cpp
#include <iostream>
#include <deque>

int main() {
    // 创建
    std::deque<int> dq = {1, 2, 3, 4, 5};
    
    // 两端操作
    dq.push_front(0);    // 前端添加
    dq.push_back(6);     // 后端添加
    dq.emplace_front(-1);
    dq.emplace_back(7);
    
    std::cout << "After push: ";
    for (int x : dq) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    dq.pop_front();      // 前端删除
    dq.pop_back();       // 后端删除
    
    std::cout << "After pop: ";
    for (int x : dq) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    // 随机访问
    std::cout << "dq[0]: " << dq[0] << std::endl;
    std::cout << "dq.at(1): " << dq.at(1) << std::endl;
    std::cout << "dq.front(): " << dq.front() << std::endl;
    std::cout << "dq.back(): " << dq.back() << std::endl;
    
    // 插入和删除
    dq.insert(dq.begin() + 2, 100);
    dq.erase(dq.begin() + 2);
    
    return 0;
}
```

### 3.2 deque vs vector

```
deque vs vector:

vector:
- 连续内存
- 尾部操作 O(1)
- 头部操作 O(n)
- 更好的缓存局部性

deque:
- 分段连续内存
- 两端操作 O(1)
- 中间插入 O(n)
- 不保证连续内存

选择建议:
- 只需尾部操作: vector
- 需要两端操作: deque
- 需要连续内存: vector
```

---

## 4. list

### 4.1 基本操作

```cpp
#include <iostream>
#include <list>

int main() {
    // 创建
    std::list<int> lst = {1, 2, 3, 4, 5};
    
    // 两端操作
    lst.push_front(0);
    lst.push_back(6);
    lst.emplace_front(-1);
    lst.emplace_back(7);
    
    // 遍历 (不支持随机访问)
    std::cout << "List: ";
    for (int x : lst) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    // 访问首尾
    std::cout << "front: " << lst.front() << std::endl;
    std::cout << "back: " << lst.back() << std::endl;
    
    // 插入
    auto it = lst.begin();
    std::advance(it, 3);  // 移动迭代器
    lst.insert(it, 100);
    
    // 删除
    lst.pop_front();
    lst.pop_back();
    lst.erase(it);
    
    // 删除特定值
    lst.remove(3);
    
    // 删除满足条件的元素
    lst.remove_if([](int x) { return x < 0; });
    
    std::cout << "After operations: ";
    for (int x : lst) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

### 4.2 list 特有操作

```cpp
#include <iostream>
#include <list>

void printList(const std::list<int>& lst, const std::string& name) {
    std::cout << name << ": ";
    for (int x : lst) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
}

int main() {
    std::list<int> lst1 = {1, 3, 5, 7, 9};
    std::list<int> lst2 = {2, 4, 6, 8, 10};
    
    // 合并 (两个列表必须已排序)
    lst1.merge(lst2);
    printList(lst1, "After merge");
    printList(lst2, "lst2 (empty)");
    
    // 拼接
    std::list<int> lst3 = {100, 200, 300};
    auto it = lst1.begin();
    std::advance(it, 5);
    lst1.splice(it, lst3);  // 将 lst3 插入到 it 位置
    printList(lst1, "After splice");
    
    // 反转
    lst1.reverse();
    printList(lst1, "After reverse");
    
    // 排序
    lst1.sort();
    printList(lst1, "After sort");
    
    // 去重 (必须先排序)
    std::list<int> lst4 = {1, 1, 2, 2, 2, 3, 3, 4};
    lst4.unique();
    printList(lst4, "After unique");
    
    return 0;
}
```

---

## 5. array

### 5.1 基本操作

```cpp
#include <iostream>
#include <array>
#include <algorithm>

int main() {
    // 创建
    std::array<int, 5> arr1 = {1, 2, 3, 4, 5};
    std::array<int, 5> arr2{};  // 全部初始化为 0
    std::array<int, 5> arr3;    // 未初始化
    
    // 大小
    std::cout << "size: " << arr1.size() << std::endl;
    std::cout << "max_size: " << arr1.max_size() << std::endl;
    std::cout << "empty: " << arr1.empty() << std::endl;
    
    // 访问
    std::cout << "arr1[0]: " << arr1[0] << std::endl;
    std::cout << "arr1.at(1): " << arr1.at(1) << std::endl;
    std::cout << "arr1.front(): " << arr1.front() << std::endl;
    std::cout << "arr1.back(): " << arr1.back() << std::endl;
    std::cout << "arr1.data(): " << arr1.data() << std::endl;
    
    // 修改
    arr1[0] = 100;
    arr1.at(1) = 200;
    
    // 填充
    arr2.fill(42);
    
    // 交换
    arr1.swap(arr2);
    
    // 迭代
    for (const auto& x : arr1) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    // 算法
    std::sort(arr1.begin(), arr1.end());
    
    // 获取元素 (编译时)
    std::cout << "get<0>: " << std::get<0>(arr1) << std::endl;
    
    return 0;
}
```

### 5.2 array vs C 数组

```cpp
#include <iostream>
#include <array>

// C 数组作为参数会退化为指针
void cArrayFunc(int arr[], size_t size) {
    // sizeof(arr) 是指针大小,不是数组大小
}

// std::array 保留大小信息
template<size_t N>
void stdArrayFunc(std::array<int, N>& arr) {
    std::cout << "Array size: " << arr.size() << std::endl;
}

int main() {
    int cArr[5] = {1, 2, 3, 4, 5};
    std::array<int, 5> stdArr = {1, 2, 3, 4, 5};
    
    // C 数组
    std::cout << "sizeof(cArr): " << sizeof(cArr) << std::endl;  // 20
    
    // std::array
    std::cout << "sizeof(stdArr): " << sizeof(stdArr) << std::endl;  // 20
    std::cout << "stdArr.size(): " << stdArr.size() << std::endl;    // 5
    
    // 边界检查
    try {
        stdArr.at(10) = 100;  // 抛出异常
    } catch (const std::out_of_range& e) {
        std::cout << "Out of range: " << e.what() << std::endl;
    }
    
    stdArrayFunc(stdArr);
    
    return 0;
}
```

---

## 6. forward_list

### 6.1 基本操作

```cpp
#include <iostream>
#include <forward_list>

int main() {
    // 创建
    std::forward_list<int> flist = {1, 2, 3, 4, 5};
    
    // 只能在前端操作
    flist.push_front(0);
    flist.emplace_front(-1);
    
    // 遍历
    std::cout << "Forward list: ";
    for (int x : flist) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    // 访问首元素
    std::cout << "front: " << flist.front() << std::endl;
    
    // 在某位置后插入
    auto it = flist.begin();
    flist.insert_after(it, 100);
    
    // 在开头前插入
    flist.insert_after(flist.before_begin(), -100);
    
    // 删除某位置后的元素
    flist.erase_after(flist.begin());
    
    // 删除首元素
    flist.pop_front();
    
    std::cout << "After operations: ";
    for (int x : flist) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    // 特有操作
    flist.reverse();
    flist.sort();
    flist.unique();
    
    return 0;
}
```

### 6.2 forward_list vs list

```
forward_list vs list:

forward_list:
- 单向链表
- 每个节点只有一个指针
- 内存更小
- 只能向前遍历
- 没有 size() 方法

list:
- 双向链表
- 每个节点有两个指针
- 可以双向遍历
- 有 size() 方法

选择建议:
- 只需向前遍历且内存敏感: forward_list
- 需要双向遍历或频繁查询大小: list
```

---

## 7. 容器选择

### 7.1 性能对比

```
操作复杂度对比:

操作          vector    deque     list      forward_list   array
─────────────────────────────────────────────────────────────────
随机访问      O(1)      O(1)      O(n)      O(n)           O(1)
头部插入      O(n)      O(1)      O(1)      O(1)           -
尾部插入      O(1)*     O(1)      O(1)      O(n)           -
中间插入      O(n)      O(n)      O(1)      O(1)           -
头部删除      O(n)      O(1)      O(1)      O(1)           -
尾部删除      O(1)      O(1)      O(1)      O(n)           -
中间删除      O(n)      O(n)      O(1)      O(1)           -

* 均摊复杂度
```

### 7.2 选择指南

```cpp
/*
容器选择指南:

1. 默认选择 vector
   - 连续内存,缓存友好
   - 随机访问快
   - 尾部操作高效

2. 需要两端操作: deque
   - 头尾都需要快速插入/删除

3. 频繁中间插入/删除: list
   - 不需要随机访问
   - 迭代器稳定性重要

4. 固定大小: array
   - 编译时已知大小
   - 替代 C 风格数组

5. 内存敏感的单向链表: forward_list
   - 只需向前遍历
   - 每个节点节省一个指针
*/
```

---

## 8. 总结

### 8.1 序列容器对比

| 容器 | 内存 | 随机访问 | 两端操作 | 中间操作 |
|------|------|---------|---------|---------|
| vector | 连续 | O(1) | 尾O(1) | O(n) |
| deque | 分段 | O(1) | O(1) | O(n) |
| list | 分散 | O(n) | O(1) | O(1) |
| forward_list | 分散 | O(n) | 头O(1) | O(1) |
| array | 连续 | O(1) | - | - |

### 8.2 最佳实践

```
1. 默认使用 vector
2. 预分配空间 (reserve)
3. 使用 emplace 代替 push
4. 避免在循环中调用 size()
5. 使用范围 for 循环
6. 考虑迭代器失效
```

### 8.3 下一篇预告

在下一篇文章中,我们将学习关联容器 (set 和 map)。

---

> 作者: C++ 技术专栏  
> 系列: STL 标准模板库 (1/8)  
> 上一篇: [内存调试与泄漏检测](../part3-memory/22-memory-debugging.md)  
> 下一篇: [关联容器](./24-associative-containers.md)
