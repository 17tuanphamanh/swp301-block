package com.fastfood.common.util;

import org.mindrot.jbcrypt.BCrypt;

/**
 * Băm và kiểm tra mật khẩu bằng bcrypt.
 * <p>
 * Không bao giờ lưu mật khẩu gốc. Cost 10 là mức cân bằng giữa an toàn và tốc độ đăng nhập.
 * jBCrypt chỉ đọc được tiền tố {@code $2$} và {@code $2a$} — hash sinh bằng htpasswd ra
 * {@code $2y$} phải đổi tiền tố trước khi đưa vào cơ sở dữ liệu.
 */
public final class PasswordUtil {

    private static final int COST = 10;

    private PasswordUtil() {
    }

    public static String hash(String rawPassword) {
        return BCrypt.hashpw(rawPassword, BCrypt.gensalt(COST));
    }

    /** Trả về false thay vì ném lỗi khi hash trong DB bị hỏng định dạng. */
    public static boolean matches(String rawPassword, String hash) {
        if (rawPassword == null || hash == null || hash.isBlank()) {
            return false;
        }
        try {
            return BCrypt.checkpw(rawPassword, hash);
        } catch (IllegalArgumentException e) {
            return false;
        }
    }
}
