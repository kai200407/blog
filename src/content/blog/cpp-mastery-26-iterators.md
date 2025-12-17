---
title: "迭代器"
description: "1. [迭代器概述](#1-迭代器概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 26
---

> 本文是 C++ 从入门到精通系列的第二十六篇,将深入讲解 STL 迭代器的概念、分类和使用方法。

---

## 目录

1. [迭代器概述](#1-迭代器概述)
2. [迭代器分类](#2-迭代器分类)
3. [迭代器操作](#3-迭代器操作)
4. [迭代器适配器](#4-迭代器适配器)
5. [迭代器失效](#5-迭代器失效)
6. [自定义迭代器](#6-自定义迭代器)
7. [总结](#7-总结)

---

## 1. 迭代器概述

### 1.1 什么是迭代器

```
迭代器 (Iterator):
- 提供统一的容器遍历接口
- 类似于指针的抽象
- 连接算法和容器的桥梁

迭代器操作:
- *it: 解引用,获取元素
- ++it: 移动到下一个元素
- it1 == it2: 比较迭代器
- it1 != it2: 比较迭代器
```

### 1.2 基本使用

```cpp
#include <iostream>
#include <vector>
#include <list>
#include <set>

int main() {
    std::vector<int> vec = {1, 2, 3, 4, 5};
    
    // 使用迭代器遍历
    std::cout << "Using iterator: ";
    for (std::vector<int>::iterator it = vec.begin(); it != vec.end(); ++it) {
        std::cout << *it << " ";
    }
    std::cout << std::endl;
    
    // 使用 auto
    std::cout << "Using auto: ";
    for (auto it = vec.begin(); it != vec.end(); ++it) {
        std::cout << *it << " ";
    }
    std::cout << std::endl;
    
    // const 迭代器
    std::cout << "Using const_iterator: ";
    for (auto it = vec.cbegin(); it != vec.cend(); ++it) {
        std::cout << *it << " ";
        // *it = 10;  // 错误: 不能修改
    }
    std::cout << std::endl;
    
    // 反向迭代器
    std::cout << "Using reverse_iterator: ";
    for (auto it = vec.rbegin(); it != vec.rend(); ++it) {
        std::cout << *it << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

---

## 2. 迭代器分类

### 2.1 迭代器类别

```
迭代器类别 (从弱到强):

1. 输入迭代器 (Input Iterator)
   - 只读,单次遍历
   - 支持: ++, *, ==, !=
   - 例: istream_iterator

2. 输出迭代器 (Output Iterator)
   - 只写,单次遍历
   - 支持: ++, *
   - 例: ostream_iterator

3. 前向迭代器 (Forward Iterator)
   - 读写,多次遍历
   - 支持: ++, *, ==, !=
   - 例: forward_list::iterator

4. 双向迭代器 (Bidirectional Iterator)
   - 读写,双向遍历
   - 支持: ++, --, *, ==, !=
   - 例: list::iterator, set::iterator

5. 随机访问迭代器 (Random Access Iterator)
   - 读写,随机访问
   - 支持: ++, --, +, -, [], *, ==, !=, <, >, <=, >=
   - 例: vector::iterator, deque::iterator

6. 连续迭代器 (Contiguous Iterator, C++17)
   - 随机访问 + 连续内存
   - 例: vector::iterator, array::iterator
```

### 2.2 迭代器类别示例

```cpp
#include <iostream>
#include <vector>
#include <list>
#include <forward_list>
#include <iterator>

template<typename Iterator>
void printIteratorCategory(Iterator) {
    using category = typename std::iterator_traits<Iterator>::iterator_category;
    
    if constexpr (std::is_same_v<category, std::input_iterator_tag>) {
        std::cout << "Input Iterator" << std::endl;
    } else if constexpr (std::is_same_v<category, std::output_iterator_tag>) {
        std::cout << "Output Iterator" << std::endl;
    } else if constexpr (std::is_same_v<category, std::forward_iterator_tag>) {
        std::cout << "Forward Iterator" << std::endl;
    } else if constexpr (std::is_same_v<category, std::bidirectional_iterator_tag>) {
        std::cout << "Bidirectional Iterator" << std::endl;
    } else if constexpr (std::is_same_v<category, std::random_access_iterator_tag>) {
        std::cout << "Random Access Iterator" << std::endl;
    }
}

int main() {
    std::vector<int> vec;
    std::list<int> lst;
    std::forward_list<int> flst;
    
    std::cout << "vector: ";
    printIteratorCategory(vec.begin());
    
    std::cout << "list: ";
    printIteratorCategory(lst.begin());
    
    std::cout << "forward_list: ";
    printIteratorCategory(flst.begin());
    
    return 0;
}
```

### 2.3 各容器的迭代器类型

```
容器迭代器类型:

随机访问迭代器:
- vector
- deque
- array
- string

双向迭代器:
- list
- set/multiset
- map/multimap

前向迭代器:
- forward_list
- unordered_set/unordered_multiset
- unordered_map/unordered_multimap
```

---

## 3. 迭代器操作

### 3.1 基本操作

```cpp
#include <iostream>
#include <vector>
#include <iterator>

int main() {
    std::vector<int> vec = {10, 20, 30, 40, 50};
    
    auto it = vec.begin();
    
    // 解引用
    std::cout << "*it: " << *it << std::endl;
    
    // 前进
    ++it;
    std::cout << "After ++it: " << *it << std::endl;
    
    // 后退 (双向迭代器)
    --it;
    std::cout << "After --it: " << *it << std::endl;
    
    // 随机访问 (随机访问迭代器)
    it += 3;
    std::cout << "After it += 3: " << *it << std::endl;
    
    it -= 2;
    std::cout << "After it -= 2: " << *it << std::endl;
    
    // 下标访问
    std::cout << "it[2]: " << it[2] << std::endl;
    
    // 迭代器差
    auto it2 = vec.end();
    std::cout << "Distance: " << (it2 - it) << std::endl;
    
    // 比较
    std::cout << "it < it2: " << (it < it2) << std::endl;
    
    return 0;
}
```

### 3.2 辅助函数

```cpp
#include <iostream>
#include <vector>
#include <list>
#include <iterator>

int main() {
    std::vector<int> vec = {10, 20, 30, 40, 50};
    std::list<int> lst = {10, 20, 30, 40, 50};
    
    // std::advance: 移动迭代器
    auto it1 = vec.begin();
    std::advance(it1, 3);
    std::cout << "After advance(it1, 3): " << *it1 << std::endl;
    
    auto it2 = lst.begin();
    std::advance(it2, 3);
    std::cout << "After advance(it2, 3): " << *it2 << std::endl;
    
    // std::distance: 计算距离
    std::cout << "Distance in vec: " << std::distance(vec.begin(), it1) << std::endl;
    std::cout << "Distance in lst: " << std::distance(lst.begin(), it2) << std::endl;
    
    // std::next: 返回前进后的迭代器
    auto it3 = std::next(vec.begin(), 2);
    std::cout << "next(begin, 2): " << *it3 << std::endl;
    
    // std::prev: 返回后退后的迭代器
    auto it4 = std::prev(vec.end(), 2);
    std::cout << "prev(end, 2): " << *it4 << std::endl;
    
    // std::begin/std::end: 通用版本
    int arr[] = {1, 2, 3, 4, 5};
    std::cout << "Array begin: " << *std::begin(arr) << std::endl;
    std::cout << "Array size: " << std::distance(std::begin(arr), std::end(arr)) << std::endl;
    
    return 0;
}
```

---

## 4. 迭代器适配器

### 4.1 反向迭代器

```cpp
#include <iostream>
#include <vector>
#include <algorithm>

int main() {
    std::vector<int> vec = {1, 2, 3, 4, 5};
    
    // 反向遍历
    std::cout << "Reverse: ";
    for (auto it = vec.rbegin(); it != vec.rend(); ++it) {
        std::cout << *it << " ";
    }
    std::cout << std::endl;
    
    // 反向迭代器与正向迭代器转换
    auto rit = vec.rbegin();
    std::advance(rit, 2);
    std::cout << "*rit: " << *rit << std::endl;
    
    // base() 返回对应的正向迭代器
    auto it = rit.base();
    std::cout << "*it (base): " << *it << std::endl;
    
    // 注意: base() 指向 rit 的下一个位置
    // rit 指向 3, base() 指向 4
    
    // 使用反向迭代器排序
    std::sort(vec.rbegin(), vec.rend());  // 降序排序
    std::cout << "Descending: ";
    for (int x : vec) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

### 4.2 插入迭代器

```cpp
#include <iostream>
#include <vector>
#include <list>
#include <iterator>
#include <algorithm>

int main() {
    std::vector<int> src = {1, 2, 3, 4, 5};
    
    // back_inserter: 在末尾插入
    std::vector<int> dest1;
    std::copy(src.begin(), src.end(), std::back_inserter(dest1));
    std::cout << "back_inserter: ";
    for (int x : dest1) std::cout << x << " ";
    std::cout << std::endl;
    
    // front_inserter: 在开头插入 (需要支持 push_front)
    std::list<int> dest2;
    std::copy(src.begin(), src.end(), std::front_inserter(dest2));
    std::cout << "front_inserter: ";
    for (int x : dest2) std::cout << x << " ";
    std::cout << std::endl;
    
    // inserter: 在指定位置插入
    std::vector<int> dest3 = {10, 20, 30};
    std::copy(src.begin(), src.end(), std::inserter(dest3, dest3.begin() + 1));
    std::cout << "inserter: ";
    for (int x : dest3) std::cout << x << " ";
    std::cout << std::endl;
    
    return 0;
}
```

### 4.3 流迭代器

```cpp
#include <iostream>
#include <vector>
#include <iterator>
#include <algorithm>
#include <sstream>

int main() {
    // ostream_iterator: 输出到流
    std::vector<int> vec = {1, 2, 3, 4, 5};
    std::cout << "ostream_iterator: ";
    std::copy(vec.begin(), vec.end(), std::ostream_iterator<int>(std::cout, " "));
    std::cout << std::endl;
    
    // istream_iterator: 从流读取
    std::istringstream iss("10 20 30 40 50");
    std::vector<int> vec2;
    std::copy(std::istream_iterator<int>(iss), 
              std::istream_iterator<int>(),
              std::back_inserter(vec2));
    
    std::cout << "istream_iterator: ";
    for (int x : vec2) std::cout << x << " ";
    std::cout << std::endl;
    
    // 从标准输入读取 (示例)
    // std::vector<int> input;
    // std::copy(std::istream_iterator<int>(std::cin),
    //           std::istream_iterator<int>(),
    //           std::back_inserter(input));
    
    return 0;
}
```

### 4.4 移动迭代器

```cpp
#include <iostream>
#include <vector>
#include <string>
#include <iterator>
#include <algorithm>

int main() {
    std::vector<std::string> src = {"hello", "world", "foo", "bar"};
    
    std::cout << "Before move:" << std::endl;
    for (const auto& s : src) {
        std::cout << "  \"" << s << "\"" << std::endl;
    }
    
    // 使用移动迭代器
    std::vector<std::string> dest;
    std::copy(std::make_move_iterator(src.begin()),
              std::make_move_iterator(src.end()),
              std::back_inserter(dest));
    
    std::cout << "\nAfter move:" << std::endl;
    std::cout << "src:" << std::endl;
    for (const auto& s : src) {
        std::cout << "  \"" << s << "\"" << std::endl;  // 可能为空
    }
    
    std::cout << "dest:" << std::endl;
    for (const auto& s : dest) {
        std::cout << "  \"" << s << "\"" << std::endl;
    }
    
    return 0;
}
```

---

## 5. 迭代器失效

### 5.1 vector 迭代器失效

```cpp
#include <iostream>
#include <vector>

int main() {
    std::vector<int> vec = {1, 2, 3, 4, 5};
    
    // 情况 1: 插入导致重新分配
    auto it = vec.begin();
    std::cout << "Before insert: " << *it << std::endl;
    
    vec.reserve(100);  // 预留空间避免重新分配
    it = vec.begin();  // 重新获取迭代器
    
    // 情况 2: 插入不导致重新分配
    // 插入点之后的迭代器失效
    
    // 情况 3: 删除
    // 删除点及之后的迭代器失效
    vec = {1, 2, 3, 4, 5};
    for (auto it = vec.begin(); it != vec.end(); ) {
        if (*it % 2 == 0) {
            it = vec.erase(it);  // erase 返回下一个有效迭代器
        } else {
            ++it;
        }
    }
    
    std::cout << "After erase even: ";
    for (int x : vec) std::cout << x << " ";
    std::cout << std::endl;
    
    return 0;
}
```

### 5.2 其他容器的迭代器失效

```cpp
#include <iostream>
#include <list>
#include <map>
#include <unordered_map>

int main() {
    // list: 只有被删除元素的迭代器失效
    std::list<int> lst = {1, 2, 3, 4, 5};
    auto it1 = lst.begin();
    auto it2 = std::next(it1);
    lst.erase(it1);  // it1 失效,it2 仍有效
    std::cout << "list after erase: " << *it2 << std::endl;
    
    // map: 只有被删除元素的迭代器失效
    std::map<int, int> m = {{1, 10}, {2, 20}, {3, 30}};
    auto mit1 = m.find(1);
    auto mit2 = m.find(2);
    m.erase(mit1);  // mit1 失效,mit2 仍有效
    std::cout << "map after erase: " << mit2->second << std::endl;
    
    // unordered_map: 重哈希时所有迭代器失效
    std::unordered_map<int, int> um;
    um.reserve(100);  // 预留空间避免重哈希
    for (int i = 0; i < 50; ++i) {
        um[i] = i * 10;
    }
    
    return 0;
}
```

### 5.3 安全删除模式

```cpp
#include <iostream>
#include <vector>
#include <list>
#include <map>
#include <algorithm>

int main() {
    // 方法 1: 使用 erase 返回值
    std::vector<int> vec = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    for (auto it = vec.begin(); it != vec.end(); ) {
        if (*it % 2 == 0) {
            it = vec.erase(it);
        } else {
            ++it;
        }
    }
    
    // 方法 2: 使用 remove_if + erase (erase-remove idiom)
    vec = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    vec.erase(std::remove_if(vec.begin(), vec.end(), 
                             [](int x) { return x % 2 == 0; }),
              vec.end());
    
    // 方法 3: C++20 std::erase_if
    // std::erase_if(vec, [](int x) { return x % 2 == 0; });
    
    std::cout << "After remove even: ";
    for (int x : vec) std::cout << x << " ";
    std::cout << std::endl;
    
    return 0;
}
```

---

## 6. 自定义迭代器

### 6.1 简单迭代器

```cpp
#include <iostream>
#include <iterator>

template<typename T>
class Range {
public:
    class Iterator {
    public:
        using iterator_category = std::forward_iterator_tag;
        using value_type = T;
        using difference_type = std::ptrdiff_t;
        using pointer = T*;
        using reference = T&;
        
        Iterator(T value) : value(value) { }
        
        T operator*() const { return value; }
        
        Iterator& operator++() {
            ++value;
            return *this;
        }
        
        Iterator operator++(int) {
            Iterator tmp = *this;
            ++value;
            return tmp;
        }
        
        bool operator==(const Iterator& other) const {
            return value == other.value;
        }
        
        bool operator!=(const Iterator& other) const {
            return value != other.value;
        }
        
    private:
        T value;
    };
    
    Range(T start, T end) : start(start), end_(end) { }
    
    Iterator begin() const { return Iterator(start); }
    Iterator end() const { return Iterator(end_); }
    
private:
    T start;
    T end_;
};

int main() {
    std::cout << "Range(1, 10): ";
    for (int x : Range<int>(1, 10)) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

### 6.2 容器迭代器

```cpp
#include <iostream>
#include <iterator>
#include <stdexcept>

template<typename T, size_t N>
class FixedArray {
public:
    class Iterator {
    public:
        using iterator_category = std::random_access_iterator_tag;
        using value_type = T;
        using difference_type = std::ptrdiff_t;
        using pointer = T*;
        using reference = T&;
        
        Iterator(pointer ptr) : ptr(ptr) { }
        
        reference operator*() const { return *ptr; }
        pointer operator->() const { return ptr; }
        reference operator[](difference_type n) const { return ptr[n]; }
        
        Iterator& operator++() { ++ptr; return *this; }
        Iterator operator++(int) { Iterator tmp = *this; ++ptr; return tmp; }
        Iterator& operator--() { --ptr; return *this; }
        Iterator operator--(int) { Iterator tmp = *this; --ptr; return tmp; }
        
        Iterator& operator+=(difference_type n) { ptr += n; return *this; }
        Iterator& operator-=(difference_type n) { ptr -= n; return *this; }
        
        Iterator operator+(difference_type n) const { return Iterator(ptr + n); }
        Iterator operator-(difference_type n) const { return Iterator(ptr - n); }
        difference_type operator-(const Iterator& other) const { return ptr - other.ptr; }
        
        bool operator==(const Iterator& other) const { return ptr == other.ptr; }
        bool operator!=(const Iterator& other) const { return ptr != other.ptr; }
        bool operator<(const Iterator& other) const { return ptr < other.ptr; }
        bool operator>(const Iterator& other) const { return ptr > other.ptr; }
        bool operator<=(const Iterator& other) const { return ptr <= other.ptr; }
        bool operator>=(const Iterator& other) const { return ptr >= other.ptr; }
        
    private:
        pointer ptr;
    };
    
    using iterator = Iterator;
    using const_iterator = Iterator;  // 简化版本
    
    T& operator[](size_t index) { return data[index]; }
    const T& operator[](size_t index) const { return data[index]; }
    
    size_t size() const { return N; }
    
    iterator begin() { return Iterator(data); }
    iterator end() { return Iterator(data + N); }
    
private:
    T data[N];
};

int main() {
    FixedArray<int, 5> arr;
    for (size_t i = 0; i < arr.size(); ++i) {
        arr[i] = (i + 1) * 10;
    }
    
    std::cout << "FixedArray: ";
    for (int x : arr) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    // 使用算法
    auto it = std::find(arr.begin(), arr.end(), 30);
    if (it != arr.end()) {
        std::cout << "Found 30 at index: " << (it - arr.begin()) << std::endl;
    }
    
    return 0;
}
```

---

## 7. 总结

### 7.1 迭代器类别

| 类别 | 操作 | 容器示例 |
|------|------|---------|
| 输入 | ++, *, == | istream_iterator |
| 输出 | ++, * | ostream_iterator |
| 前向 | ++, *, == | forward_list |
| 双向 | ++, --, *, == | list, set, map |
| 随机访问 | ++, --, +, -, [], *, ==, < | vector, deque |

### 7.2 最佳实践

```
1. 使用 auto 简化迭代器声明
2. 优先使用范围 for 循环
3. 注意迭代器失效问题
4. 使用 std::advance/std::distance
5. 选择合适的迭代器适配器
```

### 7.3 下一篇预告

在下一篇文章中,我们将学习 STL 算法。

---

> 作者: C++ 技术专栏  
> 系列: STL 标准模板库 (4/8)  
> 上一篇: [无序容器](./25-unordered-containers.md)  
> 下一篇: [STL 算法](./27-algorithms.md)
