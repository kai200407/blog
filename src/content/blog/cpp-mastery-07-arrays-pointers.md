---
title: "数组与指针基础"
description: "1. [数组基础](#1-数组基础)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 7
---

> 本文是 C++ 从入门到精通系列的第七篇,将深入讲解 C++ 的数组、指针以及它们之间的关系。

---

## 目录

1. [数组基础](#1-数组基础)
2. [多维数组](#2-多维数组)
3. [指针基础](#3-指针基础)
4. [指针运算](#4-指针运算)
5. [数组与指针的关系](#5-数组与指针的关系)
6. [指针与 const](#6-指针与-const)
7. [现代 C++ 替代方案](#7-现代-c-替代方案)
8. [总结](#8-总结)

---

## 1. 数组基础

### 1.1 数组声明与初始化

```cpp
#include <iostream>

int main() {
    // 声明数组
    int arr1[5];  // 未初始化,包含垃圾值
    
    // 初始化数组
    int arr2[5] = {1, 2, 3, 4, 5};
    
    // 部分初始化 (其余为 0)
    int arr3[5] = {1, 2};  // {1, 2, 0, 0, 0}
    
    // 全部初始化为 0
    int arr4[5] = {};
    int arr5[5] = {0};
    
    // 自动推断大小
    int arr6[] = {1, 2, 3, 4, 5};  // 大小为 5
    
    // C++11 统一初始化
    int arr7[5]{1, 2, 3, 4, 5};
    
    // 打印数组
    for (int i = 0; i < 5; ++i) {
        std::cout << arr2[i] << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

### 1.2 数组访问

```cpp
#include <iostream>

int main() {
    int arr[5] = {10, 20, 30, 40, 50};
    
    // 下标访问
    std::cout << "arr[0] = " << arr[0] << std::endl;
    std::cout << "arr[4] = " << arr[4] << std::endl;
    
    // 修改元素
    arr[2] = 100;
    
    // 遍历数组
    for (int i = 0; i < 5; ++i) {
        std::cout << arr[i] << " ";
    }
    std::cout << std::endl;
    
    // 范围 for 循环 (C++11)
    for (int x : arr) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    // 注意: 数组越界是未定义行为
    // arr[5] = 100;  // 危险!
    // arr[-1] = 100; // 危险!
    
    return 0;
}
```

### 1.3 数组大小

```cpp
#include <iostream>
#include <iterator>

int main() {
    int arr[10] = {1, 2, 3, 4, 5};
    
    // 方法 1: sizeof
    size_t size1 = sizeof(arr) / sizeof(arr[0]);
    std::cout << "Size (sizeof): " << size1 << std::endl;
    
    // 方法 2: std::size (C++17)
    size_t size2 = std::size(arr);
    std::cout << "Size (std::size): " << size2 << std::endl;
    
    // 方法 3: std::end - std::begin
    size_t size3 = std::end(arr) - std::begin(arr);
    std::cout << "Size (end-begin): " << size3 << std::endl;
    
    // 注意: 数组作为参数时会退化为指针
    // 此时无法获取大小
    
    return 0;
}
```

---

## 2. 多维数组

### 2.1 二维数组

```cpp
#include <iostream>

int main() {
    // 声明二维数组
    int matrix[3][4];
    
    // 初始化
    int matrix2[3][4] = {
        {1, 2, 3, 4},
        {5, 6, 7, 8},
        {9, 10, 11, 12}
    };
    
    // 部分初始化
    int matrix3[3][4] = {
        {1, 2},
        {5}
    };
    
    // 访问元素
    std::cout << "matrix2[1][2] = " << matrix2[1][2] << std::endl;  // 7
    
    // 遍历
    for (int i = 0; i < 3; ++i) {
        for (int j = 0; j < 4; ++j) {
            std::cout << matrix2[i][j] << "\t";
        }
        std::cout << std::endl;
    }
    
    // 范围 for 循环
    for (const auto& row : matrix2) {
        for (int val : row) {
            std::cout << val << "\t";
        }
        std::cout << std::endl;
    }
    
    return 0;
}
```

### 2.2 多维数组内存布局

```
二维数组内存布局 (行优先):

int arr[2][3] = {{1, 2, 3}, {4, 5, 6}};

内存中连续存储:
+---+---+---+---+---+---+
| 1 | 2 | 3 | 4 | 5 | 6 |
+---+---+---+---+---+---+
  ^           ^
  arr[0]      arr[1]

arr[i][j] 的地址 = arr + i * 列数 + j
```

### 2.3 三维数组

```cpp
#include <iostream>

int main() {
    // 三维数组
    int cube[2][3][4] = {
        {
            {1, 2, 3, 4},
            {5, 6, 7, 8},
            {9, 10, 11, 12}
        },
        {
            {13, 14, 15, 16},
            {17, 18, 19, 20},
            {21, 22, 23, 24}
        }
    };
    
    // 访问
    std::cout << "cube[1][2][3] = " << cube[1][2][3] << std::endl;  // 24
    
    // 遍历
    for (int i = 0; i < 2; ++i) {
        for (int j = 0; j < 3; ++j) {
            for (int k = 0; k < 4; ++k) {
                std::cout << cube[i][j][k] << " ";
            }
            std::cout << std::endl;
        }
        std::cout << "---" << std::endl;
    }
    
    return 0;
}
```

---

## 3. 指针基础

### 3.1 指针声明与初始化

```cpp
#include <iostream>

int main() {
    int value = 42;
    
    // 声明指针
    int* ptr;  // 未初始化,危险!
    
    // 初始化为变量地址
    int* ptr1 = &value;
    
    // 初始化为空指针
    int* ptr2 = nullptr;  // C++11
    int* ptr3 = NULL;     // C 风格
    int* ptr4 = 0;        // 旧风格
    
    // 解引用
    std::cout << "value = " << value << std::endl;
    std::cout << "*ptr1 = " << *ptr1 << std::endl;
    std::cout << "ptr1 = " << ptr1 << std::endl;
    std::cout << "&value = " << &value << std::endl;
    
    // 通过指针修改值
    *ptr1 = 100;
    std::cout << "value = " << value << std::endl;  // 100
    
    return 0;
}
```

### 3.2 指针类型

```cpp
#include <iostream>

int main() {
    // 不同类型的指针
    int i = 10;
    double d = 3.14;
    char c = 'A';
    
    int* pi = &i;
    double* pd = &d;
    char* pc = &c;
    
    // 指针大小 (与类型无关,取决于平台)
    std::cout << "sizeof(int*) = " << sizeof(int*) << std::endl;
    std::cout << "sizeof(double*) = " << sizeof(double*) << std::endl;
    std::cout << "sizeof(char*) = " << sizeof(char*) << std::endl;
    
    // void 指针 (通用指针)
    void* vp = &i;
    vp = &d;
    vp = &c;
    
    // void 指针需要转换才能解引用
    // int val = *vp;  // 错误
    int val = *static_cast<int*>(vp);  // 需要转换
    
    return 0;
}
```

### 3.3 指针与引用

```cpp
#include <iostream>

int main() {
    int value = 42;
    
    // 指针
    int* ptr = &value;
    *ptr = 100;
    
    // 引用
    int& ref = value;
    ref = 200;
    
    std::cout << "value = " << value << std::endl;  // 200
    
    // 区别:
    // 1. 引用必须初始化,指针可以不初始化
    // 2. 引用不能重新绑定,指针可以
    // 3. 引用不能为空,指针可以
    // 4. 引用使用更简洁
    
    int other = 50;
    ptr = &other;  // 指针可以指向其他变量
    // ref = other;  // 这是赋值,不是重新绑定
    
    return 0;
}
```

---

## 4. 指针运算

### 4.1 指针算术

```cpp
#include <iostream>

int main() {
    int arr[5] = {10, 20, 30, 40, 50};
    int* ptr = arr;
    
    // 指针加法
    std::cout << "*ptr = " << *ptr << std::endl;        // 10
    std::cout << "*(ptr+1) = " << *(ptr+1) << std::endl; // 20
    std::cout << "*(ptr+2) = " << *(ptr+2) << std::endl; // 30
    
    // 指针自增
    ptr++;
    std::cout << "*ptr = " << *ptr << std::endl;  // 20
    
    // 指针减法
    ptr--;
    std::cout << "*ptr = " << *ptr << std::endl;  // 10
    
    // 两个指针相减
    int* start = arr;
    int* end = arr + 5;
    std::cout << "end - start = " << (end - start) << std::endl;  // 5
    
    // 指针比较
    if (start < end) {
        std::cout << "start < end" << std::endl;
    }
    
    return 0;
}
```

### 4.2 指针与下标

```cpp
#include <iostream>

int main() {
    int arr[5] = {10, 20, 30, 40, 50};
    int* ptr = arr;
    
    // 以下表达式等价
    std::cout << arr[2] << std::endl;      // 30
    std::cout << *(arr + 2) << std::endl;  // 30
    std::cout << ptr[2] << std::endl;      // 30
    std::cout << *(ptr + 2) << std::endl;  // 30
    std::cout << 2[arr] << std::endl;      // 30 (奇怪但合法)
    
    // 使用指针遍历数组
    for (int* p = arr; p < arr + 5; ++p) {
        std::cout << *p << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

### 4.3 指针运算规则

```
指针运算规则:

1. ptr + n: 向后移动 n 个元素
   实际地址: ptr + n * sizeof(*ptr)

2. ptr - n: 向前移动 n 个元素

3. ptr1 - ptr2: 两指针之间的元素个数
   (必须指向同一数组)

4. 指针比较: <, >, <=, >=, ==, !=
   (必须指向同一数组或空指针)

5. 不能进行指针加法 (ptr1 + ptr2 无意义)
```

---

## 5. 数组与指针的关系

### 5.1 数组名与指针

```cpp
#include <iostream>

int main() {
    int arr[5] = {10, 20, 30, 40, 50};
    
    // 数组名在大多数情况下退化为指向首元素的指针
    int* ptr = arr;  // 等价于 int* ptr = &arr[0];
    
    std::cout << "arr = " << arr << std::endl;
    std::cout << "&arr[0] = " << &arr[0] << std::endl;
    std::cout << "ptr = " << ptr << std::endl;
    
    // 但数组名不是指针
    std::cout << "sizeof(arr) = " << sizeof(arr) << std::endl;  // 20 (5 * 4)
    std::cout << "sizeof(ptr) = " << sizeof(ptr) << std::endl;  // 8 (64位)
    
    // &arr 是指向整个数组的指针
    int (*arrPtr)[5] = &arr;
    std::cout << "sizeof(*arrPtr) = " << sizeof(*arrPtr) << std::endl;  // 20
    
    return 0;
}
```

### 5.2 数组作为函数参数

```cpp
#include <iostream>

// 以下三种声明等价
void func1(int arr[]) {
    // arr 是指针,不是数组
    std::cout << "sizeof(arr) in func1 = " << sizeof(arr) << std::endl;  // 8
}

void func2(int arr[10]) {
    // 10 被忽略,arr 仍是指针
    std::cout << "sizeof(arr) in func2 = " << sizeof(arr) << std::endl;  // 8
}

void func3(int* arr) {
    // 明确是指针
    std::cout << "sizeof(arr) in func3 = " << sizeof(arr) << std::endl;  // 8
}

// 传递数组引用 (保留大小信息)
void func4(int (&arr)[5]) {
    std::cout << "sizeof(arr) in func4 = " << sizeof(arr) << std::endl;  // 20
}

int main() {
    int arr[5] = {1, 2, 3, 4, 5};
    
    func1(arr);
    func2(arr);
    func3(arr);
    func4(arr);
    
    return 0;
}
```

### 5.3 指向数组的指针

```cpp
#include <iostream>

int main() {
    int arr[5] = {1, 2, 3, 4, 5};
    
    // 指向 int 的指针
    int* ptr1 = arr;
    
    // 指向包含 5 个 int 的数组的指针
    int (*ptr2)[5] = &arr;
    
    std::cout << "*ptr1 = " << *ptr1 << std::endl;        // 1
    std::cout << "(*ptr2)[0] = " << (*ptr2)[0] << std::endl;  // 1
    
    // 二维数组
    int matrix[3][4] = {
        {1, 2, 3, 4},
        {5, 6, 7, 8},
        {9, 10, 11, 12}
    };
    
    // 指向包含 4 个 int 的数组的指针
    int (*rowPtr)[4] = matrix;
    
    std::cout << "rowPtr[1][2] = " << rowPtr[1][2] << std::endl;  // 7
    
    return 0;
}
```

---

## 6. 指针与 const

### 6.1 const 与指针

```cpp
#include <iostream>

int main() {
    int value = 10;
    int other = 20;
    
    // 1. 指向常量的指针 (不能通过指针修改值)
    const int* ptr1 = &value;
    // *ptr1 = 20;  // 错误
    ptr1 = &other;  // OK
    
    // 2. 常量指针 (不能改变指向)
    int* const ptr2 = &value;
    *ptr2 = 20;     // OK
    // ptr2 = &other;  // 错误
    
    // 3. 指向常量的常量指针
    const int* const ptr3 = &value;
    // *ptr3 = 20;     // 错误
    // ptr3 = &other;  // 错误
    
    // 记忆技巧: const 在 * 左边修饰数据,在 * 右边修饰指针
    
    return 0;
}
```

### 6.2 const 指针与函数

```cpp
#include <iostream>

// 不修改数组内容
void printArray(const int* arr, int size) {
    for (int i = 0; i < size; ++i) {
        std::cout << arr[i] << " ";
        // arr[i] = 0;  // 错误: 不能修改
    }
    std::cout << std::endl;
}

// 可以修改数组内容
void doubleArray(int* arr, int size) {
    for (int i = 0; i < size; ++i) {
        arr[i] *= 2;
    }
}

int main() {
    int arr[] = {1, 2, 3, 4, 5};
    int size = sizeof(arr) / sizeof(arr[0]);
    
    printArray(arr, size);
    doubleArray(arr, size);
    printArray(arr, size);
    
    return 0;
}
```

---

## 7. 现代 C++ 替代方案

### 7.1 std::array

```cpp
#include <iostream>
#include <array>
#include <algorithm>

int main() {
    // std::array: 固定大小数组
    std::array<int, 5> arr = {1, 2, 3, 4, 5};
    
    // 大小信息保留
    std::cout << "Size: " << arr.size() << std::endl;
    
    // 边界检查
    std::cout << "arr.at(2) = " << arr.at(2) << std::endl;
    // arr.at(10);  // 抛出 std::out_of_range
    
    // 支持迭代器
    for (auto it = arr.begin(); it != arr.end(); ++it) {
        std::cout << *it << " ";
    }
    std::cout << std::endl;
    
    // 支持算法
    std::sort(arr.begin(), arr.end(), std::greater<int>());
    
    // 范围 for
    for (int x : arr) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    // 比较
    std::array<int, 5> arr2 = {5, 4, 3, 2, 1};
    if (arr == arr2) {
        std::cout << "Equal" << std::endl;
    }
    
    return 0;
}
```

### 7.2 std::vector

```cpp
#include <iostream>
#include <vector>

int main() {
    // std::vector: 动态数组
    std::vector<int> vec;
    
    // 添加元素
    vec.push_back(1);
    vec.push_back(2);
    vec.push_back(3);
    
    // 初始化
    std::vector<int> vec2 = {1, 2, 3, 4, 5};
    std::vector<int> vec3(10, 0);  // 10 个 0
    
    // 大小
    std::cout << "Size: " << vec2.size() << std::endl;
    std::cout << "Capacity: " << vec2.capacity() << std::endl;
    
    // 访问
    std::cout << "vec2[2] = " << vec2[2] << std::endl;
    std::cout << "vec2.at(2) = " << vec2.at(2) << std::endl;
    std::cout << "Front: " << vec2.front() << std::endl;
    std::cout << "Back: " << vec2.back() << std::endl;
    
    // 修改
    vec2[0] = 100;
    vec2.push_back(6);
    vec2.pop_back();
    
    // 遍历
    for (int x : vec2) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

### 7.3 std::span (C++20)

```cpp
#include <iostream>
#include <span>
#include <vector>
#include <array>

// 接受任何连续容器
void printSpan(std::span<int> s) {
    for (int x : s) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
}

int main() {
    int arr[] = {1, 2, 3, 4, 5};
    std::vector<int> vec = {10, 20, 30};
    std::array<int, 4> stdArr = {100, 200, 300, 400};
    
    // span 可以接受不同类型的连续容器
    printSpan(arr);
    printSpan(vec);
    printSpan(stdArr);
    
    // 子范围
    std::span<int> subSpan(arr + 1, 3);  // {2, 3, 4}
    printSpan(subSpan);
    
    return 0;
}
```

### 7.4 智能指针

```cpp
#include <iostream>
#include <memory>

int main() {
    // unique_ptr: 独占所有权
    std::unique_ptr<int> ptr1 = std::make_unique<int>(42);
    std::cout << "*ptr1 = " << *ptr1 << std::endl;
    
    // shared_ptr: 共享所有权
    std::shared_ptr<int> ptr2 = std::make_shared<int>(100);
    std::shared_ptr<int> ptr3 = ptr2;  // 共享
    std::cout << "Use count: " << ptr2.use_count() << std::endl;  // 2
    
    // 动态数组
    std::unique_ptr<int[]> arr = std::make_unique<int[]>(5);
    for (int i = 0; i < 5; ++i) {
        arr[i] = i * 10;
    }
    
    // 自动释放内存,无需 delete
    
    return 0;
}
```

---

## 8. 总结

### 8.1 数组与指针对比

| 特性 | 数组 | 指针 |
|------|------|------|
| 大小 | 固定 | 可变 |
| sizeof | 整个数组大小 | 指针大小 |
| 赋值 | 不能整体赋值 | 可以赋值 |
| 作为参数 | 退化为指针 | 保持指针 |

### 8.2 最佳实践

```
1. 优先使用 std::array 或 std::vector
2. 使用 nullptr 而非 NULL 或 0
3. 使用 const 保护不应修改的数据
4. 避免裸指针,使用智能指针
5. 注意数组越界问题
6. 函数参数使用 const 引用或 std::span
```

### 8.3 下一篇预告

在下一篇文章中,我们将学习 C++ 的字符串处理。

---

## 参考资料

1. [C++ Arrays](https://en.cppreference.com/w/cpp/language/array)
2. [C++ Pointers](https://en.cppreference.com/w/cpp/language/pointer)

---

> 作者: C++ 技术专栏  
> 系列: C++ 基础入门 (7/8)  
> 上一篇: [函数](./06-functions.md)  
> 下一篇: [字符串处理](./08-strings.md)
