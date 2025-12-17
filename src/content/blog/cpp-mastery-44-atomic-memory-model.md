---
title: "原子操作与内存模型"
description: "1. [原子操作概述](#1-原子操作概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 44
---

> 本文是 C++ 从入门到精通系列的第四十四篇,将深入讲解原子操作和 C++ 内存模型。

---

## 目录

1. [原子操作概述](#1-原子操作概述)
2. [std::atomic](#2-stdatomic)
3. [内存序](#3-内存序)
4. [原子操作应用](#4-原子操作应用)
5. [无锁编程](#5-无锁编程)
6. [总结](#6-总结)

---

## 1. 原子操作概述

### 1.1 什么是原子操作

```
原子操作:
- 不可分割的操作
- 要么完全执行,要么完全不执行
- 不会被其他线程中断

非原子操作的问题:
int x = 0;
x++;  // 读取 -> 修改 -> 写入 (3 步)

原子操作:
std::atomic<int> x = 0;
x++;  // 原子操作 (1 步)
```

### 1.2 原子操作 vs 互斥锁

```
原子操作:
- 更轻量
- 无阻塞
- 适合简单操作
- 硬件支持

互斥锁:
- 更通用
- 可能阻塞
- 适合复杂操作
- 操作系统支持
```

---

## 2. std::atomic

### 2.1 基本用法

```cpp
#include <iostream>
#include <atomic>
#include <thread>
#include <vector>

std::atomic<int> counter{0};

void increment() {
    for (int i = 0; i < 100000; ++i) {
        ++counter;  // 原子操作
    }
}

int main() {
    std::vector<std::thread> threads;
    
    for (int i = 0; i < 4; ++i) {
        threads.emplace_back(increment);
    }
    
    for (auto& t : threads) {
        t.join();
    }
    
    std::cout << "Counter: " << counter << std::endl;  // 400000
    
    return 0;
}
```

### 2.2 原子操作方法

```cpp
#include <iostream>
#include <atomic>

int main() {
    std::atomic<int> x{0};
    
    // 存储和加载
    x.store(10);
    int value = x.load();
    std::cout << "Value: " << value << std::endl;
    
    // 交换
    int old = x.exchange(20);
    std::cout << "Old: " << old << ", New: " << x.load() << std::endl;
    
    // 比较并交换
    int expected = 20;
    bool success = x.compare_exchange_strong(expected, 30);
    std::cout << "CAS success: " << success << ", Value: " << x.load() << std::endl;
    
    // 算术操作
    x.fetch_add(5);   // x += 5
    x.fetch_sub(2);   // x -= 2
    std::cout << "After arithmetic: " << x.load() << std::endl;
    
    // 位操作
    std::atomic<int> y{0b1010};
    y.fetch_and(0b1100);  // y &= 0b1100
    y.fetch_or(0b0011);   // y |= 0b0011
    y.fetch_xor(0b0101);  // y ^= 0b0101
    std::cout << "After bitwise: " << y.load() << std::endl;
    
    return 0;
}
```

### 2.3 compare_exchange

```cpp
#include <iostream>
#include <atomic>
#include <thread>

std::atomic<int> value{0};

void incrementWithCAS() {
    for (int i = 0; i < 1000; ++i) {
        int expected = value.load();
        while (!value.compare_exchange_weak(expected, expected + 1)) {
            // expected 被更新为当前值,重试
        }
    }
}

// compare_exchange_weak vs compare_exchange_strong
void casComparison() {
    std::atomic<int> x{0};
    int expected = 0;
    
    // weak: 可能虚假失败,但在循环中更高效
    while (!x.compare_exchange_weak(expected, 1)) {
        expected = 0;
    }
    
    // strong: 不会虚假失败,适合单次操作
    expected = 1;
    if (x.compare_exchange_strong(expected, 2)) {
        std::cout << "Strong CAS succeeded" << std::endl;
    }
}

int main() {
    std::thread t1(incrementWithCAS);
    std::thread t2(incrementWithCAS);
    
    t1.join();
    t2.join();
    
    std::cout << "Value: " << value << std::endl;  // 2000
    
    casComparison();
    
    return 0;
}
```

### 2.4 原子标志

```cpp
#include <iostream>
#include <atomic>
#include <thread>

std::atomic_flag lock = ATOMIC_FLAG_INIT;

void spinLock() {
    while (lock.test_and_set(std::memory_order_acquire)) {
        // 自旋等待
    }
}

void spinUnlock() {
    lock.clear(std::memory_order_release);
}

int counter = 0;

void increment() {
    for (int i = 0; i < 100000; ++i) {
        spinLock();
        ++counter;
        spinUnlock();
    }
}

int main() {
    std::thread t1(increment);
    std::thread t2(increment);
    
    t1.join();
    t2.join();
    
    std::cout << "Counter: " << counter << std::endl;  // 200000
    
    return 0;
}
```

---

## 3. 内存序

### 3.1 内存序概述

```
C++ 内存序:

memory_order_relaxed
- 只保证原子性
- 不保证顺序

memory_order_acquire
- 读操作
- 之后的读写不能重排到之前

memory_order_release
- 写操作
- 之前的读写不能重排到之后

memory_order_acq_rel
- 读-修改-写操作
- 同时具有 acquire 和 release 语义

memory_order_seq_cst
- 顺序一致性
- 最强保证,默认选项
```

### 3.2 Relaxed 序

```cpp
#include <iostream>
#include <atomic>
#include <thread>

std::atomic<int> x{0};
std::atomic<int> y{0};

void thread1() {
    x.store(1, std::memory_order_relaxed);
    y.store(1, std::memory_order_relaxed);
}

void thread2() {
    // 可能看到 y=1 但 x=0
    while (y.load(std::memory_order_relaxed) != 1) { }
    std::cout << "x = " << x.load(std::memory_order_relaxed) << std::endl;
}

// Relaxed 适用于计数器等不需要同步的场景
std::atomic<int> counter{0};

void incrementRelaxed() {
    for (int i = 0; i < 100000; ++i) {
        counter.fetch_add(1, std::memory_order_relaxed);
    }
}
```

### 3.3 Acquire-Release 序

```cpp
#include <iostream>
#include <atomic>
#include <thread>
#include <string>

std::atomic<bool> ready{false};
std::string data;

void producer() {
    data = "Hello, World!";  // 非原子写
    ready.store(true, std::memory_order_release);  // 释放
}

void consumer() {
    while (!ready.load(std::memory_order_acquire)) { }  // 获取
    std::cout << data << std::endl;  // 保证看到 "Hello, World!"
}

int main() {
    std::thread t1(producer);
    std::thread t2(consumer);
    
    t1.join();
    t2.join();
    
    return 0;
}
```

### 3.4 顺序一致性

```cpp
#include <iostream>
#include <atomic>
#include <thread>

std::atomic<bool> x{false};
std::atomic<bool> y{false};
std::atomic<int> z{0};

void writeX() {
    x.store(true, std::memory_order_seq_cst);
}

void writeY() {
    y.store(true, std::memory_order_seq_cst);
}

void readXThenY() {
    while (!x.load(std::memory_order_seq_cst)) { }
    if (y.load(std::memory_order_seq_cst)) {
        ++z;
    }
}

void readYThenX() {
    while (!y.load(std::memory_order_seq_cst)) { }
    if (x.load(std::memory_order_seq_cst)) {
        ++z;
    }
}

int main() {
    std::thread t1(writeX);
    std::thread t2(writeY);
    std::thread t3(readXThenY);
    std::thread t4(readYThenX);
    
    t1.join();
    t2.join();
    t3.join();
    t4.join();
    
    // 顺序一致性保证 z 至少为 1
    std::cout << "z = " << z << std::endl;
    
    return 0;
}
```

---

## 4. 原子操作应用

### 4.1 自旋锁

```cpp
#include <iostream>
#include <atomic>
#include <thread>

class SpinLock {
public:
    void lock() {
        while (flag.test_and_set(std::memory_order_acquire)) {
            // 自旋
        }
    }
    
    void unlock() {
        flag.clear(std::memory_order_release);
    }
    
    bool tryLock() {
        return !flag.test_and_set(std::memory_order_acquire);
    }

private:
    std::atomic_flag flag = ATOMIC_FLAG_INIT;
};

// 使用示例
SpinLock spinLock;
int sharedData = 0;

void worker() {
    for (int i = 0; i < 100000; ++i) {
        spinLock.lock();
        ++sharedData;
        spinLock.unlock();
    }
}

int main() {
    std::thread t1(worker);
    std::thread t2(worker);
    
    t1.join();
    t2.join();
    
    std::cout << "Shared data: " << sharedData << std::endl;
    
    return 0;
}
```

### 4.2 引用计数

```cpp
#include <iostream>
#include <atomic>
#include <memory>

template<typename T>
class AtomicSharedPtr {
public:
    struct ControlBlock {
        T* ptr;
        std::atomic<int> refCount;
        
        ControlBlock(T* p) : ptr(p), refCount(1) { }
        
        void release() {
            if (refCount.fetch_sub(1, std::memory_order_acq_rel) == 1) {
                delete ptr;
                delete this;
            }
        }
        
        void addRef() {
            refCount.fetch_add(1, std::memory_order_relaxed);
        }
    };
    
    AtomicSharedPtr() : control(nullptr) { }
    
    explicit AtomicSharedPtr(T* ptr) : control(new ControlBlock(ptr)) { }
    
    AtomicSharedPtr(const AtomicSharedPtr& other) : control(other.control) {
        if (control) {
            control->addRef();
        }
    }
    
    ~AtomicSharedPtr() {
        if (control) {
            control->release();
        }
    }
    
    T* get() const {
        return control ? control->ptr : nullptr;
    }
    
    int useCount() const {
        return control ? control->refCount.load() : 0;
    }

private:
    ControlBlock* control;
};

int main() {
    AtomicSharedPtr<int> p1(new int(42));
    std::cout << "Use count: " << p1.useCount() << std::endl;
    
    {
        AtomicSharedPtr<int> p2 = p1;
        std::cout << "Use count: " << p1.useCount() << std::endl;
    }
    
    std::cout << "Use count: " << p1.useCount() << std::endl;
    
    return 0;
}
```

### 4.3 无锁栈

```cpp
#include <iostream>
#include <atomic>
#include <memory>

template<typename T>
class LockFreeStack {
private:
    struct Node {
        T data;
        Node* next;
        
        Node(const T& d) : data(d), next(nullptr) { }
    };
    
    std::atomic<Node*> head{nullptr};

public:
    void push(const T& data) {
        Node* newNode = new Node(data);
        newNode->next = head.load(std::memory_order_relaxed);
        
        while (!head.compare_exchange_weak(
            newNode->next, newNode,
            std::memory_order_release,
            std::memory_order_relaxed)) {
            // 重试
        }
    }
    
    bool pop(T& result) {
        Node* oldHead = head.load(std::memory_order_relaxed);
        
        while (oldHead && !head.compare_exchange_weak(
            oldHead, oldHead->next,
            std::memory_order_acquire,
            std::memory_order_relaxed)) {
            // 重试
        }
        
        if (oldHead) {
            result = oldHead->data;
            delete oldHead;
            return true;
        }
        
        return false;
    }
    
    bool empty() const {
        return head.load(std::memory_order_relaxed) == nullptr;
    }
};

int main() {
    LockFreeStack<int> stack;
    
    stack.push(1);
    stack.push(2);
    stack.push(3);
    
    int value;
    while (stack.pop(value)) {
        std::cout << "Popped: " << value << std::endl;
    }
    
    return 0;
}
```

---

## 5. 无锁编程

### 5.1 无锁 vs 有锁

```
有锁编程:
- 使用互斥量保护共享数据
- 可能导致阻塞
- 可能死锁
- 实现简单

无锁编程:
- 使用原子操作
- 不会阻塞
- 不会死锁
- 实现复杂
- 可能有 ABA 问题
```

### 5.2 ABA 问题

```cpp
#include <iostream>
#include <atomic>
#include <thread>

/*
ABA 问题示例:

1. 线程 1 读取值 A
2. 线程 1 被挂起
3. 线程 2 将值从 A 改为 B
4. 线程 2 将值从 B 改回 A
5. 线程 1 恢复,CAS 成功 (因为值仍是 A)
6. 但实际上值已经被修改过了

解决方案:
- 使用版本号/标记
- 使用 hazard pointers
- 使用 RCU
*/

template<typename T>
struct TaggedPointer {
    T* ptr;
    size_t tag;
    
    bool operator==(const TaggedPointer& other) const {
        return ptr == other.ptr && tag == other.tag;
    }
};

// 使用带标记的指针避免 ABA 问题
template<typename T>
class ABASafeStack {
private:
    struct Node {
        T data;
        Node* next;
    };
    
    std::atomic<TaggedPointer<Node>> head{{nullptr, 0}};

public:
    void push(const T& data) {
        Node* newNode = new Node{data, nullptr};
        TaggedPointer<Node> oldHead = head.load();
        TaggedPointer<Node> newHead;
        
        do {
            newNode->next = oldHead.ptr;
            newHead = {newNode, oldHead.tag + 1};
        } while (!head.compare_exchange_weak(oldHead, newHead));
    }
    
    // ... pop 实现类似
};
```

### 5.3 内存屏障

```cpp
#include <iostream>
#include <atomic>
#include <thread>

int data = 0;
std::atomic<bool> ready{false};

void producer() {
    data = 42;
    std::atomic_thread_fence(std::memory_order_release);
    ready.store(true, std::memory_order_relaxed);
}

void consumer() {
    while (!ready.load(std::memory_order_relaxed)) { }
    std::atomic_thread_fence(std::memory_order_acquire);
    std::cout << "Data: " << data << std::endl;  // 保证是 42
}

int main() {
    std::thread t1(producer);
    std::thread t2(consumer);
    
    t1.join();
    t2.join();
    
    return 0;
}
```

---

## 6. 总结

### 6.1 原子类型

| 类型 | 说明 |
|------|------|
| std::atomic<T> | 通用原子类型 |
| std::atomic_flag | 无锁布尔标志 |
| std::atomic_int | 原子整数 |
| std::atomic_bool | 原子布尔 |

### 6.2 内存序选择

| 场景 | 推荐内存序 |
|------|-----------|
| 计数器 | relaxed |
| 发布-订阅 | release-acquire |
| 需要全局顺序 | seq_cst |

### 6.3 下一篇预告

在下一篇文章中,我们将学习 async 与 future。

---

> 作者: C++ 技术专栏  
> 系列: 并发编程 (4/6)  
> 上一篇: [条件变量](./43-condition-variable.md)  
> 下一篇: [async 与 future](./45-async-future.md)
