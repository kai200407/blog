---
title: "容器适配器"
description: "1. [容器适配器概述](#1-容器适配器概述)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 29
---

> 本文是 C++ 从入门到精通系列的第二十九篇,将深入讲解 STL 容器适配器,包括 stack、queue 和 priority_queue。

---

## 目录

1. [容器适配器概述](#1-容器适配器概述)
2. [stack](#2-stack)
3. [queue](#3-queue)
4. [priority_queue](#4-priority_queue)
5. [应用示例](#5-应用示例)
6. [总结](#6-总结)

---

## 1. 容器适配器概述

### 1.1 什么是容器适配器

```
容器适配器:
- 不是独立的容器
- 基于其他容器实现
- 提供特定的接口
- 限制底层容器的操作

三种容器适配器:
1. stack: 后进先出 (LIFO)
2. queue: 先进先出 (FIFO)
3. priority_queue: 优先级队列
```

### 1.2 底层容器

```
默认底层容器:

stack:
- 默认: deque
- 可选: vector, list

queue:
- 默认: deque
- 可选: list

priority_queue:
- 默认: vector
- 可选: deque
```

---

## 2. stack

### 2.1 基本操作

```cpp
#include <iostream>
#include <stack>
#include <vector>
#include <list>

int main() {
    // 创建 stack
    std::stack<int> s1;
    std::stack<int, std::vector<int>> s2;  // 使用 vector 作为底层容器
    std::stack<int, std::list<int>> s3;    // 使用 list 作为底层容器
    
    // 从容器初始化
    std::vector<int> vec = {1, 2, 3, 4, 5};
    std::stack<int, std::vector<int>> s4(vec);
    
    // push: 压入元素
    s1.push(10);
    s1.push(20);
    s1.push(30);
    s1.emplace(40);  // 原地构造
    
    // top: 访问栈顶
    std::cout << "top: " << s1.top() << std::endl;
    
    // pop: 弹出栈顶
    s1.pop();
    std::cout << "After pop, top: " << s1.top() << std::endl;
    
    // size: 大小
    std::cout << "size: " << s1.size() << std::endl;
    
    // empty: 是否为空
    std::cout << "empty: " << s1.empty() << std::endl;
    
    // 遍历 (会清空栈)
    std::cout << "Elements: ";
    while (!s1.empty()) {
        std::cout << s1.top() << " ";
        s1.pop();
    }
    std::cout << std::endl;
    
    return 0;
}
```

### 2.2 stack 应用

```cpp
#include <iostream>
#include <stack>
#include <string>

// 括号匹配
bool isBalanced(const std::string& s) {
    std::stack<char> st;
    
    for (char c : s) {
        if (c == '(' || c == '[' || c == '{') {
            st.push(c);
        } else if (c == ')' || c == ']' || c == '}') {
            if (st.empty()) return false;
            
            char top = st.top();
            if ((c == ')' && top != '(') ||
                (c == ']' && top != '[') ||
                (c == '}' && top != '{')) {
                return false;
            }
            st.pop();
        }
    }
    
    return st.empty();
}

// 逆波兰表达式求值
int evalRPN(const std::vector<std::string>& tokens) {
    std::stack<int> st;
    
    for (const auto& token : tokens) {
        if (token == "+" || token == "-" || token == "*" || token == "/") {
            int b = st.top(); st.pop();
            int a = st.top(); st.pop();
            
            if (token == "+") st.push(a + b);
            else if (token == "-") st.push(a - b);
            else if (token == "*") st.push(a * b);
            else if (token == "/") st.push(a / b);
        } else {
            st.push(std::stoi(token));
        }
    }
    
    return st.top();
}

int main() {
    // 括号匹配
    std::cout << "isBalanced(\"([]{})\": " << isBalanced("([]{})") << std::endl;
    std::cout << "isBalanced(\"([)]\": " << isBalanced("([)]") << std::endl;
    
    // 逆波兰表达式: 3 4 + 2 * = (3 + 4) * 2 = 14
    std::vector<std::string> rpn = {"3", "4", "+", "2", "*"};
    std::cout << "evalRPN: " << evalRPN(rpn) << std::endl;
    
    return 0;
}
```

---

## 3. queue

### 3.1 基本操作

```cpp
#include <iostream>
#include <queue>
#include <list>

int main() {
    // 创建 queue
    std::queue<int> q1;
    std::queue<int, std::list<int>> q2;  // 使用 list 作为底层容器
    
    // push: 入队
    q1.push(10);
    q1.push(20);
    q1.push(30);
    q1.emplace(40);
    
    // front: 访问队首
    std::cout << "front: " << q1.front() << std::endl;
    
    // back: 访问队尾
    std::cout << "back: " << q1.back() << std::endl;
    
    // pop: 出队
    q1.pop();
    std::cout << "After pop, front: " << q1.front() << std::endl;
    
    // size: 大小
    std::cout << "size: " << q1.size() << std::endl;
    
    // empty: 是否为空
    std::cout << "empty: " << q1.empty() << std::endl;
    
    // 遍历 (会清空队列)
    std::cout << "Elements: ";
    while (!q1.empty()) {
        std::cout << q1.front() << " ";
        q1.pop();
    }
    std::cout << std::endl;
    
    return 0;
}
```

### 3.2 queue 应用

```cpp
#include <iostream>
#include <queue>
#include <vector>

// BFS 遍历
void bfs(const std::vector<std::vector<int>>& graph, int start) {
    std::vector<bool> visited(graph.size(), false);
    std::queue<int> q;
    
    q.push(start);
    visited[start] = true;
    
    std::cout << "BFS: ";
    while (!q.empty()) {
        int node = q.front();
        q.pop();
        std::cout << node << " ";
        
        for (int neighbor : graph[node]) {
            if (!visited[neighbor]) {
                visited[neighbor] = true;
                q.push(neighbor);
            }
        }
    }
    std::cout << std::endl;
}

// 任务队列
class TaskQueue {
public:
    void addTask(const std::string& task) {
        tasks.push(task);
        std::cout << "Added task: " << task << std::endl;
    }
    
    void processNext() {
        if (!tasks.empty()) {
            std::cout << "Processing: " << tasks.front() << std::endl;
            tasks.pop();
        }
    }
    
    bool hasTasks() const {
        return !tasks.empty();
    }
    
private:
    std::queue<std::string> tasks;
};

int main() {
    // BFS
    std::vector<std::vector<int>> graph = {
        {1, 2},     // 0 -> 1, 2
        {0, 3, 4},  // 1 -> 0, 3, 4
        {0, 5},     // 2 -> 0, 5
        {1},        // 3 -> 1
        {1},        // 4 -> 1
        {2}         // 5 -> 2
    };
    bfs(graph, 0);
    
    // 任务队列
    TaskQueue taskQueue;
    taskQueue.addTask("Task 1");
    taskQueue.addTask("Task 2");
    taskQueue.addTask("Task 3");
    
    while (taskQueue.hasTasks()) {
        taskQueue.processNext();
    }
    
    return 0;
}
```

---

## 4. priority_queue

### 4.1 基本操作

```cpp
#include <iostream>
#include <queue>
#include <vector>
#include <functional>

int main() {
    // 创建 priority_queue (默认最大堆)
    std::priority_queue<int> pq1;
    
    // 最小堆
    std::priority_queue<int, std::vector<int>, std::greater<int>> pq2;
    
    // 从容器初始化
    std::vector<int> vec = {3, 1, 4, 1, 5, 9, 2, 6};
    std::priority_queue<int> pq3(vec.begin(), vec.end());
    
    // push: 插入元素
    pq1.push(30);
    pq1.push(10);
    pq1.push(50);
    pq1.push(20);
    pq1.emplace(40);
    
    // top: 访问最大元素
    std::cout << "top: " << pq1.top() << std::endl;
    
    // pop: 移除最大元素
    pq1.pop();
    std::cout << "After pop, top: " << pq1.top() << std::endl;
    
    // size: 大小
    std::cout << "size: " << pq1.size() << std::endl;
    
    // 遍历 (会清空队列)
    std::cout << "Max heap: ";
    while (!pq1.empty()) {
        std::cout << pq1.top() << " ";
        pq1.pop();
    }
    std::cout << std::endl;
    
    // 最小堆
    pq2.push(30);
    pq2.push(10);
    pq2.push(50);
    pq2.push(20);
    
    std::cout << "Min heap: ";
    while (!pq2.empty()) {
        std::cout << pq2.top() << " ";
        pq2.pop();
    }
    std::cout << std::endl;
    
    return 0;
}
```

### 4.2 自定义比较

```cpp
#include <iostream>
#include <queue>
#include <vector>
#include <string>

struct Task {
    int priority;
    std::string name;
};

// 方法 1: 重载 < 运算符
bool operator<(const Task& a, const Task& b) {
    return a.priority < b.priority;  // 优先级高的在前
}

// 方法 2: 自定义比较器
struct TaskCompare {
    bool operator()(const Task& a, const Task& b) const {
        return a.priority < b.priority;
    }
};

int main() {
    // 使用重载的 < 运算符
    std::priority_queue<Task> pq1;
    pq1.push({3, "Low priority"});
    pq1.push({1, "Lowest priority"});
    pq1.push({5, "High priority"});
    pq1.push({2, "Medium priority"});
    
    std::cout << "Tasks by priority:" << std::endl;
    while (!pq1.empty()) {
        const auto& task = pq1.top();
        std::cout << "  " << task.priority << ": " << task.name << std::endl;
        pq1.pop();
    }
    
    // 使用 lambda
    auto cmp = [](const Task& a, const Task& b) {
        return a.priority > b.priority;  // 优先级低的在前 (最小堆)
    };
    std::priority_queue<Task, std::vector<Task>, decltype(cmp)> pq2(cmp);
    
    pq2.push({3, "Low priority"});
    pq2.push({1, "Lowest priority"});
    pq2.push({5, "High priority"});
    
    std::cout << "\nTasks (min heap):" << std::endl;
    while (!pq2.empty()) {
        const auto& task = pq2.top();
        std::cout << "  " << task.priority << ": " << task.name << std::endl;
        pq2.pop();
    }
    
    return 0;
}
```

### 4.3 priority_queue 应用

```cpp
#include <iostream>
#include <queue>
#include <vector>

// Top K 问题
std::vector<int> topK(const std::vector<int>& nums, int k) {
    // 使用最小堆维护 k 个最大元素
    std::priority_queue<int, std::vector<int>, std::greater<int>> minHeap;
    
    for (int num : nums) {
        minHeap.push(num);
        if (minHeap.size() > k) {
            minHeap.pop();
        }
    }
    
    std::vector<int> result;
    while (!minHeap.empty()) {
        result.push_back(minHeap.top());
        minHeap.pop();
    }
    
    return result;
}

// 合并 K 个有序数组
std::vector<int> mergeKSorted(const std::vector<std::vector<int>>& arrays) {
    using Element = std::pair<int, std::pair<int, int>>;  // {value, {array_idx, elem_idx}}
    
    auto cmp = [](const Element& a, const Element& b) {
        return a.first > b.first;  // 最小堆
    };
    std::priority_queue<Element, std::vector<Element>, decltype(cmp)> pq(cmp);
    
    // 初始化: 每个数组的第一个元素
    for (int i = 0; i < arrays.size(); ++i) {
        if (!arrays[i].empty()) {
            pq.push({arrays[i][0], {i, 0}});
        }
    }
    
    std::vector<int> result;
    while (!pq.empty()) {
        auto [value, indices] = pq.top();
        pq.pop();
        
        result.push_back(value);
        
        auto [arrIdx, elemIdx] = indices;
        if (elemIdx + 1 < arrays[arrIdx].size()) {
            pq.push({arrays[arrIdx][elemIdx + 1], {arrIdx, elemIdx + 1}});
        }
    }
    
    return result;
}

int main() {
    // Top K
    std::vector<int> nums = {3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5};
    auto top3 = topK(nums, 3);
    std::cout << "Top 3: ";
    for (int x : top3) std::cout << x << " ";
    std::cout << std::endl;
    
    // 合并 K 个有序数组
    std::vector<std::vector<int>> arrays = {
        {1, 4, 7},
        {2, 5, 8},
        {3, 6, 9}
    };
    auto merged = mergeKSorted(arrays);
    std::cout << "Merged: ";
    for (int x : merged) std::cout << x << " ";
    std::cout << std::endl;
    
    return 0;
}
```

---

## 5. 应用示例

### 5.1 表达式求值

```cpp
#include <iostream>
#include <stack>
#include <string>
#include <sstream>
#include <cctype>

int precedence(char op) {
    if (op == '+' || op == '-') return 1;
    if (op == '*' || op == '/') return 2;
    return 0;
}

int applyOp(int a, int b, char op) {
    switch (op) {
        case '+': return a + b;
        case '-': return a - b;
        case '*': return a * b;
        case '/': return a / b;
    }
    return 0;
}

int evaluate(const std::string& expr) {
    std::stack<int> values;
    std::stack<char> ops;
    
    for (int i = 0; i < expr.length(); ++i) {
        if (expr[i] == ' ') continue;
        
        if (std::isdigit(expr[i])) {
            int val = 0;
            while (i < expr.length() && std::isdigit(expr[i])) {
                val = val * 10 + (expr[i] - '0');
                ++i;
            }
            --i;
            values.push(val);
        } else if (expr[i] == '(') {
            ops.push(expr[i]);
        } else if (expr[i] == ')') {
            while (!ops.empty() && ops.top() != '(') {
                int b = values.top(); values.pop();
                int a = values.top(); values.pop();
                char op = ops.top(); ops.pop();
                values.push(applyOp(a, b, op));
            }
            ops.pop();  // 移除 '('
        } else {
            while (!ops.empty() && precedence(ops.top()) >= precedence(expr[i])) {
                int b = values.top(); values.pop();
                int a = values.top(); values.pop();
                char op = ops.top(); ops.pop();
                values.push(applyOp(a, b, op));
            }
            ops.push(expr[i]);
        }
    }
    
    while (!ops.empty()) {
        int b = values.top(); values.pop();
        int a = values.top(); values.pop();
        char op = ops.top(); ops.pop();
        values.push(applyOp(a, b, op));
    }
    
    return values.top();
}

int main() {
    std::cout << "3 + 4 * 2 = " << evaluate("3 + 4 * 2") << std::endl;
    std::cout << "(3 + 4) * 2 = " << evaluate("(3 + 4) * 2") << std::endl;
    std::cout << "10 + 2 * 6 = " << evaluate("10 + 2 * 6") << std::endl;
    
    return 0;
}
```

### 5.2 滑动窗口最大值

```cpp
#include <iostream>
#include <vector>
#include <deque>

std::vector<int> maxSlidingWindow(const std::vector<int>& nums, int k) {
    std::deque<int> dq;  // 存储索引
    std::vector<int> result;
    
    for (int i = 0; i < nums.size(); ++i) {
        // 移除窗口外的元素
        while (!dq.empty() && dq.front() <= i - k) {
            dq.pop_front();
        }
        
        // 移除比当前元素小的元素
        while (!dq.empty() && nums[dq.back()] < nums[i]) {
            dq.pop_back();
        }
        
        dq.push_back(i);
        
        // 窗口形成后记录最大值
        if (i >= k - 1) {
            result.push_back(nums[dq.front()]);
        }
    }
    
    return result;
}

int main() {
    std::vector<int> nums = {1, 3, -1, -3, 5, 3, 6, 7};
    int k = 3;
    
    auto result = maxSlidingWindow(nums, k);
    
    std::cout << "Sliding window max (k=" << k << "): ";
    for (int x : result) std::cout << x << " ";
    std::cout << std::endl;
    
    return 0;
}
```

---

## 6. 总结

### 6.1 容器适配器对比

| 适配器 | 数据结构 | 访问 | 插入/删除 | 底层容器 |
|--------|---------|------|----------|---------|
| stack | 栈 | top | O(1) | deque/vector/list |
| queue | 队列 | front/back | O(1) | deque/list |
| priority_queue | 堆 | top | O(log n) | vector/deque |

### 6.2 最佳实践

```
1. stack: 后进先出场景
2. queue: 先进先出场景
3. priority_queue: 需要按优先级处理
4. 选择合适的底层容器
5. 注意 priority_queue 默认是最大堆
```

### 6.3 下一篇预告

在下一篇文章中,我们将学习 string 与字符串处理。

---

> 作者: C++ 技术专栏  
> 系列: STL 标准模板库 (7/8)  
> 上一篇: [函数对象与 Lambda](./28-functors-lambda.md)  
> 下一篇: [string 与字符串处理](./30-string.md)
