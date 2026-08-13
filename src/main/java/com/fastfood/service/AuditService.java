package com.fastfood.service;

import com.fastfood.common.util.DateTimeUtil;
import com.fastfood.dao.AuditLogDAO;
import com.fastfood.model.entity.AuditLog;

import java.sql.Connection;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.util.List;

/**
 * Ghi nhật ký thao tác.
 * <p>
 * Mọi phương thức đều nhận sẵn {@link Connection} để bản ghi nhật ký nằm cùng giao dịch
 * với thao tác nó mô tả. Nếu tách ra thì có thể xảy ra chuyện đơn bị huỷ mà nhật ký
 * không ghi được, hoặc ngược lại.
 */
public class AuditService {

    private final AuditLogDAO auditLogDAO = new AuditLogDAO();

    public void log(Connection con, Integer actorId, String entityType, Object entityId,
                    String action, String oldValue, String newValue) throws SQLException {
        AuditLog log = new AuditLog();
        log.setActorId(actorId);
        log.setEntityType(entityType);
        log.setEntityId(String.valueOf(entityId));
        log.setAction(action);
        log.setOldValue(oldValue);
        log.setNewValue(newValue);
        log.setCreatedAt(DateTimeUtil.now());
        auditLogDAO.insert(con, log);
    }

    /** Thao tác do hệ thống tự thực hiện: bộ hẹn giờ, cổng thanh toán. */
    public void logSystem(Connection con, String entityType, Object entityId,
                          String action, String newValue) throws SQLException {
        log(con, null, entityType, entityId, action, null, newValue);
    }

    public List<AuditLog> findByEntity(String entityType, Object entityId) {
        return Tx.read(con -> auditLogDAO.findByEntity(con, entityType, String.valueOf(entityId)));
    }

    public List<AuditLog> search(String entityType, String action, LocalDateTime from,
                                 LocalDateTime to, int limit) {
        return Tx.read(con -> auditLogDAO.search(con, entityType, action, from, to, limit));
    }

    public List<String> distinctActions() {
        return Tx.read(auditLogDAO::distinctActions);
    }
}
