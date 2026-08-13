<c:set var="pageTitle" value="Hàng chờ bếp" /><c:set var="nav" value="queue" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container">
  <div class="page-head row-between">
    <div>
      <h1>Hàng chờ</h1>
      <p>Chỉ hiện món của đơn đã tới lượt làm. Đơn đặt trước chưa tới giờ chưa xuất hiện ở đây.</p>
    </div>
    <a class="btn" href="${ctx}/kitchen/my-tasks">Việc của tôi (${fn:length(myTasks)})</a>
  </div>

  <jsp:include page="/WEB-INF/views/layout/flash.jsp"/>

  <c:choose>
    <c:when test="${empty queue}">
      <div class="card empty">
        <div class="icon">👨‍🍳</div>
        Không còn món nào chờ làm.
      </div>
    </c:when>
    <c:otherwise>
      <div class="kds-grid">
        <c:forEach var="v" items="${queue}">
          <div class="kds-card ${v.late ? 'late' : (v.urgent ? 'urgent' : (v.online ? 'online' : 'pos'))}">
            <div class="row-between">
              <span class="tag ${v.online ? 'tag-info' : 'tag-muted'}">
                ${v.online ? 'Đặt trước' : 'Tại quầy'}
              </span>
              <span class="qty">×${v.item.quantity}</span>
            </div>
            <div class="title mt">${v.item.productNameSnapshot}</div>
            <div class="meta">
              <span>Đơn #${v.item.orderId}</span>
              <span class="${v.late ? 'tag tag-red' : (v.urgent ? 'tag tag-amber' : '')}">
                ${v.pickupLabel}
              </span>
            </div>
            <c:if test="${v.openIssueCount > 0}">
              <div class="mt"><span class="tag tag-red">${v.openIssueCount} sự cố đang mở</span></div>
            </c:if>
            <div class="actions">
              <form method="post" action="${ctx}/kitchen/queue" style="flex:1;">
                <input type="hidden" name="orderItemId" value="${v.item.orderItemId}">
                <button type="submit" class="btn btn-primary btn-block btn-sm">Nhận món này</button>
              </form>
              <a class="btn btn-sm" href="${ctx}/kitchen/item?id=${v.item.orderItemId}">Chi tiết</a>
            </div>
          </div>
        </c:forEach>
      </div>
    </c:otherwise>
  </c:choose>
</main>

<%--
  Tự làm mới danh sách. Món mới xuống bếp xuất hiện sau vài giây mà đầu bếp không phải bấm gì —
  quan trọng vì trong bếp thường không rảnh tay để thao tác.
--%>
<script>
  var lastCount = ${fn:length(queue)};
  setInterval(function () {
    fetch('${ctx}/api/kds/queue')
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (data) {
        if (data && data.queueCount !== lastCount) { location.reload(); }
      })
      .catch(function () { /* bỏ qua, thử lại ở lần sau */ });
  }, 5000);
</script>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
