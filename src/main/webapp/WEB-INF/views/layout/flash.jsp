<%-- Thông báo hiển thị một lần sau khi chuyển hướng. --%>
<c:if test="${not empty flashSuccess}">
  <div class="alert alert-success">${flashSuccess}</div>
</c:if>
<c:if test="${not empty flashError}">
  <div class="alert alert-error">${flashError}</div>
</c:if>
<c:if test="${not empty errorMessage}">
  <div class="alert alert-error">${errorMessage}</div>
</c:if>
<c:if test="${not empty warning}">
  <div class="alert alert-warn">${warning}</div>
</c:if>
