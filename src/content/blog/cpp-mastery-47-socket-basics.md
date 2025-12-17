---
title: "Socket 编程基础"
description: "1. [网络编程概述](#1-网络编程概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 47
---

> 本文是 C++ 从入门到精通系列的第四十七篇,将深入讲解网络编程的基础知识和 Socket API。

---

## 目录

1. [网络编程概述](#1-网络编程概述)
2. [Socket 基础](#2-socket-基础)
3. [TCP 编程](#3-tcp-编程)
4. [UDP 编程](#4-udp-编程)
5. [地址处理](#5-地址处理)
6. [总结](#6-总结)

---

## 1. 网络编程概述

### 1.1 网络模型

```
OSI 七层模型:

7. 应用层    - HTTP, FTP, SMTP
6. 表示层    - 数据格式转换
5. 会话层    - 会话管理
4. 传输层    - TCP, UDP
3. 网络层    - IP
2. 数据链路层 - 以太网
1. 物理层    - 电缆, 光纤

TCP/IP 四层模型:

4. 应用层    - HTTP, FTP, DNS
3. 传输层    - TCP, UDP
2. 网络层    - IP, ICMP
1. 网络接口层 - 以太网, WiFi
```

### 1.2 TCP vs UDP

```
TCP (传输控制协议):
- 面向连接
- 可靠传输
- 有序交付
- 流量控制
- 适合: 文件传输, Web, 邮件

UDP (用户数据报协议):
- 无连接
- 不可靠
- 可能乱序
- 无流量控制
- 适合: 视频流, 游戏, DNS
```

---

## 2. Socket 基础

### 2.1 Socket 概念

```
Socket (套接字):
- 网络通信的端点
- 由 IP 地址 + 端口号标识
- 提供进程间通信接口

Socket 类型:
- SOCK_STREAM: TCP 套接字
- SOCK_DGRAM: UDP 套接字
- SOCK_RAW: 原始套接字
```

### 2.2 基本 API

```cpp
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>

// 创建套接字
int socket(int domain, int type, int protocol);

// 绑定地址
int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen);

// 监听连接 (TCP)
int listen(int sockfd, int backlog);

// 接受连接 (TCP)
int accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen);

// 连接服务器 (TCP)
int connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen);

// 发送数据
ssize_t send(int sockfd, const void *buf, size_t len, int flags);
ssize_t sendto(int sockfd, const void *buf, size_t len, int flags,
               const struct sockaddr *dest_addr, socklen_t addrlen);

// 接收数据
ssize_t recv(int sockfd, void *buf, size_t len, int flags);
ssize_t recvfrom(int sockfd, void *buf, size_t len, int flags,
                 struct sockaddr *src_addr, socklen_t *addrlen);

// 关闭套接字
int close(int sockfd);
```

---

## 3. TCP 编程

### 3.1 TCP 服务器

```cpp
#include <iostream>
#include <cstring>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

class TCPServer {
public:
    TCPServer(int port) : port(port), serverFd(-1) { }
    
    bool start() {
        // 创建套接字
        serverFd = socket(AF_INET, SOCK_STREAM, 0);
        if (serverFd < 0) {
            std::cerr << "Failed to create socket" << std::endl;
            return false;
        }
        
        // 设置地址重用
        int opt = 1;
        setsockopt(serverFd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
        
        // 绑定地址
        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port);
        
        if (bind(serverFd, (sockaddr*)&addr, sizeof(addr)) < 0) {
            std::cerr << "Failed to bind" << std::endl;
            return false;
        }
        
        // 开始监听
        if (listen(serverFd, 10) < 0) {
            std::cerr << "Failed to listen" << std::endl;
            return false;
        }
        
        std::cout << "Server listening on port " << port << std::endl;
        return true;
    }
    
    void run() {
        while (true) {
            sockaddr_in clientAddr{};
            socklen_t clientLen = sizeof(clientAddr);
            
            int clientFd = accept(serverFd, (sockaddr*)&clientAddr, &clientLen);
            if (clientFd < 0) {
                std::cerr << "Failed to accept" << std::endl;
                continue;
            }
            
            std::cout << "Client connected" << std::endl;
            handleClient(clientFd);
            close(clientFd);
        }
    }
    
    ~TCPServer() {
        if (serverFd >= 0) {
            close(serverFd);
        }
    }

private:
    void handleClient(int clientFd) {
        char buffer[1024];
        
        while (true) {
            ssize_t bytesRead = recv(clientFd, buffer, sizeof(buffer) - 1, 0);
            if (bytesRead <= 0) {
                break;
            }
            
            buffer[bytesRead] = '\0';
            std::cout << "Received: " << buffer << std::endl;
            
            // Echo back
            send(clientFd, buffer, bytesRead, 0);
        }
        
        std::cout << "Client disconnected" << std::endl;
    }
    
    int port;
    int serverFd;
};

int main() {
    TCPServer server(8080);
    if (server.start()) {
        server.run();
    }
    return 0;
}
```

### 3.2 TCP 客户端

```cpp
#include <iostream>
#include <cstring>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>

class TCPClient {
public:
    TCPClient(const std::string& host, int port) 
        : host(host), port(port), sockFd(-1) { }
    
    bool connect() {
        sockFd = socket(AF_INET, SOCK_STREAM, 0);
        if (sockFd < 0) {
            std::cerr << "Failed to create socket" << std::endl;
            return false;
        }
        
        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_port = htons(port);
        
        if (inet_pton(AF_INET, host.c_str(), &addr.sin_addr) <= 0) {
            std::cerr << "Invalid address" << std::endl;
            return false;
        }
        
        if (::connect(sockFd, (sockaddr*)&addr, sizeof(addr)) < 0) {
            std::cerr << "Connection failed" << std::endl;
            return false;
        }
        
        std::cout << "Connected to " << host << ":" << port << std::endl;
        return true;
    }
    
    bool send(const std::string& message) {
        ssize_t sent = ::send(sockFd, message.c_str(), message.size(), 0);
        return sent == static_cast<ssize_t>(message.size());
    }
    
    std::string receive() {
        char buffer[1024];
        ssize_t bytesRead = recv(sockFd, buffer, sizeof(buffer) - 1, 0);
        if (bytesRead > 0) {
            buffer[bytesRead] = '\0';
            return std::string(buffer);
        }
        return "";
    }
    
    ~TCPClient() {
        if (sockFd >= 0) {
            close(sockFd);
        }
    }

private:
    std::string host;
    int port;
    int sockFd;
};

int main() {
    TCPClient client("127.0.0.1", 8080);
    
    if (client.connect()) {
        client.send("Hello, Server!");
        std::string response = client.receive();
        std::cout << "Response: " << response << std::endl;
    }
    
    return 0;
}
```

### 3.3 多线程服务器

```cpp
#include <iostream>
#include <thread>
#include <vector>
#include <cstring>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

class MultithreadedServer {
public:
    MultithreadedServer(int port) : port(port), serverFd(-1), running(false) { }
    
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
        
        running = true;
        std::cout << "Server started on port " << port << std::endl;
        return true;
    }
    
    void run() {
        while (running) {
            sockaddr_in clientAddr{};
            socklen_t clientLen = sizeof(clientAddr);
            
            int clientFd = accept(serverFd, (sockaddr*)&clientAddr, &clientLen);
            if (clientFd < 0) continue;
            
            // 为每个客户端创建新线程
            std::thread([this, clientFd]() {
                handleClient(clientFd);
            }).detach();
        }
    }
    
    void stop() {
        running = false;
        close(serverFd);
    }

private:
    void handleClient(int clientFd) {
        char buffer[1024];
        
        while (running) {
            ssize_t bytesRead = recv(clientFd, buffer, sizeof(buffer) - 1, 0);
            if (bytesRead <= 0) break;
            
            buffer[bytesRead] = '\0';
            std::cout << "Thread " << std::this_thread::get_id() 
                      << " received: " << buffer << std::endl;
            
            send(clientFd, buffer, bytesRead, 0);
        }
        
        close(clientFd);
    }
    
    int port;
    int serverFd;
    bool running;
};
```

---

## 4. UDP 编程

### 4.1 UDP 服务器

```cpp
#include <iostream>
#include <cstring>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

class UDPServer {
public:
    UDPServer(int port) : port(port), sockFd(-1) { }
    
    bool start() {
        sockFd = socket(AF_INET, SOCK_DGRAM, 0);
        if (sockFd < 0) {
            std::cerr << "Failed to create socket" << std::endl;
            return false;
        }
        
        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port);
        
        if (bind(sockFd, (sockaddr*)&addr, sizeof(addr)) < 0) {
            std::cerr << "Failed to bind" << std::endl;
            return false;
        }
        
        std::cout << "UDP Server listening on port " << port << std::endl;
        return true;
    }
    
    void run() {
        char buffer[1024];
        sockaddr_in clientAddr{};
        socklen_t clientLen = sizeof(clientAddr);
        
        while (true) {
            ssize_t bytesRead = recvfrom(sockFd, buffer, sizeof(buffer) - 1, 0,
                                         (sockaddr*)&clientAddr, &clientLen);
            if (bytesRead < 0) continue;
            
            buffer[bytesRead] = '\0';
            std::cout << "Received: " << buffer << std::endl;
            
            // Echo back
            sendto(sockFd, buffer, bytesRead, 0,
                   (sockaddr*)&clientAddr, clientLen);
        }
    }
    
    ~UDPServer() {
        if (sockFd >= 0) {
            close(sockFd);
        }
    }

private:
    int port;
    int sockFd;
};
```

### 4.2 UDP 客户端

```cpp
#include <iostream>
#include <cstring>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>

class UDPClient {
public:
    UDPClient(const std::string& host, int port) 
        : host(host), port(port), sockFd(-1) {
        
        sockFd = socket(AF_INET, SOCK_DGRAM, 0);
        
        serverAddr.sin_family = AF_INET;
        serverAddr.sin_port = htons(port);
        inet_pton(AF_INET, host.c_str(), &serverAddr.sin_addr);
    }
    
    bool send(const std::string& message) {
        ssize_t sent = sendto(sockFd, message.c_str(), message.size(), 0,
                              (sockaddr*)&serverAddr, sizeof(serverAddr));
        return sent == static_cast<ssize_t>(message.size());
    }
    
    std::string receive() {
        char buffer[1024];
        sockaddr_in fromAddr{};
        socklen_t fromLen = sizeof(fromAddr);
        
        ssize_t bytesRead = recvfrom(sockFd, buffer, sizeof(buffer) - 1, 0,
                                     (sockaddr*)&fromAddr, &fromLen);
        if (bytesRead > 0) {
            buffer[bytesRead] = '\0';
            return std::string(buffer);
        }
        return "";
    }
    
    ~UDPClient() {
        if (sockFd >= 0) {
            close(sockFd);
        }
    }

private:
    std::string host;
    int port;
    int sockFd;
    sockaddr_in serverAddr;
};

int main() {
    UDPClient client("127.0.0.1", 8080);
    
    client.send("Hello, UDP Server!");
    std::string response = client.receive();
    std::cout << "Response: " << response << std::endl;
    
    return 0;
}
```

---

## 5. 地址处理

### 5.1 地址结构

```cpp
#include <netinet/in.h>
#include <arpa/inet.h>

// IPv4 地址结构
struct sockaddr_in {
    sa_family_t    sin_family;  // AF_INET
    in_port_t      sin_port;    // 端口号 (网络字节序)
    struct in_addr sin_addr;    // IP 地址
};

// IPv6 地址结构
struct sockaddr_in6 {
    sa_family_t     sin6_family;   // AF_INET6
    in_port_t       sin6_port;     // 端口号
    uint32_t        sin6_flowinfo; // 流信息
    struct in6_addr sin6_addr;     // IPv6 地址
    uint32_t        sin6_scope_id; // 作用域 ID
};
```

### 5.2 字节序转换

```cpp
#include <arpa/inet.h>

// 主机字节序 -> 网络字节序
uint16_t htons(uint16_t hostshort);  // short
uint32_t htonl(uint32_t hostlong);   // long

// 网络字节序 -> 主机字节序
uint16_t ntohs(uint16_t netshort);
uint32_t ntohl(uint32_t netlong);

// 示例
int port = 8080;
uint16_t netPort = htons(port);
```

### 5.3 地址转换

```cpp
#include <arpa/inet.h>
#include <iostream>

void addressConversion() {
    // 字符串 -> 二进制
    const char* ipStr = "192.168.1.1";
    struct in_addr addr;
    
    if (inet_pton(AF_INET, ipStr, &addr) == 1) {
        std::cout << "Converted successfully" << std::endl;
    }
    
    // 二进制 -> 字符串
    char buffer[INET_ADDRSTRLEN];
    if (inet_ntop(AF_INET, &addr, buffer, sizeof(buffer))) {
        std::cout << "IP: " << buffer << std::endl;
    }
    
    // IPv6
    const char* ip6Str = "::1";
    struct in6_addr addr6;
    
    inet_pton(AF_INET6, ip6Str, &addr6);
    
    char buffer6[INET6_ADDRSTRLEN];
    inet_ntop(AF_INET6, &addr6, buffer6, sizeof(buffer6));
}
```

### 5.4 DNS 解析

```cpp
#include <netdb.h>
#include <iostream>
#include <cstring>

void resolveDNS(const char* hostname) {
    struct addrinfo hints{}, *result;
    
    hints.ai_family = AF_UNSPEC;     // IPv4 或 IPv6
    hints.ai_socktype = SOCK_STREAM; // TCP
    
    int status = getaddrinfo(hostname, "80", &hints, &result);
    if (status != 0) {
        std::cerr << "getaddrinfo: " << gai_strerror(status) << std::endl;
        return;
    }
    
    for (struct addrinfo* p = result; p != nullptr; p = p->ai_next) {
        char ipstr[INET6_ADDRSTRLEN];
        void* addr;
        
        if (p->ai_family == AF_INET) {
            struct sockaddr_in* ipv4 = (struct sockaddr_in*)p->ai_addr;
            addr = &(ipv4->sin_addr);
        } else {
            struct sockaddr_in6* ipv6 = (struct sockaddr_in6*)p->ai_addr;
            addr = &(ipv6->sin6_addr);
        }
        
        inet_ntop(p->ai_family, addr, ipstr, sizeof(ipstr));
        std::cout << "IP: " << ipstr << std::endl;
    }
    
    freeaddrinfo(result);
}

int main() {
    resolveDNS("www.google.com");
    return 0;
}
```

---

## 6. 总结

### 6.1 Socket API

| 函数 | 说明 |
|------|------|
| socket() | 创建套接字 |
| bind() | 绑定地址 |
| listen() | 开始监听 |
| accept() | 接受连接 |
| connect() | 连接服务器 |
| send()/recv() | TCP 收发 |
| sendto()/recvfrom() | UDP 收发 |
| close() | 关闭套接字 |

### 6.2 TCP vs UDP

| 特性 | TCP | UDP |
|------|-----|-----|
| 连接 | 面向连接 | 无连接 |
| 可靠性 | 可靠 | 不可靠 |
| 顺序 | 有序 | 可能乱序 |
| 速度 | 较慢 | 较快 |

### 6.3 下一篇预告

在下一篇文章中,我们将学习 I/O 多路复用。

---

> 作者: C++ 技术专栏  
> 系列: 网络编程 (1/4)  
> 上一篇: [线程池](../part6-concurrency/46-thread-pool.md)  
> 下一篇: [I/O 多路复用](./48-io-multiplexing.md)
