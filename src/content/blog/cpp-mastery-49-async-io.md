---
title: "异步 I/O"
description: "1. [异步 I/O 概述](#1-异步-io-概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 49
---

> 本文是 C++ 从入门到精通系列的第四十九篇,将深入讲解异步 I/O 技术和事件驱动编程。

---

## 目录

1. [异步 I/O 概述](#1-异步-io-概述)
2. [POSIX AIO](#2-posix-aio)
3. [io_uring](#3-io_uring)
4. [事件驱动架构](#4-事件驱动架构)
5. [Reactor 模式](#5-reactor-模式)
6. [总结](#6-总结)

---

## 1. 异步 I/O 概述

### 1.1 同步 vs 异步

```
同步 I/O:
- 调用阻塞直到完成
- 或者轮询检查状态
- 线程等待 I/O

异步 I/O:
- 发起请求后立即返回
- I/O 在后台进行
- 完成后通知应用

真正的异步 I/O:
- 内核完成数据拷贝
- 应用无需等待
- 效率最高
```

### 1.2 异步 I/O 模型

```
异步 I/O 流程:

应用程序                    内核
    |                         |
    |-- aio_read() ---------> |
    |<-- 立即返回              |
    |                         |-- 等待数据
    |-- 继续其他工作           |-- 数据到达
    |                         |-- 拷贝到用户缓冲区
    |<-- 信号/回调通知 --------|
    |-- 处理数据               |
```

---

## 2. POSIX AIO

### 2.1 AIO API

```cpp
#include <aio.h>

// 异步读
int aio_read(struct aiocb *aiocbp);

// 异步写
int aio_write(struct aiocb *aiocbp);

// 检查状态
int aio_error(const struct aiocb *aiocbp);

// 获取返回值
ssize_t aio_return(struct aiocb *aiocbp);

// 等待完成
int aio_suspend(const struct aiocb *const list[], int nent,
                const struct timespec *timeout);

// 取消操作
int aio_cancel(int fd, struct aiocb *aiocbp);

// 控制块结构
struct aiocb {
    int             aio_fildes;     // 文件描述符
    off_t           aio_offset;     // 文件偏移
    volatile void  *aio_buf;        // 缓冲区
    size_t          aio_nbytes;     // 字节数
    int             aio_reqprio;    // 优先级
    struct sigevent aio_sigevent;   // 通知方式
    int             aio_lio_opcode; // 操作码
};
```

### 2.2 AIO 读取示例

```cpp
#include <iostream>
#include <cstring>
#include <aio.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>

class AsyncFileReader {
public:
    AsyncFileReader(const char* filename) {
        fd = open(filename, O_RDONLY);
        if (fd < 0) {
            throw std::runtime_error("Failed to open file");
        }
    }
    
    void readAsync(char* buffer, size_t size, off_t offset) {
        memset(&cb, 0, sizeof(cb));
        
        cb.aio_fildes = fd;
        cb.aio_buf = buffer;
        cb.aio_nbytes = size;
        cb.aio_offset = offset;
        
        if (aio_read(&cb) < 0) {
            throw std::runtime_error("aio_read failed");
        }
    }
    
    bool isComplete() {
        int status = aio_error(&cb);
        return status != EINPROGRESS;
    }
    
    ssize_t getResult() {
        return aio_return(&cb);
    }
    
    void wait() {
        const aiocb* list[] = {&cb};
        aio_suspend(list, 1, nullptr);
    }
    
    ~AsyncFileReader() {
        if (fd >= 0) close(fd);
    }

private:
    int fd;
    aiocb cb;
};

int main() {
    try {
        // 创建测试文件
        {
            int fd = open("test.txt", O_WRONLY | O_CREAT | O_TRUNC, 0644);
            write(fd, "Hello, Async I/O!", 17);
            close(fd);
        }
        
        AsyncFileReader reader("test.txt");
        char buffer[1024] = {0};
        
        reader.readAsync(buffer, sizeof(buffer) - 1, 0);
        
        std::cout << "Doing other work..." << std::endl;
        
        reader.wait();
        
        if (reader.isComplete()) {
            ssize_t bytesRead = reader.getResult();
            if (bytesRead > 0) {
                std::cout << "Read: " << buffer << std::endl;
            }
        }
        
        unlink("test.txt");
        
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
    }
    
    return 0;
}
```

### 2.3 AIO 信号通知

```cpp
#include <iostream>
#include <cstring>
#include <aio.h>
#include <signal.h>
#include <fcntl.h>
#include <unistd.h>

volatile sig_atomic_t readComplete = 0;
aiocb* globalCb = nullptr;

void aioHandler(int sig, siginfo_t* info, void* context) {
    if (info->si_code == SI_ASYNCIO) {
        readComplete = 1;
    }
}

int main() {
    // 设置信号处理
    struct sigaction sa;
    sa.sa_flags = SA_SIGINFO;
    sa.sa_sigaction = aioHandler;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGIO, &sa, nullptr);
    
    // 创建测试文件
    int fd = open("test.txt", O_RDWR | O_CREAT | O_TRUNC, 0644);
    write(fd, "Signal-based AIO", 16);
    lseek(fd, 0, SEEK_SET);
    
    // 设置 AIO
    char buffer[1024] = {0};
    aiocb cb;
    memset(&cb, 0, sizeof(cb));
    
    cb.aio_fildes = fd;
    cb.aio_buf = buffer;
    cb.aio_nbytes = sizeof(buffer) - 1;
    cb.aio_offset = 0;
    
    // 设置信号通知
    cb.aio_sigevent.sigev_notify = SIGEV_SIGNAL;
    cb.aio_sigevent.sigev_signo = SIGIO;
    cb.aio_sigevent.sigev_value.sival_ptr = &cb;
    
    globalCb = &cb;
    
    // 发起异步读
    aio_read(&cb);
    
    std::cout << "Waiting for signal..." << std::endl;
    
    while (!readComplete) {
        pause();
    }
    
    ssize_t bytesRead = aio_return(&cb);
    std::cout << "Read " << bytesRead << " bytes: " << buffer << std::endl;
    
    close(fd);
    unlink("test.txt");
    
    return 0;
}
```

---

## 3. io_uring

### 3.1 io_uring 概述

```
io_uring (Linux 5.1+):

优势:
- 真正的异步 I/O
- 零拷贝
- 批量提交
- 减少系统调用

组件:
- 提交队列 (SQ): 应用提交请求
- 完成队列 (CQ): 内核返回结果
- 共享内存: 减少拷贝
```

### 3.2 io_uring API

```cpp
#include <liburing.h>

// 初始化
int io_uring_queue_init(unsigned entries, struct io_uring *ring,
                        unsigned flags);

// 获取 SQE
struct io_uring_sqe *io_uring_get_sqe(struct io_uring *ring);

// 准备读操作
void io_uring_prep_read(struct io_uring_sqe *sqe, int fd,
                        void *buf, unsigned nbytes, off_t offset);

// 准备写操作
void io_uring_prep_write(struct io_uring_sqe *sqe, int fd,
                         const void *buf, unsigned nbytes, off_t offset);

// 提交请求
int io_uring_submit(struct io_uring *ring);

// 等待完成
int io_uring_wait_cqe(struct io_uring *ring, struct io_uring_cqe **cqe_ptr);

// 标记 CQE 已处理
void io_uring_cqe_seen(struct io_uring *ring, struct io_uring_cqe *cqe);

// 清理
void io_uring_queue_exit(struct io_uring *ring);
```

### 3.3 io_uring 示例

```cpp
#include <iostream>
#include <cstring>
#include <fcntl.h>
#include <unistd.h>
#include <liburing.h>

class IoUringReader {
public:
    IoUringReader() {
        if (io_uring_queue_init(32, &ring, 0) < 0) {
            throw std::runtime_error("io_uring_queue_init failed");
        }
    }
    
    void readFile(const char* filename) {
        int fd = open(filename, O_RDONLY);
        if (fd < 0) {
            throw std::runtime_error("Failed to open file");
        }
        
        char buffer[1024] = {0};
        
        // 获取 SQE
        io_uring_sqe* sqe = io_uring_get_sqe(&ring);
        if (!sqe) {
            close(fd);
            throw std::runtime_error("io_uring_get_sqe failed");
        }
        
        // 准备读操作
        io_uring_prep_read(sqe, fd, buffer, sizeof(buffer) - 1, 0);
        sqe->user_data = reinterpret_cast<__u64>(buffer);
        
        // 提交
        io_uring_submit(&ring);
        
        // 等待完成
        io_uring_cqe* cqe;
        io_uring_wait_cqe(&ring, &cqe);
        
        if (cqe->res > 0) {
            std::cout << "Read " << cqe->res << " bytes: " << buffer << std::endl;
        } else {
            std::cerr << "Read failed: " << cqe->res << std::endl;
        }
        
        io_uring_cqe_seen(&ring, cqe);
        close(fd);
    }
    
    ~IoUringReader() {
        io_uring_queue_exit(&ring);
    }

private:
    io_uring ring;
};

int main() {
    try {
        // 创建测试文件
        {
            int fd = open("test.txt", O_WRONLY | O_CREAT | O_TRUNC, 0644);
            write(fd, "Hello, io_uring!", 16);
            close(fd);
        }
        
        IoUringReader reader;
        reader.readFile("test.txt");
        
        unlink("test.txt");
        
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
    }
    
    return 0;
}
```

---

## 4. 事件驱动架构

### 4.1 事件循环

```cpp
#include <iostream>
#include <functional>
#include <queue>
#include <map>
#include <chrono>

class EventLoop {
public:
    using Callback = std::function<void()>;
    using TimePoint = std::chrono::steady_clock::time_point;
    
    void post(Callback callback) {
        tasks.push(std::move(callback));
    }
    
    void postDelayed(Callback callback, std::chrono::milliseconds delay) {
        auto when = std::chrono::steady_clock::now() + delay;
        timers.emplace(when, std::move(callback));
    }
    
    void run() {
        running = true;
        
        while (running) {
            // 处理定时器
            auto now = std::chrono::steady_clock::now();
            while (!timers.empty() && timers.begin()->first <= now) {
                auto it = timers.begin();
                it->second();
                timers.erase(it);
            }
            
            // 处理任务
            while (!tasks.empty()) {
                auto task = std::move(tasks.front());
                tasks.pop();
                task();
            }
            
            // 如果没有任务,短暂休眠
            if (tasks.empty() && timers.empty()) {
                break;
            }
        }
    }
    
    void stop() {
        running = false;
    }

private:
    std::queue<Callback> tasks;
    std::multimap<TimePoint, Callback> timers;
    bool running = false;
};

int main() {
    EventLoop loop;
    
    loop.post([]() {
        std::cout << "Task 1" << std::endl;
    });
    
    loop.post([]() {
        std::cout << "Task 2" << std::endl;
    });
    
    loop.postDelayed([]() {
        std::cout << "Delayed task" << std::endl;
    }, std::chrono::milliseconds(100));
    
    loop.run();
    
    return 0;
}
```

### 4.2 回调模式

```cpp
#include <iostream>
#include <functional>
#include <string>

class AsyncOperation {
public:
    using SuccessCallback = std::function<void(const std::string&)>;
    using ErrorCallback = std::function<void(const std::string&)>;
    
    void execute(SuccessCallback onSuccess, ErrorCallback onError) {
        // 模拟异步操作
        bool success = true;  // 模拟结果
        
        if (success) {
            onSuccess("Operation completed successfully");
        } else {
            onError("Operation failed");
        }
    }
};

// 回调地狱示例
void callbackHell() {
    AsyncOperation op1, op2, op3;
    
    op1.execute(
        [&](const std::string& result1) {
            std::cout << "Step 1: " << result1 << std::endl;
            
            op2.execute(
                [&](const std::string& result2) {
                    std::cout << "Step 2: " << result2 << std::endl;
                    
                    op3.execute(
                        [](const std::string& result3) {
                            std::cout << "Step 3: " << result3 << std::endl;
                        },
                        [](const std::string& error) {
                            std::cerr << "Error 3: " << error << std::endl;
                        }
                    );
                },
                [](const std::string& error) {
                    std::cerr << "Error 2: " << error << std::endl;
                }
            );
        },
        [](const std::string& error) {
            std::cerr << "Error 1: " << error << std::endl;
        }
    );
}

int main() {
    callbackHell();
    return 0;
}
```

---

## 5. Reactor 模式

### 5.1 Reactor 实现

```cpp
#include <iostream>
#include <functional>
#include <map>
#include <sys/epoll.h>
#include <unistd.h>

class Reactor {
public:
    using EventHandler = std::function<void(uint32_t events)>;
    
    Reactor() {
        epollFd = epoll_create1(0);
        if (epollFd < 0) {
            throw std::runtime_error("epoll_create1 failed");
        }
    }
    
    void registerHandler(int fd, uint32_t events, EventHandler handler) {
        handlers[fd] = std::move(handler);
        
        epoll_event ev{};
        ev.events = events;
        ev.data.fd = fd;
        
        epoll_ctl(epollFd, EPOLL_CTL_ADD, fd, &ev);
    }
    
    void unregisterHandler(int fd) {
        handlers.erase(fd);
        epoll_ctl(epollFd, EPOLL_CTL_DEL, fd, nullptr);
    }
    
    void modifyHandler(int fd, uint32_t events) {
        epoll_event ev{};
        ev.events = events;
        ev.data.fd = fd;
        
        epoll_ctl(epollFd, EPOLL_CTL_MOD, fd, &ev);
    }
    
    void run() {
        running = true;
        const int MAX_EVENTS = 64;
        epoll_event events[MAX_EVENTS];
        
        while (running) {
            int nfds = epoll_wait(epollFd, events, MAX_EVENTS, 1000);
            
            for (int i = 0; i < nfds; ++i) {
                int fd = events[i].data.fd;
                auto it = handlers.find(fd);
                
                if (it != handlers.end()) {
                    it->second(events[i].events);
                }
            }
        }
    }
    
    void stop() {
        running = false;
    }
    
    ~Reactor() {
        if (epollFd >= 0) close(epollFd);
    }

private:
    int epollFd;
    std::map<int, EventHandler> handlers;
    bool running = false;
};
```

### 5.2 使用 Reactor 的服务器

```cpp
#include <iostream>
#include <cstring>
#include <sys/socket.h>
#include <netinet/in.h>
#include <fcntl.h>
#include <unistd.h>

// 假设 Reactor 类已定义

class ReactorServer {
public:
    ReactorServer(Reactor& reactor, int port) 
        : reactor(reactor), port(port), serverFd(-1) { }
    
    bool start() {
        serverFd = socket(AF_INET, SOCK_STREAM, 0);
        if (serverFd < 0) return false;
        
        int opt = 1;
        setsockopt(serverFd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
        setNonBlocking(serverFd);
        
        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port);
        
        if (bind(serverFd, (sockaddr*)&addr, sizeof(addr)) < 0) return false;
        if (listen(serverFd, 10) < 0) return false;
        
        reactor.registerHandler(serverFd, EPOLLIN, 
            [this](uint32_t events) { handleAccept(); });
        
        std::cout << "Reactor server listening on port " << port << std::endl;
        return true;
    }
    
    ~ReactorServer() {
        if (serverFd >= 0) {
            reactor.unregisterHandler(serverFd);
            close(serverFd);
        }
    }

private:
    void setNonBlocking(int fd) {
        int flags = fcntl(fd, F_GETFL, 0);
        fcntl(fd, F_SETFL, flags | O_NONBLOCK);
    }
    
    void handleAccept() {
        while (true) {
            sockaddr_in clientAddr{};
            socklen_t clientLen = sizeof(clientAddr);
            int clientFd = accept(serverFd, (sockaddr*)&clientAddr, &clientLen);
            
            if (clientFd < 0) break;
            
            setNonBlocking(clientFd);
            
            reactor.registerHandler(clientFd, EPOLLIN | EPOLLET,
                [this, clientFd](uint32_t events) {
                    handleClient(clientFd, events);
                });
            
            std::cout << "New client: " << clientFd << std::endl;
        }
    }
    
    void handleClient(int fd, uint32_t events) {
        if (events & EPOLLIN) {
            char buffer[1024];
            ssize_t bytesRead = recv(fd, buffer, sizeof(buffer) - 1, 0);
            
            if (bytesRead <= 0) {
                reactor.unregisterHandler(fd);
                close(fd);
                std::cout << "Client disconnected: " << fd << std::endl;
                return;
            }
            
            buffer[bytesRead] = '\0';
            std::cout << "Received: " << buffer << std::endl;
            send(fd, buffer, bytesRead, 0);
        }
    }
    
    Reactor& reactor;
    int port;
    int serverFd;
};
```

---

## 6. 总结

### 6.1 异步 I/O 技术

| 技术 | 平台 | 特点 |
|------|------|------|
| POSIX AIO | POSIX | 标准但性能一般 |
| io_uring | Linux 5.1+ | 高性能,零拷贝 |
| IOCP | Windows | 完成端口 |

### 6.2 设计模式

| 模式 | 说明 |
|------|------|
| Reactor | 同步事件分发 |
| Proactor | 异步事件分发 |
| 事件循环 | 单线程处理 |

### 6.3 下一篇预告

在下一篇文章中,我们将学习 HTTP 服务器实现。

---

> 作者: C++ 技术专栏  
> 系列: 网络编程 (3/4)  
> 上一篇: [I/O 多路复用](./48-io-multiplexing.md)  
> 下一篇: [HTTP 服务器](./50-http-server.md)
