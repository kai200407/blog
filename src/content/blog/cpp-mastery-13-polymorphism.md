---
title: "多态与虚函数"
description: "1. [多态概述](#1-多态概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 13
---

> 本文是 C++ 从入门到精通系列的第十三篇,将深入讲解 C++ 的多态机制、虚函数以及运行时类型识别。

---

## 目录

1. [多态概述](#1-多态概述)
2. [虚函数](#2-虚函数)
3. [纯虚函数与抽象类](#3-纯虚函数与抽象类)
4. [虚函数表](#4-虚函数表)
5. [运行时类型识别](#5-运行时类型识别)
6. [多态最佳实践](#6-多态最佳实践)
7. [总结](#7-总结)

---

## 1. 多态概述

### 1.1 什么是多态

```
多态 (Polymorphism):

定义: 同一接口,不同实现

类型:
1. 编译时多态 (静态多态)
   - 函数重载
   - 运算符重载
   - 模板

2. 运行时多态 (动态多态)
   - 虚函数
   - 通过基类指针/引用调用派生类方法
```

### 1.2 多态示例

```cpp
#include <iostream>
#include <vector>
#include <memory>

class Shape {
public:
    virtual ~Shape() = default;
    virtual double area() const = 0;
    virtual void draw() const = 0;
};

class Circle : public Shape {
public:
    double radius;
    
    Circle(double r) : radius(r) { }
    
    double area() const override {
        return 3.14159 * radius * radius;
    }
    
    void draw() const override {
        std::cout << "Drawing Circle with radius " << radius << std::endl;
    }
};

class Rectangle : public Shape {
public:
    double width, height;
    
    Rectangle(double w, double h) : width(w), height(h) { }
    
    double area() const override {
        return width * height;
    }
    
    void draw() const override {
        std::cout << "Drawing Rectangle " << width << "x" << height << std::endl;
    }
};

int main() {
    std::vector<std::unique_ptr<Shape>> shapes;
    shapes.push_back(std::make_unique<Circle>(5));
    shapes.push_back(std::make_unique<Rectangle>(4, 6));
    shapes.push_back(std::make_unique<Circle>(3));
    
    // 多态: 通过基类指针调用派生类方法
    for (const auto& shape : shapes) {
        shape->draw();
        std::cout << "Area: " << shape->area() << std::endl;
    }
    
    return 0;
}
```

---

## 2. 虚函数

### 2.1 虚函数基础

```cpp
#include <iostream>

class Animal {
public:
    // 虚函数
    virtual void speak() const {
        std::cout << "Animal speaks" << std::endl;
    }
    
    // 非虚函数
    void eat() const {
        std::cout << "Animal eats" << std::endl;
    }
    
    virtual ~Animal() = default;
};

class Dog : public Animal {
public:
    // 重写虚函数
    void speak() const override {
        std::cout << "Dog barks" << std::endl;
    }
    
    // 隐藏非虚函数 (不是重写)
    void eat() const {
        std::cout << "Dog eats bones" << std::endl;
    }
};

class Cat : public Animal {
public:
    void speak() const override {
        std::cout << "Cat meows" << std::endl;
    }
};

int main() {
    Dog dog;
    Cat cat;
    
    Animal* animalPtr = &dog;
    
    // 虚函数: 调用派生类版本
    animalPtr->speak();  // "Dog barks"
    
    // 非虚函数: 调用基类版本
    animalPtr->eat();    // "Animal eats"
    
    // 直接调用
    dog.eat();           // "Dog eats bones"
    
    // 通过引用
    Animal& animalRef = cat;
    animalRef.speak();   // "Cat meows"
    
    return 0;
}
```

### 2.2 override 和 final

```cpp
#include <iostream>

class Base {
public:
    virtual void func1() { }
    virtual void func2() { }
    virtual void func3() final { }  // 不能被重写
    void func4() { }
    
    virtual ~Base() = default;
};

class Derived : public Base {
public:
    // override: 明确表示重写
    void func1() override { }
    
    // 没有 override 也可以重写,但不推荐
    void func2() { }
    
    // 错误: func3 是 final,不能重写
    // void func3() override { }
    
    // 错误: func4 不是虚函数,不能重写
    // void func4() override { }
};

// final 类: 不能被继承
class FinalClass final : public Base {
public:
    void func1() override { }
};

// 错误: FinalClass 是 final,不能继承
// class MoreDerived : public FinalClass { };
```

### 2.3 虚析构函数

```cpp
#include <iostream>

class Base {
public:
    Base() { std::cout << "Base constructor" << std::endl; }
    
    // 虚析构函数: 确保正确析构派生类
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
    delete ptr;  // 正确调用 Derived 析构函数
    
    return 0;
}

/*
输出:
Base constructor
Derived constructor
Derived destructor
Base destructor

如果 Base 析构函数不是虚的:
Base constructor
Derived constructor
Base destructor
(内存泄漏!)
*/
```

### 2.4 协变返回类型

```cpp
#include <iostream>

class Animal {
public:
    virtual Animal* clone() const {
        return new Animal(*this);
    }
    virtual ~Animal() = default;
};

class Dog : public Animal {
public:
    // 协变返回类型: 返回派生类指针
    Dog* clone() const override {
        return new Dog(*this);
    }
};

int main() {
    Dog dog;
    
    // 通过基类指针调用
    Animal* animalPtr = &dog;
    Animal* cloned = animalPtr->clone();  // 返回 Dog*
    
    // 直接调用
    Dog* dogClone = dog.clone();  // 返回 Dog*
    
    delete cloned;
    delete dogClone;
    
    return 0;
}
```

---

## 3. 纯虚函数与抽象类

### 3.1 纯虚函数

```cpp
#include <iostream>

// 抽象类: 包含纯虚函数
class Shape {
public:
    // 纯虚函数: = 0
    virtual double area() const = 0;
    virtual double perimeter() const = 0;
    virtual void draw() const = 0;
    
    // 可以有非纯虚函数
    virtual void describe() const {
        std::cout << "This is a shape" << std::endl;
    }
    
    // 可以有普通成员
    std::string name = "Shape";
    
    virtual ~Shape() = default;
};

// 具体类: 实现所有纯虚函数
class Circle : public Shape {
public:
    double radius;
    
    Circle(double r) : radius(r) { name = "Circle"; }
    
    double area() const override {
        return 3.14159 * radius * radius;
    }
    
    double perimeter() const override {
        return 2 * 3.14159 * radius;
    }
    
    void draw() const override {
        std::cout << "Drawing circle" << std::endl;
    }
};

int main() {
    // Shape s;  // 错误: 不能实例化抽象类
    
    Circle c(5);
    c.draw();
    std::cout << "Area: " << c.area() << std::endl;
    
    // 可以使用抽象类的指针/引用
    Shape* ptr = &c;
    ptr->draw();
    
    return 0;
}
```

### 3.2 接口类

```cpp
#include <iostream>
#include <string>

// 接口: 只有纯虚函数
class Drawable {
public:
    virtual void draw() const = 0;
    virtual ~Drawable() = default;
};

class Printable {
public:
    virtual void print() const = 0;
    virtual ~Printable() = default;
};

class Serializable {
public:
    virtual std::string serialize() const = 0;
    virtual void deserialize(const std::string& data) = 0;
    virtual ~Serializable() = default;
};

// 实现多个接口
class Document : public Drawable, public Printable, public Serializable {
public:
    std::string content;
    
    void draw() const override {
        std::cout << "Drawing document" << std::endl;
    }
    
    void print() const override {
        std::cout << "Printing: " << content << std::endl;
    }
    
    std::string serialize() const override {
        return "DOC:" + content;
    }
    
    void deserialize(const std::string& data) override {
        if (data.substr(0, 4) == "DOC:") {
            content = data.substr(4);
        }
    }
};

int main() {
    Document doc;
    doc.content = "Hello, World!";
    
    // 通过不同接口使用
    Drawable* drawable = &doc;
    drawable->draw();
    
    Printable* printable = &doc;
    printable->print();
    
    Serializable* serializable = &doc;
    std::cout << serializable->serialize() << std::endl;
    
    return 0;
}
```

### 3.3 纯虚函数的实现

```cpp
#include <iostream>

class Base {
public:
    // 纯虚函数可以有实现
    virtual void func() = 0;
    
    virtual ~Base() = default;
};

// 纯虚函数的实现 (类外定义)
void Base::func() {
    std::cout << "Base::func() implementation" << std::endl;
}

class Derived : public Base {
public:
    void func() override {
        // 可以调用基类的实现
        Base::func();
        std::cout << "Derived::func()" << std::endl;
    }
};

int main() {
    Derived d;
    d.func();
    
    return 0;
}
```

---

## 4. 虚函数表

### 4.1 虚函数表原理

```
虚函数表 (vtable) 原理:

1. 每个包含虚函数的类都有一个虚函数表
2. 虚函数表是函数指针数组
3. 每个对象都有一个指向虚函数表的指针 (vptr)

内存布局:

对象:
+--------+
|  vptr  | --> vtable
+--------+
| 成员1  |
+--------+
| 成员2  |
+--------+

vtable:
+------------------+
| &Base::func1     |  或 &Derived::func1
+------------------+
| &Base::func2     |  或 &Derived::func2
+------------------+
| ...              |
+------------------+
```

### 4.2 虚函数表示例

```cpp
#include <iostream>

class Base {
public:
    virtual void func1() { std::cout << "Base::func1" << std::endl; }
    virtual void func2() { std::cout << "Base::func2" << std::endl; }
    virtual ~Base() = default;
    
    int data = 0;
};

class Derived : public Base {
public:
    void func1() override { std::cout << "Derived::func1" << std::endl; }
    // func2 不重写,使用基类版本
    
    int derivedData = 0;
};

int main() {
    std::cout << "sizeof(Base): " << sizeof(Base) << std::endl;
    std::cout << "sizeof(Derived): " << sizeof(Derived) << std::endl;
    
    Base b;
    Derived d;
    
    Base* ptr = &d;
    ptr->func1();  // Derived::func1 (通过 vtable)
    ptr->func2();  // Base::func2 (通过 vtable)
    
    return 0;
}
```

### 4.3 虚函数调用开销

```cpp
#include <iostream>
#include <chrono>

class Base {
public:
    virtual void virtualFunc() { }
    void normalFunc() { }
    virtual ~Base() = default;
};

class Derived : public Base {
public:
    void virtualFunc() override { }
};

int main() {
    Derived d;
    Base* ptr = &d;
    
    const int iterations = 100000000;
    
    // 测试虚函数调用
    auto start1 = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < iterations; ++i) {
        ptr->virtualFunc();
    }
    auto end1 = std::chrono::high_resolution_clock::now();
    
    // 测试普通函数调用
    auto start2 = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < iterations; ++i) {
        ptr->normalFunc();
    }
    auto end2 = std::chrono::high_resolution_clock::now();
    
    auto duration1 = std::chrono::duration_cast<std::chrono::milliseconds>(end1 - start1);
    auto duration2 = std::chrono::duration_cast<std::chrono::milliseconds>(end2 - start2);
    
    std::cout << "Virtual function: " << duration1.count() << " ms" << std::endl;
    std::cout << "Normal function: " << duration2.count() << " ms" << std::endl;
    
    return 0;
}
```

---

## 5. 运行时类型识别

### 5.1 dynamic_cast

```cpp
#include <iostream>

class Base {
public:
    virtual ~Base() = default;
};

class Derived1 : public Base {
public:
    void derived1Method() {
        std::cout << "Derived1 method" << std::endl;
    }
};

class Derived2 : public Base {
public:
    void derived2Method() {
        std::cout << "Derived2 method" << std::endl;
    }
};

void process(Base* ptr) {
    // 尝试转换为 Derived1
    if (Derived1* d1 = dynamic_cast<Derived1*>(ptr)) {
        d1->derived1Method();
    }
    // 尝试转换为 Derived2
    else if (Derived2* d2 = dynamic_cast<Derived2*>(ptr)) {
        d2->derived2Method();
    }
    else {
        std::cout << "Unknown type" << std::endl;
    }
}

int main() {
    Derived1 d1;
    Derived2 d2;
    Base b;
    
    process(&d1);  // Derived1 method
    process(&d2);  // Derived2 method
    process(&b);   // Unknown type
    
    // 引用版本 (失败时抛出 std::bad_cast)
    try {
        Base& ref = d1;
        Derived1& d1Ref = dynamic_cast<Derived1&>(ref);
        d1Ref.derived1Method();
    } catch (const std::bad_cast& e) {
        std::cout << "Bad cast: " << e.what() << std::endl;
    }
    
    return 0;
}
```

### 5.2 typeid

```cpp
#include <iostream>
#include <typeinfo>

class Base {
public:
    virtual ~Base() = default;
};

class Derived : public Base { };

int main() {
    Base b;
    Derived d;
    Base* ptr = &d;
    
    // typeid 返回 type_info 对象
    std::cout << "Type of b: " << typeid(b).name() << std::endl;
    std::cout << "Type of d: " << typeid(d).name() << std::endl;
    std::cout << "Type of *ptr: " << typeid(*ptr).name() << std::endl;
    
    // 比较类型
    if (typeid(*ptr) == typeid(Derived)) {
        std::cout << "ptr points to Derived" << std::endl;
    }
    
    // 基本类型
    int i = 0;
    double d2 = 0.0;
    std::cout << "Type of int: " << typeid(i).name() << std::endl;
    std::cout << "Type of double: " << typeid(d2).name() << std::endl;
    
    return 0;
}
```

### 5.3 RTTI 的替代方案

```cpp
#include <iostream>

// 使用虚函数代替 RTTI
class Shape {
public:
    enum class Type { Circle, Rectangle, Triangle };
    
    virtual Type getType() const = 0;
    virtual ~Shape() = default;
};

class Circle : public Shape {
public:
    Type getType() const override { return Type::Circle; }
};

class Rectangle : public Shape {
public:
    Type getType() const override { return Type::Rectangle; }
};

void process(Shape* shape) {
    switch (shape->getType()) {
        case Shape::Type::Circle:
            std::cout << "Processing Circle" << std::endl;
            break;
        case Shape::Type::Rectangle:
            std::cout << "Processing Rectangle" << std::endl;
            break;
        default:
            std::cout << "Unknown shape" << std::endl;
    }
}

// 更好的方式: 使用访问者模式
class ShapeVisitor;

class VisitableShape {
public:
    virtual void accept(ShapeVisitor& visitor) = 0;
    virtual ~VisitableShape() = default;
};

class VisitableCircle;
class VisitableRectangle;

class ShapeVisitor {
public:
    virtual void visit(VisitableCircle& circle) = 0;
    virtual void visit(VisitableRectangle& rect) = 0;
    virtual ~ShapeVisitor() = default;
};

class VisitableCircle : public VisitableShape {
public:
    void accept(ShapeVisitor& visitor) override {
        visitor.visit(*this);
    }
};

class VisitableRectangle : public VisitableShape {
public:
    void accept(ShapeVisitor& visitor) override {
        visitor.visit(*this);
    }
};
```

---

## 6. 多态最佳实践

### 6.1 设计原则

```cpp
#include <iostream>
#include <memory>
#include <vector>

// 1. 使用智能指针管理多态对象
class Animal {
public:
    virtual void speak() const = 0;
    virtual ~Animal() = default;
};

class Dog : public Animal {
public:
    void speak() const override { std::cout << "Woof!" << std::endl; }
};

class Cat : public Animal {
public:
    void speak() const override { std::cout << "Meow!" << std::endl; }
};

// 2. 工厂函数返回智能指针
std::unique_ptr<Animal> createAnimal(const std::string& type) {
    if (type == "dog") return std::make_unique<Dog>();
    if (type == "cat") return std::make_unique<Cat>();
    return nullptr;
}

// 3. 使用接口而非具体类
void makeSpeak(const Animal& animal) {
    animal.speak();
}

int main() {
    // 使用智能指针容器
    std::vector<std::unique_ptr<Animal>> animals;
    animals.push_back(createAnimal("dog"));
    animals.push_back(createAnimal("cat"));
    
    for (const auto& animal : animals) {
        if (animal) {
            makeSpeak(*animal);
        }
    }
    
    return 0;
}
```

### 6.2 NVI 模式

```cpp
#include <iostream>

// Non-Virtual Interface (NVI) 模式
class Base {
public:
    // 公有非虚接口
    void process() {
        preProcess();
        doProcess();  // 调用虚函数
        postProcess();
    }
    
    virtual ~Base() = default;

protected:
    // 私有/保护虚函数供派生类重写
    virtual void doProcess() = 0;

private:
    void preProcess() {
        std::cout << "Pre-processing..." << std::endl;
    }
    
    void postProcess() {
        std::cout << "Post-processing..." << std::endl;
    }
};

class Derived : public Base {
protected:
    void doProcess() override {
        std::cout << "Derived processing" << std::endl;
    }
};

int main() {
    Derived d;
    d.process();
    
    return 0;
}
```

---

## 7. 总结

### 7.1 多态要点

| 概念 | 说明 |
|------|------|
| 虚函数 | 允许派生类重写 |
| 纯虚函数 | 必须被派生类实现 |
| 抽象类 | 包含纯虚函数的类 |
| override | 明确重写意图 |
| final | 禁止重写/继承 |
| dynamic_cast | 安全的向下转型 |

### 7.2 多态检查清单

```
[ ] 基类析构函数是 virtual
[ ] 使用 override 标记重写
[ ] 使用智能指针管理多态对象
[ ] 避免在构造/析构函数中调用虚函数
[ ] 考虑使用 NVI 模式
[ ] 谨慎使用 RTTI
```

### 7.3 下一篇预告

在下一篇文章中,我们将学习运算符重载。

---

> 作者: C++ 技术专栏  
> 系列: 面向对象编程 (5/8)  
> 上一篇: [继承](./12-inheritance.md)  
> 下一篇: [运算符重载](./14-operator-overloading.md)
