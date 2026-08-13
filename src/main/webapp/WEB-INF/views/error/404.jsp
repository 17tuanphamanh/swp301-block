<%@ page isErrorPage="true" %>
<c:set var="pageTitle" value="Lỗi 404" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container narrow">
  <div class="card" style="text-align:center; padding:44px 20px;">
    <div style="font-size:44px; margin-bottom:8px;">🔍</div>
    <h1>Không tìm thấy trang</h1>
    <p class="muted mt">${empty errorMessage ? 'Trang hoặc dữ liệu bạn tìm không tồn tại.' : errorMessage}</p>
    <div class="actions mt" style="justify-content:center;">
      <a class="btn btn-primary" href="${ctx}/">Về trang chủ</a>
    </div>
  </div>
</main>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
