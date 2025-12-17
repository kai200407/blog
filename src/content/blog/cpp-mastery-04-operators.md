---
title: "运算符"
description: "1. [算术运算符](#1-算术运算符)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 4
---

> 本文是 C++ 从入门到精通系列的第四篇,将全面讲解 C++ 的各类运算符,包括算术、关系、逻辑、位运算以及运算符优先级。

---

## 目录

1. [算术运算符](#1-算术运算符)
2. [关系运算符](#2-关系运算符)
3. [逻辑运算符](#3-逻辑运算符)
4. [位运算符](#4-位运算符)
5. [赋值运算符](#5-赋值运算符)
6. [其他运算符](#6-其他运算符)
7. [运算符优先级](#7-运算符优先级)
8. [总结](#8-总结)

---

## 1. 算术运算符

### 1.1 基本算术运算

```cpp
#include <iostream>

int main() {
    int a = 10, b = 3;
    
    // 基本运算
    std::cout << "a + b = " << (a + b) << std::endl;  // 13
    std::cout << "a - b = " << (a - b) << std::endl;  // 7
    std::cout << "a * b = " << (a * b) << std::endl;  // 30
    std::cout << "a / b = " << (a / b) << std::endl;  // 3 (整数除法)
    std::cout << "a % b = " << (a % b) << std::endl;  // 1 (取模)
    
    // 浮点除法
    double x = 10.0, y = 3.0;
    std::cout << "x / y = " << (x / y) << std::endl;  // 3.33333
    
    // 混合运算
    std::cout << "a / y = " << (a / y) << std::endl;  // 3.33333 (int 转 double)
    
    // 负数取模
    std::cout << "-10 % 3 = " << (-10 % 3) << std::endl;  // -1
    std::cout << "10 % -3 = " << (10 % -3) << std::endl;  // 1
    
    return 0;
}
```

### 1.2 一元运算符

```cpp
#include <iostream>

int main() {
    int a = 5;
    
    // 正负号
    int pos = +a;   // 5
    int neg = -a;   // -5
    
    // 自增自减
    int b = 5;
    std::cout << "b = " << b << std::endl;      // 5
    std::cout << "++b = " << (++b) << std::endl; // 6 (先增后用)
    std::cout << "b++ = " << (b++) << std::endl; // 6 (先用后增)
    std::cout << "b = " << b << std::endl;      // 7
    
    int c = 5;
    std::cout << "--c = " << (--c) << std::endl; // 4
    std::cout << "c-- = " << (c--) << std::endl; // 4
    std::cout << "c = " << c << std::endl;      // 3
    
    return 0;
}
```

### 1.3 注意事项

```cpp
#include <iostream>
#include <climits>

int main() {
    // 整数溢出 (未定义行为)
    int max = INT_MAX;
    std::cout << "INT_MAX = " << max << std::endl;
    std::cout << "INT_MAX + 1 = " << (max + 1) << std::endl;  // 溢出!
    
    // 除零 (未定义行为)
    // int result = 10 / 0;  // 运行时错误
    
    // 浮点除零
    double inf = 10.0 / 0.0;  // Infinity
    double nan = 0.0 / 0.0;   // NaN
    std::cout << "10.0 / 0.0 = " << inf << std::endl;
    std::cout << "0.0 / 0.0 = " << nan << std::endl;
    
    // 浮点精度问题
    double d1 = 0.1 + 0.2;
    double d2 = 0.3;
    std::cout << "0.1 + 0.2 == 0.3? " << (d1 == d2) << std::endl;  // 0 (false)
    std::cout << "0.1 + 0.2 = " << std::fixed << d1 << std::endl;
    
    return 0;
}
```

---

## 2. 关系运算符

### 2.1 比较运算

```cpp
#include <iostream>

int main() {
    int a = 10, b = 20;
    
    std::cout << std::boolalpha;  // 输出 true/false 而非 1/0
    
    std::cout << "a == b: " << (a == b) << std::endl;  // false
    std::cout << "a != b: " << (a != b) << std::endl;  // true
    std::cout << "a < b: " << (a < b) << std::endl;    // true
    std::cout << "a > b: " << (a > b) << std::endl;    // false
    std::cout << "a <= b: " << (a <= b) << std::endl;  // true
    std::cout << "a >= b: " << (a >= b) << std::endl;  // false
    
    return 0;
}
```

### 2.2 三路比较运算符 (C++20)

```cpp
#include <iostream>
#include <compare>

int main() {
    int a = 10, b = 20;
    
    // <=> 返回 std::strong_ordering
    auto result = a <=> b;
    
    if (result < 0) {
        std::cout << "a < b" << std::endl;
    } else if (result > 0) {
        std::cout << "a > b" << std::endl;
    } else {
        std::cout << "a == b" << std::endl;
    }
    
    // 比较类型
    // std::strong_ordering: 完全相等
    // std::weak_ordering: 等价但不完全相等
    // std::partial_ordering: 可能无法比较 (如 NaN)
    
    double x = 1.0, y = std::nan("");
    auto floatResult = x <=> y;  // partial_ordering::unordered
    
    return 0;
}
```

### 2.3 浮点数比较

```cpp
#include <iostream>
#include <cmath>

// 安全的浮点数比较
bool almostEqual(double a, double b, double epsilon = 1e-9) {
    return std::abs(a - b) < epsilon;
}

bool relativeEqual(double a, double b, double epsilon = 1e-9) {
    return std::abs(a - b) <= epsilon * std::max(std::abs(a), std::abs(b));
}

int main() {
    double a = 0.1 + 0.2;
    double b = 0.3;
    
    std::cout << std::boolalpha;
    std::cout << "a == b: " << (a == b) << std::endl;  // false
    std::cout << "almostEqual: " << almostEqual(a, b) << std::endl;  // true
    
    return 0;
}
```

---

## 3. 逻辑运算符

### 3.1 基本逻辑运算

```cpp
#include <iostream>

int main() {
    bool a = true, b = false;
    
    std::cout << std::boolalpha;
    
    // 逻辑与
    std::cout << "a && b: " << (a && b) << std::endl;  // false
    std::cout << "a && a: " << (a && a) << std::endl;  // true
    
    // 逻辑或
    std::cout << "a || b: " << (a || b) << std::endl;  // true
    std::cout << "b || b: " << (b || b) << std::endl;  // false
    
    // 逻辑非
    std::cout << "!a: " << (!a) << std::endl;  // false
    std::cout << "!b: " << (!b) << std::endl;  // true
    
    return 0;
}
```

### 3.2 短路求值

```cpp
#include <iostream>

bool checkA() {
    std::cout << "Checking A" << std::endl;
    return false;
}

bool checkB() {
    std::cout << "Checking B" << std::endl;
    return true;
}

int main() {
    // && 短路: 如果左边为 false,不计算右边
    std::cout << "=== && 短路 ===" << std::endl;
    if (checkA() && checkB()) {  // 只调用 checkA
        std::cout << "Both true" << std::endl;
    }
    
    // || 短路: 如果左边为 true,不计算右边
    std::cout << "=== || 短路 ===" << std::endl;
    if (checkB() || checkA()) {  // 只调用 checkB
        std::cout << "At least one true" << std::endl;
    }
    
    // 利用短路求值进行安全检查
    int* ptr = nullptr;
    // 安全: ptr 为空时不会解引用
    if (ptr != nullptr && *ptr > 0) {
        std::cout << "Value is positive" << std::endl;
    }
    
    return 0;
}
```

### 3.3 逻辑运算真值表

```
逻辑与 (&&):
A     B     A && B
─────────────────
false false false
false true  false
true  false false
true  true  true

逻辑或 (||):
A     B     A || B
─────────────────
false false false
false true  true
true  false true
true  true  true

逻辑非 (!):
A     !A
─────────
false true
true  false
```

---

## 4. 位运算符

### 4.1 基本位运算

```cpp
#include <iostream>
#include <bitset>

int main() {
    unsigned int a = 0b1010;  // 10
    unsigned int b = 0b1100;  // 12
    
    // 按位与
    std::cout << "a & b = " << std::bitset<4>(a & b) << std::endl;  // 1000
    
    // 按位或
    std::cout << "a | b = " << std::bitset<4>(a | b) << std::endl;  // 1110
    
    // 按位异或
    std::cout << "a ^ b = " << std::bitset<4>(a ^ b) << std::endl;  // 0110
    
    // 按位取反
    std::cout << "~a = " << std::bitset<32>(~a) << std::endl;
    
    // 左移
    std::cout << "a << 1 = " << std::bitset<8>(a << 1) << std::endl;  // 10100
    
    // 右移
    std::cout << "a >> 1 = " << std::bitset<4>(a >> 1) << std::endl;  // 0101
    
    return 0;
}
```

### 4.2 位运算应用

```cpp
#include <iostream>
#include <bitset>

int main() {
    unsigned int flags = 0;
    
    // 定义标志位
    const unsigned int FLAG_A = 1 << 0;  // 0001
    const unsigned int FLAG_B = 1 << 1;  // 0010
    const unsigned int FLAG_C = 1 << 2;  // 0100
    const unsigned int FLAG_D = 1 << 3;  // 1000
    
    // 设置标志
    flags |= FLAG_A;  // 设置 FLAG_A
    flags |= FLAG_C;  // 设置 FLAG_C
    std::cout << "After set: " << std::bitset<4>(flags) << std::endl;  // 0101
    
    // 清除标志
    flags &= ~FLAG_A;  // 清除 FLAG_A
    std::cout << "After clear: " << std::bitset<4>(flags) << std::endl;  // 0100
    
    // 切换标志
    flags ^= FLAG_B;  // 切换 FLAG_B
    std::cout << "After toggle: " << std::bitset<4>(flags) << std::endl;  // 0110
    
    // 检查标志
    if (flags & FLAG_C) {
        std::cout << "FLAG_C is set" << std::endl;
    }
    
    // 乘除 2 的幂
    int x = 10;
    std::cout << "x * 2 = " << (x << 1) << std::endl;  // 20
    std::cout << "x * 4 = " << (x << 2) << std::endl;  // 40
    std::cout << "x / 2 = " << (x >> 1) << std::endl;  // 5
    
    // 交换两个数 (不用临时变量)
    int a = 5, b = 3;
    a ^= b;
    b ^= a;
    a ^= b;
    std::cout << "a = " << a << ", b = " << b << std::endl;  // a = 3, b = 5
    
    return 0;
}
```

### 4.3 位操作技巧

```cpp
#include <iostream>
#include <bitset>

int main() {
    unsigned int n = 0b10110100;
    
    // 获取最低位的 1
    unsigned int lowestBit = n & (-n);
    std::cout << "Lowest bit: " << std::bitset<8>(lowestBit) << std::endl;
    
    // 清除最低位的 1
    unsigned int clearLowest = n & (n - 1);
    std::cout << "Clear lowest: " << std::bitset<8>(clearLowest) << std::endl;
    
    // 判断是否为 2 的幂
    unsigned int x = 16;
    bool isPowerOf2 = (x != 0) && ((x & (x - 1)) == 0);
    std::cout << x << " is power of 2: " << std::boolalpha << isPowerOf2 << std::endl;
    
    // 计算 1 的个数 (popcount)
    int count = 0;
    unsigned int temp = n;
    while (temp) {
        count++;
        temp &= (temp - 1);
    }
    std::cout << "Number of 1s: " << count << std::endl;
    
    // C++20 提供 std::popcount
    // std::cout << "popcount: " << std::popcount(n) << std::endl;
    
    return 0;
}
```

---

## 5. 赋值运算符

### 5.1 基本赋值

```cpp
#include <iostream>

int main() {
    int a, b, c;
    
    // 基本赋值
    a = 10;
    
    // 链式赋值
    a = b = c = 5;
    std::cout << "a = " << a << ", b = " << b << ", c = " << c << std::endl;
    
    // 赋值表达式的值
    int x;
    std::cout << "x = 10 的值: " << (x = 10) << std::endl;
    
    return 0;
}
```

### 5.2 复合赋值

```cpp
#include <iostream>

int main() {
    int a = 10;
    
    // 算术复合赋值
    a += 5;   // a = a + 5
    std::cout << "a += 5: " << a << std::endl;  // 15
    
    a -= 3;   // a = a - 3
    std::cout << "a -= 3: " << a << std::endl;  // 12
    
    a *= 2;   // a = a * 2
    std::cout << "a *= 2: " << a << std::endl;  // 24
    
    a /= 4;   // a = a / 4
    std::cout << "a /= 4: " << a << std::endl;  // 6
    
    a %= 4;   // a = a % 4
    std::cout << "a %= 4: " << a << std::endl;  // 2
    
    // 位运算复合赋值
    unsigned int b = 0b1010;
    
    b &= 0b1100;  // b = b & 0b1100
    std::cout << "b &= 0b1100: " << std::bitset<4>(b) << std::endl;  // 1000
    
    b |= 0b0011;  // b = b | 0b0011
    std::cout << "b |= 0b0011: " << std::bitset<4>(b) << std::endl;  // 1011
    
    b ^= 0b0101;  // b = b ^ 0b0101
    std::cout << "b ^= 0b0101: " << std::bitset<4>(b) << std::endl;  // 1110
    
    b <<= 1;      // b = b << 1
    std::cout << "b <<= 1: " << std::bitset<8>(b) << std::endl;  // 11100
    
    b >>= 2;      // b = b >> 2
    std::cout << "b >>= 2: " << std::bitset<8>(b) << std::endl;  // 00111
    
    return 0;
}
```

---

## 6. 其他运算符

### 6.1 条件运算符 (三元运算符)

```cpp
#include <iostream>
#include <string>

int main() {
    int a = 10, b = 20;
    
    // 基本用法
    int max = (a > b) ? a : b;
    std::cout << "max = " << max << std::endl;  // 20
    
    // 嵌套三元运算符
    int x = 5;
    std::string result = (x > 0) ? "positive" : (x < 0) ? "negative" : "zero";
    std::cout << "x is " << result << std::endl;
    
    // 作为左值 (C++)
    int c = 1, d = 2;
    ((c > d) ? c : d) = 100;  // 将 100 赋给较大的那个
    std::cout << "c = " << c << ", d = " << d << std::endl;  // c = 1, d = 100
    
    return 0;
}
```

### 6.2 逗号运算符

```cpp
#include <iostream>

int main() {
    // 逗号运算符: 从左到右求值,返回最右边的值
    int a = (1, 2, 3);
    std::cout << "a = " << a << std::endl;  // 3
    
    // 常用于 for 循环
    for (int i = 0, j = 10; i < j; ++i, --j) {
        std::cout << "i = " << i << ", j = " << j << std::endl;
    }
    
    // 注意: 函数参数中的逗号不是逗号运算符
    // func(a, b);  // 这里的逗号是参数分隔符
    
    return 0;
}
```

### 6.3 sizeof 运算符

```cpp
#include <iostream>

int main() {
    // 基本类型大小
    std::cout << "sizeof(char) = " << sizeof(char) << std::endl;
    std::cout << "sizeof(int) = " << sizeof(int) << std::endl;
    std::cout << "sizeof(double) = " << sizeof(double) << std::endl;
    
    // 变量大小
    int x = 10;
    std::cout << "sizeof(x) = " << sizeof(x) << std::endl;
    std::cout << "sizeof x = " << sizeof x << std::endl;  // 变量可以不加括号
    
    // 数组大小
    int arr[10];
    std::cout << "sizeof(arr) = " << sizeof(arr) << std::endl;  // 40
    std::cout << "数组元素个数 = " << sizeof(arr) / sizeof(arr[0]) << std::endl;  // 10
    
    // 指针大小
    int* ptr = arr;
    std::cout << "sizeof(ptr) = " << sizeof(ptr) << std::endl;  // 8 (64位系统)
    
    // 结构体大小 (包含对齐)
    struct S {
        char c;
        int i;
        char c2;
    };
    std::cout << "sizeof(S) = " << sizeof(S) << std::endl;  // 12 (对齐)
    
    return 0;
}
```

### 6.4 类型转换运算符

```cpp
#include <iostream>

int main() {
    double d = 3.14;
    
    // C 风格转换
    int i1 = (int)d;
    int i2 = int(d);
    
    // C++ 风格转换
    int i3 = static_cast<int>(d);
    
    std::cout << "i1 = " << i1 << std::endl;
    std::cout << "i2 = " << i2 << std::endl;
    std::cout << "i3 = " << i3 << std::endl;
    
    return 0;
}
```

### 6.5 成员访问运算符

```cpp
#include <iostream>

struct Point {
    int x;
    int y;
};

int main() {
    // 点运算符
    Point p1;
    p1.x = 10;
    p1.y = 20;
    std::cout << "p1: (" << p1.x << ", " << p1.y << ")" << std::endl;
    
    // 箭头运算符
    Point* ptr = &p1;
    ptr->x = 30;
    ptr->y = 40;
    std::cout << "p1: (" << ptr->x << ", " << ptr->y << ")" << std::endl;
    
    // ptr->x 等价于 (*ptr).x
    std::cout << "(*ptr).x = " << (*ptr).x << std::endl;
    
    return 0;
}
```

### 6.6 作用域解析运算符

```cpp
#include <iostream>

int value = 100;  // 全局变量

namespace MyNamespace {
    int value = 200;
}

class MyClass {
public:
    static int value;
    void print() {
        int value = 400;
        std::cout << "局部 value: " << value << std::endl;
        std::cout << "全局 value: " << ::value << std::endl;
        std::cout << "命名空间 value: " << MyNamespace::value << std::endl;
        std::cout << "类静态 value: " << MyClass::value << std::endl;
    }
};

int MyClass::value = 300;

int main() {
    MyClass obj;
    obj.print();
    
    return 0;
}
```

---

## 7. 运算符优先级

### 7.1 优先级表

```
运算符优先级 (从高到低):

优先级  运算符                    结合性
───────────────────────────────────────────
1       ::                        左到右
2       () [] -> . ++ --          左到右
3       ! ~ ++ -- + - * & sizeof  右到左
4       .* ->*                    左到右
5       * / %                     左到右
6       + -                       左到右
7       << >>                     左到右
8       < <= > >=                 左到右
9       == !=                     左到右
10      &                         左到右
11      ^                         左到右
12      |                         左到右
13      &&                        左到右
14      ||                        左到右
15      ?:                        右到左
16      = += -= *= /= %= etc.     右到左
17      ,                         左到右
```

### 7.2 优先级示例

```cpp
#include <iostream>

int main() {
    int a = 2, b = 3, c = 4;
    
    // 算术优先级: * / % 高于 + -
    int r1 = a + b * c;  // 2 + (3 * 4) = 14
    std::cout << "a + b * c = " << r1 << std::endl;
    
    // 关系优先级: < > <= >= 高于 == !=
    bool r2 = a < b == c > b;  // (a < b) == (c > b) = true == true = true
    std::cout << "a < b == c > b: " << std::boolalpha << r2 << std::endl;
    
    // 位运算优先级: & 高于 ^ 高于 |
    int r3 = 0b1010 | 0b1100 & 0b0110;  // 0b1010 | (0b1100 & 0b0110)
    std::cout << "0b1010 | 0b1100 & 0b0110 = " << std::bitset<4>(r3) << std::endl;
    
    // 逻辑优先级: && 高于 ||
    bool r4 = true || false && false;  // true || (false && false) = true
    std::cout << "true || false && false: " << r4 << std::endl;
    
    // 赋值优先级最低
    int x = 1, y = 2;
    int r5 = x = y = 10;  // x = (y = 10) = 10
    std::cout << "x = " << x << ", y = " << y << std::endl;
    
    return 0;
}
```

### 7.3 使用括号明确优先级

```cpp
#include <iostream>

int main() {
    int a = 2, b = 3, c = 4;
    
    // 不清晰
    int r1 = a + b * c / a - c;
    
    // 清晰
    int r2 = a + ((b * c) / a) - c;
    
    // 位运算与比较混用时特别注意
    int x = 5;
    // 错误: & 优先级低于 ==
    // if (x & 1 == 1) { }  // 实际是 x & (1 == 1) = x & 1
    
    // 正确
    if ((x & 1) == 1) {
        std::cout << "x is odd" << std::endl;
    }
    
    return 0;
}
```

---

## 8. 总结

### 8.1 运算符分类

| 类别 | 运算符 |
|------|--------|
| 算术 | + - * / % ++ -- |
| 关系 | == != < > <= >= <=> |
| 逻辑 | && \|\| ! |
| 位运算 | & \| ^ ~ << >> |
| 赋值 | = += -= *= /= %= &= \|= ^= <<= >>= |
| 其他 | ?: , sizeof :: . -> |

### 8.2 最佳实践

```
1. 使用括号明确优先级
2. 避免在同一表达式中多次修改同一变量
3. 注意整数溢出和除零
4. 浮点数比较使用 epsilon
5. 位运算注意有符号数的行为
6. 利用短路求值进行安全检查
```

### 8.3 下一篇预告

在下一篇文章中,我们将学习 C++ 的控制流语句。

---

## 参考资料

1. [C++ Operators](https://en.cppreference.com/w/cpp/language/operator_precedence)
2. [Operator Precedence](https://en.cppreference.com/w/cpp/language/operator_precedence)

---

> 作者: C++ 技术专栏  
> 系列: C++ 基础入门 (4/8)  
> 上一篇: [变量与数据类型](./03-variables-types.md)  
> 下一篇: [控制流语句](./05-control-flow.md)
