---
title: "构造函数与析构函数"
description: "1. [构造函数基础](#1-构造函数基础)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 10
---

> 本文是 C++ 从入门到精通系列的第十篇,将深入讲解 C++ 的构造函数、析构函数以及对象的生命周期管理。

---

## 目录

1. [构造函数基础](#1-构造函数基础)
2. [构造函数类型](#2-构造函数类型)
3. [初始化列表](#3-初始化列表)
4. [析构函数](#4-析构函数)
5. [拷贝构造函数](#5-拷贝构造函数)
6. [移动构造函数](#6-移动构造函数)
7. [特殊成员函数](#7-特殊成员函数)
8. [总结](#8-总结)

---

## 1. 构造函数基础

### 1.1 构造函数定义

```cpp
#include <iostream>
#include <string>

class Person {
public:
    std::string name;
    int age;
    
    // 构造函数: 与类同名,无返回类型
    Person() {
        std::cout << "Default constructor called" << std::endl;
        name = "Unknown";
        age = 0;
    }
    
    // 带参数的构造函数
    Person(const std::string& n, int a) {
        std::cout << "Parameterized constructor called" << std::endl;
        name = n;
        age = a;
    }
    
    void print() const {
        std::cout << "Name: " << name << ", Age: " << age << std::endl;
    }
};

int main() {
    Person p1;              // 调用默认构造函数
    Person p2("Alice", 25); // 调用带参数的构造函数
    
    p1.print();
    p2.print();
    
    return 0;
}
```

### 1.2 构造函数重载

```cpp
#include <iostream>
#include <string>

class Rectangle {
public:
    double width, height;
    
    // 默认构造函数
    Rectangle() : width(0), height(0) {
        std::cout << "Default constructor" << std::endl;
    }
    
    // 单参数构造函数 (正方形)
    Rectangle(double side) : width(side), height(side) {
        std::cout << "Square constructor" << std::endl;
    }
    
    // 双参数构造函数
    Rectangle(double w, double h) : width(w), height(h) {
        std::cout << "Rectangle constructor" << std::endl;
    }
    
    double area() const { return width * height; }
};

int main() {
    Rectangle r1;           // 默认构造
    Rectangle r2(5);        // 正方形
    Rectangle r3(4, 6);     // 矩形
    
    std::cout << "r1 area: " << r1.area() << std::endl;
    std::cout << "r2 area: " << r2.area() << std::endl;
    std::cout << "r3 area: " << r3.area() << std::endl;
    
    return 0;
}
```

### 1.3 explicit 关键字

```cpp
#include <iostream>

class MyInt {
public:
    int value;
    
    // 没有 explicit: 允许隐式转换
    // MyInt(int v) : value(v) { }
    
    // 有 explicit: 禁止隐式转换
    explicit MyInt(int v) : value(v) { }
};

void process(MyInt m) {
    std::cout << "Value: " << m.value << std::endl;
}

int main() {
    MyInt m1(10);       // OK: 直接初始化
    MyInt m2 = MyInt(20); // OK: 显式转换
    
    // MyInt m3 = 30;   // 错误: 隐式转换被禁止
    // process(40);     // 错误: 隐式转换被禁止
    
    process(MyInt(40)); // OK: 显式转换
    
    return 0;
}
```

---

## 2. 构造函数类型

### 2.1 默认构造函数

```cpp
#include <iostream>

class A {
public:
    int x;
    // 编译器生成默认构造函数
};

class B {
public:
    int x;
    B(int v) : x(v) { }  // 定义了其他构造函数
    // 编译器不再生成默认构造函数
};

class C {
public:
    int x;
    C(int v) : x(v) { }
    C() = default;  // 显式要求生成默认构造函数
};

class D {
public:
    int x;
    D() = delete;  // 禁用默认构造函数
};

int main() {
    A a;        // OK
    // B b;     // 错误: 没有默认构造函数
    B b(10);    // OK
    C c;        // OK
    C c2(20);   // OK
    // D d;     // 错误: 默认构造函数被删除
    
    return 0;
}
```

### 2.2 委托构造函数 (C++11)

```cpp
#include <iostream>
#include <string>

class Person {
public:
    std::string name;
    int age;
    std::string address;
    
    // 主构造函数
    Person(const std::string& n, int a, const std::string& addr)
        : name(n), age(a), address(addr) {
        std::cout << "Main constructor" << std::endl;
    }
    
    // 委托构造函数
    Person() : Person("Unknown", 0, "N/A") {
        std::cout << "Default constructor (delegating)" << std::endl;
    }
    
    Person(const std::string& n) : Person(n, 0, "N/A") {
        std::cout << "Name-only constructor (delegating)" << std::endl;
    }
    
    Person(const std::string& n, int a) : Person(n, a, "N/A") {
        std::cout << "Name-age constructor (delegating)" << std::endl;
    }
};

int main() {
    Person p1;
    Person p2("Alice");
    Person p3("Bob", 30);
    Person p4("Charlie", 25, "123 Main St");
    
    return 0;
}
```

### 2.3 继承构造函数 (C++11)

```cpp
#include <iostream>

class Base {
public:
    int x;
    
    Base() : x(0) { }
    Base(int v) : x(v) { }
    Base(int v, int m) : x(v * m) { }
};

class Derived : public Base {
public:
    int y;
    
    // 继承基类的所有构造函数
    using Base::Base;
    
    // 可以添加自己的构造函数
    Derived(int v, int m, int n) : Base(v, m), y(n) { }
};

int main() {
    Derived d1;         // 使用 Base()
    Derived d2(10);     // 使用 Base(int)
    Derived d3(10, 2);  // 使用 Base(int, int)
    Derived d4(10, 2, 5); // 使用 Derived 自己的构造函数
    
    std::cout << "d2.x = " << d2.x << std::endl;
    std::cout << "d3.x = " << d3.x << std::endl;
    std::cout << "d4.x = " << d4.x << ", d4.y = " << d4.y << std::endl;
    
    return 0;
}
```

---

## 3. 初始化列表

### 3.1 初始化列表语法

```cpp
#include <iostream>
#include <string>

class Person {
public:
    std::string name;
    int age;
    const int id;
    int& ref;
    
    // 使用初始化列表
    Person(const std::string& n, int a, int i, int& r)
        : name(n), age(a), id(i), ref(r)  // 初始化列表
    {
        // 构造函数体
        std::cout << "Person created: " << name << std::endl;
    }
    
    // 错误示例: const 和引用成员必须在初始化列表中初始化
    // Person(const std::string& n, int a, int i, int& r) {
    //     name = n;
    //     age = a;
    //     id = i;   // 错误: const 成员
    //     ref = r;  // 错误: 引用成员
    // }
};

int main() {
    int refValue = 100;
    Person p("Alice", 25, 1001, refValue);
    
    std::cout << "ID: " << p.id << std::endl;
    std::cout << "Ref: " << p.ref << std::endl;
    
    return 0;
}
```

### 3.2 初始化顺序

```cpp
#include <iostream>

class Demo {
public:
    int a;
    int b;
    int c;
    
    // 初始化顺序由成员声明顺序决定,而非初始化列表顺序
    Demo(int x) : c(x), b(c + 1), a(b + 1) {
        // 实际初始化顺序: a, b, c (按声明顺序)
        // 这里会有问题: a 先初始化,但 b 还未初始化
    }
    
    void print() {
        std::cout << "a=" << a << ", b=" << b << ", c=" << c << std::endl;
    }
};

class CorrectDemo {
public:
    int a;
    int b;
    int c;
    
    // 正确: 初始化列表顺序与声明顺序一致
    CorrectDemo(int x) : a(x), b(a + 1), c(b + 1) { }
    
    void print() {
        std::cout << "a=" << a << ", b=" << b << ", c=" << c << std::endl;
    }
};

int main() {
    Demo d(10);
    d.print();  // 结果可能不符合预期
    
    CorrectDemo cd(10);
    cd.print();  // a=10, b=11, c=12
    
    return 0;
}
```

### 3.3 必须使用初始化列表的情况

```cpp
#include <iostream>

class Base {
public:
    int value;
    Base(int v) : value(v) { }
};

class Derived : public Base {
public:
    const int constMember;
    int& refMember;
    
    // 以下情况必须使用初始化列表:
    // 1. 初始化基类
    // 2. 初始化 const 成员
    // 3. 初始化引用成员
    // 4. 初始化没有默认构造函数的成员
    
    Derived(int v, int c, int& r)
        : Base(v),           // 初始化基类
          constMember(c),    // 初始化 const 成员
          refMember(r)       // 初始化引用成员
    { }
};

class NoDefault {
public:
    int x;
    NoDefault(int v) : x(v) { }  // 没有默认构造函数
};

class Container {
public:
    NoDefault member;
    
    // 必须在初始化列表中初始化 member
    Container(int v) : member(v) { }
};
```

---

## 4. 析构函数

### 4.1 析构函数基础

```cpp
#include <iostream>
#include <string>

class Resource {
public:
    std::string name;
    
    Resource(const std::string& n) : name(n) {
        std::cout << "Resource " << name << " acquired" << std::endl;
    }
    
    // 析构函数: ~类名,无参数,无返回类型
    ~Resource() {
        std::cout << "Resource " << name << " released" << std::endl;
    }
};

int main() {
    std::cout << "=== Start ===" << std::endl;
    
    {
        Resource r1("A");
        Resource r2("B");
        std::cout << "=== In scope ===" << std::endl;
    }  // r2 先析构,然后 r1 (后进先出)
    
    std::cout << "=== End ===" << std::endl;
    
    return 0;
}
```

### 4.2 析构函数与资源管理

```cpp
#include <iostream>
#include <cstring>

class String {
public:
    char* data;
    size_t length;
    
    String(const char* str = "") {
        length = strlen(str);
        data = new char[length + 1];
        strcpy(data, str);
        std::cout << "String created: " << data << std::endl;
    }
    
    ~String() {
        std::cout << "String destroyed: " << data << std::endl;
        delete[] data;  // 释放动态分配的内存
    }
    
    void print() const {
        std::cout << data << std::endl;
    }
};

int main() {
    String s1("Hello");
    String s2("World");
    
    s1.print();
    s2.print();
    
    return 0;
}  // s2 和 s1 的析构函数被调用
```

### 4.3 虚析构函数

```cpp
#include <iostream>

class Base {
public:
    Base() { std::cout << "Base constructor" << std::endl; }
    
    // 虚析构函数: 确保通过基类指针删除派生类对象时正确析构
    virtual ~Base() { std::cout << "Base destructor" << std::endl; }
};

class Derived : public Base {
public:
    int* data;
    
    Derived() : data(new int[100]) {
        std::cout << "Derived constructor" << std::endl;
    }
    
    ~Derived() override {
        delete[] data;
        std::cout << "Derived destructor" << std::endl;
    }
};

int main() {
    // 通过基类指针删除派生类对象
    Base* ptr = new Derived();
    delete ptr;  // 如果 Base 析构函数不是虚的,Derived 析构函数不会被调用
    
    return 0;
}
```

---

## 5. 拷贝构造函数

### 5.1 拷贝构造函数基础

```cpp
#include <iostream>
#include <string>

class Person {
public:
    std::string name;
    int age;
    
    Person(const std::string& n, int a) : name(n), age(a) {
        std::cout << "Normal constructor" << std::endl;
    }
    
    // 拷贝构造函数
    Person(const Person& other) : name(other.name), age(other.age) {
        std::cout << "Copy constructor" << std::endl;
    }
};

void passByValue(Person p) {
    std::cout << "In function: " << p.name << std::endl;
}

Person createPerson() {
    return Person("Temp", 0);
}

int main() {
    Person p1("Alice", 25);
    
    Person p2 = p1;           // 拷贝构造
    Person p3(p1);            // 拷贝构造
    
    passByValue(p1);          // 拷贝构造 (传值)
    
    Person p4 = createPerson(); // 可能被优化 (RVO)
    
    return 0;
}
```

### 5.2 深拷贝与浅拷贝

```cpp
#include <iostream>
#include <cstring>

class ShallowCopy {
public:
    char* data;
    
    ShallowCopy(const char* str) {
        data = new char[strlen(str) + 1];
        strcpy(data, str);
    }
    
    // 默认拷贝构造函数: 浅拷贝
    // ShallowCopy(const ShallowCopy& other) : data(other.data) { }
    
    ~ShallowCopy() {
        delete[] data;  // 问题: 两个对象指向同一内存,会被释放两次
    }
};

class DeepCopy {
public:
    char* data;
    
    DeepCopy(const char* str) {
        data = new char[strlen(str) + 1];
        strcpy(data, str);
    }
    
    // 深拷贝构造函数
    DeepCopy(const DeepCopy& other) {
        data = new char[strlen(other.data) + 1];
        strcpy(data, other.data);
        std::cout << "Deep copy performed" << std::endl;
    }
    
    // 拷贝赋值运算符
    DeepCopy& operator=(const DeepCopy& other) {
        if (this != &other) {
            delete[] data;
            data = new char[strlen(other.data) + 1];
            strcpy(data, other.data);
        }
        return *this;
    }
    
    ~DeepCopy() {
        delete[] data;
    }
};

int main() {
    DeepCopy d1("Hello");
    DeepCopy d2 = d1;  // 深拷贝
    
    std::cout << "d1: " << d1.data << std::endl;
    std::cout << "d2: " << d2.data << std::endl;
    
    // 修改 d2 不影响 d1
    d2.data[0] = 'h';
    std::cout << "After modification:" << std::endl;
    std::cout << "d1: " << d1.data << std::endl;
    std::cout << "d2: " << d2.data << std::endl;
    
    return 0;
}
```

### 5.3 禁用拷贝

```cpp
#include <iostream>
#include <memory>

class NonCopyable {
public:
    NonCopyable() = default;
    
    // 禁用拷贝构造函数
    NonCopyable(const NonCopyable&) = delete;
    
    // 禁用拷贝赋值运算符
    NonCopyable& operator=(const NonCopyable&) = delete;
};

// 更好的方式: 继承自不可拷贝基类
class NoCopy {
protected:
    NoCopy() = default;
    ~NoCopy() = default;
    
    NoCopy(const NoCopy&) = delete;
    NoCopy& operator=(const NoCopy&) = delete;
};

class MyClass : private NoCopy {
public:
    int value;
    MyClass(int v) : value(v) { }
};

int main() {
    NonCopyable nc1;
    // NonCopyable nc2 = nc1;  // 错误: 拷贝被禁用
    
    MyClass m1(10);
    // MyClass m2 = m1;  // 错误: 拷贝被禁用
    
    return 0;
}
```

---

## 6. 移动构造函数

### 6.1 移动语义 (C++11)

```cpp
#include <iostream>
#include <cstring>
#include <utility>

class String {
public:
    char* data;
    size_t length;
    
    String(const char* str = "") {
        length = strlen(str);
        data = new char[length + 1];
        strcpy(data, str);
        std::cout << "Constructor: " << data << std::endl;
    }
    
    // 拷贝构造函数
    String(const String& other) {
        length = other.length;
        data = new char[length + 1];
        strcpy(data, other.data);
        std::cout << "Copy constructor: " << data << std::endl;
    }
    
    // 移动构造函数
    String(String&& other) noexcept {
        data = other.data;
        length = other.length;
        other.data = nullptr;
        other.length = 0;
        std::cout << "Move constructor: " << data << std::endl;
    }
    
    // 拷贝赋值运算符
    String& operator=(const String& other) {
        if (this != &other) {
            delete[] data;
            length = other.length;
            data = new char[length + 1];
            strcpy(data, other.data);
            std::cout << "Copy assignment: " << data << std::endl;
        }
        return *this;
    }
    
    // 移动赋值运算符
    String& operator=(String&& other) noexcept {
        if (this != &other) {
            delete[] data;
            data = other.data;
            length = other.length;
            other.data = nullptr;
            other.length = 0;
            std::cout << "Move assignment: " << data << std::endl;
        }
        return *this;
    }
    
    ~String() {
        if (data) {
            std::cout << "Destructor: " << data << std::endl;
        } else {
            std::cout << "Destructor: (moved)" << std::endl;
        }
        delete[] data;
    }
};

int main() {
    String s1("Hello");
    String s2 = s1;              // 拷贝构造
    String s3 = std::move(s1);   // 移动构造
    
    String s4("World");
    s4 = s2;                     // 拷贝赋值
    s4 = std::move(s3);          // 移动赋值
    
    return 0;
}
```

### 6.2 移动语义的好处

```cpp
#include <iostream>
#include <vector>
#include <string>

class HeavyObject {
public:
    std::vector<int> data;
    
    HeavyObject() : data(1000000) {
        std::cout << "Default constructor" << std::endl;
    }
    
    HeavyObject(const HeavyObject& other) : data(other.data) {
        std::cout << "Copy constructor (expensive)" << std::endl;
    }
    
    HeavyObject(HeavyObject&& other) noexcept : data(std::move(other.data)) {
        std::cout << "Move constructor (cheap)" << std::endl;
    }
};

HeavyObject createObject() {
    HeavyObject obj;
    return obj;  // 返回值优化 (RVO) 或移动
}

int main() {
    std::cout << "=== Creating ===" << std::endl;
    HeavyObject h1 = createObject();
    
    std::cout << "=== Copying ===" << std::endl;
    HeavyObject h2 = h1;  // 拷贝
    
    std::cout << "=== Moving ===" << std::endl;
    HeavyObject h3 = std::move(h1);  // 移动
    
    return 0;
}
```

---

## 7. 特殊成员函数

### 7.1 六个特殊成员函数

```cpp
class MyClass {
public:
    // 1. 默认构造函数
    MyClass();
    
    // 2. 析构函数
    ~MyClass();
    
    // 3. 拷贝构造函数
    MyClass(const MyClass& other);
    
    // 4. 拷贝赋值运算符
    MyClass& operator=(const MyClass& other);
    
    // 5. 移动构造函数 (C++11)
    MyClass(MyClass&& other) noexcept;
    
    // 6. 移动赋值运算符 (C++11)
    MyClass& operator=(MyClass&& other) noexcept;
};
```

### 7.2 Rule of Zero/Three/Five

```cpp
#include <iostream>
#include <string>
#include <memory>

// Rule of Zero: 如果不需要自定义,就不要定义
class RuleOfZero {
public:
    std::string name;
    std::vector<int> data;
    // 编译器生成的特殊成员函数就够用了
};

// Rule of Three: 如果定义了其中一个,就应该定义全部三个
// (析构函数、拷贝构造函数、拷贝赋值运算符)
class RuleOfThree {
public:
    int* data;
    
    RuleOfThree() : data(new int(0)) { }
    
    ~RuleOfThree() { delete data; }
    
    RuleOfThree(const RuleOfThree& other) : data(new int(*other.data)) { }
    
    RuleOfThree& operator=(const RuleOfThree& other) {
        if (this != &other) {
            delete data;
            data = new int(*other.data);
        }
        return *this;
    }
};

// Rule of Five: C++11 后,如果定义了其中一个,就应该定义全部五个
// (加上移动构造函数和移动赋值运算符)
class RuleOfFive {
public:
    int* data;
    
    RuleOfFive() : data(new int(0)) { }
    
    ~RuleOfFive() { delete data; }
    
    RuleOfFive(const RuleOfFive& other) : data(new int(*other.data)) { }
    
    RuleOfFive& operator=(const RuleOfFive& other) {
        if (this != &other) {
            delete data;
            data = new int(*other.data);
        }
        return *this;
    }
    
    RuleOfFive(RuleOfFive&& other) noexcept : data(other.data) {
        other.data = nullptr;
    }
    
    RuleOfFive& operator=(RuleOfFive&& other) noexcept {
        if (this != &other) {
            delete data;
            data = other.data;
            other.data = nullptr;
        }
        return *this;
    }
};
```

### 7.3 default 和 delete

```cpp
#include <iostream>

class MyClass {
public:
    int value;
    
    // 显式默认
    MyClass() = default;
    ~MyClass() = default;
    MyClass(const MyClass&) = default;
    MyClass& operator=(const MyClass&) = default;
    MyClass(MyClass&&) = default;
    MyClass& operator=(MyClass&&) = default;
    
    // 自定义构造函数
    MyClass(int v) : value(v) { }
};

class NonCopyable {
public:
    NonCopyable() = default;
    ~NonCopyable() = default;
    
    // 禁用拷贝
    NonCopyable(const NonCopyable&) = delete;
    NonCopyable& operator=(const NonCopyable&) = delete;
    
    // 允许移动
    NonCopyable(NonCopyable&&) = default;
    NonCopyable& operator=(NonCopyable&&) = default;
};

class NonMovable {
public:
    NonMovable() = default;
    ~NonMovable() = default;
    
    // 允许拷贝
    NonMovable(const NonMovable&) = default;
    NonMovable& operator=(const NonMovable&) = default;
    
    // 禁用移动
    NonMovable(NonMovable&&) = delete;
    NonMovable& operator=(NonMovable&&) = delete;
};
```

---

## 8. 总结

### 8.1 构造函数类型

| 类型 | 说明 |
|------|------|
| 默认构造函数 | 无参数 |
| 参数化构造函数 | 带参数 |
| 拷贝构造函数 | 从同类对象拷贝 |
| 移动构造函数 | 从临时对象移动 |
| 委托构造函数 | 调用其他构造函数 |

### 8.2 最佳实践

```
1. 使用初始化列表初始化成员
2. 遵循 Rule of Zero/Three/Five
3. 基类析构函数声明为 virtual
4. 移动构造函数标记为 noexcept
5. 使用 explicit 防止隐式转换
6. 优先使用智能指针管理资源
```

### 8.3 下一篇预告

在下一篇文章中,我们将学习访问控制与封装。

---

## 参考资料

1. [C++ Constructors](https://en.cppreference.com/w/cpp/language/constructor)
2. [C++ Destructors](https://en.cppreference.com/w/cpp/language/destructor)

---

> 作者: C++ 技术专栏  
> 系列: 面向对象编程 (2/8)  
> 上一篇: [类与对象](./09-class-object.md)  
> 下一篇: [访问控制与封装](./11-access-control.md)
