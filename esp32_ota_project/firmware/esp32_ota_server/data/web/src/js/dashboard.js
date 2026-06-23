/**
 * dashboard.js — Industrial Dashboard: gauges, matrix, charts, details
 */

function refreshDashboardView(ver, stat, hb) {
  /* === Status Bar === */
  var el;

  /* Uptime + Version */
  if (ver) {
    el = document.getElementById('dash-uptime');
    if (el) el.textContent = ver.uptime_s != null ? fmtUptime(ver.uptime_s) : '\u2014';
    el = document.getElementById('dash-version');
    if (el) el.textContent = 'v' + (ver.version || '?');
    el = document.getElementById('dash-hostname');
    if (el) el.textContent = ver.hostname || '\u2014';
  }

  /* Status + OTA */
  if (stat) {
    el = document.getElementById('dash-ip');
    if (el) el.textContent = location.host;
    el = document.getElementById('dash-mac');
    if (el) el.textContent = stat.mac || '\u2014';
    el = document.getElementById('dash-chip');
    if (el) el.textContent = stat.chip_model || '\u2014';
    el = document.getElementById('dash-flash');
    if (el) el.textContent = stat.flash_size != null ? fmtBytes(stat.flash_size) : '\u2014';
    el = document.getElementById('dash-heap-full');
    if (el) el.textContent = stat.free_heap != null ? fmtBytes(stat.free_heap) : '\u2014';

    /* Heap gauge (circular) */
    var totalRam = 320 * 1024; /* ESP32 total RAM approx */
    var heapPct = stat.free_heap != null ? Math.min(100, Math.round(stat.free_heap / totalRam * 100)) : 0;
    var circumference = 326.73; /* 2 * PI * 52 */
    var offset = circumference - (heapPct / 100) * circumference;
    el = document.getElementById('dash-heap-circle');
    if (el) el.style.strokeDashoffset = offset;
    el = document.getElementById('dash-heap-pct');
    if (el) el.textContent = heapPct + '%';
    el = document.getElementById('dash-heap-sub');
    if (el) el.textContent = fmtBytes(stat.free_heap);
    el = document.getElementById('dash-heap-detail');
    if (el) el.textContent = 'Heap: ' + fmtBytes(stat.free_heap) + ' / Flash: ' + (stat.flash_size != null ? fmtBytes(stat.flash_size) : '\u2014');

    /* Change heap gauge color based on health */
    el = document.getElementById('dash-heap-circle');
    if (el) {
      el.classList.remove('dash-circle-blue', 'dash-circle-orange');
      if (heapPct < 15) {
        el.style.stroke = '#ef5b5b'; /* danger */
      } else if (heapPct < 40) {
        el.style.stroke = '#ff9800'; /* warning */
      } else {
        el.style.stroke = '#4caf50'; /* good */
      }
    }

    /* Matrix: Memory */
    setMatrixCell('dm-heap', fmtBytes(stat.free_heap),
      stat.free_heap > 50000 ? 'OK' : (stat.free_heap > 20000 ? 'WARN' : 'CRIT'),
      stat.free_heap > 50000 ? 'green' : (stat.free_heap > 20000 ? 'orange' : 'red'));

    /* Matrix: OTA */
    var otaLabel = stat.ota_unlocked ? 'Unlocked' : 'Locked';
    setMatrixCell('dm-ota', otaLabel, stat.ota_unlocked ? 'WARN' : 'OK',
      stat.ota_unlocked ? 'orange' : 'green');

    /* Matrix: Network */
    setMatrixCell('dm-net', location.host, 'OK', 'green');

    /* Matrix: Chip */
    setMatrixCell('dm-chip', stat.chip_model || '\u2014', 'OK', 'green');

    /* OTA badge */
    var otBadge = document.getElementById('dash-ota-badge');
    if (otBadge) {
      otBadge.textContent = stat.ota_unlocked ? 'Unlocked' : 'Locked';
      otBadge.className = 'badge ' + (stat.ota_unlocked ? 'orange' : 'green');
    }
    el = document.getElementById('dash-ota-status');
    if (el) el.textContent = stat.ota_unlocked ? 'Unlocked (' + (stat.ota_remaining_s || 0) + 's remaining)' : 'Locked';
  }

  if (hb) {
    /* Tick rate gauge */
    var tickDelta = 0;
    if (tickHistory.length >= 2) {
      tickDelta = tickHistory[tickHistory.length - 1] - tickHistory[tickHistory.length - 2];
    }
    var tickRate = (currentHbInterval > 0 && tickDelta >= 0) ? (tickDelta / (currentHbInterval / 1000)).toFixed(2) : '0';
    var tickPct = Math.min(100, tickDelta > 0 ? Math.round((tickDelta / (currentHbInterval / 1000)) / 10 * 100) : 0);

    el = document.getElementById('dash-tick-circle');
    if (el) {
      var tc = 326.73;
      el.style.strokeDashoffset = tc - (tickPct / 100) * tc;
    }
    el = document.getElementById('dash-tick-pct');
    if (el) el.textContent = tickRate;
    el = document.getElementById('dash-tick-sub');
    if (el) el.textContent = tickDelta + ' ticks';
    el = document.getElementById('dash-tick-detail');
    if (el) el.textContent = 'Ticks: ' + hb.tick_count + ' | Interval: ' + hb.interval_ms + 'ms';

    /* Uptime gauge: fill based on hours (max 24h = 100%) */
    if (ver && ver.uptime_s != null) {
      var uptimeHours = ver.uptime_s / 3600;
      var upPct = Math.min(100, Math.round((uptimeHours / 24) * 100));
      el = document.getElementById('dash-uptime-circle');
      if (el) {
        var uc = 326.73;
        el.style.strokeDashoffset = uc - (upPct / 100) * uc;
      }
      el = document.getElementById('dash-uptime-val');
      if (el) el.textContent = fmtUptime(ver.uptime_s);
      el = document.getElementById('dash-uptime-sub');
      if (el) el.textContent = Math.round(uptimeHours * 10) / 10 + 'h';
    }
    el = document.getElementById('dash-uptime-detail');
    if (el) el.textContent = 'Running: ' + (hb.running ? 'Yes' : 'No') + ' | LED: GPIO ' + hb.led_pin;

    /* Matrix: Heartbeat */
    setMatrixCell('dm-hb', hb.running ? 'Running' : 'Stopped', hb.running ? 'OK' : 'CRIT',
      hb.running ? 'green' : 'red');

    el = document.getElementById('dash-hb-int');
    if (el) el.textContent = hb.interval_ms + ' ms';
    el = document.getElementById('dash-hb-led');
    if (el) el.textContent = 'GPIO ' + hb.led_pin;
    el = document.getElementById('dash-hb-tick');
    if (el) el.textContent = hb.tick_count;
  }

  if (ver) {
    /* Matrix: Firmware */
    setMatrixCell('dm-fw', 'v' + (ver.version || '?'), 'OK', 'green');
  }

  /* === Inline Charts === */
  drawLineChart('dash-heap-chart', heapHistory, {
    color: '#4caf50',
    label: 'Free Heap (bytes)',
    format: function(v) { return fmtBytes(v); }
  });

  /* Tick delta chart */
  var tickDeltas = [];
  for (var i = 1; i < tickHistory.length; i++) {
    var d = tickHistory[i] - tickHistory[i - 1];
    tickDeltas.push(d >= 0 ? d : 0);
  }
  if (tickDeltas.length < 1) tickDeltas = [0];
  drawLineChart('dash-tick-chart', tickDeltas, {
    color: '#ff9800',
    minVal: 0,
    label: 'Ticks / interval',
    format: function(v) { return Math.round(v); }
  });
}

/* Helper: set a matrix cell value + badge */
function setMatrixCell(prefix, value, statusLabel, badgeColor) {
  var valEl = document.getElementById(prefix + '-val');
  var badgeEl = document.getElementById(prefix + '-badge');
  if (valEl) valEl.textContent = value;
  if (badgeEl) {
    badgeEl.textContent = statusLabel;
    badgeEl.className = 'dash-cell-status badge ' + badgeColor;
  }
  /* Border color hint */
  var cell = document.getElementById(prefix.replace('-val', '').replace('-badge', ''));
  /* prefix is like dm-heap, dm-hb, etc — cell id matches */
}