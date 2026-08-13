<c:set var="pageTitle" value="Món ăn" /><c:set var="nav" value="products" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container">
  <div class="page-head">
    <h1>Món ăn</h1>
    <p>Món ngừng bán thì chuyển sang trạng thái ngừng kinh doanh, không xoá — đơn cũ vẫn cần tham chiếu tới.</p>
  </div>

  <jsp:include page="/WEB-INF/views/layout/flash.jsp"/>

  <div class="grid grid-side">
    <div>
      <div class="card">
        <form method="get" action="${ctx}/admin/products" class="form-row">
          <div class="field">
            <label for="keyword">Tìm món</label>
            <input type="search" id="keyword" name="keyword" value="${keyword}">
          </div>
          <div class="field">
            <label for="filterCategory">Nhóm món</label>
            <select id="filterCategory" name="categoryId">
              <option value="">Tất cả</option>
              <c:forEach var="cat" items="${categories}">
                <option value="${cat.categoryId}" ${selectedCategory eq cat.categoryId ? 'selected' : ''}>${cat.name}</option>
              </c:forEach>
            </select>
          </div>
          <button type="submit" class="btn btn-primary">Lọc</button>
        </form>
      </div>

      <div class="card pad0 table-wrap">
        <table>
          <thead><tr><th>Tên món</th><th>Nhóm</th><th class="num">Giá</th>
                     <th>Tình trạng</th><th>Trên thực đơn</th><th></th></tr></thead>
          <tbody>
            <c:forEach var="p" items="${products}">
              <tr>
                <td>
                  <strong>${p.name}</strong>
                  <div class="small muted">${p.description}</div>
                </td>
                <td class="small">${p.categoryName}</td>
                <td class="num">${ff:money(p.price)}</td>
                <td>
                  <form method="post" action="${ctx}/admin/products" class="inline-form">
                    <input type="hidden" name="action" value="toggle">
                    <input type="hidden" name="productId" value="${p.productId}">
                    <input type="hidden" name="available" value="${p.available ? 'false' : 'true'}">
                    <button type="submit" class="tag ${p.available ? 'tag-green' : 'tag-amber'}"
                            style="border:0; cursor:pointer;">
                      ${p.available ? 'Còn hàng' : 'Tạm hết'}
                    </button>
                  </form>
                </td>
                <td>
                  <span class="tag ${p.status eq 'ACTIVE' ? 'tag-info' : 'tag-muted'}">
                    ${p.status eq 'ACTIVE' ? 'Đang bán' : 'Ngừng bán'}
                  </span>
                </td>
                <td class="center">
                  <a class="btn btn-sm" href="${ctx}/admin/products?edit=${p.productId}">Sửa</a>
                </td>
              </tr>
            </c:forEach>
          </tbody>
        </table>
      </div>
    </div>

    <div class="card">
      <h2>${empty editing ? 'Thêm món mới' : 'Sửa món'}</h2>
      <form method="post" action="${ctx}/admin/products">
        <input type="hidden" name="productId" value="${editing.productId}">
        <div class="field">
          <label for="name">Tên món</label>
          <input type="text" id="name" name="name" value="${editing.name}" required>
        </div>
        <div class="field">
          <label for="categoryId">Nhóm món</label>
          <select id="categoryId" name="categoryId" required>
            <c:forEach var="cat" items="${categories}">
              <option value="${cat.categoryId}" ${editing.categoryId eq cat.categoryId ? 'selected' : ''}>${cat.name}</option>
            </c:forEach>
          </select>
        </div>
        <div class="field">
          <label for="price">Giá bán (đồng)</label>
          <input type="number" id="price" name="price" value="${editing.price}" min="0" step="1000" required>
        </div>
        <div class="field">
          <label for="description">Mô tả</label>
          <textarea id="description" name="description">${editing.description}</textarea>
        </div>
        <div class="field">
          <label for="imageUrl">Đường dẫn ảnh</label>
          <input type="text" id="imageUrl" name="imageUrl" value="${editing.imageUrl}">
        </div>
        <div class="field check">
          <input type="checkbox" id="available" name="available" value="true"
                 ${empty editing or editing.available ? 'checked' : ''}>
          <label for="available" style="margin:0;">Còn hàng hôm nay</label>
        </div>
        <div class="field check">
          <input type="checkbox" id="active" name="active" value="true"
                 ${empty editing or editing.status eq 'ACTIVE' ? 'checked' : ''}>
          <label for="active" style="margin:0;">Đang kinh doanh</label>
        </div>
        <button type="submit" class="btn btn-primary btn-block">
          ${empty editing ? 'Thêm món' : 'Lưu thay đổi'}
        </button>
        <c:if test="${not empty editing}">
          <a class="btn btn-block mt" href="${ctx}/admin/products">Huỷ sửa</a>
        </c:if>
      </form>
    </div>
  </div>
</main>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
