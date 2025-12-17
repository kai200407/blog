---
title: "控制流语句"
description: "1. [条件语句](#1-条件语句)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 5
---

> 本文是 C++ 从入门到精通系列的第五篇,将全面讲解 C++ 的控制流语句,包括条件语句、循环语句以及跳转语句。

---

## 目录

1. [条件语句](#1-条件语句)
2. [循环语句](#2-循环语句)
3. [跳转语句](#3-跳转语句)
4. [范围 for 循环](#4-范围-for-循环)
5. [控制流最佳实践](#5-控制流最佳实践)
6. [总结](#6-总结)

---

## 1. 条件语句

### 1.1 if 语句

```cpp
#include <iostream>

int main() {
    int score = 85;
    
    // 基本 if
    if (score >= 60) {
        std::cout << "及格" << std::endl;
    }
    
    // if-else
    if (score >= 60) {
        std::cout << "及格" << std::endl;
    } else {
        std::cout << "不及格" << std::endl;
    }
    
    // if-else if-else
    if (score >= 90) {
        std::cout << "优秀" << std::endl;
    } else if (score >= 80) {
        std::cout << "良好" << std::endl;
    } else if (score >= 60) {
        std::cout << "及格" << std::endl;
    } else {
        std::cout << "不及格" << std::endl;
    }
    
    return 0;
}
```

### 1.2 if 语句初始化 (C++17)

```cpp
#include <iostream>
#include <map>
#include <string>

int main() {
    std::map<std::string, int> ages = {
        {"Alice", 25},
        {"Bob", 30}
    };
    
    // C++17: if 语句中声明变量
    if (auto it = ages.find("Alice"); it != ages.end()) {
        std::cout << "Found: " << it->first << " = " << it->second << std::endl;
    } else {
        std::cout << "Not found" << std::endl;
    }
    // it 在这里不可见
    
    // 传统写法
    auto it = ages.find("Bob");
    if (it != ages.end()) {
        std::cout << "Found: " << it->first << " = " << it->second << std::endl;
    }
    // it 在这里仍然可见
    
    return 0;
}
```

### 1.3 switch 语句

```cpp
#include <iostream>

int main() {
    int day = 3;
    
    switch (day) {
        case 1:
            std::cout << "Monday" << std::endl;
            break;
        case 2:
            std::cout << "Tuesday" << std::endl;
            break;
        case 3:
            std::cout << "Wednesday" << std::endl;
            break;
        case 4:
            std::cout << "Thursday" << std::endl;
            break;
        case 5:
            std::cout << "Friday" << std::endl;
            break;
        case 6:
        case 7:
            std::cout << "Weekend" << std::endl;
            break;
        default:
            std::cout << "Invalid day" << std::endl;
            break;
    }
    
    return 0;
}
```

### 1.4 switch 语句初始化 (C++17)

```cpp
#include <iostream>

enum class Color { Red, Green, Blue };

int main() {
    // C++17: switch 语句中声明变量
    switch (Color color = Color::Green; color) {
        case Color::Red:
            std::cout << "Red" << std::endl;
            break;
        case Color::Green:
            std::cout << "Green" << std::endl;
            break;
        case Color::Blue:
            std::cout << "Blue" << std::endl;
            break;
    }
    
    return 0;
}
```

### 1.5 [[fallthrough]] 属性 (C++17)

```cpp
#include <iostream>

int main() {
    int value = 1;
    
    switch (value) {
        case 1:
            std::cout << "One" << std::endl;
            [[fallthrough]];  // 明确表示故意穿透
        case 2:
            std::cout << "One or Two" << std::endl;
            break;
        case 3:
            std::cout << "Three" << std::endl;
            break;
    }
    
    return 0;
}
```

### 1.6 条件表达式

```cpp
#include <iostream>

int main() {
    int a = 10, b = 20;
    
    // 三元运算符
    int max = (a > b) ? a : b;
    std::cout << "max = " << max << std::endl;
    
    // 嵌套三元运算符 (不推荐过度嵌套)
    int x = 5;
    const char* result = (x > 0) ? "positive" 
                       : (x < 0) ? "negative" 
                       : "zero";
    std::cout << "x is " << result << std::endl;
    
    return 0;
}
```

---

## 2. 循环语句

### 2.1 while 循环

```cpp
#include <iostream>

int main() {
    // 基本 while 循环
    int i = 0;
    while (i < 5) {
        std::cout << i << " ";
        ++i;
    }
    std::cout << std::endl;
    
    // 无限循环
    // while (true) {
    //     // ...
    //     if (condition) break;
    // }
    
    // 读取输入直到 EOF
    // int value;
    // while (std::cin >> value) {
    //     std::cout << "Read: " << value << std::endl;
    // }
    
    return 0;
}
```

### 2.2 do-while 循环

```cpp
#include <iostream>

int main() {
    // do-while: 至少执行一次
    int i = 0;
    do {
        std::cout << i << " ";
        ++i;
    } while (i < 5);
    std::cout << std::endl;
    
    // 即使条件一开始就为假,也会执行一次
    int j = 10;
    do {
        std::cout << "j = " << j << std::endl;
    } while (j < 5);
    
    // 常用于输入验证
    int choice;
    do {
        std::cout << "Enter 1-3: ";
        std::cin >> choice;
    } while (choice < 1 || choice > 3);
    
    return 0;
}
```

### 2.3 for 循环

```cpp
#include <iostream>

int main() {
    // 基本 for 循环
    for (int i = 0; i < 5; ++i) {
        std::cout << i << " ";
    }
    std::cout << std::endl;
    
    // 多个变量
    for (int i = 0, j = 10; i < j; ++i, --j) {
        std::cout << "i=" << i << ", j=" << j << std::endl;
    }
    
    // 省略部分
    int k = 0;
    for (; k < 5; ) {  // 等价于 while
        std::cout << k << " ";
        ++k;
    }
    std::cout << std::endl;
    
    // 无限循环
    // for (;;) {
    //     // ...
    //     if (condition) break;
    // }
    
    // 倒序遍历
    for (int i = 4; i >= 0; --i) {
        std::cout << i << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

### 2.4 嵌套循环

```cpp
#include <iostream>

int main() {
    // 打印乘法表
    for (int i = 1; i <= 9; ++i) {
        for (int j = 1; j <= i; ++j) {
            std::cout << j << "x" << i << "=" << i*j << "\t";
        }
        std::cout << std::endl;
    }
    
    // 打印矩形
    int rows = 3, cols = 5;
    for (int i = 0; i < rows; ++i) {
        for (int j = 0; j < cols; ++j) {
            std::cout << "* ";
        }
        std::cout << std::endl;
    }
    
    // 打印三角形
    int n = 5;
    for (int i = 1; i <= n; ++i) {
        for (int j = 1; j <= i; ++j) {
            std::cout << "* ";
        }
        std::cout << std::endl;
    }
    
    return 0;
}
```

---

## 3. 跳转语句

### 3.1 break 语句

```cpp
#include <iostream>

int main() {
    // 跳出循环
    for (int i = 0; i < 10; ++i) {
        if (i == 5) {
            break;  // 跳出循环
        }
        std::cout << i << " ";
    }
    std::cout << std::endl;  // 输出: 0 1 2 3 4
    
    // 跳出 switch
    int value = 2;
    switch (value) {
        case 1:
            std::cout << "One" << std::endl;
            break;
        case 2:
            std::cout << "Two" << std::endl;
            break;  // 跳出 switch
        case 3:
            std::cout << "Three" << std::endl;
            break;
    }
    
    // 只跳出最内层循环
    for (int i = 0; i < 3; ++i) {
        for (int j = 0; j < 3; ++j) {
            if (j == 1) {
                break;  // 只跳出内层循环
            }
            std::cout << "(" << i << "," << j << ") ";
        }
        std::cout << std::endl;
    }
    
    return 0;
}
```

### 3.2 continue 语句

```cpp
#include <iostream>

int main() {
    // 跳过当前迭代
    for (int i = 0; i < 10; ++i) {
        if (i % 2 == 0) {
            continue;  // 跳过偶数
        }
        std::cout << i << " ";
    }
    std::cout << std::endl;  // 输出: 1 3 5 7 9
    
    // while 中使用 continue
    int i = 0;
    while (i < 10) {
        ++i;
        if (i % 2 == 0) {
            continue;
        }
        std::cout << i << " ";
    }
    std::cout << std::endl;  // 输出: 1 3 5 7 9
    
    return 0;
}
```

### 3.3 goto 语句 (不推荐)

```cpp
#include <iostream>

int main() {
    // goto 语句 (一般不推荐使用)
    int i = 0;
    
loop:
    if (i < 5) {
        std::cout << i << " ";
        ++i;
        goto loop;
    }
    std::cout << std::endl;
    
    // 唯一合理的用途: 跳出多层嵌套循环
    for (int i = 0; i < 10; ++i) {
        for (int j = 0; j < 10; ++j) {
            for (int k = 0; k < 10; ++k) {
                if (i + j + k == 15) {
                    std::cout << "Found: " << i << "," << j << "," << k << std::endl;
                    goto done;  // 跳出所有循环
                }
            }
        }
    }
done:
    std::cout << "Search complete" << std::endl;
    
    return 0;
}
```

### 3.4 return 语句

```cpp
#include <iostream>

int factorial(int n) {
    if (n <= 1) {
        return 1;  // 提前返回
    }
    return n * factorial(n - 1);
}

void printPositive(int value) {
    if (value <= 0) {
        return;  // 提前返回 (void 函数)
    }
    std::cout << "Value: " << value << std::endl;
}

int main() {
    std::cout << "5! = " << factorial(5) << std::endl;
    
    printPositive(10);
    printPositive(-5);
    
    return 0;  // 从 main 返回
}
```

---

## 4. 范围 for 循环

### 4.1 基本用法

```cpp
#include <iostream>
#include <vector>
#include <array>
#include <string>

int main() {
    // 数组
    int arr[] = {1, 2, 3, 4, 5};
    for (int x : arr) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    // vector
    std::vector<int> vec = {10, 20, 30, 40, 50};
    for (int x : vec) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    // string
    std::string str = "Hello";
    for (char c : str) {
        std::cout << c << " ";
    }
    std::cout << std::endl;
    
    // 初始化列表
    for (int x : {1, 2, 3, 4, 5}) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    return 0;
}
```

### 4.2 引用与 const

```cpp
#include <iostream>
#include <vector>

int main() {
    std::vector<int> vec = {1, 2, 3, 4, 5};
    
    // 值拷贝 (不修改原容器)
    for (int x : vec) {
        x *= 2;  // 不影响 vec
    }
    
    // 引用 (可以修改原容器)
    for (int& x : vec) {
        x *= 2;  // 修改 vec
    }
    
    // const 引用 (只读,避免拷贝)
    for (const int& x : vec) {
        std::cout << x << " ";
        // x *= 2;  // 错误: 不能修改
    }
    std::cout << std::endl;
    
    // auto 推导
    for (auto x : vec) { }        // int (拷贝)
    for (auto& x : vec) { }       // int& (引用)
    for (const auto& x : vec) { } // const int& (const 引用)
    
    return 0;
}
```

### 4.3 结构化绑定 (C++17)

```cpp
#include <iostream>
#include <map>
#include <vector>
#include <tuple>

int main() {
    // map 遍历
    std::map<std::string, int> ages = {
        {"Alice", 25},
        {"Bob", 30},
        {"Charlie", 35}
    };
    
    for (const auto& [name, age] : ages) {
        std::cout << name << ": " << age << std::endl;
    }
    
    // pair vector
    std::vector<std::pair<int, std::string>> items = {
        {1, "one"},
        {2, "two"},
        {3, "three"}
    };
    
    for (const auto& [num, str] : items) {
        std::cout << num << " = " << str << std::endl;
    }
    
    // tuple vector
    std::vector<std::tuple<int, double, std::string>> data = {
        {1, 1.1, "a"},
        {2, 2.2, "b"}
    };
    
    for (const auto& [i, d, s] : data) {
        std::cout << i << ", " << d << ", " << s << std::endl;
    }
    
    return 0;
}
```

### 4.4 范围 for 循环初始化 (C++20)

```cpp
#include <iostream>
#include <vector>

std::vector<int> getNumbers() {
    return {1, 2, 3, 4, 5};
}

int main() {
    // C++20: 范围 for 循环中初始化
    for (auto vec = getNumbers(); auto x : vec) {
        std::cout << x << " ";
    }
    std::cout << std::endl;
    
    // 等价于
    {
        auto vec = getNumbers();
        for (auto x : vec) {
            std::cout << x << " ";
        }
    }
    std::cout << std::endl;
    
    return 0;
}
```

---

## 5. 控制流最佳实践

### 5.1 避免深层嵌套

```cpp
#include <iostream>

// 不好: 深层嵌套
void processDeep(int value) {
    if (value > 0) {
        if (value < 100) {
            if (value % 2 == 0) {
                std::cout << "Valid even number" << std::endl;
            }
        }
    }
}

// 好: 提前返回
void processFlat(int value) {
    if (value <= 0) return;
    if (value >= 100) return;
    if (value % 2 != 0) return;
    
    std::cout << "Valid even number" << std::endl;
}

// 好: 合并条件
void processCombined(int value) {
    if (value > 0 && value < 100 && value % 2 == 0) {
        std::cout << "Valid even number" << std::endl;
    }
}
```

### 5.2 循环优化

```cpp
#include <iostream>
#include <vector>

int main() {
    std::vector<int> vec(1000000);
    
    // 不好: 每次迭代都调用 size()
    for (size_t i = 0; i < vec.size(); ++i) {
        // ...
    }
    
    // 好: 缓存 size()
    for (size_t i = 0, n = vec.size(); i < n; ++i) {
        // ...
    }
    
    // 更好: 使用范围 for
    for (auto& x : vec) {
        // ...
    }
    
    // 使用迭代器
    for (auto it = vec.begin(); it != vec.end(); ++it) {
        // ...
    }
    
    return 0;
}
```

### 5.3 switch vs if-else

```cpp
#include <iostream>

// 使用 switch: 当比较同一变量的多个常量值时
void handleCommand(int cmd) {
    switch (cmd) {
        case 1: /* ... */ break;
        case 2: /* ... */ break;
        case 3: /* ... */ break;
        default: /* ... */ break;
    }
}

// 使用 if-else: 当条件是范围或复杂表达式时
void handleScore(int score) {
    if (score >= 90) {
        std::cout << "A" << std::endl;
    } else if (score >= 80) {
        std::cout << "B" << std::endl;
    } else if (score >= 70) {
        std::cout << "C" << std::endl;
    } else {
        std::cout << "F" << std::endl;
    }
}
```

### 5.4 使用标准算法替代循环

```cpp
#include <iostream>
#include <vector>
#include <algorithm>
#include <numeric>

int main() {
    std::vector<int> vec = {1, 2, 3, 4, 5};
    
    // 不好: 手动循环求和
    int sum1 = 0;
    for (int x : vec) {
        sum1 += x;
    }
    
    // 好: 使用 std::accumulate
    int sum2 = std::accumulate(vec.begin(), vec.end(), 0);
    
    // 不好: 手动查找
    bool found1 = false;
    for (int x : vec) {
        if (x == 3) {
            found1 = true;
            break;
        }
    }
    
    // 好: 使用 std::find
    bool found2 = std::find(vec.begin(), vec.end(), 3) != vec.end();
    
    // 好: 使用 std::any_of
    bool found3 = std::any_of(vec.begin(), vec.end(), [](int x) { return x == 3; });
    
    std::cout << "sum = " << sum2 << std::endl;
    std::cout << "found = " << std::boolalpha << found2 << std::endl;
    
    return 0;
}
```

---

## 6. 总结

### 6.1 控制流语句一览

| 类型 | 语句 | 用途 |
|------|------|------|
| 条件 | if, if-else, switch | 条件分支 |
| 循环 | while, do-while, for, range-for | 重复执行 |
| 跳转 | break, continue, return, goto | 改变执行流程 |

### 6.2 最佳实践

```
1. 优先使用范围 for 循环
2. 避免深层嵌套,使用提前返回
3. switch 中不要忘记 break
4. 使用 [[fallthrough]] 标记故意穿透
5. 利用 C++17 的 if/switch 初始化
6. 考虑使用标准算法替代手动循环
7. 避免使用 goto
```

### 6.3 下一篇预告

在下一篇文章中,我们将学习 C++ 的函数。

---

## 参考资料

1. [C++ Statements](https://en.cppreference.com/w/cpp/language/statements)
2. [Range-based for loop](https://en.cppreference.com/w/cpp/language/range-for)

---

> 作者: C++ 技术专栏  
> 系列: C++ 基础入门 (5/8)  
> 上一篇: [运算符](./04-operators.md)  
> 下一篇: [函数](./06-functions.md)
