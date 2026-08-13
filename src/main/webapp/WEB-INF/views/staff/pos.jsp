<c:set var="pageTitle" value="Bán tại quầy" /><c:set var="nav" value="pos" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container">
  <div class="page-head">
    <h1>Bán tại quầy</h1>
    <p>Khách đứng đợi tại chỗ. Thu tiền xong đơn xuống bếp ngay, không cần mã nhận hàng.</p>
  </div>

  <jsp:include page="/WEB-INF/views/layout/flash.jsp"/>

  <div class="grid grid-side">
    <div>
      <div class="card">
        <form method="get" action="${ctx}/staff/pos" class="form-row">
          <div class="field">
            <label for="keyword">Tìm món</label>
            <input type="search" id="keyword" name="keyword" value="${keyword}" placeholder="Tên món...">
          </div>
          <div class="field">
            <label for="categoryId">Nhóm món</label>
            <select id="categoryId" name="categoryId">
              <option value="">Tất cả</option>
              <c:forEach var="cat" items="${categories}">
                <option value="${cat.categoryId}" ${selectedCategory eq cat.categoryId ? 'selected' : ''}>${cat.name}</option>
              </c:forEach>
            </select>
          </div>
          <button type="submit" class="btn btn-primary">Lọc</button>
        </form>
      </div>

      <div class="menu-grid">
        <c:forEach var="p" items="${products}">
          <form method="post" action="${ctx}/staff/pos" class="product">
            <input type="hidden" name="action" value="add">
            <input type="hidden" name="productId" value="${p.productId}">
            <div class="body">
              <span class="tag tag-muted">${p.categoryName}</span>
              <div class="name">${p.name}</div>
              <div class="price">${ff:money(p.price)}</div>
            </div>
            <div class="foot">
              <button type="submit" class="btn btn-primary btn-block btn-sm">Thêm</button>
            </div>
          </form>
        </c:forEach>
      </div>
    </div>

    <div class="card">
      <div class="row-between mb">
        <h2>Phiếu tính tiền</h2>
        <c:if test="${not empty posLines}">
          <form method="post" action="${ctx}/staff/pos" class="inline-form">
            <input type="hidden" name="action" value="clear">
            <button type="submit" class="btn btn-sm btn-danger">Xoá hết</button>
          </form>
        </c:if>
      </div>

      <c:choose>
        <c:when test="${empty posLines}">
          <div class="empty"><div class="icon">🧾</div>Chưa chọn món nào.</div>
        </c:when>
        <c:otherwise>
          <c:forEach var="line" items="${posLines}">
            <div class="total-line" style="align-items:center;">
              <div>
                <div>${line[0].name}</div>
                <div class="small muted">${ff:money(line[0].price)} × ${line[1]}</div>
              </div>
              <div style="display:flex; gap:5px; align-items:center;">
                <form method="post" action="${ctx}/staff/pos" style="display:flex; gap:4px;">
                  <input type="hidden" name="action" value="setQty">
                  <input type="hidden" name="productId" value="${line[0].productId}">
                  <input type="number" name="quantity" value="${line[1]}" min="0" max="99"
                         style="width:58px; text-align:center;" onchange="this.form.submit()">
                </form>
                <span style="min-width:76px; text-align:right;">${ff:money(line[2])}</span>
              </div>
            </div>
          </c:forEach>

          <div class="total-line grand">
            <span>Tổng cộng</span>
            <span>${ff:money(posTotal)}</span>
          </div>

          <h3 class="mt">Thu tiền</h3>
          <div class="stack">
            <form method="post" action="${ctx}/staff/pos">
              <input type="hidden" name="action" value="pay">
              <input type="hidden" name="method" value="CASH">
              <button type="submit" class="btn btn-green btn-block">Khách trả tiền mặt</button>
            </form>
            <form method="post" action="${ctx}/staff/pos">
              <input type="hidden" name="action" value="pay">
              <input type="hidden" name="method" value="ONLINE_GATEWAY">
              <button type="submit" class="btn btn-blue btn-block">Khách quét mã QR</button>
            </form>
          </div>
        </c:otherwise>
      </c:choose>
    </div>
  </div>
</main>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
