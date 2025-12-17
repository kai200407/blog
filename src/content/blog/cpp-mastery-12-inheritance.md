---
title: "继承"
description: "1. [继承基础](#1-继承基础)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 12
---

> 本文是 C++ 从入门到精通系列的第十二篇,将深入讲解 C++ 的继承机制,包括单继承、多继承和虚继承。

---

## 目录

1. [继承基础](#1-继承基础)
2. [继承类型](#2-继承类型)
3. [构造与析构](#3-构造与析构)
4. [多继承](#4-多继承)
5. [虚继承](#5-虚继承)
6. [继承最佳实践](#6-继承最佳实践)
7. [总结](#7-总结)

---

## 1. 继承基础

### 1.1 继承概念

```cpp
#include <iostream>
#include <string>

// 基类 (父类)
class Animal {
public:
    std::string name;
    int age;
    
    Animal(const std::string& n, int a) : name(n), age(a) { }
    
    void eat() {
        std::cout << name << " is eating" << std::endl;
    }
    
    void sleep() {
        std::cout << name << " is sleeping" << std::endl;
    }
};

// 派生类 (子类)
class Dog : public Animal {
public:
    std::string breed;
    
    Dog(const std::string& n, int a, const std::string& b)
        : Animal(n, a), breed(b) { }
    
    void bark() {
        std::cout << name << " is barking" << std::endl;
    }
};

class Cat : public Animal {
public:
    bool isIndoor;
    
    Cat(const std::string& n, int a, bool indoor)
        : Animal(n, a), isIndoor(indoor) { }
    
    void meow() {
        std::cout << name << " is meowing" << std::endl;
    }
};

int main() {
    Dog dog("Buddy", 3, "Golden Retriever");
    dog.eat();    // 继承自 Animal
    dog.sleep();  // 继承自 Animal
    dog.bark();   // Dog 自己的方法
    
    Cat cat("Whiskers", 2, true);
    cat.eat();
    cat.meow();
    
    return 0;
}
```

### 1.2 继承层次

```
继承层次示例:

        Animal
       /      \
     Dog      Cat
    /   \
Husky  Poodle

- Animal 是 Dog 和 Cat 的基类
- Dog 是 Husky 和 Poodle 的基类
- Husky 继承了 Dog 和 Animal 的所有成员
```

### 1.3 成员访问

```cpp
#include <iostream>

class Base {
public:
    int publicVar = 1;
    void publicMethod() { std::cout << "Public method" << std::endl; }

protected:
    int protectedVar = 2;
    void protectedMethod() { std::cout << "Protected method" << std::endl; }

private:
    int privateVar = 3;
    void privateMethod() { std::cout << "Private method" << std::endl; }
};

class Derived : public Base {
public:
    void accessMembers() {
        // 可以访问 public 成员
        publicVar = 10;
        publicMethod();
        
        // 可以访问 protected 成员
        protectedVar = 20;
        protectedMethod();
        
        // 不能访问 private 成员
        // privateVar = 30;      // 错误
        // privateMethod();      // 错误
    }
};

int main() {
    Derived d;
    
    // 类外只能访问 public 成员
    d.publicVar = 100;
    d.publicMethod();
    
    // d.protectedVar = 200;  // 错误
    // d.privateVar = 300;    // 错误
    
    return 0;
}
```

---

## 2. 继承类型

### 2.1 public 继承

```cpp
#include <iostream>

class Base {
public:
    int pub = 1;
protected:
    int prot = 2;
private:
    int priv = 3;
};

// public 继承: 保持原有访问级别
class PublicDerived : public Base {
public:
    void show() {
        std::cout << "pub: " << pub << std::endl;    // OK: 仍是 public
        std::cout << "prot: " << prot << std::endl;  // OK: 仍是 protected
        // std::cout << "priv: " << priv << std::endl;  // 错误: 不可访问
    }
};

int main() {
    PublicDerived pd;
    pd.pub = 10;  // OK: public
    // pd.prot = 20;  // 错误: protected
    
    return 0;
}
```

### 2.2 protected 继承

```cpp
#include <iostream>

class Base {
public:
    int pub = 1;
protected:
    int prot = 2;
};

// protected 继承: public 变成 protected
class ProtectedDerived : protected Base {
public:
    void show() {
        std::cout << "pub: " << pub << std::endl;    // OK: 变成 protected
        std::cout << "prot: " << prot << std::endl;  // OK: 仍是 protected
    }
};

class GrandChild : public ProtectedDerived {
public:
    void access() {
        pub = 10;   // OK: 是 protected
        prot = 20;  // OK: 是 protected
    }
};

int main() {
    ProtectedDerived pd;
    // pd.pub = 10;  // 错误: 变成了 protected
    
    return 0;
}
```

### 2.3 private 继承

```cpp
#include <iostream>

class Base {
public:
    int pub = 1;
protected:
    int prot = 2;
};

// private 继承: 全部变成 private
class PrivateDerived : private Base {
public:
    void show() {
        std::cout << "pub: " << pub << std::endl;    // OK: 变成 private
        std::cout << "prot: " << prot << std::endl;  // OK: 变成 private
    }
    
    // 可以选择性地暴露基类成员
    using Base::pub;  // 将 pub 重新设为 public
};

class GrandChild : public PrivateDerived {
public:
    void access() {
        // pub = 10;   // 错误: 在 PrivateDerived 中是 private
        // prot = 20;  // 错误: 在 PrivateDerived 中是 private
    }
};

int main() {
    PrivateDerived pd;
    pd.pub = 10;  // OK: 通过 using 重新暴露
    
    return 0;
}
```

### 2.4 继承类型对比

```
继承类型对比:

基类成员      public继承    protected继承    private继承
─────────────────────────────────────────────────────
public        public        protected        private
protected     protected     protected        private
private       不可访问      不可访问         不可访问
```

---

## 3. 构造与析构

### 3.1 构造顺序

```cpp
#include <iostream>

class Base {
public:
    Base() { std::cout << "Base constructor" << std::endl; }
    Base(int x) { std::cout << "Base constructor with " << x << std::endl; }
    ~Base() { std::cout << "Base destructor" << std::endl; }
};

class Derived : public Base {
public:
    Derived() : Base() {
        std::cout << "Derived constructor" << std::endl;
    }
    
    Derived(int x) : Base(x) {
        std::cout << "Derived constructor with " << x << std::endl;
    }
    
    ~Derived() {
        std::cout << "Derived destructor" << std::endl;
    }
};

int main() {
    std::cout << "=== Creating Derived ===" << std::endl;
    Derived d(42);
    
    std::cout << "=== Destroying ===" << std::endl;
    return 0;
}

/*
输出:
=== Creating Derived ===
Base constructor with 42
Derived constructor with 42
=== Destroying ===
Derived destructor
Base destructor
*/
```

### 3.2 成员初始化顺序

```cpp
#include <iostream>

class Member {
public:
    std::string name;
    Member(const std::string& n) : name(n) {
        std::cout << "Member " << name << " constructed" << std::endl;
    }
    ~Member() {
        std::cout << "Member " << name << " destroyed" << std::endl;
    }
};

class Base {
public:
    Member baseMember;
    Base() : baseMember("BaseMember") {
        std::cout << "Base constructed" << std::endl;
    }
    ~Base() {
        std::cout << "Base destroyed" << std::endl;
    }
};

class Derived : public Base {
public:
    Member derivedMember;
    Derived() : derivedMember("DerivedMember") {
        std::cout << "Derived constructed" << std::endl;
    }
    ~Derived() {
        std::cout << "Derived destroyed" << std::endl;
    }
};

int main() {
    Derived d;
    return 0;
}

/*
构造顺序:
1. 基类成员 (baseMember)
2. 基类构造函数
3. 派生类成员 (derivedMember)
4. 派生类构造函数

析构顺序: 相反
*/
```

### 3.3 调用基类构造函数

```cpp
#include <iostream>
#include <string>

class Person {
public:
    std::string name;
    int age;
    
    Person() : name("Unknown"), age(0) {
        std::cout << "Person default constructor" << std::endl;
    }
    
    Person(const std::string& n, int a) : name(n), age(a) {
        std::cout << "Person parameterized constructor" << std::endl;
    }
};

class Student : public Person {
public:
    int studentId;
    
    // 调用基类默认构造函数
    Student() : Person(), studentId(0) {
        std::cout << "Student default constructor" << std::endl;
    }
    
    // 调用基类参数化构造函数
    Student(const std::string& n, int a, int id)
        : Person(n, a), studentId(id) {
        std::cout << "Student parameterized constructor" << std::endl;
    }
};

int main() {
    Student s1;
    std::cout << "---" << std::endl;
    Student s2("Alice", 20, 12345);
    
    return 0;
}
```

---

## 4. 多继承

### 4.1 多继承基础

```cpp
#include <iostream>
#include <string>

class Flyable {
public:
    void fly() {
        std::cout << "Flying..." << std::endl;
    }
};

class Swimmable {
public:
    void swim() {
        std::cout << "Swimming..." << std::endl;
    }
};

// 多继承
class Duck : public Flyable, public Swimmable {
public:
    void quack() {
        std::cout << "Quack!" << std::endl;
    }
};

int main() {
    Duck duck;
    duck.fly();   // 从 Flyable 继承
    duck.swim();  // 从 Swimmable 继承
    duck.quack(); // Duck 自己的方法
    
    return 0;
}
```

### 4.2 菱形继承问题

```cpp
#include <iostream>

class Animal {
public:
    int age = 0;
    void eat() { std::cout << "Eating" << std::endl; }
};

class Mammal : public Animal {
public:
    void breathe() { std::cout << "Breathing" << std::endl; }
};

class Bird : public Animal {
public:
    void fly() { std::cout << "Flying" << std::endl; }
};

// 菱形继承: Bat 有两份 Animal
class Bat : public Mammal, public Bird {
public:
    void echolocate() { std::cout << "Echolocating" << std::endl; }
};

int main() {
    Bat bat;
    
    // bat.age = 5;  // 错误: 歧义,有两个 age
    // bat.eat();    // 错误: 歧义,有两个 eat()
    
    // 需要指定使用哪个基类的成员
    bat.Mammal::age = 5;
    bat.Bird::age = 5;
    bat.Mammal::eat();
    
    return 0;
}
```

---

## 5. 虚继承

### 5.1 解决菱形继承

```cpp
#include <iostream>

class Animal {
public:
    int age = 0;
    Animal() { std::cout << "Animal constructor" << std::endl; }
    void eat() { std::cout << "Eating" << std::endl; }
};

// 虚继承
class Mammal : virtual public Animal {
public:
    Mammal() { std::cout << "Mammal constructor" << std::endl; }
    void breathe() { std::cout << "Breathing" << std::endl; }
};

class Bird : virtual public Animal {
public:
    Bird() { std::cout << "Bird constructor" << std::endl; }
    void fly() { std::cout << "Flying" << std::endl; }
};

// 现在只有一份 Animal
class Bat : public Mammal, public Bird {
public:
    Bat() { std::cout << "Bat constructor" << std::endl; }
    void echolocate() { std::cout << "Echolocating" << std::endl; }
};

int main() {
    Bat bat;
    
    bat.age = 5;  // OK: 只有一个 age
    bat.eat();    // OK: 只有一个 eat()
    
    std::cout << "Age: " << bat.age << std::endl;
    
    return 0;
}

/*
输出:
Animal constructor
Mammal constructor
Bird constructor
Bat constructor
Eating
Age: 5
*/
```

### 5.2 虚继承的构造

```cpp
#include <iostream>

class Base {
public:
    int value;
    Base(int v) : value(v) {
        std::cout << "Base(" << v << ")" << std::endl;
    }
};

class Left : virtual public Base {
public:
    Left(int v) : Base(v) {
        std::cout << "Left(" << v << ")" << std::endl;
    }
};

class Right : virtual public Base {
public:
    Right(int v) : Base(v) {
        std::cout << "Right(" << v << ")" << std::endl;
    }
};

class Bottom : public Left, public Right {
public:
    // 虚基类必须由最派生类直接初始化
    Bottom(int v) : Base(v), Left(v), Right(v) {
        std::cout << "Bottom(" << v << ")" << std::endl;
    }
};

int main() {
    Bottom b(42);
    std::cout << "Value: " << b.value << std::endl;
    
    return 0;
}
```

---

## 6. 继承最佳实践

### 6.1 何时使用继承

```cpp
/*
使用继承的场景:

1. IS-A 关系
   - Dog IS-A Animal
   - Student IS-A Person

2. 需要多态
   - 通过基类指针/引用操作派生类对象

3. 代码复用
   - 派生类需要基类的大部分功能

不应使用继承的场景:

1. HAS-A 关系 (使用组合)
   - Car HAS-A Engine

2. 只是为了复用代码
   - 考虑组合或模板

3. 基类不是为继承设计的
*/
```

### 6.2 组合优于继承

```cpp
#include <iostream>
#include <string>

// 不好: 使用继承
class BadStack : public std::vector<int> {
    // Stack 不是 vector,不应该继承
};

// 好: 使用组合
class GoodStack {
public:
    void push(int value) {
        data.push_back(value);
    }
    
    int pop() {
        int value = data.back();
        data.pop_back();
        return value;
    }
    
    bool empty() const {
        return data.empty();
    }
    
    size_t size() const {
        return data.size();
    }

private:
    std::vector<int> data;  // 组合
};

// 组合示例: Car HAS-A Engine
class Engine {
public:
    void start() { std::cout << "Engine started" << std::endl; }
    void stop() { std::cout << "Engine stopped" << std::endl; }
};

class Car {
public:
    void start() {
        engine.start();
        std::cout << "Car started" << std::endl;
    }
    
    void stop() {
        std::cout << "Car stopping" << std::endl;
        engine.stop();
    }

private:
    Engine engine;  // 组合,不是继承
};
```

### 6.3 继承设计原则

```cpp
#include <iostream>

// 1. 基类析构函数应该是 virtual 的
class Base {
public:
    virtual ~Base() = default;
};

// 2. 如果不想被继承,使用 final
class FinalClass final {
    // 不能被继承
};

// 3. 如果方法不应被重写,使用 final
class Parent {
public:
    virtual void method() final {
        // 不能被重写
    }
};

// 4. 使用 override 明确重写意图
class Child : public Base {
public:
    void someMethod() override {  // 如果基类没有此虚函数,编译错误
        // ...
    }
};

// 5. 避免在构造/析构函数中调用虚函数
class BadExample {
public:
    BadExample() {
        // 危险: 虚函数调用不会按预期工作
        // virtualMethod();
    }
    virtual void virtualMethod() { }
};
```

---

## 7. 总结

### 7.1 继承类型对比

| 继承类型 | public成员 | protected成员 | 使用场景 |
|---------|-----------|--------------|---------|
| public | public | protected | IS-A 关系 |
| protected | protected | protected | 实现继承 |
| private | private | private | 实现继承 |

### 7.2 继承检查清单

```
[ ] 确认是 IS-A 关系
[ ] 基类析构函数是 virtual
[ ] 使用 override 标记重写
[ ] 避免深层继承
[ ] 考虑组合替代继承
[ ] 虚继承解决菱形问题
```

### 7.3 下一篇预告

在下一篇文章中,我们将学习多态与虚函数。

---

> 作者: C++ 技术专栏  
> 系列: 面向对象编程 (4/8)  
> 上一篇: [访问控制与封装](./11-access-control.md)  
> 下一篇: [多态与虚函数](./13-polymorphism.md)
