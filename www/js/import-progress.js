// Bulk Import progress bar and button toggle handlers
// Used by mod_bulk_import to update progress modal and enable/disable import button

if (!window._importProgressRegistered) {
  window._importProgressRegistered = true;

  Shiny.addCustomMessageHandler('updateImportProgress', function(data) {
    var bar = document.getElementById(data.bar_id);
    var msg = document.getElementById(data.msg_id);
    if (bar) {
      bar.style.width = data.percent + '%';
      bar.setAttribute('aria-valuenow', data.percent);
      bar.textContent = data.percent + '%';
    }
    if (msg) {
      msg.textContent = data.message;
    }
  });

  Shiny.addCustomMessageHandler('toggleImportBtn', function(data) {
    var btn = document.getElementById(data.id);
    if (btn) {
      if (data.disabled) {
        btn.setAttribute('disabled', 'disabled');
      } else {
        btn.removeAttribute('disabled');
      }
    }
  });
}
