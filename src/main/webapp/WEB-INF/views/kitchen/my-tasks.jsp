<c:set var="pageTitle" value="Việc của tôi" /><c:set var="nav" value="tasks" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container">
  <div class="page-head row-between">
    <div>
      <h1>Việc của tôi</h1>
      <p>Món cuối cùng của đơn được đánh dấu xong sẽ tự báo cho khách.</p>
    </div>
    <a class="btn" href="${ctx}/kitchen/queue">Về hàng chờ</a>
  </div>

  <jsp:include page="/WEB-INF/views/layout/flash.jsp"/>

  <c:choose>
    <c:when test="${empty myTasks}">
      <div class="card empty">
        <div class="icon">☕</div>
        Bạn chưa nhận món nào.
        <div class="mt"><a class="btn btn-primary" href="${ctx}/kitchen/queue">Xem hàng chờ</a></div>
      </div>
    </c:when>
    <c:otherwise>
      <div class="kds-grid">
        <c:forEach var="v" items="${myTasks}">
          <div class="kds-card ${v.late ? 'late' : (v.urgent ? 'urgent' : (v.online ? 'online' : 'pos'))}">
            <div class="row-between">
              <span class="tag tag-amber">Đang làm</span>
              <span class="qty">×${v.item.quantity}</span>
            </div>
            <div class="title mt">${v.item.productNameSnapshot}</div>
            <div class="meta">
              <span>Đơn #${v.item.orderId}</span>
              <span>${v.pickupLabel}</span>
            </div>
            <div class="small muted mt">Bắt đầu lúc ${ff:time(v.item.startedAt)}</div>
            <div class="actions">
              <form method="post" action="${ctx}/kitchen/my-tasks" style="flex:1;">
                <input type="hidden" name="orderItemId" value="${v.item.orderItemId}">
                <input type="hidden" name="returnTo" value="/kitchen/my-tasks">
                <button type="submit" class="btn btn-green btn-block btn-sm">Đã làm xong</button>
              </form>
              <a class="btn btn-sm" href="${ctx}/kitchen/issue?orderItemId=${v.item.orderItemId}">Báo sự cố</a>
            </div>
          </div>
        </c:forEach>
      </div>
    </c:otherwise>
  </c:choose>
</main>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
