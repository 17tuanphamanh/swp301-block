<c:set var="pageTitle" value="Lịch sử" /><c:set var="nav" value="history" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container">
  <div class="page-head"><h1>Lịch sử đơn hàng</h1></div>

  <jsp:include page="/WEB-INF/views/layout/flash.jsp"/>

  <div class="card">
    <form method="get" action="${ctx}/staff/history" class="form-row">
      <div class="field">
        <label for="source">Kênh</label>
        <select id="source" name="source">
          <option value="">Tất cả</option>
          <option value="ONLINE_PREORDER" ${source eq 'ONLINE_PREORDER' ? 'selected' : ''}>Đặt trước</option>
          <option value="POS" ${source eq 'POS' ? 'selected' : ''}>Tại quầy</option>
        </select>
      </div>
      <div class="field">
        <label for="status">Trạng thái</label>
        <select id="status" name="status">
          <option value="">Tất cả</option>
          <c:forEach var="s" items="${['PENDING_PAYMENT','CONFIRMED','PREPARING','READY','COMPLETED','CANCELLED','EXPIRED']}">
            <option value="${s}" ${status eq s ? 'selected' : ''}>${ff:orderStatus(s)}</option>
          </c:forEach>
        </select>
      </div>
      <div class="field">
        <label for="from">Từ</label>
        <input type="datetime-local" id="from" name="from" value="${param.from}">
      </div>
      <div class="field">
        <label for="to">Đến</label>
        <input type="datetime-local" id="to" name="to" value="${param.to}">
      </div>
      <button type="submit" class="btn btn-primary">Lọc</button>
      <a class="btn" href="${ctx}/staff/history">Bỏ lọc</a>
    </form>
  </div>

  <div class="card pad0 table-wrap">
    <div class="card-head"><h2>Đơn hàng (${fn:length(orders)})</h2></div>
    <table>
      <thead><tr><th>Mã</th><th>Kênh</th><th>Đặt lúc</th><th>Hoàn tất</th>
                 <th class="num">Tổng tiền</th><th>Trạng thái</th><th></th></tr></thead>
      <tbody>
        <c:forEach var="o" items="${orders}">
          <tr>
            <td><strong>#${o.orderId}</strong></td>
            <td class="small">${ff:orderSource(o.orderSource)}</td>
            <td class="small muted">${ff:dateTime(o.createdAt)}</td>
            <td class="small muted">${empty o.completedAt ? '—' : ff:dateTime(o.completedAt)}</td>
            <td class="num">${ff:money(o.totalAmount)}</td>
            <td><span class="${ff:orderStatusClass(o.orderStatus)}">${ff:orderStatus(o.orderStatus)}</span></td>
            <td class="center"><a class="btn btn-sm" href="${ctx}/staff/order/detail?orderId=${o.orderId}">Xem</a></td>
          </tr>
        </c:forEach>
        <c:if test="${empty orders}">
          <tr><td colspan="7" class="center muted" style="padding:26px;">Không có đơn nào khớp bộ lọc.</td></tr>
        </c:if>
      </tbody>
    </table>
  </div>

  <div class="card pad0 table-wrap">
    <div class="card-head"><h2>Nhật ký thao tác gần đây</h2></div>
    <table>
      <thead><tr><th>Thời điểm</th><th>Đơn</th><th>Thao tác</th><th>Người thực hiện</th></tr></thead>
      <tbody>
        <c:forEach var="log" items="${auditLogs}">
          <tr>
            <td class="small muted">${ff:dateTime(log.createdAt)}</td>
            <td><a href="${ctx}/staff/order/detail?orderId=${log.entityId}">#${log.entityId}</a></td>
            <td>${ff:auditAction(log.action)}</td>
            <td class="small">${log.actorDisplay}</td>
          </tr>
        </c:forEach>
      </tbody>
    </table>
  </div>
</main>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
