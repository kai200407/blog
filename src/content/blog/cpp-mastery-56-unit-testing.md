---
title: "单元测试"
description: "1. [单元测试概述](#1-单元测试概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 56
---

> 本文是 C++ 从入门到精通系列的第五十六篇,将深入讲解 C++ 单元测试框架和测试驱动开发。

---

## 目录

1. [单元测试概述](#1-单元测试概述)
2. [Google Test](#2-google-test)
3. [Catch2](#3-catch2)
4. [Mock 和 Stub](#4-mock-和-stub)
5. [测试驱动开发](#5-测试驱动开发)
6. [总结](#6-总结)

---

## 1. 单元测试概述

### 1.1 什么是单元测试

```
单元测试:
- 测试最小可测试单元
- 通常是函数或类
- 自动化执行
- 快速反馈

好处:
- 早期发现 bug
- 重构保障
- 文档作用
- 设计改进
```

### 1.2 测试原则

```
FIRST 原则:

F - Fast (快速)
    测试应该快速执行

I - Independent (独立)
    测试之间不应相互依赖

R - Repeatable (可重复)
    每次运行结果一致

S - Self-validating (自验证)
    测试自动判断通过/失败

T - Timely (及时)
    在编写代码时编写测试
```

---

## 2. Google Test

### 2.1 基本使用

```cpp
#include <gtest/gtest.h>

// 被测函数
int add(int a, int b) {
    return a + b;
}

int factorial(int n) {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}

// 基本测试
TEST(AddTest, PositiveNumbers) {
    EXPECT_EQ(add(1, 2), 3);
    EXPECT_EQ(add(10, 20), 30);
}

TEST(AddTest, NegativeNumbers) {
    EXPECT_EQ(add(-1, -2), -3);
    EXPECT_EQ(add(-10, 5), -5);
}

TEST(AddTest, Zero) {
    EXPECT_EQ(add(0, 0), 0);
    EXPECT_EQ(add(5, 0), 5);
}

TEST(FactorialTest, HandlesZeroInput) {
    EXPECT_EQ(factorial(0), 1);
}

TEST(FactorialTest, HandlesPositiveInput) {
    EXPECT_EQ(factorial(1), 1);
    EXPECT_EQ(factorial(2), 2);
    EXPECT_EQ(factorial(3), 6);
    EXPECT_EQ(factorial(5), 120);
}

int main(int argc, char** argv) {
    testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}
```

### 2.2 断言

```cpp
#include <gtest/gtest.h>
#include <stdexcept>

TEST(AssertionTest, BasicAssertions) {
    // 布尔断言
    EXPECT_TRUE(true);
    EXPECT_FALSE(false);
    
    // 相等断言
    EXPECT_EQ(1, 1);
    EXPECT_NE(1, 2);
    
    // 比较断言
    EXPECT_LT(1, 2);  // <
    EXPECT_LE(1, 1);  // <=
    EXPECT_GT(2, 1);  // >
    EXPECT_GE(2, 2);  // >=
    
    // 字符串断言
    EXPECT_STREQ("hello", "hello");
    EXPECT_STRNE("hello", "world");
    EXPECT_STRCASEEQ("Hello", "hello");
    
    // 浮点数断言
    EXPECT_FLOAT_EQ(1.0f, 1.0f);
    EXPECT_DOUBLE_EQ(1.0, 1.0);
    EXPECT_NEAR(1.0, 1.001, 0.01);
}

TEST(AssertionTest, FatalAssertions) {
    // ASSERT_* 失败时停止当前测试
    ASSERT_TRUE(true);
    ASSERT_EQ(1, 1);
    
    // 后续代码不会执行如果上面失败
}

TEST(AssertionTest, ExceptionAssertions) {
    auto throwFunc = []() { throw std::runtime_error("error"); };
    auto noThrowFunc = []() { };
    
    EXPECT_THROW(throwFunc(), std::runtime_error);
    EXPECT_ANY_THROW(throwFunc());
    EXPECT_NO_THROW(noThrowFunc());
}

TEST(AssertionTest, PredicateAssertions) {
    auto isEven = [](int n) { return n % 2 == 0; };
    
    EXPECT_PRED1(isEven, 4);
    
    auto isBetween = [](int n, int low, int high) { 
        return n >= low && n <= high; 
    };
    
    EXPECT_PRED3(isBetween, 5, 1, 10);
}
```

### 2.3 测试夹具

```cpp
#include <gtest/gtest.h>
#include <vector>

class VectorTest : public ::testing::Test {
protected:
    void SetUp() override {
        // 每个测试前执行
        vec.push_back(1);
        vec.push_back(2);
        vec.push_back(3);
    }
    
    void TearDown() override {
        // 每个测试后执行
        vec.clear();
    }
    
    std::vector<int> vec;
};

TEST_F(VectorTest, Size) {
    EXPECT_EQ(vec.size(), 3);
}

TEST_F(VectorTest, PushBack) {
    vec.push_back(4);
    EXPECT_EQ(vec.size(), 4);
    EXPECT_EQ(vec.back(), 4);
}

TEST_F(VectorTest, PopBack) {
    vec.pop_back();
    EXPECT_EQ(vec.size(), 2);
}

// 共享夹具 (所有测试共享)
class SharedFixture : public ::testing::Test {
protected:
    static void SetUpTestSuite() {
        // 所有测试前执行一次
        sharedResource = new int(42);
    }
    
    static void TearDownTestSuite() {
        // 所有测试后执行一次
        delete sharedResource;
    }
    
    static int* sharedResource;
};

int* SharedFixture::sharedResource = nullptr;

TEST_F(SharedFixture, Test1) {
    EXPECT_EQ(*sharedResource, 42);
}

TEST_F(SharedFixture, Test2) {
    EXPECT_NE(sharedResource, nullptr);
}
```

### 2.4 参数化测试

```cpp
#include <gtest/gtest.h>
#include <tuple>

// 值参数化
class AddTest : public ::testing::TestWithParam<std::tuple<int, int, int>> {
};

TEST_P(AddTest, ReturnsCorrectSum) {
    auto [a, b, expected] = GetParam();
    EXPECT_EQ(add(a, b), expected);
}

INSTANTIATE_TEST_SUITE_P(
    AddTestCases,
    AddTest,
    ::testing::Values(
        std::make_tuple(1, 2, 3),
        std::make_tuple(0, 0, 0),
        std::make_tuple(-1, 1, 0),
        std::make_tuple(100, 200, 300)
    )
);

// 类型参数化
template<typename T>
class TypedTest : public ::testing::Test {
protected:
    T value;
};

using MyTypes = ::testing::Types<int, float, double>;
TYPED_TEST_SUITE(TypedTest, MyTypes);

TYPED_TEST(TypedTest, DefaultValue) {
    EXPECT_EQ(this->value, TypeParam{});
}

TYPED_TEST(TypedTest, Assignment) {
    this->value = TypeParam{42};
    EXPECT_EQ(this->value, TypeParam{42});
}
```

---

## 3. Catch2

### 3.1 基本使用

```cpp
#define CATCH_CONFIG_MAIN
#include <catch2/catch_test_macros.hpp>

int add(int a, int b) {
    return a + b;
}

TEST_CASE("Addition works correctly", "[add]") {
    REQUIRE(add(1, 2) == 3);
    REQUIRE(add(0, 0) == 0);
    REQUIRE(add(-1, 1) == 0);
}

TEST_CASE("Sections example", "[sections]") {
    std::vector<int> vec;
    
    REQUIRE(vec.empty());
    
    SECTION("Adding elements") {
        vec.push_back(1);
        REQUIRE(vec.size() == 1);
        
        SECTION("Adding more") {
            vec.push_back(2);
            REQUIRE(vec.size() == 2);
        }
        
        SECTION("Removing") {
            vec.pop_back();
            REQUIRE(vec.empty());
        }
    }
    
    SECTION("Reserving capacity") {
        vec.reserve(10);
        REQUIRE(vec.capacity() >= 10);
    }
}
```

### 3.2 断言和匹配器

```cpp
#include <catch2/catch_test_macros.hpp>
#include <catch2/matchers/catch_matchers_string.hpp>
#include <catch2/matchers/catch_matchers_vector.hpp>

TEST_CASE("Assertions", "[assertions]") {
    // 基本断言
    REQUIRE(1 == 1);
    CHECK(2 == 2);  // 失败后继续
    
    // 异常断言
    REQUIRE_THROWS(throw std::runtime_error("error"));
    REQUIRE_THROWS_AS(throw std::runtime_error("error"), std::runtime_error);
    REQUIRE_NOTHROW(1 + 1);
    
    // 浮点数
    REQUIRE(1.0 == Catch::Approx(1.0001).epsilon(0.01));
}

TEST_CASE("Matchers", "[matchers]") {
    using namespace Catch::Matchers;
    
    // 字符串匹配器
    std::string str = "Hello, World!";
    REQUIRE_THAT(str, StartsWith("Hello"));
    REQUIRE_THAT(str, EndsWith("World!"));
    REQUIRE_THAT(str, ContainsSubstring("llo"));
    
    // 向量匹配器
    std::vector<int> vec = {1, 2, 3, 4, 5};
    REQUIRE_THAT(vec, VectorContains(3));
    REQUIRE_THAT(vec, SizeIs(5));
}
```

### 3.3 BDD 风格

```cpp
#include <catch2/catch_test_macros.hpp>

class Stack {
public:
    void push(int value) { data.push_back(value); }
    int pop() { 
        int val = data.back(); 
        data.pop_back(); 
        return val; 
    }
    bool empty() const { return data.empty(); }
    size_t size() const { return data.size(); }
private:
    std::vector<int> data;
};

SCENARIO("Stack operations", "[stack]") {
    GIVEN("An empty stack") {
        Stack stack;
        
        THEN("It should be empty") {
            REQUIRE(stack.empty());
            REQUIRE(stack.size() == 0);
        }
        
        WHEN("An element is pushed") {
            stack.push(42);
            
            THEN("The stack is not empty") {
                REQUIRE_FALSE(stack.empty());
                REQUIRE(stack.size() == 1);
            }
            
            AND_WHEN("The element is popped") {
                int value = stack.pop();
                
                THEN("The value is correct") {
                    REQUIRE(value == 42);
                }
                
                AND_THEN("The stack is empty again") {
                    REQUIRE(stack.empty());
                }
            }
        }
    }
}
```

---

## 4. Mock 和 Stub

### 4.1 Google Mock

```cpp
#include <gmock/gmock.h>
#include <gtest/gtest.h>

// 接口
class Database {
public:
    virtual ~Database() = default;
    virtual bool connect(const std::string& host) = 0;
    virtual std::string query(const std::string& sql) = 0;
    virtual void disconnect() = 0;
};

// Mock 类
class MockDatabase : public Database {
public:
    MOCK_METHOD(bool, connect, (const std::string& host), (override));
    MOCK_METHOD(std::string, query, (const std::string& sql), (override));
    MOCK_METHOD(void, disconnect, (), (override));
};

// 被测类
class UserService {
public:
    UserService(Database& db) : db(db) {}
    
    std::string getUser(int id) {
        if (!db.connect("localhost")) {
            return "";
        }
        
        std::string result = db.query("SELECT * FROM users WHERE id = " + std::to_string(id));
        db.disconnect();
        
        return result;
    }
    
private:
    Database& db;
};

// 测试
TEST(UserServiceTest, GetUserSuccess) {
    MockDatabase mockDb;
    UserService service(mockDb);
    
    // 设置期望
    EXPECT_CALL(mockDb, connect("localhost"))
        .WillOnce(testing::Return(true));
    
    EXPECT_CALL(mockDb, query(testing::HasSubstr("SELECT")))
        .WillOnce(testing::Return("John Doe"));
    
    EXPECT_CALL(mockDb, disconnect())
        .Times(1);
    
    // 执行
    std::string result = service.getUser(1);
    
    // 验证
    EXPECT_EQ(result, "John Doe");
}

TEST(UserServiceTest, GetUserConnectionFailed) {
    MockDatabase mockDb;
    UserService service(mockDb);
    
    EXPECT_CALL(mockDb, connect("localhost"))
        .WillOnce(testing::Return(false));
    
    // query 和 disconnect 不应被调用
    EXPECT_CALL(mockDb, query(testing::_)).Times(0);
    EXPECT_CALL(mockDb, disconnect()).Times(0);
    
    std::string result = service.getUser(1);
    
    EXPECT_EQ(result, "");
}
```

### 4.2 高级 Mock 技术

```cpp
#include <gmock/gmock.h>
#include <gtest/gtest.h>

class Calculator {
public:
    virtual ~Calculator() = default;
    virtual int add(int a, int b) = 0;
    virtual int multiply(int a, int b) = 0;
};

class MockCalculator : public Calculator {
public:
    MOCK_METHOD(int, add, (int a, int b), (override));
    MOCK_METHOD(int, multiply, (int a, int b), (override));
};

TEST(MockTest, Actions) {
    MockCalculator calc;
    
    // 返回值
    ON_CALL(calc, add(testing::_, testing::_))
        .WillByDefault(testing::Return(0));
    
    // 多次调用返回不同值
    EXPECT_CALL(calc, add(1, 2))
        .WillOnce(testing::Return(3))
        .WillOnce(testing::Return(4))
        .WillRepeatedly(testing::Return(5));
    
    EXPECT_EQ(calc.add(1, 2), 3);
    EXPECT_EQ(calc.add(1, 2), 4);
    EXPECT_EQ(calc.add(1, 2), 5);
    EXPECT_EQ(calc.add(1, 2), 5);
}

TEST(MockTest, Matchers) {
    MockCalculator calc;
    
    // 参数匹配
    EXPECT_CALL(calc, add(testing::Gt(0), testing::Lt(10)))
        .WillOnce(testing::Return(100));
    
    EXPECT_CALL(calc, multiply(testing::_, testing::Eq(0)))
        .WillRepeatedly(testing::Return(0));
    
    EXPECT_EQ(calc.add(5, 5), 100);
    EXPECT_EQ(calc.multiply(100, 0), 0);
}

TEST(MockTest, Sequences) {
    MockCalculator calc;
    
    testing::InSequence seq;
    
    EXPECT_CALL(calc, add(1, 2)).WillOnce(testing::Return(3));
    EXPECT_CALL(calc, multiply(3, 4)).WillOnce(testing::Return(12));
    EXPECT_CALL(calc, add(12, 1)).WillOnce(testing::Return(13));
    
    // 必须按顺序调用
    EXPECT_EQ(calc.add(1, 2), 3);
    EXPECT_EQ(calc.multiply(3, 4), 12);
    EXPECT_EQ(calc.add(12, 1), 13);
}
```

---

## 5. 测试驱动开发

### 5.1 TDD 流程

```
TDD 循环:

1. Red (红)
   - 编写失败的测试
   - 测试应该失败

2. Green (绿)
   - 编写最少代码使测试通过
   - 不要过度设计

3. Refactor (重构)
   - 改进代码质量
   - 保持测试通过
```

### 5.2 TDD 示例

```cpp
// 步骤 1: 编写测试 (Red)
#include <gtest/gtest.h>

// 测试: 创建空购物车
TEST(ShoppingCartTest, NewCartIsEmpty) {
    ShoppingCart cart;
    EXPECT_EQ(cart.itemCount(), 0);
    EXPECT_DOUBLE_EQ(cart.total(), 0.0);
}

// 步骤 2: 实现代码 (Green)
class ShoppingCart {
public:
    int itemCount() const { return 0; }
    double total() const { return 0.0; }
};

// 步骤 3: 添加更多测试
TEST(ShoppingCartTest, AddItem) {
    ShoppingCart cart;
    cart.addItem("Apple", 1.50);
    
    EXPECT_EQ(cart.itemCount(), 1);
    EXPECT_DOUBLE_EQ(cart.total(), 1.50);
}

// 步骤 4: 实现功能
class ShoppingCart {
public:
    void addItem(const std::string& name, double price) {
        items.push_back({name, price});
    }
    
    int itemCount() const { return items.size(); }
    
    double total() const {
        double sum = 0;
        for (const auto& item : items) {
            sum += item.price;
        }
        return sum;
    }
    
private:
    struct Item {
        std::string name;
        double price;
    };
    std::vector<Item> items;
};

// 步骤 5: 继续添加测试和功能
TEST(ShoppingCartTest, AddMultipleItems) {
    ShoppingCart cart;
    cart.addItem("Apple", 1.50);
    cart.addItem("Banana", 0.75);
    cart.addItem("Orange", 2.00);
    
    EXPECT_EQ(cart.itemCount(), 3);
    EXPECT_DOUBLE_EQ(cart.total(), 4.25);
}

TEST(ShoppingCartTest, RemoveItem) {
    ShoppingCart cart;
    cart.addItem("Apple", 1.50);
    cart.addItem("Banana", 0.75);
    
    cart.removeItem("Apple");
    
    EXPECT_EQ(cart.itemCount(), 1);
    EXPECT_DOUBLE_EQ(cart.total(), 0.75);
}

TEST(ShoppingCartTest, ApplyDiscount) {
    ShoppingCart cart;
    cart.addItem("Apple", 10.00);
    
    cart.applyDiscount(0.1);  // 10% 折扣
    
    EXPECT_DOUBLE_EQ(cart.total(), 9.00);
}
```

### 5.3 测试覆盖率

```bash
# 编译带覆盖率信息
g++ -O0 -g --coverage -o test test.cpp -lgtest -lgtest_main

# 运行测试
./test

# 生成覆盖率报告
gcov test.cpp
lcov --capture --directory . --output-file coverage.info
genhtml coverage.info --output-directory coverage_report
```

---

## 6. 总结

### 6.1 测试框架对比

| 特性 | Google Test | Catch2 |
|------|-------------|--------|
| 头文件 | 需要编译 | 单头文件可选 |
| Mock | GMock | 无内置 |
| BDD | 不支持 | 支持 |
| 参数化 | 支持 | 支持 |

### 6.2 最佳实践

```
1. 测试命名清晰
2. 一个测试一个断言
3. 使用夹具减少重复
4. 测试边界条件
5. 保持测试独立
6. 定期运行测试
```

### 6.3 下一篇预告

在下一篇文章中,我们将学习代码规范与静态分析。

---

> 作者: C++ 技术专栏  
> 系列: 工程实践 (2/4)  
> 上一篇: [CMake 构建系统](./55-cmake.md)  
> 下一篇: [代码规范与静态分析](./57-code-style.md)
