<c:set var="pageTitle" value="Đã hoàn thành" /><c:set var="nav" value="history" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container">
  <div class="page-head">
    <h1>Món đã hoàn thành</h1>
    <p>50 món gần nhất, kèm thời gian làm và giờ khách hẹn để đối chiếu.</p>
  </div>

  <div class="card pad0 table-wrap">
    <table>
      <thead>
        <tr><th>Món</th><th>Đơn</th><th class="center">SL</th><th>Người làm</th>
            <th>Bắt đầu</th><th>Xong lúc</th><th>Giờ hẹn</th><th>Đúng hẹn</th></tr>
      </thead>
      <tbody>
        <c:forEach var="item" items="${recentReady}">
          <tr>
            <td>${item.productNameSnapshot}</td>
            <td>#${item.orderId}</td>
            <td class="center">${item.quantity}</td>
            <td class="small">${item.assignedToName}</td>
            <td class="small muted">${ff:time(item.startedAt)}</td>
            <td class="small muted">${ff:time(item.readyAt)}</td>
            <td class="small">
              <c:choose>
                <c:when test="${empty item.pickupTime}"><span class="muted">Tại quầy</span></c:when>
                <c:otherwise>${ff:time(item.pickupTime)}</c:otherwise>
              </c:choose>
            </td>
            <td>
              <c:choose>
                <c:when test="${empty item.pickupTime}"><span class="tag tag-muted">—</span></c:when>
                <c:when test="${item.readyAt le item.pickupTime}"><span class="tag tag-green">Đúng hẹn</span></c:when>
                <c:otherwise><span class="tag tag-red">Trễ</span></c:otherwise>
              </c:choose>
            </td>
          </tr>
        </c:forEach>
        <c:if test="${empty recentReady}">
          <tr><td colspan="8" class="center muted" style="padding:26px;">Chưa có món nào hoàn thành.</td></tr>
        </c:if>
      </tbody>
    </table>
  </div>
</main>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
