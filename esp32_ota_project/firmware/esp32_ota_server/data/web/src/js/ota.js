/**
 * ota.js — OTA unlock, countdown, and firmware flash logic
 */
function unlockOta() {
  var token = '';
  var otaToken = document.getElementById('ota-token');
  var cfgToken = document.getElementById('cfg-ota-token');
  if (otaToken && otaToken.value.trim()) token = otaToken.value.trim();
  else if (cfgToken && cfgToken.value.trim()) token = cfgToken.value.trim();
  if (!token) { toast('Enter a token', 'error'); return; }

  fetch('/unlock-ota?token=' + encodeURIComponent(token))
    .then(function(r) { return r.json(); })
    .then(function(d) {
      if (d.unlocked) {
        otaUnlocked = true;
        otaExpiresAt = Date.now() + d.expires_in_s * 1000;
        toast('OTA session unlocked \u2014 ' + d.expires_in_s + ' s', 'success');
        enableOtaSteps();
        startOtaCountdown();
      } else {
        toast(d.error || 'Unlock failed', 'error');
      }
    })
    .catch(function(e) { toast('Error: ' + e, 'error'); });
}

function enableOtaSteps() {
  var step2 = document.getElementById('ota-step-upload');
  if (step2) step2.classList.remove('disabled-card');
  var el = document.getElementById('ota-status-badge');
  if (el) { el.textContent = 'Unlocked'; el.className = 'badge green'; }
}

function disableOtaSteps() {
  var step2 = document.getElementById('ota-step-upload');
  if (step2) step2.classList.add('disabled-card');
  var el = document.getElementById('ota-status-badge');
  if (el) { el.textContent = 'Locked'; el.className = 'badge red'; }
  el = document.getElementById('ota-remaining');
  if (el) el.textContent = '\u2014';
  otaUnlocked = false;
}

function startOtaCountdown() {
  if (otaCountdownTimer) clearInterval(otaCountdownTimer);
  otaCountdownTimer = setInterval(function() {
    var remaining = Math.max(0, Math.round((otaExpiresAt - Date.now()) / 1000));
    var el1 = document.getElementById('ota-remaining');
    if (el1) el1.textContent = remaining > 0 ? remaining + ' s' : 'Expired';
    var el2 = document.getElementById('d-ota-expires');
    if (el2) el2.textContent = remaining > 0 ? remaining + ' s' : 'Expired';
    var el3 = document.getElementById('charts-ota-remaining');
    if (el3) el3.textContent = remaining > 0 ? remaining + ' s' : 'Expired';
    if (remaining <= 0) {
      clearInterval(otaCountdownTimer);
      disableOtaSteps();
      toast('OTA session expired', 'error');
    }
  }, 1000);
}