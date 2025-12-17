---
title: "动态内存分配"
description: "1. [内存区域](#1-内存区域)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 17
---

> 本文是 C++ 从入门到精通系列的第十七篇,将深入讲解 C++ 的动态内存分配机制。

---

## 目录

1. [内存区域](#1-内存区域)
2. [new 和 delete](#2-new-和-delete)
3. [数组的动态分配](#3-数组的动态分配)
4. [内存泄漏](#4-内存泄漏)
5. [placement new](#5-placement-new)
6. [自定义内存管理](#6-自定义内存管理)
7. [总结](#7-总结)

---

## 1. 内存区域

### 1.1 程序内存布局

```
程序内存布局 (从低地址到高地址):

┌─────────────────┐ 低地址
│   代码段        │ 存放程序指令
│   (Text)        │
├─────────────────┤
│   数据段        │ 已初始化的全局/静态变量
│   (Data)        │
├─────────────────┤
│   BSS 段        │ 未初始化的全局/静态变量
│                 │
├─────────────────┤
│   堆 (Heap)     │ 动态分配的内存
│       ↓         │ 向高地址增长
│                 │
│                 │
│       ↑         │
│   栈 (Stack)    │ 局部变量、函数调用
├─────────────────┤
│   内核空间      │
└─────────────────┘ 高地址
```

### 1.2 栈与堆的区别

```cpp
#include <iostream>

int globalVar = 10;        // 数据段
int uninitGlobal;          // BSS 段

void demo() {
    int stackVar = 20;     // 栈
    static int staticVar = 30;  // 数据段
    
    int* heapVar = new int(40);  // 堆
    
    std::cout << "Stack address: " << &stackVar << std::endl;
    std::cout << "Heap address: " << heapVar << std::endl;
    std::cout << "Global address: " << &globalVar << std::endl;
    std::cout << "Static address: " << &staticVar << std::endl;
    
    delete heapVar;
}

int main() {
    demo();
    return 0;
}
```

### 1.3 栈与堆的对比

| 特性 | 栈 | 堆 |
|------|-----|-----|
| 分配方式 | 自动 | 手动 (new/delete) |
| 释放方式 | 自动 | 手动 |
| 大小限制 | 较小 (通常 1-8 MB) | 较大 (受系统限制) |
| 分配速度 | 快 | 慢 |
| 碎片化 | 无 | 可能有 |
| 生命周期 | 函数作用域 | 程序员控制 |

---

## 2. new 和 delete

### 2.1 基本用法

```cpp
#include <iostream>
#include <string>

int main() {
    // 分配单个对象
    int* pInt = new int;        // 未初始化
    int* pInt2 = new int();     // 值初始化为 0
    int* pInt3 = new int(42);   // 初始化为 42
    int* pInt4 = new int{42};   // C++11 列表初始化
    
    std::cout << "*pInt2 = " << *pInt2 << std::endl;  // 0
    std::cout << "*pInt3 = " << *pInt3 << std::endl;  // 42
    
    // 释放内存
    delete pInt;
    delete pInt2;
    delete pInt3;
    delete pInt4;
    
    // 分配对象
    std::string* pStr = new std::string("Hello");
    std::cout << "*pStr = " << *pStr << std::endl;
    delete pStr;
    
    // 分配类对象
    class Point {
    public:
        int x, y;
        Point(int x, int y) : x(x), y(y) {
            std::cout << "Point constructed" << std::endl;
        }
        ~Point() {
            std::cout << "Point destroyed" << std::endl;
        }
    };
    
    Point* pPoint = new Point(10, 20);
    std::cout << "Point: (" << pPoint->x << ", " << pPoint->y << ")" << std::endl;
    delete pPoint;
    
    return 0;
}
```

### 2.2 new 的工作原理

```cpp
#include <iostream>
#include <new>

class MyClass {
public:
    int value;
    
    MyClass(int v) : value(v) {
        std::cout << "Constructor called" << std::endl;
    }
    
    ~MyClass() {
        std::cout << "Destructor called" << std::endl;
    }
};

int main() {
    // new 的工作流程:
    // 1. 调用 operator new 分配内存
    // 2. 调用构造函数初始化对象
    
    MyClass* obj = new MyClass(42);
    
    // delete 的工作流程:
    // 1. 调用析构函数
    // 2. 调用 operator delete 释放内存
    
    delete obj;
    
    // 手动模拟 new 的过程
    void* memory = operator new(sizeof(MyClass));
    MyClass* obj2 = new(memory) MyClass(100);  // placement new
    
    obj2->~MyClass();  // 手动调用析构函数
    operator delete(memory);
    
    return 0;
}
```

### 2.3 异常安全

```cpp
#include <iostream>
#include <new>

int main() {
    // new 失败时抛出 std::bad_alloc 异常
    try {
        // 尝试分配大量内存
        int* huge = new int[1000000000000];
        delete[] huge;
    } catch (const std::bad_alloc& e) {
        std::cout << "Allocation failed: " << e.what() << std::endl;
    }
    
    // nothrow 版本: 失败返回 nullptr
    int* ptr = new(std::nothrow) int[1000000000000];
    if (ptr == nullptr) {
        std::cout << "Allocation failed (nothrow)" << std::endl;
    } else {
        delete[] ptr;
    }
    
    return 0;
}
```

---

## 3. 数组的动态分配

### 3.1 基本数组分配

```cpp
#include <iostream>

int main() {
    // 分配数组
    int* arr = new int[5];  // 未初始化
    int* arr2 = new int[5]();  // 值初始化为 0
    int* arr3 = new int[5]{1, 2, 3, 4, 5};  // C++11 列表初始化
    
    // 使用数组
    for (int i = 0; i < 5; ++i) {
        arr[i] = i * 10;
    }
    
    for (int i = 0; i < 5; ++i) {
        std::cout << arr[i] << " ";
    }
    std::cout << std::endl;
    
    // 释放数组 (必须使用 delete[])
    delete[] arr;
    delete[] arr2;
    delete[] arr3;
    
    // 错误: 使用 delete 而非 delete[]
    // delete arr;  // 未定义行为!
    
    return 0;
}
```

### 3.2 对象数组

```cpp
#include <iostream>
#include <string>

class Student {
public:
    std::string name;
    int age;
    
    Student() : name("Unknown"), age(0) {
        std::cout << "Default constructor" << std::endl;
    }
    
    Student(const std::string& n, int a) : name(n), age(a) {
        std::cout << "Parameterized constructor: " << name << std::endl;
    }
    
    ~Student() {
        std::cout << "Destructor: " << name << std::endl;
    }
};

int main() {
    // 对象数组 (调用默认构造函数)
    Student* students = new Student[3];
    
    students[0].name = "Alice";
    students[0].age = 20;
    students[1].name = "Bob";
    students[1].age = 21;
    students[2].name = "Charlie";
    students[2].age = 22;
    
    for (int i = 0; i < 3; ++i) {
        std::cout << students[i].name << ", " << students[i].age << std::endl;
    }
    
    delete[] students;  // 调用每个对象的析构函数
    
    return 0;
}
```

### 3.3 多维数组

```cpp
#include <iostream>

int main() {
    int rows = 3, cols = 4;
    
    // 方法 1: 指针数组
    int** matrix = new int*[rows];
    for (int i = 0; i < rows; ++i) {
        matrix[i] = new int[cols]();
    }
    
    // 使用
    for (int i = 0; i < rows; ++i) {
        for (int j = 0; j < cols; ++j) {
            matrix[i][j] = i * cols + j;
        }
    }
    
    // 打印
    for (int i = 0; i < rows; ++i) {
        for (int j = 0; j < cols; ++j) {
            std::cout << matrix[i][j] << "\t";
        }
        std::cout << std::endl;
    }
    
    // 释放
    for (int i = 0; i < rows; ++i) {
        delete[] matrix[i];
    }
    delete[] matrix;
    
    // 方法 2: 一维数组模拟二维
    int* matrix2 = new int[rows * cols]();
    
    // 访问 matrix2[i][j] = matrix2[i * cols + j]
    for (int i = 0; i < rows; ++i) {
        for (int j = 0; j < cols; ++j) {
            matrix2[i * cols + j] = i * cols + j;
        }
    }
    
    delete[] matrix2;
    
    return 0;
}
```

---

## 4. 内存泄漏

### 4.1 常见内存泄漏场景

```cpp
#include <iostream>
#include <string>

// 场景 1: 忘记 delete
void leak1() {
    int* ptr = new int(42);
    // 忘记 delete ptr;
}  // 内存泄漏!

// 场景 2: 异常导致泄漏
void leak2() {
    int* ptr = new int(42);
    
    // 如果这里抛出异常...
    throw std::runtime_error("Error");
    
    delete ptr;  // 永远不会执行
}

// 场景 3: 重新赋值导致泄漏
void leak3() {
    int* ptr = new int(42);
    ptr = new int(100);  // 原来的内存泄漏!
    delete ptr;
}

// 场景 4: 数组使用 delete 而非 delete[]
void leak4() {
    int* arr = new int[100];
    delete arr;  // 应该用 delete[]
}

// 场景 5: 循环中的泄漏
void leak5() {
    for (int i = 0; i < 1000; ++i) {
        int* ptr = new int(i);
        // 忘记 delete
    }
}
```

### 4.2 避免内存泄漏

```cpp
#include <iostream>
#include <memory>

// 方法 1: 使用智能指针
void safe1() {
    std::unique_ptr<int> ptr = std::make_unique<int>(42);
    // 自动释放
}

// 方法 2: RAII
class Resource {
public:
    int* data;
    
    Resource() : data(new int[100]) {
        std::cout << "Resource acquired" << std::endl;
    }
    
    ~Resource() {
        delete[] data;
        std::cout << "Resource released" << std::endl;
    }
};

void safe2() {
    Resource res;  // 自动管理
}

// 方法 3: try-catch 确保释放
void safe3() {
    int* ptr = new int(42);
    try {
        // 可能抛出异常的代码
        throw std::runtime_error("Error");
    } catch (...) {
        delete ptr;
        throw;  // 重新抛出
    }
    delete ptr;
}

int main() {
    safe1();
    safe2();
    
    try {
        safe3();
    } catch (const std::exception& e) {
        std::cout << "Caught: " << e.what() << std::endl;
    }
    
    return 0;
}
```

### 4.3 内存泄漏检测

```cpp
/*
内存泄漏检测工具:

1. Valgrind (Linux)
   valgrind --leak-check=full ./program

2. AddressSanitizer (GCC/Clang)
   g++ -fsanitize=address -g program.cpp
   ./a.out

3. Visual Studio 内置检测
   #define _CRTDBG_MAP_ALLOC
   #include <crtdbg.h>
   _CrtDumpMemoryLeaks();

4. 自定义 new/delete 跟踪
*/

#include <iostream>
#include <map>

// 简单的内存跟踪
std::map<void*, size_t> allocations;

void* operator new(size_t size) {
    void* ptr = malloc(size);
    allocations[ptr] = size;
    std::cout << "Allocated " << size << " bytes at " << ptr << std::endl;
    return ptr;
}

void operator delete(void* ptr) noexcept {
    if (allocations.count(ptr)) {
        std::cout << "Freed " << allocations[ptr] << " bytes at " << ptr << std::endl;
        allocations.erase(ptr);
    }
    free(ptr);
}

void checkLeaks() {
    if (allocations.empty()) {
        std::cout << "No memory leaks detected" << std::endl;
    } else {
        std::cout << "Memory leaks detected:" << std::endl;
        for (const auto& [ptr, size] : allocations) {
            std::cout << "  " << size << " bytes at " << ptr << std::endl;
        }
    }
}

int main() {
    int* a = new int(42);
    int* b = new int(100);
    
    delete a;
    // 故意不删除 b
    
    checkLeaks();
    
    delete b;  // 清理
    
    return 0;
}
```

---

## 5. placement new

### 5.1 基本用法

```cpp
#include <iostream>
#include <new>

class MyClass {
public:
    int value;
    
    MyClass(int v) : value(v) {
        std::cout << "Constructor: " << value << std::endl;
    }
    
    ~MyClass() {
        std::cout << "Destructor: " << value << std::endl;
    }
};

int main() {
    // 预分配内存
    char buffer[sizeof(MyClass)];
    
    // 在预分配的内存上构造对象
    MyClass* obj = new(buffer) MyClass(42);
    
    std::cout << "Value: " << obj->value << std::endl;
    
    // 手动调用析构函数 (不释放内存)
    obj->~MyClass();
    
    // buffer 是栈上的,不需要释放
    
    return 0;
}
```

### 5.2 内存池应用

```cpp
#include <iostream>
#include <vector>

class MemoryPool {
public:
    MemoryPool(size_t objectSize, size_t poolSize)
        : objectSize(objectSize), poolSize(poolSize) {
        pool = new char[objectSize * poolSize];
        for (size_t i = 0; i < poolSize; ++i) {
            freeList.push_back(pool + i * objectSize);
        }
    }
    
    ~MemoryPool() {
        delete[] pool;
    }
    
    void* allocate() {
        if (freeList.empty()) {
            throw std::bad_alloc();
        }
        void* ptr = freeList.back();
        freeList.pop_back();
        return ptr;
    }
    
    void deallocate(void* ptr) {
        freeList.push_back(static_cast<char*>(ptr));
    }

private:
    char* pool;
    size_t objectSize;
    size_t poolSize;
    std::vector<char*> freeList;
};

class PooledObject {
public:
    int data;
    
    PooledObject(int d) : data(d) {
        std::cout << "PooledObject(" << data << ")" << std::endl;
    }
    
    ~PooledObject() {
        std::cout << "~PooledObject(" << data << ")" << std::endl;
    }
    
    static MemoryPool pool;
    
    static void* operator new(size_t size) {
        return pool.allocate();
    }
    
    static void operator delete(void* ptr) {
        pool.deallocate(ptr);
    }
};

MemoryPool PooledObject::pool(sizeof(PooledObject), 10);

int main() {
    PooledObject* obj1 = new PooledObject(1);
    PooledObject* obj2 = new PooledObject(2);
    PooledObject* obj3 = new PooledObject(3);
    
    delete obj2;
    
    PooledObject* obj4 = new PooledObject(4);  // 复用 obj2 的内存
    
    delete obj1;
    delete obj3;
    delete obj4;
    
    return 0;
}
```

---

## 6. 自定义内存管理

### 6.1 重载 new 和 delete

```cpp
#include <iostream>
#include <cstdlib>

class MyClass {
public:
    int value;
    
    MyClass(int v) : value(v) { }
    
    // 类特定的 operator new
    static void* operator new(size_t size) {
        std::cout << "MyClass::operator new(" << size << ")" << std::endl;
        return malloc(size);
    }
    
    // 类特定的 operator delete
    static void operator delete(void* ptr) {
        std::cout << "MyClass::operator delete" << std::endl;
        free(ptr);
    }
    
    // 数组版本
    static void* operator new[](size_t size) {
        std::cout << "MyClass::operator new[](" << size << ")" << std::endl;
        return malloc(size);
    }
    
    static void operator delete[](void* ptr) {
        std::cout << "MyClass::operator delete[]" << std::endl;
        free(ptr);
    }
};

int main() {
    MyClass* obj = new MyClass(42);
    delete obj;
    
    MyClass* arr = new MyClass[3]{{1}, {2}, {3}};
    delete[] arr;
    
    return 0;
}
```

### 6.2 对齐内存分配

```cpp
#include <iostream>
#include <cstdlib>
#include <new>

// C++17 对齐分配
struct alignas(64) CacheAligned {
    int data[16];
};

int main() {
    // 标准对齐分配
    CacheAligned* obj = new CacheAligned();
    std::cout << "Address: " << obj << std::endl;
    std::cout << "Aligned to 64: " << (reinterpret_cast<uintptr_t>(obj) % 64 == 0) << std::endl;
    delete obj;
    
    // 手动对齐分配 (C++17)
    void* ptr = operator new(sizeof(CacheAligned), std::align_val_t{64});
    CacheAligned* aligned = new(ptr) CacheAligned();
    
    aligned->~CacheAligned();
    operator delete(ptr, std::align_val_t{64});
    
    return 0;
}
```

---

## 7. 总结

### 7.1 new/delete 对照表

| 分配 | 释放 | 用途 |
|------|------|------|
| new T | delete p | 单个对象 |
| new T[n] | delete[] p | 对象数组 |
| new(ptr) T | p->~T() | placement new |

### 7.2 最佳实践

```
1. 优先使用智能指针
2. new 和 delete 配对使用
3. new[] 和 delete[] 配对使用
4. 检查 new 是否成功
5. 使用 RAII 管理资源
6. 避免裸指针
7. 使用工具检测内存泄漏
```

### 7.3 下一篇预告

在下一篇文章中,我们将学习智能指针。

---

> 作者: C++ 技术专栏  
> 系列: 内存管理与指针进阶 (1/6)  
> 上一篇: [抽象类与接口](../part2-oop/16-abstract-interface.md)  
> 下一篇: [智能指针](./18-smart-pointers.md)
