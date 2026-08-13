<c:set var="pageTitle" value="Nhóm món" /><c:set var="nav" value="categories" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container">
  <div class="page-head">
    <h1>Nhóm món</h1>
    <p>Tắt một nhóm sẽ ẩn toàn bộ món trong nhóm khỏi thực đơn — cách nhanh nhất để ngừng bán cả dòng sản phẩm.</p>
  </div>

  <jsp:include page="/WEB-INF/views/layout/flash.jsp"/>

  <div class="grid grid-side">
    <div class="card pad0 table-wrap">
      <table>
        <thead><tr><th class="center">Thứ tự</th><th>Tên nhóm</th>
                   <th class="center">Số món</th><th>Trạng thái</th><th></th></tr></thead>
        <tbody>
          <c:forEach var="cat" items="${categories}">
            <tr>
              <td class="center">${cat.displayOrder}</td>
              <td><strong>${cat.name}</strong></td>
              <td class="center">${cat.productCount}</td>
              <td>
                <span class="tag ${cat.active ? 'tag-green' : 'tag-muted'}">
                  ${cat.active ? 'Đang hiện' : 'Đã ẩn'}
                </span>
              </td>
              <td class="center"><a class="btn btn-sm" href="${ctx}/admin/categories?edit=${cat.categoryId}">Sửa</a></td>
            </tr>
          </c:forEach>
        </tbody>
      </table>
    </div>

    <div class="card">
      <h2>${empty editing ? 'Thêm nhóm món' : 'Sửa nhóm món'}</h2>
      <form method="post" action="${ctx}/admin/categories">
        <input type="hidden" name="categoryId" value="${editing.categoryId}">
        <div class="field">
          <label for="name">Tên nhóm</label>
          <input type="text" id="name" name="name" value="${editing.name}" required>
        </div>
        <div class="field">
          <label for="displayOrder">Thứ tự hiển thị</label>
          <input type="number" id="displayOrder" name="displayOrder" value="${empty editing ? 0 : editing.displayOrder}">
        </div>
        <div class="field check">
          <input type="checkbox" id="active" name="active" value="true"
                 ${empty editing or editing.active ? 'checked' : ''}>
          <label for="active" style="margin:0;">Hiện trên thực đơn</label>
        </div>
        <button type="submit" class="btn btn-primary btn-block">
          ${empty editing ? 'Thêm nhóm' : 'Lưu thay đổi'}
        </button>
        <c:if test="${not empty editing}">
          <a class="btn btn-block mt" href="${ctx}/admin/categories">Huỷ sửa</a>
        </c:if>
      </form>
    </div>
  </div>
</main>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
