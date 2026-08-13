<c:set var="pageTitle" value="Chi tiết món" /><c:set var="nav" value="queue" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container medium">
  <p class="small mb"><a href="${ctx}/kitchen/queue">← Hàng chờ</a></p>

  <jsp:include page="/WEB-INF/views/layout/flash.jsp"/>

  <div class="card">
    <div class="row-between mb">
      <div>
        <h1>${item.productNameSnapshot}</h1>
        <p class="small muted">Đơn #${item.orderId} · ${ff:orderSource(item.orderSource)}</p>
      </div>
      <span class="${ff:itemStatusClass(item.itemStatus)}">${ff:itemStatus(item.itemStatus)}</span>
    </div>

    <div class="grid grid-2">
      <div>
        <div class="total-line"><span class="muted">Số lượng</span><span><strong>${item.quantity}</strong></span></div>
        <div class="total-line"><span class="muted">Người làm</span>
          <span>${empty item.assignedToName ? 'Chưa có ai nhận' : item.assignedToName}</span></div>
      </div>
      <div>
        <c:if test="${not empty item.pickupTime}">
          <div class="total-line"><span class="muted">Giờ khách hẹn</span>
            <span><strong>${ff:dateTime(item.pickupTime)}</strong></span></div>
          <div class="total-line"><span class="muted">Còn lại</span>
            <span>${ff:humanize(item.pickupTime)}</span></div>
        </c:if>
        <c:if test="${not empty item.startedAt}">
          <div class="total-line"><span class="muted">Bắt đầu</span><span>${ff:time(item.startedAt)}</span></div>
        </c:if>
        <c:if test="${not empty item.readyAt}">
          <div class="total-line"><span class="muted">Hoàn thành</span><span>${ff:time(item.readyAt)}</span></div>
        </c:if>
      </div>
    </div>

    <div class="actions mt">
      <c:if test="${item.itemStatus eq 'WAITING'}">
        <form method="post" action="${ctx}/kitchen/queue">
          <input type="hidden" name="orderItemId" value="${item.orderItemId}">
          <button type="submit" class="btn btn-primary">Nhận món này</button>
        </form>
      </c:if>
      <c:if test="${item.itemStatus eq 'PREPARING'}">
        <form method="post" action="${ctx}/kitchen/my-tasks">
          <input type="hidden" name="orderItemId" value="${item.orderItemId}">
          <input type="hidden" name="returnTo" value="/kitchen/item?id=${item.orderItemId}">
          <button type="submit" class="btn btn-green">Đã làm xong</button>
        </form>
      </c:if>
      <a class="btn" href="${ctx}/kitchen/issue?orderItemId=${item.orderItemId}">Báo sự cố</a>
    </div>
  </div>

  <c:if test="${not empty issues}">
    <div class="card pad0 table-wrap">
      <div class="card-head"><h2>Sự cố của món này</h2></div>
      <table>
        <thead><tr><th>Thời điểm</th><th>Loại</th><th>Mô tả</th><th>Người báo</th><th>Trạng thái</th></tr></thead>
        <tbody>
          <c:forEach var="i" items="${issues}">
            <tr>
              <td class="small muted">${ff:dateTime(i.createdAt)}</td>
              <td>${ff:issueType(i.issueType)}</td>
              <td class="small">${i.description}</td>
              <td class="small">${i.createdByName}</td>
              <td><span class="tag ${i.open ? 'tag-red' : 'tag-green'}">${i.open ? 'Đang mở' : 'Đã xử lý'}</span></td>
            </tr>
          </c:forEach>
        </tbody>
      </table>
    </div>
  </c:if>
</main>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
