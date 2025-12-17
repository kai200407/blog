---
title: "访问控制与封装"
description: "1. [访问修饰符](#1-访问修饰符)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 11
---

> 本文是 C++ 从入门到精通系列的第十一篇,将深入讲解 C++ 的访问控制机制和封装原则。

---

## 目录

1. [访问修饰符](#1-访问修饰符)
2. [封装原则](#2-封装原则)
3. [getter 和 setter](#3-getter-和-setter)
4. [友元](#4-友元)
5. [封装最佳实践](#5-封装最佳实践)
6. [总结](#6-总结)

---

## 1. 访问修饰符

### 1.1 三种访问级别

```cpp
#include <iostream>
#include <string>

class Person {
public:
    // 公有成员: 任何地方都可以访问
    std::string name;
    
    void introduce() {
        std::cout << "Hi, I'm " << name << std::endl;
    }

protected:
    // 保护成员: 类内部和派生类可以访问
    int age = 0;
    
    void setAge(int a) {
        if (a >= 0) age = a;
    }

private:
    // 私有成员: 只有类内部可以访问
    std::string ssn;  // 社会安全号
    
    void validateSSN() {
        // 内部验证逻辑
    }
};

class Employee : public Person {
public:
    void setEmployeeAge(int a) {
        setAge(a);  // OK: 可以访问 protected 成员
        // ssn = "xxx";  // 错误: 不能访问 private 成员
    }
};

int main() {
    Person p;
    p.name = "Alice";  // OK: public
    p.introduce();     // OK: public
    
    // p.age = 25;     // 错误: protected
    // p.ssn = "xxx";  // 错误: private
    
    return 0;
}
```

### 1.2 class vs struct 默认访问级别

```cpp
// class 默认 private
class MyClass {
    int x;  // private
public:
    int y;  // public
};

// struct 默认 public
struct MyStruct {
    int x;  // public
private:
    int y;  // private
};

// 继承时的默认访问级别
class DerivedFromClass : MyClass { };      // 默认 private 继承
class DerivedFromStruct : MyStruct { };    // 默认 public 继承

struct StructFromClass : MyClass { };      // 默认 public 继承
struct StructFromStruct : MyStruct { };    // 默认 public 继承
```

### 1.3 继承中的访问控制

```cpp
#include <iostream>

class Base {
public:
    int publicMember = 1;
protected:
    int protectedMember = 2;
private:
    int privateMember = 3;
};

// public 继承: 保持原有访问级别
class PublicDerived : public Base {
public:
    void access() {
        publicMember = 10;     // OK: 仍然是 public
        protectedMember = 20;  // OK: 仍然是 protected
        // privateMember = 30; // 错误: 不可访问
    }
};

// protected 继承: public 变成 protected
class ProtectedDerived : protected Base {
public:
    void access() {
        publicMember = 10;     // OK: 变成 protected
        protectedMember = 20;  // OK: 仍然是 protected
    }
};

// private 继承: 全部变成 private
class PrivateDerived : private Base {
public:
    void access() {
        publicMember = 10;     // OK: 变成 private
        protectedMember = 20;  // OK: 变成 private
    }
};

int main() {
    PublicDerived pd;
    pd.publicMember = 100;  // OK
    
    ProtectedDerived ptd;
    // ptd.publicMember = 100;  // 错误: 变成 protected
    
    PrivateDerived pvd;
    // pvd.publicMember = 100;  // 错误: 变成 private
    
    return 0;
}
```

---

## 2. 封装原则

### 2.1 什么是封装

```
封装 (Encapsulation):

1. 数据隐藏
   - 将内部实现细节隐藏起来
   - 只暴露必要的接口

2. 接口与实现分离
   - 用户只需要知道如何使用
   - 不需要了解内部工作原理

3. 好处
   - 保护数据完整性
   - 降低耦合度
   - 便于维护和修改
   - 提高代码复用性
```

### 2.2 封装示例

```cpp
#include <iostream>
#include <string>
#include <stdexcept>

// 不好的设计: 没有封装
class BadBankAccount {
public:
    double balance;  // 直接暴露,可以被任意修改
};

// 好的设计: 封装
class BankAccount {
public:
    BankAccount(const std::string& owner, double initial = 0)
        : ownerName(owner), balance(initial >= 0 ? initial : 0) { }
    
    // 只读访问
    std::string getOwner() const { return ownerName; }
    double getBalance() const { return balance; }
    
    // 受控的修改操作
    void deposit(double amount) {
        if (amount <= 0) {
            throw std::invalid_argument("Deposit amount must be positive");
        }
        balance += amount;
        logTransaction("Deposit", amount);
    }
    
    bool withdraw(double amount) {
        if (amount <= 0) {
            throw std::invalid_argument("Withdrawal amount must be positive");
        }
        if (amount > balance) {
            return false;  // 余额不足
        }
        balance -= amount;
        logTransaction("Withdrawal", amount);
        return true;
    }

private:
    std::string ownerName;
    double balance;
    
    void logTransaction(const std::string& type, double amount) {
        std::cout << type << ": $" << amount 
                  << ", New balance: $" << balance << std::endl;
    }
};

int main() {
    BankAccount account("Alice", 1000);
    
    std::cout << "Owner: " << account.getOwner() << std::endl;
    std::cout << "Balance: $" << account.getBalance() << std::endl;
    
    account.deposit(500);
    account.withdraw(200);
    
    // account.balance = 1000000;  // 错误: 不能直接访问
    
    return 0;
}
```

---

## 3. getter 和 setter

### 3.1 基本实现

```cpp
#include <iostream>
#include <string>

class Person {
public:
    // Getter
    std::string getName() const { return name; }
    int getAge() const { return age; }
    
    // Setter
    void setName(const std::string& n) { name = n; }
    void setAge(int a) {
        if (a >= 0 && a <= 150) {
            age = a;
        }
    }

private:
    std::string name;
    int age = 0;
};

int main() {
    Person p;
    p.setName("Alice");
    p.setAge(25);
    
    std::cout << "Name: " << p.getName() << std::endl;
    std::cout << "Age: " << p.getAge() << std::endl;
    
    return 0;
}
```

### 3.2 返回引用

```cpp
#include <iostream>
#include <string>
#include <vector>

class Container {
public:
    // 返回 const 引用: 避免拷贝,只读访问
    const std::vector<int>& getData() const { return data; }
    
    // 返回非 const 引用: 允许修改
    std::vector<int>& getData() { return data; }
    
    // 返回 const 引用的字符串
    const std::string& getName() const { return name; }
    
    // 设置器
    void setName(const std::string& n) { name = n; }
    void addData(int value) { data.push_back(value); }

private:
    std::string name;
    std::vector<int> data;
};

int main() {
    Container c;
    c.setName("MyContainer");
    c.addData(1);
    c.addData(2);
    c.addData(3);
    
    // 通过引用访问
    const auto& data = c.getData();
    for (int x : data) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    // 通过非 const 引用修改
    c.getData().push_back(4);
    
    return 0;
}
```

### 3.3 计算属性

```cpp
#include <iostream>
#include <cmath>

class Circle {
public:
    Circle(double r) : radius(r > 0 ? r : 0) { }
    
    // 基本属性
    double getRadius() const { return radius; }
    void setRadius(double r) {
        if (r > 0) radius = r;
    }
    
    // 计算属性 (派生属性)
    double getDiameter() const { return 2 * radius; }
    double getCircumference() const { return 2 * M_PI * radius; }
    double getArea() const { return M_PI * radius * radius; }

private:
    double radius;
};

class Rectangle {
public:
    Rectangle(double w, double h) : width(w), height(h) { }
    
    double getWidth() const { return width; }
    double getHeight() const { return height; }
    
    void setWidth(double w) { if (w > 0) width = w; }
    void setHeight(double h) { if (h > 0) height = h; }
    
    // 计算属性
    double getArea() const { return width * height; }
    double getPerimeter() const { return 2 * (width + height); }
    double getDiagonal() const { return std::sqrt(width*width + height*height); }
    bool isSquare() const { return width == height; }

private:
    double width, height;
};

int main() {
    Circle c(5);
    std::cout << "Circle:" << std::endl;
    std::cout << "  Radius: " << c.getRadius() << std::endl;
    std::cout << "  Diameter: " << c.getDiameter() << std::endl;
    std::cout << "  Area: " << c.getArea() << std::endl;
    
    Rectangle r(4, 3);
    std::cout << "Rectangle:" << std::endl;
    std::cout << "  Area: " << r.getArea() << std::endl;
    std::cout << "  Diagonal: " << r.getDiagonal() << std::endl;
    
    return 0;
}
```

---

## 4. 友元

### 4.1 友元函数

```cpp
#include <iostream>

class Box {
public:
    Box(double l, double w, double h) : length(l), width(w), height(h) { }
    
    // 声明友元函数
    friend double calculateVolume(const Box& box);
    friend void printBox(const Box& box);

private:
    double length, width, height;
};

// 友元函数可以访问私有成员
double calculateVolume(const Box& box) {
    return box.length * box.width * box.height;
}

void printBox(const Box& box) {
    std::cout << "Box(" << box.length << " x " 
              << box.width << " x " << box.height << ")" << std::endl;
}

int main() {
    Box box(3, 4, 5);
    printBox(box);
    std::cout << "Volume: " << calculateVolume(box) << std::endl;
    
    return 0;
}
```

### 4.2 友元类

```cpp
#include <iostream>
#include <string>

class Engine {
public:
    void start() { running = true; }
    void stop() { running = false; }
    bool isRunning() const { return running; }

private:
    bool running = false;
    int rpm = 0;
    double temperature = 20.0;
    
    // Car 类可以访问 Engine 的私有成员
    friend class Car;
};

class Car {
public:
    Car(const std::string& model) : modelName(model) { }
    
    void startEngine() {
        engine.start();
        engine.rpm = 800;  // 可以访问私有成员
        std::cout << modelName << " engine started" << std::endl;
    }
    
    void accelerate() {
        if (engine.running) {
            engine.rpm += 1000;
            engine.temperature += 5;
            std::cout << "RPM: " << engine.rpm 
                      << ", Temp: " << engine.temperature << std::endl;
        }
    }
    
    void stopEngine() {
        engine.stop();
        engine.rpm = 0;
        std::cout << modelName << " engine stopped" << std::endl;
    }

private:
    std::string modelName;
    Engine engine;
};

int main() {
    Car car("Tesla");
    car.startEngine();
    car.accelerate();
    car.accelerate();
    car.stopEngine();
    
    return 0;
}
```

### 4.3 友元成员函数

```cpp
#include <iostream>

class B;  // 前向声明

class A {
public:
    void accessB(B& b);  // 将在 B 定义后实现
};

class B {
public:
    B(int v) : value(v) { }

private:
    int value;
    
    // 只有 A::accessB 是友元,而不是整个 A 类
    friend void A::accessB(B& b);
};

void A::accessB(B& b) {
    std::cout << "B's value: " << b.value << std::endl;
    b.value = 100;
    std::cout << "B's new value: " << b.value << std::endl;
}

int main() {
    A a;
    B b(42);
    a.accessB(b);
    
    return 0;
}
```

### 4.4 友元的注意事项

```cpp
/*
友元的特点:

1. 友元关系不是相互的
   - A 是 B 的友元,不意味着 B 是 A 的友元

2. 友元关系不能传递
   - A 是 B 的友元,B 是 C 的友元,不意味着 A 是 C 的友元

3. 友元关系不能继承
   - A 是 B 的友元,C 继承自 B,A 不是 C 的友元

4. 友元破坏封装
   - 应该谨慎使用
   - 只在必要时使用 (如运算符重载)
*/
```

---

## 5. 封装最佳实践

### 5.1 设计原则

```cpp
#include <iostream>
#include <string>
#include <vector>

// 好的封装设计示例
class Student {
public:
    // 构造函数
    Student(const std::string& name, int id)
        : name_(name), studentId_(id) {
        validateId(id);
    }
    
    // 只读访问器
    const std::string& name() const { return name_; }
    int studentId() const { return studentId_; }
    double gpa() const { return calculateGPA(); }
    
    // 业务方法
    void addGrade(const std::string& course, double grade) {
        if (grade >= 0 && grade <= 100) {
            grades_.push_back({course, grade});
        }
    }
    
    void printTranscript() const {
        std::cout << "Student: " << name_ << " (ID: " << studentId_ << ")" << std::endl;
        std::cout << "GPA: " << gpa() << std::endl;
        for (const auto& [course, grade] : grades_) {
            std::cout << "  " << course << ": " << grade << std::endl;
        }
    }

private:
    std::string name_;
    int studentId_;
    std::vector<std::pair<std::string, double>> grades_;
    
    void validateId(int id) {
        if (id <= 0) {
            throw std::invalid_argument("Invalid student ID");
        }
    }
    
    double calculateGPA() const {
        if (grades_.empty()) return 0.0;
        double sum = 0;
        for (const auto& [_, grade] : grades_) {
            sum += grade;
        }
        return sum / grades_.size() / 25.0;  // 转换为 4.0 制
    }
};

int main() {
    Student s("Alice", 12345);
    s.addGrade("Math", 95);
    s.addGrade("Physics", 88);
    s.addGrade("Chemistry", 92);
    
    s.printTranscript();
    
    return 0;
}
```

### 5.2 Pimpl 惯用法

```cpp
// widget.h
#ifndef WIDGET_H
#define WIDGET_H

#include <memory>
#include <string>

class Widget {
public:
    Widget();
    ~Widget();
    
    // 移动操作
    Widget(Widget&&) noexcept;
    Widget& operator=(Widget&&) noexcept;
    
    // 禁用拷贝
    Widget(const Widget&) = delete;
    Widget& operator=(const Widget&) = delete;
    
    void doSomething();
    std::string getName() const;

private:
    // 前向声明实现类
    class Impl;
    std::unique_ptr<Impl> pImpl;
};

#endif
```

```cpp
// widget.cpp
#include "widget.h"
#include <iostream>

// 实现类定义
class Widget::Impl {
public:
    std::string name = "Widget";
    int value = 42;
    
    void internalOperation() {
        std::cout << "Internal operation" << std::endl;
    }
};

Widget::Widget() : pImpl(std::make_unique<Impl>()) { }

Widget::~Widget() = default;

Widget::Widget(Widget&&) noexcept = default;
Widget& Widget::operator=(Widget&&) noexcept = default;

void Widget::doSomething() {
    pImpl->internalOperation();
    std::cout << "Value: " << pImpl->value << std::endl;
}

std::string Widget::getName() const {
    return pImpl->name;
}
```

---

## 6. 总结

### 6.1 访问级别对比

| 访问级别 | 类内 | 派生类 | 类外 |
|---------|------|--------|------|
| public | Yes | Yes | Yes |
| protected | Yes | Yes | No |
| private | Yes | No | No |

### 6.2 封装检查清单

```
[ ] 成员变量设为 private
[ ] 通过公有方法访问数据
[ ] getter 方法标记为 const
[ ] setter 方法进行数据验证
[ ] 只暴露必要的接口
[ ] 隐藏实现细节
[ ] 谨慎使用友元
```

### 6.3 下一篇预告

在下一篇文章中,我们将学习继承。

---

> 作者: C++ 技术专栏  
> 系列: 面向对象编程 (3/8)  
> 上一篇: [构造函数与析构函数](./10-constructor-destructor.md)  
> 下一篇: [继承](./12-inheritance.md)
