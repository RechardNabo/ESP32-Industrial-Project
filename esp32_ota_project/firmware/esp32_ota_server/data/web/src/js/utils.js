/**
 * utils.js — ESP32 Device Manager utility functions
 */
function fmtBytes(b) {
  if (b < 1024) return b + ' B';
  if (b < 1048576) return (b / 1024).toFixed(0) + ' KB';
  return (b / 1048576).toFixed(1) + ' MB';
}

function fmtUptime(s) {
  if (s < 60) return s + ' s';
  if (s < 3600) return Math.floor(s / 60) + 'm ' + (s % 60) + 's';
  var h = Math.floor(s / 3600);
  var m = Math.floor((s % 3600) / 60);
  return h + 'h ' + m + 'm';
}

function toast(msg, type) {
  var el = document.createElement('div');
  el.className = 'toast ' + type;
  el.textContent = msg;
  document.body.appendChild(el);
  setTimeout(function() { el.remove(); }, 4000);
}