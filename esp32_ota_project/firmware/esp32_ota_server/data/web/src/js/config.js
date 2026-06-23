/**
 * config.js — Configuration tab: heartbeat interval + OTA token
 */
function refreshConfig(hb) {
  document.getElementById('cfg-hb-current').textContent = hb.interval_ms + ' ms';
  document.getElementById('cfg-hb-tick').textContent = hb.tick_count;
  document.getElementById('cfg-hb-led').textContent = 'GPIO ' + hb.led_pin;
  document.getElementById('cfg-hb-running').innerHTML = hb.running
    ? '<span class="badge green">Running</span>'
    : '<span class="badge red">Stopped</span>';
  document.getElementById('cfg-hb-input').placeholder = hb.interval_ms;
  updatePresetHighlight(hb.interval_ms);
}

function setPreset(ms) {
  document.getElementById('cfg-hb-input').value = ms;
  setHeartbeat();
}

function updatePresetHighlight(current) {
  document.querySelectorAll('#cfg-hb-presets button').forEach(function(btn) {
    var match = btn.getAttribute('onclick');
    if (match) {
      var num = parseInt(match.match(/\d+/)[0]);
      btn.classList.toggle('active', num === current);
    }
  });
}

function setHeartbeat() {
  var val = parseInt(document.getElementById('cfg-hb-input').value);
  if (isNaN(val) || val < 10 || val > 60000) {
    toast('Interval must be 10 \u2013 60,000 ms', 'error');
    return;
  }
  fetch('/heartbeat?interval=' + val, { method: 'POST' })
    .then(function(r) { return r.json(); })
    .then(function(d) {
      if (d.interval_ms) {
        toast('Interval set to ' + d.interval_ms + ' ms', 'success');
        refreshAll();
      } else {
        toast(d.error || 'Failed to set interval', 'error');
      }
    })
    .catch(function(e) { toast('Error: ' + e, 'error'); });
}