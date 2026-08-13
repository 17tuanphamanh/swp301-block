<c:set var="pageTitle" value="${product.name}" /><c:set var="nav" value="menu" />
<c:set var="mainClass" value="container medium" />
<%@ include file="/WEB-INF/views/layout/page-start.jspf" %>
  <p class="small mb"><a href="${ctx}/menu">← Quay lại thực đơn</a></p>

  <%@ include file="/WEB-INF/views/layout/flash.jspf" %>

  <div class="card grid grid-2">
    <c:choose>
      <c:when test="${not empty product.imageUrl}">
        <img class="thumb thumb-lg thumb-img" src="<c:out value="${product.imageUrl}"/>" alt=""
             loading="lazy" referrerpolicy="no-referrer" data-fallback="🍔">
      </c:when>
      <c:otherwise>
        <div class="thumb thumb-lg" aria-hidden="true">🍔</div>
      </c:otherwise>
    </c:choose>
    <div class="stack">
      <span class="tag tag-muted"><c:out value="${product.categoryName}"/></span>
      <h1><c:out value="${product.name}"/></h1>
      <p class="muted"><c:out value="${product.description}"/></p>
      <div class="price price-lg">
        ${ff:money(product.price)}
      </div>

      <c:choose>
        <c:when test="${not product.orderable}">
          <div class="alert alert-warn flush">Món này hiện không còn phục vụ.</div>
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
<%@ include file="/WEB-INF/views/layout/page-end.jspf" %>
