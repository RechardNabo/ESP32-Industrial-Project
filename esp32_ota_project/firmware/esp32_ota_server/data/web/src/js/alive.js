/**
 * alive.js — Device online/offline detection via heartbeat polling
 */
function checkAlive() {
  fetch('/heartbeat', { method: 'GET' }).then(function(r) { return r.json(); }).then(function(hb) {
    var newTick = hb.tick_count;
    if (lastTickCount === -1) {
      lastTickCount = newTick;
    } else if (newTick !== lastTickCount) {
      staleCount = 0;
      isAlive = true;
      lastTickCount = newTick;
    } else {
      staleCount++;
      if (staleCount >= STALE_THRESHOLD) { isAlive = false; }
    }
    updateAliveIndicator();
  }).catch(function() {
    isAlive = false;
    staleCount = STALE_THRESHOLD;
    updateAliveIndicator();
  });
}

function updateAliveIndicator() {
  var dot = document.getElementById('alive-dot');
  var label = document.getElementById('alive-label');
  if (!dot || !label) return;
  if (isAlive) {
    dot.className = 'alive-dot alive';
    label.textContent = 'Online';
    label.className = 'alive-label alive';
  } else {
    dot.className = 'alive-dot offline';
    label.textContent = 'Offline';
    label.className = 'alive-label offline';
  }
  /* Also update dashboard status bar alive indicator */
  var dDot = document.getElementById('dash-alive-dot');
  var dLabel = document.getElementById('dash-alive-label');
  if (dDot) dDot.className = 'alive-dot ' + (isAlive ? 'alive' : 'offline');
  if (dLabel) {
    dLabel.textContent = isAlive ? 'Online' : 'Offline';
    dLabel.className = 'alive-label ' + (isAlive ? 'alive' : 'offline');
  }
}