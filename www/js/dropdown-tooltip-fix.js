// Hide any visible Bootstrap tooltip when a dropdown is about to open.
// This prevents tooltips on dropdown-toggle buttons from overlaying
// the open dropdown menu and blocking its items (issue #287).
document.addEventListener('show.bs.dropdown', function () {
  document.querySelectorAll('[data-bs-toggle="tooltip"]').forEach(function (el) {
    var tt = bootstrap.Tooltip.getInstance(el);
    if (tt) tt.hide();
  });
});
