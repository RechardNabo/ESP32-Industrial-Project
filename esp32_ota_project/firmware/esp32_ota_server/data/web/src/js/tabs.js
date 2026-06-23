/**
 * tabs.js — Tab switching: hides all .tab divs, shows the active one
 */
function setupTabs() {
  var nav = document.getElementById('tab-nav');
  if (!nav) return;
  var buttons = nav.querySelectorAll('button[data-tab]');

  function showTab(tabId) {
    // Hide all tab panels
    document.querySelectorAll('.tab').forEach(function(t) {
      t.classList.remove('active');
      t.style.display = 'none';
    });
    // Show the selected tab
    var target = document.getElementById('tab-' + tabId);
    if (target) {
      target.classList.add('active');
      target.style.display = 'block';
    }
    // Update nav buttons
    buttons.forEach(function(btn) {
      btn.classList.toggle('active', btn.getAttribute('data-tab') === tabId);
    });
    // Refresh tab-specific data
    if (tabId === 'devicemanager' || tabId === 'dashboard') {
      refreshAll();
    } else if (tabId === 'config') {
      refreshAll();
    } else if (tabId === 'modbus') {
      refreshModbus();
    } else if (tabId === 'bacnet') {
      refreshBacnet();
    } else if (tabId === 'snmp') {
      refreshSnmp();
    } else if (tabId === 'ota') {
      refreshAll();
    } else if (tabId === 'matrix') {
      refreshAll();
    } else if (tabId === 'charts') {
      refreshAll();
    }
  }

  buttons.forEach(function(btn) {
    btn.addEventListener('click', function() {
      showTab(btn.getAttribute('data-tab'));
    });
  });

  // Show initial tab
  showTab('dashboard');
}