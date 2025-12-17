---
title: "第一个 C++ 程序"
description: "1. [Hello World](#1-hello-world)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 2
---

> 本文是 C++ 从入门到精通系列的第二篇,将通过编写第一个 C++ 程序,深入理解程序的结构、编译链接过程以及程序执行原理。

---

## 目录

1. [Hello World](#1-hello-world)
2. [程序结构解析](#2-程序结构解析)
3. [编译链接过程](#3-编译链接过程)
4. [预处理器](#4-预处理器)
5. [命名空间](#5-命名空间)
6. [输入输出](#6-输入输出)
7. [注释与代码风格](#7-注释与代码风格)
8. [总结](#8-总结)

---

## 1. Hello World

### 1.1 最简单的程序

```cpp
// hello.cpp
#include <iostream>

int main() {
    std::cout << "Hello, World!" << std::endl;
    return 0;
}
```

### 1.2 编译运行

```bash
# 编译
g++ -std=c++20 hello.cpp -o hello

# 运行
./hello

# 输出
Hello, World!
```

### 1.3 程序执行流程

```
程序执行流程:

源代码 (.cpp)
     │
     ▼
┌─────────────┐
│   预处理    │  处理 #include, #define 等
└─────────────┘
     │
     ▼
┌─────────────┐
│   编译      │  生成汇编代码
└─────────────┘
     │
     ▼
┌─────────────┐
│   汇编      │  生成目标文件 (.o)
└─────────────┘
     │
     ▼
┌─────────────┐
│   链接      │  链接库文件,生成可执行文件
└─────────────┘
     │
     ▼
可执行文件
```

---

## 2. 程序结构解析

### 2.1 逐行解析

```cpp
// 第 1 行: 预处理指令
// 包含标准输入输出流头文件
#include <iostream>

// 第 2 行: 主函数
// 程序入口点,返回类型为 int
int main() {
    // 第 3 行: 输出语句
    // std::cout 是标准输出流
    // << 是流插入运算符
    // std::endl 是换行并刷新缓冲区
    std::cout << "Hello, World!" << std::endl;
    
    // 第 4 行: 返回值
    // 0 表示程序正常结束
    return 0;
}
```

### 2.2 main 函数

```cpp
// main 函数的几种形式

// 形式 1: 无参数
int main() {
    return 0;
}

// 形式 2: 带命令行参数
int main(int argc, char* argv[]) {
    // argc: 参数个数
    // argv: 参数数组
    return 0;
}

// 形式 3: 带环境变量 (非标准,但广泛支持)
int main(int argc, char* argv[], char* envp[]) {
    return 0;
}
```

### 2.3 命令行参数示例

```cpp
#include <iostream>

int main(int argc, char* argv[]) {
    std::cout << "参数个数: " << argc << std::endl;
    
    for (int i = 0; i < argc; ++i) {
        std::cout << "argv[" << i << "] = " << argv[i] << std::endl;
    }
    
    return 0;
}
```

```bash
# 编译运行
g++ args.cpp -o args
./args hello world 123

# 输出
参数个数: 4
argv[0] = ./args
argv[1] = hello
argv[2] = world
argv[3] = 123
```

### 2.4 返回值含义

```cpp
#include <cstdlib>  // EXIT_SUCCESS, EXIT_FAILURE

int main() {
    // 返回 0 或 EXIT_SUCCESS 表示成功
    // 返回非 0 或 EXIT_FAILURE 表示失败
    
    bool success = true;
    
    if (success) {
        return EXIT_SUCCESS;  // 等价于 return 0;
    } else {
        return EXIT_FAILURE;  // 等价于 return 1;
    }
}
```

```bash
# 检查返回值
./program
echo $?  # Linux/macOS
echo %ERRORLEVEL%  # Windows
```

---

## 3. 编译链接过程

### 3.1 分步编译

```bash
# 步骤 1: 预处理 (-E)
g++ -E hello.cpp -o hello.i

# 步骤 2: 编译 (-S)
g++ -S hello.i -o hello.s

# 步骤 3: 汇编 (-c)
g++ -c hello.s -o hello.o

# 步骤 4: 链接
g++ hello.o -o hello
```

### 3.2 预处理结果

```cpp
// hello.i (部分内容)
// 展开了 <iostream> 的所有内容
// 可能有数万行代码

// ... 大量标准库代码 ...

int main() {
    std::cout << "Hello, World!" << std::endl;
    return 0;
}
```

### 3.3 汇编代码

```asm
# hello.s (x86-64, 简化版)
    .file   "hello.cpp"
    .text
    .section    .rodata
.LC0:
    .string "Hello, World!"
    .text
    .globl  main
    .type   main, @function
main:
    pushq   %rbp
    movq    %rsp, %rbp
    # 调用 cout << "Hello, World!"
    leaq    .LC0(%rip), %rsi
    leaq    _ZSt4cout(%rip), %rdi
    call    _ZStlsISt11char_traitsIcEERSt13basic_ostreamIcT_ES5_PKc@PLT
    # 调用 endl
    movq    %rax, %rdi
    call    _ZSt4endlIcSt11char_traitsIcEERSt13basic_ostreamIT_T0_ES6_@PLT
    # return 0
    movl    $0, %eax
    popq    %rbp
    ret
```

### 3.4 多文件编译

```cpp
// math.h
#ifndef MATH_H
#define MATH_H

int add(int a, int b);
int multiply(int a, int b);

#endif
```

```cpp
// math.cpp
#include "math.h"

int add(int a, int b) {
    return a + b;
}

int multiply(int a, int b) {
    return a * b;
}
```

```cpp
// main.cpp
#include <iostream>
#include "math.h"

int main() {
    std::cout << "3 + 4 = " << add(3, 4) << std::endl;
    std::cout << "3 * 4 = " << multiply(3, 4) << std::endl;
    return 0;
}
```

```bash
# 分别编译
g++ -c math.cpp -o math.o
g++ -c main.cpp -o main.o

# 链接
g++ math.o main.o -o program

# 或一步完成
g++ math.cpp main.cpp -o program
```

---

## 4. 预处理器

### 4.1 #include 指令

```cpp
// 系统头文件 (在系统目录搜索)
#include <iostream>
#include <vector>
#include <string>

// 用户头文件 (先在当前目录搜索)
#include "myheader.h"
#include "../common/utils.h"
```

### 4.2 #define 宏

```cpp
// 常量宏
#define PI 3.14159
#define MAX_SIZE 100

// 函数宏 (不推荐,建议用 inline 函数)
#define SQUARE(x) ((x) * (x))
#define MAX(a, b) ((a) > (b) ? (a) : (b))

int main() {
    double area = PI * 5 * 5;
    int sq = SQUARE(4);  // 展开为 ((4) * (4))
    return 0;
}
```

### 4.3 条件编译

```cpp
// 防止头文件重复包含
#ifndef MY_HEADER_H
#define MY_HEADER_H

// 头文件内容

#endif

// 或使用 #pragma once (非标准但广泛支持)
#pragma once

// 条件编译
#ifdef DEBUG
    std::cout << "Debug mode" << std::endl;
#endif

#if __cplusplus >= 202002L
    // C++20 代码
#elif __cplusplus >= 201703L
    // C++17 代码
#else
    // 旧版本代码
#endif

// 平台相关
#ifdef _WIN32
    // Windows 代码
#elif defined(__linux__)
    // Linux 代码
#elif defined(__APPLE__)
    // macOS 代码
#endif
```

### 4.4 预定义宏

```cpp
#include <iostream>

int main() {
    std::cout << "文件: " << __FILE__ << std::endl;
    std::cout << "行号: " << __LINE__ << std::endl;
    std::cout << "函数: " << __func__ << std::endl;
    std::cout << "日期: " << __DATE__ << std::endl;
    std::cout << "时间: " << __TIME__ << std::endl;
    std::cout << "C++ 标准: " << __cplusplus << std::endl;
    
    return 0;
}
```

---

## 5. 命名空间

### 5.1 std 命名空间

```cpp
#include <iostream>
#include <string>
#include <vector>

int main() {
    // 方式 1: 完全限定名
    std::cout << "Hello" << std::endl;
    std::string name = "World";
    std::vector<int> numbers;
    
    return 0;
}
```

### 5.2 using 声明

```cpp
#include <iostream>
#include <string>

// 方式 2: using 声明 (引入特定名称)
using std::cout;
using std::endl;
using std::string;

int main() {
    cout << "Hello" << endl;
    string name = "World";
    return 0;
}
```

### 5.3 using 指令

```cpp
#include <iostream>
#include <string>

// 方式 3: using 指令 (引入整个命名空间)
// 不推荐在头文件中使用
using namespace std;

int main() {
    cout << "Hello" << endl;
    string name = "World";
    return 0;
}
```

### 5.4 自定义命名空间

```cpp
#include <iostream>

// 定义命名空间
namespace MyLib {
    int value = 42;
    
    void print() {
        std::cout << "MyLib::print()" << std::endl;
    }
    
    namespace Inner {
        void func() {
            std::cout << "MyLib::Inner::func()" << std::endl;
        }
    }
}

// 命名空间别名
namespace ML = MyLib;
namespace MLI = MyLib::Inner;

int main() {
    std::cout << MyLib::value << std::endl;
    MyLib::print();
    MyLib::Inner::func();
    
    // 使用别名
    ML::print();
    MLI::func();
    
    return 0;
}
```

---

## 6. 输入输出

### 6.1 标准输出 cout

```cpp
#include <iostream>

int main() {
    int num = 42;
    double pi = 3.14159;
    char ch = 'A';
    const char* str = "Hello";
    
    // 基本输出
    std::cout << "Number: " << num << std::endl;
    std::cout << "Pi: " << pi << std::endl;
    std::cout << "Char: " << ch << std::endl;
    std::cout << "String: " << str << std::endl;
    
    // 链式输出
    std::cout << "Values: " << num << ", " << pi << ", " << ch << std::endl;
    
    // 不换行
    std::cout << "No newline";
    std::cout << " - Same line" << std::endl;
    
    return 0;
}
```

### 6.2 标准输入 cin

```cpp
#include <iostream>
#include <string>

int main() {
    // 读取整数
    int age;
    std::cout << "请输入年龄: ";
    std::cin >> age;
    
    // 读取浮点数
    double height;
    std::cout << "请输入身高: ";
    std::cin >> height;
    
    // 读取字符串 (空格分隔)
    std::string firstName;
    std::cout << "请输入名字: ";
    std::cin >> firstName;
    
    // 读取整行 (包含空格)
    std::cin.ignore();  // 忽略之前的换行符
    std::string fullName;
    std::cout << "请输入全名: ";
    std::getline(std::cin, fullName);
    
    std::cout << "年龄: " << age << std::endl;
    std::cout << "身高: " << height << std::endl;
    std::cout << "名字: " << firstName << std::endl;
    std::cout << "全名: " << fullName << std::endl;
    
    return 0;
}
```

### 6.3 格式化输出

```cpp
#include <iostream>
#include <iomanip>

int main() {
    int num = 255;
    double pi = 3.14159265358979;
    
    // 进制转换
    std::cout << "十进制: " << std::dec << num << std::endl;
    std::cout << "十六进制: " << std::hex << num << std::endl;
    std::cout << "八进制: " << std::oct << num << std::endl;
    std::cout << std::dec;  // 恢复十进制
    
    // 浮点数精度
    std::cout << "默认: " << pi << std::endl;
    std::cout << "精度 3: " << std::setprecision(3) << pi << std::endl;
    std::cout << "固定 3: " << std::fixed << std::setprecision(3) << pi << std::endl;
    std::cout << "科学计数: " << std::scientific << pi << std::endl;
    
    // 宽度和填充
    std::cout << std::fixed << std::setprecision(2);
    std::cout << std::setw(10) << 42 << std::endl;
    std::cout << std::setw(10) << std::setfill('0') << 42 << std::endl;
    std::cout << std::left << std::setw(10) << std::setfill(' ') << 42 << std::endl;
    
    // 布尔值
    bool flag = true;
    std::cout << "默认: " << flag << std::endl;
    std::cout << "文字: " << std::boolalpha << flag << std::endl;
    
    return 0;
}
```

### 6.4 错误输出

```cpp
#include <iostream>

int main() {
    // 标准输出 (stdout)
    std::cout << "Normal output" << std::endl;
    
    // 标准错误 (stderr) - 不缓冲
    std::cerr << "Error message" << std::endl;
    
    // 标准日志 (stderr) - 缓冲
    std::clog << "Log message" << std::endl;
    
    return 0;
}
```

---

## 7. 注释与代码风格

### 7.1 注释类型

```cpp
// 单行注释

/*
 * 多行注释
 * 可以跨越多行
 */

/**
 * @brief 文档注释 (Doxygen 风格)
 * @param x 第一个参数
 * @param y 第二个参数
 * @return 返回两数之和
 */
int add(int x, int y) {
    return x + y;
}
```

### 7.2 代码风格

```cpp
// Google C++ Style Guide 示例

#include <iostream>
#include <string>
#include <vector>

// 常量命名: kCamelCase
const int kMaxSize = 100;

// 类命名: PascalCase
class MyClass {
public:
    // 方法命名: PascalCase
    void DoSomething();
    
    // 访问器: snake_case
    int value() const { return value_; }
    void set_value(int value) { value_ = value; }

private:
    // 成员变量: snake_case_
    int value_;
};

// 函数命名: PascalCase
void ProcessData(const std::vector<int>& data) {
    // 局部变量: snake_case
    int total_count = 0;
    
    for (const auto& item : data) {
        total_count += item;
    }
}

// 命名空间: snake_case
namespace my_project {

void HelperFunction() {
    // ...
}

}  // namespace my_project
```

### 7.3 头文件规范

```cpp
// my_class.h

#ifndef MY_PROJECT_MY_CLASS_H_
#define MY_PROJECT_MY_CLASS_H_

#include <string>
#include <vector>

namespace my_project {

class MyClass {
public:
    explicit MyClass(int value);
    ~MyClass();
    
    // 禁止拷贝
    MyClass(const MyClass&) = delete;
    MyClass& operator=(const MyClass&) = delete;
    
    // 允许移动
    MyClass(MyClass&&) = default;
    MyClass& operator=(MyClass&&) = default;
    
    void Process();
    int GetValue() const;

private:
    int value_;
    std::string name_;
};

}  // namespace my_project

#endif  // MY_PROJECT_MY_CLASS_H_
```

---

## 8. 总结

### 8.1 关键概念

| 概念 | 说明 |
|------|------|
| main 函数 | 程序入口点 |
| #include | 包含头文件 |
| 命名空间 | 避免名称冲突 |
| cout/cin | 标准输入输出 |
| 编译链接 | 源码到可执行文件 |

### 8.2 编译流程

```
源文件 (.cpp)
    │
    ├─ 预处理 ──> 展开的源文件 (.i)
    │
    ├─ 编译 ──> 汇编文件 (.s)
    │
    ├─ 汇编 ──> 目标文件 (.o)
    │
    └─ 链接 ──> 可执行文件
```

### 8.3 下一篇预告

在下一篇文章中,我们将学习 C++ 的变量与数据类型。

---

## 参考资料

1. [C++ Reference](https://en.cppreference.com/)
2. [Google C++ Style Guide](https://google.github.io/styleguide/cppguide.html)

---

> 作者: C++ 技术专栏  
> 系列: C++ 基础入门 (2/8)  
> 上一篇: [开发环境搭建](./01-environment-setup.md)  
> 下一篇: [变量与数据类型](./03-variables-types.md)
