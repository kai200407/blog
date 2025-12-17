---
title: "HTTP 框架"
description: "1. [框架设计](#1-框架设计)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 60
---

> 本文是 C++ 从入门到精通系列的第六十篇,将实现一个现代 C++ HTTP 框架。

---

## 目录

1. [框架设计](#1-框架设计)
2. [核心组件](#2-核心组件)
3. [路由系统](#3-路由系统)
4. [中间件](#4-中间件)
5. [完整示例](#5-完整示例)
6. [总结](#6-总结)

---

## 1. 框架设计

### 1.1 设计目标

```
设计目标:
- 简洁易用的 API
- 高性能
- 可扩展
- 类型安全

核心特性:
- RESTful 路由
- 中间件支持
- JSON 处理
- 静态文件服务
```

### 1.2 项目结构

```
http-framework/
├── include/
│   └── http/
│       ├── http.hpp
│       ├── server.hpp
│       ├── request.hpp
│       ├── response.hpp
│       ├── router.hpp
│       └── middleware.hpp
├── src/
│   ├── server.cpp
│   ├── request.cpp
│   ├── response.cpp
│   └── router.cpp
├── examples/
│   └── main.cpp
└── CMakeLists.txt
```

---

## 2. 核心组件

### 2.1 Request 类

```cpp
// include/http/request.hpp
#pragma once

#include <string>
#include <map>
#include <optional>

namespace http {

class Request {
public:
    // HTTP 方法
    enum class Method {
        GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS
    };
    
    // 解析请求
    static std::optional<Request> parse(const std::string& raw);
    
    // 访问器
    Method method() const { return method_; }
    const std::string& path() const { return path_; }
    const std::string& version() const { return version_; }
    const std::string& body() const { return body_; }
    
    // 头部
    std::string header(const std::string& key) const;
    const std::map<std::string, std::string>& headers() const { return headers_; }
    
    // 查询参数
    std::string query(const std::string& key) const;
    const std::map<std::string, std::string>& queries() const { return queries_; }
    
    // 路径参数 (由路由器设置)
    std::string param(const std::string& key) const;
    void setParam(const std::string& key, const std::string& value);
    
    // 方法转换
    static Method parseMethod(const std::string& method);
    static std::string methodToString(Method method);

private:
    Method method_;
    std::string path_;
    std::string version_;
    std::map<std::string, std::string> headers_;
    std::map<std::string, std::string> queries_;
    std::map<std::string, std::string> params_;
    std::string body_;
};

} // namespace http
```

### 2.2 Request 实现

```cpp
// src/request.cpp
#include "http/request.hpp"
#include <sstream>
#include <algorithm>

namespace http {

std::optional<Request> Request::parse(const std::string& raw) {
    Request req;
    std::istringstream stream(raw);
    std::string line;
    
    // 解析请求行
    if (!std::getline(stream, line)) {
        return std::nullopt;
    }
    
    // 移除 \r
    if (!line.empty() && line.back() == '\r') {
        line.pop_back();
    }
    
    std::istringstream requestLine(line);
    std::string method, path;
    
    if (!(requestLine >> method >> path >> req.version_)) {
        return std::nullopt;
    }
    
    req.method_ = parseMethod(method);
    
    // 解析查询字符串
    size_t queryPos = path.find('?');
    if (queryPos != std::string::npos) {
        std::string queryString = path.substr(queryPos + 1);
        req.path_ = path.substr(0, queryPos);
        
        std::istringstream queryStream(queryString);
        std::string pair;
        while (std::getline(queryStream, pair, '&')) {
            size_t eqPos = pair.find('=');
            if (eqPos != std::string::npos) {
                req.queries_[pair.substr(0, eqPos)] = pair.substr(eqPos + 1);
            }
        }
    } else {
        req.path_ = path;
    }
    
    // 解析头部
    while (std::getline(stream, line)) {
        if (!line.empty() && line.back() == '\r') {
            line.pop_back();
        }
        
        if (line.empty()) {
            break;
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
            
            req.headers_[key] = value;
        }
    }
    
    // 解析请求体
    std::ostringstream bodyStream;
    bodyStream << stream.rdbuf();
    req.body_ = bodyStream.str();
    
    return req;
}

std::string Request::header(const std::string& key) const {
    auto it = headers_.find(key);
    return it != headers_.end() ? it->second : "";
}

std::string Request::query(const std::string& key) const {
    auto it = queries_.find(key);
    return it != queries_.end() ? it->second : "";
}

std::string Request::param(const std::string& key) const {
    auto it = params_.find(key);
    return it != params_.end() ? it->second : "";
}

void Request::setParam(const std::string& key, const std::string& value) {
    params_[key] = value;
}

Request::Method Request::parseMethod(const std::string& method) {
    if (method == "GET") return Method::GET;
    if (method == "POST") return Method::POST;
    if (method == "PUT") return Method::PUT;
    if (method == "DELETE") return Method::DELETE;
    if (method == "PATCH") return Method::PATCH;
    if (method == "HEAD") return Method::HEAD;
    if (method == "OPTIONS") return Method::OPTIONS;
    return Method::GET;
}

std::string Request::methodToString(Method method) {
    switch (method) {
        case Method::GET: return "GET";
        case Method::POST: return "POST";
        case Method::PUT: return "PUT";
        case Method::DELETE: return "DELETE";
        case Method::PATCH: return "PATCH";
        case Method::HEAD: return "HEAD";
        case Method::OPTIONS: return "OPTIONS";
    }
    return "GET";
}

} // namespace http
```

### 2.3 Response 类

```cpp
// include/http/response.hpp
#pragma once

#include <string>
#include <map>
#include <sstream>

namespace http {

class Response {
public:
    Response() : statusCode_(200), statusText_("OK") { }
    
    // 状态
    Response& status(int code);
    Response& status(int code, const std::string& text);
    
    // 头部
    Response& header(const std::string& key, const std::string& value);
    Response& contentType(const std::string& type);
    
    // 响应体
    Response& body(const std::string& content);
    Response& json(const std::string& jsonContent);
    Response& html(const std::string& htmlContent);
    Response& text(const std::string& textContent);
    
    // 重定向
    Response& redirect(const std::string& url, int code = 302);
    
    // 生成响应字符串
    std::string toString() const;
    
    // 便捷方法
    static Response ok(const std::string& body = "");
    static Response notFound();
    static Response badRequest(const std::string& message = "Bad Request");
    static Response internalError(const std::string& message = "Internal Server Error");

private:
    int statusCode_;
    std::string statusText_;
    std::map<std::string, std::string> headers_;
    std::string body_;
};

} // namespace http
```

### 2.4 Response 实现

```cpp
// src/response.cpp
#include "http/response.hpp"

namespace http {

Response& Response::status(int code) {
    statusCode_ = code;
    
    switch (code) {
        case 200: statusText_ = "OK"; break;
        case 201: statusText_ = "Created"; break;
        case 204: statusText_ = "No Content"; break;
        case 301: statusText_ = "Moved Permanently"; break;
        case 302: statusText_ = "Found"; break;
        case 304: statusText_ = "Not Modified"; break;
        case 400: statusText_ = "Bad Request"; break;
        case 401: statusText_ = "Unauthorized"; break;
        case 403: statusText_ = "Forbidden"; break;
        case 404: statusText_ = "Not Found"; break;
        case 500: statusText_ = "Internal Server Error"; break;
        default: statusText_ = "Unknown"; break;
    }
    
    return *this;
}

Response& Response::status(int code, const std::string& text) {
    statusCode_ = code;
    statusText_ = text;
    return *this;
}

Response& Response::header(const std::string& key, const std::string& value) {
    headers_[key] = value;
    return *this;
}

Response& Response::contentType(const std::string& type) {
    return header("Content-Type", type);
}

Response& Response::body(const std::string& content) {
    body_ = content;
    header("Content-Length", std::to_string(body_.size()));
    return *this;
}

Response& Response::json(const std::string& jsonContent) {
    contentType("application/json");
    return body(jsonContent);
}

Response& Response::html(const std::string& htmlContent) {
    contentType("text/html; charset=utf-8");
    return body(htmlContent);
}

Response& Response::text(const std::string& textContent) {
    contentType("text/plain; charset=utf-8");
    return body(textContent);
}

Response& Response::redirect(const std::string& url, int code) {
    status(code);
    header("Location", url);
    return *this;
}

std::string Response::toString() const {
    std::ostringstream response;
    
    response << "HTTP/1.1 " << statusCode_ << " " << statusText_ << "\r\n";
    
    for (const auto& [key, value] : headers_) {
        response << key << ": " << value << "\r\n";
    }
    
    response << "\r\n";
    response << body_;
    
    return response.str();
}

Response Response::ok(const std::string& body) {
    Response resp;
    resp.status(200);
    if (!body.empty()) {
        resp.body(body);
    }
    return resp;
}

Response Response::notFound() {
    Response resp;
    resp.status(404);
    resp.html("<h1>404 Not Found</h1>");
    return resp;
}

Response Response::badRequest(const std::string& message) {
    Response resp;
    resp.status(400);
    resp.html("<h1>400 Bad Request</h1><p>" + message + "</p>");
    return resp;
}

Response Response::internalError(const std::string& message) {
    Response resp;
    resp.status(500);
    resp.html("<h1>500 Internal Server Error</h1><p>" + message + "</p>");
    return resp;
}

} // namespace http
```

---

## 3. 路由系统

### 3.1 Router 类

```cpp
// include/http/router.hpp
#pragma once

#include "request.hpp"
#include "response.hpp"
#include <functional>
#include <vector>
#include <regex>

namespace http {

using Handler = std::function<Response(Request&)>;

class Router {
public:
    // 路由注册
    void get(const std::string& path, Handler handler);
    void post(const std::string& path, Handler handler);
    void put(const std::string& path, Handler handler);
    void del(const std::string& path, Handler handler);
    void patch(const std::string& path, Handler handler);
    
    // 通用路由
    void route(Request::Method method, const std::string& path, Handler handler);
    
    // 路由匹配
    std::optional<Handler> match(Request& request);
    
    // 分组路由
    Router& group(const std::string& prefix);

private:
    struct Route {
        Request::Method method;
        std::string pattern;
        std::regex regex;
        std::vector<std::string> paramNames;
        Handler handler;
    };
    
    static std::pair<std::regex, std::vector<std::string>> 
        compilePattern(const std::string& pattern);
    
    std::vector<Route> routes_;
    std::string prefix_;
};

} // namespace http
```

### 3.2 Router 实现

```cpp
// src/router.cpp
#include "http/router.hpp"

namespace http {

void Router::get(const std::string& path, Handler handler) {
    route(Request::Method::GET, path, std::move(handler));
}

void Router::post(const std::string& path, Handler handler) {
    route(Request::Method::POST, path, std::move(handler));
}

void Router::put(const std::string& path, Handler handler) {
    route(Request::Method::PUT, path, std::move(handler));
}

void Router::del(const std::string& path, Handler handler) {
    route(Request::Method::DELETE, path, std::move(handler));
}

void Router::patch(const std::string& path, Handler handler) {
    route(Request::Method::PATCH, path, std::move(handler));
}

void Router::route(Request::Method method, const std::string& path, Handler handler) {
    Route route;
    route.method = method;
    route.pattern = prefix_ + path;
    
    auto [regex, paramNames] = compilePattern(route.pattern);
    route.regex = std::move(regex);
    route.paramNames = std::move(paramNames);
    route.handler = std::move(handler);
    
    routes_.push_back(std::move(route));
}

std::optional<Handler> Router::match(Request& request) {
    for (const auto& route : routes_) {
        if (route.method != request.method()) {
            continue;
        }
        
        std::smatch matches;
        std::string path = request.path();
        
        if (std::regex_match(path, matches, route.regex)) {
            // 提取路径参数
            for (size_t i = 0; i < route.paramNames.size(); ++i) {
                request.setParam(route.paramNames[i], matches[i + 1].str());
            }
            return route.handler;
        }
    }
    
    return std::nullopt;
}

Router& Router::group(const std::string& prefix) {
    prefix_ += prefix;
    return *this;
}

std::pair<std::regex, std::vector<std::string>> 
Router::compilePattern(const std::string& pattern) {
    std::vector<std::string> paramNames;
    std::string regexPattern;
    
    size_t i = 0;
    while (i < pattern.size()) {
        if (pattern[i] == ':') {
            // 路径参数
            size_t start = ++i;
            while (i < pattern.size() && 
                   (std::isalnum(pattern[i]) || pattern[i] == '_')) {
                ++i;
            }
            
            std::string paramName = pattern.substr(start, i - start);
            paramNames.push_back(paramName);
            regexPattern += "([^/]+)";
        } else if (pattern[i] == '*') {
            // 通配符
            regexPattern += ".*";
            ++i;
        } else {
            // 普通字符
            if (pattern[i] == '.' || pattern[i] == '?' || 
                pattern[i] == '+' || pattern[i] == '(' || 
                pattern[i] == ')' || pattern[i] == '[' || 
                pattern[i] == ']' || pattern[i] == '{' || 
                pattern[i] == '}' || pattern[i] == '\\' ||
                pattern[i] == '^' || pattern[i] == '$') {
                regexPattern += '\\';
            }
            regexPattern += pattern[i];
            ++i;
        }
    }
    
    return {std::regex("^" + regexPattern + "$"), paramNames};
}

} // namespace http
```

---

## 4. 中间件

### 4.1 Middleware 定义

```cpp
// include/http/middleware.hpp
#pragma once

#include "request.hpp"
#include "response.hpp"
#include <functional>
#include <vector>

namespace http {

using Next = std::function<Response()>;
using Middleware = std::function<Response(Request&, Next)>;

class MiddlewareChain {
public:
    void use(Middleware middleware);
    Response execute(Request& request, Handler finalHandler);

private:
    std::vector<Middleware> middlewares_;
};

// 内置中间件
namespace middleware {

// 日志中间件
Middleware logger();

// CORS 中间件
Middleware cors(const std::string& origin = "*");

// 静态文件中间件
Middleware staticFiles(const std::string& root, const std::string& prefix = "/static");

// 请求体解析中间件
Middleware bodyParser();

// 错误处理中间件
Middleware errorHandler();

} // namespace middleware

} // namespace http
```

### 4.2 Middleware 实现

```cpp
// src/middleware.cpp
#include "http/middleware.hpp"
#include <iostream>
#include <chrono>
#include <fstream>
#include <filesystem>

namespace http {

void MiddlewareChain::use(Middleware middleware) {
    middlewares_.push_back(std::move(middleware));
}

Response MiddlewareChain::execute(Request& request, Handler finalHandler) {
    size_t index = 0;
    
    std::function<Response()> next = [&]() -> Response {
        if (index < middlewares_.size()) {
            return middlewares_[index++](request, next);
        } else {
            return finalHandler(request);
        }
    };
    
    return next();
}

namespace middleware {

Middleware logger() {
    return [](Request& req, Next next) -> Response {
        auto start = std::chrono::high_resolution_clock::now();
        
        Response resp = next();
        
        auto end = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration<double, std::milli>(end - start);
        
        std::cout << Request::methodToString(req.method()) << " "
                  << req.path() << " - " 
                  << duration.count() << "ms" << std::endl;
        
        return resp;
    };
}

Middleware cors(const std::string& origin) {
    return [origin](Request& req, Next next) -> Response {
        Response resp = next();
        
        resp.header("Access-Control-Allow-Origin", origin);
        resp.header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
        resp.header("Access-Control-Allow-Headers", "Content-Type, Authorization");
        
        return resp;
    };
}

Middleware staticFiles(const std::string& root, const std::string& prefix) {
    return [root, prefix](Request& req, Next next) -> Response {
        if (req.method() != Request::Method::GET) {
            return next();
        }
        
        std::string path = req.path();
        if (path.find(prefix) != 0) {
            return next();
        }
        
        std::string filePath = root + path.substr(prefix.size());
        
        // 安全检查
        if (filePath.find("..") != std::string::npos) {
            return Response::badRequest("Invalid path");
        }
        
        if (!std::filesystem::exists(filePath)) {
            return next();
        }
        
        std::ifstream file(filePath, std::ios::binary);
        if (!file) {
            return next();
        }
        
        std::ostringstream content;
        content << file.rdbuf();
        
        Response resp;
        resp.status(200);
        
        // 设置 Content-Type
        std::string ext = std::filesystem::path(filePath).extension();
        if (ext == ".html") resp.contentType("text/html");
        else if (ext == ".css") resp.contentType("text/css");
        else if (ext == ".js") resp.contentType("application/javascript");
        else if (ext == ".json") resp.contentType("application/json");
        else if (ext == ".png") resp.contentType("image/png");
        else if (ext == ".jpg" || ext == ".jpeg") resp.contentType("image/jpeg");
        else resp.contentType("application/octet-stream");
        
        resp.body(content.str());
        return resp;
    };
}

Middleware errorHandler() {
    return [](Request& req, Next next) -> Response {
        try {
            return next();
        } catch (const std::exception& e) {
            std::cerr << "Error: " << e.what() << std::endl;
            return Response::internalError(e.what());
        } catch (...) {
            std::cerr << "Unknown error" << std::endl;
            return Response::internalError("Unknown error");
        }
    };
}

} // namespace middleware

} // namespace http
```

---

## 5. 完整示例

### 5.1 Server 类

```cpp
// include/http/server.hpp
#pragma once

#include "router.hpp"
#include "middleware.hpp"
#include <thread>
#include <atomic>

namespace http {

class Server {
public:
    Server(int port = 8080);
    ~Server();
    
    // 路由
    void get(const std::string& path, Handler handler);
    void post(const std::string& path, Handler handler);
    void put(const std::string& path, Handler handler);
    void del(const std::string& path, Handler handler);
    
    // 中间件
    void use(Middleware middleware);
    
    // 启动/停止
    void start();
    void stop();

private:
    void handleConnection(int clientFd);
    
    int port_;
    int serverFd_;
    std::atomic<bool> running_;
    Router router_;
    MiddlewareChain middlewares_;
};

} // namespace http
```

### 5.2 使用示例

```cpp
// examples/main.cpp
#include "http/http.hpp"
#include <iostream>

int main() {
    http::Server server(8080);
    
    // 中间件
    server.use(http::middleware::logger());
    server.use(http::middleware::cors());
    server.use(http::middleware::errorHandler());
    
    // 路由
    server.get("/", [](http::Request& req) {
        return http::Response::ok()
            .html("<h1>Welcome to C++ HTTP Framework</h1>");
    });
    
    server.get("/api/hello", [](http::Request& req) {
        std::string name = req.query("name");
        if (name.empty()) name = "World";
        
        return http::Response::ok()
            .json(R"({"message": "Hello, )" + name + R"(!"})");
    });
    
    server.get("/api/users/:id", [](http::Request& req) {
        std::string id = req.param("id");
        
        return http::Response::ok()
            .json(R"({"id": ")" + id + R"(", "name": "User )" + id + R"("})");
    });
    
    server.post("/api/users", [](http::Request& req) {
        std::string body = req.body();
        
        return http::Response::ok()
            .status(201)
            .json(R"({"status": "created", "data": )" + body + "}");
    });
    
    server.get("/api/error", [](http::Request& req) {
        throw std::runtime_error("Test error");
        return http::Response::ok();
    });
    
    std::cout << "Server starting on port 8080..." << std::endl;
    server.start();
    
    return 0;
}
```

### 5.3 CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.20)
project(http-framework VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 库
add_library(http
    src/request.cpp
    src/response.cpp
    src/router.cpp
    src/middleware.cpp
    src/server.cpp
)

target_include_directories(http PUBLIC include)

# 示例
add_executable(example examples/main.cpp)
target_link_libraries(example PRIVATE http)

# 测试
enable_testing()
add_subdirectory(tests)
```

---

## 6. 总结

### 6.1 框架特性

| 特性 | 说明 |
|------|------|
| RESTful 路由 | 支持路径参数 |
| 中间件 | 可组合的请求处理 |
| 类型安全 | 现代 C++ API |
| 易于扩展 | 模块化设计 |

### 6.2 API 概览

```cpp
// 创建服务器
http::Server server(8080);

// 添加中间件
server.use(http::middleware::logger());

// 定义路由
server.get("/path", handler);
server.post("/path", handler);

// 启动服务器
server.start();
```

### 6.3 下一篇预告

在下一篇文章中,我们将实现一个简单的数据库引擎。

---

> 作者: C++ 技术专栏  
> 系列: 项目实战 (2/4)  
> 上一篇: [JSON 解析器](./59-json-parser.md)  
> 下一篇: [数据库引擎](./61-database-engine.md)
