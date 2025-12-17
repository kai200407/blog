---
title: "字符串处理"
description: "1. [C 风格字符串](#1-c-风格字符串)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 8
---

> 本文是 C++ 从入门到精通系列的第八篇,也是第一部分的收官之作。我们将全面讲解 C++ 的字符串处理,包括 C 风格字符串和 std::string。

---

## 目录

1. [C 风格字符串](#1-c-风格字符串)
2. [std::string 基础](#2-stdstring-基础)
3. [字符串操作](#3-字符串操作)
4. [字符串查找](#4-字符串查找)
5. [字符串转换](#5-字符串转换)
6. [字符串视图](#6-字符串视图)
7. [字符串格式化](#7-字符串格式化)
8. [总结](#8-总结)

---

## 1. C 风格字符串

### 1.1 字符数组

```cpp
#include <iostream>
#include <cstring>

int main() {
    // C 风格字符串: 以 '\0' 结尾的字符数组
    char str1[] = "Hello";  // 自动添加 '\0',大小为 6
    char str2[10] = "World"; // 大小为 10,后面填充 '\0'
    char str3[] = {'H', 'i', '\0'};  // 手动添加 '\0'
    
    // 打印
    std::cout << str1 << std::endl;
    std::cout << "Length: " << strlen(str1) << std::endl;
    std::cout << "Size: " << sizeof(str1) << std::endl;
    
    // 字符访问
    std::cout << "str1[0] = " << str1[0] << std::endl;
    str1[0] = 'h';
    std::cout << str1 << std::endl;
    
    // 注意: 字符串字面量是 const
    const char* str4 = "Constant";
    // str4[0] = 'c';  // 错误: 不能修改字符串字面量
    
    return 0;
}
```

### 1.2 C 字符串函数

```cpp
#include <iostream>
#include <cstring>

int main() {
    char str1[20] = "Hello";
    char str2[] = "World";
    char dest[50];
    
    // strlen: 字符串长度 (不含 '\0')
    std::cout << "strlen(str1) = " << strlen(str1) << std::endl;
    
    // strcpy: 复制字符串
    strcpy(dest, str1);
    std::cout << "After strcpy: " << dest << std::endl;
    
    // strcat: 连接字符串
    strcat(dest, " ");
    strcat(dest, str2);
    std::cout << "After strcat: " << dest << std::endl;
    
    // strcmp: 比较字符串
    int result = strcmp(str1, str2);
    if (result < 0) {
        std::cout << str1 << " < " << str2 << std::endl;
    } else if (result > 0) {
        std::cout << str1 << " > " << str2 << std::endl;
    } else {
        std::cout << str1 << " == " << str2 << std::endl;
    }
    
    // strchr: 查找字符
    char* pos = strchr(dest, 'o');
    if (pos) {
        std::cout << "Found 'o' at position: " << (pos - dest) << std::endl;
    }
    
    // strstr: 查找子串
    char* sub = strstr(dest, "World");
    if (sub) {
        std::cout << "Found 'World' at position: " << (sub - dest) << std::endl;
    }
    
    return 0;
}
```

### 1.3 C 字符串的问题

```cpp
#include <iostream>
#include <cstring>

int main() {
    // 问题 1: 缓冲区溢出
    char small[5];
    // strcpy(small, "This is too long");  // 危险!
    
    // 安全版本
    strncpy(small, "This is too long", sizeof(small) - 1);
    small[sizeof(small) - 1] = '\0';
    
    // 问题 2: 忘记 '\0'
    char str[5] = {'H', 'e', 'l', 'l', 'o'};  // 没有 '\0'
    // std::cout << str;  // 未定义行为
    
    // 问题 3: 内存管理
    char* dynamic = new char[100];
    strcpy(dynamic, "Dynamic string");
    // 必须手动释放
    delete[] dynamic;
    
    return 0;
}
```

---

## 2. std::string 基础

### 2.1 创建字符串

```cpp
#include <iostream>
#include <string>

int main() {
    // 默认构造
    std::string s1;
    
    // 从 C 字符串构造
    std::string s2 = "Hello";
    std::string s3("World");
    
    // 重复字符
    std::string s4(5, 'A');  // "AAAAA"
    
    // 拷贝构造
    std::string s5 = s2;
    std::string s6(s2);
    
    // 子串构造
    std::string s7(s2, 1, 3);  // "ell" (从位置 1 开始,长度 3)
    
    // 迭代器构造
    std::string s8(s2.begin(), s2.end());
    
    // C++11 初始化列表
    std::string s9{'H', 'i'};
    
    // 打印
    std::cout << "s1: '" << s1 << "'" << std::endl;
    std::cout << "s2: " << s2 << std::endl;
    std::cout << "s4: " << s4 << std::endl;
    std::cout << "s7: " << s7 << std::endl;
    
    return 0;
}
```

### 2.2 字符串属性

```cpp
#include <iostream>
#include <string>

int main() {
    std::string str = "Hello, World!";
    
    // 长度
    std::cout << "length(): " << str.length() << std::endl;
    std::cout << "size(): " << str.size() << std::endl;
    
    // 容量
    std::cout << "capacity(): " << str.capacity() << std::endl;
    std::cout << "max_size(): " << str.max_size() << std::endl;
    
    // 是否为空
    std::cout << "empty(): " << std::boolalpha << str.empty() << std::endl;
    
    // 调整大小
    str.resize(5);
    std::cout << "After resize(5): " << str << std::endl;
    
    str.resize(10, 'X');
    std::cout << "After resize(10, 'X'): " << str << std::endl;
    
    // 预留空间
    str.reserve(100);
    std::cout << "After reserve(100), capacity: " << str.capacity() << std::endl;
    
    // 收缩到适合大小
    str.shrink_to_fit();
    std::cout << "After shrink_to_fit(), capacity: " << str.capacity() << std::endl;
    
    // 清空
    str.clear();
    std::cout << "After clear(), empty: " << str.empty() << std::endl;
    
    return 0;
}
```

### 2.3 字符访问

```cpp
#include <iostream>
#include <string>

int main() {
    std::string str = "Hello";
    
    // 下标访问 (不检查边界)
    std::cout << "str[0] = " << str[0] << std::endl;
    str[0] = 'h';
    
    // at() 访问 (检查边界)
    std::cout << "str.at(1) = " << str.at(1) << std::endl;
    
    try {
        char c = str.at(100);  // 抛出 std::out_of_range
    } catch (const std::out_of_range& e) {
        std::cout << "Exception: " << e.what() << std::endl;
    }
    
    // 首尾字符
    std::cout << "front(): " << str.front() << std::endl;
    std::cout << "back(): " << str.back() << std::endl;
    
    // 获取 C 字符串
    const char* cstr = str.c_str();
    std::cout << "c_str(): " << cstr << std::endl;
    
    // 获取数据指针
    const char* data = str.data();
    std::cout << "data(): " << data << std::endl;
    
    return 0;
}
```

---

## 3. 字符串操作

### 3.1 赋值与连接

```cpp
#include <iostream>
#include <string>

int main() {
    std::string str;
    
    // 赋值
    str = "Hello";
    str.assign("World");
    str.assign(5, 'A');
    
    std::cout << "After assign: " << str << std::endl;
    
    // 连接
    std::string s1 = "Hello";
    std::string s2 = "World";
    
    // + 运算符
    std::string s3 = s1 + " " + s2;
    std::cout << "s1 + s2: " << s3 << std::endl;
    
    // += 运算符
    s1 += " ";
    s1 += s2;
    std::cout << "s1 += s2: " << s1 << std::endl;
    
    // append()
    std::string s4 = "Hello";
    s4.append(" World");
    s4.append(3, '!');
    std::cout << "After append: " << s4 << std::endl;
    
    // push_back()
    s4.push_back('?');
    std::cout << "After push_back: " << s4 << std::endl;
    
    return 0;
}
```

### 3.2 插入与删除

```cpp
#include <iostream>
#include <string>

int main() {
    std::string str = "Hello World";
    
    // 插入
    str.insert(5, ",");
    std::cout << "After insert: " << str << std::endl;
    
    str.insert(0, "Say: ");
    std::cout << "After insert at 0: " << str << std::endl;
    
    // 删除
    str.erase(0, 5);  // 从位置 0 删除 5 个字符
    std::cout << "After erase: " << str << std::endl;
    
    str.erase(5);  // 从位置 5 删除到末尾
    std::cout << "After erase to end: " << str << std::endl;
    
    // pop_back()
    str.pop_back();
    std::cout << "After pop_back: " << str << std::endl;
    
    return 0;
}
```

### 3.3 替换与子串

```cpp
#include <iostream>
#include <string>

int main() {
    std::string str = "Hello World";
    
    // 替换
    str.replace(6, 5, "C++");  // 从位置 6 替换 5 个字符
    std::cout << "After replace: " << str << std::endl;
    
    // 子串
    std::string sub = str.substr(0, 5);
    std::cout << "Substring: " << sub << std::endl;
    
    std::string sub2 = str.substr(6);  // 从位置 6 到末尾
    std::cout << "Substring from 6: " << sub2 << std::endl;
    
    // 交换
    std::string s1 = "First";
    std::string s2 = "Second";
    s1.swap(s2);
    std::cout << "After swap: s1=" << s1 << ", s2=" << s2 << std::endl;
    
    return 0;
}
```

### 3.4 比较

```cpp
#include <iostream>
#include <string>

int main() {
    std::string s1 = "apple";
    std::string s2 = "banana";
    std::string s3 = "apple";
    
    // 比较运算符
    std::cout << std::boolalpha;
    std::cout << "s1 == s3: " << (s1 == s3) << std::endl;
    std::cout << "s1 != s2: " << (s1 != s2) << std::endl;
    std::cout << "s1 < s2: " << (s1 < s2) << std::endl;
    std::cout << "s1 > s2: " << (s1 > s2) << std::endl;
    
    // compare()
    int result = s1.compare(s2);
    if (result < 0) {
        std::cout << s1 << " < " << s2 << std::endl;
    } else if (result > 0) {
        std::cout << s1 << " > " << s2 << std::endl;
    } else {
        std::cout << s1 << " == " << s2 << std::endl;
    }
    
    // 部分比较
    std::string str = "Hello World";
    result = str.compare(0, 5, "Hello");
    std::cout << "Compare first 5 chars with 'Hello': " << result << std::endl;
    
    return 0;
}
```

---

## 4. 字符串查找

### 4.1 查找函数

```cpp
#include <iostream>
#include <string>

int main() {
    std::string str = "Hello World, Hello C++";
    
    // find(): 从前向后查找
    size_t pos = str.find("Hello");
    if (pos != std::string::npos) {
        std::cout << "Found 'Hello' at: " << pos << std::endl;
    }
    
    // 从指定位置开始查找
    pos = str.find("Hello", 1);
    std::cout << "Found second 'Hello' at: " << pos << std::endl;
    
    // rfind(): 从后向前查找
    pos = str.rfind("Hello");
    std::cout << "Last 'Hello' at: " << pos << std::endl;
    
    // find_first_of(): 查找任意字符首次出现
    pos = str.find_first_of("aeiou");
    std::cout << "First vowel at: " << pos << std::endl;
    
    // find_last_of(): 查找任意字符最后出现
    pos = str.find_last_of("aeiou");
    std::cout << "Last vowel at: " << pos << std::endl;
    
    // find_first_not_of(): 查找不在集合中的首个字符
    pos = str.find_first_not_of("Helo ");
    std::cout << "First char not in 'Helo ': " << pos << std::endl;
    
    // find_last_not_of()
    pos = str.find_last_not_of("+");
    std::cout << "Last char not '+': " << pos << std::endl;
    
    return 0;
}
```

### 4.2 查找与替换所有

```cpp
#include <iostream>
#include <string>

// 替换所有出现
std::string replaceAll(std::string str, const std::string& from, const std::string& to) {
    size_t pos = 0;
    while ((pos = str.find(from, pos)) != std::string::npos) {
        str.replace(pos, from.length(), to);
        pos += to.length();
    }
    return str;
}

// 统计出现次数
int countOccurrences(const std::string& str, const std::string& sub) {
    int count = 0;
    size_t pos = 0;
    while ((pos = str.find(sub, pos)) != std::string::npos) {
        ++count;
        pos += sub.length();
    }
    return count;
}

int main() {
    std::string str = "Hello World, Hello C++, Hello Everyone";
    
    std::cout << "Original: " << str << std::endl;
    std::cout << "'Hello' count: " << countOccurrences(str, "Hello") << std::endl;
    
    str = replaceAll(str, "Hello", "Hi");
    std::cout << "After replace: " << str << std::endl;
    
    return 0;
}
```

### 4.3 C++20 contains/starts_with/ends_with

```cpp
#include <iostream>
#include <string>

int main() {
    std::string str = "Hello World";
    
    // C++20 新增方法
    std::cout << std::boolalpha;
    
    // starts_with
    std::cout << "starts_with('Hello'): " << str.starts_with("Hello") << std::endl;
    std::cout << "starts_with('World'): " << str.starts_with("World") << std::endl;
    
    // ends_with
    std::cout << "ends_with('World'): " << str.ends_with("World") << std::endl;
    std::cout << "ends_with('Hello'): " << str.ends_with("Hello") << std::endl;
    
    // contains
    std::cout << "contains('lo Wo'): " << str.contains("lo Wo") << std::endl;
    std::cout << "contains('xyz'): " << str.contains("xyz") << std::endl;
    
    return 0;
}
```

---

## 5. 字符串转换

### 5.1 数值转字符串

```cpp
#include <iostream>
#include <string>
#include <sstream>

int main() {
    // std::to_string (C++11)
    int i = 42;
    double d = 3.14159;
    
    std::string s1 = std::to_string(i);
    std::string s2 = std::to_string(d);
    
    std::cout << "to_string(42): " << s1 << std::endl;
    std::cout << "to_string(3.14159): " << s2 << std::endl;
    
    // stringstream
    std::ostringstream oss;
    oss << "Value: " << i << ", Pi: " << std::fixed << std::setprecision(2) << d;
    std::string s3 = oss.str();
    std::cout << "stringstream: " << s3 << std::endl;
    
    return 0;
}
```

### 5.2 字符串转数值

```cpp
#include <iostream>
#include <string>
#include <sstream>

int main() {
    std::string s1 = "42";
    std::string s2 = "3.14159";
    std::string s3 = "100abc";
    
    // stoi, stol, stoll (C++11)
    int i = std::stoi(s1);
    long l = std::stol(s1);
    long long ll = std::stoll(s1);
    
    // stof, stod, stold
    float f = std::stof(s2);
    double d = std::stod(s2);
    
    std::cout << "stoi: " << i << std::endl;
    std::cout << "stod: " << d << std::endl;
    
    // 带位置参数
    size_t pos;
    int partial = std::stoi(s3, &pos);
    std::cout << "stoi('" << s3 << "'): " << partial << ", pos: " << pos << std::endl;
    
    // 不同进制
    std::string hex = "FF";
    int hexVal = std::stoi(hex, nullptr, 16);
    std::cout << "stoi('FF', 16): " << hexVal << std::endl;
    
    // stringstream
    std::istringstream iss("123 456 789");
    int a, b, c;
    iss >> a >> b >> c;
    std::cout << "Parsed: " << a << ", " << b << ", " << c << std::endl;
    
    // 异常处理
    try {
        int invalid = std::stoi("not a number");
    } catch (const std::invalid_argument& e) {
        std::cout << "Invalid argument: " << e.what() << std::endl;
    } catch (const std::out_of_range& e) {
        std::cout << "Out of range: " << e.what() << std::endl;
    }
    
    return 0;
}
```

### 5.3 大小写转换

```cpp
#include <iostream>
#include <string>
#include <algorithm>
#include <cctype>

int main() {
    std::string str = "Hello World";
    
    // 转大写
    std::string upper = str;
    std::transform(upper.begin(), upper.end(), upper.begin(), ::toupper);
    std::cout << "Upper: " << upper << std::endl;
    
    // 转小写
    std::string lower = str;
    std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);
    std::cout << "Lower: " << lower << std::endl;
    
    // 单个字符
    char c = 'a';
    std::cout << "toupper('a'): " << static_cast<char>(std::toupper(c)) << std::endl;
    std::cout << "tolower('A'): " << static_cast<char>(std::tolower('A')) << std::endl;
    
    return 0;
}
```

---

## 6. 字符串视图

### 6.1 std::string_view (C++17)

```cpp
#include <iostream>
#include <string>
#include <string_view>

// 使用 string_view 避免拷贝
void printView(std::string_view sv) {
    std::cout << "View: " << sv << std::endl;
    std::cout << "Length: " << sv.length() << std::endl;
}

int main() {
    // 从不同来源创建
    std::string str = "Hello World";
    const char* cstr = "C String";
    
    std::string_view sv1 = str;
    std::string_view sv2 = cstr;
    std::string_view sv3 = "Literal";
    
    printView(sv1);
    printView(sv2);
    printView(sv3);
    
    // 子视图
    std::string_view sub = sv1.substr(0, 5);
    std::cout << "Substring view: " << sub << std::endl;
    
    // 移除前缀/后缀
    std::string_view sv4 = "   Hello   ";
    sv4.remove_prefix(3);
    sv4.remove_suffix(3);
    std::cout << "Trimmed: '" << sv4 << "'" << std::endl;
    
    // 注意: string_view 不拥有数据
    // 确保底层数据在 string_view 使用期间有效
    
    return 0;
}
```

### 6.2 string_view 注意事项

```cpp
#include <iostream>
#include <string>
#include <string_view>

// 危险: 返回临时对象的 string_view
std::string_view dangerous() {
    std::string temp = "Temporary";
    return temp;  // 危险! temp 被销毁后 view 悬空
}

// 安全: 返回 string
std::string safe() {
    std::string temp = "Temporary";
    return temp;
}

int main() {
    // 安全用法
    std::string str = "Hello";
    std::string_view sv = str;
    std::cout << sv << std::endl;
    
    // 危险: str 被修改后 sv 可能失效
    str += " World";  // 可能导致重新分配
    // sv 可能指向无效内存
    
    // 安全: 重新获取 view
    sv = str;
    std::cout << sv << std::endl;
    
    return 0;
}
```

---

## 7. 字符串格式化

### 7.1 传统方式

```cpp
#include <iostream>
#include <string>
#include <sstream>
#include <iomanip>
#include <cstdio>

int main() {
    int id = 42;
    std::string name = "Alice";
    double score = 95.5;
    
    // sprintf (C 风格,不安全)
    char buffer[100];
    sprintf(buffer, "ID: %d, Name: %s, Score: %.1f", id, name.c_str(), score);
    std::cout << buffer << std::endl;
    
    // snprintf (更安全)
    snprintf(buffer, sizeof(buffer), "ID: %d, Name: %s, Score: %.1f", 
             id, name.c_str(), score);
    std::cout << buffer << std::endl;
    
    // stringstream
    std::ostringstream oss;
    oss << "ID: " << id << ", Name: " << name 
        << ", Score: " << std::fixed << std::setprecision(1) << score;
    std::cout << oss.str() << std::endl;
    
    return 0;
}
```

### 7.2 std::format (C++20)

```cpp
#include <iostream>
#include <string>
#include <format>

int main() {
    int id = 42;
    std::string name = "Alice";
    double score = 95.5;
    
    // 基本格式化
    std::string s1 = std::format("ID: {}, Name: {}, Score: {}", id, name, score);
    std::cout << s1 << std::endl;
    
    // 位置参数
    std::string s2 = std::format("{1} has ID {0}", id, name);
    std::cout << s2 << std::endl;
    
    // 格式说明符
    std::string s3 = std::format("Hex: {:x}, Binary: {:b}, Octal: {:o}", 255, 255, 255);
    std::cout << s3 << std::endl;
    
    // 宽度和对齐
    std::string s4 = std::format("|{:10}|{:<10}|{:>10}|{:^10}|", 
                                  "default", "left", "right", "center");
    std::cout << s4 << std::endl;
    
    // 填充字符
    std::string s5 = std::format("{:*^20}", "Hello");
    std::cout << s5 << std::endl;
    
    // 浮点数精度
    std::string s6 = std::format("Pi: {:.2f}, Scientific: {:.2e}", 3.14159, 12345.6789);
    std::cout << s6 << std::endl;
    
    // 直接输出
    std::print("Direct print: {} + {} = {}\n", 1, 2, 3);
    
    return 0;
}
```

### 7.3 字符串分割

```cpp
#include <iostream>
#include <string>
#include <vector>
#include <sstream>

// 使用 stringstream 分割
std::vector<std::string> split(const std::string& str, char delimiter) {
    std::vector<std::string> tokens;
    std::stringstream ss(str);
    std::string token;
    
    while (std::getline(ss, token, delimiter)) {
        if (!token.empty()) {
            tokens.push_back(token);
        }
    }
    
    return tokens;
}

// 使用 find 分割
std::vector<std::string> splitByString(const std::string& str, const std::string& delimiter) {
    std::vector<std::string> tokens;
    size_t start = 0;
    size_t end = 0;
    
    while ((end = str.find(delimiter, start)) != std::string::npos) {
        tokens.push_back(str.substr(start, end - start));
        start = end + delimiter.length();
    }
    tokens.push_back(str.substr(start));
    
    return tokens;
}

int main() {
    std::string str = "apple,banana,cherry,date";
    
    auto tokens = split(str, ',');
    for (const auto& token : tokens) {
        std::cout << token << std::endl;
    }
    
    std::string str2 = "one::two::three::four";
    auto tokens2 = splitByString(str2, "::");
    for (const auto& token : tokens2) {
        std::cout << token << std::endl;
    }
    
    return 0;
}
```

---

## 8. 总结

### 8.1 字符串类型对比

| 类型 | 特点 | 使用场景 |
|------|------|---------|
| char[] | 固定大小,手动管理 | 与 C 代码交互 |
| std::string | 动态大小,自动管理 | 一般用途 |
| std::string_view | 只读视图,无拷贝 | 函数参数 |

### 8.2 最佳实践

```
1. 优先使用 std::string
2. 函数参数使用 std::string_view 或 const std::string&
3. 使用 std::format (C++20) 进行格式化
4. 避免 C 风格字符串函数
5. 注意 string_view 的生命周期
6. 预分配空间提高性能 (reserve)
```

### 8.3 Part 1 完成

恭喜你完成了 C++ 基础入门部分的全部 8 篇文章!

**实战项目建议**: 命令行计算器
- 支持四则运算和括号
- 使用字符串解析表达式
- 实现错误处理

### 8.4 下一篇预告

在下一篇文章中,我们将进入面向对象编程部分,学习类与对象。

---

## 参考资料

1. [std::string](https://en.cppreference.com/w/cpp/string/basic_string)
2. [std::string_view](https://en.cppreference.com/w/cpp/string/basic_string_view)
3. [std::format](https://en.cppreference.com/w/cpp/utility/format/format)

---

> 作者: C++ 技术专栏  
> 系列: C++ 基础入门 (8/8)  
> 上一篇: [数组与指针基础](./07-arrays-pointers.md)  
> 下一篇: [类与对象](../part2-oop/09-class-object.md)
