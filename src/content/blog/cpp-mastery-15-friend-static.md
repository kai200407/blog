---
title: "友元与静态成员"
description: "1. [友元函数](#1-友元函数)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 15
---

> 本文是 C++ 从入门到精通系列的第十五篇,将深入讲解 C++ 的友元机制和静态成员。

---

## 目录

1. [友元函数](#1-友元函数)
2. [友元类](#2-友元类)
3. [静态成员变量](#3-静态成员变量)
4. [静态成员函数](#4-静态成员函数)
5. [单例模式](#5-单例模式)
6. [总结](#6-总结)

---

## 1. 友元函数

### 1.1 友元函数基础

```cpp
#include <iostream>

class Box {
public:
    Box(double l, double w, double h) 
        : length(l), width(w), height(h) { }
    
    // 声明友元函数
    friend double calculateVolume(const Box& box);
    friend void printBox(const Box& box);

private:
    double length, width, height;
};

// 友元函数定义 (可以访问私有成员)
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

### 1.2 友元与运算符重载

```cpp
#include <iostream>

class Complex {
public:
    double real, imag;
    
    Complex(double r = 0, double i = 0) : real(r), imag(i) { }
    
    // 友元运算符重载
    friend Complex operator+(const Complex& a, const Complex& b);
    friend Complex operator-(const Complex& a, const Complex& b);
    friend Complex operator*(const Complex& a, const Complex& b);
    friend std::ostream& operator<<(std::ostream& os, const Complex& c);
    friend bool operator==(const Complex& a, const Complex& b);
};

Complex operator+(const Complex& a, const Complex& b) {
    return Complex(a.real + b.real, a.imag + b.imag);
}

Complex operator-(const Complex& a, const Complex& b) {
    return Complex(a.real - b.real, a.imag - b.imag);
}

Complex operator*(const Complex& a, const Complex& b) {
    return Complex(
        a.real * b.real - a.imag * b.imag,
        a.real * b.imag + a.imag * b.real
    );
}

std::ostream& operator<<(std::ostream& os, const Complex& c) {
    os << c.real;
    if (c.imag >= 0) os << "+";
    os << c.imag << "i";
    return os;
}

bool operator==(const Complex& a, const Complex& b) {
    return a.real == b.real && a.imag == b.imag;
}

int main() {
    Complex c1(1, 2);
    Complex c2(3, 4);
    
    std::cout << "c1 = " << c1 << std::endl;
    std::cout << "c2 = " << c2 << std::endl;
    std::cout << "c1 + c2 = " << (c1 + c2) << std::endl;
    std::cout << "c1 * c2 = " << (c1 * c2) << std::endl;
    
    return 0;
}
```

### 1.3 友元成员函数

```cpp
#include <iostream>

class B;  // 前向声明

class A {
public:
    void accessB(B& b);
};

class B {
public:
    B(int v) : value(v) { }

private:
    int value;
    
    // 只有 A::accessB 是友元
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

---

## 2. 友元类

### 2.1 友元类基础

```cpp
#include <iostream>
#include <string>

class Engine {
public:
    void start() { running = true; }
    void stop() { running = false; }

private:
    bool running = false;
    int rpm = 0;
    double temperature = 20.0;
    
    // Car 是友元类
    friend class Car;
};

class Car {
public:
    Car(const std::string& model) : modelName(model) { }
    
    void startEngine() {
        engine.start();
        engine.rpm = 800;
        std::cout << modelName << " engine started, RPM: " << engine.rpm << std::endl;
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

### 2.2 友元关系的特性

```cpp
/*
友元关系的特性:

1. 不是相互的
   - A 是 B 的友元,不意味着 B 是 A 的友元

2. 不能传递
   - A 是 B 的友元,B 是 C 的友元,不意味着 A 是 C 的友元

3. 不能继承
   - A 是 B 的友元,C 继承自 B,A 不是 C 的友元

4. 破坏封装
   - 应该谨慎使用
*/

#include <iostream>

class C;

class A {
public:
    void accessC(C& c);
};

class B {
public:
    void accessC(C& c);
};

class C {
private:
    int value = 42;
    friend class A;  // A 是友元
};

void A::accessC(C& c) {
    std::cout << "A accessing C: " << c.value << std::endl;  // OK
}

void B::accessC(C& c) {
    // std::cout << c.value << std::endl;  // 错误: B 不是友元
}
```

---

## 3. 静态成员变量

### 3.1 静态成员变量基础

```cpp
#include <iostream>
#include <string>

class Counter {
public:
    Counter() {
        ++count;
        id = count;
        std::cout << "Counter " << id << " created" << std::endl;
    }
    
    ~Counter() {
        --count;
        std::cout << "Counter " << id << " destroyed" << std::endl;
    }
    
    int getId() const { return id; }
    
    // 静态成员函数访问静态成员变量
    static int getCount() { return count; }

private:
    int id;
    static int count;  // 静态成员变量声明
};

// 静态成员变量定义 (必须在类外)
int Counter::count = 0;

int main() {
    std::cout << "Count: " << Counter::getCount() << std::endl;  // 0
    
    Counter c1;
    Counter c2;
    std::cout << "Count: " << Counter::getCount() << std::endl;  // 2
    
    {
        Counter c3;
        std::cout << "Count: " << Counter::getCount() << std::endl;  // 3
    }
    
    std::cout << "Count: " << Counter::getCount() << std::endl;  // 2
    
    return 0;
}
```

### 3.2 静态成员变量的初始化

```cpp
#include <iostream>
#include <string>

class Config {
public:
    // 静态常量可以在类内初始化 (整型)
    static const int MAX_SIZE = 100;
    static constexpr double PI = 3.14159;
    
    // 非整型静态常量需要在类外初始化
    static const std::string DEFAULT_NAME;
    
    // C++17 内联静态变量
    inline static int inlineVar = 42;
    inline static std::string inlineStr = "Hello";
};

// 类外定义
const std::string Config::DEFAULT_NAME = "Default";

int main() {
    std::cout << "MAX_SIZE: " << Config::MAX_SIZE << std::endl;
    std::cout << "PI: " << Config::PI << std::endl;
    std::cout << "DEFAULT_NAME: " << Config::DEFAULT_NAME << std::endl;
    std::cout << "inlineVar: " << Config::inlineVar << std::endl;
    std::cout << "inlineStr: " << Config::inlineStr << std::endl;
    
    return 0;
}
```

### 3.3 静态成员变量的用途

```cpp
#include <iostream>
#include <vector>
#include <string>

class Logger {
public:
    enum class Level { DEBUG, INFO, WARNING, ERROR };
    
    static void setLevel(Level level) {
        currentLevel = level;
    }
    
    static void log(Level level, const std::string& message) {
        if (level >= currentLevel) {
            logs.push_back(levelToString(level) + ": " + message);
            std::cout << logs.back() << std::endl;
        }
    }
    
    static const std::vector<std::string>& getLogs() {
        return logs;
    }

private:
    static Level currentLevel;
    static std::vector<std::string> logs;
    
    static std::string levelToString(Level level) {
        switch (level) {
            case Level::DEBUG: return "DEBUG";
            case Level::INFO: return "INFO";
            case Level::WARNING: return "WARNING";
            case Level::ERROR: return "ERROR";
            default: return "UNKNOWN";
        }
    }
};

Logger::Level Logger::currentLevel = Logger::Level::INFO;
std::vector<std::string> Logger::logs;

int main() {
    Logger::log(Logger::Level::DEBUG, "Debug message");    // 不输出
    Logger::log(Logger::Level::INFO, "Info message");      // 输出
    Logger::log(Logger::Level::WARNING, "Warning message"); // 输出
    Logger::log(Logger::Level::ERROR, "Error message");    // 输出
    
    Logger::setLevel(Logger::Level::WARNING);
    Logger::log(Logger::Level::INFO, "Another info");      // 不输出
    
    return 0;
}
```

---

## 4. 静态成员函数

### 4.1 静态成员函数基础

```cpp
#include <iostream>
#include <cmath>

class MathUtils {
public:
    // 静态成员函数
    static double square(double x) {
        return x * x;
    }
    
    static double cube(double x) {
        return x * x * x;
    }
    
    static double distance(double x1, double y1, double x2, double y2) {
        return std::sqrt(square(x2 - x1) + square(y2 - y1));
    }
    
    static bool isEven(int n) {
        return n % 2 == 0;
    }
    
    static int factorial(int n) {
        if (n <= 1) return 1;
        return n * factorial(n - 1);
    }
};

int main() {
    // 通过类名调用
    std::cout << "5^2 = " << MathUtils::square(5) << std::endl;
    std::cout << "3^3 = " << MathUtils::cube(3) << std::endl;
    std::cout << "Distance: " << MathUtils::distance(0, 0, 3, 4) << std::endl;
    std::cout << "5! = " << MathUtils::factorial(5) << std::endl;
    
    // 也可以通过对象调用 (不推荐)
    MathUtils utils;
    std::cout << "10^2 = " << utils.square(10) << std::endl;
    
    return 0;
}
```

### 4.2 静态成员函数的限制

```cpp
#include <iostream>

class MyClass {
public:
    int instanceVar = 10;
    static int staticVar;
    
    void instanceMethod() {
        // 可以访问所有成员
        std::cout << "instanceVar: " << instanceVar << std::endl;
        std::cout << "staticVar: " << staticVar << std::endl;
        staticMethod();
    }
    
    static void staticMethod() {
        // 只能访问静态成员
        std::cout << "staticVar: " << staticVar << std::endl;
        
        // 不能访问非静态成员
        // std::cout << instanceVar << std::endl;  // 错误
        // instanceMethod();  // 错误
        
        // 没有 this 指针
        // std::cout << this->staticVar << std::endl;  // 错误
    }
};

int MyClass::staticVar = 20;

int main() {
    MyClass obj;
    obj.instanceMethod();
    
    MyClass::staticMethod();
    
    return 0;
}
```

### 4.3 工厂方法

```cpp
#include <iostream>
#include <memory>
#include <string>

class Shape {
public:
    virtual void draw() const = 0;
    virtual ~Shape() = default;
    
    // 静态工厂方法
    static std::unique_ptr<Shape> create(const std::string& type);
};

class Circle : public Shape {
public:
    void draw() const override {
        std::cout << "Drawing Circle" << std::endl;
    }
};

class Rectangle : public Shape {
public:
    void draw() const override {
        std::cout << "Drawing Rectangle" << std::endl;
    }
};

class Triangle : public Shape {
public:
    void draw() const override {
        std::cout << "Drawing Triangle" << std::endl;
    }
};

std::unique_ptr<Shape> Shape::create(const std::string& type) {
    if (type == "circle") return std::make_unique<Circle>();
    if (type == "rectangle") return std::make_unique<Rectangle>();
    if (type == "triangle") return std::make_unique<Triangle>();
    return nullptr;
}

int main() {
    auto shape1 = Shape::create("circle");
    auto shape2 = Shape::create("rectangle");
    auto shape3 = Shape::create("triangle");
    
    if (shape1) shape1->draw();
    if (shape2) shape2->draw();
    if (shape3) shape3->draw();
    
    return 0;
}
```

---

## 5. 单例模式

### 5.1 基本单例

```cpp
#include <iostream>
#include <string>

class Singleton {
public:
    // 删除拷贝和移动
    Singleton(const Singleton&) = delete;
    Singleton& operator=(const Singleton&) = delete;
    Singleton(Singleton&&) = delete;
    Singleton& operator=(Singleton&&) = delete;
    
    // 获取实例
    static Singleton& getInstance() {
        static Singleton instance;  // C++11 保证线程安全
        return instance;
    }
    
    void doSomething() {
        std::cout << "Singleton doing something" << std::endl;
    }
    
    void setData(const std::string& d) { data = d; }
    std::string getData() const { return data; }

private:
    // 私有构造函数
    Singleton() {
        std::cout << "Singleton created" << std::endl;
    }
    
    ~Singleton() {
        std::cout << "Singleton destroyed" << std::endl;
    }
    
    std::string data;
};

int main() {
    // 获取单例实例
    Singleton& s1 = Singleton::getInstance();
    Singleton& s2 = Singleton::getInstance();
    
    // s1 和 s2 是同一个对象
    std::cout << "Same instance: " << (&s1 == &s2) << std::endl;
    
    s1.setData("Hello");
    std::cout << "s2.getData(): " << s2.getData() << std::endl;
    
    s1.doSomething();
    
    return 0;
}
```

### 5.2 线程安全单例

```cpp
#include <iostream>
#include <mutex>
#include <memory>

class ThreadSafeSingleton {
public:
    ThreadSafeSingleton(const ThreadSafeSingleton&) = delete;
    ThreadSafeSingleton& operator=(const ThreadSafeSingleton&) = delete;
    
    static ThreadSafeSingleton* getInstance() {
        // 双重检查锁定
        if (instance == nullptr) {
            std::lock_guard<std::mutex> lock(mutex);
            if (instance == nullptr) {
                instance = new ThreadSafeSingleton();
            }
        }
        return instance;
    }
    
    void doSomething() {
        std::cout << "ThreadSafeSingleton doing something" << std::endl;
    }

private:
    ThreadSafeSingleton() = default;
    
    static ThreadSafeSingleton* instance;
    static std::mutex mutex;
};

ThreadSafeSingleton* ThreadSafeSingleton::instance = nullptr;
std::mutex ThreadSafeSingleton::mutex;

// 更简单的方式: 使用 Meyers' Singleton (C++11)
class MeyersSingleton {
public:
    MeyersSingleton(const MeyersSingleton&) = delete;
    MeyersSingleton& operator=(const MeyersSingleton&) = delete;
    
    static MeyersSingleton& getInstance() {
        static MeyersSingleton instance;  // C++11 保证线程安全
        return instance;
    }

private:
    MeyersSingleton() = default;
};

int main() {
    ThreadSafeSingleton::getInstance()->doSomething();
    
    MeyersSingleton& s = MeyersSingleton::getInstance();
    
    return 0;
}
```

---

## 6. 总结

### 6.1 友元与静态成员对比

| 特性 | 友元 | 静态成员 |
|------|------|---------|
| 访问私有成员 | 是 | 是 (类内) |
| 属于类 | 否 | 是 |
| 需要对象 | 否 | 否 |
| 破坏封装 | 是 | 否 |

### 6.2 使用建议

```
友元:
- 运算符重载 (特别是 << >>)
- 紧密相关的类之间
- 谨慎使用,避免滥用

静态成员变量:
- 类级别的共享数据
- 计数器、配置信息
- 常量定义

静态成员函数:
- 工具函数
- 工厂方法
- 单例模式
```

### 6.3 下一篇预告

在下一篇文章中,我们将学习抽象类与接口。

---

> 作者: C++ 技术专栏  
> 系列: 面向对象编程 (7/8)  
> 上一篇: [运算符重载](./14-operator-overloading.md)  
> 下一篇: [抽象类与接口](./16-abstract-interface.md)
