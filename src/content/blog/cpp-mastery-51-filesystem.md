---
title: "文件系统操作"
description: "1. [文件系统库概述](#1-文件系统库概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 51
---

> 本文是 C++ 从入门到精通系列的第五十一篇,将深入讲解 C++17 文件系统库和文件 I/O 操作。

---

## 目录

1. [文件系统库概述](#1-文件系统库概述)
2. [路径操作](#2-路径操作)
3. [目录操作](#3-目录操作)
4. [文件操作](#4-文件操作)
5. [文件 I/O](#5-文件-io)
6. [总结](#6-总结)

---

## 1. 文件系统库概述

### 1.1 C++17 filesystem

```cpp
#include <filesystem>
#include <iostream>

namespace fs = std::filesystem;

int main() {
    // 获取当前路径
    fs::path currentPath = fs::current_path();
    std::cout << "Current path: " << currentPath << std::endl;
    
    // 检查路径是否存在
    if (fs::exists(currentPath)) {
        std::cout << "Path exists" << std::endl;
    }
    
    // 检查是否是目录
    if (fs::is_directory(currentPath)) {
        std::cout << "Is directory" << std::endl;
    }
    
    return 0;
}
```

### 1.2 主要组件

```
filesystem 库组件:

路径类:
- std::filesystem::path

目录迭代器:
- directory_iterator
- recursive_directory_iterator

文件状态:
- file_status
- file_type
- perms

操作函数:
- exists, is_directory, is_regular_file
- create_directory, remove, copy
- file_size, last_write_time
```

---

## 2. 路径操作

### 2.1 路径构造

```cpp
#include <filesystem>
#include <iostream>

namespace fs = std::filesystem;

int main() {
    // 构造路径
    fs::path p1("/home/user/documents");
    fs::path p2("file.txt");
    fs::path p3 = p1 / p2;  // 路径拼接
    
    std::cout << "p3: " << p3 << std::endl;
    
    // 从字符串构造
    std::string str = "/var/log/app.log";
    fs::path p4(str);
    
    // 使用字面量
    using namespace std::filesystem;
    auto p5 = path("/tmp") / "test" / "file.txt";
    
    std::cout << "p5: " << p5 << std::endl;
    
    return 0;
}
```

### 2.2 路径分解

```cpp
#include <filesystem>
#include <iostream>

namespace fs = std::filesystem;

int main() {
    fs::path p("/home/user/documents/report.pdf");
    
    std::cout << "Full path: " << p << std::endl;
    std::cout << "Root name: " << p.root_name() << std::endl;
    std::cout << "Root directory: " << p.root_directory() << std::endl;
    std::cout << "Root path: " << p.root_path() << std::endl;
    std::cout << "Relative path: " << p.relative_path() << std::endl;
    std::cout << "Parent path: " << p.parent_path() << std::endl;
    std::cout << "Filename: " << p.filename() << std::endl;
    std::cout << "Stem: " << p.stem() << std::endl;
    std::cout << "Extension: " << p.extension() << std::endl;
    
    return 0;
}
```

### 2.3 路径修改

```cpp
#include <filesystem>
#include <iostream>

namespace fs = std::filesystem;

int main() {
    fs::path p("/home/user/file.txt");
    
    // 替换文件名
    p.replace_filename("newfile.txt");
    std::cout << "After replace_filename: " << p << std::endl;
    
    // 替换扩展名
    p.replace_extension(".md");
    std::cout << "After replace_extension: " << p << std::endl;
    
    // 移除文件名
    p.remove_filename();
    std::cout << "After remove_filename: " << p << std::endl;
    
    // 追加路径
    p /= "subdir";
    p /= "file.cpp";
    std::cout << "After append: " << p << std::endl;
    
    return 0;
}
```

### 2.4 路径比较和查询

```cpp
#include <filesystem>
#include <iostream>

namespace fs = std::filesystem;

int main() {
    fs::path p1("/home/user/../user/file.txt");
    fs::path p2("/home/user/file.txt");
    
    // 规范化路径
    std::cout << "Canonical p1: " << fs::weakly_canonical(p1) << std::endl;
    
    // 绝对路径
    fs::path relative("./test.txt");
    std::cout << "Absolute: " << fs::absolute(relative) << std::endl;
    
    // 相对路径
    fs::path base("/home/user");
    fs::path target("/home/user/documents/file.txt");
    std::cout << "Relative: " << fs::relative(target, base) << std::endl;
    
    // 路径查询
    std::cout << "Has root: " << p1.has_root_path() << std::endl;
    std::cout << "Has filename: " << p1.has_filename() << std::endl;
    std::cout << "Has extension: " << p1.has_extension() << std::endl;
    std::cout << "Is absolute: " << p1.is_absolute() << std::endl;
    std::cout << "Is relative: " << p1.is_relative() << std::endl;
    
    return 0;
}
```

---

## 3. 目录操作

### 3.1 创建和删除目录

```cpp
#include <filesystem>
#include <iostream>

namespace fs = std::filesystem;

int main() {
    // 创建单个目录
    fs::path dir1 = "test_dir";
    if (fs::create_directory(dir1)) {
        std::cout << "Created: " << dir1 << std::endl;
    }
    
    // 创建多级目录
    fs::path dir2 = "parent/child/grandchild";
    if (fs::create_directories(dir2)) {
        std::cout << "Created: " << dir2 << std::endl;
    }
    
    // 删除空目录
    if (fs::remove(dir1)) {
        std::cout << "Removed: " << dir1 << std::endl;
    }
    
    // 递归删除目录
    std::uintmax_t count = fs::remove_all("parent");
    std::cout << "Removed " << count << " items" << std::endl;
    
    return 0;
}
```

### 3.2 目录遍历

```cpp
#include <filesystem>
#include <iostream>

namespace fs = std::filesystem;

void listDirectory(const fs::path& dir) {
    std::cout << "Contents of " << dir << ":" << std::endl;
    
    for (const auto& entry : fs::directory_iterator(dir)) {
        std::cout << "  ";
        
        if (entry.is_directory()) {
            std::cout << "[DIR] ";
        } else if (entry.is_regular_file()) {
            std::cout << "[FILE] ";
        } else {
            std::cout << "[OTHER] ";
        }
        
        std::cout << entry.path().filename();
        
        if (entry.is_regular_file()) {
            std::cout << " (" << entry.file_size() << " bytes)";
        }
        
        std::cout << std::endl;
    }
}

void listRecursive(const fs::path& dir) {
    std::cout << "Recursive contents of " << dir << ":" << std::endl;
    
    for (const auto& entry : fs::recursive_directory_iterator(dir)) {
        // 计算深度
        auto relative = fs::relative(entry.path(), dir);
        int depth = std::distance(relative.begin(), relative.end()) - 1;
        
        std::cout << std::string(depth * 2, ' ');
        std::cout << entry.path().filename() << std::endl;
    }
}

int main() {
    fs::path currentDir = fs::current_path();
    listDirectory(currentDir);
    
    return 0;
}
```

### 3.3 目录迭代器选项

```cpp
#include <filesystem>
#include <iostream>

namespace fs = std::filesystem;

int main() {
    fs::path dir = "/tmp";
    
    // 跳过权限错误
    auto options = fs::directory_options::skip_permission_denied;
    
    for (const auto& entry : fs::recursive_directory_iterator(dir, options)) {
        std::cout << entry.path() << std::endl;
    }
    
    // 跟随符号链接
    auto options2 = fs::directory_options::follow_directory_symlink;
    
    return 0;
}
```

---

## 4. 文件操作

### 4.1 文件信息

```cpp
#include <filesystem>
#include <iostream>
#include <chrono>
#include <iomanip>

namespace fs = std::filesystem;

void printFileInfo(const fs::path& path) {
    if (!fs::exists(path)) {
        std::cout << "File does not exist: " << path << std::endl;
        return;
    }
    
    std::cout << "File: " << path << std::endl;
    
    // 文件类型
    auto status = fs::status(path);
    std::cout << "  Type: ";
    switch (status.type()) {
        case fs::file_type::regular: std::cout << "regular file"; break;
        case fs::file_type::directory: std::cout << "directory"; break;
        case fs::file_type::symlink: std::cout << "symlink"; break;
        case fs::file_type::block: std::cout << "block device"; break;
        case fs::file_type::character: std::cout << "character device"; break;
        case fs::file_type::fifo: std::cout << "FIFO"; break;
        case fs::file_type::socket: std::cout << "socket"; break;
        default: std::cout << "unknown"; break;
    }
    std::cout << std::endl;
    
    // 文件大小
    if (fs::is_regular_file(path)) {
        std::cout << "  Size: " << fs::file_size(path) << " bytes" << std::endl;
    }
    
    // 最后修改时间
    auto ftime = fs::last_write_time(path);
    auto sctp = std::chrono::time_point_cast<std::chrono::system_clock::duration>(
        ftime - fs::file_time_type::clock::now() + std::chrono::system_clock::now()
    );
    auto time = std::chrono::system_clock::to_time_t(sctp);
    std::cout << "  Modified: " << std::ctime(&time);
    
    // 权限
    auto perms = status.permissions();
    std::cout << "  Permissions: ";
    std::cout << ((perms & fs::perms::owner_read) != fs::perms::none ? "r" : "-");
    std::cout << ((perms & fs::perms::owner_write) != fs::perms::none ? "w" : "-");
    std::cout << ((perms & fs::perms::owner_exec) != fs::perms::none ? "x" : "-");
    std::cout << ((perms & fs::perms::group_read) != fs::perms::none ? "r" : "-");
    std::cout << ((perms & fs::perms::group_write) != fs::perms::none ? "w" : "-");
    std::cout << ((perms & fs::perms::group_exec) != fs::perms::none ? "x" : "-");
    std::cout << ((perms & fs::perms::others_read) != fs::perms::none ? "r" : "-");
    std::cout << ((perms & fs::perms::others_write) != fs::perms::none ? "w" : "-");
    std::cout << ((perms & fs::perms::others_exec) != fs::perms::none ? "x" : "-");
    std::cout << std::endl;
}

int main() {
    printFileInfo("/etc/passwd");
    return 0;
}
```

### 4.2 复制和移动

```cpp
#include <filesystem>
#include <iostream>

namespace fs = std::filesystem;

int main() {
    // 复制文件
    fs::path src = "source.txt";
    fs::path dst = "destination.txt";
    
    // 创建测试文件
    {
        std::ofstream f(src);
        f << "Test content";
    }
    
    // 复制
    fs::copy(src, dst);
    std::cout << "Copied " << src << " to " << dst << std::endl;
    
    // 复制选项
    fs::copy(src, "backup.txt", fs::copy_options::overwrite_existing);
    
    // 复制目录
    fs::create_directory("src_dir");
    {
        std::ofstream f("src_dir/file.txt");
        f << "File in directory";
    }
    
    fs::copy("src_dir", "dst_dir", fs::copy_options::recursive);
    
    // 移动/重命名
    fs::rename(dst, "renamed.txt");
    std::cout << "Renamed " << dst << " to renamed.txt" << std::endl;
    
    // 清理
    fs::remove(src);
    fs::remove("backup.txt");
    fs::remove("renamed.txt");
    fs::remove_all("src_dir");
    fs::remove_all("dst_dir");
    
    return 0;
}
```

### 4.3 权限操作

```cpp
#include <filesystem>
#include <iostream>

namespace fs = std::filesystem;

int main() {
    fs::path file = "test_perms.txt";
    
    // 创建文件
    {
        std::ofstream f(file);
        f << "Test";
    }
    
    // 获取当前权限
    auto perms = fs::status(file).permissions();
    std::cout << "Current permissions: " << static_cast<int>(perms) << std::endl;
    
    // 添加权限
    fs::permissions(file, fs::perms::owner_exec, fs::perm_options::add);
    std::cout << "Added owner execute" << std::endl;
    
    // 移除权限
    fs::permissions(file, fs::perms::others_read | fs::perms::others_write,
                    fs::perm_options::remove);
    std::cout << "Removed others read/write" << std::endl;
    
    // 设置权限
    fs::permissions(file, fs::perms::owner_read | fs::perms::owner_write,
                    fs::perm_options::replace);
    std::cout << "Set to owner read/write only" << std::endl;
    
    fs::remove(file);
    
    return 0;
}
```

---

## 5. 文件 I/O

### 5.1 文本文件读写

```cpp
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

// 读取整个文件
std::string readFile(const std::string& path) {
    std::ifstream file(path);
    if (!file) {
        throw std::runtime_error("Cannot open file: " + path);
    }
    
    std::ostringstream ss;
    ss << file.rdbuf();
    return ss.str();
}

// 按行读取
std::vector<std::string> readLines(const std::string& path) {
    std::ifstream file(path);
    if (!file) {
        throw std::runtime_error("Cannot open file: " + path);
    }
    
    std::vector<std::string> lines;
    std::string line;
    
    while (std::getline(file, line)) {
        lines.push_back(line);
    }
    
    return lines;
}

// 写入文件
void writeFile(const std::string& path, const std::string& content) {
    std::ofstream file(path);
    if (!file) {
        throw std::runtime_error("Cannot open file: " + path);
    }
    
    file << content;
}

// 追加到文件
void appendFile(const std::string& path, const std::string& content) {
    std::ofstream file(path, std::ios::app);
    if (!file) {
        throw std::runtime_error("Cannot open file: " + path);
    }
    
    file << content;
}

int main() {
    writeFile("test.txt", "Line 1\nLine 2\nLine 3\n");
    
    auto lines = readLines("test.txt");
    for (const auto& line : lines) {
        std::cout << line << std::endl;
    }
    
    appendFile("test.txt", "Line 4\n");
    
    std::cout << "\nFull content:\n" << readFile("test.txt");
    
    std::filesystem::remove("test.txt");
    
    return 0;
}
```

### 5.2 二进制文件读写

```cpp
#include <fstream>
#include <iostream>
#include <vector>

struct Record {
    int id;
    char name[32];
    double value;
};

void writeBinary(const std::string& path, const std::vector<Record>& records) {
    std::ofstream file(path, std::ios::binary);
    if (!file) {
        throw std::runtime_error("Cannot open file");
    }
    
    // 写入记录数量
    size_t count = records.size();
    file.write(reinterpret_cast<const char*>(&count), sizeof(count));
    
    // 写入记录
    file.write(reinterpret_cast<const char*>(records.data()),
               records.size() * sizeof(Record));
}

std::vector<Record> readBinary(const std::string& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        throw std::runtime_error("Cannot open file");
    }
    
    // 读取记录数量
    size_t count;
    file.read(reinterpret_cast<char*>(&count), sizeof(count));
    
    // 读取记录
    std::vector<Record> records(count);
    file.read(reinterpret_cast<char*>(records.data()),
              count * sizeof(Record));
    
    return records;
}

int main() {
    std::vector<Record> records = {
        {1, "Alice", 100.5},
        {2, "Bob", 200.75},
        {3, "Charlie", 300.25}
    };
    
    writeBinary("data.bin", records);
    
    auto loaded = readBinary("data.bin");
    for (const auto& r : loaded) {
        std::cout << r.id << ": " << r.name << " = " << r.value << std::endl;
    }
    
    std::filesystem::remove("data.bin");
    
    return 0;
}
```

### 5.3 内存映射文件

```cpp
#include <iostream>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <cstring>

class MemoryMappedFile {
public:
    MemoryMappedFile(const char* path, bool writable = false) 
        : data(nullptr), size(0), fd(-1) {
        
        int flags = writable ? O_RDWR : O_RDONLY;
        fd = open(path, flags);
        if (fd < 0) {
            throw std::runtime_error("Cannot open file");
        }
        
        struct stat st;
        if (fstat(fd, &st) < 0) {
            close(fd);
            throw std::runtime_error("Cannot stat file");
        }
        
        size = st.st_size;
        
        int prot = PROT_READ | (writable ? PROT_WRITE : 0);
        data = mmap(nullptr, size, prot, MAP_SHARED, fd, 0);
        
        if (data == MAP_FAILED) {
            close(fd);
            throw std::runtime_error("Cannot mmap file");
        }
    }
    
    ~MemoryMappedFile() {
        if (data && data != MAP_FAILED) {
            munmap(data, size);
        }
        if (fd >= 0) {
            close(fd);
        }
    }
    
    void* getData() { return data; }
    size_t getSize() const { return size; }

private:
    void* data;
    size_t size;
    int fd;
};

int main() {
    // 创建测试文件
    {
        std::ofstream f("mmap_test.txt");
        f << "Hello, Memory Mapped File!";
    }
    
    MemoryMappedFile mmf("mmap_test.txt");
    
    std::cout << "File size: " << mmf.getSize() << std::endl;
    std::cout << "Content: " << static_cast<char*>(mmf.getData()) << std::endl;
    
    std::filesystem::remove("mmap_test.txt");
    
    return 0;
}
```

---

## 6. 总结

### 6.1 filesystem 主要类

| 类 | 说明 |
|-----|------|
| path | 文件路径 |
| directory_entry | 目录条目 |
| directory_iterator | 目录迭代器 |
| file_status | 文件状态 |
| space_info | 磁盘空间信息 |

### 6.2 常用操作

| 操作 | 函数 |
|------|------|
| 检查存在 | exists() |
| 创建目录 | create_directory() |
| 删除 | remove(), remove_all() |
| 复制 | copy() |
| 移动 | rename() |
| 文件大小 | file_size() |

### 6.3 下一篇预告

在下一篇文章中,我们将学习进程与信号。

---

> 作者: C++ 技术专栏  
> 系列: 系统编程与性能优化 (1/4)  
> 上一篇: [HTTP 服务器](../part7-network/50-http-server.md)  
> 下一篇: [进程与信号](./52-process-signal.md)
