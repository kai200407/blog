---
title: "async 与 future"
description: "1. [异步编程概述](#1-异步编程概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 45
---

> 本文是 C++ 从入门到精通系列的第四十五篇,将深入讲解异步编程工具 async、future 和 promise。

---

## 目录

1. [异步编程概述](#1-异步编程概述)
2. [std::future](#2-stdfuture)
3. [std::async](#3-stdasync)
4. [std::promise](#4-stdpromise)
5. [std::packaged_task](#5-stdpackaged_task)
6. [高级应用](#6-高级应用)
7. [总结](#7-总结)

---

## 1. 异步编程概述

### 1.1 为什么需要异步

```
同步编程:
- 顺序执行
- 阻塞等待
- 简单直观

异步编程:
- 并行执行
- 非阻塞
- 更高效利用资源

C++ 异步工具:
- std::async: 异步执行任务
- std::future: 获取异步结果
- std::promise: 设置异步结果
- std::packaged_task: 包装可调用对象
```

### 1.2 基本模型

```
异步执行模型:

主线程                    工作线程
   |                         |
   |-- async(task) --------->|
   |                         |-- 执行任务
   |-- 继续其他工作           |
   |                         |
   |<-- future.get() --------|-- 返回结果
   |                         |
```

---

## 2. std::future

### 2.1 基本用法

```cpp
#include <iostream>
#include <future>
#include <thread>
#include <chrono>

int compute() {
    std::this_thread::sleep_for(std::chrono::seconds(2));
    return 42;
}

int main() {
    // 创建 future
    std::future<int> fut = std::async(std::launch::async, compute);
    
    std::cout << "Doing other work..." << std::endl;
    
    // 获取结果 (阻塞)
    int result = fut.get();
    std::cout << "Result: " << result << std::endl;
    
    return 0;
}
```

### 2.2 future 状态

```cpp
#include <iostream>
#include <future>
#include <thread>
#include <chrono>

int slowCompute() {
    std::this_thread::sleep_for(std::chrono::seconds(2));
    return 42;
}

int main() {
    std::future<int> fut = std::async(std::launch::async, slowCompute);
    
    // 检查状态
    while (fut.wait_for(std::chrono::milliseconds(100)) != std::future_status::ready) {
        std::cout << "Waiting..." << std::endl;
    }
    
    std::cout << "Result: " << fut.get() << std::endl;
    
    return 0;
}
```

### 2.3 wait 方法

```cpp
#include <iostream>
#include <future>
#include <chrono>

int main() {
    auto fut = std::async(std::launch::async, []() {
        std::this_thread::sleep_for(std::chrono::seconds(2));
        return 42;
    });
    
    // wait: 阻塞等待
    fut.wait();
    std::cout << "Task completed" << std::endl;
    
    // wait_for: 等待指定时间
    auto fut2 = std::async(std::launch::async, []() {
        std::this_thread::sleep_for(std::chrono::seconds(5));
        return 100;
    });
    
    auto status = fut2.wait_for(std::chrono::seconds(1));
    if (status == std::future_status::ready) {
        std::cout << "Ready" << std::endl;
    } else if (status == std::future_status::timeout) {
        std::cout << "Timeout" << std::endl;
    } else if (status == std::future_status::deferred) {
        std::cout << "Deferred" << std::endl;
    }
    
    // wait_until: 等待到指定时间点
    auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(3);
    fut2.wait_until(deadline);
    
    return 0;
}
```

### 2.4 shared_future

```cpp
#include <iostream>
#include <future>
#include <thread>
#include <vector>

int main() {
    std::promise<int> prom;
    std::shared_future<int> sharedFut = prom.get_future().share();
    
    // 多个线程可以等待同一个 shared_future
    std::vector<std::thread> threads;
    
    for (int i = 0; i < 3; ++i) {
        threads.emplace_back([sharedFut, i]() {
            int result = sharedFut.get();  // 可以多次调用
            std::cout << "Thread " << i << " got: " << result << std::endl;
        });
    }
    
    std::this_thread::sleep_for(std::chrono::seconds(1));
    prom.set_value(42);
    
    for (auto& t : threads) {
        t.join();
    }
    
    return 0;
}
```

---

## 3. std::async

### 3.1 启动策略

```cpp
#include <iostream>
#include <future>
#include <thread>

int task() {
    std::cout << "Task running in thread: " 
              << std::this_thread::get_id() << std::endl;
    return 42;
}

int main() {
    std::cout << "Main thread: " << std::this_thread::get_id() << std::endl;
    
    // async: 异步执行 (新线程)
    auto fut1 = std::async(std::launch::async, task);
    std::cout << "async result: " << fut1.get() << std::endl;
    
    // deferred: 延迟执行 (调用 get 时执行)
    auto fut2 = std::async(std::launch::deferred, task);
    std::cout << "deferred result: " << fut2.get() << std::endl;
    
    // 默认: async | deferred (由实现决定)
    auto fut3 = std::async(task);
    std::cout << "default result: " << fut3.get() << std::endl;
    
    return 0;
}
```

### 3.2 传递参数

```cpp
#include <iostream>
#include <future>
#include <string>

int add(int a, int b) {
    return a + b;
}

std::string greet(const std::string& name) {
    return "Hello, " + name + "!";
}

class Calculator {
public:
    int multiply(int a, int b) const {
        return a * b;
    }
};

int main() {
    // 传递参数
    auto fut1 = std::async(add, 3, 4);
    std::cout << "add: " << fut1.get() << std::endl;
    
    // 传递字符串
    auto fut2 = std::async(greet, "World");
    std::cout << greet: " << fut2.get() << std::endl;
    
    // 成员函数
    Calculator calc;
    auto fut3 = std::async(&Calculator::multiply, &calc, 5, 6);
    std::cout << "multiply: " << fut3.get() << std::endl;
    
    // Lambda
    auto fut4 = std::async([](int x) { return x * x; }, 7);
    std::cout << "square: " << fut4.get() << std::endl;
    
    return 0;
}
```

### 3.3 异常处理

```cpp
#include <iostream>
#include <future>
#include <stdexcept>

int riskyTask() {
    throw std::runtime_error("Something went wrong!");
    return 42;
}

int main() {
    auto fut = std::async(std::launch::async, riskyTask);
    
    try {
        int result = fut.get();  // 异常在这里重新抛出
        std::cout << "Result: " << result << std::endl;
    } catch (const std::exception& e) {
        std::cout << "Exception: " << e.what() << std::endl;
    }
    
    return 0;
}
```

---

## 4. std::promise

### 4.1 基本用法

```cpp
#include <iostream>
#include <future>
#include <thread>

void producer(std::promise<int>& prom) {
    std::this_thread::sleep_for(std::chrono::seconds(1));
    prom.set_value(42);
}

void consumer(std::future<int>& fut) {
    std::cout << "Waiting for value..." << std::endl;
    int value = fut.get();
    std::cout << "Got value: " << value << std::endl;
}

int main() {
    std::promise<int> prom;
    std::future<int> fut = prom.get_future();
    
    std::thread t1(producer, std::ref(prom));
    std::thread t2(consumer, std::ref(fut));
    
    t1.join();
    t2.join();
    
    return 0;
}
```

### 4.2 设置异常

```cpp
#include <iostream>
#include <future>
#include <thread>
#include <stdexcept>

void worker(std::promise<int>& prom, bool success) {
    std::this_thread::sleep_for(std::chrono::seconds(1));
    
    if (success) {
        prom.set_value(42);
    } else {
        prom.set_exception(
            std::make_exception_ptr(std::runtime_error("Task failed!"))
        );
    }
}

int main() {
    std::promise<int> prom;
    std::future<int> fut = prom.get_future();
    
    std::thread t(worker, std::ref(prom), false);
    
    try {
        int result = fut.get();
        std::cout << "Result: " << result << std::endl;
    } catch (const std::exception& e) {
        std::cout << "Exception: " << e.what() << std::endl;
    }
    
    t.join();
    
    return 0;
}
```

### 4.3 一次性通道

```cpp
#include <iostream>
#include <future>
#include <thread>
#include <queue>

template<typename T>
class Channel {
public:
    void send(T value) {
        promise.set_value(std::move(value));
    }
    
    T receive() {
        return future.get();
    }
    
    Channel() : future(promise.get_future()) { }

private:
    std::promise<T> promise;
    std::future<T> future;
};

int main() {
    Channel<std::string> channel;
    
    std::thread sender([&channel]() {
        std::this_thread::sleep_for(std::chrono::seconds(1));
        channel.send("Hello from sender!");
    });
    
    std::thread receiver([&channel]() {
        std::string msg = channel.receive();
        std::cout << "Received: " << msg << std::endl;
    });
    
    sender.join();
    receiver.join();
    
    return 0;
}
```

---

## 5. std::packaged_task

### 5.1 基本用法

```cpp
#include <iostream>
#include <future>
#include <thread>

int compute(int x) {
    return x * x;
}

int main() {
    // 包装函数
    std::packaged_task<int(int)> task(compute);
    std::future<int> fut = task.get_future();
    
    // 在另一个线程执行
    std::thread t(std::move(task), 5);
    
    std::cout << "Result: " << fut.get() << std::endl;
    
    t.join();
    
    return 0;
}
```

### 5.2 任务队列

```cpp
#include <iostream>
#include <future>
#include <thread>
#include <queue>
#include <mutex>
#include <condition_variable>

class TaskQueue {
public:
    template<typename F, typename... Args>
    auto submit(F&& f, Args&&... args) 
        -> std::future<typename std::invoke_result<F, Args...>::type> {
        
        using ReturnType = typename std::invoke_result<F, Args...>::type;
        
        auto task = std::make_shared<std::packaged_task<ReturnType()>>(
            std::bind(std::forward<F>(f), std::forward<Args>(args)...)
        );
        
        std::future<ReturnType> fut = task->get_future();
        
        {
            std::lock_guard<std::mutex> lock(mutex);
            tasks.push([task]() { (*task)(); });
        }
        cv.notify_one();
        
        return fut;
    }
    
    void processOne() {
        std::function<void()> task;
        {
            std::unique_lock<std::mutex> lock(mutex);
            cv.wait(lock, [this]{ return !tasks.empty(); });
            task = std::move(tasks.front());
            tasks.pop();
        }
        task();
    }
    
    bool empty() const {
        std::lock_guard<std::mutex> lock(mutex);
        return tasks.empty();
    }

private:
    mutable std::mutex mutex;
    std::condition_variable cv;
    std::queue<std::function<void()>> tasks;
};

int main() {
    TaskQueue queue;
    
    // 工作线程
    std::thread worker([&queue]() {
        for (int i = 0; i < 3; ++i) {
            queue.processOne();
        }
    });
    
    // 提交任务
    auto fut1 = queue.submit([](int x) { return x * 2; }, 10);
    auto fut2 = queue.submit([](int x, int y) { return x + y; }, 3, 4);
    auto fut3 = queue.submit([]() { return std::string("Hello"); });
    
    std::cout << "Result 1: " << fut1.get() << std::endl;
    std::cout << "Result 2: " << fut2.get() << std::endl;
    std::cout << "Result 3: " << fut3.get() << std::endl;
    
    worker.join();
    
    return 0;
}
```

---

## 6. 高级应用

### 6.1 并行计算

```cpp
#include <iostream>
#include <future>
#include <vector>
#include <numeric>

// 并行求和
long long parallelSum(const std::vector<int>& data, int numThreads) {
    size_t chunkSize = data.size() / numThreads;
    std::vector<std::future<long long>> futures;
    
    for (int i = 0; i < numThreads; ++i) {
        size_t start = i * chunkSize;
        size_t end = (i == numThreads - 1) ? data.size() : (i + 1) * chunkSize;
        
        futures.push_back(std::async(std::launch::async, [&data, start, end]() {
            return std::accumulate(data.begin() + start, data.begin() + end, 0LL);
        }));
    }
    
    long long total = 0;
    for (auto& fut : futures) {
        total += fut.get();
    }
    
    return total;
}

int main() {
    std::vector<int> data(10000000, 1);
    
    auto start = std::chrono::high_resolution_clock::now();
    long long sum = parallelSum(data, 4);
    auto end = std::chrono::high_resolution_clock::now();
    
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
    
    std::cout << "Sum: " << sum << std::endl;
    std::cout << "Time: " << duration.count() << " ms" << std::endl;
    
    return 0;
}
```

### 6.2 超时处理

```cpp
#include <iostream>
#include <future>
#include <optional>

template<typename T>
std::optional<T> getWithTimeout(std::future<T>& fut, 
                                 std::chrono::milliseconds timeout) {
    if (fut.wait_for(timeout) == std::future_status::ready) {
        return fut.get();
    }
    return std::nullopt;
}

int main() {
    auto fut = std::async(std::launch::async, []() {
        std::this_thread::sleep_for(std::chrono::seconds(5));
        return 42;
    });
    
    auto result = getWithTimeout(fut, std::chrono::seconds(1));
    
    if (result) {
        std::cout << "Result: " << *result << std::endl;
    } else {
        std::cout << "Timeout!" << std::endl;
    }
    
    return 0;
}
```

### 6.3 when_all 模拟

```cpp
#include <iostream>
#include <future>
#include <vector>
#include <tuple>

template<typename... Futures>
auto whenAll(Futures&&... futures) {
    return std::async(std::launch::async, [](auto... futs) {
        return std::make_tuple(futs.get()...);
    }, std::forward<Futures>(futures)...);
}

int main() {
    auto fut1 = std::async(std::launch::async, []() { return 1; });
    auto fut2 = std::async(std::launch::async, []() { return 2.5; });
    auto fut3 = std::async(std::launch::async, []() { return std::string("hello"); });
    
    auto combined = whenAll(std::move(fut1), std::move(fut2), std::move(fut3));
    auto [a, b, c] = combined.get();
    
    std::cout << "Results: " << a << ", " << b << ", " << c << std::endl;
    
    return 0;
}
```

---

## 7. 总结

### 7.1 异步工具对比

| 工具 | 用途 |
|------|------|
| std::async | 简单异步执行 |
| std::future | 获取异步结果 |
| std::promise | 手动设置结果 |
| std::packaged_task | 包装可调用对象 |
| std::shared_future | 多次获取结果 |

### 7.2 最佳实践

```
1. 优先使用 std::async
2. 注意 future 的生命周期
3. 处理异常
4. 考虑超时
5. 使用 shared_future 共享结果
```

### 7.3 下一篇预告

在下一篇文章中,我们将学习线程池实现。

---

> 作者: C++ 技术专栏  
> 系列: 并发编程 (5/6)  
> 上一篇: [原子操作与内存模型](./44-atomic-memory-model.md)  
> 下一篇: [线程池](./46-thread-pool.md)
