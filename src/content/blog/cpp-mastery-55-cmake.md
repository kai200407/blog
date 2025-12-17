---
title: "CMake 构建系统"
description: "1. [CMake 概述](#1-cmake-概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 55
---

> 本文是 C++ 从入门到精通系列的第五十五篇,将深入讲解 CMake 构建系统的使用。

---

## 目录

1. [CMake 概述](#1-cmake-概述)
2. [基础语法](#2-基础语法)
3. [目标和依赖](#3-目标和依赖)
4. [查找库](#4-查找库)
5. [高级特性](#5-高级特性)
6. [总结](#6-总结)

---

## 1. CMake 概述

### 1.1 什么是 CMake

```
CMake:
- 跨平台构建系统生成器
- 生成 Makefile, Ninja, Visual Studio 等
- 现代 C++ 项目标准

优势:
- 跨平台
- 支持复杂项目
- 丰富的模块
- 活跃的社区
```

### 1.2 基本工作流

```bash
# 创建构建目录
mkdir build && cd build

# 配置项目
cmake ..

# 构建
cmake --build .

# 安装
cmake --install .

# 或使用预设
cmake --preset=release
cmake --build --preset=release
```

---

## 2. 基础语法

### 2.1 最小 CMakeLists.txt

```cmake
# 最低版本要求
cmake_minimum_required(VERSION 3.20)

# 项目名称和版本
project(MyProject VERSION 1.0.0 LANGUAGES CXX)

# 设置 C++ 标准
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# 添加可执行文件
add_executable(myapp main.cpp)
```

### 2.2 变量和缓存

```cmake
# 普通变量
set(MY_VAR "value")
set(MY_LIST "a" "b" "c")

# 缓存变量 (可在命令行覆盖)
set(MY_OPTION "default" CACHE STRING "Description")
option(ENABLE_TESTS "Enable tests" ON)

# 环境变量
set(ENV{MY_ENV} "value")
message("PATH: $ENV{PATH}")

# 变量引用
message("MY_VAR = ${MY_VAR}")

# 列表操作
list(APPEND MY_LIST "d")
list(LENGTH MY_LIST len)
list(GET MY_LIST 0 first)

# 字符串操作
string(TOUPPER "${MY_VAR}" MY_VAR_UPPER)
string(REPLACE "old" "new" result "${input}")
```

### 2.3 条件和循环

```cmake
# 条件语句
if(WIN32)
    message("Windows")
elseif(APPLE)
    message("macOS")
elseif(UNIX)
    message("Linux/Unix")
endif()

# 变量条件
if(DEFINED MY_VAR)
    message("MY_VAR is defined")
endif()

if(MY_VAR STREQUAL "value")
    message("MY_VAR equals value")
endif()

if(MY_VAR MATCHES "^v[0-9]+")
    message("MY_VAR matches pattern")
endif()

# 循环
foreach(item IN LISTS MY_LIST)
    message("Item: ${item}")
endforeach()

foreach(i RANGE 1 10)
    message("i = ${i}")
endforeach()

# while 循环
set(counter 0)
while(counter LESS 5)
    message("counter = ${counter}")
    math(EXPR counter "${counter} + 1")
endwhile()
```

### 2.4 函数和宏

```cmake
# 函数 (有自己的作用域)
function(my_function arg1 arg2)
    message("arg1 = ${arg1}")
    message("arg2 = ${arg2}")
    message("ARGC = ${ARGC}")
    message("ARGV = ${ARGV}")
    message("ARGN = ${ARGN}")
    
    # 返回值
    set(${arg1}_result "processed" PARENT_SCOPE)
endfunction()

my_function(foo bar extra1 extra2)

# 宏 (没有自己的作用域)
macro(my_macro arg1)
    message("In macro: ${arg1}")
    set(MACRO_VAR "set in macro")
endmacro()

my_macro(test)
message("MACRO_VAR = ${MACRO_VAR}")
```

---

## 3. 目标和依赖

### 3.1 添加目标

```cmake
# 可执行文件
add_executable(myapp
    src/main.cpp
    src/utils.cpp
)

# 静态库
add_library(mylib STATIC
    src/lib.cpp
)

# 共享库
add_library(myshared SHARED
    src/shared.cpp
)

# 头文件库 (接口库)
add_library(myheader INTERFACE)

# 对象库
add_library(myobject OBJECT
    src/object.cpp
)

# 别名
add_library(MyProject::mylib ALIAS mylib)
```

### 3.2 目标属性

```cmake
# 包含目录
target_include_directories(myapp
    PUBLIC include
    PRIVATE src
)

# 编译定义
target_compile_definitions(myapp
    PUBLIC APP_VERSION="1.0"
    PRIVATE DEBUG_MODE
)

# 编译选项
target_compile_options(myapp
    PRIVATE
        $<$<CXX_COMPILER_ID:GNU>:-Wall -Wextra>
        $<$<CXX_COMPILER_ID:MSVC>:/W4>
)

# 编译特性
target_compile_features(myapp
    PUBLIC cxx_std_20
)

# 链接选项
target_link_options(myapp
    PRIVATE -static-libgcc
)
```

### 3.3 链接库

```cmake
# 链接库
target_link_libraries(myapp
    PUBLIC mylib
    PRIVATE external_lib
)

# 链接系统库
target_link_libraries(myapp
    PRIVATE pthread
)

# 条件链接
target_link_libraries(myapp
    PRIVATE
        $<$<PLATFORM_ID:Linux>:dl>
        $<$<PLATFORM_ID:Windows>:ws2_32>
)
```

### 3.4 生成器表达式

```cmake
# 基本语法: $<condition:value>

# 配置相关
target_compile_definitions(myapp PRIVATE
    $<$<CONFIG:Debug>:DEBUG_BUILD>
    $<$<CONFIG:Release>:NDEBUG>
)

# 编译器相关
target_compile_options(myapp PRIVATE
    $<$<CXX_COMPILER_ID:GNU>:-Wall>
    $<$<CXX_COMPILER_ID:Clang>:-Weverything>
)

# 平台相关
target_sources(myapp PRIVATE
    $<$<PLATFORM_ID:Windows>:src/windows.cpp>
    $<$<PLATFORM_ID:Linux>:src/linux.cpp>
)

# 目标属性
target_include_directories(myapp PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)
```

---

## 4. 查找库

### 4.1 find_package

```cmake
# 查找包
find_package(Threads REQUIRED)
find_package(OpenSSL REQUIRED)
find_package(Boost 1.70 REQUIRED COMPONENTS filesystem system)

# 使用找到的包
target_link_libraries(myapp
    PRIVATE
        Threads::Threads
        OpenSSL::SSL
        OpenSSL::Crypto
        Boost::filesystem
        Boost::system
)

# 可选包
find_package(OpenMP)
if(OpenMP_CXX_FOUND)
    target_link_libraries(myapp PRIVATE OpenMP::OpenMP_CXX)
endif()
```

### 4.2 FetchContent

```cmake
include(FetchContent)

# 声明依赖
FetchContent_Declare(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG v1.14.0
)

FetchContent_Declare(
    fmt
    GIT_REPOSITORY https://github.com/fmtlib/fmt.git
    GIT_TAG 10.1.1
)

# 获取依赖
FetchContent_MakeAvailable(googletest fmt)

# 使用
target_link_libraries(myapp PRIVATE fmt::fmt)
target_link_libraries(mytest PRIVATE GTest::gtest_main)
```

### 4.3 自定义 Find 模块

```cmake
# FindMyLib.cmake
# 查找 MyLib 库

find_path(MYLIB_INCLUDE_DIR
    NAMES mylib.h
    PATHS /usr/include /usr/local/include
)

find_library(MYLIB_LIBRARY
    NAMES mylib
    PATHS /usr/lib /usr/local/lib
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(MyLib
    REQUIRED_VARS MYLIB_LIBRARY MYLIB_INCLUDE_DIR
)

if(MyLib_FOUND AND NOT TARGET MyLib::MyLib)
    add_library(MyLib::MyLib UNKNOWN IMPORTED)
    set_target_properties(MyLib::MyLib PROPERTIES
        IMPORTED_LOCATION "${MYLIB_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${MYLIB_INCLUDE_DIR}"
    )
endif()
```

---

## 5. 高级特性

### 5.1 项目结构

```
project/
├── CMakeLists.txt
├── cmake/
│   ├── MyLibConfig.cmake.in
│   └── FindSomeLib.cmake
├── include/
│   └── mylib/
│       └── mylib.h
├── src/
│   ├── CMakeLists.txt
│   └── mylib.cpp
├── apps/
│   ├── CMakeLists.txt
│   └── main.cpp
├── tests/
│   ├── CMakeLists.txt
│   └── test_mylib.cpp
└── docs/
    └── CMakeLists.txt
```

```cmake
# 根 CMakeLists.txt
cmake_minimum_required(VERSION 3.20)
project(MyProject VERSION 1.0.0 LANGUAGES CXX)

# 选项
option(BUILD_TESTS "Build tests" ON)
option(BUILD_DOCS "Build documentation" OFF)

# 设置模块路径
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# 添加子目录
add_subdirectory(src)
add_subdirectory(apps)

if(BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()

if(BUILD_DOCS)
    add_subdirectory(docs)
endif()
```

### 5.2 安装和导出

```cmake
include(GNUInstallDirs)

# 安装目标
install(TARGETS mylib myapp
    EXPORT MyProjectTargets
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

# 安装头文件
install(DIRECTORY include/
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

# 导出目标
install(EXPORT MyProjectTargets
    FILE MyProjectTargets.cmake
    NAMESPACE MyProject::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/MyProject
)

# 配置文件
include(CMakePackageConfigHelpers)

configure_package_config_file(
    cmake/MyProjectConfig.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/MyProjectConfig.cmake
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/MyProject
)

write_basic_package_version_file(
    ${CMAKE_CURRENT_BINARY_DIR}/MyProjectConfigVersion.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

install(FILES
    ${CMAKE_CURRENT_BINARY_DIR}/MyProjectConfig.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/MyProjectConfigVersion.cmake
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/MyProject
)
```

### 5.3 CMake 预设

```json
// CMakePresets.json
{
    "version": 6,
    "cmakeMinimumRequired": {
        "major": 3,
        "minor": 21,
        "patch": 0
    },
    "configurePresets": [
        {
            "name": "base",
            "hidden": true,
            "binaryDir": "${sourceDir}/build/${presetName}",
            "cacheVariables": {
                "CMAKE_CXX_STANDARD": "20"
            }
        },
        {
            "name": "debug",
            "inherits": "base",
            "displayName": "Debug",
            "cacheVariables": {
                "CMAKE_BUILD_TYPE": "Debug"
            }
        },
        {
            "name": "release",
            "inherits": "base",
            "displayName": "Release",
            "cacheVariables": {
                "CMAKE_BUILD_TYPE": "Release"
            }
        }
    ],
    "buildPresets": [
        {
            "name": "debug",
            "configurePreset": "debug"
        },
        {
            "name": "release",
            "configurePreset": "release"
        }
    ],
    "testPresets": [
        {
            "name": "debug",
            "configurePreset": "debug",
            "output": {
                "outputOnFailure": true
            }
        }
    ]
}
```

### 5.4 测试集成

```cmake
enable_testing()

# 添加测试
add_test(NAME MyTest COMMAND mytest)

# 设置测试属性
set_tests_properties(MyTest PROPERTIES
    TIMEOUT 60
    LABELS "unit"
)

# CTest 配置
include(CTest)

# Google Test 集成
include(GoogleTest)
gtest_discover_tests(mytest)
```

---

## 6. 总结

### 6.1 常用命令

| 命令 | 说明 |
|------|------|
| add_executable | 添加可执行文件 |
| add_library | 添加库 |
| target_link_libraries | 链接库 |
| target_include_directories | 包含目录 |
| find_package | 查找包 |
| install | 安装规则 |

### 6.2 最佳实践

```
1. 使用现代 CMake (3.x)
2. 使用 target_* 命令
3. 避免全局变量
4. 使用生成器表达式
5. 导出配置文件
6. 使用预设
```

### 6.3 下一篇预告

在下一篇文章中,我们将学习单元测试。

---

> 作者: C++ 技术专栏  
> 系列: 工程实践 (1/4)  
> 上一篇: [SIMD 与并行计算](../part8-system/54-simd-parallel.md)  
> 下一篇: [单元测试](./56-unit-testing.md)
