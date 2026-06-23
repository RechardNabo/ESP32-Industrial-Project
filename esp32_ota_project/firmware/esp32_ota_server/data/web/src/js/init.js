/**
 * init.js — Application bootstrap and initialisation
 */
function init() {
  try {
    console.log('ESP32 UI: Starting init...');
    setupTabs();

    // File input handler for OTA
    var fileInput = document.getElementById('ota-file');
    if (fileInput) {
      fileInput.addEventListener('change', function(e) {
        var file = e.target.files[0];
        if (!file) return;
        document.getElementById('ota-file-info').style.display = 'block';
        document.getElementById('ota-filename').textContent = file.name;
        document.getElementById('ota-filesize').textContent = fmtBytes(file.size);

        // Validate magic byte (0xE9)
        var reader = new FileReader();
        reader.onload = function(ev) {
          var arr = new Uint8Array(ev.target.result);
          if (arr.length > 0 && arr[0] === 0xE9) {
            document.getElementById('ota-magic').textContent = '0xE9 Valid';
            document.getElementById('ota-magic').style.color = 'var(--success)';
            document.getElementById('ota-flash-btn').disabled = false;
          } else {
            var hex = arr.length > 0 ? '0x' + arr[0].toString(16).toUpperCase() : '??';
            document.getElementById('ota-magic').textContent = hex + ' Invalid';
            document.getElementById('ota-magic').style.color = 'var(--danger)';
            document.getElementById('ota-flash-btn').disabled = true;
            toast('Invalid ESP32 binary - magic byte must be 0xE9', 'error');
          }
        };
        reader.readAsArrayBuffer(file.slice(0, 4));
      });
      console.log('ESP32 UI: File input handler set');
    } else {
      console.error('ESP32 UI: ota-file element not found!');
    }

    // Initial data fetch
    refreshAll();
    checkAlive();

    // Initial protocol tab data
    refreshModbus();
    refreshBacnet();
    refreshSnmp();

    // Full data refresh every 5 seconds
    refreshTimer = setInterval(refreshAll, 5000);

    // Fast heartbeat alive check every 2 seconds
    hbFastTimer = setInterval(checkAlive, 2000);

    // Refresh protocol tabs every 3 seconds (simulated data)
    setInterval(function() {
      refreshModbus();
      refreshBacnet();
      refreshSnmp();
    }, 3000);

    console.log('ESP32 UI: Init complete');
  } catch (e) {
    console.error('ESP32 UI Init Error:', e);
    var errDiv = document.createElement('div');
    errDiv.style.cssText = 'position:fixed;top:0;left:0;right:0;background:#ef5b5b;color:#fff;padding:12px;text-align:center;font-size:14px;z-index:99999;';
    errDiv.textContent = 'UI Error: ' + e.message;
    document.body.appendChild(errDiv);
  }
}

// Run when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}