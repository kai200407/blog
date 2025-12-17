---
title: "string 与字符串处理"
description: "1. [string 基础回顾](#1-string-基础回顾)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 30
---

> 本文是 C++ 从入门到精通系列的第三十篇,也是 STL 标准模板库部分的收官之作。我们将深入讲解 std::string 的高级用法和字符串处理技术。

---

## 目录

1. [string 基础回顾](#1-string-基础回顾)
2. [字符串操作](#2-字符串操作)
3. [字符串搜索](#3-字符串搜索)
4. [字符串转换](#4-字符串转换)
5. [正则表达式](#5-正则表达式)
6. [string_view](#6-string_view)
7. [总结](#7-总结)

---

## 1. string 基础回顾

### 1.1 创建和初始化

```cpp
#include <iostream>
#include <string>

int main() {
    // 创建方式
    std::string s1;                      // 空字符串
    std::string s2("Hello");             // 从 C 字符串
    std::string s3 = "World";            // 拷贝初始化
    std::string s4(5, 'a');              // 5 个 'a'
    std::string s5(s2);                  // 拷贝构造
    std::string s6(s2, 1, 3);            // 子串: "ell"
    std::string s7(s2.begin(), s2.end()); // 迭代器范围
    std::string s8 = {'H', 'i'};         // 初始化列表
    
    // C++14 字符串字面量
    using namespace std::string_literals;
    auto s9 = "Hello"s;  // std::string 类型
    
    // 打印
    std::cout << "s2: " << s2 << std::endl;
    std::cout << "s4: " << s4 << std::endl;
    std::cout << "s6: " << s6 << std::endl;
    
    return 0;
}
```

### 1.2 容量操作

```cpp
#include <iostream>
#include <string>

int main() {
    std::string s = "Hello, World!";
    
    // 大小
    std::cout << "size: " << s.size() << std::endl;
    std::cout << "length: " << s.length() << std::endl;
    std::cout << "empty: " << s.empty() << std::endl;
    
    // 容量
    std::cout << "capacity: " << s.capacity() << std::endl;
    std::cout << "max_size: " << s.max_size() << std::endl;
    
    // 预留空间
    s.reserve(100);
    std::cout << "After reserve(100), capacity: " << s.capacity() << std::endl;
    
    // 调整大小
    s.resize(5);
    std::cout << "After resize(5): \"" << s << "\"" << std::endl;
    
    s.resize(10, 'x');
    std::cout << "After resize(10, 'x'): \"" << s << "\"" << std::endl;
    
    // 收缩
    s.shrink_to_fit();
    std::cout << "After shrink_to_fit, capacity: " << s.capacity() << std::endl;
    
    // 清空
    s.clear();
    std::cout << "After clear, size: " << s.size() << std::endl;
    
    return 0;
}
```

---

## 2. 字符串操作

### 2.1 访问和修改

```cpp
#include <iostream>
#include <string>

int main() {
    std::string s = "Hello";
    
    // 访问字符
    std::cout << "s[0]: " << s[0] << std::endl;
    std::cout << "s.at(1): " << s.at(1) << std::endl;
    std::cout << "s.front(): " << s.front() << std::endl;
    std::cout << "s.back(): " << s.back() << std::endl;
    
    // 修改字符
    s[0] = 'h';
    s.at(1) = 'E';
    s.front() = 'H';
    s.back() = 'O';
    std::cout << "Modified: " << s << std::endl;
    
    // 获取 C 字符串
    const char* cstr = s.c_str();
    const char* data = s.data();
    std::cout << "c_str: " << cstr << std::endl;
    
    return 0;
}
```

### 2.2 追加和插入

```cpp
#include <iostream>
#include <string>

int main() {
    std::string s = "Hello";
    
    // 追加
    s += " World";
    s.append("!");
    s.append(3, '!');
    s.push_back('?');
    
    std::cout << "After append: " << s << std::endl;
    
    // 插入
    s = "Hello World";
    s.insert(5, ",");
    std::cout << "After insert: " << s << std::endl;
    
    s.insert(0, "Say: ");
    std::cout << "After insert at 0: " << s << std::endl;
    
    s.insert(s.end(), '!');
    std::cout << "After insert at end: " << s << std::endl;
    
    return 0;
}
```

### 2.3 删除和替换

```cpp
#include <iostream>
#include <string>

int main() {
    std::string s = "Hello, World!";
    
    // 删除
    s.erase(5, 2);  // 从位置 5 删除 2 个字符
    std::cout << "After erase(5, 2): " << s << std::endl;
    
    s.erase(s.begin());  // 删除第一个字符
    std::cout << "After erase(begin): " << s << std::endl;
    
    s.pop_back();  // 删除最后一个字符
    std::cout << "After pop_back: " << s << std::endl;
    
    // 替换
    s = "Hello, World!";
    s.replace(7, 5, "C++");  // 从位置 7 替换 5 个字符
    std::cout << "After replace: " << s << std::endl;
    
    // 替换所有出现
    s = "aaa bbb aaa ccc aaa";
    size_t pos = 0;
    while ((pos = s.find("aaa", pos)) != std::string::npos) {
        s.replace(pos, 3, "XXX");
        pos += 3;
    }
    std::cout << "After replace all: " << s << std::endl;
    
    return 0;
}
```

### 2.4 子串和连接

```cpp
#include <iostream>
#include <string>
#include <vector>
#include <sstream>

int main() {
    std::string s = "Hello, World!";
    
    // 子串
    std::string sub = s.substr(7, 5);
    std::cout << "substr(7, 5): " << sub << std::endl;
    
    sub = s.substr(7);  // 从位置 7 到末尾
    std::cout << "substr(7): " << sub << std::endl;
    
    // 连接
    std::string a = "Hello";
    std::string b = "World";
    std::string c = a + ", " + b + "!";
    std::cout << "Concatenated: " << c << std::endl;
    
    // 使用 stringstream 连接
    std::vector<std::string> parts = {"one", "two", "three"};
    std::ostringstream oss;
    for (size_t i = 0; i < parts.size(); ++i) {
        if (i > 0) oss << ", ";
        oss << parts[i];
    }
    std::cout << "Joined: " << oss.str() << std::endl;
    
    return 0;
}
```

---

## 3. 字符串搜索

### 3.1 查找

```cpp
#include <iostream>
#include <string>

int main() {
    std::string s = "Hello, World! Hello, C++!";
    
    // find: 查找子串
    size_t pos = s.find("Hello");
    std::cout << "find(\"Hello\"): " << pos << std::endl;
    
    pos = s.find("Hello", 7);  // 从位置 7 开始查找
    std::cout << "find(\"Hello\", 7): " << pos << std::endl;
    
    pos = s.find("xyz");
    if (pos == std::string::npos) {
        std::cout << "\"xyz\" not found" << std::endl;
    }
    
    // rfind: 从后向前查找
    pos = s.rfind("Hello");
    std::cout << "rfind(\"Hello\"): " << pos << std::endl;
    
    // find_first_of: 查找任意字符
    pos = s.find_first_of("aeiou");
    std::cout << "find_first_of(\"aeiou\"): " << pos << std::endl;
    
    // find_last_of: 从后查找任意字符
    pos = s.find_last_of("aeiou");
    std::cout << "find_last_of(\"aeiou\"): " << pos << std::endl;
    
    // find_first_not_of: 查找不在集合中的字符
    pos = s.find_first_not_of("Helo, ");
    std::cout << "find_first_not_of(\"Helo, \"): " << pos << std::endl;
    
    return 0;
}
```

### 3.2 查找所有出现

```cpp
#include <iostream>
#include <string>
#include <vector>

std::vector<size_t> findAll(const std::string& str, const std::string& pattern) {
    std::vector<size_t> positions;
    size_t pos = 0;
    
    while ((pos = str.find(pattern, pos)) != std::string::npos) {
        positions.push_back(pos);
        pos += pattern.length();
    }
    
    return positions;
}

int main() {
    std::string s = "ababababab";
    auto positions = findAll(s, "ab");
    
    std::cout << "Positions of \"ab\": ";
    for (size_t pos : positions) {
        std::cout << pos << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

### 3.3 比较

```cpp
#include <iostream>
#include <string>

int main() {
    std::string s1 = "apple";
    std::string s2 = "banana";
    std::string s3 = "apple";
    
    // 比较运算符
    std::cout << "s1 == s3: " << (s1 == s3) << std::endl;
    std::cout << "s1 != s2: " << (s1 != s2) << std::endl;
    std::cout << "s1 < s2: " << (s1 < s2) << std::endl;
    
    // compare 方法
    int result = s1.compare(s2);
    if (result < 0) {
        std::cout << "s1 < s2" << std::endl;
    } else if (result > 0) {
        std::cout << "s1 > s2" << std::endl;
    } else {
        std::cout << "s1 == s2" << std::endl;
    }
    
    // 部分比较
    std::string s4 = "Hello, World!";
    result = s4.compare(7, 5, "World");
    std::cout << "s4[7:12] == \"World\": " << (result == 0) << std::endl;
    
    return 0;
}
```

---

## 4. 字符串转换

### 4.1 数值转换

```cpp
#include <iostream>
#include <string>

int main() {
    // 字符串转数值
    std::string s1 = "42";
    std::string s2 = "3.14159";
    std::string s3 = "100abc";
    
    int i = std::stoi(s1);
    long l = std::stol(s1);
    long long ll = std::stoll(s1);
    
    float f = std::stof(s2);
    double d = std::stod(s2);
    
    std::cout << "stoi: " << i << std::endl;
    std::cout << "stod: " << d << std::endl;
    
    // 带位置参数
    size_t pos;
    int i2 = std::stoi(s3, &pos);
    std::cout << "stoi(\"100abc\"): " << i2 << ", pos: " << pos << std::endl;
    
    // 指定进制
    std::string hex = "ff";
    int hexVal = std::stoi(hex, nullptr, 16);
    std::cout << "stoi(\"ff\", 16): " << hexVal << std::endl;
    
    // 数值转字符串
    std::string str1 = std::to_string(42);
    std::string str2 = std::to_string(3.14159);
    
    std::cout << "to_string(42): " << str1 << std::endl;
    std::cout << "to_string(3.14159): " << str2 << std::endl;
    
    return 0;
}
```

### 4.2 大小写转换

```cpp
#include <iostream>
#include <string>
#include <algorithm>
#include <cctype>

std::string toUpper(std::string s) {
    std::transform(s.begin(), s.end(), s.begin(), ::toupper);
    return s;
}

std::string toLower(std::string s) {
    std::transform(s.begin(), s.end(), s.begin(), ::tolower);
    return s;
}

int main() {
    std::string s = "Hello, World!";
    
    std::cout << "Upper: " << toUpper(s) << std::endl;
    std::cout << "Lower: " << toLower(s) << std::endl;
    
    return 0;
}
```

### 4.3 去除空白

```cpp
#include <iostream>
#include <string>
#include <algorithm>

std::string ltrim(const std::string& s) {
    size_t start = s.find_first_not_of(" \t\n\r");
    return (start == std::string::npos) ? "" : s.substr(start);
}

std::string rtrim(const std::string& s) {
    size_t end = s.find_last_not_of(" \t\n\r");
    return (end == std::string::npos) ? "" : s.substr(0, end + 1);
}

std::string trim(const std::string& s) {
    return ltrim(rtrim(s));
}

int main() {
    std::string s = "   Hello, World!   ";
    
    std::cout << "Original: \"" << s << "\"" << std::endl;
    std::cout << "ltrim: \"" << ltrim(s) << "\"" << std::endl;
    std::cout << "rtrim: \"" << rtrim(s) << "\"" << std::endl;
    std::cout << "trim: \"" << trim(s) << "\"" << std::endl;
    
    return 0;
}
```

### 4.4 分割字符串

```cpp
#include <iostream>
#include <string>
#include <vector>
#include <sstream>

// 使用 stringstream 分割
std::vector<std::string> split(const std::string& s, char delimiter) {
    std::vector<std::string> tokens;
    std::stringstream ss(s);
    std::string token;
    
    while (std::getline(ss, token, delimiter)) {
        if (!token.empty()) {
            tokens.push_back(token);
        }
    }
    
    return tokens;
}

// 使用 find 分割
std::vector<std::string> splitByString(const std::string& s, const std::string& delimiter) {
    std::vector<std::string> tokens;
    size_t start = 0;
    size_t end;
    
    while ((end = s.find(delimiter, start)) != std::string::npos) {
        tokens.push_back(s.substr(start, end - start));
        start = end + delimiter.length();
    }
    tokens.push_back(s.substr(start));
    
    return tokens;
}

int main() {
    std::string s = "one,two,three,four";
    auto parts = split(s, ',');
    
    std::cout << "Split by ',': ";
    for (const auto& part : parts) {
        std::cout << "[" << part << "] ";
    }
    std::cout << std::endl;
    
    s = "one::two::three";
    parts = splitByString(s, "::");
    
    std::cout << "Split by '::': ";
    for (const auto& part : parts) {
        std::cout << "[" << part << "] ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

---

## 5. 正则表达式

### 5.1 基本匹配

```cpp
#include <iostream>
#include <string>
#include <regex>

int main() {
    std::string s = "Hello, World! 123";
    
    // 匹配
    std::regex pattern("World");
    bool found = std::regex_search(s, pattern);
    std::cout << "Contains 'World': " << found << std::endl;
    
    // 完全匹配
    std::regex emailPattern(R"(\w+@\w+\.\w+)");
    std::string email = "test@example.com";
    bool isEmail = std::regex_match(email, emailPattern);
    std::cout << "Is email: " << isEmail << std::endl;
    
    // 获取匹配结果
    std::smatch match;
    if (std::regex_search(s, match, std::regex(R"(\d+)"))) {
        std::cout << "Found number: " << match[0] << std::endl;
        std::cout << "Position: " << match.position() << std::endl;
    }
    
    return 0;
}
```

### 5.2 查找所有匹配

```cpp
#include <iostream>
#include <string>
#include <regex>
#include <vector>

int main() {
    std::string s = "The quick brown fox jumps over the lazy dog";
    std::regex wordPattern(R"(\b\w{4}\b)");  // 4 字母单词
    
    // 使用迭代器
    auto begin = std::sregex_iterator(s.begin(), s.end(), wordPattern);
    auto end = std::sregex_iterator();
    
    std::cout << "4-letter words: ";
    for (auto it = begin; it != end; ++it) {
        std::cout << it->str() << " ";
    }
    std::cout << std::endl;
    
    // 提取所有数字
    std::string text = "Price: $100, Quantity: 5, Total: $500";
    std::regex numPattern(R"(\d+)");
    
    std::vector<int> numbers;
    for (auto it = std::sregex_iterator(text.begin(), text.end(), numPattern);
         it != std::sregex_iterator(); ++it) {
        numbers.push_back(std::stoi(it->str()));
    }
    
    std::cout << "Numbers: ";
    for (int n : numbers) {
        std::cout << n << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

### 5.3 替换

```cpp
#include <iostream>
#include <string>
#include <regex>

int main() {
    std::string s = "Hello, World! Hello, C++!";
    
    // 替换
    std::regex pattern("Hello");
    std::string result = std::regex_replace(s, pattern, "Hi");
    std::cout << "Replace: " << result << std::endl;
    
    // 使用捕获组
    std::string date = "2023-12-25";
    std::regex datePattern(R"((\d{4})-(\d{2})-(\d{2}))");
    result = std::regex_replace(date, datePattern, "$2/$3/$1");
    std::cout << "Date format: " << result << std::endl;
    
    // 只替换第一个
    s = "aaa bbb aaa ccc aaa";
    result = std::regex_replace(s, std::regex("aaa"), "XXX", 
                                std::regex_constants::format_first_only);
    std::cout << "Replace first: " << result << std::endl;
    
    return 0;
}
```

---

## 6. string_view

### 6.1 基本用法

```cpp
#include <iostream>
#include <string>
#include <string_view>

void printView(std::string_view sv) {
    std::cout << "View: " << sv << ", length: " << sv.length() << std::endl;
}

int main() {
    // 从不同来源创建
    std::string str = "Hello, World!";
    const char* cstr = "Hello, C++!";
    
    std::string_view sv1(str);
    std::string_view sv2(cstr);
    std::string_view sv3("Literal");
    std::string_view sv4(str.data(), 5);  // "Hello"
    
    printView(sv1);
    printView(sv2);
    printView(sv3);
    printView(sv4);
    
    // 子视图
    std::string_view sv5 = sv1.substr(7, 5);  // "World"
    printView(sv5);
    
    // 移除前缀/后缀
    std::string_view sv6 = "   Hello   ";
    sv6.remove_prefix(3);
    sv6.remove_suffix(3);
    printView(sv6);  // "Hello"
    
    return 0;
}
```

### 6.2 string_view 的优势

```cpp
#include <iostream>
#include <string>
#include <string_view>
#include <chrono>

// 使用 string (会复制)
void processString(const std::string& s) {
    // 处理字符串
}

// 使用 string_view (不会复制)
void processStringView(std::string_view sv) {
    // 处理字符串
}

int main() {
    std::string longString(1000000, 'x');
    
    // 测试 string
    auto start1 = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 10000; ++i) {
        processString(longString.substr(0, 1000));
    }
    auto end1 = std::chrono::high_resolution_clock::now();
    
    // 测试 string_view
    auto start2 = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 10000; ++i) {
        processStringView(std::string_view(longString).substr(0, 1000));
    }
    auto end2 = std::chrono::high_resolution_clock::now();
    
    auto d1 = std::chrono::duration_cast<std::chrono::microseconds>(end1 - start1);
    auto d2 = std::chrono::duration_cast<std::chrono::microseconds>(end2 - start2);
    
    std::cout << "string: " << d1.count() << " us" << std::endl;
    std::cout << "string_view: " << d2.count() << " us" << std::endl;
    
    return 0;
}
```

### 6.3 注意事项

```cpp
#include <iostream>
#include <string>
#include <string_view>

std::string_view dangerous() {
    std::string local = "Hello";
    return local;  // 危险! local 被销毁后 string_view 悬空
}

std::string_view safe(const std::string& s) {
    return s;  // 安全,只要 s 存在
}

int main() {
    // 注意生命周期
    std::string str = "Hello, World!";
    std::string_view sv = str;
    
    str = "Goodbye";  // sv 现在指向无效内存!
    // std::cout << sv << std::endl;  // 未定义行为
    
    // 正确用法
    std::string str2 = "Hello";
    std::string_view sv2 = str2;
    std::cout << sv2 << std::endl;  // 安全
    
    return 0;
}
```

---

## 7. 总结

### 7.1 字符串操作速查

| 操作 | 方法 |
|------|------|
| 查找 | find, rfind, find_first_of |
| 子串 | substr |
| 追加 | append, +=, push_back |
| 插入 | insert |
| 删除 | erase, pop_back, clear |
| 替换 | replace |
| 比较 | compare, ==, <, > |
| 转换 | stoi, stod, to_string |

### 7.2 最佳实践

```
1. 使用 string_view 避免不必要的复制
2. 预分配空间 (reserve)
3. 使用 emplace 代替 push_back
4. 注意 string_view 的生命周期
5. 使用正则表达式处理复杂模式
```

### 7.3 Part 4 完成

恭喜你完成了 STL 标准模板库部分的全部 8 篇文章!

**实战项目建议**: 文本处理工具
- 实现词频统计
- 实现文本搜索替换
- 实现简单的模板引擎

### 7.4 下一篇预告

在下一篇文章中,我们将进入现代 C++ 部分,学习 auto 与类型推导。

---

> 作者: C++ 技术专栏  
> 系列: STL 标准模板库 (8/8)  
> 上一篇: [容器适配器](./29-container-adapters.md)  
> 下一篇: [auto 与类型推导](../part5-modern/31-auto-type-deduction.md)
