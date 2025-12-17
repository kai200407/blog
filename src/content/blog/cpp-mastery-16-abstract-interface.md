---
title: "抽象类与接口"
description: "1. [抽象类基础](#1-抽象类基础)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 16
---

> 本文是 C++ 从入门到精通系列的第十六篇,也是面向对象编程部分的收官之作。我们将深入讲解 C++ 的抽象类和接口设计。

---

## 目录

1. [抽象类基础](#1-抽象类基础)
2. [纯虚函数](#2-纯虚函数)
3. [接口设计](#3-接口设计)
4. [多接口继承](#4-多接口继承)
5. [接口与实现分离](#5-接口与实现分离)
6. [设计模式应用](#6-设计模式应用)
7. [总结](#7-总结)

---

## 1. 抽象类基础

### 1.1 什么是抽象类

```cpp
#include <iostream>
#include <string>

// 抽象类: 包含至少一个纯虚函数的类
class Shape {
public:
    // 纯虚函数
    virtual double area() const = 0;
    virtual double perimeter() const = 0;
    virtual void draw() const = 0;
    
    // 普通虚函数
    virtual std::string getName() const {
        return "Shape";
    }
    
    // 非虚函数
    void printInfo() const {
        std::cout << getName() << ": Area = " << area() 
                  << ", Perimeter = " << perimeter() << std::endl;
    }
    
    // 虚析构函数
    virtual ~Shape() = default;
};

// 具体类: 实现所有纯虚函数
class Circle : public Shape {
public:
    double radius;
    
    Circle(double r) : radius(r) { }
    
    double area() const override {
        return 3.14159 * radius * radius;
    }
    
    double perimeter() const override {
        return 2 * 3.14159 * radius;
    }
    
    void draw() const override {
        std::cout << "Drawing circle with radius " << radius << std::endl;
    }
    
    std::string getName() const override {
        return "Circle";
    }
};

class Rectangle : public Shape {
public:
    double width, height;
    
    Rectangle(double w, double h) : width(w), height(h) { }
    
    double area() const override {
        return width * height;
    }
    
    double perimeter() const override {
        return 2 * (width + height);
    }
    
    void draw() const override {
        std::cout << "Drawing rectangle " << width << "x" << height << std::endl;
    }
    
    std::string getName() const override {
        return "Rectangle";
    }
};

int main() {
    // Shape s;  // 错误: 不能实例化抽象类
    
    Circle circle(5);
    Rectangle rect(4, 6);
    
    circle.printInfo();
    rect.printInfo();
    
    // 多态使用
    Shape* shapes[] = {&circle, &rect};
    for (Shape* shape : shapes) {
        shape->draw();
    }
    
    return 0;
}
```

### 1.2 抽象类的特点

```
抽象类特点:

1. 不能直接实例化
2. 可以有成员变量
3. 可以有普通成员函数
4. 可以有构造函数 (供派生类调用)
5. 派生类必须实现所有纯虚函数才能实例化
6. 可以有指针和引用
```

### 1.3 部分实现的抽象类

```cpp
#include <iostream>

// 部分实现的抽象类
class Animal {
public:
    std::string name;
    
    Animal(const std::string& n) : name(n) { }
    
    // 纯虚函数
    virtual void speak() const = 0;
    
    // 已实现的虚函数
    virtual void eat() const {
        std::cout << name << " is eating" << std::endl;
    }
    
    virtual void sleep() const {
        std::cout << name << " is sleeping" << std::endl;
    }
    
    virtual ~Animal() = default;
};

class Dog : public Animal {
public:
    Dog(const std::string& n) : Animal(n) { }
    
    // 必须实现纯虚函数
    void speak() const override {
        std::cout << name << " says: Woof!" << std::endl;
    }
    
    // 可选: 重写已实现的虚函数
    void eat() const override {
        std::cout << name << " is eating dog food" << std::endl;
    }
};

class Cat : public Animal {
public:
    Cat(const std::string& n) : Animal(n) { }
    
    void speak() const override {
        std::cout << name << " says: Meow!" << std::endl;
    }
};

int main() {
    Dog dog("Buddy");
    Cat cat("Whiskers");
    
    dog.speak();
    dog.eat();
    dog.sleep();
    
    cat.speak();
    cat.eat();   // 使用基类实现
    cat.sleep(); // 使用基类实现
    
    return 0;
}
```

---

## 2. 纯虚函数

### 2.1 纯虚函数语法

```cpp
#include <iostream>

class Base {
public:
    // 纯虚函数声明
    virtual void pureVirtual() = 0;
    
    // 纯虚函数可以有实现
    virtual void pureWithImpl() = 0;
    
    virtual ~Base() = default;
};

// 纯虚函数的实现 (类外定义)
void Base::pureWithImpl() {
    std::cout << "Base::pureWithImpl()" << std::endl;
}

class Derived : public Base {
public:
    void pureVirtual() override {
        std::cout << "Derived::pureVirtual()" << std::endl;
    }
    
    void pureWithImpl() override {
        // 可以调用基类的实现
        Base::pureWithImpl();
        std::cout << "Derived::pureWithImpl()" << std::endl;
    }
};

int main() {
    Derived d;
    d.pureVirtual();
    d.pureWithImpl();
    
    return 0;
}
```

### 2.2 纯虚析构函数

```cpp
#include <iostream>

class Base {
public:
    // 纯虚析构函数
    virtual ~Base() = 0;
};

// 必须提供实现
Base::~Base() {
    std::cout << "Base destructor" << std::endl;
}

class Derived : public Base {
public:
    ~Derived() override {
        std::cout << "Derived destructor" << std::endl;
    }
};

int main() {
    // Base b;  // 错误: 抽象类
    
    Derived d;
    
    Base* ptr = new Derived();
    delete ptr;  // 正确调用析构函数链
    
    return 0;
}
```

---

## 3. 接口设计

### 3.1 纯接口类

```cpp
#include <iostream>
#include <string>

// 纯接口: 只有纯虚函数
class IDrawable {
public:
    virtual void draw() const = 0;
    virtual void setColor(const std::string& color) = 0;
    virtual std::string getColor() const = 0;
    virtual ~IDrawable() = default;
};

class IPrintable {
public:
    virtual void print() const = 0;
    virtual std::string toString() const = 0;
    virtual ~IPrintable() = default;
};

class ISerializable {
public:
    virtual std::string serialize() const = 0;
    virtual void deserialize(const std::string& data) = 0;
    virtual ~ISerializable() = default;
};

// 实现多个接口
class Shape : public IDrawable, public IPrintable {
public:
    std::string color = "black";
    
    void setColor(const std::string& c) override {
        color = c;
    }
    
    std::string getColor() const override {
        return color;
    }
    
    void print() const override {
        std::cout << toString() << std::endl;
    }
};

class Circle : public Shape {
public:
    double radius;
    
    Circle(double r) : radius(r) { }
    
    void draw() const override {
        std::cout << "Drawing " << color << " circle with radius " << radius << std::endl;
    }
    
    std::string toString() const override {
        return "Circle(radius=" + std::to_string(radius) + ", color=" + color + ")";
    }
};

int main() {
    Circle circle(5);
    circle.setColor("red");
    
    // 通过不同接口使用
    IDrawable* drawable = &circle;
    drawable->draw();
    
    IPrintable* printable = &circle;
    printable->print();
    
    return 0;
}
```

### 3.2 接口命名约定

```cpp
/*
接口命名约定:

1. I 前缀 (常见于 C++)
   - IDrawable
   - ISerializable
   - IComparable

2. able 后缀
   - Drawable
   - Serializable
   - Comparable

3. 描述性名称
   - Observer
   - Listener
   - Handler
*/

// 示例
class IObserver {
public:
    virtual void onUpdate(const std::string& message) = 0;
    virtual ~IObserver() = default;
};

class IEventListener {
public:
    virtual void onEvent(int eventType, void* data) = 0;
    virtual ~IEventListener() = default;
};

class IComparable {
public:
    virtual int compareTo(const IComparable& other) const = 0;
    virtual ~IComparable() = default;
};
```

---

## 4. 多接口继承

### 4.1 实现多个接口

```cpp
#include <iostream>
#include <string>
#include <vector>

// 接口定义
class IReadable {
public:
    virtual std::string read() const = 0;
    virtual ~IReadable() = default;
};

class IWritable {
public:
    virtual void write(const std::string& data) = 0;
    virtual ~IWritable() = default;
};

class ICloseable {
public:
    virtual void close() = 0;
    virtual bool isClosed() const = 0;
    virtual ~ICloseable() = default;
};

// 组合接口
class IReadWriteCloseable : public IReadable, public IWritable, public ICloseable {
};

// 实现类
class File : public IReadWriteCloseable {
public:
    std::string filename;
    std::string content;
    bool closed = false;
    
    File(const std::string& name) : filename(name) { }
    
    std::string read() const override {
        if (closed) throw std::runtime_error("File is closed");
        return content;
    }
    
    void write(const std::string& data) override {
        if (closed) throw std::runtime_error("File is closed");
        content += data;
    }
    
    void close() override {
        closed = true;
        std::cout << "File " << filename << " closed" << std::endl;
    }
    
    bool isClosed() const override {
        return closed;
    }
};

// 使用接口
void processReadable(const IReadable& readable) {
    std::cout << "Content: " << readable.read() << std::endl;
}

void processWritable(IWritable& writable) {
    writable.write("Hello, World!");
}

int main() {
    File file("test.txt");
    
    processWritable(file);
    processReadable(file);
    
    file.close();
    
    return 0;
}
```

### 4.2 接口隔离原则

```cpp
#include <iostream>

// 不好: 胖接口
class IBadWorker {
public:
    virtual void work() = 0;
    virtual void eat() = 0;
    virtual void sleep() = 0;
    virtual ~IBadWorker() = default;
};

// 机器人不需要 eat 和 sleep
class Robot : public IBadWorker {
public:
    void work() override { std::cout << "Robot working" << std::endl; }
    void eat() override { /* 不需要 */ }
    void sleep() override { /* 不需要 */ }
};

// 好: 接口隔离
class IWorkable {
public:
    virtual void work() = 0;
    virtual ~IWorkable() = default;
};

class IEatable {
public:
    virtual void eat() = 0;
    virtual ~IEatable() = default;
};

class ISleepable {
public:
    virtual void sleep() = 0;
    virtual ~ISleepable() = default;
};

// 人类实现所有接口
class Human : public IWorkable, public IEatable, public ISleepable {
public:
    void work() override { std::cout << "Human working" << std::endl; }
    void eat() override { std::cout << "Human eating" << std::endl; }
    void sleep() override { std::cout << "Human sleeping" << std::endl; }
};

// 机器人只实现需要的接口
class GoodRobot : public IWorkable {
public:
    void work() override { std::cout << "Robot working" << std::endl; }
};

int main() {
    Human human;
    GoodRobot robot;
    
    // 通过接口使用
    IWorkable* workers[] = {&human, &robot};
    for (IWorkable* worker : workers) {
        worker->work();
    }
    
    return 0;
}
```

---

## 5. 接口与实现分离

### 5.1 Pimpl 模式

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
    
    Widget(Widget&&) noexcept;
    Widget& operator=(Widget&&) noexcept;
    
    void doSomething();
    void setName(const std::string& name);
    std::string getName() const;

private:
    class Impl;
    std::unique_ptr<Impl> pImpl;
};

#endif
```

```cpp
// widget.cpp
#include "widget.h"
#include <iostream>

class Widget::Impl {
public:
    std::string name;
    int value = 0;
    
    void internalWork() {
        std::cout << "Internal work for " << name << std::endl;
    }
};

Widget::Widget() : pImpl(std::make_unique<Impl>()) { }
Widget::~Widget() = default;
Widget::Widget(Widget&&) noexcept = default;
Widget& Widget::operator=(Widget&&) noexcept = default;

void Widget::doSomething() {
    pImpl->internalWork();
}

void Widget::setName(const std::string& name) {
    pImpl->name = name;
}

std::string Widget::getName() const {
    return pImpl->name;
}
```

### 5.2 抽象工厂

```cpp
#include <iostream>
#include <memory>
#include <string>

// 产品接口
class IButton {
public:
    virtual void render() const = 0;
    virtual void onClick() const = 0;
    virtual ~IButton() = default;
};

class ITextBox {
public:
    virtual void render() const = 0;
    virtual void setText(const std::string& text) = 0;
    virtual ~ITextBox() = default;
};

// 工厂接口
class IUIFactory {
public:
    virtual std::unique_ptr<IButton> createButton() const = 0;
    virtual std::unique_ptr<ITextBox> createTextBox() const = 0;
    virtual ~IUIFactory() = default;
};

// Windows 实现
class WindowsButton : public IButton {
public:
    void render() const override {
        std::cout << "Rendering Windows button" << std::endl;
    }
    void onClick() const override {
        std::cout << "Windows button clicked" << std::endl;
    }
};

class WindowsTextBox : public ITextBox {
public:
    void render() const override {
        std::cout << "Rendering Windows textbox" << std::endl;
    }
    void setText(const std::string& text) override {
        std::cout << "Windows textbox: " << text << std::endl;
    }
};

class WindowsUIFactory : public IUIFactory {
public:
    std::unique_ptr<IButton> createButton() const override {
        return std::make_unique<WindowsButton>();
    }
    std::unique_ptr<ITextBox> createTextBox() const override {
        return std::make_unique<WindowsTextBox>();
    }
};

// macOS 实现
class MacButton : public IButton {
public:
    void render() const override {
        std::cout << "Rendering Mac button" << std::endl;
    }
    void onClick() const override {
        std::cout << "Mac button clicked" << std::endl;
    }
};

class MacTextBox : public ITextBox {
public:
    void render() const override {
        std::cout << "Rendering Mac textbox" << std::endl;
    }
    void setText(const std::string& text) override {
        std::cout << "Mac textbox: " << text << std::endl;
    }
};

class MacUIFactory : public IUIFactory {
public:
    std::unique_ptr<IButton> createButton() const override {
        return std::make_unique<MacButton>();
    }
    std::unique_ptr<ITextBox> createTextBox() const override {
        return std::make_unique<MacTextBox>();
    }
};

// 客户端代码
void createUI(const IUIFactory& factory) {
    auto button = factory.createButton();
    auto textBox = factory.createTextBox();
    
    button->render();
    textBox->render();
    textBox->setText("Hello");
    button->onClick();
}

int main() {
    std::cout << "=== Windows UI ===" << std::endl;
    WindowsUIFactory windowsFactory;
    createUI(windowsFactory);
    
    std::cout << "\n=== Mac UI ===" << std::endl;
    MacUIFactory macFactory;
    createUI(macFactory);
    
    return 0;
}
```

---

## 6. 设计模式应用

### 6.1 策略模式

```cpp
#include <iostream>
#include <memory>
#include <vector>

// 策略接口
class ISortStrategy {
public:
    virtual void sort(std::vector<int>& data) const = 0;
    virtual std::string getName() const = 0;
    virtual ~ISortStrategy() = default;
};

// 具体策略
class BubbleSort : public ISortStrategy {
public:
    void sort(std::vector<int>& data) const override {
        for (size_t i = 0; i < data.size(); ++i) {
            for (size_t j = 0; j < data.size() - i - 1; ++j) {
                if (data[j] > data[j + 1]) {
                    std::swap(data[j], data[j + 1]);
                }
            }
        }
    }
    
    std::string getName() const override { return "Bubble Sort"; }
};

class QuickSort : public ISortStrategy {
public:
    void sort(std::vector<int>& data) const override {
        quickSort(data, 0, data.size() - 1);
    }
    
    std::string getName() const override { return "Quick Sort"; }

private:
    void quickSort(std::vector<int>& data, int low, int high) const {
        if (low < high) {
            int pi = partition(data, low, high);
            quickSort(data, low, pi - 1);
            quickSort(data, pi + 1, high);
        }
    }
    
    int partition(std::vector<int>& data, int low, int high) const {
        int pivot = data[high];
        int i = low - 1;
        for (int j = low; j < high; ++j) {
            if (data[j] < pivot) {
                ++i;
                std::swap(data[i], data[j]);
            }
        }
        std::swap(data[i + 1], data[high]);
        return i + 1;
    }
};

// 上下文
class Sorter {
public:
    void setStrategy(std::unique_ptr<ISortStrategy> strategy) {
        this->strategy = std::move(strategy);
    }
    
    void sort(std::vector<int>& data) {
        if (strategy) {
            std::cout << "Using " << strategy->getName() << std::endl;
            strategy->sort(data);
        }
    }

private:
    std::unique_ptr<ISortStrategy> strategy;
};

int main() {
    std::vector<int> data = {64, 34, 25, 12, 22, 11, 90};
    
    Sorter sorter;
    
    sorter.setStrategy(std::make_unique<BubbleSort>());
    sorter.sort(data);
    
    for (int x : data) std::cout << x << " ";
    std::cout << std::endl;
    
    data = {64, 34, 25, 12, 22, 11, 90};
    sorter.setStrategy(std::make_unique<QuickSort>());
    sorter.sort(data);
    
    for (int x : data) std::cout << x << " ";
    std::cout << std::endl;
    
    return 0;
}
```

### 6.2 观察者模式

```cpp
#include <iostream>
#include <vector>
#include <string>
#include <algorithm>

// 观察者接口
class IObserver {
public:
    virtual void update(const std::string& message) = 0;
    virtual ~IObserver() = default;
};

// 主题接口
class ISubject {
public:
    virtual void attach(IObserver* observer) = 0;
    virtual void detach(IObserver* observer) = 0;
    virtual void notify() = 0;
    virtual ~ISubject() = default;
};

// 具体主题
class NewsPublisher : public ISubject {
public:
    void attach(IObserver* observer) override {
        observers.push_back(observer);
    }
    
    void detach(IObserver* observer) override {
        observers.erase(
            std::remove(observers.begin(), observers.end(), observer),
            observers.end()
        );
    }
    
    void notify() override {
        for (IObserver* observer : observers) {
            observer->update(latestNews);
        }
    }
    
    void publishNews(const std::string& news) {
        latestNews = news;
        std::cout << "Publishing: " << news << std::endl;
        notify();
    }

private:
    std::vector<IObserver*> observers;
    std::string latestNews;
};

// 具体观察者
class NewsSubscriber : public IObserver {
public:
    std::string name;
    
    NewsSubscriber(const std::string& n) : name(n) { }
    
    void update(const std::string& message) override {
        std::cout << name << " received: " << message << std::endl;
    }
};

int main() {
    NewsPublisher publisher;
    
    NewsSubscriber sub1("Alice");
    NewsSubscriber sub2("Bob");
    NewsSubscriber sub3("Charlie");
    
    publisher.attach(&sub1);
    publisher.attach(&sub2);
    publisher.attach(&sub3);
    
    publisher.publishNews("Breaking: C++ is awesome!");
    
    std::cout << std::endl;
    publisher.detach(&sub2);
    
    publisher.publishNews("Update: New C++ standard released!");
    
    return 0;
}
```

---

## 7. 总结

### 7.1 抽象类 vs 接口

| 特性 | 抽象类 | 接口 (纯虚类) |
|------|--------|--------------|
| 成员变量 | 可以有 | 通常没有 |
| 实现代码 | 可以有 | 通常没有 |
| 构造函数 | 可以有 | 通常没有 |
| 多继承 | 复杂 | 简单 |
| 用途 | 部分实现 | 定义契约 |

### 7.2 设计原则

```
1. 依赖倒置原则 (DIP)
   - 依赖抽象,不依赖具体

2. 接口隔离原则 (ISP)
   - 小而专一的接口

3. 开闭原则 (OCP)
   - 对扩展开放,对修改关闭

4. 里氏替换原则 (LSP)
   - 子类可以替换父类
```

### 7.3 Part 2 完成

恭喜你完成了面向对象编程部分的全部 8 篇文章!

**实战项目建议**: 简易 2D 游戏引擎
- 使用继承设计游戏对象
- 使用多态实现渲染
- 使用接口定义行为

### 7.4 下一篇预告

在下一篇文章中,我们将进入内存管理部分,学习动态内存分配。

---

> 作者: C++ 技术专栏  
> 系列: 面向对象编程 (8/8)  
> 上一篇: [友元与静态成员](./15-friend-static.md)  
> 下一篇: [动态内存分配](../part3-memory/17-dynamic-memory.md)
