package com.fastfood.config;

import com.fastfood.common.constant.BusinessRule;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;
import java.util.logging.Logger;

/**
 * Tham số vận hành đọc từ {@code app.properties}.
 * <p>
 * Các con số nghiệp vụ (đặt trước tối thiểu 30 phút, vào bếp trước 20 phút, hết hạn thanh toán
 * sau 15 phút) để ở file cấu hình thay vì hard-code, nhưng giá trị mặc định vẫn lấy từ
 * {@link BusinessRule} để ứng dụng chạy được ngay cả khi thiếu file.
 */
public final class AppConfig {

    private static final Logger LOG = Logger.getLogger(AppConfig.class.getName());
    private static Properties props = new Properties();

    private AppConfig() {
    }

    public static synchronized void init() {
        try (InputStream in = AppConfig.class.getClassLoader().getResourceAsStream("app.properties")) {
            if (in != null) {
                props.load(in);
                LOG.info("AppConfig: da nap app.properties");
            } else {
                LOG.warning("AppConfig: khong thay app.properties, dung gia tri mac dinh");
            }
        } catch (IOException e) {
            LOG.warning("AppConfig: loi doc app.properties, dung gia tri mac dinh - " + e.getMessage());
        }
    }

    public static String get(String key, String defaultValue) {
        return props.getProperty(key, defaultValue);
    }

    public static int getInt(String key, int defaultValue) {
        try {
            return Integer.parseInt(props.getProperty(key, String.valueOf(defaultValue)).trim());
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }

    // ----- Tham số nghiệp vụ -----

    /** Khách phải hẹn giờ lấy cách thời điểm đặt ít nhất bao nhiêu phút. */
    public static int pickupMinLeadMinutes() {
        return getInt("business.pickup.minLeadMinutes", BusinessRule.PICKUP_MIN_LEAD_MINUTES);
    }

    /** Đơn được đưa xuống bếp trước giờ hẹn bao nhiêu phút. */
    public static int kitchenPrepLeadMinutes() {
        return getInt("business.kitchen.prepLeadMinutes", BusinessRule.KITCHEN_PREP_LEAD_MINUTES);
    }

    /** Đơn chờ thanh toán quá bao nhiêu phút thì bị huỷ hiệu lực. */
    public static int paymentExpiryMinutes() {
        return getInt("business.payment.expiryMinutes", BusinessRule.PAYMENT_EXPIRY_MINUTES);
    }

    /** Quá giờ hẹn bao nhiêu phút thì đánh dấu khách đến muộn. */
    public static int pickupOverdueMinutes() {
        return getInt("business.pickup.overdueMinutes", BusinessRule.PICKUP_OVERDUE_MINUTES);
    }

    // ----- Scheduler -----

    public static int releaseIntervalSeconds() {
        return getInt("scheduler.kitchenRelease.intervalSeconds", 30);
    }

    public static int expiryIntervalSeconds() {
        return getInt("scheduler.paymentExpiry.intervalSeconds", 60);
    }

    // ----- Tích hợp ngoài -----

    public static String gatewayProvider() {
        return get("payment.gateway.provider", "MOCK");
    }

    public static String notificationChannel() {
        return get("notification.channel", "MOCK");
    }
}
