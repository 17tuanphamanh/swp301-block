<c:set var="pageTitle" value="Đơn hàng" /><c:set var="nav" value="orders" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container">
  <div class="page-head"><h1>Đơn hàng</h1></div>

  <jsp:include page="/WEB-INF/views/layout/flash.jsp"/>

  <div class="tabs">
    <a href="${ctx}/staff/orders?tab=POS" class="${tab eq 'POS' ? 'active' : ''}">
      Tại quầy <span class="count">${countPos}</span></a>
    <a href="${ctx}/staff/orders?tab=SCHEDULED" class="${tab eq 'SCHEDULED' ? 'active' : ''}">
      Đặt trước chờ tới giờ <span class="count">${countScheduled}</span></a>
    <a href="${ctx}/staff/orders?tab=READY" class="${tab eq 'READY' ? 'active' : ''}">
      Chờ khách tới lấy <span class="count">${countReady}</span></a>
    <a href="${ctx}/staff/orders?tab=OVERDUE" class="${tab eq 'OVERDUE' ? 'active' : ''}">
      Khách đến muộn <span class="count">${countOverdue}</span></a>
  </div>

  <c:if test="${tab eq 'SCHEDULED'}">
    <div class="alert alert-info">
      Các đơn này đã thanh toán nhưng cố ý chưa đưa xuống bếp. Hệ thống sẽ tự đưa xuống
      trước giờ hẹn để món ra đúng lúc khách tới.
    </div>
  </c:if>
  <c:if test="${tab eq 'OVERDUE'}">
    <div class="alert alert-warn">
      Khách đã quá giờ hẹn mà chưa tới lấy. Đơn vẫn được giữ nguyên — hệ thống không tự huỷ
      cũng không tự hoàn tiền vì khách đã trả tiền trước.
    </div>
  </c:if>

  <div class="card pad0 table-wrap">
    <c:choose>
      <c:when test="${empty orders}">
        <div class="empty"><div class="icon">✅</div>Không có đơn nào trong mục này.</div>
      </c:when>
      <c:otherwise>
        <table>
          <thead>
            <tr><th>Mã đơn</th><th>Kênh</th><th>Khách</th><th>Giờ hẹn</th>
                <th>Bếp</th><th class="num">Tổng tiền</th><th>Trạng thái</th><th></th></tr>
          </thead>
          <tbody>
            <c:forEach var="o" items="${orders}">
              <tr>
                <td><strong>#${o.orderId}</strong>
                  <c:if test="${not empty o.pickupCode}">
                    <div class="mono small muted">${o.pickupCode}</div>
                  </c:if>
                </td>
                <td><span class="tag ${o.online ? 'tag-info' : 'tag-muted'}">${ff:orderSource(o.orderSource)}</span></td>
                <td class="small">${empty o.customerName ? 'Khách tại quầy' : o.customerName}</td>
                <td class="small">
                  <c:choose>
                    <c:when test="${o.online}">
                      ${ff:time(o.pickupTime)}
                      <div class="muted">${ff:humanize(o.pickupTime)}</div>
                    </c:when>
                    <c:otherwise><span class="muted">—</span></c:otherwise>
                  </c:choose>
                </td>
                <td class="small">${ff:releaseState(o.releaseState)}</td>
                <td class="num">${ff:money(o.totalAmount)}</td>
                <td>
                  <span class="${ff:orderStatusClass(o.orderStatus)}">${ff:orderStatus(o.orderStatus)}</span>
                  <c:if test="${o.overdue}"><div><span class="tag tag-red">Đến muộn</span></div></c:if>
                </td>
                <td class="center">
                  <a class="btn btn-sm btn-primary" href="${ctx}/staff/order/detail?orderId=${o.orderId}">Mở</a>
                </td>
              </tr>
            </c:forEach>
          </tbody>
        </table>
      </c:otherwise>
    </c:choose>
  </div>
</main>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
