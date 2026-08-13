<c:set var="pageTitle" value="Thực đơn" /><c:set var="nav" value="menu" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container">
  <div class="page-head row-between">
    <div>
      <h1>Thực đơn</h1>
      <p>Đặt trước, chọn giờ đến lấy — món làm xong đúng lúc bạn tới.</p>
    </div>
    <c:if test="${not empty cartCount and cartCount > 0}">
      <a class="btn btn-primary" href="${ctx}/cart">Giỏ hàng (${cartCount})</a>
    </c:if>
  </div>

  <jsp:include page="/WEB-INF/views/layout/flash.jsp"/>

  <div class="card">
    <form method="get" action="${ctx}/menu" class="form-row">
      <div class="field">
        <label for="keyword">Tìm món</label>
        <input type="search" id="keyword" name="keyword" value="${keyword}" placeholder="Nhập tên món...">
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
      <a class="btn" href="${ctx}/menu">Bỏ lọc</a>
    </form>
  </div>

  <c:choose>
    <c:when test="${empty products}">
      <div class="card empty">
        <div class="icon">🍽️</div>
        Không tìm thấy món nào phù hợp.
      </div>
    </c:when>
    <c:otherwise>
      <div class="menu-grid">
        <c:forEach var="p" items="${products}">
          <div class="product">
            <div class="thumb">🍔</div>
            <div class="body">
              <span class="tag tag-muted">${p.categoryName}</span>
              <a class="name" href="${ctx}/product/detail?id=${p.productId}">${p.name}</a>
              <div class="desc">${p.description}</div>
              <div class="price">${ff:money(p.price)}</div>
            </div>
            <div class="foot">
              <c:choose>
                <c:when test="${empty me}">
                  <a class="btn btn-block" href="${ctx}/login">Đăng nhập để đặt</a>
                </c:when>
                <c:when test="${me.roleName ne 'CUSTOMER'}">
                  <a class="btn btn-block" href="${ctx}/product/detail?id=${p.productId}">Xem chi tiết</a>
                </c:when>
                <c:otherwise>
                  <form method="post" action="${ctx}/cart">
                    <input type="hidden" name="action" value="add">
                    <input type="hidden" name="productId" value="${p.productId}">
                    <input type="hidden" name="quantity" value="1">
                    <input type="hidden" name="returnTo" value="/menu">
                    <button type="submit" class="btn btn-primary btn-block">Thêm vào giỏ</button>
                  </form>
                </c:otherwise>
              </c:choose>
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
