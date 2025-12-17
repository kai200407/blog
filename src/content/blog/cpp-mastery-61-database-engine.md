---
title: "数据库引擎"
description: "1. [数据库设计](#1-数据库设计)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 61
---

> 本文是 C++ 从入门到精通系列的第六十一篇,将实现一个简单的键值数据库引擎。

---

## 目录

1. [数据库设计](#1-数据库设计)
2. [存储引擎](#2-存储引擎)
3. [索引结构](#3-索引结构)
4. [事务支持](#4-事务支持)
5. [查询接口](#5-查询接口)
6. [总结](#6-总结)

---

## 1. 数据库设计

### 1.1 设计目标

```
设计目标:
- 持久化存储
- 高效读写
- 事务支持
- 崩溃恢复

核心组件:
- 存储引擎 (Storage Engine)
- 索引结构 (B+ Tree)
- 事务管理 (Transaction)
- 日志系统 (WAL)
```

### 1.2 项目结构

```
database-engine/
├── include/
│   └── db/
│       ├── db.hpp
│       ├── storage.hpp
│       ├── btree.hpp
│       ├── transaction.hpp
│       └── wal.hpp
├── src/
│   ├── storage.cpp
│   ├── btree.cpp
│   ├── transaction.cpp
│   └── wal.cpp
├── tests/
│   └── test_db.cpp
└── CMakeLists.txt
```

---

## 2. 存储引擎

### 2.1 页面管理

```cpp
// include/db/storage.hpp
#pragma once

#include <cstdint>
#include <string>
#include <vector>
#include <memory>
#include <fstream>
#include <unordered_map>
#include <mutex>

namespace db {

constexpr size_t PAGE_SIZE = 4096;
constexpr size_t MAX_KEY_SIZE = 256;
constexpr size_t MAX_VALUE_SIZE = 1024;

using PageId = uint32_t;

// 页面头部
struct PageHeader {
    PageId pageId;
    uint16_t numSlots;
    uint16_t freeSpace;
    uint32_t nextPage;
    uint32_t prevPage;
};

// 页面
class Page {
public:
    Page(PageId id = 0);
    
    PageId id() const { return header_.pageId; }
    
    // 槽操作
    bool insert(const std::string& key, const std::string& value);
    bool remove(const std::string& key);
    std::string get(const std::string& key) const;
    bool contains(const std::string& key) const;
    
    // 序列化
    void serialize(char* buffer) const;
    void deserialize(const char* buffer);
    
    // 迭代
    std::vector<std::pair<std::string, std::string>> entries() const;

private:
    PageHeader header_;
    std::vector<std::pair<std::string, std::string>> slots_;
};

// 缓冲池
class BufferPool {
public:
    BufferPool(const std::string& filename, size_t poolSize = 100);
    ~BufferPool();
    
    Page* fetchPage(PageId pageId);
    Page* newPage();
    void flushPage(PageId pageId);
    void flushAll();
    
    void deletePage(PageId pageId);

private:
    void evict();
    
    std::string filename_;
    std::fstream file_;
    size_t poolSize_;
    PageId nextPageId_;
    
    std::unordered_map<PageId, std::unique_ptr<Page>> pages_;
    std::vector<PageId> lruList_;
    std::mutex mutex_;
};

} // namespace db
```

### 2.2 存储实现

```cpp
// src/storage.cpp
#include "db/storage.hpp"
#include <algorithm>
#include <cstring>

namespace db {

Page::Page(PageId id) {
    header_.pageId = id;
    header_.numSlots = 0;
    header_.freeSpace = PAGE_SIZE - sizeof(PageHeader);
    header_.nextPage = 0;
    header_.prevPage = 0;
}

bool Page::insert(const std::string& key, const std::string& value) {
    size_t entrySize = key.size() + value.size() + 8;  // 长度字段
    
    if (entrySize > header_.freeSpace) {
        return false;
    }
    
    // 检查是否已存在
    for (auto& slot : slots_) {
        if (slot.first == key) {
            slot.second = value;
            return true;
        }
    }
    
    slots_.emplace_back(key, value);
    header_.numSlots++;
    header_.freeSpace -= entrySize;
    
    return true;
}

bool Page::remove(const std::string& key) {
    for (auto it = slots_.begin(); it != slots_.end(); ++it) {
        if (it->first == key) {
            size_t entrySize = it->first.size() + it->second.size() + 8;
            header_.freeSpace += entrySize;
            header_.numSlots--;
            slots_.erase(it);
            return true;
        }
    }
    return false;
}

std::string Page::get(const std::string& key) const {
    for (const auto& slot : slots_) {
        if (slot.first == key) {
            return slot.second;
        }
    }
    return "";
}

bool Page::contains(const std::string& key) const {
    for (const auto& slot : slots_) {
        if (slot.first == key) {
            return true;
        }
    }
    return false;
}

void Page::serialize(char* buffer) const {
    std::memcpy(buffer, &header_, sizeof(PageHeader));
    
    size_t offset = sizeof(PageHeader);
    for (const auto& [key, value] : slots_) {
        uint32_t keyLen = key.size();
        uint32_t valLen = value.size();
        
        std::memcpy(buffer + offset, &keyLen, 4);
        offset += 4;
        std::memcpy(buffer + offset, key.data(), keyLen);
        offset += keyLen;
        std::memcpy(buffer + offset, &valLen, 4);
        offset += 4;
        std::memcpy(buffer + offset, value.data(), valLen);
        offset += valLen;
    }
}

void Page::deserialize(const char* buffer) {
    std::memcpy(&header_, buffer, sizeof(PageHeader));
    
    slots_.clear();
    size_t offset = sizeof(PageHeader);
    
    for (uint16_t i = 0; i < header_.numSlots; ++i) {
        uint32_t keyLen, valLen;
        
        std::memcpy(&keyLen, buffer + offset, 4);
        offset += 4;
        std::string key(buffer + offset, keyLen);
        offset += keyLen;
        
        std::memcpy(&valLen, buffer + offset, 4);
        offset += 4;
        std::string value(buffer + offset, valLen);
        offset += valLen;
        
        slots_.emplace_back(std::move(key), std::move(value));
    }
}

std::vector<std::pair<std::string, std::string>> Page::entries() const {
    return slots_;
}

// BufferPool
BufferPool::BufferPool(const std::string& filename, size_t poolSize)
    : filename_(filename), poolSize_(poolSize), nextPageId_(0) {
    
    file_.open(filename, std::ios::in | std::ios::out | std::ios::binary);
    
    if (!file_.is_open()) {
        file_.open(filename, std::ios::out | std::ios::binary);
        file_.close();
        file_.open(filename, std::ios::in | std::ios::out | std::ios::binary);
    }
    
    // 获取文件大小确定下一个页面 ID
    file_.seekg(0, std::ios::end);
    nextPageId_ = file_.tellg() / PAGE_SIZE;
}

BufferPool::~BufferPool() {
    flushAll();
    file_.close();
}

Page* BufferPool::fetchPage(PageId pageId) {
    std::lock_guard<std::mutex> lock(mutex_);
    
    // 检查缓存
    auto it = pages_.find(pageId);
    if (it != pages_.end()) {
        // 更新 LRU
        lruList_.erase(std::remove(lruList_.begin(), lruList_.end(), pageId), 
                       lruList_.end());
        lruList_.push_back(pageId);
        return it->second.get();
    }
    
    // 从磁盘读取
    if (pages_.size() >= poolSize_) {
        evict();
    }
    
    auto page = std::make_unique<Page>(pageId);
    
    char buffer[PAGE_SIZE];
    file_.seekg(pageId * PAGE_SIZE);
    file_.read(buffer, PAGE_SIZE);
    
    if (file_.gcount() == PAGE_SIZE) {
        page->deserialize(buffer);
    }
    
    Page* ptr = page.get();
    pages_[pageId] = std::move(page);
    lruList_.push_back(pageId);
    
    return ptr;
}

Page* BufferPool::newPage() {
    std::lock_guard<std::mutex> lock(mutex_);
    
    if (pages_.size() >= poolSize_) {
        evict();
    }
    
    PageId pageId = nextPageId_++;
    auto page = std::make_unique<Page>(pageId);
    
    Page* ptr = page.get();
    pages_[pageId] = std::move(page);
    lruList_.push_back(pageId);
    
    return ptr;
}

void BufferPool::flushPage(PageId pageId) {
    auto it = pages_.find(pageId);
    if (it == pages_.end()) return;
    
    char buffer[PAGE_SIZE] = {0};
    it->second->serialize(buffer);
    
    file_.seekp(pageId * PAGE_SIZE);
    file_.write(buffer, PAGE_SIZE);
    file_.flush();
}

void BufferPool::flushAll() {
    for (const auto& [pageId, page] : pages_) {
        char buffer[PAGE_SIZE] = {0};
        page->serialize(buffer);
        
        file_.seekp(pageId * PAGE_SIZE);
        file_.write(buffer, PAGE_SIZE);
    }
    file_.flush();
}

void BufferPool::evict() {
    if (lruList_.empty()) return;
    
    PageId victimId = lruList_.front();
    lruList_.erase(lruList_.begin());
    
    flushPage(victimId);
    pages_.erase(victimId);
}

} // namespace db
```

---

## 3. 索引结构

### 3.1 B+ 树

```cpp
// include/db/btree.hpp
#pragma once

#include "storage.hpp"
#include <optional>

namespace db {

constexpr int BTREE_ORDER = 64;

class BTree {
public:
    BTree(BufferPool& bufferPool);
    
    void insert(const std::string& key, const std::string& value);
    std::optional<std::string> get(const std::string& key);
    bool remove(const std::string& key);
    bool contains(const std::string& key);
    
    // 范围查询
    std::vector<std::pair<std::string, std::string>> 
        range(const std::string& start, const std::string& end);
    
    // 遍历
    void forEach(std::function<void(const std::string&, const std::string&)> callback);

private:
    struct Node {
        bool isLeaf;
        std::vector<std::string> keys;
        std::vector<std::string> values;  // 叶子节点
        std::vector<PageId> children;     // 内部节点
        PageId nextLeaf;                  // 叶子节点链表
        
        Node() : isLeaf(true), nextLeaf(0) { }
    };
    
    Node* loadNode(PageId pageId);
    void saveNode(PageId pageId, const Node& node);
    
    void insertInternal(PageId nodeId, const std::string& key, 
                        const std::string& value, std::string& promotedKey,
                        PageId& newChild);
    
    BufferPool& bufferPool_;
    PageId rootId_;
};

} // namespace db
```

### 3.2 B+ 树实现

```cpp
// src/btree.cpp
#include "db/btree.hpp"
#include <algorithm>

namespace db {

BTree::BTree(BufferPool& bufferPool) : bufferPool_(bufferPool), rootId_(0) {
    // 创建根节点
    Page* rootPage = bufferPool_.newPage();
    rootId_ = rootPage->id();
}

void BTree::insert(const std::string& key, const std::string& value) {
    std::string promotedKey;
    PageId newChild = 0;
    
    insertInternal(rootId_, key, value, promotedKey, newChild);
    
    if (newChild != 0) {
        // 根节点分裂,创建新根
        Page* newRoot = bufferPool_.newPage();
        Node node;
        node.isLeaf = false;
        node.keys.push_back(promotedKey);
        node.children.push_back(rootId_);
        node.children.push_back(newChild);
        
        saveNode(newRoot->id(), node);
        rootId_ = newRoot->id();
    }
}

void BTree::insertInternal(PageId nodeId, const std::string& key,
                           const std::string& value, std::string& promotedKey,
                           PageId& newChild) {
    Page* page = bufferPool_.fetchPage(nodeId);
    Node node = *loadNode(nodeId);
    
    if (node.isLeaf) {
        // 在叶子节点插入
        auto it = std::lower_bound(node.keys.begin(), node.keys.end(), key);
        size_t pos = it - node.keys.begin();
        
        if (it != node.keys.end() && *it == key) {
            // 更新现有值
            node.values[pos] = value;
        } else {
            // 插入新键值对
            node.keys.insert(it, key);
            node.values.insert(node.values.begin() + pos, value);
        }
        
        // 检查是否需要分裂
        if (node.keys.size() > BTREE_ORDER) {
            // 分裂
            size_t mid = node.keys.size() / 2;
            
            Node newNode;
            newNode.isLeaf = true;
            newNode.keys.assign(node.keys.begin() + mid, node.keys.end());
            newNode.values.assign(node.values.begin() + mid, node.values.end());
            
            node.keys.resize(mid);
            node.values.resize(mid);
            
            Page* newPage = bufferPool_.newPage();
            newNode.nextLeaf = node.nextLeaf;
            node.nextLeaf = newPage->id();
            
            saveNode(newPage->id(), newNode);
            saveNode(nodeId, node);
            
            promotedKey = newNode.keys[0];
            newChild = newPage->id();
        } else {
            saveNode(nodeId, node);
            newChild = 0;
        }
    } else {
        // 在内部节点查找
        auto it = std::upper_bound(node.keys.begin(), node.keys.end(), key);
        size_t pos = it - node.keys.begin();
        
        std::string childPromotedKey;
        PageId childNewChild;
        
        insertInternal(node.children[pos], key, value, 
                       childPromotedKey, childNewChild);
        
        if (childNewChild != 0) {
            // 子节点分裂,插入新键和子节点
            node.keys.insert(node.keys.begin() + pos, childPromotedKey);
            node.children.insert(node.children.begin() + pos + 1, childNewChild);
            
            // 检查是否需要分裂
            if (node.keys.size() > BTREE_ORDER) {
                size_t mid = node.keys.size() / 2;
                
                Node newNode;
                newNode.isLeaf = false;
                newNode.keys.assign(node.keys.begin() + mid + 1, node.keys.end());
                newNode.children.assign(node.children.begin() + mid + 1, 
                                        node.children.end());
                
                promotedKey = node.keys[mid];
                
                node.keys.resize(mid);
                node.children.resize(mid + 1);
                
                Page* newPage = bufferPool_.newPage();
                saveNode(newPage->id(), newNode);
                saveNode(nodeId, node);
                
                newChild = newPage->id();
            } else {
                saveNode(nodeId, node);
                newChild = 0;
            }
        } else {
            newChild = 0;
        }
    }
}

std::optional<std::string> BTree::get(const std::string& key) {
    PageId currentId = rootId_;
    
    while (true) {
        Node node = *loadNode(currentId);
        
        if (node.isLeaf) {
            auto it = std::lower_bound(node.keys.begin(), node.keys.end(), key);
            if (it != node.keys.end() && *it == key) {
                size_t pos = it - node.keys.begin();
                return node.values[pos];
            }
            return std::nullopt;
        } else {
            auto it = std::upper_bound(node.keys.begin(), node.keys.end(), key);
            size_t pos = it - node.keys.begin();
            currentId = node.children[pos];
        }
    }
}

bool BTree::contains(const std::string& key) {
    return get(key).has_value();
}

std::vector<std::pair<std::string, std::string>> 
BTree::range(const std::string& start, const std::string& end) {
    std::vector<std::pair<std::string, std::string>> result;
    
    // 找到起始叶子节点
    PageId currentId = rootId_;
    
    while (true) {
        Node node = *loadNode(currentId);
        
        if (node.isLeaf) {
            // 遍历叶子节点
            while (currentId != 0) {
                Node leafNode = *loadNode(currentId);
                
                for (size_t i = 0; i < leafNode.keys.size(); ++i) {
                    if (leafNode.keys[i] >= start && leafNode.keys[i] <= end) {
                        result.emplace_back(leafNode.keys[i], leafNode.values[i]);
                    } else if (leafNode.keys[i] > end) {
                        return result;
                    }
                }
                
                currentId = leafNode.nextLeaf;
            }
            break;
        } else {
            auto it = std::upper_bound(node.keys.begin(), node.keys.end(), start);
            size_t pos = it - node.keys.begin();
            currentId = node.children[pos];
        }
    }
    
    return result;
}

BTree::Node* BTree::loadNode(PageId pageId) {
    // 简化实现: 从页面加载节点
    static thread_local Node node;
    Page* page = bufferPool_.fetchPage(pageId);
    
    // 实际实现需要从页面数据反序列化
    // 这里简化处理
    return &node;
}

void BTree::saveNode(PageId pageId, const Node& node) {
    Page* page = bufferPool_.fetchPage(pageId);
    // 实际实现需要序列化节点到页面
    bufferPool_.flushPage(pageId);
}

} // namespace db
```

---

## 4. 事务支持

### 4.1 WAL 日志

```cpp
// include/db/wal.hpp
#pragma once

#include <string>
#include <fstream>
#include <vector>
#include <mutex>

namespace db {

enum class LogType : uint8_t {
    BEGIN,
    INSERT,
    UPDATE,
    DELETE,
    COMMIT,
    ABORT
};

struct LogRecord {
    uint64_t lsn;           // 日志序列号
    uint64_t txnId;         // 事务 ID
    LogType type;
    std::string key;
    std::string oldValue;   // 用于回滚
    std::string newValue;
};

class WAL {
public:
    WAL(const std::string& filename);
    ~WAL();
    
    uint64_t append(const LogRecord& record);
    void flush();
    
    // 恢复
    std::vector<LogRecord> recover();
    
    // 检查点
    void checkpoint();

private:
    std::string filename_;
    std::ofstream file_;
    uint64_t nextLSN_;
    std::mutex mutex_;
};

} // namespace db
```

### 4.2 事务管理

```cpp
// include/db/transaction.hpp
#pragma once

#include "wal.hpp"
#include <functional>
#include <unordered_set>

namespace db {

class Database;

class Transaction {
public:
    Transaction(Database& db, uint64_t txnId);
    ~Transaction();
    
    void put(const std::string& key, const std::string& value);
    std::optional<std::string> get(const std::string& key);
    void remove(const std::string& key);
    
    void commit();
    void abort();

private:
    Database& db_;
    uint64_t txnId_;
    bool committed_;
    bool aborted_;
    
    // 写集
    std::unordered_map<std::string, std::string> writeSet_;
    std::unordered_set<std::string> deleteSet_;
};

class TransactionManager {
public:
    TransactionManager(WAL& wal);
    
    std::unique_ptr<Transaction> begin(Database& db);
    void commit(uint64_t txnId);
    void abort(uint64_t txnId);
    
    void recover();

private:
    WAL& wal_;
    uint64_t nextTxnId_;
    std::unordered_set<uint64_t> activeTxns_;
    std::mutex mutex_;
};

} // namespace db
```

---

## 5. 查询接口

### 5.1 Database 类

```cpp
// include/db/db.hpp
#pragma once

#include "storage.hpp"
#include "btree.hpp"
#include "transaction.hpp"
#include "wal.hpp"
#include <memory>

namespace db {

class Database {
public:
    Database(const std::string& path);
    ~Database();
    
    // 基本操作
    void put(const std::string& key, const std::string& value);
    std::optional<std::string> get(const std::string& key);
    void remove(const std::string& key);
    bool contains(const std::string& key);
    
    // 范围查询
    std::vector<std::pair<std::string, std::string>> 
        range(const std::string& start, const std::string& end);
    
    // 遍历
    void forEach(std::function<void(const std::string&, const std::string&)> callback);
    
    // 事务
    std::unique_ptr<Transaction> beginTransaction();
    
    // 统计
    size_t count();
    
    // 持久化
    void flush();
    void close();

private:
    friend class Transaction;
    
    std::string path_;
    std::unique_ptr<BufferPool> bufferPool_;
    std::unique_ptr<BTree> index_;
    std::unique_ptr<WAL> wal_;
    std::unique_ptr<TransactionManager> txnManager_;
};

} // namespace db
```

### 5.2 使用示例

```cpp
// examples/main.cpp
#include "db/db.hpp"
#include <iostream>

int main() {
    // 创建数据库
    db::Database database("./mydb");
    
    // 基本操作
    database.put("name", "Alice");
    database.put("age", "25");
    database.put("city", "New York");
    
    // 读取
    auto name = database.get("name");
    if (name) {
        std::cout << "Name: " << *name << std::endl;
    }
    
    // 检查存在
    if (database.contains("age")) {
        std::cout << "Age exists" << std::endl;
    }
    
    // 删除
    database.remove("city");
    
    // 范围查询
    database.put("user:1", "Alice");
    database.put("user:2", "Bob");
    database.put("user:3", "Charlie");
    
    auto users = database.range("user:1", "user:3");
    for (const auto& [key, value] : users) {
        std::cout << key << " -> " << value << std::endl;
    }
    
    // 遍历
    database.forEach([](const std::string& key, const std::string& value) {
        std::cout << key << ": " << value << std::endl;
    });
    
    // 事务
    {
        auto txn = database.beginTransaction();
        
        txn->put("balance:alice", "1000");
        txn->put("balance:bob", "500");
        
        // 转账
        auto aliceBalance = txn->get("balance:alice");
        auto bobBalance = txn->get("balance:bob");
        
        if (aliceBalance && bobBalance) {
            int alice = std::stoi(*aliceBalance);
            int bob = std::stoi(*bobBalance);
            
            alice -= 100;
            bob += 100;
            
            txn->put("balance:alice", std::to_string(alice));
            txn->put("balance:bob", std::to_string(bob));
        }
        
        txn->commit();
    }
    
    // 持久化
    database.flush();
    
    return 0;
}
```

---

## 6. 总结

### 6.1 数据库组件

| 组件 | 功能 |
|------|------|
| BufferPool | 页面缓存管理 |
| B+ Tree | 索引结构 |
| WAL | 预写日志 |
| Transaction | 事务管理 |

### 6.2 特性

| 特性 | 说明 |
|------|------|
| 持久化 | 数据写入磁盘 |
| 索引 | B+ 树高效查询 |
| 事务 | ACID 支持 |
| 恢复 | WAL 崩溃恢复 |

### 6.3 下一篇预告

在下一篇文章中,我们将实现一个简单的游戏引擎。

---

> 作者: C++ 技术专栏  
> 系列: 项目实战 (3/4)  
> 上一篇: [HTTP 框架](./60-http-framework.md)  
> 下一篇: [游戏引擎](./62-game-engine.md)
