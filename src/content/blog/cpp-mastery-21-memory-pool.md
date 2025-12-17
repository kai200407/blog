---
title: "内存池与自定义分配器"
description: "1. [内存池概述](#1-内存池概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 21
---

> 本文是 C++ 从入门到精通系列的第二十一篇,将深入讲解内存池技术和自定义分配器的实现。

---

## 目录

1. [内存池概述](#1-内存池概述)
2. [简单内存池实现](#2-简单内存池实现)
3. [对象池](#3-对象池)
4. [自定义分配器](#4-自定义分配器)
5. [STL 分配器](#5-stl-分配器)
6. [总结](#6-总结)

---

## 1. 内存池概述

### 1.1 为什么需要内存池

```
标准内存分配的问题:

1. 性能开销
   - 每次 new/delete 都有系统调用开销
   - 内存碎片化

2. 内存碎片
   - 频繁分配/释放小对象
   - 内存利用率下降

3. 缓存不友好
   - 分散的内存访问
   - 缓存命中率低

内存池的优势:

1. 预分配大块内存
2. 快速分配/释放
3. 减少碎片
4. 提高缓存命中率
```

### 1.2 内存池类型

```
内存池类型:

1. 固定大小内存池
   - 所有块大小相同
   - 分配/释放 O(1)
   - 适合同类型对象

2. 可变大小内存池
   - 支持不同大小的分配
   - 更复杂的管理
   - 适合通用场景

3. 对象池
   - 预创建对象
   - 复用对象而非销毁
   - 避免构造/析构开销
```

---

## 2. 简单内存池实现

### 2.1 固定大小内存池

```cpp
#include <iostream>
#include <vector>
#include <cstdint>

class FixedSizePool {
public:
    FixedSizePool(size_t blockSize, size_t blockCount)
        : blockSize(blockSize), blockCount(blockCount) {
        // 分配内存池
        pool = new char[blockSize * blockCount];
        
        // 初始化空闲链表
        for (size_t i = 0; i < blockCount; ++i) {
            freeList.push_back(pool + i * blockSize);
        }
        
        std::cout << "Pool created: " << blockCount << " blocks of " 
                  << blockSize << " bytes" << std::endl;
    }
    
    ~FixedSizePool() {
        delete[] pool;
        std::cout << "Pool destroyed" << std::endl;
    }
    
    void* allocate() {
        if (freeList.empty()) {
            throw std::bad_alloc();
        }
        
        void* ptr = freeList.back();
        freeList.pop_back();
        ++allocatedCount;
        
        return ptr;
    }
    
    void deallocate(void* ptr) {
        if (ptr == nullptr) return;
        
        // 验证指针在池范围内
        if (ptr < pool || ptr >= pool + blockSize * blockCount) {
            throw std::invalid_argument("Pointer not from this pool");
        }
        
        freeList.push_back(static_cast<char*>(ptr));
        --allocatedCount;
    }
    
    size_t getAllocatedCount() const { return allocatedCount; }
    size_t getFreeCount() const { return freeList.size(); }

private:
    char* pool;
    size_t blockSize;
    size_t blockCount;
    size_t allocatedCount = 0;
    std::vector<char*> freeList;
};

int main() {
    FixedSizePool pool(sizeof(int), 10);
    
    std::vector<int*> ptrs;
    
    // 分配
    for (int i = 0; i < 5; ++i) {
        int* p = static_cast<int*>(pool.allocate());
        *p = i * 10;
        ptrs.push_back(p);
        std::cout << "Allocated: " << *p << " at " << p << std::endl;
    }
    
    std::cout << "Allocated: " << pool.getAllocatedCount() 
              << ", Free: " << pool.getFreeCount() << std::endl;
    
    // 释放
    for (int* p : ptrs) {
        pool.deallocate(p);
    }
    
    std::cout << "After deallocation - Allocated: " << pool.getAllocatedCount() 
              << ", Free: " << pool.getFreeCount() << std::endl;
    
    return 0;
}
```

### 2.2 链表式空闲块管理

```cpp
#include <iostream>
#include <cstdint>

class LinkedPool {
public:
    LinkedPool(size_t blockSize, size_t blockCount)
        : blockSize(std::max(blockSize, sizeof(void*))), 
          blockCount(blockCount) {
        // 分配内存池
        pool = new char[this->blockSize * blockCount];
        
        // 使用链表管理空闲块
        freeHead = reinterpret_cast<FreeBlock*>(pool);
        FreeBlock* current = freeHead;
        
        for (size_t i = 1; i < blockCount; ++i) {
            current->next = reinterpret_cast<FreeBlock*>(
                pool + i * this->blockSize);
            current = current->next;
        }
        current->next = nullptr;
    }
    
    ~LinkedPool() {
        delete[] pool;
    }
    
    void* allocate() {
        if (freeHead == nullptr) {
            throw std::bad_alloc();
        }
        
        FreeBlock* block = freeHead;
        freeHead = freeHead->next;
        return block;
    }
    
    void deallocate(void* ptr) {
        if (ptr == nullptr) return;
        
        FreeBlock* block = static_cast<FreeBlock*>(ptr);
        block->next = freeHead;
        freeHead = block;
    }

private:
    struct FreeBlock {
        FreeBlock* next;
    };
    
    char* pool;
    size_t blockSize;
    size_t blockCount;
    FreeBlock* freeHead;
};

int main() {
    LinkedPool pool(32, 100);
    
    void* p1 = pool.allocate();
    void* p2 = pool.allocate();
    void* p3 = pool.allocate();
    
    std::cout << "Allocated: " << p1 << ", " << p2 << ", " << p3 << std::endl;
    
    pool.deallocate(p2);
    
    void* p4 = pool.allocate();
    std::cout << "Reused: " << p4 << " (should be same as p2)" << std::endl;
    
    pool.deallocate(p1);
    pool.deallocate(p3);
    pool.deallocate(p4);
    
    return 0;
}
```

---

## 3. 对象池

### 3.1 基本对象池

```cpp
#include <iostream>
#include <vector>
#include <memory>

template<typename T>
class ObjectPool {
public:
    ObjectPool(size_t initialSize = 10) {
        expandPool(initialSize);
    }
    
    ~ObjectPool() {
        for (char* block : blocks) {
            delete[] block;
        }
    }
    
    template<typename... Args>
    T* acquire(Args&&... args) {
        if (freeList.empty()) {
            expandPool(blocks.size() * 2);  // 扩展池
        }
        
        T* obj = freeList.back();
        freeList.pop_back();
        
        // 在已分配的内存上构造对象
        new(obj) T(std::forward<Args>(args)...);
        
        return obj;
    }
    
    void release(T* obj) {
        if (obj == nullptr) return;
        
        // 调用析构函数
        obj->~T();
        
        freeList.push_back(obj);
    }
    
    size_t size() const { return totalObjects; }
    size_t available() const { return freeList.size(); }

private:
    void expandPool(size_t count) {
        char* block = new char[sizeof(T) * count];
        blocks.push_back(block);
        
        for (size_t i = 0; i < count; ++i) {
            freeList.push_back(reinterpret_cast<T*>(block + i * sizeof(T)));
        }
        
        totalObjects += count;
        std::cout << "Pool expanded by " << count << " objects" << std::endl;
    }
    
    std::vector<char*> blocks;
    std::vector<T*> freeList;
    size_t totalObjects = 0;
};

class GameObject {
public:
    int id;
    float x, y;
    
    GameObject(int id = 0, float x = 0, float y = 0)
        : id(id), x(x), y(y) {
        std::cout << "GameObject " << id << " constructed" << std::endl;
    }
    
    ~GameObject() {
        std::cout << "GameObject " << id << " destroyed" << std::endl;
    }
};

int main() {
    ObjectPool<GameObject> pool(5);
    
    std::cout << "\n=== Acquiring objects ===" << std::endl;
    GameObject* obj1 = pool.acquire(1, 10.0f, 20.0f);
    GameObject* obj2 = pool.acquire(2, 30.0f, 40.0f);
    GameObject* obj3 = pool.acquire(3, 50.0f, 60.0f);
    
    std::cout << "\nPool: " << pool.available() << "/" << pool.size() << " available" << std::endl;
    
    std::cout << "\n=== Releasing obj2 ===" << std::endl;
    pool.release(obj2);
    
    std::cout << "\n=== Acquiring new object ===" << std::endl;
    GameObject* obj4 = pool.acquire(4, 70.0f, 80.0f);
    
    std::cout << "\n=== Cleanup ===" << std::endl;
    pool.release(obj1);
    pool.release(obj3);
    pool.release(obj4);
    
    return 0;
}
```

### 3.2 线程安全对象池

```cpp
#include <iostream>
#include <vector>
#include <mutex>
#include <thread>

template<typename T>
class ThreadSafePool {
public:
    ThreadSafePool(size_t initialSize = 10) {
        expandPool(initialSize);
    }
    
    ~ThreadSafePool() {
        std::lock_guard<std::mutex> lock(mutex);
        for (char* block : blocks) {
            delete[] block;
        }
    }
    
    template<typename... Args>
    T* acquire(Args&&... args) {
        std::lock_guard<std::mutex> lock(mutex);
        
        if (freeList.empty()) {
            expandPool(blocks.size() * 2);
        }
        
        T* obj = freeList.back();
        freeList.pop_back();
        
        new(obj) T(std::forward<Args>(args)...);
        return obj;
    }
    
    void release(T* obj) {
        if (obj == nullptr) return;
        
        obj->~T();
        
        std::lock_guard<std::mutex> lock(mutex);
        freeList.push_back(obj);
    }

private:
    void expandPool(size_t count) {
        char* block = new char[sizeof(T) * count];
        blocks.push_back(block);
        
        for (size_t i = 0; i < count; ++i) {
            freeList.push_back(reinterpret_cast<T*>(block + i * sizeof(T)));
        }
    }
    
    std::vector<char*> blocks;
    std::vector<T*> freeList;
    std::mutex mutex;
};

struct Task {
    int id;
    Task(int i) : id(i) { }
};

int main() {
    ThreadSafePool<Task> pool(100);
    
    auto worker = [&pool](int threadId) {
        for (int i = 0; i < 10; ++i) {
            Task* task = pool.acquire(threadId * 100 + i);
            // 模拟工作
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
            pool.release(task);
        }
    };
    
    std::vector<std::thread> threads;
    for (int i = 0; i < 4; ++i) {
        threads.emplace_back(worker, i);
    }
    
    for (auto& t : threads) {
        t.join();
    }
    
    std::cout << "All threads completed" << std::endl;
    
    return 0;
}
```

---

## 4. 自定义分配器

### 4.1 简单分配器

```cpp
#include <iostream>
#include <memory>

template<typename T>
class SimpleAllocator {
public:
    using value_type = T;
    
    SimpleAllocator() noexcept {
        std::cout << "SimpleAllocator created for " << typeid(T).name() << std::endl;
    }
    
    template<typename U>
    SimpleAllocator(const SimpleAllocator<U>&) noexcept { }
    
    T* allocate(size_t n) {
        std::cout << "Allocating " << n << " objects of size " << sizeof(T) << std::endl;
        return static_cast<T*>(::operator new(n * sizeof(T)));
    }
    
    void deallocate(T* p, size_t n) noexcept {
        std::cout << "Deallocating " << n << " objects" << std::endl;
        ::operator delete(p);
    }
};

template<typename T, typename U>
bool operator==(const SimpleAllocator<T>&, const SimpleAllocator<U>&) {
    return true;
}

template<typename T, typename U>
bool operator!=(const SimpleAllocator<T>&, const SimpleAllocator<U>&) {
    return false;
}

int main() {
    std::vector<int, SimpleAllocator<int>> vec;
    
    std::cout << "\n=== Adding elements ===" << std::endl;
    for (int i = 0; i < 5; ++i) {
        vec.push_back(i);
    }
    
    std::cout << "\n=== Vector contents ===" << std::endl;
    for (int x : vec) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    std::cout << "\n=== Destroying vector ===" << std::endl;
    
    return 0;
}
```

### 4.2 池分配器

```cpp
#include <iostream>
#include <vector>
#include <list>
#include <memory>

template<typename T, size_t PoolSize = 1024>
class PoolAllocator {
public:
    using value_type = T;
    
    PoolAllocator() noexcept {
        pool = new char[PoolSize * sizeof(T)];
        freePtr = pool;
        endPtr = pool + PoolSize * sizeof(T);
    }
    
    ~PoolAllocator() {
        delete[] pool;
    }
    
    template<typename U>
    PoolAllocator(const PoolAllocator<U, PoolSize>&) noexcept {
        pool = new char[PoolSize * sizeof(T)];
        freePtr = pool;
        endPtr = pool + PoolSize * sizeof(T);
    }
    
    T* allocate(size_t n) {
        size_t bytes = n * sizeof(T);
        
        if (freePtr + bytes > endPtr) {
            // 池已满,回退到标准分配
            return static_cast<T*>(::operator new(bytes));
        }
        
        T* result = reinterpret_cast<T*>(freePtr);
        freePtr += bytes;
        return result;
    }
    
    void deallocate(T* p, size_t n) noexcept {
        // 简单池不支持单独释放
        // 只有当整个池销毁时才释放内存
        
        // 检查是否在池外分配
        if (reinterpret_cast<char*>(p) < pool || 
            reinterpret_cast<char*>(p) >= endPtr) {
            ::operator delete(p);
        }
    }

private:
    char* pool;
    char* freePtr;
    char* endPtr;
};

template<typename T, typename U, size_t S>
bool operator==(const PoolAllocator<T, S>&, const PoolAllocator<U, S>&) {
    return false;  // 每个分配器有自己的池
}

template<typename T, typename U, size_t S>
bool operator!=(const PoolAllocator<T, S>&, const PoolAllocator<U, S>&) {
    return true;
}

int main() {
    std::vector<int, PoolAllocator<int, 100>> vec;
    
    for (int i = 0; i < 50; ++i) {
        vec.push_back(i);
    }
    
    std::cout << "Vector size: " << vec.size() << std::endl;
    
    return 0;
}
```

---

## 5. STL 分配器

### 5.1 std::allocator

```cpp
#include <iostream>
#include <memory>
#include <vector>

int main() {
    std::allocator<int> alloc;
    
    // 分配内存
    int* p = alloc.allocate(5);
    
    // 构造对象
    for (int i = 0; i < 5; ++i) {
        std::allocator_traits<std::allocator<int>>::construct(alloc, p + i, i * 10);
    }
    
    // 使用
    for (int i = 0; i < 5; ++i) {
        std::cout << p[i] << " ";
    }
    std::cout << std::endl;
    
    // 销毁对象
    for (int i = 0; i < 5; ++i) {
        std::allocator_traits<std::allocator<int>>::destroy(alloc, p + i);
    }
    
    // 释放内存
    alloc.deallocate(p, 5);
    
    return 0;
}
```

### 5.2 std::pmr 多态分配器 (C++17)

```cpp
#include <iostream>
#include <memory_resource>
#include <vector>
#include <array>

int main() {
    // 栈上的缓冲区
    std::array<std::byte, 1024> buffer;
    
    // 单调缓冲区资源
    std::pmr::monotonic_buffer_resource pool(
        buffer.data(), buffer.size(),
        std::pmr::null_memory_resource()
    );
    
    // 使用多态分配器的 vector
    std::pmr::vector<int> vec(&pool);
    
    for (int i = 0; i < 100; ++i) {
        vec.push_back(i);
    }
    
    std::cout << "Vector size: " << vec.size() << std::endl;
    
    // 嵌套容器
    std::pmr::vector<std::pmr::string> strings(&pool);
    strings.push_back("Hello");
    strings.push_back("World");
    
    for (const auto& s : strings) {
        std::cout << s << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

---

## 6. 总结

### 6.1 内存池类型对比

| 类型 | 优点 | 缺点 | 适用场景 |
|------|------|------|---------|
| 固定大小池 | 简单高效 | 大小固定 | 同类型对象 |
| 可变大小池 | 灵活 | 复杂 | 通用场景 |
| 对象池 | 避免构造开销 | 需要重置 | 频繁创建销毁 |

### 6.2 最佳实践

```
1. 根据场景选择合适的池类型
2. 考虑线程安全需求
3. 预估池大小避免频繁扩展
4. 使用 std::pmr 简化实现
5. 性能测试验证效果
```

### 6.3 下一篇预告

在下一篇文章中,我们将学习内存调试与泄漏检测。

---

> 作者: C++ 技术专栏  
> 系列: 内存管理与指针进阶 (5/6)  
> 上一篇: [内存布局与对齐](./20-memory-layout.md)  
> 下一篇: [内存调试与泄漏检测](./22-memory-debugging.md)
