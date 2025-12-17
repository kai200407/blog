---
title: "SIMD 与并行计算"
description: "1. [SIMD 概述](#1-simd-概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 54
---

> 本文是 C++ 从入门到精通系列的第五十四篇,也是系统编程与性能优化部分的收官之作。我们将深入讲解 SIMD 指令和并行计算技术。

---

## 目录

1. [SIMD 概述](#1-simd-概述)
2. [Intel Intrinsics](#2-intel-intrinsics)
3. [自动向量化](#3-自动向量化)
4. [OpenMP 并行](#4-openmp-并行)
5. [GPU 计算简介](#5-gpu-计算简介)
6. [总结](#6-总结)

---

## 1. SIMD 概述

### 1.1 什么是 SIMD

```
SIMD (Single Instruction, Multiple Data):
- 单条指令处理多个数据
- 数据并行
- 向量化计算

指令集:
- SSE: 128 位寄存器 (4 个 float)
- AVX: 256 位寄存器 (8 个 float)
- AVX-512: 512 位寄存器 (16 个 float)

应用场景:
- 图像处理
- 音视频编解码
- 科学计算
- 机器学习
```

### 1.2 数据类型

```cpp
#include <immintrin.h>

// SSE 类型 (128 位)
__m128  // 4 个 float
__m128d // 2 个 double
__m128i // 整数 (4x32, 8x16, 16x8)

// AVX 类型 (256 位)
__m256  // 8 个 float
__m256d // 4 个 double
__m256i // 整数 (8x32, 16x16, 32x8)

// AVX-512 类型 (512 位)
__m512  // 16 个 float
__m512d // 8 个 double
__m512i // 整数
```

---

## 2. Intel Intrinsics

### 2.1 基本操作

```cpp
#include <iostream>
#include <immintrin.h>

void basicOperations() {
    // 加载数据
    float a[8] = {1, 2, 3, 4, 5, 6, 7, 8};
    float b[8] = {8, 7, 6, 5, 4, 3, 2, 1};
    float c[8];
    
    __m256 va = _mm256_loadu_ps(a);  // 非对齐加载
    __m256 vb = _mm256_loadu_ps(b);
    
    // 算术运算
    __m256 sum = _mm256_add_ps(va, vb);
    __m256 diff = _mm256_sub_ps(va, vb);
    __m256 prod = _mm256_mul_ps(va, vb);
    __m256 quot = _mm256_div_ps(va, vb);
    
    // 存储结果
    _mm256_storeu_ps(c, sum);
    
    std::cout << "Sum: ";
    for (int i = 0; i < 8; ++i) {
        std::cout << c[i] << " ";
    }
    std::cout << std::endl;
    
    // 融合乘加 (FMA)
    __m256 fma = _mm256_fmadd_ps(va, vb, sum);  // a * b + sum
    
    // 比较
    __m256 mask = _mm256_cmp_ps(va, vb, _CMP_GT_OQ);  // a > b
    
    // 选择
    __m256 selected = _mm256_blendv_ps(vb, va, mask);  // mask ? a : b
}

void horizontalSum() {
    float data[8] = {1, 2, 3, 4, 5, 6, 7, 8};
    __m256 v = _mm256_loadu_ps(data);
    
    // 水平求和
    __m256 sum1 = _mm256_hadd_ps(v, v);
    __m256 sum2 = _mm256_hadd_ps(sum1, sum1);
    
    // 提取高低 128 位
    __m128 low = _mm256_castps256_ps128(sum2);
    __m128 high = _mm256_extractf128_ps(sum2, 1);
    __m128 total = _mm_add_ps(low, high);
    
    float result = _mm_cvtss_f32(total);
    std::cout << "Horizontal sum: " << result << std::endl;
}

int main() {
    basicOperations();
    horizontalSum();
    return 0;
}
```

### 2.2 向量化数组操作

```cpp
#include <iostream>
#include <vector>
#include <chrono>
#include <immintrin.h>
#include <cmath>

// 标量版本
void scalarSqrt(const float* input, float* output, size_t n) {
    for (size_t i = 0; i < n; ++i) {
        output[i] = std::sqrt(input[i]);
    }
}

// SIMD 版本
void simdSqrt(const float* input, float* output, size_t n) {
    size_t i = 0;
    
    for (; i + 8 <= n; i += 8) {
        __m256 v = _mm256_loadu_ps(input + i);
        __m256 result = _mm256_sqrt_ps(v);
        _mm256_storeu_ps(output + i, result);
    }
    
    for (; i < n; ++i) {
        output[i] = std::sqrt(input[i]);
    }
}

// 向量归一化
void normalizeVectors(float* vectors, size_t count, size_t dim) {
    for (size_t i = 0; i < count; ++i) {
        float* vec = vectors + i * dim;
        
        // 计算长度
        __m256 sum = _mm256_setzero_ps();
        size_t j = 0;
        
        for (; j + 8 <= dim; j += 8) {
            __m256 v = _mm256_loadu_ps(vec + j);
            sum = _mm256_fmadd_ps(v, v, sum);
        }
        
        // 水平求和
        float temp[8];
        _mm256_storeu_ps(temp, sum);
        float length = 0;
        for (int k = 0; k < 8; ++k) length += temp[k];
        for (; j < dim; ++j) length += vec[j] * vec[j];
        length = std::sqrt(length);
        
        // 归一化
        __m256 invLen = _mm256_set1_ps(1.0f / length);
        j = 0;
        
        for (; j + 8 <= dim; j += 8) {
            __m256 v = _mm256_loadu_ps(vec + j);
            v = _mm256_mul_ps(v, invLen);
            _mm256_storeu_ps(vec + j, v);
        }
        
        for (; j < dim; ++j) {
            vec[j] /= length;
        }
    }
}

int main() {
    const size_t N = 10000000;
    std::vector<float> input(N), output(N);
    
    for (size_t i = 0; i < N; ++i) {
        input[i] = static_cast<float>(i + 1);
    }
    
    auto start = std::chrono::high_resolution_clock::now();
    scalarSqrt(input.data(), output.data(), N);
    auto end = std::chrono::high_resolution_clock::now();
    std::cout << "Scalar sqrt: " 
              << std::chrono::duration<double, std::milli>(end - start).count() 
              << " ms" << std::endl;
    
    start = std::chrono::high_resolution_clock::now();
    simdSqrt(input.data(), output.data(), N);
    end = std::chrono::high_resolution_clock::now();
    std::cout << "SIMD sqrt: " 
              << std::chrono::duration<double, std::milli>(end - start).count() 
              << " ms" << std::endl;
    
    return 0;
}
```

### 2.3 矩阵乘法

```cpp
#include <iostream>
#include <vector>
#include <chrono>
#include <immintrin.h>

// 标量矩阵乘法
void matmulScalar(const float* A, const float* B, float* C, int N) {
    for (int i = 0; i < N; ++i) {
        for (int j = 0; j < N; ++j) {
            float sum = 0;
            for (int k = 0; k < N; ++k) {
                sum += A[i * N + k] * B[k * N + j];
            }
            C[i * N + j] = sum;
        }
    }
}

// SIMD 矩阵乘法 (简化版)
void matmulSIMD(const float* A, const float* B, float* C, int N) {
    for (int i = 0; i < N; ++i) {
        for (int j = 0; j < N; j += 8) {
            __m256 sum = _mm256_setzero_ps();
            
            for (int k = 0; k < N; ++k) {
                __m256 a = _mm256_set1_ps(A[i * N + k]);
                __m256 b = _mm256_loadu_ps(&B[k * N + j]);
                sum = _mm256_fmadd_ps(a, b, sum);
            }
            
            _mm256_storeu_ps(&C[i * N + j], sum);
        }
    }
}

int main() {
    const int N = 512;
    std::vector<float> A(N * N), B(N * N), C(N * N);
    
    for (int i = 0; i < N * N; ++i) {
        A[i] = static_cast<float>(rand()) / RAND_MAX;
        B[i] = static_cast<float>(rand()) / RAND_MAX;
    }
    
    auto start = std::chrono::high_resolution_clock::now();
    matmulScalar(A.data(), B.data(), C.data(), N);
    auto end = std::chrono::high_resolution_clock::now();
    std::cout << "Scalar matmul: " 
              << std::chrono::duration<double, std::milli>(end - start).count() 
              << " ms" << std::endl;
    
    start = std::chrono::high_resolution_clock::now();
    matmulSIMD(A.data(), B.data(), C.data(), N);
    end = std::chrono::high_resolution_clock::now();
    std::cout << "SIMD matmul: " 
              << std::chrono::duration<double, std::milli>(end - start).count() 
              << " ms" << std::endl;
    
    return 0;
}
```

---

## 3. 自动向量化

### 3.1 编译器自动向量化

```cpp
#include <iostream>
#include <vector>

// 编译器可以自动向量化的代码
void autoVectorizable(float* a, float* b, float* c, size_t n) {
    for (size_t i = 0; i < n; ++i) {
        c[i] = a[i] + b[i];
    }
}

// 使用 restrict 帮助编译器
void withRestrict(float* __restrict a, float* __restrict b, 
                  float* __restrict c, size_t n) {
    for (size_t i = 0; i < n; ++i) {
        c[i] = a[i] * b[i] + 1.0f;
    }
}

// 使用 pragma 提示
void withPragma(float* a, float* b, float* c, size_t n) {
    #pragma omp simd
    for (size_t i = 0; i < n; ++i) {
        c[i] = a[i] + b[i];
    }
}

// GCC 向量化提示
void gccVectorize(float* a, float* b, float* c, size_t n) {
    #pragma GCC ivdep
    for (size_t i = 0; i < n; ++i) {
        c[i] = a[i] + b[i];
    }
}

int main() {
    // 编译: g++ -O3 -march=native -fopt-info-vec program.cpp
    return 0;
}
```

### 3.2 向量化障碍

```cpp
#include <iostream>
#include <vector>

// 无法向量化: 数据依赖
void dataDependency(float* a, size_t n) {
    for (size_t i = 1; i < n; ++i) {
        a[i] = a[i-1] + 1.0f;  // 依赖前一个元素
    }
}

// 无法向量化: 函数调用
void withFunctionCall(float* a, float* b, size_t n) {
    for (size_t i = 0; i < n; ++i) {
        b[i] = std::sin(a[i]);  // 可能无法向量化
    }
}

// 无法向量化: 条件分支
void withBranch(float* a, float* b, size_t n) {
    for (size_t i = 0; i < n; ++i) {
        if (a[i] > 0) {
            b[i] = a[i] * 2;
        } else {
            b[i] = a[i] * -1;
        }
    }
}

// 可以向量化: 使用条件表达式
void withConditional(float* a, float* b, size_t n) {
    for (size_t i = 0; i < n; ++i) {
        b[i] = (a[i] > 0) ? a[i] * 2 : a[i] * -1;
    }
}

int main() {
    return 0;
}
```

---

## 4. OpenMP 并行

### 4.1 基本并行

```cpp
#include <iostream>
#include <vector>
#include <chrono>
#include <omp.h>

void parallelFor() {
    const int N = 100000000;
    std::vector<double> data(N);
    
    // 串行
    auto start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < N; ++i) {
        data[i] = std::sin(i * 0.001);
    }
    auto end = std::chrono::high_resolution_clock::now();
    std::cout << "Serial: " 
              << std::chrono::duration<double, std::milli>(end - start).count() 
              << " ms" << std::endl;
    
    // 并行
    start = std::chrono::high_resolution_clock::now();
    #pragma omp parallel for
    for (int i = 0; i < N; ++i) {
        data[i] = std::sin(i * 0.001);
    }
    end = std::chrono::high_resolution_clock::now();
    std::cout << "Parallel: " 
              << std::chrono::duration<double, std::milli>(end - start).count() 
              << " ms" << std::endl;
}

void parallelReduce() {
    const int N = 100000000;
    std::vector<double> data(N);
    
    for (int i = 0; i < N; ++i) {
        data[i] = 1.0 / (i + 1);
    }
    
    double sum = 0;
    
    #pragma omp parallel for reduction(+:sum)
    for (int i = 0; i < N; ++i) {
        sum += data[i];
    }
    
    std::cout << "Sum: " << sum << std::endl;
}

int main() {
    std::cout << "Threads: " << omp_get_max_threads() << std::endl;
    
    parallelFor();
    parallelReduce();
    
    return 0;
}
```

### 4.2 任务并行

```cpp
#include <iostream>
#include <vector>
#include <omp.h>

// 并行归并排序
void parallelMergeSort(int* arr, int* temp, int left, int right) {
    if (right - left < 1000) {
        // 小数组使用串行排序
        std::sort(arr + left, arr + right + 1);
        return;
    }
    
    int mid = (left + right) / 2;
    
    #pragma omp task shared(arr, temp)
    parallelMergeSort(arr, temp, left, mid);
    
    #pragma omp task shared(arr, temp)
    parallelMergeSort(arr, temp, mid + 1, right);
    
    #pragma omp taskwait
    
    // 合并
    int i = left, j = mid + 1, k = left;
    while (i <= mid && j <= right) {
        if (arr[i] <= arr[j]) {
            temp[k++] = arr[i++];
        } else {
            temp[k++] = arr[j++];
        }
    }
    while (i <= mid) temp[k++] = arr[i++];
    while (j <= right) temp[k++] = arr[j++];
    
    for (int i = left; i <= right; ++i) {
        arr[i] = temp[i];
    }
}

void sortExample() {
    const int N = 10000000;
    std::vector<int> data(N), temp(N);
    
    for (int i = 0; i < N; ++i) {
        data[i] = rand();
    }
    
    #pragma omp parallel
    {
        #pragma omp single
        parallelMergeSort(data.data(), temp.data(), 0, N - 1);
    }
    
    // 验证
    bool sorted = std::is_sorted(data.begin(), data.end());
    std::cout << "Sorted: " << (sorted ? "yes" : "no") << std::endl;
}

int main() {
    sortExample();
    return 0;
}
```

### 4.3 SIMD + OpenMP

```cpp
#include <iostream>
#include <vector>
#include <chrono>
#include <omp.h>
#include <immintrin.h>

void hybridParallel(const float* a, const float* b, float* c, size_t n) {
    #pragma omp parallel for
    for (size_t i = 0; i < n; i += 8) {
        __m256 va = _mm256_loadu_ps(a + i);
        __m256 vb = _mm256_loadu_ps(b + i);
        __m256 vc = _mm256_add_ps(va, vb);
        _mm256_storeu_ps(c + i, vc);
    }
}

void hybridDotProduct(const float* a, const float* b, size_t n, float& result) {
    float partialSums[64] = {0};  // 假设最多 64 个线程
    
    #pragma omp parallel
    {
        int tid = omp_get_thread_num();
        __m256 sum = _mm256_setzero_ps();
        
        #pragma omp for nowait
        for (size_t i = 0; i < n; i += 8) {
            __m256 va = _mm256_loadu_ps(a + i);
            __m256 vb = _mm256_loadu_ps(b + i);
            sum = _mm256_fmadd_ps(va, vb, sum);
        }
        
        // 水平求和
        float temp[8];
        _mm256_storeu_ps(temp, sum);
        for (int i = 0; i < 8; ++i) {
            partialSums[tid] += temp[i];
        }
    }
    
    result = 0;
    for (int i = 0; i < omp_get_max_threads(); ++i) {
        result += partialSums[i];
    }
}

int main() {
    const size_t N = 100000000;
    std::vector<float> a(N), b(N), c(N);
    
    for (size_t i = 0; i < N; ++i) {
        a[i] = 1.0f;
        b[i] = 2.0f;
    }
    
    auto start = std::chrono::high_resolution_clock::now();
    hybridParallel(a.data(), b.data(), c.data(), N);
    auto end = std::chrono::high_resolution_clock::now();
    std::cout << "Hybrid parallel add: " 
              << std::chrono::duration<double, std::milli>(end - start).count() 
              << " ms" << std::endl;
    
    float dot;
    start = std::chrono::high_resolution_clock::now();
    hybridDotProduct(a.data(), b.data(), N, dot);
    end = std::chrono::high_resolution_clock::now();
    std::cout << "Hybrid dot product: " 
              << std::chrono::duration<double, std::milli>(end - start).count() 
              << " ms, result = " << dot << std::endl;
    
    return 0;
}
```

---

## 5. GPU 计算简介

### 5.1 CUDA 基础

```cpp
// CUDA 示例 (需要 NVIDIA GPU 和 CUDA 工具包)

// kernel.cu
__global__ void vectorAdd(const float* a, const float* b, float* c, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        c[i] = a[i] + b[i];
    }
}

void cudaVectorAdd(const float* h_a, const float* h_b, float* h_c, int n) {
    float *d_a, *d_b, *d_c;
    size_t size = n * sizeof(float);
    
    // 分配设备内存
    cudaMalloc(&d_a, size);
    cudaMalloc(&d_b, size);
    cudaMalloc(&d_c, size);
    
    // 复制数据到设备
    cudaMemcpy(d_a, h_a, size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_b, h_b, size, cudaMemcpyHostToDevice);
    
    // 启动 kernel
    int blockSize = 256;
    int numBlocks = (n + blockSize - 1) / blockSize;
    vectorAdd<<<numBlocks, blockSize>>>(d_a, d_b, d_c, n);
    
    // 复制结果回主机
    cudaMemcpy(h_c, d_c, size, cudaMemcpyDeviceToHost);
    
    // 释放设备内存
    cudaFree(d_a);
    cudaFree(d_b);
    cudaFree(d_c);
}
```

### 5.2 OpenCL 基础

```cpp
// OpenCL 示例 (跨平台 GPU 计算)

#include <CL/cl.hpp>
#include <iostream>
#include <vector>

const char* kernelSource = R"(
__kernel void vectorAdd(__global const float* a,
                        __global const float* b,
                        __global float* c,
                        int n) {
    int i = get_global_id(0);
    if (i < n) {
        c[i] = a[i] + b[i];
    }
}
)";

void openclVectorAdd() {
    const int N = 1000000;
    std::vector<float> a(N, 1.0f), b(N, 2.0f), c(N);
    
    // 获取平台和设备
    std::vector<cl::Platform> platforms;
    cl::Platform::get(&platforms);
    
    std::vector<cl::Device> devices;
    platforms[0].getDevices(CL_DEVICE_TYPE_GPU, &devices);
    
    // 创建上下文和命令队列
    cl::Context context(devices);
    cl::CommandQueue queue(context, devices[0]);
    
    // 创建缓冲区
    cl::Buffer bufA(context, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR,
                    N * sizeof(float), a.data());
    cl::Buffer bufB(context, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR,
                    N * sizeof(float), b.data());
    cl::Buffer bufC(context, CL_MEM_WRITE_ONLY, N * sizeof(float));
    
    // 编译 kernel
    cl::Program program(context, kernelSource);
    program.build(devices);
    
    cl::Kernel kernel(program, "vectorAdd");
    kernel.setArg(0, bufA);
    kernel.setArg(1, bufB);
    kernel.setArg(2, bufC);
    kernel.setArg(3, N);
    
    // 执行
    queue.enqueueNDRangeKernel(kernel, cl::NullRange, cl::NDRange(N));
    
    // 读取结果
    queue.enqueueReadBuffer(bufC, CL_TRUE, 0, N * sizeof(float), c.data());
    
    std::cout << "c[0] = " << c[0] << std::endl;
}
```

---

## 6. 总结

### 6.1 SIMD 指令集

| 指令集 | 寄存器宽度 | float 数量 |
|--------|-----------|-----------|
| SSE | 128 位 | 4 |
| AVX | 256 位 | 8 |
| AVX-512 | 512 位 | 16 |

### 6.2 并行技术对比

| 技术 | 适用场景 | 特点 |
|------|---------|------|
| SIMD | 数据并行 | 单线程向量化 |
| OpenMP | 任务并行 | 多线程 |
| CUDA/OpenCL | 大规模并行 | GPU 加速 |

### 6.3 Part 8 完成

恭喜你完成了系统编程与性能优化部分的全部 4 篇文章!

**实战项目建议**: 高性能图像处理库
- 使用 SIMD 优化滤波器
- 使用 OpenMP 并行处理
- 实现常用图像算法

### 6.4 下一篇预告

在下一篇文章中,我们将进入工程实践部分,学习 CMake 构建系统。

---

> 作者: C++ 技术专栏  
> 系列: 系统编程与性能优化 (4/4)  
> 上一篇: [性能分析与优化](./53-performance.md)  
> 下一篇: [CMake 构建系统](../part9-engineering/55-cmake.md)
