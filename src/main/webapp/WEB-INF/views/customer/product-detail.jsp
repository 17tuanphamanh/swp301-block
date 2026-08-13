<c:set var="pageTitle" value="${product.name}" /><c:set var="nav" value="menu" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container medium">
  <p class="small mb"><a href="${ctx}/menu">← Quay lại thực đơn</a></p>

  <jsp:include page="/WEB-INF/views/layout/flash.jsp"/>

  <div class="card grid grid-2">
    <div class="thumb" style="height:200px; border-radius:8px; background:linear-gradient(135deg,#fff1f0,#fef6ec);
         display:flex; align-items:center; justify-content:center; font-size:60px;">🍔</div>
    <div class="stack">
      <span class="tag tag-muted">${product.categoryName}</span>
      <h1>${product.name}</h1>
      <p class="muted">${product.description}</p>
      <div class="price" style="font-size:24px; font-weight:700; color:var(--brand);">
        ${ff:money(product.price)}
      </div>

      <c:choose>
        <c:when test="${not product.orderable}">
          <div class="alert alert-warn" style="margin:0;">Món này hiện không còn phục vụ.</div>
        </c:when>
        <c:when test="${empty me}">
          <a class="btn btn-primary" href="${ctx}/login">Đăng nhập để đặt món</a>
        </c:when>
        <c:when test="${me.roleName ne 'CUSTOMER'}">
          <p class="small muted">Tài khoản nhân viên không dùng giỏ hàng của khách.</p>
        </c:when>
        <c:otherwise>
          <form method="post" action="${ctx}/cart" class="stack">
            <input type="hidden" name="action" value="add">
            <input type="hidden" name="productId" value="${product.productId}">
            <input type="hidden" name="returnTo" value="/cart">
            <div class="field">
              <label for="quantity">Số lượng</label>
              <input type="number" id="quantity" name="quantity" value="1" min="1" max="50">
            </div>
            <button type="submit" class="btn btn-primary">Thêm vào giỏ hàng</button>
          </form>
        </c:otherwise>
      </c:choose>
    </div>
  </div>
</main>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
