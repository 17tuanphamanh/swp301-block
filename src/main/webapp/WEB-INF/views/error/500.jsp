<%@ page isErrorPage="true" %>
<c:set var="pageTitle" value="Lỗi 500" />
<!DOCTYPE html>
<html lang="vi">
<head><jsp:include page="/WEB-INF/views/layout/head.jsp"/></head>
<body>
<jsp:include page="/WEB-INF/views/layout/header.jsp"/>

<main class="container narrow">
  <div class="card" style="text-align:center; padding:44px 20px;">
    <div style="font-size:44px; margin-bottom:8px;">⚠️</div>
    <h1>Có lỗi xảy ra</h1>
    <p class="muted mt">${empty errorMessage ? 'Hệ thống gặp sự cố khi xử lý yêu cầu. Vui lòng thử lại sau ít phút.' : errorMessage}</p>
    <div class="actions mt" style="justify-content:center;">
      <a class="btn btn-primary" href="${ctx}/">Về trang chủ</a>
    </div>
  </div>
</main>

<jsp:include page="/WEB-INF/views/layout/footer.jsp"/>
</body>
</html>
