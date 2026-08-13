<c:set var="pageTitle" value="Nhật ký" /><c:set var="nav" value="audit" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container">
  <div class="page-head">
    <h1>Nhật ký thao tác</h1>
    <p>Mọi việc liên quan tới tiền và trạng thái đơn đều để lại dấu vết ở đây.</p>
  </div>

  <jsp:include page="/WEB-INF/views/layout/flash.jsp"/>

  <div class="card">
    <form method="get" action="${ctx}/admin/audit" class="form-row">
      <div class="field">
        <label for="entityType">Đối tượng</label>
        <select id="entityType" name="entityType">
          <option value="">Tất cả</option>
          <c:forEach var="t" items="${['ORDER','ORDER_ITEM','PAYMENT','PRODUCT','CATEGORY','USER','KITCHEN_ISSUE']}">
            <option value="${t}" ${entityType eq t ? 'selected' : ''}>${t}</option>
          </c:forEach>
        </select>
      </div>
      <div class="field">
        <label for="action">Thao tác</label>
        <select id="action" name="action">
          <option value="">Tất cả</option>
          <c:forEach var="a" items="${actions}">
            <option value="${a}" ${param.action eq a ? 'selected' : ''}>${ff:auditAction(a)}</option>
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
      <a class="btn" href="${ctx}/admin/audit">Bỏ lọc</a>
    </form>
  </div>

  <div class="card pad0 table-wrap">
    <div class="card-head"><h2>Bản ghi (${fn:length(logs)})</h2></div>
    <table>
      <thead>
        <tr><th>Thời điểm</th><th>Đối tượng</th><th>Mã</th><th>Thao tác</th>
            <th>Người thực hiện</th><th>Thay đổi</th></tr>
      </thead>
      <tbody>
        <c:forEach var="log" items="${logs}">
          <tr>
            <td class="small muted">${ff:dateTime(log.createdAt)}</td>
            <td class="small">${log.entityType}</td>
            <td class="small">
              <c:choose>
                <c:when test="${log.entityType eq 'ORDER'}">
                  <a href="${ctx}/staff/order/detail?orderId=${log.entityId}">#${log.entityId}</a>
                </c:when>
                <c:otherwise>${log.entityId}</c:otherwise>
              </c:choose>
            </td>
            <td>${ff:auditAction(log.action)}</td>
            <td class="small">${log.actorDisplay}</td>
            <td class="small muted">
              <c:if test="${not empty log.oldValue}">${log.oldValue} → </c:if>${log.newValue}
            </td>
          </tr>
        </c:forEach>
        <c:if test="${empty logs}">
          <tr><td colspan="6" class="center muted" style="padding:26px;">Không có bản ghi nào khớp bộ lọc.</td></tr>
        </c:if>
      </tbody>
    </table>
  </div>
</main>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
