---
title: "RAII 与资源管理"
description: "1. [RAII 概述](#1-raii-概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 19
---

> 本文是 C++ 从入门到精通系列的第十九篇,将深入讲解 RAII (Resource Acquisition Is Initialization) 原则和资源管理技术。

---

## 目录

1. [RAII 概述](#1-raii-概述)
2. [RAII 实现](#2-raii-实现)
3. [标准库中的 RAII](#3-标准库中的-raii)
4. [自定义 RAII 类](#4-自定义-raii-类)
5. [作用域守卫](#5-作用域守卫)
6. [总结](#6-总结)

---

## 1. RAII 概述

### 1.1 什么是 RAII

```
RAII (Resource Acquisition Is Initialization):
资源获取即初始化

核心思想:
1. 在构造函数中获取资源
2. 在析构函数中释放资源
3. 利用栈对象的生命周期自动管理资源

资源类型:
- 内存
- 文件句柄
- 网络连接
- 互斥锁
- 数据库连接
- 图形资源
```

### 1.2 RAII 的优势

```cpp
#include <iostream>
#include <fstream>
#include <mutex>

// 不使用 RAII: 容易出错
void badExample() {
    FILE* file = fopen("test.txt", "r");
    if (!file) return;
    
    // 如果这里抛出异常,文件不会被关闭
    // ...处理文件...
    
    fclose(file);  // 容易忘记
}

// 使用 RAII: 安全可靠
void goodExample() {
    std::ifstream file("test.txt");
    if (!file) return;
    
    // 即使抛出异常,文件也会被正确关闭
    // ...处理文件...
    
}  // 文件自动关闭

// 互斥锁示例
std::mutex mtx;

void badLocking() {
    mtx.lock();
    // 如果这里抛出异常,锁不会被释放 (死锁)
    // ...
    mtx.unlock();
}

void goodLocking() {
    std::lock_guard<std::mutex> lock(mtx);
    // 即使抛出异常,锁也会被正确释放
    // ...
}  // 锁自动释放
```

---

## 2. RAII 实现

### 2.1 基本 RAII 类

```cpp
#include <iostream>
#include <cstdio>

// 文件 RAII 包装
class FileHandle {
public:
    explicit FileHandle(const char* filename, const char* mode)
        : file(fopen(filename, mode)) {
        if (!file) {
            throw std::runtime_error("Failed to open file");
        }
        std::cout << "File opened" << std::endl;
    }
    
    ~FileHandle() {
        if (file) {
            fclose(file);
            std::cout << "File closed" << std::endl;
        }
    }
    
    // 禁用拷贝
    FileHandle(const FileHandle&) = delete;
    FileHandle& operator=(const FileHandle&) = delete;
    
    // 允许移动
    FileHandle(FileHandle&& other) noexcept : file(other.file) {
        other.file = nullptr;
    }
    
    FileHandle& operator=(FileHandle&& other) noexcept {
        if (this != &other) {
            if (file) fclose(file);
            file = other.file;
            other.file = nullptr;
        }
        return *this;
    }
    
    FILE* get() const { return file; }
    
    void write(const char* data) {
        if (file) {
            fprintf(file, "%s", data);
        }
    }
    
    explicit operator bool() const { return file != nullptr; }

private:
    FILE* file;
};

int main() {
    try {
        FileHandle file("output.txt", "w");
        file.write("Hello, RAII!\n");
        
        // 即使这里抛出异常,文件也会被正确关闭
        // throw std::runtime_error("Test exception");
        
    } catch (const std::exception& e) {
        std::cout << "Exception: " << e.what() << std::endl;
    }
    
    std::cout << "After try-catch" << std::endl;
    
    return 0;
}
```

### 2.2 内存 RAII

```cpp
#include <iostream>
#include <cstring>

// 简单的字符串 RAII 类
class MyString {
public:
    MyString() : data(nullptr), length(0) { }
    
    MyString(const char* str) {
        length = strlen(str);
        data = new char[length + 1];
        strcpy(data, str);
    }
    
    ~MyString() {
        delete[] data;
    }
    
    // 拷贝构造
    MyString(const MyString& other) {
        length = other.length;
        data = new char[length + 1];
        strcpy(data, other.data);
    }
    
    // 拷贝赋值
    MyString& operator=(const MyString& other) {
        if (this != &other) {
            delete[] data;
            length = other.length;
            data = new char[length + 1];
            strcpy(data, other.data);
        }
        return *this;
    }
    
    // 移动构造
    MyString(MyString&& other) noexcept
        : data(other.data), length(other.length) {
        other.data = nullptr;
        other.length = 0;
    }
    
    // 移动赋值
    MyString& operator=(MyString&& other) noexcept {
        if (this != &other) {
            delete[] data;
            data = other.data;
            length = other.length;
            other.data = nullptr;
            other.length = 0;
        }
        return *this;
    }
    
    const char* c_str() const { return data ? data : ""; }
    size_t size() const { return length; }

private:
    char* data;
    size_t length;
};

int main() {
    MyString s1("Hello");
    MyString s2 = s1;  // 拷贝
    MyString s3 = std::move(s1);  // 移动
    
    std::cout << "s2: " << s2.c_str() << std::endl;
    std::cout << "s3: " << s3.c_str() << std::endl;
    
    return 0;
}  // 自动释放所有内存
```

---

## 3. 标准库中的 RAII

### 3.1 智能指针

```cpp
#include <iostream>
#include <memory>

class Resource {
public:
    Resource() { std::cout << "Resource acquired" << std::endl; }
    ~Resource() { std::cout << "Resource released" << std::endl; }
    void use() { std::cout << "Resource used" << std::endl; }
};

int main() {
    // unique_ptr: 独占所有权
    {
        auto ptr = std::make_unique<Resource>();
        ptr->use();
    }  // 自动释放
    
    std::cout << "---" << std::endl;
    
    // shared_ptr: 共享所有权
    {
        auto ptr1 = std::make_shared<Resource>();
        {
            auto ptr2 = ptr1;
            ptr2->use();
        }  // ptr2 销毁,但资源不释放
        ptr1->use();
    }  // 最后一个 shared_ptr 销毁,资源释放
    
    return 0;
}
```

### 3.2 锁守卫

```cpp
#include <iostream>
#include <mutex>
#include <shared_mutex>
#include <thread>
#include <vector>

std::mutex mtx;
std::shared_mutex sharedMtx;
int counter = 0;

void incrementWithLockGuard() {
    std::lock_guard<std::mutex> lock(mtx);
    ++counter;
    // 锁自动释放
}

void incrementWithUniqueLock() {
    std::unique_lock<std::mutex> lock(mtx);
    ++counter;
    
    // unique_lock 更灵活
    lock.unlock();
    // 做一些不需要锁的工作
    lock.lock();
    ++counter;
}  // 锁自动释放

void readWithSharedLock() {
    std::shared_lock<std::shared_mutex> lock(sharedMtx);
    // 多个读者可以同时持有共享锁
    std::cout << "Counter: " << counter << std::endl;
}

void writeWithUniqueLock() {
    std::unique_lock<std::shared_mutex> lock(sharedMtx);
    // 写者独占锁
    ++counter;
}

int main() {
    std::vector<std::thread> threads;
    
    for (int i = 0; i < 10; ++i) {
        threads.emplace_back(incrementWithLockGuard);
    }
    
    for (auto& t : threads) {
        t.join();
    }
    
    std::cout << "Final counter: " << counter << std::endl;
    
    return 0;
}
```

### 3.3 文件流

```cpp
#include <iostream>
#include <fstream>
#include <string>

void writeFile(const std::string& filename) {
    std::ofstream file(filename);
    if (!file) {
        throw std::runtime_error("Cannot open file for writing");
    }
    
    file << "Line 1\n";
    file << "Line 2\n";
    file << "Line 3\n";
    
}  // 文件自动关闭

void readFile(const std::string& filename) {
    std::ifstream file(filename);
    if (!file) {
        throw std::runtime_error("Cannot open file for reading");
    }
    
    std::string line;
    while (std::getline(file, line)) {
        std::cout << line << std::endl;
    }
    
}  // 文件自动关闭

int main() {
    try {
        writeFile("test.txt");
        readFile("test.txt");
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
    }
    
    return 0;
}
```

---

## 4. 自定义 RAII 类

### 4.1 数据库连接

```cpp
#include <iostream>
#include <string>
#include <memory>

// 模拟数据库连接
class DatabaseConnection {
public:
    explicit DatabaseConnection(const std::string& connectionString) {
        // 模拟连接数据库
        std::cout << "Connecting to: " << connectionString << std::endl;
        connected = true;
    }
    
    ~DatabaseConnection() {
        if (connected) {
            std::cout << "Disconnecting from database" << std::endl;
            connected = false;
        }
    }
    
    // 禁用拷贝
    DatabaseConnection(const DatabaseConnection&) = delete;
    DatabaseConnection& operator=(const DatabaseConnection&) = delete;
    
    // 允许移动
    DatabaseConnection(DatabaseConnection&& other) noexcept
        : connected(other.connected) {
        other.connected = false;
    }
    
    DatabaseConnection& operator=(DatabaseConnection&& other) noexcept {
        if (this != &other) {
            if (connected) {
                std::cout << "Disconnecting from database" << std::endl;
            }
            connected = other.connected;
            other.connected = false;
        }
        return *this;
    }
    
    void execute(const std::string& query) {
        if (!connected) {
            throw std::runtime_error("Not connected");
        }
        std::cout << "Executing: " << query << std::endl;
    }
    
    bool isConnected() const { return connected; }

private:
    bool connected = false;
};

// 事务 RAII
class Transaction {
public:
    explicit Transaction(DatabaseConnection& conn) : connection(conn) {
        connection.execute("BEGIN TRANSACTION");
        active = true;
    }
    
    ~Transaction() {
        if (active) {
            try {
                rollback();
            } catch (...) {
                // 析构函数不应抛出异常
            }
        }
    }
    
    void commit() {
        if (active) {
            connection.execute("COMMIT");
            active = false;
        }
    }
    
    void rollback() {
        if (active) {
            connection.execute("ROLLBACK");
            active = false;
        }
    }

private:
    DatabaseConnection& connection;
    bool active = false;
};

int main() {
    try {
        DatabaseConnection db("localhost:5432/mydb");
        
        {
            Transaction tx(db);
            db.execute("INSERT INTO users VALUES (1, 'Alice')");
            db.execute("INSERT INTO users VALUES (2, 'Bob')");
            tx.commit();
        }
        
        {
            Transaction tx(db);
            db.execute("DELETE FROM users WHERE id = 1");
            // 不调用 commit,析构时自动 rollback
        }
        
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
    }
    
    return 0;
}
```

### 4.2 定时器

```cpp
#include <iostream>
#include <chrono>
#include <string>

class Timer {
public:
    explicit Timer(const std::string& name = "Timer")
        : name(name), start(std::chrono::high_resolution_clock::now()) {
        std::cout << name << " started" << std::endl;
    }
    
    ~Timer() {
        auto end = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
        std::cout << name << " took " << duration.count() << " microseconds" << std::endl;
    }
    
    // 禁用拷贝和移动
    Timer(const Timer&) = delete;
    Timer& operator=(const Timer&) = delete;

private:
    std::string name;
    std::chrono::high_resolution_clock::time_point start;
};

void someOperation() {
    Timer timer("someOperation");
    
    // 模拟一些工作
    int sum = 0;
    for (int i = 0; i < 1000000; ++i) {
        sum += i;
    }
}

int main() {
    {
        Timer timer("Main scope");
        
        someOperation();
        someOperation();
    }
    
    return 0;
}
```

---

## 5. 作用域守卫

### 5.1 通用作用域守卫

```cpp
#include <iostream>
#include <functional>

// 通用作用域守卫
class ScopeGuard {
public:
    explicit ScopeGuard(std::function<void()> onExit)
        : onExit(std::move(onExit)), active(true) { }
    
    ~ScopeGuard() {
        if (active) {
            try {
                onExit();
            } catch (...) {
                // 忽略异常
            }
        }
    }
    
    // 禁用拷贝
    ScopeGuard(const ScopeGuard&) = delete;
    ScopeGuard& operator=(const ScopeGuard&) = delete;
    
    // 允许移动
    ScopeGuard(ScopeGuard&& other) noexcept
        : onExit(std::move(other.onExit)), active(other.active) {
        other.active = false;
    }
    
    void dismiss() { active = false; }

private:
    std::function<void()> onExit;
    bool active;
};

// 辅助宏
#define SCOPE_EXIT(code) ScopeGuard CONCAT(scopeGuard_, __LINE__)([&]() { code; })
#define CONCAT(a, b) CONCAT_IMPL(a, b)
#define CONCAT_IMPL(a, b) a##b

int main() {
    // 使用 ScopeGuard
    {
        std::cout << "Entering scope" << std::endl;
        
        ScopeGuard guard([]() {
            std::cout << "Scope guard executed" << std::endl;
        });
        
        std::cout << "In scope" << std::endl;
        
        // guard.dismiss();  // 取消执行
    }
    
    std::cout << "---" << std::endl;
    
    // 使用宏
    {
        SCOPE_EXIT(std::cout << "Cleanup 1" << std::endl);
        SCOPE_EXIT(std::cout << "Cleanup 2" << std::endl);
        
        std::cout << "Doing work" << std::endl;
    }
    
    return 0;
}
```

### 5.2 条件作用域守卫

```cpp
#include <iostream>
#include <functional>

template<typename Func>
class ScopeGuardImpl {
public:
    explicit ScopeGuardImpl(Func&& func)
        : func(std::forward<Func>(func)), active(true) { }
    
    ~ScopeGuardImpl() {
        if (active) {
            try { func(); } catch (...) { }
        }
    }
    
    ScopeGuardImpl(ScopeGuardImpl&& other) noexcept
        : func(std::move(other.func)), active(other.active) {
        other.active = false;
    }
    
    void dismiss() { active = false; }

private:
    Func func;
    bool active;
};

template<typename Func>
ScopeGuardImpl<Func> makeScopeGuard(Func&& func) {
    return ScopeGuardImpl<Func>(std::forward<Func>(func));
}

// 成功时执行
template<typename Func>
class ScopeSuccess {
public:
    explicit ScopeSuccess(Func&& func)
        : func(std::forward<Func>(func)), 
          uncaughtExceptions(std::uncaught_exceptions()) { }
    
    ~ScopeSuccess() {
        if (std::uncaught_exceptions() == uncaughtExceptions) {
            func();
        }
    }

private:
    Func func;
    int uncaughtExceptions;
};

// 失败时执行
template<typename Func>
class ScopeFail {
public:
    explicit ScopeFail(Func&& func)
        : func(std::forward<Func>(func)),
          uncaughtExceptions(std::uncaught_exceptions()) { }
    
    ~ScopeFail() {
        if (std::uncaught_exceptions() > uncaughtExceptions) {
            try { func(); } catch (...) { }
        }
    }

private:
    Func func;
    int uncaughtExceptions;
};

int main() {
    // 正常退出
    {
        auto guard = makeScopeGuard([]() {
            std::cout << "Always executed" << std::endl;
        });
        
        ScopeSuccess success([]() {
            std::cout << "Success!" << std::endl;
        });
        
        ScopeFail fail([]() {
            std::cout << "Failed!" << std::endl;
        });
        
        std::cout << "Normal execution" << std::endl;
    }
    
    std::cout << "---" << std::endl;
    
    // 异常退出
    try {
        auto guard = makeScopeGuard([]() {
            std::cout << "Always executed" << std::endl;
        });
        
        ScopeSuccess success([]() {
            std::cout << "Success!" << std::endl;
        });
        
        ScopeFail fail([]() {
            std::cout << "Failed!" << std::endl;
        });
        
        throw std::runtime_error("Test exception");
    } catch (...) {
        std::cout << "Exception caught" << std::endl;
    }
    
    return 0;
}
```

---

## 6. 总结

### 6.1 RAII 核心原则

```
1. 构造函数获取资源
2. 析构函数释放资源
3. 禁用或正确实现拷贝
4. 考虑移动语义
5. 析构函数不抛异常
```

### 6.2 标准库 RAII 类

| 类 | 管理的资源 |
|----|-----------|
| unique_ptr | 动态内存 |
| shared_ptr | 共享动态内存 |
| lock_guard | 互斥锁 |
| unique_lock | 互斥锁 (灵活) |
| fstream | 文件 |
| thread | 线程 |

### 6.3 下一篇预告

在下一篇文章中,我们将学习内存布局与对齐。

---

> 作者: C++ 技术专栏  
> 系列: 内存管理与指针进阶 (3/6)  
> 上一篇: [智能指针](./18-smart-pointers.md)  
> 下一篇: [内存布局与对齐](./20-memory-layout.md)
