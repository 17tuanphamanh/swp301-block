package com.fastfood.model.entity;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * Món ăn.
 * Hai cột trạng thái tách riêng: {@code status} là còn kinh doanh hay đã ngừng bán,
 * {@code available} là còn hàng trong ngày hay không.
 */
public class Product {
    private int productId;
    private int categoryId;
    private String name;
    private String description;
    private BigDecimal price;
    private String imageUrl;
    private boolean available;
    private String status;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    private String categoryName;

    public int getProductId() { return productId; }
    public void setProductId(int productId) { this.productId = productId; }

    public int getCategoryId() { return categoryId; }
    public void setCategoryId(int categoryId) { this.categoryId = categoryId; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public BigDecimal getPrice() { return price; }
    public void setPrice(BigDecimal price) { this.price = price; }

    public String getImageUrl() { return imageUrl; }
    public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }

    public boolean isAvailable() { return available; }
    public void setAvailable(boolean available) { this.available = available; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }

    public String getCategoryName() { return categoryName; }
    public void setCategoryName(String categoryName) { this.categoryName = categoryName; }

    /** Món chỉ đặt được khi vừa còn kinh doanh vừa còn hàng. */
    public boolean isOrderable() { return "ACTIVE".equals(status) && available; }
}
