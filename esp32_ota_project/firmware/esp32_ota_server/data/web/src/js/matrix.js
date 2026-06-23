/**
 * matrix.js — Analysis Matrix tab: system health table + heap gauge
 */
function refreshMatrix(ver, stat, hb) {
  var rows = [];
  if (ver) {
    rows.push({ param: 'Firmware Version', value: 'v' + (ver.version || '\u2014'), range: '\u2014', status: 'info' });
    rows.push({ param: 'Hostname', value: ver.hostname || '\u2014', range: '\u2014', status: 'info' });
    rows.push({ param: 'Uptime', value: ver.uptime_s != null ? fmtUptime(ver.uptime_s) : '\u2014', range: '\u2014', status: ver.uptime_s > 60 ? 'ok' : 'warn' });
  }
  if (stat) {
    var heapStatus = stat.free_heap > 50000 ? 'ok' : (stat.free_heap > 20000 ? 'warn' : 'error');
    rows.push({ param: 'Free Heap', value: fmtBytes(stat.free_heap), range: '0 \u2013 ' + fmtBytes(stat.flash_size), status: heapStatus });
    rows.push({ param: 'Flash Size', value: fmtBytes(stat.flash_size), range: '\u2014', status: 'info' });
    rows.push({ param: 'Chip Model', value: stat.chip_model || '\u2014', range: '\u2014', status: 'info' });
    rows.push({ param: 'MAC Address', value: stat.mac || '\u2014', range: '\u2014', status: 'info' });
    rows.push({ param: 'OTA Session', value: stat.ota_unlocked ? 'Unlocked' : 'Locked', range: '\u2014', status: stat.ota_unlocked ? 'warn' : 'ok' });
  }
  if (hb) {
    rows.push({ param: 'Heartbeat Interval', value: hb.interval_ms + ' ms', range: '10 \u2013 60,000 ms', status: (hb.interval_ms >= 10 && hb.interval_ms <= 60000) ? 'ok' : 'error' });
    rows.push({ param: 'Tick Count', value: hb.tick_count, range: '\u2014', status: hb.tick_count > 0 ? 'ok' : 'warn' });
    rows.push({ param: 'LED Pin', value: 'GPIO ' + hb.led_pin, range: '\u2014', status: 'info' });
    rows.push({ param: 'Heartbeat Running', value: hb.running ? 'Yes' : 'No', range: '\u2014', status: hb.running ? 'ok' : 'error' });
  }

  var tbody = document.getElementById('matrix-body');
  if (!tbody) return;
  tbody.innerHTML = '';
  rows.forEach(function(row) {
    var tr = document.createElement('tr');
    var statusLabels = { ok: '\u2713 OK', warn: '\u26A0 Warning', error: '\u2717 Critical', info: '\u2139 Info' };
    var statusClass = 'status-' + row.status;
    tr.innerHTML = '<td>' + row.param + '</td>' +
                   '<td><code>' + row.value + '</code></td>' +
                   '<td style="color:var(--text-dim)">' + row.range + '</td>' +
                   '<td class="' + statusClass + '">' + statusLabels[row.status] + '</td>';
    tbody.appendChild(tr);
  });

  // Heap gauge
  if (stat && stat.flash_size > 0) {
    var totalRam = 320 * 1024;
    var freePct = Math.min(100, Math.round(stat.free_heap / totalRam * 100));
    var el = document.getElementById('matrix-heap-gauge');
    if (el) el.style.width = freePct + '%';
    el = document.getElementById('matrix-heap-pct');
    if (el) el.textContent = freePct + '%';
    el = document.getElementById('matrix-heap-val');
    if (el) el.textContent = fmtBytes(stat.free_heap);
    el = document.getElementById('matrix-flash-val');
    if (el) el.textContent = fmtBytes(stat.flash_size);
  }

  // Device info section
  if (ver) {
    el = document.getElementById('matrix-hostname');
    if (el) el.textContent = ver.hostname || '\u2014';
    el = document.getElementById('matrix-version');
    if (el) el.textContent = 'v' + (ver.version || '?');
    el = document.getElementById('matrix-uptime');
    if (el) el.textContent = ver.uptime_s != null ? fmtUptime(ver.uptime_s) : '\u2014';
  }
  if (stat) {
    el = document.getElementById('matrix-ip');
    if (el) el.textContent = location.host;
    el = document.getElementById('matrix-mac');
    if (el) el.textContent = stat.mac || '\u2014';
    el = document.getElementById('matrix-chip');
    if (el) el.textContent = stat.chip_model || '\u2014';
  }
}