---
title: "条件变量"
description: "1. [条件变量概述](#1-条件变量概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 43
---

> 本文是 C++ 从入门到精通系列的第四十三篇,将深入讲解条件变量,实现线程间的同步和通信。

---

## 目录

1. [条件变量概述](#1-条件变量概述)
2. [std::condition_variable](#2-stdcondition_variable)
3. [生产者消费者模式](#3-生产者消费者模式)
4. [高级用法](#4-高级用法)
5. [常见问题](#5-常见问题)
6. [总结](#6-总结)

---

## 1. 条件变量概述

### 1.1 为什么需要条件变量

```cpp
#include <iostream>
#include <thread>
#include <mutex>

std::mutex mtx;
bool ready = false;

// 忙等待 (低效)
void busyWait() {
    while (true) {
        std::lock_guard<std::mutex> lock(mtx);
        if (ready) {
            std::cout << "Ready!" << std::endl;
            break;
        }
        // 不断循环检查,浪费 CPU
    }
}

// 使用条件变量可以让线程休眠,直到条件满足
```

### 1.2 条件变量工作原理

```
条件变量工作流程:

等待线程:
1. 获取互斥锁
2. 检查条件
3. 如果条件不满足,释放锁并等待
4. 被唤醒后重新获取锁
5. 再次检查条件

通知线程:
1. 获取互斥锁
2. 修改共享状态
3. 释放锁
4. 通知等待的线程
```

---

## 2. std::condition_variable

### 2.1 基本用法

```cpp
#include <iostream>
#include <thread>
#include <mutex>
#include <condition_variable>

std::mutex mtx;
std::condition_variable cv;
bool ready = false;

void waitingThread() {
    std::unique_lock<std::mutex> lock(mtx);
    
    // 等待条件满足
    cv.wait(lock, []{ return ready; });
    
    std::cout << "Condition met, proceeding..." << std::endl;
}

void notifyingThread() {
    std::this_thread::sleep_for(std::chrono::seconds(1));
    
    {
        std::lock_guard<std::mutex> lock(mtx);
        ready = true;
    }
    
    cv.notify_one();  // 唤醒一个等待的线程
}

int main() {
    std::thread t1(waitingThread);
    std::thread t2(notifyingThread);
    
    t1.join();
    t2.join();
    
    return 0;
}
```

### 2.2 wait 的变体

```cpp
#include <iostream>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <chrono>

std::mutex mtx;
std::condition_variable cv;
bool ready = false;

void waitExample() {
    std::unique_lock<std::mutex> lock(mtx);
    
    // 方式 1: 带谓词的 wait
    cv.wait(lock, []{ return ready; });
    
    // 等价于:
    // while (!ready) {
    //     cv.wait(lock);
    // }
}

void waitForExample() {
    std::unique_lock<std::mutex> lock(mtx);
    
    // 等待指定时间
    if (cv.wait_for(lock, std::chrono::seconds(2), []{ return ready; })) {
        std::cout << "Condition met" << std::endl;
    } else {
        std::cout << "Timeout" << std::endl;
    }
}

void waitUntilExample() {
    std::unique_lock<std::mutex> lock(mtx);
    
    auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    
    // 等待到指定时间点
    if (cv.wait_until(lock, deadline, []{ return ready; })) {
        std::cout << "Condition met" << std::endl;
    } else {
        std::cout << "Timeout" << std::endl;
    }
}

int main() {
    std::thread t(waitForExample);
    
    std::this_thread::sleep_for(std::chrono::seconds(1));
    {
        std::lock_guard<std::mutex> lock(mtx);
        ready = true;
    }
    cv.notify_one();
    
    t.join();
    
    return 0;
}
```

### 2.3 notify_one vs notify_all

```cpp
#include <iostream>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <vector>

std::mutex mtx;
std::condition_variable cv;
bool ready = false;

void worker(int id) {
    std::unique_lock<std::mutex> lock(mtx);
    cv.wait(lock, []{ return ready; });
    std::cout << "Worker " << id << " started" << std::endl;
}

int main() {
    std::vector<std::thread> workers;
    
    for (int i = 0; i < 5; ++i) {
        workers.emplace_back(worker, i);
    }
    
    std::this_thread::sleep_for(std::chrono::seconds(1));
    
    {
        std::lock_guard<std::mutex> lock(mtx);
        ready = true;
    }
    
    // notify_one: 只唤醒一个线程
    // cv.notify_one();
    
    // notify_all: 唤醒所有等待的线程
    cv.notify_all();
    
    for (auto& t : workers) {
        t.join();
    }
    
    return 0;
}
```

---

## 3. 生产者消费者模式

### 3.1 简单实现

```cpp
#include <iostream>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <queue>

template<typename T>
class ThreadSafeQueue {
public:
    void push(T value) {
        std::lock_guard<std::mutex> lock(mutex);
        queue.push(std::move(value));
        cv.notify_one();
    }
    
    T pop() {
        std::unique_lock<std::mutex> lock(mutex);
        cv.wait(lock, [this]{ return !queue.empty(); });
        
        T value = std::move(queue.front());
        queue.pop();
        return value;
    }
    
    bool tryPop(T& value) {
        std::lock_guard<std::mutex> lock(mutex);
        if (queue.empty()) {
            return false;
        }
        value = std::move(queue.front());
        queue.pop();
        return true;
    }
    
    bool empty() const {
        std::lock_guard<std::mutex> lock(mutex);
        return queue.empty();
    }

private:
    mutable std::mutex mutex;
    std::queue<T> queue;
    std::condition_variable cv;
};

int main() {
    ThreadSafeQueue<int> queue;
    
    // 生产者
    std::thread producer([&queue]() {
        for (int i = 0; i < 10; ++i) {
            queue.push(i);
            std::cout << "Produced: " << i << std::endl;
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
    });
    
    // 消费者
    std::thread consumer([&queue]() {
        for (int i = 0; i < 10; ++i) {
            int value = queue.pop();
            std::cout << "Consumed: " << value << std::endl;
        }
    });
    
    producer.join();
    consumer.join();
    
    return 0;
}
```

### 3.2 有界缓冲区

```cpp
#include <iostream>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <queue>

template<typename T>
class BoundedQueue {
public:
    BoundedQueue(size_t capacity) : capacity(capacity) { }
    
    void push(T value) {
        std::unique_lock<std::mutex> lock(mutex);
        
        // 等待队列有空间
        notFull.wait(lock, [this]{ return queue.size() < capacity; });
        
        queue.push(std::move(value));
        notEmpty.notify_one();
    }
    
    T pop() {
        std::unique_lock<std::mutex> lock(mutex);
        
        // 等待队列非空
        notEmpty.wait(lock, [this]{ return !queue.empty(); });
        
        T value = std::move(queue.front());
        queue.pop();
        notFull.notify_one();
        
        return value;
    }

private:
    std::mutex mutex;
    std::condition_variable notEmpty;
    std::condition_variable notFull;
    std::queue<T> queue;
    size_t capacity;
};

int main() {
    BoundedQueue<int> queue(3);  // 容量为 3
    
    std::thread producer([&queue]() {
        for (int i = 0; i < 10; ++i) {
            std::cout << "Producing: " << i << std::endl;
            queue.push(i);
            std::cout << "Produced: " << i << std::endl;
        }
    });
    
    std::thread consumer([&queue]() {
        for (int i = 0; i < 10; ++i) {
            std::this_thread::sleep_for(std::chrono::milliseconds(200));
            int value = queue.pop();
            std::cout << "Consumed: " << value << std::endl;
        }
    });
    
    producer.join();
    consumer.join();
    
    return 0;
}
```

### 3.3 多生产者多消费者

```cpp
#include <iostream>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <queue>
#include <vector>
#include <atomic>

template<typename T>
class MPMCQueue {
public:
    void push(T value) {
        std::lock_guard<std::mutex> lock(mutex);
        queue.push(std::move(value));
        cv.notify_one();
    }
    
    bool pop(T& value) {
        std::unique_lock<std::mutex> lock(mutex);
        cv.wait(lock, [this]{ return !queue.empty() || done; });
        
        if (queue.empty()) {
            return false;
        }
        
        value = std::move(queue.front());
        queue.pop();
        return true;
    }
    
    void setDone() {
        std::lock_guard<std::mutex> lock(mutex);
        done = true;
        cv.notify_all();
    }

private:
    std::mutex mutex;
    std::condition_variable cv;
    std::queue<T> queue;
    bool done = false;
};

int main() {
    MPMCQueue<int> queue;
    std::atomic<int> produced{0};
    std::atomic<int> consumed{0};
    
    // 多个生产者
    std::vector<std::thread> producers;
    for (int i = 0; i < 3; ++i) {
        producers.emplace_back([&queue, &produced, i]() {
            for (int j = 0; j < 5; ++j) {
                queue.push(i * 100 + j);
                ++produced;
            }
        });
    }
    
    // 多个消费者
    std::vector<std::thread> consumers;
    for (int i = 0; i < 2; ++i) {
        consumers.emplace_back([&queue, &consumed, i]() {
            int value;
            while (queue.pop(value)) {
                std::cout << "Consumer " << i << " got: " << value << std::endl;
                ++consumed;
            }
        });
    }
    
    for (auto& t : producers) {
        t.join();
    }
    
    queue.setDone();
    
    for (auto& t : consumers) {
        t.join();
    }
    
    std::cout << "Produced: " << produced << ", Consumed: " << consumed << std::endl;
    
    return 0;
}
```

---

## 4. 高级用法

### 4.1 std::condition_variable_any

```cpp
#include <iostream>
#include <thread>
#include <mutex>
#include <shared_mutex>
#include <condition_variable>

std::shared_mutex smtx;
std::condition_variable_any cv;
bool ready = false;

void reader() {
    std::shared_lock<std::shared_mutex> lock(smtx);
    cv.wait(lock, []{ return ready; });
    std::cout << "Reader: data is ready" << std::endl;
}

void writer() {
    std::this_thread::sleep_for(std::chrono::seconds(1));
    
    {
        std::unique_lock<std::shared_mutex> lock(smtx);
        ready = true;
    }
    
    cv.notify_all();
}

int main() {
    std::thread r1(reader);
    std::thread r2(reader);
    std::thread w(writer);
    
    r1.join();
    r2.join();
    w.join();
    
    return 0;
}
```

### 4.2 事件通知

```cpp
#include <iostream>
#include <thread>
#include <mutex>
#include <condition_variable>

class Event {
public:
    void wait() {
        std::unique_lock<std::mutex> lock(mutex);
        cv.wait(lock, [this]{ return signaled; });
    }
    
    template<typename Rep, typename Period>
    bool waitFor(const std::chrono::duration<Rep, Period>& timeout) {
        std::unique_lock<std::mutex> lock(mutex);
        return cv.wait_for(lock, timeout, [this]{ return signaled; });
    }
    
    void signal() {
        {
            std::lock_guard<std::mutex> lock(mutex);
            signaled = true;
        }
        cv.notify_all();
    }
    
    void reset() {
        std::lock_guard<std::mutex> lock(mutex);
        signaled = false;
    }

private:
    std::mutex mutex;
    std::condition_variable cv;
    bool signaled = false;
};

int main() {
    Event event;
    
    std::thread waiter([&event]() {
        std::cout << "Waiting for event..." << std::endl;
        event.wait();
        std::cout << "Event received!" << std::endl;
    });
    
    std::this_thread::sleep_for(std::chrono::seconds(1));
    std::cout << "Signaling event..." << std::endl;
    event.signal();
    
    waiter.join();
    
    return 0;
}
```

---

## 5. 常见问题

### 5.1 虚假唤醒

```cpp
#include <iostream>
#include <thread>
#include <mutex>
#include <condition_variable>

std::mutex mtx;
std::condition_variable cv;
bool ready = false;

void correctWait() {
    std::unique_lock<std::mutex> lock(mtx);
    
    // 正确: 使用谓词处理虚假唤醒
    cv.wait(lock, []{ return ready; });
    
    // 或者使用循环
    // while (!ready) {
    //     cv.wait(lock);
    // }
}

void incorrectWait() {
    std::unique_lock<std::mutex> lock(mtx);
    
    // 错误: 可能因虚假唤醒而提前返回
    // cv.wait(lock);
    // if (ready) { ... }
}
```

### 5.2 丢失唤醒

```cpp
#include <iostream>
#include <thread>
#include <mutex>
#include <condition_variable>

std::mutex mtx;
std::condition_variable cv;
bool ready = false;

// 错误: 可能丢失唤醒
void incorrectNotify() {
    ready = true;  // 没有持有锁
    cv.notify_one();  // 可能在 wait 之前执行
}

// 正确: 在持有锁时修改条件
void correctNotify() {
    {
        std::lock_guard<std::mutex> lock(mtx);
        ready = true;
    }
    cv.notify_one();
}
```

### 5.3 最佳实践

```
条件变量最佳实践:

1. 总是使用谓词版本的 wait
   cv.wait(lock, predicate);

2. 在持有锁时修改共享状态
   {
       std::lock_guard lock(mtx);
       ready = true;
   }
   cv.notify_one();

3. 使用 unique_lock 而非 lock_guard
   cv.wait 需要能够解锁和重新锁定

4. 考虑使用 notify_all 而非 notify_one
   除非确定只需要唤醒一个线程

5. 注意条件变量的生命周期
   确保在所有线程完成前不被销毁
```

---

## 6. 总结

### 6.1 条件变量方法

| 方法 | 说明 |
|------|------|
| wait | 等待条件 |
| wait_for | 等待指定时间 |
| wait_until | 等待到指定时间点 |
| notify_one | 唤醒一个等待线程 |
| notify_all | 唤醒所有等待线程 |

### 6.2 使用场景

| 场景 | 说明 |
|------|------|
| 生产者消费者 | 数据队列 |
| 事件通知 | 一次性或可重置事件 |
| 屏障同步 | 等待所有线程到达 |
| 资源池 | 等待资源可用 |

### 6.3 下一篇预告

在下一篇文章中,我们将学习原子操作与内存模型。

---

> 作者: C++ 技术专栏  
> 系列: 并发编程 (3/6)  
> 上一篇: [互斥量与锁](./42-mutex-lock.md)  
> 下一篇: [原子操作与内存模型](./44-atomic-memory-model.md)
