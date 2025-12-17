---
title: "游戏引擎"
description: "1. [引擎架构](#1-引擎架构)"
pubDate: "2025-12-17"
tags: ["cpp","programming"]
category: "cpp"
series: "C++ 从入门到精通"
order: 62
---

> 本文是 C++ 从入门到精通系列的第六十二篇,也是整个系列的收官之作。我们将实现一个简单的 2D 游戏引擎。

---

## 目录

1. [引擎架构](#1-引擎架构)
2. [核心系统](#2-核心系统)
3. [渲染系统](#3-渲染系统)
4. [物理系统](#4-物理系统)
5. [完整示例](#5-完整示例)
6. [总结](#6-总结)

---

## 1. 引擎架构

### 1.1 设计目标

```
设计目标:
- 模块化架构
- 高性能
- 易于扩展
- 跨平台

核心系统:
- 游戏循环 (Game Loop)
- 实体组件系统 (ECS)
- 渲染系统 (Renderer)
- 输入系统 (Input)
- 物理系统 (Physics)
- 资源管理 (Resources)
```

### 1.2 项目结构

```
game-engine/
├── include/
│   └── engine/
│       ├── engine.hpp
│       ├── ecs.hpp
│       ├── renderer.hpp
│       ├── input.hpp
│       ├── physics.hpp
│       ├── math.hpp
│       └── resources.hpp
├── src/
│   ├── engine.cpp
│   ├── ecs.cpp
│   ├── renderer.cpp
│   ├── input.cpp
│   └── physics.cpp
├── examples/
│   └── game.cpp
└── CMakeLists.txt
```

---

## 2. 核心系统

### 2.1 数学库

```cpp
// include/engine/math.hpp
#pragma once

#include <cmath>
#include <algorithm>

namespace engine {

struct Vec2 {
    float x = 0, y = 0;
    
    Vec2() = default;
    Vec2(float x, float y) : x(x), y(y) { }
    
    Vec2 operator+(const Vec2& other) const { return {x + other.x, y + other.y}; }
    Vec2 operator-(const Vec2& other) const { return {x - other.x, y - other.y}; }
    Vec2 operator*(float scalar) const { return {x * scalar, y * scalar}; }
    Vec2 operator/(float scalar) const { return {x / scalar, y / scalar}; }
    
    Vec2& operator+=(const Vec2& other) { x += other.x; y += other.y; return *this; }
    Vec2& operator-=(const Vec2& other) { x -= other.x; y -= other.y; return *this; }
    Vec2& operator*=(float scalar) { x *= scalar; y *= scalar; return *this; }
    
    float length() const { return std::sqrt(x * x + y * y); }
    float lengthSquared() const { return x * x + y * y; }
    
    Vec2 normalized() const {
        float len = length();
        return len > 0 ? *this / len : Vec2{0, 0};
    }
    
    float dot(const Vec2& other) const { return x * other.x + y * other.y; }
    float cross(const Vec2& other) const { return x * other.y - y * other.x; }
    
    static Vec2 lerp(const Vec2& a, const Vec2& b, float t) {
        return a + (b - a) * t;
    }
};

struct Rect {
    float x = 0, y = 0, width = 0, height = 0;
    
    Rect() = default;
    Rect(float x, float y, float w, float h) : x(x), y(y), width(w), height(h) { }
    
    bool contains(const Vec2& point) const {
        return point.x >= x && point.x <= x + width &&
               point.y >= y && point.y <= y + height;
    }
    
    bool intersects(const Rect& other) const {
        return x < other.x + other.width && x + width > other.x &&
               y < other.y + other.height && y + height > other.y;
    }
    
    Vec2 center() const { return {x + width / 2, y + height / 2}; }
};

struct Color {
    uint8_t r = 255, g = 255, b = 255, a = 255;
    
    Color() = default;
    Color(uint8_t r, uint8_t g, uint8_t b, uint8_t a = 255) 
        : r(r), g(g), b(b), a(a) { }
    
    static Color white() { return {255, 255, 255}; }
    static Color black() { return {0, 0, 0}; }
    static Color red() { return {255, 0, 0}; }
    static Color green() { return {0, 255, 0}; }
    static Color blue() { return {0, 0, 255}; }
};

} // namespace engine
```

### 2.2 实体组件系统

```cpp
// include/engine/ecs.hpp
#pragma once

#include "math.hpp"
#include <vector>
#include <memory>
#include <unordered_map>
#include <typeindex>
#include <functional>

namespace engine {

using EntityId = uint32_t;

// 组件基类
struct Component {
    virtual ~Component() = default;
};

// 常用组件
struct Transform : Component {
    Vec2 position;
    float rotation = 0;
    Vec2 scale{1, 1};
};

struct Sprite : Component {
    std::string texture;
    Rect srcRect;
    Color color{255, 255, 255, 255};
    int layer = 0;
};

struct RigidBody : Component {
    Vec2 velocity;
    Vec2 acceleration;
    float mass = 1.0f;
    float drag = 0.0f;
    bool isStatic = false;
};

struct BoxCollider : Component {
    Rect bounds;
    bool isTrigger = false;
};

struct Script : Component {
    std::function<void(EntityId, float)> onUpdate;
    std::function<void(EntityId, EntityId)> onCollision;
};

// 实体
class Entity {
public:
    Entity(EntityId id) : id_(id), active_(true) { }
    
    EntityId id() const { return id_; }
    bool isActive() const { return active_; }
    void setActive(bool active) { active_ = active; }
    
    template<typename T, typename... Args>
    T& addComponent(Args&&... args) {
        auto component = std::make_unique<T>(std::forward<Args>(args)...);
        T& ref = *component;
        components_[std::type_index(typeid(T))] = std::move(component);
        return ref;
    }
    
    template<typename T>
    T* getComponent() {
        auto it = components_.find(std::type_index(typeid(T)));
        if (it != components_.end()) {
            return static_cast<T*>(it->second.get());
        }
        return nullptr;
    }
    
    template<typename T>
    bool hasComponent() const {
        return components_.count(std::type_index(typeid(T))) > 0;
    }
    
    template<typename T>
    void removeComponent() {
        components_.erase(std::type_index(typeid(T)));
    }

private:
    EntityId id_;
    bool active_;
    std::unordered_map<std::type_index, std::unique_ptr<Component>> components_;
};

// 世界
class World {
public:
    Entity& createEntity() {
        EntityId id = nextId_++;
        entities_.push_back(std::make_unique<Entity>(id));
        return *entities_.back();
    }
    
    void destroyEntity(EntityId id) {
        entities_.erase(
            std::remove_if(entities_.begin(), entities_.end(),
                [id](const auto& e) { return e->id() == id; }),
            entities_.end()
        );
    }
    
    Entity* getEntity(EntityId id) {
        for (auto& entity : entities_) {
            if (entity->id() == id) {
                return entity.get();
            }
        }
        return nullptr;
    }
    
    template<typename... Components>
    std::vector<Entity*> query() {
        std::vector<Entity*> result;
        for (auto& entity : entities_) {
            if (entity->isActive() && (entity->hasComponent<Components>() && ...)) {
                result.push_back(entity.get());
            }
        }
        return result;
    }
    
    const std::vector<std::unique_ptr<Entity>>& entities() const { return entities_; }

private:
    std::vector<std::unique_ptr<Entity>> entities_;
    EntityId nextId_ = 0;
};

} // namespace engine
```

### 2.3 游戏循环

```cpp
// include/engine/engine.hpp
#pragma once

#include "ecs.hpp"
#include "renderer.hpp"
#include "input.hpp"
#include "physics.hpp"
#include <chrono>
#include <string>

namespace engine {

class Game {
public:
    Game(const std::string& title, int width, int height);
    virtual ~Game();
    
    void run();
    void quit();
    
    // 生命周期
    virtual void onCreate() { }
    virtual void onUpdate(float deltaTime) { }
    virtual void onRender() { }
    virtual void onDestroy() { }
    
    // 访问器
    World& world() { return world_; }
    Renderer& renderer() { return *renderer_; }
    Input& input() { return *input_; }
    Physics& physics() { return *physics_; }
    
    int width() const { return width_; }
    int height() const { return height_; }

protected:
    std::string title_;
    int width_;
    int height_;
    bool running_;
    
    World world_;
    std::unique_ptr<Renderer> renderer_;
    std::unique_ptr<Input> input_;
    std::unique_ptr<Physics> physics_;
};

} // namespace engine
```

### 2.4 引擎实现

```cpp
// src/engine.cpp
#include "engine/engine.hpp"
#include <iostream>
#include <thread>

namespace engine {

Game::Game(const std::string& title, int width, int height)
    : title_(title), width_(width), height_(height), running_(false) {
    
    renderer_ = std::make_unique<Renderer>(width, height);
    input_ = std::make_unique<Input>();
    physics_ = std::make_unique<Physics>();
}

Game::~Game() {
    onDestroy();
}

void Game::run() {
    onCreate();
    running_ = true;
    
    using Clock = std::chrono::high_resolution_clock;
    auto lastTime = Clock::now();
    
    const float targetFPS = 60.0f;
    const float targetFrameTime = 1.0f / targetFPS;
    
    while (running_) {
        auto currentTime = Clock::now();
        float deltaTime = std::chrono::duration<float>(currentTime - lastTime).count();
        lastTime = currentTime;
        
        // 输入处理
        input_->update();
        
        if (input_->isKeyPressed(Key::Escape)) {
            quit();
        }
        
        // 物理更新
        physics_->update(world_, deltaTime);
        
        // 脚本更新
        for (auto* entity : world_.query<Script>()) {
            auto* script = entity->getComponent<Script>();
            if (script->onUpdate) {
                script->onUpdate(entity->id(), deltaTime);
            }
        }
        
        // 用户更新
        onUpdate(deltaTime);
        
        // 渲染
        renderer_->clear();
        
        // 渲染精灵
        auto sprites = world_.query<Transform, Sprite>();
        std::sort(sprites.begin(), sprites.end(), 
            [](Entity* a, Entity* b) {
                return a->getComponent<Sprite>()->layer < 
                       b->getComponent<Sprite>()->layer;
            });
        
        for (auto* entity : sprites) {
            auto* transform = entity->getComponent<Transform>();
            auto* sprite = entity->getComponent<Sprite>();
            
            renderer_->drawSprite(*transform, *sprite);
        }
        
        onRender();
        
        renderer_->present();
        
        // 帧率控制
        auto frameTime = std::chrono::duration<float>(Clock::now() - currentTime).count();
        if (frameTime < targetFrameTime) {
            std::this_thread::sleep_for(
                std::chrono::duration<float>(targetFrameTime - frameTime));
        }
    }
}

void Game::quit() {
    running_ = false;
}

} // namespace engine
```

---

## 3. 渲染系统

### 3.1 渲染器

```cpp
// include/engine/renderer.hpp
#pragma once

#include "math.hpp"
#include "ecs.hpp"
#include <string>
#include <unordered_map>

namespace engine {

class Renderer {
public:
    Renderer(int width, int height);
    ~Renderer();
    
    void clear(const Color& color = Color::black());
    void present();
    
    // 基本绘制
    void drawRect(const Rect& rect, const Color& color);
    void drawFilledRect(const Rect& rect, const Color& color);
    void drawLine(const Vec2& start, const Vec2& end, const Color& color);
    void drawCircle(const Vec2& center, float radius, const Color& color);
    
    // 精灵绘制
    void drawSprite(const Transform& transform, const Sprite& sprite);
    
    // 文本
    void drawText(const std::string& text, const Vec2& position, 
                  const Color& color = Color::white());
    
    // 纹理管理
    void loadTexture(const std::string& name, const std::string& path);
    void unloadTexture(const std::string& name);
    
    // 相机
    void setCamera(const Vec2& position, float zoom = 1.0f);
    Vec2 screenToWorld(const Vec2& screenPos);
    Vec2 worldToScreen(const Vec2& worldPos);

private:
    int width_;
    int height_;
    Vec2 cameraPosition_;
    float cameraZoom_;
    
    // 纹理缓存 (实际实现需要图形 API)
    std::unordered_map<std::string, int> textures_;
};

} // namespace engine
```

### 3.2 渲染实现

```cpp
// src/renderer.cpp
#include "engine/renderer.hpp"
#include <iostream>

namespace engine {

Renderer::Renderer(int width, int height)
    : width_(width), height_(height), cameraZoom_(1.0f) {
    // 初始化图形 API (SDL, OpenGL, etc.)
    std::cout << "Renderer initialized: " << width << "x" << height << std::endl;
}

Renderer::~Renderer() {
    // 清理资源
}

void Renderer::clear(const Color& color) {
    // 清屏
}

void Renderer::present() {
    // 显示
}

void Renderer::drawRect(const Rect& rect, const Color& color) {
    // 绘制矩形边框
    std::cout << "Draw rect: " << rect.x << ", " << rect.y 
              << ", " << rect.width << ", " << rect.height << std::endl;
}

void Renderer::drawFilledRect(const Rect& rect, const Color& color) {
    // 绘制填充矩形
}

void Renderer::drawLine(const Vec2& start, const Vec2& end, const Color& color) {
    // 绘制线段
}

void Renderer::drawCircle(const Vec2& center, float radius, const Color& color) {
    // 绘制圆形
}

void Renderer::drawSprite(const Transform& transform, const Sprite& sprite) {
    // 计算屏幕位置
    Vec2 screenPos = worldToScreen(transform.position);
    
    // 绘制精灵
    Rect destRect{
        screenPos.x - sprite.srcRect.width * transform.scale.x / 2,
        screenPos.y - sprite.srcRect.height * transform.scale.y / 2,
        sprite.srcRect.width * transform.scale.x,
        sprite.srcRect.height * transform.scale.y
    };
    
    // 实际渲染 (需要图形 API)
}

void Renderer::drawText(const std::string& text, const Vec2& position, 
                        const Color& color) {
    // 绘制文本
}

void Renderer::loadTexture(const std::string& name, const std::string& path) {
    // 加载纹理
    textures_[name] = textures_.size();
    std::cout << "Loaded texture: " << name << " from " << path << std::endl;
}

void Renderer::unloadTexture(const std::string& name) {
    textures_.erase(name);
}

void Renderer::setCamera(const Vec2& position, float zoom) {
    cameraPosition_ = position;
    cameraZoom_ = zoom;
}

Vec2 Renderer::screenToWorld(const Vec2& screenPos) {
    return (screenPos - Vec2{width_ / 2.0f, height_ / 2.0f}) / cameraZoom_ + cameraPosition_;
}

Vec2 Renderer::worldToScreen(const Vec2& worldPos) {
    return (worldPos - cameraPosition_) * cameraZoom_ + Vec2{width_ / 2.0f, height_ / 2.0f};
}

} // namespace engine
```

---

## 4. 物理系统

### 4.1 物理引擎

```cpp
// include/engine/physics.hpp
#pragma once

#include "ecs.hpp"
#include <vector>
#include <functional>

namespace engine {

struct Collision {
    EntityId entityA;
    EntityId entityB;
    Vec2 normal;
    float depth;
};

class Physics {
public:
    Physics();
    
    void update(World& world, float deltaTime);
    
    void setGravity(const Vec2& gravity) { gravity_ = gravity; }
    Vec2 gravity() const { return gravity_; }
    
    // 碰撞回调
    using CollisionCallback = std::function<void(const Collision&)>;
    void onCollision(CollisionCallback callback) { collisionCallback_ = callback; }

private:
    void integrateVelocities(World& world, float deltaTime);
    void detectCollisions(World& world);
    void resolveCollisions(World& world);
    
    bool checkCollision(Entity* a, Entity* b, Collision& collision);
    
    Vec2 gravity_{0, 9.8f};
    std::vector<Collision> collisions_;
    CollisionCallback collisionCallback_;
};

} // namespace engine
```

### 4.2 物理实现

```cpp
// src/physics.cpp
#include "engine/physics.hpp"
#include <algorithm>

namespace engine {

Physics::Physics() { }

void Physics::update(World& world, float deltaTime) {
    integrateVelocities(world, deltaTime);
    detectCollisions(world);
    resolveCollisions(world);
}

void Physics::integrateVelocities(World& world, float deltaTime) {
    for (auto* entity : world.query<Transform, RigidBody>()) {
        auto* transform = entity->getComponent<Transform>();
        auto* body = entity->getComponent<RigidBody>();
        
        if (body->isStatic) continue;
        
        // 应用重力
        body->acceleration += gravity_;
        
        // 应用阻力
        body->velocity *= (1.0f - body->drag * deltaTime);
        
        // 更新速度
        body->velocity += body->acceleration * deltaTime;
        
        // 更新位置
        transform->position += body->velocity * deltaTime;
        
        // 重置加速度
        body->acceleration = Vec2{0, 0};
    }
}

void Physics::detectCollisions(World& world) {
    collisions_.clear();
    
    auto entities = world.query<Transform, BoxCollider>();
    
    for (size_t i = 0; i < entities.size(); ++i) {
        for (size_t j = i + 1; j < entities.size(); ++j) {
            Collision collision;
            if (checkCollision(entities[i], entities[j], collision)) {
                collisions_.push_back(collision);
            }
        }
    }
}

bool Physics::checkCollision(Entity* a, Entity* b, Collision& collision) {
    auto* transformA = a->getComponent<Transform>();
    auto* colliderA = a->getComponent<BoxCollider>();
    auto* transformB = b->getComponent<Transform>();
    auto* colliderB = b->getComponent<BoxCollider>();
    
    Rect rectA{
        transformA->position.x + colliderA->bounds.x,
        transformA->position.y + colliderA->bounds.y,
        colliderA->bounds.width,
        colliderA->bounds.height
    };
    
    Rect rectB{
        transformB->position.x + colliderB->bounds.x,
        transformB->position.y + colliderB->bounds.y,
        colliderB->bounds.width,
        colliderB->bounds.height
    };
    
    if (!rectA.intersects(rectB)) {
        return false;
    }
    
    // 计算碰撞信息
    collision.entityA = a->id();
    collision.entityB = b->id();
    
    Vec2 centerA = rectA.center();
    Vec2 centerB = rectB.center();
    Vec2 diff = centerB - centerA;
    
    float overlapX = (rectA.width + rectB.width) / 2 - std::abs(diff.x);
    float overlapY = (rectA.height + rectB.height) / 2 - std::abs(diff.y);
    
    if (overlapX < overlapY) {
        collision.normal = Vec2{diff.x > 0 ? 1.0f : -1.0f, 0};
        collision.depth = overlapX;
    } else {
        collision.normal = Vec2{0, diff.y > 0 ? 1.0f : -1.0f};
        collision.depth = overlapY;
    }
    
    return true;
}

void Physics::resolveCollisions(World& world) {
    for (const auto& collision : collisions_) {
        Entity* entityA = world.getEntity(collision.entityA);
        Entity* entityB = world.getEntity(collision.entityB);
        
        if (!entityA || !entityB) continue;
        
        auto* colliderA = entityA->getComponent<BoxCollider>();
        auto* colliderB = entityB->getComponent<BoxCollider>();
        
        // 触发器不解析碰撞
        if (colliderA->isTrigger || colliderB->isTrigger) {
            if (collisionCallback_) {
                collisionCallback_(collision);
            }
            continue;
        }
        
        auto* bodyA = entityA->getComponent<RigidBody>();
        auto* bodyB = entityB->getComponent<RigidBody>();
        auto* transformA = entityA->getComponent<Transform>();
        auto* transformB = entityB->getComponent<Transform>();
        
        // 分离物体
        float totalMass = 0;
        if (bodyA && !bodyA->isStatic) totalMass += bodyA->mass;
        if (bodyB && !bodyB->isStatic) totalMass += bodyB->mass;
        
        if (totalMass > 0) {
            if (bodyA && !bodyA->isStatic) {
                float ratio = bodyA->mass / totalMass;
                transformA->position -= collision.normal * collision.depth * ratio;
            }
            if (bodyB && !bodyB->isStatic) {
                float ratio = bodyB->mass / totalMass;
                transformB->position += collision.normal * collision.depth * ratio;
            }
        }
        
        // 速度响应
        if (bodyA && bodyB) {
            Vec2 relativeVel = bodyB->velocity - bodyA->velocity;
            float velAlongNormal = relativeVel.dot(collision.normal);
            
            if (velAlongNormal > 0) continue;
            
            float restitution = 0.5f;
            float impulse = -(1 + restitution) * velAlongNormal;
            impulse /= 1.0f / bodyA->mass + 1.0f / bodyB->mass;
            
            Vec2 impulseVec = collision.normal * impulse;
            
            if (!bodyA->isStatic) {
                bodyA->velocity -= impulseVec / bodyA->mass;
            }
            if (!bodyB->isStatic) {
                bodyB->velocity += impulseVec / bodyB->mass;
            }
        }
        
        // 调用脚本回调
        auto* scriptA = entityA->getComponent<Script>();
        auto* scriptB = entityB->getComponent<Script>();
        
        if (scriptA && scriptA->onCollision) {
            scriptA->onCollision(collision.entityA, collision.entityB);
        }
        if (scriptB && scriptB->onCollision) {
            scriptB->onCollision(collision.entityB, collision.entityA);
        }
        
        if (collisionCallback_) {
            collisionCallback_(collision);
        }
    }
}

} // namespace engine
```

---

## 5. 完整示例

### 5.1 简单游戏

```cpp
// examples/game.cpp
#include "engine/engine.hpp"
#include <iostream>

class MyGame : public engine::Game {
public:
    MyGame() : Game("My Game", 800, 600) { }
    
    void onCreate() override {
        std::cout << "Game created!" << std::endl;
        
        // 设置物理
        physics().setGravity({0, 500});
        
        // 创建玩家
        auto& player = world().createEntity();
        auto& transform = player.addComponent<engine::Transform>();
        transform.position = {400, 300};
        
        auto& sprite = player.addComponent<engine::Sprite>();
        sprite.texture = "player";
        sprite.srcRect = {0, 0, 32, 32};
        sprite.color = engine::Color::blue();
        
        auto& body = player.addComponent<engine::RigidBody>();
        body.mass = 1.0f;
        body.drag = 0.1f;
        
        auto& collider = player.addComponent<engine::BoxCollider>();
        collider.bounds = {-16, -16, 32, 32};
        
        auto& script = player.addComponent<engine::Script>();
        script.onUpdate = [this](engine::EntityId id, float dt) {
            auto* entity = world().getEntity(id);
            auto* body = entity->getComponent<engine::RigidBody>();
            
            float speed = 300.0f;
            
            if (input().isKeyDown(engine::Key::Left)) {
                body->velocity.x = -speed;
            } else if (input().isKeyDown(engine::Key::Right)) {
                body->velocity.x = speed;
            }
            
            if (input().isKeyPressed(engine::Key::Space)) {
                body->velocity.y = -400;
            }
        };
        
        playerId_ = player.id();
        
        // 创建地面
        auto& ground = world().createEntity();
        auto& groundTransform = ground.addComponent<engine::Transform>();
        groundTransform.position = {400, 550};
        
        auto& groundSprite = ground.addComponent<engine::Sprite>();
        groundSprite.srcRect = {0, 0, 800, 50};
        groundSprite.color = engine::Color::green();
        
        auto& groundBody = ground.addComponent<engine::RigidBody>();
        groundBody.isStatic = true;
        
        auto& groundCollider = ground.addComponent<engine::BoxCollider>();
        groundCollider.bounds = {-400, -25, 800, 50};
        
        // 创建障碍物
        for (int i = 0; i < 5; ++i) {
            auto& obstacle = world().createEntity();
            auto& t = obstacle.addComponent<engine::Transform>();
            t.position = {100.0f + i * 150.0f, 450.0f};
            
            auto& s = obstacle.addComponent<engine::Sprite>();
            s.srcRect = {0, 0, 40, 40};
            s.color = engine::Color::red();
            
            auto& b = obstacle.addComponent<engine::RigidBody>();
            b.mass = 0.5f;
            
            auto& c = obstacle.addComponent<engine::BoxCollider>();
            c.bounds = {-20, -20, 40, 40};
        }
    }
    
    void onUpdate(float deltaTime) override {
        // 相机跟随玩家
        auto* player = world().getEntity(playerId_);
        if (player) {
            auto* transform = player->getComponent<engine::Transform>();
            renderer().setCamera(transform->position);
        }
    }
    
    void onRender() override {
        // 绘制 UI
        renderer().drawText("WASD to move, Space to jump", {10, 10});
    }
    
    void onDestroy() override {
        std::cout << "Game destroyed!" << std::endl;
    }

private:
    engine::EntityId playerId_;
};

int main() {
    MyGame game;
    game.run();
    return 0;
}
```

---

## 6. 总结

### 6.1 引擎组件

| 组件 | 功能 |
|------|------|
| ECS | 实体组件系统 |
| Renderer | 2D 渲染 |
| Physics | 物理模拟 |
| Input | 输入处理 |

### 6.2 扩展方向

```
可扩展功能:
- 音频系统
- 粒子系统
- 动画系统
- UI 系统
- 场景管理
- 资源打包
- 脚本系统 (Lua)
- 网络同步
```

### 6.3 系列完结

恭喜你完成了 C++ 从入门到精通系列的全部 62 篇文章!

**学习路径回顾:**
- Part 1-2: C++ 基础和面向对象
- Part 3-4: 内存管理和 STL
- Part 5-6: 现代 C++ 和并发编程
- Part 7-8: 网络编程和系统优化
- Part 9-10: 工程实践和项目实战

**下一步建议:**
1. 深入学习感兴趣的领域
2. 参与开源项目
3. 阅读优秀代码
4. 持续实践

---

> 作者: C++ 技术专栏  
> 系列: 项目实战 (4/4)  
> 上一篇: [数据库引擎](./61-database-engine.md)  
> 系列完结
