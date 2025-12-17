---
title: "JSON 解析器"
description: "1. [项目概述](#1-项目概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 59
---

> 本文是 C++ 从入门到精通系列的第五十九篇,将实现一个完整的 JSON 解析器。

---

## 目录

1. [项目概述](#1-项目概述)
2. [JSON 数据结构](#2-json-数据结构)
3. [词法分析](#3-词法分析)
4. [语法分析](#4-语法分析)
5. [序列化](#5-序列化)
6. [总结](#6-总结)

---

## 1. 项目概述

### 1.1 JSON 格式

```
JSON (JavaScript Object Notation):
- 轻量级数据交换格式
- 人类可读
- 语言无关

数据类型:
- null
- boolean (true/false)
- number (整数/浮点数)
- string (双引号字符串)
- array (有序列表)
- object (键值对)
```

### 1.2 项目结构

```
json-parser/
├── include/
│   └── json/
│       ├── json.hpp
│       ├── value.hpp
│       ├── parser.hpp
│       └── serializer.hpp
├── src/
│   ├── value.cpp
│   ├── parser.cpp
│   └── serializer.cpp
├── tests/
│   └── test_json.cpp
└── CMakeLists.txt
```

---

## 2. JSON 数据结构

### 2.1 Value 类

```cpp
// include/json/value.hpp
#pragma once

#include <string>
#include <vector>
#include <map>
#include <variant>
#include <memory>
#include <stdexcept>

namespace json {

class Value;

using Null = std::nullptr_t;
using Bool = bool;
using Number = double;
using String = std::string;
using Array = std::vector<Value>;
using Object = std::map<std::string, Value>;

class Value {
public:
    enum class Type {
        Null,
        Bool,
        Number,
        String,
        Array,
        Object
    };
    
    // 构造函数
    Value() : data_(nullptr) { }
    Value(std::nullptr_t) : data_(nullptr) { }
    Value(bool b) : data_(b) { }
    Value(int n) : data_(static_cast<double>(n)) { }
    Value(double n) : data_(n) { }
    Value(const char* s) : data_(std::string(s)) { }
    Value(const std::string& s) : data_(s) { }
    Value(std::string&& s) : data_(std::move(s)) { }
    Value(const Array& arr) : data_(arr) { }
    Value(Array&& arr) : data_(std::move(arr)) { }
    Value(const Object& obj) : data_(obj) { }
    Value(Object&& obj) : data_(std::move(obj)) { }
    
    // 初始化列表
    Value(std::initializer_list<Value> init);
    
    // 类型查询
    Type type() const;
    bool isNull() const { return std::holds_alternative<Null>(data_); }
    bool isBool() const { return std::holds_alternative<Bool>(data_); }
    bool isNumber() const { return std::holds_alternative<Number>(data_); }
    bool isString() const { return std::holds_alternative<String>(data_); }
    bool isArray() const { return std::holds_alternative<Array>(data_); }
    bool isObject() const { return std::holds_alternative<Object>(data_); }
    
    // 值访问
    bool asBool() const;
    double asNumber() const;
    const std::string& asString() const;
    const Array& asArray() const;
    const Object& asObject() const;
    
    // 可修改访问
    Array& asArray();
    Object& asObject();
    
    // 数组操作
    Value& operator[](size_t index);
    const Value& operator[](size_t index) const;
    void push_back(const Value& value);
    size_t size() const;
    
    // 对象操作
    Value& operator[](const std::string& key);
    const Value& operator[](const std::string& key) const;
    bool contains(const std::string& key) const;
    
    // 比较
    bool operator==(const Value& other) const;
    bool operator!=(const Value& other) const { return !(*this == other); }

private:
    std::variant<Null, Bool, Number, String, Array, Object> data_;
};

// 异常
class JsonException : public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};

class TypeError : public JsonException {
public:
    TypeError(const std::string& msg) : JsonException("Type error: " + msg) { }
};

class ParseError : public JsonException {
public:
    ParseError(const std::string& msg, size_t line, size_t col)
        : JsonException("Parse error at line " + std::to_string(line) + 
                       ", column " + std::to_string(col) + ": " + msg)
        , line_(line), column_(col) { }
    
    size_t line() const { return line_; }
    size_t column() const { return column_; }

private:
    size_t line_;
    size_t column_;
};

} // namespace json
```

### 2.2 Value 实现

```cpp
// src/value.cpp
#include "json/value.hpp"

namespace json {

Value::Value(std::initializer_list<Value> init) {
    // 检查是否是对象 (所有元素都是两元素数组,第一个是字符串)
    bool isObject = true;
    for (const auto& elem : init) {
        if (!elem.isArray() || elem.size() != 2 || !elem[0].isString()) {
            isObject = false;
            break;
        }
    }
    
    if (isObject && init.size() > 0) {
        Object obj;
        for (const auto& elem : init) {
            obj[elem[0].asString()] = elem[1];
        }
        data_ = std::move(obj);
    } else {
        data_ = Array(init);
    }
}

Value::Type Value::type() const {
    return std::visit([](auto&& arg) -> Type {
        using T = std::decay_t<decltype(arg)>;
        if constexpr (std::is_same_v<T, Null>) return Type::Null;
        else if constexpr (std::is_same_v<T, Bool>) return Type::Bool;
        else if constexpr (std::is_same_v<T, Number>) return Type::Number;
        else if constexpr (std::is_same_v<T, String>) return Type::String;
        else if constexpr (std::is_same_v<T, Array>) return Type::Array;
        else if constexpr (std::is_same_v<T, Object>) return Type::Object;
    }, data_);
}

bool Value::asBool() const {
    if (!isBool()) throw TypeError("Expected bool");
    return std::get<Bool>(data_);
}

double Value::asNumber() const {
    if (!isNumber()) throw TypeError("Expected number");
    return std::get<Number>(data_);
}

const std::string& Value::asString() const {
    if (!isString()) throw TypeError("Expected string");
    return std::get<String>(data_);
}

const Array& Value::asArray() const {
    if (!isArray()) throw TypeError("Expected array");
    return std::get<Array>(data_);
}

const Object& Value::asObject() const {
    if (!isObject()) throw TypeError("Expected object");
    return std::get<Object>(data_);
}

Array& Value::asArray() {
    if (!isArray()) throw TypeError("Expected array");
    return std::get<Array>(data_);
}

Object& Value::asObject() {
    if (!isObject()) throw TypeError("Expected object");
    return std::get<Object>(data_);
}

Value& Value::operator[](size_t index) {
    return asArray().at(index);
}

const Value& Value::operator[](size_t index) const {
    return asArray().at(index);
}

void Value::push_back(const Value& value) {
    asArray().push_back(value);
}

size_t Value::size() const {
    if (isArray()) return asArray().size();
    if (isObject()) return asObject().size();
    throw TypeError("Expected array or object");
}

Value& Value::operator[](const std::string& key) {
    if (!isObject()) {
        data_ = Object();
    }
    return std::get<Object>(data_)[key];
}

const Value& Value::operator[](const std::string& key) const {
    return asObject().at(key);
}

bool Value::contains(const std::string& key) const {
    if (!isObject()) return false;
    return asObject().count(key) > 0;
}

bool Value::operator==(const Value& other) const {
    return data_ == other.data_;
}

} // namespace json
```

---

## 3. 词法分析

### 3.1 Token 定义

```cpp
// include/json/parser.hpp
#pragma once

#include "value.hpp"
#include <string_view>

namespace json {

enum class TokenType {
    LeftBrace,    // {
    RightBrace,   // }
    LeftBracket,  // [
    RightBracket, // ]
    Colon,        // :
    Comma,        // ,
    String,
    Number,
    True,
    False,
    Null,
    EndOfFile,
    Error
};

struct Token {
    TokenType type;
    std::string_view text;
    size_t line;
    size_t column;
};

class Lexer {
public:
    Lexer(std::string_view input);
    Token nextToken();
    Token peekToken();

private:
    void skipWhitespace();
    Token scanString();
    Token scanNumber();
    Token scanKeyword();
    Token makeToken(TokenType type);
    Token errorToken(const std::string& message);
    
    char current() const;
    char peek() const;
    char advance();
    bool isAtEnd() const;
    
    std::string_view input_;
    size_t pos_ = 0;
    size_t line_ = 1;
    size_t column_ = 1;
    size_t tokenStart_ = 0;
    Token peeked_;
    bool hasPeeked_ = false;
};

} // namespace json
```

### 3.2 Lexer 实现

```cpp
// src/parser.cpp (Lexer 部分)
#include "json/parser.hpp"
#include <cctype>

namespace json {

Lexer::Lexer(std::string_view input) : input_(input) { }

Token Lexer::nextToken() {
    if (hasPeeked_) {
        hasPeeked_ = false;
        return peeked_;
    }
    
    skipWhitespace();
    tokenStart_ = pos_;
    
    if (isAtEnd()) {
        return makeToken(TokenType::EndOfFile);
    }
    
    char c = advance();
    
    switch (c) {
        case '{': return makeToken(TokenType::LeftBrace);
        case '}': return makeToken(TokenType::RightBrace);
        case '[': return makeToken(TokenType::LeftBracket);
        case ']': return makeToken(TokenType::RightBracket);
        case ':': return makeToken(TokenType::Colon);
        case ',': return makeToken(TokenType::Comma);
        case '"': return scanString();
        case '-':
        case '0': case '1': case '2': case '3': case '4':
        case '5': case '6': case '7': case '8': case '9':
            return scanNumber();
        default:
            if (std::isalpha(c)) {
                return scanKeyword();
            }
            return errorToken("Unexpected character");
    }
}

Token Lexer::peekToken() {
    if (!hasPeeked_) {
        peeked_ = nextToken();
        hasPeeked_ = true;
    }
    return peeked_;
}

void Lexer::skipWhitespace() {
    while (!isAtEnd()) {
        char c = current();
        switch (c) {
            case ' ':
            case '\t':
            case '\r':
                advance();
                break;
            case '\n':
                line_++;
                column_ = 1;
                pos_++;
                break;
            default:
                return;
        }
    }
}

Token Lexer::scanString() {
    while (!isAtEnd() && current() != '"') {
        if (current() == '\\') {
            advance();  // 跳过转义字符
            if (!isAtEnd()) advance();
        } else if (current() == '\n') {
            return errorToken("Unterminated string");
        } else {
            advance();
        }
    }
    
    if (isAtEnd()) {
        return errorToken("Unterminated string");
    }
    
    advance();  // 跳过结束引号
    return makeToken(TokenType::String);
}

Token Lexer::scanNumber() {
    // 整数部分
    while (!isAtEnd() && std::isdigit(current())) {
        advance();
    }
    
    // 小数部分
    if (!isAtEnd() && current() == '.' && std::isdigit(peek())) {
        advance();  // 跳过 '.'
        while (!isAtEnd() && std::isdigit(current())) {
            advance();
        }
    }
    
    // 指数部分
    if (!isAtEnd() && (current() == 'e' || current() == 'E')) {
        advance();
        if (!isAtEnd() && (current() == '+' || current() == '-')) {
            advance();
        }
        while (!isAtEnd() && std::isdigit(current())) {
            advance();
        }
    }
    
    return makeToken(TokenType::Number);
}

Token Lexer::scanKeyword() {
    while (!isAtEnd() && std::isalpha(current())) {
        advance();
    }
    
    std::string_view text = input_.substr(tokenStart_, pos_ - tokenStart_);
    
    if (text == "true") return makeToken(TokenType::True);
    if (text == "false") return makeToken(TokenType::False);
    if (text == "null") return makeToken(TokenType::Null);
    
    return errorToken("Unknown keyword");
}

Token Lexer::makeToken(TokenType type) {
    Token token;
    token.type = type;
    token.text = input_.substr(tokenStart_, pos_ - tokenStart_);
    token.line = line_;
    token.column = column_ - (pos_ - tokenStart_);
    return token;
}

Token Lexer::errorToken(const std::string& message) {
    Token token;
    token.type = TokenType::Error;
    token.text = std::string_view(message);
    token.line = line_;
    token.column = column_;
    return token;
}

char Lexer::current() const {
    return input_[pos_];
}

char Lexer::peek() const {
    if (pos_ + 1 >= input_.size()) return '\0';
    return input_[pos_ + 1];
}

char Lexer::advance() {
    column_++;
    return input_[pos_++];
}

bool Lexer::isAtEnd() const {
    return pos_ >= input_.size();
}

} // namespace json
```

---

## 4. 语法分析

### 4.1 Parser 类

```cpp
// include/json/parser.hpp (添加)

class Parser {
public:
    Parser(std::string_view input);
    Value parse();

private:
    Value parseValue();
    Value parseObject();
    Value parseArray();
    Value parseString();
    Value parseNumber();
    
    std::string parseStringContent(std::string_view text);
    char parseEscapeSequence(char c);
    
    void expect(TokenType type, const std::string& message);
    void error(const std::string& message);
    
    Lexer lexer_;
    Token current_;
};

// 便捷函数
Value parse(std::string_view input);
Value parse(const std::string& input);

} // namespace json
```

### 4.2 Parser 实现

```cpp
// src/parser.cpp (Parser 部分)

Parser::Parser(std::string_view input) : lexer_(input) {
    current_ = lexer_.nextToken();
}

Value Parser::parse() {
    Value result = parseValue();
    
    if (current_.type != TokenType::EndOfFile) {
        error("Unexpected token after JSON value");
    }
    
    return result;
}

Value Parser::parseValue() {
    switch (current_.type) {
        case TokenType::LeftBrace:
            return parseObject();
        case TokenType::LeftBracket:
            return parseArray();
        case TokenType::String:
            return parseString();
        case TokenType::Number:
            return parseNumber();
        case TokenType::True:
            current_ = lexer_.nextToken();
            return Value(true);
        case TokenType::False:
            current_ = lexer_.nextToken();
            return Value(false);
        case TokenType::Null:
            current_ = lexer_.nextToken();
            return Value(nullptr);
        case TokenType::Error:
            error(std::string(current_.text));
        default:
            error("Unexpected token");
    }
    return Value();  // 不会到达
}

Value Parser::parseObject() {
    expect(TokenType::LeftBrace, "Expected '{'");
    
    Object obj;
    
    if (current_.type != TokenType::RightBrace) {
        do {
            if (current_.type != TokenType::String) {
                error("Expected string key");
            }
            std::string key = parseStringContent(current_.text);
            current_ = lexer_.nextToken();
            
            expect(TokenType::Colon, "Expected ':'");
            
            obj[key] = parseValue();
            
        } while (current_.type == TokenType::Comma && 
                 (current_ = lexer_.nextToken(), true));
    }
    
    expect(TokenType::RightBrace, "Expected '}'");
    
    return Value(std::move(obj));
}

Value Parser::parseArray() {
    expect(TokenType::LeftBracket, "Expected '['");
    
    Array arr;
    
    if (current_.type != TokenType::RightBracket) {
        do {
            arr.push_back(parseValue());
        } while (current_.type == TokenType::Comma && 
                 (current_ = lexer_.nextToken(), true));
    }
    
    expect(TokenType::RightBracket, "Expected ']'");
    
    return Value(std::move(arr));
}

Value Parser::parseString() {
    std::string str = parseStringContent(current_.text);
    current_ = lexer_.nextToken();
    return Value(std::move(str));
}

Value Parser::parseNumber() {
    double num = std::stod(std::string(current_.text));
    current_ = lexer_.nextToken();
    return Value(num);
}

std::string Parser::parseStringContent(std::string_view text) {
    // 去掉引号
    text = text.substr(1, text.size() - 2);
    
    std::string result;
    result.reserve(text.size());
    
    for (size_t i = 0; i < text.size(); ++i) {
        if (text[i] == '\\' && i + 1 < text.size()) {
            result += parseEscapeSequence(text[++i]);
        } else {
            result += text[i];
        }
    }
    
    return result;
}

char Parser::parseEscapeSequence(char c) {
    switch (c) {
        case '"': return '"';
        case '\\': return '\\';
        case '/': return '/';
        case 'b': return '\b';
        case 'f': return '\f';
        case 'n': return '\n';
        case 'r': return '\r';
        case 't': return '\t';
        default: return c;
    }
}

void Parser::expect(TokenType type, const std::string& message) {
    if (current_.type != type) {
        error(message);
    }
    current_ = lexer_.nextToken();
}

void Parser::error(const std::string& message) {
    throw ParseError(message, current_.line, current_.column);
}

Value parse(std::string_view input) {
    Parser parser(input);
    return parser.parse();
}

Value parse(const std::string& input) {
    return parse(std::string_view(input));
}

} // namespace json
```

---

## 5. 序列化

### 5.1 Serializer 类

```cpp
// include/json/serializer.hpp
#pragma once

#include "value.hpp"
#include <string>
#include <sstream>

namespace json {

struct SerializeOptions {
    bool pretty = false;
    int indent = 2;
};

class Serializer {
public:
    Serializer(const SerializeOptions& options = {});
    std::string serialize(const Value& value);

private:
    void serializeValue(const Value& value);
    void serializeObject(const Object& obj);
    void serializeArray(const Array& arr);
    void serializeString(const std::string& str);
    
    void newline();
    void indent();
    
    std::ostringstream output_;
    SerializeOptions options_;
    int depth_ = 0;
};

// 便捷函数
std::string stringify(const Value& value, bool pretty = false);

} // namespace json
```

### 5.2 Serializer 实现

```cpp
// src/serializer.cpp
#include "json/serializer.hpp"
#include <iomanip>

namespace json {

Serializer::Serializer(const SerializeOptions& options) 
    : options_(options) { }

std::string Serializer::serialize(const Value& value) {
    output_.str("");
    output_.clear();
    serializeValue(value);
    return output_.str();
}

void Serializer::serializeValue(const Value& value) {
    switch (value.type()) {
        case Value::Type::Null:
            output_ << "null";
            break;
        case Value::Type::Bool:
            output_ << (value.asBool() ? "true" : "false");
            break;
        case Value::Type::Number: {
            double num = value.asNumber();
            if (num == static_cast<int64_t>(num)) {
                output_ << static_cast<int64_t>(num);
            } else {
                output_ << std::setprecision(15) << num;
            }
            break;
        }
        case Value::Type::String:
            serializeString(value.asString());
            break;
        case Value::Type::Array:
            serializeArray(value.asArray());
            break;
        case Value::Type::Object:
            serializeObject(value.asObject());
            break;
    }
}

void Serializer::serializeObject(const Object& obj) {
    output_ << '{';
    
    if (obj.empty()) {
        output_ << '}';
        return;
    }
    
    depth_++;
    newline();
    
    bool first = true;
    for (const auto& [key, value] : obj) {
        if (!first) {
            output_ << ',';
            newline();
        }
        first = false;
        
        indent();
        serializeString(key);
        output_ << ':';
        if (options_.pretty) output_ << ' ';
        serializeValue(value);
    }
    
    depth_--;
    newline();
    indent();
    output_ << '}';
}

void Serializer::serializeArray(const Array& arr) {
    output_ << '[';
    
    if (arr.empty()) {
        output_ << ']';
        return;
    }
    
    depth_++;
    newline();
    
    bool first = true;
    for (const auto& value : arr) {
        if (!first) {
            output_ << ',';
            newline();
        }
        first = false;
        
        indent();
        serializeValue(value);
    }
    
    depth_--;
    newline();
    indent();
    output_ << ']';
}

void Serializer::serializeString(const std::string& str) {
    output_ << '"';
    
    for (char c : str) {
        switch (c) {
            case '"': output_ << "\\\""; break;
            case '\\': output_ << "\\\\"; break;
            case '\b': output_ << "\\b"; break;
            case '\f': output_ << "\\f"; break;
            case '\n': output_ << "\\n"; break;
            case '\r': output_ << "\\r"; break;
            case '\t': output_ << "\\t"; break;
            default:
                if (static_cast<unsigned char>(c) < 0x20) {
                    output_ << "\\u" << std::hex << std::setw(4) 
                            << std::setfill('0') << static_cast<int>(c);
                } else {
                    output_ << c;
                }
        }
    }
    
    output_ << '"';
}

void Serializer::newline() {
    if (options_.pretty) {
        output_ << '\n';
    }
}

void Serializer::indent() {
    if (options_.pretty) {
        output_ << std::string(depth_ * options_.indent, ' ');
    }
}

std::string stringify(const Value& value, bool pretty) {
    SerializeOptions options;
    options.pretty = pretty;
    Serializer serializer(options);
    return serializer.serialize(value);
}

} // namespace json
```

---

## 6. 总结

### 6.1 使用示例

```cpp
#include "json/json.hpp"
#include <iostream>

int main() {
    // 解析 JSON
    auto value = json::parse(R"({
        "name": "John",
        "age": 30,
        "active": true,
        "scores": [95, 87, 92],
        "address": {
            "city": "New York",
            "zip": "10001"
        }
    })");
    
    // 访问数据
    std::cout << "Name: " << value["name"].asString() << std::endl;
    std::cout << "Age: " << value["age"].asNumber() << std::endl;
    std::cout << "Active: " << value["active"].asBool() << std::endl;
    
    // 遍历数组
    for (const auto& score : value["scores"].asArray()) {
        std::cout << "Score: " << score.asNumber() << std::endl;
    }
    
    // 构建 JSON
    json::Value newValue;
    newValue["message"] = "Hello, JSON!";
    newValue["count"] = 42;
    newValue["items"] = json::Array{1, 2, 3};
    
    // 序列化
    std::cout << json::stringify(newValue, true) << std::endl;
    
    return 0;
}
```

### 6.2 项目特点

| 特性 | 说明 |
|------|------|
| 类型安全 | 使用 std::variant |
| 异常处理 | 详细错误信息 |
| 现代 C++ | C++17 特性 |
| 易于使用 | 直观的 API |

### 6.3 下一篇预告

在下一篇文章中,我们将实现一个 HTTP 框架。

---

> 作者: C++ 技术专栏  
> 系列: 项目实战 (1/4)  
> 上一篇: [设计模式](../part9-engineering/58-design-patterns.md)  
> 下一篇: [HTTP 框架](./60-http-framework.md)
