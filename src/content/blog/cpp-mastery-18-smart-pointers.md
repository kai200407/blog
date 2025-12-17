---
title: "智能指针"
description: "1. [智能指针概述](#1-智能指针概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 18
---

> 本文是 C++ 从入门到精通系列的第十八篇,将深入讲解 C++ 的智能指针,包括 unique_ptr、shared_ptr 和 weak_ptr。

---

## 目录

1. [智能指针概述](#1-智能指针概述)
2. [unique_ptr](#2-unique_ptr)
3. [shared_ptr](#3-shared_ptr)
4. [weak_ptr](#4-weak_ptr)
5. [智能指针与数组](#5-智能指针与数组)
6. [最佳实践](#6-最佳实践)
7. [总结](#7-总结)

---

## 1. 智能指针概述

### 1.1 为什么需要智能指针

```cpp
#include <iostream>
#include <memory>

// 问题: 裸指针的问题
void rawPointerProblems() {
    // 1. 忘记释放
    int* p1 = new int(42);
    // 忘记 delete p1;
    
    // 2. 异常导致泄漏
    int* p2 = new int(42);
    throw std::runtime_error("Error");  // p2 泄漏
    delete p2;
    
    // 3. 重复释放
    int* p3 = new int(42);
    delete p3;
    // delete p3;  // 未定义行为
    
    // 4. 悬空指针
    int* p4 = new int(42);
    delete p4;
    // *p4 = 100;  // 未定义行为
}

// 解决方案: 智能指针
void smartPointerSolution() {
    // 自动管理内存
    std::unique_ptr<int> p1 = std::make_unique<int>(42);
    // 离开作用域自动释放
    
    // 异常安全
    std::unique_ptr<int> p2 = std::make_unique<int>(42);
    throw std::runtime_error("Error");  // p2 仍然会被正确释放
}
```

### 1.2 智能指针类型

```
智能指针类型:

1. std::unique_ptr
   - 独占所有权
   - 不能拷贝,只能移动
   - 零开销抽象

2. std::shared_ptr
   - 共享所有权
   - 引用计数
   - 有一定开销

3. std::weak_ptr
   - 弱引用
   - 不增加引用计数
   - 用于打破循环引用
```

---

## 2. unique_ptr

### 2.1 基本用法

```cpp
#include <iostream>
#include <memory>
#include <string>

class Resource {
public:
    std::string name;
    
    Resource(const std::string& n) : name(n) {
        std::cout << "Resource " << name << " created" << std::endl;
    }
    
    ~Resource() {
        std::cout << "Resource " << name << " destroyed" << std::endl;
    }
    
    void use() {
        std::cout << "Using " << name << std::endl;
    }
};

int main() {
    // 创建 unique_ptr
    std::unique_ptr<Resource> ptr1(new Resource("A"));
    
    // 推荐: 使用 make_unique (C++14)
    auto ptr2 = std::make_unique<Resource>("B");
    
    // 使用
    ptr1->use();
    ptr2->use();
    
    // 获取原始指针
    Resource* raw = ptr1.get();
    raw->use();
    
    // 检查是否为空
    if (ptr1) {
        std::cout << "ptr1 is not null" << std::endl;
    }
    
    // 释放所有权
    Resource* released = ptr1.release();
    std::cout << "ptr1 is null: " << (ptr1 == nullptr) << std::endl;
    delete released;  // 需要手动删除
    
    // 重置
    ptr2.reset();  // 释放并置空
    ptr2.reset(new Resource("C"));  // 释放旧的,指向新的
    
    return 0;
}  // ptr2 自动释放
```

### 2.2 移动语义

```cpp
#include <iostream>
#include <memory>
#include <vector>

class Widget {
public:
    int id;
    Widget(int i) : id(i) {
        std::cout << "Widget " << id << " created" << std::endl;
    }
    ~Widget() {
        std::cout << "Widget " << id << " destroyed" << std::endl;
    }
};

std::unique_ptr<Widget> createWidget(int id) {
    return std::make_unique<Widget>(id);
}

void processWidget(std::unique_ptr<Widget> widget) {
    std::cout << "Processing widget " << widget->id << std::endl;
}

int main() {
    // unique_ptr 不能拷贝
    auto ptr1 = std::make_unique<Widget>(1);
    // auto ptr2 = ptr1;  // 错误: 不能拷贝
    
    // 可以移动
    auto ptr2 = std::move(ptr1);
    std::cout << "ptr1 is null: " << (ptr1 == nullptr) << std::endl;
    
    // 从函数返回
    auto ptr3 = createWidget(2);
    
    // 传递给函数 (转移所有权)
    processWidget(std::move(ptr3));
    std::cout << "ptr3 is null: " << (ptr3 == nullptr) << std::endl;
    
    // 存储在容器中
    std::vector<std::unique_ptr<Widget>> widgets;
    widgets.push_back(std::make_unique<Widget>(3));
    widgets.push_back(std::make_unique<Widget>(4));
    
    return 0;
}
```

### 2.3 自定义删除器

```cpp
#include <iostream>
#include <memory>
#include <cstdio>

// 自定义删除器
struct FileDeleter {
    void operator()(FILE* file) const {
        if (file) {
            std::cout << "Closing file" << std::endl;
            fclose(file);
        }
    }
};

int main() {
    // 使用函数对象作为删除器
    std::unique_ptr<FILE, FileDeleter> file1(fopen("test.txt", "w"));
    if (file1) {
        fprintf(file1.get(), "Hello, World!\n");
    }
    
    // 使用 lambda 作为删除器
    auto deleter = [](FILE* f) {
        if (f) {
            std::cout << "Lambda closing file" << std::endl;
            fclose(f);
        }
    };
    std::unique_ptr<FILE, decltype(deleter)> file2(fopen("test2.txt", "w"), deleter);
    
    // 使用函数指针作为删除器
    std::unique_ptr<FILE, int(*)(FILE*)> file3(fopen("test3.txt", "w"), fclose);
    
    return 0;
}
```

---

## 3. shared_ptr

### 3.1 基本用法

```cpp
#include <iostream>
#include <memory>

class Resource {
public:
    std::string name;
    
    Resource(const std::string& n) : name(n) {
        std::cout << "Resource " << name << " created" << std::endl;
    }
    
    ~Resource() {
        std::cout << "Resource " << name << " destroyed" << std::endl;
    }
};

int main() {
    // 创建 shared_ptr
    std::shared_ptr<Resource> ptr1(new Resource("A"));
    
    // 推荐: 使用 make_shared
    auto ptr2 = std::make_shared<Resource>("B");
    
    std::cout << "ptr2 use_count: " << ptr2.use_count() << std::endl;  // 1
    
    // 共享所有权
    auto ptr3 = ptr2;
    std::cout << "ptr2 use_count: " << ptr2.use_count() << std::endl;  // 2
    std::cout << "ptr3 use_count: " << ptr3.use_count() << std::endl;  // 2
    
    // ptr3 离开作用域
    {
        auto ptr4 = ptr2;
        std::cout << "ptr2 use_count: " << ptr2.use_count() << std::endl;  // 3
    }
    std::cout << "ptr2 use_count: " << ptr2.use_count() << std::endl;  // 2
    
    // 重置
    ptr3.reset();
    std::cout << "ptr2 use_count: " << ptr2.use_count() << std::endl;  // 1
    
    return 0;
}  // 最后一个 shared_ptr 销毁时释放资源
```

### 3.2 make_shared 的优势

```cpp
#include <iostream>
#include <memory>

class Widget {
public:
    int data[100];
    Widget() { std::cout << "Widget created" << std::endl; }
    ~Widget() { std::cout << "Widget destroyed" << std::endl; }
};

int main() {
    // 方式 1: 直接构造 (两次内存分配)
    std::shared_ptr<Widget> ptr1(new Widget());
    // 分配 1: Widget 对象
    // 分配 2: 控制块 (引用计数等)
    
    // 方式 2: make_shared (一次内存分配)
    auto ptr2 = std::make_shared<Widget>();
    // 分配 1: Widget 对象 + 控制块 (一起分配)
    
    // make_shared 的优势:
    // 1. 更高效 (一次分配)
    // 2. 异常安全
    // 3. 代码更简洁
    
    // 异常安全问题示例
    // processWidget(std::shared_ptr<Widget>(new Widget()), computePriority());
    // 如果 computePriority() 抛出异常,new Widget() 可能泄漏
    
    // 安全版本
    // processWidget(std::make_shared<Widget>(), computePriority());
    
    return 0;
}
```

### 3.3 自定义删除器

```cpp
#include <iostream>
#include <memory>

class Connection {
public:
    int id;
    Connection(int i) : id(i) {
        std::cout << "Connection " << id << " opened" << std::endl;
    }
};

void closeConnection(Connection* conn) {
    std::cout << "Connection " << conn->id << " closed" << std::endl;
    delete conn;
}

int main() {
    // shared_ptr 的删除器不影响类型
    std::shared_ptr<Connection> conn1(new Connection(1), closeConnection);
    
    // lambda 删除器
    std::shared_ptr<Connection> conn2(new Connection(2), [](Connection* c) {
        std::cout << "Lambda closing connection " << c->id << std::endl;
        delete c;
    });
    
    // 可以赋值给相同类型 (删除器不是类型的一部分)
    std::shared_ptr<Connection> conn3 = conn1;
    
    return 0;
}
```

### 3.4 enable_shared_from_this

```cpp
#include <iostream>
#include <memory>

class Widget : public std::enable_shared_from_this<Widget> {
public:
    int id;
    
    Widget(int i) : id(i) {
        std::cout << "Widget " << id << " created" << std::endl;
    }
    
    ~Widget() {
        std::cout << "Widget " << id << " destroyed" << std::endl;
    }
    
    std::shared_ptr<Widget> getShared() {
        return shared_from_this();
    }
    
    void process() {
        // 需要传递 shared_ptr 给其他函数
        auto self = shared_from_this();
        // doSomething(self);
    }
};

int main() {
    // 必须先创建 shared_ptr
    auto ptr1 = std::make_shared<Widget>(1);
    
    // 获取共享指针
    auto ptr2 = ptr1->getShared();
    
    std::cout << "use_count: " << ptr1.use_count() << std::endl;  // 2
    
    // 错误: 不能在没有 shared_ptr 的情况下调用
    // Widget w(2);
    // auto ptr3 = w.getShared();  // 未定义行为
    
    return 0;
}
```

---

## 4. weak_ptr

### 4.1 基本用法

```cpp
#include <iostream>
#include <memory>

int main() {
    std::weak_ptr<int> weak;
    
    {
        auto shared = std::make_shared<int>(42);
        weak = shared;
        
        std::cout << "use_count: " << shared.use_count() << std::endl;  // 1
        std::cout << "weak expired: " << weak.expired() << std::endl;   // false
        
        // 获取 shared_ptr
        if (auto locked = weak.lock()) {
            std::cout << "Value: " << *locked << std::endl;
            std::cout << "use_count: " << shared.use_count() << std::endl;  // 2
        }
    }
    
    // shared_ptr 已销毁
    std::cout << "weak expired: " << weak.expired() << std::endl;  // true
    
    if (auto locked = weak.lock()) {
        std::cout << "Value: " << *locked << std::endl;
    } else {
        std::cout << "Object no longer exists" << std::endl;
    }
    
    return 0;
}
```

### 4.2 解决循环引用

```cpp
#include <iostream>
#include <memory>
#include <string>

// 问题: 循环引用导致内存泄漏
class BadNode {
public:
    std::string name;
    std::shared_ptr<BadNode> next;
    std::shared_ptr<BadNode> prev;  // 循环引用!
    
    BadNode(const std::string& n) : name(n) {
        std::cout << "BadNode " << name << " created" << std::endl;
    }
    ~BadNode() {
        std::cout << "BadNode " << name << " destroyed" << std::endl;
    }
};

// 解决方案: 使用 weak_ptr
class GoodNode {
public:
    std::string name;
    std::shared_ptr<GoodNode> next;
    std::weak_ptr<GoodNode> prev;  // 使用 weak_ptr
    
    GoodNode(const std::string& n) : name(n) {
        std::cout << "GoodNode " << name << " created" << std::endl;
    }
    ~GoodNode() {
        std::cout << "GoodNode " << name << " destroyed" << std::endl;
    }
};

int main() {
    std::cout << "=== Bad Example ===" << std::endl;
    {
        auto node1 = std::make_shared<BadNode>("A");
        auto node2 = std::make_shared<BadNode>("B");
        
        node1->next = node2;
        node2->prev = node1;  // 循环引用
        
        std::cout << "node1 use_count: " << node1.use_count() << std::endl;  // 2
        std::cout << "node2 use_count: " << node2.use_count() << std::endl;  // 2
    }
    std::cout << "BadNodes not destroyed (memory leak)!" << std::endl;
    
    std::cout << "\n=== Good Example ===" << std::endl;
    {
        auto node1 = std::make_shared<GoodNode>("A");
        auto node2 = std::make_shared<GoodNode>("B");
        
        node1->next = node2;
        node2->prev = node1;  // weak_ptr 不增加引用计数
        
        std::cout << "node1 use_count: " << node1.use_count() << std::endl;  // 1
        std::cout << "node2 use_count: " << node2.use_count() << std::endl;  // 2
    }
    std::cout << "GoodNodes properly destroyed!" << std::endl;
    
    return 0;
}
```

### 4.3 观察者模式中的应用

```cpp
#include <iostream>
#include <memory>
#include <vector>
#include <algorithm>

class Observer;

class Subject {
public:
    void attach(std::weak_ptr<Observer> observer) {
        observers.push_back(observer);
    }
    
    void notify();

private:
    std::vector<std::weak_ptr<Observer>> observers;
};

class Observer : public std::enable_shared_from_this<Observer> {
public:
    std::string name;
    
    Observer(const std::string& n) : name(n) {
        std::cout << "Observer " << name << " created" << std::endl;
    }
    
    ~Observer() {
        std::cout << "Observer " << name << " destroyed" << std::endl;
    }
    
    void update() {
        std::cout << "Observer " << name << " notified" << std::endl;
    }
};

void Subject::notify() {
    // 清理已销毁的观察者
    observers.erase(
        std::remove_if(observers.begin(), observers.end(),
            [](const std::weak_ptr<Observer>& wp) { return wp.expired(); }),
        observers.end()
    );
    
    // 通知存活的观察者
    for (auto& wp : observers) {
        if (auto sp = wp.lock()) {
            sp->update();
        }
    }
}

int main() {
    Subject subject;
    
    auto obs1 = std::make_shared<Observer>("A");
    auto obs2 = std::make_shared<Observer>("B");
    
    subject.attach(obs1);
    subject.attach(obs2);
    
    std::cout << "\n=== First notify ===" << std::endl;
    subject.notify();
    
    obs1.reset();  // 销毁 Observer A
    
    std::cout << "\n=== Second notify ===" << std::endl;
    subject.notify();  // 只通知 Observer B
    
    return 0;
}
```

---

## 5. 智能指针与数组

### 5.1 unique_ptr 与数组

```cpp
#include <iostream>
#include <memory>

int main() {
    // unique_ptr 支持数组
    std::unique_ptr<int[]> arr(new int[5]);
    
    for (int i = 0; i < 5; ++i) {
        arr[i] = i * 10;
    }
    
    for (int i = 0; i < 5; ++i) {
        std::cout << arr[i] << " ";
    }
    std::cout << std::endl;
    
    // C++14: make_unique 支持数组
    auto arr2 = std::make_unique<int[]>(5);
    
    // 自动调用 delete[]
    
    return 0;
}
```

### 5.2 shared_ptr 与数组

```cpp
#include <iostream>
#include <memory>

int main() {
    // C++17 之前: 需要自定义删除器
    std::shared_ptr<int> arr1(new int[5], std::default_delete<int[]>());
    
    // 或使用 lambda
    std::shared_ptr<int> arr2(new int[5], [](int* p) { delete[] p; });
    
    // C++17: 直接支持数组
    std::shared_ptr<int[]> arr3(new int[5]);
    
    // C++20: make_shared 支持数组
    // auto arr4 = std::make_shared<int[]>(5);
    
    // 使用
    for (int i = 0; i < 5; ++i) {
        arr3[i] = i * 10;
    }
    
    for (int i = 0; i < 5; ++i) {
        std::cout << arr3[i] << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

---

## 6. 最佳实践

### 6.1 选择正确的智能指针

```cpp
/*
选择指南:

1. unique_ptr (默认选择)
   - 独占所有权
   - 零开销
   - 可以转换为 shared_ptr

2. shared_ptr
   - 需要共享所有权
   - 有引用计数开销
   - 注意循环引用

3. weak_ptr
   - 观察但不拥有
   - 打破循环引用
   - 缓存场景
*/

#include <iostream>
#include <memory>

class Resource {
public:
    void use() { std::cout << "Using resource" << std::endl; }
};

// 工厂函数: 返回 unique_ptr
std::unique_ptr<Resource> createResource() {
    return std::make_unique<Resource>();
}

// 独占所有权: 使用 unique_ptr
void exclusiveOwnership(std::unique_ptr<Resource> res) {
    res->use();
}

// 共享所有权: 使用 shared_ptr
void sharedOwnership(std::shared_ptr<Resource> res) {
    res->use();
}

// 只是使用,不拥有: 使用引用或原始指针
void justUse(Resource& res) {
    res.use();
}

void justUsePtr(Resource* res) {
    if (res) res->use();
}

int main() {
    auto res = createResource();
    
    // 传递引用 (不转移所有权)
    justUse(*res);
    justUsePtr(res.get());
    
    // 转移所有权
    exclusiveOwnership(std::move(res));
    
    // 转换为 shared_ptr
    auto shared = std::make_shared<Resource>();
    sharedOwnership(shared);
    
    return 0;
}
```

### 6.2 避免常见错误

```cpp
#include <iostream>
#include <memory>

class Widget {
public:
    int id;
    Widget(int i) : id(i) { }
};

int main() {
    // 错误 1: 同一指针创建多个智能指针
    Widget* raw = new Widget(1);
    // std::shared_ptr<Widget> sp1(raw);
    // std::shared_ptr<Widget> sp2(raw);  // 错误: 双重释放
    
    // 正确: 使用 make_shared 或拷贝
    auto sp1 = std::make_shared<Widget>(1);
    auto sp2 = sp1;  // 正确: 共享所有权
    
    // 错误 2: 从 this 创建 shared_ptr
    // 使用 enable_shared_from_this
    
    // 错误 3: 循环引用
    // 使用 weak_ptr 打破循环
    
    // 错误 4: 使用已移动的 unique_ptr
    auto up = std::make_unique<Widget>(2);
    auto up2 = std::move(up);
    // up->id;  // 错误: up 已为空
    
    // 错误 5: get() 返回的指针被删除
    auto sp = std::make_shared<Widget>(3);
    Widget* ptr = sp.get();
    // delete ptr;  // 错误: 智能指针仍然管理这块内存
    
    return 0;
}
```

---

## 7. 总结

### 7.1 智能指针对比

| 特性 | unique_ptr | shared_ptr | weak_ptr |
|------|------------|------------|----------|
| 所有权 | 独占 | 共享 | 无 |
| 拷贝 | 不可 | 可以 | 可以 |
| 移动 | 可以 | 可以 | 可以 |
| 开销 | 零 | 引用计数 | 无 |
| 数组 | 支持 | C++17 支持 | - |

### 7.2 使用建议

```
1. 默认使用 unique_ptr
2. 需要共享时使用 shared_ptr
3. 使用 make_unique/make_shared
4. 用 weak_ptr 打破循环引用
5. 避免混用裸指针和智能指针
6. 函数参数考虑使用引用
```

### 7.3 下一篇预告

在下一篇文章中,我们将学习 RAII 与资源管理。

---

> 作者: C++ 技术专栏  
> 系列: 内存管理与指针进阶 (2/6)  
> 上一篇: [动态内存分配](./17-dynamic-memory.md)  
> 下一篇: [RAII 与资源管理](./19-raii.md)
