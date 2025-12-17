---
title: "内存调试与泄漏检测"
description: "1. [常见内存问题](#1-常见内存问题)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 22
---

> 本文是 C++ 从入门到精通系列的第二十二篇,也是内存管理部分的收官之作。我们将深入讲解内存调试工具和泄漏检测技术。

---

## 目录

1. [常见内存问题](#1-常见内存问题)
2. [Valgrind](#2-valgrind)
3. [AddressSanitizer](#3-addresssanitizer)
4. [自定义内存跟踪](#4-自定义内存跟踪)
5. [调试技巧](#5-调试技巧)
6. [总结](#6-总结)

---

## 1. 常见内存问题

### 1.1 内存问题类型

```cpp
#include <iostream>
#include <cstring>

// 1. 内存泄漏
void memoryLeak() {
    int* p = new int[100];
    // 忘记 delete[] p;
}

// 2. 重复释放
void doubleFree() {
    int* p = new int(42);
    delete p;
    // delete p;  // 危险!
}

// 3. 使用已释放内存
void useAfterFree() {
    int* p = new int(42);
    delete p;
    // *p = 100;  // 危险!
}

// 4. 缓冲区溢出
void bufferOverflow() {
    int arr[10];
    // arr[10] = 100;  // 越界写入
}

// 5. 未初始化内存
void uninitializedMemory() {
    int* p = new int;
    // int x = *p;  // 读取未初始化值
    delete p;
}

// 6. 野指针
void wildPointer() {
    int* p;
    // *p = 100;  // 使用未初始化指针
}

// 7. 数组越界
void arrayOutOfBounds() {
    int arr[5] = {1, 2, 3, 4, 5};
    // int x = arr[10];  // 越界读取
}

// 8. 栈溢出
void stackOverflow(int n) {
    int arr[1000000];  // 大数组可能导致栈溢出
    // stackOverflow(n + 1);  // 无限递归
}
```

### 1.2 问题影响

```
内存问题的影响:

1. 内存泄漏
   - 内存逐渐耗尽
   - 程序变慢
   - 最终崩溃

2. 缓冲区溢出
   - 数据损坏
   - 安全漏洞
   - 不可预测行为

3. 悬空指针
   - 随机崩溃
   - 数据损坏
   - 难以调试

4. 重复释放
   - 堆损坏
   - 程序崩溃
   - 安全漏洞
```

---

## 2. Valgrind

### 2.1 Valgrind 简介

```bash
# 安装 Valgrind (Ubuntu/Debian)
sudo apt-get install valgrind

# 基本用法
valgrind ./program

# 详细内存检查
valgrind --leak-check=full ./program

# 显示泄漏详情
valgrind --leak-check=full --show-leak-kinds=all ./program

# 跟踪内存来源
valgrind --leak-check=full --track-origins=yes ./program
```

### 2.2 检测内存泄漏

```cpp
// leak_example.cpp
#include <iostream>

void leakyFunction() {
    int* p = new int[100];
    // 忘记释放
}

int main() {
    for (int i = 0; i < 10; ++i) {
        leakyFunction();
    }
    
    std::cout << "Program finished" << std::endl;
    return 0;
}
```

```bash
# 编译 (带调试信息)
g++ -g leak_example.cpp -o leak_example

# 运行 Valgrind
valgrind --leak-check=full ./leak_example

# 输出示例:
# ==12345== HEAP SUMMARY:
# ==12345==     in use at exit: 4,000 bytes in 10 blocks
# ==12345==   total heap usage: 11 allocs, 1 frees, 76,704 bytes allocated
# ==12345== 
# ==12345== 4,000 bytes in 10 blocks are definitely lost in loss record 1 of 1
# ==12345==    at 0x4C2E0EF: operator new[](unsigned long)
# ==12345==    by 0x4011A5: leakyFunction() (leak_example.cpp:5)
# ==12345==    by 0x4011D4: main (leak_example.cpp:10)
```

### 2.3 检测无效内存访问

```cpp
// invalid_access.cpp
#include <iostream>

int main() {
    int* arr = new int[5];
    
    // 初始化
    for (int i = 0; i < 5; ++i) {
        arr[i] = i;
    }
    
    // 越界访问
    int x = arr[10];  // 越界读取
    arr[10] = 100;    // 越界写入
    
    delete[] arr;
    
    // 使用已释放内存
    arr[0] = 42;
    
    return 0;
}
```

```bash
# Valgrind 会检测到:
# - Invalid read of size 4
# - Invalid write of size 4
# - Invalid write of size 4 (after free)
```

---

## 3. AddressSanitizer

### 3.1 ASan 简介

```bash
# 编译时启用 AddressSanitizer
g++ -fsanitize=address -g program.cpp -o program

# 或使用 Clang
clang++ -fsanitize=address -g program.cpp -o program

# 运行
./program

# 环境变量控制
ASAN_OPTIONS=detect_leaks=1 ./program
```

### 3.2 检测示例

```cpp
// asan_example.cpp
#include <iostream>

int main() {
    int* arr = new int[10];
    
    // 堆缓冲区溢出
    arr[10] = 42;  // ASan 会检测到
    
    delete[] arr;
    
    return 0;
}
```

```bash
# 编译
g++ -fsanitize=address -g asan_example.cpp -o asan_example

# 运行
./asan_example

# 输出示例:
# =================================================================
# ==12345==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x...
# WRITE of size 4 at 0x... thread T0
#     #0 0x... in main asan_example.cpp:8
# ...
```

### 3.3 其他 Sanitizer

```bash
# 内存泄漏检测 (LeakSanitizer)
g++ -fsanitize=leak -g program.cpp -o program

# 未定义行为检测 (UndefinedBehaviorSanitizer)
g++ -fsanitize=undefined -g program.cpp -o program

# 线程问题检测 (ThreadSanitizer)
g++ -fsanitize=thread -g program.cpp -o program

# 组合使用
g++ -fsanitize=address,undefined -g program.cpp -o program
```

---

## 4. 自定义内存跟踪

### 4.1 重载 new/delete

```cpp
#include <iostream>
#include <map>
#include <mutex>
#include <cstdlib>

// 内存跟踪器
class MemoryTracker {
public:
    static MemoryTracker& instance() {
        static MemoryTracker tracker;
        return tracker;
    }
    
    void recordAllocation(void* ptr, size_t size, const char* file, int line) {
        std::lock_guard<std::mutex> lock(mutex);
        allocations[ptr] = {size, file, line};
        totalAllocated += size;
        ++allocationCount;
    }
    
    void recordDeallocation(void* ptr) {
        std::lock_guard<std::mutex> lock(mutex);
        auto it = allocations.find(ptr);
        if (it != allocations.end()) {
            totalAllocated -= it->second.size;
            ++deallocationCount;
            allocations.erase(it);
        }
    }
    
    void report() {
        std::lock_guard<std::mutex> lock(mutex);
        std::cout << "\n=== Memory Report ===" << std::endl;
        std::cout << "Total allocations: " << allocationCount << std::endl;
        std::cout << "Total deallocations: " << deallocationCount << std::endl;
        std::cout << "Current allocations: " << allocations.size() << std::endl;
        std::cout << "Bytes in use: " << totalAllocated << std::endl;
        
        if (!allocations.empty()) {
            std::cout << "\n=== Memory Leaks ===" << std::endl;
            for (const auto& [ptr, info] : allocations) {
                std::cout << "  " << info.size << " bytes at " << ptr
                          << " (" << info.file << ":" << info.line << ")" << std::endl;
            }
        }
    }

private:
    struct AllocationInfo {
        size_t size;
        const char* file;
        int line;
    };
    
    std::map<void*, AllocationInfo> allocations;
    std::mutex mutex;
    size_t totalAllocated = 0;
    size_t allocationCount = 0;
    size_t deallocationCount = 0;
};

// 自定义 new
void* operator new(size_t size, const char* file, int line) {
    void* ptr = std::malloc(size);
    if (!ptr) throw std::bad_alloc();
    MemoryTracker::instance().recordAllocation(ptr, size, file, line);
    return ptr;
}

void* operator new[](size_t size, const char* file, int line) {
    void* ptr = std::malloc(size);
    if (!ptr) throw std::bad_alloc();
    MemoryTracker::instance().recordAllocation(ptr, size, file, line);
    return ptr;
}

void operator delete(void* ptr) noexcept {
    MemoryTracker::instance().recordDeallocation(ptr);
    std::free(ptr);
}

void operator delete[](void* ptr) noexcept {
    MemoryTracker::instance().recordDeallocation(ptr);
    std::free(ptr);
}

// 宏定义
#define new new(__FILE__, __LINE__)

int main() {
    int* p1 = new int(42);
    int* p2 = new int[100];
    char* p3 = new char[50];
    
    delete p1;
    delete[] p2;
    // 故意不删除 p3
    
    MemoryTracker::instance().report();
    
    delete[] p3;  // 清理
    
    return 0;
}
```

### 4.2 智能指针包装

```cpp
#include <iostream>
#include <memory>
#include <atomic>

template<typename T>
class TrackedPtr {
public:
    TrackedPtr() : ptr(nullptr) {
        ++instanceCount;
    }
    
    explicit TrackedPtr(T* p) : ptr(p) {
        ++instanceCount;
        if (ptr) ++activeCount;
    }
    
    ~TrackedPtr() {
        --instanceCount;
        if (ptr) {
            --activeCount;
            delete ptr;
        }
    }
    
    // 禁用拷贝
    TrackedPtr(const TrackedPtr&) = delete;
    TrackedPtr& operator=(const TrackedPtr&) = delete;
    
    // 允许移动
    TrackedPtr(TrackedPtr&& other) noexcept : ptr(other.ptr) {
        other.ptr = nullptr;
    }
    
    TrackedPtr& operator=(TrackedPtr&& other) noexcept {
        if (this != &other) {
            if (ptr) {
                --activeCount;
                delete ptr;
            }
            ptr = other.ptr;
            other.ptr = nullptr;
        }
        return *this;
    }
    
    T& operator*() const { return *ptr; }
    T* operator->() const { return ptr; }
    T* get() const { return ptr; }
    explicit operator bool() const { return ptr != nullptr; }
    
    static size_t getInstanceCount() { return instanceCount; }
    static size_t getActiveCount() { return activeCount; }
    
    static void report() {
        std::cout << "TrackedPtr instances: " << instanceCount << std::endl;
        std::cout << "Active pointers: " << activeCount << std::endl;
    }

private:
    T* ptr;
    static std::atomic<size_t> instanceCount;
    static std::atomic<size_t> activeCount;
};

template<typename T>
std::atomic<size_t> TrackedPtr<T>::instanceCount{0};

template<typename T>
std::atomic<size_t> TrackedPtr<T>::activeCount{0};

int main() {
    {
        TrackedPtr<int> p1(new int(42));
        TrackedPtr<int> p2(new int(100));
        
        TrackedPtr<int>::report();
        
        TrackedPtr<int> p3 = std::move(p1);
    }
    
    std::cout << "\nAfter scope:" << std::endl;
    TrackedPtr<int>::report();
    
    return 0;
}
```

---

## 5. 调试技巧

### 5.1 断言和检查

```cpp
#include <iostream>
#include <cassert>
#include <stdexcept>

// 调试断言
#define DEBUG_ASSERT(condition, message) \
    do { \
        if (!(condition)) { \
            std::cerr << "Assertion failed: " << message << std::endl; \
            std::cerr << "  File: " << __FILE__ << std::endl; \
            std::cerr << "  Line: " << __LINE__ << std::endl; \
            std::abort(); \
        } \
    } while (0)

// 边界检查数组
template<typename T, size_t N>
class SafeArray {
public:
    T& operator[](size_t index) {
        if (index >= N) {
            throw std::out_of_range("Array index out of bounds");
        }
        return data[index];
    }
    
    const T& operator[](size_t index) const {
        if (index >= N) {
            throw std::out_of_range("Array index out of bounds");
        }
        return data[index];
    }
    
    size_t size() const { return N; }

private:
    T data[N];
};

int main() {
    SafeArray<int, 5> arr;
    
    for (size_t i = 0; i < arr.size(); ++i) {
        arr[i] = i * 10;
    }
    
    try {
        arr[10] = 100;  // 抛出异常
    } catch (const std::out_of_range& e) {
        std::cout << "Caught: " << e.what() << std::endl;
    }
    
    int* ptr = new int(42);
    DEBUG_ASSERT(ptr != nullptr, "Memory allocation failed");
    delete ptr;
    
    return 0;
}
```

### 5.2 内存填充

```cpp
#include <iostream>
#include <cstring>

// 调试模式下的内存填充
class DebugAllocator {
public:
    static constexpr unsigned char ALLOC_PATTERN = 0xCD;  // 已分配
    static constexpr unsigned char FREE_PATTERN = 0xDD;   // 已释放
    static constexpr unsigned char GUARD_PATTERN = 0xFD;  // 边界保护
    
    static void* allocate(size_t size) {
        // 添加前后保护区
        size_t totalSize = size + 2 * GUARD_SIZE;
        char* memory = static_cast<char*>(std::malloc(totalSize));
        
        if (!memory) return nullptr;
        
        // 填充保护区
        std::memset(memory, GUARD_PATTERN, GUARD_SIZE);
        std::memset(memory + GUARD_SIZE + size, GUARD_PATTERN, GUARD_SIZE);
        
        // 填充用户区域
        char* userPtr = memory + GUARD_SIZE;
        std::memset(userPtr, ALLOC_PATTERN, size);
        
        return userPtr;
    }
    
    static void deallocate(void* ptr, size_t size) {
        if (!ptr) return;
        
        char* memory = static_cast<char*>(ptr) - GUARD_SIZE;
        
        // 检查保护区
        checkGuard(memory, "前保护区");
        checkGuard(static_cast<char*>(ptr) + size, "后保护区");
        
        // 填充已释放模式
        std::memset(ptr, FREE_PATTERN, size);
        
        std::free(memory);
    }

private:
    static constexpr size_t GUARD_SIZE = 8;
    
    static void checkGuard(const char* guard, const char* name) {
        for (size_t i = 0; i < GUARD_SIZE; ++i) {
            if (static_cast<unsigned char>(guard[i]) != GUARD_PATTERN) {
                std::cerr << "Guard corruption detected in " << name << std::endl;
                std::abort();
            }
        }
    }
};

int main() {
    int* p = static_cast<int*>(DebugAllocator::allocate(sizeof(int) * 5));
    
    for (int i = 0; i < 5; ++i) {
        p[i] = i * 10;
    }
    
    // p[10] = 100;  // 这会破坏保护区
    
    DebugAllocator::deallocate(p, sizeof(int) * 5);
    
    std::cout << "Memory operations completed successfully" << std::endl;
    
    return 0;
}
```

### 5.3 GDB 调试

```bash
# 编译带调试信息
g++ -g -O0 program.cpp -o program

# 启动 GDB
gdb ./program

# 常用命令
(gdb) break main          # 设置断点
(gdb) run                  # 运行程序
(gdb) next                 # 单步执行
(gdb) step                 # 进入函数
(gdb) print variable       # 打印变量
(gdb) x/10x ptr           # 查看内存
(gdb) backtrace           # 查看调用栈
(gdb) watch variable      # 监视变量
(gdb) continue            # 继续执行
(gdb) quit                # 退出

# 内存相关
(gdb) x/20b ptr           # 查看 20 字节
(gdb) x/10w ptr           # 查看 10 个字 (4 字节)
(gdb) x/s str             # 查看字符串
```

---

## 6. 总结

### 6.1 工具对比

| 工具 | 优点 | 缺点 | 适用场景 |
|------|------|------|---------|
| Valgrind | 全面,无需重编译 | 慢 (10-50x) | 开发测试 |
| ASan | 快 (2x),精确 | 需要重编译 | CI/CD |
| 自定义跟踪 | 可定制 | 需要维护 | 特殊需求 |

### 6.2 最佳实践

```
1. 开发时使用 ASan
2. 测试时使用 Valgrind
3. 使用智能指针
4. 启用编译器警告
5. 代码审查关注内存
6. 自动化内存测试
```

### 6.3 Part 3 完成

恭喜你完成了内存管理与指针进阶部分的全部 6 篇文章!

**实战项目建议**: 内存分配器
- 实现固定大小内存池
- 添加内存跟踪功能
- 支持多线程

### 6.4 下一篇预告

在下一篇文章中,我们将进入 STL 标准模板库部分,学习序列容器。

---

> 作者: C++ 技术专栏  
> 系列: 内存管理与指针进阶 (6/6)  
> 上一篇: [内存池与自定义分配器](./21-memory-pool.md)  
> 下一篇: [序列容器](../part4-stl/23-sequence-containers.md)
