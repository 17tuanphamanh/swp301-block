<%--
  Thanh điều hướng. Mục hiển thị theo vai trò của người đang đăng nhập.
  Ẩn mục ở đây chỉ để giao diện gọn — quyền thật sự do bộ lọc phía máy chủ quyết định.
--%>
<header class="app-header">
  <div class="inner">
    <a class="brand" href="${ctx}/">🍔 Fast Food</a>

    <nav>
      <c:choose>
        <c:when test="${empty me or me.roleName eq 'CUSTOMER'}">
          <a href="${ctx}/menu" class="${nav eq 'menu' ? 'active' : ''}">Thực đơn</a>
          <c:if test="${not empty me}">
            <a href="${ctx}/cart" class="${nav eq 'cart' ? 'active' : ''}">Giỏ hàng</a>
            <a href="${ctx}/order/history" class="${nav eq 'orders' ? 'active' : ''}">Đơn của tôi</a>
          </c:if>
        </c:when>

        <c:when test="${me.roleName eq 'CASHIER'}">
          <a href="${ctx}/staff/pos" class="${nav eq 'pos' ? 'active' : ''}">Bán tại quầy</a>
          <a href="${ctx}/staff/orders" class="${nav eq 'orders' ? 'active' : ''}">Đơn hàng</a>
          <a href="${ctx}/staff/pickup/verify" class="${nav eq 'pickup' ? 'active' : ''}">Tra mã nhận hàng</a>
          <a href="${ctx}/staff/history" class="${nav eq 'history' ? 'active' : ''}">Lịch sử</a>
        </c:when>

        <c:when test="${me.roleName eq 'KITCHEN'}">
          <a href="${ctx}/kitchen/queue" class="${nav eq 'queue' ? 'active' : ''}">Hàng chờ</a>
          <a href="${ctx}/kitchen/my-tasks" class="${nav eq 'tasks' ? 'active' : ''}">Việc của tôi</a>
          <a href="${ctx}/kitchen/issue" class="${nav eq 'issue' ? 'active' : ''}">Sự cố</a>
          <a href="${ctx}/kitchen/history" class="${nav eq 'history' ? 'active' : ''}">Đã hoàn thành</a>
        </c:when>

        <c:otherwise>
          <a href="${ctx}/admin/dashboard" class="${nav eq 'dashboard' ? 'active' : ''}">Tổng quan</a>
          <a href="${ctx}/admin/products" class="${nav eq 'products' ? 'active' : ''}">Món ăn</a>
          <a href="${ctx}/admin/categories" class="${nav eq 'categories' ? 'active' : ''}">Nhóm món</a>
          <a href="${ctx}/admin/users" class="${nav eq 'users' ? 'active' : ''}">Tài khoản</a>
          <a href="${ctx}/admin/audit" class="${nav eq 'audit' ? 'active' : ''}">Nhật ký</a>
        </c:otherwise>
      </c:choose>
    </nav>

    <div class="user-box">
      <c:choose>
        <c:when test="${empty me}">
          <a class="btn btn-sm" href="${ctx}/register">Đăng ký</a>
          <a class="btn btn-sm btn-primary" href="${ctx}/login">Đăng nhập</a>
        </c:when>
        <c:otherwise>
          <span class="who">
            ${me.fullName} · <span class="tag">${ff:roleName(me.roleName)}</span>
          </span>
          <a href="${ctx}/profile" class="btn btn-sm">Tài khoản</a>
          <a href="${ctx}/logout" class="btn btn-sm">Thoát</a>
        </c:otherwise>
      </c:choose>
    </div>
  </div>
</header>
