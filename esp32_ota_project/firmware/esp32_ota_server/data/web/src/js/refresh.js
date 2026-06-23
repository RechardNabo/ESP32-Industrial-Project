/**
 * refresh.js — Data polling and tab update orchestration
 */

function refreshCharts() {
  drawLineChart('chart-heap', heapHistory, {
    color: '#4caf50',
    minVal: 0,
    label: 'Free Heap (bytes)',
    format: function(v) { return fmtBytes(v); }
  });

  drawLineChart('chart-uptime', uptimeHistory, {
    color: '#5b8def',
    minVal: 0,
    label: 'Uptime (seconds)',
    format: function(v) { return fmtUptime(v); }
  });

  // Tick delta chart
  var tickDeltas = [];
  for (var i = 1; i < tickHistory.length; i++) {
    var delta = tickHistory[i] - tickHistory[i - 1];
    tickDeltas.push(delta >= 0 ? delta : 0);
  }
  if (tickDeltas.length < 1) tickDeltas = [0];

  drawLineChart('chart-ticks', tickDeltas, {
    color: '#ff9800',
    minVal: 0,
    label: 'Ticks / interval',
    format: function(v) { return Math.round(v); }
  });

  // OTA status
  var el = document.getElementById('charts-ota-status');
  if (el) el.textContent = otaUnlocked ? 'Unlocked' : 'Locked';
  el = document.getElementById('charts-ota-remaining');
  if (el) el.textContent = otaUnlocked ? '\u2014' : '\u2014';
}

function refreshAll() {
  Promise.all([
    fetch('/version').then(function(r) { return r.json(); }).catch(function() { return null; }),
    fetch('/status').then(function(r) { return r.json(); }).catch(function() { return null; }),
    fetch('/heartbeat').then(function(r) { return r.json(); }).catch(function() { return null; })
  ]).then(function(data) {
    var ver = data[0], stat = data[1], hb = data[2];
    if (ver || stat || hb) recordSample(ver, stat, hb);
    refreshDashboardView(ver, stat, hb);
    if (hb) refreshConfig(hb);
    refreshMatrix(ver, stat, hb);
    refreshCharts();
  }).catch(function(e) {
    console.error('ESP32 UI: refreshAll error:', e);
  });
}