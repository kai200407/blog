---
title: "性能分析与优化"
description: "1. [性能分析概述](#1-性能分析概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 53
---

> 本文是 C++ 从入门到精通系列的第五十三篇,将深入讲解性能分析工具和优化技术。

---

## 目录

1. [性能分析概述](#1-性能分析概述)
2. [性能分析工具](#2-性能分析工具)
3. [CPU 优化](#3-cpu-优化)
4. [内存优化](#4-内存优化)
5. [编译器优化](#5-编译器优化)
6. [总结](#6-总结)

---

## 1. 性能分析概述

### 1.1 性能指标

```
关键性能指标:

时间指标:
- 延迟 (Latency): 单次操作耗时
- 吞吐量 (Throughput): 单位时间处理量
- 响应时间: 请求到响应的时间

资源指标:
- CPU 使用率
- 内存使用量
- I/O 带宽
- 缓存命中率
```

### 1.2 优化原则

```
优化原则:

1. 先测量,后优化
   - 不要猜测瓶颈
   - 使用工具定位问题

2. 优化热点代码
   - 80/20 法则
   - 关注关键路径

3. 算法优先
   - O(n) vs O(n^2)
   - 选择正确的数据结构

4. 避免过早优化
   - 先保证正确性
   - 可读性优先
```

---

## 2. 性能分析工具

### 2.1 时间测量

```cpp
#include <iostream>
#include <chrono>
#include <vector>
#include <algorithm>

class Timer {
public:
    Timer() : start(std::chrono::high_resolution_clock::now()) { }
    
    double elapsed() const {
        auto end = std::chrono::high_resolution_clock::now();
        return std::chrono::duration<double, std::milli>(end - start).count();
    }
    
    void reset() {
        start = std::chrono::high_resolution_clock::now();
    }

private:
    std::chrono::high_resolution_clock::time_point start;
};

// RAII 计时器
class ScopedTimer {
public:
    ScopedTimer(const char* name) : name(name), start(std::chrono::high_resolution_clock::now()) { }
    
    ~ScopedTimer() {
        auto end = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration<double, std::milli>(end - start).count();
        std::cout << name << ": " << duration << " ms" << std::endl;
    }

private:
    const char* name;
    std::chrono::high_resolution_clock::time_point start;
};

void benchmark() {
    const int N = 1000000;
    std::vector<int> data(N);
    
    {
        ScopedTimer timer("Fill");
        for (int i = 0; i < N; ++i) {
            data[i] = rand();
        }
    }
    
    {
        ScopedTimer timer("Sort");
        std::sort(data.begin(), data.end());
    }
    
    {
        ScopedTimer timer("Binary search x1000");
        for (int i = 0; i < 1000; ++i) {
            std::binary_search(data.begin(), data.end(), rand());
        }
    }
}

int main() {
    benchmark();
    return 0;
}
```

### 2.2 perf 工具

```bash
# 编译带调试信息
g++ -O2 -g program.cpp -o program

# CPU 性能分析
perf stat ./program

# 采样分析
perf record -g ./program
perf report

# 火焰图
perf record -F 99 -g ./program
perf script | stackcollapse-perf.pl | flamegraph.pl > flame.svg
```

### 2.3 Valgrind

```bash
# 内存检查
valgrind --leak-check=full ./program

# 缓存分析
valgrind --tool=cachegrind ./program
cg_annotate cachegrind.out.*

# 调用图
valgrind --tool=callgrind ./program
kcachegrind callgrind.out.*
```

### 2.4 简单性能计数器

```cpp
#include <iostream>
#include <map>
#include <string>
#include <chrono>

class Profiler {
public:
    static Profiler& instance() {
        static Profiler profiler;
        return profiler;
    }
    
    void start(const std::string& name) {
        starts[name] = std::chrono::high_resolution_clock::now();
        counts[name]++;
    }
    
    void stop(const std::string& name) {
        auto end = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration<double, std::micro>(end - starts[name]).count();
        totals[name] += duration;
    }
    
    void report() {
        std::cout << "\n=== Performance Report ===" << std::endl;
        for (const auto& [name, total] : totals) {
            std::cout << name << ": " 
                      << total / 1000.0 << " ms total, "
                      << counts[name] << " calls, "
                      << total / counts[name] << " us/call" << std::endl;
        }
    }

private:
    std::map<std::string, std::chrono::high_resolution_clock::time_point> starts;
    std::map<std::string, double> totals;
    std::map<std::string, int> counts;
};

#define PROFILE_SCOPE(name) \
    Profiler::instance().start(name); \
    struct ScopeGuard##__LINE__ { \
        const char* n; \
        ScopeGuard##__LINE__(const char* name) : n(name) {} \
        ~ScopeGuard##__LINE__() { Profiler::instance().stop(n); } \
    } guard##__LINE__(name)

void functionA() {
    PROFILE_SCOPE("functionA");
    // 模拟工作
    volatile int sum = 0;
    for (int i = 0; i < 100000; ++i) sum += i;
}

void functionB() {
    PROFILE_SCOPE("functionB");
    for (int i = 0; i < 10; ++i) {
        functionA();
    }
}

int main() {
    for (int i = 0; i < 5; ++i) {
        functionB();
    }
    
    Profiler::instance().report();
    return 0;
}
```

---

## 3. CPU 优化

### 3.1 缓存优化

```cpp
#include <iostream>
#include <chrono>
#include <vector>

// 缓存不友好: 列优先访问
void columnMajor(std::vector<std::vector<int>>& matrix) {
    int rows = matrix.size();
    int cols = matrix[0].size();
    
    for (int j = 0; j < cols; ++j) {
        for (int i = 0; i < rows; ++i) {
            matrix[i][j] *= 2;
        }
    }
}

// 缓存友好: 行优先访问
void rowMajor(std::vector<std::vector<int>>& matrix) {
    int rows = matrix.size();
    int cols = matrix[0].size();
    
    for (int i = 0; i < rows; ++i) {
        for (int j = 0; j < cols; ++j) {
            matrix[i][j] *= 2;
        }
    }
}

// 数据局部性优化
struct Point3D {
    float x, y, z;
};

// AoS (Array of Structures) - 缓存不友好
struct ParticlesAoS {
    std::vector<Point3D> positions;
    
    void update() {
        for (auto& p : positions) {
            p.x += 1.0f;
            p.y += 1.0f;
            p.z += 1.0f;
        }
    }
};

// SoA (Structure of Arrays) - 缓存友好
struct ParticlesSoA {
    std::vector<float> x, y, z;
    
    void update() {
        for (size_t i = 0; i < x.size(); ++i) {
            x[i] += 1.0f;
        }
        for (size_t i = 0; i < y.size(); ++i) {
            y[i] += 1.0f;
        }
        for (size_t i = 0; i < z.size(); ++i) {
            z[i] += 1.0f;
        }
    }
};

int main() {
    const int SIZE = 2000;
    std::vector<std::vector<int>> matrix(SIZE, std::vector<int>(SIZE, 1));
    
    auto start = std::chrono::high_resolution_clock::now();
    columnMajor(matrix);
    auto end = std::chrono::high_resolution_clock::now();
    std::cout << "Column major: " 
              << std::chrono::duration<double, std::milli>(end - start).count() 
              << " ms" << std::endl;
    
    start = std::chrono::high_resolution_clock::now();
    rowMajor(matrix);
    end = std::chrono::high_resolution_clock::now();
    std::cout << "Row major: " 
              << std::chrono::duration<double, std::milli>(end - start).count() 
              << " ms" << std::endl;
    
    return 0;
}
```

### 3.2 分支预测

```cpp
#include <iostream>
#include <vector>
#include <algorithm>
#include <chrono>

void branchPrediction() {
    const int SIZE = 10000000;
    std::vector<int> data(SIZE);
    
    for (int i = 0; i < SIZE; ++i) {
        data[i] = rand() % 256;
    }
    
    // 未排序: 分支预测失败率高
    auto start = std::chrono::high_resolution_clock::now();
    long sum = 0;
    for (int i = 0; i < SIZE; ++i) {
        if (data[i] >= 128) {
            sum += data[i];
        }
    }
    auto end = std::chrono::high_resolution_clock::now();
    std::cout << "Unsorted: " 
              << std::chrono::duration<double, std::milli>(end - start).count() 
              << " ms, sum = " << sum << std::endl;
    
    // 排序后: 分支预测成功率高
    std::sort(data.begin(), data.end());
    
    start = std::chrono::high_resolution_clock::now();
    sum = 0;
    for (int i = 0; i < SIZE; ++i) {
        if (data[i] >= 128) {
            sum += data[i];
        }
    }
    end = std::chrono::high_resolution_clock::now();
    std::cout << "Sorted: " 
              << std::chrono::duration<double, std::milli>(end - start).count() 
              << " ms, sum = " << sum << std::endl;
    
    // 无分支版本
    start = std::chrono::high_resolution_clock::now();
    sum = 0;
    for (int i = 0; i < SIZE; ++i) {
        sum += (data[i] >= 128) * data[i];
    }
    end = std::chrono::high_resolution_clock::now();
    std::cout << "Branchless: " 
              << std::chrono::duration<double, std::milli>(end - start).count() 
              << " ms, sum = " << sum << std::endl;
}

int main() {
    branchPrediction();
    return 0;
}
```

### 3.3 SIMD 优化

```cpp
#include <iostream>
#include <vector>
#include <chrono>
#include <immintrin.h>

// 标量版本
void addArraysScalar(const float* a, const float* b, float* c, size_t n) {
    for (size_t i = 0; i < n; ++i) {
        c[i] = a[i] + b[i];
    }
}

// SIMD 版本 (AVX)
void addArraysSIMD(const float* a, const float* b, float* c, size_t n) {
    size_t i = 0;
    
    // 处理 8 个 float 一组
    for (; i + 8 <= n; i += 8) {
        __m256 va = _mm256_loadu_ps(a + i);
        __m256 vb = _mm256_loadu_ps(b + i);
        __m256 vc = _mm256_add_ps(va, vb);
        _mm256_storeu_ps(c + i, vc);
    }
    
    // 处理剩余元素
    for (; i < n; ++i) {
        c[i] = a[i] + b[i];
    }
}

// 点积
float dotProductScalar(const float* a, const float* b, size_t n) {
    float sum = 0;
    for (size_t i = 0; i < n; ++i) {
        sum += a[i] * b[i];
    }
    return sum;
}

float dotProductSIMD(const float* a, const float* b, size_t n) {
    __m256 sum = _mm256_setzero_ps();
    size_t i = 0;
    
    for (; i + 8 <= n; i += 8) {
        __m256 va = _mm256_loadu_ps(a + i);
        __m256 vb = _mm256_loadu_ps(b + i);
        sum = _mm256_fmadd_ps(va, vb, sum);
    }
    
    // 水平求和
    float result[8];
    _mm256_storeu_ps(result, sum);
    float total = result[0] + result[1] + result[2] + result[3] +
                  result[4] + result[5] + result[6] + result[7];
    
    for (; i < n; ++i) {
        total += a[i] * b[i];
    }
    
    return total;
}

int main() {
    const size_t N = 10000000;
    std::vector<float> a(N), b(N), c(N);
    
    for (size_t i = 0; i < N; ++i) {
        a[i] = static_cast<float>(i);
        b[i] = static_cast<float>(i * 2);
    }
    
    auto start = std::chrono::high_resolution_clock::now();
    addArraysScalar(a.data(), b.data(), c.data(), N);
    auto end = std::chrono::high_resolution_clock::now();
    std::cout << "Scalar add: " 
              << std::chrono::duration<double, std::milli>(end - start).count() 
              << " ms" << std::endl;
    
    start = std::chrono::high_resolution_clock::now();
    addArraysSIMD(a.data(), b.data(), c.data(), N);
    end = std::chrono::high_resolution_clock::now();
    std::cout << "SIMD add: " 
              << std::chrono::duration<double, std::milli>(end - start).count() 
              << " ms" << std::endl;
    
    return 0;
}
```

---

## 4. 内存优化

### 4.1 内存池

```cpp
#include <iostream>
#include <vector>
#include <chrono>

template<typename T, size_t BlockSize = 4096>
class MemoryPool {
public:
    MemoryPool() : currentBlock(nullptr), currentSlot(nullptr), 
                   lastSlot(nullptr), freeSlots(nullptr) { }
    
    ~MemoryPool() {
        for (char* block : blocks) {
            delete[] block;
        }
    }
    
    T* allocate() {
        if (freeSlots != nullptr) {
            T* result = reinterpret_cast<T*>(freeSlots);
            freeSlots = freeSlots->next;
            return result;
        }
        
        if (currentSlot >= lastSlot) {
            allocateBlock();
        }
        
        return reinterpret_cast<T*>(currentSlot++);
    }
    
    void deallocate(T* p) {
        if (p != nullptr) {
            reinterpret_cast<Slot*>(p)->next = freeSlots;
            freeSlots = reinterpret_cast<Slot*>(p);
        }
    }

private:
    union Slot {
        T element;
        Slot* next;
    };
    
    void allocateBlock() {
        char* newBlock = new char[BlockSize];
        blocks.push_back(newBlock);
        
        currentBlock = newBlock;
        currentSlot = reinterpret_cast<Slot*>(newBlock);
        lastSlot = reinterpret_cast<Slot*>(newBlock + BlockSize - sizeof(Slot) + 1);
    }
    
    std::vector<char*> blocks;
    Slot* currentBlock;
    Slot* currentSlot;
    Slot* lastSlot;
    Slot* freeSlots;
};

struct TestObject {
    int data[4];
};

void benchmarkAllocation() {
    const int N = 1000000;
    
    // 标准 new/delete
    auto start = std::chrono::high_resolution_clock::now();
    std::vector<TestObject*> ptrs(N);
    for (int i = 0; i < N; ++i) {
        ptrs[i] = new TestObject;
    }
    for (int i = 0; i < N; ++i) {
        delete ptrs[i];
    }
    auto end = std::chrono::high_resolution_clock::now();
    std::cout << "new/delete: " 
              << std::chrono::duration<double, std::milli>(end - start).count() 
              << " ms" << std::endl;
    
    // 内存池
    MemoryPool<TestObject> pool;
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < N; ++i) {
        ptrs[i] = pool.allocate();
    }
    for (int i = 0; i < N; ++i) {
        pool.deallocate(ptrs[i]);
    }
    end = std::chrono::high_resolution_clock::now();
    std::cout << "Memory pool: " 
              << std::chrono::duration<double, std::milli>(end - start).count() 
              << " ms" << std::endl;
}

int main() {
    benchmarkAllocation();
    return 0;
}
```

### 4.2 避免内存碎片

```cpp
#include <iostream>
#include <vector>
#include <memory>

// 对象池
template<typename T>
class ObjectPool {
public:
    ObjectPool(size_t size) : pool(size), available(size) {
        for (size_t i = 0; i < size; ++i) {
            available[i] = &pool[i];
        }
        nextAvailable = size;
    }
    
    T* acquire() {
        if (nextAvailable == 0) {
            return nullptr;
        }
        return available[--nextAvailable];
    }
    
    void release(T* obj) {
        available[nextAvailable++] = obj;
    }

private:
    std::vector<T> pool;
    std::vector<T*> available;
    size_t nextAvailable;
};

// 预分配容器
void preallocateContainers() {
    std::vector<int> vec;
    
    // 预分配空间
    vec.reserve(1000000);
    
    // 避免多次重新分配
    for (int i = 0; i < 1000000; ++i) {
        vec.push_back(i);
    }
}

int main() {
    ObjectPool<int> pool(100);
    
    int* p1 = pool.acquire();
    int* p2 = pool.acquire();
    
    *p1 = 42;
    *p2 = 100;
    
    pool.release(p1);
    pool.release(p2);
    
    return 0;
}
```

---

## 5. 编译器优化

### 5.1 优化级别

```bash
# 优化级别
g++ -O0 program.cpp  # 无优化
g++ -O1 program.cpp  # 基本优化
g++ -O2 program.cpp  # 推荐优化
g++ -O3 program.cpp  # 激进优化
g++ -Os program.cpp  # 优化大小
g++ -Ofast program.cpp  # 最快 (可能不符合标准)

# 特定优化
g++ -march=native program.cpp  # 针对本机 CPU
g++ -mtune=native program.cpp  # 调优本机 CPU
g++ -flto program.cpp  # 链接时优化
g++ -ffast-math program.cpp  # 快速数学
```

### 5.2 编译器提示

```cpp
#include <iostream>

// 内联提示
inline int add(int a, int b) {
    return a + b;
}

// 强制内联
__attribute__((always_inline)) inline int multiply(int a, int b) {
    return a * b;
}

// 禁止内联
__attribute__((noinline)) int divide(int a, int b) {
    return a / b;
}

// 分支预测提示
void processValue(int value) {
    if (__builtin_expect(value > 0, 1)) {
        // 预期为真的分支
        std::cout << "Positive" << std::endl;
    } else {
        // 预期为假的分支
        std::cout << "Non-positive" << std::endl;
    }
}

// C++20 likely/unlikely
#if __cplusplus >= 202002L
void processValueCpp20(int value) {
    if (value > 0) [[likely]] {
        std::cout << "Positive" << std::endl;
    } else [[unlikely]] {
        std::cout << "Non-positive" << std::endl;
    }
}
#endif

// restrict 指针 (C99, 编译器扩展)
void addArrays(float* __restrict a, float* __restrict b, 
               float* __restrict c, size_t n) {
    for (size_t i = 0; i < n; ++i) {
        c[i] = a[i] + b[i];
    }
}

// 纯函数
__attribute__((pure)) int pureFunction(int x) {
    return x * x;
}

// 常量函数
__attribute__((const)) int constFunction(int x) {
    return x * 2;
}

int main() {
    processValue(10);
    return 0;
}
```

### 5.3 Profile-Guided Optimization

```bash
# 步骤 1: 生成插桩版本
g++ -O2 -fprofile-generate program.cpp -o program

# 步骤 2: 运行程序收集数据
./program

# 步骤 3: 使用收集的数据优化
g++ -O2 -fprofile-use program.cpp -o program_optimized
```

---

## 6. 总结

### 6.1 性能分析工具

| 工具 | 用途 |
|------|------|
| perf | CPU 性能分析 |
| Valgrind | 内存分析 |
| gprof | 函数调用分析 |
| Intel VTune | 全面性能分析 |

### 6.2 优化技术

| 技术 | 效果 |
|------|------|
| 缓存优化 | 减少缓存未命中 |
| SIMD | 并行数据处理 |
| 内存池 | 减少分配开销 |
| 分支预测 | 减少流水线停顿 |

### 6.3 下一篇预告

在下一篇文章中,我们将学习 SIMD 与并行计算。

---

> 作者: C++ 技术专栏  
> 系列: 系统编程与性能优化 (3/4)  
> 上一篇: [进程与信号](./52-process-signal.md)  
> 下一篇: [SIMD 与并行计算](./54-simd-parallel.md)
