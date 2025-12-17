---
title: "设计模式"
description: "1. [设计模式概述](#1-设计模式概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 58
---

> 本文是 C++ 从入门到精通系列的第五十八篇,也是工程实践部分的收官之作。我们将深入讲解常用设计模式的 C++ 实现。

---

## 目录

1. [设计模式概述](#1-设计模式概述)
2. [创建型模式](#2-创建型模式)
3. [结构型模式](#3-结构型模式)
4. [行为型模式](#4-行为型模式)
5. [现代 C++ 模式](#5-现代-c-模式)
6. [总结](#6-总结)

---

## 1. 设计模式概述

### 1.1 什么是设计模式

```
设计模式:
- 解决常见问题的通用方案
- 经过验证的最佳实践
- 提高代码可维护性和复用性

分类:
- 创建型: 对象创建机制
- 结构型: 类和对象组合
- 行为型: 对象间通信
```

### 1.2 设计原则

```
SOLID 原则:

S - 单一职责原则 (SRP)
    一个类只负责一件事

O - 开闭原则 (OCP)
    对扩展开放,对修改关闭

L - 里氏替换原则 (LSP)
    子类可以替换父类

I - 接口隔离原则 (ISP)
    使用多个专门接口

D - 依赖倒置原则 (DIP)
    依赖抽象而非具体
```

---

## 2. 创建型模式

### 2.1 单例模式

```cpp
#include <mutex>
#include <memory>

// 线程安全的单例 (C++11 Meyer's Singleton)
class Singleton {
public:
    static Singleton& getInstance() {
        static Singleton instance;
        return instance;
    }
    
    // 禁止拷贝和移动
    Singleton(const Singleton&) = delete;
    Singleton& operator=(const Singleton&) = delete;
    Singleton(Singleton&&) = delete;
    Singleton& operator=(Singleton&&) = delete;
    
    void doSomething() {
        // ...
    }

private:
    Singleton() = default;
    ~Singleton() = default;
};

// 使用
void example() {
    Singleton::getInstance().doSomething();
}

// 模板单例
template<typename T>
class SingletonHolder {
public:
    static T& getInstance() {
        static T instance;
        return instance;
    }
    
    SingletonHolder(const SingletonHolder&) = delete;
    SingletonHolder& operator=(const SingletonHolder&) = delete;

protected:
    SingletonHolder() = default;
    ~SingletonHolder() = default;
};

class MyService : public SingletonHolder<MyService> {
    friend class SingletonHolder<MyService>;
private:
    MyService() = default;
public:
    void serve() { }
};
```

### 2.2 工厂模式

```cpp
#include <memory>
#include <string>
#include <map>
#include <functional>

// 产品接口
class Product {
public:
    virtual ~Product() = default;
    virtual void use() = 0;
};

// 具体产品
class ConcreteProductA : public Product {
public:
    void use() override {
        std::cout << "Using Product A" << std::endl;
    }
};

class ConcreteProductB : public Product {
public:
    void use() override {
        std::cout << "Using Product B" << std::endl;
    }
};

// 简单工厂
class SimpleFactory {
public:
    static std::unique_ptr<Product> create(const std::string& type) {
        if (type == "A") {
            return std::make_unique<ConcreteProductA>();
        } else if (type == "B") {
            return std::make_unique<ConcreteProductB>();
        }
        return nullptr;
    }
};

// 工厂方法
class Creator {
public:
    virtual ~Creator() = default;
    virtual std::unique_ptr<Product> createProduct() = 0;
    
    void operation() {
        auto product = createProduct();
        product->use();
    }
};

class ConcreteCreatorA : public Creator {
public:
    std::unique_ptr<Product> createProduct() override {
        return std::make_unique<ConcreteProductA>();
    }
};

// 注册工厂
class ProductRegistry {
public:
    using Creator = std::function<std::unique_ptr<Product>()>;
    
    static ProductRegistry& instance() {
        static ProductRegistry registry;
        return registry;
    }
    
    void registerProduct(const std::string& name, Creator creator) {
        creators[name] = std::move(creator);
    }
    
    std::unique_ptr<Product> create(const std::string& name) {
        auto it = creators.find(name);
        if (it != creators.end()) {
            return it->second();
        }
        return nullptr;
    }

private:
    std::map<std::string, Creator> creators;
};

// 自动注册
template<typename T>
class ProductRegistrar {
public:
    ProductRegistrar(const std::string& name) {
        ProductRegistry::instance().registerProduct(name, []() {
            return std::make_unique<T>();
        });
    }
};

// 使用
static ProductRegistrar<ConcreteProductA> regA("A");
static ProductRegistrar<ConcreteProductB> regB("B");
```

### 2.3 建造者模式

```cpp
#include <string>
#include <memory>
#include <optional>

class HttpRequest {
public:
    class Builder {
    public:
        Builder& setMethod(const std::string& method) {
            method_ = method;
            return *this;
        }
        
        Builder& setUrl(const std::string& url) {
            url_ = url;
            return *this;
        }
        
        Builder& setHeader(const std::string& key, const std::string& value) {
            headers_[key] = value;
            return *this;
        }
        
        Builder& setBody(const std::string& body) {
            body_ = body;
            return *this;
        }
        
        Builder& setTimeout(int timeout) {
            timeout_ = timeout;
            return *this;
        }
        
        HttpRequest build() {
            return HttpRequest(*this);
        }
        
    private:
        friend class HttpRequest;
        std::string method_ = "GET";
        std::string url_;
        std::map<std::string, std::string> headers_;
        std::optional<std::string> body_;
        int timeout_ = 30;
    };
    
    static Builder builder() {
        return Builder();
    }
    
    void send() {
        std::cout << method << " " << url << std::endl;
    }

private:
    HttpRequest(const Builder& builder)
        : method(builder.method_)
        , url(builder.url_)
        , headers(builder.headers_)
        , body(builder.body_)
        , timeout(builder.timeout_) { }
    
    std::string method;
    std::string url;
    std::map<std::string, std::string> headers;
    std::optional<std::string> body;
    int timeout;
};

// 使用
void example() {
    auto request = HttpRequest::builder()
        .setMethod("POST")
        .setUrl("https://api.example.com/data")
        .setHeader("Content-Type", "application/json")
        .setBody(R"({"key": "value"})")
        .setTimeout(60)
        .build();
    
    request.send();
}
```

---

## 3. 结构型模式

### 3.1 适配器模式

```cpp
#include <memory>

// 目标接口
class Target {
public:
    virtual ~Target() = default;
    virtual void request() = 0;
};

// 被适配的类
class Adaptee {
public:
    void specificRequest() {
        std::cout << "Specific request" << std::endl;
    }
};

// 对象适配器
class ObjectAdapter : public Target {
public:
    ObjectAdapter(std::shared_ptr<Adaptee> adaptee) 
        : adaptee_(std::move(adaptee)) { }
    
    void request() override {
        adaptee_->specificRequest();
    }

private:
    std::shared_ptr<Adaptee> adaptee_;
};

// 类适配器
class ClassAdapter : public Target, private Adaptee {
public:
    void request() override {
        specificRequest();
    }
};

// 函数适配器
template<typename F>
class FunctionAdapter : public Target {
public:
    FunctionAdapter(F func) : func_(std::move(func)) { }
    
    void request() override {
        func_();
    }

private:
    F func_;
};

// 使用
void example() {
    auto adaptee = std::make_shared<Adaptee>();
    auto adapter = std::make_unique<ObjectAdapter>(adaptee);
    adapter->request();
    
    // 函数适配器
    auto funcAdapter = FunctionAdapter([]() {
        std::cout << "Lambda adapted" << std::endl;
    });
    funcAdapter.request();
}
```

### 3.2 装饰器模式

```cpp
#include <memory>
#include <string>

// 组件接口
class Coffee {
public:
    virtual ~Coffee() = default;
    virtual std::string getDescription() const = 0;
    virtual double getCost() const = 0;
};

// 具体组件
class SimpleCoffee : public Coffee {
public:
    std::string getDescription() const override {
        return "Simple Coffee";
    }
    
    double getCost() const override {
        return 1.0;
    }
};

// 装饰器基类
class CoffeeDecorator : public Coffee {
public:
    CoffeeDecorator(std::unique_ptr<Coffee> coffee)
        : coffee_(std::move(coffee)) { }

protected:
    std::unique_ptr<Coffee> coffee_;
};

// 具体装饰器
class MilkDecorator : public CoffeeDecorator {
public:
    using CoffeeDecorator::CoffeeDecorator;
    
    std::string getDescription() const override {
        return coffee_->getDescription() + ", Milk";
    }
    
    double getCost() const override {
        return coffee_->getCost() + 0.5;
    }
};

class SugarDecorator : public CoffeeDecorator {
public:
    using CoffeeDecorator::CoffeeDecorator;
    
    std::string getDescription() const override {
        return coffee_->getDescription() + ", Sugar";
    }
    
    double getCost() const override {
        return coffee_->getCost() + 0.2;
    }
};

// 使用
void example() {
    std::unique_ptr<Coffee> coffee = std::make_unique<SimpleCoffee>();
    coffee = std::make_unique<MilkDecorator>(std::move(coffee));
    coffee = std::make_unique<SugarDecorator>(std::move(coffee));
    
    std::cout << coffee->getDescription() << std::endl;
    std::cout << "Cost: $" << coffee->getCost() << std::endl;
}
```

### 3.3 代理模式

```cpp
#include <memory>
#include <iostream>

// 主题接口
class Image {
public:
    virtual ~Image() = default;
    virtual void display() = 0;
};

// 真实主题
class RealImage : public Image {
public:
    RealImage(const std::string& filename) : filename_(filename) {
        loadFromDisk();
    }
    
    void display() override {
        std::cout << "Displaying " << filename_ << std::endl;
    }

private:
    void loadFromDisk() {
        std::cout << "Loading " << filename_ << " from disk" << std::endl;
    }
    
    std::string filename_;
};

// 代理 (延迟加载)
class ImageProxy : public Image {
public:
    ImageProxy(const std::string& filename) : filename_(filename) { }
    
    void display() override {
        if (!realImage_) {
            realImage_ = std::make_unique<RealImage>(filename_);
        }
        realImage_->display();
    }

private:
    std::string filename_;
    std::unique_ptr<RealImage> realImage_;
};

// 保护代理
class ProtectedImageProxy : public Image {
public:
    ProtectedImageProxy(std::unique_ptr<Image> image, bool hasAccess)
        : image_(std::move(image)), hasAccess_(hasAccess) { }
    
    void display() override {
        if (hasAccess_) {
            image_->display();
        } else {
            std::cout << "Access denied" << std::endl;
        }
    }

private:
    std::unique_ptr<Image> image_;
    bool hasAccess_;
};

// 使用
void example() {
    // 延迟加载
    auto image = std::make_unique<ImageProxy>("photo.jpg");
    // 图片还未加载
    image->display();  // 现在加载
    image->display();  // 使用缓存
}
```

---

## 4. 行为型模式

### 4.1 观察者模式

```cpp
#include <vector>
#include <memory>
#include <algorithm>
#include <functional>

// 观察者接口
class Observer {
public:
    virtual ~Observer() = default;
    virtual void update(int value) = 0;
};

// 主题
class Subject {
public:
    void attach(std::shared_ptr<Observer> observer) {
        observers_.push_back(observer);
    }
    
    void detach(std::shared_ptr<Observer> observer) {
        observers_.erase(
            std::remove_if(observers_.begin(), observers_.end(),
                [&](const std::weak_ptr<Observer>& wp) {
                    auto sp = wp.lock();
                    return !sp || sp == observer;
                }),
            observers_.end()
        );
    }
    
    void notify() {
        for (auto& wp : observers_) {
            if (auto sp = wp.lock()) {
                sp->update(value_);
            }
        }
    }
    
    void setValue(int value) {
        value_ = value;
        notify();
    }

private:
    std::vector<std::weak_ptr<Observer>> observers_;
    int value_ = 0;
};

// 具体观察者
class ConcreteObserver : public Observer {
public:
    ConcreteObserver(const std::string& name) : name_(name) { }
    
    void update(int value) override {
        std::cout << name_ << " received: " << value << std::endl;
    }

private:
    std::string name_;
};

// 函数式观察者
class FunctionObserver : public Observer {
public:
    using Callback = std::function<void(int)>;
    
    FunctionObserver(Callback callback) : callback_(std::move(callback)) { }
    
    void update(int value) override {
        callback_(value);
    }

private:
    Callback callback_;
};

// 使用
void example() {
    Subject subject;
    
    auto observer1 = std::make_shared<ConcreteObserver>("Observer1");
    auto observer2 = std::make_shared<FunctionObserver>([](int v) {
        std::cout << "Lambda received: " << v << std::endl;
    });
    
    subject.attach(observer1);
    subject.attach(observer2);
    
    subject.setValue(42);
}
```

### 4.2 策略模式

```cpp
#include <memory>
#include <functional>

// 策略接口
class SortStrategy {
public:
    virtual ~SortStrategy() = default;
    virtual void sort(std::vector<int>& data) = 0;
};

// 具体策略
class QuickSort : public SortStrategy {
public:
    void sort(std::vector<int>& data) override {
        std::sort(data.begin(), data.end());
        std::cout << "Quick sorted" << std::endl;
    }
};

class BubbleSort : public SortStrategy {
public:
    void sort(std::vector<int>& data) override {
        for (size_t i = 0; i < data.size(); ++i) {
            for (size_t j = 0; j < data.size() - i - 1; ++j) {
                if (data[j] > data[j + 1]) {
                    std::swap(data[j], data[j + 1]);
                }
            }
        }
        std::cout << "Bubble sorted" << std::endl;
    }
};

// 上下文
class Sorter {
public:
    void setStrategy(std::unique_ptr<SortStrategy> strategy) {
        strategy_ = std::move(strategy);
    }
    
    void sort(std::vector<int>& data) {
        if (strategy_) {
            strategy_->sort(data);
        }
    }

private:
    std::unique_ptr<SortStrategy> strategy_;
};

// 函数式策略
class FunctionalSorter {
public:
    using Strategy = std::function<void(std::vector<int>&)>;
    
    void setStrategy(Strategy strategy) {
        strategy_ = std::move(strategy);
    }
    
    void sort(std::vector<int>& data) {
        if (strategy_) {
            strategy_(data);
        }
    }

private:
    Strategy strategy_;
};

// 使用
void example() {
    Sorter sorter;
    std::vector<int> data = {5, 2, 8, 1, 9};
    
    sorter.setStrategy(std::make_unique<QuickSort>());
    sorter.sort(data);
    
    // 函数式
    FunctionalSorter fsorter;
    fsorter.setStrategy([](std::vector<int>& d) {
        std::sort(d.begin(), d.end(), std::greater<int>());
    });
    fsorter.sort(data);
}
```

### 4.3 命令模式

```cpp
#include <memory>
#include <vector>
#include <stack>

// 命令接口
class Command {
public:
    virtual ~Command() = default;
    virtual void execute() = 0;
    virtual void undo() = 0;
};

// 接收者
class TextEditor {
public:
    void insertText(const std::string& text, size_t pos) {
        content_.insert(pos, text);
    }
    
    void deleteText(size_t pos, size_t len) {
        content_.erase(pos, len);
    }
    
    const std::string& getContent() const { return content_; }

private:
    std::string content_;
};

// 具体命令
class InsertCommand : public Command {
public:
    InsertCommand(TextEditor& editor, const std::string& text, size_t pos)
        : editor_(editor), text_(text), pos_(pos) { }
    
    void execute() override {
        editor_.insertText(text_, pos_);
    }
    
    void undo() override {
        editor_.deleteText(pos_, text_.length());
    }

private:
    TextEditor& editor_;
    std::string text_;
    size_t pos_;
};

// 命令管理器
class CommandManager {
public:
    void execute(std::unique_ptr<Command> command) {
        command->execute();
        undoStack_.push(std::move(command));
        // 清空 redo 栈
        while (!redoStack_.empty()) redoStack_.pop();
    }
    
    void undo() {
        if (!undoStack_.empty()) {
            auto command = std::move(undoStack_.top());
            undoStack_.pop();
            command->undo();
            redoStack_.push(std::move(command));
        }
    }
    
    void redo() {
        if (!redoStack_.empty()) {
            auto command = std::move(redoStack_.top());
            redoStack_.pop();
            command->execute();
            undoStack_.push(std::move(command));
        }
    }

private:
    std::stack<std::unique_ptr<Command>> undoStack_;
    std::stack<std::unique_ptr<Command>> redoStack_;
};

// 使用
void example() {
    TextEditor editor;
    CommandManager manager;
    
    manager.execute(std::make_unique<InsertCommand>(editor, "Hello", 0));
    manager.execute(std::make_unique<InsertCommand>(editor, " World", 5));
    
    std::cout << editor.getContent() << std::endl;  // "Hello World"
    
    manager.undo();
    std::cout << editor.getContent() << std::endl;  // "Hello"
    
    manager.redo();
    std::cout << editor.getContent() << std::endl;  // "Hello World"
}
```

---

## 5. 现代 C++ 模式

### 5.1 CRTP (奇异递归模板模式)

```cpp
// 静态多态
template<typename Derived>
class Base {
public:
    void interface() {
        static_cast<Derived*>(this)->implementation();
    }
    
    void implementation() {
        std::cout << "Base implementation" << std::endl;
    }
};

class Derived : public Base<Derived> {
public:
    void implementation() {
        std::cout << "Derived implementation" << std::endl;
    }
};

// 计数器
template<typename T>
class Counter {
public:
    Counter() { ++count_; }
    Counter(const Counter&) { ++count_; }
    ~Counter() { --count_; }
    
    static int getCount() { return count_; }

private:
    static inline int count_ = 0;
};

class MyClass : public Counter<MyClass> { };
class OtherClass : public Counter<OtherClass> { };
```

### 5.2 类型擦除

```cpp
#include <memory>
#include <functional>

// 简单类型擦除
class AnyCallable {
public:
    template<typename F>
    AnyCallable(F f) : impl_(std::make_unique<Model<F>>(std::move(f))) { }
    
    void operator()() {
        impl_->call();
    }

private:
    struct Concept {
        virtual ~Concept() = default;
        virtual void call() = 0;
    };
    
    template<typename F>
    struct Model : Concept {
        Model(F f) : f_(std::move(f)) { }
        void call() override { f_(); }
        F f_;
    };
    
    std::unique_ptr<Concept> impl_;
};

// 使用
void example() {
    AnyCallable c1([]() { std::cout << "Lambda" << std::endl; });
    AnyCallable c2(std::function<void()>([]() { std::cout << "Function" << std::endl; }));
    
    c1();
    c2();
}
```

### 5.3 Policy-Based Design

```cpp
// 策略类
struct NoLocking {
    void lock() { }
    void unlock() { }
};

struct MutexLocking {
    void lock() { mutex_.lock(); }
    void unlock() { mutex_.unlock(); }
private:
    std::mutex mutex_;
};

template<typename T>
struct DefaultCreation {
    static T* create() { return new T(); }
    static void destroy(T* p) { delete p; }
};

template<typename T>
struct PoolCreation {
    static T* create() { /* 从池中获取 */ return new T(); }
    static void destroy(T* p) { /* 返回池中 */ delete p; }
};

// 使用策略组合
template<typename T, 
         typename LockingPolicy = NoLocking,
         typename CreationPolicy = DefaultCreation<T>>
class SmartPointer : private LockingPolicy {
public:
    SmartPointer() : ptr_(CreationPolicy::create()) { }
    
    ~SmartPointer() {
        CreationPolicy::destroy(ptr_);
    }
    
    T* operator->() {
        this->lock();
        return ptr_;
    }
    
    void release() {
        this->unlock();
    }

private:
    T* ptr_;
};

// 使用
void example() {
    SmartPointer<int, MutexLocking> threadSafePtr;
    SmartPointer<int, NoLocking, PoolCreation<int>> pooledPtr;
}
```

---

## 6. 总结

### 6.1 模式分类

| 类型 | 模式 | 用途 |
|------|------|------|
| 创建型 | 单例、工厂、建造者 | 对象创建 |
| 结构型 | 适配器、装饰器、代理 | 类组合 |
| 行为型 | 观察者、策略、命令 | 对象通信 |

### 6.2 选择建议

```
1. 不要过度使用模式
2. 优先使用简单方案
3. 理解问题再选择模式
4. 结合现代 C++ 特性
5. 考虑性能影响
```

### 6.3 Part 9 完成

恭喜你完成了工程实践部分的全部 4 篇文章!

**实战项目建议**: 插件系统
- 使用工厂模式加载插件
- 使用观察者模式通信
- 使用策略模式配置

### 6.4 下一篇预告

在下一篇文章中,我们将进入项目实战部分,实现一个 JSON 解析器。

---

> 作者: C++ 技术专栏  
> 系列: 工程实践 (4/4)  
> 上一篇: [代码规范与静态分析](./57-code-style.md)  
> 下一篇: [JSON 解析器](../part10-projects/59-json-parser.md)
