---
title: "类与对象"
description: "1. [面向对象概述](#1-面向对象概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 9
---

> 本文是 C++ 从入门到精通系列的第九篇,将深入讲解 C++ 面向对象编程的核心概念:类与对象。

---

## 目录

1. [面向对象概述](#1-面向对象概述)
2. [类的定义](#2-类的定义)
3. [对象的创建](#3-对象的创建)
4. [成员变量](#4-成员变量)
5. [成员函数](#5-成员函数)
6. [this 指针](#6-this-指针)
7. [类的作用域](#7-类的作用域)
8. [总结](#8-总结)

---

## 1. 面向对象概述

### 1.1 面向对象三大特性

```
面向对象编程 (OOP) 三大特性:

1. 封装 (Encapsulation)
   - 将数据和操作数据的方法绑定在一起
   - 隐藏内部实现细节
   - 通过接口与外界交互

2. 继承 (Inheritance)
   - 从已有类派生新类
   - 代码复用
   - 建立类的层次结构

3. 多态 (Polymorphism)
   - 同一接口,不同实现
   - 运行时动态绑定
   - 提高代码灵活性
```

### 1.2 类与对象的关系

```
类 (Class):
- 抽象的概念
- 定义数据和行为的模板
- 类似于"蓝图"

对象 (Object):
- 类的具体实例
- 占用实际内存
- 类似于"根据蓝图建造的房子"

示例:
类: 汽车
对象: 我的红色特斯拉, 你的蓝色宝马
```

---

## 2. 类的定义

### 2.1 基本语法

```cpp
#include <iostream>
#include <string>

// 类定义
class Person {
public:
    // 成员变量 (属性)
    std::string name;
    int age;
    
    // 成员函数 (方法)
    void introduce() {
        std::cout << "Hi, I'm " << name << ", " << age << " years old." << std::endl;
    }
    
    void setAge(int newAge) {
        if (newAge >= 0 && newAge <= 150) {
            age = newAge;
        }
    }
};

int main() {
    // 创建对象
    Person person;
    person.name = "Alice";
    person.age = 25;
    person.introduce();
    
    return 0;
}
```

### 2.2 访问修饰符

```cpp
class MyClass {
public:
    // 公有成员: 任何地方都可以访问
    int publicVar;
    void publicMethod() { }

protected:
    // 保护成员: 类内部和派生类可以访问
    int protectedVar;
    void protectedMethod() { }

private:
    // 私有成员: 只有类内部可以访问
    int privateVar;
    void privateMethod() { }
};

// 默认访问级别
class DefaultClass {
    int x;  // 默认 private
};

struct DefaultStruct {
    int x;  // 默认 public
};
```

### 2.3 class vs struct

```cpp
// class: 默认 private
class MyClass {
    int x;  // private
public:
    int y;  // public
};

// struct: 默认 public
struct MyStruct {
    int x;  // public
private:
    int y;  // private
};

// 使用建议:
// - struct: 简单数据聚合,POD 类型
// - class: 有行为的复杂类型
```

### 2.4 类的声明与定义分离

```cpp
// Person.h
#ifndef PERSON_H
#define PERSON_H

#include <string>

class Person {
public:
    std::string name;
    int age;
    
    void introduce();
    void setAge(int newAge);
    int getAge() const;

private:
    void validateAge(int age);
};

#endif
```

```cpp
// Person.cpp
#include "Person.h"
#include <iostream>

void Person::introduce() {
    std::cout << "Hi, I'm " << name << ", " << age << " years old." << std::endl;
}

void Person::setAge(int newAge) {
    validateAge(newAge);
    age = newAge;
}

int Person::getAge() const {
    return age;
}

void Person::validateAge(int age) {
    if (age < 0 || age > 150) {
        throw std::invalid_argument("Invalid age");
    }
}
```

---

## 3. 对象的创建

### 3.1 栈上创建

```cpp
#include <iostream>

class Point {
public:
    int x, y;
    
    void print() {
        std::cout << "(" << x << ", " << y << ")" << std::endl;
    }
};

int main() {
    // 默认初始化 (成员未初始化)
    Point p1;
    
    // 值初始化 (成员初始化为 0)
    Point p2{};
    
    // 聚合初始化
    Point p3{10, 20};
    
    // 拷贝初始化
    Point p4 = p3;
    
    p1.x = 1;
    p1.y = 2;
    p1.print();
    
    p3.print();
    
    return 0;
}  // 对象自动销毁
```

### 3.2 堆上创建

```cpp
#include <iostream>
#include <memory>

class Point {
public:
    int x, y;
    
    void print() {
        std::cout << "(" << x << ", " << y << ")" << std::endl;
    }
};

int main() {
    // new 创建 (需要手动 delete)
    Point* p1 = new Point;
    p1->x = 10;
    p1->y = 20;
    p1->print();
    delete p1;
    
    // new 带初始化
    Point* p2 = new Point{30, 40};
    p2->print();
    delete p2;
    
    // 智能指针 (推荐)
    auto p3 = std::make_unique<Point>();
    p3->x = 50;
    p3->y = 60;
    p3->print();
    // 自动释放
    
    auto p4 = std::make_shared<Point>();
    p4->x = 70;
    p4->y = 80;
    p4->print();
    // 自动释放
    
    return 0;
}
```

### 3.3 对象数组

```cpp
#include <iostream>
#include <vector>
#include <array>

class Point {
public:
    int x = 0, y = 0;
    
    void print() const {
        std::cout << "(" << x << ", " << y << ") ";
    }
};

int main() {
    // C 风格数组
    Point arr1[3];
    arr1[0].x = 1;
    arr1[0].y = 2;
    
    // 初始化列表
    Point arr2[3] = {{1, 2}, {3, 4}, {5, 6}};
    
    // std::array
    std::array<Point, 3> arr3 = {{{1, 2}, {3, 4}, {5, 6}}};
    
    // std::vector (推荐)
    std::vector<Point> vec = {{1, 2}, {3, 4}, {5, 6}};
    vec.push_back({7, 8});
    
    for (const auto& p : vec) {
        p.print();
    }
    std::cout << std::endl;
    
    return 0;
}
```

---

## 4. 成员变量

### 4.1 成员变量初始化

```cpp
#include <iostream>
#include <string>

class Person {
public:
    // C++11 类内初始化
    std::string name = "Unknown";
    int age = 0;
    double height = 0.0;
    bool isStudent = false;
    
    // const 成员必须初始化
    const int id = 0;
    
    // static 成员
    static int count;
    
    void print() const {
        std::cout << "Name: " << name << ", Age: " << age << std::endl;
    }
};

// static 成员类外定义
int Person::count = 0;

int main() {
    Person p1;
    p1.print();  // 使用默认值
    
    Person p2;
    p2.name = "Alice";
    p2.age = 25;
    p2.print();
    
    return 0;
}
```

### 4.2 成员变量类型

```cpp
#include <iostream>
#include <string>
#include <vector>
#include <memory>

class Container {
public:
    // 基本类型
    int intValue = 0;
    double doubleValue = 0.0;
    
    // 对象成员
    std::string strValue;
    std::vector<int> vecValue;
    
    // 指针成员
    int* rawPtr = nullptr;
    std::unique_ptr<int> smartPtr;
    
    // 引用成员 (必须在构造函数中初始化)
    // int& refValue;  // 需要构造函数初始化
    
    // 数组成员
    int arrValue[10] = {};
    
    // 嵌套类对象
    struct Inner {
        int x, y;
    };
    Inner innerValue;
};
```

### 4.3 mutable 成员

```cpp
#include <iostream>

class Counter {
public:
    int getValue() const {
        ++accessCount;  // 可以修改 mutable 成员
        return value;
    }
    
    void setValue(int v) {
        value = v;
    }
    
    int getAccessCount() const {
        return accessCount;
    }

private:
    int value = 0;
    mutable int accessCount = 0;  // 即使在 const 方法中也可修改
};

int main() {
    const Counter c;
    c.getValue();
    c.getValue();
    c.getValue();
    
    std::cout << "Access count: " << c.getAccessCount() << std::endl;  // 3
    
    return 0;
}
```

---

## 5. 成员函数

### 5.1 成员函数定义

```cpp
#include <iostream>

class Rectangle {
public:
    double width, height;
    
    // 类内定义 (隐式内联)
    double area() const {
        return width * height;
    }
    
    // 类内声明
    double perimeter() const;
    void scale(double factor);
};

// 类外定义
double Rectangle::perimeter() const {
    return 2 * (width + height);
}

void Rectangle::scale(double factor) {
    width *= factor;
    height *= factor;
}

int main() {
    Rectangle rect{10, 5};
    
    std::cout << "Area: " << rect.area() << std::endl;
    std::cout << "Perimeter: " << rect.perimeter() << std::endl;
    
    rect.scale(2);
    std::cout << "After scale - Area: " << rect.area() << std::endl;
    
    return 0;
}
```

### 5.2 const 成员函数

```cpp
#include <iostream>

class Point {
public:
    int x, y;
    
    // const 成员函数: 不修改对象状态
    int getX() const { return x; }
    int getY() const { return y; }
    
    void print() const {
        std::cout << "(" << x << ", " << y << ")" << std::endl;
        // x = 10;  // 错误: 不能在 const 函数中修改成员
    }
    
    // 非 const 成员函数: 可以修改对象状态
    void setX(int newX) { x = newX; }
    void setY(int newY) { y = newY; }
    
    // const 重载
    int& at(int index) {
        return (index == 0) ? x : y;
    }
    
    const int& at(int index) const {
        return (index == 0) ? x : y;
    }
};

int main() {
    Point p{10, 20};
    p.print();
    p.setX(30);
    p.print();
    
    const Point cp{100, 200};
    cp.print();
    // cp.setX(300);  // 错误: const 对象不能调用非 const 方法
    
    // const 重载
    p.at(0) = 50;  // 调用非 const 版本
    int val = cp.at(0);  // 调用 const 版本
    
    return 0;
}
```

### 5.3 静态成员函数

```cpp
#include <iostream>

class Counter {
public:
    Counter() {
        ++count;
        id = count;
    }
    
    ~Counter() {
        --count;
    }
    
    int getId() const { return id; }
    
    // 静态成员函数
    static int getCount() {
        return count;
        // return id;  // 错误: 不能访问非静态成员
    }
    
    static void resetCount() {
        count = 0;
    }

private:
    int id;
    static int count;  // 静态成员变量
};

int Counter::count = 0;

int main() {
    std::cout << "Count: " << Counter::getCount() << std::endl;  // 0
    
    Counter c1;
    Counter c2;
    Counter c3;
    
    std::cout << "Count: " << Counter::getCount() << std::endl;  // 3
    std::cout << "c1 id: " << c1.getId() << std::endl;  // 1
    std::cout << "c2 id: " << c2.getId() << std::endl;  // 2
    
    {
        Counter c4;
        std::cout << "Count: " << Counter::getCount() << std::endl;  // 4
    }
    
    std::cout << "Count: " << Counter::getCount() << std::endl;  // 3
    
    return 0;
}
```

---

## 6. this 指针

### 6.1 this 指针基础

```cpp
#include <iostream>

class Point {
public:
    int x, y;
    
    // this 是指向当前对象的指针
    void setX(int x) {
        this->x = x;  // 区分成员变量和参数
    }
    
    void setY(int y) {
        this->y = y;
    }
    
    // 返回 *this 实现链式调用
    Point& setXY(int x, int y) {
        this->x = x;
        this->y = y;
        return *this;
    }
    
    Point& moveX(int dx) {
        x += dx;
        return *this;
    }
    
    Point& moveY(int dy) {
        y += dy;
        return *this;
    }
    
    void print() const {
        std::cout << "(" << x << ", " << y << ")" << std::endl;
    }
};

int main() {
    Point p;
    
    // 链式调用
    p.setXY(10, 20).moveX(5).moveY(10).print();  // (15, 30)
    
    return 0;
}
```

### 6.2 this 指针的类型

```cpp
#include <iostream>

class MyClass {
public:
    void normalMethod() {
        // this 的类型是 MyClass*
        std::cout << "this type: MyClass*" << std::endl;
    }
    
    void constMethod() const {
        // this 的类型是 const MyClass*
        std::cout << "this type: const MyClass*" << std::endl;
    }
    
    // C++23: 显式 this 参数
    // void explicitThis(this MyClass& self) { }
};
```

### 6.3 this 指针的使用场景

```cpp
#include <iostream>

class Node {
public:
    int value;
    Node* next;
    
    Node(int v) : value(v), next(nullptr) { }
    
    // 返回自身引用
    Node& setValue(int v) {
        value = v;
        return *this;
    }
    
    // 比较两个对象
    bool equals(const Node& other) const {
        return this == &other;  // 比较地址
    }
    
    // 防止自赋值
    Node& operator=(const Node& other) {
        if (this != &other) {  // 检查自赋值
            value = other.value;
            // 处理 next...
        }
        return *this;
    }
};
```

---

## 7. 类的作用域

### 7.1 类作用域

```cpp
#include <iostream>

class Outer {
public:
    int value = 10;
    
    // 嵌套类
    class Inner {
    public:
        int innerValue = 20;
        
        void print() {
            std::cout << "Inner value: " << innerValue << std::endl;
        }
    };
    
    // 嵌套枚举
    enum class Color { Red, Green, Blue };
    
    // 类型别名
    using IntPtr = int*;
    
    void useInner() {
        Inner inner;
        inner.print();
    }
};

int main() {
    Outer outer;
    outer.useInner();
    
    // 访问嵌套类
    Outer::Inner inner;
    inner.print();
    
    // 访问嵌套枚举
    Outer::Color color = Outer::Color::Red;
    
    // 使用类型别名
    Outer::IntPtr ptr = nullptr;
    
    return 0;
}
```

### 7.2 前向声明

```cpp
// 前向声明
class B;

class A {
public:
    void setB(B* b);  // 可以使用 B 的指针或引用
    // B member;  // 错误: 不能使用不完整类型
    B* bPtr;
};

class B {
public:
    int value = 42;
};

void A::setB(B* b) {
    bPtr = b;
}
```

### 7.3 友元

```cpp
#include <iostream>

class MyClass {
public:
    MyClass(int v) : value(v) { }

private:
    int value;
    
    // 友元函数
    friend void printValue(const MyClass& obj);
    
    // 友元类
    friend class FriendClass;
};

// 友元函数可以访问私有成员
void printValue(const MyClass& obj) {
    std::cout << "Value: " << obj.value << std::endl;
}

// 友元类可以访问私有成员
class FriendClass {
public:
    void accessPrivate(const MyClass& obj) {
        std::cout << "Accessed: " << obj.value << std::endl;
    }
};

int main() {
    MyClass obj(42);
    printValue(obj);
    
    FriendClass fc;
    fc.accessPrivate(obj);
    
    return 0;
}
```

---

## 8. 总结

### 8.1 类的组成

| 组成部分 | 说明 |
|---------|------|
| 成员变量 | 对象的数据/属性 |
| 成员函数 | 对象的行为/方法 |
| 构造函数 | 初始化对象 |
| 析构函数 | 清理资源 |
| 静态成员 | 类级别的数据和方法 |

### 8.2 访问控制

| 修饰符 | 类内 | 派生类 | 类外 |
|--------|------|--------|------|
| public | Yes | Yes | Yes |
| protected | Yes | Yes | No |
| private | Yes | No | No |

### 8.3 最佳实践

```
1. 成员变量设为 private
2. 通过公有方法访问成员
3. const 成员函数标记为 const
4. 使用类内初始化
5. 优先使用智能指针
6. 声明与定义分离
```

### 8.4 下一篇预告

在下一篇文章中,我们将学习构造函数与析构函数。

---

## 参考资料

1. [C++ Classes](https://en.cppreference.com/w/cpp/language/classes)
2. [Access Specifiers](https://en.cppreference.com/w/cpp/language/access)

---

> 作者: C++ 技术专栏  
> 系列: 面向对象编程 (1/8)  
> 上一篇: [字符串处理](../part1-basics/08-strings.md)  
> 下一篇: [构造函数与析构函数](./10-constructor-destructor.md)
