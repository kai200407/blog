---
title: "C++ 开发环境搭建"
description: "1. [编译器选择](#1-编译器选择)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 1
---

> 本文是 C++ 从入门到精通系列的第一篇,将帮助你搭建完整的 C++ 开发环境,包括编译器安装、IDE 配置以及调试工具的使用。

---

## 目录

1. [编译器选择](#1-编译器选择)
2. [Linux 环境搭建](#2-linux-环境搭建)
3. [Windows 环境搭建](#3-windows-环境搭建)
4. [macOS 环境搭建](#4-macos-环境搭建)
5. [IDE 与编辑器](#5-ide-与编辑器)
6. [第一次编译](#6-第一次编译)
7. [调试工具](#7-调试工具)
8. [总结](#8-总结)

---

## 1. 编译器选择

### 1.1 主流 C++ 编译器

```
C++ 编译器对比:

+------------+----------+------------+------------------+
|   编译器   |   平台   | C++ 标准   |      特点        |
+------------+----------+------------+------------------+
| GCC        | 跨平台   | C++23      | 开源、标准兼容好 |
| Clang      | 跨平台   | C++23      | 错误信息友好     |
| MSVC       | Windows  | C++23      | Windows 原生     |
| Intel C++  | 跨平台   | C++20      | 高性能优化       |
+------------+----------+------------+------------------+
```

### 1.2 编译器版本建议

```
推荐版本 (2024):

- GCC 11+ (支持 C++20 大部分特性)
- GCC 13+ (支持 C++23 部分特性)
- Clang 14+ (支持 C++20)
- Clang 16+ (支持 C++23 部分特性)
- MSVC 2022 (支持 C++20/23)
```

### 1.3 C++ 标准版本

```
C++ 标准演进:

C++98/03 ──> C++11 ──> C++14 ──> C++17 ──> C++20 ──> C++23
   │           │         │         │         │         │
   │           │         │         │         │         └─ 最新标准
   │           │         │         │         └─ 协程、Concepts、Ranges
   │           │         │         └─ 结构化绑定、optional、variant
   │           │         └─ 泛型 Lambda、变量模板
   │           └─ 现代 C++ 起点 (auto、Lambda、移动语义)
   └─ 经典 C++
```

---

## 2. Linux 环境搭建

### 2.1 Ubuntu/Debian

```bash
# 更新包管理器
sudo apt update

# 安装 GCC
sudo apt install build-essential

# 安装特定版本 GCC
sudo apt install gcc-13 g++-13

# 设置默认版本
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 100
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 100

# 验证安装
gcc --version
g++ --version
```

### 2.2 安装 Clang

```bash
# Ubuntu/Debian
sudo apt install clang

# 安装最新版本
wget https://apt.llvm.org/llvm.sh
chmod +x llvm.sh
sudo ./llvm.sh 17

# 验证安装
clang++ --version
```

### 2.3 安装构建工具

```bash
# CMake
sudo apt install cmake

# Ninja (可选,更快的构建)
sudo apt install ninja-build

# 调试器
sudo apt install gdb

# 验证
cmake --version
gdb --version
```

---

## 3. Windows 环境搭建

### 3.1 Visual Studio 2022

```
安装步骤:

1. 下载 Visual Studio Installer
   https://visualstudio.microsoft.com/

2. 选择工作负载:
   [x] 使用 C++ 的桌面开发
   [x] 使用 C++ 的 Linux 开发 (可选)

3. 单独组件 (推荐):
   [x] MSVC v143 - VS 2022 C++ x64/x86 生成工具
   [x] Windows 11 SDK
   [x] C++ CMake 工具
   [x] C++ AddressSanitizer
```

### 3.2 MinGW-w64 (GCC for Windows)

```
安装方法:

方法 1: MSYS2 (推荐)
1. 下载 MSYS2: https://www.msys2.org/
2. 安装后运行 MSYS2 UCRT64
3. 执行:
   pacman -Syu
   pacman -S mingw-w64-ucrt-x86_64-gcc
   pacman -S mingw-w64-ucrt-x86_64-cmake
   pacman -S mingw-w64-ucrt-x86_64-gdb

4. 添加到 PATH:
   C:\msys64\ucrt64\bin

方法 2: 直接下载
https://github.com/niXman/mingw-builds-binaries/releases
```

### 3.3 验证安装

```cmd
:: 命令提示符
g++ --version
cmake --version

:: 或 PowerShell
g++ --version
cmake --version
```

---

## 4. macOS 环境搭建

### 4.1 Xcode Command Line Tools

```bash
# 安装命令行工具 (包含 Clang)
xcode-select --install

# 验证
clang++ --version
```

### 4.2 Homebrew 安装工具

```bash
# 安装 Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 安装 GCC
brew install gcc

# 安装 CMake
brew install cmake

# 安装 LLDB (调试器)
brew install llvm

# 验证
gcc-13 --version
cmake --version
```

---

## 5. IDE 与编辑器

### 5.1 Visual Studio Code

```
VS Code 配置:

1. 安装扩展:
   - C/C++ (Microsoft)
   - C/C++ Extension Pack
   - CMake Tools
   - CodeLLDB (调试)

2. 配置文件 (.vscode/c_cpp_properties.json):
```

```json
{
    "configurations": [
        {
            "name": "Linux",
            "includePath": [
                "${workspaceFolder}/**"
            ],
            "defines": [],
            "compilerPath": "/usr/bin/g++",
            "cStandard": "c17",
            "cppStandard": "c++20",
            "intelliSenseMode": "linux-gcc-x64"
        }
    ],
    "version": 4
}
```

### 5.2 VS Code 任务配置

```json
// .vscode/tasks.json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "C++ Build",
            "type": "shell",
            "command": "g++",
            "args": [
                "-std=c++20",
                "-g",
                "-Wall",
                "-Wextra",
                "${file}",
                "-o",
                "${fileDirname}/${fileBasenameNoExtension}"
            ],
            "group": {
                "kind": "build",
                "isDefault": true
            },
            "problemMatcher": ["$gcc"]
        }
    ]
}
```

### 5.3 VS Code 调试配置

```json
// .vscode/launch.json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "C++ Debug",
            "type": "cppdbg",
            "request": "launch",
            "program": "${fileDirname}/${fileBasenameNoExtension}",
            "args": [],
            "stopAtEntry": false,
            "cwd": "${workspaceFolder}",
            "environment": [],
            "externalConsole": false,
            "MIMode": "gdb",
            "setupCommands": [
                {
                    "description": "Enable pretty-printing",
                    "text": "-enable-pretty-printing",
                    "ignoreFailures": true
                }
            ],
            "preLaunchTask": "C++ Build"
        }
    ]
}
```

### 5.4 CLion

```
CLion 配置:

1. 安装 CLion (JetBrains)
2. 配置工具链:
   File -> Settings -> Build, Execution, Deployment -> Toolchains
   
   - Name: GCC
   - CMake: /usr/bin/cmake
   - C Compiler: /usr/bin/gcc
   - C++ Compiler: /usr/bin/g++
   - Debugger: /usr/bin/gdb

3. CMake 配置:
   File -> Settings -> Build, Execution, Deployment -> CMake
   
   - Build type: Debug
   - CMake options: -DCMAKE_CXX_STANDARD=20
```

---

## 6. 第一次编译

### 6.1 创建源文件

```cpp
// hello.cpp
#include <iostream>

int main() {
    std::cout << "Hello, C++!" << std::endl;
    return 0;
}
```

### 6.2 命令行编译

```bash
# 基本编译
g++ hello.cpp -o hello

# 指定 C++ 标准
g++ -std=c++20 hello.cpp -o hello

# 开启警告
g++ -std=c++20 -Wall -Wextra hello.cpp -o hello

# 调试模式
g++ -std=c++20 -g -O0 hello.cpp -o hello

# 优化模式
g++ -std=c++20 -O2 hello.cpp -o hello

# 运行
./hello
```

### 6.3 编译选项详解

```
常用编译选项:

-std=c++20      指定 C++ 标准
-o <file>       指定输出文件名
-c              只编译不链接
-g              生成调试信息
-O0/O1/O2/O3    优化级别
-Wall           开启常见警告
-Wextra         开启额外警告
-Werror         警告视为错误
-I<dir>         添加头文件搜索路径
-L<dir>         添加库文件搜索路径
-l<lib>         链接库
-D<macro>       定义宏
-pthread        启用多线程支持
```

### 6.4 使用 CMake

```cmake
# CMakeLists.txt
cmake_minimum_required(VERSION 3.20)
project(HelloCpp)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(hello hello.cpp)
```

```bash
# 构建
mkdir build && cd build
cmake ..
make

# 或使用 Ninja
cmake -G Ninja ..
ninja
```

---

## 7. 调试工具

### 7.1 GDB 基础

```bash
# 编译时添加调试信息
g++ -g -O0 hello.cpp -o hello

# 启动 GDB
gdb ./hello

# GDB 常用命令
(gdb) run              # 运行程序
(gdb) break main       # 在 main 函数设置断点
(gdb) break 10         # 在第 10 行设置断点
(gdb) next             # 单步执行 (不进入函数)
(gdb) step             # 单步执行 (进入函数)
(gdb) continue         # 继续执行
(gdb) print var        # 打印变量值
(gdb) backtrace        # 查看调用栈
(gdb) info locals      # 查看局部变量
(gdb) quit             # 退出
```

### 7.2 LLDB (macOS/Clang)

```bash
# 启动 LLDB
lldb ./hello

# LLDB 常用命令
(lldb) run
(lldb) breakpoint set --name main
(lldb) breakpoint set --file hello.cpp --line 10
(lldb) next
(lldb) step
(lldb) continue
(lldb) frame variable
(lldb) bt
(lldb) quit
```

### 7.3 AddressSanitizer

```bash
# 编译时启用 ASan
g++ -std=c++20 -g -fsanitize=address -fno-omit-frame-pointer hello.cpp -o hello

# 运行会自动检测内存错误
./hello
```

### 7.4 Valgrind

```bash
# 安装
sudo apt install valgrind

# 内存泄漏检测
valgrind --leak-check=full ./hello

# 详细报告
valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes ./hello
```

---

## 8. 总结

### 8.1 环境检查清单

```
[ ] 编译器已安装 (GCC/Clang/MSVC)
[ ] 支持 C++20 标准
[ ] CMake 已安装
[ ] 调试器已配置 (GDB/LLDB)
[ ] IDE/编辑器已配置
[ ] 能成功编译运行 Hello World
```

### 8.2 推荐配置

| 平台 | 编译器 | IDE | 调试器 |
|------|--------|-----|--------|
| Linux | GCC 13 | VS Code / CLion | GDB |
| Windows | MSVC 2022 | Visual Studio | VS Debugger |
| macOS | Clang 16 | Xcode / CLion | LLDB |

### 8.3 下一篇预告

在下一篇文章中,我们将编写第一个 C++ 程序,深入理解程序的编译链接过程。

---

## 参考资料

1. [GCC Documentation](https://gcc.gnu.org/onlinedocs/)
2. [Clang Documentation](https://clang.llvm.org/docs/)
3. [CMake Documentation](https://cmake.org/documentation/)

---

> 作者: C++ 技术专栏  
> 系列: C++ 基础入门 (1/8)  
> 下一篇: [第一个 C++ 程序](./02-first-program.md)
