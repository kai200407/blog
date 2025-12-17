---
title: "进程与信号"
description: "1. [进程基础](#1-进程基础)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 52
---

> 本文是 C++ 从入门到精通系列的第五十二篇,将深入讲解 Linux 进程管理和信号处理。

---

## 目录

1. [进程基础](#1-进程基础)
2. [进程创建](#2-进程创建)
3. [进程间通信](#3-进程间通信)
4. [信号处理](#4-信号处理)
5. [守护进程](#5-守护进程)
6. [总结](#6-总结)

---

## 1. 进程基础

### 1.1 进程概念

```
进程 (Process):
- 程序的运行实例
- 拥有独立的地址空间
- 由操作系统调度

进程属性:
- PID: 进程 ID
- PPID: 父进程 ID
- UID/GID: 用户/组 ID
- 状态: 运行、睡眠、停止、僵尸
- 优先级
- 资源使用
```

### 1.2 获取进程信息

```cpp
#include <iostream>
#include <unistd.h>
#include <sys/types.h>

int main() {
    // 进程 ID
    pid_t pid = getpid();
    std::cout << "PID: " << pid << std::endl;
    
    // 父进程 ID
    pid_t ppid = getppid();
    std::cout << "PPID: " << ppid << std::endl;
    
    // 用户 ID
    uid_t uid = getuid();
    uid_t euid = geteuid();
    std::cout << "UID: " << uid << ", EUID: " << euid << std::endl;
    
    // 组 ID
    gid_t gid = getgid();
    gid_t egid = getegid();
    std::cout << "GID: " << gid << ", EGID: " << egid << std::endl;
    
    // 进程组 ID
    pid_t pgid = getpgrp();
    std::cout << "PGID: " << pgid << std::endl;
    
    // 会话 ID
    pid_t sid = getsid(0);
    std::cout << "SID: " << sid << std::endl;
    
    return 0;
}
```

---

## 2. 进程创建

### 2.1 fork

```cpp
#include <iostream>
#include <unistd.h>
#include <sys/wait.h>

int main() {
    std::cout << "Before fork, PID: " << getpid() << std::endl;
    
    pid_t pid = fork();
    
    if (pid < 0) {
        std::cerr << "Fork failed" << std::endl;
        return 1;
    } else if (pid == 0) {
        // 子进程
        std::cout << "Child process, PID: " << getpid() 
                  << ", PPID: " << getppid() << std::endl;
        sleep(2);
        std::cout << "Child exiting" << std::endl;
        return 42;
    } else {
        // 父进程
        std::cout << "Parent process, PID: " << getpid() 
                  << ", Child PID: " << pid << std::endl;
        
        int status;
        waitpid(pid, &status, 0);
        
        if (WIFEXITED(status)) {
            std::cout << "Child exited with status: " 
                      << WEXITSTATUS(status) << std::endl;
        }
    }
    
    return 0;
}
```

### 2.2 exec 系列

```cpp
#include <iostream>
#include <unistd.h>
#include <sys/wait.h>

void runCommand() {
    pid_t pid = fork();
    
    if (pid == 0) {
        // 子进程执行命令
        
        // execl: 参数列表
        // execl("/bin/ls", "ls", "-l", nullptr);
        
        // execlp: 使用 PATH
        // execlp("ls", "ls", "-l", nullptr);
        
        // execv: 参数数组
        char* args[] = {(char*)"ls", (char*)"-l", nullptr};
        execv("/bin/ls", args);
        
        // 如果 exec 成功,不会执行到这里
        std::cerr << "exec failed" << std::endl;
        _exit(1);
    } else if (pid > 0) {
        wait(nullptr);
    }
}

void runWithEnv() {
    pid_t pid = fork();
    
    if (pid == 0) {
        char* args[] = {(char*)"env", nullptr};
        char* envp[] = {
            (char*)"MY_VAR=hello",
            (char*)"PATH=/bin:/usr/bin",
            nullptr
        };
        
        execve("/usr/bin/env", args, envp);
        _exit(1);
    } else if (pid > 0) {
        wait(nullptr);
    }
}

int main() {
    std::cout << "Running ls:" << std::endl;
    runCommand();
    
    std::cout << "\nRunning with custom env:" << std::endl;
    runWithEnv();
    
    return 0;
}
```

### 2.3 进程等待

```cpp
#include <iostream>
#include <unistd.h>
#include <sys/wait.h>
#include <vector>

void waitExample() {
    std::vector<pid_t> children;
    
    // 创建多个子进程
    for (int i = 0; i < 3; ++i) {
        pid_t pid = fork();
        
        if (pid == 0) {
            sleep(i + 1);
            std::cout << "Child " << i << " (PID " << getpid() 
                      << ") exiting" << std::endl;
            _exit(i);
        } else {
            children.push_back(pid);
        }
    }
    
    // 等待所有子进程
    for (pid_t child : children) {
        int status;
        pid_t result = waitpid(child, &status, 0);
        
        if (result > 0) {
            if (WIFEXITED(status)) {
                std::cout << "Child " << child << " exited with " 
                          << WEXITSTATUS(status) << std::endl;
            } else if (WIFSIGNALED(status)) {
                std::cout << "Child " << child << " killed by signal " 
                          << WTERMSIG(status) << std::endl;
            }
        }
    }
}

void nonBlockingWait() {
    pid_t pid = fork();
    
    if (pid == 0) {
        sleep(3);
        _exit(0);
    }
    
    // 非阻塞等待
    while (true) {
        int status;
        pid_t result = waitpid(pid, &status, WNOHANG);
        
        if (result == 0) {
            std::cout << "Child still running..." << std::endl;
            sleep(1);
        } else if (result > 0) {
            std::cout << "Child finished" << std::endl;
            break;
        } else {
            std::cerr << "waitpid error" << std::endl;
            break;
        }
    }
}

int main() {
    std::cout << "Wait example:" << std::endl;
    waitExample();
    
    std::cout << "\nNon-blocking wait:" << std::endl;
    nonBlockingWait();
    
    return 0;
}
```

---

## 3. 进程间通信

### 3.1 管道

```cpp
#include <iostream>
#include <unistd.h>
#include <sys/wait.h>
#include <cstring>

void pipeExample() {
    int pipefd[2];
    
    if (pipe(pipefd) < 0) {
        std::cerr << "pipe failed" << std::endl;
        return;
    }
    
    pid_t pid = fork();
    
    if (pid == 0) {
        // 子进程: 读取
        close(pipefd[1]);  // 关闭写端
        
        char buffer[256];
        ssize_t n = read(pipefd[0], buffer, sizeof(buffer) - 1);
        
        if (n > 0) {
            buffer[n] = '\0';
            std::cout << "Child received: " << buffer << std::endl;
        }
        
        close(pipefd[0]);
        _exit(0);
    } else {
        // 父进程: 写入
        close(pipefd[0]);  // 关闭读端
        
        const char* message = "Hello from parent!";
        write(pipefd[1], message, strlen(message));
        
        close(pipefd[1]);
        wait(nullptr);
    }
}

void pipeChain() {
    // 实现 ls | grep .cpp
    int pipefd[2];
    pipe(pipefd);
    
    pid_t pid1 = fork();
    
    if (pid1 == 0) {
        // 第一个子进程: ls
        close(pipefd[0]);
        dup2(pipefd[1], STDOUT_FILENO);
        close(pipefd[1]);
        
        execlp("ls", "ls", nullptr);
        _exit(1);
    }
    
    pid_t pid2 = fork();
    
    if (pid2 == 0) {
        // 第二个子进程: grep
        close(pipefd[1]);
        dup2(pipefd[0], STDIN_FILENO);
        close(pipefd[0]);
        
        execlp("grep", "grep", ".cpp", nullptr);
        _exit(1);
    }
    
    close(pipefd[0]);
    close(pipefd[1]);
    
    wait(nullptr);
    wait(nullptr);
}

int main() {
    std::cout << "Pipe example:" << std::endl;
    pipeExample();
    
    std::cout << "\nPipe chain (ls | grep .cpp):" << std::endl;
    pipeChain();
    
    return 0;
}
```

### 3.2 共享内存

```cpp
#include <iostream>
#include <sys/mman.h>
#include <sys/wait.h>
#include <unistd.h>
#include <cstring>

struct SharedData {
    int counter;
    char message[256];
};

void sharedMemoryExample() {
    // 创建共享内存
    SharedData* shared = static_cast<SharedData*>(
        mmap(nullptr, sizeof(SharedData),
             PROT_READ | PROT_WRITE,
             MAP_SHARED | MAP_ANONYMOUS,
             -1, 0)
    );
    
    if (shared == MAP_FAILED) {
        std::cerr << "mmap failed" << std::endl;
        return;
    }
    
    shared->counter = 0;
    strcpy(shared->message, "Initial message");
    
    pid_t pid = fork();
    
    if (pid == 0) {
        // 子进程
        sleep(1);
        
        std::cout << "Child: counter = " << shared->counter << std::endl;
        std::cout << "Child: message = " << shared->message << std::endl;
        
        shared->counter = 100;
        strcpy(shared->message, "Modified by child");
        
        _exit(0);
    } else {
        // 父进程
        shared->counter = 42;
        strcpy(shared->message, "Set by parent");
        
        wait(nullptr);
        
        std::cout << "Parent: counter = " << shared->counter << std::endl;
        std::cout << "Parent: message = " << shared->message << std::endl;
    }
    
    munmap(shared, sizeof(SharedData));
}

int main() {
    sharedMemoryExample();
    return 0;
}
```

---

## 4. 信号处理

### 4.1 信号基础

```
常用信号:

SIGINT (2)   - 中断 (Ctrl+C)
SIGTERM (15) - 终止
SIGKILL (9)  - 强制终止 (不可捕获)
SIGSTOP (19) - 停止 (不可捕获)
SIGCONT (18) - 继续
SIGHUP (1)   - 挂起
SIGCHLD (17) - 子进程状态改变
SIGUSR1 (10) - 用户定义信号 1
SIGUSR2 (12) - 用户定义信号 2
SIGALRM (14) - 定时器
SIGSEGV (11) - 段错误
```

### 4.2 信号处理函数

```cpp
#include <iostream>
#include <csignal>
#include <unistd.h>
#include <atomic>

std::atomic<bool> running{true};

void signalHandler(int signum) {
    std::cout << "\nReceived signal: " << signum << std::endl;
    
    switch (signum) {
        case SIGINT:
            std::cout << "SIGINT received, shutting down..." << std::endl;
            running = false;
            break;
        case SIGTERM:
            std::cout << "SIGTERM received, terminating..." << std::endl;
            running = false;
            break;
        case SIGUSR1:
            std::cout << "SIGUSR1 received" << std::endl;
            break;
    }
}

int main() {
    // 注册信号处理函数
    signal(SIGINT, signalHandler);
    signal(SIGTERM, signalHandler);
    signal(SIGUSR1, signalHandler);
    
    std::cout << "PID: " << getpid() << std::endl;
    std::cout << "Running... Press Ctrl+C to stop" << std::endl;
    std::cout << "Or send SIGUSR1: kill -USR1 " << getpid() << std::endl;
    
    while (running) {
        std::cout << "." << std::flush;
        sleep(1);
    }
    
    std::cout << "Exiting gracefully" << std::endl;
    
    return 0;
}
```

### 4.3 sigaction

```cpp
#include <iostream>
#include <csignal>
#include <unistd.h>
#include <cstring>

void sigactionHandler(int signum, siginfo_t* info, void* context) {
    std::cout << "Signal: " << signum << std::endl;
    std::cout << "Sender PID: " << info->si_pid << std::endl;
    std::cout << "Sender UID: " << info->si_uid << std::endl;
    
    if (signum == SIGCHLD) {
        std::cout << "Child status: " << info->si_status << std::endl;
    }
}

void setupSignalHandler() {
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    
    sa.sa_sigaction = sigactionHandler;
    sa.sa_flags = SA_SIGINFO;  // 使用 sa_sigaction
    sigemptyset(&sa.sa_mask);
    
    sigaction(SIGINT, &sa, nullptr);
    sigaction(SIGCHLD, &sa, nullptr);
    sigaction(SIGUSR1, &sa, nullptr);
}

int main() {
    setupSignalHandler();
    
    std::cout << "PID: " << getpid() << std::endl;
    
    // 创建子进程测试 SIGCHLD
    pid_t pid = fork();
    if (pid == 0) {
        sleep(1);
        _exit(42);
    }
    
    std::cout << "Waiting for signals..." << std::endl;
    
    for (int i = 0; i < 5; ++i) {
        pause();  // 等待信号
    }
    
    return 0;
}
```

### 4.4 信号阻塞

```cpp
#include <iostream>
#include <csignal>
#include <unistd.h>

void handler(int signum) {
    std::cout << "Received signal: " << signum << std::endl;
}

void blockSignals() {
    sigset_t mask, oldmask;
    
    // 初始化信号集
    sigemptyset(&mask);
    sigaddset(&mask, SIGINT);
    sigaddset(&mask, SIGTERM);
    
    // 阻塞信号
    sigprocmask(SIG_BLOCK, &mask, &oldmask);
    
    std::cout << "Signals blocked, doing critical work..." << std::endl;
    sleep(5);
    std::cout << "Critical work done" << std::endl;
    
    // 恢复信号
    sigprocmask(SIG_SETMASK, &oldmask, nullptr);
    
    std::cout << "Signals unblocked" << std::endl;
}

int main() {
    signal(SIGINT, handler);
    signal(SIGTERM, handler);
    
    std::cout << "PID: " << getpid() << std::endl;
    
    blockSignals();
    
    std::cout << "Waiting for signals..." << std::endl;
    pause();
    
    return 0;
}
```

---

## 5. 守护进程

### 5.1 创建守护进程

```cpp
#include <iostream>
#include <fstream>
#include <unistd.h>
#include <sys/stat.h>
#include <csignal>
#include <cstring>

void daemonize() {
    // 第一次 fork
    pid_t pid = fork();
    if (pid < 0) {
        exit(1);
    }
    if (pid > 0) {
        exit(0);  // 父进程退出
    }
    
    // 创建新会话
    if (setsid() < 0) {
        exit(1);
    }
    
    // 忽略 SIGHUP
    signal(SIGHUP, SIG_IGN);
    
    // 第二次 fork
    pid = fork();
    if (pid < 0) {
        exit(1);
    }
    if (pid > 0) {
        exit(0);
    }
    
    // 更改工作目录
    chdir("/");
    
    // 重设文件权限掩码
    umask(0);
    
    // 关闭文件描述符
    for (int fd = sysconf(_SC_OPEN_MAX); fd >= 0; --fd) {
        close(fd);
    }
    
    // 重定向标准流
    open("/dev/null", O_RDWR);  // stdin
    dup(0);  // stdout
    dup(0);  // stderr
}

void writePidFile(const char* path) {
    std::ofstream file(path);
    if (file) {
        file << getpid();
    }
}

void daemonMain() {
    writePidFile("/tmp/mydaemon.pid");
    
    std::ofstream log("/tmp/mydaemon.log", std::ios::app);
    
    while (true) {
        log << "Daemon running, PID: " << getpid() << std::endl;
        log.flush();
        sleep(10);
    }
}

int main(int argc, char* argv[]) {
    if (argc > 1 && strcmp(argv[1], "-d") == 0) {
        daemonize();
        daemonMain();
    } else {
        std::cout << "Run with -d to start as daemon" << std::endl;
        std::cout << "PID file: /tmp/mydaemon.pid" << std::endl;
        std::cout << "Log file: /tmp/mydaemon.log" << std::endl;
    }
    
    return 0;
}
```

### 5.2 守护进程管理

```cpp
#include <iostream>
#include <fstream>
#include <csignal>
#include <unistd.h>
#include <cstring>

pid_t readPidFile(const char* path) {
    std::ifstream file(path);
    pid_t pid = 0;
    if (file) {
        file >> pid;
    }
    return pid;
}

bool isRunning(pid_t pid) {
    return kill(pid, 0) == 0;
}

void startDaemon() {
    std::cout << "Starting daemon..." << std::endl;
    // 实际启动守护进程
}

void stopDaemon() {
    pid_t pid = readPidFile("/tmp/mydaemon.pid");
    
    if (pid > 0 && isRunning(pid)) {
        std::cout << "Stopping daemon (PID: " << pid << ")..." << std::endl;
        kill(pid, SIGTERM);
        
        // 等待进程退出
        for (int i = 0; i < 10; ++i) {
            if (!isRunning(pid)) {
                std::cout << "Daemon stopped" << std::endl;
                return;
            }
            sleep(1);
        }
        
        // 强制终止
        std::cout << "Force killing daemon..." << std::endl;
        kill(pid, SIGKILL);
    } else {
        std::cout << "Daemon not running" << std::endl;
    }
}

void statusDaemon() {
    pid_t pid = readPidFile("/tmp/mydaemon.pid");
    
    if (pid > 0 && isRunning(pid)) {
        std::cout << "Daemon is running (PID: " << pid << ")" << std::endl;
    } else {
        std::cout << "Daemon is not running" << std::endl;
    }
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cout << "Usage: " << argv[0] << " start|stop|status" << std::endl;
        return 1;
    }
    
    if (strcmp(argv[1], "start") == 0) {
        startDaemon();
    } else if (strcmp(argv[1], "stop") == 0) {
        stopDaemon();
    } else if (strcmp(argv[1], "status") == 0) {
        statusDaemon();
    }
    
    return 0;
}
```

---

## 6. 总结

### 6.1 进程 API

| 函数 | 说明 |
|------|------|
| fork() | 创建子进程 |
| exec*() | 执行程序 |
| wait()/waitpid() | 等待子进程 |
| exit()/_exit() | 退出进程 |
| getpid()/getppid() | 获取进程 ID |

### 6.2 信号 API

| 函数 | 说明 |
|------|------|
| signal() | 简单信号处理 |
| sigaction() | 高级信号处理 |
| kill() | 发送信号 |
| sigprocmask() | 阻塞信号 |
| pause() | 等待信号 |

### 6.3 下一篇预告

在下一篇文章中,我们将学习性能分析与优化。

---

> 作者: C++ 技术专栏  
> 系列: 系统编程与性能优化 (2/4)  
> 上一篇: [文件系统操作](./51-filesystem.md)  
> 下一篇: [性能分析与优化](./53-performance.md)
