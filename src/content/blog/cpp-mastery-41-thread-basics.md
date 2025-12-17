---
title: "线程基础"
description: "1. [多线程概述](#1-多线程概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 41
---

> 本文是 C++ 从入门到精通系列的第四十一篇,将深入讲解 C++ 多线程编程的基础知识。

---

## 目录

1. [多线程概述](#1-多线程概述)
2. [std::thread](#2-stdthread)
3. [线程管理](#3-线程管理)
4. [线程参数传递](#4-线程参数传递)
5. [线程本地存储](#5-线程本地存储)
6. [总结](#6-总结)

---

## 1. 多线程概述

### 1.1 并发与并行

```
并发 (Concurrency):
- 多个任务交替执行
- 可以在单核 CPU 上实现
- 通过时间片轮转

并行 (Parallelism):
- 多个任务同时执行
- 需要多核 CPU
- 真正的同时运行

C++ 线程支持:
- C++11 引入 <thread>
- 跨平台的线程抽象
- 与操作系统线程一一对应
```

### 1.2 线程 vs 进程

```
进程:
- 独立的地址空间
- 资源隔离
- 创建开销大
- 通信复杂

线程:
- 共享地址空间
- 轻量级
- 创建开销小
- 通信简单但需同步
```

---

## 2. std::thread

### 2.1 创建线程

```cpp
#include <iostream>
#include <thread>

// 普通函数
void hello() {
    std::cout << "Hello from thread!" << std::endl;
}

// 带参数的函数
void greet(const std::string& name) {
    std::cout << "Hello, " << name << "!" << std::endl;
}

// 函数对象
class Task {
public:
    void operator()() const {
        std::cout << "Task running in thread" << std::endl;
    }
};

int main() {
    // 使用普通函数
    std::thread t1(hello);
    t1.join();
    
    // 使用带参数的函数
    std::thread t2(greet, "World");
    t2.join();
    
    // 使用函数对象
    Task task;
    std::thread t3(task);
    t3.join();
    
    // 使用 lambda
    std::thread t4([]() {
        std::cout << "Lambda in thread" << std::endl;
    });
    t4.join();
    
    return 0;
}
```

### 2.2 线程标识

```cpp
#include <iostream>
#include <thread>

void printThreadId() {
    std::cout << "Thread ID: " << std::this_thread::get_id() << std::endl;
}

int main() {
    std::cout << "Main thread ID: " << std::this_thread::get_id() << std::endl;
    
    std::thread t1(printThreadId);
    std::thread t2(printThreadId);
    
    std::cout << "t1 ID: " << t1.get_id() << std::endl;
    std::cout << "t2 ID: " << t2.get_id() << std::endl;
    
    t1.join();
    t2.join();
    
    // 硬件并发数
    std::cout << "Hardware concurrency: " 
              << std::thread::hardware_concurrency() << std::endl;
    
    return 0;
}
```

---

## 3. 线程管理

### 3.1 join 和 detach

```cpp
#include <iostream>
#include <thread>
#include <chrono>

void longTask() {
    std::cout << "Long task started" << std::endl;
    std::this_thread::sleep_for(std::chrono::seconds(2));
    std::cout << "Long task finished" << std::endl;
}

void backgroundTask() {
    std::cout << "Background task started" << std::endl;
    std::this_thread::sleep_for(std::chrono::seconds(1));
    std::cout << "Background task finished" << std::endl;
}

int main() {
    // join: 等待线程完成
    std::thread t1(longTask);
    std::cout << "Waiting for t1..." << std::endl;
    t1.join();
    std::cout << "t1 joined" << std::endl;
    
    // detach: 分离线程
    std::thread t2(backgroundTask);
    t2.detach();
    std::cout << "t2 detached" << std::endl;
    
    // 检查是否可 join
    std::thread t3(longTask);
    if (t3.joinable()) {
        std::cout << "t3 is joinable" << std::endl;
        t3.join();
    }
    
    // 等待分离的线程完成 (仅用于演示)
    std::this_thread::sleep_for(std::chrono::seconds(2));
    
    return 0;
}
```

### 3.2 RAII 线程管理

```cpp
#include <iostream>
#include <thread>

// RAII 线程包装器
class ThreadGuard {
public:
    explicit ThreadGuard(std::thread& t) : thread(t) { }
    
    ~ThreadGuard() {
        if (thread.joinable()) {
            thread.join();
        }
    }
    
    ThreadGuard(const ThreadGuard&) = delete;
    ThreadGuard& operator=(const ThreadGuard&) = delete;

private:
    std::thread& thread;
};

// 更好的方式: 使用 jthread (C++20)
void demonstrateJthread() {
    std::jthread t([]() {
        std::cout << "jthread automatically joins" << std::endl;
    });
    // 不需要显式 join,析构时自动 join
}

void riskyFunction() {
    std::thread t([]() {
        std::cout << "Risky thread" << std::endl;
    });
    
    ThreadGuard guard(t);
    
    // 即使抛出异常,线程也会被正确 join
    // throw std::runtime_error("Error!");
}

int main() {
    riskyFunction();
    demonstrateJthread();
    
    return 0;
}
```

### 3.3 线程休眠和让步

```cpp
#include <iostream>
#include <thread>
#include <chrono>

int main() {
    // sleep_for: 休眠指定时间
    std::cout << "Sleeping for 1 second..." << std::endl;
    std::this_thread::sleep_for(std::chrono::seconds(1));
    std::cout << "Woke up!" << std::endl;
    
    // sleep_until: 休眠到指定时间点
    auto wakeTime = std::chrono::steady_clock::now() + std::chrono::milliseconds(500);
    std::cout << "Sleeping until..." << std::endl;
    std::this_thread::sleep_until(wakeTime);
    std::cout << "Woke up!" << std::endl;
    
    // yield: 让出 CPU
    for (int i = 0; i < 5; ++i) {
        std::cout << "Working... " << i << std::endl;
        std::this_thread::yield();  // 让其他线程有机会运行
    }
    
    return 0;
}
```

---

## 4. 线程参数传递

### 4.1 值传递

```cpp
#include <iostream>
#include <thread>
#include <string>

void printValue(int x) {
    std::cout << "Value: " << x << std::endl;
}

void printString(std::string s) {
    std::cout << "String: " << s << std::endl;
}

int main() {
    int value = 42;
    std::string str = "Hello";
    
    // 值传递
    std::thread t1(printValue, value);
    std::thread t2(printString, str);
    
    t1.join();
    t2.join();
    
    // 原始值不受影响
    std::cout << "Original value: " << value << std::endl;
    std::cout << "Original string: " << str << std::endl;
    
    return 0;
}
```

### 4.2 引用传递

```cpp
#include <iostream>
#include <thread>
#include <functional>

void increment(int& x) {
    ++x;
    std::cout << "Incremented to: " << x << std::endl;
}

void modify(std::string& s) {
    s += " World";
}

int main() {
    int value = 42;
    std::string str = "Hello";
    
    // 使用 std::ref 传递引用
    std::thread t1(increment, std::ref(value));
    std::thread t2(modify, std::ref(str));
    
    t1.join();
    t2.join();
    
    std::cout << "Modified value: " << value << std::endl;
    std::cout << "Modified string: " << str << std::endl;
    
    return 0;
}
```

### 4.3 移动语义

```cpp
#include <iostream>
#include <thread>
#include <memory>
#include <vector>

void processUnique(std::unique_ptr<int> ptr) {
    std::cout << "Processing: " << *ptr << std::endl;
}

void processVector(std::vector<int> vec) {
    std::cout << "Vector size: " << vec.size() << std::endl;
}

int main() {
    // 移动 unique_ptr
    auto ptr = std::make_unique<int>(42);
    std::thread t1(processUnique, std::move(ptr));
    t1.join();
    // ptr 现在为空
    
    // 移动 vector
    std::vector<int> vec = {1, 2, 3, 4, 5};
    std::thread t2(processVector, std::move(vec));
    t2.join();
    // vec 现在为空
    
    return 0;
}
```

### 4.4 成员函数

```cpp
#include <iostream>
#include <thread>

class Worker {
public:
    Worker(int id) : id(id) { }
    
    void doWork() {
        std::cout << "Worker " << id << " working" << std::endl;
    }
    
    void doWorkWithParam(int value) {
        std::cout << "Worker " << id << " processing " << value << std::endl;
    }

private:
    int id;
};

int main() {
    Worker worker(1);
    
    // 调用成员函数
    std::thread t1(&Worker::doWork, &worker);
    std::thread t2(&Worker::doWorkWithParam, &worker, 42);
    
    t1.join();
    t2.join();
    
    // 使用 shared_ptr
    auto sharedWorker = std::make_shared<Worker>(2);
    std::thread t3(&Worker::doWork, sharedWorker);
    t3.join();
    
    return 0;
}
```

---

## 5. 线程本地存储

### 5.1 thread_local

```cpp
#include <iostream>
#include <thread>

// 线程本地变量
thread_local int threadLocalValue = 0;

void incrementAndPrint(int id) {
    for (int i = 0; i < 3; ++i) {
        ++threadLocalValue;
        std::cout << "Thread " << id << ": " << threadLocalValue << std::endl;
    }
}

int main() {
    std::thread t1(incrementAndPrint, 1);
    std::thread t2(incrementAndPrint, 2);
    
    t1.join();
    t2.join();
    
    // 主线程的值
    std::cout << "Main thread: " << threadLocalValue << std::endl;
    
    return 0;
}
```

### 5.2 线程本地对象

```cpp
#include <iostream>
#include <thread>
#include <string>

class ThreadContext {
public:
    ThreadContext() {
        std::cout << "ThreadContext created for thread " 
                  << std::this_thread::get_id() << std::endl;
    }
    
    ~ThreadContext() {
        std::cout << "ThreadContext destroyed for thread " 
                  << std::this_thread::get_id() << std::endl;
    }
    
    void setName(const std::string& n) { name = n; }
    const std::string& getName() const { return name; }

private:
    std::string name;
};

thread_local ThreadContext context;

void threadFunction(const std::string& name) {
    context.setName(name);
    std::cout << "Thread name: " << context.getName() << std::endl;
}

int main() {
    std::thread t1(threadFunction, "Worker1");
    std::thread t2(threadFunction, "Worker2");
    
    t1.join();
    t2.join();
    
    return 0;
}
```

---

## 6. 总结

### 6.1 关键类和函数

| 类/函数 | 说明 |
|---------|------|
| std::thread | 线程类 |
| join() | 等待线程完成 |
| detach() | 分离线程 |
| joinable() | 检查是否可 join |
| get_id() | 获取线程 ID |
| std::this_thread | 当前线程操作 |
| thread_local | 线程本地存储 |
| std::jthread | C++20 自动 join 线程 |

### 6.2 最佳实践

```
1. 总是 join 或 detach 线程
2. 使用 RAII 管理线程生命周期
3. 优先使用 std::jthread (C++20)
4. 注意参数传递方式
5. 避免数据竞争
```

### 6.3 下一篇预告

在下一篇文章中,我们将学习互斥量与锁。

---

> 作者: C++ 技术专栏  
> 系列: 并发编程 (1/6)  
> 上一篇: [C++20/23 新特性](../part5-modern/40-cpp20-23-features.md)  
> 下一篇: [互斥量与锁](./42-mutex-lock.md)
