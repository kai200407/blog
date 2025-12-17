---
title: "运算符重载"
description: "1. [运算符重载基础](#1-运算符重载基础)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 14
---

> 本文是 C++ 从入门到精通系列的第十四篇,将深入讲解 C++ 的运算符重载机制。

---

## 目录

1. [运算符重载基础](#1-运算符重载基础)
2. [算术运算符](#2-算术运算符)
3. [比较运算符](#3-比较运算符)
4. [赋值运算符](#4-赋值运算符)
5. [下标与函数调用运算符](#5-下标与函数调用运算符)
6. [流运算符](#6-流运算符)
7. [类型转换运算符](#7-类型转换运算符)
8. [总结](#8-总结)

---

## 1. 运算符重载基础

### 1.1 运算符重载概念

```cpp
#include <iostream>

class Complex {
public:
    double real, imag;
    
    Complex(double r = 0, double i = 0) : real(r), imag(i) { }
    
    // 成员函数形式的运算符重载
    Complex operator+(const Complex& other) const {
        return Complex(real + other.real, imag + other.imag);
    }
    
    void print() const {
        std::cout << real << " + " << imag << "i" << std::endl;
    }
};

int main() {
    Complex c1(1, 2);
    Complex c2(3, 4);
    
    Complex c3 = c1 + c2;  // 调用 operator+
    c3.print();  // 4 + 6i
    
    return 0;
}
```

### 1.2 可重载的运算符

```
可重载的运算符:

算术: + - * / % ++ --
关系: == != < > <= >= <=>
逻辑: && || !
位运算: & | ^ ~ << >>
赋值: = += -= *= /= %= &= |= ^= <<= >>=
其他: [] () -> ->* , new delete new[] delete[]

不可重载的运算符:
:: . .* ?: sizeof typeid
```

### 1.3 重载规则

```cpp
/*
运算符重载规则:

1. 不能创建新运算符
2. 不能改变运算符的优先级和结合性
3. 不能改变运算符的操作数个数
4. 至少有一个操作数是用户定义类型
5. 某些运算符只能作为成员函数重载 (= [] () ->)
*/

// 成员函数 vs 友元函数
class MyClass {
public:
    int value;
    
    // 成员函数: 左操作数是 this
    MyClass operator+(const MyClass& other) const {
        return MyClass{value + other.value};
    }
    
    // 友元函数: 两个操作数都是参数
    friend MyClass operator-(const MyClass& a, const MyClass& b);
};

MyClass operator-(const MyClass& a, const MyClass& b) {
    return MyClass{a.value - b.value};
}
```

---

## 2. 算术运算符

### 2.1 二元算术运算符

```cpp
#include <iostream>

class Vector2D {
public:
    double x, y;
    
    Vector2D(double x = 0, double y = 0) : x(x), y(y) { }
    
    // 加法
    Vector2D operator+(const Vector2D& other) const {
        return Vector2D(x + other.x, y + other.y);
    }
    
    // 减法
    Vector2D operator-(const Vector2D& other) const {
        return Vector2D(x - other.x, y - other.y);
    }
    
    // 标量乘法 (成员函数)
    Vector2D operator*(double scalar) const {
        return Vector2D(x * scalar, y * scalar);
    }
    
    // 标量除法
    Vector2D operator/(double scalar) const {
        return Vector2D(x / scalar, y / scalar);
    }
    
    // 点积
    double operator*(const Vector2D& other) const {
        return x * other.x + y * other.y;
    }
    
    void print() const {
        std::cout << "(" << x << ", " << y << ")" << std::endl;
    }
};

// 标量乘法 (友元函数,支持 scalar * vector)
Vector2D operator*(double scalar, const Vector2D& v) {
    return v * scalar;
}

int main() {
    Vector2D v1(1, 2);
    Vector2D v2(3, 4);
    
    (v1 + v2).print();   // (4, 6)
    (v1 - v2).print();   // (-2, -2)
    (v1 * 2).print();    // (2, 4)
    (2 * v1).print();    // (2, 4)
    std::cout << "Dot: " << (v1 * v2) << std::endl;  // 11
    
    return 0;
}
```

### 2.2 一元运算符

```cpp
#include <iostream>

class Integer {
public:
    int value;
    
    Integer(int v = 0) : value(v) { }
    
    // 一元正号
    Integer operator+() const {
        return *this;
    }
    
    // 一元负号
    Integer operator-() const {
        return Integer(-value);
    }
    
    // 前置递增
    Integer& operator++() {
        ++value;
        return *this;
    }
    
    // 后置递增 (int 参数用于区分)
    Integer operator++(int) {
        Integer temp = *this;
        ++value;
        return temp;
    }
    
    // 前置递减
    Integer& operator--() {
        --value;
        return *this;
    }
    
    // 后置递减
    Integer operator--(int) {
        Integer temp = *this;
        --value;
        return temp;
    }
    
    void print() const {
        std::cout << value << std::endl;
    }
};

int main() {
    Integer i(5);
    
    (-i).print();    // -5
    (++i).print();   // 6
    (i++).print();   // 6
    i.print();       // 7
    
    return 0;
}
```

### 2.3 复合赋值运算符

```cpp
#include <iostream>

class Counter {
public:
    int value;
    
    Counter(int v = 0) : value(v) { }
    
    // += 运算符
    Counter& operator+=(const Counter& other) {
        value += other.value;
        return *this;
    }
    
    Counter& operator+=(int n) {
        value += n;
        return *this;
    }
    
    // -= 运算符
    Counter& operator-=(const Counter& other) {
        value -= other.value;
        return *this;
    }
    
    // *= 运算符
    Counter& operator*=(int n) {
        value *= n;
        return *this;
    }
    
    // 基于复合赋值实现二元运算符
    Counter operator+(const Counter& other) const {
        Counter result = *this;
        result += other;
        return result;
    }
};

int main() {
    Counter c1(10);
    Counter c2(5);
    
    c1 += c2;
    std::cout << "c1 += c2: " << c1.value << std::endl;  // 15
    
    c1 += 3;
    std::cout << "c1 += 3: " << c1.value << std::endl;   // 18
    
    c1 *= 2;
    std::cout << "c1 *= 2: " << c1.value << std::endl;   // 36
    
    return 0;
}
```

---

## 3. 比较运算符

### 3.1 关系运算符

```cpp
#include <iostream>
#include <string>

class Person {
public:
    std::string name;
    int age;
    
    Person(const std::string& n, int a) : name(n), age(a) { }
    
    // 相等
    bool operator==(const Person& other) const {
        return name == other.name && age == other.age;
    }
    
    // 不相等
    bool operator!=(const Person& other) const {
        return !(*this == other);
    }
    
    // 小于 (按年龄比较)
    bool operator<(const Person& other) const {
        return age < other.age;
    }
    
    // 大于
    bool operator>(const Person& other) const {
        return other < *this;
    }
    
    // 小于等于
    bool operator<=(const Person& other) const {
        return !(other < *this);
    }
    
    // 大于等于
    bool operator>=(const Person& other) const {
        return !(*this < other);
    }
};

int main() {
    Person p1("Alice", 25);
    Person p2("Bob", 30);
    Person p3("Alice", 25);
    
    std::cout << std::boolalpha;
    std::cout << "p1 == p3: " << (p1 == p3) << std::endl;  // true
    std::cout << "p1 != p2: " << (p1 != p2) << std::endl;  // true
    std::cout << "p1 < p2: " << (p1 < p2) << std::endl;    // true
    
    return 0;
}
```

### 3.2 三路比较运算符 (C++20)

```cpp
#include <iostream>
#include <compare>
#include <string>

class Version {
public:
    int major, minor, patch;
    
    Version(int ma, int mi, int pa) : major(ma), minor(mi), patch(pa) { }
    
    // 三路比较运算符
    auto operator<=>(const Version& other) const {
        if (auto cmp = major <=> other.major; cmp != 0) return cmp;
        if (auto cmp = minor <=> other.minor; cmp != 0) return cmp;
        return patch <=> other.patch;
    }
    
    // 相等运算符 (需要单独定义)
    bool operator==(const Version& other) const = default;
};

int main() {
    Version v1(1, 2, 3);
    Version v2(1, 2, 4);
    Version v3(1, 2, 3);
    
    std::cout << std::boolalpha;
    std::cout << "v1 < v2: " << (v1 < v2) << std::endl;   // true
    std::cout << "v1 == v3: " << (v1 == v3) << std::endl; // true
    std::cout << "v2 > v1: " << (v2 > v1) << std::endl;   // true
    
    return 0;
}
```

---

## 4. 赋值运算符

### 4.1 拷贝赋值运算符

```cpp
#include <iostream>
#include <cstring>

class String {
public:
    char* data;
    size_t length;
    
    String(const char* str = "") {
        length = strlen(str);
        data = new char[length + 1];
        strcpy(data, str);
    }
    
    // 拷贝构造函数
    String(const String& other) {
        length = other.length;
        data = new char[length + 1];
        strcpy(data, other.data);
    }
    
    // 拷贝赋值运算符
    String& operator=(const String& other) {
        if (this != &other) {  // 检查自赋值
            delete[] data;
            length = other.length;
            data = new char[length + 1];
            strcpy(data, other.data);
        }
        return *this;
    }
    
    ~String() {
        delete[] data;
    }
    
    void print() const {
        std::cout << data << std::endl;
    }
};

int main() {
    String s1("Hello");
    String s2("World");
    
    s1.print();  // Hello
    s2.print();  // World
    
    s1 = s2;     // 拷贝赋值
    s1.print();  // World
    
    s1 = s1;     // 自赋值 (安全)
    s1.print();  // World
    
    return 0;
}
```

### 4.2 移动赋值运算符

```cpp
#include <iostream>
#include <cstring>
#include <utility>

class String {
public:
    char* data;
    size_t length;
    
    String(const char* str = "") {
        length = strlen(str);
        data = new char[length + 1];
        strcpy(data, str);
    }
    
    // 拷贝构造函数
    String(const String& other) {
        length = other.length;
        data = new char[length + 1];
        strcpy(data, other.data);
        std::cout << "Copy constructor" << std::endl;
    }
    
    // 移动构造函数
    String(String&& other) noexcept {
        data = other.data;
        length = other.length;
        other.data = nullptr;
        other.length = 0;
        std::cout << "Move constructor" << std::endl;
    }
    
    // 拷贝赋值运算符
    String& operator=(const String& other) {
        if (this != &other) {
            delete[] data;
            length = other.length;
            data = new char[length + 1];
            strcpy(data, other.data);
        }
        std::cout << "Copy assignment" << std::endl;
        return *this;
    }
    
    // 移动赋值运算符
    String& operator=(String&& other) noexcept {
        if (this != &other) {
            delete[] data;
            data = other.data;
            length = other.length;
            other.data = nullptr;
            other.length = 0;
        }
        std::cout << "Move assignment" << std::endl;
        return *this;
    }
    
    ~String() {
        delete[] data;
    }
};

int main() {
    String s1("Hello");
    String s2("World");
    
    s1 = s2;              // Copy assignment
    s1 = std::move(s2);   // Move assignment
    
    return 0;
}
```

---

## 5. 下标与函数调用运算符

### 5.1 下标运算符

```cpp
#include <iostream>
#include <stdexcept>

class Array {
public:
    int* data;
    size_t size;
    
    Array(size_t n) : size(n), data(new int[n]()) { }
    
    ~Array() { delete[] data; }
    
    // 非 const 版本 (可修改)
    int& operator[](size_t index) {
        if (index >= size) {
            throw std::out_of_range("Index out of range");
        }
        return data[index];
    }
    
    // const 版本 (只读)
    const int& operator[](size_t index) const {
        if (index >= size) {
            throw std::out_of_range("Index out of range");
        }
        return data[index];
    }
    
    size_t getSize() const { return size; }
};

int main() {
    Array arr(5);
    
    // 写入
    for (size_t i = 0; i < arr.getSize(); ++i) {
        arr[i] = i * 10;
    }
    
    // 读取
    for (size_t i = 0; i < arr.getSize(); ++i) {
        std::cout << arr[i] << " ";
    }
    std::cout << std::endl;
    
    // const 对象
    const Array& constArr = arr;
    std::cout << constArr[2] << std::endl;
    // constArr[2] = 100;  // 错误: const 版本返回 const 引用
    
    return 0;
}
```

### 5.2 函数调用运算符

```cpp
#include <iostream>
#include <vector>
#include <algorithm>

// 函数对象 (仿函数)
class Adder {
public:
    int value;
    
    Adder(int v) : value(v) { }
    
    int operator()(int x) const {
        return x + value;
    }
};

class Multiplier {
public:
    int operator()(int a, int b) const {
        return a * b;
    }
};

// 用于排序的比较器
class DescendingCompare {
public:
    bool operator()(int a, int b) const {
        return a > b;
    }
};

int main() {
    Adder add5(5);
    std::cout << "add5(10) = " << add5(10) << std::endl;  // 15
    
    Multiplier mult;
    std::cout << "mult(3, 4) = " << mult(3, 4) << std::endl;  // 12
    
    // 用于 STL 算法
    std::vector<int> vec = {3, 1, 4, 1, 5, 9, 2, 6};
    
    // 使用函数对象排序
    std::sort(vec.begin(), vec.end(), DescendingCompare());
    
    for (int x : vec) {
        std::cout << x << " ";
    }
    std::cout << std::endl;  // 9 6 5 4 3 2 1 1
    
    return 0;
}
```

---

## 6. 流运算符

### 6.1 输出运算符

```cpp
#include <iostream>
#include <string>

class Person {
public:
    std::string name;
    int age;
    
    Person(const std::string& n, int a) : name(n), age(a) { }
    
    // 友元函数重载 <<
    friend std::ostream& operator<<(std::ostream& os, const Person& p);
};

std::ostream& operator<<(std::ostream& os, const Person& p) {
    os << "Person{name=" << p.name << ", age=" << p.age << "}";
    return os;
}

int main() {
    Person p("Alice", 25);
    
    std::cout << p << std::endl;
    std::cout << "Person: " << p << ", done" << std::endl;
    
    return 0;
}
```

### 6.2 输入运算符

```cpp
#include <iostream>
#include <string>

class Point {
public:
    double x, y;
    
    Point(double x = 0, double y = 0) : x(x), y(y) { }
    
    // 输出运算符
    friend std::ostream& operator<<(std::ostream& os, const Point& p) {
        os << "(" << p.x << ", " << p.y << ")";
        return os;
    }
    
    // 输入运算符
    friend std::istream& operator>>(std::istream& is, Point& p) {
        is >> p.x >> p.y;
        if (!is) {
            p = Point();  // 输入失败时重置
        }
        return is;
    }
};

int main() {
    Point p;
    
    std::cout << "Enter x and y: ";
    std::cin >> p;
    
    std::cout << "Point: " << p << std::endl;
    
    return 0;
}
```

---

## 7. 类型转换运算符

### 7.1 转换运算符

```cpp
#include <iostream>
#include <string>

class Fraction {
public:
    int numerator, denominator;
    
    Fraction(int n, int d = 1) : numerator(n), denominator(d) { }
    
    // 转换为 double
    operator double() const {
        return static_cast<double>(numerator) / denominator;
    }
    
    // 转换为 bool
    explicit operator bool() const {
        return numerator != 0;
    }
    
    // 转换为 string
    explicit operator std::string() const {
        return std::to_string(numerator) + "/" + std::to_string(denominator);
    }
};

int main() {
    Fraction f(3, 4);
    
    // 隐式转换为 double
    double d = f;
    std::cout << "As double: " << d << std::endl;  // 0.75
    
    // explicit 转换需要显式调用
    if (f) {  // OK: 在条件中可以隐式转换
        std::cout << "Fraction is non-zero" << std::endl;
    }
    
    // bool b = f;  // 错误: explicit
    bool b = static_cast<bool>(f);  // OK
    
    std::string s = static_cast<std::string>(f);
    std::cout << "As string: " << s << std::endl;  // 3/4
    
    return 0;
}
```

### 7.2 转换构造函数

```cpp
#include <iostream>

class Meters {
public:
    double value;
    
    // 转换构造函数
    Meters(double v) : value(v) { }
    
    // 从 Feet 转换
    explicit Meters(class Feet f);
};

class Feet {
public:
    double value;
    
    Feet(double v) : value(v) { }
    
    // 转换为 Meters
    operator Meters() const {
        return Meters(value * 0.3048);
    }
};

Meters::Meters(Feet f) : value(f.value * 0.3048) { }

void printMeters(Meters m) {
    std::cout << m.value << " meters" << std::endl;
}

int main() {
    Feet f(10);
    
    // 使用转换运算符
    Meters m1 = f;  // 调用 Feet::operator Meters()
    printMeters(m1);
    
    // 使用转换构造函数
    Meters m2(f);   // 调用 Meters::Meters(Feet)
    printMeters(m2);
    
    return 0;
}
```

---

## 8. 总结

### 8.1 运算符重载方式

| 运算符 | 成员函数 | 友元函数 | 说明 |
|--------|---------|---------|------|
| = [] () -> | 必须 | 不可 | 只能作为成员 |
| += -= 等 | 推荐 | 可以 | 返回引用 |
| + - * / | 可以 | 推荐 | 支持交换律 |
| << >> | 不可 | 必须 | 左操作数是流 |
| == < 等 | 可以 | 可以 | 推荐友元 |

### 8.2 运算符重载检查清单

```
[ ] 保持运算符的直观含义
[ ] 提供完整的运算符集合
[ ] 使用 const 正确性
[ ] 处理自赋值
[ ] 返回正确的类型
[ ] 考虑使用 explicit
```

### 8.3 下一篇预告

在下一篇文章中,我们将学习友元与静态成员。

---

> 作者: C++ 技术专栏  
> 系列: 面向对象编程 (6/8)  
> 上一篇: [多态与虚函数](./13-polymorphism.md)  
> 下一篇: [友元与静态成员](./15-friend-static.md)
