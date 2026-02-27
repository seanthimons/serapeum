// Citation Audit progress bar handler
// Used by mod_citation_audit to update progress modal during analysis

if (!window._auditProgressRegistered) {
  window._auditProgressRegistered = true;

  Shiny.addCustomMessageHandler('updateAuditProgress', function(data) {
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
}
