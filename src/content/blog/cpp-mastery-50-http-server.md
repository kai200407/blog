---
title: "HTTP 服务器"
description: "1. [HTTP 协议基础](#1-http-协议基础)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 50
---

> 本文是 C++ 从入门到精通系列的第五十篇,也是网络编程部分的收官之作。我们将实现一个简单的 HTTP 服务器。

---

## 目录

1. [HTTP 协议基础](#1-http-协议基础)
2. [请求解析](#2-请求解析)
3. [响应构建](#3-响应构建)
4. [完整服务器](#4-完整服务器)
5. [性能优化](#5-性能优化)
6. [总结](#6-总结)

---

## 1. HTTP 协议基础

### 1.1 HTTP 请求格式

```
HTTP 请求格式:

请求行: 方法 路径 版本
GET /index.html HTTP/1.1

请求头:
Host: www.example.com
User-Agent: Mozilla/5.0
Accept: text/html
Connection: keep-alive

空行

请求体 (可选):
name=value&other=data
```

### 1.2 HTTP 响应格式

```
HTTP 响应格式:

状态行: 版本 状态码 状态描述
HTTP/1.1 200 OK

响应头:
Content-Type: text/html
Content-Length: 1234
Connection: keep-alive

空行

响应体:
<html>...</html>
```

### 1.3 常见状态码

```
状态码分类:

1xx: 信息
2xx: 成功
  200 OK
  201 Created
  204 No Content
3xx: 重定向
  301 Moved Permanently
  302 Found
  304 Not Modified
4xx: 客户端错误
  400 Bad Request
  401 Unauthorized
  403 Forbidden
  404 Not Found
5xx: 服务器错误
  500 Internal Server Error
  502 Bad Gateway
  503 Service Unavailable
```

---

## 2. 请求解析

### 2.1 HTTP 请求类

```cpp
#include <iostream>
#include <string>
#include <map>
#include <sstream>

class HttpRequest {
public:
    std::string method;
    std::string path;
    std::string version;
    std::map<std::string, std::string> headers;
    std::string body;
    std::map<std::string, std::string> queryParams;
    
    bool parse(const std::string& raw) {
        std::istringstream stream(raw);
        std::string line;
        
        // 解析请求行
        if (!std::getline(stream, line)) {
            return false;
        }
        
        // 移除 \r
        if (!line.empty() && line.back() == '\r') {
            line.pop_back();
        }
        
        std::istringstream requestLine(line);
        if (!(requestLine >> method >> path >> version)) {
            return false;
        }
        
        // 解析查询参数
        size_t queryPos = path.find('?');
        if (queryPos != std::string::npos) {
            std::string query = path.substr(queryPos + 1);
            path = path.substr(0, queryPos);
            parseQueryString(query);
        }
        
        // 解析请求头
        while (std::getline(stream, line)) {
            if (!line.empty() && line.back() == '\r') {
                line.pop_back();
            }
            
            if (line.empty()) {
                break;  // 空行,请求头结束
            }
            
            size_t colonPos = line.find(':');
            if (colonPos != std::string::npos) {
                std::string key = line.substr(0, colonPos);
                std::string value = line.substr(colonPos + 1);
                
                // 去除前导空格
                size_t start = value.find_first_not_of(' ');
                if (start != std::string::npos) {
                    value = value.substr(start);
                }
                
                headers[key] = value;
            }
        }
        
        // 解析请求体
        std::ostringstream bodyStream;
        bodyStream << stream.rdbuf();
        body = bodyStream.str();
        
        return true;
    }
    
    std::string getHeader(const std::string& key) const {
        auto it = headers.find(key);
        return it != headers.end() ? it->second : "";
    }
    
    std::string getQueryParam(const std::string& key) const {
        auto it = queryParams.find(key);
        return it != queryParams.end() ? it->second : "";
    }

private:
    void parseQueryString(const std::string& query) {
        std::istringstream stream(query);
        std::string pair;
        
        while (std::getline(stream, pair, '&')) {
            size_t eqPos = pair.find('=');
            if (eqPos != std::string::npos) {
                std::string key = pair.substr(0, eqPos);
                std::string value = pair.substr(eqPos + 1);
                queryParams[key] = urlDecode(value);
            }
        }
    }
    
    std::string urlDecode(const std::string& str) {
        std::string result;
        for (size_t i = 0; i < str.size(); ++i) {
            if (str[i] == '%' && i + 2 < str.size()) {
                int value;
                std::istringstream iss(str.substr(i + 1, 2));
                if (iss >> std::hex >> value) {
                    result += static_cast<char>(value);
                    i += 2;
                }
            } else if (str[i] == '+') {
                result += ' ';
            } else {
                result += str[i];
            }
        }
        return result;
    }
};
```

---

## 3. 响应构建

### 3.1 HTTP 响应类

```cpp
#include <string>
#include <map>
#include <sstream>

class HttpResponse {
public:
    int statusCode = 200;
    std::string statusText = "OK";
    std::map<std::string, std::string> headers;
    std::string body;
    
    HttpResponse() {
        headers["Content-Type"] = "text/html; charset=utf-8";
        headers["Connection"] = "close";
    }
    
    void setStatus(int code, const std::string& text) {
        statusCode = code;
        statusText = text;
    }
    
    void setHeader(const std::string& key, const std::string& value) {
        headers[key] = value;
    }
    
    void setBody(const std::string& content) {
        body = content;
        headers["Content-Length"] = std::to_string(body.size());
    }
    
    void setContentType(const std::string& type) {
        headers["Content-Type"] = type;
    }
    
    std::string toString() const {
        std::ostringstream response;
        
        // 状态行
        response << "HTTP/1.1 " << statusCode << " " << statusText << "\r\n";
        
        // 响应头
        for (const auto& [key, value] : headers) {
            response << key << ": " << value << "\r\n";
        }
        
        // 空行
        response << "\r\n";
        
        // 响应体
        response << body;
        
        return response.str();
    }
    
    // 便捷方法
    static HttpResponse ok(const std::string& body) {
        HttpResponse resp;
        resp.setBody(body);
        return resp;
    }
    
    static HttpResponse notFound() {
        HttpResponse resp;
        resp.setStatus(404, "Not Found");
        resp.setBody("<h1>404 Not Found</h1>");
        return resp;
    }
    
    static HttpResponse badRequest() {
        HttpResponse resp;
        resp.setStatus(400, "Bad Request");
        resp.setBody("<h1>400 Bad Request</h1>");
        return resp;
    }
    
    static HttpResponse internalError() {
        HttpResponse resp;
        resp.setStatus(500, "Internal Server Error");
        resp.setBody("<h1>500 Internal Server Error</h1>");
        return resp;
    }
    
    static HttpResponse json(const std::string& jsonBody) {
        HttpResponse resp;
        resp.setContentType("application/json");
        resp.setBody(jsonBody);
        return resp;
    }
};
```

---

## 4. 完整服务器

### 4.1 路由系统

```cpp
#include <functional>
#include <vector>
#include <regex>

class Router {
public:
    using Handler = std::function<HttpResponse(const HttpRequest&)>;
    
    void get(const std::string& path, Handler handler) {
        routes.push_back({"GET", path, std::move(handler)});
    }
    
    void post(const std::string& path, Handler handler) {
        routes.push_back({"POST", path, std::move(handler)});
    }
    
    void put(const std::string& path, Handler handler) {
        routes.push_back({"PUT", path, std::move(handler)});
    }
    
    void del(const std::string& path, Handler handler) {
        routes.push_back({"DELETE", path, std::move(handler)});
    }
    
    HttpResponse handle(const HttpRequest& request) {
        for (const auto& route : routes) {
            if (route.method == request.method && matchPath(route.path, request.path)) {
                try {
                    return route.handler(request);
                } catch (const std::exception& e) {
                    return HttpResponse::internalError();
                }
            }
        }
        return HttpResponse::notFound();
    }

private:
    struct Route {
        std::string method;
        std::string path;
        Handler handler;
    };
    
    std::vector<Route> routes;
    
    bool matchPath(const std::string& pattern, const std::string& path) {
        // 简单匹配,可以扩展为正则或参数匹配
        return pattern == path;
    }
};
```

### 4.2 HTTP 服务器

```cpp
#include <iostream>
#include <cstring>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <thread>
#include <vector>

class HttpServer {
public:
    HttpServer(int port) : port(port), serverFd(-1), running(false) { }
    
    Router& getRouter() {
        return router;
    }
    
    bool start() {
        serverFd = socket(AF_INET, SOCK_STREAM, 0);
        if (serverFd < 0) {
            std::cerr << "Failed to create socket" << std::endl;
            return false;
        }
        
        int opt = 1;
        setsockopt(serverFd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
        
        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(port);
        
        if (bind(serverFd, (sockaddr*)&addr, sizeof(addr)) < 0) {
            std::cerr << "Failed to bind" << std::endl;
            return false;
        }
        
        if (listen(serverFd, 10) < 0) {
            std::cerr << "Failed to listen" << std::endl;
            return false;
        }
        
        running = true;
        std::cout << "HTTP Server listening on port " << port << std::endl;
        return true;
    }
    
    void run() {
        while (running) {
            sockaddr_in clientAddr{};
            socklen_t clientLen = sizeof(clientAddr);
            
            int clientFd = accept(serverFd, (sockaddr*)&clientAddr, &clientLen);
            if (clientFd < 0) {
                if (running) {
                    std::cerr << "Accept failed" << std::endl;
                }
                continue;
            }
            
            // 为每个连接创建线程
            std::thread([this, clientFd]() {
                handleConnection(clientFd);
            }).detach();
        }
    }
    
    void stop() {
        running = false;
        if (serverFd >= 0) {
            close(serverFd);
        }
    }
    
    ~HttpServer() {
        stop();
    }

private:
    void handleConnection(int clientFd) {
        char buffer[8192];
        ssize_t bytesRead = recv(clientFd, buffer, sizeof(buffer) - 1, 0);
        
        if (bytesRead > 0) {
            buffer[bytesRead] = '\0';
            
            HttpRequest request;
            if (request.parse(buffer)) {
                std::cout << request.method << " " << request.path << std::endl;
                
                HttpResponse response = router.handle(request);
                std::string responseStr = response.toString();
                
                send(clientFd, responseStr.c_str(), responseStr.size(), 0);
            } else {
                HttpResponse response = HttpResponse::badRequest();
                std::string responseStr = response.toString();
                send(clientFd, responseStr.c_str(), responseStr.size(), 0);
            }
        }
        
        close(clientFd);
    }
    
    int port;
    int serverFd;
    bool running;
    Router router;
};
```

### 4.3 使用示例

```cpp
#include <iostream>
#include <sstream>

int main() {
    HttpServer server(8080);
    Router& router = server.getRouter();
    
    // 首页
    router.get("/", [](const HttpRequest& req) {
        return HttpResponse::ok(R"(
            <!DOCTYPE html>
            <html>
            <head><title>C++ HTTP Server</title></head>
            <body>
                <h1>Welcome to C++ HTTP Server</h1>
                <p>This is a simple HTTP server written in C++.</p>
                <ul>
                    <li><a href="/api/hello">Hello API</a></li>
                    <li><a href="/api/time">Time API</a></li>
                </ul>
            </body>
            </html>
        )");
    });
    
    // Hello API
    router.get("/api/hello", [](const HttpRequest& req) {
        std::string name = req.getQueryParam("name");
        if (name.empty()) name = "World";
        
        std::ostringstream json;
        json << R"({"message": "Hello, )" << name << R"(!"})";
        
        return HttpResponse::json(json.str());
    });
    
    // Time API
    router.get("/api/time", [](const HttpRequest& req) {
        auto now = std::chrono::system_clock::now();
        auto time = std::chrono::system_clock::to_time_t(now);
        
        std::ostringstream json;
        json << R"({"time": ")" << std::ctime(&time) << R"("})";
        
        return HttpResponse::json(json.str());
    });
    
    // Echo API
    router.post("/api/echo", [](const HttpRequest& req) {
        return HttpResponse::json(req.body);
    });
    
    if (server.start()) {
        server.run();
    }
    
    return 0;
}
```

---

## 5. 性能优化

### 5.1 Keep-Alive

```cpp
class KeepAliveHandler {
public:
    void handleConnection(int clientFd, Router& router) {
        char buffer[8192];
        
        while (true) {
            ssize_t bytesRead = recv(clientFd, buffer, sizeof(buffer) - 1, 0);
            if (bytesRead <= 0) break;
            
            buffer[bytesRead] = '\0';
            
            HttpRequest request;
            if (!request.parse(buffer)) {
                sendResponse(clientFd, HttpResponse::badRequest());
                break;
            }
            
            HttpResponse response = router.handle(request);
            
            // 检查 Connection 头
            std::string connection = request.getHeader("Connection");
            bool keepAlive = (connection == "keep-alive" || 
                             (request.version == "HTTP/1.1" && connection != "close"));
            
            if (keepAlive) {
                response.setHeader("Connection", "keep-alive");
                response.setHeader("Keep-Alive", "timeout=5, max=100");
            } else {
                response.setHeader("Connection", "close");
            }
            
            sendResponse(clientFd, response);
            
            if (!keepAlive) break;
        }
        
        close(clientFd);
    }

private:
    void sendResponse(int fd, const HttpResponse& response) {
        std::string str = response.toString();
        send(fd, str.c_str(), str.size(), 0);
    }
};
```

### 5.2 静态文件服务

```cpp
#include <fstream>
#include <filesystem>

class StaticFileHandler {
public:
    StaticFileHandler(const std::string& root) : rootPath(root) { }
    
    HttpResponse serve(const std::string& path) {
        std::string fullPath = rootPath + path;
        
        // 安全检查
        if (path.find("..") != std::string::npos) {
            return HttpResponse::badRequest();
        }
        
        // 检查文件是否存在
        if (!std::filesystem::exists(fullPath)) {
            return HttpResponse::notFound();
        }
        
        // 如果是目录,尝试 index.html
        if (std::filesystem::is_directory(fullPath)) {
            fullPath += "/index.html";
            if (!std::filesystem::exists(fullPath)) {
                return HttpResponse::notFound();
            }
        }
        
        // 读取文件
        std::ifstream file(fullPath, std::ios::binary);
        if (!file) {
            return HttpResponse::notFound();
        }
        
        std::ostringstream content;
        content << file.rdbuf();
        
        HttpResponse response;
        response.setBody(content.str());
        response.setContentType(getMimeType(fullPath));
        
        return response;
    }

private:
    std::string rootPath;
    
    std::string getMimeType(const std::string& path) {
        std::string ext = std::filesystem::path(path).extension();
        
        static const std::map<std::string, std::string> mimeTypes = {
            {".html", "text/html"},
            {".css", "text/css"},
            {".js", "application/javascript"},
            {".json", "application/json"},
            {".png", "image/png"},
            {".jpg", "image/jpeg"},
            {".gif", "image/gif"},
            {".svg", "image/svg+xml"},
            {".ico", "image/x-icon"},
            {".txt", "text/plain"},
        };
        
        auto it = mimeTypes.find(ext);
        return it != mimeTypes.end() ? it->second : "application/octet-stream";
    }
};
```

### 5.3 线程池集成

```cpp
// 使用之前实现的 ThreadPool

class ThreadPoolHttpServer {
public:
    ThreadPoolHttpServer(int port, size_t numThreads = 4) 
        : port(port), pool(numThreads), serverFd(-1), running(false) { }
    
    void run() {
        // ... 初始化代码 ...
        
        while (running) {
            int clientFd = accept(serverFd, nullptr, nullptr);
            if (clientFd < 0) continue;
            
            // 提交到线程池
            pool.submit([this, clientFd]() {
                handleConnection(clientFd);
            });
        }
    }

private:
    int port;
    ThreadPool pool;
    int serverFd;
    bool running;
    Router router;
    
    void handleConnection(int clientFd) {
        // ... 处理连接 ...
    }
};
```

---

## 6. 总结

### 6.1 HTTP 服务器组件

| 组件 | 功能 |
|------|------|
| 请求解析器 | 解析 HTTP 请求 |
| 响应构建器 | 构建 HTTP 响应 |
| 路由器 | 路由分发 |
| 连接处理器 | 处理客户端连接 |
| 静态文件服务 | 提供静态资源 |

### 6.2 优化策略

| 策略 | 效果 |
|------|------|
| Keep-Alive | 减少连接开销 |
| 线程池 | 控制并发 |
| epoll | 高效 I/O |
| 缓存 | 减少磁盘 I/O |
| 压缩 | 减少传输量 |

### 6.3 Part 7 完成

恭喜你完成了网络编程部分的全部 4 篇文章!

**实战项目建议**: RESTful API 服务器
- 实现 CRUD 操作
- 添加 JSON 解析
- 实现中间件机制
- 添加日志记录

### 6.4 下一篇预告

在下一篇文章中,我们将进入系统编程与性能优化部分,学习文件系统操作。

---

> 作者: C++ 技术专栏  
> 系列: 网络编程 (4/4)  
> 上一篇: [异步 I/O](./49-async-io.md)  
> 下一篇: [文件系统操作](../part8-system/51-filesystem.md)
