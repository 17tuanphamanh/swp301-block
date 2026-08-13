package com.fastfood.testsupport;

import com.fastfood.config.AppConfig;
import com.fastfood.config.DBContext;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;
import java.util.Properties;

/**
 * Dựng lại database test từ chính file schema của dự án.
 * <p>
 * Chạy <b>một lần</b> cho cả lượt test, không phải mỗi lớp: dựng lại schema mất vài giây, và
 * các bài test được viết sao cho không giẫm lên nhau (mỗi bài tự tạo dữ liệu của mình, hoặc
 * chỉ đọc dữ liệu mẫu).
 * <p>
 * Dùng đúng file {@code database/FastFoodPreorder.sql} mà người chấm sẽ chạy, chứ không chép
 * ra một bản riêng cho test. Chép ra bản riêng thì hai bản lệch nhau lúc nào không ai biết,
 * và bộ test sẽ xanh trên một schema không tồn tại ở đâu cả.
 */
public final class TestDatabase {

    private static final String SCHEMA_FILE = "database/FastFoodPreorder.sql";

    private static boolean prepared;
    private static boolean available;
    private static String unavailableReason;

    private TestDatabase() {
    }

    /**
     * Bảo đảm database test đã sẵn sàng.
     *
     * @return true nếu dùng được; false nghĩa là máy chạy test không có SQL Server và
     *         các bài test tích hợp nên tự bỏ qua thay vì báo đỏ
     */
    public static synchronized boolean ensureReady() {
        if (prepared) {
            return available;
        }
        prepared = true;
        try {
            AppConfig.init();
            rebuild();
            available = true;
        } catch (Exception e) {
            available = false;
            unavailableReason = e.getClass().getSimpleName() + ": " + e.getMessage();
        }
        return available;
    }

    public static String unavailableReason() {
        return unavailableReason == null ? "khong ro" : unavailableReason;
    }

    // ------------------------------------------------------------------ dựng lại

    private static void rebuild() throws Exception {
        Properties p = loadTestProperties();
        String targetDb = databaseNameOf(p.getProperty("db.url"));

        // Pool cũ còn giữ kết nối tới database sắp bị dựng lại thì lệnh ALTER DATABASE
        // trong script sẽ chờ vô hạn. Đóng pool trước, mở lại sau.
        DBContext.shutdown();

        String script = Files.readString(projectFile(SCHEMA_FILE), StandardCharsets.UTF_8)
                // Script gốc thao tác trên database thật; test chạy trên bản sao có hậu tố _Test
                .replace("FastFoodPreorder", targetDb);

        // Nối vào master: script tự CREATE DATABASE rồi USE sang database đích, nên phải
        // dùng CHUNG một kết nối cho toàn bộ các lô lệnh — USE không có tác dụng xuyên kết nối.
        String masterUrl = p.getProperty("db.url").replace("databaseName=" + targetDb, "databaseName=master");
        Class.forName(p.getProperty("db.driver"));

        try (Connection con = DriverManager.getConnection(
                masterUrl, p.getProperty("db.username"), p.getProperty("db.password"))) {
            for (String batch : splitOnGo(script)) {
                try (Statement st = con.createStatement()) {
                    st.execute(batch);
                    // Script in ra khá nhiều kết quả kiểm tra ở cuối; đọc hết cho sạch stream
                    while (st.getMoreResults() || st.getUpdateCount() != -1) {
                        // bỏ qua nội dung, chỉ cần rút cạn
                    }
                } catch (SQLException e) {
                    throw new IllegalStateException(
                            "Loi khi chay schema test.\nLo lenh:\n" + preview(batch) + "\nLoi: " + e.getMessage(), e);
                }
            }
        }
    }

    /**
     * Tách script theo {@code GO}.
     * <p>
     * {@code GO} không phải câu lệnh SQL mà là dấu ngắt lô của công cụ dòng lệnh; JDBC không
     * hiểu nó. Chỉ nhận dòng nào <i>chỉ có mỗi</i> chữ GO, để không cắt nhầm chữ GO nằm trong
     * chuỗi hay trong lời chú thích.
     */
    private static List<String> splitOnGo(String script) {
        List<String> batches = new ArrayList<>();
        StringBuilder current = new StringBuilder();
        for (String line : script.split("\r?\n")) {
            if (line.trim().equalsIgnoreCase("GO")) {
                addIfMeaningful(batches, current);
                current.setLength(0);
            } else {
                current.append(line).append('\n');
            }
        }
        addIfMeaningful(batches, current);
        return batches;
    }

    private static void addIfMeaningful(List<String> batches, StringBuilder sb) {
        String batch = sb.toString().trim();
        if (!batch.isEmpty()) {
            batches.add(batch);
        }
    }

    private static String preview(String batch) {
        return batch.length() <= 400 ? batch : batch.substring(0, 400) + " ...";
    }

    // ------------------------------------------------------------------ tiện ích

    private static Properties loadTestProperties() throws IOException {
        Properties p = new Properties();
        try (InputStream in = TestDatabase.class.getClassLoader().getResourceAsStream("db.properties")) {
            if (in == null) {
                throw new IllegalStateException("Khong tim thay db.properties trong classpath test");
            }
            p.load(in);
        }
        return p;
    }

    private static String databaseNameOf(String jdbcUrl) {
        for (String part : jdbcUrl.split(";")) {
            if (part.startsWith("databaseName=")) {
                return part.substring("databaseName=".length());
            }
        }
        throw new IllegalStateException("db.url thieu databaseName: " + jdbcUrl);
    }

    /**
     * Tìm file trong thư mục gốc dự án.
     * <p>
     * Thư mục làm việc lúc chạy test tuỳ công cụ: Maven đặt ở gốc dự án, một số IDE đặt ở nơi
     * khác. Đi ngược lên cho tới khi thấy {@code pom.xml} thì chắc chắn đúng gốc.
     */
    private static Path projectFile(String relative) {
        Path dir = Path.of("").toAbsolutePath();
        while (dir != null && !Files.exists(dir.resolve("pom.xml"))) {
            dir = dir.getParent();
        }
        if (dir == null) {
            throw new IllegalStateException("Khong tim thay thu muc goc du an (khong thay pom.xml)");
        }
        Path file = dir.resolve(relative);
        if (!Files.exists(file)) {
            throw new IllegalStateException("Khong tim thay " + file);
        }
        return file;
    }
}
