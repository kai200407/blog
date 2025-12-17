---
title: "内存布局与对齐"
description: "1. [对象内存布局](#1-对象内存布局)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 20
---

> 本文是 C++ 从入门到精通系列的第二十篇,将深入讲解 C++ 对象的内存布局、字节对齐以及相关优化技术。

---

## 目录

1. [对象内存布局](#1-对象内存布局)
2. [字节对齐](#2-字节对齐)
3. [类的内存布局](#3-类的内存布局)
4. [虚函数表布局](#4-虚函数表布局)
5. [内存布局优化](#5-内存布局优化)
6. [总结](#6-总结)

---

## 1. 对象内存布局

### 1.1 基本类型大小

```cpp
#include <iostream>
#include <cstdint>

int main() {
    std::cout << "=== 基本类型大小 ===" << std::endl;
    std::cout << "char: " << sizeof(char) << " bytes" << std::endl;
    std::cout << "short: " << sizeof(short) << " bytes" << std::endl;
    std::cout << "int: " << sizeof(int) << " bytes" << std::endl;
    std::cout << "long: " << sizeof(long) << " bytes" << std::endl;
    std::cout << "long long: " << sizeof(long long) << " bytes" << std::endl;
    std::cout << "float: " << sizeof(float) << " bytes" << std::endl;
    std::cout << "double: " << sizeof(double) << " bytes" << std::endl;
    std::cout << "void*: " << sizeof(void*) << " bytes" << std::endl;
    
    std::cout << "\n=== 固定宽度类型 ===" << std::endl;
    std::cout << "int8_t: " << sizeof(int8_t) << " bytes" << std::endl;
    std::cout << "int16_t: " << sizeof(int16_t) << " bytes" << std::endl;
    std::cout << "int32_t: " << sizeof(int32_t) << " bytes" << std::endl;
    std::cout << "int64_t: " << sizeof(int64_t) << " bytes" << std::endl;
    
    return 0;
}
```

### 1.2 简单结构体布局

```cpp
#include <iostream>
#include <cstddef>

struct Simple {
    int a;
    int b;
    int c;
};

int main() {
    Simple s;
    
    std::cout << "sizeof(Simple): " << sizeof(Simple) << std::endl;
    
    std::cout << "Address of s: " << &s << std::endl;
    std::cout << "Address of s.a: " << &s.a << std::endl;
    std::cout << "Address of s.b: " << &s.b << std::endl;
    std::cout << "Address of s.c: " << &s.c << std::endl;
    
    std::cout << "\nOffsets:" << std::endl;
    std::cout << "offsetof(Simple, a): " << offsetof(Simple, a) << std::endl;
    std::cout << "offsetof(Simple, b): " << offsetof(Simple, b) << std::endl;
    std::cout << "offsetof(Simple, c): " << offsetof(Simple, c) << std::endl;
    
    return 0;
}
```

### 1.3 内存布局可视化

```
Simple 结构体内存布局:

地址偏移    内容
────────────────────
0          a (4 bytes)
4          b (4 bytes)
8          c (4 bytes)
────────────────────
总大小: 12 bytes
```

---

## 2. 字节对齐

### 2.1 对齐规则

```cpp
#include <iostream>
#include <cstddef>

// 未优化的结构体
struct Unoptimized {
    char a;     // 1 byte
    // 3 bytes padding
    int b;      // 4 bytes
    char c;     // 1 byte
    // 3 bytes padding
};

// 优化后的结构体
struct Optimized {
    int b;      // 4 bytes
    char a;     // 1 byte
    char c;     // 1 byte
    // 2 bytes padding
};

int main() {
    std::cout << "sizeof(Unoptimized): " << sizeof(Unoptimized) << std::endl;  // 12
    std::cout << "sizeof(Optimized): " << sizeof(Optimized) << std::endl;      // 8
    
    std::cout << "\nUnoptimized offsets:" << std::endl;
    std::cout << "a: " << offsetof(Unoptimized, a) << std::endl;
    std::cout << "b: " << offsetof(Unoptimized, b) << std::endl;
    std::cout << "c: " << offsetof(Unoptimized, c) << std::endl;
    
    std::cout << "\nOptimized offsets:" << std::endl;
    std::cout << "b: " << offsetof(Optimized, b) << std::endl;
    std::cout << "a: " << offsetof(Optimized, a) << std::endl;
    std::cout << "c: " << offsetof(Optimized, c) << std::endl;
    
    return 0;
}
```

### 2.2 对齐规则详解

```
对齐规则:

1. 成员对齐
   - 每个成员的偏移量必须是其大小的整数倍
   - char: 1 字节对齐
   - short: 2 字节对齐
   - int: 4 字节对齐
   - double: 8 字节对齐
   - 指针: 平台相关 (32位: 4, 64位: 8)

2. 结构体对齐
   - 结构体大小必须是最大成员对齐值的整数倍

Unoptimized 布局:
┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
│ a │pad│pad│pad│   b (4 bytes)   │ c │pad│pad│pad│
└───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘
 0   1   2   3   4   5   6   7   8   9  10  11

Optimized 布局:
┌───┬───┬───┬───┬───┬───┬───┬───┐
│   b (4 bytes)   │ a │ c │pad│pad│
└───┴───┴───┴───┴───┴───┴───┴───┘
 0   1   2   3   4   5   6   7
```

### 2.3 alignas 和 alignof

```cpp
#include <iostream>

// 指定对齐方式
struct alignas(16) Aligned16 {
    int a;
    int b;
};

struct alignas(64) CacheLineAligned {
    int data[16];
};

int main() {
    std::cout << "=== alignof ===" << std::endl;
    std::cout << "alignof(char): " << alignof(char) << std::endl;
    std::cout << "alignof(int): " << alignof(int) << std::endl;
    std::cout << "alignof(double): " << alignof(double) << std::endl;
    std::cout << "alignof(void*): " << alignof(void*) << std::endl;
    
    std::cout << "\n=== 自定义对齐 ===" << std::endl;
    std::cout << "sizeof(Aligned16): " << sizeof(Aligned16) << std::endl;
    std::cout << "alignof(Aligned16): " << alignof(Aligned16) << std::endl;
    
    std::cout << "sizeof(CacheLineAligned): " << sizeof(CacheLineAligned) << std::endl;
    std::cout << "alignof(CacheLineAligned): " << alignof(CacheLineAligned) << std::endl;
    
    // 验证对齐
    Aligned16 a;
    std::cout << "\nAddress of Aligned16: " << &a << std::endl;
    std::cout << "Is 16-byte aligned: " << (reinterpret_cast<uintptr_t>(&a) % 16 == 0) << std::endl;
    
    return 0;
}
```

### 2.4 #pragma pack

```cpp
#include <iostream>
#include <cstddef>

// 默认对齐
struct Default {
    char a;
    int b;
    char c;
};

// 1 字节对齐 (紧凑)
#pragma pack(push, 1)
struct Packed1 {
    char a;
    int b;
    char c;
};
#pragma pack(pop)

// 2 字节对齐
#pragma pack(push, 2)
struct Packed2 {
    char a;
    int b;
    char c;
};
#pragma pack(pop)

int main() {
    std::cout << "sizeof(Default): " << sizeof(Default) << std::endl;   // 12
    std::cout << "sizeof(Packed1): " << sizeof(Packed1) << std::endl;   // 6
    std::cout << "sizeof(Packed2): " << sizeof(Packed2) << std::endl;   // 8
    
    std::cout << "\nPacked1 offsets:" << std::endl;
    std::cout << "a: " << offsetof(Packed1, a) << std::endl;  // 0
    std::cout << "b: " << offsetof(Packed1, b) << std::endl;  // 1
    std::cout << "c: " << offsetof(Packed1, c) << std::endl;  // 5
    
    return 0;
}
```

---

## 3. 类的内存布局

### 3.1 简单类

```cpp
#include <iostream>

class SimpleClass {
public:
    int a;
    double b;
    char c;
    
    void method() { }  // 不占用对象空间
    static int staticVar;  // 不占用对象空间
};

int SimpleClass::staticVar = 0;

int main() {
    std::cout << "sizeof(SimpleClass): " << sizeof(SimpleClass) << std::endl;
    
    SimpleClass obj;
    std::cout << "Address of obj: " << &obj << std::endl;
    std::cout << "Address of obj.a: " << &obj.a << std::endl;
    std::cout << "Address of obj.b: " << &obj.b << std::endl;
    std::cout << "Address of obj.c: " << &obj.c << std::endl;
    
    return 0;
}
```

### 3.2 继承的内存布局

```cpp
#include <iostream>

class Base {
public:
    int baseA;
    int baseB;
};

class Derived : public Base {
public:
    int derivedC;
    int derivedD;
};

int main() {
    std::cout << "sizeof(Base): " << sizeof(Base) << std::endl;
    std::cout << "sizeof(Derived): " << sizeof(Derived) << std::endl;
    
    Derived d;
    d.baseA = 1;
    d.baseB = 2;
    d.derivedC = 3;
    d.derivedD = 4;
    
    // 内存布局: baseA, baseB, derivedC, derivedD
    int* ptr = reinterpret_cast<int*>(&d);
    std::cout << "\nMemory layout:" << std::endl;
    for (int i = 0; i < 4; ++i) {
        std::cout << "offset " << i * 4 << ": " << ptr[i] << std::endl;
    }
    
    return 0;
}
```

### 3.3 多继承的内存布局

```cpp
#include <iostream>

class Base1 {
public:
    int a;
};

class Base2 {
public:
    int b;
};

class MultiDerived : public Base1, public Base2 {
public:
    int c;
};

int main() {
    std::cout << "sizeof(Base1): " << sizeof(Base1) << std::endl;
    std::cout << "sizeof(Base2): " << sizeof(Base2) << std::endl;
    std::cout << "sizeof(MultiDerived): " << sizeof(MultiDerived) << std::endl;
    
    MultiDerived md;
    md.a = 1;
    md.b = 2;
    md.c = 3;
    
    // 指针转换
    Base1* pb1 = &md;
    Base2* pb2 = &md;
    MultiDerived* pmd = &md;
    
    std::cout << "\nPointer addresses:" << std::endl;
    std::cout << "MultiDerived*: " << pmd << std::endl;
    std::cout << "Base1*: " << pb1 << std::endl;
    std::cout << "Base2*: " << pb2 << std::endl;  // 注意: 地址不同!
    
    return 0;
}
```

---

## 4. 虚函数表布局

### 4.1 虚函数表基础

```cpp
#include <iostream>

class Base {
public:
    virtual void func1() { std::cout << "Base::func1" << std::endl; }
    virtual void func2() { std::cout << "Base::func2" << std::endl; }
    int data;
};

class Derived : public Base {
public:
    void func1() override { std::cout << "Derived::func1" << std::endl; }
    virtual void func3() { std::cout << "Derived::func3" << std::endl; }
    int derivedData;
};

int main() {
    std::cout << "sizeof(Base): " << sizeof(Base) << std::endl;
    std::cout << "sizeof(Derived): " << sizeof(Derived) << std::endl;
    
    Base b;
    Derived d;
    
    // vptr 通常在对象开头
    void** vptr_b = *reinterpret_cast<void***>(&b);
    void** vptr_d = *reinterpret_cast<void***>(&d);
    
    std::cout << "\nBase vptr: " << vptr_b << std::endl;
    std::cout << "Derived vptr: " << vptr_d << std::endl;
    
    // 通过基类指针调用虚函数
    Base* ptr = &d;
    ptr->func1();  // Derived::func1
    ptr->func2();  // Base::func2
    
    return 0;
}
```

### 4.2 虚函数表结构

```
虚函数表布局:

Base 对象:
┌─────────────┐
│    vptr     │ ──→ Base vtable
├─────────────┤     ┌─────────────────┐
│    data     │     │ &Base::func1    │
└─────────────┘     │ &Base::func2    │
                    └─────────────────┘

Derived 对象:
┌─────────────┐
│    vptr     │ ──→ Derived vtable
├─────────────┤     ┌─────────────────┐
│    data     │     │ &Derived::func1 │ (重写)
├─────────────┤     │ &Base::func2    │ (继承)
│ derivedData │     │ &Derived::func3 │ (新增)
└─────────────┘     └─────────────────┘
```

### 4.3 多继承的虚函数表

```cpp
#include <iostream>

class Base1 {
public:
    virtual void func1() { std::cout << "Base1::func1" << std::endl; }
    int data1;
};

class Base2 {
public:
    virtual void func2() { std::cout << "Base2::func2" << std::endl; }
    int data2;
};

class MultiDerived : public Base1, public Base2 {
public:
    void func1() override { std::cout << "MultiDerived::func1" << std::endl; }
    void func2() override { std::cout << "MultiDerived::func2" << std::endl; }
    virtual void func3() { std::cout << "MultiDerived::func3" << std::endl; }
    int data3;
};

int main() {
    std::cout << "sizeof(Base1): " << sizeof(Base1) << std::endl;
    std::cout << "sizeof(Base2): " << sizeof(Base2) << std::endl;
    std::cout << "sizeof(MultiDerived): " << sizeof(MultiDerived) << std::endl;
    
    MultiDerived md;
    
    Base1* pb1 = &md;
    Base2* pb2 = &md;
    
    pb1->func1();  // MultiDerived::func1
    pb2->func2();  // MultiDerived::func2
    
    return 0;
}
```

---

## 5. 内存布局优化

### 5.1 成员排序优化

```cpp
#include <iostream>

// 未优化
struct BadLayout {
    bool flag1;      // 1 + 7 padding
    double value1;   // 8
    bool flag2;      // 1 + 3 padding
    int count;       // 4
    bool flag3;      // 1 + 7 padding
    double value2;   // 8
};  // 总计: 40 bytes

// 优化后
struct GoodLayout {
    double value1;   // 8
    double value2;   // 8
    int count;       // 4
    bool flag1;      // 1
    bool flag2;      // 1
    bool flag3;      // 1 + 1 padding
};  // 总计: 24 bytes

int main() {
    std::cout << "sizeof(BadLayout): " << sizeof(BadLayout) << std::endl;
    std::cout << "sizeof(GoodLayout): " << sizeof(GoodLayout) << std::endl;
    
    // 节省了 16 bytes (40%)
    
    return 0;
}
```

### 5.2 位域

```cpp
#include <iostream>

// 使用位域压缩
struct Flags {
    unsigned int flag1 : 1;
    unsigned int flag2 : 1;
    unsigned int flag3 : 1;
    unsigned int flag4 : 1;
    unsigned int value : 4;  // 0-15
};

struct Status {
    uint8_t isActive : 1;
    uint8_t isVisible : 1;
    uint8_t isEnabled : 1;
    uint8_t priority : 3;    // 0-7
    uint8_t reserved : 2;
};

int main() {
    std::cout << "sizeof(Flags): " << sizeof(Flags) << std::endl;   // 4
    std::cout << "sizeof(Status): " << sizeof(Status) << std::endl; // 1
    
    Flags f;
    f.flag1 = 1;
    f.flag2 = 0;
    f.flag3 = 1;
    f.flag4 = 0;
    f.value = 15;
    
    Status s;
    s.isActive = 1;
    s.isVisible = 1;
    s.isEnabled = 0;
    s.priority = 5;
    
    std::cout << "\nFlags values:" << std::endl;
    std::cout << "flag1: " << f.flag1 << std::endl;
    std::cout << "value: " << f.value << std::endl;
    
    std::cout << "\nStatus values:" << std::endl;
    std::cout << "isActive: " << (int)s.isActive << std::endl;
    std::cout << "priority: " << (int)s.priority << std::endl;
    
    return 0;
}
```

### 5.3 空基类优化 (EBO)

```cpp
#include <iostream>

class Empty { };

class NotOptimized {
    Empty e;
    int data;
};

class Optimized : private Empty {
    int data;
};

int main() {
    std::cout << "sizeof(Empty): " << sizeof(Empty) << std::endl;           // 1
    std::cout << "sizeof(NotOptimized): " << sizeof(NotOptimized) << std::endl; // 8
    std::cout << "sizeof(Optimized): " << sizeof(Optimized) << std::endl;   // 4
    
    // 空基类优化: 继承空类不增加大小
    
    return 0;
}
```

---

## 6. 总结

### 6.1 对齐规则

```
1. 成员按声明顺序排列
2. 每个成员对齐到其大小的整数倍
3. 结构体大小是最大对齐值的整数倍
4. 可用 alignas 指定对齐
5. 可用 #pragma pack 修改对齐
```

### 6.2 优化建议

```
1. 按大小降序排列成员
2. 将相同类型的成员放在一起
3. 使用位域压缩布尔值
4. 利用空基类优化
5. 考虑缓存行对齐
```

### 6.3 下一篇预告

在下一篇文章中,我们将学习内存池与自定义分配器。

---

> 作者: C++ 技术专栏  
> 系列: 内存管理与指针进阶 (4/6)  
> 上一篇: [RAII 与资源管理](./19-raii.md)  
> 下一篇: [内存池与自定义分配器](./21-memory-pool.md)
