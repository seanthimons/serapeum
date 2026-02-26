// Select-all checkbox tri-state handler (Phase 38)
// Used by mod_search_notebook to set checkbox checked/indeterminate state

if (!window._selectAllRegistered) {
  window._selectAllRegistered = true;

  Shiny.addCustomMessageHandler('setCheckboxState', function(data) {
    var cb = document.getElementById(data.id);
    if (cb) {
      cb.checked = data.checked;
      cb.indeterminate = data.indeterminate || false;
    }
  });
}
