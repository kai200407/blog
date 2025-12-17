---
title: "I/O 多路复用"
description: "1. [I/O 模型概述](#1-io-模型概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 48
---

> 本文是 C++ 从入门到精通系列的第四十八篇,将深入讲解 I/O 多路复用技术,包括 select、poll 和 epoll。

---

## 目录

1. [I/O 模型概述](#1-io-模型概述)
2. [select](#2-select)
3. [poll](#3-poll)
4. [epoll](#4-epoll)
5. [性能对比](#5-性能对比)
6. [总结](#6-总结)

---

## 1. I/O 模型概述

### 1.1 I/O 模型分类

```
五种 I/O 模型:

1. 阻塞 I/O (Blocking I/O)
   - 调用阻塞直到数据就绪
   - 最简单的模型

2. 非阻塞 I/O (Non-blocking I/O)
   - 立即返回
   - 需要轮询

3. I/O 多路复用 (I/O Multiplexing)
   - 同时监控多个文件描述符
   - select, poll, epoll

4. 信号驱动 I/O (Signal-driven I/O)
   - 使用信号通知
   - 较少使用

5. 异步 I/O (Asynchronous I/O)
   - 完全异步
   - aio_read, aio_write
```

### 1.2 为什么需要 I/O 多路复用

```
问题:
- 一个线程只能处理一个连接
- 多线程开销大
- 线程数量有限

解决方案:
- 一个线程监控多个连接
- 只处理就绪的连接
- 减少线程数量
```

---

## 2. select

### 2.1 select API

```cpp
#include <sys/select.h>

int select(int nfds, fd_set *readfds, fd_set *writefds,
           fd_set *exceptfds, struct timeval *timeout);

// fd_set 操作宏
FD_ZERO(fd_set *set);           // 清空集合
FD_SET(int fd, fd_set *set);    // 添加 fd
FD_CLR(int fd, fd_set *set);    // 移除 fd
FD_ISSET(int fd, fd_set *set);  // 检查 fd 是否在集合中
```

### 2.2 select 服务器

```cpp
#include <iostream>
#include <vector>
#include <cstring>
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/select.h>
#include <unistd.h>

class SelectServer {
public:
    SelectServer(int port) : port(port), serverFd(-1) { }
    
    bool start() {
        serverFd = socket(AF_INET, SOCK_STREAM, 0);
        if (serverFd < 0) return false;
        
        int opt = 1;
        setsockopt(serverFd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
        
        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port);
        
        if (bind(serverFd, (sockaddr*)&addr, sizeof(addr)) < 0) return false;
        if (listen(serverFd, 10) < 0) return false;
        
        std::cout << "Select server listening on port " << port << std::endl;
        return true;
    }
    
    void run() {
        std::vector<int> clients;
        
        while (true) {
            fd_set readfds;
            FD_ZERO(&readfds);
            FD_SET(serverFd, &readfds);
            
            int maxFd = serverFd;
            
            for (int fd : clients) {
                FD_SET(fd, &readfds);
                maxFd = std::max(maxFd, fd);
            }
            
            // 等待事件
            int activity = select(maxFd + 1, &readfds, nullptr, nullptr, nullptr);
            if (activity < 0) {
                std::cerr << "select error" << std::endl;
                continue;
            }
            
            // 检查新连接
            if (FD_ISSET(serverFd, &readfds)) {
                sockaddr_in clientAddr{};
                socklen_t clientLen = sizeof(clientAddr);
                int clientFd = accept(serverFd, (sockaddr*)&clientAddr, &clientLen);
                
                if (clientFd >= 0) {
                    clients.push_back(clientFd);
                    std::cout << "New client connected: " << clientFd << std::endl;
                }
            }
            
            // 检查客户端数据
            for (auto it = clients.begin(); it != clients.end(); ) {
                int fd = *it;
                
                if (FD_ISSET(fd, &readfds)) {
                    char buffer[1024];
                    ssize_t bytesRead = recv(fd, buffer, sizeof(buffer) - 1, 0);
                    
                    if (bytesRead <= 0) {
                        close(fd);
                        it = clients.erase(it);
                        std::cout << "Client disconnected: " << fd << std::endl;
                        continue;
                    }
                    
                    buffer[bytesRead] = '\0';
                    std::cout << "Received from " << fd << ": " << buffer << std::endl;
                    send(fd, buffer, bytesRead, 0);
                }
                
                ++it;
            }
        }
    }
    
    ~SelectServer() {
        if (serverFd >= 0) close(serverFd);
    }

private:
    int port;
    int serverFd;
};

int main() {
    SelectServer server(8080);
    if (server.start()) {
        server.run();
    }
    return 0;
}
```

### 2.3 select 的限制

```
select 的限制:

1. 文件描述符数量限制
   - 通常最大 1024 (FD_SETSIZE)

2. 每次调用需要重新设置 fd_set
   - 因为 select 会修改 fd_set

3. 需要遍历所有 fd 检查状态
   - O(n) 复杂度

4. 用户态和内核态之间拷贝 fd_set
   - 开销较大
```

---

## 3. poll

### 3.1 poll API

```cpp
#include <poll.h>

int poll(struct pollfd *fds, nfds_t nfds, int timeout);

struct pollfd {
    int   fd;         // 文件描述符
    short events;     // 请求的事件
    short revents;    // 返回的事件
};

// 事件类型
POLLIN   // 可读
POLLOUT  // 可写
POLLERR  // 错误
POLLHUP  // 挂起
POLLNVAL // 无效 fd
```

### 3.2 poll 服务器

```cpp
#include <iostream>
#include <vector>
#include <cstring>
#include <sys/socket.h>
#include <netinet/in.h>
#include <poll.h>
#include <unistd.h>

class PollServer {
public:
    PollServer(int port) : port(port), serverFd(-1) { }
    
    bool start() {
        serverFd = socket(AF_INET, SOCK_STREAM, 0);
        if (serverFd < 0) return false;
        
        int opt = 1;
        setsockopt(serverFd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
        
        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port);
        
        if (bind(serverFd, (sockaddr*)&addr, sizeof(addr)) < 0) return false;
        if (listen(serverFd, 10) < 0) return false;
        
        std::cout << "Poll server listening on port " << port << std::endl;
        return true;
    }
    
    void run() {
        std::vector<pollfd> fds;
        fds.push_back({serverFd, POLLIN, 0});
        
        while (true) {
            int activity = poll(fds.data(), fds.size(), -1);
            if (activity < 0) {
                std::cerr << "poll error" << std::endl;
                continue;
            }
            
            // 检查服务器 socket
            if (fds[0].revents & POLLIN) {
                sockaddr_in clientAddr{};
                socklen_t clientLen = sizeof(clientAddr);
                int clientFd = accept(serverFd, (sockaddr*)&clientAddr, &clientLen);
                
                if (clientFd >= 0) {
                    fds.push_back({clientFd, POLLIN, 0});
                    std::cout << "New client connected: " << clientFd << std::endl;
                }
            }
            
            // 检查客户端 socket
            for (size_t i = 1; i < fds.size(); ) {
                if (fds[i].revents & POLLIN) {
                    char buffer[1024];
                    ssize_t bytesRead = recv(fds[i].fd, buffer, sizeof(buffer) - 1, 0);
                    
                    if (bytesRead <= 0) {
                        close(fds[i].fd);
                        fds.erase(fds.begin() + i);
                        std::cout << "Client disconnected" << std::endl;
                        continue;
                    }
                    
                    buffer[bytesRead] = '\0';
                    std::cout << "Received: " << buffer << std::endl;
                    send(fds[i].fd, buffer, bytesRead, 0);
                }
                
                if (fds[i].revents & (POLLERR | POLLHUP | POLLNVAL)) {
                    close(fds[i].fd);
                    fds.erase(fds.begin() + i);
                    continue;
                }
                
                ++i;
            }
        }
    }
    
    ~PollServer() {
        if (serverFd >= 0) close(serverFd);
    }

private:
    int port;
    int serverFd;
};
```

### 3.3 poll vs select

```
poll 相比 select 的改进:

1. 没有文件描述符数量限制
   - 使用动态数组

2. 不需要每次重新设置
   - events 和 revents 分开

3. 更清晰的事件类型
   - 使用位掩码

仍然存在的问题:
- 需要遍历所有 fd
- 用户态和内核态拷贝
```

---

## 4. epoll

### 4.1 epoll API

```cpp
#include <sys/epoll.h>

// 创建 epoll 实例
int epoll_create(int size);
int epoll_create1(int flags);

// 控制 epoll
int epoll_ctl(int epfd, int op, int fd, struct epoll_event *event);

// 等待事件
int epoll_wait(int epfd, struct epoll_event *events,
               int maxevents, int timeout);

struct epoll_event {
    uint32_t     events;  // 事件类型
    epoll_data_t data;    // 用户数据
};

// 操作类型
EPOLL_CTL_ADD  // 添加
EPOLL_CTL_MOD  // 修改
EPOLL_CTL_DEL  // 删除

// 事件类型
EPOLLIN      // 可读
EPOLLOUT     // 可写
EPOLLERR     // 错误
EPOLLHUP     // 挂起
EPOLLET      // 边缘触发
EPOLLONESHOT // 一次性
```

### 4.2 epoll 服务器

```cpp
#include <iostream>
#include <cstring>
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/epoll.h>
#include <fcntl.h>
#include <unistd.h>

class EpollServer {
public:
    EpollServer(int port) : port(port), serverFd(-1), epollFd(-1) { }
    
    bool start() {
        serverFd = socket(AF_INET, SOCK_STREAM, 0);
        if (serverFd < 0) return false;
        
        int opt = 1;
        setsockopt(serverFd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
        
        // 设置非阻塞
        setNonBlocking(serverFd);
        
        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port);
        
        if (bind(serverFd, (sockaddr*)&addr, sizeof(addr)) < 0) return false;
        if (listen(serverFd, 10) < 0) return false;
        
        // 创建 epoll 实例
        epollFd = epoll_create1(0);
        if (epollFd < 0) return false;
        
        // 添加服务器 socket
        epoll_event ev{};
        ev.events = EPOLLIN;
        ev.data.fd = serverFd;
        epoll_ctl(epollFd, EPOLL_CTL_ADD, serverFd, &ev);
        
        std::cout << "Epoll server listening on port " << port << std::endl;
        return true;
    }
    
    void run() {
        const int MAX_EVENTS = 64;
        epoll_event events[MAX_EVENTS];
        
        while (true) {
            int nfds = epoll_wait(epollFd, events, MAX_EVENTS, -1);
            if (nfds < 0) {
                std::cerr << "epoll_wait error" << std::endl;
                continue;
            }
            
            for (int i = 0; i < nfds; ++i) {
                int fd = events[i].data.fd;
                
                if (fd == serverFd) {
                    // 新连接
                    handleAccept();
                } else if (events[i].events & EPOLLIN) {
                    // 可读
                    handleRead(fd);
                }
            }
        }
    }
    
    ~EpollServer() {
        if (serverFd >= 0) close(serverFd);
        if (epollFd >= 0) close(epollFd);
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
            
            if (clientFd < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    break;  // 没有更多连接
                }
                std::cerr << "accept error" << std::endl;
                break;
            }
            
            setNonBlocking(clientFd);
            
            epoll_event ev{};
            ev.events = EPOLLIN | EPOLLET;  // 边缘触发
            ev.data.fd = clientFd;
            epoll_ctl(epollFd, EPOLL_CTL_ADD, clientFd, &ev);
            
            std::cout << "New client connected: " << clientFd << std::endl;
        }
    }
    
    void handleRead(int fd) {
        char buffer[1024];
        
        while (true) {
            ssize_t bytesRead = recv(fd, buffer, sizeof(buffer) - 1, 0);
            
            if (bytesRead < 0) {
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    break;  // 没有更多数据
                }
                // 错误
                closeClient(fd);
                break;
            } else if (bytesRead == 0) {
                // 连接关闭
                closeClient(fd);
                break;
            }
            
            buffer[bytesRead] = '\0';
            std::cout << "Received from " << fd << ": " << buffer << std::endl;
            send(fd, buffer, bytesRead, 0);
        }
    }
    
    void closeClient(int fd) {
        epoll_ctl(epollFd, EPOLL_CTL_DEL, fd, nullptr);
        close(fd);
        std::cout << "Client disconnected: " << fd << std::endl;
    }
    
    int port;
    int serverFd;
    int epollFd;
};

int main() {
    EpollServer server(8080);
    if (server.start()) {
        server.run();
    }
    return 0;
}
```

### 4.3 水平触发 vs 边缘触发

```
水平触发 (Level Triggered, LT):
- 默认模式
- 只要有数据就通知
- 可以不一次读完

边缘触发 (Edge Triggered, ET):
- 状态变化时通知
- 必须一次读完所有数据
- 性能更高
- 需要非阻塞 I/O

使用 ET 的注意事项:
1. 必须使用非阻塞 I/O
2. 读取直到 EAGAIN
3. 写入直到 EAGAIN
```

---

## 5. 性能对比

### 5.1 复杂度对比

```
操作复杂度:

           select    poll      epoll
添加 fd    O(1)      O(1)      O(1)
删除 fd    O(1)      O(1)      O(1)
等待事件   O(n)      O(n)      O(1)
内核遍历   O(n)      O(n)      O(活跃fd)

n = 文件描述符数量
```

### 5.2 适用场景

```
select:
- 跨平台 (Windows, Linux, macOS)
- 连接数少 (<1000)
- 简单场景

poll:
- 连接数中等
- 需要更多事件类型
- 不需要跨平台

epoll:
- Linux 专用
- 高并发 (>10000)
- 生产环境首选
```

### 5.3 其他选择

```
其他 I/O 多路复用:

kqueue (BSD/macOS):
- 类似 epoll
- 更通用的事件通知

IOCP (Windows):
- 完成端口
- 真正的异步 I/O

libevent/libuv:
- 跨平台库
- 封装底层差异
```

---

## 6. 总结

### 6.1 API 对比

| 特性 | select | poll | epoll |
|------|--------|------|-------|
| 最大 fd | 1024 | 无限制 | 无限制 |
| 复杂度 | O(n) | O(n) | O(1) |
| 触发模式 | LT | LT | LT/ET |
| 跨平台 | 是 | 部分 | 否 |

### 6.2 最佳实践

```
1. 高并发场景使用 epoll
2. 跨平台使用 libevent/libuv
3. ET 模式配合非阻塞 I/O
4. 合理设置超时
5. 处理 EAGAIN/EWOULDBLOCK
```

### 6.3 下一篇预告

在下一篇文章中,我们将学习异步 I/O。

---

> 作者: C++ 技术专栏  
> 系列: 网络编程 (2/4)  
> 上一篇: [Socket 编程基础](./47-socket-basics.md)  
> 下一篇: [异步 I/O](./49-async-io.md)
