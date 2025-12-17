---
title: "第41章：Spring Boot 整合 RabbitMQ"
description: "Spring Boot 通过 `spring-boot-starter-amqp` 提供了对 RabbitMQ 的自动配置支持，大大简化了开发。"
pubDate: "2025-12-17"
tags: ["rabbitmq","mq","backend"]
category: "rabbitmq"
series: "RabbitMQ 消息队列"
order: 41
---

## 41.1 概述

Spring Boot 通过 `spring-boot-starter-amqp` 提供了对 RabbitMQ 的自动配置支持，大大简化了开发。

### 核心组件

| 组件 | 说明 |
|------|------|
| `RabbitTemplate` | 发送消息的模板类 |
| `@RabbitListener` | 消息监听注解 |
| `RabbitAdmin` | 管理交换器、队列、绑定 |
| `MessageConverter` | 消息转换器 |

---

## 41.2 项目搭建

### Maven 依赖

```xml
<dependencies>
    <!-- Spring Boot Starter AMQP -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-amqp</artifactId>
    </dependency>
    
    <!-- Spring Boot Starter Web -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    
    <!-- JSON 支持 -->
    <dependency>
        <groupId>com.fasterxml.jackson.core</groupId>
        <artifactId>jackson-databind</artifactId>
    </dependency>
    
    <!-- Lombok (可选) -->
    <dependency>
        <groupId>org.projectlombok</groupId>
        <artifactId>lombok</artifactId>
        <optional>true</optional>
    </dependency>
</dependencies>
```

### application.yml

```yaml
spring:
  rabbitmq:
    host: localhost
    port: 5672
    username: admin
    password: admin123
    virtual-host: /
    
    # 发布确认
    publisher-confirm-type: correlated
    publisher-returns: true
    
    # 消费者配置
    listener:
      simple:
        # 手动确认
        acknowledge-mode: manual
        # 并发消费者数量
        concurrency: 3
        max-concurrency: 10
        # 预取数量
        prefetch: 1
        # 重试配置
        retry:
          enabled: true
          initial-interval: 1000
          max-attempts: 3
          max-interval: 10000
          multiplier: 2

# 自定义配置
rabbitmq:
  exchange:
    direct: direct.exchange
    topic: topic.exchange
    fanout: fanout.exchange
  queue:
    order: order.queue
    payment: payment.queue
  routing-key:
    order: order.routing.key
    payment: payment.routing.key
```

---

## 41.3 配置类

### RabbitMQ 配置

```java
package com.example.config;

import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitMQConfig {

    @Value("${rabbitmq.exchange.direct}")
    private String directExchange;

    @Value("${rabbitmq.exchange.topic}")
    private String topicExchange;

    @Value("${rabbitmq.queue.order}")
    private String orderQueue;

    @Value("${rabbitmq.queue.payment}")
    private String paymentQueue;

    @Value("${rabbitmq.routing-key.order}")
    private String orderRoutingKey;

    // ==================== 消息转换器 ====================
    
    @Bean
    public MessageConverter jsonMessageConverter() {
        return new Jackson2JsonMessageConverter();
    }

    @Bean
    public RabbitTemplate rabbitTemplate(ConnectionFactory connectionFactory,
                                         MessageConverter messageConverter) {
        RabbitTemplate template = new RabbitTemplate(connectionFactory);
        template.setMessageConverter(messageConverter);
        
        // 发布确认回调
        template.setConfirmCallback((correlationData, ack, cause) -> {
            if (ack) {
                System.out.println("Message confirmed: " + correlationData);
            } else {
                System.err.println("Message not confirmed: " + cause);
            }
        });
        
        // 消息返回回调
        template.setReturnsCallback(returned -> {
            System.err.println("Message returned: " + returned.getMessage());
            System.err.println("Reply code: " + returned.getReplyCode());
            System.err.println("Reply text: " + returned.getReplyText());
        });
        
        return template;
    }

    // ==================== 交换器 ====================
    
    @Bean
    public DirectExchange directExchange() {
        return new DirectExchange(directExchange, true, false);
    }

    @Bean
    public TopicExchange topicExchange() {
        return new TopicExchange(topicExchange, true, false);
    }

    @Bean
    public FanoutExchange fanoutExchange() {
        return new FanoutExchange("fanout.exchange", true, false);
    }

    // ==================== 队列 ====================
    
    @Bean
    public Queue orderQueue() {
        return QueueBuilder
            .durable(orderQueue)
            .withArgument("x-message-ttl", 60000)  // 消息过期时间
            .build();
    }

    @Bean
    public Queue paymentQueue() {
        return QueueBuilder
            .durable(paymentQueue)
            .build();
    }

    // ==================== 绑定 ====================
    
    @Bean
    public Binding orderBinding() {
        return BindingBuilder
            .bind(orderQueue())
            .to(directExchange())
            .with(orderRoutingKey);
    }

    @Bean
    public Binding paymentBinding() {
        return BindingBuilder
            .bind(paymentQueue())
            .to(topicExchange())
            .with("payment.#");
    }
}
```

### 死信队列配置

```java
@Configuration
public class DeadLetterConfig {

    public static final String DLX_EXCHANGE = "dlx.exchange";
    public static final String DLQ_QUEUE = "dlq.queue";
    public static final String BUSINESS_QUEUE = "business.queue";

    @Bean
    public DirectExchange dlxExchange() {
        return new DirectExchange(DLX_EXCHANGE, true, false);
    }

    @Bean
    public Queue dlqQueue() {
        return new Queue(DLQ_QUEUE, true);
    }

    @Bean
    public Binding dlqBinding() {
        return BindingBuilder.bind(dlqQueue()).to(dlxExchange()).with("dlq");
    }

    @Bean
    public Queue businessQueue() {
        return QueueBuilder
            .durable(BUSINESS_QUEUE)
            .withArgument("x-dead-letter-exchange", DLX_EXCHANGE)
            .withArgument("x-dead-letter-routing-key", "dlq")
            .build();
    }
}
```

---

## 41.4 消息实体

```java
package com.example.model;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class OrderMessage implements Serializable {
    
    private String orderId;
    private String userId;
    private String productId;
    private Integer quantity;
    private BigDecimal amount;
    private String status;
    private LocalDateTime createTime;
}
```

---

## 41.5 生产者服务

```java
package com.example.producer;

import com.example.model.OrderMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.connection.CorrelationData;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class OrderProducer {

    private final RabbitTemplate rabbitTemplate;

    @Value("${rabbitmq.exchange.direct}")
    private String exchange;

    @Value("${rabbitmq.routing-key.order}")
    private String routingKey;

    /**
     * 发送订单消息
     */
    public void sendOrder(OrderMessage order) {
        String correlationId = UUID.randomUUID().toString();
        CorrelationData correlationData = new CorrelationData(correlationId);
        
        log.info("Sending order message: {}, correlationId: {}", order.getOrderId(), correlationId);
        
        rabbitTemplate.convertAndSend(exchange, routingKey, order, correlationData);
    }

    /**
     * 发送延迟消息
     */
    public void sendDelayedOrder(OrderMessage order, long delayMs) {
        rabbitTemplate.convertAndSend(
            "delayed.exchange",
            "delayed.routing.key",
            order,
            message -> {
                message.getMessageProperties().setDelay((int) delayMs);
                return message;
            }
        );
        log.info("Sent delayed order: {}, delay: {}ms", order.getOrderId(), delayMs);
    }

    /**
     * 发送到 Topic 交换器
     */
    public void sendToTopic(String routingKey, Object message) {
        rabbitTemplate.convertAndSend("topic.exchange", routingKey, message);
        log.info("Sent to topic with routing key: {}", routingKey);
    }

    /**
     * 发送到 Fanout 交换器
     */
    public void broadcast(Object message) {
        rabbitTemplate.convertAndSend("fanout.exchange", "", message);
        log.info("Broadcast message sent");
    }
}
```

---

## 41.6 消费者服务

```java
package com.example.consumer;

import com.example.model.OrderMessage;
import com.rabbitmq.client.Channel;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.amqp.support.AmqpHeaders;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Component;

import java.io.IOException;

@Slf4j
@Component
public class OrderConsumer {

    /**
     * 简单消费者
     */
    @RabbitListener(queues = "${rabbitmq.queue.order}")
    public void handleOrder(@Payload OrderMessage order,
                            @Header(AmqpHeaders.DELIVERY_TAG) long deliveryTag,
                            Channel channel) throws IOException {
        try {
            log.info("Received order: {}", order.getOrderId());
            
            // 处理订单业务逻辑
            processOrder(order);
            
            // 手动确认
            channel.basicAck(deliveryTag, false);
            log.info("Order processed successfully: {}", order.getOrderId());
            
        } catch (Exception e) {
            log.error("Error processing order: {}", order.getOrderId(), e);
            
            // 拒绝消息，不重新入队（进入死信队列）
            channel.basicNack(deliveryTag, false, false);
        }
    }

    /**
     * 监听多个队列
     */
    @RabbitListener(queues = {"queue1", "queue2"})
    public void handleMultipleQueues(Message message, Channel channel) throws IOException {
        String queue = message.getMessageProperties().getConsumerQueue();
        log.info("Received from queue: {}, message: {}", queue, new String(message.getBody()));
        channel.basicAck(message.getMessageProperties().getDeliveryTag(), false);
    }

    /**
     * 使用 @RabbitListener 声明队列和绑定
     */
    @RabbitListener(bindings = @org.springframework.amqp.rabbit.annotation.QueueBinding(
        value = @org.springframework.amqp.rabbit.annotation.Queue(
            value = "auto.declared.queue",
            durable = "true"
        ),
        exchange = @org.springframework.amqp.rabbit.annotation.Exchange(
            value = "auto.declared.exchange",
            type = "topic"
        ),
        key = "auto.#"
    ))
    public void handleAutoDeclared(String message) {
        log.info("Received auto declared: {}", message);
    }

    /**
     * 死信队列消费者
     */
    @RabbitListener(queues = "dlq.queue")
    public void handleDeadLetter(Message message, Channel channel) throws IOException {
        log.warn("Received dead letter: {}", new String(message.getBody()));
        
        // 记录日志、发送告警等
        // ...
        
        channel.basicAck(message.getMessageProperties().getDeliveryTag(), false);
    }

    private void processOrder(OrderMessage order) {
        // 业务处理逻辑
        log.info("Processing order: {} for user: {}", order.getOrderId(), order.getUserId());
        
        // 模拟处理时间
        try {
            Thread.sleep(100);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
```

---

## 41.7 Controller

```java
package com.example.controller;

import com.example.model.OrderMessage;
import com.example.producer.OrderProducer;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@RestController
@RequestMapping("/api/orders")
@RequiredArgsConstructor
public class OrderController {

    private final OrderProducer orderProducer;

    @PostMapping
    public String createOrder(@RequestBody OrderMessage order) {
        order.setOrderId(UUID.randomUUID().toString().substring(0, 8));
        order.setStatus("PENDING");
        order.setCreateTime(LocalDateTime.now());
        
        orderProducer.sendOrder(order);
        
        return "Order created: " + order.getOrderId();
    }

    @PostMapping("/delayed")
    public String createDelayedOrder(@RequestBody OrderMessage order,
                                     @RequestParam(defaultValue = "30000") long delayMs) {
        order.setOrderId(UUID.randomUUID().toString().substring(0, 8));
        order.setStatus("PENDING");
        order.setCreateTime(LocalDateTime.now());
        
        orderProducer.sendDelayedOrder(order, delayMs);
        
        return "Delayed order created: " + order.getOrderId() + ", delay: " + delayMs + "ms";
    }

    @PostMapping("/broadcast")
    public String broadcast(@RequestBody String message) {
        orderProducer.broadcast(message);
        return "Message broadcasted";
    }

    @GetMapping("/test")
    public String test() {
        OrderMessage order = new OrderMessage();
        order.setOrderId(UUID.randomUUID().toString().substring(0, 8));
        order.setUserId("user001");
        order.setProductId("product001");
        order.setQuantity(1);
        order.setAmount(new BigDecimal("99.99"));
        order.setStatus("PENDING");
        order.setCreateTime(LocalDateTime.now());
        
        orderProducer.sendOrder(order);
        
        return "Test order sent: " + order.getOrderId();
    }
}
```

---

## 41.8 消息幂等性

```java
@Slf4j
@Component
@RequiredArgsConstructor
public class IdempotentOrderConsumer {

    private final RedisTemplate<String, String> redisTemplate;

    @RabbitListener(queues = "order.queue")
    public void handleOrder(@Payload OrderMessage order,
                            @Header(AmqpHeaders.DELIVERY_TAG) long deliveryTag,
                            @Header(AmqpHeaders.MESSAGE_ID) String messageId,
                            Channel channel) throws IOException {
        
        String idempotentKey = "order:processed:" + messageId;
        
        try {
            // 检查是否已处理
            Boolean isNew = redisTemplate.opsForValue()
                .setIfAbsent(idempotentKey, "1", Duration.ofHours(24));
            
            if (Boolean.FALSE.equals(isNew)) {
                log.warn("Duplicate message ignored: {}", messageId);
                channel.basicAck(deliveryTag, false);
                return;
            }
            
            // 处理订单
            processOrder(order);
            
            channel.basicAck(deliveryTag, false);
            
        } catch (Exception e) {
            log.error("Error processing order", e);
            // 删除幂等键，允许重试
            redisTemplate.delete(idempotentKey);
            channel.basicNack(deliveryTag, false, true);
        }
    }
}
```

---

## 41.9 测试

```java
@SpringBootTest
class OrderProducerTest {

    @Autowired
    private OrderProducer orderProducer;

    @Test
    void testSendOrder() {
        OrderMessage order = new OrderMessage();
        order.setOrderId("test-001");
        order.setUserId("user001");
        order.setProductId("product001");
        order.setQuantity(1);
        order.setAmount(new BigDecimal("99.99"));
        order.setStatus("PENDING");
        order.setCreateTime(LocalDateTime.now());

        orderProducer.sendOrder(order);
        
        // 等待消息被消费
        Thread.sleep(1000);
    }
}
```

---

## 41.10 本章小结

| 注解/类 | 说明 |
|---------|------|
| `@RabbitListener` | 消息监听器 |
| `RabbitTemplate` | 消息发送模板 |
| `@Payload` | 消息体 |
| `@Header` | 消息头 |
| `Channel` | 用于手动确认 |
| `CorrelationData` | 发布确认关联数据 |

---

**下一章**: [Python Pika 实战](../42-python-pika/README.md)
