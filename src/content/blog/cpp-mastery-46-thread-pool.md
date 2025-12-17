---
title: "线程池"
description: "1. [线程池概述](#1-线程池概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 46
---

> 本文是 C++ 从入门到精通系列的第四十六篇,也是并发编程部分的收官之作。我们将实现一个完整的线程池。

---

## 目录

1. [线程池概述](#1-线程池概述)
2. [简单线程池](#2-简单线程池)
3. [带返回值的线程池](#3-带返回值的线程池)
4. [高级特性](#4-高级特性)
5. [性能优化](#5-性能优化)
6. [总结](#6-总结)

---

## 1. 线程池概述

### 1.1 为什么需要线程池

```
问题:
- 频繁创建/销毁线程开销大
- 线程数量不受控制
- 资源管理困难

线程池优势:
- 重用线程,减少开销
- 控制并发数量
- 统一管理任务队列
- 提供任务调度能力
```

### 1.2 线程池架构

```
线程池架构:

┌─────────────────────────────────────────┐
│              Thread Pool                 │
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────┐    │
│  │         Task Queue              │    │
│  │  [Task1] [Task2] [Task3] ...    │    │
│  └─────────────────────────────────┘    │
│                  │                       │
│    ┌─────────────┼─────────────┐        │
│    ▼             ▼             ▼        │
│ ┌──────┐    ┌──────┐    ┌──────┐       │
│ │Worker│    │Worker│    │Worker│       │
│ │  1   │    │  2   │    │  3   │       │
│ └──────┘    └──────┘    └──────┘       │
└─────────────────────────────────────────┘
```

---

## 2. 简单线程池

### 2.1 基本实现

```cpp
#include <iostream>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <queue>
#include <functional>
#include <vector>

class SimpleThreadPool {
public:
    SimpleThreadPool(size_t numThreads) : stop(false) {
        for (size_t i = 0; i < numThreads; ++i) {
            workers.emplace_back([this]() {
                while (true) {
                    std::function<void()> task;
                    
                    {
                        std::unique_lock<std::mutex> lock(mutex);
                        condition.wait(lock, [this]() {
                            return stop || !tasks.empty();
                        });
                        
                        if (stop && tasks.empty()) {
                            return;
                        }
                        
                        task = std::move(tasks.front());
                        tasks.pop();
                    }
                    
                    task();
                }
            });
        }
    }
    
    void enqueue(std::function<void()> task) {
        {
            std::lock_guard<std::mutex> lock(mutex);
            tasks.push(std::move(task));
        }
        condition.notify_one();
    }
    
    ~SimpleThreadPool() {
        {
            std::lock_guard<std::mutex> lock(mutex);
            stop = true;
        }
        condition.notify_all();
        
        for (auto& worker : workers) {
            worker.join();
        }
    }

private:
    std::vector<std::thread> workers;
    std::queue<std::function<void()>> tasks;
    std::mutex mutex;
    std::condition_variable condition;
    bool stop;
};

int main() {
    SimpleThreadPool pool(4);
    
    for (int i = 0; i < 10; ++i) {
        pool.enqueue([i]() {
            std::cout << "Task " << i << " running in thread " 
                      << std::this_thread::get_id() << std::endl;
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        });
    }
    
    std::this_thread::sleep_for(std::chrono::seconds(2));
    
    return 0;
}
```

---

## 3. 带返回值的线程池

### 3.1 完整实现

```cpp
#include <iostream>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <queue>
#include <functional>
#include <vector>
#include <future>
#include <memory>
#include <type_traits>

class ThreadPool {
public:
    ThreadPool(size_t numThreads = std::thread::hardware_concurrency()) 
        : stop(false) {
        for (size_t i = 0; i < numThreads; ++i) {
            workers.emplace_back([this]() {
                workerLoop();
            });
        }
    }
    
    template<typename F, typename... Args>
    auto submit(F&& f, Args&&... args) 
        -> std::future<typename std::invoke_result<F, Args...>::type> {
        
        using ReturnType = typename std::invoke_result<F, Args...>::type;
        
        auto task = std::make_shared<std::packaged_task<ReturnType()>>(
            std::bind(std::forward<F>(f), std::forward<Args>(args)...)
        );
        
        std::future<ReturnType> result = task->get_future();
        
        {
            std::lock_guard<std::mutex> lock(mutex);
            
            if (stop) {
                throw std::runtime_error("ThreadPool is stopped");
            }
            
            tasks.emplace([task]() { (*task)(); });
        }
        
        condition.notify_one();
        return result;
    }
    
    size_t size() const {
        return workers.size();
    }
    
    size_t pendingTasks() const {
        std::lock_guard<std::mutex> lock(mutex);
        return tasks.size();
    }
    
    ~ThreadPool() {
        shutdown();
    }
    
    void shutdown() {
        {
            std::lock_guard<std::mutex> lock(mutex);
            if (stop) return;
            stop = true;
        }
        
        condition.notify_all();
        
        for (auto& worker : workers) {
            if (worker.joinable()) {
                worker.join();
            }
        }
    }

private:
    void workerLoop() {
        while (true) {
            std::function<void()> task;
            
            {
                std::unique_lock<std::mutex> lock(mutex);
                condition.wait(lock, [this]() {
                    return stop || !tasks.empty();
                });
                
                if (stop && tasks.empty()) {
                    return;
                }
                
                task = std::move(tasks.front());
                tasks.pop();
            }
            
            task();
        }
    }
    
    std::vector<std::thread> workers;
    std::queue<std::function<void()>> tasks;
    mutable std::mutex mutex;
    std::condition_variable condition;
    bool stop;
};

int main() {
    ThreadPool pool(4);
    
    // 提交任务并获取结果
    std::vector<std::future<int>> results;
    
    for (int i = 0; i < 10; ++i) {
        results.push_back(pool.submit([i]() {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
            return i * i;
        }));
    }
    
    // 获取结果
    for (size_t i = 0; i < results.size(); ++i) {
        std::cout << "Result " << i << ": " << results[i].get() << std::endl;
    }
    
    return 0;
}
```

### 3.2 使用示例

```cpp
#include <iostream>
#include <vector>
#include <numeric>

// 假设 ThreadPool 类已定义

// 并行求和
long long parallelSum(ThreadPool& pool, const std::vector<int>& data) {
    size_t numChunks = pool.size();
    size_t chunkSize = data.size() / numChunks;
    
    std::vector<std::future<long long>> futures;
    
    for (size_t i = 0; i < numChunks; ++i) {
        size_t start = i * chunkSize;
        size_t end = (i == numChunks - 1) ? data.size() : (i + 1) * chunkSize;
        
        futures.push_back(pool.submit([&data, start, end]() {
            return std::accumulate(data.begin() + start, 
                                   data.begin() + end, 0LL);
        }));
    }
    
    long long total = 0;
    for (auto& fut : futures) {
        total += fut.get();
    }
    
    return total;
}

// 并行 map
template<typename T, typename F>
std::vector<T> parallelMap(ThreadPool& pool, 
                           const std::vector<T>& input, 
                           F func) {
    std::vector<std::future<T>> futures;
    
    for (const auto& item : input) {
        futures.push_back(pool.submit(func, item));
    }
    
    std::vector<T> results;
    results.reserve(futures.size());
    
    for (auto& fut : futures) {
        results.push_back(fut.get());
    }
    
    return results;
}
```

---

## 4. 高级特性

### 4.1 优先级队列

```cpp
#include <iostream>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <queue>
#include <functional>
#include <vector>

class PriorityThreadPool {
public:
    struct Task {
        int priority;
        std::function<void()> func;
        
        bool operator<(const Task& other) const {
            return priority < other.priority;  // 高优先级在前
        }
    };
    
    PriorityThreadPool(size_t numThreads) : stop(false) {
        for (size_t i = 0; i < numThreads; ++i) {
            workers.emplace_back([this]() {
                while (true) {
                    Task task;
                    
                    {
                        std::unique_lock<std::mutex> lock(mutex);
                        condition.wait(lock, [this]() {
                            return stop || !tasks.empty();
                        });
                        
                        if (stop && tasks.empty()) return;
                        
                        task = tasks.top();
                        tasks.pop();
                    }
                    
                    task.func();
                }
            });
        }
    }
    
    void enqueue(int priority, std::function<void()> func) {
        {
            std::lock_guard<std::mutex> lock(mutex);
            tasks.push({priority, std::move(func)});
        }
        condition.notify_one();
    }
    
    ~PriorityThreadPool() {
        {
            std::lock_guard<std::mutex> lock(mutex);
            stop = true;
        }
        condition.notify_all();
        for (auto& w : workers) w.join();
    }

private:
    std::vector<std::thread> workers;
    std::priority_queue<Task> tasks;
    std::mutex mutex;
    std::condition_variable condition;
    bool stop;
};
```

### 4.2 工作窃取

```cpp
#include <iostream>
#include <thread>
#include <mutex>
#include <deque>
#include <vector>
#include <functional>
#include <atomic>
#include <random>

class WorkStealingPool {
public:
    WorkStealingPool(size_t numThreads) 
        : stop(false), queues(numThreads) {
        
        for (size_t i = 0; i < numThreads; ++i) {
            workers.emplace_back([this, i]() {
                workerLoop(i);
            });
        }
    }
    
    void submit(std::function<void()> task) {
        // 随机选择一个队列
        static thread_local std::random_device rd;
        static thread_local std::mt19937 gen(rd());
        std::uniform_int_distribution<> dis(0, queues.size() - 1);
        
        size_t idx = dis(gen);
        
        {
            std::lock_guard<std::mutex> lock(queues[idx].mutex);
            queues[idx].tasks.push_back(std::move(task));
        }
    }
    
    ~WorkStealingPool() {
        stop = true;
        for (auto& w : workers) w.join();
    }

private:
    struct TaskQueue {
        std::deque<std::function<void()>> tasks;
        std::mutex mutex;
    };
    
    void workerLoop(size_t myIndex) {
        while (!stop) {
            std::function<void()> task;
            
            // 先从自己的队列取
            {
                std::lock_guard<std::mutex> lock(queues[myIndex].mutex);
                if (!queues[myIndex].tasks.empty()) {
                    task = std::move(queues[myIndex].tasks.front());
                    queues[myIndex].tasks.pop_front();
                }
            }
            
            // 如果自己队列空了,尝试从其他队列窃取
            if (!task) {
                for (size_t i = 0; i < queues.size(); ++i) {
                    if (i == myIndex) continue;
                    
                    std::lock_guard<std::mutex> lock(queues[i].mutex);
                    if (!queues[i].tasks.empty()) {
                        task = std::move(queues[i].tasks.back());
                        queues[i].tasks.pop_back();
                        break;
                    }
                }
            }
            
            if (task) {
                task();
            } else {
                std::this_thread::yield();
            }
        }
    }
    
    std::vector<std::thread> workers;
    std::vector<TaskQueue> queues;
    std::atomic<bool> stop;
};
```

### 4.3 动态调整线程数

```cpp
#include <iostream>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <queue>
#include <functional>
#include <vector>
#include <atomic>

class DynamicThreadPool {
public:
    DynamicThreadPool(size_t minThreads, size_t maxThreads)
        : minThreads(minThreads), maxThreads(maxThreads),
          activeThreads(0), stop(false) {
        
        for (size_t i = 0; i < minThreads; ++i) {
            addWorker();
        }
    }
    
    void enqueue(std::function<void()> task) {
        {
            std::lock_guard<std::mutex> lock(mutex);
            tasks.push(std::move(task));
            
            // 如果任务多且线程数未达上限,增加线程
            if (tasks.size() > workers.size() && 
                workers.size() < maxThreads) {
                addWorker();
            }
        }
        condition.notify_one();
    }
    
    ~DynamicThreadPool() {
        {
            std::lock_guard<std::mutex> lock(mutex);
            stop = true;
        }
        condition.notify_all();
        for (auto& w : workers) {
            if (w.joinable()) w.join();
        }
    }

private:
    void addWorker() {
        workers.emplace_back([this]() {
            while (true) {
                std::function<void()> task;
                
                {
                    std::unique_lock<std::mutex> lock(mutex);
                    
                    // 等待任务或超时
                    bool hasTask = condition.wait_for(
                        lock, 
                        std::chrono::seconds(30),
                        [this]() { return stop || !tasks.empty(); }
                    );
                    
                    if (stop && tasks.empty()) return;
                    
                    // 超时且线程数超过最小值,退出
                    if (!hasTask && workers.size() > minThreads) {
                        return;
                    }
                    
                    if (!tasks.empty()) {
                        task = std::move(tasks.front());
                        tasks.pop();
                    }
                }
                
                if (task) {
                    ++activeThreads;
                    task();
                    --activeThreads;
                }
            }
        });
    }
    
    size_t minThreads;
    size_t maxThreads;
    std::atomic<size_t> activeThreads;
    std::vector<std::thread> workers;
    std::queue<std::function<void()>> tasks;
    std::mutex mutex;
    std::condition_variable condition;
    bool stop;
};
```

---

## 5. 性能优化

### 5.1 减少锁竞争

```cpp
// 使用线程本地队列
thread_local std::queue<std::function<void()>> localQueue;

// 批量提交
void submitBatch(std::vector<std::function<void()>> tasks) {
    std::lock_guard<std::mutex> lock(mutex);
    for (auto& task : tasks) {
        this->tasks.push(std::move(task));
    }
    condition.notify_all();
}
```

### 5.2 避免虚假共享

```cpp
#include <new>

// 缓存行对齐
struct alignas(std::hardware_destructive_interference_size) AlignedCounter {
    std::atomic<int> count{0};
};

// 每个线程有自己的计数器
std::vector<AlignedCounter> perThreadCounters(numThreads);
```

### 5.3 最佳实践

```
线程池最佳实践:

1. 线程数量
   - CPU 密集型: 线程数 = CPU 核心数
   - I/O 密集型: 线程数 = CPU 核心数 * 2 或更多

2. 任务粒度
   - 避免过小的任务 (调度开销)
   - 避免过大的任务 (负载不均)

3. 避免阻塞
   - 任务中避免长时间阻塞
   - 使用异步 I/O

4. 异常处理
   - 捕获任务中的异常
   - 避免线程意外终止

5. 优雅关闭
   - 等待所有任务完成
   - 设置超时
```

---

## 6. 总结

### 6.1 线程池组件

| 组件 | 说明 |
|------|------|
| 任务队列 | 存储待执行任务 |
| 工作线程 | 执行任务 |
| 同步机制 | 互斥量 + 条件变量 |
| 提交接口 | 添加任务 |
| 关闭机制 | 优雅停止 |

### 6.2 线程池类型

| 类型 | 特点 |
|------|------|
| 固定大小 | 简单,适合大多数场景 |
| 动态调整 | 根据负载调整线程数 |
| 优先级 | 支持任务优先级 |
| 工作窃取 | 负载均衡 |

### 6.3 Part 6 完成

恭喜你完成了并发编程部分的全部 6 篇文章!

**实战项目建议**: 并发服务器
- 使用线程池处理请求
- 实现生产者消费者模式
- 使用原子操作优化性能

### 6.4 下一篇预告

在下一篇文章中,我们将进入网络编程部分,学习 Socket 编程基础。

---

> 作者: C++ 技术专栏  
> 系列: 并发编程 (6/6)  
> 上一篇: [async 与 future](./45-async-future.md)  
> 下一篇: [Socket 编程基础](../part7-network/47-socket-basics.md)
