package com.k8s.demo.orderservice.controller;

import org.springframework.web.bind.annotation.*;
import org.springframework.http.ResponseEntity;
import java.util.*;

@RestController
@RequestMapping("/api/orders")
@CrossOrigin(origins = "*")
public class OrderController {

    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "healthy");
        response.put("service", "order-service");
        response.put("timestamp", new Date());
        return ResponseEntity.ok(response);
    }

    @GetMapping
    public ResponseEntity<List<Map<String, Object>>> getAllOrders() {
        List<Map<String, Object>> orders = new ArrayList<>();
        
        // Sample data
        Map<String, Object> order1 = new HashMap<>();
        order1.put("id", 1);
        order1.put("userId", 1);
        order1.put("productId", 1);
        order1.put("quantity", 2);
        order1.put("status", "completed");
        order1.put("total", 29.98);
        orders.add(order1);

        Map<String, Object> order2 = new HashMap<>();
        order2.put("id", 2);
        order2.put("userId", 2);
        order2.put("productId", 2);
        order2.put("quantity", 1);
        order2.put("status", "pending");
        order2.put("total", 19.99);
        orders.add(order2);

        return ResponseEntity.ok(orders);
    }

    @GetMapping("/{id}")
    public ResponseEntity<Map<String, Object>> getOrder(@PathVariable Long id) {
        Map<String, Object> order = new HashMap<>();
        order.put("id", id);
        order.put("userId", 1);
        order.put("productId", 1);
        order.put("quantity", 2);
        order.put("status", "completed");
        order.put("total", 29.98);
        return ResponseEntity.ok(order);
    }

    @PostMapping
    public ResponseEntity<Map<String, Object>> createOrder(@RequestBody Map<String, Object> orderData) {
        Map<String, Object> response = new HashMap<>();
        response.put("id", new Random().nextInt(1000));
        response.put("status", "created");
        response.put("message", "Order created successfully");
        response.putAll(orderData);
        return ResponseEntity.ok(response);
    }
}
