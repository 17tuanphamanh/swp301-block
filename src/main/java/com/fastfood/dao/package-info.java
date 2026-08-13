/**
 * Tầng truy cập dữ liệu. Mỗi lớp phụ trách một bảng, chỉ chứa câu lệnh SQL, không chứa
 * quy tắc nghiệp vụ. Mọi phương thức nhận sẵn Connection để tầng Service gom nhiều thao tác
 * vào chung một giao dịch.
 * <p>
 * Các phương thức đổi trạng thái gộp điều kiện kiểm tra vào chính câu lệnh cập nhật và trả về
 * số dòng bị ảnh hưởng — đây là cách chống trùng lặp khi nhiều luồng cùng chạy.
 */
package com.fastfood.dao;
