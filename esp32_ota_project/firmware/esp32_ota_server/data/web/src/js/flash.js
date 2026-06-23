/**
 * flash.js — Firmware upload and progress tracking
 */
function pushFirmware() {
  if (!otaUnlocked) { toast('Unlock OTA session first', 'error'); return; }
  var fileInput = document.getElementById('ota-file');
  if (!fileInput.files[0]) { toast('Select a .bin file', 'error'); return; }
  var file = fileInput.files[0];

  var formData = new FormData();
  formData.append('firmware', file);

  document.getElementById('ota-upload-area').style.display = 'none';
  document.getElementById('ota-progress-area').style.display = 'block';

  var xhr = new XMLHttpRequest();
  xhr.open('POST', '/push-firmware', true);

  xhr.upload.onprogress = function(e) {
    if (e.lengthComputable) {
      var pct = Math.round(e.loaded / e.total * 100);
      document.getElementById('ota-progress').style.width = pct + '%';
      document.getElementById('ota-progress').textContent = pct + '%';
    }
  };

  xhr.onload = function() {
    document.getElementById('ota-progress').style.width = '100%';
    document.getElementById('ota-progress').textContent = '100%';
    try {
      var resp = JSON.parse(xhr.responseText);
      if (resp.success) {
        document.getElementById('ota-status-text').textContent = 'Flashing complete \u2014 rebooting\u2026';
        toast('Firmware update successful! Device is rebooting.', 'success');
        setTimeout(function() { location.reload(); }, 10000);
      } else {
        document.getElementById('ota-status-text').textContent = 'Error: ' + (resp.error || 'Unknown');
        toast('Flash error: ' + (resp.error || 'Unknown'), 'error');
      }
    } catch (e) {
      document.getElementById('ota-status-text').textContent = 'Unexpected response';
      toast('Unexpected response from device', 'error');
    }
  };

  xhr.onerror = function() {
    var pct = parseInt(document.getElementById('ota-progress').textContent) || 0;
    if (pct >= 90) {
      document.getElementById('ota-status-text').textContent = 'Upload complete \u2014 device rebooting\u2026';
      toast('Firmware uploaded. Device is rebooting.', 'success');
      setTimeout(function() { location.reload(); }, 10000);
    } else {
      document.getElementById('ota-status-text').textContent = 'Upload failed \u2014 connection lost';
      toast('Upload failed \u2014 connection lost', 'error');
    }
  };

  xhr.send(formData);
}