package com.fastfood.config;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

/**
 * Đè tài khoản SQL Server lên cấu hình đọc từ {@code db.properties}, để mật khẩu không phải nằm trong git.
 * <p>
 * Thứ tự ưu tiên, nguồn sau thắng nguồn trước:
 * <ol>
 *   <li>{@code db.properties} (có trong git, không chứa mật khẩu thật)</li>
 *   <li>{@code db.local.properties} trên classpath (đã nằm trong .gitignore)</li>
 *   <li>Biến môi trường {@code DB_USERNAME}, {@code DB_PASSWORD}</li>
 * </ol>
 * Chỉ tài khoản được đè, {@code db.url} thì không: bộ test xoá và dựng lại toàn bộ bảng,
 * nên nếu một biến môi trường đổi được URL thì test có thể chạy nhầm vào database đang phát triển.
 */
public final class DbCredentials {

    private static final String[][] KEYS = {
        {"db.username", "DB_USERNAME"},
        {"db.password", "DB_PASSWORD"},
    };

    private DbCredentials() {
    }

    public static Properties apply(Properties p) {
        Properties local = new Properties();
        try (InputStream in = DbCredentials.class.getClassLoader().getResourceAsStream("db.local.properties")) {
            if (in != null) {
                local.load(in);
            }
        } catch (IOException e) {
            throw new IllegalStateException("Khong doc duoc db.local.properties", e);
        }
        for (String[] k : KEYS) {
            String fromFile = local.getProperty(k[0]);
            if (fromFile != null && !fromFile.isEmpty()) {
                p.setProperty(k[0], fromFile);
            }
            String fromEnv = System.getenv(k[1]);
            if (fromEnv != null && !fromEnv.isEmpty()) {
                p.setProperty(k[0], fromEnv);
            }
        }
        return p;
    }
}
