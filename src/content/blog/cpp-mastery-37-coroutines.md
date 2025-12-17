---
title: "协程"
description: "1. [协程概述](#1-协程概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 37
---

> 本文是 C++ 从入门到精通系列的第三十七篇,将深入讲解 C++20 引入的协程 (Coroutines)。

---

## 目录

1. [协程概述](#1-协程概述)
2. [协程基础](#2-协程基础)
3. [Generator](#3-generator)
4. [异步任务](#4-异步任务)
5. [协程原理](#5-协程原理)
6. [实际应用](#6-实际应用)
7. [总结](#7-总结)

---

## 1. 协程概述

### 1.1 什么是协程

```
协程 vs 函数:

普通函数:
- 调用时执行到完成
- 只有一个入口点
- 返回后状态丢失

协程:
- 可以暂停和恢复
- 多个挂起点
- 保持状态

协程 vs 线程:
- 协程是协作式的
- 线程是抢占式的
- 协程更轻量
- 协程无需同步
```

### 1.2 C++20 协程关键字

```cpp
// co_await: 暂停协程,等待操作完成
// co_yield: 产生一个值并暂停
// co_return: 完成协程并返回值

// 示例 (概念性代码)
/*
Task<int> asyncOperation() {
    int result = co_await someAsyncCall();
    co_return result;
}

Generator<int> generateNumbers() {
    for (int i = 0; i < 10; ++i) {
        co_yield i;
    }
}
*/
```

---

## 2. 协程基础

### 2.1 协程框架

```cpp
#include <iostream>
#include <coroutine>

// 简单的协程返回类型
struct SimpleCoroutine {
    struct promise_type {
        SimpleCoroutine get_return_object() {
            return SimpleCoroutine{
                std::coroutine_handle<promise_type>::from_promise(*this)
            };
        }
        
        std::suspend_never initial_suspend() { return {}; }
        std::suspend_always final_suspend() noexcept { return {}; }
        void return_void() { }
        void unhandled_exception() { std::terminate(); }
    };
    
    std::coroutine_handle<promise_type> handle;
    
    ~SimpleCoroutine() {
        if (handle) handle.destroy();
    }
};

SimpleCoroutine simpleCoroutine() {
    std::cout << "Hello from coroutine!" << std::endl;
    co_return;
}

int main() {
    auto coro = simpleCoroutine();
    std::cout << "Coroutine created" << std::endl;
    
    return 0;
}
```

### 2.2 挂起和恢复

```cpp
#include <iostream>
#include <coroutine>

struct SuspendableCoroutine {
    struct promise_type {
        SuspendableCoroutine get_return_object() {
            return SuspendableCoroutine{
                std::coroutine_handle<promise_type>::from_promise(*this)
            };
        }
        
        std::suspend_always initial_suspend() { return {}; }
        std::suspend_always final_suspend() noexcept { return {}; }
        void return_void() { }
        void unhandled_exception() { std::terminate(); }
    };
    
    std::coroutine_handle<promise_type> handle;
    
    void resume() {
        if (handle && !handle.done()) {
            handle.resume();
        }
    }
    
    bool done() const {
        return handle.done();
    }
    
    ~SuspendableCoroutine() {
        if (handle) handle.destroy();
    }
};

SuspendableCoroutine counter() {
    std::cout << "Counter: 1" << std::endl;
    co_await std::suspend_always{};
    
    std::cout << "Counter: 2" << std::endl;
    co_await std::suspend_always{};
    
    std::cout << "Counter: 3" << std::endl;
}

int main() {
    auto coro = counter();
    
    std::cout << "Starting..." << std::endl;
    
    while (!coro.done()) {
        std::cout << "Resuming coroutine" << std::endl;
        coro.resume();
    }
    
    std::cout << "Done!" << std::endl;
    
    return 0;
}
```

---

## 3. Generator

### 3.1 简单 Generator

```cpp
#include <iostream>
#include <coroutine>
#include <optional>

template<typename T>
class Generator {
public:
    struct promise_type {
        T current_value;
        
        Generator get_return_object() {
            return Generator{
                std::coroutine_handle<promise_type>::from_promise(*this)
            };
        }
        
        std::suspend_always initial_suspend() { return {}; }
        std::suspend_always final_suspend() noexcept { return {}; }
        
        std::suspend_always yield_value(T value) {
            current_value = value;
            return {};
        }
        
        void return_void() { }
        void unhandled_exception() { std::terminate(); }
    };
    
    struct Iterator {
        std::coroutine_handle<promise_type> handle;
        
        Iterator& operator++() {
            handle.resume();
            return *this;
        }
        
        T operator*() const {
            return handle.promise().current_value;
        }
        
        bool operator!=(std::default_sentinel_t) const {
            return !handle.done();
        }
    };
    
    Iterator begin() {
        handle.resume();
        return Iterator{handle};
    }
    
    std::default_sentinel_t end() {
        return {};
    }
    
    Generator(std::coroutine_handle<promise_type> h) : handle(h) { }
    
    ~Generator() {
        if (handle) handle.destroy();
    }
    
    Generator(const Generator&) = delete;
    Generator& operator=(const Generator&) = delete;
    
    Generator(Generator&& other) noexcept : handle(other.handle) {
        other.handle = nullptr;
    }

private:
    std::coroutine_handle<promise_type> handle;
};

Generator<int> range(int start, int end) {
    for (int i = start; i < end; ++i) {
        co_yield i;
    }
}

Generator<int> fibonacci(int n) {
    int a = 0, b = 1;
    for (int i = 0; i < n; ++i) {
        co_yield a;
        int temp = a;
        a = b;
        b = temp + b;
    }
}

int main() {
    std::cout << "Range: ";
    for (int x : range(1, 10)) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    std::cout << "Fibonacci: ";
    for (int x : fibonacci(10)) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

### 3.2 无限 Generator

```cpp
#include <iostream>
#include <coroutine>

template<typename T>
class InfiniteGenerator {
public:
    struct promise_type {
        T current_value;
        
        InfiniteGenerator get_return_object() {
            return InfiniteGenerator{
                std::coroutine_handle<promise_type>::from_promise(*this)
            };
        }
        
        std::suspend_always initial_suspend() { return {}; }
        std::suspend_always final_suspend() noexcept { return {}; }
        
        std::suspend_always yield_value(T value) {
            current_value = value;
            return {};
        }
        
        void return_void() { }
        void unhandled_exception() { std::terminate(); }
    };
    
    std::optional<T> next() {
        if (handle.done()) return std::nullopt;
        handle.resume();
        if (handle.done()) return std::nullopt;
        return handle.promise().current_value;
    }
    
    InfiniteGenerator(std::coroutine_handle<promise_type> h) : handle(h) { }
    
    ~InfiniteGenerator() {
        if (handle) handle.destroy();
    }

private:
    std::coroutine_handle<promise_type> handle;
};

InfiniteGenerator<int> naturalNumbers() {
    int n = 0;
    while (true) {
        co_yield n++;
    }
}

InfiniteGenerator<int> primes() {
    auto isPrime = [](int n) {
        if (n < 2) return false;
        for (int i = 2; i * i <= n; ++i) {
            if (n % i == 0) return false;
        }
        return true;
    };
    
    int n = 2;
    while (true) {
        if (isPrime(n)) {
            co_yield n;
        }
        ++n;
    }
}

int main() {
    auto gen = naturalNumbers();
    std::cout << "First 10 natural numbers: ";
    for (int i = 0; i < 10; ++i) {
        if (auto val = gen.next()) {
            std::cout << *val << " ";
        }
    }
    std::cout << std::endl;
    
    auto primeGen = primes();
    std::cout << "First 10 primes: ";
    for (int i = 0; i < 10; ++i) {
        if (auto val = primeGen.next()) {
            std::cout << *val << " ";
        }
    }
    std::cout << std::endl;
    
    return 0;
}
```

---

## 4. 异步任务

### 4.1 简单 Task

```cpp
#include <iostream>
#include <coroutine>
#include <optional>

template<typename T>
class Task {
public:
    struct promise_type {
        std::optional<T> result;
        std::exception_ptr exception;
        
        Task get_return_object() {
            return Task{
                std::coroutine_handle<promise_type>::from_promise(*this)
            };
        }
        
        std::suspend_never initial_suspend() { return {}; }
        std::suspend_always final_suspend() noexcept { return {}; }
        
        void return_value(T value) {
            result = value;
        }
        
        void unhandled_exception() {
            exception = std::current_exception();
        }
    };
    
    T get() {
        if (handle.promise().exception) {
            std::rethrow_exception(handle.promise().exception);
        }
        return *handle.promise().result;
    }
    
    bool done() const {
        return handle.done();
    }
    
    Task(std::coroutine_handle<promise_type> h) : handle(h) { }
    
    ~Task() {
        if (handle) handle.destroy();
    }

private:
    std::coroutine_handle<promise_type> handle;
};

Task<int> computeAsync() {
    std::cout << "Starting computation..." << std::endl;
    // 模拟异步操作
    co_return 42;
}

int main() {
    auto task = computeAsync();
    std::cout << "Task created" << std::endl;
    std::cout << "Result: " << task.get() << std::endl;
    
    return 0;
}
```

### 4.2 可等待对象

```cpp
#include <iostream>
#include <coroutine>
#include <thread>
#include <chrono>

// 自定义 awaitable
struct SleepAwaiter {
    std::chrono::milliseconds duration;
    
    bool await_ready() const noexcept {
        return duration.count() <= 0;
    }
    
    void await_suspend(std::coroutine_handle<> handle) const {
        std::thread([handle, this]() {
            std::this_thread::sleep_for(duration);
            handle.resume();
        }).detach();
    }
    
    void await_resume() const noexcept { }
};

auto sleep_for(std::chrono::milliseconds ms) {
    return SleepAwaiter{ms};
}

struct AsyncTask {
    struct promise_type {
        AsyncTask get_return_object() {
            return AsyncTask{
                std::coroutine_handle<promise_type>::from_promise(*this)
            };
        }
        
        std::suspend_never initial_suspend() { return {}; }
        std::suspend_always final_suspend() noexcept { return {}; }
        void return_void() { }
        void unhandled_exception() { std::terminate(); }
    };
    
    std::coroutine_handle<promise_type> handle;
    
    bool done() const { return handle.done(); }
    
    ~AsyncTask() {
        if (handle) handle.destroy();
    }
};

AsyncTask asyncExample() {
    std::cout << "Start" << std::endl;
    
    co_await sleep_for(std::chrono::milliseconds(100));
    std::cout << "After 100ms" << std::endl;
    
    co_await sleep_for(std::chrono::milliseconds(200));
    std::cout << "After 200ms more" << std::endl;
    
    std::cout << "Done" << std::endl;
}

int main() {
    auto task = asyncExample();
    
    // 等待任务完成
    while (!task.done()) {
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }
    
    return 0;
}
```

---

## 5. 协程原理

### 5.1 协程状态

```
协程状态机:

1. 创建: 分配协程帧
2. 初始挂起: initial_suspend
3. 执行: 运行协程体
4. 挂起: co_await/co_yield
5. 恢复: resume()
6. 完成: co_return
7. 最终挂起: final_suspend
8. 销毁: 释放协程帧

协程帧包含:
- promise 对象
- 函数参数副本
- 局部变量
- 挂起点信息
```

### 5.2 promise_type

```cpp
#include <iostream>
#include <coroutine>

struct DetailedPromise {
    struct promise_type {
        int value = 0;
        
        // 获取返回对象
        DetailedPromise get_return_object() {
            std::cout << "get_return_object()" << std::endl;
            return DetailedPromise{
                std::coroutine_handle<promise_type>::from_promise(*this)
            };
        }
        
        // 初始挂起点
        std::suspend_always initial_suspend() {
            std::cout << "initial_suspend()" << std::endl;
            return {};
        }
        
        // 最终挂起点
        std::suspend_always final_suspend() noexcept {
            std::cout << "final_suspend()" << std::endl;
            return {};
        }
        
        // co_return value
        void return_value(int v) {
            std::cout << "return_value(" << v << ")" << std::endl;
            value = v;
        }
        
        // co_yield value
        std::suspend_always yield_value(int v) {
            std::cout << "yield_value(" << v << ")" << std::endl;
            value = v;
            return {};
        }
        
        // 异常处理
        void unhandled_exception() {
            std::cout << "unhandled_exception()" << std::endl;
            std::terminate();
        }
    };
    
    std::coroutine_handle<promise_type> handle;
    
    int getValue() const {
        return handle.promise().value;
    }
    
    void resume() {
        if (!handle.done()) {
            handle.resume();
        }
    }
    
    bool done() const {
        return handle.done();
    }
    
    ~DetailedPromise() {
        if (handle) handle.destroy();
    }
};

DetailedPromise detailedCoroutine() {
    std::cout << "Coroutine body start" << std::endl;
    
    co_yield 1;
    std::cout << "After first yield" << std::endl;
    
    co_yield 2;
    std::cout << "After second yield" << std::endl;
    
    co_return 3;
}

int main() {
    std::cout << "=== Creating coroutine ===" << std::endl;
    auto coro = detailedCoroutine();
    
    std::cout << "\n=== First resume ===" << std::endl;
    coro.resume();
    std::cout << "Value: " << coro.getValue() << std::endl;
    
    std::cout << "\n=== Second resume ===" << std::endl;
    coro.resume();
    std::cout << "Value: " << coro.getValue() << std::endl;
    
    std::cout << "\n=== Third resume ===" << std::endl;
    coro.resume();
    std::cout << "Value: " << coro.getValue() << std::endl;
    
    std::cout << "\n=== Destroying ===" << std::endl;
    
    return 0;
}
```

### 5.3 Awaitable 接口

```cpp
#include <iostream>
#include <coroutine>

// Awaitable 必须实现三个方法
struct CustomAwaitable {
    int value;
    
    // 是否需要挂起
    bool await_ready() const noexcept {
        std::cout << "await_ready()" << std::endl;
        return false;  // true = 不挂起
    }
    
    // 挂起时调用
    void await_suspend(std::coroutine_handle<> handle) const {
        std::cout << "await_suspend()" << std::endl;
        // 可以存储 handle 以便稍后恢复
        // 这里立即恢复
        handle.resume();
    }
    
    // 恢复后返回值
    int await_resume() const noexcept {
        std::cout << "await_resume()" << std::endl;
        return value;
    }
};

struct SimpleTask {
    struct promise_type {
        SimpleTask get_return_object() {
            return SimpleTask{
                std::coroutine_handle<promise_type>::from_promise(*this)
            };
        }
        std::suspend_never initial_suspend() { return {}; }
        std::suspend_always final_suspend() noexcept { return {}; }
        void return_void() { }
        void unhandled_exception() { std::terminate(); }
    };
    
    std::coroutine_handle<promise_type> handle;
    
    ~SimpleTask() {
        if (handle) handle.destroy();
    }
};

SimpleTask testAwaitable() {
    std::cout << "Before co_await" << std::endl;
    int result = co_await CustomAwaitable{42};
    std::cout << "After co_await, result: " << result << std::endl;
}

int main() {
    auto task = testAwaitable();
    return 0;
}
```

---

## 6. 实际应用

### 6.1 异步文件读取 (概念)

```cpp
#include <iostream>
#include <coroutine>
#include <string>
#include <fstream>

// 概念性代码,展示异步文件读取的协程设计

template<typename T>
struct AsyncResult {
    struct promise_type {
        T result;
        
        AsyncResult get_return_object() {
            return AsyncResult{
                std::coroutine_handle<promise_type>::from_promise(*this)
            };
        }
        
        std::suspend_never initial_suspend() { return {}; }
        std::suspend_always final_suspend() noexcept { return {}; }
        
        void return_value(T value) {
            result = std::move(value);
        }
        
        void unhandled_exception() { std::terminate(); }
    };
    
    std::coroutine_handle<promise_type> handle;
    
    T get() { return handle.promise().result; }
    
    ~AsyncResult() {
        if (handle) handle.destroy();
    }
};

// 模拟异步文件读取
AsyncResult<std::string> readFileAsync(const std::string& filename) {
    // 在实际应用中,这里会使用异步 I/O
    std::ifstream file(filename);
    std::string content;
    
    if (file) {
        std::string line;
        while (std::getline(file, line)) {
            content += line + "\n";
        }
    }
    
    co_return content;
}

int main() {
    // 创建测试文件
    {
        std::ofstream file("test.txt");
        file << "Hello, Coroutines!\nThis is a test file.";
    }
    
    auto result = readFileAsync("test.txt");
    std::cout << "File content:\n" << result.get() << std::endl;
    
    // 清理
    std::remove("test.txt");
    
    return 0;
}
```

### 6.2 状态机

```cpp
#include <iostream>
#include <coroutine>
#include <string>

template<typename T>
class StateMachine {
public:
    struct promise_type {
        T current_state;
        
        StateMachine get_return_object() {
            return StateMachine{
                std::coroutine_handle<promise_type>::from_promise(*this)
            };
        }
        
        std::suspend_always initial_suspend() { return {}; }
        std::suspend_always final_suspend() noexcept { return {}; }
        
        std::suspend_always yield_value(T state) {
            current_state = state;
            return {};
        }
        
        void return_void() { }
        void unhandled_exception() { std::terminate(); }
    };
    
    T currentState() const {
        return handle.promise().current_state;
    }
    
    void advance() {
        if (!handle.done()) {
            handle.resume();
        }
    }
    
    bool done() const {
        return handle.done();
    }
    
    StateMachine(std::coroutine_handle<promise_type> h) : handle(h) { }
    
    ~StateMachine() {
        if (handle) handle.destroy();
    }

private:
    std::coroutine_handle<promise_type> handle;
};

enum class TrafficLight { Red, Yellow, Green };

std::ostream& operator<<(std::ostream& os, TrafficLight light) {
    switch (light) {
        case TrafficLight::Red: return os << "Red";
        case TrafficLight::Yellow: return os << "Yellow";
        case TrafficLight::Green: return os << "Green";
    }
    return os;
}

StateMachine<TrafficLight> trafficLightCycle() {
    while (true) {
        co_yield TrafficLight::Red;
        co_yield TrafficLight::Green;
        co_yield TrafficLight::Yellow;
    }
}

int main() {
    auto light = trafficLightCycle();
    
    for (int i = 0; i < 9; ++i) {
        light.advance();
        std::cout << "Light: " << light.currentState() << std::endl;
    }
    
    return 0;
}
```

---

## 7. 总结

### 7.1 协程关键字

| 关键字 | 功能 |
|--------|------|
| co_await | 暂停并等待 |
| co_yield | 产生值并暂停 |
| co_return | 完成协程 |

### 7.2 核心组件

| 组件 | 说明 |
|------|------|
| promise_type | 控制协程行为 |
| coroutine_handle | 协程句柄 |
| Awaitable | 可等待对象 |

### 7.3 最佳实践

```
1. 使用库提供的协程类型
2. 注意协程生命周期
3. 正确处理异常
4. 避免在协程中使用引用
5. 考虑使用 cppcoro 等库
```

### 7.4 下一篇预告

在下一篇文章中,我们将学习 Modules。

---

> 作者: C++ 技术专栏  
> 系列: 现代 C++ (7/10)  
> 上一篇: [Ranges 库](./36-ranges.md)  
> 下一篇: [Modules](./38-modules.md)
