---
title: "变量与数据类型"
description: "1. [变量基础](#1-变量基础)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 3
---

> 本文是 C++ 从入门到精通系列的第三篇,将深入讲解 C++ 的变量声明、基本数据类型、类型转换以及常量定义。

---

## 目录

1. [变量基础](#1-变量基础)
2. [基本数据类型](#2-基本数据类型)
3. [类型修饰符](#3-类型修饰符)
4. [类型转换](#4-类型转换)
5. [常量](#5-常量)
6. [类型别名](#6-类型别名)
7. [auto 类型推导](#7-auto-类型推导)
8. [总结](#8-总结)

---

## 1. 变量基础

### 1.1 变量声明与定义

```cpp
#include <iostream>

int main() {
    // 声明并初始化
    int age = 25;
    double salary = 5000.50;
    char grade = 'A';
    bool isStudent = true;
    
    // 先声明后赋值
    int count;
    count = 10;
    
    // 多个变量同时声明
    int x = 1, y = 2, z = 3;
    
    // C++11 统一初始化 (推荐)
    int value{42};
    double pi{3.14159};
    
    // 列表初始化防止窄化转换
    // int narrow{3.14};  // 错误: 窄化转换
    
    std::cout << "age = " << age << std::endl;
    std::cout << "salary = " << salary << std::endl;
    
    return 0;
}
```

### 1.2 变量命名规则

```cpp
// 合法的变量名
int age;
int _count;
int myVariable;
int my_variable;
int variable123;
int _123;

// 非法的变量名
// int 123abc;      // 不能以数字开头
// int my-variable; // 不能包含连字符
// int my variable; // 不能包含空格
// int class;       // 不能使用关键字

// 命名建议
int studentAge;      // 驼峰命名 (camelCase)
int student_age;     // 下划线命名 (snake_case)
const int MAX_SIZE = 100;  // 常量全大写
```

### 1.3 变量作用域

```cpp
#include <iostream>

int globalVar = 100;  // 全局变量

int main() {
    int localVar = 10;  // 局部变量
    
    {
        int blockVar = 20;  // 块作用域变量
        std::cout << "blockVar = " << blockVar << std::endl;
        std::cout << "localVar = " << localVar << std::endl;
        std::cout << "globalVar = " << globalVar << std::endl;
    }
    
    // std::cout << blockVar;  // 错误: blockVar 不在作用域内
    
    // 同名变量遮蔽
    int globalVar = 50;  // 遮蔽全局变量
    std::cout << "localVar = " << localVar << std::endl;
    std::cout << "globalVar (local) = " << globalVar << std::endl;
    std::cout << "globalVar (global) = " << ::globalVar << std::endl;  // 使用 :: 访问全局
    
    return 0;
}
```

---

## 2. 基本数据类型

### 2.1 整数类型

```cpp
#include <iostream>
#include <climits>
#include <cstdint>

int main() {
    // 基本整数类型
    short s = 32767;
    int i = 2147483647;
    long l = 2147483647L;
    long long ll = 9223372036854775807LL;
    
    // 查看类型大小
    std::cout << "short: " << sizeof(short) << " bytes" << std::endl;
    std::cout << "int: " << sizeof(int) << " bytes" << std::endl;
    std::cout << "long: " << sizeof(long) << " bytes" << std::endl;
    std::cout << "long long: " << sizeof(long long) << " bytes" << std::endl;
    
    // 查看取值范围
    std::cout << "int 范围: " << INT_MIN << " ~ " << INT_MAX << std::endl;
    
    // 固定宽度整数 (C++11, 推荐)
    int8_t i8 = 127;
    int16_t i16 = 32767;
    int32_t i32 = 2147483647;
    int64_t i64 = 9223372036854775807LL;
    
    std::cout << "int32_t: " << sizeof(int32_t) << " bytes" << std::endl;
    
    return 0;
}
```

### 2.2 整数类型大小

```
整数类型大小 (典型值):

类型          大小 (字节)    范围
─────────────────────────────────────────────────
char          1             -128 ~ 127
short         2             -32,768 ~ 32,767
int           4             -2^31 ~ 2^31-1
long          4/8           平台相关
long long     8             -2^63 ~ 2^63-1

固定宽度类型 (推荐):
int8_t        1             -128 ~ 127
int16_t       2             -32,768 ~ 32,767
int32_t       4             -2^31 ~ 2^31-1
int64_t       8             -2^63 ~ 2^63-1
```

### 2.3 无符号整数

```cpp
#include <iostream>
#include <cstdint>

int main() {
    // 无符号类型
    unsigned short us = 65535;
    unsigned int ui = 4294967295U;
    unsigned long ul = 4294967295UL;
    unsigned long long ull = 18446744073709551615ULL;
    
    // 固定宽度无符号类型
    uint8_t u8 = 255;
    uint16_t u16 = 65535;
    uint32_t u32 = 4294967295U;
    uint64_t u64 = 18446744073709551615ULL;
    
    // 注意: 无符号数溢出
    unsigned int x = 0;
    x = x - 1;  // 溢出,变成最大值
    std::cout << "0 - 1 (unsigned) = " << x << std::endl;
    
    // size_t: 无符号,用于表示大小
    size_t size = sizeof(int);
    std::cout << "size_t: " << sizeof(size_t) << " bytes" << std::endl;
    
    return 0;
}
```

### 2.4 浮点类型

```cpp
#include <iostream>
#include <iomanip>
#include <cfloat>
#include <cmath>

int main() {
    // 浮点类型
    float f = 3.14159f;
    double d = 3.14159265358979;
    long double ld = 3.14159265358979323846L;
    
    // 大小
    std::cout << "float: " << sizeof(float) << " bytes" << std::endl;
    std::cout << "double: " << sizeof(double) << " bytes" << std::endl;
    std::cout << "long double: " << sizeof(long double) << " bytes" << std::endl;
    
    // 精度
    std::cout << std::setprecision(20);
    std::cout << "float: " << f << std::endl;
    std::cout << "double: " << d << std::endl;
    std::cout << "long double: " << ld << std::endl;
    
    // 特殊值
    double inf = 1.0 / 0.0;
    double nan = 0.0 / 0.0;
    std::cout << "Infinity: " << inf << std::endl;
    std::cout << "NaN: " << nan << std::endl;
    std::cout << "isnan: " << std::isnan(nan) << std::endl;
    std::cout << "isinf: " << std::isinf(inf) << std::endl;
    
    // 科学计数法
    double sci = 1.23e10;
    double sci2 = 1.23e-5;
    std::cout << "1.23e10 = " << sci << std::endl;
    std::cout << "1.23e-5 = " << sci2 << std::endl;
    
    return 0;
}
```

### 2.5 字符类型

```cpp
#include <iostream>

int main() {
    // 字符类型
    char c = 'A';
    char c2 = 65;  // ASCII 码
    
    std::cout << "c = " << c << std::endl;
    std::cout << "c2 = " << c2 << std::endl;
    std::cout << "ASCII of 'A' = " << static_cast<int>(c) << std::endl;
    
    // 转义字符
    char newline = '\n';
    char tab = '\t';
    char backslash = '\\';
    char quote = '\'';
    char dquote = '\"';
    char null_char = '\0';
    
    std::cout << "Hello\tWorld\n";
    std::cout << "Path: C:\\Users\\Name\n";
    std::cout << "Quote: \"Hello\"\n";
    
    // 宽字符
    wchar_t wc = L'中';
    char16_t c16 = u'中';
    char32_t c32 = U'中';
    
    std::cout << "wchar_t: " << sizeof(wchar_t) << " bytes" << std::endl;
    std::cout << "char16_t: " << sizeof(char16_t) << " bytes" << std::endl;
    std::cout << "char32_t: " << sizeof(char32_t) << " bytes" << std::endl;
    
    // C++20 char8_t
    // char8_t c8 = u8'A';
    
    return 0;
}
```

### 2.6 布尔类型

```cpp
#include <iostream>

int main() {
    bool flag1 = true;
    bool flag2 = false;
    
    std::cout << "true = " << flag1 << std::endl;
    std::cout << "false = " << flag2 << std::endl;
    std::cout << std::boolalpha;
    std::cout << "true = " << flag1 << std::endl;
    std::cout << "false = " << flag2 << std::endl;
    
    // bool 与整数转换
    bool b1 = 42;    // 非零为 true
    bool b2 = 0;     // 零为 false
    int i1 = true;   // 1
    int i2 = false;  // 0
    
    std::cout << "bool(42) = " << b1 << std::endl;
    std::cout << "bool(0) = " << b2 << std::endl;
    std::cout << "int(true) = " << i1 << std::endl;
    std::cout << "int(false) = " << i2 << std::endl;
    
    // sizeof
    std::cout << "sizeof(bool) = " << sizeof(bool) << " bytes" << std::endl;
    
    return 0;
}
```

---

## 3. 类型修饰符

### 3.1 signed 和 unsigned

```cpp
#include <iostream>

int main() {
    // 有符号 (默认)
    signed int si = -10;
    int i = -10;  // 等价于 signed int
    
    // 无符号
    unsigned int ui = 10;
    unsigned u = 10;  // 等价于 unsigned int
    
    // char 的符号性是实现定义的
    char c = 'A';
    signed char sc = -1;
    unsigned char uc = 255;
    
    std::cout << "signed int: " << si << std::endl;
    std::cout << "unsigned int: " << ui << std::endl;
    std::cout << "signed char: " << static_cast<int>(sc) << std::endl;
    std::cout << "unsigned char: " << static_cast<int>(uc) << std::endl;
    
    return 0;
}
```

### 3.2 short 和 long

```cpp
#include <iostream>

int main() {
    short s = 100;           // short int
    short int si = 100;      // 等价
    
    long l = 100L;           // long int
    long int li = 100L;      // 等价
    
    long long ll = 100LL;    // long long int
    long long int lli = 100LL;  // 等价
    
    // 组合
    unsigned short us = 100;
    unsigned long ul = 100UL;
    unsigned long long ull = 100ULL;
    
    std::cout << "short: " << sizeof(short) << std::endl;
    std::cout << "long: " << sizeof(long) << std::endl;
    std::cout << "long long: " << sizeof(long long) << std::endl;
    
    return 0;
}
```

### 3.3 const 修饰符

```cpp
#include <iostream>

int main() {
    // 常量变量
    const int MAX_SIZE = 100;
    // MAX_SIZE = 200;  // 错误: 不能修改 const 变量
    
    // const 与指针
    int value = 10;
    int other = 20;
    
    // 指向常量的指针 (不能通过指针修改值)
    const int* ptr1 = &value;
    // *ptr1 = 20;  // 错误
    ptr1 = &other;  // OK: 可以改变指向
    
    // 常量指针 (不能改变指向)
    int* const ptr2 = &value;
    *ptr2 = 20;     // OK: 可以修改值
    // ptr2 = &other;  // 错误
    
    // 指向常量的常量指针
    const int* const ptr3 = &value;
    // *ptr3 = 20;     // 错误
    // ptr3 = &other;  // 错误
    
    std::cout << "value = " << value << std::endl;
    
    return 0;
}
```

### 3.4 volatile 修饰符

```cpp
#include <iostream>

// volatile 告诉编译器不要优化这个变量
// 常用于:
// 1. 硬件寄存器
// 2. 多线程共享变量 (不推荐,应使用 atomic)
// 3. 信号处理程序

volatile int flag = 0;

void signalHandler(int) {
    flag = 1;
}

int main() {
    // 编译器不会优化掉对 flag 的读取
    while (flag == 0) {
        // 等待
    }
    
    std::cout << "Flag changed!" << std::endl;
    
    return 0;
}
```

---

## 4. 类型转换

### 4.1 隐式转换

```cpp
#include <iostream>

int main() {
    // 整数提升
    char c = 'A';
    int i = c;  // char -> int
    
    // 算术转换
    int a = 10;
    double b = 3.14;
    double result = a + b;  // int -> double
    
    // 赋值转换
    int x = 3.99;  // double -> int (截断)
    std::cout << "x = " << x << std::endl;  // 3
    
    // bool 转换
    int y = 0;
    if (y) {  // int -> bool
        std::cout << "y is true" << std::endl;
    }
    
    // 警告: 窄化转换
    int large = 1000;
    char small = large;  // 可能丢失数据
    std::cout << "small = " << static_cast<int>(small) << std::endl;
    
    return 0;
}
```

### 4.2 显式转换 (C 风格)

```cpp
#include <iostream>

int main() {
    // C 风格转换 (不推荐)
    double d = 3.14;
    int i = (int)d;
    int j = int(d);  // 函数风格
    
    std::cout << "i = " << i << std::endl;
    std::cout << "j = " << j << std::endl;
    
    // 指针转换
    int* ptr = nullptr;
    void* vptr = (void*)ptr;
    int* ptr2 = (int*)vptr;
    
    return 0;
}
```

### 4.3 C++ 风格转换 (推荐)

```cpp
#include <iostream>

int main() {
    // static_cast: 编译时检查的转换
    double d = 3.14;
    int i = static_cast<int>(d);
    
    // const_cast: 移除或添加 const
    const int ci = 10;
    int* pi = const_cast<int*>(&ci);
    // *pi = 20;  // 未定义行为!
    
    // reinterpret_cast: 位模式重新解释
    int x = 42;
    int* px = &x;
    long addr = reinterpret_cast<long>(px);
    std::cout << "Address: " << addr << std::endl;
    
    // dynamic_cast: 运行时类型检查 (用于多态)
    // 在后续面向对象章节详细讲解
    
    return 0;
}
```

### 4.4 类型转换最佳实践

```cpp
#include <iostream>
#include <cstdint>

int main() {
    // 1. 优先使用 static_cast
    double pi = 3.14159;
    int truncated = static_cast<int>(pi);
    
    // 2. 避免窄化转换
    int64_t big = 1000000000000LL;
    // int32_t small = big;  // 危险!
    
    // 3. 使用 {} 初始化检测窄化
    // int32_t safe{big};  // 编译错误
    
    // 4. 显式处理符号转换
    int negative = -1;
    unsigned int positive = static_cast<unsigned int>(negative);
    std::cout << "negative as unsigned: " << positive << std::endl;
    
    // 5. 检查范围
    if (big <= INT32_MAX && big >= INT32_MIN) {
        int32_t safe = static_cast<int32_t>(big);
    }
    
    return 0;
}
```

---

## 5. 常量

### 5.1 字面量

```cpp
#include <iostream>

int main() {
    // 整数字面量
    int dec = 42;        // 十进制
    int oct = 052;       // 八进制 (0 前缀)
    int hex = 0x2A;      // 十六进制 (0x 前缀)
    int bin = 0b101010;  // 二进制 (C++14, 0b 前缀)
    
    // 数字分隔符 (C++14)
    int million = 1'000'000;
    int binary = 0b1010'1010;
    
    // 后缀
    long l = 42L;
    unsigned u = 42U;
    unsigned long ul = 42UL;
    long long ll = 42LL;
    
    // 浮点字面量
    double d1 = 3.14;
    double d2 = 3.14e10;
    float f = 3.14f;
    long double ld = 3.14L;
    
    // 字符字面量
    char c = 'A';
    wchar_t wc = L'A';
    char16_t c16 = u'A';
    char32_t c32 = U'A';
    
    // 字符串字面量
    const char* s1 = "Hello";
    const wchar_t* s2 = L"Hello";
    const char16_t* s3 = u"Hello";
    const char32_t* s4 = U"Hello";
    const char* s5 = u8"Hello";  // UTF-8
    
    // 原始字符串 (C++11)
    const char* raw = R"(Line 1
Line 2
Path: C:\Users\Name)";
    
    std::cout << raw << std::endl;
    
    return 0;
}
```

### 5.2 const 常量

```cpp
#include <iostream>

// 全局常量
const double PI = 3.14159265358979;
const int MAX_BUFFER_SIZE = 1024;

int main() {
    // 局部常量
    const int localConst = 100;
    
    // 必须初始化
    // const int uninit;  // 错误
    
    // 编译时常量
    const int size = 10;
    int array[size];  // OK: size 是编译时常量
    
    std::cout << "PI = " << PI << std::endl;
    
    return 0;
}
```

### 5.3 constexpr (C++11)

```cpp
#include <iostream>

// constexpr 函数
constexpr int square(int x) {
    return x * x;
}

constexpr int factorial(int n) {
    return n <= 1 ? 1 : n * factorial(n - 1);
}

int main() {
    // constexpr 变量: 编译时常量
    constexpr int size = 10;
    constexpr double pi = 3.14159;
    
    // 编译时计算
    constexpr int sq = square(5);
    constexpr int fact = factorial(5);
    
    // 可用于数组大小
    int array[sq];
    
    std::cout << "square(5) = " << sq << std::endl;
    std::cout << "factorial(5) = " << fact << std::endl;
    
    // 运行时调用也可以
    int x = 10;
    int result = square(x);  // 运行时计算
    
    return 0;
}
```

### 5.4 枚举常量

```cpp
#include <iostream>

// 传统枚举
enum Color {
    RED,      // 0
    GREEN,    // 1
    BLUE      // 2
};

enum Size {
    SMALL = 1,
    MEDIUM = 5,
    LARGE = 10
};

// 强类型枚举 (C++11, 推荐)
enum class Status {
    OK,
    ERROR,
    PENDING
};

enum class Priority : uint8_t {
    LOW = 1,
    MEDIUM = 2,
    HIGH = 3
};

int main() {
    // 传统枚举
    Color c = RED;
    int colorValue = c;  // 隐式转换为 int
    
    // 强类型枚举
    Status s = Status::OK;
    // int statusValue = s;  // 错误: 不能隐式转换
    int statusValue = static_cast<int>(s);
    
    Priority p = Priority::HIGH;
    
    // switch 使用
    switch (s) {
        case Status::OK:
            std::cout << "OK" << std::endl;
            break;
        case Status::ERROR:
            std::cout << "ERROR" << std::endl;
            break;
        case Status::PENDING:
            std::cout << "PENDING" << std::endl;
            break;
    }
    
    return 0;
}
```

---

## 6. 类型别名

### 6.1 typedef

```cpp
#include <iostream>
#include <vector>

// 基本类型别名
typedef unsigned int uint;
typedef unsigned long ulong;
typedef long long int64;

// 复杂类型别名
typedef int* IntPtr;
typedef int IntArray[10];
typedef int (*FuncPtr)(int, int);

// 容器类型别名
typedef std::vector<int> IntVector;
typedef std::vector<std::vector<int>> IntMatrix;

int add(int a, int b) { return a + b; }

int main() {
    uint x = 100;
    IntPtr ptr = &x;
    IntArray arr = {1, 2, 3};
    FuncPtr fp = add;
    
    IntVector vec = {1, 2, 3, 4, 5};
    
    std::cout << "x = " << x << std::endl;
    std::cout << "add(3, 4) = " << fp(3, 4) << std::endl;
    
    return 0;
}
```

### 6.2 using (C++11, 推荐)

```cpp
#include <iostream>
#include <vector>
#include <map>
#include <functional>

// 基本类型别名
using uint = unsigned int;
using int64 = long long;

// 指针和数组
using IntPtr = int*;
using IntArray = int[10];

// 函数指针
using FuncPtr = int (*)(int, int);

// 更清晰的函数类型
using BinaryOp = std::function<int(int, int)>;

// 容器类型
using IntVector = std::vector<int>;
using StringMap = std::map<std::string, int>;

// 模板别名 (typedef 做不到)
template<typename T>
using Vec = std::vector<T>;

template<typename K, typename V>
using Map = std::map<K, V>;

int main() {
    Vec<int> intVec = {1, 2, 3};
    Vec<double> doubleVec = {1.1, 2.2, 3.3};
    Map<std::string, int> ages;
    
    ages["Alice"] = 25;
    ages["Bob"] = 30;
    
    for (const auto& [name, age] : ages) {
        std::cout << name << ": " << age << std::endl;
    }
    
    return 0;
}
```

---

## 7. auto 类型推导

### 7.1 auto 基础

```cpp
#include <iostream>
#include <vector>
#include <map>

int main() {
    // 基本类型推导
    auto i = 42;        // int
    auto d = 3.14;      // double
    auto c = 'A';       // char
    auto s = "Hello";   // const char*
    
    // 复杂类型推导
    std::vector<int> vec = {1, 2, 3};
    auto it = vec.begin();  // std::vector<int>::iterator
    
    std::map<std::string, int> ages = {{"Alice", 25}, {"Bob", 30}};
    auto mapIt = ages.begin();  // std::map<...>::iterator
    
    // 范围 for 循环
    for (auto& v : vec) {
        v *= 2;
    }
    
    for (const auto& [name, age] : ages) {
        std::cout << name << ": " << age << std::endl;
    }
    
    return 0;
}
```

### 7.2 auto 规则

```cpp
#include <iostream>

int main() {
    int x = 10;
    const int cx = 20;
    const int& rx = x;
    
    // auto 会丢弃顶层 const 和引用
    auto a = x;    // int
    auto b = cx;   // int (丢弃 const)
    auto c = rx;   // int (丢弃 const 和引用)
    
    // 保留 const 和引用
    const auto d = x;   // const int
    auto& e = x;        // int&
    const auto& f = x;  // const int&
    auto&& g = x;       // int& (左值)
    auto&& h = 42;      // int&& (右值)
    
    // 指针
    int* ptr = &x;
    auto p1 = ptr;   // int*
    auto* p2 = ptr;  // int* (更明确)
    
    return 0;
}
```

### 7.3 decltype

```cpp
#include <iostream>
#include <vector>

int main() {
    int x = 10;
    const int cx = 20;
    
    // decltype 保留完整类型
    decltype(x) a = 5;     // int
    decltype(cx) b = 10;   // const int
    decltype((x)) c = x;   // int& (注意双括号)
    
    // 用于函数返回类型
    std::vector<int> vec = {1, 2, 3};
    decltype(vec.begin()) it = vec.begin();
    
    // decltype(auto) (C++14)
    decltype(auto) d = x;      // int
    decltype(auto) e = (x);    // int&
    decltype(auto) f = cx;     // const int
    
    return 0;
}
```

---

## 8. 总结

### 8.1 类型大小表

| 类型 | 大小 (字节) | 范围 |
|------|------------|------|
| bool | 1 | true/false |
| char | 1 | -128 ~ 127 |
| short | 2 | -32768 ~ 32767 |
| int | 4 | -2^31 ~ 2^31-1 |
| long long | 8 | -2^63 ~ 2^63-1 |
| float | 4 | 约 7 位精度 |
| double | 8 | 约 15 位精度 |

### 8.2 最佳实践

```
1. 优先使用固定宽度类型 (int32_t, uint64_t)
2. 使用 {} 初始化防止窄化转换
3. 使用 const/constexpr 定义常量
4. 使用 auto 简化复杂类型声明
5. 使用 static_cast 进行类型转换
6. 使用 enum class 而非传统 enum
7. 使用 using 而非 typedef
```

### 8.3 下一篇预告

在下一篇文章中,我们将学习 C++ 的运算符。

---

## 参考资料

1. [C++ Type System](https://en.cppreference.com/w/cpp/language/type)
2. [Fundamental Types](https://en.cppreference.com/w/cpp/language/types)

---

> 作者: C++ 技术专栏  
> 系列: C++ 基础入门 (3/8)  
> 上一篇: [第一个 C++ 程序](./02-first-program.md)  
> 下一篇: [运算符](./04-operators.md)
