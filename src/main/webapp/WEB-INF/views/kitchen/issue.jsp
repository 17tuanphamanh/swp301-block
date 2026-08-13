<c:set var="pageTitle" value="Sự cố bếp" /><c:set var="nav" value="issue" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container">
  <div class="page-head">
    <h1>Sự cố bếp</h1>
    <p>Ghi nhận sự cố không làm món quay về hàng chờ — món vẫn thuộc về người đang làm.</p>
  </div>

  <jsp:include page="/WEB-INF/views/layout/flash.jsp"/>

  <div class="grid grid-side">
    <div>
      <div class="card pad0 table-wrap">
        <div class="card-head"><h2>Đang mở (${fn:length(openIssues)})</h2></div>
        <table>
          <thead><tr><th>Món</th><th>Đơn</th><th>Loại</th><th>Mô tả</th><th>Người báo</th><th></th></tr></thead>
          <tbody>
            <c:forEach var="i" items="${openIssues}">
              <tr>
                <td>${i.productName}</td>
                <td>#${i.orderId}</td>
                <td><span class="tag tag-red">${ff:issueType(i.issueType)}</span></td>
                <td class="small">${i.description}</td>
                <td class="small muted">${i.createdByName}<br>${ff:time(i.createdAt)}</td>
                <td class="center">
                  <form method="post" action="${ctx}/kitchen/issue" class="inline-form">
                    <input type="hidden" name="action" value="resolve">
                    <input type="hidden" name="issueId" value="${i.issueId}">
                    <button type="submit" class="btn btn-sm btn-green">Đã xử lý</button>
                  </form>
                </td>
              </tr>
            </c:forEach>
            <c:if test="${empty openIssues}">
              <tr><td colspan="6" class="center muted" style="padding:26px;">Không có sự cố nào đang mở.</td></tr>
            </c:if>
          </tbody>
        </table>
      </div>

      <div class="card pad0 table-wrap">
        <div class="card-head"><h2>Đã xử lý gần đây</h2></div>
        <table>
          <thead><tr><th>Thời điểm</th><th>Món</th><th>Loại</th><th>Trạng thái</th></tr></thead>
          <tbody>
            <c:forEach var="i" items="${recentIssues}">
              <c:if test="${not i.open}">
                <tr>
                  <td class="small muted">${ff:dateTime(i.createdAt)}</td>
                  <td>${i.productName}</td>
                  <td>${ff:issueType(i.issueType)}</td>
                  <td><span class="tag tag-green">Đã xử lý</span></td>
                </tr>
              </c:if>
            </c:forEach>
          </tbody>
        </table>
      </div>
    </div>

    <div class="card">
      <h2>Báo sự cố mới</h2>
      <form method="post" action="${ctx}/kitchen/issue">
        <div class="field">
          <label for="orderItemId">Mã món cần báo</label>
          <input type="number" id="orderItemId" name="orderItemId"
                 value="${orderItemId > 0 ? orderItemId : ''}" required>
          <p class="small muted mt">Lấy từ màn hình chi tiết món.</p>
        </div>
        <div class="field">
          <label for="issueType">Loại sự cố</label>
          <select id="issueType" name="issueType" required>
            <option value="OUT_OF_STOCK">Hết nguyên liệu</option>
            <option value="QUALITY">Chất lượng không đạt</option>
            <option value="REMAKE">Phải làm lại</option>
            <option value="OTHER">Khác</option>
          </select>
        </div>
        <div class="field">
          <label for="description">Mô tả</label>
          <textarea id="description" name="description" placeholder="Mô tả ngắn gọn..."></textarea>
        </div>
        <button type="submit" class="btn btn-primary btn-block">Ghi nhận sự cố</button>
      </form>
    </div>
  </div>
</main>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
