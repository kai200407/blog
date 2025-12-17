---
title: "互斥量与锁"
description: "1. [数据竞争问题](#1-数据竞争问题)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 42
---

> 本文是 C++ 从入门到精通系列的第四十二篇,将深入讲解互斥量和锁机制,解决多线程数据竞争问题。

---

## 目录

1. [数据竞争问题](#1-数据竞争问题)
2. [std::mutex](#2-stdmutex)
3. [锁管理器](#3-锁管理器)
4. [其他互斥量](#4-其他互斥量)
5. [死锁与避免](#5-死锁与避免)
6. [总结](#6-总结)

---

## 1. 数据竞争问题

### 1.1 什么是数据竞争

```cpp
#include <iostream>
#include <thread>
#include <vector>

int counter = 0;

void increment() {
    for (int i = 0; i < 100000; ++i) {
        ++counter;  // 数据竞争!
    }
}

int main() {
    std::thread t1(increment);
    std::thread t2(increment);
    
    t1.join();
    t2.join();
    
    // 预期: 200000,实际: 不确定
    std::cout << "Counter: " << counter << std::endl;
    
    return 0;
}
```

### 1.2 竞争条件分析

```
++counter 的实际操作:

1. 读取 counter 的值
2. 增加 1
3. 写回 counter

线程交错示例:
Thread 1: 读取 counter (0)
Thread 2: 读取 counter (0)
Thread 1: 增加 1 (1)
Thread 2: 增加 1 (1)
Thread 1: 写回 (counter = 1)
Thread 2: 写回 (counter = 1)

结果: 两次增加,但 counter 只变成 1
```

---

## 2. std::mutex

### 2.1 基本用法

```cpp
#include <iostream>
#include <thread>
#include <mutex>

int counter = 0;
std::mutex mtx;

void increment() {
    for (int i = 0; i < 100000; ++i) {
        mtx.lock();
        ++counter;
        mtx.unlock();
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

### 2.2 try_lock

```cpp
#include <iostream>
#include <thread>
#include <mutex>
#include <chrono>

std::mutex mtx;

void tryLockExample(int id) {
    for (int i = 0; i < 3; ++i) {
        if (mtx.try_lock()) {
            std::cout << "Thread " << id << " acquired lock" << std::endl;
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
            mtx.unlock();
        } else {
            std::cout << "Thread " << id << " failed to acquire lock" << std::endl;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }
}

int main() {
    std::thread t1(tryLockExample, 1);
    std::thread t2(tryLockExample, 2);
    
    t1.join();
    t2.join();
    
    return 0;
}
```

---

## 3. 锁管理器

### 3.1 std::lock_guard

```cpp
#include <iostream>
#include <thread>
#include <mutex>

int counter = 0;
std::mutex mtx;

void safeIncrement() {
    for (int i = 0; i < 100000; ++i) {
        std::lock_guard<std::mutex> lock(mtx);
        ++counter;
        // 自动解锁
    }
}

// 异常安全
void exceptionSafe() {
    std::lock_guard<std::mutex> lock(mtx);
    // 即使抛出异常,锁也会被释放
    throw std::runtime_error("Error");
}

int main() {
    std::thread t1(safeIncrement);
    std::thread t2(safeIncrement);
    
    t1.join();
    t2.join();
    
    std::cout << "Counter: " << counter << std::endl;
    
    return 0;
}
```

### 3.2 std::unique_lock

```cpp
#include <iostream>
#include <thread>
#include <mutex>
#include <chrono>

std::mutex mtx;

void uniqueLockExample() {
    // 延迟锁定
    std::unique_lock<std::mutex> lock(mtx, std::defer_lock);
    
    std::cout << "Doing some work before locking..." << std::endl;
    
    lock.lock();  // 手动锁定
    std::cout << "Locked!" << std::endl;
    
    lock.unlock();  // 手动解锁
    std::cout << "Unlocked!" << std::endl;
    
    lock.lock();  // 再次锁定
    // 析构时自动解锁
}

void tryLockFor() {
    std::unique_lock<std::mutex> lock(mtx, std::try_to_lock);
    
    if (lock.owns_lock()) {
        std::cout << "Acquired lock" << std::endl;
    } else {
        std::cout << "Failed to acquire lock" << std::endl;
    }
}

void moveLock() {
    std::unique_lock<std::mutex> lock1(mtx);
    
    // 移动锁的所有权
    std::unique_lock<std::mutex> lock2 = std::move(lock1);
    
    // lock1 不再拥有锁
    std::cout << "lock1 owns lock: " << lock1.owns_lock() << std::endl;
    std::cout << "lock2 owns lock: " << lock2.owns_lock() << std::endl;
}

int main() {
    uniqueLockExample();
    tryLockFor();
    moveLock();
    
    return 0;
}
```

### 3.3 std::scoped_lock (C++17)

```cpp
#include <iostream>
#include <thread>
#include <mutex>

std::mutex mtx1, mtx2;

void scopedLockExample() {
    // 同时锁定多个互斥量,避免死锁
    std::scoped_lock lock(mtx1, mtx2);
    
    std::cout << "Both mutexes locked" << std::endl;
    // 自动解锁
}

// 等价于 C++11 的写法
void oldWay() {
    std::lock(mtx1, mtx2);  // 同时锁定
    std::lock_guard<std::mutex> lock1(mtx1, std::adopt_lock);
    std::lock_guard<std::mutex> lock2(mtx2, std::adopt_lock);
    
    std::cout << "Both mutexes locked (old way)" << std::endl;
}

int main() {
    scopedLockExample();
    oldWay();
    
    return 0;
}
```

---

## 4. 其他互斥量

### 4.1 std::recursive_mutex

```cpp
#include <iostream>
#include <thread>
#include <mutex>

std::recursive_mutex rmtx;

void recursiveFunction(int depth) {
    std::lock_guard<std::recursive_mutex> lock(rmtx);
    
    std::cout << "Depth: " << depth << std::endl;
    
    if (depth > 0) {
        recursiveFunction(depth - 1);  // 可以再次获取锁
    }
}

int main() {
    std::thread t(recursiveFunction, 5);
    t.join();
    
    return 0;
}
```

### 4.2 std::timed_mutex

```cpp
#include <iostream>
#include <thread>
#include <mutex>
#include <chrono>

std::timed_mutex tmtx;

void timedLockExample(int id) {
    // 尝试在指定时间内获取锁
    if (tmtx.try_lock_for(std::chrono::milliseconds(100))) {
        std::cout << "Thread " << id << " acquired lock" << std::endl;
        std::this_thread::sleep_for(std::chrono::milliseconds(200));
        tmtx.unlock();
    } else {
        std::cout << "Thread " << id << " timeout" << std::endl;
    }
}

void timedLockUntil(int id) {
    auto deadline = std::chrono::steady_clock::now() + std::chrono::milliseconds(150);
    
    if (tmtx.try_lock_until(deadline)) {
        std::cout << "Thread " << id << " acquired lock (until)" << std::endl;
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
        tmtx.unlock();
    } else {
        std::cout << "Thread " << id << " timeout (until)" << std::endl;
    }
}

int main() {
    std::thread t1(timedLockExample, 1);
    std::thread t2(timedLockExample, 2);
    
    t1.join();
    t2.join();
    
    return 0;
}
```

### 4.3 std::shared_mutex (C++17)

```cpp
#include <iostream>
#include <thread>
#include <shared_mutex>
#include <vector>

class ThreadSafeCounter {
public:
    int get() const {
        std::shared_lock<std::shared_mutex> lock(mutex);
        return value;
    }
    
    void increment() {
        std::unique_lock<std::shared_mutex> lock(mutex);
        ++value;
    }
    
    void reset() {
        std::unique_lock<std::shared_mutex> lock(mutex);
        value = 0;
    }

private:
    mutable std::shared_mutex mutex;
    int value = 0;
};

int main() {
    ThreadSafeCounter counter;
    
    // 多个读者
    auto reader = [&counter](int id) {
        for (int i = 0; i < 5; ++i) {
            std::cout << "Reader " << id << ": " << counter.get() << std::endl;
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }
    };
    
    // 写者
    auto writer = [&counter]() {
        for (int i = 0; i < 10; ++i) {
            counter.increment();
            std::this_thread::sleep_for(std::chrono::milliseconds(20));
        }
    };
    
    std::thread w(writer);
    std::thread r1(reader, 1);
    std::thread r2(reader, 2);
    
    w.join();
    r1.join();
    r2.join();
    
    std::cout << "Final value: " << counter.get() << std::endl;
    
    return 0;
}
```

---

## 5. 死锁与避免

### 5.1 死锁示例

```cpp
#include <iostream>
#include <thread>
#include <mutex>

std::mutex mtx1, mtx2;

void thread1() {
    std::lock_guard<std::mutex> lock1(mtx1);
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
    std::lock_guard<std::mutex> lock2(mtx2);  // 等待 mtx2
    
    std::cout << "Thread 1 done" << std::endl;
}

void thread2() {
    std::lock_guard<std::mutex> lock2(mtx2);
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
    std::lock_guard<std::mutex> lock1(mtx1);  // 等待 mtx1
    
    std::cout << "Thread 2 done" << std::endl;
}

// 警告: 这会导致死锁!
// int main() {
//     std::thread t1(thread1);
//     std::thread t2(thread2);
//     t1.join();
//     t2.join();
//     return 0;
// }
```

### 5.2 避免死锁

```cpp
#include <iostream>
#include <thread>
#include <mutex>

std::mutex mtx1, mtx2;

// 方法 1: 使用 std::lock 同时锁定
void safeThread1() {
    std::lock(mtx1, mtx2);
    std::lock_guard<std::mutex> lock1(mtx1, std::adopt_lock);
    std::lock_guard<std::mutex> lock2(mtx2, std::adopt_lock);
    
    std::cout << "Safe thread 1 done" << std::endl;
}

void safeThread2() {
    std::lock(mtx1, mtx2);
    std::lock_guard<std::mutex> lock1(mtx1, std::adopt_lock);
    std::lock_guard<std::mutex> lock2(mtx2, std::adopt_lock);
    
    std::cout << "Safe thread 2 done" << std::endl;
}

// 方法 2: 使用 std::scoped_lock (C++17)
void scopedThread1() {
    std::scoped_lock lock(mtx1, mtx2);
    std::cout << "Scoped thread 1 done" << std::endl;
}

void scopedThread2() {
    std::scoped_lock lock(mtx1, mtx2);
    std::cout << "Scoped thread 2 done" << std::endl;
}

// 方法 3: 固定锁定顺序
void orderedThread1() {
    std::lock_guard<std::mutex> lock1(mtx1);  // 总是先锁 mtx1
    std::lock_guard<std::mutex> lock2(mtx2);  // 再锁 mtx2
    std::cout << "Ordered thread 1 done" << std::endl;
}

void orderedThread2() {
    std::lock_guard<std::mutex> lock1(mtx1);  // 总是先锁 mtx1
    std::lock_guard<std::mutex> lock2(mtx2);  // 再锁 mtx2
    std::cout << "Ordered thread 2 done" << std::endl;
}

int main() {
    std::thread t1(safeThread1);
    std::thread t2(safeThread2);
    t1.join();
    t2.join();
    
    std::thread t3(scopedThread1);
    std::thread t4(scopedThread2);
    t3.join();
    t4.join();
    
    return 0;
}
```

### 5.3 死锁避免策略

```
死锁避免策略:

1. 固定锁定顺序
   - 所有线程按相同顺序获取锁

2. 使用 std::lock / std::scoped_lock
   - 同时获取多个锁

3. 使用 try_lock
   - 获取失败时释放已持有的锁

4. 避免嵌套锁
   - 尽量不在持有锁时调用外部代码

5. 使用层次锁
   - 只能获取比当前层次低的锁
```

---

## 6. 总结

### 6.1 互斥量类型

| 类型 | 说明 |
|------|------|
| std::mutex | 基本互斥量 |
| std::recursive_mutex | 可递归锁定 |
| std::timed_mutex | 支持超时 |
| std::recursive_timed_mutex | 递归 + 超时 |
| std::shared_mutex | 读写锁 |

### 6.2 锁管理器

| 类型 | 说明 |
|------|------|
| std::lock_guard | 简单 RAII 锁 |
| std::unique_lock | 灵活的锁管理 |
| std::scoped_lock | 多锁管理 (C++17) |
| std::shared_lock | 共享锁 |

### 6.3 下一篇预告

在下一篇文章中,我们将学习条件变量。

---

> 作者: C++ 技术专栏  
> 系列: 并发编程 (2/6)  
> 上一篇: [线程基础](./41-thread-basics.md)  
> 下一篇: [条件变量](./43-condition-variable.md)
