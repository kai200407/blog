---
title: "右值引用与移动语义"
description: "1. [左值与右值](#1-左值与右值)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 32
---

> 本文是 C++ 从入门到精通系列的第三十二篇,将深入讲解 C++11 引入的右值引用和移动语义。

---

## 目录

1. [左值与右值](#1-左值与右值)
2. [右值引用](#2-右值引用)
3. [移动语义](#3-移动语义)
4. [完美转发](#4-完美转发)
5. [移动语义最佳实践](#5-移动语义最佳实践)
6. [总结](#6-总结)

---

## 1. 左值与右值

### 1.1 基本概念

```cpp
#include <iostream>
#include <string>

int getValue() { return 42; }
int& getRef() { static int x = 10; return x; }

int main() {
    // 左值 (lvalue): 有持久身份,可以取地址
    int x = 10;           // x 是左值
    int* px = &x;         // 可以取地址
    
    int& ref = x;         // 左值引用绑定左值
    
    // 右值 (rvalue): 临时的,不能取地址
    // int* p = &42;      // 错误: 不能取右值的地址
    // int& r = 42;       // 错误: 左值引用不能绑定右值
    
    const int& cr = 42;   // const 左值引用可以绑定右值
    
    // 表达式的值类别
    x = 10;               // x 是左值
    getValue();           // 返回右值
    getRef();             // 返回左值
    
    x + 1;                // 右值
    ++x;                  // 左值 (前置递增)
    x++;                  // 右值 (后置递增)
    
    return 0;
}
```

### 1.2 值类别详解

```
C++11 值类别:

        表达式
       /      \
    glvalue   rvalue
    /    \    /    \
 lvalue  xvalue  prvalue

lvalue (左值):
- 有名字的对象
- 可以取地址
- 例: 变量, *ptr, arr[i]

prvalue (纯右值):
- 临时值
- 字面量
- 例: 42, true, nullptr

xvalue (将亡值):
- 即将被移动的对象
- 例: std::move(x), 返回右值引用的函数
```

---

## 2. 右值引用

### 2.1 基本语法

```cpp
#include <iostream>
#include <string>

int main() {
    int x = 10;
    
    // 左值引用
    int& lref = x;
    // int& lref2 = 42;  // 错误
    
    // 右值引用
    int&& rref = 42;     // OK: 绑定右值
    // int&& rref2 = x;  // 错误: 不能绑定左值
    
    int&& rref3 = std::move(x);  // OK: std::move 将左值转为右值
    
    // 右值引用本身是左值
    int&& rref4 = 100;
    int& lref2 = rref4;  // OK: rref4 是左值
    // int&& rref5 = rref4;  // 错误: rref4 是左值
    
    std::cout << "rref: " << rref << std::endl;
    
    // 可以修改右值引用
    rref = 200;
    std::cout << "rref after modify: " << rref << std::endl;
    
    return 0;
}
```

### 2.2 std::move

```cpp
#include <iostream>
#include <string>
#include <utility>

int main() {
    std::string s1 = "Hello, World!";
    
    // std::move 不移动任何东西,只是类型转换
    std::string&& rref = std::move(s1);
    
    // s1 仍然有效
    std::cout << "s1: " << s1 << std::endl;
    
    // 真正的移动发生在移动构造/赋值时
    std::string s2 = std::move(s1);
    
    // s1 现在处于有效但未指定的状态
    std::cout << "s1 after move: \"" << s1 << "\"" << std::endl;
    std::cout << "s2: " << s2 << std::endl;
    
    return 0;
}
```

---

## 3. 移动语义

### 3.1 移动构造函数

```cpp
#include <iostream>
#include <cstring>

class String {
public:
    // 默认构造
    String() : data(nullptr), size(0) {
        std::cout << "Default constructor" << std::endl;
    }
    
    // 参数构造
    String(const char* str) {
        size = strlen(str);
        data = new char[size + 1];
        strcpy(data, str);
        std::cout << "Constructor: " << data << std::endl;
    }
    
    // 拷贝构造
    String(const String& other) {
        size = other.size;
        data = new char[size + 1];
        strcpy(data, other.data);
        std::cout << "Copy constructor: " << data << std::endl;
    }
    
    // 移动构造
    String(String&& other) noexcept {
        data = other.data;
        size = other.size;
        other.data = nullptr;
        other.size = 0;
        std::cout << "Move constructor: " << data << std::endl;
    }
    
    // 析构
    ~String() {
        if (data) {
            std::cout << "Destructor: " << data << std::endl;
        }
        delete[] data;
    }
    
    const char* c_str() const { return data ? data : ""; }

private:
    char* data;
    size_t size;
};

int main() {
    String s1("Hello");
    
    std::cout << "\n--- Copy ---" << std::endl;
    String s2 = s1;  // 拷贝构造
    
    std::cout << "\n--- Move ---" << std::endl;
    String s3 = std::move(s1);  // 移动构造
    
    std::cout << "\n--- End ---" << std::endl;
    std::cout << "s1: \"" << s1.c_str() << "\"" << std::endl;
    std::cout << "s2: \"" << s2.c_str() << "\"" << std::endl;
    std::cout << "s3: \"" << s3.c_str() << "\"" << std::endl;
    
    return 0;
}
```

### 3.2 移动赋值运算符

```cpp
#include <iostream>
#include <cstring>

class Buffer {
public:
    Buffer(size_t size) : size(size), data(new int[size]) {
        std::cout << "Constructor: size=" << size << std::endl;
    }
    
    // 拷贝赋值
    Buffer& operator=(const Buffer& other) {
        std::cout << "Copy assignment" << std::endl;
        if (this != &other) {
            delete[] data;
            size = other.size;
            data = new int[size];
            std::copy(other.data, other.data + size, data);
        }
        return *this;
    }
    
    // 移动赋值
    Buffer& operator=(Buffer&& other) noexcept {
        std::cout << "Move assignment" << std::endl;
        if (this != &other) {
            delete[] data;
            data = other.data;
            size = other.size;
            other.data = nullptr;
            other.size = 0;
        }
        return *this;
    }
    
    ~Buffer() {
        delete[] data;
    }

private:
    size_t size;
    int* data;
};

int main() {
    Buffer b1(100);
    Buffer b2(50);
    
    std::cout << "\n--- Copy assignment ---" << std::endl;
    b2 = b1;
    
    Buffer b3(200);
    std::cout << "\n--- Move assignment ---" << std::endl;
    b3 = std::move(b1);
    
    return 0;
}
```

### 3.3 noexcept 的重要性

```cpp
#include <iostream>
#include <vector>

class Widget {
public:
    Widget() { std::cout << "Default" << std::endl; }
    Widget(const Widget&) { std::cout << "Copy" << std::endl; }
    
    // 不带 noexcept 的移动构造
    // Widget(Widget&&) { std::cout << "Move" << std::endl; }
    
    // 带 noexcept 的移动构造
    Widget(Widget&&) noexcept { std::cout << "Move" << std::endl; }
};

int main() {
    std::vector<Widget> vec;
    vec.reserve(2);
    
    std::cout << "--- Push 1 ---" << std::endl;
    vec.push_back(Widget());
    
    std::cout << "--- Push 2 ---" << std::endl;
    vec.push_back(Widget());
    
    std::cout << "--- Push 3 (triggers reallocation) ---" << std::endl;
    vec.push_back(Widget());
    
    // 如果移动构造不是 noexcept,vector 会使用拷贝构造
    // 因为拷贝构造提供强异常保证
    
    return 0;
}
```

---

## 4. 完美转发

### 4.1 转发引用

```cpp
#include <iostream>
#include <utility>

void process(int& x) {
    std::cout << "lvalue: " << x << std::endl;
}

void process(int&& x) {
    std::cout << "rvalue: " << x << std::endl;
}

// 转发引用 (universal reference)
template<typename T>
void wrapper(T&& arg) {
    // 不使用 forward: 总是调用左值版本
    // process(arg);
    
    // 使用 forward: 保持值类别
    process(std::forward<T>(arg));
}

int main() {
    int x = 10;
    
    wrapper(x);      // 调用 process(int&)
    wrapper(42);     // 调用 process(int&&)
    wrapper(std::move(x));  // 调用 process(int&&)
    
    return 0;
}
```

### 4.2 std::forward

```cpp
#include <iostream>
#include <utility>
#include <string>

class Widget {
public:
    Widget(const std::string& name) : name(name) {
        std::cout << "Copy: " << name << std::endl;
    }
    
    Widget(std::string&& name) : name(std::move(name)) {
        std::cout << "Move: " << this->name << std::endl;
    }

private:
    std::string name;
};

// 工厂函数
template<typename... Args>
Widget createWidget(Args&&... args) {
    return Widget(std::forward<Args>(args)...);
}

int main() {
    std::string name = "Widget1";
    
    std::cout << "--- Create with lvalue ---" << std::endl;
    auto w1 = createWidget(name);
    
    std::cout << "\n--- Create with rvalue ---" << std::endl;
    auto w2 = createWidget(std::string("Widget2"));
    
    std::cout << "\n--- Create with move ---" << std::endl;
    auto w3 = createWidget(std::move(name));
    
    return 0;
}
```

### 4.3 引用折叠

```cpp
#include <iostream>
#include <type_traits>

/*
引用折叠规则:
T& &   -> T&
T& &&  -> T&
T&& &  -> T&
T&& && -> T&&

只有 && && 才会变成 &&
*/

template<typename T>
void showType(T&& arg) {
    if constexpr (std::is_lvalue_reference_v<T>) {
        std::cout << "T is lvalue reference" << std::endl;
    } else {
        std::cout << "T is not reference" << std::endl;
    }
    
    if constexpr (std::is_lvalue_reference_v<decltype(arg)>) {
        std::cout << "arg is lvalue reference" << std::endl;
    } else if constexpr (std::is_rvalue_reference_v<decltype(arg)>) {
        std::cout << "arg is rvalue reference" << std::endl;
    }
}

int main() {
    int x = 10;
    
    std::cout << "--- lvalue ---" << std::endl;
    showType(x);      // T = int&, T&& = int& && = int&
    
    std::cout << "\n--- rvalue ---" << std::endl;
    showType(42);     // T = int, T&& = int&&
    
    return 0;
}
```

---

## 5. 移动语义最佳实践

### 5.1 Rule of Five

```cpp
#include <iostream>
#include <cstring>

class Resource {
public:
    // 1. 构造函数
    Resource(const char* data = "") {
        size = strlen(data);
        this->data = new char[size + 1];
        strcpy(this->data, data);
    }
    
    // 2. 析构函数
    ~Resource() {
        delete[] data;
    }
    
    // 3. 拷贝构造函数
    Resource(const Resource& other) {
        size = other.size;
        data = new char[size + 1];
        strcpy(data, other.data);
    }
    
    // 4. 拷贝赋值运算符
    Resource& operator=(const Resource& other) {
        if (this != &other) {
            delete[] data;
            size = other.size;
            data = new char[size + 1];
            strcpy(data, other.data);
        }
        return *this;
    }
    
    // 5. 移动构造函数
    Resource(Resource&& other) noexcept
        : data(other.data), size(other.size) {
        other.data = nullptr;
        other.size = 0;
    }
    
    // 6. 移动赋值运算符
    Resource& operator=(Resource&& other) noexcept {
        if (this != &other) {
            delete[] data;
            data = other.data;
            size = other.size;
            other.data = nullptr;
            other.size = 0;
        }
        return *this;
    }

private:
    char* data;
    size_t size;
};
```

### 5.2 何时使用 std::move

```cpp
#include <iostream>
#include <string>
#include <vector>

class Widget {
public:
    // 接受值并移动
    void setName(std::string name) {
        this->name = std::move(name);
    }
    
    // 或者提供两个重载
    void setData(const std::string& data) {
        this->data = data;
    }
    
    void setData(std::string&& data) {
        this->data = std::move(data);
    }

private:
    std::string name;
    std::string data;
};

int main() {
    Widget w;
    
    std::string name = "Widget";
    w.setName(name);  // 拷贝 + 移动
    w.setName(std::move(name));  // 移动 + 移动
    w.setName("Temp");  // 移动
    
    // 不要对局部变量 return 使用 std::move
    // return std::move(local);  // 错误: 阻止 RVO
    // return local;  // 正确: 允许 RVO
    
    return 0;
}
```

### 5.3 移动后的状态

```cpp
#include <iostream>
#include <string>
#include <vector>

int main() {
    std::string s = "Hello";
    std::string s2 = std::move(s);
    
    // 移动后的对象处于有效但未指定的状态
    // 可以安全地:
    // 1. 销毁
    // 2. 赋予新值
    // 3. 调用不依赖当前状态的操作
    
    s = "World";  // OK: 赋予新值
    std::cout << s << std::endl;
    
    std::vector<int> v = {1, 2, 3};
    std::vector<int> v2 = std::move(v);
    
    v.clear();  // OK
    v.push_back(10);  // OK
    std::cout << v.size() << std::endl;
    
    return 0;
}
```

---

## 6. 总结

### 6.1 关键概念

| 概念 | 说明 |
|------|------|
| 左值 | 有持久身份,可取地址 |
| 右值 | 临时的,即将销毁 |
| 右值引用 | T&&,绑定右值 |
| std::move | 将左值转为右值 |
| std::forward | 保持值类别 |
| 移动构造 | 窃取资源 |
| noexcept | 保证不抛异常 |

### 6.2 最佳实践

```
1. 移动构造/赋值标记 noexcept
2. 移动后对象置于有效状态
3. 不要对返回值使用 std::move
4. 使用 std::forward 完美转发
5. 遵循 Rule of Five
```

### 6.3 下一篇预告

在下一篇文章中,我们将学习变参模板。

---

> 作者: C++ 技术专栏  
> 系列: 现代 C++ (2/10)  
> 上一篇: [auto 与类型推导](./31-auto-type-deduction.md)  
> 下一篇: [变参模板](./33-variadic-templates.md)
